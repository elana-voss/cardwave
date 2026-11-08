//! Chats over HTTP: the list, starting, the branch in view, writing, editing,
//! swiping, deleting and putting back messages, the persona, lorebooks, characters
//! joining or leaving, who replies next and in what order, how replies are
//! written (`set_reply`), the characters' own replies (`set_talk`), Rename, a new
//! chat like it (`again`), and the chat as a file. A message sent takes the
//! waiting attachments it names (`api/attachments.rs`). Messages sent, deleted or
//! put back tell the user's other pages (`PageEvent::Messages`); a chat started,
//! renamed, starred, archived, trashed, restored or deleted tells them
//! (`PageEvent::Chat`, `PageEvent::Trash`). Replies are made in `generate`; a
//! chat always uses its cards' current texts.
//!
//! A chat's view tells per character whether it has written (`written`), its
//! modes (`ChatView::modes`, `api/assistant.rs`) and whether replies get the
//! Reply length (`thinks`, `tools`). A chat without characters is the AI itself
//! (`ChatView::model`). A chat names itself once after its first turns (`name_itself`).

use std::collections::HashMap;
use std::collections::hash_map::Entry;

use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::Response;
use axum::routing::{delete, get, patch, post, put};
use axum::{Json, Router};
use cw_chat::chats::{
    self, Chat, ChatLorebook, ChatReply, ChatSort, ChatSummary, ChatTalk, Find, LoreSource,
    MessageView, NewChat, NewMessage, turn,
};
use cw_chat::{assistant, attachments};
use cw_core::NotFound;
use cw_core::{Events, PageEvent};
use cw_library::cards::{self, Show};
use cw_library::personas::{self, Persona};
use cw_library::settings;
use cw_library::trash;
use cw_prompt::Role;
use cw_provider::{self as provider, Provider};
use cw_store::Db;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::cards::{avatar_url, download};
use super::lorebooks::AddLorebook;
use super::{ApiResult, Flags, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/chats", get(list).post(start))
        .route("/api/chats/{id}", get(show).patch(change).delete(remove))
        .route("/api/chats/{id}/export", get(export))
        .route("/api/chats/{id}/title", put(rename))
        .route("/api/chats/{id}/again", post(again))
        .route("/api/chats/{id}/head", put(move_head))
        .route(
            "/api/chats/{id}/persona",
            put(set_persona).delete(drop_persona),
        )
        .route("/api/chats/{id}/lore", put(set_lore))
        .route("/api/chats/{id}/reply", put(set_reply))
        .route("/api/chats/{id}/talk", put(set_talk))
        .route("/api/chats/{id}/lorebooks", post(add_lorebook))
        .route(
            "/api/chats/{id}/lorebooks/{lorebook_id}",
            delete(remove_lorebook),
        )
        .route("/api/chats/{id}/messages", post(send))
        .route("/api/chats/{id}/turn", put(set_turn))
        .route("/api/chats/{id}/characters", post(add_character))
        .route("/api/chat-characters/{id}", delete(remove_character))
        .route("/api/chat-characters/{id}/position", put(move_character))
        .route("/api/messages/{id}", patch(edit).delete(delete_message))
        .route("/api/messages/{id}/version", delete(delete_version))
        .route("/api/messages/{id}/restore", post(restore_messages))
        .route("/api/messages/{id}/swipes", post(add_swipe))
}

/// One character of a chat.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct ChatCharacter {
    /// What a message's `speaker_id` refers to.
    pub id: i64,
    /// Its place in the chat's speaking order, from 0.
    pub position: i64,
    pub card_id: i64,
    /// The card's title in the library.
    pub card_title: String,
    /// The card's version, which is its current one.
    pub version_id: i64,
    /// The character's ID in that card.
    pub character: String,
    pub name: String,
    pub(crate) avatar_url: String,
    /// It has written in the chat, on any branch, and so stays in it.
    pub written: bool,
}

/// A chat as its screen shows it.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct ChatView {
    pub chat: Chat,
    /// In speaking order. The one the chat is called after is the one with
    /// the lowest `id`, which joined first.
    pub characters: Vec<ChatCharacter>,
    /// The branch in view, from the first message to the chat's head.
    pub messages: Vec<MessageView>,
    /// The lorebooks its characters bring along and those it took from the
    /// library, with what the chat leaves out.
    pub lorebooks: Vec<ChatLorebook>,
    /// Who the user is in it, if anyone in particular: the chat keeps its
    /// persona when that is archived or in the Trash.
    pub persona: Option<Persona>,
    /// The call of a tool its reply waits for the user to allow; read by the
    /// chat's own `GET` alone, `None` in every other answer.
    pub asking: Option<cw_coding::tools::ToolAsk>,
    /// The modes of the card of the character it began with, which it can be
    /// in (`assistant`); none for a card without modes.
    pub modes: Vec<String>,
    /// In a chat without a character, the chat model a new reply comes from,
    /// whose name a reply carries that does not keep its own
    /// (`MessageView::model`); none where no model is set up.
    pub model: Option<String>,
    /// Whether the account's chat model thinks (`Provider::thinks`), so its
    /// replies are sent no Reply length.
    pub thinks: bool,
    /// Whether a reply of its first character (in a chat without one, the AI)
    /// is offered a tool besides Code mode's and the dice (`generate::offers_tools`), so
    /// it is sent no Reply length; with Code mode on it always is.
    pub tools: bool,
}

/// What the list of chats is asked for, in the address: `?q=mira&show=archived&sort=name`.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct ChatQuery {
    /// Words to search for in titles, characters' names and cards' titles.
    pub q: Option<String>,
    pub show: Option<Show>,
    pub sort: Option<ChatSort>,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct CharacterRef {
    pub version_id: i64,
    /// The character's ID in that card version.
    pub character: String,
}

#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct StartChat {
    /// In speaking order; the first one's greetings open the chat.
    pub characters: Vec<CharacterRef>,
    /// The user's default persona when left out.
    pub persona_id: Option<i64>,
    /// Which greeting is in view at first; the others are its swipes.
    pub greeting: Option<usize>,
}

/// A chat's title, as the user gives it ("Rename").
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct ChatTitle {
    pub title: String,
}

/// A character of a card of the library, to join a chat that is there.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct AddCharacter {
    pub card_id: i64,
    /// The character's ID in the card.
    pub character: String,
}

/// Where a chat character goes in its chat's speaking order.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct MoveCharacter {
    /// Its place: 0 is the first, and one past the last is the last.
    pub position: u32,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetPersona {
    pub persona_id: i64,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetLore {
    #[serde(flatten)]
    #[ts(flatten)]
    pub source: LoreSource,
    /// A lorebook of the chat or an entry of one, as its card or its lorebook names it.
    pub reference: String,
    /// False leaves it out of the chat's prompts.
    pub on: bool,
}

#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct SendMessage {
    pub content: String,
    /// The user's message unless said otherwise.
    pub role: Option<Role>,
    /// The chat character speaking, for an assistant message only; the one
    /// the chat began with, which joined first, when left out.
    pub speaker_id: Option<i64>,
    /// What waits attached in the chat that goes with it (`attachments`).
    pub attachments: Option<Vec<i64>>,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct MessageText {
    pub content: String,
}

#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct MoveHead {
    pub message_id: i64,
    /// True shows the message's branch down to its newest message. Otherwise the
    /// view ends at the message, and the next message starts a new branch there.
    pub follow: Option<bool>,
}

/// The chat `chat_id` as its page shows it, to this computer's account where
/// `owner`.
fn view(db: &Db, user: i64, chat_id: i64, owner: bool) -> anyhow::Result<ChatView> {
    let (chat, messages) = chats::branch(db, user, chat_id)?;
    // Characters out of one card share its version, which is read once.
    let mut versions = HashMap::new();
    let mut characters = Vec::new();
    let written = chats::written(db, chat_id)?;
    for participant in chats::participants(db, user, chat_id)? {
        let version_id = participant.version_id;
        let (card_id, card_title, document) = match versions.entry(version_id) {
            Entry::Occupied(known) => known.into_mut(),
            Entry::Vacant(new) => {
                let card_id =
                    cards::card_of(db, user, version_id)?.ok_or(NotFound("card version"))?;
                let title = cards::title(db, user, card_id)?.ok_or(NotFound("card"))?;
                new.insert((card_id, title, cards::document_of(db, version_id)?))
            }
        };
        characters.push(ChatCharacter {
            id: participant.id,
            position: participant.position,
            card_id: *card_id,
            card_title: card_title.clone(),
            version_id,
            name: document.character_name(&participant.character),
            avatar_url: avatar_url(db, version_id, document, &participant.character)?,
            character: participant.character,
            written: written.contains(&participant.id),
        });
    }
    // Each character in the language the AI writes in, as the prompt reads it
    // (a translated card's lorebooks are copies with references of their own).
    let language = settings::get(db, user)?.language;
    let sources: Vec<_> = characters
        .iter()
        .map(|character| {
            let document = &versions[&character.version_id].2;
            let id = document.in_language(&character.character, &language);
            (character.card_id, document, id)
        })
        .collect();
    let lorebooks = chats::lorebooks_of(db, chat_id, &sources)?;
    let first = characters.iter().min_by_key(|one| one.id);
    let document = first.map(|first| &versions[&first.version_id].2);
    let modes = document
        .map(|document| document.modes())
        .unwrap_or_default();
    let tools = super::generate::offers_tools(
        db,
        user,
        owner,
        first.map(|first| first.card_id),
        first.map_or("", |first| first.character.as_str()),
        document
            .and_then(|document| assistant::mode_of(document, &chat))
            .as_deref(),
    )?;
    let persona = chats::persona_of(db, user, &chat)?;
    let provider = provider::get(db, user)?;
    let thinks = provider.as_ref().is_some_and(Provider::thinks);
    let model = provider
        .filter(|_| characters.is_empty())
        .map(|provider| provider.model);
    Ok(ChatView {
        chat,
        characters,
        messages,
        lorebooks,
        persona,
        asking: None,
        modes,
        model,
        thinks,
        tools,
    })
}

/// The chats the list of chats shows; see [`chats::find`].
async fn list(
    State(state): State<AppState>,
    User(user): User,
    Query(query): Query<ChatQuery>,
) -> ApiResult<Json<Vec<ChatSummary>>> {
    state
        .run(move |db| {
            let find = Find {
                query: query.q.as_deref().unwrap_or(""),
                show: query.show.unwrap_or_default(),
                sort: query.sort.unwrap_or_default(),
            };
            chats::find(db, user, &find)
        })
        .await
        .map(Json)
}

async fn start(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<StartChat>,
) -> ApiResult<(StatusCode, Json<ChatView>)> {
    let owner = user == state.local_user();
    let chat = state
        .run(move |db| {
            let characters: Vec<(i64, &str)> = new
                .characters
                .iter()
                .map(|c| (c.version_id, c.character.as_str()))
                .collect();
            // A chat without a character has no persona.
            let persona_id = match new.persona_id {
                _ if characters.is_empty() => None,
                Some(id) => Some(id),
                None => personas::default_of(db, user)?,
            };
            let new = NewChat {
                characters: &characters,
                persona_id,
                greeting: new.greeting.unwrap_or(0),
            };
            view(db, user, chats::create(db, user, &new)?, owner)
        })
        .await?;
    told_chat(&state, user, &page, chat.chat.id);
    Ok((StatusCode::CREATED, Json(chat)))
}

async fn show(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<ChatView>> {
    let mut chat = viewed(&state, user, move |_| Ok(id)).await?;
    chat.asking = state
        .asks()
        .get(&(user, id))
        .map(|asking| asking.ask.clone());
    Ok(Json(chat))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(flags): Json<Flags>,
) -> ApiResult<Json<Chat>> {
    let trashes = flags.trashes();
    let chat = changed(&state, (user, id), move |db| {
        let set: [super::SetFlag; 3] = [
            |db, user, id, on| chats::set_favorite(db, user, id, on),
            |db, user, id, on| chats::set_archived(db, user, id, on),
            |db, user, id, on| chats::set_trashed(db, user, id, on),
        ];
        flags.apply(db, user, id, set)
    })
    .await?;
    told_chat(&state, user, &page, id);
    if trashes {
        super::cards::told_trash(&state, user, &page);
    }
    Ok(chat)
}

/// Tells the user's pages of a change of the chat `id`, but for the page `from` that made it.
fn told_chat(state: &AppState, user: i64, from: &Page, id: i64) {
    state.tell(user, from, &PageEvent::Chat { id });
}

/// Makes a change to the chat, and answers with the chat as it is after it.
async fn changed<T: Send + 'static>(
    state: &AppState,
    (user, id): (i64, i64),
    change: impl FnOnce(&Db) -> anyhow::Result<T> + Send + 'static,
) -> ApiResult<Json<Chat>> {
    state
        .run(move |db| {
            change(db)?;
            Ok(chats::get(db, user, id)?.ok_or(NotFound("chat"))?)
        })
        .await
        .map(Json)
}

/// Makes a change that answers the chat's ID, and answers with the chat's view after it.
async fn viewed(
    state: &AppState,
    user: i64,
    change: impl FnOnce(&Db) -> anyhow::Result<i64> + Send + 'static,
) -> ApiResult<ChatView> {
    let owner = user == state.local_user();
    state
        .run(move |db| view(db, user, change(db)?, owner))
        .await
}

/// Gives the chat a title of the user's ("Rename").
async fn rename(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(to): Json<ChatTitle>,
) -> ApiResult<Json<Chat>> {
    let chat = changed(&state, (user, id), move |db| {
        chats::rename(db, user, id, &to.title)
    })
    .await?;
    told_chat(&state, user, &page, id);
    Ok(chat)
}

/// Starts a new chat with the chat's characters and settings
/// (`chats::again`), and answers with it.
async fn again(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<(StatusCode, Json<ChatView>)> {
    let chat = viewed(&state, user, move |db| chats::again::again(db, user, id)).await?;
    told_chat(&state, user, &page, chat.chat.id);
    Ok((StatusCode::CREATED, Json(chat)))
}

/// Deletes a chat for good. Only a chat in the Trash, and not while a reply is
/// being generated in it.
async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| trash::delete_chat(db, user, id))
        .await?;
    told_chat(&state, user, &page, id);
    super::cards::told_trash(&state, user, &page);
    Ok(StatusCode::NO_CONTENT)
}

/// The chat as a file to save, of the kind SillyTavern keeps a chat in; see [`chats::export`].
async fn export(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    let exported = state.run(move |db| chats::export(db, user, id)).await?;
    Ok(download("application/jsonl", exported))
}

/// Sets who the user is in the chat, from the next reply on.
async fn set_persona(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<SetPersona>,
) -> ApiResult<Json<Chat>> {
    let persona_id = Some(to.persona_id);
    changed(&state, (user, id), move |db| {
        chats::set_persona(db, user, id, persona_id)
    })
    .await
}

/// Takes the persona off the chat.
async fn drop_persona(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Chat>> {
    changed(&state, (user, id), move |db| {
        chats::set_persona(db, user, id, None)
    })
    .await
}

/// Sets the chat's reply length and Code mode, from the next reply on.
async fn set_reply(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<ChatReply>,
) -> ApiResult<Json<Chat>> {
    changed(&state, (user, id), move |db| {
        chats::set_reply(db, user, id, &to)
    })
    .await
}

/// Sets the pause between the characters' own replies and how many they write in a row.
async fn set_talk(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<ChatTalk>,
) -> ApiResult<Json<Chat>> {
    changed(&state, (user, id), move |db| {
        chats::set_talk(db, user, id, &to)
    })
    .await
}

/// Leaves a lorebook or one of its entries out of the chat's prompts, or takes
/// it back in, from the next reply on. Answers with the chat's lorebooks.
async fn set_lore(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<SetLore>,
) -> ApiResult<Json<Vec<ChatLorebook>>> {
    state
        .run(move |db| chats::set_lore(db, user, id, to.source, &to.reference, to.on))
        .await
        .map(Json)
}

/// Takes a lorebook of the library along in the chat, from the next reply on.
/// Answers with the chat's lorebooks.
async fn add_lorebook(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(new): Json<AddLorebook>,
) -> ApiResult<Json<Vec<ChatLorebook>>> {
    state
        .run(move |db| chats::add_lorebook(db, user, id, new.lorebook_id))
        .await
        .map(Json)
}

/// Lets a lorebook of the library go from the chat. Answers with the chat's lorebooks.
async fn remove_lorebook(
    State(state): State<AppState>,
    User(user): User,
    Path((id, lorebook_id)): Path<(i64, i64)>,
) -> ApiResult<Json<Vec<ChatLorebook>>> {
    state
        .run(move |db| chats::remove_lorebook(db, user, id, lorebook_id))
        .await
        .map(Json)
}

/// Switches to another swipe or branch, or goes back to an earlier message. Not
/// while a reply is being generated in the chat.
async fn move_head(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<MoveHead>,
) -> ApiResult<Json<ChatView>> {
    viewed(&state, user, move |db| {
        let show = if to.follow.unwrap_or(false) {
            chats::show_branch
        } else {
            chats::set_head
        };
        show(db, user, id, to.message_id)?;
        Ok(id)
    })
    .await
    .map(Json)
}

/// Adds a message after the chat's head. Not while a reply is being generated
/// there.
async fn send(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<SendMessage>,
) -> ApiResult<(StatusCode, Json<MessageView>)> {
    let message = state
        .run(move |db| {
            let attached = new.attachments.unwrap_or_default();
            attachments::ensure_waiting(db, user, id, &attached)?;
            let message = NewMessage {
                role: new.role.unwrap_or(Role::User),
                speaker_id: new.speaker_id,
                content: &new.content,
                complete: true,
            };
            let message = chats::append(db, user, id, &message)?;
            attachments::take(db, id, message, &attached)?;
            chats::view(db, user, message)
        })
        .await?;
    state.tell(user, &page, &PageEvent::Messages { chat_id: id });
    Ok((StatusCode::CREATED, Json(message)))
}

async fn edit(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(text): Json<MessageText>,
) -> ApiResult<Json<MessageView>> {
    state
        .run(move |db| {
            chats::set_content(db, user, id, &text.content)?;
            chats::view(db, user, id)
        })
        .await
        .map(Json)
}

/// Deletes a message in view with its versions and what follows them; see
/// [`chats::delete_message`]. Answers with the chat.
async fn delete_message(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<ChatView>> {
    messages_changed(state, user, page, id, |db, user, id| {
        chats::delete_message(db, user, id)
    })
    .await
}

/// Deletes only the version shown of a message in view, with what follows it;
/// see [`chats::delete_version`]. Answers with the chat.
async fn delete_version(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<ChatView>> {
    messages_changed(state, user, page, id, |db, user, id| {
        chats::delete_version(db, user, id)
    })
    .await
}

/// Puts back the deletion that took the message `id`; see
/// [`chats::restore_messages`]. Answers with the chat.
async fn restore_messages(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<ChatView>> {
    messages_changed(state, user, page, id, |db, user, id| {
        chats::restore_messages(db, user, id)
    })
    .await
}

/// Changes the messages of a chat by `change` of the message `id`, which
/// answers the chat's id; tells the user's other pages and answers with the chat.
async fn messages_changed(
    state: AppState,
    user: i64,
    page: Page,
    id: i64,
    change: fn(&Db, i64, i64) -> anyhow::Result<i64>,
) -> ApiResult<Json<ChatView>> {
    let shown = viewed(&state, user, move |db| change(db, user, id)).await?;
    let chat_id = shown.chat.id;
    state.tell(user, &page, &PageEvent::Messages { chat_id });
    Ok(Json(shown))
}

/// Adds another version of the message `id` beside it and brings it into view.
async fn add_swipe(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(text): Json<MessageText>,
) -> ApiResult<(StatusCode, Json<MessageView>)> {
    let message = state
        .run(move |db| {
            chats::view(
                db,
                user,
                chats::add_swipe(db, user, id, &text.content, true)?,
            )
        })
        .await?;
    Ok((StatusCode::CREATED, Json(message)))
}

/// Sets who replies next in the chat, from the next reply on; see
/// [`turn::set`]. Answers with the chat.
async fn set_turn(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<turn::Turn>,
) -> ApiResult<Json<Chat>> {
    changed(&state, (user, id), move |db| turn::set(db, user, id, to)).await
}

/// Adds a character of a card of the library to the chat; see
/// [`chats::add_character`]. Answers with the chat, of which it is the last character.
async fn add_character(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(new): Json<AddCharacter>,
) -> ApiResult<(StatusCode, Json<ChatView>)> {
    let chat = viewed(&state, user, move |db| {
        chats::add_character(db, user, id, new.card_id, &new.character)?;
        Ok(id)
    })
    .await?;
    Ok((StatusCode::CREATED, Json(chat)))
}

/// Takes a chat character that has written nothing out of its chat again; see
/// [`chats::remove_character`]. Answers with the chat.
async fn remove_character(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<ChatView>> {
    viewed(&state, user, move |db| {
        chats::remove_character(db, user, id)
    })
    .await
    .map(Json)
}

/// Moves a chat character to another place in its chat's speaking order; see
/// [`turn::reorder`]. Answers with the chat.
async fn move_character(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<MoveCharacter>,
) -> ApiResult<Json<ChatView>> {
    viewed(&state, user, move |db| {
        turn::reorder(db, user, id, to.position as usize)
    })
    .await
    .map(Json)
}

/// Has a chat name itself, once it is still to be named and has the reply
/// `chats::title` waits for, and tells its pages. Nothing
/// that fails here matters: the next reply asks again.
pub(super) fn name_itself(state: &AppState, user: i64, chat_id: i64) {
    let state = state.clone();
    let Ok(Some(titling)) = state.unless_restoring(|| state.titles.start(user, chat_id)) else {
        return;
    };
    tokio::spawn(async move {
        let _titling = titling;
        let asked = state
            .work(move |db| {
                let Some(said) = chats::title::unnamed(db, user, chat_id)? else {
                    return Ok(None);
                };
                Ok(provider::for_work(db, user)?.map(|provider| (said, provider)))
            })
            .await;
        let (said, provider) = match asked {
            Ok(Some(asked)) => asked,
            Ok(None) => return,
            Err(failure) => {
                tracing::error!("chat {chat_id} cannot be read for its title: {failure:#}");
                return;
            }
        };
        let title = match chats::title::ask(&state.http, &provider, &said).await {
            Ok(Some(title)) => title,
            Ok(None) => return,
            Err(failure) => {
                tracing::warn!("chat {chat_id} could not be named: {failure:#}");
                return;
            }
        };
        let kept = title.clone();
        match state
            .work(move |db| chats::title::keep(db, user, chat_id, &kept))
            .await
        {
            Ok(true) => state.push(user, &PageEvent::ChatTitle { chat_id, title }),
            Ok(false) => {}
            Err(failure) => tracing::error!("chat {chat_id}'s title cannot be kept: {failure:#}"),
        }
    });
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/chats.rs"));

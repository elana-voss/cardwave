//! Chat storage: a chat itself (`create`, `find`, its settings) and its lore.
//! Every chat is a group chat of one user; the usual one has one character,
//! with its card's one version (`chat_characters.version_id`), which an edit
//! of the card moves it to (`cards::retire`), in the language the AI writes
//! in where the card has it (`Document::in_language`). Its characters are in
//! `characters`, its messages and their tree in `messages`, what a reply's
//! prompt is built from in `inputs`; who replies next is `turn`.
//!
//! A chat is named by its character that joined first (lowest ID).
//! `cw_store::lorebooks::HAD` says which lore a chat has.
//!
//! A chat without a character (`create` with none) is the AI itself: no
//! persona, its replies without a speaker, a prompt of the chat alone; it keeps
//! an empty title, which the page words, until it names itself.

use std::borrow::Borrow;
use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};

use anyhow::ensure;
use cw_ccv4::{Document, display, mapping};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::cards::{self, Show, name_order};
use cw_library::lorebooks;
use cw_library::personas::{self, Persona};
use cw_library::settings;
use cw_library::trash;
use cw_prompt::Variables;
use cw_prompt::macros::{self, MacroContext};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::prompt_presets::ChatPromptPreset;

pub mod again;
pub mod characters;
pub mod export;
pub mod inputs;
pub mod messages;
pub mod reply;
pub mod title;
pub mod turn;

pub use characters::*;
pub use export::export;
pub use inputs::*;
pub use messages::*;
pub use turn::TurnOrder;

pub struct NewChat<'a> {
    /// The characters as (card version, character ID in that card), in speaking
    /// order; none for a chat without a character.
    pub characters: &'a [(i64, &'a str)],
    pub persona_id: Option<i64>,
    /// Which of the first character's greetings opens the chat. All of them are
    /// stored as swipes of the first message.
    pub greeting: usize,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Chat {
    pub id: i64,
    pub title: String,
    pub persona_id: Option<i64>,
    /// The newest message of the branch in view.
    pub head_id: Option<i64>,
    pub favorite: bool,
    /// Hidden from the list but still found by search.
    pub archived: bool,
    /// In the trash, from where it can be restored.
    pub trashed: bool,
    /// When it is deleted for good, while it is in the trash.
    pub deleted_at: Option<i64>,
    pub created_at: i64,
    /// When a message was last added.
    pub updated_at: i64,
    /// How the chat picks who of several characters replies next.
    pub turn_order: TurnOrder,
    /// The chat character picked by hand, who replies in the order's place.
    pub replier_id: Option<i64>,
    /// The prompt preset it goes by (`prompt_presets`).
    pub prompt_preset: ChatPromptPreset,
    /// The mode the user set it to; none where it picks by itself (`assistant`).
    pub mode: Option<String>,
    /// The mode it picked last by itself.
    pub auto_mode: Option<String>,
    /// The most tokens of a reply, its thinking not counted (`set_reply`).
    pub reply_length: u32,
    /// Code mode: the model may write itself tools in this chat (`make_tool`);
    /// those kept are offered in every chat.
    pub code_mode: bool,
    /// Seconds the characters of a chat of several wait after a reply of
    /// theirs before the next, while they keep replying by themselves (`set_talk`).
    pub talk_pause: u32,
    /// How many replies they write by themselves in a row before they stop.
    pub talk_replies: u32,
}

/// How the characters of a chat of several keep replying by themselves: the
/// side panel's two numbers (`set_talk`). The page runs it; the server keeps them.
#[derive(Clone, Debug, Deserialize, TS)]
#[ts(export)]
pub struct ChatTalk {
    pub talk_pause: u32,
    pub talk_replies: u32,
}

/// The longest pause between the characters' own replies, in seconds (Claude).
pub(crate) const MOST_TALK_PAUSE: u32 = 600;
/// The most replies they write by themselves in a row (Claude).
pub(crate) const MOST_TALK_REPLIES: u32 = 100;

/// How the chat's replies are written: the side panel's box (`set_reply`).
#[derive(Clone, Debug, Deserialize, TS)]
#[ts(export)]
pub struct ChatReply {
    pub reply_length: u32,
    pub code_mode: bool,
}

/// The longest reply a chat may ask for, in tokens (Claude).
pub(crate) const MOST_REPLY_LENGTH: u32 = 100_000;

/// A card a chat has characters of.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ChatCard {
    pub id: i64,
    /// The card's title in the library.
    pub title: String,
    /// The version of it the chat is with: that of the first of its characters.
    pub version_id: i64,
}

/// A chat as the list of chats shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ChatSummary {
    #[serde(flatten)]
    #[ts(flatten)]
    pub chat: Chat,
    /// What its characters are called in it, in the order they joined it,
    /// so the first is the one the chat is called after; see [`turn::reorder`].
    pub names: Vec<String>,
    /// The cards its characters are from, each once, in the characters' order.
    pub cards: Vec<ChatCard>,
    /// The start of the newest message of the branch in view, as plain text.
    pub excerpt: String,
}

/// The order the list of chats shows them in.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum ChatSort {
    /// The chat written in last comes first.
    #[default]
    LastWritten,
    /// By title; of chats called the same, the one written in last comes first.
    Name,
    /// The chat started last comes first.
    Started,
}

/// What the list of chats asks for; see [`find`].
#[derive(Clone, Copy, Debug, Default)]
pub struct Find<'a> {
    /// Words that must all be in the chat's title, its characters' names or its cards' titles.
    pub query: &'a str,
    pub show: Show,
    pub sort: ChatSort,
}

/// Where a chat has lore from.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum LoreSource {
    /// A card of the chat's characters.
    CardId(i64),
    /// A lorebook of the library that the chat took along.
    LorebookId(i64),
}

/// One lorebook entry, as a chat shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Lore {
    #[serde(flatten)]
    #[ts(flatten)]
    pub source: LoreSource,
    /// The entry in its card or its lorebook, `lore.ID`.
    pub reference: String,
    pub name: String,
}

/// One lorebook of a chat: one its characters bring along, or one of the
/// library, which is attached to a card of its characters or which the chat
/// took along.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ChatLorebook {
    #[serde(flatten)]
    #[ts(flatten)]
    pub source: LoreSource,
    /// The lorebook in its card or its document, `lorebook.ID`.
    pub reference: String,
    pub name: String,
    /// False while the chat leaves it out of its prompts.
    pub on: bool,
    /// Its entries, as its card or its document names them, `lore.ID`: what
    /// the chat can leave out of it.
    pub entries: Vec<String>,
    /// Its entries that the chat leaves out by themselves.
    pub removed: Vec<Lore>,
    /// A lorebook of the library that is in the Trash: the chat has it until
    /// it is deleted for good.
    pub trashed: bool,
    /// The chat took it along itself, and can let it go. One it has through
    /// its characters or their cards alone comes and goes with them.
    pub taken: bool,
    /// A lorebook of the library for every chat: it is taken off in its own
    /// settings, not in the chat.
    pub everywhere: bool,
    /// One of the chat's persona: it is taken off in the persona.
    pub persona: bool,
}

/// A reply is being generated in the chat, which takes nothing else until the
/// reply has ended. The API answers it with 409.
pub const BUSY: Fail = Fail::new(Code::ChatBusy);

/// What a chat in the Trash answers to a change: it is only read.
pub const IN_TRASH: &str = "the chat is in the Trash; restore it first";

/// What a chat answers that is to be with a card in the Trash: a chat is
/// there while one of its cards is.
pub const CARD_IN_TRASH: &str = "the card is in the Trash; restore it to chat with it";

/// What a chat answers that is given a chat character it has not.
pub const NOT_IN_CHAT: &str = "the speaker is not part of this chat";

/// Refuses a chat in which a reply is being generated.
pub fn ensure_idle(db: &dyn Storage, chat_id: i64) -> anyhow::Result<()> {
    ensure!(!db.writing(chat_id)?, BUSY);
    Ok(())
}

/// Starts a chat. The first character's greetings become the first message
/// and its swipes; a chat with several characters prefers the group greetings.
/// A greeting's macros are resolved here, once, as the Flutter app does: the
/// message is what the user reads. Variables a greeting sets are kept on it and
/// reach the replies on its branch. A character named twice, of one version of
/// its card or of two, starts no chat, nor does a card in the Trash. Without
/// characters the chat is the AI itself: no persona, no message and no title.
pub fn create(db: &dyn Storage, user: i64, new: &NewChat<'_>) -> anyhow::Result<i64> {
    if new.characters.is_empty() {
        return db.start_plain_chat(user);
    }
    let user_name = match new.persona_id {
        Some(id) => personas::usable(db, user, id)?.name,
        None => settings::user_stand_in(db, user)?.to_string(),
    };
    let mut title = String::new();
    let mut greetings = Vec::new();
    // The greetings are the card's in the language the AI writes in, where it has it.
    let language = settings::get(db, user)?.language;
    let mut names = Vec::new();
    for (index, &(version_id, character)) in new.characters.iter().enumerate() {
        let document = cards::document(db, user, version_id)?;
        ensure!(
            document.character(character).is_some(),
            Fail::said(
                Code::NotPossible,
                format!("the card has no character {character:?}")
            )
            .with("what", "card_character")
        );
        names.push(listed_name(&document, character));
        if index == 0 {
            title = document.character_label(character);
            let shown = document.in_language(character, &language);
            let char_name = document.character_name(shown);
            for greeting in &document.greetings(shown, new.characters.len() > 1) {
                let (text, variables) = greeted(greeting, &char_name, &user_name);
                let state = (!variables.is_empty())
                    .then(|| Snapshot {
                        opening: variables.clone(),
                        variables,
                        ..Default::default()
                    })
                    .map(|snapshot| serde_json::to_string(&snapshot))
                    .transpose()?;
                greetings.push((text, state));
            }
        }
    }
    db.start_chat(
        user,
        &Opening {
            title: &title,
            new,
            names: &names,
            greetings: &greetings,
        },
    )?
}

/// A greeting as the user reads it, its macros resolved once, with the
/// variables they set.
pub(crate) fn greeted(greeting: &str, char_name: &str, user_name: &str) -> (String, Variables) {
    let mut variables = Variables::new();
    let mut context = MacroContext {
        char_name,
        user_name,
        local: Some(&mut variables),
        global: None,
        tracking_id: None,
    };
    let text = macros::render(greeting, &mut context);
    (text, variables)
}

/// What a chat starts with (`create`): its title, characters, their names in
/// the list, and the first character's greetings, each with the state its
/// macros left, of which `new.greeting` is in view.
pub struct Opening<'a> {
    pub title: &'a str,
    pub new: &'a NewChat<'a>,
    pub names: &'a [String],
    pub greetings: &'a [(String, Option<String>)],
}

/// What the chats need of the database, which `cw_store::chats` gives, with what
/// every chat module stores and the library and providers they read: what a
/// function across modules takes.
pub trait Storage:
    crate::chats::characters::Storage
    + crate::chats::export::Storage
    + crate::chats::inputs::Storage
    + crate::chats::messages::Storage
    + crate::chats::title::Storage
    + crate::chats::turn::Storage
    + crate::attachments::Storage
    + crate::documents::Storage
    + crate::prompt_presets::Storage
    + crate::memory::Storage
    + crate::assistant::Storage
    + crate::images::Storage
    + crate::figures::Storage
    + cards::Storage
    + lorebooks::Storage
    + personas::Storage
    + settings::Storage
    + trash::Storage
    + cw_provider::Storage
    + cw_provider::kinds::Storage
{
    fn chat(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<Chat>>;
    /// Whether a reply is being generated in the chat: it has a message that is not complete.
    fn writing(&self, chat_id: i64) -> anyhow::Result<bool>;
    /// A chat without a character: no persona, no message and no title.
    fn start_plain_chat(&self, user: i64) -> anyhow::Result<i64>;
    /// A chat as `opening` has it; refused (the inner error) with a card in
    /// the Trash or a character twice.
    fn start_chat(&self, user: i64, opening: &Opening<'_>) -> anyhow::Result<anyhow::Result<i64>>;
    /// The chats the list shows as `show` has them, with their characters'
    /// names and cards, and the start of their newest message as written.
    fn chat_summaries(
        &self,
        user: i64,
        show: Show,
        searching: bool,
    ) -> anyhow::Result<Vec<ChatSummary>>;
    /// The chat characters without a name: ID, card version, character.
    fn unnamed_characters(&self) -> anyhow::Result<Vec<(i64, i64, String)>>;
    fn name_characters(&self, named: &[(i64, String)]) -> anyhow::Result<()>;
    fn set_chat_favorite(&self, user: i64, chat_id: i64, on: bool) -> anyhow::Result<()>;
    fn set_chat_archived(&self, user: i64, chat_id: i64, on: bool) -> anyhow::Result<()>;
    fn set_chat_reply(&self, user: i64, chat_id: i64, reply: &ChatReply) -> anyhow::Result<()>;
    fn set_chat_talk(&self, user: i64, chat_id: i64, talk: &ChatTalk) -> anyhow::Result<()>;
    fn set_chat_persona(
        &self,
        user: i64,
        chat_id: i64,
        persona_id: Option<i64>,
    ) -> anyhow::Result<()>;
    /// What the chat leaves out of its lore: whether of the library's, the
    /// card's or lorebook's ID, the reference.
    fn lore_off(&self, chat_id: i64) -> anyhow::Result<Vec<(bool, i64, String)>>;
    /// Leaves out the lore `reference` of `source`, or takes it in again.
    fn set_lore_off(
        &self,
        chat_id: i64,
        source: LoreSource,
        reference: &str,
        on: bool,
    ) -> anyhow::Result<()>;
    /// Takes a lorebook of the library along; one taken already stays.
    fn take_lorebook(&self, chat_id: i64, lorebook_id: i64) -> anyhow::Result<()>;
    fn chats_of_card(&self, user: i64, card_id: i64) -> anyhow::Result<Vec<Chat>>;
    fn rename_chat(&self, user: i64, chat_id: i64, title: &str) -> anyhow::Result<()>;
    /// Gives the chat `to` the settings of `from` (`again::again`): `pairs`
    /// are each character of `from` with its place in `to`.
    fn copy_chat_settings(&self, from: i64, to: i64, pairs: &[(i64, i64)]) -> anyhow::Result<()>;
    fn allow_tool(
        &self,
        user: i64,
        chat_id: i64,
        kind: cw_coding::tools::AskKind,
    ) -> anyhow::Result<()>;
    fn tool_allowed(
        &self,
        user: i64,
        chat_id: i64,
        kind: cw_coding::tools::AskKind,
    ) -> anyhow::Result<bool>;
}

pub fn get(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<Option<Chat>> {
    db.chat(user, chat_id)
}

/// Who the user is in the chat: its persona, one in the Trash too. Without
/// one the user is the stand-in name (`settings::user_stand_in`).
pub fn persona_of(db: &dyn Storage, user: i64, chat: &Chat) -> anyhow::Result<Option<Persona>> {
    match chat.persona_id {
        Some(id) => personas::get(db, user, id),
        None => Ok(None),
    }
}

/// The chats of `user` the list of chats shows. Never those in the Trash.
/// Archived chats only when they are asked for, or in a search, where they
/// come after the others. A search finds the chats that have every word of the
/// query in their title, their characters' names or their cards' titles, in
/// any case, and looks at no message. No card is read for the list: what a
/// character is called is kept with it (see [`name_missing`]).
pub fn find(db: &dyn Storage, user: i64, find: &Find<'_>) -> anyhow::Result<Vec<ChatSummary>> {
    let query = find.query.to_lowercase();
    let words: Vec<&str> = query.split_whitespace().collect();
    let searching = !words.is_empty();
    let mut chats = db.chat_summaries(user, find.show, searching)?;
    // Compared here: the database knows upper and lower case from a to z only.
    chats.retain(|one| {
        let cards = one.cards.iter().map(|card| &card.title);
        let text: Vec<String> = [&one.chat.title]
            .into_iter()
            .chain(&one.names)
            .chain(cards)
            .map(|part| part.to_lowercase())
            .collect();
        let text = text.join("\n");
        words.iter().all(|word| text.contains(word))
    });
    for one in &mut chats {
        one.excerpt = display::excerpt(&one.excerpt);
    }
    let behind = |one: &ChatSummary| searching && one.chat.archived;
    match find.sort {
        ChatSort::LastWritten => chats.sort_by_key(|one| {
            (
                behind(one),
                Reverse(one.chat.updated_at),
                Reverse(one.chat.id),
            )
        }),
        ChatSort::Name => chats.sort_by_cached_key(|one| {
            (
                behind(one),
                name_order(&one.chat.title),
                Reverse(one.chat.updated_at),
                Reverse(one.chat.id),
            )
        }),
        ChatSort::Started => chats.sort_by_key(|one| {
            (
                behind(one),
                Reverse(one.chat.created_at),
                Reverse(one.chat.id),
            )
        }),
    }
    Ok(chats)
}

/// What a character is called in the list of chats: its name in the chat,
/// as long as the library keeps a name. A card can give one of any length.
pub fn listed_name(document: &Document, character: &str) -> String {
    cards::short(document.character_name(character))
}

/// Gives every chat character that has none its name: what its card's
/// version calls it, which a chat started by an older build did not keep. Run
/// when the server starts. A character of a card that cannot be read goes by
/// its ID, and is not tried again at the next start.
pub fn name_missing(db: &dyn Storage) -> anyhow::Result<()> {
    let unnamed = db.unnamed_characters()?;
    // Characters out of one card version share it, which is read once.
    let mut documents: HashMap<i64, Option<Document>> = HashMap::new();
    let mut named = Vec::with_capacity(unnamed.len());
    for (id, version_id, character) in unnamed {
        let document = documents.entry(version_id).or_insert_with(|| {
            cards::document_of(db, version_id)
                .inspect_err(|error| {
                    tracing::warn!(
                        "card version {version_id} cannot be read for its names: {error:#}"
                    )
                })
                .ok()
        });
        let name = document.as_ref().map_or_else(
            || character.clone(),
            |document| listed_name(document, &character),
        );
        named.push((id, name));
    }
    // Written at once: the server's start waits for one write, however many chats there are.
    db.name_characters(&named)
}

/// The chats of `user` with characters of one card, the one written in last
/// first. Without the archived and trashed ones.
pub fn of_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<Vec<Chat>> {
    db.chats_of_card(user, card_id)
}

pub fn set_favorite(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    favorite: bool,
) -> anyhow::Result<()> {
    db.set_chat_favorite(user, chat_id, favorite)
}

pub fn set_archived(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    archived: bool,
) -> anyhow::Result<()> {
    db.set_chat_archived(user, chat_id, archived)
}

/// Moves the chat to the trash or takes it back out; see [`trash`].
pub fn set_trashed(db: &dyn Storage, user: i64, chat_id: i64, trashed: bool) -> anyhow::Result<()> {
    if trashed {
        trash::put_chat(db, user, chat_id)
    } else {
        trash::restore_chat(db, user, chat_id)
    }
}

/// Sets who the user is in the chat, from the next reply on. Not in a chat
/// that is in the Trash, and not a persona that is there.
pub fn set_persona(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    persona_id: Option<i64>,
) -> anyhow::Result<()> {
    ensure_kept(db, user, chat_id)?;
    if let Some(persona_id) = persona_id {
        personas::usable(db, user, persona_id)?;
    }
    db.set_chat_persona(user, chat_id, persona_id)
}

/// Sets how the chat's replies are written, from the next reply on. Not in a
/// chat that is in the Trash.
pub fn set_reply(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    reply: &ChatReply,
) -> anyhow::Result<()> {
    ensure!(
        (1..=MOST_REPLY_LENGTH).contains(&reply.reply_length),
        Fail::said(
            Code::OutOfRange,
            format!("the reply length must be from 1 to {MOST_REPLY_LENGTH} tokens")
        )
        .with("what", "reply_length")
        .with("most_reply_length", MOST_REPLY_LENGTH)
    );
    ensure_kept(db, user, chat_id)?;
    db.set_chat_reply(user, chat_id, reply)
}

/// The longest title a chat is given, in characters (Claude).
const TITLE_LIMIT: usize = 100;

/// Gives the chat the title `title` ("Rename"), trimmed. Not in the Trash.
pub fn rename(db: &dyn Storage, user: i64, chat_id: i64, title: &str) -> anyhow::Result<()> {
    let title = title.trim();
    ensure!(
        !title.is_empty(),
        Fail::said(Code::Needed, "a chat's title has words").with("what", "chat_title")
    );
    ensure!(
        title.chars().count() <= TITLE_LIMIT,
        Fail::said(
            Code::TooLong,
            format!("a chat's title has at most {TITLE_LIMIT} characters")
        )
        .with("what", "chat_title")
        .with("title_limit", TITLE_LIMIT)
    );
    ensure_kept(db, user, chat_id)?;
    db.rename_chat(user, chat_id, title)
}

/// Sets the pause between the characters' own replies and how many they write
/// in a row, from their next replying by themselves on. Not in a chat in the Trash.
pub fn set_talk(db: &dyn Storage, user: i64, chat_id: i64, talk: &ChatTalk) -> anyhow::Result<()> {
    ensure!(
        talk.talk_pause <= MOST_TALK_PAUSE,
        Fail::said(
            Code::OutOfRange,
            format!("the pause must be from 0 to {MOST_TALK_PAUSE} seconds")
        )
        .with("what", "talk_pause")
        .with("most_talk_pause", MOST_TALK_PAUSE)
    );
    ensure!(
        (1..=MOST_TALK_REPLIES).contains(&talk.talk_replies),
        Fail::said(
            Code::OutOfRange,
            format!("the replies in a row must be from 1 to {MOST_TALK_REPLIES}")
        )
        .with("what", "talk_replies")
        .with("most_talk_replies", MOST_TALK_REPLIES)
    );
    ensure_kept(db, user, chat_id)?;
    db.set_chat_talk(user, chat_id, talk)
}

/// Refuses a chat that is not there or is in the Trash.
pub fn ensure_kept(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<()> {
    ensure!(
        !get(db, user, chat_id)?.ok_or(NotFound("chat"))?.trashed,
        Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
    );
    Ok(())
}

/// The chat's characters, each as the card it is from, that card's document
/// in the version the chat is pinned to, and the character's ID in it.
fn sources(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Vec<(i64, Document, String)>> {
    get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    let language = settings::get(db, user)?.language;
    let mut sources = Vec::new();
    for participant in participants(db, user, chat_id)? {
        let card_id =
            cards::card_of(db, user, participant.version_id)?.ok_or(NotFound("card version"))?;
        let document = cards::document_of(db, participant.version_id)?;
        let character = document
            .in_language(&participant.character, &language)
            .to_string();
        sources.push((card_id, document, character));
    }
    Ok(sources)
}

/// A lorebook with all its entries.
struct Book {
    lorebook: Lore,
    entries: Vec<Lore>,
    /// See [`ChatLorebook::trashed`], [`ChatLorebook::taken`],
    /// [`ChatLorebook::everywhere`] and [`ChatLorebook::persona`].
    trashed: bool,
    taken: bool,
    everywhere: bool,
    persona: bool,
}

/// What a chat leaves out of its lore, as references by where the lore is from.
type Off = HashMap<LoreSource, HashSet<String>>;

/// The lorebooks that reach the prompts of `characters`, each once, in the
/// characters' order. A character is given as the card it is from, that card's
/// document and its ID in it, owned (as [`sources`] reads them) or borrowed.
fn books(characters: &[(i64, impl Borrow<Document>, impl AsRef<str>)]) -> Vec<Book> {
    let mut books: Vec<Book> = Vec::new();
    // Per lorebook, the entries it has so far. Characters of one card may be pinned
    // to different versions of it: what either version lists is an entry, once.
    let mut seen: Vec<HashSet<&str>> = Vec::new();
    for (card_id, document, character) in characters {
        let (card_id, document): (i64, &Document) = (*card_id, document.borrow());
        let source = LoreSource::CardId(card_id);
        let lore = |reference: &str| Lore {
            source,
            reference: reference.to_string(),
            name: mapping::lore_name(document, reference),
        };
        for reference in mapping::lorebooks(document, character.as_ref()) {
            let known = books.iter().position(|book| {
                book.lorebook.source == source && book.lorebook.reference == reference
            });
            let at = match known {
                Some(at) => at,
                None => {
                    books.push(Book {
                        lorebook: lore(reference),
                        entries: Vec::new(),
                        trashed: false,
                        taken: false,
                        everywhere: false,
                        persona: false,
                    });
                    seen.push(HashSet::new());
                    books.len() - 1
                }
            };
            for entry in mapping::entries(document, reference) {
                if seen[at].insert(entry) {
                    books[at].entries.push(lore(entry));
                }
            }
        }
    }
    books
}

/// The lorebooks of a chat with `characters`: those the characters bring (see
/// [`books`]), then those of the library that the chat has (see
/// [`lorebooks::of_chat`]).
fn books_of(
    db: &dyn Storage,
    chat_id: i64,
    characters: &[(i64, impl Borrow<Document>, impl AsRef<str>)],
) -> anyhow::Result<Vec<Book>> {
    let mut books = books(characters);
    for taken in lorebooks::of_chat(db, chat_id)? {
        let source = LoreSource::LorebookId(taken.id);
        let entries = mapping::entries(&taken.document, &taken.reference)
            .into_iter()
            .map(|entry| Lore {
                source,
                reference: entry.to_string(),
                name: mapping::lore_name(&taken.document, entry),
            })
            .collect();
        let lorebook = Lore {
            source,
            reference: taken.reference,
            name: taken.name,
        };
        books.push(Book {
            lorebook,
            entries,
            trashed: taken.trashed,
            taken: taken.by_chat,
            everywhere: taken.everywhere,
            persona: taken.persona,
        });
    }
    Ok(books)
}

/// What the chat leaves out of its lore: of its cards' and of the lorebooks it
/// took from the library.
fn lore_off(db: &dyn Storage, chat_id: i64) -> anyhow::Result<Off> {
    let rows = db.lore_off(chat_id)?;
    let mut off = Off::new();
    for (of_library, id, reference) in rows {
        let source = if of_library {
            LoreSource::LorebookId(id)
        } else {
            LoreSource::CardId(id)
        };
        off.entry(source).or_default().insert(reference);
    }
    Ok(off)
}

/// The lorebooks of a chat, with what the chat leaves out: those its
/// characters bring, then those of the library that are attached to their
/// cards, then those it took from the library itself.
pub fn lorebooks(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<Vec<ChatLorebook>> {
    lorebooks_of(db, chat_id, &sources(db, user, chat_id)?)
}

/// [`lorebooks`] for a caller that has read the chat's characters already:
/// each as its card, that card's document and the character's ID in it.
pub fn lorebooks_of(
    db: &dyn Storage,
    chat_id: i64,
    characters: &[(i64, impl Borrow<Document>, impl AsRef<str>)],
) -> anyhow::Result<Vec<ChatLorebook>> {
    Ok(shown(
        books_of(db, chat_id, characters)?,
        &lore_off(db, chat_id)?,
    ))
}

/// `books` as a chat shows them, which leaves `off` out.
fn shown(books: Vec<Book>, off: &Off) -> Vec<ChatLorebook> {
    let is_off = |lore: &Lore| {
        off.get(&lore.source)
            .is_some_and(|off| off.contains(&lore.reference))
    };
    books
        .into_iter()
        .map(
            |Book {
                 lorebook,
                 entries,
                 trashed,
                 taken,
                 everywhere,
                 persona,
             }| ChatLorebook {
                on: !is_off(&lorebook),
                entries: entries
                    .iter()
                    .map(|entry| entry.reference.clone())
                    .collect(),
                removed: entries.into_iter().filter(is_off).collect(),
                source: lorebook.source,
                reference: lorebook.reference,
                name: lorebook.name,
                trashed,
                taken,
                everywhere,
                persona,
            },
        )
        .collect()
}

/// Leaves a lorebook or one of its entries out of the chat's prompts, or
/// takes it back in, from the next reply on. `reference` names it in the card
/// or the library's lorebook `source`; it has to be a lorebook of the chat or
/// an entry of one. Not in a chat that is in the Trash. Answers with the
/// chat's lorebooks as they then are.
pub fn set_lore(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    source: LoreSource,
    reference: &str,
    on: bool,
) -> anyhow::Result<Vec<ChatLorebook>> {
    ensure_kept(db, user, chat_id)?;
    let books = books_of(db, chat_id, &sources(db, user, chat_id)?)?;
    let known = books.iter().any(|book| {
        std::iter::once(&book.lorebook)
            .chain(&book.entries)
            .any(|lore| lore.source == source && lore.reference == reference)
    });
    ensure!(
        known,
        Fail::said(
            Code::NotPossible,
            "the chat has no such lorebook or lorebook entry"
        )
        .with("what", "chat_lore")
    );
    db.set_lore_off(chat_id, source, reference, on)?;
    Ok(shown(books, &lore_off(db, chat_id)?))
}

/// Takes a lorebook of the library along in the chat: its entries reach the
/// chat's prompts from the next reply on. Not in a chat that is in the Trash,
/// and not a lorebook that is there. One the chat has already stays as it is.
/// Answers with the chat's lorebooks as they then are.
pub fn add_lorebook(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    lorebook_id: i64,
) -> anyhow::Result<Vec<ChatLorebook>> {
    ensure_kept(db, user, chat_id)?;
    lorebooks::ensure_usable(db, user, lorebook_id)?;
    db.take_lorebook(chat_id, lorebook_id)?;
    lorebooks(db, user, chat_id)
}

/// Lets a lorebook of the library that the chat took along go from the chat,
/// from the next reply on, and forgets what the chat had left out of it. One
/// that is attached to a card of the chat's characters as well stays in the
/// chat as it is. The lorebook stays in the library. Not in a chat that is in
/// the Trash.
pub fn remove_lorebook(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    lorebook_id: i64,
) -> anyhow::Result<Vec<ChatLorebook>> {
    ensure_kept(db, user, chat_id)?;
    let gone = lorebooks::Storage::drop_chat_lorebook(db, chat_id, lorebook_id)?;
    ensure!(
        gone,
        Fail::said(Code::NotPossible, "the chat has no such lorebook")
            .with("what", "chat_lorebook")
    );
    lorebooks(db, user, chat_id)
}

/// Lets the chat's tools do what `kind` asks about without asking again, as
/// "Allow … for this chat" says.
pub fn allow_tool(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    kind: cw_coding::tools::AskKind,
) -> anyhow::Result<()> {
    db.allow_tool(user, chat_id, kind)
}

/// Whether the chat lets its tools do what `kind` asks about without asking.
pub fn tool_allowed(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    kind: cw_coding::tools::AskKind,
) -> anyhow::Result<bool> {
    db.tool_allowed(user, chat_id, kind)
}

/// What coding asks of the chats (`ports::ChatSide`), on the storage `.0`.
pub struct Side<'a>(pub &'a (dyn Storage + Sync));

impl cw_coding::ports::ChatSide for Side<'_> {
    fn post(&self, user: i64, chat_id: i64, content: &str) -> anyhow::Result<i64> {
        let new = NewMessage {
            role: cw_prompt::Role::Assistant,
            speaker_id: None,
            content,
            complete: true,
        };
        append(self.0, user, chat_id, &new)
    }

    fn picture<'a>(
        &'a self,
        http: &'a cw_platform::http::Client,
        whom: &'a cw_provider::images::Whom,
        words: &'a str,
    ) -> futures_util::future::BoxFuture<'a, anyhow::Result<cw_provider::images::Picture>> {
        Box::pin(crate::images::make(http, whom, words))
    }
}

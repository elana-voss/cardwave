//! Replies from the model, streamed into a new message and pushed over the
//! event socket; one at a time per chat, and it can be stopped. A reply begins
//! with `pick_mode`, `claim` (its message, or the one continued), then
//! `memory::recall` and `build` (the tools, then the prompt of `chats::reply`
//! with their notes, none where the model's server refused tools: `toolless`;
//! the companion's character is told its figure's bubble lately, `Building::bubble`);
//! `turn::next` picks the speaker where none is named. The rounds, the tools
//! run between them, are in `rounds`, each round's words saved and pushed in
//! `stream`; a round is limited to the Reply length where the model does not
//! think (`Provider::limited`) and no tool but a chat tool is offered. A call to
//! allow first waits in `AppState::asks`, answered by `answer`. Its end is kept
//! in `writer::finish`: ended with words, memory reads the turn and a chat
//! without a character names itself. The reply keeps whom it was asked
//! of (`set_model`) and how long it took (`chats::Times`). `draft` (`POST
//! /api/chats/{id}/draft`) is no message: the text alone for the message field.
//! A draft written for the user and a continued reply take a `direction`, the
//! field's words, which steer them and are sent as no message.

use std::collections::HashMap;
use std::time::Duration;

use anyhow::ensure;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::post;
use axum::{Extension, Json, Router};
use cw_chat::assistant;
use cw_chat::chats::reply;
use cw_chat::chats::{self, Chat, Message, MessageView, NewMessage, turn};
use cw_chat::images;
use cw_coding::tools::{ToolAsk, Toolbox};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_library::settings;
use cw_prompt::{PromptMessage, Role};
use cw_provider::kinds::{self, Kind};
use cw_provider::{self as provider, Provider};
use cw_store::Db;
use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;
use tokio::time::Instant;
use ts_rs::TS;

use super::events::EndTo;
use super::{Api, ApiResult, Caller, ReplyEvent, User, memory};
use crate::AppState;
use stream::Pushed;
use writer::{Read, Writer};

mod rounds;
mod stream;
mod writer;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/chats/{id}/generate", post(generate))
        .route("/api/chats/{id}/stop", post(stop))
        .route("/api/chats/{id}/draft", post(draft))
        .route("/api/chats/{id}/answer", post(answer))
}

/// The calls of tools the user is asked to allow, by user and chat.
pub(crate) type Asks = HashMap<(i64, i64), Asking>;

/// A call of a tool that waits for the user.
pub(crate) struct Asking {
    pub ask: ToolAsk,
    answer: oneshot::Sender<bool>,
}

/// The user's answer to a tool's call that waits: whether it may run, and
/// whether such calls run in this chat from now on without asking.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct Answer {
    pub allow: bool,
    pub(crate) for_chat: Option<bool>,
}

#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct Generate {
    /// The chat character who replies. When left out, the one the chat says:
    /// the one picked by hand, else whom its turn order picks ([`turn::next`]).
    pub speaker_id: Option<i64>,
    /// True writes the chat's newest message again, as another swipe of it,
    /// instead of a reply to it. That message must be a character's, and the
    /// same character writes it.
    pub(crate) regenerate: Option<bool>,
    /// True writes on at the chat's newest message, a character's reply with
    /// text, by the one who wrote it: the model goes on from its end, and what
    /// it writes is added to the message's text, which keeps what it had
    /// should nothing come. Not with `regenerate`.
    #[serde(rename = "continue")]
    pub(crate) go_on: Option<bool>,
    /// With `continue`: the words in the message field, which steer the
    /// continuation and are sent as no message.
    pub direction: Option<String>,
}

/// What the model writes for the user's message field.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct Draft {
    /// The user's message, to be bettered. When left out, the model writes the
    /// user's next message.
    pub improve: Option<String>,
    /// Without `improve`: the words in the message field, which steer what
    /// the model writes for the user.
    pub direction: Option<String>,
}

/// The text the model wrote for the message field.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct Drafted {
    pub content: String,
}

/// A reply about to be written.
struct Job {
    /// The still empty message the reply goes into.
    message_id: i64,
    /// The chat's head before that message was added.
    head_before: Option<i64>,
    provider: Provider,
    /// The prompt, taken out, as is `before`, when the reply is written.
    messages: Vec<PromptMessage>,
    /// Where in `messages` the tools' note stands (`assemble`).
    tools_at: Option<usize>,
    /// The model's server refused tools before: none is offered.
    toolless: bool,
    /// The text the message holds before the reply: a continued reply's, else none.
    before: String,
    /// Who writes it, who sends the pictures it makes.
    speaker_id: Option<i64>,
    /// The tools it is offered.
    toolbox: Option<Toolbox>,
    /// The names of the chat's other characters, whose lines it is cut before.
    others: Vec<String>,
}

/// Starts a reply in the chat and answers with its message, which is empty and
/// incomplete. The text follows as `reply_text` events and ends with `reply_ended`.
async fn generate(
    State(state): State<AppState>,
    Extension(api): Extension<Api>,
    caller: Caller,
    end_to: Option<Extension<EndTo>>,
    Path(chat_id): Path<i64>,
    Json(new): Json<Generate>,
) -> ApiResult<(StatusCode, Json<MessageView>)> {
    let user = caller.user;
    let waiter = end_to.and_then(|Extension(end_to)| end_to.take());
    // The reply's events wait until this request is answered or given up, so
    // that a page knows of the message before it hears how it went.
    let (_answered, answered) = oneshot::channel::<()>();
    // On a task of its own: a page that hangs up in the middle of the request
    // must not leave behind a message that nobody writes.
    let started = tokio::spawn(async move {
        let writer = Writer::list(&state, user, chat_id, waiter)?;
        // Another version of a reply, or more of it, answers what the reply before answered: in its mode.
        if new.regenerate != Some(true) && new.go_on != Some(true) {
            pick_mode(&state, user, chat_id).await;
        }
        let mut claimed = state.run(move |db| claim(db, user, chat_id, &new)).await?;
        let (speaker, last) = (claimed.reply.speaker_id, claimed.after);
        // The documents take a tenth of the chat model's context at most.
        let budget = claimed.provider.sampling.context() / 10;
        let recalled = memory::recall(
            &state,
            user,
            &claimed.chat,
            speaker,
            last,
            &claimed.inputs,
            budget,
        )
        .await;
        claimed.inputs.state.meaning = recalled.meaning;
        let building = Building {
            memory: recalled.memory,
            documents: recalled.documents,
            bubble: state.companion.bubble_note(user, claimed.inputs.card_id),
            owner: user == state.local_user(),
            toolless: state.toolless().contains(&(
                claimed.provider.base_url.clone(),
                claimed.provider.model.clone(),
            )),
            // Cardwave's own tools ask the API as this request's caller.
            api,
            caller,
        };
        let (job, message) = state.run(move |db| build(db, claimed, building)).await?;
        tokio::spawn(async move {
            // Its sender dropped (the request given up), the reply is written all the same.
            let _ = answered.await;
            write_reply(writer, job).await;
        });
        ApiResult::Ok(message)
    });
    Ok((StatusCode::ACCEPTED, Json(started.await??)))
}

/// How long a reply waits for the worker model to pick the chat's mode.
const PICK_LIMIT: Duration = Duration::from_secs(30);

/// Has the worker model pick the chat's mode, where the chat picks by itself
/// among two modes or more, and keeps it. Nothing that fails here holds the
/// reply back: the chat stays in the mode it was in.
async fn pick_mode(state: &AppState, user: i64, chat_id: i64) {
    let asked = state
        .work(move |db| {
            let chat = chats::get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
            let to_pick = assistant::to_pick(db, user, &chat)?;
            Ok(to_pick.zip(provider::for_work(db, user)?))
        })
        .await;
    let (to_pick, provider) = match asked {
        Ok(Some(asked)) => asked,
        Ok(None) => return,
        Err(failure) => {
            tracing::error!("chat {chat_id}'s mode cannot be read: {failure:#}");
            return;
        }
    };
    let picked = tokio::time::timeout(
        PICK_LIMIT,
        assistant::pick(&state.http, &provider, &to_pick),
    )
    .await;
    let mode = match picked.unwrap_or_else(|late| Err(late.into())) {
        Ok(Some(mode)) => mode,
        Ok(None) => return,
        Err(failure) => {
            tracing::warn!("chat {chat_id}'s mode could not be picked: {failure:#}");
            return;
        }
    };
    let kept = mode.clone();
    match state
        .work(move |db| assistant::keep_picked(db, user, chat_id, &kept))
        .await
    {
        Ok(true) => state.push(user, &PageEvent::ChatMode { chat_id, mode }),
        Ok(false) => {}
        Err(failure) => tracing::error!("chat {chat_id}'s mode cannot be kept: {failure:#}"),
    }
}

/// A reply's message, added to the chat, and what its prompt is built of.
struct Claimed {
    chat: Chat,
    provider: Provider,
    /// The message the reply goes into.
    reply: Message,
    /// The chat's head before that message was added.
    head_before: Option<i64>,
    /// The newest message the reply answers.
    after: Option<i64>,
    inputs: chats::PromptInputs,
    /// The reply is continued: its text so far.
    continued: Option<String>,
    /// What steers a continued reply ([`Generate::direction`]).
    direction: Option<String>,
}

/// Ends a claimed message that gets no reply. Should this fail too, a stop ends it.
fn let_go(db: &Db, user: i64, reply: &Message, head_before: Option<i64>, text: &str) {
    // Should this fail too, a stop ends it.
    let _ = chats::finish_reply(db, user, reply.id, text, head_before);
}

/// Adds the message the reply goes into, or claims the one continued, and
/// reads what its prompt is built of.
fn claim(db: &Db, user: i64, chat_id: i64, new: &Generate) -> anyhow::Result<Claimed> {
    let chat = chats::get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    let provider = provider::chat(db, user)?;
    ensure!(
        new.direction.is_none() || new.go_on == Some(true),
        Fail::new(Code::DirectionWithoutGoOn)
    );
    if new.go_on == Some(true) {
        ensure!(new.regenerate != Some(true), Fail::new(Code::AgainOrGoOn));
        // As below, claiming the message comes first.
        let reply = chats::reopen(db, user, chat_id)?;
        let head_before = Some(reply.id);
        let inputs = chats::prompt_inputs_after(db, user, &chat, reply.speaker_id, Some(reply.id))
            .inspect_err(|_| let_go(db, user, &reply, head_before, &reply.content))?;
        return Ok(Claimed {
            chat,
            provider,
            head_before,
            after: Some(reply.id),
            inputs,
            continued: Some(reply.content.clone()),
            direction: new.direction.clone(),
            reply,
        });
    }
    // The message comes first. Adding it is what claims the chat, and where it
    // lands says what the reply answers, whatever else was sent meanwhile.
    let again = match new.regenerate {
        Some(true) => {
            let head = chat.head_id.ok_or(Fail::new(Code::NoReplyToWriteAgain))?;
            let role = chats::view(db, user, head)?.message.role;
            ensure!(role == Role::Assistant, Fail::new(Code::AgainNotReply));
            Some(head)
        }
        _ => None,
    };
    let message_id = match again {
        Some(original) => chats::add_swipe(db, user, original, "", false)?,
        None => {
            // A chat without a character has none: the AI itself replies.
            let speaker_id = match new.speaker_id {
                Some(named) => Some(named),
                None => turn::next(db, user, &chat, rand::random())?,
            };
            let reply = NewMessage {
                role: Role::Assistant,
                speaker_id,
                content: "",
                complete: false,
            };
            chats::append(db, user, chat_id, &reply)?
        }
    };
    let reply = chats::view(db, user, message_id)?.message;
    let head_before = again.or(reply.parent_id);
    // Another version of a reply answers the chat as it was before that reply.
    let inputs = chats::prompt_inputs_after(db, user, &chat, reply.speaker_id, reply.parent_id)
        .inspect_err(|_| let_go(db, user, &reply, head_before, ""))?;
    Ok(Claimed {
        chat,
        provider,
        head_before,
        after: reply.parent_id,
        inputs,
        continued: None,
        direction: None,
        reply,
    })
}

/// What a claimed reply is built with besides its claim.
struct Building {
    /// What it is reminded of, and the pieces of documents it is given.
    memory: Option<String>,
    documents: Option<String>,
    /// What the companion's figure said in its bubble lately, where the
    /// speaker is the companion's character (`Live::bubble_note`).
    bubble: Option<String>,
    /// The user is this computer's account, whose tools may touch its files.
    owner: bool,
    /// The model's server refused tools before (`rounds`), looked up once per
    /// reply: no tool is told of, as none is offered.
    toolless: bool,
    /// The API Cardwave's own tools ask, and as whom.
    api: Api,
    caller: Caller,
}

/// Builds the prompt of a claimed reply as `building` says, and answers with
/// its job and its message, read again after the build, which notes on it what
/// it used.
fn build(db: &Db, claimed: Claimed, building: Building) -> anyhow::Result<(Job, MessageView)> {
    let Building {
        memory,
        documents,
        bubble,
        owner,
        toolless,
        api,
        caller,
    } = building;
    let user = caller.user;
    let Claimed {
        chat,
        provider,
        reply,
        head_before,
        mut inputs,
        continued,
        direction,
        ..
    } = claimed;
    let others = std::mem::take(&mut inputs.others);
    let (mode, card_id, character_id) = (
        inputs.mode.clone(),
        inputs.card_id,
        inputs.character_id.clone(),
    );
    let (length, code) = (chat.reply_length, chat.code_mode);
    let continuing = continued.is_some();
    let before = continued.unwrap_or_default();
    let made = (|| -> anyhow::Result<_> {
        let (personal, app) = speaker_tools(db, card_id, &character_id, mode.as_deref())?;
        let api = app.then_some((api, caller));
        let toolbox = toolbox(db, user, (owner, code), personal.as_deref(), api)?
            .map(|toolbox| toolbox.in_chat(chat.id));
        let notes = match &toolbox {
            Some(toolbox) if !toolless => toolbox.notes().join("\n\n"),
            _ => String::new(),
        };
        let given = reply::Given {
            memory: memory.as_deref(),
            documents: documents.as_deref(),
            tools: Some(notes.as_str()).filter(|notes| !notes.is_empty()),
            length,
            bubble: bubble.as_deref(),
        };
        let prompt = if continuing {
            reply::continue_prompt(&mut inputs, &provider.sampling, given, direction.as_deref())?
        } else {
            reply::prompt_for(db, user, &chat, &provider.sampling, &reply, inputs, given)?
        };
        let whose = kinds::whose(&provider.name, &provider.base_url);
        chats::set_model(db, user, reply.id, &provider.model, &whose)?;
        let message = chats::view(db, user, reply.id)?;
        Ok((prompt, message, toolbox))
    })();
    // Without a prompt there is no reply; a continued one keeps what it had.
    let (prompt, message, toolbox) =
        made.inspect_err(|_| let_go(db, user, &reply, head_before, &before))?;
    let provider = provider.limited(length);
    Ok((
        Job {
            message_id: reply.id,
            head_before,
            provider,
            messages: prompt.messages,
            tools_at: prompt.tools_at,
            toolless,
            before,
            speaker_id: reply.speaker_id,
            toolbox,
            others,
        },
        message,
    ))
}

/// How the tools go by who replies, the character `character` of the card
/// `card_id` (none in a chat without a character) in `mode`: in a personal
/// mode the tools its personality keeps from it, and whether Cardwave's own
/// are offered (in a chat without a character, and in a personal mode).
fn speaker_tools(
    db: &Db,
    card_id: Option<i64>,
    character: &str,
    mode: Option<&str>,
) -> anyhow::Result<(Option<Vec<assistant::Tool>>, bool)> {
    let personal = match card_id.filter(|_| assistant::is_personal(mode)) {
        Some(card_id) => Some(assistant::kept(db, card_id, character)?.0),
        None => None,
    };
    let app = card_id.is_none() || personal.is_some();
    Ok((personal, app))
}

/// Whether a reply of that speaker (`speaker_tools`) is offered any tool
/// besides Code mode's `make_tool` and the chat tools, by the rule of `toolbox`: what the chat's
/// side panel tells of Reply length (`ChatView::tools`).
pub(crate) fn offers_tools(
    db: &Db,
    user: i64,
    owner: bool,
    card_id: Option<i64>,
    character: &str,
    mode: Option<&str>,
) -> anyhow::Result<bool> {
    let (personal, app) = speaker_tools(db, card_id, character, mode)?;
    Ok(tools_of(db, user, (owner, false), personal.as_deref(), app)?.cuts())
}

/// The tools the user's settings offer a reply, with `make_tool` where the
/// chat's Code mode is on (`code`); of a character in a personal mode
/// (`personal`, the tools it may not use), only those its personality lets it
/// use, with coding tasks; Cardwave's own (`tools::app`) only with `api`, the
/// API they ask and as whom.
pub(crate) fn toolbox(
    db: &Db,
    user: i64,
    (owner, code): (bool, bool),
    personal: Option<&[assistant::Tool]>,
    api: Option<(Api, Caller)>,
) -> anyhow::Result<Option<Toolbox>> {
    let toolbox = tools_of(db, user, (owner, code), personal, api.is_some())?
        .with_app(api.map(|(api, caller)| super::app_tools::ask_app(api, caller)));
    Ok(toolbox.offers().then_some(toolbox))
}

/// The toolbox of `toolbox` before its API, Cardwave's own tools with `app`.
fn tools_of(
    db: &Db,
    user: i64,
    (owner, code): (bool, bool),
    personal: Option<&[assistant::Tool]>,
    app: bool,
) -> anyhow::Result<Toolbox> {
    let mut tools = settings::get(db, user)?.tools;
    tools.app &= app;
    let coding = personal.is_some_and(|off| assistant::restrict(&mut tools, off));
    let image = match tools.pictures && kinds::picked(db, user, Kind::Images)?.is_some() {
        true => Some(images::whom(db, user)?),
        false => None,
    };
    Ok(Toolbox::of(
        tools,
        (owner, code),
        image,
        user,
        (coding, super::app_tools::tool_routes()),
    )
    .with_written(cw_coding::tools::written::list(db, user)?))
}

/// Writes the reply into its message and tells the pages how it ended.
async fn write_reply(writer: Writer, mut job: Job) {
    let messages = std::mem::take(&mut job.messages);
    let mut content = std::mem::take(&mut job.before);
    let mut made = Vec::new();
    let mut pushed = Pushed::new(&content);
    let reply = (&mut pushed, &mut content, &mut made);
    let began = Instant::now();
    let failure = rounds::read_reply(&writer, &job, messages, reply)
        .await
        .err();
    let read = Read {
        content,
        made,
        pushed,
        began,
        failure,
    };
    writer::finish(writer, job, read).await;
}

/// Answers the call of a tool that waits in the chat.
async fn answer(
    State(state): State<AppState>,
    User(user): User,
    Path(chat_id): Path<i64>,
    Json(answer): Json<Answer>,
) -> ApiResult<StatusCode> {
    let asking = state.asks().remove(&(user, chat_id));
    let asking = asking.ok_or(NotFound("question"))?;
    // The answer goes first: keeping it for the chat cannot keep it from the reply.
    let kind = asking.ask.kind;
    // Its receiver gone, nobody waits for the answer.
    let _ = asking.answer.send(answer.allow);
    // A change of Cardwave's is asked each time.
    if answer.allow && answer.for_chat == Some(true) && kind != cw_coding::tools::AskKind::App {
        state
            .run(move |db| chats::allow_tool(db, user, chat_id, kind))
            .await?;
    }
    Ok(StatusCode::NO_CONTENT)
}

/// Stops the reply being written in the chat, if there is one. What it has so
/// far stays; its end is told by a `reply_ended` event like any other.
async fn stop(
    State(state): State<AppState>,
    User(user): User,
    Path(chat_id): Path<i64>,
) -> ApiResult<StatusCode> {
    let writer = state.replies().get(&(user, chat_id)).cloned();
    match writer {
        Some(stop) => stop.notify_one(),
        // Nothing writes in this chat. A reply whose end could not be saved
        // would keep it busy for good, so such a reply is ended here.
        None => {
            let ended = state
                .run(move |db| chats::finish_abandoned(db, user, chat_id))
                .await?;
            for (message_id, message) in ended {
                state.push_reply(
                    user,
                    ReplyEvent::ReplyEnded {
                        chat_id,
                        message_id,
                        message: message.map(Box::new),
                        error: None,
                    },
                );
            }
        }
    }
    Ok(StatusCode::NO_CONTENT)
}

/// Writes the user's next message, or betters `improve`, and answers with the
/// text for the message field. The chat is not changed, nor kept busy: the
/// text is the page's to send or not.
async fn draft(
    State(state): State<AppState>,
    User(user): User,
    Path(chat_id): Path<i64>,
    Json(draft): Json<Draft>,
) -> ApiResult<Json<Drafted>> {
    let improve = draft.improve.clone();
    let (provider, prompt, name) = state
        .run(move |db| {
            reply::draft_prompt(
                db,
                user,
                chat_id,
                draft.improve.as_deref(),
                draft.direction.as_deref(),
            )
        })
        .await?;
    // A page that hangs up drops this, and with it the model's answer.
    let mut reply = provider::ask(&state.http, &provider, &prompt).await?;
    let mut text = String::new();
    while let Some(piece) = reply.next().await? {
        text.push_str(&piece);
    }
    let content = reply::cleaned(&text, &name, improve.as_deref());
    if content.is_empty() {
        return Err(Fail::new(Code::NoText).into());
    }
    Ok(Json(Drafted { content }))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/generate.rs"));

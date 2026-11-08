//! The memory over HTTP, and when it is asked (`memory.rs` holds the rest).
//!
//! `GET /api/memories`, `PATCH`/`DELETE /api/memories/{id}` and `POST
//! /api/memories/{id}/restore` serve Knowledge › Memories (an ID is
//! `<memory>.<entry>`); every change and block read is pushed as `memories` with
//! its chat, and the search model reads what Search Cardwave finds of it.
//!
//! `remember` runs a pass after a reply ended with words, one per chat at a time
//! (`AppState::remembering`): each whole unread block (`memory::next_block`) is
//! read by the Worker model, a failed one stays for the next pass; then the
//! missing vectors are made, without the reply's time limit, and other chats of
//! a shared memory whose blocks were let go are read again. `recall`, before a
//! reply, never fails it; a memory that does not read leaves the rest: the note
//! (by words alone without vectors), lorebook entries by meaning, documents
//! (those attached to the message answered whole, the rest by meaning).

use std::collections::HashSet;

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, patch, post};
use axum::{Json, Router};
use cw_chat::assistant::{self, Remembering};
use cw_chat::attachments;
use cw_chat::chats::{self, Chat, PromptInputs};
use cw_chat::documents;
use cw_chat::memory::{self, ChangeMemory, Helper, MemoryView, Vectors};
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_find::place::Place;
use cw_find::reader;
use cw_prompt::lorebook::uid;
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::{self as provider, Provider};
use futures_util::future::BoxFuture;

use super::{ApiResult, User};
use crate::AppState;
use cw_search as search;

/// How many of the newest messages the search model reads for meaning: the
/// newest exchange, as SillyTavern's vector lorebook reads by default.
const MEANT: usize = 2;
/// The helper's temperature (build spec A8).
const TEMPERATURE: f64 = 0.2;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/memories", get(list))
        .route("/api/memories/{id}", patch(change).delete(delete))
        .route("/api/memories/{id}/restore", post(restore))
}

async fn list(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Vec<MemoryView>>> {
    Ok(Json(state.run(move |db| memory::list(db, user)).await?))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<String>,
    Json(change): Json<ChangeMemory>,
) -> ApiResult<Json<MemoryView>> {
    let view = state
        .run(move |db| memory::change(db, user, &id, &change))
        .await?;
    told(&state, user, view.chat_id);
    // Its new text's vector.
    remember(&state, user, view.chat_id);
    Ok(Json(view))
}

async fn delete(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<String>,
) -> ApiResult<StatusCode> {
    let view = state.run(move |db| memory::delete(db, user, &id)).await?;
    told(&state, user, view.chat_id);
    Ok(StatusCode::NO_CONTENT)
}

async fn restore(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<String>,
) -> ApiResult<Json<MemoryView>> {
    let view = state.run(move |db| memory::restore(db, user, &id)).await?;
    told(&state, user, view.chat_id);
    Ok(Json(view))
}

fn told(state: &AppState, user: i64, chat_id: i64) {
    state.push(user, &PageEvent::Memories { chat_id });
}

/// The Worker model as the memory's helper: one user message, at the build
/// spec's temperature (a thinking model's thinking is left out by
/// `provider`); an empty answer asked once more.
struct Worker<'a> {
    http: &'a Http,
    provider: Provider,
}

impl Helper for Worker<'_> {
    fn ask<'a>(&'a self, prompt: &'a str) -> BoxFuture<'a, anyhow::Result<String>> {
        Box::pin(async move {
            let asked = [PromptMessage::new(Role::User, prompt)];
            for _ in 0..2 {
                let answer = cw_provider::answer(self.http, &self.provider, &asked).await?;
                if !answer.trim().is_empty() {
                    return Ok(answer.trim().to_string());
                }
            }
            anyhow::bail!(Fail::new(Code::WorkerNoAnswer))
        })
    }
}

/// Has a memory pass read the chat's new messages, unless one does already.
pub(super) fn remember(state: &AppState, user: i64, chat_id: i64) {
    // Refused while a restore runs; a pass already reading the chat is the same user's.
    let first = state.unless_restoring(|| state.remembering().insert(chat_id, user).is_none());
    if !matches!(first, Ok(true)) {
        return;
    }
    let held = state.clone();
    let place = Place::new(move || {
        held.remembering().remove(&chat_id);
    });
    tokio::spawn(pass(state.clone(), user, chat_id, place));
}

/// A chat, whose memory it keeps, and the Worker model.
type Working = (Chat, (memory::Owner, memory::Mode), Provider);

/// The chat's memory and the Worker model, where it remembers and there is one.
fn worker(db: &cw_store::Db, user: i64, chat_id: i64) -> anyhow::Result<Option<Working>> {
    let Some(chat) = chats::get(db, user, chat_id)? else {
        return Ok(None);
    };
    let owner = assistant::chat_remembering(db, user, &chat)?.owner(chat.id);
    let provider = provider::for_work(db, user)?;
    Ok(owner.zip(provider).map(|(owner, mut provider)| {
        provider.sampling.temperature = Some(TEMPERATURE);
        (chat, owner, provider)
    }))
}

/// A block of the chat to read, and the Worker model that reads it.
type ToRead = (memory::Next, Provider);

/// The memory's store and the chat's next whole unread block with the Worker
/// model to read it: up to the chat's head, unless a reply is being written
/// there (its end has the pass go on). Neither where the chat does not remember.
fn next_of(
    db: &cw_store::Db,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<(Option<i64>, Option<ToRead>)> {
    let Some((chat, (owner, mode), provider)) = worker(db, user, chat_id)? else {
        return Ok((None, None));
    };
    let next = match chat.head_id {
        Some(head) if chats::view(db, user, head)?.message.complete => {
            memory::next_block(db, user, &chat, (&owner, mode), Some(head))?
        }
        _ => None,
    };
    Ok(match next {
        Some(next) => (Some(next.store), Some((next, provider))),
        // The blocks read before still have their vectors made by the store the pass holds.
        None => match memory::store_of(db, &owner) {
            Ok(store) => (store, None),
            Err(failure) => {
                tracing::error!("chat {chat_id}'s memory store cannot be read: {failure:#}");
                (None, None)
            }
        },
    })
}

async fn pass(state: AppState, user: i64, chat_id: i64, place: Place) {
    let mut again = Vec::new();
    let mut store = None;
    loop {
        let taken = state.clone();
        let read = state
            .work(move |db| {
                let mut remembering = taken.remembering();
                let read = next_of(db, user, chat_id);
                if matches!(read, Ok((_, None))) {
                    remembering.remove(&chat_id);
                }
                read
            })
            .await;
        let (mut next, provider) = match read {
            Ok((found, next)) => {
                store = found.or(store);
                match next {
                    Some(next) => next,
                    None => break,
                }
            }
            Err(failure) => {
                tracing::error!("chat {chat_id}'s memory cannot be read: {failure:#}");
                return;
            }
        };
        again.append(&mut next.again);
        let helper = Worker {
            http: &state.http,
            provider,
        };
        let added = match memory::system()
            .add(&next.state, &next.block, &helper)
            .await
        {
            Ok(added) => added,
            Err(failure) => {
                tracing::warn!("chat {chat_id}'s memory pass failed: {failure:#}");
                state.remembering().remove(&chat_id);
                break;
            }
        };
        match state
            .work(move |db| memory::keep(db, user, &mut next, added))
            .await
        {
            Ok(true) => told(&state, user, chat_id),
            Ok(false) => {}
            Err(failure) => {
                tracing::error!("chat {chat_id}'s memory cannot be kept: {failure:#}");
                return;
            }
        }
    }
    place.release();
    if let Some(store) = store {
        embed(&state, user, store).await;
        // What Search Cardwave keeps of it, written anew (`memory::keep`).
        cw_find::reader::read_cards(&state);
    }
    again.sort_unstable();
    again.dedup();
    for other in again {
        remember(&state, user, other);
    }
}

/// Makes the vectors the memory's newest state lacks, and lets go of those it no longer has.
async fn embed(state: &AppState, user: i64, store: i64) {
    let read = state
        .work(move |db| memory::unembedded(db, user, store))
        .await;
    let (stamp, mut missing) = match read {
        Ok(read) => read,
        Err(failure) => {
            tracing::error!("memory {store}'s vectors cannot be read: {failure:#}");
            return;
        }
    };
    missing.sort_unstable();
    missing.dedup();
    let made = match missing.is_empty() {
        true => Vec::new(),
        false => match reader::memory_vectors(state, user, &missing, false).await {
            // Made by another model than the one they were missing of: the next pass makes them.
            Some((by, made)) if by == stamp => made,
            _ => return,
        },
    };
    let new: Vec<(Vec<u8>, Vec<u8>)> = missing
        .iter()
        .zip(made)
        .map(|(text, vector)| {
            (
                search::text_hash(&stamp, text),
                cw_provider::embedder::to_bytes(&vector),
            )
        })
        .collect();
    if let Err(failure) = state
        .work(move |db| memory::keep_vectors(db, store, &stamp, &new))
        .await
    {
        tracing::error!("memory {store}'s vectors cannot be kept: {failure:#}");
    }
}

/// What a reply is given beside the chat (`recall`).
#[derive(Default)]
pub(super) struct Recalled {
    /// What it is reminded of, as the prompt's memory.
    pub memory: Option<String>,
    /// The lorebook entries used by meaning that its newest messages are
    /// about (`ChatState::meaning`); none where the search model does not tell.
    pub meaning: Option<HashSet<String>>,
    /// The pieces of the documents it is given, as the prompt's section.
    pub documents: Option<String>,
}

/// What a reply of `speaker` after the message `last`, whose prompt is made of
/// `inputs`, is given beside the chat: its memory note, which of the lorebook
/// entries used by meaning its newest messages are about, and the pieces of
/// its documents near them, of at most `budget` tokens. Nothing that fails
/// here holds the reply back: it goes without.
pub(super) async fn recall(
    state: &AppState,
    user: i64,
    chat: &Chat,
    speaker: Option<i64>,
    last: Option<i64>,
    inputs: &PromptInputs,
    budget: usize,
) -> Recalled {
    let taken = chat.clone();
    let card_id = inputs.card_id;
    let (character, mode) = (inputs.character_id.clone(), inputs.mode.clone());
    let read = state
        .work(move |db| {
            let remembering = match card_id {
                Some(card_id) => assistant::remembering(db, card_id, &character, mode.as_deref())?,
                None => Remembering::Off,
            };
            let read = memory::read_chat(db, user, &taken, last)?;
            let newest: Vec<String> = read.said[read.said.len().saturating_sub(MEANT)..]
                .iter()
                .map(|(said, _)| said.line())
                .collect();
            let to_render = || match remembering.owner(taken.id) {
                Some((owner, mode)) => {
                    match memory::to_render(db, user, &read, (&owner, mode), speaker)? {
                        Some(to_render) => {
                            let kept = memory::kept_vectors(db, user, &to_render)?;
                            anyhow::Ok(Some((to_render, kept)))
                        }
                        None => Ok(None),
                    }
                }
                None => Ok(None),
            };
            let to_render = to_render().unwrap_or_else(|failure| {
                tracing::error!("chat {}'s memory cannot be read: {failure:#}", taken.id);
                None
            });
            let pieces =
                documents::for_reply(db, user, taken.id, card_id).unwrap_or_else(|failure| {
                    tracing::error!("chat {}'s documents cannot be read: {failure:#}", taken.id);
                    Vec::new()
                });
            let attached = last.map_or(Ok(Vec::new()), |last| {
                attachments::Storage::message_documents(db, user, last)
            });
            let attached = attached.unwrap_or_else(|failure| {
                tracing::error!(
                    "chat {}'s attached documents cannot be read: {failure:#}",
                    taken.id
                );
                Vec::new()
            });
            Ok((newest.join("\n\n"), to_render, (attached, pieces)))
        })
        .await;
    let (newest, to_render, (attached, pieces)) = match read {
        Ok(read) => read,
        Err(failure) => {
            tracing::error!("chat {}'s memory cannot be read: {failure:#}", chat.id);
            return Recalled::default();
        }
    };
    let mut recalled = Recalled::default();
    by_meaning(
        state,
        user,
        inputs,
        &newest,
        (&attached, pieces, budget),
        &mut recalled,
    )
    .await;
    if let Some((to_render, kept)) = to_render {
        recalled.memory = note(state, user, to_render, kept).await;
    }
    recalled
}

/// The memory note of `to_render`, ranked by meaning too where the search
/// model gives the vectors of the asked texts in time and every text's is kept.
async fn note(
    state: &AppState,
    user: i64,
    to_render: memory::ToRender,
    (stamp, kept): (String, Option<Vectors>),
) -> Option<String> {
    let ask = &to_render.ask;
    let vectors = match kept {
        Some(mut vectors) => {
            let mut asked = vec![ask.query.clone()];
            asked.extend(ask.prev.iter().map(|prev| format!("{}\n{prev}", ask.query)));
            reader::memory_vectors(state, user, &asked, true)
                .await
                .filter(|(by, _)| *by == stamp)
                .map(|(_, made)| {
                    vectors.extend(asked.into_iter().zip(made));
                    vectors
                })
        }
        None => None,
    };
    match memory::system().render(&to_render.state, ask, vectors.as_ref()) {
        Ok(note) => (!note.is_empty()).then_some(note),
        Err(failure) => {
            tracing::error!(
                "memory {}'s note cannot be written: {failure:#}",
                to_render.store
            );
            None
        }
    }
}

/// A document attached to the message answered: its ID, name and text.
type Attached = (i64, String, String);

/// Gives `recalled` the lorebook entries used by meaning that the `newest`
/// messages are about and the documents (`documents::given`, of at most
/// `budget` tokens): those `attached` to the message answered, whatever the
/// search model, and the `pieces` near the newest: all by one vector of them.
async fn by_meaning(
    state: &AppState,
    user: i64,
    inputs: &PromptInputs,
    newest: &str,
    (attached, pieces, budget): (&[Attached], Vec<cw_search::Piece>, usize),
    recalled: &mut Recalled,
) {
    let entries: Vec<(String, String)> = inputs
        .character
        .lorebook
        .iter()
        .flat_map(|book| book.entries.iter().enumerate())
        .filter(|(_, entry)| entry.by_meaning && entry.enabled && !entry.content.trim().is_empty())
        .map(|(at, entry)| (uid(at, entry), entry.content.clone()))
        .collect();
    let query = match entries.is_empty() && pieces.is_empty() {
        true => None,
        false => reader::newest_vector(state, user, newest).await,
    };
    recalled.documents = documents::given(attached, query.as_deref(), pieces, budget);
    let (Some(query), false) = (query, entries.is_empty()) else {
        return;
    };
    let texts: Vec<String> = entries.iter().map(|(_, content)| content.clone()).collect();
    let Some(vectors) = reader::vectors(state, user, texts).await else {
        return;
    };
    recalled.meaning = Some(
        entries
            .iter()
            .zip(&vectors)
            .filter(|(_, v)| search::nearest(&query, v) >= search::MEANING)
            .map(|((uid, _), _)| uid.clone())
            .collect(),
    );
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/memory.rs"));

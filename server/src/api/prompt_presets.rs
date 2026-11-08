//! Prompt presets over HTTP: the list, a new one, a change, a copy (of
//! Default too: `POST /api/prompt-presets/default/duplicate`), a deletion,
//! the one in use for every chat, and a chat's own choice
//! (`PUT /api/chats/{id}/prompt-preset`). What they hold and do is
//! `crates/cw-chat/src/prompt_presets.rs`.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_chat::chats::{self, Chat};
use cw_chat::prompt_presets::{self, ChatPromptPreset, PromptPreset, PromptTexts};
use cw_core::NotFound;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Copied, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/prompt-presets", get(list).post(create))
        .route("/api/prompt-presets/in-use", put(put_in_use))
        .route("/api/prompt-presets/{id}", put(change).delete(remove))
        .route("/api/prompt-presets/{id}/duplicate", post(duplicate))
        .route(
            "/api/prompt-presets/default/duplicate",
            post(duplicate_default),
        )
        .route("/api/chats/{id}/prompt-preset", put(choose))
}

/// A prompt preset as its editor holds it: its name and what it holds.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct EditPromptPreset {
    pub name: String,
    #[serde(flatten)]
    #[ts(flatten)]
    pub texts: PromptTexts,
}

/// Default's name in the user's language and the word for a copy ([`Copied`]),
/// for a copy of Default.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct CopiedDefault {
    pub name: String,
    pub copy: String,
}

/// The prompt preset in use for every chat that does not choose its own;
/// `null` for "Default", the card's own prompt.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct PromptPresetInUse {
    pub id: Option<i64>,
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Vec<PromptPreset>>> {
    state
        .run(move |db| prompt_presets::list(db, user))
        .await
        .map(Json)
}

async fn create(
    State(state): State<AppState>,
    User(user): User,
    Json(new): Json<EditPromptPreset>,
) -> ApiResult<(StatusCode, Json<PromptPreset>)> {
    let made = state
        .run(move |db| prompt_presets::create(db, user, &new.name, &new.texts))
        .await?;
    Ok((StatusCode::CREATED, Json(made)))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<EditPromptPreset>,
) -> ApiResult<Json<PromptPreset>> {
    state
        .run(move |db| prompt_presets::change(db, user, id, &to.name, &to.texts))
        .await
        .map(Json)
}

async fn duplicate(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(word): Json<Copied>,
) -> ApiResult<(StatusCode, Json<PromptPreset>)> {
    let copy = state
        .run(move |db| prompt_presets::duplicate(db, user, id, &word.copy))
        .await?;
    Ok((StatusCode::CREATED, Json(copy)))
}

/// Makes a copy of Default, the card's own prompt: an empty preset under a
/// name of its own.
async fn duplicate_default(
    State(state): State<AppState>,
    User(user): User,
    Json(default): Json<CopiedDefault>,
) -> ApiResult<(StatusCode, Json<PromptPreset>)> {
    let copy = state
        .run(move |db| prompt_presets::duplicate_default(db, user, &default.name, &default.copy))
        .await?;
    Ok((StatusCode::CREATED, Json(copy)))
}

async fn remove(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| prompt_presets::delete(db, user, id))
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

async fn put_in_use(
    State(state): State<AppState>,
    User(user): User,
    Json(to): Json<PromptPresetInUse>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| prompt_presets::put_in_use(db, user, to.id))
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

/// Has the chat go by a prompt preset of its own, the card's own prompt, or
/// the one in use, from its next reply on. Answers with the chat.
async fn choose(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(to): Json<ChatPromptPreset>,
) -> ApiResult<Json<Chat>> {
    state
        .run(move |db| {
            prompt_presets::choose_for_chat(db, user, id, to)?;
            Ok(chats::get(db, user, id)?.ok_or(NotFound("chat"))?)
        })
        .await
        .map(Json)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/prompt_presets.rs"));

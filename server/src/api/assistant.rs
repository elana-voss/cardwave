//! A chat's mode and its character's personality over HTTP (`assistant`):
//! `PUT /api/chats/{id}/mode` sets the mode by hand, or has the chat pick by
//! itself again (`null`); `GET`/`PATCH /api/chats/{id}/personality` read and
//! change the personality of the chat's first character, with the tools the
//! account offers.

use axum::extract::{Path, State};
use axum::routing::{get, put};
use axum::{Json, Router};
use cw_chat::assistant::{self, ChangePersonality, Personality};
use cw_chat::chats::Chat;
use cw_library::settings;
use cw_provider::kinds::{self, Kind};
use cw_store::Db;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/chats/{id}/mode", put(set_mode))
        .route(
            "/api/chats/{id}/personality",
            get(personality).patch(change),
        )
}

/// The mode a chat is set to: one of its card's, or none to pick by itself.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetMode {
    pub mode: Option<String>,
}

async fn set_mode(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<SetMode>,
) -> ApiResult<Json<Chat>> {
    state
        .run(move |db| assistant::set_mode(db, user, id, asked.mode.as_deref()))
        .await
        .map(Json)
}

/// The personality of the chat's first character, with what the account offers.
fn read(db: &Db, user: i64, chat_id: i64, owner: bool) -> anyhow::Result<Personality> {
    let (card_id, character, _) = assistant::first(db, user, chat_id)?;
    let tools = settings::get(db, user)?.tools;
    let image = kinds::picked(db, user, Kind::Images)?.is_some();
    let (tools_off, memory) = assistant::kept(db, card_id, &character)?;
    Ok(Personality {
        offered: assistant::offered(&tools, owner, image),
        tools_off,
        memory,
    })
}

async fn personality(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Personality>> {
    let owner = user == state.local_user();
    state
        .run(move |db| read(db, user, id, owner))
        .await
        .map(Json)
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<ChangePersonality>,
) -> ApiResult<Json<Personality>> {
    let owner = user == state.local_user();
    state
        .run(move |db| {
            let (card_id, character, _) = assistant::first(db, user, id)?;
            assistant::change(db, user, card_id, &character, &asked)?;
            read(db, user, id, owner)
        })
        .await
        .map(Json)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/assistant.rs"));

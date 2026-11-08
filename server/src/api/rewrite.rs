//! A card's text changed by an AI tool over HTTP: `POST /api/rewrite` with a
//! [`Rewrite`] answers `{ "text": … }`, the background model's new text
//! (`rewrite::ask`); `POST /api/rewrite/lore` with a [`LoreRewrite`] answers
//! the entries as the lorebook's AI tool changed them (`rewrite::lore`). A
//! page that hangs up stops the model.

use axum::extract::State;
use axum::routing::post;
use axum::{Json, Router};
use cw_ccv4::languages::LoreText;
use cw_library::rewrite::{self, LoreRewrite, Rewrite};
use cw_provider::{self as provider, NOT_SET_UP};
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/rewrite", post(change))
        .route("/api/rewrite/lore", post(change_lore))
}

/// The text as the AI tool changed it.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct Rewritten {
    pub text: String,
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<Rewrite>,
) -> ApiResult<Json<Rewritten>> {
    let provider = state
        .run(move |db| Ok(provider::for_work(db, user)?.ok_or(NOT_SET_UP)?))
        .await?;
    let text = rewrite::ask(&state.http, &provider, &asked).await?;
    Ok(Json(Rewritten { text }))
}

async fn change_lore(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<LoreRewrite>,
) -> ApiResult<Json<Vec<LoreText>>> {
    let provider = state
        .run(move |db| Ok(provider::for_work(db, user)?.ok_or(NOT_SET_UP)?))
        .await?;
    Ok(Json(rewrite::lore(&state.http, &provider, asked).await?))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/rewrite.rs"));

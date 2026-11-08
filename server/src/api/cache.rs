//! The cache over HTTP: what the server keeps for a user that it can make
//! again, how much that is, and throwing it away. So far it is the cards'
//! pictures made small for the lists (`thumbnails`).
//!
//! It is `GET` and `DELETE /api/cache`, answered as `CacheSize`. The UI has no
//! line for it: the small pictures keep in check by themselves (they go with
//! their picture, and at the start those of a size no list asks for); the
//! browser tests clear it.

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::get;
use axum::{Json, Router};
use cw_library::thumbnails;
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/cache", get(show).delete(clear))
}

/// How much the cache holds, in bytes.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct CacheSize {
    /// The small pictures of the user's cards.
    #[ts(type = "number")]
    pub thumbnails: u64,
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<CacheSize>> {
    let thumbnails = state.run(move |db| thumbnails::size(db, user)).await?;
    Ok(Json(CacheSize { thumbnails }))
}

/// Throws away what the cache holds. All of it is made again when it is asked for.
async fn clear(State(state): State<AppState>, User(user): User) -> ApiResult<StatusCode> {
    state.run(move |db| thumbnails::clear(db, user)).await?;
    Ok(StatusCode::NO_CONTENT)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/cache.rs"));

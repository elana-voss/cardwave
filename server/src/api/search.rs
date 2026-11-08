//! The search model over HTTP; its work is `find::reader`'s.
//!
//! `GET /api/search` is its state; `POST`/`DELETE /api/search/download` start
//! and cancel the download; `DELETE /api/search` stops the model and removes
//! its file (vectors stay); these three are this computer's account's alone, as
//! the model serves every account.

use axum::extract::State;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_core::ErrorBody;
use cw_find::reader;
use cw_provider::embedder::MODEL;
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, Owner, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/search", get(show).delete(remove))
        .route("/api/search/download", post(download).delete(cancel))
}

/// The search model's state, as the dialog and the settings show it.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct SearchModel {
    pub name: String,
    /// The size of its file, in bytes.
    pub size: u64,
    pub state: SearchState,
    /// The bytes downloaded, while it downloads.
    pub done: u64,
    /// Why the last download failed, or the model did.
    pub failure: Option<ErrorBody>,
    /// The user's cards it has yet to read, while it is ready.
    pub left: usize,
}

#[derive(Serialize, TS)]
#[ts(export, rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum SearchState {
    Absent,
    Downloading,
    Ready,
}

async fn state_of(state: &AppState, user: i64) -> ApiResult<SearchModel> {
    let status = reader::status(state, user).await?;
    Ok(SearchModel {
        name: MODEL.into(),
        size: status.size,
        state: if status.downloading {
            SearchState::Downloading
        } else if status.ready {
            SearchState::Ready
        } else {
            SearchState::Absent
        },
        done: status.done,
        failure: status.failure,
        left: status.left,
    })
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<SearchModel>> {
    reader::read_cards(&state);
    state_of(&state, user).await.map(Json)
}

/// Starts downloading the model, unless it is there or downloads already.
async fn download(
    State(state): State<AppState>,
    Owner(user): Owner,
) -> ApiResult<Json<SearchModel>> {
    reader::download(&state);
    state_of(&state, user).await.map(Json)
}

/// Cancels the download, if one runs.
async fn cancel(State(state): State<AppState>, Owner(user): Owner) -> ApiResult<Json<SearchModel>> {
    reader::cancel(&state);
    state_of(&state, user).await.map(Json)
}

/// Removes the model's file (`reader::remove`).
async fn remove(State(state): State<AppState>, Owner(user): Owner) -> ApiResult<Json<SearchModel>> {
    reader::remove(&state).await?;
    state_of(&state, user).await.map(Json)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/search.rs"));

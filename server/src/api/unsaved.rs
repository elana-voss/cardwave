//! Unsaved edits over HTTP (`cw_library::unsaved`): `GET /api/unsaved/{field}` answers the text kept, or null;
//! `PUT` with `{ "text": … }` keeps it, an empty one removing it.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::get;
use axum::{Json, Router};
use cw_library::unsaved;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

/// A field's unsaved text, as kept or to keep.
#[derive(Deserialize, Serialize, TS)]
#[ts(export)]
pub(crate) struct Unsaved {
    pub text: String,
}

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/unsaved/{field}", get(show).put(keep))
}

async fn show(
    State(state): State<AppState>,
    User(user): User,
    Path(field): Path<String>,
) -> ApiResult<Json<Option<Unsaved>>> {
    let text = state.run(move |db| unsaved::get(db, user, &field)).await?;
    Ok(Json(text.map(|text| Unsaved { text })))
}

async fn keep(
    State(state): State<AppState>,
    User(user): User,
    Path(field): Path<String>,
    Json(kept): Json<Unsaved>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| unsaved::keep(db, user, &field, &kept.text))
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/unsaved.rs"));

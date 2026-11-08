//! The tools the model wrote (code mode, `tools::written`) over HTTP, for
//! Settings › Tools › "Tools the AI wrote": `GET /api/tools/written` lists
//! the account's, `PATCH /api/tools/written/{id}` switches one on or off,
//! `DELETE` deletes it and `POST …/restore` puts it back (Undo). Each change
//! tells the user's other pages (`PageEvent::WrittenTools`).

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, patch, post};
use axum::{Json, Router};
use cw_coding::tools::written::{self, WrittenTool};
use cw_core::PageEvent;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/tools/written", get(list))
        .route("/api/tools/written/{id}", patch(change).delete(delete))
        .route("/api/tools/written/{id}/restore", post(restore))
}

/// A written tool switched on or off.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct ChangeWrittenTool {
    pub on: bool,
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Vec<WrittenTool>>> {
    Ok(Json(state.run(move |db| written::list(db, user)).await?))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(change): Json<ChangeWrittenTool>,
) -> ApiResult<Json<WrittenTool>> {
    let on = change.on;
    let tool = state
        .run(move |db| written::set_on(db, user, id, on))
        .await?;
    state.tell(user, &page, &PageEvent::WrittenTools);
    Ok(Json(tool))
}

async fn delete(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state.run(move |db| written::delete(db, user, id)).await?;
    state.tell(user, &page, &PageEvent::WrittenTools);
    Ok(StatusCode::NO_CONTENT)
}

async fn restore(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<WrittenTool>> {
    let tool = state.run(move |db| written::restore(db, user, id)).await?;
    state.tell(user, &page, &PageEvent::WrittenTools);
    Ok(Json(tool))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/written.rs"));

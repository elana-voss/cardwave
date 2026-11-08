//! The Trash over HTTP: what is in it, and emptying it. An item is put there
//! and taken back out by a change to it (`trashed`), and deleted for good by
//! `DELETE` on its own address. Emptying it tells the user's other pages.

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::get;
use axum::{Json, Router};
use cw_library::trash::{self, TrashItem};
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/trash", get(show).delete(empty))
}

#[derive(Serialize, TS)]
#[ts(export)]
pub struct Trash {
    /// How many days an item stays before it is deleted for good.
    pub days: u32,
    /// The item moved to the Trash last comes first.
    pub items: Vec<TrashItem>,
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Trash>> {
    let items = state.run(move |db| trash::list(db, user)).await?;
    Ok(Json(Trash {
        days: trash::DAYS,
        items,
    }))
}

/// Deletes all that is in the Trash for good.
async fn empty(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
) -> ApiResult<StatusCode> {
    state.run(move |db| trash::empty(db, user)).await?;
    super::cards::told_trash(&state, user, &page);
    Ok(StatusCode::NO_CONTENT)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/trash.rs"));

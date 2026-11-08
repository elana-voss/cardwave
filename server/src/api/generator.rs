//! Extras › Character generator over HTTP: `POST /api/generator` with the
//! [`GeneratorPicks`] has the chat model write the card's greeting and example messages
//! (`generator::make`), then makes the card as "New card" does
//! (`cards::made`), and answers as an import does; 424 while the user has no
//! provider. A page that hangs up stops the model, and no card is made.

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::post;
use axum::{Json, Router};
use cw_library::cards::Imported;
use cw_library::generator::{self, GeneratorPicks};
use cw_provider::{self as provider, NOT_SET_UP};

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/generator", post(generate))
}

/// Makes a card of the picks, its greeting and example messages written by the chat model.
async fn generate(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(picks): Json<GeneratorPicks>,
) -> ApiResult<(StatusCode, Json<Imported>)> {
    let _at_work = state.at_work(user)?;
    let provider = state
        .run(move |db| Ok(provider::get(db, user)?.ok_or(NOT_SET_UP)?))
        .await?;
    let new = generator::make(&state.http, &provider, picks).await?;
    super::cards::made(&state, user, &page, new).await
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/generator.rs"));

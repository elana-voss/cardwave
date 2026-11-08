//! Languages over HTTP: `GET /api/languages`, those the app names
//! (`languages::all`); a card translated by "Translate…" of its menu, its own
//! lorebook's entries by the background model (`POST
//! /api/cards/{id}/lore-translation`, `rewrite::translate_lore`) and the
//! translation kept as a whole (`POST /api/cards/{id}/languages`,
//! `cards::translate`). The card's texts themselves are translated one by one
//! with `/api/rewrite`. A page that hangs up stops the model. A translation
//! kept tells the user's other pages (`cards::told`).

use axum::extract::{Path, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_ccv4::languages::{LoreText, Translation};
use cw_core::languages::{self, Language};
use cw_library::cards::{self, CardVersion};
use cw_library::rewrite;
use cw_provider as provider;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/languages", get(list))
        .route("/api/cards/{id}/lore-translation", post(lore))
        .route("/api/cards/{id}/languages", post(keep))
}

async fn list() -> Json<Vec<Language>> {
    Json(languages::all())
}

/// The language a card's lorebook is translated into, by its code.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct LoreTranslation {
    pub language: String,
}

async fn lore(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<LoreTranslation>,
) -> ApiResult<Json<Vec<LoreText>>> {
    let (provider, entries) = state
        .run(move |db| {
            let provider = provider::worker(db, user)?;
            Ok((provider, cards::lore_texts(db, user, id)?))
        })
        .await?;
    let name = languages::name_of(&asked.language);
    let translated = rewrite::translate_lore(&state.http, &provider, entries, &name).await?;
    Ok(Json(translated))
}

async fn keep(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(translation): Json<Translation>,
) -> ApiResult<Json<CardVersion>> {
    let saved = state
        .run(move |db| cards::translate(db, user, id, &translation))
        .await?;
    super::cards::told(&state, user, &page, id);
    cw_find::reader::read_cards(&state);
    Ok(Json(saved))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/languages.rs"));

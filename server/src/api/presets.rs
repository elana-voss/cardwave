//! Model presets over HTTP: the list, a new one made of the chat model in
//! use and the values for a reply, a change, a copy, a deletion, and one put
//! in use as the chat model. A
//! preset's key goes in and never comes out. A change of the presets tells
//! the user's pages (`PageEvent::Presets`), and one put in use that the
//! stored provider was changed (`PageEvent::Provider`).

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, patch, post};
use axum::{Json, Router};
use cw_core::PageEvent;
use cw_provider::kinds::{self, Kind};
use cw_provider::presets::{self, PresetView};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::provider::ProviderView;
use super::{ApiResult, Copied, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/presets", get(list).post(create))
        .route("/api/presets/{id}", patch(change).delete(remove))
        .route("/api/presets/{id}/duplicate", post(duplicate))
        .route("/api/presets/{id}/use", post(put_in_use))
}

/// A preset to keep: the chat model in use and the values for a reply, under a name.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct NewPreset {
    pub name: String,
}

/// Changes to a preset; what is left out stays as it is.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct ChangePreset {
    pub name: Option<String>,
    /// Whether it holds the chat model in use and the values for a reply
    /// from now on, as a new one would.
    pub replace: Option<bool>,
}

/// What putting a preset in use came to.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct UsedPreset {
    /// The stored provider from now on.
    pub provider: ProviderView,
    /// The provider stored until now, as a preset that is on no list: put in
    /// use (`POST /api/presets/{before}/use`), it takes this back. `null`
    /// where none was stored.
    pub before: Option<i64>,
}

/// The user's presets, in the order of their names.
async fn list(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Vec<PresetView>>> {
    state.run(move |db| presets::list(db, user)).await.map(Json)
}

async fn create(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<NewPreset>,
) -> ApiResult<(StatusCode, Json<PresetView>)> {
    let preset = state
        .run(move |db| presets::create(db, user, &new.name))
        .await?;
    state.tell(user, &page, &PageEvent::Presets);
    Ok((StatusCode::CREATED, Json(preset)))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(change): Json<ChangePreset>,
) -> ApiResult<Json<PresetView>> {
    let changed = state
        .run(move |db| {
            presets::change(
                db,
                user,
                id,
                change.name.as_deref(),
                change.replace.unwrap_or(false),
            )
        })
        .await?;
    state.tell(user, &page, &PageEvent::Presets);
    Ok(Json(changed))
}

async fn duplicate(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(word): Json<Copied>,
) -> ApiResult<(StatusCode, Json<PresetView>)> {
    let copy = state
        .run(move |db| presets::duplicate(db, user, id, &word.copy))
        .await?;
    state.tell(user, &page, &PageEvent::Presets);
    Ok((StatusCode::CREATED, Json(copy)))
}

async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state.run(move |db| presets::delete(db, user, id)).await?;
    state.tell(user, &page, &PageEvent::Presets);
    Ok(StatusCode::NO_CONTENT)
}

/// Stores what the preset holds as the user's provider.
async fn put_in_use(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<UsedPreset>> {
    let (used, worker) = state
        .run(move |db| {
            let used = presets::put_in_use(db, user, id)?;
            let worker = kinds::picked(db, user, Kind::Background)?.map(|picked| picked.model);
            Ok((used, worker))
        })
        .await?;
    state.tell(user, &page, &PageEvent::Provider);
    Ok(Json(UsedPreset {
        provider: ProviderView::of(used.provider, worker),
        before: used.before,
    }))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/presets.rs"));

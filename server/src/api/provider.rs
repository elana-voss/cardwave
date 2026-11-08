//! The user's model provider over HTTP. The key goes in and never comes out,
//! but for the last characters of a long one. Beside it the providers the app
//! knows by name, the search for the API of one it does not know, the models
//! an address lists, first run's picks of them, and the test of a model. A store of the provider tells
//! the user's pages (`PageEvent::Provider`).

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_core::PageEvent;
use cw_provider::check::{self, TestModel};
use cw_provider::list::{self, KnownProvider};
use cw_provider::models::{self, Limits, ListModels, ListedModels};
use cw_provider::picks::{self, Picks};
use cw_provider::places::{FindProvider, FoundProvider};
use cw_provider::{self as provider, Provider, Sampling, SetProvider};
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/provider", get(show).put(set))
        .route("/api/provider/find", post(find))
        .route("/api/provider/models", post(list_models))
        .route("/api/provider/picks", post(picks))
        .route("/api/provider/test", post(test))
        .route("/api/providers", get(known))
}

/// The providers the form offers by name, in the order of the names.
async fn known(User(_): User) -> Json<&'static [KnownProvider]> {
    Json(list::all())
}

/// The address of the API of the provider whose website the user gave, for
/// the user to take or not, or `null` when none was found. Nothing is stored.
async fn find(
    State(state): State<AppState>,
    User(_): User,
    Json(asked): Json<FindProvider>,
) -> ApiResult<Json<Option<FoundProvider>>> {
    Ok(Json(state.finder.find(&asked.website).await?))
}

/// The models the address in the form lists, asked with the key that would go
/// there with a chat. Nothing is stored.
async fn list_models(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<ListModels>,
) -> ApiResult<Json<ListedModels>> {
    let (base_url, key) = state
        .run(move |db| provider::whom(db, user, &asked.base_url, asked.api_key))
        .await?;
    let listed = models::of(&state.http, &base_url, &key, Limits::default()).await?;
    Ok(Json(listed))
}

/// First run's picks of a model of each kind at the address in the form,
/// asked with the key that would go there with a chat (`provider::picks`).
/// Nothing is stored.
async fn picks(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<ListModels>,
) -> ApiResult<Json<Picks>> {
    let (base_url, key) = state
        .run(move |db| provider::whom(db, user, &asked.base_url, asked.api_key))
        .await?;
    let index = state.models_dev.index(&state.http).await;
    Ok(Json(
        picks::pick(&state.http, &index, &base_url, &key).await,
    ))
}

/// Asks the model in the form a small question, at the form's address and
/// with the key that would go there with a chat. The answer is empty when the
/// model replied, and says why not otherwise. Nothing is stored.
async fn test(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<TestModel>,
) -> ApiResult<StatusCode> {
    let provider = state.run(move |db| check::whom(db, user, asked)).await?;
    check::model(&state.http, &provider, check::WAIT).await?;
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Serialize, TS)]
#[ts(export)]
pub struct ProviderView {
    pub base_url: String,
    pub model: String,
    /// Whether a key is stored. The key itself never leaves the server.
    pub has_key: bool,
    /// The last characters of the stored key, by which the user knows which
    /// one it is. Not there for a key too short to tell any of it.
    pub key_end: Option<String>,
    pub sampling: Sampling,
    /// What the user calls the provider, where it has a name of the user's.
    pub name: Option<String>,
    /// The worker model, where one is set; else the chat model does the work.
    pub worker_model: Option<String>,
}

impl ProviderView {
    pub fn of(provider: Provider, worker_model: Option<String>) -> Self {
        Self {
            worker_model,
            key_end: provider.key_end(),
            base_url: provider.base_url,
            model: provider.model,
            has_key: !provider.api_key.is_empty(),
            sampling: provider.sampling,
            name: Some(provider.name).filter(|name| !name.is_empty()),
        }
    }
}

/// The user's provider, or `null` when none is set up yet.
async fn show(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Option<ProviderView>>> {
    let stored = state.run(move |db| provider::stored(db, user)).await?;
    Ok(Json(stored.map(|(provider, worker)| {
        ProviderView::of(provider, worker)
    })))
}

async fn set(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<SetProvider>,
) -> ApiResult<Json<ProviderView>> {
    let (provider, worker) = state.run(move |db| provider::set(db, user, new)).await?;
    state.tell(user, &page, &PageEvent::Provider);
    Ok(Json(ProviderView::of(provider, worker)))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/provider.rs"));

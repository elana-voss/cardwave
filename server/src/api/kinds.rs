//! Settings › Providers over HTTP: the account's providers and the kind of
//! model each serves (`provider::kinds`), a provider added, changed and
//! removed, the models one offers with their kinds (`provider::catalog`), a
//! kind's model picked (search and voice also taken back to this computer's
//! download, `DELETE /api/kinds/{kind}`; the search's change has the cards
//! read anew), its thinking turned on or off, a ComfyUI's saved
//! workflow picked for its pictures (the background model finding where the
//! words go, 424 without one), This computer's folder of models set (this
//! computer's account's alone, 403 for another) with the models that fit
//! this computer downloaded into it, cancelled and removed (`provider::fit`,
//! each step pushed as `local_models` to this computer's account), and the
//! account's values for a reply. A key goes in and never comes out, but for the end of a long one.
//! Every change tells the user's pages (`PageEvent::Provider`).

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_chat::images::comfy;
use cw_core::NotFound;
use cw_core::{Events, PageEvent};
use cw_provider::catalog::{self, Catalog};
use cw_provider::fit::FitView;
use cw_provider::kinds::{self, ChangeEntry, EntryView, Kind, NewEntry, PickModel, ProvidersView};
use cw_provider::{self as provider, NOT_SET_UP, Sampling};
use cw_store::Db;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Owner, Page, User, owner_only};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/provider-list", get(show).post(add))
        .route(
            "/api/provider-list/{id}",
            axum::routing::patch(change).delete(remove),
        )
        .route("/api/provider-list/{id}/models", get(offered))
        .route("/api/provider-list/{id}/workflow", put(workflow))
        .route("/api/this-computer", put(folder))
        .route("/api/this-computer/models", get(fitting))
        .route(
            "/api/this-computer/models/{file}",
            post(download).delete(remove_model),
        )
        .route(
            "/api/this-computer/models/{file}/download",
            axum::routing::delete(cancel),
        )
        .route("/api/kinds/{kind}", put(pick).delete(unpick))
        .route("/api/kinds/{kind}/thinking", put(thinking))
        .route("/api/sampling", get(sampling).put(set_sampling))
}

/// Whether a kind's model is to think.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetThinking {
    pub on: bool,
}

/// The ComfyUI workflow a provider's pictures are made by.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct SetWorkflow {
    /// Its name as the provider's list of models has it; left out, ComfyUI's default one.
    pub name: Option<String>,
}

/// The folder whose GGUF files are This computer's models.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetFolder {
    pub folder: String,
}

fn kind(text: &str) -> anyhow::Result<Kind> {
    Ok(Kind::of(text).ok_or(NotFound("kind of model"))?)
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<ProvidersView>> {
    state.run(move |db| kinds::all(db, user)).await.map(Json)
}

/// Adds a provider, or answers the one at that address with that key.
async fn add(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<NewEntry>,
) -> ApiResult<(StatusCode, Json<EntryView>)> {
    let added = state.run(move |db| kinds::add(db, user, new)).await?;
    state.tell(user, &page, &PageEvent::Provider);
    Ok((StatusCode::CREATED, Json(added)))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<ChangeEntry>,
) -> ApiResult<Json<EntryView>> {
    let entry = state
        .run(move |db| kinds::change(db, user, id, new))
        .await?;
    // The search at its old address is another model than at its new.
    changed(&state, user, &page, Kind::Search);
    Ok(Json(entry))
}

/// Removes a provider, and the kinds of model at it with it.
async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state.run(move |db| kinds::remove(db, user, id)).await?;
    // The search may have gone back to this computer's model.
    changed(&state, user, &page, Kind::Search);
    Ok(StatusCode::NO_CONTENT)
}

/// The models the provider offers, with their kinds. Nothing is stored.
async fn offered(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Catalog>> {
    let entry = state.run(move |db| kinds::entry(db, user, id)).await?;
    Ok(Json(
        catalog::of(&state.http, &entry.base_url, &entry.api_key).await,
    ))
}

/// Has the provider's pictures made by a saved workflow of its ComfyUI, with
/// where its words go as the background model finds it, or by its default one.
async fn workflow(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(asked): Json<SetWorkflow>,
) -> ApiResult<Json<ProvidersView>> {
    let picked = match asked.name {
        Some(name) => {
            let (entry, worker) = state
                .run(move |db| {
                    let entry = kinds::entry(db, user, id)?;
                    Ok((entry, provider::for_work(db, user)?.ok_or(NOT_SET_UP)?))
                })
                .await?;
            let http = &state.http;
            Some(comfy::pick(http, &worker, &entry.base_url, &entry.api_key, &name).await?)
        }
        None => None,
    };
    let work = move |db: &Db| kinds::keep_workflow(db, user, id, picked.as_ref());
    kept(&state, user, &page, None, work).await
}

/// Has This computer's models be the GGUF files of a folder.
async fn folder(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(asked): Json<SetFolder>,
) -> ApiResult<Json<ProvidersView>> {
    if user != state.local_user() {
        Err(owner_only("choose its models"))?;
    }
    let work = move |db: &Db| kinds::keep_folder(db, user, &asked.folder);
    kept(&state, user, &page, None, work).await
}

/// Puts the kind at a provider's model.
async fn pick(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(text): Path<String>,
    Json(asked): Json<PickModel>,
) -> ApiResult<Json<ProvidersView>> {
    let kind = kind(&text)?;
    let work = move |db: &Db| kinds::pick(db, user, kind, asked);
    kept(&state, user, &page, Some(kind), work).await
}

/// Takes search or voice back to this computer's download.
async fn unpick(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(text): Path<String>,
) -> ApiResult<Json<ProvidersView>> {
    let kind = kind(&text)?;
    let work = move |db: &Db| kinds::unpick(db, user, kind);
    kept(&state, user, &page, Some(kind), work).await
}

/// Tells the user's pages of a kind put elsewhere; a search model's change has
/// the cards read by the new one.
fn changed(state: &AppState, user: i64, page: &Page, kind: Kind) {
    state.tell(user, page, &PageEvent::Provider);
    if kind == Kind::Search {
        cw_find::reader::provider_changed(state);
        state.push(user, &PageEvent::Search);
    }
}

/// Turns the kind's thinking on, or off where its provider takes a form of it.
async fn thinking(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(text): Path<String>,
    Json(asked): Json<SetThinking>,
) -> ApiResult<Json<ProvidersView>> {
    let kind = kind(&text)?;
    let provider = state
        .run(move |db| Ok(kinds::provider_of(db, user, kind)?.ok_or(NotFound("model"))?))
        .await?;
    let thinking = kinds::thinking(&state.http, &provider, asked.on).await?;
    let work = move |db: &Db| kinds::keep_thinking(db, user, kind, &provider.model, thinking);
    kept(&state, user, &page, None, work).await
}

/// Keeps a change of the user's providers (`work`), tells the user's pages of
/// it (of a kind put elsewhere, `changed`) and answers them all as they are now.
async fn kept(
    state: &AppState,
    user: i64,
    page: &Page,
    kind: Option<Kind>,
    work: impl FnOnce(&Db) -> anyhow::Result<()> + Send + 'static,
) -> ApiResult<Json<ProvidersView>> {
    let all = state
        .run(move |db| {
            work(db)?;
            kinds::all(db, user)
        })
        .await?;
    match kind {
        Some(kind) => changed(state, user, page, kind),
        None => state.tell(user, page, &PageEvent::Provider),
    }
    Ok(Json(all))
}

async fn sampling(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Sampling>> {
    state
        .run(move |db| kinds::sampling(db, user))
        .await
        .map(Json)
}

/// Keeps the values for a reply as they are typed: each in its range.
async fn set_sampling(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<Sampling>,
) -> ApiResult<Json<Sampling>> {
    let kept = state
        .run(move |db| kinds::keep_sampling(db, user, new))
        .await?;
    state.tell(user, &page, &PageEvent::Provider);
    Ok(Json(kept))
}

/// The models of This computer's folder and Cardwave's list, with whether
/// each fits this computer's memory.
async fn fitting(State(state): State<AppState>, Owner(user): Owner) -> ApiResult<Json<FitView>> {
    let folder = state.run(move |db| kinds::folder(db, user)).await?;
    fit_view(&state, &folder)
}

/// The models of `folder` and Cardwave's list, as `fitting` answers them.
fn fit_view(state: &AppState, folder: &std::path::Path) -> ApiResult<Json<FitView>> {
    Ok(Json(state.fit.list(folder)?))
}

/// Starts the download of a model of Cardwave's list into This computer's
/// folder; one too large for this computer, or there already, is refused.
async fn download(
    State(state): State<AppState>,
    Owner(user): Owner,
    Path(file): Path<String>,
) -> ApiResult<Json<FitView>> {
    let folder = state.run(move |db| kinds::folder(db, user)).await?;
    if let Some(stop) = state.fit.begin(&file, &folder)? {
        let (fetching, folder) = (state.clone(), folder.clone());
        tokio::spawn(async move {
            let told = || fetching.push(user, &PageEvent::LocalModels);
            fetching.fit.fetch(&file, &folder, &stop, told).await;
        });
    }
    state.push(user, &PageEvent::LocalModels);
    fit_view(&state, &folder)
}

/// Cancels a model's download, where one runs.
async fn cancel(
    State(state): State<AppState>,
    Owner(user): Owner,
    Path(file): Path<String>,
) -> ApiResult<Json<FitView>> {
    let folder = state.run(move |db| kinds::folder(db, user)).await?;
    state.fit.cancel(&file, &folder);
    fit_view(&state, &folder)
}

/// Removes a model of Cardwave's list from This computer's folder; the kinds
/// at it stay, as when the folder changes.
async fn remove_model(
    State(state): State<AppState>,
    Owner(user): Owner,
    Path(file): Path<String>,
) -> ApiResult<Json<FitView>> {
    let folder = state.run(move |db| kinds::folder(db, user)).await?;
    state.fit.remove(&file, &folder).await?;
    state.push(user, &PageEvent::LocalModels);
    fit_view(&state, &folder)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/kinds.rs"));

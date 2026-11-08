//! 3D figures over HTTP (`figures`).
//!
//! `GET /api/figures` lists the figures outside the Trash ("Add a 3D figure"); `GET …/{id}/file` is a figure's file
//! and `GET …/{id}/still` its still; `PATCH` and `DELETE …/{id}` are `held`'s. A card's:
//! `GET /api/cards/{id}/figures` is its figure and its modes';
//! `PUT` with `figure` (or none) and `mode` (or none, the card's own) gives it one the app holds or takes it off,
//! `POST` with a file ("From a file…") keeps a figure once and gives it so; both answer the one before, for Undo.
//! `GET /api/companion/figure` is the figure the companion shows, or none (its robot).

use axum::extract::{DefaultBodyLimit, Path, State};
use axum::response::Response;
use axum::routing::get;
use axum::{Json, Router};
use cw_chat::figures::{
    self, CardFigureChanged, CardFigures, Figure, MAX_FIGURE, NewFigure, SetCardFigure,
};
use cw_library::trash;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/figures", get(list))
        .route(
            "/api/figures/{id}",
            super::held::routes(
                |db, user, id, on| figures::set_trashed(db, user, id, on),
                |db, user, id| trash::delete_figure(db, user, id),
            ),
        )
        .route("/api/figures/{id}/file", get(file))
        .route("/api/figures/{id}/still", get(still))
        .route(
            "/api/cards/{id}/figures",
            get(of_card)
                .put(put_on_card)
                .post(from_file)
                // The file and its still in base64, with room for the rest.
                .layer(DefaultBodyLimit::max(MAX_FIGURE / 3 * 4 + 8 * 1024 * 1024)),
        )
        .route("/api/companion/figure", get(companion))
}

async fn list(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Vec<Figure>>> {
    state.run(move |db| figures::list(db, user)).await.map(Json)
}

async fn bytes(state: AppState, user: i64, id: i64, still: bool) -> ApiResult<Response> {
    let (kind, data) = state
        .run(move |db| figures::bytes(db, user, id, still))
        .await?;
    Ok(super::fresh_file(kind, data))
}

async fn file(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    bytes(state, user, id, false).await
}

async fn still(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    bytes(state, user, id, true).await
}

async fn of_card(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<CardFigures>> {
    state
        .run(move |db| figures::of_card(db, user, id))
        .await
        .map(Json)
}

async fn put_on_card(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(asked): Json<SetCardFigure>,
) -> ApiResult<Json<CardFigureChanged>> {
    super::cards::card_changed(&state, user, &page, id, move |db| {
        figures::put_on_card(db, user, id, &asked)
    })
    .await
}

async fn from_file(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<NewFigure>,
) -> ApiResult<Json<CardFigureChanged>> {
    super::cards::card_changed(&state, user, &page, id, move |db| {
        figures::import_for_card(db, user, id, new)
    })
    .await
}

async fn companion(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Option<Figure>>> {
    state
        .run(move |db| figures::companion(db, user))
        .await
        .map(Json)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/figures.rs"));

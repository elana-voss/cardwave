//! Expression packs over HTTP (`expressions`).
//!
//! `GET /api/expressions` lists the packs outside the Trash ("Add expressions"); `GET …/{id}/{mood}` is one of a
//! pack's pictures; `PATCH` and `DELETE …/{id}` are `held`'s. A card's: `GET /api/cards/{id}/expressions` is
//! its pack or none, `PUT` with `pack` (or none) gives it one the app holds or takes it off, `POST` with files
//! ("From a file…") keeps a pack once and gives it the card; both answer the pack it had, for Undo.
//! `GET /api/messages/{id}/expression` is the picture of a reply's mood, which the chat's portrait shows.

use axum::extract::{DefaultBodyLimit, Path, State};
use axum::response::Response;
use axum::routing::get;
use axum::{Json, Router};
use cw_find::mood::{self, Expression};
use cw_library::expressions::{self, CardExpressions, ExpressionPack, NewPack};
use cw_library::trash;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

/// The largest body of files for a pack, in base64.
const MAX_FILES: usize = 300 * 1024 * 1024;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/expressions", get(list))
        .route(
            "/api/expressions/{id}",
            super::held::routes(
                |db, user, id, on| expressions::set_trashed(db, user, id, on),
                |db, user, id| trash::delete_expression_pack(db, user, id),
            ),
        )
        .route("/api/expressions/{id}/{mood}", get(picture))
        .route(
            "/api/cards/{id}/expressions",
            get(of_card)
                .put(put_on_card)
                .post(from_files)
                .layer(DefaultBodyLimit::max(MAX_FILES)),
        )
        .route("/api/messages/{id}/expression", get(of_message))
}

/// The pack a card is to have, or none.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetCardExpressions {
    pub pack: Option<i64>,
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Vec<ExpressionPack>>> {
    state
        .run(move |db| expressions::list(db, user))
        .await
        .map(Json)
}

async fn picture(
    State(state): State<AppState>,
    User(user): User,
    Path((id, mood)): Path<(i64, String)>,
) -> ApiResult<Response> {
    let (kind, data) = state
        .run(move |db| expressions::picture(db, user, id, &mood))
        .await?;
    Ok(super::fresh_file(kind, data))
}

async fn of_card(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Option<ExpressionPack>>> {
    state
        .run(move |db| expressions::of_card(db, user, id))
        .await
        .map(Json)
}

async fn put_on_card(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(asked): Json<SetCardExpressions>,
) -> ApiResult<Json<CardExpressions>> {
    super::cards::card_changed(&state, user, &page, id, move |db| {
        expressions::put_on_card(db, user, id, asked.pack)
    })
    .await
}

async fn from_files(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<NewPack>,
) -> ApiResult<Json<CardExpressions>> {
    super::cards::card_changed(&state, user, &page, id, move |db| {
        expressions::import_for_card(db, user, id, new)
    })
    .await
}

async fn of_message(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Expression>> {
    Ok(Json(mood::shown_for(&state, user, id).await?))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/expressions.rs"));

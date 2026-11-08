//! Documents over HTTP (`documents.rs` holds the rest).
//!
//! `POST /api/chats/{id}/documents` and `POST /api/cards/{id}/documents` take
//! the file as the body and its name in `?name=`; `GET /api/documents`,
//! `DELETE /api/documents/{id}` and `POST /api/documents/{id}/restore` serve
//! Knowledge › Documents. Every change, and every document the search model
//! has read, is pushed as `documents`; one added or put back has the model
//! read it (`find::reader::read_cards`, which reads documents after the cards).

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, Query, State};
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_chat::documents::{self, DocumentView, FILE_LIMIT, Owner};
use cw_core::{Events, PageEvent};
use cw_find::reader;
use serde::Deserialize;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    let upload = DefaultBodyLimit::max(FILE_LIMIT);
    Router::new()
        .route("/api/documents", get(list))
        .route("/api/documents/{id}", axum::routing::delete(delete))
        .route("/api/documents/{id}/restore", post(restore))
        .route("/api/chats/{id}/documents", post(to_chat).layer(upload))
        .route("/api/cards/{id}/documents", post(to_card).layer(upload))
}

#[derive(Deserialize)]
struct FileName {
    name: String,
}

async fn to_chat(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(named): Query<FileName>,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<DocumentView>)> {
    add(state, user, Owner::Chat(id), named.name, file).await
}

async fn to_card(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(named): Query<FileName>,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<DocumentView>)> {
    add(state, user, Owner::Card(id), named.name, file).await
}

async fn add(
    state: AppState,
    user: i64,
    owner: Owner,
    name: String,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<DocumentView>)> {
    let added = state
        .run(move |db| {
            let text = documents::text_of(&name, &file)?;
            documents::add(db, user, owner, &name, &text)
        })
        .await?;
    told(&state, user);
    Ok((StatusCode::CREATED, Json(added)))
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Vec<DocumentView>>> {
    Ok(Json(state.run(move |db| documents::list(db, user)).await?))
}

async fn delete(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state.run(move |db| documents::delete(db, user, id)).await?;
    told(&state, user);
    Ok(StatusCode::NO_CONTENT)
}

async fn restore(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<DocumentView>> {
    let back = state
        .run(move |db| documents::restore(db, user, id))
        .await?;
    told(&state, user);
    Ok(Json(back))
}

/// Tells the user's pages, and has the search model read what it has not.
pub(super) fn told(state: &AppState, user: i64) {
    state.push(user, &PageEvent::Documents);
    reader::read_cards(state);
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/documents.rs"));

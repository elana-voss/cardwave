//! Attachments over HTTP (`attachments` holds the rest).
//!
//! `POST /api/chats/{id}/attachments` takes the file as the body and its name
//! in `?name=`, and answers the attachment, waiting for the message, 201: a
//! picture once the chat model is known to see it (400 where it cannot, 424
//! without a provider; a model that sees is asked once for the server's
//! life), else a document, kept for the chat too, which is pushed as `documents` and read by the search model. `DELETE
//! /api/attachments/{id}` takes off one that waits, its document with it (204
//! also where none waits);
//! `GET /api/attachments/{id}` is a picture. `POST /api/chats/{id}/messages`
//! (`api::chats`) gives the waiting ones it names to the message.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, Query, State};
use axum::http::StatusCode;
use axum::response::Response;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_chat::attachments::{self, Attachment};
use cw_chat::chats;
use cw_chat::documents::FILE_LIMIT;
use cw_core::{Code, Fail};
use cw_provider::{self as provider, NOT_SET_UP, check};
use serde::Deserialize;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/chats/{id}/attachments",
            post(attach).layer(DefaultBodyLimit::max(FILE_LIMIT)),
        )
        .route("/api/attachments/{id}", get(picture).delete(remove))
}

#[derive(Deserialize)]
struct FileName {
    name: String,
}

async fn attach(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(named): Query<FileName>,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<Attachment>)> {
    let name = named.name;
    if attachments::picture_type(&file).is_none() {
        let attached = state
            .run(move |db| attachments::attach_document(db, user, id, &name, &file))
            .await?;
        super::documents::told(&state, user);
        return Ok((StatusCode::CREATED, Json(attached.0)));
    }
    let provider = state
        .run(move |db| {
            chats::ensure_kept(db, user, id)?;
            Ok(provider::get(db, user)?.ok_or(NOT_SET_UP)?)
        })
        .await?;
    if !sees(&state, &provider).await? {
        let model = provider.model;
        return Err(Fail::new(Code::ModelSeesNoPictures)
            .with("model", model)
            .into());
    }
    let attached = state
        .run(move |db| attachments::attach_picture(db, user, id, &name, &file))
        .await?;
    Ok((StatusCode::CREATED, Json(attached)))
}

/// Whether the provider's model sees pictures, as `check::sees` answered
/// before or answers now. Only a yes is kept: a refusal costs nothing and may
/// pass (a local model still loading).
async fn sees(state: &AppState, provider: &provider::Provider) -> anyhow::Result<bool> {
    let model = (provider.base_url.clone(), provider.model.clone());
    if state.seeing().contains(&model) {
        return Ok(true);
    }
    let sees = check::sees(&state.http, provider).await?;
    if sees {
        state.seeing().insert(model);
    }
    Ok(sees)
}

async fn picture(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    let (kind, data) = state
        .run(move |db| attachments::picture(db, user, id))
        .await?;
    Ok(super::fresh_file(kind, data))
}

async fn remove(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    if state
        .run(move |db| attachments::remove(db, user, id))
        .await?
    {
        super::documents::told(&state, user);
    }
    Ok(StatusCode::NO_CONTENT)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/attachments.rs"));

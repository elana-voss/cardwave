//! Pictures over HTTP (`images`).
//!
//! `GET /api/images` is the account's image model (`null` while none is set
//! up; it is stored as every kind is, `api::kinds`); `POST /api/images/models`
//! the image models the address in the form lists, asked with the key that
//! would go there (`images::whom_listed`). `POST /api/chats/{id}/picture`
//! has a picture made for the chat and answers with its message, 201, once it
//! is there: the worker model writes its words (424 without a provider), the
//! image model makes it, which may take minutes on a ComfyUI, and nothing is
//! kept of one that failed. `GET /api/messages/{id}/picture` is the picture;
//! `POST` there makes it anew of the words given ("Make again"), which the
//! worker model writes out as typed words are, as another version of the message.
//! The message says the words typed, the image model gets the worker model's.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::Response;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_chat::chats::{self, MessageView};
use cw_chat::images::{self, ImageModelView};
use cw_core::{Code, Fail};
use cw_provider as provider;
use cw_provider::models::{ListModels, ListedModels};
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/images", get(show))
        .route("/api/images/models", post(list))
        .route("/api/chats/{id}/picture", post(make))
        .route("/api/messages/{id}/picture", get(picture).post(remake))
}

/// The words a picture in a chat is made anew of ("Make again").
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct MakeAgain {
    pub words: String,
}

/// A picture asked for in a chat.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct MakePicture {
    /// What it is to show, as the user typed it. Left out, it shows the scene
    /// of the newest messages.
    pub words: Option<String>,
    /// The chat character who sends it; the one the chat began with when left out.
    pub speaker_id: Option<i64>,
}

async fn show(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Option<ImageModelView>>> {
    state.run(move |db| images::get(db, user)).await.map(Json)
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<ListModels>,
) -> ApiResult<Json<ListedModels>> {
    let (base_url, key) = state
        .run(move |db| images::whom_listed(db, user, asked))
        .await?;
    Ok(Json(
        provider::images::listed(&state.http, &base_url, &key).await?,
    ))
}

async fn make(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<MakePicture>,
) -> ApiResult<(StatusCode, Json<MessageView>)> {
    let speaker = asked.speaker_id;
    let _at_work = state.at_work(user)?;
    let (worker, whom, inputs) = state
        .run(move |db| {
            // A chat that cannot take the picture's message says so before
            // anything is spent on it.
            chats::ensure_kept(db, user, id)?;
            chats::ensure_idle(db, id)?;
            let worker = provider::worker(db, user)?;
            let whom = images::whom(db, user)?;
            Ok((worker, whom, chats::prompt_inputs(db, user, id, speaker)?))
        })
        .await?;
    let typed = asked
        .words
        .as_deref()
        .map(str::trim)
        .filter(|typed| !typed.is_empty());
    let asked_for = images::asked_of(&inputs, typed);
    let words = images::words_of(&cw_provider::answer(&state.http, &worker, &asked_for).await?)?;
    let made = images::make(&state.http, &whom, &words).await?;
    let shown = typed.unwrap_or(&words).to_string();
    let message = state
        .run(move |db| {
            chats::view(
                db,
                user,
                images::keep(db, user, id, speaker, (&shown, &words), &made)?,
            )
        })
        .await?;
    Ok((StatusCode::CREATED, Json(message)))
}

/// Makes the picture of the message `id` anew of the words given, which the
/// worker model writes out with the character's looks, as another version of
/// that message; answers with it, 201, once it is there.
async fn remake(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<MakeAgain>,
) -> ApiResult<(StatusCode, Json<MessageView>)> {
    let words = asked.words.trim().to_string();
    if words.is_empty() {
        return Err(Fail::new(Code::PictureNeedsWords).into());
    }
    let _at_work = state.at_work(user)?;
    let (worker, whom, inputs) = state
        .run(move |db| {
            let (chat, speaker) = images::chat_of(db, user, id)?;
            let worker = provider::worker(db, user)?;
            let whom = images::whom(db, user)?;
            Ok((worker, whom, chats::prompt_inputs(db, user, chat, speaker)?))
        })
        .await?;
    let asked_for = images::asked_of(&inputs, Some(&words));
    let prompt = images::words_of(&cw_provider::answer(&state.http, &worker, &asked_for).await?)?;
    let made = images::make(&state.http, &whom, &prompt).await?;
    let message = state
        .run(move |db| {
            let again = images::keep_again(db, user, id, (&words, &prompt), &made)?;
            chats::view(db, user, again)
        })
        .await?;
    Ok((StatusCode::CREATED, Json(message)))
}

async fn picture(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    let picture = state.run(move |db| images::picture(db, user, id)).await?;
    Ok(super::fresh_file(picture.mime, picture.data))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/images.rs"));

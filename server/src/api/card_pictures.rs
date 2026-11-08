//! A card's pictures over HTTP (`cards::pictures`).
//!
//! `GET /api/cards/{id}/pictures` lists them ("Earlier pictures"), the one in use
//! first; `GET …/pictures/{picture}` is one. `POST …/pictures` with a PNG, JPEG
//! or WebP body makes it the card's; `PUT /api/cards/{id}/picture` shows one it
//! has; both answer the new version and the picture before, for Undo. "Make a
//! picture": `POST …/pictures/words` has the worker model write what the picture
//! shows (424 without a provider, 400 without an image model), `POST
//! …/pictures/made` has the image model draw it and keeps it unshown (201). A
//! picture made the card's tells the user's other pages (`cards::told`).
//!
//! Trap: a picture is made a PNG off the database (`spawn_blocking`); a
//! picture's number may come again after its card was deleted, so it is asked
//! for anew each time.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, State};
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_chat::images::{self, Shape};
use cw_core::{Code, Fail};
use cw_library::cards::pictures::{CardPicture, PictureChanged};
use cw_library::cards::{self, pictures};
use cw_library::describe;
use cw_provider::{self as provider, NOT_SET_UP};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

/// Largest picture file taken, as large as a card file may be.
const MAX_PICTURE: usize = 100 * 1024 * 1024;
/// The most characters of the words a picture is made from, as the dialog's field takes them.
const MAX_WORDS: usize = 1000;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/cards/{id}/pictures",
            get(list).merge(post(from_file).layer(DefaultBodyLimit::max(MAX_PICTURE))),
        )
        .route("/api/cards/{id}/pictures/{picture}", get(picture))
        .route("/api/cards/{id}/picture", put(use_picture))
        .route("/api/cards/{id}/pictures/words", post(words))
        .route("/api/cards/{id}/pictures/made", post(made))
}

/// One of the card's pictures to show.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct UsePicture {
    pub picture: i64,
}

/// What the worker model wrote that the card's picture shows, and who draws it.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct PictureWords {
    pub words: String,
    /// The image model's provider, as Settings names it (empty for a server on this computer, which the page words).
    pub provider: String,
}

/// A picture to be made for a card, of the words the dialog holds.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct MakeCardPicture {
    pub words: String,
}

async fn list(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Vec<CardPicture>>> {
    state
        .run(move |db| pictures::list(db, user, id))
        .await
        .map(Json)
}

async fn picture(
    State(state): State<AppState>,
    User(user): User,
    Path((id, picture)): Path<(i64, i64)>,
) -> ApiResult<Response> {
    let data = state
        .run(move |db| pictures::picture(db, user, id, picture))
        .await?;
    let headers = [
        (header::CONTENT_TYPE, "image/png"),
        (header::CACHE_CONTROL, "private, no-cache"),
    ];
    Ok((headers, data).into_response())
}

/// A picture file as a card keeps it, made away from the database.
async fn as_png(file: impl AsRef<[u8]> + Send + 'static) -> ApiResult<Vec<u8>> {
    Ok(tokio::task::spawn_blocking(move || pictures::as_png(file.as_ref())).await??)
}

async fn from_file(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    file: Bytes,
) -> ApiResult<Json<PictureChanged>> {
    let png = as_png(file).await?;
    let changed = state
        .run(move |db| pictures::use_file(db, user, id, &png))
        .await?;
    super::cards::told(&state, user, &page, id);
    Ok(Json(changed))
}

async fn use_picture(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(asked): Json<UsePicture>,
) -> ApiResult<Json<PictureChanged>> {
    let changed = state
        .run(move |db| pictures::use_picture(db, user, id, asked.picture))
        .await?;
    super::cards::told(&state, user, &page, id);
    Ok(Json(changed))
}

async fn words(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<PictureWords>> {
    let (worker, whom, card, character) = state
        .run(move |db| {
            let (card, _) = cards::newest(db, user, id)?;
            anyhow::ensure!(!card.trashed, Fail::new(Code::CardTrashed));
            let worker = provider::for_work(db, user)?.ok_or(NOT_SET_UP)?;
            let whom = images::whom(db, user)?;
            let document = cards::document_of(db, card.version_id)?;
            let character = document
                .characters()
                .first()
                .map(|first| document.character_name(first))
                .unwrap_or_default();
            Ok((worker, whom, describe::card_json(&document), character))
        })
        .await?;
    // The card is read whole or not at all, as for its description.
    describe::fits(&worker, images::CARD, &card.to_string())?;
    let asked = images::asked_of_card(&card, &character, &whom.model);
    let words = images::words_of(&cw_provider::answer(&state.http, &worker, &asked).await?)?;
    Ok(Json(PictureWords {
        words,
        provider: whom.provider,
    }))
}

async fn made(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(asked): Json<MakeCardPicture>,
) -> ApiResult<(StatusCode, Json<CardPicture>)> {
    let _at_work = state.at_work(user)?;
    let words = asked.words.trim().to_string();
    let count = words.chars().count();
    let whom = state
        .run(move |db| {
            anyhow::ensure!(count > 0, Fail::new(Code::PictureWordsMissing));
            anyhow::ensure!(
                count <= MAX_WORDS,
                Fail::new(Code::PictureWordsTooLong).with("most", MAX_WORDS)
            );
            let (card, _) = cards::newest(db, user, id)?;
            anyhow::ensure!(!card.trashed, Fail::new(Code::CardTrashed));
            images::whom(db, user)
        })
        .await?;
    let picture = images::make_shaped(&state.http, &whom, &words, Shape::Upright).await?;
    let png = as_png(picture.data).await?;
    let made = state
        .run(move |db| pictures::add_made(db, user, id, &png))
        .await?;
    Ok((StatusCode::CREATED, Json(made)))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/card_pictures.rs"));

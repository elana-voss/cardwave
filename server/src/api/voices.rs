//! The account's own voices and its characters' over HTTP (`voice::own`).
//!
//! `POST /api/voice/own?name=…` makes a voice of the recording in its body, a
//! WAV file of 16-bit PCM (the page makes one of a recording or of a file
//! chosen), brought to the shipped recordings' form (`voice::prepare`);
//! `PATCH`/`DELETE /api/voice/own/{id}` (the voice's id, `own-<n>`) rename and
//! delete one, the cards that read in it then reading in the account's voice.
//! `GET /api/voice/characters` lists the cards with a voice of their own;
//! `PUT`/`DELETE /api/voice/characters/{card}` set and take away one's, a
//! provider's voice too where Voice is at one (`voice::at`). Each
//! change is pushed as `voice` to the account's other pages.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, Query, State};
use axum::routing::{patch, post, put};
use axum::{Json, Router};
use cw_core::NotFound;
use cw_core::PageEvent;
use cw_voice::own::{self, CharacterVoice};
use serde::Deserialize;
use ts_rs::TS;

use super::voice::{VoiceChoice, VoiceModel, listed, state_of};
use super::{ApiResult, Page, User};
use crate::AppState;

/// The largest recording taken, in bytes: a minute of 16-bit stereo at 48 kHz
/// and more; what it keeps is at most `voice::LONGEST` seconds.
const RECORDING_LIMIT: usize = 16 * 1024 * 1024;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/voice/own",
            post(make).layer(DefaultBodyLimit::max(RECORDING_LIMIT)),
        )
        .route("/api/voice/own/{id}", patch(rename).delete(delete))
        .route("/api/voice/characters", axum::routing::get(characters))
        .route(
            "/api/voice/characters/{card}",
            put(set_character).delete(unset_character),
        )
}

#[derive(Deserialize)]
struct Named {
    name: String,
}

/// Makes a voice of the recording, named `name`.
async fn make(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Query(Named { name }): Query<Named>,
    recording: Bytes,
) -> ApiResult<Json<VoiceChoice>> {
    let name = own::name(&name)?;
    let recording = tokio::task::spawn_blocking(move || cw_voice::prepare(&recording)).await??;
    let made = state
        .run(move |db| own::add(db, user, &name, &recording))
        .await?;
    state.tell(user, &page, &PageEvent::Voice);
    Ok(Json(VoiceChoice::own(&made)))
}

/// A new name for a voice the account made.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct RenameVoice {
    pub name: String,
}

/// The number of the voice `id`, where it is one the account may have made.
fn number(id: &str) -> Result<i64, NotFound> {
    own::own_number(id).ok_or(NotFound("voice"))
}

async fn rename(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<String>,
    Json(renamed): Json<RenameVoice>,
) -> ApiResult<Json<VoiceModel>> {
    let (number, name) = (number(&id)?, own::name(&renamed.name)?);
    if !state
        .run(move |db| own::rename(db, user, number, &name))
        .await?
    {
        Err(NotFound("voice"))?;
    }
    state.tell(user, &page, &PageEvent::Voice);
    state_of(&state, user).await.map(Json)
}

async fn delete(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<String>,
) -> ApiResult<Json<VoiceModel>> {
    let number = number(&id)?;
    if !state
        .run(move |db| own::delete(db, user, number, &id))
        .await?
    {
        Err(NotFound("voice"))?;
    }
    state.tell(user, &page, &PageEvent::Voice);
    state_of(&state, user).await.map(Json)
}

async fn characters(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Vec<CharacterVoice>>> {
    state
        .run(move |db| own::characters(db, user))
        .await
        .map(Json)
}

/// The voice a card's character reads in.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetCharacterVoice {
    pub voice: String,
}

async fn set_character(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(card): Path<i64>,
    Json(set): Json<SetCharacterVoice>,
) -> ApiResult<Json<Vec<CharacterVoice>>> {
    listed(&state, user, &set.voice).await?;
    let set = state
        .run(move |db| own::set_character(db, user, card, Some(&set.voice)))
        .await?
        .ok_or(NotFound("card"))?;
    state.tell(user, &page, &PageEvent::Voice);
    Ok(Json(set))
}

async fn unset_character(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(card): Path<i64>,
) -> ApiResult<Json<Vec<CharacterVoice>>> {
    let left = state
        .run(move |db| own::set_character(db, user, card, None))
        .await?
        .ok_or(NotFound("card"))?;
    state.tell(user, &page, &PageEvent::Voice);
    Ok(Json(left))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/voices.rs"));

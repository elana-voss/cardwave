//! Voice over HTTP: the model's and its languages' downloads, and a text read
//! aloud. The account's and its characters' voices are `voices.rs`'s.
//!
//! `GET /api/voice` is the model's state, the voices (shipped, then own) and the
//! languages; `POST`/`DELETE /api/voice/download` start and cancel English's
//! download, `/api/voice/languages/{id}` another's, or removes it. Only this
//! computer's account downloads; each step is pushed as `voice` to every account;
//! each download (`fetching::Fetches`) is kept by its pack's id (`ENGLISH`). `GET
//! /api/voice/shipped` is the shipped voices, for "About Cardwave".
//! `POST /api/voice/speak` streams 16-bit mono samples at `voice::RATE`, sped by
//! `voice_speed`, in the AI's language where downloaded, else English
//! (`content-language`). One text at a time; one whose page has gone is not
//! begun, a dropped answer stops at the next piece; a failure before the first
//! sound is the answer, after it breaks off. The model loads at the first
//! reading and is let go `IDLE` after (about 1.5 GB). At a provider: `voice::at`.

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::body::{Body, Bytes};
use axum::extract::{Path, State};
use axum::http::header;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_core::NotFound;
use cw_core::{Code, ErrorBody, Fail};
use cw_core::{Events, PageEvent};
use cw_library::settings;
use cw_modelfiles::{self as fetching, Begun, DownloadState, Fetches};
use cw_platform::http::Client;
use cw_provider::Provider;
use cw_provider::kinds::{self, Kind};
use cw_voice::own::{self, Chosen};
use cw_voice::{self as voice, Part, Setup, Speak, Stretch};
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, Owner, User};
use crate::AppState;

/// How long the model stays loaded after its last reading.
const IDLE: Duration = Duration::from_secs(5 * 60);
/// The key of English's download among the downloads.
const ENGLISH: &str = "";

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/voice", get(show))
        .route("/api/voice/download", post(download).delete(cancel))
        .route(
            "/api/voice/languages/{id}",
            post(download_language).delete(remove_language),
        )
        .route("/api/voice/speak", post(speak))
        .route("/api/voice/shipped", get(shipped))
}

/// What speaks, with the folder of the language it reads.
type Loaded = (String, Box<dyn Speak>);

/// The voice of a server: where it comes from, how far its downloads are, and
/// what speaks once it is there.
pub struct Voice {
    setup: Setup,
    folder: PathBuf,
    http: Client,
    fetches: Fetches<String>,
    /// What speaks, with the folder of its language, loaded at the first
    /// reading; held while one reads.
    speaker: Mutex<Option<Loaded>>,
    /// How many readings have ended, so that the model is let go only after the last.
    readings: AtomicU64,
}

impl Voice {
    pub fn new(setup: Setup, data_dir: &std::path::Path) -> anyhow::Result<Self> {
        Ok(Self {
            setup,
            folder: voice::folder(data_dir),
            http: fetching::client()?,
            fetches: Fetches::default(),
            speaker: Mutex::default(),
            readings: AtomicU64::new(0),
        })
    }

    fn ready(&self) -> bool {
        self.setup.ready(&self.folder)
    }

    /// The parts of the pack `key` (English's or a language's), if there is one.
    fn parts(&self, key: &str) -> Option<&[Part]> {
        if key == ENGLISH {
            return Some(&self.setup.parts);
        }
        self.setup.language(key).map(|pack| pack.parts.as_slice())
    }
}

/// The voice's state, as Settings › Voices and the line "Voice" show it.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct VoiceModel {
    /// What English, the runtime and the recordings download, in bytes.
    pub size: u64,
    pub state: DownloadState,
    /// The bytes downloaded, while it downloads.
    pub done: u64,
    /// Why the last download failed; where Voice is at a provider, why its
    /// voices did not come.
    pub failure: Option<ErrorBody>,
    /// The sound's samples a second.
    pub rate: u32,
    /// The shipped voices, then the account's own, the oldest first.
    pub voices: Vec<VoiceChoice>,
    /// The languages besides English.
    pub languages: Vec<VoiceLanguage>,
    /// The language the account's messages are read in: the one the AI
    /// writes in where it is downloaded, else English.
    pub reads_in: String,
    /// Whether the account's voice is at a provider, which reads without a download.
    pub(crate) at_provider: bool,
}

/// A voice to choose, with the set its recording is of, the set's license and
/// whom it credits (`Voice::credit`); one the account made has `own` set, no
/// language, set or license.
#[derive(Default, Serialize, TS)]
#[ts(export)]
pub struct VoiceChoice {
    pub id: String,
    pub name: String,
    pub language: String,
    pub set: String,
    pub license: String,
    pub credit: String,
    pub own: bool,
}

impl VoiceChoice {
    pub fn own(voice: &own::OwnVoice) -> Self {
        Self {
            id: voice.voice_id(),
            name: voice.name.clone(),
            own: true,
            ..Self::default()
        }
    }
}

/// A language the voice reads besides English, and its download.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct VoiceLanguage {
    pub id: String,
    pub name: String,
    /// What it downloads, in bytes.
    pub size: u64,
    pub state: DownloadState,
    pub done: u64,
    pub failure: Option<ErrorBody>,
}

/// The voice's state for `user`: this computer's voices with the user's own,
/// or where Voice is at a provider, the provider's.
pub(crate) async fn state_of(state: &AppState, user: i64) -> ApiResult<VoiceModel> {
    let (own, language, at) = state
        .run(move |db| {
            let at = kinds::provider_of(db, user, Kind::Voice)?;
            Ok((own::all(db, user)?, settings::get(db, user)?.language, at))
        })
        .await?;
    let at_provider = at.is_some();
    let (listed, unlisted) = match &at {
        Some(provider) => match voice::at::voices(&state.voice.http, provider).await {
            Ok(listed) => (listed, None),
            Err(why) => (
                Vec::new(),
                Some(crate::api::body_of(&why, Code::RequestFailed)),
            ),
        },
        None => (Vec::new(), None),
    };
    let mut voices: Vec<VoiceChoice> = match &at {
        Some(provider) => listed
            .into_iter()
            .map(|name| VoiceChoice {
                id: format!("{}{name}", voice::at::PREFIX),
                name,
                set: provider.model.clone(),
                ..VoiceChoice::default()
            })
            .collect(),
        None => shipped_voices(),
    };
    if at.is_none() {
        voices.extend(own.iter().map(VoiceChoice::own));
    }
    let voice = &state.voice;
    let (english, done, failure) = voice.fetches.state_of(&ENGLISH.into(), voice.ready());
    let languages = voice
        .setup
        .languages
        .iter()
        .map(|pack| {
            let (state, done, failure) =
                voice.fetches.state_of(&pack.id, pack.ready(&voice.folder));
            VoiceLanguage {
                id: pack.id.clone(),
                name: pack.name.clone(),
                size: pack.size(),
                state,
                done,
                failure,
            }
        })
        .collect();
    Ok(VoiceModel {
        size: voice.setup.size(),
        state: english,
        done,
        failure: if at_provider { unlisted } else { failure },
        rate: voice::RATE,
        voices,
        languages,
        reads_in: voice.setup.reads_in(&voice.folder, &language).1.into(),
        at_provider,
    })
}

/// The voices Cardwave ships, wherever the account's Voice is.
fn shipped_voices() -> Vec<VoiceChoice> {
    voice::all()
        .map(|voice| VoiceChoice {
            id: voice.id.into(),
            name: voice.name.into(),
            language: voice.language.into(),
            set: voice.set.into(),
            license: voice.license.into(),
            credit: voice.credit(),
            own: false,
        })
        .collect()
}

/// The shipped voices with their licences, for "About Cardwave".
async fn shipped(User(_): User) -> Json<Vec<VoiceChoice>> {
    Json(shipped_voices())
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<VoiceModel>> {
    state_of(&state, user).await.map(Json)
}

/// Refuses `id` where it names a provider's voice (`voice::at::PREFIX`) that
/// the account's provider of Voice does not list; this computer's voices are
/// checked where they are kept (`own::known`).
pub async fn listed(state: &AppState, user: i64, id: &str) -> ApiResult<()> {
    let Some(name) = id.strip_prefix(voice::at::PREFIX) else {
        return Ok(());
    };
    let at = state
        .run(move |db| kinds::provider_of(db, user, Kind::Voice))
        .await?;
    let listed = match at {
        Some(provider) => voice::at::voices(&state.voice.http, &provider).await?,
        None => Vec::new(),
    };
    if !listed.iter().any(|voice| voice == name) {
        Err(Fail::new(Code::UnknownVoice).with("voice", id))?;
    }
    Ok(())
}

/// Starts the download of the pack `key`, unless all of it is there or it downloads already.
fn start(state: &AppState, key: &str) {
    let voice = &state.voice;
    let Some(parts) = voice.parts(key) else {
        return;
    };
    if voice::ready_in(parts, &voice.folder) {
        return;
    }
    if let Begun::Started(stop) = voice.fetches.begin(&key.to_string()) {
        let (state, key) = (state.clone(), key.to_string());
        tokio::spawn(async move {
            let voice = &state.voice;
            let parts = voice.parts(&key).unwrap_or_default();
            let told = || state.push_all(&PageEvent::Voice);
            (voice.fetches)
                .fetch(
                    &key,
                    &voice.http,
                    parts,
                    &voice.folder,
                    &stop,
                    "the voice",
                    told,
                )
                .await;
        });
    }
}

/// Starts English's download.
async fn download(
    State(state): State<AppState>,
    Owner(user): Owner,
) -> ApiResult<Json<VoiceModel>> {
    start(&state, ENGLISH);
    state.push_all(&PageEvent::Voice);
    state_of(&state, user).await.map(Json)
}

/// Stops the pack `key`'s download where it runs; whether it ran.
fn stop(state: &AppState, key: &str) -> bool {
    state.voice.fetches.cancel(&key.to_string())
}

async fn cancel(State(state): State<AppState>, Owner(user): Owner) -> ApiResult<Json<VoiceModel>> {
    stop(&state, ENGLISH);
    state_of(&state, user).await.map(Json)
}

/// Starts the download of the language `id`.
async fn download_language(
    State(state): State<AppState>,
    Owner(user): Owner,
    Path(id): Path<String>,
) -> ApiResult<Json<VoiceModel>> {
    state
        .voice
        .setup
        .language(&id)
        .ok_or(NotFound("language"))?;
    start(&state, &id);
    state.push_all(&PageEvent::Voice);
    state_of(&state, user).await.map(Json)
}

/// Cancels the language `id`'s download where it runs, else removes its files,
/// letting go of its model first where it is loaded.
async fn remove_language(
    State(state): State<AppState>,
    Owner(user): Owner,
    Path(id): Path<String>,
) -> ApiResult<Json<VoiceModel>> {
    state
        .voice
        .setup
        .language(&id)
        .ok_or(NotFound("language"))?;
    if !stop(&state, &id) {
        let (removing, key) = (state.clone(), id.clone());
        let failed = tokio::task::spawn_blocking(move || {
            let voice = &removing.voice;
            let mut speaker = cw_core::lock(&voice.speaker);
            if speaker
                .as_ref()
                .is_some_and(|(language, _)| *language == id)
            {
                *speaker = None;
            }
            let folder = voice.folder.join(&id);
            match std::fs::remove_dir_all(&folder) {
                Err(failure) if failure.kind() != std::io::ErrorKind::NotFound => Err(failure),
                _ => Ok(()),
            }
        })
        .await?;
        failed?;
        // A download started meanwhile stays; only a failed one's word goes.
        state.voice.fetches.forget_failure(&key);
        state.push_all(&PageEvent::Voice);
    }
    state_of(&state, user).await.map(Json)
}

/// A text to read aloud, in the voice `voice`, else in the voice of the card
/// `card` (the character's whose message it is), else in the account's.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct SpeakText {
    pub text: String,
    pub voice: Option<String>,
    pub card: Option<i64>,
}

/// What the reading hands the answer: sound, or why it failed.
enum Piece {
    Sound(Bytes),
    Failed(anyhow::Error),
}

/// `sound` as the answer sends it.
fn samples(sound: &[f32]) -> Bytes {
    cw_voice::pcm16(sound).into()
}

async fn speak(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<SpeakText>,
) -> ApiResult<Response> {
    let text = asked.text.trim().to_string();
    if text.is_empty() {
        Err(Fail::new(Code::NothingToRead))?;
    }
    let (settings, at, card) = state
        .run(move |db| {
            let at = kinds::provider_of(db, user, Kind::Voice)?;
            // This computer's voice reads the card's in `voice_of`.
            let card = match (asked.card, &at) {
                (Some(card), Some(_)) => own::card_voice(db, user, card)?,
                _ => None,
            };
            Ok((settings::get(db, user)?, at, card))
        })
        .await?;
    let speed = f64::from(settings.voice_speed) / 100.0;
    if let Some(provider) = at {
        let voices = [
            asked.voice.as_deref(),
            card.as_deref(),
            settings.voice.as_deref(),
        ];
        return speak_at(&state, &provider, &text, speed, voices, settings.language).await;
    }
    if !state.voice.ready() {
        Err(Fail::new(Code::VoiceNotDownloaded))?;
    }
    let (voice, card, account) = (asked.voice, asked.card, settings.voice.clone());
    let chosen = state
        .run(move |db| own::voice_of(db, user, voice.as_deref(), card, account.as_deref()))
        .await?;
    let recording = match &chosen {
        Chosen::Shipped(shipped) => {
            let voice = &state.voice;
            voice.setup.recording(&voice.folder, shipped)?
        }
        Chosen::Own { recording, .. } => recording.clone(),
    };
    let (language, code) = {
        let voice = &state.voice;
        let (language, _, code) = voice.setup.reads_in(&voice.folder, &settings.language);
        (language.to_string(), code.to_string())
    };
    let (sender, mut pieces) = tokio::sync::mpsc::channel::<Piece>(4);
    let reading = Reading {
        voice: chosen.id().to_string(),
        recording,
        text,
        language,
        speed,
    };
    let server = state.clone();
    let runtime = tokio::runtime::Handle::current();
    tokio::task::spawn_blocking(move || read_aloud(&server, reading, &sender, &runtime));
    let first = match pieces.recv().await {
        Some(Piece::Sound(sound)) => sound,
        Some(Piece::Failed(why)) => {
            let body = crate::api::body_of(&why, Code::VoiceFailed);
            return Ok((super::http_status(body.code), Json(body)).into_response());
        }
        None => Bytes::new(),
    };
    // A failure after the first sound breaks the answer off, so that the page does not take it as the end.
    let rest = futures_util::stream::unfold(pieces, |mut pieces| async move {
        match pieces.recv().await {
            Some(Piece::Sound(sound)) => Some((Ok(sound), pieces)),
            Some(Piece::Failed(why)) => {
                Some((Err(std::io::Error::other(format!("{why:#}"))), pieces))
            }
            None => None,
        }
    });
    let body = futures_util::stream::once(async { Ok(first) }).chain(rest);
    Ok(sound(code, Body::from_stream(body)))
}

/// Reads `text` at `provider`, in the first of `voices` it lists, else its own.
async fn speak_at(
    state: &AppState,
    provider: &Provider,
    text: &str,
    speed: f64,
    voices: [Option<&str>; 3],
    language: String,
) -> ApiResult<Response> {
    let http = &state.voice.http;
    let listed = voice::at::voices(http, provider).await?;
    let voice = voice::at::pick(&listed, &voices).map(str::to_string);
    let sound = voice::at::read(http, provider, text, speed, voice).await?;
    let body = Body::from_stream(sound.map(|piece| piece.map(Bytes::from)));
    Ok(self::sound(language, body))
}

/// The answer of a reading: its samples, `body`, in the language `code`.
fn sound(code: String, body: Body) -> Response {
    let kind = "application/octet-stream".to_string();
    (
        [
            (header::CONTENT_TYPE, kind),
            (header::CONTENT_LANGUAGE, code),
        ],
        body,
    )
        .into_response()
}

/// What one reading reads: in which voice and language, at which speed.
struct Reading {
    voice: String,
    recording: Vec<u8>,
    text: String,
    language: String,
    speed: f64,
}

/// Reads `reading` aloud on the blocking thread it is called on, its sound
/// handed to `sender` as it is made: the model of its language loaded first
/// where another (or none) is, and let go `IDLE` after the last reading.
fn read_aloud(
    server: &AppState,
    reading: Reading,
    sender: &tokio::sync::mpsc::Sender<Piece>,
    runtime: &tokio::runtime::Handle,
) {
    let voice = &server.voice;
    let mut speaker = cw_core::lock(&voice.speaker);
    if sender.is_closed() {
        return;
    }
    if speaker
        .as_ref()
        .is_none_or(|(had, _)| *had != reading.language)
    {
        // The model of another language is let go before this one is loaded.
        *speaker = None;
        match voice::load(&voice.setup, &voice.folder, &reading.language) {
            Ok(loaded) => *speaker = Some((reading.language.clone(), loaded)),
            Err(failure) => {
                // Its listener gone, nobody hears of it.
                let _ = sender.blocking_send(Piece::Failed(failure));
                return;
            }
        }
    }
    let Some((_, speaker)) = speaker.as_mut() else {
        return;
    };
    let mut stretch = Stretch::new(reading.speed);
    let read = speaker.speak(
        &reading.voice,
        &reading.recording,
        &reading.text,
        &mut |sound| {
            let sound = stretch.push(sound);
            sound.is_empty() || sender.blocking_send(Piece::Sound(samples(&sound))).is_ok()
        },
    );
    match read {
        Ok(()) => {
            let rest = stretch.finish();
            if !rest.is_empty() {
                // Its listener gone, nobody hears it.
                let _ = sender.blocking_send(Piece::Sound(samples(&rest)));
            }
        }
        Err(failure) => {
            tracing::warn!("reading aloud failed: {failure:#}");
            // Its listener gone, nobody hears of it.
            let _ = sender.blocking_send(Piece::Failed(failure));
        }
    }
    let ended = voice.readings.fetch_add(1, Ordering::Relaxed) + 1;
    // Held weakly: a server that is stopped meanwhile goes at once.
    let later = Arc::downgrade(&server.0);
    runtime.spawn(async move {
        tokio::time::sleep(IDLE).await;
        let Some(server) = later.upgrade() else {
            return;
        };
        let state = AppState(server);
        let voice = &state.voice;
        if voice.readings.load(Ordering::Relaxed) == ended
            && let Ok(mut speaker) = voice.speaker.try_lock()
        {
            *speaker = None;
        }
    });
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/voice.rs"));

//! Dictation over HTTP (`dictation.rs`).
//!
//! `GET /api/dictation` is the model's state; `POST`/`DELETE
//! /api/dictation/download` start and cancel its download and `DELETE
//! /api/dictation` stops and removes it, these three this computer's account's
//! alone; each step is pushed as `dictation` to every account. `POST
//! /api/dictation/hear` takes a WAV of at most `LONGEST` bytes and answers its
//! words, for every account; `POST /api/dictation/load` loads the model ahead,
//! as the page's microphone is pressed (a first load took 26 s in the smoke test).
//!
//! The model loads then or at the first hearing (2 s measured), hears one recording at a
//! time, and is let go `IDLE` after the last (it holds 0.9 GB of the graphics
//! card); a failed load is tried again at the next hearing. Loading and hearing
//! run on a blocking thread, the model taken out of its lock and put back by a
//! task of its own, which a request given up meanwhile does not end.

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_core::{Code, ErrorBody, Fail};
use cw_core::{Events, PageEvent};
use cw_dictation::{self as dictation, MODEL, Model, Setup};
use cw_modelfiles::{self as fetching, Begun, DownloadState, Fetches};
use cw_platform::http::Client;
use serde::Serialize;
use ts_rs::TS;

use super::{ApiResult, Owner, User};
use crate::AppState;

/// The largest recording taken, in bytes: two minutes of 16-bit sound at
/// 16,000 samples a second, as the page records, and room to spare.
const LONGEST: usize = 8 << 20;
/// How long the model stays after the last hearing.
const IDLE: Duration = Duration::from_secs(5 * 60);

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/dictation", get(show).delete(remove))
        .route("/api/dictation/download", post(download).delete(cancel))
        .route("/api/dictation/load", post(load))
        .route(
            "/api/dictation/hear",
            post(hear).layer(DefaultBodyLimit::max(LONGEST)),
        )
}

/// Dictation of a server: where its model comes from, how far its download
/// is, and the model while it runs.
pub struct Dictation {
    setup: Setup,
    folder: PathBuf,
    http: Client,
    fetches: Fetches<()>,
    /// The model while it is loaded; held while it hears.
    running: tokio::sync::Mutex<Option<Model>>,
    /// How many hearings have ended, so that the model is let go only after the last.
    heard: AtomicU64,
}

impl Dictation {
    pub fn new(setup: Setup, data_dir: &std::path::Path) -> anyhow::Result<Self> {
        Ok(Self {
            setup,
            folder: dictation::folder(data_dir),
            http: fetching::client()?,
            fetches: Fetches::default(),
            running: tokio::sync::Mutex::default(),
            heard: AtomicU64::new(0),
        })
    }

    fn ready(&self) -> bool {
        fetching::ready_in(&self.setup.parts, &self.folder)
    }
}

/// Dictation's state, as its line in Settings › Models and the message field show it.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct DictationModel {
    pub name: String,
    /// What it downloads, in bytes.
    pub size: u64,
    pub state: DownloadState,
    /// The bytes downloaded, while it downloads.
    pub done: u64,
    /// Why the last download failed.
    pub failure: Option<ErrorBody>,
}

fn state_of(state: &AppState) -> DictationModel {
    let dictation = &state.dictation;
    let (now, done, failure) = dictation.fetches.state_of(&(), dictation.ready());
    DictationModel {
        name: MODEL.into(),
        size: fetching::size_of(&dictation.setup.parts),
        state: now,
        done,
        failure,
    }
}

async fn show(State(state): State<AppState>, User(_): User) -> Json<DictationModel> {
    Json(state_of(&state))
}

/// Starts downloading the model, unless it is there or downloads already.
async fn download(State(state): State<AppState>, Owner(_): Owner) -> Json<DictationModel> {
    let dictation = &state.dictation;
    if !dictation.ready()
        && let Begun::Started(stop) = dictation.fetches.begin(&())
    {
        let state = state.clone();
        tokio::spawn(async move {
            let dictation = &state.dictation;
            let (http, parts) = (&dictation.http, &dictation.setup.parts);
            let told = || state.push_all(&PageEvent::Dictation);
            let what = "dictation's model";
            (dictation.fetches)
                .fetch(&(), http, parts, &dictation.folder, &stop, what, told)
                .await;
        });
    }
    state.push_all(&PageEvent::Dictation);
    Json(state_of(&state))
}

/// Cancels the download, if one runs.
async fn cancel(State(state): State<AppState>, Owner(_): Owner) -> Json<DictationModel> {
    state.dictation.fetches.cancel(&());
    Json(state_of(&state))
}

/// Stops the model and removes its files.
async fn remove(State(state): State<AppState>, Owner(_): Owner) -> ApiResult<Json<DictationModel>> {
    let dictation = &state.dictation;
    dictation.fetches.cancel(&());
    // The model is not started again while its files go: a hearing waits for the lock.
    let mut running = dictation.running.lock().await;
    // Let go of the graphics card's memory before the file goes.
    drop(running.take());
    for part in &dictation.setup.parts {
        fetching::remove_released(&dictation.folder.join(&part.path)).await?;
    }
    drop(running);
    dictation.fetches.forget_failure(&());
    state.push_all(&PageEvent::Dictation);
    Ok(Json(state_of(&state)))
}

/// What was said.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct Heard {
    pub text: String,
}

/// The words of the recording sent, a WAV file.
async fn hear(State(state): State<AppState>, User(_): User, wav: Bytes) -> ApiResult<Json<Heard>> {
    let samples = dictation::samples(&wav)?;
    let text = tokio::spawn(hear_in(state, samples)).await??;
    Ok(Json(Heard { text }))
}

/// Loads the model ahead, as the microphone is pressed, so the first
/// recording is heard as fast as the next; answers at once. Nothing where
/// it is not downloaded or is loaded already.
async fn load(State(state): State<AppState>, User(_): User) -> axum::http::StatusCode {
    tokio::spawn(async move {
        if let Err(failure) = use_model(state, None).await {
            tracing::warn!("dictation: the model cannot be loaded ahead: {failure:#}");
        }
    });
    axum::http::StatusCode::NO_CONTENT
}

/// Hears `samples` by the model, loaded if it is not; the model is let go
/// `IDLE` after the last hearing.
async fn hear_in(state: AppState, samples: Vec<f32>) -> anyhow::Result<String> {
    use_model(state, Some(samples))
        .await?
        .unwrap_or_else(|| Ok(String::new()))
}

/// The model loaded if it is not, and `samples` heard by it where given;
/// the model is let go `IDLE` after this, unless it is used again meanwhile.
async fn use_model(
    state: AppState,
    samples: Option<Vec<f32>>,
) -> anyhow::Result<Option<anyhow::Result<String>>> {
    let dictation = &state.dictation;
    let mut running = dictation.running.lock().await;
    // Checked under the lock, as a removal may have taken it first.
    if !dictation.ready() {
        return match samples {
            Some(_) => Err(Fail::new(Code::DictationNotSetUp).into()),
            None => Ok(None),
        };
    }
    let (setup, folder) = (dictation.setup.clone(), dictation.folder.clone());
    let loaded = running.take();
    // A panic in whisper.cpp leaves the model out, to be loaded again.
    let (model, text) = tokio::task::spawn_blocking(move || {
        let mut model = match loaded {
            Some(model) => model,
            None => Model::load(&setup, &folder)?,
        };
        let text = samples.map(|samples| model.hear(&samples));
        anyhow::Ok((model, text))
    })
    .await??;
    *running = Some(model);
    drop(running);
    let after = dictation.heard.fetch_add(1, Ordering::SeqCst) + 1;
    let later = state.clone();
    tokio::spawn(async move {
        tokio::time::sleep(IDLE).await;
        let dictation = &later.dictation;
        let mut running = dictation.running.lock().await;
        if dictation.heard.load(Ordering::SeqCst) == after {
            drop(running.take());
        }
    });
    Ok(text)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/dictation.rs"));

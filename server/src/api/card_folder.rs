//! A folder of cards imported over HTTP, this computer's account's alone (403 for another), as the folder is
//! this computer's: `POST /api/card-folder/import` with `{ "folder": … }` answers 202 at once (400 for no
//! folder, 409 with the one going on, which goes on), and a task of its own finds the card files, which can
//! take long in a large folder, and imports them; `GET` answers how far the last one came, `null` before any.
//! A file that holds no card is neither counted nor failed. `GET /api/card-folder/offered` answers the folder
//! first run offers: the folder of cards chosen, else the user's Documents folder (`Options::documents`),
//! `null` where neither is a folder.
//! The folder of cards in the settings is also watched ([`look`], every `Options::watch_every`, while
//! "Import new cards automatically" is on and no import of a folder goes on): a file in it is taken once
//! written completely (`cards/watch.rs`), imported quietly (a failure only logged, the pages told only of
//! cards imported) and not counted in `GET`'s import. Where the settings say so, a file imported, by either,
//! is moved to the Recycle Bin.
//!
//! Each file is imported in a blocking task of its own, so the database is held only while a card is stored
//! and every request in between is answered (measured: the work log's "A folder of cards: the import"). A
//! file the library has already is skipped by its fingerprint, one the watch took before and unchanged
//! since unread (`cards/folder.rs`). Pages are told at most once a second, and at
//! the end, as `card_folder`, not per card: thousands of cards would otherwise have every page read the list
//! thousands of times; then too the cards imported are queued to be described, where the settings say so,
//! and the search model reads them.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_find::place::Place;
use cw_library::cards::folder::{self, FailedFile, FolderImport, Outcome};
use cw_library::cards::watch::Watch;
use cw_library::settings::{self, CardFolder};
use serde::Deserialize;
use ts_rs::TS;

use super::cards::MAX_CARD_FILE;
use super::{ApiResult, Owner};
use crate::{AppState, AtWork};

/// How often the pages are told how far an import has come.
const TELL_EVERY: Duration = Duration::from_secs(1);

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/card-folder/import", post(start).get(show))
        .route("/api/card-folder/offered", get(offered))
}

/// The folder first run offers as the folder of cards: the one chosen, else (none chosen, or no folder) the
/// user's Documents folder.
async fn offered(
    State(state): State<AppState>,
    Owner(user): Owner,
) -> ApiResult<Json<Option<String>>> {
    let chosen = state
        .work(move |db| Ok(settings::get(db, user)?.card_folder.folder))
        .await?;
    for folder in [
        chosen.map(PathBuf::from),
        state.documents.as_deref().map(PathBuf::from),
    ]
    .into_iter()
    .flatten()
    {
        if is_folder(&folder).await {
            return Ok(Json(Some(folder.display().to_string())));
        }
    }
    Ok(Json(None))
}

/// Whether `path` is a folder that can be read.
async fn is_folder(path: &Path) -> bool {
    tokio::fs::metadata(path)
        .await
        .is_ok_and(|meta| meta.is_dir())
}

/// The folder whose cards are imported.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct ImportFolder {
    pub folder: String,
}

async fn show(State(state): State<AppState>, Owner(_): Owner) -> Json<Option<FolderImport>> {
    Json(state.card_folder().clone())
}

async fn start(
    State(state): State<AppState>,
    Owner(user): Owner,
    Json(asked): Json<ImportFolder>,
) -> ApiResult<(StatusCode, Json<FolderImport>)> {
    let folder = PathBuf::from(asked.folder.trim());
    if !is_folder(&folder).await {
        let fail = Fail::new(Code::NoSuchFolder).with("folder", folder.display().to_string());
        return Err(fail.into());
    }
    let begun = FolderImport {
        folder: folder.display().to_string(),
        running: true,
        ..FolderImport::default()
    };
    // Held to the import's end, so a restore or the account's delete waits for it.
    let work = state.at_work(user)?;
    {
        let mut held = state.card_folder();
        if let Some(going) = held.clone().filter(|going| going.running) {
            return Ok((StatusCode::CONFLICT, Json(going)));
        }
        *held = Some(begun.clone());
    }
    tokio::spawn(run(state.clone(), user, folder, work));
    state.push(user, &PageEvent::CardFolder);
    Ok((StatusCode::ACCEPTED, Json(begun)))
}

/// Finds the card files of `folder` and imports them one after the other, keeping how far it has come in
/// `card_folder`; however it ends, a panic too, the import is no longer going on and the pages are told.
async fn run(state: AppState, user: i64, folder: PathBuf, work: AtWork) {
    let held = state.clone();
    let ended = Place::new(move || {
        if let Some(going) = held.card_folder().as_mut() {
            going.running = false;
        }
        held.push(user, &PageEvent::CardFolder);
    });
    let looked = folder.clone();
    let walked = tokio::task::spawn_blocking(move || folder::card_files(&looked)).await;
    let files = match walked {
        Ok(Ok((files, failed))) => {
            if let Some(going) = state.card_folder().as_mut() {
                going.found = files.len() + failed.len();
                going.failed = failed;
            }
            files.into_iter().map(|(path, _)| path).collect()
        }
        failure => {
            let reason = match failure {
                Ok(Err(error)) => folder::unread(error),
                _ => Fail::new(Code::Internal).into(),
            };
            if let Some(going) = state.card_folder().as_mut() {
                going.found = 1;
                going.failed.push(FailedFile {
                    name: ".".to_string(),
                    reason,
                });
            }
            Vec::new()
        }
    };
    import_files(&state, user, folder, files, false).await;
    drop((ended, work));
}

/// Imports the card files put in the folder of cards since the last look (`watch`), where the settings
/// watch it, unless an import of a folder goes on.
pub(crate) async fn look(state: &AppState, watch: &mut Watch) {
    let user = state.local_user();
    let chosen = state
        .work(move |db| Ok(settings::get(db, user)?.card_folder))
        .await;
    let folder = match chosen {
        Ok(CardFolder {
            folder: Some(folder),
            watch: true,
            ..
        }) => PathBuf::from(folder),
        Ok(_) => return watch.forget(),
        Err(failure) => {
            return tracing::warn!("the folder of cards is not looked at: {failure:#}");
        }
    };
    if state
        .card_folder()
        .as_ref()
        .is_some_and(|going| going.running)
    {
        return;
    }
    // Not while a restore runs: the folder is looked at the next time.
    let Ok(_work) = state.at_work(user) else {
        return;
    };
    let (looked, mut held) = (folder.clone(), std::mem::take(watch));
    let walked = tokio::task::spawn_blocking(move || {
        let taken = held.look(&looked);
        (held, taken)
    })
    .await;
    // A folder gone, or not to be read, is looked for again the next time.
    let taken = match walked {
        Ok((held, Ok(taken))) => {
            *watch = held;
            taken
        }
        Ok((_, Err(failure))) => {
            return tracing::debug!("the folder of cards is not watched: {failure:#}");
        }
        Err(_) => return,
    };
    if !taken.is_empty() {
        import_files(state, user, folder, taken, true).await;
    }
}

/// Imports `files` of `folder` one after the other, each counted in `card_folder` but where `watched`
/// (then a failure is only logged), each moved to the Recycle Bin once imported where the settings say so.
async fn import_files(
    state: &AppState,
    user: i64,
    folder: PathBuf,
    files: Vec<PathBuf>,
    watched: bool,
) {
    let recycle = state
        .work(move |db| Ok(settings::get(db, user)?.card_folder.recycle))
        .await
        .unwrap_or_else(|failure| {
            tracing::warn!("no imported file is moved to the Recycle Bin: {failure:#}");
            false
        });
    let folder = std::sync::Arc::new(folder);
    let (mut told, mut fresh, mut queued) = (Instant::now(), false, false);
    for path in files {
        let (within, name) = (folder.clone(), path.display().to_string());
        let outcome = state
            .work(move |db| {
                let outcome = folder::import_file(db, user, &within, &path, MAX_CARD_FILE, watched);
                let queued = match &outcome {
                    Outcome::Imported(card) => {
                        if recycle && let Err(failure) = cw_platform::sys::recycle(&path) {
                            tracing::warn!("{failure:#}");
                        }
                        super::describe::queue_imported(db, user, card.card_id)
                            .inspect_err(|failure| {
                                tracing::warn!(
                                    "an imported card is not queued to be described: {failure:#}"
                                )
                            })
                            .unwrap_or(false)
                    }
                    _ => false,
                };
                Ok((outcome, queued))
            })
            .await;
        let (outcome, described) = outcome.unwrap_or_else(|failure| {
            // Only a task that panicked or was cancelled lands here.
            tracing::error!("{name} was not imported: {failure:#}");
            let reason = Fail::new(Code::Internal).into();
            (Outcome::Failed(FailedFile { name, reason }), false)
        });
        queued |= described;
        fresh |= matches!(outcome, Outcome::Imported(_));
        if watched {
            if let Outcome::Failed(file) = outcome {
                tracing::info!(
                    "{} of the folder of cards is not imported: {}",
                    file.name,
                    file.reason.error
                );
            }
        } else if let Some(going) = state.card_folder().as_mut() {
            match outcome {
                Outcome::Imported(_) => going.imported += 1,
                Outcome::Skipped => going.skipped += 1,
                Outcome::NotCard => going.found = going.found.saturating_sub(1),
                Outcome::Failed(file) => going.failed.push(file),
            }
        }
        if told.elapsed() >= TELL_EVERY {
            tell(
                state,
                user,
                !watched || fresh,
                std::mem::take(&mut fresh),
                std::mem::take(&mut queued),
            );
            told = Instant::now();
        }
    }
    // The folder's import tells its pages as it ends.
    tell(state, user, watched && fresh, fresh, queued);
}

/// Tells the user's pages how far the import has come where `push`; has the search model read the cards
/// imported where there are `fresh` ones, and the worker describe those `queued`.
fn tell(state: &AppState, user: i64, push: bool, fresh: bool, queued: bool) {
    if push {
        state.push(user, &PageEvent::CardFolder);
    }
    if fresh {
        cw_find::reader::read_cards(state);
        crate::faces::look(state);
    }
    if queued {
        super::describe::started(state, user);
    }
}

include!(concat!(env!("OUT_DIR"), "/route_tools/card_folder.rs"));

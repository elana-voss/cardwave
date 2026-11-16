//! Backups over HTTP (`backup.rs`).
//!
//! `POST /api/backup/save` is the backup, `cardwave-backup-<day>.cwbackup`, made
//! in the data folder and sent as it is read; a form's post, so the browser saves
//! it as it comes. Its field `password` seals it where no password is on (400
//! without one); where one is on, that one does. `POST /api/backup` takes one as
//! the body, its password in `x-cardwave-password`, percent-encoded (401 missing
//! or wrong), and replaces all the server holds: every page is told
//! (`restored`) and starts anew. A backup made while Cardwave asked for its
//! password on opening brings that lock back, with the password sent (`put_on`
//! of password.rs; where it cannot, the restore fails, to be tried again); one made
//! without leaves the lock here as it is. Not while any work is under way
//! (`AppState::busy`, a reply, a description, a memory pass, the search model's
//! reading and the rest). Both are this computer's
//! account's alone; a restore signs every page out and listens on the home
//! network as the backup says.
//!
//! Trap: the backup's file is deleted while open, so nothing stays behind;
//! Windows allows it, as Rust opens files so.

use std::sync::atomic::Ordering;

use anyhow::ensure;
use axum::Form;
use axum::Router;
use axum::body::Body;
use axum::extract::{DefaultBodyLimit, Request, State};
use axum::http::{HeaderMap, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::post;
use cw_accounts::{password, users};
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_store::backup;
use futures_util::StreamExt;
use percent_encoding::percent_decode_str;
use serde::Deserialize;
use tokio::io::AsyncWriteExt;

use super::{ApiResult, Owner};
use crate::AppState;

/// The header a restore is sent the backup's password in.
const PASSWORD_HEADER: &str = "x-cardwave-password";

/// The backup sent as it comes, in the data folder, with a mark of its own.
const UPLOAD: &str = "restore.upload";

/// A mark of chance for a file of one request.
fn mark() -> anyhow::Result<String> {
    cw_key::random_hex(8)
}

pub(super) fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/backup",
            post(restore).layer(DefaultBodyLimit::disable()),
        )
        .route("/api/backup/save", post(save))
}

/// What "Back up" sends.
#[derive(Deserialize)]
struct Asked {
    /// The backup's password, where none is on.
    password: Option<String>,
}

async fn save(
    State(state): State<AppState>,
    Owner(_): Owner,
    Form(asked): Form<Asked>,
) -> ApiResult<Response> {
    let (head, file) = tokio::task::spawn_blocking(move || -> anyhow::Result<_> {
        let inner = &state.0;
        let (sealed, locked) = match password::read(&inner.data_dir)? {
            Some((sealed, _)) => (sealed, true),
            None => {
                let password = asked.password.unwrap_or_default();
                ensure!(!password.is_empty(), Fail::new(Code::BackupNeedsPassword));
                (password::seal(&inner.key, &password)?, false)
            }
        };
        let path = inner.data_dir.join(format!("backup-{}.db", mark()?));
        let live = inner.data_dir.join(cw_key::FILE_NAME);
        let made = backup::snapshot(&live, &inner.key, sealed, locked, &path);
        let opened = made.and_then(|head| Ok((head, std::fs::File::open(&path)?)));
        // Gone once it is sent; where it could not be removed, it stays in the data folder.
        let _ = std::fs::remove_file(&path);
        opened
    })
    .await??;
    let size = head.len() as u64 + file.metadata()?.len();
    let rest = tokio_util::io::ReaderStream::new(tokio::fs::File::from_std(file));
    let body = Body::from_stream(futures_util::stream::once(async { Ok(head.into()) }).chain(rest));
    let name = file_name(&chrono::Local::now());
    let headers = [
        (header::CONTENT_TYPE, "application/octet-stream".to_string()),
        (header::CONTENT_LENGTH, size.to_string()),
        (
            header::CONTENT_DISPOSITION,
            format!("attachment; filename*=UTF-8''{name}"),
        ),
    ];
    Ok((headers, body).into_response())
}

/// The backup file's name by the day of `now`: the user's own day, as every
/// other date they see, handed the local clock.
fn file_name<Tz: chrono::TimeZone>(now: &chrono::DateTime<Tz>) -> String
where
    Tz::Offset: std::fmt::Display,
{
    let day = now.format("%Y-%m-%d");
    format!("cardwave-backup-{day}.cwbackup")
}

async fn restore(
    State(state): State<AppState>,
    Owner(_): Owner,
    headers: HeaderMap,
    request: Request,
) -> ApiResult<StatusCode> {
    let password = match headers.get(PASSWORD_HEADER) {
        Some(sent) => Some(
            percent_decode_str(sent.to_str()?)
                .decode_utf8()?
                .into_owned(),
        ),
        None => None,
    };
    let upload = state.data_dir.join(format!("{UPLOAD}-{}", mark()?));
    let mut out = tokio::fs::File::create(&upload).await?;
    let mut body = request.into_body().into_data_stream();
    let written = async {
        while let Some(piece) = body.next().await {
            out.write_all(&piece?).await?;
        }
        out.flush().await?;
        anyhow::Ok(())
    }
    .await;
    drop(out);
    let restored = match written {
        Ok(()) => {
            let state = state.clone();
            let upload = upload.clone();
            tokio::task::spawn_blocking(move || put_back(&state, &upload, password.as_deref()))
                .await?
        }
        Err(failure) => Err(failure),
    };
    // Not there, or left for `backup::remove_left` at the next start.
    let _ = tokio::fs::remove_file(&upload).await;
    restored?;
    state.push_all(&PageEvent::Restored);
    Ok(StatusCode::NO_CONTENT)
}

/// Restores the backup at `upload`, if nothing is at work on the data, and
/// does what a start does for data that was not this server's.
fn put_back(
    state: &AppState,
    upload: &std::path::Path,
    password: Option<&str>,
) -> anyhow::Result<()> {
    let inner = &state.0;
    let _held = cw_core::lock(&inner.guarded);
    ensure!(!state.busy(None), Fail::new(Code::RestoreBusy));
    let locked = backup::restore(&inner.db, &inner.key, upload, password, &inner.data_dir)?;
    inner.restores.fetch_add(1, Ordering::SeqCst);
    // The lock comes back at once with the password the backup was just opened by, so a stop
    // after this leaves the data behind it; its name is put right below.
    let lock = match (locked, password) {
        (true, Some(password)) => super::password::put_on(state, password, &inner.account_name),
        _ => Ok(()),
    };
    // At once, so a later failure leaves no switch of the data before.
    state.web_pictures().clear();
    // The data is the backup's now: each step that makes the server match it
    // runs whatever another comes to, and the restore is answered as done.
    // The backup's sessions are not this server's pages.
    let ended = state.sessions.end_every(&inner.db);
    // As at a start: a reply that was being written when the backup was made is ended, and so on.
    let tidied = crate::tidy(&inner.db, true);
    // No account where the backup's cannot be read (0 is none's number).
    let local = users::local(&inner.db, &inner.account_name);
    inner
        .local_user
        .store(*local.as_ref().unwrap_or(&0), Ordering::Relaxed);
    let renamed = local.and_then(|local| {
        password::rename(&inner.data_dir, &users::account(&inner.db, local)?.name)
    });
    for failure in [ended, tidied, renamed].into_iter().filter_map(Result::err) {
        tracing::error!("after a restore: {failure:#}");
    }
    // The backup is restored whatever its listener comes to.
    if let Some(gate) = state.gate()
        && let Err(failure) = cw_accounts::users::reached(&inner.db).and_then(|on| gate.listen(on))
    {
        tracing::warn!("{failure:#}");
    }
    // A lock that did not come back is said, never left open unsaid: the restore is tried again.
    lock
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/backup.rs"));

#[cfg(test)]
mod tests {
    #[test]
    fn the_file_is_named_by_the_local_day_just_after_midnight() {
        let now = chrono::DateTime::parse_from_rfc3339("2026-11-10T00:05:00+02:00").unwrap();
        assert_eq!(
            super::file_name(&now),
            "cardwave-backup-2026-11-10.cwbackup"
        );
    }
}

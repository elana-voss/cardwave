//! How far each of a part's downloads is (`Fetches`, kept by a key: a voice
//! pack's id, a model's file, or `()` for the one search model), and the
//! client they download with ([`client`]). A file's download is
//! [`download_file`]'s, a model of several files' (`Part`) [`download`]'s,
//! a zip unpacked where its part says; the rest is bookkeeping: [`Fetches::begin`]
//! marks one running and hands over what stops it, [`Fetches::progress`]
//! counts its bytes and tells at each hundredth, [`Fetches::finish`] forgets
//! it, or keeps why it failed where it did not end by [`Fetches::cancel`].
//!
//! Traps: a download being cancelled stays running until its task ends, and
//! is [`Begun::Stopping`] meanwhile; a failure's word stays until the next
//! download, or until [`Fetches::forget_failure`]. A model's file is deleted
//! by [`remove_released`], as Windows holds it a moment after its process.

use std::collections::HashMap;
use std::hash::Hash;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_core::{Code, ErrorBody, Fail};
use cw_platform::http::Client;
use serde::Serialize;
use sha2::{Digest, Sha256};
use tokio::io::{AsyncSeekExt, AsyncWriteExt};
use tokio::time::sleep;
use ts_rs::TS;

/// The client a download takes, which may take minutes: 30 s to connect,
/// 120 s of silence at most.
pub fn client() -> anyhow::Result<Client> {
    Ok(cw_platform::http::client(cw_platform::http::Make {
        connect: Some(Duration::from_secs(30)),
        silence: Some(Duration::from_secs(120)),
        ..Default::default()
    })?)
}

enum Fetch {
    Running { done: u64, stop: Arc<AtomicBool> },
    Failed(ErrorBody),
}

/// Where a download is.
#[derive(Clone, Debug, PartialEq)]
pub enum Seen {
    Idle,
    /// With the bytes done so far.
    Running(u64),
    /// With why it failed, as the UI words it.
    Failed(ErrorBody),
}

/// A downloaded model's state, as the UI shows it.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, TS)]
#[ts(export, rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum DownloadState {
    Absent,
    Downloading,
    Ready,
}

/// What [`Fetches::begin`] did.
pub enum Begun {
    /// It runs from now on, until this is set.
    Started(Arc<AtomicBool>),
    Running,
    /// One runs that is being cancelled.
    Stopping,
}

/// The downloads of a part, by their keys.
pub struct Fetches<K>(Mutex<HashMap<K, Fetch>>);

impl<K> Default for Fetches<K> {
    fn default() -> Self {
        Self(Mutex::default())
    }
}

impl<K: Eq + Hash + Clone> Fetches<K> {
    fn lock(&self) -> MutexGuard<'_, HashMap<K, Fetch>> {
        cw_core::lock(&self.0)
    }

    /// Marks `key` as downloading, unless it is already.
    pub fn begin(&self, key: &K) -> Begun {
        let mut fetches = self.lock();
        match fetches.get(key) {
            Some(Fetch::Running { stop, .. }) if stop.load(Ordering::Relaxed) => Begun::Stopping,
            Some(Fetch::Running { .. }) => Begun::Running,
            _ => {
                let stop = Arc::new(AtomicBool::new(false));
                let running = Fetch::Running {
                    done: 0,
                    stop: stop.clone(),
                };
                fetches.insert(key.clone(), running);
                Begun::Started(stop)
            }
        }
    }

    pub fn state(&self, key: &K) -> Seen {
        match self.lock().get(key) {
            None => Seen::Idle,
            Some(Fetch::Running { done, .. }) => Seen::Running(*done),
            Some(Fetch::Failed(why)) => Seen::Failed(why.clone()),
        }
    }

    /// `key`'s [`DownloadState`], the bytes done and why it failed;
    /// `ready` whether all of it is there.
    pub fn state_of(&self, key: &K, ready: bool) -> (DownloadState, u64, Option<ErrorBody>) {
        match self.state(key) {
            Seen::Running(done) => (DownloadState::Downloading, done, None),
            Seen::Failed(why) => (DownloadState::Absent, 0, Some(why)),
            Seen::Idle if ready => (DownloadState::Ready, 0, None),
            Seen::Idle => (DownloadState::Absent, 0, None),
        }
    }

    /// What [`download_file`] is told the bytes of `key`'s download of
    /// `size` bytes by: it keeps them and calls `told` at each hundredth.
    pub fn progress<'a>(
        &'a self,
        key: &'a K,
        size: u64,
        told: impl Fn() + 'a,
    ) -> impl FnMut(u64) + 'a {
        let step = (size / 100).max(1);
        let mut said = 0;
        move |done| {
            if let Some(Fetch::Running { done: had, .. }) = self.lock().get_mut(key) {
                *had = done;
            }
            if done >= said + step {
                said = done;
                told();
            }
        }
    }

    /// Ends `key`'s download as `fetched` says, logging a failure as that of `what`.
    pub fn finish(&self, key: &K, fetched: anyhow::Result<()>, what: &str) {
        let mut fetches = self.lock();
        match fetched {
            Err(failure) if !failure.is::<Cancelled>() => {
                tracing::warn!("the download of {what} failed: {failure:#}");
                fetches.insert(
                    key.clone(),
                    Fetch::Failed(cw_core::told(&failure, Code::DownloadFailed)),
                );
            }
            _ => {
                fetches.remove(key);
            }
        }
    }

    /// Runs `key`'s download of `parts` into `folder`, begun by
    /// [`Fetches::begin`] with `stop`, to its [`Fetches::finish`] (a failure
    /// logged as that of `what`); `told` at each hundredth and at the end.
    #[allow(clippy::too_many_arguments)] // Each is one thing of the download; a struct would only rename them.
    pub async fn fetch(
        &self,
        key: &K,
        http: &Client,
        parts: &[Part],
        folder: &Path,
        stop: &AtomicBool,
        what: &str,
        told: impl Fn(),
    ) {
        let progress = self.progress(key, size_of(parts), &told);
        let fetched = download(http, parts, folder, progress, stop).await;
        self.finish(key, fetched, what);
        told();
    }

    /// Stops `key`'s download; whether one ran.
    pub fn cancel(&self, key: &K) -> bool {
        match self.lock().get(key) {
            Some(Fetch::Running { stop, .. }) => {
                stop.store(true, Ordering::Relaxed);
                true
            }
            _ => false,
        }
    }

    /// Forgets why `key`'s last download failed; one running stays.
    pub fn forget_failure(&self, key: &K) {
        let mut fetches = self.lock();
        if matches!(fetches.get(key), Some(Fetch::Failed(..))) {
            fetches.remove(key);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_download_runs_once_and_keeps_only_its_failure() {
        let fetches = Fetches::default();
        let Begun::Started(stop) = fetches.begin(&"a") else {
            panic!("not started")
        };
        assert!(matches!(fetches.begin(&"a"), Begun::Running));
        let told = std::cell::Cell::new(0);
        let mut progress = fetches.progress(&"a", 1000, || told.set(told.get() + 1));
        progress(5);
        progress(10);
        drop(progress);
        assert_eq!((fetches.state(&"a"), told.get()), (Seen::Running(10), 1));
        assert!(fetches.cancel(&"a") && stop.load(Ordering::Relaxed));
        assert!(matches!(fetches.begin(&"a"), Begun::Stopping));
        fetches.finish(&"a", Err(Cancelled.into()), "a");
        assert_eq!(fetches.state(&"a"), Seen::Idle);
        fetches.begin(&"a");
        fetches.finish(&"a", Err(anyhow::anyhow!("gone")), "a");
        let Seen::Failed(why) = fetches.state(&"a") else {
            panic!("not failed")
        };
        assert_eq!(
            (why.code, why.error.as_str()),
            (Code::DownloadFailed, "gone")
        );
        fetches.forget_failure(&"a");
        assert!(!fetches.cancel(&"a") && fetches.state(&"a") == Seen::Idle);
    }
}

/// A file a model needs (the voice's, dictation's): where it comes from, and
/// where it is kept in the model's folder. Where `unpack` is set, the download is a zip and the file
/// kept is the one of that name in it.
#[derive(Clone, Debug)]
pub struct Part {
    pub file: ModelFile,
    pub path: String,
    pub unpack: Option<String>,
}

/// The bytes of `parts` together.
/// Deletes `file`, a model's that a process stopped just now held: Windows
/// lets go of it a moment after the process is gone. One not there is no
/// failure.
pub async fn remove_released(file: &Path) -> std::io::Result<()> {
    let mut tries = 0;
    loop {
        match tokio::fs::remove_file(file).await {
            Err(failure) if failure.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(failure) if tries < 20 => {
                tracing::debug!("{} is not deleted yet: {failure}", file.display());
                tries += 1;
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
            Err(failure) => return Err(failure),
            Ok(()) => return Ok(()),
        }
    }
}

pub fn size_of(parts: &[Part]) -> u64 {
    parts.iter().map(|part| part.file.size).sum()
}

/// Whether every file of `parts` is in `folder`.
pub fn ready_in(parts: &[Part], folder: &Path) -> bool {
    parts.iter().all(|part| folder.join(&part.path).exists())
}

/// Downloads into `folder` each file of `parts` that is not there yet, one
/// after the other, telling `told` the bytes there so far of all of them,
/// until `stop` is set.
pub async fn download(
    http: &Client,
    parts: &[Part],
    folder: &Path,
    mut told: impl FnMut(u64),
    stop: &AtomicBool,
) -> anyhow::Result<()> {
    let mut before = 0;
    for part in parts {
        let to = folder.join(&part.path);
        if !to.exists() {
            let fetched = match &part.unpack {
                None => to.clone(),
                Some(_) => to.with_extension("zip"),
            };
            if !fetched.exists() {
                download_file(http, &part.file, &fetched, |done| told(before + done), stop).await?;
            }
            if let Some(inside) = &part.unpack {
                let (zip, inside, to) = (fetched.clone(), inside.clone(), to.clone());
                let unpacked = tokio::task::spawn_blocking(move || unpack(&zip, &inside, &to));
                unpacked.await.context(Fail::new(Code::Internal))??;
                tokio::fs::remove_file(&fetched).await?;
            }
        }
        before += part.file.size;
        told(before);
    }
    Ok(())
}

/// Writes the file `inside` of the zip `zip` to `to`, by way of a file beside it.
fn unpack(zip: &Path, inside: &str, to: &Path) -> anyhow::Result<()> {
    let mut archive = zip::ZipArchive::new(std::fs::File::open(zip)?)?;
    let mut file = archive
        .by_name(inside)
        .with_context(|| format!("{inside} is not in the package"))?;
    let part = to.with_extension("part");
    std::io::copy(&mut file, &mut std::fs::File::create(&part)?)?;
    std::fs::rename(&part, to)?;
    Ok(())
}

/// The model's file: where it is downloaded from, and its size and SHA-256 in
/// lower-case hex, by which the download is checked.
#[derive(Clone, Debug)]
pub struct ModelFile {
    pub url: String,
    pub size: u64,
    pub sha256: String,
}

/// The download was cancelled; it is no failure.
#[derive(Debug)]
pub(crate) struct Cancelled;

impl std::fmt::Display for Cancelled {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("the download was cancelled")
    }
}

impl std::error::Error for Cancelled {}

/// Downloads `model` to `to`, telling `told` the bytes come so far, until
/// `stop` is set. What came is a file beside `to` until all of it is there
/// and checked; then it becomes `to`, and otherwise it is deleted. A
/// connection that drops is taken up again where it stopped (`fetch`), up to
/// `RETRIES` times, a second more to wait each time.
pub async fn download_file(
    http: &Client,
    model: &ModelFile,
    to: &Path,
    mut told: impl FnMut(u64),
    stop: &AtomicBool,
) -> anyhow::Result<()> {
    let part = to.with_extension("part");
    if let Some(folder) = to.parent() {
        tokio::fs::create_dir_all(folder).await?;
    }
    let fetched = async {
        let mut file = tokio::fs::File::create(&part).await?;
        let mut hash = Sha256::new();
        let mut done = 0;
        let mut broke = 0;
        // A connection that drops is taken up again where it stopped, a few times.
        while let Err(failure) = fetch(
            http, model, &mut file, &mut hash, &mut done, &mut told, stop,
        )
        .await
        {
            if !failure.is::<BrokeOff>() || broke == RETRIES {
                return Err(failure);
            }
            broke += 1;
            tracing::warn!(
                "the search model's download broke off at {done} bytes, try {broke}: {failure:#}"
            );
            tokio::select! {
                () = sleep(Duration::from_secs(broke)) => {}
                () = stopped(stop) => bail!(Cancelled),
            }
        }
        file.sync_all().await?;
        drop(file);
        let sum: String = hash
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect();
        ensure!(
            sum == model.sha256,
            Fail::said(Code::NotReadable, "the file downloaded is not the model")
                .with("what", "downloaded_model")
        );
        tokio::fs::rename(&part, to).await?;
        anyhow::Ok(())
    }
    .await;
    if fetched.is_err() {
        // The download's failure is what is told; a part left is written over by the next.
        let _ = tokio::fs::remove_file(&part).await;
    }
    fetched
}

/// How many times a download that broke off is taken up again.
const RETRIES: u64 = 5;

/// The connection dropped, or the server could not be reached: worth another try.
#[derive(Debug)]
struct BrokeOff(String);

impl std::fmt::Display for BrokeOff {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "the download broke off: {}", self.0)
    }
}

impl std::error::Error for BrokeOff {}

/// Downloads the rest of the model's file, from `done` bytes on (asked for
/// by `Range`, and from the start where the server sends all of it), into
/// `file` and `hash`, until the whole is there.
async fn fetch(
    http: &Client,
    model: &ModelFile,
    file: &mut tokio::fs::File,
    hash: &mut Sha256,
    done: &mut u64,
    told: &mut impl FnMut(u64),
    stop: &AtomicBool,
) -> anyhow::Result<()> {
    let broke =
        |failure: cw_platform::http::Error| anyhow::Error::new(BrokeOff(format!("{failure}")));
    let mut asked = http.get(&model.url);
    if *done > 0 {
        asked = asked.header(cw_platform::http::header::RANGE, format!("bytes={done}-"));
    }
    let response = asked.send().await.map_err(broke)?;
    if response.status().is_server_error() {
        bail!(BrokeOff(format!(
            "the server answered {}",
            response.status()
        )));
    }
    let mut response = response.error_for_status().context(
        Fail::said(Code::Unreachable, "the model's file cannot be downloaded")
            .with("whose", "model_download"),
    )?;
    if *done > 0 && response.status() != cw_platform::http::StatusCode::PARTIAL_CONTENT {
        // The whole file again: what came is thrown away.
        file.set_len(0).await?;
        file.seek(std::io::SeekFrom::Start(0)).await?;
        *hash = Sha256::new();
        *done = 0;
    }
    loop {
        let piece = tokio::select! {
            piece = response.chunk() => piece.map_err(broke)?,
            () = stopped(stop) => bail!(Cancelled),
        };
        let Some(piece) = piece else {
            break;
        };
        hash.update(&piece);
        file.write_all(&piece).await?;
        *done += piece.len() as u64;
        ensure!(
            *done <= model.size,
            Fail::said(Code::NotReadable, "the file downloaded is not the model")
                .with("what", "downloaded_model")
        );
        told(*done);
    }
    if *done < model.size {
        bail!(BrokeOff("it ended early".into()));
    }
    Ok(())
}

/// Ends when `stop` is set.
async fn stopped(stop: &AtomicBool) {
    while !stop.load(Ordering::Relaxed) {
        sleep(Duration::from_millis(100)).await;
    }
}

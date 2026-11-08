//! The search model's work, beside the server: this computer's model's download
//! and removal, the background reading of every card and document without
//! vectors of its user's model (`read_cards`), and the answers to a search
//! (`near`) and to a chat's memory and lorebook (`newest_vector`, `vectors`,
//! `memory_vectors`). Its HTTP is `api/search.rs`. An account's model is its
//! search kind's where at a provider, else this computer's (`reader_now`).
//!
//! `read_cards` reads cards, then documents, then Search Cardwave's texts
//! (`find.rs`), one task at a time (`Search::reading`), this computer's model
//! started for the first that needs it; steps are pushed as `search`. The
//! answers use this computer's model only where it runs, never wait for its
//! start, and a reply waits `REPLY_LIMIT` at most (a memory pass as long as it
//! takes). A model that fails or hangs is not asked for `RETRY` (this
//! computer's is stopped), a provider's until its entry or a kind changes
//! (`provider_changed`); a card it cannot read (`TextRefused`) is kept without.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use cw_chat::documents;
use cw_core::PageEvent;
use cw_core::{Code, ErrorBody, Fail};
use cw_library::cards;
use cw_modelfiles::{self as fetching, Begun, Fetches, Seen};
use cw_platform::http::Client;
use cw_provider::embedder::{self, At, MODEL, Reader, Running, Setup};
use cw_provider::kinds::{self, Kind};
use cw_search as search;

use crate::place::Place;
use crate::{Host, Storage, work};

/// The longest query given to the model, in characters; the words of a longer
/// one are still searched for.
const QUERY_LIMIT: usize = 400;
/// How long after it failed a model is not asked again.
const RETRY: Duration = Duration::from_secs(5 * 60);
/// How long a reply waits for the search model's vectors before it goes
/// without them.
const REPLY_LIMIT: Duration = Duration::from_secs(5);
/// How many pieces of a card the model is asked for at once: a long card's
/// whole would take minutes on a processor.
const BATCH: usize = 16;

/// A query read: its model's stamp, its text and its vector.
type LastQuery = (String, String, Arc<Vec<f32>>);

/// The search model of a server: where this computer's comes from and how far
/// it is, and how the models of every account fared.
pub struct Search {
    setup: Setup,
    /// The model's file, and the log of its process.
    file: PathBuf,
    log: PathBuf,
    /// The download's and the models' own client: a download takes minutes.
    http: Client,
    fetch: Fetches<()>,
    running: tokio::sync::Mutex<Option<Arc<Running>>>,
    /// Why each model, by its stamp, last failed to start or to answer, and when.
    failure: Mutex<HashMap<String, (ErrorBody, Instant)>>,
    /// Whether a task is reading cards.
    reading: Mutex<bool>,
    /// The last query read, by its model's stamp, and its vector.
    last: Mutex<Option<LastQuery>>,
}

impl Search {
    pub fn new(setup: Setup, data_dir: &std::path::Path) -> anyhow::Result<Self> {
        Ok(Self {
            setup,
            file: embedder::model_path(data_dir),
            log: data_dir.join("llama-server.log"),
            http: fetching::client()?,
            fetch: Fetches::default(),
            running: tokio::sync::Mutex::default(),
            failure: Mutex::default(),
            reading: Mutex::default(),
            last: Mutex::default(),
        })
    }

    fn ready(&self) -> bool {
        self.file.exists()
    }

    fn failure(&self) -> MutexGuard<'_, HashMap<String, (ErrorBody, Instant)>> {
        cw_core::lock(&self.failure)
    }

    /// Whether the model of `stamp` failed a short while ago: it is not asked again before `RETRY`.
    fn held_back(&self, stamp: &str) -> bool {
        self.failure()
            .get(stamp)
            .is_some_and(|(_, when)| when.elapsed() < RETRY)
    }

    /// The stamps of the models held back, and this computer's where it is not downloaded.
    fn skipped(&self) -> Vec<String> {
        let mut skip: Vec<String> = self
            .failure()
            .iter()
            .filter(|(_, (_, when))| when.elapsed() < RETRY)
            .map(|(stamp, _)| stamp.clone())
            .collect();
        if !self.ready() {
            skip.push(MODEL.to_string());
        }
        skip
    }

    fn last(&self) -> MutexGuard<'_, Option<LastQuery>> {
        cw_core::lock(&self.last)
    }

    /// Whether a task is reading cards.
    pub fn is_reading(&self) -> bool {
        *self.reading()
    }

    fn reading(&self) -> MutexGuard<'_, bool> {
        cw_core::lock(&self.reading)
    }

    /// This computer's model, started where it does not run yet; not while it is held back.
    async fn running(&self) -> anyhow::Result<Arc<Running>> {
        let mut running = self.running.lock().await;
        if let Some(running) = running.as_ref() {
            return Ok(running.clone());
        }
        anyhow::ensure!(
            self.ready(),
            Fail::said(Code::NotNow, "the search model is not downloaded")
                .with("what", "search_model_not_downloaded")
        );
        if self.held_back(MODEL)
            && let Some((why, _)) = self.failure().get(MODEL)
        {
            Err(Fail::from(why.clone()))?;
        }
        let started = Running::start(&self.http, &self.setup, &self.file, &self.log).await;
        let started = Arc::new(started?);
        *running = Some(started.clone());
        Ok(started)
    }

    /// Notes why the model of `stamp` failed; this computer's is stopped too:
    /// the next need after `RETRY` asks it anew.
    async fn failed(&self, stamp: &str, failure: &anyhow::Error) {
        tracing::warn!("the search model {stamp} failed: {failure:#}");
        self.failure().insert(
            stamp.to_string(),
            (
                cw_core::told(failure, Code::SearchModelFailed),
                Instant::now(),
            ),
        );
        if stamp == MODEL
            && let Some(running) = self.running.lock().await.take()
        {
            running.stop().await;
        }
    }
}

/// How far the model is, as the dialog and the settings show it.
pub struct Status {
    pub downloading: bool,
    /// The bytes downloaded, while it downloads.
    pub done: u64,
    /// Why the last download failed, or else, once the user's model can be
    /// asked, the model did.
    pub failure: Option<ErrorBody>,
    /// Whether this computer's model is downloaded.
    pub ready: bool,
    /// The size of its file, in bytes.
    pub size: u64,
    /// The user's cards their model has yet to read, while it can be asked.
    pub left: usize,
}

pub async fn status(state: &dyn Host, user: i64) -> anyhow::Result<Status> {
    let search = state.search();
    let (downloading, done, failed) = match search.fetch.state(&()) {
        Seen::Idle => (false, 0, None),
        Seen::Running(done) => (true, done, None),
        Seen::Failed(why) => (false, 0, Some(why)),
    };
    let ready = search.ready();
    let (stamp, left) = work(state, move |db| {
        let stamp = db.search_stamp(user)?;
        let usable = ready || stamp != MODEL;
        Ok((stamp, if usable { db.cards_unread(user)? } else { 0 }))
    })
    .await?;
    let usable = ready || stamp != MODEL;
    Ok(Status {
        downloading,
        done,
        failure: failed.or_else(|| {
            search
                .failure()
                .get(&stamp)
                .filter(|_| usable)
                .map(|(why, _)| why.clone())
        }),
        ready,
        size: search.setup.model.size,
        left,
    })
}

/// Starts downloading the model, unless it is there or downloads already.
pub fn download(state: &dyn Host) {
    let search = state.search();
    if !search.ready()
        && let Begun::Started(stop) = search.fetch.begin(&())
    {
        let state = state.held();
        tokio::spawn(async move { fetch_model(&*state, &stop).await });
    }
    state.push_all(&PageEvent::Search);
}

async fn fetch_model(state: &dyn Host, stop: &AtomicBool) {
    let search = state.search();
    let progress = search.fetch.progress(&(), search.setup.model.size, || {
        state.push_all(&PageEvent::Search);
    });
    let (model, file) = (&search.setup.model, &search.file);
    let fetched = fetching::download_file(&search.http, model, file, progress, stop).await;
    search.fetch.finish(&(), fetched, "the search model");
    search.failure().remove(MODEL);
    state.push_all(&PageEvent::Search);
    read_cards(state);
}

/// Cancels the download, if one runs.
pub fn cancel(state: &dyn Host) {
    state.search().fetch.cancel(&());
}

/// Removes the model's file, after the download that is running, if one is.
/// The model is stopped first, as its process holds the file open, and is not
/// started again meanwhile: that waits for the same hold.
pub async fn remove(state: &dyn Host) -> std::io::Result<()> {
    let search = state.search();
    search.fetch.cancel(&());
    let mut running = search.running.lock().await;
    if let Some(running) = running.take() {
        running.stop().await;
    }
    search.failure().remove(MODEL);
    *search.last() = None;
    cw_modelfiles::remove_released(&search.file).await?;
    drop(running);
    state.push_all(&PageEvent::Search);
    Ok(())
}

/// The model of `user`'s texts where it can answer now, not held back: its
/// search kind's at a provider, else this computer's where it runs; where
/// that is ready and does not run yet, it is started for the next time, and
/// this time goes without it.
async fn reader_now(state: &dyn Host, user: i64) -> Option<Reader> {
    let search = state.search();
    let at = work(state, move |db| at_of(db, user)).await;
    let at = match at {
        Ok(at) => at,
        Err(failure) => {
            tracing::error!("the search model of user {user} cannot be read: {failure:#}");
            return None;
        }
    };
    if let Some(at) = at {
        return (!search.held_back(&at.stamp())).then(|| Reader::At(Arc::new(at)));
    }
    if !search.ready() {
        return None;
    }
    let running = search
        .running
        .try_lock()
        .ok()
        .and_then(|running| running.clone());
    if running.is_none() {
        read_cards(state);
    }
    running.map(Reader::Local)
}

/// `query` as `user`'s search model reads it, where the model can answer now
/// (`reader_now`) and the query has words: its first piece, as a card's are
/// cut. Where it cannot, or fails, the search goes by the words alone.
pub async fn near(state: &dyn Host, user: i64, query: &str) -> Option<Arc<Vec<f32>>> {
    let search = state.search();
    let query: String = query.trim().chars().take(QUERY_LIMIT).collect();
    if query.is_empty() {
        return None;
    }
    let reader = reader_now(state, user).await?;
    let stamp = reader.stamp();
    if let Some((by, had, vector)) = search.last().as_ref()
        && *by == stamp
        && *had == query
    {
        return Some(vector.clone());
    }
    let read = async {
        let first = reader
            .chunks(&search.http, &query)
            .await?
            .into_iter()
            .next();
        let mut vectors = reader.embed(&search.http, &Vec::from_iter(first)).await?;
        anyhow::Ok(Arc::new(vectors.pop().unwrap_or_default()))
    };
    match read.await {
        Ok(vector) => {
            *search.last() = Some((stamp, query, vector.clone()));
            Some(vector)
        }
        Err(failure) => {
            search.failed(&stamp, &failure).await;
            None
        }
    }
}

/// What the model is given at most to answer a reply's question, beside
/// the reply's own: one that hangs is held back as one that failed.
async fn in_time<T>(
    search: &Search,
    stamp: &str,
    work: impl Future<Output = anyhow::Result<T>>,
) -> Option<T> {
    let failure = match tokio::time::timeout(REPLY_LIMIT, work).await {
        Ok(Ok(done)) => return Some(done),
        Ok(Err(failure)) => failure,
        Err(_) => anyhow::anyhow!(
            Fail::said(Code::TimedOut, "the search model did not answer in time")
                .with("whose", "search_model")
        ),
    };
    search.failed(stamp, &failure).await;
    None
}

/// The vector of the newest piece of `text`, the newest messages of a chat,
/// where `user`'s model can answer now (`reader_now`) and answers in time,
/// else none.
pub async fn newest_vector(state: &dyn Host, user: i64, text: &str) -> Option<Vec<f32>> {
    let search = state.search();
    if text.trim().is_empty() {
        return None;
    }
    let reader = reader_now(state, user).await?;
    let read = async {
        let last = reader.chunks(&search.http, text).await?.pop();
        let mut vectors = reader.embed(&search.http, &Vec::from_iter(last)).await?;
        anyhow::Ok(vectors.pop())
    };
    in_time(search, &reader.stamp(), read)
        .await
        .flatten()
        .filter(|vector| !vector.is_empty())
}

/// The vectors of `texts` by `user`'s model, of each the vectors of all its
/// pieces one after the other, as `embedder::to_bytes` stores them
/// (`search::nearest` reads them): those kept (`search::kept_vectors`) are
/// taken, the others made where the model can answer now and answers in time,
/// and kept. None where one is missing and cannot be made.
pub async fn vectors(state: &dyn Host, user: i64, texts: Vec<String>) -> Option<Vec<Vec<u8>>> {
    let search = state.search();
    let reader = reader_now(state, user).await;
    let stamp = match &reader {
        Some(reader) => reader.stamp(),
        None => match work(state, move |db| db.search_stamp(user)).await {
            Ok(stamp) => stamp,
            Err(failure) => {
                tracing::error!("the search model of user {user} cannot be read: {failure:#}");
                return None;
            }
        },
    };
    let hashes: Vec<Vec<u8>> = texts
        .iter()
        .map(|text| search::text_hash(&stamp, text))
        .collect();
    let asked = hashes.clone();
    let mut kept = match work(state, move |db| db.kept_vectors(&asked)).await {
        Ok(kept) => kept,
        Err(failure) => {
            tracing::error!("the kept vectors cannot be read: {failure:#}");
            return None;
        }
    };
    let missing: Vec<usize> = (0..texts.len()).filter(|&at| kept[at].is_none()).collect();
    if missing.is_empty() {
        return kept.into_iter().collect();
    }
    let reader = reader?;
    let read = async {
        let mut pieces = Vec::new();
        for &at in &missing {
            for piece in reader.chunks(&search.http, &texts[at]).await? {
                pieces.push((at, piece));
            }
        }
        let mut made: Vec<(usize, Vec<u8>)> = missing.iter().map(|&at| (at, Vec::new())).collect();
        for batch in pieces.chunks(BATCH) {
            let only: Vec<String> = batch.iter().map(|(_, piece)| piece.clone()).collect();
            let read = reader.embed(&search.http, &only).await?;
            for ((at, _), vector) in batch.iter().zip(read) {
                let place = missing.iter().position(|m| m == at).unwrap_or_default();
                made[place].1.extend(embedder::to_bytes(&vector));
            }
        }
        anyhow::Ok(made)
    };
    let made = in_time(search, &stamp, read).await?;
    let new: Vec<(Vec<u8>, Vec<u8>)> = made
        .into_iter()
        .map(|(at, bytes)| {
            kept[at] = Some(bytes.clone());
            (hashes[at].clone(), bytes)
        })
        .collect();
    if let Err(failure) = work(state, move |db| db.keep_vectors(&new)).await {
        tracing::error!("the vectors cannot be kept: {failure:#}");
    }
    kept.into_iter().collect()
}

/// The vector of each of `texts` for the memory (`memory::Vectors`) by
/// `user`'s model, with its stamp: of its newest piece, the whole of a short
/// text; where the model can answer now and, if `hurried` (a reply waits),
/// answers in time; else none.
pub async fn memory_vectors(
    state: &dyn Host,
    user: i64,
    texts: &[String],
    hurried: bool,
) -> Option<(String, Vec<Vec<f32>>)> {
    let search = state.search();
    let reader = reader_now(state, user).await?;
    let stamp = reader.stamp();
    if texts.is_empty() {
        return Some((stamp, Vec::new()));
    }
    let read = async {
        let mut pieces = Vec::new();
        for text in texts {
            let newest = reader.chunks(&search.http, text).await?.pop();
            pieces.push(newest.unwrap_or_else(|| text.clone()));
        }
        let mut made = Vec::new();
        for batch in pieces.chunks(BATCH) {
            made.extend(reader.embed(&search.http, batch).await?);
        }
        anyhow::ensure!(
            made.len() == texts.len(),
            Fail::said(Code::ModelAnswer, "the search model left out a text")
                .with("what", "search_left_out")
        );
        anyhow::Ok(made)
    };
    let made = match hurried {
        true => in_time(search, &stamp, read).await?,
        false => match read.await {
            Ok(made) => made,
            Err(failure) => {
                search.failed(&stamp, &failure).await;
                return None;
            }
        },
    };
    Some((stamp, made))
}

/// Has every card and document read by its user's model that it has not been,
/// unless a task does already.
/// `user`'s search model at a provider, where the account has one.
fn at_of(db: &dyn Storage, user: i64) -> anyhow::Result<Option<At>> {
    let Some(picked) = kinds::picked(db, user, Kind::Search)? else {
        return Ok(None);
    };
    let provider = kinds::provider_of(db, user, Kind::Search)?;
    Ok(provider.map(|provider| At::of(picked.entry, provider)))
}

/// After a provider or a kind changed: the providers' models are asked
/// again at once (a key mended), and what is unread is read.
pub fn provider_changed(state: &dyn Host) {
    state.search().failure().retain(|stamp, _| stamp == MODEL);
    read_cards(state);
}

pub fn read_cards(state: &dyn Host) {
    let search = state.search();
    {
        let mut reading = search.reading();
        if *reading {
            return;
        }
        *reading = true;
    }
    let held = state.held();
    let place = Place::new(move || *held.search().reading() = false);
    tokio::spawn(read(state.held(), place));
}

/// What `read` reads next: a card, with its user, newest version and title,
/// or else a document, with its user and text, or else rows of Search
/// Cardwave's texts (`find`), with their user and what is read of each; each
/// with its user's stamp.
enum Next {
    Card(i64, i64, i64, String, String),
    Document(i64, i64, String, String),
    Texts(i64, Vec<(i64, String)>, String),
}

/// How many of Search Cardwave's rows are read at a time.
const TEXTS_AT_ONCE: usize = 16;

/// The model of `stamp` for `user`'s texts, as the reading asks it: this
/// computer's started where it does not run, a provider's while it is still
/// the user's search kind. None where it cannot be had: it is skipped.
async fn reader_for(
    state: &dyn Host,
    readers: &mut HashMap<String, Reader>,
    user: i64,
    stamp: &str,
) -> Option<Reader> {
    if let Some(reader) = readers.get(stamp) {
        return Some(reader.clone());
    }
    let search = state.search();
    let reader = if stamp == MODEL {
        match search.running().await {
            Ok(running) => Reader::Local(running),
            Err(failure) => {
                search.failed(MODEL, &failure).await;
                state.push_all(&PageEvent::Search);
                return None;
            }
        }
    } else {
        let at = work(state, move |db| at_of(db, user))
            .await
            .ok()
            .flatten()?;
        // Picked otherwise meanwhile: the next round reads by the new one.
        if at.stamp() != stamp {
            return None;
        }
        Reader::At(Arc::new(at))
    };
    readers.insert(stamp.to_string(), reader.clone());
    Some(reader)
}

/// Reads one card after the other, each by its user's model, then one
/// document after the other. Where a model fails it is held back until
/// `RETRY` has passed, and the texts of its stamp are skipped; where it
/// answers but cannot read a card, the card is kept without vectors, not to
/// hold back those after it, and read again when it has another version; a
/// document so is kept without pieces.
async fn read(held: Arc<dyn Host>, place: Place) {
    let state = &*held;
    let search = state.search();
    let mut skip = search.skipped();
    let mut readers: HashMap<String, Reader> = HashMap::new();
    loop {
        let taken = state.held();
        let skipping = skip.clone();
        let next = work(state, move |db| {
            let mut reading = taken.search().reading();
            let mut skip = skipping;
            // A model removed meanwhile reads nothing more.
            if !taken.search().ready() {
                skip.push(MODEL.to_string());
            }
            let next = db.unread_card(&skip).and_then(|card| match card {
                Some((card, user, version, title, stamp)) => {
                    Ok(Some(Next::Card(card, user, version, title, stamp)))
                }
                None => match documents::next(db, &skip)? {
                    Some((id, user, text, stamp)) => {
                        Ok(Some(Next::Document(id, user, text, stamp)))
                    }
                    None => {
                        let rows = db.unread_texts(&skip, TEXTS_AT_ONCE)?;
                        Ok(rows
                            .first()
                            .map(|(_, user, _, stamp)| (*user, stamp.clone()))
                            .map(|(user, stamp)| {
                                Next::Texts(
                                    user,
                                    rows.into_iter()
                                        .map(|(id, _, text, _)| (id, text))
                                        .collect(),
                                    stamp,
                                )
                            }))
                    }
                },
            });
            if !matches!(next, Ok(Some(_))) {
                *reading = false;
            }
            Ok(next)
        })
        .await;
        let next = match next {
            Ok(Ok(Some(next))) => next,
            Ok(given_up) => {
                place.release();
                if let Err(failure) = given_up {
                    tracing::error!("the cards to read cannot be found: {failure:#}");
                }
                return;
            }
            Err(failure) => {
                tracing::error!("the reading of the cards broke off: {failure:#}");
                return;
            }
        };
        let (user, stamp) = match &next {
            Next::Card(_, user, _, _, stamp)
            | Next::Document(_, user, _, stamp)
            | Next::Texts(user, _, stamp) => (*user, stamp.clone()),
        };
        let Some(reader) = reader_for(state, &mut readers, user, &stamp).await else {
            skip.push(stamp);
            continue;
        };
        let read = match next {
            Next::Card(card, user, version, title, _) => {
                read_card(state, &reader, (card, user, version), title).await
            }
            Next::Document(id, user, text, _) => {
                read_document(state, &reader, id, user, &text).await
            }
            Next::Texts(_, rows, _) => read_texts(state, &reader, rows).await,
        };
        match read {
            Ok(true) => {}
            Ok(false) => {
                skip.push(stamp.clone());
                readers.remove(&stamp);
            }
            Err(()) => return,
        }
    }
}

/// Reads a card by `reader` and keeps its vectors. False where the model
/// failed; an error where the database did.
async fn read_card(
    state: &dyn Host,
    reader: &Reader,
    (card_id, user, version_id): (i64, i64, i64),
    title: String,
) -> Result<bool, ()> {
    let search = state.search();
    let document = work(state, move |db| cards::document_of(db, version_id)).await;
    let texts = match &document {
        Ok(document) => search::texts(&title, document),
        // The database failing is tried again at the next start of the reading.
        Err(failure) if state.storage().failed_in(failure) => {
            tracing::error!("card {card_id} cannot be read: {failure:#}");
            return Err(());
        }
        // A card whose files cannot be read is read by its title alone.
        Err(_) => vec![vec![title]],
    };
    let stamp = reader.stamp();
    let vectors = match vectors_of(search, reader, &texts).await {
        Ok(vectors) => {
            search.failure().remove(&stamp);
            vectors
        }
        Err(failure) if reader.answers(&search.http, &failure).await => {
            tracing::warn!("card {card_id} cannot be read by the search model: {failure:#}");
            Vec::new()
        }
        Err(failure) => {
            search.failed(&stamp, &failure).await;
            state.push(user, &PageEvent::Search);
            return Ok(false);
        }
    };
    if let Err(failure) = work(state, move |db| {
        db.keep_card_vectors(card_id, version_id, &stamp, &vectors)
    })
    .await
    {
        tracing::error!("card {card_id}'s vectors cannot be kept: {failure:#}");
        return Err(());
    }
    state.push(user, &PageEvent::Search);
    Ok(true)
}

/// Reads a document's pieces by `reader` and keeps them (none where the model
/// cannot read them). False where the model failed; an error where the
/// pieces cannot be kept.
async fn read_document(
    state: &dyn Host,
    reader: &Reader,
    id: i64,
    user: i64,
    text: &str,
) -> Result<bool, ()> {
    let search = state.search();
    let pieces = documents::pieces(text);
    let texts: Vec<Vec<String>> = pieces.iter().map(|piece| vec![piece.clone()]).collect();
    let stamp = reader.stamp();
    let kept = match vectors_of(search, reader, &texts).await {
        Ok(vectors) => {
            let mut kept: Vec<(String, Vec<u8>)> = pieces
                .into_iter()
                .map(|piece| (piece, Vec::new()))
                .collect();
            for (at, vector) in vectors {
                kept[at].1.extend(embedder::to_bytes(&vector));
            }
            kept
        }
        Err(failure) if reader.answers(&search.http, &failure).await => {
            tracing::warn!("document {id} cannot be read by the search model: {failure:#}");
            Vec::new()
        }
        Err(failure) => {
            search.failed(&stamp, &failure).await;
            state.push(user, &PageEvent::Search);
            return Ok(false);
        }
    };
    if let Err(failure) = work(state, move |db| documents::keep(db, id, &stamp, &kept)).await {
        tracing::error!("document {id}'s pieces cannot be kept: {failure:#}");
        return Err(());
    }
    state.push(user, &PageEvent::Documents);
    Ok(true)
}

/// Reads Search Cardwave's rows by `reader` and keeps their vectors; a row it
/// answers but cannot read is kept without them, read one at a time where
/// several were asked. False where the model failed; an error where the
/// vectors cannot be kept.
async fn read_texts(
    state: &dyn Host,
    reader: &Reader,
    rows: Vec<(i64, String)>,
) -> Result<bool, ()> {
    let search = state.search();
    let stamp = reader.stamp();
    let mut kept: Vec<(i64, Vec<u8>)> = Vec::new();
    let mut asked = vec![rows];
    while let Some(rows) = asked.pop() {
        let texts: Vec<Vec<String>> = rows.iter().map(|(_, text)| vec![text.clone()]).collect();
        match vectors_of(search, reader, &texts).await {
            Ok(vectors) => {
                let mut read: Vec<(i64, Vec<u8>)> =
                    rows.iter().map(|(id, _)| (*id, Vec::new())).collect();
                for (at, vector) in vectors {
                    read[at].1.extend(embedder::to_bytes(&vector));
                }
                kept.extend(read);
            }
            Err(failure) if reader.answers(&search.http, &failure).await => {
                if rows.len() > 1 {
                    asked.extend(rows.into_iter().map(|row| vec![row]));
                } else {
                    tracing::warn!("a text cannot be read by the search model: {failure:#}");
                    kept.extend(rows.into_iter().map(|(id, _)| (id, Vec::new())));
                }
            }
            Err(failure) => {
                search.failed(&stamp, &failure).await;
                return Ok(false);
            }
        }
    }
    if let Err(failure) = work(state, move |db| db.keep_text_vectors(&stamp, &kept)).await {
        tracing::error!("the search's texts' vectors cannot be kept: {failure:#}");
        return Err(());
    }
    Ok(true)
}

/// The vectors of a card's `texts` (by field), each with its field: every
/// text in pieces, asked for `BATCH` pieces at a time.
async fn vectors_of(
    search: &Search,
    reader: &Reader,
    texts: &[Vec<String>],
) -> anyhow::Result<Vec<(usize, Vec<f32>)>> {
    let mut pieces = Vec::new();
    for (field, texts) in texts.iter().enumerate() {
        for text in texts {
            for piece in reader.chunks(&search.http, text).await? {
                pieces.push((field, piece));
            }
        }
    }
    let mut vectors = Vec::new();
    for batch in pieces.chunks(BATCH) {
        let only: Vec<String> = batch.iter().map(|(_, piece)| piece.clone()).collect();
        let read = reader.embed(&search.http, &only).await?;
        vectors.extend(batch.iter().map(|(field, _)| *field).zip(read));
    }
    Ok(vectors)
}

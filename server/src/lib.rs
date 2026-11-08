//! Cardwave server: the HTTP API, the event socket and the web UI on one local port, the request logging and
//! the wiring of the crates, which hold every area (the store cw-store, Search Cardwave cw-find). The desktop
//! app runs this same server in-process; both programs start from `Options::product`. The app's parts are
//! `Inner`'s, reached through an `AppState`.
//!
//! `router` answers through a `Gate`: with a password on the server starts locked, serving the web UI,
//! `GET /api/lock` and `POST /api/unlock` and answering everything else 423 until the password opens the
//! database and `open` makes the app. "Lock" (`Gate::close`) waits for the password again: the app stays made
//! but answers nothing, and every event socket ends. The models' client carries the pretend model's answers
//! (`pretend::FIXED`). Other devices reach it where the owner lets them (`Gate::listen`, `api/accounts.rs`):
//! a second listener on `Options::network`, whose requests are `Remote` and must be signed in, started with
//! the app as `meta`'s `network` says. Both answer
//! only `localhost` or a numeric address, and a browser only from the server's own pages (`origin_guard`).

pub mod api;
mod faces;
mod ports;
pub mod pretend;

use anyhow::Context;
use axum::extract::connect_info::ConnectInfo;
use std::collections::{HashMap, HashSet};
use std::fs::{File, TryLockError};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::ops::RangeInclusive;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicI64, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock, Weak};
use std::time::Duration;

use axum::Router;
use axum::extract::{Request, State};
use axum::http::{HeaderName, HeaderValue, StatusCode, header};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use tokio::net::TcpListener;
use tokio::sync::{Notify, broadcast, oneshot, watch};
use tower::ServiceExt;
use tower_http::services::{ServeDir, ServeFile};
use tower_http::set_header::SetResponseHeaderLayer;

/// Ports tried in order when no fixed port is given.
pub const DEFAULT_PORTS: RangeInclusive<u16> = 8477..=8496;

#[derive(Clone)]
pub struct Options {
    /// Folder for all user data. Created if missing.
    pub data_dir: PathBuf,
    /// Built web UI (`web/dist`). Without it only the API is served.
    pub web_dir: Option<PathBuf>,
    /// Where the key of the database in `data_dir` is kept while no password is on.
    pub key: cw_key::Place,
    /// A test's own server, which the search for a provider's API and the web
    /// tool ask in place of the hosts (`cw_provider::places::Finder`,
    /// `tools::web::Web`). `None` outside tests.
    pub provider_places: Option<String>,
    /// Where models.dev's list is fetched anew from, at most once a day
    /// (`cw_provider::models_dev`). `None` fetches nothing: the shipped list.
    pub models_dev: Option<String>,
    /// Where the search model is downloaded from and what runs it.
    pub search: cw_provider::embedder::Setup,
    /// What looks for the faces on the cards' pictures. `None` looks for none.
    pub faces: Option<cw_library::faces::Opener>,
    /// What the voice downloads and what speaks.
    pub voice: cw_voice::Setup,
    /// What dictation downloads and what hears.
    pub dictation: cw_dictation::Setup,
    /// The models This computer offers to download (`cw_provider::fit::offered`).
    pub local_models: Vec<cw_provider::fit::Offered>,
    /// Where other devices of the home network reach the server, once let.
    pub network: Network,
    /// How often the folder of cards is looked at for new cards (`WATCH_EVERY`; shorter in tests).
    pub watch_every: Duration,
    /// The user's Documents folder, which first run offers as the folder of cards; a folder of their own
    /// in tests, none where the system names none.
    pub documents: Option<PathBuf>,
    /// What this computer's account is called when it is made ([`account_name`]).
    pub account_name: String,
}

impl Options {
    /// The product's: models.dev's list, bge-m3 run by `llama_dir`'s `llama-server`, the shipped voice, dictation
    /// and models of This computer, the home network, the user's Documents. A test changes only its stand-ins.
    pub fn product(
        data_dir: PathBuf,
        web_dir: Option<PathBuf>,
        llama_dir: PathBuf,
    ) -> anyhow::Result<Self> {
        Ok(Self {
            data_dir,
            web_dir,
            key: cw_key::Place::from_env()?,
            provider_places: None,
            models_dev: Some(cw_provider::models_dev::SOURCE.into()),
            search: cw_provider::embedder::Setup::bge_m3(llama_dir),
            faces: Some(cw_library::faces::the_model()),
            voice: cw_voice::Setup::pocket(),
            dictation: cw_dictation::Setup::turbo(),
            local_models: cw_provider::fit::offered(),
            network: Network::home(),
            watch_every: WATCH_EVERY,
            documents: documents_folder(),
            account_name: account_name(),
        })
    }
}

/// How often the folder of cards is looked at: only the files the system told of, and only a file new or
/// written anew read.
pub const WATCH_EVERY: Duration = Duration::from_secs(5);

/// What this computer's account is first called ([`Options::account_name`]): the system's user name; in a
/// debug build `CARDWAVE_USER` in its place, so a test's is never the user's.
pub fn account_name() -> String {
    account_name_from(|key| std::env::var(key).ok())
}

/// [`account_name`] of the variables `var` reads; empty where none is set.
fn account_name_from(var: impl Fn(&str) -> Option<String>) -> String {
    let test = var("CARDWAVE_USER").filter(|_| cfg!(debug_assertions));
    test.or_else(|| var("USERNAME"))
        .or_else(|| var("USER"))
        .unwrap_or_default()
}

/// The user's Documents folder, as the system names it ([`Options::documents`]); in a debug build
/// `CARDWAVE_DOCUMENTS` names the tests' own folder in its place, so theirs is never the user's.
pub fn documents_folder() -> Option<PathBuf> {
    match std::env::var_os("CARDWAVE_DOCUMENTS").filter(|_| cfg!(debug_assertions)) {
        Some(folder) => Some(PathBuf::from(folder)),
        None => dirs::document_dir(),
    }
}

/// Where other devices of the home network reach the server, once its owner
/// lets them (`Gate::listen`): an address of this computer and the ports tried
/// in order. `home` is every address, on the first free port of
/// `DEFAULT_PORTS`; `loopback` is this computer alone, on any free port, for
/// tests, as Windows asks its user before a program listens on the network.
#[derive(Clone)]
pub struct Network {
    pub host: IpAddr,
    pub ports: RangeInclusive<u16>,
}

impl Network {
    pub fn home() -> Self {
        Self {
            host: IpAddr::V4(Ipv4Addr::UNSPECIFIED),
            ports: DEFAULT_PORTS,
        }
    }

    pub fn loopback() -> Self {
        Self {
            host: IpAddr::V4(Ipv4Addr::LOCALHOST),
            ports: 0..=0,
        }
    }
}

/// Marks a request the home network's listener took: another device's, which
/// is asked for a session (`api.rs`, `Caller`).
#[derive(Clone, Copy)]
pub(crate) struct Remote;

/// Where a request comes from, for counting wrong passwords by it.
pub(crate) fn peer(extensions: &axum::http::Extensions) -> IpAddr {
    extensions
        .get::<ConnectInfo<SocketAddr>>()
        .map_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED), |ConnectInfo(at)| at.ip())
}

#[derive(Clone)]
pub struct AppState(Arc<Inner>);

/// The app's parts, which every module of this crate reaches through an `AppState`.
impl std::ops::Deref for AppState {
    type Target = Inner;

    fn deref(&self) -> &Inner {
        &self.0
    }
}

pub struct Inner {
    data_dir: PathBuf,
    db: cw_store::Db,
    /// The database's key, and where it is kept while no password is on.
    key: cw_key::DbKey,
    place: cw_key::Place,
    /// Held while the password is changed or a backup restored.
    guarded: Mutex<()>,
    /// The pieces of work under way that write what a model made into the data by its ids (a picture, an
    /// interview's or the generator's card), by user, which a restore and the account's delete wait for
    /// ([`AppState::at_work`]).
    at_work: Mutex<HashMap<i64, usize>>,
    /// How many backups were restored since the start: work begun before one is refused ([`AppState::at_work`]).
    restores: AtomicU64,
    local_user: AtomicI64,
    /// What this computer's account is called when a restored backup has none.
    account_name: String,
    /// The pages signed in to an account.
    sessions: cw_accounts::sessions::Sessions,
    /// Wrong passwords tried, the gate's too.
    tries: Arc<cw_accounts::password::Tries>,
    /// The gate the app was opened by, which listens on the home network.
    gate: Weak<Gate>,
    /// All calls to model providers share one client and its connections,
    http: cw_provider::Http,
    /// but for the interview's writer, whose calls may stay silent longer ([`writer::SILENCE`]).
    ///
    /// [`writer::SILENCE`]: cw_library::interview::writer::SILENCE
    writer_http: cw_provider::Http,
    /// Looks for the API of a provider that is not on the list.
    finder: cw_provider::places::Finder,
    /// models.dev's list, by which first run picks the models.
    models_dev: cw_provider::models_dev::ModelsDev,
    /// The web tool's searches and pages.
    web: cw_coding::tools::web::Web,
    /// The calls of tools that wait for the user to allow them.
    asks: Mutex<api::generate::Asks>,
    /// What the event sockets push: each event as JSON, with the user it is
    /// for and the page that is not told of it.
    events: broadcast::Sender<api::Pushed>,
    /// The replies being generated, by user and chat, each with what stops it.
    replies: Mutex<Replies>,
    /// The coding tasks that run (`coding::run`).
    coding: Mutex<cw_coding::coding::run::Tasks>,
    /// Whose turn it is to make a card's picture small.
    thumbnails: cw_library::thumbnails::Turns,
    /// The looking for faces on the cards' pictures (`faces.rs`).
    faces: faces::Faces,
    /// The users whose cards the worker model is describing, with the card in hand (`api/describe.rs`).
    describing: Mutex<HashMap<i64, Option<i64>>>,
    /// The chats whose title the worker model is asked for.
    titles: cw_chat::chats::title::Titles,
    /// The import of a folder of cards, the last one or the one going on (`api/card_folder.rs`).
    card_folder: Mutex<Option<cw_library::cards::folder::FolderImport>>,
    /// The folder first run offers as the folder of cards ([`Options::documents`]).
    documents: Option<PathBuf>,
    /// The chats whose new messages a memory pass is reading (`api/memory.rs`), and whose they are.
    remembering: Mutex<HashMap<i64, i64>>,
    /// The models, by address and name, that answered they see pictures
    /// (`api/attachments.rs`).
    seeing: Mutex<HashSet<(String, String)>>,
    /// The models, by address and name, whose server refused a request with
    /// tools and took it without (`api/generate.rs`): asked without from then on.
    toolless: Mutex<HashSet<(String, String)>>,
    /// The search model (`find/reader.rs`).
    search: cw_find::reader::Search,
    /// The voice that reads messages aloud (`api/voice.rs`).
    voice: api::voice::Voice,
    /// What the companion's figure does and Cardwave's window shows (`api/companion.rs`).
    companion: api::companion::Live,
    /// Each user's switch of pictures from the web as last read or changed, which every page's policy
    /// asks (`api::page_policy`; set by the settings' change, emptied by a restore, a user's by its deletion).
    web_pictures: Mutex<HashMap<i64, bool>>,
    /// Dictation in the message field (`api/dictation.rs`).
    dictation: api::dictation::Dictation,
    /// The downloads of the models that fit this computer.
    fit: cw_provider::fit::Downloads,
    /// Locked for as long as this server runs, if it was the first on its data folder.
    _alone: File,
    /// Its end, when the server goes, ends the task that empties the Trash.
    _running: oneshot::Sender<()>,
}

type Replies = HashMap<(i64, i64), Arc<Notify>>;

/// In the data folder; see `Inner::_alone`.
const LOCK_FILE: &str = "server.lock";

/// Events a socket may fall behind by before it is cut off.
const EVENT_BACKLOG: usize = 1024;

/// How often the Trash is looked through for what has been in it long enough.
const PURGE_EVERY: Duration = Duration::from_secs(60 * 60);

impl AppState {
    /// The user requests act for; see [`api::User`].
    pub fn local_user(&self) -> i64 {
        self.local_user.load(Ordering::Relaxed)
    }

    /// The gate, while the server runs.
    fn gate(&self) -> Option<Arc<Gate>> {
        self.gate.upgrade()
    }

    fn describing(&self) -> MutexGuard<'_, HashMap<i64, Option<i64>>> {
        cw_core::lock(&self.describing)
    }

    fn card_folder(&self) -> MutexGuard<'_, Option<cw_library::cards::folder::FolderImport>> {
        cw_core::lock(&self.card_folder)
    }

    fn remembering(&self) -> MutexGuard<'_, HashMap<i64, i64>> {
        cw_core::lock(&self.remembering)
    }

    fn seeing(&self) -> MutexGuard<'_, HashSet<(String, String)>> {
        cw_core::lock(&self.seeing)
    }

    fn toolless(&self) -> MutexGuard<'_, HashSet<(String, String)>> {
        cw_core::lock(&self.toolless)
    }

    fn asks(&self) -> MutexGuard<'_, api::generate::Asks> {
        cw_core::lock(&self.asks)
    }

    fn coding(&self) -> MutexGuard<'_, cw_coding::coding::run::Tasks> {
        cw_core::lock(&self.coding)
    }

    fn replies(&self) -> MutexGuard<'_, Replies> {
        cw_core::lock(&self.replies)
    }

    fn web_pictures(&self) -> MutexGuard<'_, HashMap<i64, bool>> {
        cw_core::lock(&self.web_pictures)
    }

    /// Marks a piece of `user`'s work on the data as under way until the mark is dropped, so a restore and the
    /// account's delete wait for it: it would write into the restored data by the old data's ids, or into an
    /// account that is gone. Begun while a restore runs, it is refused once the restore has ended: its ids
    /// are the old data's.
    fn at_work(&self, user: i64) -> Result<AtWork, cw_core::Fail> {
        let before = self.0.restores.load(Ordering::SeqCst);
        unless_restored(&self.0.restores, &self.guarded, before, || {
            *cw_core::lock(&self.0.at_work).entry(user).or_default() += 1;
            AtWork(self.clone(), user)
        })
    }

    /// Whether any piece of work marked by [`AppState::at_work`] is under way.
    fn is_at_work(&self) -> bool {
        !cw_core::lock(&self.0.at_work).is_empty()
    }

    /// Whether a piece of `user`'s work marked by [`AppState::at_work`] is under way.
    fn user_at_work(&self, user: i64) -> bool {
        cw_core::lock(&self.0.at_work).contains_key(&user)
    }
}

/// A piece of a user's work on the data under way ([`AppState::at_work`]).
/// Does `then` under `guarded` (held while a backup is restored), unless a restore ended since `restores` was
/// `begun`: the work's ids would be the old data's.
fn unless_restored<T>(
    restores: &AtomicU64,
    guarded: &Mutex<()>,
    begun: u64,
    then: impl FnOnce() -> T,
) -> Result<T, cw_core::Fail> {
    let _held = cw_core::lock(guarded);
    if restores.load(Ordering::SeqCst) != begun {
        return Err(cw_core::Fail::new(cw_core::Code::RestoreBusy));
    }
    Ok(then())
}

struct AtWork(AppState, i64);

impl Drop for AtWork {
    fn drop(&mut self) {
        let mut at_work = cw_core::lock(&self.0.0.at_work);
        if let Some(count) = at_work.get_mut(&self.1) {
            *count -= 1;
            if *count == 0 {
                at_work.remove(&self.1);
            }
        }
    }
}

/// What answers before the app is open, and hands every request to it after.
pub(crate) struct Gate {
    opts: Options,
    /// The app, once the database is open.
    app: OnceLock<Router>,
    /// Held while the password is tried.
    trying: tokio::sync::Mutex<()>,
    /// Wrong passwords tried, by what for and where from; the app's too.
    tries: Arc<cw_accounts::password::Tries>,
    /// The home network's listener, while there is one.
    network: Mutex<Option<Listening>>,
    /// Whether the home network's listener runs: a socket of another device
    /// ends when it stops.
    reached: watch::Sender<bool>,
    /// Whether the app was locked again ("Lock"): every socket ends then.
    shut: watch::Sender<bool>,
}

/// The home network's listener: where it listens, and what stops it, which
/// its drop does too; the runtime's end stops it as well, as its task holds
/// the gate.
struct Listening {
    at: SocketAddr,
    _stop: oneshot::Sender<()>,
}

impl Gate {
    pub(crate) fn data_dir(&self) -> &PathBuf {
        &self.opts.data_dir
    }

    pub(crate) fn is_open(&self) -> bool {
        self.app.get().is_some() && !*self.shut.borrow()
    }

    /// Opens the app with the database `key`, unless it is made, and has it
    /// listen on the home network where the database says so; an app locked
    /// again is opened as it was.
    pub(crate) fn open(self: &Arc<Self>, key: cw_key::DbKey) -> anyhow::Result<()> {
        self.shut.send_replace(false);
        if self.app.get().is_none() {
            let (app, reached) = open(
                self.opts.clone(),
                key,
                Arc::downgrade(self),
                self.tries.clone(),
            )?;
            if self.app.set(app).is_ok()
                && reached
                && let Err(failure) = self.listen(true)
            {
                tracing::warn!("{failure:#}");
            }
        }
        Ok(())
    }

    /// Locks the app again until the password is given ("Lock").
    pub(crate) fn close(&self) {
        self.shut.send_replace(true);
    }

    /// Told when the app is locked again.
    pub(crate) fn shut(&self) -> watch::Receiver<bool> {
        self.shut.subscribe()
    }

    /// Held while the password is tried.
    pub(crate) async fn trying(&self) -> tokio::sync::MutexGuard<'_, ()> {
        self.trying.lock().await
    }

    /// Lets other devices of the home network reach the server (`on`), or no
    /// longer. Answers where they reach it.
    pub(crate) fn listen(self: &Arc<Self>, on: bool) -> anyhow::Result<Option<SocketAddr>> {
        let mut network = cw_core::lock(&self.network);
        if !on {
            *network = None;
            self.reached.send_replace(false);
            return Ok(None);
        }
        if let Some(listening) = &*network {
            return Ok(Some(listening.at));
        }
        let runtime =
            tokio::runtime::Handle::try_current().context("the server runs in no runtime")?;
        let Network { host, ports } = &self.opts.network;
        let bound = bind_first(*host, ports.clone())
            .context("Cardwave cannot listen on the home network")?;
        let at = bound.local_addr()?;
        let (stop, stopped) = oneshot::channel::<()>();
        let app = outer(gated(self.clone()).layer(middleware::map_request(remote)));
        runtime.spawn(async move {
            let served = match TcpListener::from_std(bound) {
                Ok(listener) => {
                    serve(listener, app, async {
                        // Its sender dropped stops the server as a stop would.
                        let _ = stopped.await;
                    })
                    .await
                }
                Err(failure) => Err(failure),
            };
            if let Err(failure) = served {
                tracing::warn!("the home network's listener stopped: {failure}");
            }
        });
        *network = Some(Listening { at, _stop: stop });
        self.reached.send_replace(true);
        Ok(Some(at))
    }

    /// Where the home network's listener listens, while it does.
    pub(crate) fn listening(&self) -> Option<SocketAddr> {
        let network = cw_core::lock(&self.network);
        network.as_ref().map(|listening| listening.at)
    }

    /// Told when the home network's listener stops.
    pub(crate) fn reached(&self) -> watch::Receiver<bool> {
        self.reached.subscribe()
    }
}

/// Marks a request of the home network's listener as another device's.
async fn remote(mut request: Request) -> Request {
    request.extensions_mut().insert(Remote);
    request
}

/// What the gate answers itself, and hands on to the app.
fn gated(gate: Arc<Gate>) -> Router {
    api::password::gate_routes()
        .layer(middleware::from_fn(own_pages_only))
        .fallback(pass)
        .with_state(gate)
}

pub fn router(opts: Options) -> anyhow::Result<Router> {
    std::fs::create_dir_all(&opts.data_dir)?;
    let gate = Arc::new(Gate {
        app: OnceLock::new(),
        trying: tokio::sync::Mutex::new(()),
        tries: Arc::default(),
        network: Mutex::default(),
        reached: watch::Sender::new(false),
        shut: watch::Sender::new(false),
        opts,
    });
    if !cw_accounts::password::is_on(gate.data_dir()) {
        gate.open(gate.opts.key.load_or_create(gate.data_dir())?)?;
    }
    Ok(outer(gated(gate)))
}

/// The pages' Content-Security-Policy with the pictures it allows (`img-src`).
macro_rules! page_policy {
    ($pictures:literal) => {
        concat!(
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src ",
            $pictures,
            "; media-src 'self' data: blob:; font-src 'self' data:; ",
            "connect-src 'self' data: blob: ipc: http://ipc.localhost; frame-src 'self'; object-src 'none'; ",
            "base-uri 'none'; form-action 'self'; frame-ancestors 'self'"
        )
    };
}

/// The pages' Content-Security-Policy, the second guard should a stranger's text ever reach the page as HTML:
/// scripts only the app's own files, no inline script or eval. Styles allow inline for the user's own CSS
/// (a `<style>`); pictures only the app's own; `ipc:` is the desktop window's way to its shell, `blob:`/`data:`
/// the figures' files read in the page. A stored file's answer keeps its own, stricter policy (api.rs).
pub(crate) const PAGE_POLICY: &str = page_policy!("'self' data: blob:");
/// [`PAGE_POLICY`] with pictures from the web, for a page whose user's Settings show them ([`api::page_policy`]).
pub(crate) const WEB_PAGE_POLICY: &str = page_policy!("'self' data: blob: http: https:");

/// What every answer of the server has around it, of both its listeners.
fn outer(app: Router) -> Router {
    let default =
        |name, value| SetResponseHeaderLayer::if_not_present(name, HeaderValue::from_static(value));
    app.layer(middleware::from_fn(origin_guard))
        .layer(middleware::from_fn(api::noted))
        .layer(middleware::map_response(api::error_body))
        .layer(default(header::CACHE_CONTROL, "no-cache"))
        .layer(default(header::X_CONTENT_TYPE_OPTIONS, "nosniff"))
        .layer(default(header::CONTENT_SECURITY_POLICY, PAGE_POLICY))
        // Another site's page cannot embed what this server answers (pictures, for one).
        .layer(default(
            HeaderName::from_static("cross-origin-resource-policy"),
            "same-origin",
        ))
}

/// The web UI's files; a path that is none of them gets `index.html`, for its routes.
fn web_files(web: &Path) -> ServeDir<ServeFile> {
    ServeDir::new(web).fallback(ServeFile::new(web.join("index.html")))
}

/// Hands a request to the app once it is open. Before, the API and the socket
/// answer 423, and what else is asked is the web UI's, which has the start screen.
async fn pass(State(gate): State<Arc<Gate>>, request: Request) -> Response {
    if gate.is_open()
        && let Some(app) = gate.app.get()
    {
        return app.clone().oneshot(request).await.into_response();
    }
    let path = request.uri().path();
    if path.starts_with("/api/") || path == "/ws" {
        return api::ApiError::from(cw_core::Fail::new(cw_core::Code::Locked)).into_response();
    }
    match &gate.opts.web_dir {
        Some(web) => web_files(web).oneshot(request).await.into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

/// The app on the database `key` opens: the API, the socket and the web UI,
/// and whether it is to be reached from the home network.
fn open(
    opts: Options,
    key: cw_key::DbKey,
    gate: Weak<Gate>,
    tries: Arc<cw_accounts::password::Tries>,
) -> anyhow::Result<(Router, bool)> {
    let db = cw_store::Db::open(&opts.data_dir.join(cw_key::FILE_NAME), &key)?;
    let local_user = cw_accounts::users::local(&db, &opts.account_name)?;
    let sessions = cw_accounts::sessions::Sessions::load(&db)?;
    let reached = cw_accounts::users::reached(&db)?;
    // Not when another server is running on the same data folder: its replies
    // are still written, its pages still offer what was deleted, and a backup
    // of its may be on its way.
    let alone = File::options()
        .write(true)
        .create(true)
        .truncate(false)
        .open(opts.data_dir.join(LOCK_FILE))?;
    let alone_now = match alone.try_lock() {
        Ok(()) => true,
        Err(TryLockError::WouldBlock) => {
            tracing::warn!("another server is using this data folder");
            false
        }
        Err(TryLockError::Error(failure)) => return Err(failure.into()),
    };
    tidy(&db, alone_now)?;
    if alone_now {
        cw_store::backup::remove_left(&opts.data_dir);
    }
    let runtime =
        tokio::runtime::Handle::try_current().context("the server is made in no runtime")?;
    let (running, ended) = oneshot::channel();
    // This computer's models run as the search model does.
    cw_provider::local::set_up(cw_provider::local::Setup {
        runner: opts.search.runner.clone(),
        log: opts.data_dir.join("local-model.log"),
    });
    let models_dev = cw_provider::models_dev::ModelsDev::new(opts.models_dev, &opts.data_dir);
    let search = cw_find::reader::Search::new(opts.search, &opts.data_dir)?;
    let voice = api::voice::Voice::new(opts.voice, &opts.data_dir)?;
    let dictation = api::dictation::Dictation::new(opts.dictation, &opts.data_dir)?;
    let http = cw_provider::client()?.answering(&pretend::FIXED);
    let writer_http = http.with_silence(cw_library::interview::writer::SILENCE)?;
    let watch_every = opts.watch_every;
    let state = AppState(Arc::new(Inner {
        data_dir: opts.data_dir,
        db,
        key,
        place: opts.key,
        guarded: Mutex::default(),
        at_work: Mutex::default(),
        restores: AtomicU64::new(0),
        local_user: AtomicI64::new(local_user),
        sessions,
        tries,
        gate,
        http,
        writer_http,
        finder: cw_provider::places::Finder::new(opts.provider_places.clone())?,
        models_dev,
        web: cw_coding::tools::web::Web::new(opts.provider_places)?,
        asks: Mutex::default(),
        events: broadcast::channel(EVENT_BACKLOG).0,
        replies: Mutex::default(),
        coding: Mutex::default(),
        thumbnails: cw_library::thumbnails::Turns::default(),
        describing: Mutex::default(),
        titles: Default::default(),
        card_folder: Mutex::default(),
        documents: opts.documents,
        account_name: opts.account_name,
        remembering: Mutex::default(),
        seeing: Mutex::default(),
        toolless: Mutex::default(),
        search,
        voice,
        companion: api::companion::Live::default(),
        web_pictures: Mutex::default(),
        faces: faces::Faces::new(opts.faces.clone()),
        dictation,
        fit: cw_provider::fit::Downloads::new(opts.local_models)?,
        _alone: alone,
        _running: running,
    }));
    purge_on_time(&runtime, Arc::downgrade(&state.0), ended);
    // Not when another server is running on the same data folder: what it has queued is its own.
    if alone_now {
        runtime.spawn(api::describe::queue_lacking(state.clone()));
        let looked_by = state.clone();
        runtime.spawn(async move { faces::look(&looked_by) });
    }
    watch_card_folder(&runtime, Arc::downgrade(&state.0), watch_every);
    let read_after = || middleware::from_fn_with_state(state.clone(), api::find::read_after);
    let in_process = api::Api(api::routes().layer(read_after()).with_state(state.clone()));
    let mut app = api::routes()
        .layer(read_after())
        .layer(axum::Extension(in_process))
        .layer(middleware::from_fn_with_state(state.clone(), api::who))
        .layer(middleware::from_fn(own_pages_only))
        .with_state(state.clone());
    if let Some(web) = &opts.web_dir {
        app = app.fallback_service(web_files(web));
    }
    let app = app.layer(middleware::from_fn_with_state(state, api::page_policy));
    Ok((app, reached))
}

/// What a start does for the data: the library's index and the chats' names
/// made where they are missing, the small pictures no list asks for and what
/// has been in the Trash long enough deleted. `alone`, where no other server
/// runs on the data: the card versions of an older build are made into the
/// texts' history, replies cut off when the server last stopped are ended,
/// the cards queued to be described are let go, and the providers that
/// presets took the place of and the messages, memories and documents deleted
/// are let go, as nothing offers to take one back any more, and the pictures
/// attached to a message never sent (a document stays the chat's). A restored backup
/// is tidied so too.
pub(crate) fn tidy(db: &cw_store::Db, alone: bool) -> anyhow::Result<()> {
    if alone {
        cw_library::cards::fold_versions(db)?;
    }
    cw_library::cards::index_missing(db)?;
    cw_find::index_missing(db)?;
    cw_chat::chats::name_missing(db)?;
    cw_library::thumbnails::remove_unasked(db)?;
    purge(db);
    if alone {
        cw_chat::chats::finish_interrupted(db)?;
        cw_chat::chats::purge_deleted(db)?;
        cw_coding::coding::stop_interrupted(db)?;
        cw_chat::memory::purge_deleted(db)?;
        cw_chat::documents::purge_deleted(db)?;
        cw_chat::attachments::purge_waiting(db)?;
        cw_coding::tools::written::purge_deleted(db)?;
        cw_search::Index::forget_unused_vectors(db)?;
        cw_library::describe::forget_unfinished(db)?;
        cw_provider::Storage::forget_replaced_providers(db, None)?;
    }
    Ok(())
}

/// Deletes for good what has been in the Trash long enough, every hour for as
/// long as the server lives, on the runtime the server is made in.
fn purge_on_time(
    runtime: &tokio::runtime::Handle,
    server: Weak<Inner>,
    mut ended: oneshot::Receiver<()>,
) {
    runtime.spawn(async move {
        // The server's end drops the sender, which wakes the task at once.
        while tokio::time::timeout(PURGE_EVERY, &mut ended).await.is_err() {
            let Some(server) = server.upgrade() else {
                return;
            };
            // The database's work is not the runtime's; a failed task is purge's next turn.
            let _ = tokio::task::spawn_blocking(move || purge(&server.db)).await;
        }
    });
}

/// Looks at the folder of cards every `every` for as long as the server lives (`api/card_folder.rs`), on
/// the runtime the server is made in.
fn watch_card_folder(runtime: &tokio::runtime::Handle, server: Weak<Inner>, every: Duration) {
    runtime.spawn(async move {
        let mut watch = cw_library::cards::watch::Watch::default();
        loop {
            tokio::time::sleep(every).await;
            let Some(server) = server.upgrade() else {
                return;
            };
            api::card_folder::look(&AppState(server), &mut watch).await;
        }
    });
}

/// Deletes for good what has been in the Trash long enough. A failure is
/// noted and waits for the next time: the server runs without it.
fn purge(db: &cw_store::Db) {
    if let Err(error) = cw_library::trash::purge(db, cw_core::now_ms()) {
        tracing::warn!("the Trash could not be emptied: {error:#}");
    }
}

/// Rejects requests sent to a name other than `localhost` or a numeric address,
/// so a page whose name was made to lead here (DNS rebinding) is refused, and
/// browser requests whose `Origin` differs from the `Host` they were sent to,
/// so a page from another site cannot drive the server (cross-site requests and
/// sockets). It guards every route, current and future. Clients that send no
/// `Origin` (curl, native apps, same-origin GETs) pass that second check.
async fn origin_guard(req: Request, next: Next) -> Response {
    let headers = req.headers();
    let host = headers
        .get(header::HOST)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("");
    let name = host_name(host);
    if !host.is_empty()
        && !name.eq_ignore_ascii_case("localhost")
        && name.parse::<IpAddr>().is_err()
    {
        return StatusCode::FORBIDDEN.into_response();
    }
    if let Some(origin) = headers.get(header::ORIGIN) {
        let authority = origin.to_str().ok().and_then(|o| {
            o.strip_prefix("http://")
                .or_else(|| o.strip_prefix("https://"))
        });
        if !authority.is_some_and(|a| a.eq_ignore_ascii_case(host)) {
            return StatusCode::FORBIDDEN.into_response();
        }
    }
    next.run(req).await
}

/// The name or address of a `Host` header, without its port or brackets.
pub(crate) fn host_name(host: &str) -> &str {
    match host.strip_prefix('[') {
        Some(rest) => rest.split(']').next().unwrap_or(""),
        None => host.split(':').next().unwrap_or(""),
    }
}

/// Keeps the API and the socket to the server's own pages. A browser sends no
/// `Origin` with a picture or script that another site's page embeds, but it says
/// where the request comes from. Clients that say nothing pass.
async fn own_pages_only(req: Request, next: Next) -> Response {
    let from = req
        .headers()
        .get("sec-fetch-site")
        .and_then(|site| site.to_str().ok());
    if from.is_some_and(|site| site != "same-origin" && site != "none") {
        return StatusCode::FORBIDDEN.into_response();
    }
    next.run(req).await
}

/// Binds the first free port in `ports` on localhost.
pub async fn bind_local(ports: RangeInclusive<u16>) -> std::io::Result<TcpListener> {
    TcpListener::from_std(bind_first(IpAddr::V4(Ipv4Addr::LOCALHOST), ports)?)
}

/// Binds the first free port in `ports` on `host`, non-blocking for tokio;
/// else the last port's error.
fn bind_first(host: IpAddr, ports: RangeInclusive<u16>) -> std::io::Result<std::net::TcpListener> {
    let mut last_err = None;
    for port in ports {
        match std::net::TcpListener::bind((host, port)) {
            Ok(bound) => {
                bound.set_nonblocking(true)?;
                return Ok(bound);
            }
            Err(e) => last_err = Some(e),
        }
    }
    Err(last_err.unwrap_or_else(|| std::io::Error::other("empty port range")))
}

pub async fn serve(
    listener: TcpListener,
    app: Router,
    shutdown: impl Future<Output = ()> + Send + 'static,
) -> std::io::Result<()> {
    let app = app.into_make_service_with_connect_info::<SocketAddr>();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown)
        .await
}

#[cfg(test)]
mod tests {
    use super::{account_name_from, unless_restored};
    use std::sync::{Mutex, atomic::AtomicU64};

    #[test]
    fn work_begun_before_a_restore_ended_is_refused() {
        let (restores, guarded) = (AtomicU64::new(1), Mutex::default());
        let refused = unless_restored(&restores, &guarded, 0, || ()).unwrap_err();
        assert_eq!(refused.code, cw_core::Code::RestoreBusy);
        assert!(unless_restored(&restores, &guarded, 1, || ()).is_ok());
    }

    #[test]
    fn this_computers_account_is_first_called_by_the_systems_user_name() {
        let windows = |key: &str| (key == "USERNAME").then(|| "rowan".to_string());
        assert_eq!(account_name_from(windows), "rowan");
        let test = |key: &str| Some(key.to_lowercase());
        assert_eq!(account_name_from(test), "cardwave_user");
        assert_eq!(account_name_from(|_: &str| None), "");
    }
}

//! The typed API. Every type that crosses the wire derives `TS`, so `cargo test`
//! writes its TypeScript twin to `web/src/api/generated/`. A flagged item hands
//! its three setters to `Flags::apply` and flattens `Flags` into its change
//! type. Every error answer is an `ErrorBody` of the one list (cw-core).
//!
//! Who a request acts for is `Caller` (`who`, before every API path and the
//! socket): the page's session's account, else on this computer its own; a page
//! of another device without a session gets 401 `SIGN_IN`, but on `OPEN` paths.
//! `User` is the caller's account, `Owner` this computer's.
//!
//! A change is told over `/ws` to every page but the one that made it
//! (`events`, by `x-cardwave-page`, [`Page`]).
//! PUT sets what its path names as a whole; PATCH changes the fields its body
//! names. A file sent alone is the raw body; one with other fields is base64 in
//! a JSON body.

pub(crate) mod accounts;
pub mod app_tools;
mod assistant;
mod attachments;
mod backup;
mod cache;
pub(crate) mod card_folder;
mod card_pictures;
mod cards;
mod chats;
mod coding;
pub(crate) mod companion;
pub(crate) mod describe;
pub(crate) mod dictation;
mod documents;
mod errors;
mod events;
mod expressions;
mod figures;
pub(crate) mod find;
pub(crate) mod generate;
mod generator;
mod held;
mod images;
mod interview;
mod kinds;
mod languages;
mod lorebooks;
pub(crate) mod mcp;
mod memory;
mod noted;
pub(crate) mod password;
mod personas;
mod presets;
mod prompt_presets;
mod provider;
mod rewrite;
pub(crate) mod search;
pub(crate) mod settings;
mod trash;
mod unsaved;
pub(crate) mod voice;
mod voices;
mod written;

use std::convert::Infallible;
use std::sync::Arc;

use axum::Json;
use axum::Router;
use axum::extract::{FromRequestParts, Request, State};
use axum::http::request::Parts;
use axum::http::{HeaderMap, StatusCode, header};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::routing::{any, get};
use cw_core::{Code, Fail};
use cw_store::Db;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::{AppState, Remote};

pub(crate) use errors::{
    ApiError, ApiResult, body_of, error_body, failed_here, http_status, owner_only,
};
pub(crate) use events::{Pushed, ReplyEvent};
pub use noted::noted;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/status", get(status))
        .route("/ws", get(events::events))
        .merge(accounts::routes())
        .merge(assistant::routes())
        .merge(attachments::routes())
        .merge(backup::routes())
        .merge(cache::routes())
        .merge(cards::routes())
        .merge(card_folder::routes())
        .merge(card_pictures::routes())
        .merge(chats::routes())
        .merge(coding::routes())
        .merge(companion::routes())
        .merge(describe::routes())
        .merge(documents::routes())
        .merge(expressions::routes())
        .merge(figures::routes())
        .merge(find::routes())
        .merge(generate::routes())
        .merge(generator::routes())
        .merge(interview::routes())
        .merge(images::routes())
        .merge(lorebooks::routes())
        .merge(mcp::routes())
        .merge(memory::routes())
        .merge(password::routes())
        .merge(personas::routes())
        .merge(presets::routes())
        .merge(prompt_presets::routes())
        .merge(provider::routes())
        .merge(kinds::routes())
        .merge(rewrite::routes())
        .merge(languages::routes())
        .merge(search::routes())
        .merge(settings::routes())
        .merge(trash::routes())
        .merge(unsaved::routes())
        .merge(voice::routes())
        .merge(dictation::routes())
        .merge(voices::routes())
        .merge(written::routes())
        // Unknown API paths are a real 404, not the SPA fallback's index.html.
        .route("/api/{*rest}", any(|| async { StatusCode::NOT_FOUND }))
}

#[derive(Serialize, TS)]
#[ts(export)]
pub struct Status {
    pub app: String,
    pub version: String,
    /// When the server was built, in ms since 1970 (`build.rs`).
    pub built: i64,
    /// Whether files can be moved to the Recycle Bin here, which Settings › Data's switch needs.
    pub(crate) recycle_bin: bool,
}

/// Paths that answer a page signed in to no account.
const OPEN: [&str; 2] = ["/api/status", "/api/sign-in"];

/// The header that says a page is to sign in.
pub(crate) const SIGN_IN: &str = "x-cardwave-sign-in";

/// The API without its sign-in, built once (`open`) and handed to every
/// request, also those asked of it in-process (`app_tools::request`), which
/// MCP and Cardwave's tools ask as the caller.
#[derive(Clone)]
pub(crate) struct Api(pub(crate) Router);

/// Who a request acts for (`who`).
#[derive(Clone)]
pub(crate) struct Caller {
    pub user: i64,
    /// The session the request came by, where it came by one.
    pub session: Option<Arc<str>>,
    /// Whether it comes from another device, by the home network.
    pub remote: bool,
}

/// The value of the cookie `name` of a request.
pub(crate) fn cookie(headers: &HeaderMap, name: &str) -> Option<String> {
    headers
        .get_all(header::COOKIE)
        .iter()
        .filter_map(|value| value.to_str().ok())
        .flat_map(|value| value.split(';'))
        .filter_map(|pair| pair.trim().split_once('='))
        .find(|(key, _)| *key == name)
        .map(|(_, value)| value.to_string())
}

/// The answer to a page that is to sign in.
fn signed_out() -> Response {
    ([(SIGN_IN, "1")], ApiError::from(Fail::new(Code::SignIn))).into_response()
}

/// The user a request acts for: its session's, else this computer's own user; none for another device signed out.
fn user_of(state: &AppState, session: Option<&str>, remote: bool) -> Option<i64> {
    match session {
        Some(token) => state.sessions.user(token),
        None => (!remote).then(|| state.local_user()),
    }
}

/// A page's policy lets pictures from the web load while its user's Settings show them in messages
/// ("Show pictures from other websites"), from the page loaded after a change; else the stricter
/// [`crate::PAGE_POLICY`] of every answer stands. A page is told by its address, not its answer's type:
/// a page loaded again may be answered "not modified", whose policy the browser takes too.
pub(crate) async fn page_policy(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Response {
    let path = request.uri().path();
    let name = path.rsplit('/').next().unwrap_or_default();
    let page = !path.starts_with("/api/")
        && path != "/ws"
        && (name.ends_with(".html") || !name.contains('.'));
    let remote = request.extensions().get::<Remote>().is_some();
    let session = cookie(request.headers(), state.sessions.cookie());
    let user = user_of(&state, session.as_deref(), remote).filter(|_| page);
    let mut response = next.run(request).await;
    if let Some(user) = user
        && !response
            .headers()
            .contains_key(header::CONTENT_SECURITY_POLICY)
    {
        match settings::web_pictures(&state, user).await {
            Ok(true) => {
                response.headers_mut().insert(
                    header::CONTENT_SECURITY_POLICY,
                    header::HeaderValue::from_static(crate::WEB_PAGE_POLICY),
                );
            }
            Ok(false) => {}
            // The stricter policy stands.
            Err(failure) => tracing::warn!("{failure:#}"),
        }
    }
    response
}

/// Finds who a request acts for, and answers one that is to sign in.
pub(crate) async fn who(
    State(state): State<AppState>,
    mut request: Request,
    next: Next,
) -> Response {
    let remote = request.extensions().get::<Remote>().is_some();
    let session = cookie(request.headers(), state.sessions.cookie());
    match user_of(&state, session.as_deref(), remote) {
        Some(user) => {
            let session = session.map(Arc::from);
            request.extensions_mut().insert(Caller {
                user,
                session,
                remote,
            });
        }
        None if OPEN.contains(&request.uri().path()) => {}
        None => return signed_out(),
    }
    next.run(request).await
}

impl FromRequestParts<AppState> for Caller {
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, _state: &AppState) -> Result<Self, Response> {
        parts
            .extensions
            .get::<Self>()
            .cloned()
            .ok_or_else(signed_out)
    }
}

/// The account a request acts for.
pub struct User(pub i64);

impl FromRequestParts<AppState> for User {
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Response> {
        Ok(Self(Caller::from_request_parts(parts, state).await?.user))
    }
}

/// This computer's account, where a request acts for it; another's is answered 403.
pub struct Owner(pub i64);

impl FromRequestParts<AppState> for Owner {
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Response> {
        let User(user) = User::from_request_parts(parts, state).await?;
        if user != state.local_user() {
            let refused = owner_only("do that");
            return Err(ApiError::from(refused).into_response());
        }
        Ok(Self(user))
    }
}

/// The page a request comes from, by the mark it calls itself in the header
/// `x-cardwave-page`, so that it is not told of its own change. A request
/// without one, or with one longer than [`PAGE_MARK`] bytes, is no page's.
pub struct Page(Option<Arc<str>>);

/// The header in which a page sends its mark.
pub(crate) const PAGE_HEADER: &str = "x-cardwave-page";

/// How long a page's mark may be, in bytes.
pub(crate) const PAGE_MARK: usize = 64;

/// A page's mark as it is kept: none where it is empty or too long.
fn mark(text: &str) -> Option<Arc<str>> {
    Some(text)
        .filter(|text| !text.is_empty() && text.len() <= PAGE_MARK)
        .map(Arc::from)
}

impl FromRequestParts<AppState> for Page {
    type Rejection = Infallible;

    async fn from_request_parts(parts: &mut Parts, _state: &AppState) -> Result<Self, Infallible> {
        let header = parts.headers.get(PAGE_HEADER);
        Ok(Self(
            header.and_then(|value| value.to_str().ok()).and_then(mark),
        ))
    }
}

/// Changes to a library item or a chat; what is left out stays as it is.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct Flags {
    pub favorite: Option<bool>,
    pub archived: Option<bool>,
    pub trashed: Option<bool>,
}

/// A text, lorebook or entry as a card names it, `TYPE.ID` (`lorebook.ID`):
/// whose drafts are asked for, which lorebook a card brings is copied or moved.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct Reference {
    pub reference: String,
}

/// The word for a copy in the user's language, which a copy's name ends in:
/// "Rig (copy)". The page sends it; the name then stays as made.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct Copied {
    pub copy: String,
}

/// A lorebook a card brings, to be copied into the library, and the word for
/// a copy ([`Copied`]) its name ends in where the library has one so called.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct CopiedReference {
    pub reference: String,
    pub copy: String,
}

/// What made an edit: `?made=fix` (an AI tool's key), "restored" where an
/// earlier draft was gone back to; "edited" where none is said.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct Made {
    pub made: Option<String>,
}

type SetFlag = fn(&Db, i64, i64, bool) -> anyhow::Result<()>;

impl Flags {
    /// Makes the changes with an item's setters for favorite, archived and trashed.
    fn apply(&self, db: &Db, user: i64, id: i64, setters: [SetFlag; 3]) -> anyhow::Result<()> {
        for (flag, set) in [self.favorite, self.archived, self.trashed]
            .into_iter()
            .zip(setters)
        {
            if let Some(flag) = flag {
                set(db, user, id, flag)?;
            }
        }
        Ok(())
    }

    /// Whether the change puts the item in the Trash or takes it out.
    fn trashes(&self) -> bool {
        self.trashed.is_some()
    }
}

/// A stored file the browser must not run, asked anew each time: its number
/// may come again after it was deleted.
fn fresh_file(content_type: &'static str, data: Vec<u8>) -> Response {
    stored_file(content_type, data, "private, no-cache")
}

/// A stored file the browser must not run, even when it is opened as a page,
/// kept by the browser as `cache` (its Cache-Control) says.
fn stored_file(content_type: &'static str, data: Vec<u8>, cache: &'static str) -> Response {
    let headers = [
        (header::CONTENT_TYPE, content_type),
        (
            header::CONTENT_SECURITY_POLICY,
            "default-src 'none'; sandbox",
        ),
        (header::CACHE_CONTROL, cache),
    ];
    (headers, data).into_response()
}

/// The file's name, where the page sends it (`?name=coast.json`).
#[derive(Deserialize)]
struct FileName {
    name: Option<String>,
}

impl AppState {
    /// Runs storage work. The database is synchronous, so the work goes to a
    /// thread that may block.
    pub(crate) async fn work<T: Send + 'static>(
        &self,
        work: impl FnOnce(&Db) -> anyhow::Result<T> + Send + 'static,
    ) -> anyhow::Result<T> {
        let state = self.clone();
        let done = tokio::task::spawn_blocking(move || work(&state.db)).await;
        done.map_err(|e| errors::internal(e.into()))?
            .map_err(errors::internal)
    }

    /// [`Self::work`] for a request.
    async fn run<T: Send + 'static>(
        &self,
        work: impl FnOnce(&Db) -> anyhow::Result<T> + Send + 'static,
    ) -> ApiResult<T> {
        Ok(self.work(work).await?)
    }
}

fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

async fn status() -> Json<Status> {
    Json(Status {
        app: "cardwave".into(),
        version: version(),
        built: env!("CARDWAVE_BUILT").parse().unwrap_or_default(),
        recycle_bin: cw_platform::sys::RECYCLE_BIN,
    })
}

// Every route as a tool (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/api.rs"));

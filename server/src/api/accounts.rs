//! Accounts over HTTP: signing in, the server's accounts, an account's picture,
//! and whether the home network reaches the server.
//!
//! `GET /api/sign-in` says whether to sign in (`SignIn`) and to which accounts;
//! `POST /api/sign-in` signs in (`SignInWith`), replacing the page's session,
//! and sets its cookie (cw-accounts' `sessions`); `POST /api/sign-out` ends it.
//! This computer's account signs in by the database's password (`password`), or
//! on this computer without one where none is on; another by its own; wrong ones
//! are held back (`password::Tries`). `GET /api/accounts` lists those the page
//! can switch to; this computer's account adds one (`POST`), resets its password
//! (`PUT /api/accounts/{id}/password`) or deletes it with all it holds
//! (`DELETE`), ending its sessions. `/api/account` is the page's own account
//! (`PUT` renames it), `/api/account/picture` its picture.
//! `/api/network` (this computer's account alone) says and sets whether other
//! devices reach the server (`users::reached`) and the address they open, found
//! by the way out to the internet (`this_computer`).

use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, FromRequestParts, Path, State};
use axum::http::request::Parts;
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_accounts::password;
use cw_accounts::users::{self, Listed};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_store::Db;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, Caller, Owner, User, cookie};
use crate::{AppState, Remote, peer};

/// The account a page acts for.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct Account {
    /// What the user is called.
    pub name: String,
    /// Whether it is this computer's account, the one a server has without a
    /// login.
    pub local: bool,
    /// The address of its picture, where it has one.
    pub picture: Option<String>,
}

impl From<cw_accounts::users::Called> for Account {
    fn from(called: cw_accounts::users::Called) -> Self {
        Self {
            name: called.name,
            local: called.local,
            picture: called
                .picture_at
                .map(|at| format!("/api/account/picture?at={at}")),
        }
    }
}

/// Another name for the account.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct RenameAccount {
    pub name: String,
}

/// How long a page's cookie keeps its session, in seconds: as long as a
/// browser keeps one (400 days); the session ends before by itself.
const KEPT: u32 = 400 * 24 * 60 * 60;

/// The largest picture taken, in bytes, before it is made small.
pub(super) const PICTURE_LIMIT: usize = 16 * 1024 * 1024;

pub(super) fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/account", get(account).put(rename_account))
        .route("/api/sign-in", get(signing_in).post(sign_in))
        .route("/api/sign-out", post(sign_out))
        .route("/api/accounts", get(list).post(add))
        .route("/api/accounts/{id}", axum::routing::delete(delete))
        .route("/api/accounts/{id}/password", put(reset))
        .route(
            "/api/account/picture",
            get(picture)
                .put(set_picture)
                .delete(remove_picture)
                .layer(DefaultBodyLimit::max(PICTURE_LIMIT)),
        )
        .route("/api/network", get(network).put(set_network))
}

/// Whether the page is to sign in, and to which accounts it can.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct SignIn {
    /// Whether the page is to sign in before anything else: one of another
    /// device without a session, or one whose session ended.
    pub needed: bool,
    /// Whether the page is of another device, by the home network.
    pub remote: bool,
    /// The accounts the page can sign in to, this computer's first.
    pub accounts: Vec<AccountLine>,
}

/// An account as a page lists it.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct AccountLine {
    pub id: i64,
    pub name: String,
    /// Whether it is this computer's account.
    pub local: bool,
    /// Whether the page is signed in to it.
    pub current: bool,
    /// Whether signing in to it from the page asks for its password.
    pub password: bool,
}

/// An account signed in to, with its password where it asks for one.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct SignInWith {
    pub account: i64,
    pub password: Option<String>,
}

/// An account for someone else: a name and a password.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct NewAccount {
    pub name: String,
    pub password: String,
}

/// Another password for an account.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct ResetPassword {
    pub password: String,
}

/// Whether other devices of the home network reach the server, and the
/// address they open.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct NetworkState {
    pub on: bool,
    /// Where another device opens Cardwave, while it reaches it; none where
    /// this computer's address in the network is not found.
    pub address: Option<String>,
}

/// Other devices reach the server, or no longer.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct SetNetwork {
    pub on: bool,
}

/// Where a request comes from: another device or this computer, the session
/// its cookie holds, who it acts for where it acts for one, and its peer.
struct Visit {
    remote: bool,
    session: Option<String>,
    caller: Option<Caller>,
    peer: IpAddr,
}

impl FromRequestParts<AppState> for Visit {
    type Rejection = std::convert::Infallible;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        Ok(Self {
            remote: parts.extensions.get::<Remote>().is_some(),
            session: cookie(&parts.headers, state.sessions.cookie()),
            caller: parts.extensions.get::<Caller>().cloned(),
            peer: peer(&parts.extensions),
        })
    }
}

/// Whether `account` asks for a password to sign in from a page `remote` or
/// not, where a password is `on` for the database or not; none where it cannot
/// sign in from there: this computer's account from another device without a
/// password, and an account without a password of its own.
fn asks(account: &Listed, on: bool, remote: bool) -> Option<bool> {
    match account.local {
        true if on => Some(true),
        true => (!remote).then_some(false),
        false => account.password.then_some(true),
    }
}

/// The accounts a page `remote` or not can sign in to, `user` being the one it is signed in to.
fn lines(db: &Db, on: bool, remote: bool, user: Option<i64>) -> anyhow::Result<Vec<AccountLine>> {
    Ok(users::list(db)?
        .into_iter()
        .filter_map(|account| {
            let password = asks(&account, on, remote)?;
            Some(AccountLine {
                current: Some(account.id) == user,
                id: account.id,
                name: account.name,
                local: account.local,
                password,
            })
        })
        .collect())
}

async fn signing_in(State(state): State<AppState>, visit: Visit) -> ApiResult<Json<SignIn>> {
    let on = password::is_on(&state.data_dir);
    let user = visit.caller.as_ref().map(|caller| caller.user);
    let remote = visit.remote;
    let accounts = state.run(move |db| lines(db, on, remote, user)).await?;
    Ok(Json(SignIn {
        needed: visit.caller.is_none(),
        remote,
        accounts,
    }))
}

/// The cookie `name` that holds `token`, or that ends the one held (`None`).
fn session_cookie(name: &str, token: Option<&str>) -> String {
    match token {
        Some(token) => format!("{name}={token}; Path=/; HttpOnly; SameSite=Strict; Max-Age={KEPT}"),
        None => format!("{name}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"),
    }
}

async fn sign_in(
    State(state): State<AppState>,
    visit: Visit,
    Json(with): Json<SignInWith>,
) -> ApiResult<Response> {
    let held = state.clone();
    let token = tokio::task::spawn_blocking(move || -> anyhow::Result<String> {
        let db = &held.db;
        let account = users::list(db)?
            .into_iter()
            .find(|account| account.id == with.account)
            .ok_or(NotFound("account"))?;
        let on = password::is_on(&held.data_dir);
        let asks = asks(&account, on, visit.remote).ok_or(Fail::new(Code::RemoteSignInOff))?;
        // This computer's account has the database's password, which the start screen is given too.
        let scope = (!account.local).then_some(account.id);
        held.tries.attempt(scope, visit.peer, || {
            if !asks {
                return Ok(());
            }
            let given = with
                .password
                .as_deref()
                .ok_or(Fail::new(Code::PasswordNeeded))?;
            match account.local {
                true => {
                    let (sealed, _) =
                        password::read(&held.data_dir)?.ok_or(Fail::new(Code::NoPasswordOn))?;
                    password::unseal(&sealed, given).map(drop)
                }
                false => {
                    let kept = users::password_of(db, account.id)?
                        .ok_or(Fail::new(Code::NoPasswordSet))?;
                    password::verify(&kept, given)
                }
            }
        })?;
        if let Some(had) = &visit.session {
            held.sessions.end(db, had)?;
        }
        held.sessions.start(db, account.id)
    })
    .await??;
    let cookie = session_cookie(state.sessions.cookie(), Some(&token));
    Ok((StatusCode::NO_CONTENT, [(header::SET_COOKIE, cookie)]).into_response())
}

async fn sign_out(State(state): State<AppState>, visit: Visit) -> ApiResult<Response> {
    if let Some(had) = visit.session {
        let held = state.clone();
        state.run(move |db| held.sessions.end(db, &had)).await?;
    }
    let cookie = session_cookie(state.sessions.cookie(), None);
    Ok((StatusCode::NO_CONTENT, [(header::SET_COOKIE, cookie)]).into_response())
}

async fn list(State(state): State<AppState>, caller: Caller) -> ApiResult<Json<Vec<AccountLine>>> {
    let on = password::is_on(&state.data_dir);
    let lines = state
        .run(move |db| lines(db, on, caller.remote, Some(caller.user)))
        .await?;
    Ok(Json(lines))
}

async fn add(
    State(state): State<AppState>,
    Owner(owner): Owner,
    Json(new): Json<NewAccount>,
) -> ApiResult<(StatusCode, Json<AccountLine>)> {
    let line = tokio::task::spawn_blocking(move || -> anyhow::Result<AccountLine> {
        let id = users::add(&state.db, &new.name, &new.password)?;
        let called = users::account(&state.db, id)?;
        Ok(AccountLine {
            id,
            name: called.name,
            local: false,
            current: id == owner,
            password: true,
        })
    })
    .await??;
    Ok((StatusCode::CREATED, Json(line)))
}

async fn reset(
    State(state): State<AppState>,
    Owner(_): Owner,
    Path(id): Path<i64>,
    Json(new): Json<ResetPassword>,
) -> ApiResult<StatusCode> {
    tokio::task::spawn_blocking(move || -> anyhow::Result<()> {
        users::set_password(&state.db, id, &new.password)?;
        // Who knew the old password is signed out.
        state.sessions.end_all(&state.db, id, None)
    })
    .await??;
    Ok(StatusCode::NO_CONTENT)
}

async fn delete(
    State(state): State<AppState>,
    Owner(owner): Owner,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    if id == owner {
        return Err(NotFound("account").into());
    }
    let held = state.clone();
    state
        .run(move |db| {
            // Held to the delete, so no work the check would find begins in between.
            let _held = cw_core::lock(&held.guarded);
            // What would write into an account that is gone.
            let busy = held.replies().keys().any(|(user, _)| *user == id)
                || held.describing().contains_key(&id)
                || held.remembering().values().any(|user| *user == id)
                || held.coding().values().any(|task| task.user() == id)
                || held.user_at_work(id);
            anyhow::ensure!(!busy, Fail::new(Code::AccountBusy));
            users::delete(db, id)?;
            // After the account, so that no session begins between the two.
            held.sessions.end_all(db, id, None)
        })
        .await?;
    // A later account may be given its number.
    state.web_pictures().remove(&id);
    Ok(StatusCode::NO_CONTENT)
}

async fn picture(State(state): State<AppState>, User(user): User) -> ApiResult<Response> {
    let picture = state.run(move |db| users::picture(db, user)).await?;
    let picture = picture.ok_or(NotFound("picture"))?;
    Ok(([(header::CONTENT_TYPE, "image/png")], picture).into_response())
}

/// Gives the account the picture sent, or takes it away (`None`), and tells its pages.
async fn picture_set(state: AppState, user: i64, file: Option<Bytes>) -> ApiResult<Json<Account>> {
    let account = state
        .run(move |db| {
            users::set_picture(db, user, file.as_deref())?;
            users::account(db, user)
        })
        .await?;
    let account = Account::from(account);
    told_account(&state, user, &account);
    Ok(Json(account))
}

async fn set_picture(
    State(state): State<AppState>,
    User(user): User,
    file: Bytes,
) -> ApiResult<Json<Account>> {
    picture_set(state, user, Some(file)).await
}

async fn remove_picture(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Account>> {
    picture_set(state, user, None).await
}

/// This computer's address in the home network: the one the way out to the
/// internet leaves by. No packet is sent: a UDP socket only picks its way
/// when it is connected.
fn this_computer() -> Option<IpAddr> {
    let probe = std::net::UdpSocket::bind((Ipv4Addr::UNSPECIFIED, 0)).ok()?;
    probe.connect((Ipv4Addr::new(192, 0, 2, 1), 9)).ok()?;
    Some(probe.local_addr().ok()?.ip()).filter(|ip| !ip.is_unspecified())
}

/// The state of the home network's listener at `at`.
fn network_state(at: Option<SocketAddr>) -> NetworkState {
    let address = at.and_then(|at| {
        let host = match at.ip().is_unspecified() {
            true => this_computer()?,
            false => at.ip(),
        };
        Some(format!("http://{}/", SocketAddr::new(host, at.port())))
    });
    NetworkState {
        on: at.is_some(),
        address,
    }
}

async fn network(State(state): State<AppState>, Owner(_): Owner) -> ApiResult<Json<NetworkState>> {
    let at = state.gate().and_then(|gate| gate.listening());
    Ok(Json(network_state(at)))
}

async fn set_network(
    State(state): State<AppState>,
    Owner(_): Owner,
    Json(set): Json<SetNetwork>,
) -> ApiResult<Json<NetworkState>> {
    let gate = state.gate().ok_or(Fail::new(Code::Stopping))?;
    let at = gate.listen(set.on)?;
    let on = set.on;
    if let Err(failure) = state.run(move |db| users::set_reached(db, on)).await {
        // The listener stays as the database says.
        let _ = gate.listen(!set.on);
        return Err(failure);
    }
    Ok(Json(network_state(at)))
}

async fn account(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Account>> {
    let called = state
        .run(move |db| cw_accounts::users::account(db, user))
        .await?;
    Ok(Json(called.into()))
}

/// Tells the pages of `user` the account as it is now.
fn told_account(state: &AppState, user: i64, account: &Account) {
    let event = PageEvent::Account {
        name: account.name.clone(),
        local: account.local,
        picture: account.picture.clone(),
    };
    state.push(user, &event);
}

/// Gives the account another name, and tells the user's pages, which show it
/// in the rail.
async fn rename_account(
    State(state): State<AppState>,
    User(user): User,
    Json(new): Json<RenameAccount>,
) -> ApiResult<Json<Account>> {
    let held = state.clone();
    let renamed = state
        .run(move |db| {
            let renamed = cw_accounts::users::rename(db, user, &new.name)?;
            // The start screen shows the name of this computer's account before the database is open.
            if renamed.local {
                let _held = cw_core::lock(&held.guarded);
                cw_accounts::password::rename(&held.data_dir, &renamed.name)?;
            }
            Ok(renamed)
        })
        .await?;
    let account = Account::from(renamed);
    told_account(&state, user, &account);
    Ok(Json(account))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/accounts.rs"));

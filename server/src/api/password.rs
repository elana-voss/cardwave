//! The password over HTTP (`password.rs`).
//!
//! The gate's own routes, answered before the app is open too (`gate_routes`):
//! `GET /api/lock` says whether the server waits for the password, whether one
//! is on and, while it waits, the account's name for the start screen; `POST
//! /api/unlock` tries a password, 401 where it is wrong, and opens the app.
//! `POST /api/password/lock` ("Lock") has the app wait for it again; this
//! computer's account's alone, and only while a password is on.
//! The app's: `PUT /api/password` switches it on (`password` alone), changes it
//! (`current` and `password`) or switches it off (`current` alone), 401 where
//! `current` is wrong or missing; for another account than this computer's it
//! changes that account's own password, which cannot be switched off. Wrong
//! passwords are held back (`password::Tries`, 429), and a password changed or
//! switched off ends the account's other sessions.

use std::sync::Arc;

use axum::extract::{ConnectInfo, State};
use axum::http::StatusCode;
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_accounts::password;
use cw_accounts::users;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use std::net::SocketAddr;

use super::{ApiResult, Caller, owner_only};
use crate::{AppState, Gate};

pub(crate) fn gate_routes() -> Router<Arc<Gate>> {
    Router::new()
        .route("/api/lock", get(lock))
        .route("/api/unlock", post(unlock))
}

pub(super) fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/password", put(change))
        .route("/api/password/lock", post(close))
}

/// Whether the app waits for its password.
#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct LockState {
    /// Whether the server waits for the password before it opens anything.
    pub(crate) locked: bool,
    /// Whether a password is on: the app asks for it whenever it starts.
    pub password: bool,
    /// The account's name, while the server waits.
    pub name: Option<String>,
}

/// The password the start screen was given.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct Unlock {
    pub password: String,
}

/// A password switched on (`password`), changed (`current` and `password`) or
/// switched off (`current`).
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct ChangePassword {
    pub current: Option<String>,
    pub password: Option<String>,
}

async fn lock(State(gate): State<Arc<Gate>>) -> ApiResult<Json<LockState>> {
    let locked = !gate.is_open();
    let name = match locked {
        true => password::read(gate.data_dir())?.map(|(_, name)| name),
        false => None,
    };
    Ok(Json(LockState {
        locked,
        password: password::is_on(gate.data_dir()),
        name,
    }))
}

async fn unlock(
    State(gate): State<Arc<Gate>>,
    ConnectInfo(from): ConnectInfo<SocketAddr>,
    Json(Unlock { password }): Json<Unlock>,
) -> ApiResult<StatusCode> {
    // One try at a time: a second waits, and finds the app open where the first opened it.
    let _one = gate.trying().await;
    if !gate.is_open() {
        let gate = gate.clone();
        // An app locked again opens as it was: the password is tried all the same.
        tokio::task::spawn_blocking(move || {
            let (sealed, _) =
                password::read(gate.data_dir())?.ok_or(Fail::new(Code::NoPasswordOn))?;
            let key = gate
                .tries
                .attempt(None, from.ip(), || password::unseal(&sealed, &password))?;
            gate.open(key)?;
            // Where the app stopped as the password was switched on, the store may hold the key still.
            if let Err(failure) = gate.opts.key.forget(gate.data_dir()) {
                tracing::warn!("{failure:#}");
            }
            anyhow::Ok(())
        })
        .await??;
    }
    Ok(StatusCode::NO_CONTENT)
}

/// Locks the app until the password is given again.
async fn close(State(state): State<AppState>, caller: Caller) -> ApiResult<StatusCode> {
    if caller.user != state.local_user() {
        Err(owner_only("lock Cardwave"))?;
    }
    if !password::is_on(&state.data_dir) {
        Err(Fail::new(Code::NoPasswordToLock))?;
    }
    if let Some(gate) = state.gate() {
        gate.close();
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn change(
    State(state): State<AppState>,
    caller: Caller,
    ConnectInfo(from): ConnectInfo<SocketAddr>,
    Json(asked): Json<ChangePassword>,
) -> ApiResult<Json<LockState>> {
    let on = tokio::task::spawn_blocking(move || {
        let (current, new) = (asked.current.as_deref(), asked.password.as_deref());
        let on = match caller.user == state.local_user() {
            true => set(&state, caller.user, from, current, new)?,
            false => set_own(&state, caller.user, from, current, new)?,
        };
        // Who knew the old password, on another device, is signed out; this page stays.
        let session = caller.session.as_deref();
        state.sessions.end_all(&state.db, caller.user, session)?;
        anyhow::Ok(on)
    })
    .await??;
    Ok(Json(LockState {
        locked: false,
        password: on,
        name: None,
    }))
}

/// Switches the password on, changes it or switches it off, as [`ChangePassword`]
/// says; answers whether one is on after that. On, the key leaves the place
/// it was kept in; off, it goes back there.
fn set(
    state: &AppState,
    user: i64,
    from: SocketAddr,
    current: Option<&str>,
    new: Option<&str>,
) -> anyhow::Result<bool> {
    let inner = &state.0;
    let _held = cw_core::lock(&inner.guarded);
    let dir = &inner.data_dir;
    let Some((sealed, name)) = password::read(dir)? else {
        let new = new.ok_or(Fail::new(Code::NoPasswordOn))?;
        let name = users::account(&inner.db, user)?.name;
        password::write(dir, &password::seal(&inner.key, new)?, &name)?;
        if let Err(failure) = inner.place.forget(dir) {
            password::remove(dir)?;
            return Err(failure);
        }
        return Ok(true);
    };
    let current = current.ok_or(Fail::new(Code::CurrentPasswordNeeded))?;
    state
        .tries
        .attempt(None, from.ip(), || password::unseal(&sealed, current))?;
    match new {
        Some(new) => {
            password::write(dir, &password::seal(&inner.key, new)?, &name)?;
            Ok(true)
        }
        None => {
            inner.place.keep(dir, &inner.key)?;
            password::remove(dir)?;
            Ok(false)
        }
    }
}

/// Changes the password of `user`, another account than this computer's,
/// from `current` to `new`; it cannot be switched off.
fn set_own(
    state: &AppState,
    user: i64,
    from: SocketAddr,
    current: Option<&str>,
    new: Option<&str>,
) -> anyhow::Result<bool> {
    let new = new.ok_or(Fail::new(Code::PasswordKept))?;
    let current = current.ok_or(Fail::new(Code::CurrentPasswordNeeded))?;
    let kept = users::password_of(&state.db, user)?.ok_or(Fail::new(Code::NoPasswordSet))?;
    state
        .tries
        .attempt(Some(user), from.ip(), || password::verify(&kept, current))?;
    users::set_password(&state.db, user, new)?;
    Ok(true)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/password.rs"));

//! The app's updates, by Tauri's updater: `update_check` asks the feed
//! (`plugins.updater.endpoints` in tauri.conf.json, the `latest.json` the
//! installer's build on GitHub attaches to each release) for a newer version
//! and keeps it; `update_install` downloads that one, installs it and starts
//! the app anew. Only an installer signed with the project's key (its public
//! half is `plugins.updater.pubkey`) is installed: the updater refuses any
//! other. When and whether to check is the page's (web/src/settings/update.ts).
//!
//! Trap: on Windows the installer ends the app itself as it starts, so
//! `restart` is reached only where it does not.

use std::sync::Mutex;

use serde::Serialize;
use tauri::{AppHandle, State};
use tauri_plugin_updater::{Update, UpdaterExt};

/// The newer version the last check found, which "Update and restart" installs.
#[derive(Default)]
pub struct Pending(Mutex<Option<Update>>);

/// What a check found: this version, and the newer one with its notes where
/// there is one.
#[derive(Serialize)]
pub struct Checked {
    current: String,
    latest: Option<String>,
    notes: Option<String>,
}

/// Asks the feed for a newer version than this one.
#[tauri::command]
pub async fn update_check(app: AppHandle, pending: State<'_, Pending>) -> Result<Checked, String> {
    let update = app
        .updater()
        .map_err(|e| e.to_string())?
        .check()
        .await
        .map_err(|e| {
            tracing::warn!("the update check failed: {e}");
            e.to_string()
        })?;
    let found = Checked {
        current: app.package_info().version.to_string(),
        latest: update.as_ref().map(|update| update.version.clone()),
        notes: update
            .as_ref()
            .and_then(|update| update.body.clone())
            .filter(|notes| !notes.trim().is_empty()),
    };
    *pending.0.lock().map_err(|e| e.to_string())? = update;
    Ok(found)
}

/// Downloads the version the last check found, installs it and starts the app anew.
/// The version stays kept, so "Update and restart" can be pressed again after a failure.
#[tauri::command]
pub async fn update_install(app: AppHandle, pending: State<'_, Pending>) -> Result<(), String> {
    let update = pending.0.lock().map_err(|e| e.to_string())?.clone();
    let Some(update) = update else {
        return Err("no newer version was found".into());
    };
    update
        .download_and_install(|_, _| {}, || {})
        .await
        .map_err(|e| e.to_string())?;
    app.restart()
}

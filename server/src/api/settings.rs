//! The user's settings over HTTP. Of the tools, files and commands and their
//! folder are this computer's account's alone (403 for another), and are
//! switched on only with a folder that is there and is neither Cardwave's
//! data folder, one that holds it, nor a drive's root (`tools_checked`). So is
//! the folder of cards, which must be a folder that is there and no drive's root, and its Recycle
//! Bin is Windows' alone (`card_folder_checked`). A change tells the user's
//! other pages (`PageEvent::Settings`).

use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use cw_coding::tools::sandbox;
use cw_core::PageEvent;
use cw_core::{Code, Fail};
use cw_library::settings::{self, ChangeCardFolder, ChangeSettings, ChangeTools, Settings};

use std::path::Path;

use anyhow::ensure;

use super::{ApiResult, Page, User, owner_only};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/settings", get(show).patch(change))
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Settings>> {
    state.run(move |db| settings::get(db, user)).await.map(Json)
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(mut change): Json<ChangeSettings>,
) -> ApiResult<Json<Settings>> {
    trimmed(
        change
            .tools
            .as_mut()
            .and_then(|tools| tools.folder.as_mut()),
    );
    trimmed(
        change
            .card_folder
            .as_mut()
            .and_then(|cards| cards.folder.as_mut()),
    );
    if let Some(voice) = &change.voice {
        super::voice::listed(&state, user, voice).await?;
    }
    let owner = user == state.local_user();
    let data = state.data_dir.clone();
    let kept = state.clone();
    let changed = state
        .run(move |db| {
            if let Some(tools) = &change.tools {
                let kept = settings::get(db, user)?.tools.folder;
                tools_checked(tools, &kept, owner, &data)?;
            }
            if let Some(cards) = &change.card_folder {
                card_folder_checked(cards, owner)?;
            }
            // The kept switch's lock spans the write, so it and the stored one change in the same order.
            let mut on = kept.web_pictures();
            let changed = settings::change(db, user, &change)?;
            on.insert(user, changed.web_pictures);
            Ok(changed)
        })
        .await?;
    state.tell(user, &page, &PageEvent::Settings);
    Ok(Json(changed))
}

/// Whether `user`'s Settings show pictures from the web, read once and then kept (`Inner::web_pictures`).
pub(crate) async fn web_pictures(state: &AppState, user: i64) -> anyhow::Result<bool> {
    if let Some(&on) = state.web_pictures().get(&user) {
        return Ok(on);
    }
    let kept = state.clone();
    state
        .work(move |db| {
            // Held while it reads, so a change (`patch_settings`) cannot land between the read and the keeping.
            let mut on = kept.web_pictures();
            if let Some(&known) = on.get(&user) {
                return Ok(known);
            }
            let read = settings::get(db, user)?.web_pictures;
            on.insert(user, read);
            Ok(read)
        })
        .await
}

/// A folder as typed, without the spaces around it.
fn trimmed(folder: Option<&mut String>) {
    if let Some(folder) = folder {
        *folder = folder.trim().to_string();
    }
}

/// Refuses a change of the tools that `owner` (this computer's account or
/// not) may not make, or that leaves files or commands on without a folder;
/// `folder` is the one kept. The folder files and commands are switched on
/// with may not be in Cardwave's data folder `data`, hold it, or be a drive's
/// root (the owner, 2026-10-15).
fn tools_checked(
    change: &ChangeTools,
    folder: &Option<String>,
    owner: bool,
    data: &Path,
) -> anyhow::Result<()> {
    let ChangeTools {
        files,
        ask_writes,
        commands,
        ask_commands,
        folder: new,
        ..
    } = change;
    let disk = [files, ask_writes, commands, ask_commands]
        .iter()
        .any(|set| set.is_some());
    if !owner && (disk || new.is_some()) {
        Err(owner_only("use its files"))?;
    }
    let folder = new.as_ref().or(folder.as_ref());
    let switched_on = *files == Some(true) || *commands == Some(true);
    if let Some(chosen) = folder.filter(|_| new.is_some() || switched_on) {
        settings::folder_checked(chosen, data)?;
    }
    if switched_on {
        ensure!(folder.is_some(), Fail::new(Code::FolderNotChosen));
    }
    if *commands == Some(true) {
        ensure!(sandbox::AVAILABLE, Fail::new(Code::CommandsWindowsOnly));
    }
    Ok(())
}

/// Refuses a change of the folder of cards by another account than this
/// computer's (`owner`), a folder that is not there or a drive's root, and the Recycle Bin where
/// there is none.
fn card_folder_checked(change: &ChangeCardFolder, owner: bool) -> anyhow::Result<()> {
    if !owner {
        Err(owner_only("use its folders"))?;
    }
    if let Some(folder) = &change.folder {
        // Walked every few seconds, a whole drive would never let the computer rest.
        settings::folder_there(folder, Code::DriveRootToWatch)?;
    }
    if change.recycle == Some(true) {
        ensure!(
            cw_platform::sys::RECYCLE_BIN,
            Fail::new(Code::RecycleBinWindowsOnly)
        );
    }
    Ok(())
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/settings.rs"));

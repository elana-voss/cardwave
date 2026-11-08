//! What the app holds once and cards share (expression packs, 3D figures) over HTTP: the part they have alike.
//! `PATCH …/{id}` with `trashed` moves one no card has to the Trash or out, `DELETE` deletes one in the Trash for
//! good; each area gives [`routes`] its two functions. Either tells the user's other pages of the Trash.

use axum::Json;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{MethodRouter, patch};
use cw_store::Db;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

/// A held item moved to the Trash or out.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct ChangeHeld {
    pub trashed: bool,
}

/// PATCH and DELETE of one held item, by the area's `set_trashed` and `delete`.
pub fn routes(
    set_trashed: fn(&Db, i64, i64, bool) -> anyhow::Result<()>,
    delete: fn(&Db, i64, i64) -> anyhow::Result<()>,
) -> MethodRouter<AppState> {
    let change = move |State(state): State<AppState>,
                       User(user): User,
                       page: Page,
                       Path(id): Path<i64>,
                       Json(change): Json<ChangeHeld>| async move {
        state
            .run(move |db| set_trashed(db, user, id, change.trashed))
            .await?;
        super::cards::told_trash(&state, user, &page);
        ApiResult::Ok(StatusCode::NO_CONTENT)
    };
    let remove = move |State(state): State<AppState>,
                       User(user): User,
                       page: Page,
                       Path(id): Path<i64>| async move {
        state.run(move |db| delete(db, user, id)).await?;
        super::cards::told_trash(&state, user, &page);
        ApiResult::Ok(StatusCode::NO_CONTENT)
    };
    patch(change).delete(remove)
}

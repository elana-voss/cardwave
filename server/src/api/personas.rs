//! Personas over HTTP; `/api/personas/{id}/picture` is a persona's picture,
//! `GET`, `PUT` (a PNG or JPEG file, which the page makes of what it is given) and `DELETE`. Each change tells
//! the user's other pages (`told`, `PageEvent::Personas`), and of the Trash where it moved one there or out.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, Query, State};
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, patch};
use axum::{Json, Router};
use cw_core::NotFound;
use cw_core::PageEvent;
use cw_library::personas::{self, Persona};
use cw_library::trash;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/personas", get(list).post(create))
        .route("/api/personas/{id}", patch(change).delete(remove))
        .route(
            "/api/personas/{id}/picture",
            get(picture)
                .put(set_picture)
                .delete(remove_picture)
                .layer(DefaultBodyLimit::max(super::accounts::PICTURE_LIMIT)),
        )
}

async fn picture(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Response> {
    let picture = state.run(move |db| personas::picture(db, user, id)).await?;
    let picture = picture.ok_or(NotFound("picture"))?;
    Ok(([(header::CONTENT_TYPE, "image/png")], picture).into_response())
}

/// Gives the persona the picture sent, or takes it away (`None`).
async fn picture_set(
    (state, page): (AppState, Page),
    user: i64,
    id: i64,
    file: Option<Bytes>,
) -> ApiResult<Json<Persona>> {
    let changed = state
        .run(move |db| {
            personas::set_picture(db, user, id, file.as_deref())?;
            Ok(personas::get(db, user, id)?.ok_or(NotFound("persona"))?)
        })
        .await?;
    told(&state, user, &page);
    Ok(Json(changed))
}

/// Tells the user's pages that the personas were changed, but for the page `from` that changed them.
fn told(state: &AppState, user: i64, from: &Page) {
    state.tell(user, from, &PageEvent::Personas);
}

async fn set_picture(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    file: Bytes,
) -> ApiResult<Json<Persona>> {
    picture_set((state, page), user, id, Some(file)).await
}

async fn remove_picture(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<Json<Persona>> {
    picture_set((state, page), user, id, None).await
}

/// What the list of personas is asked for, in the address: `?q=sea`.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct PersonaQuery {
    /// Words to search for in names and descriptions.
    pub q: Option<String>,
}

#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct NewPersona {
    pub name: String,
    pub description: Option<String>,
    /// The lorebooks of the library it is given, in order.
    pub lorebooks: Option<Vec<i64>>,
}

/// Changes to a persona; what is left out stays as it is. A change that is
/// refused is refused as a whole.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct ChangePersona {
    pub name: Option<String>,
    pub description: Option<String>,
    /// True makes it the persona new chats start with; false takes that back.
    pub is_default: Option<bool>,
    /// The lorebooks of the library it has from now on, in order: those left
    /// out are taken away.
    pub lorebooks: Option<Vec<i64>>,
    /// True puts it in the Trash, false takes it out.
    pub trashed: Option<bool>,
}

/// The personas the library shows; see [`personas::find`].
async fn list(
    State(state): State<AppState>,
    User(user): User,
    Query(query): Query<PersonaQuery>,
) -> ApiResult<Json<Vec<Persona>>> {
    state
        .run(move |db| personas::find(db, user, query.q.as_deref().unwrap_or("")))
        .await
        .map(Json)
}

async fn create(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<NewPersona>,
) -> ApiResult<(StatusCode, Json<Persona>)> {
    let persona = state
        .run(move |db| {
            let lorebooks = new.lorebooks.unwrap_or_default();
            personas::ensure_givable(db, user, None, &lorebooks)?;
            let id = personas::create(
                db,
                user,
                &new.name,
                new.description.as_deref().unwrap_or_default(),
            )?;
            personas::set_lorebooks(db, user, id, &lorebooks)?;
            Ok(personas::get(db, user, id)?.ok_or(NotFound("persona"))?)
        })
        .await?;
    told(&state, user, &page);
    Ok((StatusCode::CREATED, Json(persona)))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(to): Json<ChangePersona>,
) -> ApiResult<Json<Persona>> {
    let trashes = to.trashed.is_some();
    let changed = state
        .run(move |db| {
            // Whether it can be the default is asked of the persona as the change
            // leaves it, before anything is changed. The name is the first change
            // and is refused before it is made, so no refusal leaves a part behind.
            if to.is_default == Some(true) {
                let now = personas::get(db, user, id)?.ok_or(NotFound("persona"))?;
                personas::defaultable(to.trashed.unwrap_or(now.trashed))?;
            }
            if let Some(lorebooks) = &to.lorebooks {
                let now = personas::get(db, user, id)?.ok_or(NotFound("persona"))?;
                personas::ensure_givable(db, user, Some(&now), lorebooks)?;
            }
            personas::change(db, user, id, to.name.as_deref(), to.description.as_deref())?;
            if let Some(lorebooks) = &to.lorebooks {
                personas::set_lorebooks(db, user, id, lorebooks)?;
            }
            if let Some(trashed) = to.trashed {
                personas::set_trashed(db, user, id, trashed)?;
            }
            if let Some(default) = to.is_default {
                personas::set_default(db, user, id, default)?;
            }
            Ok(personas::get(db, user, id)?.ok_or(NotFound("persona"))?)
        })
        .await?;
    told(&state, user, &page);
    if trashes {
        super::cards::told_trash(&state, user, &page);
    }
    Ok(Json(changed))
}

/// Deletes a persona for good. Only one in the Trash.
async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| trash::delete_persona(db, user, id))
        .await?;
    told(&state, user, &page);
    super::cards::told_trash(&state, user, &page);
    Ok(StatusCode::NO_CONTENT)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/personas.rs"));

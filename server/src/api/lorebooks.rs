//! The library's lorebooks over HTTP: the list and its search, import by file upload, one made from scratch
//! (`POST /api/lorebooks/new`), the three flags with the name and the description (`PATCH /api/lorebooks/{id}`),
//! and the lorebook's editor: `GET …/{id}/edit` is what it shows, `POST …/{id}/entries` adds an entry, `PATCH`
//! and `DELETE …/{id}/entries/{reference}` change one and take one out, `POST …/{id}/entries/restore` puts
//! back what `DELETE` answered, `GET …/entries/{reference}/drafts` lists an entry's versions. An entry's
//! reference stands in the address as it is (`lore.ID`). A card's own lorebook has the same editor under
//! `/api/cards/{id}/lorebook` (`At`, `?book=lorebook.ID` where it is not the card's first), with `POST …/move`
//! ("Move to library") and `POST /api/cards/{id}/lorebooks/{lorebook}/back` (its Undo).
//! `/api/cards/{id}/lorebooks` lists the card's lorebooks, attaches one of the library (`POST`; `DELETE
//! …/{lorebook_id}` detaches it) and copies one it brings (`POST …/copy`). What a chat does with lorebooks is
//! in `chats`. Each change of a library lorebook tells the user's pages (`PageEvent::Lorebook`), of a card's
//! own the card's (`PageEvent::Card`), and one into the Trash or out the Trash's.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, FromRequestParts, Path, Query, State};
use axum::http::StatusCode;
use axum::http::request::Parts;
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, patch, post};
use axum::{Json, Router};
use cw_ccv4::drafts::{self, TextDrafts};
use cw_ccv4::lore::{EditEntry, EntryChange, RemovedEntry};
use cw_core::NotFound;
use cw_core::PageEvent;
use cw_core::{Code, Fail};
use cw_library::cards::Show;
use cw_library::lorebooks::{self, Book, CardLorebook, ImportedLorebook, Lorebook, LorebookEdit};
use cw_library::trash;
use cw_store::Db;
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, CopiedReference, FileName, Flags, Made, Page, Reference, User};
use crate::AppState;

/// Largest lorebook file an upload may be. It is text alone.
const MAX_LOREBOOK_FILE: usize = 20 * 1024 * 1024;

pub fn routes() -> Router<AppState> {
    let upload = DefaultBodyLimit::max(MAX_LOREBOOK_FILE);
    Router::new()
        .route(
            "/api/lorebooks",
            get(list).merge(post(import).layer(upload)),
        )
        .route("/api/lorebooks/new", post(create))
        .route("/api/lorebooks/{id}", patch(change).delete(remove))
        .route("/api/lorebooks/{id}/edit", get(editable))
        .route("/api/lorebooks/{id}/export", get(export))
        .route("/api/lorebooks/{id}/entries", post(add_entry))
        .route("/api/lorebooks/{id}/entries/restore", post(restore_entry))
        .route(
            "/api/lorebooks/{id}/entries/{reference}",
            patch(change_entry).delete(remove_entry),
        )
        .route(
            "/api/lorebooks/{id}/entries/{reference}/drafts",
            get(entry_drafts),
        )
        .route("/api/cards/{id}/lorebook", patch(describe_own))
        .route("/api/cards/{id}/lorebook/edit", get(editable))
        .route("/api/cards/{id}/lorebook/export", get(export))
        .route("/api/cards/{id}/lorebook/move", post(move_own))
        .route("/api/cards/{id}/lorebook/entries", post(add_entry))
        .route(
            "/api/cards/{id}/lorebook/entries/restore",
            post(restore_entry),
        )
        .route(
            "/api/cards/{id}/lorebook/entries/{reference}",
            patch(change_entry).delete(remove_entry),
        )
        .route(
            "/api/cards/{id}/lorebook/entries/{reference}/drafts",
            get(entry_drafts),
        )
        .route(
            "/api/cards/{id}/lorebooks/{lorebook_id}/back",
            post(move_back),
        )
        .route(
            "/api/cards/{id}/lorebooks",
            get(lorebooks_of).post(attach_lorebook),
        )
        .route("/api/cards/{id}/lorebooks/copy", post(copy_lorebook))
        .route(
            "/api/cards/{id}/lorebooks/{lorebook_id}",
            delete(detach_lorebook),
        )
}

/// The lorebook a request of its editor is of, by its address:
/// `/api/lorebooks/{id}/…` one of the library, `/api/cards/{id}/lorebook/…` a
/// card's own, the one `?book=lorebook.ID` names or else the card's first.
pub struct At(pub Book);

/// Which of a card's own lorebooks is meant: `?book=lorebook.ID`.
#[derive(Deserialize)]
struct Which {
    book: Option<String>,
}

impl FromRequestParts<AppState> for At {
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, _state: &AppState) -> Result<Self, Response> {
        let mut path = parts.uri.path().split('/').skip(2);
        let (kind, id) = (path.next(), path.next().and_then(|id| id.parse().ok()));
        let which =
            Query::<Which>::try_from_uri(&parts.uri).map_err(IntoResponse::into_response)?;
        match (kind, id) {
            (Some("lorebooks"), Some(id)) => Ok(Self(Book::Library(id))),
            (Some("cards"), Some(card_id)) => Ok(Self(Book::Card {
                card_id,
                book: which.0.book,
            })),
            _ => Err(StatusCode::NOT_FOUND.into_response()),
        }
    }
}

/// Changes to a lorebook; what is left out stays as it is. The name and the
/// description are changed first, so one that is refused leaves the flags as
/// they are; a flag that is refused after them does not take them back.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct ChangeLorebook {
    pub name: Option<String>,
    pub description: Option<String>,
    /// Its own scan depth; 0 for none.
    pub scan_depth: Option<u32>,
    /// Its own token budget; 0 for none.
    pub token_budget: Option<u32>,
    /// Whether every chat has it ([`lorebooks::set_everywhere`]).
    pub everywhere: Option<bool>,
    #[serde(flatten)]
    #[ts(flatten)]
    pub flags: Flags,
}

/// A lorebook made from scratch: its name, and what it says of itself.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct NewLorebook {
    pub name: String,
    pub description: Option<String>,
}

/// What the list of lorebooks is asked for, in the address: `?q=sea&show=archived`.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct LorebookQuery {
    /// Words to search for in names, descriptions and the names of entries.
    pub q: Option<String>,
    pub show: Option<Show>,
}

/// The lorebooks the library shows; see [`lorebooks::find`].
async fn list(
    State(state): State<AppState>,
    User(user): User,
    Query(query): Query<LorebookQuery>,
) -> ApiResult<Json<Vec<Lorebook>>> {
    state
        .run(move |db| {
            lorebooks::find(
                db,
                user,
                query.q.as_deref().unwrap_or(""),
                query.show.unwrap_or_default(),
            )
        })
        .await
        .map(Json)
}

/// The request body is the lorebook file itself; see [`lorebooks::import`].
async fn import(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Query(named): Query<FileName>,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<ImportedLorebook>)> {
    let imported = state
        .run(move |db| lorebooks::import(db, user, &file, named.name.as_deref().unwrap_or("")))
        .await?;
    told(&state, user, &page, imported.lorebook.id);
    Ok((StatusCode::CREATED, Json(imported)))
}

/// See [`lorebooks::create`].
async fn create(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<NewLorebook>,
) -> ApiResult<(StatusCode, Json<Lorebook>)> {
    let made = state
        .run(move |db| {
            let description = new.description.as_deref().unwrap_or("");
            lorebooks::create(db, user, &new.name, description)
        })
        .await?;
    told(&state, user, &page, made.id);
    Ok((StatusCode::CREATED, Json(made)))
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(change): Json<ChangeLorebook>,
) -> ApiResult<Json<Lorebook>> {
    let trashes = change.flags.trashes();
    let changed = state
        .run(move |db| {
            // One for every chat is refused before anything changes where the flags leave it in the Trash.
            if change.everywhere == Some(true) {
                let now = lorebooks::get(db, user, id)?.ok_or(NotFound("lorebook"))?;
                anyhow::ensure!(
                    !change.flags.trashed.unwrap_or(now.trashed),
                    Fail::new(Code::LorebookTrashed).with("name", now.name.as_str())
                );
            }
            // The name first: one that is refused leaves the flags as they are.
            let numbers = [change.scan_depth, change.token_budget];
            if change.name.is_some()
                || change.description.is_some()
                || numbers.iter().any(Option::is_some)
            {
                let (name, description) = (change.name.as_deref(), change.description.as_deref());
                lorebooks::describe(db, user, id, name, description, numbers)?;
            }
            change.flags.apply(
                db,
                user,
                id,
                [
                    |db, user, id, on| lorebooks::set_favorite(db, user, id, on),
                    |db, user, id, on| lorebooks::set_archived(db, user, id, on),
                    |db, user, id, on| lorebooks::set_trashed(db, user, id, on),
                ],
            )?;
            if let Some(on) = change.everywhere {
                lorebooks::set_everywhere(db, user, id, on)?;
            }
            Ok(lorebooks::get(db, user, id)?.ok_or(NotFound("lorebook"))?)
        })
        .await?;
    told(&state, user, &page, id);
    if trashes {
        super::cards::told_trash(&state, user, &page);
    }
    Ok(Json(changed))
}

/// Tells the user's pages that the lorebook `id` was changed, but for the page `from` that changed it.
pub(super) fn told(state: &AppState, user: i64, from: &Page, id: i64) {
    state.tell(user, from, &PageEvent::Lorebook { id });
}

/// A lorebook as a file to save; see [`lorebooks::export`].
async fn export(
    State(state): State<AppState>,
    User(user): User,
    At(book): At,
) -> ApiResult<axum::response::Response> {
    let exported = state
        .run(move |db| lorebooks::export(db, user, book))
        .await?;
    Ok(super::cards::download("application/json", exported))
}

/// A lorebook as its editor shows it; see [`lorebooks::editable`].
async fn editable(
    State(state): State<AppState>,
    User(user): User,
    At(book): At,
) -> ApiResult<Json<LorebookEdit>> {
    state
        .run(move |db| lorebooks::editable(db, user, book))
        .await
        .map(Json)
}

async fn add_entry(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    At(book): At,
    Json(entry): Json<EntryChange>,
) -> ApiResult<(StatusCode, Json<EditEntry>)> {
    let added = on_book(&state, user, &page, book, move |db, of| {
        lorebooks::add_entry(db, user, of, &entry)
    })
    .await?;
    Ok((StatusCode::CREATED, Json(added)))
}

async fn change_entry(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    At(book): At,
    Path((_, reference)): Path<(i64, String)>,
    Query(made): Query<Made>,
    Json(change): Json<EntryChange>,
) -> ApiResult<Json<EditEntry>> {
    on_book(&state, user, &page, book, move |db, of| {
        let made = made.made.as_deref().unwrap_or(drafts::EDITED);
        lorebooks::change_entry_as(db, user, of, &reference, &change, made)
    })
    .await
    .map(Json)
}

/// Takes an entry out, and answers with what puts it back.
async fn remove_entry(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    At(book): At,
    Path((_, reference)): Path<(i64, String)>,
) -> ApiResult<Json<RemovedEntry>> {
    on_book(&state, user, &page, book, move |db, of| {
        lorebooks::remove_entry(db, user, of, &reference)
    })
    .await
    .map(Json)
}

async fn restore_entry(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    At(book): At,
    Json(removed): Json<RemovedEntry>,
) -> ApiResult<(StatusCode, Json<EditEntry>)> {
    let entry = on_book(&state, user, &page, book, move |db, of| {
        lorebooks::restore_entry(db, user, of, &removed)
    })
    .await?;
    Ok((StatusCode::CREATED, Json(entry)))
}

/// Changes the lorebook `book`'s entries by `change`, and tells the user's
/// other pages of the lorebook. Answers with what `change` answered.
async fn on_book<T: Send + 'static>(
    state: &AppState,
    user: i64,
    page: &Page,
    book: Book,
    change: impl FnOnce(&Db, Book) -> anyhow::Result<T> + Send + 'static,
) -> ApiResult<T> {
    let of = book.clone();
    let changed = state.run(move |db| change(db, of)).await?;
    told_of(state, user, page, &book);
    Ok(changed)
}

/// Deletes a lorebook for good. Only one in the Trash.
async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| trash::delete_lorebook(db, user, id))
        .await?;
    told(&state, user, &page, id);
    super::cards::told_trash(&state, user, &page);
    Ok(StatusCode::NO_CONTENT)
}

/// Tells the user's pages of a change of `book`: of the lorebook where it is
/// the library's, else of the card it is its own.
fn told_of(state: &AppState, user: i64, from: &Page, book: &Book) {
    match book {
        Book::Library(id) => told(state, user, from, *id),
        Book::Card { card_id, .. } => super::cards::told(state, user, from, *card_id),
    }
}

/// The versions of an entry's words; see [`lorebooks::entry_drafts`].
async fn entry_drafts(
    State(state): State<AppState>,
    User(user): User,
    At(book): At,
    Path((_, reference)): Path<(i64, String)>,
) -> ApiResult<Json<TextDrafts>> {
    state
        .run(move |db| lorebooks::entry_drafts(db, user, book, &reference))
        .await
        .map(Json)
}

/// "Lorebook settings" of a card's own lorebook: its name, description, scan
/// depth and token budget. It has no flags of its own, and is not for every
/// chat: a change of one is refused.
async fn describe_own(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    At(book): At,
    Json(change): Json<ChangeLorebook>,
) -> ApiResult<StatusCode> {
    let flagged = [
        change.flags.favorite,
        change.flags.archived,
        change.flags.trashed,
    ];
    if flagged.iter().any(Option::is_some) || change.everywhere.is_some() {
        return Err(Fail::new(Code::OwnLorebookFlags).into());
    }
    let of = book.clone();
    state
        .run(move |db| {
            let numbers = [change.scan_depth, change.token_budget];
            let (name, description) = (change.name.as_deref(), change.description.as_deref());
            lorebooks::describe(db, user, of, name, description, numbers)
        })
        .await?;
    told_of(&state, user, &page, &book);
    Ok(StatusCode::NO_CONTENT)
}

/// "Move to library"; see [`lorebooks::move_to_library`].
async fn move_own(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(which): Json<Reference>,
) -> ApiResult<(StatusCode, Json<Lorebook>)> {
    let moved = state
        .run(move |db| lorebooks::move_to_library(db, user, id, &which.reference))
        .await?;
    told(&state, user, &page, moved.id);
    super::cards::told(&state, user, &page, id);
    Ok((StatusCode::CREATED, Json(moved)))
}

/// The Undo of "Move to library"; see [`lorebooks::move_back`].
async fn move_back(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path((id, lorebook_id)): Path<(i64, i64)>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| lorebooks::move_back(db, user, id, lorebook_id))
        .await?;
    told(&state, user, &page, lorebook_id);
    super::cards::told(&state, user, &page, id);
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct AddLorebook {
    /// A lorebook of the library.
    pub lorebook_id: i64,
}

/// The card's lorebooks: those it brings, then those of the library attached to it.
async fn lorebooks_of(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Vec<CardLorebook>>> {
    state
        .run(move |db| lorebooks::of_card(db, user, id))
        .await
        .map(Json)
}

/// Attaches a lorebook of the library to the card, for all its chats. Answers
/// with the card's lorebooks.
async fn attach_lorebook(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<AddLorebook>,
) -> ApiResult<Json<Vec<CardLorebook>>> {
    let attached = state
        .run(move |db| lorebooks::attach(db, user, id, new.lorebook_id))
        .await?;
    super::cards::told(&state, user, &page, id);
    Ok(Json(attached))
}

/// Detaches a lorebook of the library from the card. Answers with the card's lorebooks.
async fn detach_lorebook(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path((id, lorebook_id)): Path<(i64, i64)>,
) -> ApiResult<Json<Vec<CardLorebook>>> {
    let detached = state
        .run(move |db| lorebooks::detach(db, user, id, lorebook_id))
        .await?;
    super::cards::told(&state, user, &page, id);
    Ok(Json(detached))
}

/// Copies a lorebook the card brings into the library. Answers with the new lorebook.
async fn copy_lorebook(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(which): Json<CopiedReference>,
) -> ApiResult<(StatusCode, Json<Lorebook>)> {
    let copy = state
        .run(move |db| {
            lorebooks::copy_from_card(
                db,
                user,
                id,
                &which.reference,
                lorebooks::Words { copy: &which.copy },
            )
        })
        .await?;
    told(&state, user, &page, copy.id);
    super::cards::told(&state, user, &page, id);
    Ok((StatusCode::CREATED, Json(copy)))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/lorebooks.rs"));

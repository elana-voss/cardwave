//! Cards over HTTP: the library's list and search (by meaning too: `find::reader::near`), import, a card made
//! from scratch ([`cards::create`], by `made`, which the character generator uses too), a card's page with its facts, summary and content level (`describe`),
//! its chats and texts as written (`/edit`, in one of its languages with `?language=de`, with a text's drafts at `/drafts`), its summary as the user writes it, its pictures and assets, and the card as a file, with its texts'
//! history where the settings say so (`Settings::export_history`).
//!
//! Traps: an address that names a key several times (`?tag=sea&tag=keeper`) is read with `axum-extra`'s
//! `Query` (`Repeating`), as axum's refuses it. A picture and an asset go by the id of the card's version
//! (`/api/card-versions/{id}/…`), never given twice, so a browser keeps them for good; an edit changes it.
//! With `?size=96x128` a picture is answered small (`small_image`, by `thumbnails::make`). Each change of a card
//! tells the user's other pages (`told`, `PageEvent::Card`), and of the Trash where it moved the card there or out.

use std::collections::HashMap;

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, Path, Query, State};
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post, put};
use axum::{Json, Router};
use axum_extra::extract::Query as Repeating;
use cw_ccv4::drafts::{self, TextDrafts};
use cw_ccv4::edit::CardEdit;
use cw_ccv4::new::NewCard;
use cw_ccv4::{Document, display, mapping};
use cw_chat::chats::{self, Chat};
use cw_chat::memory;
use cw_core::NotFound;
use cw_core::PageEvent;
use cw_core::{Code, Fail};
use cw_library::cards::{
    self, CardSummary, CardVersion, Exported, Find, Imported, Show, Sort, TagCount,
};
use cw_library::describe::{self, Facts};
use cw_library::expressions;
use cw_library::needs::{self, CardNeeds};
use cw_library::settings;
use cw_library::thumbnails::{self, Kept};
use cw_library::trash;
use cw_store::Db;
use percent_encoding::{AsciiSet, NON_ALPHANUMERIC, utf8_percent_encode};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, FileName, Flags, Made, Page, Reference, User};
use crate::AppState;

/// Largest card file an upload may be. A card carries its pictures and sounds.
pub(super) const MAX_CARD_FILE: usize = 100 * 1024 * 1024;
/// Largest edit of a card: all its texts at once, which are seldom a hundredth of this.
const MAX_EDIT: usize = 16 * 1024 * 1024;
/// Largest card made from scratch: its texts, and its picture in base64, which is a third longer than the picture.
const MAX_NEW: usize = MAX_CARD_FILE / 3 * 4 + MAX_EDIT;

/// What stays as it is in a file name given in a header.
const FILE_NAME: &AsciiSet = &NON_ALPHANUMERIC.remove(b'.').remove(b'-').remove(b'_');
/// What stays as it is in a URL path.
const PATH: &AsciiSet = &FILE_NAME.remove(b'/');

pub fn routes() -> Router<AppState> {
    let upload = DefaultBodyLimit::max(MAX_CARD_FILE);
    Router::new()
        .route("/api/cards", get(list).merge(post(import).layer(upload)))
        .route("/api/cards/tags", get(tags))
        .route(
            "/api/cards/new",
            post(create).layer(DefaultBodyLimit::max(MAX_NEW)),
        )
        .route("/api/cards/{id}", get(detail).patch(change).delete(remove))
        .route("/api/cards/{id}/chats", get(chats_of))
        .route(
            "/api/cards/{id}/edit",
            get(editable).merge(put(edit).layer(DefaultBodyLimit::max(MAX_EDIT))),
        )
        .route("/api/cards/{id}/drafts", get(drafts_of))
        .route("/api/cards/{id}/summary", put(summary))
        .route("/api/cards/{id}/export", get(export))
        .route("/api/card-versions/{id}/image", get(image))
        .route("/api/card-versions/{id}/assets/{*name}", get(asset))
}

/// One character of a card version.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct CardCharacter {
    /// Its ID in the card; a chat is started with it.
    pub id: String,
    /// The name it has in a chat.
    pub name: String,
    /// The name it has in lists.
    pub label: String,
    pub(crate) avatar_url: String,
    /// The messages a chat with it can open with. These and the texts below are
    /// as a reader sees them: macros resolved as in a chat without a persona.
    pub greetings: Vec<String>,
    pub description: String,
    pub personality: String,
    pub scenario: String,
    pub example_dialogue: String,
    /// What the card's creator tells its users; never sent to a model.
    pub creator_notes: String,
    /// What the page says of the character without a model.
    pub facts: Facts,
}

#[derive(Serialize, TS)]
#[ts(export)]
pub(crate) struct CardDetail {
    pub card: CardSummary,
    /// The card's as the library has them, but for the content level, which
    /// is `content`.
    pub tags: Vec<String>,
    /// The three sentences the worker model wrote of the card; empty until it
    /// is described.
    pub summary: String,
    /// The card's rating and content flags, shown as chips; none until it is
    /// described.
    pub content: Vec<String>,
    /// The needs the card offers, as far as they are asked.
    pub needs: CardNeeds,
    /// Who made the card; empty when it does not say.
    pub creator: String,
    /// When the card was last edited; none while it is as it came.
    pub edited_at: Option<i64>,
    pub characters: Vec<CardCharacter>,
}

/// What the library's list is asked for, in the address: `?q=sea&show=all&sort=name&tag=keeper&tag=slow+burn`.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct CardQuery {
    /// Words to search for in titles, names and tags.
    pub q: Option<String>,
    /// Tags the cards must all have, each as a `tag` of its own.
    pub tag: Option<Vec<String>>,
    /// Needs picked in the view "By need", each as a `need` of its own: the cards with any of them, the
    /// highest sum of levels over them first, then the best rank, then by title.
    pub need: Option<Vec<String>>,
    pub show: Option<Show>,
    pub sort: Option<Sort>,
    /// Whether each card brings what its poster shows; the view Posters alone asks.
    pub posters: Option<bool>,
}

impl CardQuery {
    /// What is asked for, with `near` the query as the search model reads it and `strengths` what the needs picked come to.
    fn find<'a>(
        &'a self,
        near: Option<&'a [f32]>,
        strengths: Option<&'a HashMap<i64, needs::Strength>>,
    ) -> Find<'a> {
        Find {
            query: self.q.as_deref().unwrap_or(""),
            tags: self.tag.as_deref().unwrap_or_default(),
            show: self.show.unwrap_or_default(),
            sort: self.sort.unwrap_or_default(),
            near,
            strengths,
        }
    }

    /// What the needs picked come to, where any are ([`needs::strengths`]).
    fn strengths(
        &self,
        db: &cw_store::Db,
        user: i64,
    ) -> anyhow::Result<Option<HashMap<i64, needs::Strength>>> {
        let picked = self.need.as_deref().unwrap_or_default();
        if picked.is_empty() {
            return Ok(None);
        }
        Ok(Some(needs::strengths(db, user, picked)?))
    }

    /// What `answer` finds of what is asked for, with the query as the search model reads it, where it
    /// is set up.
    async fn found<T: Send + 'static>(
        self,
        state: &AppState,
        user: i64,
        answer: fn(&dyn cards::Storage, i64, &Find) -> anyhow::Result<T>,
    ) -> ApiResult<Json<T>> {
        let near = cw_find::reader::near(state, user, self.q.as_deref().unwrap_or("")).await;
        state
            .run(move |db| {
                let strengths = self.strengths(db, user)?;
                answer(
                    db,
                    user,
                    &self.find(near.as_deref().map(Vec::as_slice), strengths.as_ref()),
                )
            })
            .await
            .map(Json)
    }
}

/// The cards the library shows; see [`cards::find`]. Has the search model
/// read the cards it has not yet.
async fn list(
    State(state): State<AppState>,
    User(user): User,
    Repeating(query): Repeating<CardQuery>,
) -> ApiResult<Json<Vec<CardSummary>>> {
    cw_find::reader::read_cards(&state);
    crate::faces::look(&state);
    let posters = query.posters.unwrap_or_default();
    let Json(found) = query.found(&state, user, cards::find).await?;
    Ok(Json(match posters {
        true => found,
        false => found.into_iter().map(CardSummary::plain).collect(),
    }))
}

/// The tags the list can be narrowed by, as it is asked for; see [`cards::tag_counts`].
async fn tags(
    State(state): State<AppState>,
    User(user): User,
    Repeating(query): Repeating<CardQuery>,
) -> ApiResult<Json<Vec<TagCount>>> {
    query.found(&state, user, cards::tag_counts).await
}

/// The chats with the card's characters, the one written in last first.
async fn chats_of(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Vec<Chat>>> {
    state
        .run(move |db| {
            cards::title(db, user, id)?.ok_or(NotFound("card"))?;
            chats::of_card(db, user, id)
        })
        .await
        .map(Json)
}

/// Tells the user's pages that the card `id` was changed, but for the page `from` that changed it.
pub(super) fn told(state: &AppState, user: i64, from: &Page, id: i64) {
    state.tell(user, from, &PageEvent::Card { id });
}

/// Tells the user's pages, but for `from`, of a change that put something in the Trash or took it out.
pub(super) fn told_trash(state: &AppState, user: i64, from: &Page) {
    state.tell(user, from, &PageEvent::Trash);
}

/// Changes what the card `id` holds by `change`, and tells the user's other
/// pages of the card and of the Trash: what the card had before may have gone
/// to the Trash. Answers with what `change` answered.
pub(super) async fn card_changed<T: Send + 'static>(
    state: &AppState,
    user: i64,
    page: &Page,
    id: i64,
    change: impl FnOnce(&Db) -> anyhow::Result<T> + Send + 'static,
) -> ApiResult<Json<T>> {
    let changed = state.run(change).await?;
    told(state, user, page, id);
    told_trash(state, user, page);
    Ok(Json(changed))
}

/// The request body is the card file itself (a CCV4 or SillyTavern PNG), its name in `?name=`.
async fn import(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Query(named): Query<FileName>,
    file: Bytes,
) -> ApiResult<(StatusCode, Json<Imported>)> {
    let imported = state
        .run(move |db| cards::import_named(db, user, &file, named.name.as_deref()))
        .await?;
    told(&state, user, &page, imported.card_id);
    super::describe::imported(&state, user, imported.card_id).await;
    cw_find::reader::read_cards(&state);
    Ok((StatusCode::CREATED, Json(imported)))
}

/// Makes a card from scratch; see [`cards::create`]. Answers as an import does.
async fn create(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(new): Json<NewCard>,
) -> ApiResult<(StatusCode, Json<Imported>)> {
    made(&state, user, &page, new).await
}

/// Makes the card `new` and tells the user's other pages; the character generator's card too.
pub(super) async fn made(
    state: &AppState,
    user: i64,
    page: &Page,
    new: NewCard,
) -> ApiResult<(StatusCode, Json<Imported>)> {
    let made = state.run(move |db| cards::create(db, user, new)).await?;
    told(state, user, page, made.card_id);
    cw_find::reader::read_cards(state);
    Ok((StatusCode::CREATED, Json(made)))
}

/// A card as its editor shows it; see [`cards::editable`].
async fn editable(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(asked): Query<InLanguage>,
) -> ApiResult<Json<CardEdit>> {
    state
        .run(move |db| cards::editable(db, user, id, asked.language.as_deref()))
        .await
        .map(Json)
}

/// The language a card's texts are asked in, where one is.
#[derive(Deserialize, ts_rs::TS)]
#[ts(export)]
struct InLanguage {
    language: Option<String>,
}

/// A text's drafts; see [`cards::drafts`].
async fn drafts_of(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(of): Query<Reference>,
) -> ApiResult<Json<TextDrafts>> {
    state
        .run(move |db| cards::drafts(db, user, id, &of.reference))
        .await
        .map(Json)
}

/// A summary the user wrote.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct NewSummary {
    pub summary: String,
}

/// Gives the card the summary the user wrote, not one in the Trash; see [`describe::set_summary`].
async fn summary(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(new): Json<NewSummary>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| {
            let card = cards::get(db, user, id)?.ok_or(NotFound("card"))?;
            anyhow::ensure!(!card.trashed, Fail::new(Code::CardTrashed));
            describe::set_summary(db, id, &new.summary)
        })
        .await?;
    told(&state, user, &page, id);
    Ok(StatusCode::NO_CONTENT)
}

/// Saves an edit of the card; see [`cards::edit_as`]. Answers with the card's
/// version, which is no new one when the edit changed nothing.
async fn edit(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Query(by): Query<Made>,
    Json(edit): Json<CardEdit>,
) -> ApiResult<Json<CardVersion>> {
    let made = by.made.unwrap_or_else(|| drafts::EDITED.to_string());
    let saved = state
        .run(move |db| {
            // A character the edit renames keeps what its chats' memories know.
            let before = memory::casts(db, user, id)?;
            let saved = cards::edit_as(db, user, id, &edit, &made)?;
            memory::follow_casts(db, user, &before)?;
            Ok(saved)
        })
        .await?;
    told(&state, user, &page, id);
    cw_find::reader::read_cards(&state);
    Ok(Json(saved))
}

/// A card as its page shows it.
async fn detail(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<CardDetail>> {
    state
        .run(move |db| {
            let (card, files) = cards::newest(db, user, id)?;
            let document = Document::parse(&files)?;
            let stand_in = settings::user_outside_chat(db, user)?;
            let language = settings::app_language(db, user)?;
            let mut characters = Vec::new();
            for character in document.characters() {
                let name = document.character_name(character);
                let shown = |text: &str| display::render(text, &name, &stand_in, &language);
                let texts = mapping::character(&document, character).unwrap_or_default();
                characters.push(CardCharacter {
                    id: character.to_string(),
                    label: document.character_label(character),
                    avatar_url: avatar_url(db, card.version_id, &document, character)?,
                    greetings: document
                        .greetings(character, false)
                        .iter()
                        .map(|greeting| shown(greeting))
                        .collect(),
                    description: shown(&texts.description),
                    personality: shown(&texts.personality),
                    scenario: shown(&texts.scenario),
                    example_dialogue: shown(&texts.mes_example),
                    creator_notes: shown(document.creator_note(character).unwrap_or("")),
                    facts: describe::facts(&document, character),
                    name,
                });
            }
            let (summary, content) = describe::of_card(db, id)?;
            let mut tags = card.tags.clone();
            tags.retain(|tag| !content.contains(tag));
            let edited_at = cards::edited_at(db, card.version_id)?;
            Ok(CardDetail {
                edited_at,
                needs: needs::of_card(db, id)?,
                tags,
                summary,
                content,
                creator: document.creator().unwrap_or("").to_string(),
                characters,
                card: card.plain(),
            })
        })
        .await
        .map(Json)
}

async fn change(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
    Json(flags): Json<Flags>,
) -> ApiResult<Json<CardSummary>> {
    let trashes = flags.trashes();
    let changed = state
        .run(move |db| {
            flags.apply(
                db,
                user,
                id,
                [
                    |db, user, id, on| cards::set_favorite(db, user, id, on),
                    |db, user, id, on| cards::set_archived(db, user, id, on),
                    |db, user, id, on| cards::set_trashed(db, user, id, on),
                ],
            )?;
            Ok(cards::get(db, user, id)?.ok_or(NotFound("card"))?.plain())
        })
        .await?;
    told(&state, user, &page, id);
    if trashes {
        told_trash(&state, user, &page);
    }
    Ok(Json(changed))
}

/// Which character a SillyTavern card is made of: `?character=mira`.
#[derive(Deserialize, ts_rs::TS)]
#[ts(export)]
struct ExportQuery {
    /// Its ID in the card; the card's first character when left out.
    character: Option<String>,
}

/// The card as a file to save, in the format the user has chosen; see [`cards::export`].
async fn export(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(query): Query<ExportQuery>,
) -> ApiResult<Response> {
    let exported = state
        .run(move |db| {
            let settings = settings::get(db, user)?;
            let (format, history) = (settings.export_format, settings.export_history);
            cards::export(db, user, id, format, history, query.character.as_deref())
        })
        .await?;
    Ok(download("image/png", exported))
}

/// A file to save, of the type and under the name given.
pub(super) fn download(content_type: &'static str, exported: Exported) -> Response {
    let name = format!(
        "attachment; filename*=UTF-8''{}",
        utf8_percent_encode(&exported.file_name, FILE_NAME)
    );
    let headers = [
        (header::CONTENT_TYPE, content_type.to_string()),
        (header::CONTENT_DISPOSITION, name),
    ];
    (headers, exported.data).into_response()
}

/// Deletes a card for good, with its chats. Only a card in the Trash, and not
/// while a reply is being generated in one of its chats.
async fn remove(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    state
        .run(move |db| trash::delete_card(db, user, id))
        .await?;
    told(&state, user, &page, id);
    told_trash(&state, user, &page);
    Ok(StatusCode::NO_CONTENT)
}

/// How large a version's picture is asked for, in the address: `?size=96x128`.
#[derive(Deserialize, ts_rs::TS)]
#[ts(export)]
struct ImageQuery {
    /// One of the sizes the lists draw it in; the whole picture when left out.
    size: Option<thumbnails::Size>,
}

/// A version's picture: the whole one, or made small for a list. A small one
/// never changes either, so the browser keeps it as long.
async fn image(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Query(asked): Query<ImageQuery>,
) -> ApiResult<Response> {
    let data = match asked.size {
        None => state.run(move |db| cards::image(db, user, id)).await?,
        Some(size) => small_image(&state, user, id, size).await?,
    }
    .ok_or(NotFound("card version"))?;
    // A small picture is kept without its type, so its first bytes say.
    let content_type = expressions::picture_type(&data).unwrap_or("image/png");
    Ok(file(content_type, data))
}

/// A version's picture in a size of the lists, made now if it was never asked
/// for: see [`thumbnails::make`], which also says when the whole picture is
/// the answer.
async fn small_image(
    state: &AppState,
    user: i64,
    id: i64,
    size: thumbnails::Size,
) -> ApiResult<Option<Vec<u8>>> {
    let picture = match state
        .run(move |db| thumbnails::kept(db, user, id, size))
        .await?
    {
        None => return Ok(None),
        Some(Kept::Small(small)) => return Ok(Some(small)),
        Some(Kept::NotYet(picture)) => picture,
    };
    // The turn goes along, so it lasts until the picture is made, whoever
    // still waits for it.
    let turn = state.thumbnails.take(picture).await;
    state
        .run(move |db| thumbnails::make(db, turn, user, id, size))
        .await
}

async fn asset(
    State(state): State<AppState>,
    User(user): User,
    Path((id, name)): Path<(i64, String)>,
) -> ApiResult<Response> {
    let content_type = content_type(&name);
    let data = state
        .run(move |db| cards::asset(db, user, id, &name))
        .await?
        .ok_or(NotFound("asset"))?;
    Ok(file(content_type, data))
}

/// Where the UI finds a character's picture: its avatar among the card's
/// assets, or else the card's own picture.
pub(super) fn avatar_url(
    db: &Db,
    version_id: i64,
    document: &Document,
    character: &str,
) -> anyhow::Result<String> {
    Ok(match document.avatar(character) {
        Some(name) if cards::has_asset(db, version_id, name)? => {
            format!(
                "/api/card-versions/{version_id}/assets/{}",
                utf8_percent_encode(name, PATH)
            )
        }
        _ => format!("/api/card-versions/{version_id}/image"),
    })
}

/// The type a browser is told for an asset, by its file name. Anything else is
/// a download.
fn content_type(name: &str) -> &'static str {
    let extension = name
        .rsplit_once('.')
        .map(|(_, extension)| extension.to_ascii_lowercase())
        .unwrap_or_default();
    match extension.as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "avif" => "image/avif",
        "svg" => "image/svg+xml",
        "mp3" => "audio/mpeg",
        "ogg" => "audio/ogg",
        "wav" => "audio/wav",
        "mp4" => "video/mp4",
        "webm" => "video/webm",
        _ => "application/octet-stream",
    }
}

/// A file out of a card. Cards come from strangers, so the browser must not run
/// anything inside it. A card version never changes, so the browser may keep the file.
fn file(content_type: &'static str, data: Vec<u8>) -> Response {
    super::stored_file(content_type, data, "private, max-age=31536000, immutable")
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/cards.rs"));

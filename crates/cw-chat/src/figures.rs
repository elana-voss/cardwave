//! 3D figures: what the desktop companion shows for a card (web/src/figures/, web/src/companion/figure.ts). A
//! figure is a VRM, GLB or FBX file of a rigged human (`kind_of`), kept once per user by its bytes (`hash`) with its
//! still, a PNG the UI drew of it when it was added. Cards share it: a card has one (`cards.figure_id`), and each of
//! its modes may have its own (`card_mode_figures`), which shows in that mode; a mode without one shows the card's
//! (`shown`). One that no card has any more goes to the Trash alone (`trash::FIGURES`), as an expression pack does.
//!
//! The UI reads the file before it is sent and refuses a skeleton that is not human; the server checks only that
//! the bytes are of the kind named, as the companion falls back to its robot where a figure does not load.

use anyhow::{bail, ensure};
use cw_ccv4::same_mode;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::cards;
use cw_library::settings;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use ts_rs::TS;

use crate::assistant;
use crate::chats;

/// The largest figure file taken (a VRM of VRoid Studio is some 10 to 30 MB).
pub const MAX_FIGURE: usize = 100 * 1024 * 1024;
/// The largest still taken.
const MAX_STILL: usize = 4 * 1024 * 1024;
/// The most characters of a figure's name.
const MAX_NAME: usize = 100;

/// A figure as the card page and "Add a 3D figure" show it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Figure {
    pub id: i64,
    pub name: String,
    /// `vrm`, `glb` or `fbx`.
    pub kind: String,
    /// How many cards outside the Trash have it, as theirs or a mode's.
    pub cards: u32,
}

/// A mode's own figure.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ModeFigure {
    pub mode: String,
    pub figure: Figure,
}

/// A card's figures: its own, and those of its modes that have one.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct CardFigures {
    pub figure: Option<Figure>,
    pub modes: Vec<ModeFigure>,
}

/// A card's figures after a change, and the figure the card or mode had before, for Undo.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct CardFigureChanged {
    pub figures: CardFigures,
    pub before: Option<i64>,
}

/// The figure a card, or one of its modes, is to have, or none.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct SetCardFigure {
    pub figure: Option<i64>,
    pub mode: Option<String>,
}

/// A figure from a file, for a card or one of its modes: the file's name and bytes, and its still.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct NewFigure {
    pub file_name: String,
    /// The file's bytes in base64.
    pub data: String,
    /// The still, a PNG, in base64.
    pub still: String,
    pub mode: Option<String>,
}

/// A figure's file to keep: its name, kind, the SHA-256 and bytes of the file and of its still.
pub struct FigureFile<'a> {
    pub name: &'a str,
    pub kind: &'a str,
    pub hash: &'a [u8],
    pub data: &'a [u8],
    pub still_hash: &'a [u8],
    pub still: &'a [u8],
}

/// What the figures need of the database, which `cw_store::figures` gives.
pub trait Storage {
    /// Keeps a figure of `user` unless one of the same bytes is kept; answers its id either way.
    fn store_figure(&self, user: i64, file: &FigureFile<'_>) -> anyhow::Result<i64>;
    /// The figures of `user` outside the Trash, by name.
    fn figures(&self, user: i64) -> anyhow::Result<Vec<Figure>>;
    /// A card's figures; `NotFound` where there is no such card.
    fn card_figures(&self, user: i64, card_id: i64) -> anyhow::Result<CardFigures>;
    /// Gives the card, or its mode `mode` (as the card names it), the figure, or takes it off; takes it out of the
    /// Trash, and moves the one before there where no card has it any more. Answers the one before.
    fn set_card_figure(
        &self,
        user: i64,
        card_id: i64,
        mode: Option<&str>,
        figure: Option<i64>,
    ) -> anyhow::Result<Option<i64>>;
    /// A figure's kind, and its file's or still's bytes.
    fn figure_bytes(
        &self,
        user: i64,
        figure: i64,
        still: bool,
    ) -> anyhow::Result<Option<(String, Vec<u8>)>>;
    /// Moves a figure no card has to the Trash, or out.
    fn set_figure_trashed(&self, user: i64, figure: i64, trashed: bool) -> anyhow::Result<()>;
}

/// The kind of a figure file by its name, where its bytes are of that kind.
pub fn kind_of(file_name: &str, data: &[u8]) -> anyhow::Result<&'static str> {
    let lower = file_name.to_lowercase();
    let kind = match lower.rsplit_once('.').map(|(_, ext)| ext) {
        Some("vrm") => "vrm",
        Some("glb") => "glb",
        Some("fbx") => "fbx",
        _ => bail!(
            Fail::said(Code::NotReadable, "a 3D figure is a VRM, GLB or FBX file")
                .with("what", "figure_type")
        ),
    };
    let fits = match kind {
        "fbx" => {
            data.starts_with(b"Kaydara FBX Binary")
                || data[..data.len().min(4096)]
                    .windows(18)
                    .any(|one| one == b"FBXHeaderExtension")
        }
        _ => data.starts_with(b"glTF"),
    };
    ensure!(
        fits,
        Fail::said(
            Code::NotReadable,
            format!("{file_name} is not a {} file", kind.to_uppercase())
        )
        .with("what", "figure_file")
        .with("file_name", file_name.to_string())
        .with("kind", (kind.to_uppercase()).to_string())
    );
    Ok(kind)
}

/// A figure's name as it is kept: the file's name without its kind, trimmed and cut, "Figure" where none is left.
fn name_of(file_name: &str) -> String {
    let stem = file_name
        .rsplit_once('.')
        .map_or(file_name, |(stem, _)| stem);
    let name: String = stem.trim().chars().take(MAX_NAME).collect();
    if name.is_empty() {
        "Figure".to_string()
    } else {
        name
    }
}

/// The mode of the card as the card names it; an error where it has none such.
fn card_mode(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    mode: Option<&str>,
) -> anyhow::Result<Option<String>> {
    let Some(mode) = mode else {
        return Ok(None);
    };
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    let document = cards::document_of(db, card.version_id)?;
    match document
        .modes()
        .into_iter()
        .find(|one| same_mode(one, mode))
    {
        Some(one) => Ok(Some(one)),
        None => bail!(
            Fail::said(Code::NotPossible, format!("the card has no mode “{mode}”"))
                .with("what", "card_mode")
                .with("mode", mode.to_string())
        ),
    }
}

/// Keeps a figure of `user` from a file, or finds the same one kept, and gives it the card or its mode.
pub fn import_for_card(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    new: NewFigure,
) -> anyhow::Result<CardFigureChanged> {
    use base64::Engine;
    let decode = |text: &str, what: &str| {
        base64::engine::general_purpose::STANDARD
            .decode(text.trim())
            .map_err(|_| {
                anyhow::anyhow!(
                    Fail::said(Code::NotReadable, format!("the {what} is not base64"))
                        .with("what", "base64")
                )
            })
    };
    let data = decode(&new.data, "figure")?;
    ensure!(
        data.len() <= MAX_FIGURE,
        Fail::said(
            Code::TooBig,
            format!(
                "a 3D figure may have at most {} MB",
                MAX_FIGURE / 1024 / 1024
            )
        )
        .with("what", "figure")
    );
    let kind = kind_of(&new.file_name, &data)?;
    let still = decode(&new.still, "still")?;
    ensure!(
        still.len() <= MAX_STILL && still.starts_with(b"\x89PNG\r\n\x1a\n"),
        Fail::said(
            Code::NotReadable,
            "the figure's still is not a PNG of at most 4 MB"
        )
        .with("what", "figure_still")
    );
    // The card and mode are asked for first, so a figure for no card is not kept.
    let mode = card_mode(db, user, card_id, new.mode.as_deref())?;
    db.card_figures(user, card_id)?;
    let file = FigureFile {
        name: &name_of(&new.file_name),
        kind,
        hash: &Sha256::digest(&data),
        data: &data,
        still_hash: &Sha256::digest(&still),
        still: &still,
    };
    let figure = db.store_figure(user, &file)?;
    put(db, user, card_id, mode.as_deref(), Some(figure))
}

/// Gives the card, or its mode, a figure the app holds, or takes its figure off.
pub fn put_on_card(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    set: &SetCardFigure,
) -> anyhow::Result<CardFigureChanged> {
    let mode = match (
        card_mode(db, user, card_id, set.mode.as_deref()),
        set.figure,
    ) {
        (Ok(mode), _) => mode,
        // A mode the card no longer has (renamed or removed) still has its figure taken off, by its name as kept.
        (Err(error), None) if error.downcast_ref::<NotFound>().is_none() => set.mode.clone(),
        (Err(error), _) => return Err(error),
    };
    put(db, user, card_id, mode.as_deref(), set.figure)
}

fn put(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    mode: Option<&str>,
    figure: Option<i64>,
) -> anyhow::Result<CardFigureChanged> {
    let before = db.set_card_figure(user, card_id, mode, figure)?;
    Ok(CardFigureChanged {
        figures: db.card_figures(user, card_id)?,
        before,
    })
}

pub fn of_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<CardFigures> {
    db.card_figures(user, card_id)
}

pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<Figure>> {
    db.figures(user)
}

/// A figure's file, or its still, with its media type.
pub fn bytes(
    db: &dyn Storage,
    user: i64,
    figure: i64,
    still: bool,
) -> anyhow::Result<(&'static str, Vec<u8>)> {
    let (kind, data) = db
        .figure_bytes(user, figure, still)?
        .ok_or(NotFound("figure"))?;
    let media = match (still, kind.as_str()) {
        (true, _) => "image/png",
        (false, "fbx") => "application/octet-stream",
        (false, _) => "model/gltf-binary",
    };
    Ok((media, data))
}

/// Moves a figure no card has to the Trash, or takes it out.
pub fn set_trashed(db: &dyn Storage, user: i64, figure: i64, trashed: bool) -> anyhow::Result<()> {
    db.set_figure_trashed(user, figure, trashed)
}

/// The figure that shows in the mode `mode` of a card's figures: the mode's own, else the card's.
pub fn shown(figures: CardFigures, mode: Option<&str>) -> Option<Figure> {
    let own = mode.and_then(|mode| {
        figures
            .modes
            .iter()
            .find(|one| same_mode(&one.mode, mode))
            .map(|one| one.figure.clone())
    });
    own.or(figures.figure)
}

/// The figure the companion shows: its card's, in the mode of the newest chat with the card (the compact chat's),
/// else in the card's first mode; none without a companion or a figure.
pub fn companion(db: &dyn crate::chats::Storage, user: i64) -> anyhow::Result<Option<Figure>> {
    let Some(card_id) = settings::get(db, user)?.companion.card_id else {
        return Ok(None);
    };
    let Some(card) = cards::get(db, user, card_id)? else {
        return Ok(None);
    };
    let mode = match chats::of_card(db, user, card_id)?.into_iter().next() {
        Some(chat) => {
            let (_, _, document) = assistant::first(db, user, chat.id)?;
            assistant::mode_of(&document, &chat)
        }
        None => cards::document_of(db, card.version_id)?.mode_or_first(&[]),
    };
    Ok(shown(db.card_figures(user, card_id)?, mode.as_deref()))
}

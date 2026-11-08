//! A card version's files read back: its document, assets and picture, and the
//! card exported as a file (SillyTavern's or CCV4's).

use anyhow::bail;
use cw_ccv4::{Document, drafts, png, sillytavern};
use cw_core::NotFound;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::cards::{CardSummary, NewestFiles, Storage, card_of, get};

/// The merged TOML document of one card version.
pub fn document(db: &dyn Storage, user: i64, version_id: i64) -> anyhow::Result<Document> {
    card_of(db, user, version_id)?.ok_or(NotFound("card version"))?;
    document_of(db, version_id)
}

/// [`document`] for a version already known to be the user's.
pub fn document_of(db: &dyn Storage, version_id: i64) -> anyhow::Result<Document> {
    Document::parse(&toml_of(db, version_id)?)
}

/// The TOML files of a card version, each with its name.
pub(super) fn toml_of(db: &dyn Storage, version_id: i64) -> anyhow::Result<Vec<(String, String)>> {
    let files = db.toml_files(version_id)?;
    if files.is_empty() {
        bail!(NotFound("card version"));
    }
    Ok(files)
}

/// A card of `user` and the TOML files of its newest version, read at once: an
/// edit saved meanwhile cannot put that version away between the two.
pub fn newest(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
) -> anyhow::Result<(CardSummary, Vec<(String, String)>)> {
    let NewestFiles { card, files } = db.newest_files(user, card_id)?.ok_or(NotFound("card"))?;
    if files.is_empty() {
        bail!(NotFound("card version"));
    }
    Ok((card, files))
}

/// Whether a card version holds an asset of this file name.
pub fn has_asset(db: &dyn Storage, version_id: i64, name: &str) -> anyhow::Result<bool> {
    db.has_asset(version_id, name)
}

/// One asset of a card version by its file name (what follows `asset://`).
pub fn asset(
    db: &dyn Storage,
    user: i64,
    version_id: i64,
    name: &str,
) -> anyhow::Result<Option<Vec<u8>>> {
    db.asset(user, version_id, name)
}

/// The file format a card is exported in.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum ExportFormat {
    /// A SillyTavern card (Character Card V3, with a V2 copy beside it).
    #[default]
    SillytavernV3,
    Ccv4,
}

/// A card or a chat as a file to save.
pub struct Exported {
    pub file_name: String,
    pub data: Vec<u8>,
}

/// A card as a card file. As CCV4 it is the card as it is kept, without the
/// files that belong to its user (spec section 2.7), but for its texts'
/// history where `history` asks for it. A SillyTavern card holds one
/// character, `character` or else the card's first, and no history.
pub fn export(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    format: ExportFormat,
    history: bool,
    character: Option<&str>,
) -> anyhow::Result<Exported> {
    let card = get(db, user, card_id)?.ok_or(NotFound("card"))?;
    let mut container = files(db, card.version_id)?;
    let data = match format {
        ExportFormat::Ccv4 => {
            let history = match history {
                true => drafts::only_history(&Document::parse(&container.toml)?)?,
                false => None,
            };
            container.toml.retain(|(name, _)| name.starts_with("card/"));
            container.toml.extend(history);
            container
                .assets
                .retain(|(name, _)| name.starts_with("card/"));
            png::write(&container)?
        }
        ExportFormat::SillytavernV3 => sillytavern::export(&container, character)?,
    };
    Ok(Exported {
        file_name: format!("{}.png", file_stem(&card.title, "card")),
        data,
    })
}

/// A title as the start of a file's name: without what a file name cannot
/// hold, and `unnamed` where that leaves nothing.
pub fn file_stem(title: &str, unnamed: &str) -> String {
    const FORBIDDEN: &str = "\\/:*?\"<>|";
    let clean: String = title
        .chars()
        .map(|c| {
            if c.is_control() || FORBIDDEN.contains(c) {
                '_'
            } else {
                c
            }
        })
        .take(80)
        .collect();
    // Windows takes no name that ends in a dot or a space.
    let clean = clean.trim_matches(|c: char| c == '.' || c.is_whitespace());
    if clean.is_empty() { unnamed } else { clean }.to_string()
}

/// The parts of a card version, as a card file holds them.
fn files(db: &dyn Storage, version_id: i64) -> anyhow::Result<png::Container> {
    db.card_files(version_id)
}

/// The card's picture: the imported PNG without its CCV4 chunks.
pub fn image(db: &dyn Storage, user: i64, version_id: i64) -> anyhow::Result<Option<Vec<u8>>> {
    db.card_image(user, version_id)
}

//! Putting a card in: an import or a new card stored as its first version, its
//! files and pictures as blobs (once per content), its assets of kind `emotion`
//! as its expression pack, and the library's view of it (`put_index`, brought
//! up to date at a start by `index_missing`), with what Search Cardwave finds of
//! it: its characters' texts and greetings, its lorebooks' entries. An import of a file a card outside the
//! Trash came from (by its fingerprint, the SHA-256 of the whole file), or an exact copy of one (picture and
//! TOML files alike), is refused ([`super::in_library`]); two cards of one name are both kept.

use std::io::Cursor;

use anyhow::Context;
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_ccv4::edit;
use cw_ccv4::new::{self, NewCard};
use cw_ccv4::png::Container;
use cw_ccv4::{Document, display, drafts, png, sillytavern};
use cw_core::now_ms;
use cw_core::{Code, Fail};
use image::{ImageFormat, RgbaImage};
use sha2::{Digest, Sha256};

use crate::lorebooks;

use crate::cards::pictures::{Source, as_png};
use crate::cards::{CardIndex, Imported, MAX_LISTED, MAX_LISTED_CHARS, Storage, document_of};

/// Imports a card file (CCV4, or SillyTavern V2/V3 as a PNG or a JSON file) as a new card of `user`; a
/// JSON card has a picture of one pixel, as a card without art.
/// Of a card with several characters only the first is kept, and the import says so;
/// a card the library has already is refused ([`super::in_library`]), a file without a card is
/// [`super::NotACard`].
pub fn import(db: &dyn Storage, user: i64, file: &[u8]) -> anyhow::Result<Imported> {
    let fingerprint = Sha256::digest(file);
    // Asked before the file is parsed, so a folder imported again costs only reading and hashing it; asked
    // again as it is stored, in the transaction.
    if db.knows_file(user, &fingerprint)? {
        return Err(crate::cards::in_library().into());
    }
    let (mut container, mut notes) = if is_json_object(file) {
        match sillytavern::convert_json(file)? {
            Some((mut container, notes)) => {
                container.image = blank_picture()?;
                (container, notes)
            }
            None => return Err(crate::cards::NotACard("this file holds no character card").into()),
        }
    } else {
        (png::read(file)?, Vec::new())
    };
    notes.extend(edit::first_only(&mut container.toml)?);
    let mut imported = store(db, user, container, Source::Imported, Some(&fingerprint))?;
    imported.warnings.extend(notes);
    Ok(imported)
}

/// Whether `file` begins as a JSON object does, past a byte order mark and white space: a JSON card.
pub(crate) fn is_json_object(file: &[u8]) -> bool {
    file.iter()
        .find(|b| !b.is_ascii_whitespace() && ![0xEF, 0xBB, 0xBF].contains(*b))
        == Some(&b'{')
}

/// A picture of one pixel: a card's without art.
fn blank_picture() -> anyhow::Result<Vec<u8>> {
    let mut blank = Cursor::new(Vec::new());
    RgbaImage::new(1, 1).write_to(&mut blank, ImageFormat::Png)?;
    Ok(blank.into_inner())
}

/// The longest file name kept of an import, in characters.
const MAX_FILE_NAME: usize = 255;

/// [`import`], the card keeping `name`, the file's name, for its texts' imported drafts; a name of
/// only spaces is none, a longer one is cut to [`MAX_FILE_NAME`] characters.
pub fn import_named(
    db: &dyn Storage,
    user: i64,
    file: &[u8],
    name: Option<&str>,
) -> anyhow::Result<Imported> {
    let imported = import(db, user, file)?;
    let name: String = name
        .unwrap_or("")
        .trim()
        .chars()
        .take(MAX_FILE_NAME)
        .collect();
    if !name.is_empty() {
        db.set_card_file(imported.card_id, &name)?;
    }
    Ok(imported)
}

/// Makes a card from scratch, of what the form "New card" gives, as a new
/// card of `user`: its first version is the card file those texts make (see
/// [`new::files`]), stored as an imported one is. Its picture is the file
/// given, as a card keeps one ([`as_png`]); without one the card has a picture
/// of one pixel, which is a card without art. Each of its texts has its first
/// draft. Refused: a card without a title or without a name for its
/// character, and a picture that is no PNG, JPEG or WebP.
pub fn create(db: &dyn Storage, user: i64, mut new: NewCard) -> anyhow::Result<Imported> {
    let image = match new.picture.take() {
        Some(picture) => as_png(&STANDARD.decode(picture.trim()).context(
            Fail::said(Code::NotReadable, "the picture is not base64").with("what", "base64"),
        )?)?,
        None => blank_picture()?,
    };
    let now = now_ms();
    let mut toml = new::files(&new, now)?;
    let written = Document::parse(&toml)?;
    drafts::record(&mut toml, None, &written, drafts::EDITED, now, now)?;
    let container = Container {
        image,
        toml,
        assets: Vec::new(),
    };
    let made = store(db, user, container, Source::File, None)?;
    // Its title and its tags are the user's own.
    db.mark_card_made(made.card_id)?;
    Ok(made)
}

/// Stores what a card file held as a new card, its picture come from `source`, the file's `fingerprint`
/// kept where it was imported.
fn store(
    db: &dyn Storage,
    user: i64,
    mut container: Container,
    source: Source,
    fingerprint: Option<&[u8]>,
) -> anyhow::Result<Imported> {
    let mut warnings = Vec::new();
    if container.toml.is_empty() {
        match sillytavern::convert(&container.image)? {
            Some((converted, notes)) => (container, warnings) = (converted, notes),
            None => return Err(crate::cards::NotACard("this PNG holds no character card").into()),
        }
    }
    let document = Document::parse(&container.toml)?;
    let asset_names: Vec<&str> = container
        .assets
        .iter()
        .map(|(name, _)| name.as_str())
        .collect();
    warnings.extend(document.warnings(&asset_names));
    // Hashed here so the database is not held while it happens.
    let image_hash = Sha256::digest(&container.image);
    let asset_hashes: Vec<_> = container
        .assets
        .iter()
        .map(|(_, data)| Sha256::digest(data))
        .collect();
    let now = now_ms();

    let title = document.title();
    let index = index_of(&title, Some(&document));
    let hashes: Vec<Vec<u8>> = asset_hashes.iter().map(|hash| hash.to_vec()).collect();
    let (card_id, version_id) = db.store_card(
        user,
        &title,
        &container,
        (&image_hash, &hashes),
        source.as_str(),
        fingerprint,
        &index,
        now,
    )?;
    // Pictures of kind `emotion` among its assets are its expression pack.
    crate::expressions::take_from_card(db, user, card_id, &document, &container.assets)?;
    let version = 1;
    Ok(Imported {
        card_id,
        version_id,
        version,
        title,
        warnings,
        lorebooks: lorebooks::brought(&document),
    })
}

/// A name or a tag as the library keeps it: its first letters.
pub fn short(text: String) -> String {
    text.chars().take(MAX_LISTED_CHARS).collect()
}

/// The tags of a card version as the library keeps and shows them: a card can
/// hold any number of any length.
pub fn tags(document: &Document) -> Vec<String> {
    document
        .tags()
        .into_iter()
        .take(MAX_LISTED)
        .map(short)
        .collect()
}

/// What the library shows and searches of a card (the `card_index` table), of
/// the version that is now its newest. Without a `document` (it cannot be
/// read) the card is listed and found by its title alone.
pub(super) fn index_of(title: &str, document: Option<&Document>) -> CardIndex {
    let mut names: Vec<String> = Vec::new();
    let mut listed: Vec<String> = Vec::new();
    let mut search = vec![title.to_string()];
    let mut excerpt = String::new();
    let mut texts = Vec::new();
    let mut lore = Vec::new();
    let mut brings = 0;
    if let Some(document) = document {
        for id in &characters_of(document) {
            if let Some(said) = cw_ccv4::mapping::character(document, id) {
                texts.extend([said.description, said.personality, said.scenario]);
            }
            texts.extend(document.greetings(id, false));
        }
        lore = lorebooks::card_texts(document);
        brings = lorebooks::brings(document);
        let characters = document.characters();
        for id in characters.iter().take(MAX_LISTED) {
            let name = short(document.character_name(id));
            search.push(short(document.character_label(id)));
            if !names.contains(&name) {
                names.push(name);
            }
        }
        listed = tags(document);
        search.extend(names.iter().chain(&listed).cloned());
        excerpt = characters
            .iter()
            .find_map(|id| {
                // Only the start of a greeting is read: it can be of any length.
                let greeting = document.greetings(id, false).into_iter().next()?;
                Some(display::excerpt(&display::render(
                    display::head(&greeting),
                    &document.character_name(id),
                    // The word is put in when the card is read, in the app's language.
                    super::USER_MARK,
                )))
            })
            .unwrap_or_default();
    }
    CardIndex {
        names: serde_json::json!(names).to_string(),
        tags: serde_json::json!(listed).to_string(),
        excerpt,
        search: search.join("\n").to_lowercase(),
        texts: texts
            .into_iter()
            .filter(|text| !text.trim().is_empty())
            .collect::<Vec<_>>()
            .join("\n"),
        lore,
        brings,
    }
}

/// A card's characters, as its document names them.
fn characters_of(document: &Document) -> Vec<String> {
    document
        .characters()
        .into_iter()
        .map(str::to_string)
        .collect()
}

/// Brings the library's view of the cards up to date: for every card that has
/// none yet (it was imported by an older build) or whose newest version it does
/// not show. Run when the server starts.
pub fn index_missing(db: &dyn Storage) -> anyhow::Result<()> {
    let stale = db.stale_indexes()?;
    for (card_id, version_id, title) in stale {
        // One card that cannot be read must not keep the server from starting.
        // It is listed by its title, and not tried again at the next start.
        let document = document_of(db, version_id)
            .inspect_err(|error| {
                tracing::warn!("card {card_id} cannot be listed in full: {error:#}")
            })
            .ok();
        db.put_index(card_id, version_id, &index_of(&title, document.as_ref()))?;
    }
    Ok(())
}

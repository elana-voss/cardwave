//! A card's pictures. None is ever thrown away: every picture a card had stays
//! in `card_pictures`, with where it came from (`Source`) and when, until the
//! card is deleted for good. "Earlier pictures" lists them (`list`, `picture`);
//! one is shown as the card's by a new version in the card's place
//! (`use_picture`, by `versions::use_picture`); a file chosen or dropped joins
//! them and is shown (`use_file`); a picture the image model made joins them
//! as one to choose (`add_made`).
//!
//! A picture is kept as a PNG, as a card file holds one (`as_png`). Trap: a
//! picture of fewer than `MIN_ART` pixels a side is a card without art (a new
//! card's, or an import's without art), which is kept but not listed.

use std::io::Cursor;

use anyhow::{Context, bail, ensure};
use cw_ccv4::{png, sillytavern};
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};
use image::codecs::png::PngEncoder;
use image::metadata::Orientation;
use image::{DynamicImage, ImageDecoder, ImageEncoder, ImageFormat, ImageReader};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use ts_rs::TS;

use crate::thumbnails::MAX_PIXELS;

use crate::cards::{CardVersion, Storage, versions};

/// A picture smaller than this on a side is no art (the UI's `MIN_ART` too).
pub(crate) const MIN_ART: u32 = 16;

/// Where a card's picture came from.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export, rename = "PictureSource")]
pub enum Source {
    /// With the card file.
    Imported,
    /// A file chosen or dropped onto the picture.
    File,
    /// Made by the image model ("Make a picture").
    Made,
}

impl Source {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Imported => "imported",
            Self::File => "file",
            Self::Made => "made",
        }
    }

    fn of(kept: &str) -> Self {
        match kept {
            "file" => Self::File,
            "made" => Self::Made,
            _ => Self::Imported,
        }
    }
}

/// A picture as the database keeps it ([`Storage::card_pictures`]): its first
/// bytes, which say its size, in place of the picture.
pub struct Kept {
    pub id: i64,
    pub source: String,
    pub added_at: i64,
    pub head: Vec<u8>,
    pub in_use: bool,
}

/// One of a card's pictures, as "Earlier pictures" lists it.
#[derive(Debug, Serialize, TS)]
#[ts(export)]
pub struct CardPicture {
    pub id: i64,
    pub source: Source,
    /// When it came to the card.
    pub added_at: i64,
    /// Whether the card shows it.
    pub in_use: bool,
}

/// A card shown with another picture: its new version, and the picture it
/// showed before, which Undo shows again.
#[derive(Debug, Serialize, TS)]
#[ts(export)]
pub struct PictureChanged {
    pub version: CardVersion,
    pub before: i64,
}

/// A picture file as a card keeps it: a PNG as it is, without a card it holds
/// (CCV4 or SillyTavern's), and a JPEG or WebP written as a PNG with its colour
/// profile, turned upright as its EXIF says. Refused: any other file, one that
/// cannot be read, and one of more than [`MAX_PIXELS`].
pub fn as_png(file: &[u8]) -> anyhow::Result<Vec<u8>> {
    let png = match image::guess_format(file).ok() {
        Some(ImageFormat::Png) => {
            let image = png::read(file)
                .context(
                    Fail::said(Code::NotReadable, "the picture cannot be read")
                        .with("what", "picture_unreadable"),
                )?
                .image;
            sillytavern::plain_picture(&image)?
        }
        Some(format @ (ImageFormat::Jpeg | ImageFormat::WebP)) => {
            let mut decoder = ImageReader::with_format(Cursor::new(file), format)
                .into_decoder()
                .context(
                    Fail::said(Code::NotReadable, "the picture cannot be read")
                        .with("what", "picture_unreadable"),
                )?;
            let (wide, high) = decoder.dimensions();
            not_too_large(wide, high)?;
            // A profile that cannot be read is done without; so is a turn (EXIF).
            let profile = decoder.icc_profile().ok().flatten();
            let turn = decoder.orientation().unwrap_or(Orientation::NoTransforms);
            let mut picture = DynamicImage::from_decoder(decoder).context(
                Fail::said(Code::NotReadable, "the picture cannot be read")
                    .with("what", "picture_unreadable"),
            )?;
            // A phone's photo is kept upright, as the browser showed it.
            picture.apply_orientation(turn);
            let mut written = Vec::new();
            let mut encoder = PngEncoder::new(&mut written);
            if let Some(profile) = profile {
                // A profile the encoder does not take is done without.
                let _ = encoder.set_icc_profile(profile);
            }
            picture.write_with_encoder(encoder)?;
            written
        }
        _ => bail!(
            Fail::said(Code::NotReadable, "the picture is no PNG, JPEG or WebP")
                .with("what", "picture")
        ),
    };
    let (wide, high) = ImageReader::with_format(Cursor::new(&png), ImageFormat::Png)
        .into_dimensions()
        .context(
            Fail::said(Code::NotReadable, "the picture cannot be read")
                .with("what", "picture_unreadable"),
        )?;
    not_too_large(wide, high)?;
    Ok(png)
}

/// Refuses a picture of more than [`MAX_PIXELS`].
fn not_too_large(wide: u32, high: u32) -> anyhow::Result<()> {
    ensure!(
        u64::from(wide) * u64::from(high) <= MAX_PIXELS,
        Fail::said(
            Code::TooBig,
            format!("the picture is too large ({wide} by {high} pixels)")
        )
        .with("what", "picture_pixels")
        .with("wide", wide.to_string())
        .with("high", high.to_string())
    );
    Ok(())
}

/// Whether a PNG, of which `head` is the first bytes, is art: its header says
/// a size of at least [`MIN_ART`] on each side.
pub(crate) fn is_art(head: &[u8]) -> bool {
    let side = |at: usize| {
        head.get(at..at + 4)
            .and_then(|bytes| bytes.try_into().ok())
            .map(u32::from_be_bytes)
    };
    head.starts_with(b"\x89PNG")
        && matches!((side(16), side(20)), (Some(wide), Some(high)) if wide >= MIN_ART && high >= MIN_ART)
}

/// Every picture of a card of `user`'s that is art, the one it shows first,
/// then the newest first.
pub fn list(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<Vec<CardPicture>> {
    crate::cards::newest(db, user, card_id)?;
    Ok(db
        .card_pictures(user, card_id)?
        .into_iter()
        .filter(|kept| is_art(&kept.head))
        .map(|kept| CardPicture {
            id: kept.id,
            source: Source::of(&kept.source),
            added_at: kept.added_at,
            in_use: kept.in_use,
        })
        .collect())
}

/// One picture of a card of `user`'s, as a PNG.
pub fn picture(db: &dyn Storage, user: i64, card_id: i64, picture: i64) -> anyhow::Result<Vec<u8>> {
    Ok(db
        .card_picture(user, card_id, picture)?
        .ok_or(NotFound("picture"))?)
}

/// Keeps `png` among the pictures of a card of `user`'s that is not in the
/// Trash, as come from `source`: its id.
fn add(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    png: &[u8],
    source: Source,
) -> anyhow::Result<i64> {
    versions::kept_card(db, user, card_id)?;
    let hash = Sha256::digest(png);
    db.add_card_picture(card_id, &hash, png, source.as_str(), now_ms())
}

/// Has the card show its picture `picture`, of those it has. A picture it
/// shows already adds no version.
pub fn use_picture(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    picture: i64,
) -> anyhow::Result<PictureChanged> {
    let (version, before) = versions::use_picture(db, user, card_id, picture)?;
    Ok(PictureChanged { version, before })
}

/// Has the card show `png`, a file chosen for it ([`as_png`]), which joins its pictures.
pub fn use_file(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    png: &[u8],
) -> anyhow::Result<PictureChanged> {
    let picture = add(db, user, card_id, png, Source::File)?;
    use_picture(db, user, card_id, picture)
}

/// Keeps `png`, a picture the image model made for the card ([`as_png`]),
/// among its pictures, without showing it.
pub fn add_made(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    png: &[u8],
) -> anyhow::Result<CardPicture> {
    let id = add(db, user, card_id, png, Source::Made)?;
    list(db, user, card_id)?
        .into_iter()
        .find(|one| one.id == id)
        .context(
            Fail::said(Code::ModelAnswer, "the picture made is no art").with("what", "picture_art"),
        )
}

//! Expression packs: a character's pictures for moods, as SillyTavern keeps them, a folder or a zip of pictures
//! named by mood (`joy.png`, `anger-2.webp`; `read_pack`). A pack is kept once per user, by its pictures (`hash`);
//! cards share it, one pack per card (`cards.expression_pack_id`), and one that no card has any more goes to the
//! Trash alone (`trash::EXPRESSIONS`): when it is taken off a card (`put_on_card`) or the last card with it is
//! deleted for good. Put on a card again, it comes back out of the Trash. A card imported with pictures of kind
//! `emotion` among its assets (Character Card V3) has them as its pack (`take_from_card`).
//!
//! In a chat the picture of a reply's mood shows in the portrait's place, the mood told by the search model
//! (`find::mood`) of `MOODS`' descriptions; a pack without that mood's picture shows neutral's, and one without
//! that the plain portrait (`picture_for`).

use std::collections::BTreeMap;
use std::io::{Cursor, Read};

use anyhow::{Context, ensure};
use cw_ccv4::Document;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use ts_rs::TS;

/// The moods a pack has pictures for, GoEmotions' 27 as SillyTavern names them, each with the description its
/// vector is made of (the Flutter app's). Neutral, the 28th, has none: it is what no mood comes near.
pub const MOODS: [(&str, &str); 27] = [
    (
        "admiration",
        "respect and warm approval for someone or something impressive",
    ),
    ("amusement", "finding something funny or entertaining"),
    (
        "anger",
        "a strong feeling of displeasure, hostility, or rage",
    ),
    (
        "annoyance",
        "mild irritation or being bothered by something",
    ),
    (
        "approval",
        "a favorable opinion of or agreement with something",
    ),
    ("caring", "concern, kindness, and tenderness toward someone"),
    (
        "confusion",
        "being unable to understand or feeling uncertain",
    ),
    ("curiosity", "an eager desire to know or learn something"),
    (
        "desire",
        "a strong wish or longing for something or someone",
    ),
    (
        "disappointment",
        "sadness from hopes or expectations going unmet",
    ),
    (
        "disapproval",
        "an unfavorable opinion of or objection to something",
    ),
    ("disgust", "strong revulsion or distaste"),
    (
        "embarrassment",
        "feeling self-conscious, awkward, or ashamed",
    ),
    ("excitement", "feeling eager, thrilled, and full of energy"),
    ("fear", "feeling afraid, anxious, or threatened by danger"),
    ("gratitude", "feeling thankful and appreciative"),
    ("grief", "deep sorrow, especially over a loss"),
    ("joy", "great happiness, delight, and cheer"),
    ("love", "deep affection and attachment toward someone"),
    ("nervousness", "feeling anxious, worried, or on edge"),
    ("optimism", "hopefulness and confidence about the future"),
    (
        "pride",
        "satisfaction in one's own achievements or qualities",
    ),
    (
        "realization",
        "suddenly understanding or becoming aware of something",
    ),
    ("relief", "reassurance and ease after distress has passed"),
    ("remorse", "deep regret or guilt over a wrong"),
    ("sadness", "feeling unhappy, sorrowful, or downhearted"),
    ("surprise", "mild astonishment at something unexpected"),
];
pub const NEUTRAL: &str = "neutral";

/// The largest picture of a pack taken, and the most files a zip may hold.
const MAX_PICTURE: u64 = 20 * 1024 * 1024;
const MAX_ENTRIES: usize = 2000;
/// The most a zip's pictures may hold together, unpacked (a pack of SillyTavern's is some 30 MB).
const MAX_PACK: u64 = 100 * 1024 * 1024;
/// The most characters of a pack's name.
const MAX_NAME: usize = 100;

/// A pack as the card page and "Add expressions" show it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ExpressionPack {
    pub id: i64,
    pub name: String,
    /// The moods it has a picture for, in `MOODS`' order, neutral last.
    pub moods: Vec<String>,
    /// How many cards outside the Trash have it.
    pub cards: u32,
}

/// A file given for a pack: a picture named by its mood, or a zip of them.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct PackFile {
    pub name: String,
    /// Its bytes in base64.
    pub data: String,
}

/// A pack from files, for a card: the name it is to have, if it is new, and its files.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct NewPack {
    pub name: String,
    pub files: Vec<PackFile>,
}

/// A card's pack after a change, and the one it had before, for Undo.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct CardExpressions {
    pub pack: Option<ExpressionPack>,
    pub before: Option<i64>,
}

/// One picture of a pack: its mood, its bytes' SHA-256 and its bytes.
pub struct Picture {
    pub mood: String,
    pub hash: Vec<u8>,
    pub data: Vec<u8>,
}

/// A pack's id and the moods it has pictures of.
pub type PackMoods = (i64, Vec<String>);

/// What the packs need of the database, which `cw_store::expressions` gives.
pub trait Storage {
    /// Keeps a pack of `user` unless one with the same pictures (`hash`) is kept; answers its id either way.
    fn store_pack(
        &self,
        user: i64,
        name: &str,
        hash: &[u8],
        pictures: &[Picture],
    ) -> anyhow::Result<i64>;
    /// The packs of `user` outside the Trash, by name.
    fn packs(&self, user: i64) -> anyhow::Result<Vec<ExpressionPack>>;
    /// The pack of a card of `user`, if it has one.
    fn card_pack(&self, user: i64, card_id: i64) -> anyhow::Result<Option<ExpressionPack>>;
    /// Gives a card of `user` the pack (or none), takes that out of the Trash, and puts the one it had into the
    /// Trash where no card has that any more. Answers the one it had.
    fn set_card_pack(
        &self,
        user: i64,
        card_id: i64,
        pack: Option<i64>,
    ) -> anyhow::Result<Option<i64>>;
    /// A picture of a pack of `user`.
    fn pack_picture(&self, user: i64, pack: i64, mood: &str) -> anyhow::Result<Option<Vec<u8>>>;
    /// A message of `user` (none where it is gone) and, where its speaker's card has one, the pack: its id and moods.
    fn message_pack(
        &self,
        user: i64,
        message_id: i64,
    ) -> anyhow::Result<(String, Option<PackMoods>)>;
    /// Moves a pack of `user` that no card has to the Trash, or takes one out.
    fn set_pack_trashed(&self, user: i64, pack: i64, trashed: bool) -> anyhow::Result<()>;
}

/// The mood a file is named for: its name's stem, or the stem's first word (`joy-2`, `joy_smile`), as SillyTavern
/// keeps several pictures of a mood. A hidden file (`._joy.png` of a Mac's zip) is none.
pub fn mood_of_name(path: &str) -> Option<&'static str> {
    named(path).map(|(mood, _)| mood)
}

/// The mood a file is named for, and whether its stem is the mood's name alone.
fn named(path: &str) -> Option<(&'static str, bool)> {
    let name = path.rsplit(['/', '\\']).next()?;
    if name.starts_with('.') {
        return None;
    }
    let stem = name
        .rsplit_once('.')
        .map_or(name, |(stem, _)| stem)
        .to_lowercase();
    let first = stem.split(['-', '_', ' ', '.']).next().unwrap_or_default();
    MOODS
        .iter()
        .map(|(mood, _)| *mood)
        .chain([NEUTRAL])
        .find(|mood| *mood == stem || *mood == first)
        .map(|mood| (mood, mood == stem))
}

/// The type of a picture by its first bytes: PNG, JPEG, WebP or GIF; none for anything else.
pub fn picture_type(data: &[u8]) -> Option<&'static str> {
    if data.starts_with(b"\x89PNG\r\n\x1a\n") {
        Some("image/png")
    } else if data.starts_with(b"\xff\xd8\xff") {
        Some("image/jpeg")
    } else if data.len() >= 12 && &data[..4] == b"RIFF" && &data[8..12] == b"WEBP" {
        Some("image/webp")
    } else if data.starts_with(b"GIF87a") || data.starts_with(b"GIF89a") {
        Some("image/gif")
    } else {
        None
    }
}

/// The pictures of a pack from its files, a zip's opened: of each mood the one named by it alone (`joy.png`), else
/// the first by name; other files left out.
/// Refused where no picture is named by a mood.
pub(crate) fn read_pack(files: Vec<(String, Vec<u8>)>) -> anyhow::Result<Vec<Picture>> {
    let mut all = Vec::new();
    for (name, data) in files {
        if name.to_lowercase().ends_with(".zip") {
            all.extend(unzip(&name, data)?);
        } else {
            all.push((name, data));
        }
    }
    let mut all: Vec<_> = all
        .into_iter()
        .filter_map(|(name, data)| named(&name).map(|(mood, alone)| (!alone, name, mood, data)))
        .collect();
    all.sort_by(|a, b| (a.0, &a.1).cmp(&(b.0, &b.1)));
    let mut by_mood: BTreeMap<usize, Picture> = BTreeMap::new();
    for (_, _, mood, data) in all {
        if picture_type(&data).is_none() || data.len() as u64 > MAX_PICTURE {
            continue;
        }
        let order = MOODS
            .iter()
            .position(|(one, _)| *one == mood)
            .unwrap_or(MOODS.len());
        by_mood.entry(order).or_insert_with(|| Picture {
            mood: mood.to_string(),
            hash: Sha256::digest(&data).to_vec(),
            data,
        });
    }
    ensure!(!by_mood.is_empty(), Fail::said(Code::NotReadable, "none of its pictures is named by a mood, as joy.png or anger.png are (PNG, JPEG, WebP or GIF)").with("what", "expression_pack"));
    Ok(by_mood.into_values().collect())
}

/// The pictures of a zip named by a mood, each read up to `MAX_PICTURE` and one byte more, so a larger one is known
/// and left out; refused where those kept hold more than `MAX_PACK` together, so a zip that unpacks to gigabytes
/// is not held in memory.
fn unzip(name: &str, data: Vec<u8>) -> anyhow::Result<Vec<(String, Vec<u8>)>> {
    let mut zip = zip::ZipArchive::new(Cursor::new(data)).with_context(|| {
        Fail::said(Code::NotReadable, format!("{name} cannot be read as a zip"))
            .with("what", "zip")
            .with("name", name.to_string())
    })?;
    ensure!(
        zip.len() <= MAX_ENTRIES,
        Fail::said(
            Code::TooBig,
            format!("{name} holds more than {MAX_ENTRIES} files")
        )
        .with("what", "expression_zip_files")
        .with("name", name.to_string())
        .with("max_entries", MAX_ENTRIES)
    );
    let (mut files, mut total) = (Vec::new(), 0);
    for at in 0..zip.len() {
        let mut file = zip.by_index(at)?;
        // A name that is not UTF-8 names no mood.
        let Ok(path) = file.name().map(|name| name.to_string()) else {
            continue;
        };
        if file.is_dir() || mood_of_name(&path).is_none() || file.size() > MAX_PICTURE {
            continue;
        }
        let mut bytes = Vec::new();
        (&mut file).take(MAX_PICTURE + 1).read_to_end(&mut bytes)?;
        if picture_type(&bytes).is_none() || bytes.len() as u64 > MAX_PICTURE {
            continue;
        }
        total += bytes.len() as u64;
        ensure!(
            total <= MAX_PACK,
            Fail::said(
                Code::TooBig,
                format!("{name}'s pictures hold more than {} MB", MAX_PACK >> 20)
            )
            .with("what", "expression_pack_size")
            .with("name", name.to_string())
        );
        files.push((path, bytes));
    }
    Ok(files)
}

/// What makes a pack the same as another: its moods and their pictures.
pub(crate) fn hash_of(pictures: &[Picture]) -> Vec<u8> {
    let mut hash = Sha256::new();
    for picture in pictures {
        hash.update(picture.mood.as_bytes());
        hash.update([0]);
        hash.update(&picture.hash);
    }
    hash.finalize().to_vec()
}

/// A pack's name as it is kept: trimmed and cut, "Expressions" where none is given.
fn name_of(name: &str) -> String {
    let name: String = name.trim().chars().take(MAX_NAME).collect();
    if name.is_empty() {
        "Expressions".to_string()
    } else {
        name
    }
}

/// Keeps a pack of `user` from files, or finds the same one kept, and puts it on the card.
pub fn import_for_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    new: NewPack,
) -> anyhow::Result<CardExpressions> {
    use base64::Engine;
    let files = new
        .files
        .into_iter()
        .map(|file| {
            let data = base64::engine::general_purpose::STANDARD
                .decode(file.data.trim())
                .with_context(|| {
                    Fail::said(Code::NotReadable, format!("{} is not base64", file.name))
                        .with("what", "base64_file")
                        .with("name", (file.name).to_string())
                })?;
            Ok((file.name, data))
        })
        .collect::<anyhow::Result<Vec<_>>>()?;
    ensure!(
        !files.is_empty(),
        Fail::said(Code::Needed, "choose a zip or the pictures of a pack")
            .with("what", "expression_files")
    );
    let pictures = read_pack(files)?;
    // The card is asked for first, so a pack for no card is not kept.
    db.card_pack(user, card_id)?;
    let pack = db.store_pack(user, &name_of(&new.name), &hash_of(&pictures), &pictures)?;
    put_on_card(db, user, card_id, Some(pack))
}

/// Gives a card the pack, or none; the one it had goes to the Trash where no card has it any more.
pub fn put_on_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    pack: Option<i64>,
) -> anyhow::Result<CardExpressions> {
    let before = db.set_card_pack(user, card_id, pack)?;
    Ok(CardExpressions {
        pack: db.card_pack(user, card_id)?,
        before,
    })
}

/// The pack of a card, if it has one.
pub fn of_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
) -> anyhow::Result<Option<ExpressionPack>> {
    db.card_pack(user, card_id)
}

/// The packs of `user` outside the Trash, by name.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<ExpressionPack>> {
    db.packs(user)
}

/// A picture of a pack and its type.
pub fn picture(
    db: &dyn Storage,
    user: i64,
    pack: i64,
    mood: &str,
) -> anyhow::Result<(&'static str, Vec<u8>)> {
    let data = db
        .pack_picture(user, pack, mood)?
        .ok_or(cw_core::NotFound("expression"))?;
    Ok((
        picture_type(&data).unwrap_or("application/octet-stream"),
        data,
    ))
}

/// Moves a pack no card has to the Trash, or takes it out.
pub fn set_trashed(db: &dyn Storage, user: i64, pack: i64, trashed: bool) -> anyhow::Result<()> {
    db.set_pack_trashed(user, pack, trashed)
}

/// The mood whose picture shows for `mood` in a pack with `moods`: its own, else neutral's, else none.
pub fn picture_for<'a>(mood: &str, moods: &'a [String]) -> Option<&'a str> {
    moods
        .iter()
        .find(|one| *one == mood)
        .or_else(|| moods.iter().find(|one| *one == NEUTRAL))
        .map(String::as_str)
}

/// A card's pack from its assets of kind `emotion`, each named by its mood, as Character Card V3 has them: kept as
/// any pack is and put on the card. Nothing where it has none.
pub(crate) fn take_from_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    document: &Document,
    assets: &[(String, Vec<u8>)],
) -> anyhow::Result<()> {
    let mut files = Vec::new();
    for id in document.ids("asset") {
        let Some(asset) = document.element("asset", id) else {
            continue;
        };
        let field = |key: &str| {
            asset
                .get(key)
                .and_then(|value| value.as_str())
                .unwrap_or_default()
        };
        if field("kind") != "emotion" {
            continue;
        }
        let Some(file) = field("file").strip_prefix("asset://") else {
            continue;
        };
        let Some((_, data)) = assets.iter().find(|(name, _)| name == file) else {
            continue;
        };
        let extension = file
            .rsplit_once('.')
            .map_or("png", |(_, extension)| extension);
        files.push((format!("{}.{extension}", field("name")), data.clone()));
    }
    if files.is_empty() {
        return Ok(());
    }
    // A card's assets that make no pack leave it without one: the card itself is what was imported.
    let Ok(pictures) = read_pack(files) else {
        return Ok(());
    };
    let name = document
        .characters()
        .first()
        .map(|first| document.character_name(first))
        .unwrap_or_default();
    let pack = db.store_pack(user, &name_of(&name), &hash_of(&pictures), &pictures)?;
    db.set_card_pack(user, card_id, Some(pack))?;
    Ok(())
}

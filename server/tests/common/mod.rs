//! Shared by the card and chat tests: a small CCV4 card file, a scratch database
//! and, in `server`, a running server.
//!
//! `Scratch` is a database with one user and no server, for the rules of the
//! storage, in which each table counts from 1, so that the first chat and the
//! first lorebook have one number: a test of a rule that could take one for the
//! other makes them differ (seen). `card_file()` is the sample card: its
//! character is `mira`, its first greeting `"You picked a night for it,
//! {{user}}."`, its lorebook `lorebook.coast` (`lore.wreck`, `lore.lamp`, which
//! always applies, and `lore.off`); its second character `bare` has no place
//! for lorebooks in its prompt. An import keeps a card's first character alone;
//! `import_whole` (over HTTP `Server::upload_whole`) keeps them all, as a card
//! imported before that has them, for chats with several characters of one card.
//! `lore` has the lorebook tests' world-info files and chats; `user`, `reply`
//! and `writing` are messages to store.
#![allow(dead_code)]

pub mod api;
pub mod describing;
pub mod edit;
pub mod embedder;
pub mod lore;
pub mod lorebook_edit;
pub mod memory;
pub mod model;
pub mod server;
pub mod streamed;

use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_ccv4::png::{self, Container};
use cw_chat::chats::NewMessage;
use cw_key::DbKey;
use cw_key::FILE_NAME;
use cw_library::cards;
use cw_prompt::Role;
use cw_store::Db;
use serde_json::Value as Json;

static NEXT: AtomicUsize = AtomicUsize::new(0);

/// A database in a scratch folder, removed on drop.
pub struct Scratch {
    // Before the folder, so that it is closed first: a folder with an open
    // file in it cannot be removed on Windows.
    pub db: Db,
    /// The user the tests act for.
    pub user: i64,
    dir: Dir,
}

/// A folder of the test's own, removed on drop.
pub struct Folder(pub PathBuf);

impl Folder {
    pub fn new(name: &str) -> Self {
        let path =
            std::env::temp_dir().join(format!("cardwave-folder-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&path);
        std::fs::create_dir_all(&path).unwrap();
        Self(path)
    }

    pub fn path(&self) -> String {
        self.0.display().to_string()
    }
}

impl Drop for Folder {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// Imports `file` as a card of `user` with all its characters, as one imported
/// before a card held one: its files are put back as the file has them.
pub fn import_whole(db: &Db, user: i64, file: &[u8]) -> anyhow::Result<cards::Imported> {
    let imported = cards::import(db, user, file)?;
    plant_whole(db, imported.version_id, file);
    Ok(imported)
}

/// Gives the card version `version` the TOML files of the card `file` as they are written.
pub fn plant_whole(db: &Db, version: i64, file: &[u8]) {
    for (name, text) in png::read(file).unwrap().toml {
        db.with(|conn| {
            conn.execute(
                "update card_files set toml = ?1 where version_id = ?2 and name = ?3",
                (&text, version, &name),
            )
        })
        .unwrap();
    }
    // Its content hash no longer holds: it is no copy of any file imported (the card of several characters
    // imported keeps only its first, which is otherwise the same as that one alone).
    db.with(|conn| {
        conn.execute(
            "update card_versions set content = null where id = ?1",
            [version],
        )
    })
    .unwrap();
}

/// A folder that goes when it is dropped.
struct Dir(PathBuf);

impl Scratch {
    pub fn new() -> Self {
        let n = NEXT.fetch_add(1, Ordering::Relaxed);
        let dir =
            Dir(std::env::temp_dir()
                .join(format!("cardwave-store-test-{}-{n}", std::process::id())));
        // A run that was killed leaves its folders, and process numbers come round again.
        let _ = std::fs::remove_dir_all(&dir.0);
        std::fs::create_dir_all(&dir.0).unwrap();
        let db = Db::open(&dir.0.join(FILE_NAME), &DbKey::generate().unwrap()).unwrap();
        let user = cw_accounts::users::create(&db, "erin").unwrap();
        Self { db, user, dir }
    }
}

impl Drop for Dir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// One PNG chunk: length, type, data, checksum.
pub fn chunk(kind: &[u8; 4], data: &[u8]) -> Vec<u8> {
    let mut out = (data.len() as u32).to_be_bytes().to_vec();
    out.extend_from_slice(kind);
    out.extend_from_slice(data);
    let crc = crc32fast::hash(&out[4..]);
    out.extend_from_slice(&crc.to_be_bytes());
    out
}

pub fn png_of(chunks: &[Vec<u8>]) -> Vec<u8> {
    let mut out = vec![0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];
    for chunk in chunks {
        out.extend_from_slice(chunk);
    }
    out
}

pub fn header() -> Vec<u8> {
    chunk(b"IHDR", &[0, 0, 0, 1, 0, 0, 0, 1, 8, 0, 0, 0, 0])
}

pub fn pixels() -> Vec<u8> {
    chunk(
        b"IDAT",
        &[0x78, 0x9C, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01],
    )
}

/// A one-pixel PNG without card data.
pub fn picture() -> Vec<u8> {
    png_of(&[header(), pixels(), chunk(b"IEND", &[])])
}

/// A PNG `tEXt` chunk.
pub fn text_chunk(keyword: &str, text: &[u8]) -> Vec<u8> {
    let mut data = keyword.as_bytes().to_vec();
    data.push(0);
    data.extend_from_slice(text);
    chunk(b"tEXt", &data)
}

/// The one-pixel picture with `chunks` in front of its end.
pub fn png_with(chunks: Vec<Vec<u8>>) -> Vec<u8> {
    let mut all = vec![header(), pixels()];
    all.extend(chunks);
    all.push(chunk(b"IEND", &[]));
    png_of(&all)
}

pub fn encoded(card: &Json) -> Vec<u8> {
    STANDARD.encode(card.to_string()).into_bytes()
}

/// A card file as SillyTavern writes it.
pub fn card_png(card: &Json) -> Vec<u8> {
    png_with(vec![text_chunk("chara", &encoded(card))])
}

/// The fields of the card a tool wrote into `file`, read without the importer.
pub fn card_data(file: &[u8]) -> Json {
    let (_, texts) =
        png::take_text(file, |keyword| keyword == "ccv3" || keyword == "chara").unwrap();
    let text = texts
        .iter()
        .find(|(keyword, _)| keyword == "ccv3")
        .or(texts.first())
        .expect("no card chunk")
        .1;
    let card: Json = serde_json::from_slice(&STANDARD.decode(text).unwrap()).unwrap();
    card["data"].clone()
}

pub const BLOCKS: &str = r#"
spec = "ccv4:1.0.0"

[meta-info]
title = "Mira of the North Light"
tags = ["sea", "mystery"]

[name.mira]
text = "Mira"

[description.mira]
text = """
Keeper of the north light. {{char}} counts ships.
"""

[personality.mira]
text = "Dry, patient."

[wardrobe.oilskin]
text = "A patched oilskin coat."

[scenario.storm]
text = "A storm has cut the causeway. {{user}} is stranded."

[greeting.door]
text = """
"You picked a night for it, {{user}}."
"""

[greeting.lamp]
text = "Hold the lamp. Don't ask."

[greeting.crowd]
text = "All of you, inside."

[dialogue-example.tea]
text = """
<START>
{{user}}: Tea?
{{char}}: "Black."
"""

[prompt.main]
text = "Write tersely."

[prompt.whisper]
depth = 2
text = "[The light flickers.]"

[prompt.tide]
depth = 0
text = "[The tide is rising.]"

[prompt.style]
text = "[Under 100 words.]"

[creator-note.tips]
text = "Never sent to the model."
"#;

pub const CARDS: &str = r#"
[lore.wreck]
keywords = ["wreck"]
priority = 5
sticky = 2
text = "The Asta sank here in 1911."

[lore.lamp]
trigger = "always"
keywords = []
insertion-order = 1
text = "The lamp must never go out."

[lore.off]
enabled = false
keywords = ["wreck"]
text = "Disabled."

[lorebook.coast]
scan-depth = 3
token-budget = 300
entries = ["lore.wreck", "lore.lamp", "lore.off"]

[character.mira]
name-card = "Mira (storm night)"
name-char = "name.mira"
avatar = "asset://card/images/mira.png"
greetings = ["greeting.door", "greeting.lamp"]
group-greetings = ["greeting.crowd"]
lorebooks = ["lorebook.coast"]
creator-note = "creator-note.tips"
prompt = [
  "prompt.main",
  "name.mira",
  "description.mira",
  "wardrobe.oilskin",
  "personality.mira",
  "scenario.storm",
  "dialogue-example.tea",
  "prompt.whisper",
  "prompt.tide",
  "creator-note.tips",
  "LOREBOOK",
  "CHAT-HISTORY",
  { text = "Stay in the scene." },
  "prompt.style",
]

[character.bare]
prompt = ["CHAT-HISTORY"]
"#;

pub const USER: &str = r#"
[user-state]
is-favorite = true

[revision."personality.mira"]
drafts = [
  { saved = 2026-07-08T09:00:00Z, pinned = true, payload = { text = "Old pin." } },
  { saved = 2026-07-10T18:30:00Z, pinned = true, payload = { text = "Wry, patient." } },
  { saved = 2026-07-12T18:30:00Z, payload = { text = "Not pinned." } },
]
"#;

pub const AVATAR: &[u8] = b"not really a picture";

pub fn files() -> Vec<(String, String)> {
    vec![
        ("card/0001_blocks.toml".to_string(), BLOCKS.to_string()),
        ("card/0002_cards.toml".to_string(), CARDS.to_string()),
        ("user/0000_state.toml".to_string(), USER.to_string()),
    ]
}

pub fn container() -> Container {
    Container {
        image: picture(),
        toml: files(),
        assets: vec![("card/images/mira.png".to_string(), AVATAR.to_vec())],
    }
}

/// The sample card as a CCV4 PNG file.
pub fn card_file() -> Vec<u8> {
    png::write(&container()).unwrap()
}

/// The sample card as a file that is no exact copy of one imported before, as
/// an import refuses those: its first TOML file made [`unique`].
pub fn card_copy() -> Vec<u8> {
    let mut container = container();
    container.toml[0].1 = unique(&container.toml[0].1);
    png::write(&container).unwrap()
}

/// A card's TOML text with a comment of its own at its end, so that the card
/// is no exact copy of another.
pub fn unique(toml: &str) -> String {
    format!("{toml}\n# copy {}\n", NEXT.fetch_add(1, Ordering::Relaxed))
}

/// A message of the user, complete.
pub fn user(content: &str) -> NewMessage<'_> {
    NewMessage {
        role: Role::User,
        speaker_id: None,
        content,
        complete: true,
    }
}

/// A character's reply, complete.
pub fn reply(content: &str) -> NewMessage<'_> {
    NewMessage {
        role: Role::Assistant,
        speaker_id: None,
        content,
        complete: true,
    }
}

/// A reply that is still being generated.
pub fn writing(content: &str) -> NewMessage<'_> {
    NewMessage {
        complete: false,
        ..reply(content)
    }
}

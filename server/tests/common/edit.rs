//! Helpers of the tests of a card's editor (`edit.rs`, `edit_more.rs`): a card version's files as kept,
//! a card of one TOML file, the editor's characters and texts, and `TALKATIVE`, a card of three characters
//! talkative beyond the most there is.

use cw_ccv4::Document;
use cw_ccv4::edit::{EditCharacter, EditText};
use cw_ccv4::png::{self, Container};
use cw_library::cards;
use cw_store::Db;
use serde_json::Value;

use super::{Scratch, picture};

/// The TOML files of a card version as they are kept, by name.
pub fn texts(db: &Db, version: i64) -> Vec<(String, String)> {
    db.with(|conn| {
        let mut query =
            conn.prepare("select name, toml from card_files where version_id = ?1 and toml is not null order by name")?;
        query.query_map([version], |r| Ok((r.get(0)?, r.get(1)?)))?.collect()
    })
    .unwrap()
}

/// The assets of a card version: each file's name and which stored file it is.
pub fn assets(db: &Db, version: i64) -> Vec<(String, i64)> {
    db.with(|conn| {
        let mut query =
            conn.prepare("select name, asset_id from card_files where version_id = ?1 and toml is null order by name")?;
        query.query_map([version], |r| Ok((r.get(0)?, r.get(1)?)))?.collect()
    })
    .unwrap()
}

pub fn count(db: &Db, table: &str) -> i64 {
    db.with(|conn| conn.query_row(&format!("select count(*) from {table}"), [], |r| r.get(0)))
        .unwrap()
}

/// A card of one TOML file, with the one-pixel picture.
pub fn card_of(toml: &str) -> Vec<u8> {
    let toml = vec![("card/0001_card.toml".to_string(), toml.to_string())];
    png::write(&Container {
        image: picture(),
        toml,
        assets: Vec::new(),
    })
    .unwrap()
}

/// What the page shows of each character of the one-file card `toml`: each as
/// the first of a card of its own. A card holds one character, but one
/// imported before (`super::import_whole`) may have several, and an edit may
/// name each.
pub fn each_shown(toml: &str) -> Vec<EditCharacter> {
    let file = [("card/0001_card.toml".to_string(), toml.to_string())];
    let document = Document::parse(&file).unwrap();
    let scratch = Scratch::new();
    let first = |id: &str| {
        let at = toml.find(&format!("\n[character.{id}]")).unwrap();
        let end = toml[at + 1..]
            .find("\n[")
            .map_or(toml.len(), |n| at + 1 + n);
        let rest = format!("{}{}", &toml[..at], &toml[end..]);
        let before = rest.find("\n[character.").unwrap_or(rest.len());
        format!("{}{}{}", &rest[..before], &toml[at..end], &rest[before..])
    };
    document
        .ids("character")
        .into_iter()
        .map(|id| {
            let card = super::import_whole(&scratch.db, scratch.user, &card_of(&first(id)));
            let card_id = card.unwrap().card_id;
            let mut form = cards::editable(&scratch.db, scratch.user, card_id, None).unwrap();
            form.characters.remove(0)
        })
        .collect()
}

/// A text of the card in the block `reference`.
pub fn part(reference: &str, text: &str) -> EditText {
    EditText {
        reference: Some(reference.to_string()),
        text: text.to_string(),
        modes: Vec::new(),
    }
}

/// A text the card has no block for yet.
pub fn new(text: &str) -> EditText {
    EditText {
        reference: None,
        text: text.to_string(),
        modes: Vec::new(),
    }
}

pub fn refusal(result: anyhow::Result<cards::CardVersion>) -> String {
    format!("{:#}", result.unwrap_err())
}

/// What a character's keys say: a list as it is, a reference as itself.
pub fn key(document: &Document, id: &str, key: &str) -> Value {
    serde_json::to_value(document.character(id).unwrap().get(key)).unwrap()
}

/// Three characters, talkative beyond the most there is, as the card says nothing, and quietly.
pub const TALKATIVE: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
modified = 2026-07-11

[name.ada]
text = "Ada"

[character.ada]
name-char = "name.ada"
group-talkativeness = 1.5 # beyond the most
prompt = ["name.ada", "CHAT-HISTORY"]
"#;

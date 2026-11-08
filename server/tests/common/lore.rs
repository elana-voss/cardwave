//! Lorebooks for the tests of the library's lorebooks (`lorebooks.rs`) and of a
//! card's (`lorebooks_cards.rs`) and of those for every chat and a persona
//! (`lorebooks_reach.rs`): world-info files made, imported and listed,
//! chats with the sample card, and what a chat's lorebooks and prompt hold.

use cw_chat::chats::{self, ChatLorebook, NewChat};
use cw_library::cards::Show;
use cw_library::lorebooks::{self, Lorebook};
use cw_library::trash::{self, TrashItem};
use cw_store::Db;
use serde_json::{Value, json};

use super::Scratch;

/// A world-info entry, as SillyTavern names its settings.
pub fn entry(name: &str, keys: &[&str], content: &str) -> Value {
    json!({ "key": keys, "comment": name, "content": content })
}

/// A world-info file with `entries` under the numbers 0, 1, 2, …
pub fn world(entries: &[Value]) -> Value {
    let numbered: serde_json::Map<String, Value> = entries
        .iter()
        .enumerate()
        .map(|(number, entry)| (number.to_string(), entry.clone()))
        .collect();
    json!({ "entries": numbered })
}

pub fn import(scratch: &Scratch, file: &Value, file_name: &str) -> Lorebook {
    let imported = lorebooks::import(
        &scratch.db,
        scratch.user,
        file.to_string().as_bytes(),
        file_name,
    )
    .unwrap();
    assert!(imported.warnings.is_empty(), "{:?}", imported.warnings);
    imported.lorebook
}

/// The names the list shows of the library's own lorebooks for a search and
/// a filter, in its order: the cards' own it lists too are left out.
pub fn names(scratch: &Scratch, query: &str, show: Show) -> Vec<String> {
    lorebooks::find(&scratch.db, scratch.user, query, show)
        .unwrap()
        .into_iter()
        .filter(|lorebook| lorebook.card.is_none())
        .map(|lorebook| lorebook.name)
        .collect()
}

/// A chat with one character of the sample card: `mira`, who brings the
/// lorebook `coast`, or `bare`, whose prompt has no place for lorebooks.
pub fn chat(scratch: &Scratch, character: &str) -> i64 {
    let card = super::import_whole(&scratch.db, scratch.user, &super::card_copy()).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, character)],
        persona_id: None,
        greeting: 0,
    };
    chats::create(&scratch.db, scratch.user, &new).unwrap()
}

/// The one book the chat's prompts are built with.
pub fn book(scratch: &Scratch, chat_id: i64) -> Option<cw_prompt::Lorebook> {
    chats::prompt_inputs(&scratch.db, scratch.user, chat_id, None)
        .unwrap()
        .character
        .lorebook
}

/// The entries of that book, by their IDs.
pub fn ids(scratch: &Scratch, chat_id: i64) -> Vec<String> {
    book(scratch, chat_id)
        .map(|book| {
            book.entries
                .into_iter()
                .filter_map(|entry| entry.id)
                .collect()
        })
        .unwrap_or_default()
}

/// The chat's lorebooks as (name, on, the names of what is left out, in the Trash).
pub fn taken(scratch: &Scratch, chat_id: i64) -> Vec<(String, bool, Vec<String>, bool)> {
    let shown = |book: ChatLorebook| {
        (
            book.name,
            book.on,
            book.removed.into_iter().map(|lore| lore.name).collect(),
            book.trashed,
        )
    };
    chats::lorebooks(&scratch.db, scratch.user, chat_id)
        .unwrap()
        .into_iter()
        .map(shown)
        .collect()
}

/// The lorebooks the Trash lists, as (id, chats that have it).
pub fn in_trash(db: &Db, user: i64) -> Vec<(i64, u32)> {
    trash::list(db, user)
        .unwrap()
        .into_iter()
        .filter_map(|item| match item {
            TrashItem::Lorebook { id, chats, .. } => Some((id, chats)),
            _ => None,
        })
        .collect()
}

pub fn count(db: &Db, table: &str) -> i64 {
    db.with(|conn| conn.query_row(&format!("select count(*) from {table}"), [], |r| r.get(0)))
        .unwrap()
}

/// A lorebook as a card carries it, called "Harbour": two entries, a budget and a scan depth.
pub fn harbour() -> Value {
    json!({
        "name": "Harbour", "description": "The harbour and its bell.", "scan_depth": 7, "token_budget": 500,
        "entries": [
            { "keys": ["pier"], "comment": "Pier", "content": "The pier is rotten.", "enabled": true },
            { "keys": ["bell"], "comment": "Bell", "content": "The bell rings in fog.", "constant": true, "enabled": true },
        ],
    })
}

/// A lorebook of one entry, called as its file is.
pub fn single(scratch: &Scratch, name: &str) -> i64 {
    import(
        scratch,
        &world(&[entry(name, &[name], &format!("Of {name}."))]),
        &format!("{name}.json"),
    )
    .id
}

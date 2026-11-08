//! Helpers of the tests of a lorebook's editor (`lorebook_edit.rs`, `lorebook_edit_more.rs`): `NOTED`, the
//! lorebook written by hand, its entries `wreck` and `lamp` as the editor reads them, and what keeps,
//! reads, changes and chats with a lorebook of the library (the heads of those files say each).

use cw_ccv4::lore::{self, EditEntry, EntryChange, Trigger};
use cw_chat::chats::{self, NewChat};
use cw_library::lorebooks;
use cw_prompt::SelectiveLogic;
use serde_json::json;

use super::Scratch;

pub const NOTED: &str = r#"# The coast, by hand.
spec = "ccv4:1.0.0"

[lorebook.coast]
name = "North Coast"
description = "Of the coast and its lights."
scan-depth = 6
entries = [
    "lore.wreck",
    "lore.lamp",
    "lore.gone",
]

# Sank in 1911.
[lore.wreck]
name = "The wreck" # as the charts call it
keywords = ["wreck", "Asta"]
secondary-keywords = ["storm", "night"]
selective = true
selective-logic = "not-any"
priority = 5
sticky = 2
use-regex = false
text = """
The Asta sank here in 1911.
"""

[lore.wreck.character-filter]
names = ["Mira"]
tags = []
exclude = true

[lore.lamp]
keywords = ["lamp"]
secondary-keywords = ["oil"]
selective-logic = "and-all"
trigger = "always"
enabled = false
insertion-order = 40
probability = 30
scan-depth = 2
depth = 3
role = "user"
case-sensitive = true
match-whole-words = true
text = "The lamp burns whale oil."

[lore.stray]
keywords = ["stray"]
text = "Listed by nobody."
"#;

/// Keeps `toml` as a lorebook of the library, and answers with its number.
pub fn plant(scratch: &Scratch, toml: &str) -> i64 {
    let file = json!({ "entries": { "0": { "key": ["first"], "content": "First." } } });
    let made = lorebooks::import(
        &scratch.db,
        scratch.user,
        file.to_string().as_bytes(),
        "Coast.json",
    );
    let id = made.unwrap().lorebook.id;
    scratch
        .db
        .with(|conn| conn.execute("update lorebooks set toml = ?2 where id = ?1", (id, toml)))
        .unwrap();
    id
}

/// A lorebook's file as it is kept, without its entries' history (`lore::files_of`).
pub fn file(scratch: &Scratch, id: i64) -> String {
    let kept: String = scratch
        .db
        .with(|conn| {
            conn.query_row("select toml from lorebooks where id = ?1", [id], |r| {
                r.get(0)
            })
        })
        .unwrap();
    lore::files_of(&kept).unwrap().swap_remove(0).1
}

/// A change that `set` fills in.
pub fn only(set: impl FnOnce(&mut EntryChange)) -> EntryChange {
    let mut change = EntryChange::default();
    set(&mut change);
    change
}

pub fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|item| item.to_string()).collect()
}

/// The editor's entries, by their references.
pub fn listed(scratch: &Scratch, id: i64) -> Vec<String> {
    let shown = lorebooks::editable(&scratch.db, scratch.user, id).unwrap();
    shown
        .entries
        .into_iter()
        .map(|entry| entry.reference)
        .collect()
}

/// An entry as the editor shows it.
pub fn shown(scratch: &Scratch, id: i64, reference: &str) -> EditEntry {
    let shown = lorebooks::editable(&scratch.db, scratch.user, id).unwrap();
    let mut entries = shown.entries.into_iter();
    entries.find(|entry| entry.reference == reference).unwrap()
}

/// Makes a change, and answers why it was refused.
pub fn refused(scratch: &Scratch, id: i64, reference: &str, change: &EntryChange) -> String {
    let made = lorebooks::change_entry(&scratch.db, scratch.user, id, reference, change);
    format!("{:#}", made.unwrap_err())
}

/// A chat with `bare` of the sample card, who brings no lorebook, that took the lorebook `id` along.
pub fn chat(scratch: &Scratch, id: i64) -> i64 {
    let card = super::import_whole(&scratch.db, scratch.user, &super::card_copy()).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "bare")],
        persona_id: None,
        greeting: 0,
    };
    let chat_id = chats::create(&scratch.db, scratch.user, &new).unwrap();
    chats::add_lorebook(&scratch.db, scratch.user, chat_id, id).unwrap();
    chat_id
}

/// The entries the chat's prompts are built with.
pub fn book(scratch: &Scratch, chat_id: i64) -> Vec<cw_prompt::LorebookEntry> {
    let inputs = chats::prompt_inputs(&scratch.db, scratch.user, chat_id, None).unwrap();
    inputs
        .character
        .lorebook
        .map_or(Vec::new(), |book| book.entries)
}

/// What the entry `lore.wreck` of `NOTED` reads as.
pub fn wreck() -> EditEntry {
    EditEntry {
        reference: "lore.wreck".into(),
        label: "The wreck".into(),
        name: "The wreck".into(),
        trigger: Trigger::Keyword,
        keywords: strings(&["wreck", "Asta"]),
        content: "The Asta sank here in 1911.".into(),
        enabled: true,
        at_depth: false,
        depth: 4,
        order: 0,
        secondary: strings(&["storm", "night"]),
        logic: SelectiveLogic::NotAny,
        probability: 100,
        scan_depth: 0,
        case_sensitive: false,
        whole_words: false,
    }
}

/// What the entry `lore.lamp` of `NOTED` reads as.
pub fn lamp() -> EditEntry {
    EditEntry {
        reference: "lore.lamp".into(),
        // Without a name it goes by its first keyword.
        label: "lamp".into(),
        name: String::new(),
        trigger: Trigger::Always,
        keywords: strings(&["lamp"]),
        content: "The lamp burns whale oil.".into(),
        enabled: false,
        at_depth: true,
        depth: 3,
        order: 40,
        // Its secondary keywords do not count, as nothing says `selective`: the editor shows none.
        secondary: Vec::new(),
        logic: SelectiveLogic::AndAny,
        probability: 30,
        scan_depth: 2,
        case_sensitive: true,
        whole_words: true,
    }
}

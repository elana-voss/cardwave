//! A lorebook that comes as a file of its own, converted to CCV4 the way a
//! card's embedded one is: one `lorebook` block with its `lore` blocks.
//!
//! Two forms are read. SillyTavern's world info: its `entries` are an object,
//! one entry under each number, and the settings go by SillyTavern's own names
//! (`key`, `keysecondary`, `order`, `disable`). And a card's `character_book`
//! saved by itself: its `entries` are a list, and the book may be wrapped as
//! `{"spec": "lorebook_v3", "data": …}`.

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use serde_json::Value as Json;

use crate::sillytavern::{Card, Object, flag, slug_or, string, strings};

/// A lorebook file as CCV4.
pub struct Lorebook {
    /// The one TOML file it consists of.
    pub toml: String,
    /// What the file calls the lorebook; empty when it does not say.
    pub name: String,
    /// What was not taken over as it came.
    pub notes: Vec<crate::ImportNote>,
}

/// What a world-info entry calls its settings, with the names a card's
/// lorebook has for them.
const NAMES: [(&str, &str); 8] = [
    ("scanDepth", "scan_depth"),
    ("key", "keys"),
    ("keysecondary", "secondary_keys"),
    ("order", "insertion_order"),
    ("caseSensitive", "case_sensitive"),
    ("matchWholeWords", "match_whole_words"),
    ("ignoreBudget", "ignore_budget"),
    ("characterFilter", "character_filter"),
];
/// What the book says of itself. A world info made from a card keeps the
/// card's book as `originalData`, which says it where the file itself does not.
const ABOUT: [&str; 5] = [
    "name",
    "description",
    "scan_depth",
    "token_budget",
    "recursive_scanning",
];

/// Converts a lorebook file. Refused: a file that is not JSON, a card, and a file without entries.
pub fn convert(file: &[u8]) -> anyhow::Result<Lorebook> {
    let text = String::from_utf8_lossy(file);
    let root: Json = serde_json::from_str(text.trim_start_matches('\u{feff}')).context(
        Fail::said(Code::NotReadable, "the file is not valid JSON").with("what", "json"),
    )?;
    let book = match &root {
        Json::Object(root) => match root.get("data") {
            Some(Json::Object(data)) if data.contains_key("entries") => data,
            // A card may carry a lorebook, but is none.
            Some(_) if string(root.get("spec")).starts_with("chara_card") => {
                bail!(
                    Fail::said(
                        Code::NotReadable,
                        "the file is a character card, not a lorebook"
                    )
                    .with("what", "lorebook_not_card")
                )
            }
            _ => root,
        },
        _ => bail!(
            Fail::said(Code::NotReadable, "the file holds no lorebook").with("what", "lorebook")
        ),
    };
    let entries: Vec<Object> = match book.get("entries") {
        Some(Json::Array(entries)) => entries
            .iter()
            .filter_map(Json::as_object)
            .cloned()
            .collect(),
        Some(Json::Object(numbered)) => {
            // In the order of their numbers, not of the numbers as text.
            let mut entries: Vec<(i64, &Object)> = numbered
                .iter()
                .filter_map(|(number, entry)| {
                    Some((
                        number.trim().parse().unwrap_or(i64::MAX),
                        entry.as_object()?,
                    ))
                })
                .collect();
            entries.sort_by_key(|(number, _)| *number);
            entries
                .into_iter()
                .map(|(_, entry)| entry.clone())
                .collect()
        }
        _ => bail!(
            Fail::said(
                Code::NotReadable,
                "the file holds no lorebook: it has no entries"
            )
            .with("what", "lorebook")
        ),
    };

    let original = book.get("originalData").and_then(Json::as_object);
    let mut plain = Object::new();
    for key in ABOUT {
        let said = book
            .get(key)
            .filter(|value| !value.is_null())
            .or_else(|| original?.get(key));
        if let Some(value) = said {
            plain.insert(key.to_string(), value.clone());
        }
    }
    plain.insert(
        "entries".to_string(),
        entries
            .into_iter()
            .map(|entry| Json::Object(renamed(entry)))
            .collect(),
    );

    let name = string(plain.get("name"));
    let mut card = Card::default();
    card.root.insert("spec".to_string(), "ccv4:1.0.0".into());
    card.lorebook(&slug_or(&name, "lorebook"), &plain).context(
        Fail::said(Code::NotReadable, "the lorebook has no entries")
            .with("what", "lorebook_entries"),
    )?;
    Ok(Lorebook {
        toml: card.toml()?,
        name,
        notes: card.notes,
    })
}

/// A world-info entry under the names a card's lorebook has for its settings.
/// An entry that has those already stays as it is.
fn renamed(mut entry: Object) -> Object {
    for (theirs, ours) in NAMES {
        if let Some(value) = entry.remove(theirs)
            && entry.get(ours).is_none_or(Json::is_null)
        {
            entry.insert(ours.to_string(), value);
        }
    }
    if entry.get("enabled").is_none_or(Json::is_null)
        && let Some(off) = flag(entry.get("disable"))
    {
        entry.insert("enabled".to_string(), (!off).into());
    }
    if let Some(Json::Object(filter)) = entry.get_mut("character_filter")
        && let Some(exclude) = filter.remove("isExclude")
    {
        filter.entry("is_exclude").or_insert(exclude);
    }
    // In SillyTavern a key written as /pattern/flags is a regular expression,
    // with no setting that says so. Here the setting holds for all keys of an
    // entry, so the plain keys beside such a one are made patterns that match
    // just their text.
    if entry.get("use_regex").is_none_or(Json::is_null) {
        let lists = ["keys", "secondary_keys"];
        if lists
            .iter()
            .any(|list| strings(entry.get(*list)).iter().any(|key| is_pattern(key)))
        {
            for list in lists {
                let keys = strings(entry.get(list)).into_iter();
                let keys = keys.map(|key| {
                    if is_pattern(&key) {
                        key
                    } else {
                        fancy_regex::escape(&key).into_owned()
                    }
                });
                entry.insert(list.to_string(), keys.map(Json::String).collect());
            }
            entry.insert("use_regex".to_string(), true.into());
        }
    }
    entry
}

/// Whether a key has JavaScript's `/pattern/flags` form.
fn is_pattern(key: &str) -> bool {
    key.starts_with('/')
        && key.rfind('/').is_some_and(|end| {
            end > 1 && key[end + 1..].bytes().all(|flag| flag.is_ascii_lowercase())
        })
}

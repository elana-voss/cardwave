//! CCV4 cards, a pure crate above cw-core and cw-prompt that saves nothing: the
//! PNG container ([`png`]), the merged TOML document with its `TYPE.ID`
//! references (here), a character mapped onto the prompt builder's inputs
//! ([`mapping`]), its text as a person reads it ([`display`]), as an editor
//! changes it ([`edit`]) with its history ([`drafts`]), a library lorebook's
//! entries ([`lore`]), a card made from scratch ([`new`]), what went into making
//! it ([`creation`]) and SillyTavern's
//! cards converted ([`sillytavern`]). Spec: the `card_spec_v4` repository;
//! section numbers in comments refer to it.
//!
//! Two tags are one by `tag_key`, two modes by `same_mode`. A card's modes
//! (`Document::modes`, `meta-info.modes`) and a block's (`block_modes`, its
//! `modes`) are this app's, beyond the spec. What the modules that write a card
//! share is here: `slug_or` makes an ID of a name, `written_date` writes a
//! moment as a card does, and `ONE_FILE` is the one file of a card this app
//! writes whole.

pub mod creation;
pub mod display;
pub mod drafts;
pub mod edit;
pub mod languages;
pub mod lore;
pub mod mapping;
pub mod new;
mod note;
pub mod png;
pub mod sillytavern;

pub use note::ImportNote;

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use toml::{Table, Value};

/// Highest major version of the format this build reads.
const SUPPORTED_MAJOR: u64 = 1;
/// A character's `group-talkativeness` where its card gives none (the spec's default, and SillyTavern's).
pub(crate) const DEFAULT_TALKATIVENESS: f64 = 0.5;
/// Types that belong to the card's user and live in `user/` files (section 2.7).
const USER_TYPES: [&str; 4] = ["session", "user-state", "revision", "cardwave_creation"];
/// Authored types of the spec; they live in `card/` files.
const CARD_TYPES: [&str; 16] = [
    "name",
    "description",
    "personality",
    "wardrobe",
    "scenario",
    "greeting",
    "dialogue-example",
    "prompt",
    "creator-note",
    "lore",
    "lorebook",
    "character",
    "group",
    "persona",
    "llm",
    "meta-info",
];
const PLACEHOLDERS: [&str; 2] = ["CHAT-HISTORY", "LOREBOOK"];
/// The one TOML file of a card that this app writes whole: one converted from SillyTavern's format, and one made in the app.
const ONE_FILE: &str = "card/0001_card.toml";

/// All TOML files of one card merged into one document, with pinned revisions
/// already standing in for their live blocks (section 3.5).
#[derive(Clone, Debug)]
pub struct Document {
    root: Table,
    /// Elements found in the wrong kind of file.
    misplaced: Vec<ImportNote>,
}

/// Splits a `TYPE.ID` reference at its first dot; the ID may hold more dots.
fn split_reference(reference: &str) -> Option<(&str, &str)> {
    reference
        .split_once('.')
        .filter(|(kind, id)| !kind.is_empty() && !id.is_empty())
}

/// An all-uppercase word in a prompt template (`CHAT-HISTORY`, `LOREBOOK`).
pub(crate) fn is_placeholder(item: &str) -> bool {
    item.starts_with(|c: char| c.is_ascii_uppercase())
        && item.chars().all(|c| c.is_ascii_uppercase() || c == '-')
}

/// What makes two tags the same tag: their letters, whatever their case and
/// the space around them. A card keeps a tag as it is written.
pub fn tag_key(tag: &str) -> String {
    tag.trim().to_lowercase()
}

fn strings(value: Option<&Value>) -> Vec<&str> {
    match value {
        Some(Value::Array(items)) => items.iter().filter_map(Value::as_str).collect(),
        _ => Vec::new(),
    }
}

/// The longest ID `slug` makes.
const MAX_ID: usize = 40;

/// An ID as the spec likes it: lowercase ASCII letters, digits and dashes.
/// Empty when `text` has none of those.
fn slug(text: &str) -> String {
    let mut out = String::new();
    for c in text.chars() {
        if c.is_ascii_alphanumeric() {
            out.push(c.to_ascii_lowercase());
        } else if !matches!(c, '\'' | '’') && !out.is_empty() && !out.ends_with('-') {
            out.push('-');
        }
        if out.len() >= MAX_ID {
            break;
        }
    }
    out.trim_end_matches('-').to_string()
}

/// `slug` of `text`, or `fallback` where that is empty.
fn slug_or(text: &str, fallback: &str) -> String {
    Some(slug(text))
        .filter(|id| !id.is_empty())
        .unwrap_or_else(|| fallback.to_string())
}

/// `id`, or `id` with the first number from 2 on behind it that `taken` does
/// not say is in use: `x`, `x-2`, `x-3`.
fn free_id(id: &str, taken: impl Fn(&str) -> bool) -> String {
    let mut free = id.to_string();
    let mut number = 1;
    while taken(&free) {
        number += 1;
        free = format!("{id}-{number}");
    }
    free
}

/// Modes as they are kept: each once, whatever its case, without the space
/// around it, and none empty.
pub(crate) fn tidy_modes<'a>(modes: impl IntoIterator<Item = &'a str>) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    modes
        .into_iter()
        .map(str::trim)
        .filter(|mode| !mode.is_empty() && seen.insert(tag_key(mode)))
        .map(str::to_string)
        .collect()
}

/// Whether two modes are one: their letters, whatever their case.
pub fn same_mode(a: &str, b: &str) -> bool {
    tag_key(a) == tag_key(b)
}

/// A text on one line: its words with one space between them.
pub fn one_line(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// The moment `at`, in milliseconds since 1970, as a card writes a date.
fn written_date(at: i64) -> anyhow::Result<String> {
    let moment = chrono::DateTime::from_timestamp_millis(at)
        .context(Fail::said(Code::Internal, "the clock tells no time"))?;
    Ok(moment.format("%Y-%m-%dT%H:%M:%SZ").to_string())
}

/// A text as a text field holds it: with a field's line ends, and without the
/// space around it.
fn plain(text: &str) -> String {
    text.replace("\r\n", "\n")
        .replace('\r', "\n")
        .trim()
        .to_string()
}

impl Document {
    /// Merges the TOML files, given as (filename, text). Fails on broken TOML, on
    /// an element or key defined in two files, and on a missing or unsupported
    /// `spec` version.
    pub fn parse(files: &[(String, String)]) -> anyhow::Result<Self> {
        // Chunk order carries no meaning; sorting only makes the result repeatable.
        let mut files: Vec<&(String, String)> = files.iter().collect();
        files.sort_by(|a, b| a.0.cmp(&b.0));

        let mut root = Table::new();
        let mut misplaced = Vec::new();
        for (name, text) in files {
            let table: Table = toml::from_str(text).with_context(|| {
                Fail::said(Code::NotReadable, format!("{name} is not valid TOML"))
                    .with("what", "toml")
                    .with("name", name.to_string())
            })?;
            let is_user_file = name.starts_with("user/");
            for (key, value) in table {
                let belongs_to_user = USER_TYPES.contains(&key.as_str());
                if belongs_to_user != is_user_file
                    && (belongs_to_user || CARD_TYPES.contains(&key.as_str()))
                {
                    misplaced.push(ImportNote::Misplaced {
                        kind: key.clone(),
                        file: name.clone(),
                    });
                }
                match (root.get_mut(&key), value) {
                    (None, value) => {
                        root.insert(key, value);
                    }
                    (Some(Value::Table(existing)), Value::Table(added)) => {
                        for (id, element) in added {
                            if existing.contains_key(&id) {
                                bail!(
                                    Fail::said(
                                        Code::NotReadable,
                                        format!("{key}.{id} is defined in more than one file")
                                    )
                                    .with("what", "card_defined_twice")
                                    .with("key", key.to_string())
                                    .with("id", id.to_string())
                                );
                            }
                            existing.insert(id, element);
                        }
                    }
                    _ => bail!(
                        Fail::said(
                            Code::NotReadable,
                            format!("{key} is defined in more than one file")
                        )
                        .with("what", "card_defined_twice")
                        .with("key", key.to_string())
                    ),
                }
            }
        }

        let spec = root.get("spec").and_then(Value::as_str).context(
            Fail::said(Code::NotReadable, "the card has no spec version")
                .with("what", "spec_version"),
        )?;
        let major = spec
            .strip_prefix("ccv4:")
            .and_then(|version| {
                let parts: Vec<&str> = version.split('.').collect();
                let numbers: Option<Vec<u64>> = parts.iter().map(|p| p.parse().ok()).collect();
                numbers.filter(|n| n.len() == 3).map(|n| n[0])
            })
            .with_context(|| {
                Fail::said(
                    Code::NotReadable,
                    format!("the spec version {spec:?} is not of the form ccv4:1.0.0"),
                )
                .with("what", "spec_version_form")
            })?;
        if major > SUPPORTED_MAJOR {
            bail!(Fail::said(Code::NotReadable, format!("the card uses CCV4 version {major}; this build reads up to version {SUPPORTED_MAJOR}")).with("what", "ccv4_version").with("major", major.to_string()).with("supported_major", SUPPORTED_MAJOR));
        }

        let mut document = Self { root, misplaced };
        document.apply_pins();
        Ok(document)
    }

    /// Replaces each block that has a pinned draft by the newest pinned draft's
    /// payload, whole (section 3.3.4). A pin without a live block is ignored.
    fn apply_pins(&mut self) {
        let Some(Value::Table(revisions)) = self.root.get("revision") else {
            return;
        };
        let mut pinned = Vec::new();
        for (reference, revision) in revisions {
            if let (Some((_, draft)), Some((kind, id))) =
                (pinned_draft(revision), split_reference(reference))
            {
                pinned.push((kind.to_string(), id.to_string(), draft["payload"].clone()));
            }
        }
        for (kind, id, payload) in pinned {
            if let Some(Value::Table(elements)) = self.root.get_mut(&kind)
                && let Some(block) = elements.get_mut(&id)
            {
                *block = payload;
            }
        }
    }

    /// Which draft stands in for the block `reference`, or would if the card
    /// had that block, as its place among the block's drafts; none for a block
    /// that reads as it is written.
    pub(crate) fn pin(&self, reference: &str) -> Option<usize> {
        pinned_draft(self.root.get("revision")?.get(reference)?).map(|(at, _)| at)
    }

    /// Whether the card keeps a history of the block `reference`, which it may no longer have.
    pub(crate) fn has_revision(&self, reference: &str) -> bool {
        self.root
            .get("revision")
            .is_some_and(|all| all.get(reference).is_some())
    }

    pub fn element(&self, kind: &str, id: &str) -> Option<&Table> {
        self.root.get(kind)?.as_table()?.get(id)?.as_table()
    }

    /// Resolves a `TYPE.ID` reference.
    pub fn lookup(&self, reference: &str) -> Option<&Table> {
        let (kind, id) = split_reference(reference)?;
        self.element(kind, id)
    }

    /// The `text` of the block `reference` names.
    pub fn text(&self, reference: &str) -> Option<&str> {
        self.lookup(reference)?.get("text")?.as_str()
    }

    /// IDs of all elements of one type.
    pub fn ids(&self, kind: &str) -> Vec<&str> {
        match self.root.get(kind) {
            Some(Value::Table(elements)) => elements
                .iter()
                .filter(|(_, v)| v.is_table())
                .map(|(id, _)| id.as_str())
                .collect(),
            _ => Vec::new(),
        }
    }

    pub fn character(&self, id: &str) -> Option<&Table> {
        self.element("character", id)
    }

    /// The characters the card is used by: its first alone, as a card holds
    /// one character (the owner, 2026-10-18). A chat made before with another
    /// still finds it by its ID ([`Document::character`]).
    pub fn characters(&self) -> Vec<&str> {
        self.ids("character").into_iter().take(1).collect()
    }

    /// The lorebook `reference` as a document of its own, in TOML: its block
    /// and the entries it lists, as they read here, and nothing else of the
    /// card. `None` when there is no such lorebook.
    pub fn lorebook_alone(&self, reference: &str) -> Option<String> {
        let (_, id) = split_reference(reference).filter(|(kind, _)| *kind == "lorebook")?;
        let book = self.element("lorebook", id)?;
        let entries = strings(book.get("entries"))
            .into_iter()
            .filter_map(|entry| {
                let (_, id) = split_reference(entry).filter(|(kind, _)| *kind == "lore")?;
                Some((
                    id.to_string(),
                    Value::Table(self.element("lore", id)?.clone()),
                ))
            });
        let mut alone = Table::new();
        alone.insert("spec".to_string(), self.root.get("spec")?.clone());
        alone.insert("lore".to_string(), Value::Table(entries.collect()));
        alone.insert(
            "lorebook".to_string(),
            Value::Table(Table::from_iter([(
                id.to_string(),
                Value::Table(book.clone()),
            )])),
        );
        toml::to_string_pretty(&alone).ok()
    }

    /// The character's name in the chat, what `{{char}}` stands for; its ID when
    /// the card names none.
    pub fn character_name(&self, id: &str) -> String {
        self.character(id)
            .and_then(|c| c.get("name-char")?.as_str())
            .and_then(|reference| self.text(reference))
            .map(str::trim)
            .filter(|name| !name.is_empty())
            .unwrap_or(id)
            .to_string()
    }

    /// The character's label in lists; its ID when the card gives none.
    pub fn character_label(&self, id: &str) -> String {
        self.character(id)
            .and_then(|c| c.get("name-card")?.as_str())
            .map(str::trim)
            .filter(|label| !label.is_empty())
            .unwrap_or(id)
            .to_string()
    }

    /// How readily the character speaks up in a chat of several when nobody
    /// names it, from 0 to 1: its `group-talkativeness`, and
    /// [`DEFAULT_TALKATIVENESS`] where it gives none that is a number.
    pub fn talkativeness(&self, id: &str) -> f64 {
        self.character(id)
            .and_then(|c| c.get("group-talkativeness"))
            .and_then(|value| value.as_float().or(value.as_integer().map(|n| n as f64)))
            .filter(|n| n.is_finite())
            .map_or(DEFAULT_TALKATIVENESS, |n| n.clamp(0.0, 1.0))
    }

    /// The opening messages a chat with this character offers. A group chat
    /// uses the group greetings when the card has any.
    pub fn greetings(&self, id: &str, group: bool) -> Vec<String> {
        let Some(character) = self.character(id) else {
            return Vec::new();
        };
        let keys = if group {
            ["group-greetings", "greetings"]
        } else {
            ["greetings", "group-greetings"]
        };
        keys.iter()
            .map(|key| {
                strings(character.get(*key))
                    .into_iter()
                    .filter_map(|reference| self.text(reference))
                    .map(|text| text.trim().to_string())
                    .filter(|text| !text.is_empty())
                    .collect::<Vec<_>>()
            })
            .find(|greetings| !greetings.is_empty())
            .unwrap_or_default()
    }

    /// File name of the character's picture among the card's assets.
    pub fn avatar(&self, id: &str) -> Option<&str> {
        self.character(id)?
            .get("avatar")?
            .as_str()?
            .strip_prefix("asset://")
    }

    /// What the card's creator tells its users about this character.
    pub fn creator_note(&self, id: &str) -> Option<&str> {
        self.text(self.character(id)?.get("creator-note")?.as_str()?)
    }

    fn meta(&self, key: &str) -> Option<&Value> {
        self.root.get("meta-info")?.get(key)
    }

    /// Who made the card, if it says.
    pub fn creator(&self) -> Option<&str> {
        self.meta("creator")?
            .as_str()
            .map(str::trim)
            .filter(|creator| !creator.is_empty())
    }

    /// The card's modes, as it names them (`meta-info.modes`), each once
    /// whatever its case: the first is the one a chat begins in. None for a
    /// card without modes, whose every text is used always.
    pub fn modes(&self) -> Vec<String> {
        tidy_modes(strings(self.meta("modes")))
    }

    /// The mode of the card that `wanted` names, whatever its case; else the
    /// card's first. None for a card without modes.
    pub fn mode_or_first(&self, wanted: &[&str]) -> Option<String> {
        let modes = self.modes();
        wanted
            .iter()
            .find_map(|want| modes.iter().find(|mode| same_mode(mode, want)))
            .or(modes.first())
            .cloned()
    }

    /// The modes the block `reference` is used in (its `modes`); none where it
    /// is used in all.
    pub(crate) fn block_modes(&self, reference: &str) -> Vec<String> {
        let Some(block) = self.lookup(reference) else {
            return Vec::new();
        };
        strings(block.get("modes"))
            .into_iter()
            .map(str::trim)
            .filter(|mode| !mode.is_empty())
            .map(str::to_string)
            .collect()
    }

    pub fn tags(&self) -> Vec<String> {
        strings(self.meta("tags"))
            .into_iter()
            .map(str::to_string)
            .collect()
    }

    /// Title for the library: the card's own, else its first character's label,
    /// else none (empty), which the page words.
    pub fn title(&self) -> String {
        let own = self
            .meta("title")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|t| !t.is_empty());
        match (own, self.characters().first()) {
            (Some(title), _) => title.to_string(),
            (None, Some(id)) => self.character_label(id),
            (None, None) => String::new(),
        }
    }

    /// What a validator would flag but an import can live with: references that
    /// lead nowhere and elements in the wrong kind of file. `assets` are the
    /// card's asset file names.
    pub fn warnings(&self, assets: &[&str]) -> Vec<ImportNote> {
        let assets: std::collections::HashSet<&str> = assets.iter().copied().collect();
        let mut out = self.misplaced.clone();
        let mut dangling = Vec::new();
        let mut check = |owner: &str, key: &str, reference: &str, kind: Option<&str>| {
            let fits = split_reference(reference)
                .is_some_and(|(found, _)| kind.is_none_or(|k| k == found));
            if !fits || self.lookup(reference).is_none() {
                dangling.push(ImportNote::Dangling {
                    owner: owner.to_string(),
                    key: key.to_string(),
                    reference: reference.to_string(),
                });
            }
        };
        for id in self.ids("character") {
            let owner = format!("character.{id}");
            let character = &self.root["character"][id];
            if let Some(reference) = character.get("name-char").and_then(Value::as_str) {
                check(&owner, "name-char", reference, Some("name"));
            }
            if let Some(reference) = character.get("creator-note").and_then(Value::as_str) {
                check(&owner, "creator-note", reference, Some("creator-note"));
            }
            for (key, kind) in [
                ("greetings", "greeting"),
                ("group-greetings", "greeting"),
                ("lorebooks", "lorebook"),
            ] {
                for reference in strings(character.get(key)) {
                    check(&owner, key, reference, Some(kind));
                }
            }
            for item in strings(character.get("prompt")) {
                if !is_placeholder(item) {
                    check(&owner, "prompt", item, None);
                } else if !PLACEHOLDERS.contains(&item) {
                    out.push(ImportNote::UnknownPlaceholder {
                        owner: owner.clone(),
                        placeholder: item.to_string(),
                    });
                }
            }
        }
        for id in self.ids("lorebook") {
            for reference in strings(self.root["lorebook"][id].get("entries")) {
                check(
                    &format!("lorebook.{id}"),
                    "entries",
                    reference,
                    Some("lore"),
                );
            }
        }
        for id in self.ids("group") {
            let owner = format!("group.{id}");
            let group = &self.root["group"][id];
            if let Some(reference) = group.get("scenario").and_then(Value::as_str) {
                check(&owner, "scenario", reference, Some("scenario"));
            }
            for (key, kind) in [("characters", "character"), ("lorebooks", "lorebook")] {
                for reference in strings(group.get(key)) {
                    check(&owner, key, reference, Some(kind));
                }
            }
        }
        out.append(&mut dangling);
        // Assets may be referenced from any string of any element.
        for (kind, elements) in &self.root {
            let Value::Table(elements) = elements else {
                continue;
            };
            for (id, element) in elements {
                let Value::Table(element) = element else {
                    continue;
                };
                for (key, value) in element {
                    if let Some(file) = value.as_str().and_then(|s| s.strip_prefix("asset://"))
                        && !assets.contains(file)
                    {
                        out.push(ImportNote::MissingAsset {
                            owner: format!("{kind}.{id}"),
                            key: key.clone(),
                            file: file.to_string(),
                        });
                    }
                }
            }
        }
        out
    }
}

/// The draft of a `revision` that stands in for its block: the newest pinned
/// one that has a payload (section 3.3.4), with its place among the drafts.
fn pinned_draft(revision: &Value) -> Option<(usize, &Value)> {
    let Some(Value::Array(drafts)) = revision.get("drafts") else {
        return None;
    };
    let pinned = drafts.iter().enumerate().filter(|(_, draft)| {
        draft.get("pinned").and_then(Value::as_bool) == Some(true)
            && draft.get("payload").is_some_and(Value::is_table)
    });
    pinned.max_by_key(|(_, draft)| saved_at(draft.get("saved")))
}

/// Orders drafts by their `saved` stamp, in milliseconds. A stamp without a
/// time zone counts as UTC; anything unreadable sorts first.
fn saved_at(saved: Option<&Value>) -> i64 {
    let Some(Value::Datetime(stamp)) = saved else {
        return i64::MIN;
    };
    let text = stamp.to_string();
    if let Ok(exact) = chrono::DateTime::parse_from_rfc3339(&text) {
        return exact.timestamp_millis();
    }
    if let Ok(local) = chrono::NaiveDateTime::parse_from_str(&text, "%Y-%m-%dT%H:%M:%S%.f") {
        return local.and_utc().timestamp_millis();
    }
    chrono::NaiveDate::parse_from_str(&text, "%Y-%m-%d")
        .ok()
        .and_then(|date| date.and_hms_opt(0, 0, 0))
        .map_or(i64::MIN, |midnight| midnight.and_utc().timestamp_millis())
}

#[cfg(test)]
mod tests {
    use super::Document;

    #[test]
    fn a_card_without_a_title_or_a_character_has_none() {
        let document =
            Document::parse(&[("card.toml".into(), "spec = \"ccv4:1.0.0\"\n".into())]).unwrap();
        assert_eq!(
            document.title(),
            "",
            "the page words a card that names nothing"
        );
    }
}

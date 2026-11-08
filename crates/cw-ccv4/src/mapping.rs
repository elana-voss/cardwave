//! Maps one character of a CCV4 card onto the prompt builder's [`Character`].
//!
//! A CCV4 character is an ordered template of text blocks; the builder has
//! fixed sections in a fixed order. Each block goes to the section of its type,
//! and prompt text goes before or after the chat by where the template has it
//! relative to `CHAT-HISTORY`. The template's finer ordering is not kept.
//!
//! Which kinds of block make which of a character's texts (`description` and
//! `wardrobe` the description) is `SECTIONS`, for the prompt and for the
//! editor. A card with modes has a block that names modes (its `modes`) only
//! in those; [`character`] is the card in its first mode.

use std::collections::HashSet;

use cw_prompt::{
    Character, CharacterFilter, DEFAULT_DEPTH, DepthPrompt, Lorebook, LorebookEntry, Role,
    SelectiveLogic,
};
use toml::{Table, Value};

use crate::{Document, is_placeholder, same_mode, split_reference, strings};

/// A name from a card is shown up to this many characters.
const MAX_NAME: usize = 64;

/// A text of a character that the builder has a section for.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Section {
    Description,
    Personality,
    Scenario,
    Examples,
}

/// The kinds of block that make a section's text, in the order a prompt has
/// them. A section's first kind is what a new text of it is written as.
pub(crate) const SECTIONS: [(&str, Section); 5] = [
    ("description", Section::Description),
    // The builder has no section for outfits; they describe the character.
    ("wardrobe", Section::Description),
    ("personality", Section::Personality),
    ("scenario", Section::Scenario),
    ("dialogue-example", Section::Examples),
];

impl Section {
    /// The section a block of `kind` is part of; none for one that is no part of any.
    pub(crate) fn of(kind: &str) -> Option<Self> {
        SECTIONS
            .iter()
            .find(|(one, _)| *one == kind)
            .map(|(_, section)| *section)
    }

    /// The kind of block a new text of the section is written as.
    pub(crate) fn kind(self) -> &'static str {
        SECTIONS
            .iter()
            .find(|(_, section)| *section == self)
            .map_or("", |(kind, _)| kind)
    }
}

/// A lorebook a chat adds to those its character brings: one out of a document
/// that is not the character's card.
pub struct Added<'a> {
    /// Stands before an entry's reference in its ID, which tells the entry from
    /// those of the card and of any other lorebook added.
    pub key: String,
    pub document: &'a Document,
    /// The lorebook in that document, `lorebook.ID`.
    pub reference: &'a str,
    /// What of it the chat leaves out, as references.
    pub off: &'a HashSet<String>,
}

/// The builder's view of the character `id`, in the card's first mode, or
/// `None` when the card has no such character.
pub fn character(doc: &Document, id: &str) -> Option<Character> {
    character_in(doc, id, &HashSet::new(), &[], None)
}

/// [`character`] in a chat, which leaves out some of the card's lore (the
/// lorebooks and the entries whose references are in `off`) and may add
/// lorebooks of its own. Those reach the prompt whether or not the character's
/// template has a place for lorebooks: the user put them into the chat. In
/// the mode `mode`, or the card's first where it has no such mode.
pub fn character_in(
    doc: &Document,
    id: &str,
    off: &HashSet<String>,
    added: &[Added<'_>],
    mode: Option<&str>,
) -> Option<Character> {
    let card = doc.character(id)?;
    let mode = doc.mode_or_first(&mode.into_iter().collect::<Vec<_>>());
    let mut system = Vec::new();
    let mut post_history = Vec::new();
    let mut description = Vec::new();
    let mut personality = Vec::new();
    let mut scenario = Vec::new();
    let mut examples = Vec::new();
    let mut depth_prompts = Vec::new();
    let mut told_name = None;
    let mut after_history = false;

    let template: &[Value] = match card.get("prompt") {
        Some(Value::Array(items)) => items.as_slice(),
        _ => &[],
    };
    for item in template {
        let (kind, block) = match item {
            Value::String(word) if is_placeholder(word) => {
                after_history |= word == "CHAT-HISTORY";
                continue;
            }
            Value::String(reference) => {
                let Some(block) = doc.lookup(reference) else {
                    continue;
                };
                (
                    split_reference(reference).map_or("", |(kind, _)| kind),
                    block,
                )
            }
            // Inline prose counts as prompt text.
            Value::Table(inline) => ("prompt", inline),
            _ => continue,
        };
        let text = text_of(block);
        if text.is_empty() || !used_in(mode.as_deref(), block) {
            continue;
        }
        match kind {
            "prompt" => match uint(block, "depth") {
                Some(depth) => {
                    depth_prompts.push(DepthPrompt {
                        prompt: text.to_string(),
                        depth,
                        role: role_of(block),
                    });
                }
                None if after_history => post_history.push(text),
                None => system.push(text),
            },
            // The name the model is told is the builder's identity line.
            "name" => _ = told_name.get_or_insert(text),
            _ => match Section::of(kind) {
                Some(Section::Description) => description.push(text),
                Some(Section::Personality) => personality.push(text),
                Some(Section::Scenario) => scenario.push(text),
                Some(Section::Examples) => examples.push(text),
                // Greetings open the chat log. Creator notes and unknown types never reach the model.
                None => {}
            },
        }
    }

    // `name-char` is what {{char}} stands for; a card may tell the model another name.
    let chat_name = doc.character_name(id);
    let name = told_name.map_or_else(|| chat_name.clone(), str::to_string);
    Some(Character {
        nickname: (chat_name != name).then_some(chat_name),
        name,
        tags: doc.tags(),
        system_prompt: system.join("\n\n"),
        description: description.join("\n\n"),
        personality: personality.join("\n\n"),
        scenario: scenario.join("\n\n"),
        post_history_instructions: post_history.join("\n\n"),
        mes_example: examples.join("\n\n"),
        depth_prompts,
        lorebook: lore_in(doc, id, off, added),
    })
}

/// Whether a block is used in `mode`: one that names modes in those alone; in
/// a card without modes, always.
fn used_in(mode: Option<&str>, block: &Table) -> bool {
    match (mode, block.get("modes")) {
        (Some(mode), Some(Value::Array(modes))) if !modes.is_empty() => modes
            .iter()
            .filter_map(Value::as_str)
            .any(|one| same_mode(one, mode)),
        _ => true,
    }
}

/// The lore of the character `id` in a chat (as [`character_in`]): its own
/// lorebooks but what is `off`, and those `added`, merged into one.
fn lore_in(
    doc: &Document,
    id: &str,
    off: &HashSet<String>,
    added: &[Added<'_>],
) -> Option<Lorebook> {
    let mut lore = Merge::default();
    lore.add("", doc, &lorebooks(doc, id), off);
    for book in added {
        lore.add(&book.key, book.document, &[book.reference], book.off);
    }
    lore.finish()
}

/// The lorebooks that reach the prompt of the character `id`, as references:
/// those the character lists and the card has, if the character's template has
/// a place for them.
pub fn lorebooks<'a>(doc: &'a Document, id: &str) -> Vec<&'a str> {
    let Some(card) = doc.character(id) else {
        return Vec::new();
    };
    if !strings(card.get("prompt")).contains(&"LOREBOOK") {
        return Vec::new();
    }
    let mut listed = strings(card.get("lorebooks"));
    listed.retain(|reference| doc.lookup(reference).is_some());
    listed
}

/// What a lorebook or a lorebook entry is called where it is shown: its `name`,
/// else an entry's first keyword, else its ID.
pub fn lore_name(doc: &Document, reference: &str) -> String {
    let block = doc.lookup(reference);
    let own = block.and_then(|block| block.get("name")?.as_str());
    let keyword = block.and_then(|block| strings(block.get("keywords")).into_iter().next());
    let id = split_reference(reference).map_or(reference, |(_, id)| id);
    let name = [own, keyword]
        .into_iter()
        .flatten()
        .map(str::trim)
        .find(|name| !name.is_empty())
        .unwrap_or(id);
    name.chars().take(MAX_NAME).collect()
}

/// The entries of the lorebook `reference` that the card has, as references.
pub fn entries<'a>(doc: &'a Document, reference: &str) -> Vec<&'a str> {
    let mut listed = strings(doc.lookup(reference).and_then(|book| book.get("entries")));
    listed.retain(|entry| doc.lookup(entry).is_some());
    listed
}

/// Lorebooks on their way to being the one book the builder takes. Budgets add
/// up, and one book without a budget lifts the limit for all.
#[derive(Default)]
struct Merge {
    book: Lorebook,
    unlimited: bool,
}

impl Merge {
    /// Adds the lorebooks `references` of `doc`, without what is in `off`. An
    /// entry's ID in the chat's sticky and cooldown state is its reference
    /// behind `key`. A lorebook of which no entry is left counts for nothing:
    /// neither its budget nor its scan depth.
    fn add(&mut self, key: &str, doc: &Document, references: &[&str], off: &HashSet<String>) {
        let book = &mut self.book;
        let mut seen = HashSet::new();
        for reference in references {
            if off.contains(*reference) {
                continue;
            }
            let Some(source) = doc.lookup(reference) else {
                continue;
            };
            let entries: Vec<(&str, &Table)> = strings(source.get("entries"))
                .into_iter()
                .filter(|entry| !off.contains(*entry))
                .filter_map(|entry| Some((entry, doc.lookup(entry)?)))
                .collect();
            if entries.is_empty() {
                continue;
            }
            if let Some(depth) = uint(source, "scan-depth") {
                book.scan_depth = Some(book.scan_depth.map_or(depth, |d| d.max(depth)));
            }
            match uint(source, "token-budget") {
                Some(budget) if budget > 0 => {
                    book.token_budget = book.token_budget.saturating_add(budget)
                }
                _ => self.unlimited = true,
            }
            for (entry, lore) in entries {
                if seen.insert(entry) {
                    let id = format!("{key}{entry}");
                    book.entries.push(LorebookEntry {
                        name: lore_name(doc, entry),
                        ..lore_entry(id, lore)
                    });
                }
            }
        }
    }

    /// The one book, or none when no entry is left.
    fn finish(mut self) -> Option<Lorebook> {
        if self.unlimited {
            self.book.token_budget = 0;
        }
        (!self.book.entries.is_empty()).then_some(self.book)
    }
}

/// One `lore` block (section 3.3.2), under `id` in the chat's sticky and
/// cooldown state. Beyond the spec's keys it reads the ones the SillyTavern
/// import writes (see [`super::sillytavern`]). A lorebook's editor shows an
/// entry as this reads it (`lore.rs`).
pub(super) fn lore_entry(id: String, lore: &Table) -> LorebookEntry {
    let flag = |key: &str, default: bool| lore.get(key).and_then(Value::as_bool).unwrap_or(default);
    let keys = |key: &str| -> Vec<String> {
        strings(lore.get(key))
            .into_iter()
            .map(str::to_string)
            .collect()
    };
    let filter = lore
        .get("character-filter")
        .and_then(Value::as_table)
        .map(|filter| {
            let names = |key: &str| {
                strings(filter.get(key))
                    .into_iter()
                    .map(str::to_string)
                    .collect()
            };
            CharacterFilter {
                names: names("names"),
                tags: names("tags"),
                is_exclude: filter
                    .get("exclude")
                    .and_then(Value::as_bool)
                    .unwrap_or(false),
            }
        });
    LorebookEntry {
        id: Some(id),
        name: String::new(),
        keys: keys("keywords"),
        secondary_keys: keys("secondary-keywords"),
        content: text_of(lore).to_string(),
        enabled: flag("enabled", true),
        constant: lore.get("trigger").and_then(Value::as_str) == Some("always"),
        by_meaning: lore.get("trigger").and_then(Value::as_str) == Some("vector"),
        selective: flag("selective", false),
        selective_logic: match lore.get("selective-logic").and_then(Value::as_str) {
            Some("not-all") => SelectiveLogic::NotAll,
            Some("not-any") => SelectiveLogic::NotAny,
            Some("and-all") => SelectiveLogic::AndAll,
            _ => SelectiveLogic::AndAny,
        },
        use_regex: flag("use-regex", false),
        case_sensitive: flag("case-sensitive", false),
        match_whole_words: flag("match-whole-words", false),
        // An entry's own, where it has one; else its lorebook's counts.
        scan_depth: uint(lore, "scan-depth").filter(|depth| *depth > 0),
        character_filter: filter,
        priority: lore
            .get("priority")
            .and_then(Value::as_integer)
            .unwrap_or(0),
        insertion_order: lore
            .get("insertion-order")
            .and_then(Value::as_integer)
            .unwrap_or(0),
        // An entry with a depth goes into the chat, like a prompt block with one.
        at_depth: lore.contains_key("depth"),
        depth: uint(lore, "depth").unwrap_or(DEFAULT_DEPTH),
        role: role_of(lore),
        probability: uint(lore, "probability").map_or(100, |percent| percent.min(100) as u32),
        sticky: uint(lore, "sticky").unwrap_or(0),
        cooldown: uint(lore, "cooldown").unwrap_or(0),
        delay: uint(lore, "delay").unwrap_or(0),
        ignore_budget: flag("ignore-budget", false),
    }
}

/// Who a block that sits in the chat speaks as; the system unless it says otherwise.
fn role_of(block: &Table) -> Role {
    match block.get("role").and_then(Value::as_str) {
        Some("user") => Role::User,
        Some("assistant") => Role::Assistant,
        _ => Role::System,
    }
}

/// A block's text without the line breaks TOML's `"""` blocks leave around it.
fn text_of(block: &Table) -> &str {
    block
        .get("text")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
}

/// A count from the card, capped so that sums of them cannot overflow.
fn uint(table: &Table, key: &str) -> Option<usize> {
    const MAX: usize = 1_000_000_000;
    table
        .get(key)?
        .as_integer()
        .and_then(|n| usize::try_from(n).ok())
        .map(|n| n.min(MAX))
}

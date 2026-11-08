//! A card's texts as its editor shows them ([`CardEdit::of`]: as written, each
//! with its block and its modes), and an edit written back into the card's
//! files ([`apply`]) with the crate `toml_edit`. A file changes only where the
//! edit is: its comments, its order and every block the editor does not show
//! stay; a file the edit does not change stays to the letter, one it changes
//! ends its lines as Unix does and loses a byte-order mark. A text a pinned
//! draft stands in for (section 3.3.4) is written into that draft.
//!
//! Traps: a key is written through `set` and `set_list`, never `insert`, which
//! drops the comments around a line that is there; a table is asked for a key
//! with `find`, as asking an `Item` puts the key there. Comments between the
//! items of a changed list are lost. The three serve the lorebook's editor too
//! (`lore.rs`). A talkativeness is written into the character only once it is
//! changed; a text may only be in modes the card has, and no modes is no key.
//! Parts: `card` (the files open for an edit), `apply`, `first` ([`first_only`]).
//! A card's other languages are `super::languages`: `of` shows one by its code.

use std::collections::HashSet;

use cw_core::languages::Language;
use serde::{Deserialize, Serialize};
use toml_edit::{Array, Item, TableLike, Value};
use ts_rs::TS;

use crate::mapping::Section;
use crate::{Document, is_placeholder, plain, same_mode, split_reference, strings, tag_key};

mod apply;
mod card;
mod first;

pub use apply::*;
use card::*;
pub use first::*;

/// One text of a card as it is written, macros and all.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct EditText {
    /// The block it stands in, `TYPE.ID`. Without one, it is a text the card
    /// has no block for yet: an edit that gives it words makes the block.
    pub reference: Option<String>,
    pub text: String,
    /// The card's modes it is used in; none where it is used in all. Each
    /// has to be a mode of the card.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    #[ts(as = "Option<Vec<String>>", optional)]
    pub modes: Vec<String>,
}

/// A prompt block that stands at a depth in the chat (section 3.3.1): put
/// into it that many messages before its end. Its depth is not changed by an edit.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct DepthText {
    #[serde(flatten)]
    #[ts(flatten)]
    pub part: EditText,
    pub depth: u64,
}

/// One character of a card, as its editor shows it.
#[derive(Clone, Debug, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct EditCharacter {
    /// Its ID in the card.
    pub id: String,
    /// The name it has in lists. An edit does not change it, unless it was the
    /// character's name: then it follows the name.
    pub label: String,
    /// The name it has in a chat.
    pub name: String,
    /// The block the name stands in, where it has one. Characters that name
    /// the same block have one name. An edit does not change which it is.
    pub name_block: Option<String>,
    /// The messages a chat with it can open with, in their order. An edit
    /// gives all of them: one it leaves out, or leaves empty, is taken off.
    pub greetings: Vec<EditText>,
    /// Those it opens a chat of several with, where it has any, in place of
    /// the others; an edit gives them as it gives the greetings.
    pub group_greetings: Vec<EditText>,
    /// The texts below stand in the character's prompt, in its order. A card
    /// mostly has one of each; an outfit counts as a description.
    pub description: Vec<EditText>,
    pub personality: Vec<EditText>,
    pub scenario: Vec<EditText>,
    pub example_dialogue: Vec<EditText>,
    /// Its prompt blocks: those before the chat, those after it, and those at
    /// a depth in it, which an edit cannot add.
    pub system_prompt: Vec<EditText>,
    pub post_history: Vec<EditText>,
    pub depth_prompts: Vec<DepthText>,
    /// What the card's creator tells its users; never sent to a model.
    pub creator_notes: String,
    /// How readily it replies where a chat of several has one reply by
    /// chance, from 0 to 1, as it counts ([`Document::talkativeness`]): the
    /// card's `group-talkativeness` within 0 and 1, and 0.5 where the card
    /// gives none. An edit writes it into the character where it differs
    /// from that, 0.5 too; one beyond 0 and 1 is refused.
    pub talkativeness: f64,
}

/// What a card's editor shows of it, and what it saves.
#[derive(Clone, Debug, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct CardEdit {
    /// The number of the version these texts are of. An edit of another than
    /// the card's newest is refused.
    pub version: i64,
    /// What the library calls the card.
    pub title: String,
    pub tags: Vec<String>,
    /// Who made the card; empty when it does not say.
    pub creator: String,
    /// The card's modes, the first the one a chat begins in; none for a card
    /// whose every text is used always.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    #[ts(as = "Option<Vec<String>>", optional)]
    pub modes: Vec<String>,
    /// An edit changes the characters it names and leaves the others as they are.
    pub characters: Vec<EditCharacter>,
    /// The card's languages, its first language first (`languages::shown`).
    /// Not read from an edit.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    #[ts(as = "Option<Vec<Language>>", optional)]
    pub languages: Vec<Language>,
    /// The language of the characters shown, where it is not the card's first.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    #[ts(optional)]
    pub language: Option<String>,
}

/// Tags as they are kept: each once, whatever its case, without the space
/// around it, and none with a comma in it, which is what parts them in a field.
fn tidy(tags: &[String]) -> Vec<String> {
    let mut seen = HashSet::new();
    let parts = tags.iter().flat_map(|tag| tag.split(',')).map(str::trim);
    parts
        .filter(|tag| !tag.is_empty() && seen.insert(tag_key(tag)))
        .map(str::to_string)
        .collect()
}

/// The text of the block `reference`, as a field holds it.
fn text_of(document: &Document, reference: &str) -> Option<String> {
    Some(plain(
        document
            .lookup(reference)?
            .get("text")
            .and_then(toml::Value::as_str)
            .unwrap_or(""),
    ))
}

/// Gives the key `key` of `table` the value `new`. A key that is there keeps
/// its line as it is written around the value: the comments over it and
/// behind it.
pub(super) fn set(table: &mut dyn TableLike, key: &str, new: impl Into<Value>) {
    let mut new = new.into();
    match table.get_mut(key).and_then(Item::as_value_mut) {
        Some(old) => {
            *new.decor_mut() = old.decor().clone();
            *old = new;
        }
        None => _ = table.insert(key, Item::Value(new)),
    }
}

/// How a list begins each of its items where they stand on lines of their own:
/// the line end and what the line is indented by. None for a list on one line.
fn line_of(list: &Array) -> Option<String> {
    list.iter().find_map(|item| {
        let (_, indent) = item.decor().prefix()?.as_str()?.rsplit_once('\n')?;
        Some(format!("\n{indent}"))
    })
}

/// Gives the key `key` of `table` the list `items`, written as the list there
/// is: each item on a line of its own where they were, and ended as it was.
pub(super) fn set_list(table: &mut dyn TableLike, key: &str, items: &[String]) {
    let mut new = Array::from_iter(items);
    if let Some(old) = table.get(key).and_then(Item::as_array)
        && let Some(line) = line_of(old)
        && !items.is_empty()
    {
        for item in new.iter_mut() {
            item.decor_mut().set_prefix(line.as_str());
        }
        new.set_trailing(old.trailing().clone());
        new.set_trailing_comma(old.trailing_comma());
    }
    set(table, key, new);
}

/// The blocks among `references` that are part of `section` (all of them
/// without one), each once, with their texts.
fn blocks(document: &Document, references: &[&str], section: Option<Section>) -> Vec<EditText> {
    let mut seen = HashSet::new();
    let fits = |reference: &&str| {
        section.is_none_or(|section| {
            split_reference(reference).is_some_and(|(kind, _)| Section::of(kind) == Some(section))
        })
    };
    let once = references
        .iter()
        .copied()
        .filter(fits)
        .filter(|reference| seen.insert(*reference));
    once.filter_map(|reference| {
        Some(EditText {
            reference: Some(reference.to_string()),
            text: text_of(document, reference)?,
            // A block's modes that are not the card's (a card written by hand) are not shown, nor kept.
            modes: document
                .block_modes(reference)
                .into_iter()
                .filter(|mode| document.modes().iter().any(|one| same_mode(one, mode)))
                .collect(),
        })
    })
    .collect()
}

/// A text of the character's prompt: its blocks that have words. Where none
/// has, the first of them, to be given words, or else a text without a block.
fn field(document: &Document, template: &[&str], section: Section) -> Vec<EditText> {
    written_or_one(blocks(document, template, Some(section)))
}

/// Of `parts`, those with words; where none has, the first, or else a text without a block.
fn written_or_one(parts: Vec<EditText>) -> Vec<EditText> {
    let (written, mut empty): (Vec<_>, Vec<_>) =
        parts.into_iter().partition(|part| !part.text.is_empty());
    if !written.is_empty() {
        return written;
    }
    empty.truncate(1);
    if empty.is_empty() {
        empty.push(EditText {
            reference: None,
            text: String::new(),
            modes: Vec::new(),
        });
    }
    empty
}

/// The prompt blocks of a character's `template`, as the prompt has them: those
/// before the chat, those after it, and those at a depth (with words only).
fn prompts(
    document: &Document,
    template: &[&str],
) -> (Vec<EditText>, Vec<EditText>, Vec<DepthText>) {
    let (mut before, mut after, mut deep) = (Vec::new(), Vec::new(), Vec::new());
    let mut past_chat = false;
    for item in template {
        past_chat |= *item == "CHAT-HISTORY";
        let Some(block) = document.lookup(item) else {
            continue;
        };
        if is_placeholder(item) || split_reference(item).map(|(kind, _)| kind) != Some("prompt") {
            continue;
        }
        match block.get("depth").and_then(toml::Value::as_integer) {
            Some(depth) if depth >= 0 => deep.push((*item, depth as u64)),
            _ if past_chat => after.push(*item),
            _ => before.push(*item),
        }
    }
    let depth_prompts = deep
        .into_iter()
        .filter_map(|(reference, depth)| {
            let part = blocks(document, &[reference], None).pop()?;
            (!part.text.is_empty()).then_some(DepthText { part, depth })
        })
        .collect();
    (
        written_or_one(blocks(document, &before, None)),
        written_or_one(blocks(document, &after, None)),
        depth_prompts,
    )
}

/// The block that the key `key` of the character `id` names; none where it names none the card has.
fn named<'a>(document: &'a Document, id: &str, key: &str) -> Option<&'a str> {
    let reference = document.character(id)?.get(key)?.as_str()?;
    document.lookup(reference).map(|_| reference)
}

/// The character `id` as the editor shows it; none when the card has no such character.
fn character(document: &Document, id: &str) -> Option<EditCharacter> {
    let block = document.character(id)?;
    let template = strings(block.get("prompt"));
    let greetings = |key: &str| {
        let mut all = blocks(document, &strings(block.get(key)), None);
        all.retain(|greeting| !greeting.text.is_empty());
        all
    };
    let (system_prompt, post_history, depth_prompts) = prompts(document, &template);
    Some(EditCharacter {
        id: id.to_string(),
        label: document.character_label(id),
        name: plain(&document.character_name(id)),
        name_block: named(document, id, "name-char").map(str::to_string),
        greetings: greetings("greetings"),
        group_greetings: greetings("group-greetings"),
        description: field(document, &template, Section::Description),
        personality: field(document, &template, Section::Personality),
        scenario: field(document, &template, Section::Scenario),
        example_dialogue: field(document, &template, Section::Examples),
        system_prompt,
        post_history,
        depth_prompts,
        creator_notes: plain(document.creator_note(id).unwrap_or("")),
        talkativeness: document.talkativeness(id),
    })
}

impl CardEdit {
    /// What the editor shows of `document`, the version `version` of the card
    /// the library calls `title`, in `language` where the card has it (else in
    /// its first). Unlike the card's page it shows the texts as they are
    /// written, and the tags in full.
    pub fn of(document: &Document, version: i64, title: &str, language: Option<&str>) -> Self {
        let languages = crate::languages::shown(document);
        let shown = |id: &str| match language {
            Some(language) => document.in_language(id, language).to_string(),
            None => id.to_string(),
        };
        let characters: Vec<String> = document.characters().into_iter().map(shown).collect();
        let language = characters
            .first()
            .and_then(|id| document.character_language(id))
            .filter(|_| {
                document.characters().first().copied() != characters.first().map(String::as_str)
            });
        Self {
            version,
            title: title.to_string(),
            tags: tidy(&document.tags()),
            creator: document.creator().unwrap_or("").to_string(),
            modes: document.modes(),
            characters: characters
                .iter()
                .filter_map(|id| character(document, id))
                .collect(),
            languages,
            language,
        }
    }
}

/// What stands under `keys` in a file, each inside the one before, to be
/// changed there. Asked of the tables: asking an item itself for a key that is
/// not there would put it there.
pub(super) fn find<'a>(item: &'a mut Item, keys: &[&str]) -> Option<&'a mut Item> {
    keys.iter()
        .try_fold(item, |item, key| item.as_table_like_mut()?.get_mut(key))
}

/// The one among `texts` that stands in the block `reference`.
fn of_block<'a>(texts: &'a [EditText], reference: &str) -> Option<&'a EditText> {
    texts
        .iter()
        .find(|one| one.reference.as_deref() == Some(reference))
}

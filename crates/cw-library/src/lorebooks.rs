//! Lorebooks of the user's own: library items beside the cards and the
//! personas. One comes from a file (see [`world`]), is copied or moved out of
//! a card that brings it (`own.rs`), or is made from scratch without entries
//! (`create`), and is kept as a CCV4 document with one `lorebook` block and
//! its `lore` blocks, the form a card's lorebook has, with its entries'
//! history (`lore::files_of`). Its editor, which edits a card's own the same
//! way, is `edit.rs`. The library lists the cards' own too (`find`). What Search
//! Cardwave finds of a lorebook, its name and each entry, is written with it
//! (`texts`, `card_texts`; `find.rs`).
//!
//! A card's lorebooks are `of_card`, `attach`, `detach`, and `copy_from_card`;
//! over HTTP they are under `/api/cards/{id}/lorebooks` (`api/cards.rs`).
//! Which chats have which lorebook, taken along, attached to a card of their
//! characters, given to their persona (`personas::set_lorebooks`) or for every
//! chat (`set_everywhere`), is `cw_store::lorebooks::HAD`. What a chat left out of one
//! (`chat_lorebook_off`) is taken away once the chat has it neither way, and
//! stays while an entry is taken out, so the entry put back is left out as
//! before; no new entry is given the ID of one a chat has left out
//! (`left_out`). In a prompt a library lorebook's entries have the ID
//! `.<lorebook's number>.<reference>` (`key`; `entry_of` reads it back), a
//! card's entries their reference alone.

use std::collections::HashSet;

use anyhow::{Context, ensure};
use cw_ccv4::lore::{self, EditEntry, parse};
use cw_ccv4::sillytavern::world;
use cw_ccv4::{Document, mapping, one_line};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use serde::Serialize;
use ts_rs::TS;

use crate::cards::{self, Show, name_order};
use crate::trash;

mod edit;
mod own;

pub use edit::*;
pub use own::*;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Lorebook {
    pub id: i64,
    pub name: String,
    /// The start of what the lorebook says of itself; often nothing.
    pub description: String,
    /// How many entries it has.
    pub entries: u32,
    /// What its first entries are called.
    pub entry_names: Vec<String>,
    pub favorite: bool,
    pub archived: bool,
    pub trashed: bool,
    /// Every chat with a character has it, as if attached to its card.
    pub everywhere: bool,
    /// Of the library's, who use it: the titles of the cards it is attached to (empty: untitled), then the
    /// names of the personas given it, none in the Trash; empty of a card's own.
    pub used_by: Vec<String>,
    /// Of the library's, how many chats outside the Trash took it along themselves.
    pub chats: u32,
    /// Of a lorebook a card brings itself, listed with the library's: the
    /// card. Its `id` is then the card's.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[ts(optional)]
    pub card: Option<OwnedBy>,
}

/// The card a lorebook it brings itself is of.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct OwnedBy {
    pub card_id: i64,
    /// The card's title.
    pub title: String,
    /// The lorebook in the card, `lorebook.ID`.
    pub reference: String,
    /// Whether it is the card's first, which its address names without the reference.
    pub first: bool,
}

#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct ImportedLorebook {
    pub lorebook: Lorebook,
    /// What the import did not take over as it came.
    pub warnings: Vec<cw_ccv4::ImportNote>,
}

/// Where a card has a lorebook from.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum CardLoreSource {
    /// The card brings it itself: what the card calls it, `lorebook.ID`.
    Reference(String),
    /// It is a lorebook of the library, attached to the card.
    LorebookId(i64),
}

/// One lorebook of a card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct CardLorebook {
    #[serde(flatten)]
    #[ts(flatten)]
    pub source: CardLoreSource,
    pub name: String,
    /// How many entries it has. One the card brings without any cannot be
    /// copied into the library.
    pub entries: u32,
    /// A lorebook of the library that is in the Trash: the card has it until
    /// it is deleted for good.
    pub trashed: bool,
}

/// A lorebook of the library as a chat has it.
pub struct Taken {
    pub id: i64,
    pub name: String,
    pub trashed: bool,
    pub document: Document,
    /// The lorebook in that document, `lorebook.ID`.
    pub reference: String,
    /// The chat took it along itself, and can let it go. Otherwise it has it
    /// through a card of its characters alone.
    pub by_chat: bool,
    /// It is a lorebook for every chat, taken off in its own settings.
    pub everywhere: bool,
    /// The chat has it from its persona, which it is taken off in.
    pub persona: bool,
}

/// A lorebook as its editor shows it. Its `id` is the library lorebook's.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct LorebookEdit {
    pub id: i64,
    pub name: String,
    /// What it says of itself, in full.
    pub description: String,
    /// How many of the newest messages are read for its keywords, where it says.
    pub scan_depth: Option<u32>,
    /// The tokens its entries may take of a prompt, where it says.
    pub token_budget: Option<u32>,
    pub favorite: bool,
    pub archived: bool,
    /// See [`Lorebook::everywhere`]; a card's own never is.
    pub everywhere: bool,
    pub entries: Vec<EditEntry>,
    /// What a new entry begins with.
    pub blank: EditEntry,
    /// Of a card's own lorebook, the card; `id` is then the card's.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[ts(optional)]
    pub card: Option<OwnedBy>,
}

/// What a lorebook is called when neither it nor its file has a name.
const UNNAMED: &str = "Lorebook";
/// How many letters of a lorebook's name are kept, and of its description for the list.
const MAX_NAME: usize = 64;
const MAX_DESCRIPTION: usize = 1000;
/// Of how many entries the list keeps the names. A lorebook can have any number.
const MAX_LISTED: usize = 64;

/// What the library's list keeps of a lorebook beside its name (`listed`).
pub struct Listed {
    /// How many entries it has.
    pub entries: i64,
    /// What the first of them are called, as a JSON list.
    pub entry_names: String,
    /// The start of what it says of itself.
    pub about: String,
    /// It and its entries as Search Cardwave keeps them.
    pub texts: Vec<cw_search::kept::Text>,
}

/// What the lorebooks need of the database, which `cw_store::lorebooks` gives.
pub trait Storage: crate::cards::Storage + cw_search::kept::Storage {
    fn add_lorebook(
        &self,
        user: i64,
        name: &str,
        toml: &str,
        listed: &Listed,
    ) -> anyhow::Result<i64>;
    /// A lorebook of `user`, wherever it is.
    fn lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<Option<Lorebook>>;
    /// Those not in the Trash, as `show` has them.
    fn lorebooks(&self, user: i64, show: Show, searching: bool) -> anyhow::Result<Vec<Lorebook>>;
    fn kept_lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<Option<KeptLorebook>>;
    /// The references chats have left out of it.
    fn left_out_entries(&self, lorebook_id: i64) -> anyhow::Result<HashSet<String>>;
    /// Writes its document `toml` in place of `was`, where that is still its
    /// own: whether it did.
    fn write_lorebook(
        &self,
        lorebook_id: i64,
        was: &str,
        toml: &str,
        listed: &Listed,
        name: Option<&str>,
    ) -> anyhow::Result<bool>;
    /// Calls it `name`, where that is given: whether it is there.
    fn rename_lorebook(&self, lorebook_id: i64, name: Option<&str>) -> anyhow::Result<bool>;
    fn set_lorebook_favorite(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()>;
    fn set_lorebook_archived(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()>;
    /// Those of the library attached to a card, in the order they were.
    fn attached_lorebooks(&self, card_id: i64) -> anyhow::Result<Vec<CardLorebook>>;
    fn attach_lorebook(&self, card_id: i64, lorebook_id: i64) -> anyhow::Result<()>;
    /// Makes it one for every chat, from now, or no longer, forgetting what
    /// chats left out of it where they no longer have it.
    fn set_lorebook_everywhere(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()>;
    /// How many cards and personas it is attached to and chats took it, and
    /// one more where it is for every chat.
    fn lorebook_uses(&self, lorebook_id: i64) -> anyhow::Result<i64>;
    /// Detaches it from the card, forgetting what chats left out of it where
    /// they no longer have it: whether the card had it.
    fn detach_lorebook(&self, card_id: i64, lorebook_id: i64) -> anyhow::Result<bool>;
    /// Lets the chat's own lorebook go, as `detach_lorebook` does a card's.
    fn drop_chat_lorebook(&self, chat_id: i64, lorebook_id: i64) -> anyhow::Result<bool>;
    /// Those a chat has, as `of_chat`.
    fn chat_lorebooks(&self, chat_id: i64) -> anyhow::Result<Vec<ChatLorebookRow>>;
}

/// A lorebook as `Storage::kept_lorebook` reads it.
pub struct KeptLorebook {
    pub name: String,
    /// Its document.
    pub toml: String,
    /// Whether it is in the Trash.
    pub trashed: bool,
    /// When it came into the library.
    pub created_at: i64,
}

/// A lorebook a chat has, as `Storage::chat_lorebooks` reads it.
pub struct ChatLorebookRow {
    pub id: i64,
    pub name: String,
    /// Whether it is in the Trash.
    pub trashed: bool,
    /// Its document.
    pub toml: String,
    /// Whether the chat took it along itself.
    pub by_chat: bool,
    /// Whether it is a lorebook for every chat.
    pub everywhere: bool,
    /// Whether the chat has it from its persona.
    pub persona: bool,
}

/// What the library's list keeps of the lorebook `reference` of `document`,
/// beside its name: how many entries it has, what the first of them are
/// called, and the start of what it says of itself.
fn listed(document: &Document, reference: &str) -> Listed {
    let entries = mapping::entries(document, reference);
    let names: Vec<String> = entries
        .iter()
        .take(MAX_LISTED)
        .map(|entry| mapping::lore_name(document, entry))
        .collect();
    let about = document
        .lookup(reference)
        .and_then(|book| book.get("description")?.as_str())
        .unwrap_or("");
    Listed {
        entries: entries.len() as i64,
        entry_names: serde_json::json!(names).to_string(),
        about: about.chars().take(MAX_DESCRIPTION).collect(),
        texts: texts(document, reference, ""),
    }
}

/// The lorebook `reference` of `document` and each of its entries as Search Cardwave keeps them (`search::kept::Text`),
/// `book` naming it in its card.
fn texts(document: &Document, reference: &str, book: &str) -> Vec<cw_search::kept::Text> {
    let name = mapping::lore_name(document, reference);
    let mut texts = vec![cw_search::kept::Text {
        book: book.to_string(),
        title: name.clone(),
        text: lore::description(document, reference),
        ..Default::default()
    }];
    texts.extend(lore::entries(document, reference).into_iter().map(|entry| {
        cw_search::kept::Text {
            book: book.to_string(),
            entry: entry.reference,
            title: entry.label,
            within: name.clone(),
            keys: entry.keywords.join(", "),
            text: entry.content,
            ..Default::default()
        }
    }));
    texts
}

/// Writes the library's lorebook `id` anew as Search Cardwave keeps it (`find::index_missing`).
pub fn index(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    use cw_search::kept::Owner;
    let Some(kept) = db.kept_lorebook(user, id)? else {
        return Ok(());
    };
    let document = parse(&kept.toml)?;
    let reference = lore::book(&document).context(
        Fail::said(Code::NotReadable, "the file holds no lorebook").with("what", "lorebook"),
    )?;
    db.put_texts(user, Owner::Lorebook(id), &texts(&document, &reference, ""))
}

/// The lorebooks a card's document brings and their entries, as Search Cardwave keeps them: the first named
/// without its reference, as its address names it.
pub(crate) fn card_texts(document: &Document) -> Vec<cw_search::kept::Text> {
    brought_by(document)
        .into_iter()
        .enumerate()
        .flat_map(|(at, reference)| {
            texts(document, reference, if at == 0 { "" } else { reference })
        })
        .collect()
}

/// What stands before an entry's reference in its ID in a chat, when the entry
/// is of the lorebook `id`. No reference into a card starts with a dot, so
/// such an ID is never an entry of the chat's cards.
pub fn key(id: i64) -> String {
    format!(".{id}.")
}

/// What an entry's ID in a chat names when it is of one of the lorebooks
/// `library`: that lorebook and the entry's reference in it. `None` for an
/// entry of a card.
pub fn entry_of<'a>(id: &'a str, library: &[i64]) -> Option<(i64, &'a str)> {
    library
        .iter()
        .find_map(|&book| Some((book, id.strip_prefix(&key(book))?)))
}

/// A text on one line, its first `most` letters.
fn short(text: &str, most: usize) -> String {
    one_line(text).chars().take(most).collect()
}

/// Imports a lorebook file (SillyTavern world info, or a card's lorebook saved
/// by itself) as a new lorebook of `user`. It is called what the file says, or
/// else as the file itself is called (`file_name`).
pub fn import(
    db: &dyn Storage,
    user: i64,
    file: &[u8],
    file_name: &str,
) -> anyhow::Result<ImportedLorebook> {
    let converted = world::convert(file)?;
    // The file's name without its folders and its ending.
    let file_name = file_name.rsplit(['/', '\\']).next().unwrap_or("");
    let stem = file_name
        .rsplit_once('.')
        .map_or(file_name, |(stem, _)| stem);
    let lorebook = add(db, user, &converted.toml, [&converted.name, stem])?;
    Ok(ImportedLorebook {
        lorebook,
        warnings: converted.notes,
    })
}

/// The page's words a lorebook copied from a card is named with, in the
/// user's language: the word for a copy.
#[derive(Clone, Copy)]
pub struct Words<'a> {
    pub copy: &'a str,
}

/// Copies a lorebook that a card brings into the library, as a lorebook of
/// its own with the entries as the card's newest version has them. It is
/// called what the card calls it, or else as the card itself is called (a card
/// that brings a lorebook has a character, so a title); where the library has
/// a lorebook so called, as a copy is (`cw_core::copy_name`, with the word
/// `words.copy`). The card keeps its own.
pub fn copy_from_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    reference: &str,
    words: Words,
) -> anyhow::Result<Lorebook> {
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    let document = cards::document_of(db, card.version_id)?;
    ensure!(
        brought_by(&document).contains(&reference),
        Fail::said(Code::NotPossible, "the card brings no such lorebook")
            .with("what", "card_lorebook")
    );
    let toml = document.lorebook_alone(reference).context(
        Fail::said(Code::NotPossible, "the card brings no such lorebook")
            .with("what", "card_lorebook"),
    )?;
    let entries = mapping::entries(&document, reference).len();
    ensure!(
        entries > 0,
        Fail::said(Code::NotReadable, "the lorebook has no entries")
            .with("what", "lorebook_entries")
    );
    let name = document
        .lookup(reference)
        .and_then(|book| book.get("name")?.as_str())
        .unwrap_or("");
    let name = if name.trim().is_empty() {
        card.title.as_str()
    } else {
        name
    };
    // A copy is told from a lorebook of the library called so already.
    let lorebooks = db.lorebooks(user, Show::All, true)?;
    let taken = |made: &str| lorebooks.iter().any(|lorebook| lorebook.name == made);
    let name = if taken(&short(name, MAX_NAME)) {
        cw_core::copy_name(words.copy, &one_line(name), MAX_NAME, taken)
    } else {
        name.to_string()
    };
    add(db, user, &toml, [&name, &card.title])
}

/// Makes a lorebook of `user` from scratch, without entries, called `name`
/// (on one line) and saying `description` of itself. Its entries are added in
/// its editor.
pub fn create(
    db: &dyn Storage,
    user: i64,
    name: &str,
    description: &str,
) -> anyhow::Result<Lorebook> {
    let name = checked_name(name)?;
    add(db, user, &lore::empty(&name, description), [&name, ""])
}

/// Keeps a lorebook's document as a new lorebook of `user`. It is called by
/// the first of `names` that says anything, or else [`UNNAMED`]. It may have
/// no entries: an import and a copy from a card see that theirs has some.
fn add(db: &dyn Storage, user: i64, toml: &str, names: [&str; 2]) -> anyhow::Result<Lorebook> {
    let document = parse(toml)?;
    let reference = lore::book(&document).context(
        Fail::said(Code::NotReadable, "the file holds no lorebook").with("what", "lorebook"),
    )?;
    let listed = listed(&document, &reference);
    let name = names
        .into_iter()
        .chain([UNNAMED])
        .map(|name| short(name, MAX_NAME))
        .find(|name| !name.is_empty())
        .unwrap_or_default();
    let id = db.add_lorebook(user, &name, toml, &listed)?;
    Ok(get(db, user, id)?.ok_or(NotFound("lorebook"))?)
}

/// A lorebook of `user`, wherever it is: archived and in the Trash too.
pub fn get(db: &dyn Storage, user: i64, lorebook_id: i64) -> anyhow::Result<Option<Lorebook>> {
    db.lorebook(user, lorebook_id)
}

/// Refuses a lorebook that cannot be given to a chat: one in the Trash.
pub fn ensure_usable(db: &dyn Storage, user: i64, lorebook_id: i64) -> anyhow::Result<()> {
    let lorebook = get(db, user, lorebook_id)?.ok_or(NotFound("lorebook"))?;
    ensure!(
        !lorebook.trashed,
        Fail::said(
            Code::InTrash,
            format!(
                "the lorebook “{}” is in the Trash; restore it to use it",
                lorebook.name
            )
        )
        .with("what", "lorebook_to_use")
        .with("name", (lorebook.name).to_string())
    );
    Ok(())
}

/// The lorebooks of `user` the library shows, by name, with those the cards
/// bring themselves ([`own_rows`]). Never those in the Trash. Archived ones only when they are asked for, or in a search, where
/// they come after the others. A search finds the lorebooks that have every
/// word of the query in their name, their description or the names of their
/// first entries, in any case.
pub fn find(db: &dyn Storage, user: i64, query: &str, show: Show) -> anyhow::Result<Vec<Lorebook>> {
    let query = query.to_lowercase();
    let words: Vec<&str> = query.split_whitespace().collect();
    let searching = !words.is_empty();
    let mut lorebooks = db.lorebooks(user, show, searching)?;
    lorebooks.extend(own_rows(db, user, show, searching)?);
    lorebooks.retain(|lorebook| {
        let text = format!(
            "{}\n{}\n{}",
            lorebook.name,
            lorebook.description,
            lorebook.entry_names.join("\n")
        )
        .to_lowercase();
        words.iter().all(|word| text.contains(word))
    });
    lorebooks.sort_by_cached_key(|lorebook| {
        (
            searching && lorebook.archived,
            name_order(&lorebook.name),
            lorebook.id,
        )
    });
    Ok(lorebooks)
}

/// The entries chats have left out of the lorebook `lorebook_id`, as
/// references: one of them that is gone from the lorebook is still left out
/// when it is put back.
fn left_out(db: &dyn Storage, lorebook_id: i64) -> anyhow::Result<HashSet<String>> {
    db.left_out_entries(lorebook_id)
}

/// A lorebook's name as it is kept, on one line; refused where it says
/// nothing or is too long.
fn checked_name(name: &str) -> anyhow::Result<String> {
    let name = one_line(name);
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "a lorebook needs a name").with("what", "lorebook_name")
    );
    ensure!(
        name.chars().count() <= MAX_NAME,
        Fail::said(
            Code::TooLong,
            format!("a lorebook's name has at most {MAX_NAME} characters")
        )
        .with("what", "lorebook_name")
        .with("max_name", MAX_NAME)
    );
    Ok(name)
}

pub fn set_favorite(
    db: &dyn Storage,
    user: i64,
    lorebook_id: i64,
    favorite: bool,
) -> anyhow::Result<()> {
    db.set_lorebook_favorite(user, lorebook_id, favorite)
}

pub fn set_archived(
    db: &dyn Storage,
    user: i64,
    lorebook_id: i64,
    archived: bool,
) -> anyhow::Result<()> {
    db.set_lorebook_archived(user, lorebook_id, archived)
}

/// Makes the lorebook one that every chat with a character has, as if attached
/// to its card, or no longer. A chat can still leave it out. Not one in the Trash.
pub fn set_everywhere(
    db: &dyn Storage,
    user: i64,
    lorebook_id: i64,
    on: bool,
) -> anyhow::Result<()> {
    if on {
        ensure_usable(db, user, lorebook_id)?;
    }
    db.set_lorebook_everywhere(user, lorebook_id, on)
}

/// Moves the lorebook to the trash or takes it back out; see [`trash`].
pub fn set_trashed(
    db: &dyn Storage,
    user: i64,
    lorebook_id: i64,
    trashed: bool,
) -> anyhow::Result<()> {
    if trashed {
        trash::put(db, user, trash::LOREBOOKS, lorebook_id)
    } else {
        trash::restore(db, user, trash::LOREBOOKS, lorebook_id)
    }
}

/// The lorebooks a card's document brings, as references: those a chat with
/// one of its characters is given, each once, in the characters' order.
fn brought_by(document: &Document) -> Vec<&str> {
    let mut references = Vec::new();
    for character in document.characters() {
        for reference in mapping::lorebooks(document, character) {
            if !references.contains(&reference) {
                references.push(reference);
            }
        }
    }
    references
}

/// How many lorebooks a card's document brings; see [`brought_by`].
pub(crate) fn brings(document: &Document) -> u32 {
    brought_by(document).len() as u32
}

/// The lorebooks a card's document brings; see [`brought_by`].
pub fn brought(document: &Document) -> Vec<CardLorebook> {
    let lorebook = |reference: &str| CardLorebook {
        source: CardLoreSource::Reference(reference.to_string()),
        name: mapping::lore_name(document, reference),
        entries: mapping::entries(document, reference).len() as u32,
        trashed: false,
    };
    brought_by(document).into_iter().map(lorebook).collect()
}

/// The lorebooks of a card: those its newest version brings, then those of
/// the library attached to it, in the order they were attached. One that is
/// archived or in the Trash is among them: the card keeps it until it is
/// deleted for good.
pub fn of_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<Vec<CardLorebook>> {
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    let mut lorebooks = brought(&cards::document_of(db, card.version_id)?);
    let attached = db.attached_lorebooks(card_id)?;
    lorebooks.extend(attached);
    Ok(lorebooks)
}

/// Refuses a card that is not there or is in the Trash.
fn ensure_kept(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<()> {
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    ensure!(
        !card.trashed,
        Fail::said(Code::InTrash, "the card is in the Trash; restore it first")
            .with("what", "card")
    );
    Ok(())
}

/// Attaches a lorebook of the library to a card: every chat with one of the
/// card's characters has it from its next reply on. Not to a card in the
/// Trash, and not a lorebook that is there. One the card has already stays
/// as it is. Answers with the card's lorebooks as they then are.
pub fn attach(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    lorebook_id: i64,
) -> anyhow::Result<Vec<CardLorebook>> {
    ensure_kept(db, user, card_id)?;
    ensure_usable(db, user, lorebook_id)?;
    db.attach_lorebook(card_id, lorebook_id)?;
    of_card(db, user, card_id)
}

/// Detaches a lorebook of the library from a card, from the next reply of the
/// card's chats on. The lorebook stays in the library, and a chat that took
/// it along itself keeps it. Not from a card in the Trash. Answers with the
/// card's lorebooks as they then are.
pub fn detach(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    lorebook_id: i64,
) -> anyhow::Result<Vec<CardLorebook>> {
    ensure_kept(db, user, card_id)?;
    let gone = db.detach_lorebook(card_id, lorebook_id)?;
    ensure!(
        gone,
        Fail::said(Code::NotPossible, "the card has no such lorebook attached")
            .with("what", "card_lorebook_attached")
    );
    of_card(db, user, card_id)
}

/// The lorebooks of the library a chat has: those attached to the cards of
/// its characters, in the order they were attached, then those it took along
/// itself, in the order it took them. Each once: one the chat has both ways
/// stands among the attached ones. One that is archived or in the Trash is
/// among them: the chat keeps it until it is deleted for good.
pub fn of_chat(db: &dyn Storage, chat_id: i64) -> anyhow::Result<Vec<Taken>> {
    let rows = db.chat_lorebooks(chat_id)?;
    rows.into_iter()
        .map(|row| {
            let ChatLorebookRow {
                id,
                name,
                trashed,
                toml,
                by_chat,
                everywhere,
                persona,
            } = row;
            let document = parse(&toml).with_context(|| {
                Fail::said(
                    Code::NotReadable,
                    format!("the lorebook “{name}” cannot be read"),
                )
                .with("what", "lorebook_named")
                .with("name", name.to_string())
            })?;
            let reference = lore::book(&document).with_context(|| {
                Fail::said(Code::NotReadable, format!("the lorebook “{name}” is empty"))
                    .with("what", "lorebook_named_empty")
                    .with("name", name.to_string())
            })?;
            Ok(Taken {
                id,
                name,
                trashed,
                document,
                reference,
                by_chat,
                everywhere,
                persona,
            })
        })
        .collect()
}

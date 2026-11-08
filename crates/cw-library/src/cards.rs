//! Card storage. A card is one imported CCV4 file (a SillyTavern card converted first) and holds one
//! character (`Document::characters`; an import keeps the first); it belongs to one user. Its parts are kept
//! as they came, in its one version: TOML files as text, assets and the picture in `blobs`, once per content.
//! An edit (`edit`, its files by `ccv4/edit.rs`) puts a new version in its place (a new ID, never given twice,
//! so what is made of a version is made anew) and the chats move to it (`retire`): a chat always uses the
//! card's current texts. Each text keeps its earlier drafts in the card's own files (`ccv4/drafts.rs`, listed
//! by `drafts`); an edit says what made them (`edit_as`); an older build's versions become those drafts at a
//! start (`fold_versions`). Every picture a card had stays in `card_pictures`.
//!
//! The library's list is `find`, its tags `tag_counts`; tags are the same by `tag_key` and compared in
//! Rust, as SQLite knows case from a to z only. A described card (`describe`) shows the classifier's terms
//! and then the user's own (`cards.own_tags`) as its tags, and its logline; a title the user gave
//! (`cards.title_edited`) is never replaced. Traps: the file's `user-state` flags are not taken over (the
//! file may be a stranger's); `edit` asks for the card's version again inside its transaction; a stored
//! excerpt names the user by `USER_MARK`, worded in the app's language when read (`worded`). Its parts:
//! `store` (putting a card in), `versions` (edits and drafts), `files` (reading and exporting it), `folder`
//! and `watch` (a folder of cards imported, and watched).

use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};

use cw_ccv4::png::Container;
use cw_ccv4::tag_key;
use cw_ccv4::{Document, display};
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;
use unicode_normalization::UnicodeNormalization;
use unicode_normalization::char::is_combining_mark;

use crate::faces::Face;
use crate::lorebooks::CardLorebook;
use crate::needs::Strength;
use crate::posters::Letter;
use crate::posters::Mood;
use crate::trash;
use cw_search as search;

mod files;
pub mod folder;
pub mod pictures;
mod store;
mod versions;
pub mod watch;

pub use files::*;
pub use store::*;
pub use versions::*;

/// An import of a card the library has already: of the same file (its fingerprint, the SHA-256 of its whole
/// contents), or an exact copy of its picture and files. A card of the same name alone is not one.
pub fn in_library() -> Fail {
    Fail::said(Code::Taken, "already in your library").with("what", IN_LIBRARY)
}

/// The `what` of [`in_library`].
const IN_LIBRARY: &str = "card_in_library";

/// Whether `failure` is an import of a card the library has already ([`in_library`]).
pub(crate) fn is_in_library(failure: &anyhow::Error) -> bool {
    cw_core::coded(failure).is_some_and(|fail| fail.details.get("what") == Some(&IN_LIBRARY.into()))
}

/// The user's lists of files of a folder of cards, each by its path, size and time written, so one unchanged
/// is passed over unread (`folder.rs`).
#[derive(Clone, Copy, Debug)]
pub enum KeptFiles {
    /// Found to hold no card.
    NotCards,
    /// Taken by the watched folder: imported, or found in the library.
    Watched,
}

/// A file that holds no card: a PNG without card data, a JSON that is no SillyTavern card. A folder of cards
/// passes it over silently (`folder.rs`).
#[derive(Debug)]
pub(crate) struct NotACard(pub &'static str);

impl std::fmt::Display for NotACard {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.0)
    }
}

impl std::error::Error for NotACard {}

#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct Imported {
    pub card_id: i64,
    pub version_id: i64,
    /// The version's number within its card, from 1.
    pub version: i64,
    pub title: String,
    /// Flaws the import tolerated, such as references that lead nowhere.
    pub warnings: Vec<cw_ccv4::ImportNote>,
    /// The lorebooks the card brings. One with entries can be copied into the library.
    pub lorebooks: Vec<CardLorebook>,
}

#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct CardSummary {
    pub id: i64,
    pub title: String,
    pub favorite: bool,
    /// Hidden from the library but still found by search.
    pub archived: bool,
    /// In the trash, from where it can be restored.
    pub trashed: bool,
    /// The newest version.
    pub version_id: i64,
    pub version: i64,
    /// When the card was added.
    pub created_at: i64,
    /// When a message was last added to a chat with it. Archived and trashed
    /// chats aside: it is the chat the library goes on with.
    pub last_chat_at: Option<i64>,
    /// That chat's name.
    pub last_chat_title: Option<String>,
    /// What its characters are called in a chat.
    pub names: Vec<String>,
    /// The classifier's terms and the user's own tags once the card is
    /// described, until then the file's.
    pub tags: Vec<String>,
    /// The card's logline once it is described, until then the start of the
    /// first greeting, as plain text.
    pub excerpt: String,
    /// Whether the card waits for the worker model to describe it.
    pub describing: bool,
    /// What its poster shows: read always, sent only to the view Posters, which asks for it.
    pub poster: Option<Poster>,
}

impl CardSummary {
    /// The card without what its poster shows, for every view but Posters.
    pub fn plain(self) -> Self {
        Self {
            poster: None,
            ..self
        }
    }
}

/// What a card's poster shows beside its picture and title.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct Poster {
    /// The line on its poster: empty until it is described, or where the model wrote none that fits.
    pub tagline: String,
    /// Which of a poster's looks it takes; none until it is described.
    pub mood: Option<Mood>,
    /// The faces on its picture: none until they have been looked for.
    pub faces: Vec<Face>,
    /// Which of its mood's two poster designs it takes: none until it has a mood.
    pub design: Option<Letter>,
}

/// Which of its items a section of the library shows.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Show {
    #[default]
    All,
    Favorites,
    Archived,
}

/// The order the library shows them in.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Sort {
    /// The card chatted with last comes first; cards never chatted with follow, newest first.
    #[default]
    LastChatted,
    Name,
    /// The card added last comes first.
    Added,
}

/// What the library asks for; see [`find`].
#[derive(Clone, Copy, Debug, Default)]
pub struct Find<'a> {
    /// Words that must all be in the card's title, its characters' names or its tags.
    pub query: &'a str,
    /// Tags the card must have, all of them, whatever their case; see [`tag_key`].
    pub tags: &'a [String],
    pub show: Show,
    pub sort: Sort,
    /// The query as the search model reads it, where it is set up: the cards
    /// near it in meaning are found too (`search`).
    pub near: Option<&'a [f32]>,
    /// With needs picked (view "By need"), each card that has any and how strongly (`needs::strengths`): the
    /// list is those, the highest sum first, then the best rank, of two alike by title, whatever the sort asked for.
    pub strengths: Option<&'a HashMap<i64, Strength>>,
}

/// One of the tags the library's cards have, to filter the list by.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct TagCount {
    /// As most of the cards that have it write it.
    pub tag: String,
    /// How many of the cards the list shows have it.
    pub cards: u32,
    /// The list was asked for the cards that have it.
    pub chosen: bool,
}

/// Most words of a query that are searched for.
const MAX_WORDS: usize = 8;
/// Most names and tags of a card the library keeps, and the longest of them in
/// characters. A card can hold any number of either.
const MAX_LISTED: usize = 64;
const MAX_LISTED_CHARS: usize = 64;

#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct CardVersion {
    pub id: i64,
    /// Its number within the card, from 1.
    pub number: i64,
    pub created_at: i64,
}

/// Tags as what makes each the tag it is ([`tag_key`]) and as they are
/// written, each once.
pub fn each_once<'a>(tags: impl IntoIterator<Item = &'a String>) -> Vec<(String, &'a str)> {
    let mut once: Vec<(String, &str)> = Vec::new();
    for tag in tags {
        let key = tag_key(tag);
        if !key.is_empty() && once.iter().all(|(had, _)| *had != key) {
            once.push((key, tag.trim()));
        }
    }
    once
}

/// Whether a card with the tags `own` has every one of `wanted`.
fn has_all(own: &[(String, &str)], wanted: &[(String, &str)]) -> bool {
    wanted
        .iter()
        .all(|(tag, _)| own.iter().any(|(key, _)| key == tag))
}

/// All cards of `user`, trashed ones included, oldest first.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<CardSummary>> {
    worded(db, user, db.card_summaries(user)?)
}

/// What stands in a stored excerpt for the user's name (`{{user}}`): the index
/// is kept apart from the settings, so the word in the app's language is put in
/// when a card is read ([`worded`]). A character of Unicode's private use area,
/// which no card's text holds and no macro expands.
pub(crate) const USER_MARK: &str = "\u{E000}";

/// `cards` with [`USER_MARK`] in their excerpts replaced by the stand-in name in
/// the app's language; the settings are read only when a mark is there.
fn worded(
    db: &dyn Storage,
    user: i64,
    mut cards: Vec<CardSummary>,
) -> anyhow::Result<Vec<CardSummary>> {
    if cards.iter().any(|card| card.excerpt.contains(USER_MARK)) {
        let word = crate::settings::user_stand_in(db, user)?;
        for card in &mut cards {
            if card.excerpt.contains(USER_MARK) {
                // Cut again: the word is longer than the mark it was measured as.
                card.excerpt = display::excerpt(&card.excerpt.replace(USER_MARK, word));
            }
        }
    }
    Ok(cards)
}

/// The cards of `user` the library shows. Never the trashed ones. Archived
/// cards only when they are asked for, or in a search, where they come after
/// the others. A search finds the cards that have every word of the query in
/// their title, their characters' names or their tags, in any case, and with
/// `near` also those near the query in meaning (`search::found`), in the
/// order of the two fused (`search::fuse`: the cards found by their words in
/// the order asked for, and those found by their meaning, the nearest first),
/// the nearer first of two that rank alike, in place of the order asked for. Tags asked for narrow the list to the cards that have them all; they
/// are no search, so archived cards stay out.
pub fn find(db: &dyn Storage, user: i64, find: &Find<'_>) -> anyhow::Result<Vec<CardSummary>> {
    let mut cards = worded(db, user, found(db, user, find)?)?;
    if let Some(strengths) = find.strengths {
        cards.retain(|card| strengths.contains_key(&card.id));
        // Archived cards stay behind in a search, as there without needs.
        let behind = !find.query.trim().is_empty();
        cards.sort_by_cached_key(|card| {
            let strength = strengths.get(&card.id);
            (
                behind && card.archived,
                Reverse(strength.map(|strength| strength.sum)),
                strength.map(|strength| strength.rank),
                name_order(&card.title),
            )
        });
    }
    Ok(cards)
}

/// The list [`find`] gives, before any need picked.
fn found(db: &dyn Storage, user: i64, find: &Find<'_>) -> anyhow::Result<Vec<CardSummary>> {
    let query = find.query.to_lowercase();
    let words: Vec<&str> = query.split_whitespace().take(MAX_WORDS).collect();
    let searching = !words.is_empty();
    let near = find.near.filter(|_| searching);
    let FoundCards { mut cards, meaning } = db.find_cards(user, find.show, &words, near)?;
    // The tags are compared here: the database knows upper and lower case from a to z only.
    let wanted = each_once(find.tags);
    if !wanted.is_empty() {
        cards.retain(|card| has_all(&each_once(&card.tags), &wanted));
    }
    let behind = |card: &CardSummary| searching && card.archived;
    order(&mut cards, find.sort, behind);
    let Some(ByMeaning { mut all, near }) = meaning else {
        return Ok(cards);
    };
    let by_words: Vec<i64> = cards.iter().map(|card| card.id).collect();
    all.retain(|card| has_all(&each_once(&card.tags), &wanted));
    // Found by meaning, the nearest first.
    let by_meaning = search::found(&near, all.iter().map(|card| card.id));
    let found: HashSet<i64> = by_words.iter().chain(&by_meaning).copied().collect();
    all.retain(|card| found.contains(&card.id));
    let fused = search::fuse(&[by_words, by_meaning]);
    let rank = |card: &CardSummary| fused.get(&card.id).copied().unwrap_or_default();
    let nearest = |card: &CardSummary| near.get(&card.id).copied().unwrap_or(f32::MIN);
    all.sort_by(|a, b| {
        behind(a)
            .cmp(&behind(b))
            .then(rank(b).total_cmp(&rank(a)))
            .then(nearest(b).total_cmp(&nearest(a)))
            .then(b.id.cmp(&a.id))
    });
    Ok(all)
}

/// Puts `cards` in the order `sort`, those `behind` after the others.
fn order(cards: &mut [CardSummary], sort: Sort, behind: impl Fn(&CardSummary) -> bool) {
    // In each order the newer card comes first where the order itself does not tell.
    match sort {
        Sort::LastChatted => cards.sort_by_key(|card| {
            (
                behind(card),
                Reverse(card.last_chat_at),
                Reverse(card.created_at),
                Reverse(card.id),
            )
        }),
        Sort::Name => cards
            .sort_by_cached_key(|card| (behind(card), name_order(&card.title), Reverse(card.id))),
        Sort::Added => {
            cards.sort_by_key(|card| (behind(card), Reverse(card.created_at), Reverse(card.id)))
        }
    }
}

/// The tags the library's list can be narrowed by: those of the cards [`find`]
/// lists when it is asked for no tags, each with how many of the cards it
/// lists as it is asked have it. So a tag that would leave no card counts 0.
/// A tag asked for is among them also when no card has it. In the order of
/// their names; tags that differ in their case only are one, written as most
/// of the cards write it.
pub fn tag_counts(db: &dyn Storage, user: i64, find: &Find<'_>) -> anyhow::Result<Vec<TagCount>> {
    let wanted = each_once(find.tags);
    // Per tag: how many cards write it which way, and how many of the cards listed have it.
    let mut found: HashMap<String, (HashMap<&str, u32>, u32)> = HashMap::new();
    // A tag asked for is one of them, as it was asked for, also when no card has it.
    for (key, written) in &wanted {
        found.entry(key.clone()).or_default().0.insert(*written, 0);
    }
    let within = crate::cards::find(db, user, &Find { tags: &[], ..*find })?;
    for card in &within {
        let own = each_once(&card.tags);
        let listed = has_all(&own, &wanted);
        for (key, written) in own {
            let (ways, cards) = found.entry(key).or_default();
            *ways.entry(written).or_default() += 1;
            *cards += u32::from(listed);
        }
    }
    let mut counts = Vec::new();
    for (key, (ways, cards)) in found {
        // Written as most cards do; of two ways as common, the one that comes first by its letters.
        let (tag, _) = ways
            .into_iter()
            .max_by_key(|(written, cards)| (*cards, Reverse(*written)))
            .unwrap_or_default();
        let chosen = wanted.iter().any(|(tag, _)| *tag == key);
        counts.push(TagCount {
            tag: tag.to_string(),
            cards,
            chosen,
        });
    }
    counts.sort_by_cached_key(|count| (name_order(&count.tag), count.tag.clone()));
    Ok(counts)
}

/// What a name is put in order by: its letters without their case and their
/// marks, so that "Émile" stands beside "Emil" and not after "Zoe".
pub fn name_order(name: &str) -> String {
    name.nfd()
        .filter(|letter| !is_combining_mark(*letter))
        .flat_map(char::to_lowercase)
        .collect()
}

pub fn get(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<Option<CardSummary>> {
    let card = db.card(user, card_id)?;
    Ok(worded(db, user, card.into_iter().collect())?.pop())
}

pub fn set_favorite(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    favorite: bool,
) -> anyhow::Result<()> {
    db.set_card_favorite(user, card_id, favorite)
}

pub fn set_archived(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    archived: bool,
) -> anyhow::Result<()> {
    db.set_card_archived(user, card_id, archived)
}

/// Moves the card to the trash or takes it back out, and its chats with it; see [`trash`].
pub fn set_trashed(db: &dyn Storage, user: i64, card_id: i64, trashed: bool) -> anyhow::Result<()> {
    if trashed {
        trash::put_card(db, user, card_id)
    } else {
        trash::restore_card(db, user, card_id)
    }
}

/// A card's title, if the card is `user`'s. The cheap way to ask whether it is.
pub fn title(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<Option<String>> {
    db.card_title(user, card_id)
}

/// When a version that is not its card's first was made, in milliseconds; none
/// for a first version, which is the card as imported or made.
pub fn edited_at(db: &dyn Storage, version_id: i64) -> anyhow::Result<Option<i64>> {
    db.edited_at(version_id)
}

/// The card a version belongs to, if that card is `user`'s.
pub fn card_of(db: &dyn Storage, user: i64, version_id: i64) -> anyhow::Result<Option<i64>> {
    db.card_of_version(user, version_id)
}

/// What the library shows and searches of a card, as `index_of` makes it of
/// its newest version: names and tags as JSON lists, and the text a search
/// looks in, in lower case.
pub struct CardIndex {
    pub names: String,
    pub tags: String,
    pub excerpt: String,
    pub search: String,
    /// What its characters say, which Search Cardwave searches (`find`): descriptions, personalities,
    /// scenarios and greetings, as written.
    pub texts: String,
    /// Its own lorebooks and their entries, as Search Cardwave keeps them.
    pub lore: Vec<cw_search::kept::Text>,
    /// How many lorebooks it brings itself, so the lorebooks list reads only
    /// the documents of cards that bring one.
    pub brings: u32,
}

/// An edit to save as a card's new version (`edit_as`).
pub struct SavedEdit<'a> {
    pub card_id: i64,
    /// The number and id of the version the edit was made on.
    pub version: i64,
    pub version_id: i64,
    pub now: i64,
    pub files: &'a [(String, String)],
    pub title: &'a str,
    pub renamed: bool,
    /// The card's own tags (JSON) after the edit, of those it had and the tags
    /// its index had before (both JSON).
    pub own_tags: &'a dyn Fn(&str, &str) -> String,
    pub index: &'a CardIndex,
    pub document: &'a Document,
    /// The picture (its blob) the new version shows; the old version's where none.
    pub image: Option<i64>,
}

/// The cards a search found by their words, as `Storage::find_cards` reads them.
pub struct FoundCards {
    pub cards: Vec<CardSummary>,
    /// Where it searched by meaning too, every card shown, with how near those
    /// that have vectors are.
    pub meaning: Option<ByMeaning>,
}

/// Every card shown, and how near each that has vectors is to the search.
pub struct ByMeaning {
    pub all: Vec<CardSummary>,
    pub near: HashMap<i64, f32>,
}

/// A card and its newest version's TOML files (name, text), read at once.
pub struct NewestFiles {
    pub card: CardSummary,
    pub files: Vec<(String, String)>,
}

/// What the cards need of the database, which `cw_store::cards` gives.
pub trait Storage:
    crate::trash::Storage
    + crate::expressions::Storage
    + crate::failures::Failures
    + crate::settings::Storage
{
    fn card_summaries(&self, user: i64) -> anyhow::Result<Vec<CardSummary>>;
    /// The cards of `user`, as `card_summaries`, that bring a lorebook of their own (`CardIndex::brings`).
    fn cards_bringing_lore(&self, user: i64) -> anyhow::Result<Vec<CardSummary>>;
    /// The cards not in the Trash as `show` has them with every one of `words`
    /// in their title, names, tags or terms; and with `near`, every card shown
    /// with how near it is in meaning.
    fn find_cards(
        &self,
        user: i64,
        show: Show,
        words: &[&str],
        near: Option<&[f32]>,
    ) -> anyhow::Result<FoundCards>;
    fn card(&self, user: i64, card_id: i64) -> anyhow::Result<Option<CardSummary>>;
    fn set_card_favorite(&self, user: i64, card_id: i64, on: bool) -> anyhow::Result<()>;
    fn set_card_archived(&self, user: i64, card_id: i64, on: bool) -> anyhow::Result<()>;
    fn card_title(&self, user: i64, card_id: i64) -> anyhow::Result<Option<String>>;
    /// When a version that is not its card's first was made.
    fn edited_at(&self, version_id: i64) -> anyhow::Result<Option<i64>>;
    fn card_of_version(&self, user: i64, version_id: i64) -> anyhow::Result<Option<i64>>;
    /// Stores a card file's parts as a new card, with the SHA-256 of its picture
    /// and of each asset, its picture come from `source` (`pictures::Source`):
    /// its id and its version's. An import is refused ([`in_library`]) where a card in the library (not in
    /// the Trash) came from a file of its `fingerprint`, or is an exact copy, its picture and every file the same.
    #[allow(clippy::too_many_arguments)]
    fn store_card(
        &self,
        user: i64,
        title: &str,
        container: &Container,
        hashes: (&[u8], &[Vec<u8>]),
        source: &str,
        fingerprint: Option<&[u8]>,
        index: &CardIndex,
        now: i64,
    ) -> anyhow::Result<(i64, i64)>;
    /// Whether a card of `user` outside the Trash came from a file of this `fingerprint`.
    fn knows_file(&self, user: i64, fingerprint: &[u8]) -> anyhow::Result<bool>;
    /// Whether `path` is in `user`'s list `kept` as it is now: of this size and time written (ms).
    fn is_kept_file(
        &self,
        kept: KeptFiles,
        user: i64,
        path: &str,
        len: u64,
        modified: i64,
    ) -> anyhow::Result<bool>;
    /// Keeps `path`, of this size and time written, in `user`'s list `kept`.
    fn keep_file(
        &self,
        kept: KeptFiles,
        user: i64,
        path: &str,
        len: u64,
        modified: i64,
    ) -> anyhow::Result<()>;
    /// Makes a card's title and tags the user's own, as of a card made from scratch.
    fn mark_card_made(&self, card_id: i64) -> anyhow::Result<()>;
    /// Keeps the name of the file the card was imported from.
    fn set_card_file(&self, card_id: i64, name: &str) -> anyhow::Result<()>;
    /// The name of the file the card was imported from, where it was given one.
    fn card_file(&self, card_id: i64) -> anyhow::Result<Option<String>>;
    /// The cards whose index is missing or not of their newest version: id, version, title.
    fn stale_indexes(&self) -> anyhow::Result<Vec<(i64, i64, String)>>;
    fn put_index(&self, card_id: i64, version_id: i64, index: &CardIndex) -> anyhow::Result<()>;
    /// Saves `edit` as the card's newest version, its chats moved to it; or
    /// the card's newest number, none without the card, where the edit was not
    /// made on that.
    fn save_edit(&self, edit: &SavedEdit<'_>) -> anyhow::Result<Result<CardVersion, Option<i64>>>;
    fn version_made(&self, version_id: i64) -> anyhow::Result<i64>;
    /// The cards that have more than one version.
    fn cards_with_versions(&self) -> anyhow::Result<Vec<i64>>;
    /// Deletes the pictures and files no card uses any more.
    fn remove_unused_blobs(&self) -> anyhow::Result<()>;
    /// A card's versions, oldest first, each with when it was made.
    fn versions_of(&self, card_id: i64) -> anyhow::Result<Vec<(i64, i64)>>;
    /// The characters of the card's versions that chats are with.
    fn characters_chatted(&self, card_id: i64) -> anyhow::Result<Vec<String>>;
    /// Gives the version `keep` the TOML `files` (which make `document`) and
    /// puts it in the place of the card's others.
    fn fold_into(
        &self,
        card_id: i64,
        keep: i64,
        files: &[(String, String)],
        document: &Document,
    ) -> anyhow::Result<()>;
    /// The TOML files of a version; none where it has none.
    fn toml_files(&self, version_id: i64) -> anyhow::Result<Vec<(String, String)>>;
    /// A card and its newest version's TOML files, read at once.
    fn newest_files(&self, user: i64, card_id: i64) -> anyhow::Result<Option<NewestFiles>>;
    fn has_asset(&self, version_id: i64, name: &str) -> anyhow::Result<bool>;
    fn asset(&self, user: i64, version_id: i64, name: &str) -> anyhow::Result<Option<Vec<u8>>>;
    /// The parts of a card version, as a card file holds them.
    fn card_files(&self, version_id: i64) -> anyhow::Result<Container>;
    fn card_image(&self, user: i64, version_id: i64) -> anyhow::Result<Option<Vec<u8>>>;
    /// Keeps a picture (a PNG, with its SHA-256) among the card's, as come from
    /// `source`, where it is not one of them yet: its id.
    fn add_card_picture(
        &self,
        card_id: i64,
        hash: &[u8],
        data: &[u8],
        source: &str,
        now: i64,
    ) -> anyhow::Result<i64>;
    /// The pictures of a card of `user`'s, the one its newest version shows
    /// first, then the newest first.
    fn card_pictures(
        &self,
        user: i64,
        card_id: i64,
    ) -> anyhow::Result<Vec<crate::cards::pictures::Kept>>;
    /// One picture of a card of `user`'s.
    fn card_picture(
        &self,
        user: i64,
        card_id: i64,
        picture: i64,
    ) -> anyhow::Result<Option<Vec<u8>>>;
}

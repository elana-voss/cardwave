//! cw-find, Search Cardwave (docs/design.md "Tabs and search"): one search over the user's characters, lorebooks (a hit of
//! an entry names it), chats, personas, memories and documents, by words (`by_words`) and, given the query as the
//! search model reads it, by meaning too (`by_meaning`). The app's pages are the UI's own. A query's words must all
//! be in an item, in any case (`fold`); a match in a name (a card's title, names and tags; a lorebook's, or an
//! entry's name and keywords; a chat's title and characters; a persona's; a memory's text; a document's file
//! name) ranks above one in a text, whose grey line is the matching words in context (`in_context`); those found
//! by meaning alone come after, the nearest first, each kind as near as `search::found` asks. A chat is found by
//! its title and characters alone, never by its messages.
//!
//! What is searched of lorebooks, personas and memories is kept per owner in `search_texts` (`cw_search::kept`),
//! made anew whenever its owner is written (a lorebook saved, a card's newest version, a persona, a memory's
//! state), the vectors of a row whose words stayed kept; the search model reads the others in the background
//! (`reader`), which tells a chat reply's mood too (`mood`). Its SQL is cw-store's `find.rs`.

use std::collections::HashSet;

use cw_ccv4::one_line;
use cw_chat::chats::{self, ChatSort};
use cw_core::{Events, as_internal};
use cw_library::cards::name_order;
use cw_library::failures::Failures;
use cw_search::kept::{self, Among, Known, Owner, Text, TextRow};
use serde::Serialize;
use ts_rs::TS;

pub mod mood;
pub mod place;
pub mod reader;

/// What Search Cardwave and its reader ask of the store, which cw-store's `find.rs` gives.
pub trait Storage:
    chats::Storage
    + cw_search::Index
    + kept::Storage
    + cw_library::expressions::Storage
    + Failures
    + Send
    + Sync
{
}

/// What the reader asks of the app, which the server is: its state, the store, and the pages to tell.
pub trait Host: Events + Send + Sync + 'static {
    /// The reader's state, which the app holds.
    fn search(&self) -> &crate::reader::Search;
    /// The store.
    fn storage(&self) -> &dyn Storage;
    /// The same app, for a task to hold.
    fn held(&self) -> std::sync::Arc<dyn Host>;
}

/// Runs storage work on a thread that may block (the store is synchronous); a failure of the store or of the
/// thread is marked the server's own (`cw_core::as_internal`).
pub(crate) async fn work<T: Send + 'static>(
    host: &dyn Host,
    work: impl FnOnce(&dyn Storage) -> anyhow::Result<T> + Send + 'static,
) -> anyhow::Result<T> {
    let held = host.held();
    match tokio::task::spawn_blocking(move || work(held.storage())).await {
        Err(stopped) => Err(as_internal(stopped.into())),
        Ok(Err(failure)) if host.storage().failed_in(&failure) => Err(as_internal(failure)),
        Ok(done) => done,
    }
}

/// Most words of a query searched for, and most hits of a kind.
const MAX_WORDS: usize = 8;
pub(crate) const MAX_HITS: usize = 100;
/// Of a match in a text, how many characters stand before it in its line, and how many the line has at most.
const BEFORE: usize = 24;
const LINE: usize = 120;

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum HitKind {
    Character,
    Lorebook,
    Chat,
    Persona,
    Memory,
    Document,
}

/// What a search found, as its panel shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Hit {
    pub kind: HitKind,
    /// The card, the library's lorebook, the chat, the persona, the document; of a card's lorebook the card; of
    /// a memory its chat.
    pub id: i64,
    pub name: String,
    /// The grey line: the matching words in context, else what its kind tells of it.
    pub line: String,
    /// The card version whose picture is its round.
    pub picture: Option<i64>,
    /// Of a card's own lorebook: its reference, empty for the card's first.
    pub book: Option<String>,
    /// The part of its page it is: a lorebook's entry (`lore.ID`), a memory (its ID).
    pub part: Option<String>,
    /// Of a chat: its characters' names, which it is called after, and when it was written in last.
    pub names: Vec<String>,
    /// Of a memory: who knows it.
    pub known: Option<Known>,
    pub(crate) when: Option<i64>,
}

impl Hit {
    fn of(kind: HitKind, id: i64, name: String, line: String) -> Self {
        Self {
            kind,
            id,
            name,
            line,
            picture: None,
            book: None,
            part: None,
            names: Vec::new(),
            known: None,
            when: None,
        }
    }
}

/// A hit with what tells it from another of its kind, and how it was found.
pub struct Found {
    pub key: (HitKind, i64, String),
    pub hit: Hit,
    /// Its words were in its name.
    pub named: bool,
}

/// Has Search Cardwave keep the lorebooks, personas and memories it has none of: those of a database from before
/// it (a card's lorebooks come with its index, `cards::index_missing`). Run at a start; one that cannot be read
/// does not keep the server from starting.
pub fn index_missing(db: &dyn Storage) -> anyhow::Result<()> {
    for (user, owner) in db.unindexed()? {
        let done = match owner {
            Owner::Lorebook(id) => cw_library::lorebooks::index(db, user, id),
            Owner::Persona(id) => match cw_library::personas::get(db, user, id)? {
                Some(persona) => db.put_texts(
                    user,
                    owner,
                    &[Text::persona(persona.name, persona.description)],
                ),
                None => Ok(()),
            },
            Owner::Memory(id) => cw_chat::memory::index(db, user, id),
            Owner::Card(_) => Ok(()),
        };
        if let Err(failure) = done {
            tracing::warn!("{owner:?} cannot be kept for the search: {failure:#}");
        }
    }
    Ok(())
}

/// `text` in lower case, each character as the first of its lower case, so that a place in it is one in `text`.
fn fold(text: &str) -> String {
    text.chars()
        .map(|c| c.to_lowercase().next().unwrap_or(c))
        .collect()
}

/// The words of `query`, folded.
pub fn words(query: &str) -> Vec<String> {
    fold(query)
        .split_whitespace()
        .take(MAX_WORDS)
        .map(str::to_string)
        .collect()
}

/// Whether every one of `words` is in one of `parts`.
fn has_all(parts: &[&str], words: &[String]) -> bool {
    let folded = fold(&parts.join("\n"));
    words.iter().all(|word| folded.contains(word.as_str()))
}

/// The line of `text` around the first of `words` in it, on one line, cut at a word before it; none where none is.
pub(crate) fn in_context(text: &str, words: &[String]) -> Option<String> {
    let folded = fold(text);
    let at = words
        .iter()
        .filter_map(|word| folded.find(word.as_str()))
        .min()?;
    let before = folded[..at].chars().count();
    let start = before.saturating_sub(BEFORE);
    let mut line: String = text.chars().skip(start).take(LINE).collect();
    if start > 0 {
        // A word cut at the start goes; the match itself stays.
        if let Some(gap) = line
            .find(char::is_whitespace)
            .filter(|gap| line[..*gap].chars().count() < before - start)
        {
            line = line[gap..].to_string();
        }
        line = format!("…{}", line.trim_start());
    }
    Some(one_line(&line))
}

/// Everything `query` finds by its words, grouped by kind in the panel's order.
pub fn by_words(db: &dyn Storage, user: i64, query: &str) -> anyhow::Result<Vec<Hit>> {
    by_meaning(db, user, query, None)
}

/// [`by_words`], and with `near` (the query as the search model reads it) what it finds by meaning after them.
pub fn by_meaning(
    db: &dyn Storage,
    user: i64,
    query: &str,
    near: Option<&[f32]>,
) -> anyhow::Result<Vec<Hit>> {
    let words = words(query);
    if words.is_empty() {
        return Ok(Vec::new());
    }
    let ascii: Vec<String> = words.iter().filter(|w| w.is_ascii()).cloned().collect();
    let mut groups: Vec<(HitKind, Vec<Found>)> = vec![
        (
            HitKind::Character,
            cards(db, user, &words, Among::Words(&ascii))?,
        ),
        (HitKind::Lorebook, Vec::new()),
        (HitKind::Chat, chats(db, user, &words.join(" "))?),
        (HitKind::Persona, Vec::new()),
        (HitKind::Memory, Vec::new()),
        (
            HitKind::Document,
            documents(db, user, &words, Among::Words(&ascii))?,
        ),
    ];
    for found in texts(db, user, &words, Among::Words(&ascii))? {
        // Every kind has its group, made above.
        let at = groups
            .iter()
            .position(|(kind, _)| *kind == found.key.0)
            .unwrap_or_default();
        groups[at].1.push(found);
    }
    for (_, found) in &mut groups {
        // Named first, each part in the order of its names, as stable as its keys.
        found.sort_by_cached_key(|f| (!f.named, name_order(&f.hit.name), f.key.clone()));
    }
    if let Some(near) = near {
        meaning(db, user, near, &mut groups)?;
    }
    Ok(groups
        .into_iter()
        .flat_map(|(_, found)| found.into_iter().take(MAX_HITS).map(|f| f.hit))
        .collect())
}

/// Adds to each group what is near `near` by meaning and was not found by its words, the nearest first.
fn meaning(
    db: &dyn Storage,
    user: i64,
    near: &[f32],
    groups: &mut [(HitKind, Vec<Found>)],
) -> anyhow::Result<()> {
    use cw_search::{self as search, found};
    let had: HashSet<(HitKind, i64, String)> = groups
        .iter()
        .flat_map(|(_, f)| f.iter().map(|f| f.key.clone()))
        .collect();
    let mut add = |kind: HitKind, more: Vec<Found>| {
        // Every kind has its group (`by_words`).
        let at = groups
            .iter()
            .position(|(k, _)| *k == kind)
            .unwrap_or_default();
        groups[at]
            .1
            .extend(more.into_iter().filter(|f| !had.contains(&f.key)));
    };
    let cards_near: std::collections::HashMap<i64, f32> =
        db.near_cards(user, near)?.into_iter().collect();
    let ids = found(&cards_near, cards_near.keys().copied());
    add(
        HitKind::Character,
        in_order(&ids, cards(db, user, &[], Among::Ids(&ids))?, |f| f.key.1),
    );
    let texts_near: std::collections::HashMap<i64, f32> =
        db.near_texts(user, near)?.into_iter().collect();
    let rows = db.find_texts(
        user,
        Among::Ids(&texts_near.keys().copied().collect::<Vec<_>>()),
    )?;
    // Each kind is found by meaning against its own nearest.
    for kind in [HitKind::Lorebook, HitKind::Persona, HitKind::Memory] {
        let of_kind: Vec<&TextRow> = rows.iter().filter(|row| kind_of(row) == kind).collect();
        let ids = found(&texts_near, of_kind.iter().map(|row| row.id));
        let hits: Vec<Found> = ids
            .iter()
            .filter_map(|id| of_kind.iter().find(|row| row.id == *id))
            .map(|row| text_hit(row, &[]))
            .collect();
        add(kind, hits);
    }
    let pieces = search::Index::document_pieces(db, user, None)?;
    let documents_near = search::nearest_by(
        near,
        pieces
            .into_iter()
            .map(|p| (p.document, p.text, p.embedding)),
    );
    let by_id: std::collections::HashMap<i64, f32> = documents_near
        .iter()
        .map(|(id, (n, _))| (*id, *n))
        .collect();
    let ids = found(&by_id, by_id.keys().copied());
    let mut hits = in_order(&ids, documents(db, user, &[], Among::Ids(&ids))?, |f| {
        f.key.1
    });
    for hit in &mut hits {
        if let Some((_, piece)) = documents_near.get(&hit.key.1) {
            hit.hit.line = in_context(piece, &[])
                .unwrap_or_else(|| one_line(&piece.chars().take(LINE).collect::<String>()));
        }
    }
    add(HitKind::Document, hits);
    Ok(())
}

/// `found` in the order of `ids`.
fn in_order(ids: &[i64], mut found: Vec<Found>, id: impl Fn(&Found) -> i64) -> Vec<Found> {
    found.sort_by_key(|f| ids.iter().position(|i| *i == id(f)).unwrap_or(usize::MAX));
    found
}

/// The cards with all `words` (none: all those read), by their names or else their texts.
fn cards(
    db: &dyn Storage,
    user: i64,
    words: &[String],
    among: Among<'_>,
) -> anyhow::Result<Vec<Found>> {
    let mut out = Vec::new();
    for card in kept::Storage::find_cards(db, user, among)? {
        let names = [card.title.as_str()]
            .into_iter()
            .chain(card.names.iter().map(String::as_str))
            .chain(card.tags.iter().map(String::as_str))
            .collect::<Vec<_>>();
        let named = has_all(&names, words);
        if !named && !has_all(&[&names.join("\n"), &card.texts], words) {
            continue;
        }
        let shown = || {
            let mut parts = vec![format!("as {}", card.names.join(", "))];
            parts.extend(card.tags.iter().take(3).cloned());
            parts.join(" · ")
        };
        let line = match named || words.is_empty() {
            true => shown(),
            false => in_context(&card.texts, words).unwrap_or_else(shown),
        };
        let mut hit = Hit::of(HitKind::Character, card.id, card.title.clone(), line);
        hit.picture = Some(card.version_id);
        out.push(Found {
            key: (HitKind::Character, card.id, String::new()),
            hit,
            named,
        });
    }
    Ok(out)
}

/// The chats whose title or characters' names have all the words of `query` (the counted words, `words`), as the
/// list of chats finds them.
fn chats(db: &dyn Storage, user: i64, query: &str) -> anyhow::Result<Vec<Found>> {
    let find = chats::Find {
        query,
        show: Default::default(),
        sort: ChatSort::LastWritten,
    };
    Ok(chats::find(db, user, &find)?
        .into_iter()
        .map(|one| {
            let mut hit = Hit::of(
                HitKind::Chat,
                one.chat.id,
                one.chat.title.clone(),
                String::new(),
            );
            hit.picture = one.cards.first().map(|card| card.version_id);
            hit.names = one.names;
            hit.when = Some(one.chat.updated_at);
            Found {
                key: (HitKind::Chat, one.chat.id, String::new()),
                hit,
                named: true,
            }
        })
        .collect())
}

/// The documents with all `words` in their name or else their text.
fn documents(
    db: &dyn Storage,
    user: i64,
    words: &[String],
    among: Among<'_>,
) -> anyhow::Result<Vec<Found>> {
    let mut out = Vec::new();
    for document in db.find_documents(user, among)? {
        let named = has_all(&[&document.name], words);
        if !named && !has_all(&[&document.name, &document.text], words) {
            continue;
        }
        let counted = format!("{} words", document.words);
        let line = match named || words.is_empty() {
            true => counted,
            false => in_context(&document.text, words).unwrap_or(counted),
        };
        let hit = Hit::of(HitKind::Document, document.id, document.name, line);
        out.push(Found {
            key: (HitKind::Document, document.id, String::new()),
            hit,
            named,
        });
    }
    Ok(out)
}

/// What kind of hit a row of `search_texts` is.
fn kind_of(row: &TextRow) -> HitKind {
    match row.owner {
        Owner::Lorebook(_) | Owner::Card(_) => HitKind::Lorebook,
        Owner::Persona(_) => HitKind::Persona,
        Owner::Memory(_) => HitKind::Memory,
    }
}

/// The rows of `search_texts` with all `words`, by their names or else their texts.
fn texts(
    db: &dyn Storage,
    user: i64,
    words: &[String],
    among: Among<'_>,
) -> anyhow::Result<Vec<Found>> {
    let mut out = Vec::new();
    for row in db.find_texts(user, among)? {
        let text = &row.text;
        let names = [text.title.as_str(), text.keys.as_str()];
        let named = has_all(&names, words);
        if named || has_all(&[&text.title, &text.keys, &text.text], words) {
            let mut found = text_hit(&row, words);
            found.named = named;
            out.push(found);
        }
    }
    Ok(out)
}

/// The hit of a row of `search_texts`, its line the matching `words` in context where they are in its text.
fn text_hit(row: &TextRow, words: &[String]) -> Found {
    let text = &row.text;
    let kind = kind_of(row);
    let context = || {
        in_context(&text.keys, words)
            .filter(|_| !has_all(&[&text.title], words))
            .or_else(|| in_context(&text.text, words))
    };
    let (id, name, line) = match row.owner {
        Owner::Lorebook(id) | Owner::Card(id) if text.entry.is_empty() => {
            let name = text.title.clone();
            let told = match row.owner {
                Owner::Lorebook(_) if row.entries == 1 => "1 entry".to_string(),
                Owner::Lorebook(_) => format!("{} entries", row.entries),
                _ => format!("in {}", row.name),
            };
            let line = match has_all(&[&name], words) {
                true => told,
                false => in_context(&text.text, words).unwrap_or(told),
            };
            (id, name, line)
        }
        Owner::Lorebook(id) | Owner::Card(id) => {
            let within = text.within.clone();
            let line = match context() {
                Some(context) if !words.is_empty() => format!("{} · {context}", text.title),
                _ => text.title.clone(),
            };
            (id, within, line)
        }
        Owner::Persona(id) => {
            let line = context()
                .unwrap_or_else(|| one_line(&text.text.chars().take(LINE).collect::<String>()));
            (id, text.title.clone(), line)
        }
        Owner::Memory(_) => (
            text.chat_id.unwrap_or_default(),
            one_line(&text.title),
            String::new(),
        ),
    };
    let mut hit = Hit::of(kind, id, name, line);
    hit.known = text.known.clone();
    if let Owner::Card(_) = row.owner {
        hit.book = Some(text.book.clone());
    }
    if !text.entry.is_empty() {
        hit.part = Some(text.entry.clone());
    }
    let key = (kind, row.id, String::new());
    Found {
        key,
        hit,
        named: false,
    }
}

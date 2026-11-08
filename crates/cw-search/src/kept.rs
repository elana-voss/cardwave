//! What Search Cardwave keeps of each area and reads back (`find`): the rows of `search_texts` an area hands in
//! (`Text`, by its `Owner`), and the rows of cards, texts and documents a search reads (`Storage`, which
//! `db/find.rs` gives).

use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Who knows a memory, as its search hit tells it: everyone, or the characters named and the user where `you`
/// (neither: nobody); the user is not among `names`, so the hit says "you" as Knowledge › Memories does.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(tag = "code", rename_all = "snake_case")]
#[ts(export)]
pub enum Known {
    Everyone,
    By { names: Vec<String>, you: bool },
}

/// What a row of `search_texts` is of; deleting it deletes its rows.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Owner {
    Lorebook(i64),
    /// A card's own lorebooks, of its newest version.
    Card(i64),
    Persona(i64),
    /// A memory (`memory_stores`).
    Memory(i64),
}

/// A row of `search_texts`: a lorebook (its `entry` empty) or one of its entries, a persona, a memory.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Text {
    /// Of a card's lorebook its reference, empty for the card's first (its address names it without one).
    pub book: String,
    /// An entry's reference (`lore.ID`); a memory's ID; empty for a lorebook or a persona.
    pub entry: String,
    /// Its name: a lorebook's, an entry's label, a persona's; a memory's text.
    pub title: String,
    /// An entry's lorebook's name.
    pub within: String,
    /// An entry's keywords.
    pub keys: String,
    /// A lorebook's description, an entry's content, a persona's description.
    pub text: String,
    /// A memory's who knows it.
    pub known: Option<Known>,
    /// A memory's chat.
    pub chat_id: Option<i64>,
}

impl Text {
    /// A persona's row: its name and description.
    pub fn persona(name: String, description: String) -> Self {
        Text {
            title: name,
            text: description,
            ..Default::default()
        }
    }

    /// What the search model reads of it.
    pub fn read(&self) -> String {
        [&self.title, &self.keys, &self.text]
            .into_iter()
            .filter(|part| !part.trim().is_empty())
            .map(String::as_str)
            .collect::<Vec<_>>()
            .join("\n")
    }
}

/// Which rows the storage reads: those with every one of these words (lower case, a to z alone, as SQLite
/// compares them; the others are compared after), or those of these IDs. Known limit: a letter that folds to
/// one of a to z only outside SQLite (the Turkish İ, the Kelvin sign) is not found by that letter.
pub enum Among<'a> {
    Words(&'a [String]),
    Ids(&'a [i64]),
}

/// A card as the search reads it.
pub struct CardRow {
    pub id: i64,
    pub title: String,
    pub names: Vec<String>,
    pub tags: Vec<String>,
    /// What its characters say: descriptions, personalities, scenarios, greetings.
    pub texts: String,
    pub version_id: i64,
}

/// A row of `search_texts` with what its hit tells of its owner.
pub struct TextRow {
    pub id: i64,
    pub owner: Owner,
    pub text: Text,
    /// The title of a card whose lorebook it is.
    pub name: String,
    /// A library lorebook's number of entries.
    pub entries: i64,
}

/// A document as the search reads it.
pub struct DocumentRow {
    pub id: i64,
    pub name: String,
    pub text: String,
    pub words: i64,
}

/// What the search needs of the database, which `db/find.rs` gives.
pub trait Storage {
    /// The user's cards not in the Trash.
    fn find_cards(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<CardRow>>;
    /// The rows of `search_texts` whose owner is not in the Trash (a memory's: its chat).
    fn find_texts(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<TextRow>>;
    /// The user's documents not deleted.
    fn find_documents(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<DocumentRow>>;
    /// How near `query` each of those cards is, by its nearest piece, where its vectors are of the user's model.
    fn near_cards(&self, user: i64, query: &[f32]) -> anyhow::Result<Vec<(i64, f32)>>;
    /// The same of the rows of `search_texts`, by their IDs.
    fn near_texts(&self, user: i64, query: &[f32]) -> anyhow::Result<Vec<(i64, f32)>>;
    /// Writes the rows of `owner` anew, keeping the vectors of those that read the same.
    fn put_texts(&self, user: i64, owner: Owner, texts: &[Text]) -> anyhow::Result<()>;
    /// The library's lorebooks, the personas and the memories without a row, each with its user.
    fn unindexed(&self) -> anyhow::Result<Vec<(i64, Owner)>>;
    /// The next rows to read, up to `count`, all of one user and stamp, but those whose stamp is in `skip`: each
    /// as its ID, user, what the model reads of it and the stamp.
    fn unread_texts(
        &self,
        skip: &[String],
        count: usize,
    ) -> anyhow::Result<Vec<(i64, i64, String, String)>>;
    /// Keeps the vectors of the rows `read` by the model of `stamp` (empty where it could not read one).
    fn keep_text_vectors(&self, stamp: &str, read: &[(i64, Vec<u8>)]) -> anyhow::Result<()>;
}

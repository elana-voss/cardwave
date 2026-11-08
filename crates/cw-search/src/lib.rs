//! The library's search by meaning, beside its search by words (`cards::find`).
//!
//! A card is read as Cardwave reads it (`texts`): name, tags, each character's
//! personality, description and scenario, in pieces of at most
//! `embedder::CHUNK_TOKENS`, kept in `card_chunks` for its newest version
//! (`card_search`, `next`). A search finds a card by its nearest piece where that
//! is about as near as the nearest card's (`found`), and words and meaning are
//! fused by rank (`fuse`, k = 60). A chat's texts (memories, lorebook entries)
//! are kept by text (`text_hash`, `text_vectors`), each as near as its nearest
//! piece (`nearest`, `nearest_by`); unused for 30 days they go (`forget_unused`).
//! Search Cardwave's texts keep their vectors in `search_texts`; what it keeps
//! and reads (`Text`, `Owner`, their `Storage`) is [`kept`].
//!
//! Every vector is kept with its model's stamp (`embedder::Reader::stamp`): the
//! account's search kind's model, else this computer's bge-m3; one of another
//! stamp is read anew, two are never compared. The SQL behind [`Index`] is the
//! server's `db/search.rs`.

use std::collections::HashMap;

use cw_ccv4::{Document, mapping};
use cw_provider::embedder;
use sha2::{Digest, Sha256};

pub mod kept;

/// How near, as a cosine, a card's nearest piece must be to a search for the
/// card to be found by its meaning alone: at least `FOUND`, and no more than
/// `BEHIND` behind the nearest card's. Measured with bge-m3 on the 11 test
/// cards (the work log, "Search by description"): a card that fits a search
/// came at 0.51 to 0.64, others at 0.35 to 0.6.
pub(crate) const FOUND: f32 = 0.5;
const BEHIND: f32 = 0.03;

/// The vectors of every card's pieces, by card, as `card_chunks` holds them:
/// each card's, with the stamp of the model that made them.
pub type CardVectors = HashMap<i64, (String, Vec<Vec<u8>>)>;

/// A piece of a document that a reply may be given.
pub struct Piece {
    /// The document's ID and name.
    pub document: i64,
    pub name: String,
    pub text: String,
    /// The vectors of its parts one after the other (`search::nearest`).
    pub embedding: Vec<u8>,
}

/// The constant of reciprocal rank fusion, as its paper has it.
const FUSION_K: f64 = 60.0;

/// The texts of each field of a card (name, tags, personality, description,
/// scenario, in this order: the number each piece is kept with), one for each character
/// where a field is a character's, as written.
pub fn texts(title: &str, document: &Document) -> Vec<Vec<String>> {
    let characters = document.characters();
    let mut names = vec![title.trim().to_string()];
    for id in &characters {
        let name = document.character_name(id);
        if !names.contains(&name) {
            names.push(name);
        }
    }
    let mut fields = vec![
        vec![names.join(", ")],
        vec![document.tags().join(", ")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
    ];
    for id in &characters {
        let Some(texts) = mapping::character(document, id) else {
            continue;
        };
        fields[2].push(texts.personality);
        fields[3].push(texts.description);
        fields[4].push(texts.scenario);
    }
    fields
}

/// The cards of `near` found by their meaning, of those `among`, the nearest
/// first. Not by a sum of the fields weighted as Cardwave weighs them: bge-m3
/// puts any text about as near to a field as to another, so a card with more
/// fields came first (seen: "a robot" put a detective before the robot).
pub fn found(near: &HashMap<i64, f32>, among: impl Iterator<Item = i64>) -> Vec<i64> {
    let nearest = |card: &i64| near.get(card).copied().unwrap_or(f32::MIN);
    let mut among: Vec<i64> = among.filter(|card| near.contains_key(card)).collect();
    among.sort_by(|a, b| nearest(b).total_cmp(&nearest(a)).then(b.cmp(a)));
    let bar = FOUND.max(among.first().map_or(f32::MIN, nearest) - BEHIND);
    among.retain(|card| nearest(card) >= bar);
    among
}

/// How near, as a cosine, the newest messages of a chat must be to a lorebook
/// entry used by meaning, by its nearest piece, for it to be used. Measured
/// with bge-m3 (the work log, "Memory"): of 8 entries and 11 exchanges, an
/// exchange about an entry without its words came at 0.49 to 0.65, all others
/// at 0.25 to 0.49; 0.5 found 7 of the 8 and none of the others.
pub const MEANING: f32 = 0.5;

/// How long a kept text's vector stays unused before the server's start lets
/// it go (`forget_unused`).
pub const UNUSED: i64 = 30 * 24 * 60 * 60 * 1000;

/// The cosine of `query` and the nearest of the vectors `stored` one after
/// the other (`reader::vectors`).
pub fn nearest(query: &[f32], stored: &[u8]) -> f32 {
    let size = query.len() * 4;
    if size == 0 {
        return f32::MIN;
    }
    stored
        .chunks(size)
        .map(|piece| embedder::cosine(query, piece))
        .fold(f32::MIN, f32::max)
}

/// Of each key among `pieces` (a key, what comes with the piece, its vectors),
/// how near its nearest piece is to `query` (`nearest`), with what came with
/// that piece; of two as near, the first.
pub fn nearest_by<K: Eq + std::hash::Hash, T, V: AsRef<[u8]>>(
    query: &[f32],
    pieces: impl IntoIterator<Item = (K, T, V)>,
) -> HashMap<K, (f32, T)> {
    let mut best: HashMap<K, (f32, T)> = HashMap::new();
    for (key, with, vectors) in pieces {
        let near = nearest(query, vectors.as_ref());
        if best.get(&key).is_none_or(|(had, _)| near > *had) {
            best.insert(key, (near, with));
        }
    }
    best
}

/// What a text's vector is kept by: a hash of the model's stamp and the text.
pub fn text_hash(stamp: &str, text: &str) -> Vec<u8> {
    let mut hash = Sha256::new();
    hash.update(stamp.as_bytes());
    hash.update([0]);
    hash.update(text.as_bytes());
    hash.finalize().to_vec()
}

/// How near each of the cards `among` that has vectors of `stamp`'s model is
/// to `query`: as its nearest piece.
pub fn rank(vectors: &CardVectors, among: &[i64], stamp: &str, query: &[f32]) -> HashMap<i64, f32> {
    let pieces = among
        .iter()
        .filter_map(|card| {
            vectors
                .get(card)
                .map(|(made_by, pieces)| (card, made_by, pieces))
        })
        .filter(|(_, made_by, _)| *made_by == stamp)
        .flat_map(|(card, _, pieces)| pieces.iter().map(move |piece| (*card, (), piece)));
    nearest_by(query, pieces)
        .into_iter()
        .map(|(card, (near, ()))| (card, near))
        .collect()
}

/// The search's storage: the cards' vectors (`card_chunks`, `card_search`),
/// the texts' (`text_vectors`) and the documents' pieces (`document_pieces`),
/// kept by SQLite beside the rest.
pub trait Index {
    /// The stamp of the user's vectors (`stamp_sql`).
    fn search_stamp(&self, user: i64) -> anyhow::Result<String>;
    fn unread_card(&self, skip: &[String]) -> anyhow::Result<Option<Unread>>;
    fn cards_unread(&self, user: i64) -> anyhow::Result<usize>;
    fn keep_card_vectors(
        &self,
        card_id: i64,
        version_id: i64,
        stamp: &str,
        vectors: &[(usize, Vec<f32>)],
    ) -> anyhow::Result<()>;
    fn kept_vectors(&self, hashes: &[Vec<u8>]) -> anyhow::Result<Vec<Option<Vec<u8>>>>;
    fn forget_unused_vectors(&self) -> anyhow::Result<()>;
    fn keep_vectors(&self, vectors: &[(Vec<u8>, Vec<u8>)]) -> anyhow::Result<()>;
    /// The next document its user's search model is to read, of any user but
    /// those whose stamp is in `skip`: one not deleted that the model has not
    /// read. With its user, its text and the stamp.
    fn unread_document(
        &self,
        skip: &[String],
    ) -> anyhow::Result<Option<(i64, i64, String, String)>>;
    /// Keeps the document's pieces, each with its vectors, in place of those
    /// it had, and that the model of `stamp` read it.
    fn keep_document_pieces(
        &self,
        id: i64,
        stamp: &str,
        pieces: &[(String, Vec<u8>)],
    ) -> anyhow::Result<()>;
    /// The pieces of the user's documents as the user's model read them: of
    /// the chat and its card in `chat` (`(chat_id, card_id)`), or of them all;
    /// none of a card or chat in the Trash.
    fn document_pieces(
        &self,
        user: i64,
        chat: Option<(i64, Option<i64>)>,
    ) -> anyhow::Result<Vec<Piece>>;
}

/// A card its user's search model is to read: its ID, user, newest version
/// and title, and the stamp of the user's model.
pub type Unread = (i64, i64, i64, String, String);

/// The fused score of each item ranked by any of `ranked`, each list best
/// first: reciprocal-rank fusion, `1 / (60 + r)` at rank r from 1.
pub fn fuse<K: Copy + Eq + std::hash::Hash>(ranked: &[Vec<K>]) -> HashMap<K, f64> {
    let mut fused = HashMap::new();
    for list in ranked {
        for (rank, id) in list.iter().enumerate() {
            *fused.entry(*id).or_default() += 1.0 / (FUSION_K + rank as f64 + 1.0);
        }
    }
    fused
}

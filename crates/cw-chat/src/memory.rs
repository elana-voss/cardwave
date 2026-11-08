//! What the characters remember: facts and events a helper (the Worker model)
//! reads out of each block of 20 messages, and the note a reply gets just
//! before the newest message. The system is behind one hook, `Remembers`
//! (`system()`: the benchmark's winner, `memory/hybrid.rs`), so another can
//! take its place: its state is the JSON it writes.
//!
//! A memory (`Owner`) is a roleplay chat's own, or a character's in a personal
//! mode (assistant, companion), shared by all its chats. Its state is kept
//! after each block (`cw_store::memory`); a block is told by its chat, number and
//! `chain` (its messages and all before them), so a block whose messages
//! changed (an edit, another swipe, a deletion, its chat deleted) and every
//! later one are let go and read again (`next_block`), and a reply reads the
//! state that holds on its branch and, of a shared memory, in its other chats
//! as they are now (`to_render`, `holding_all`), without what chats in the
//! Trash told it. Days (companion, assistant) are calendar days, day 1 the memory's
//! first. When a pass runs is `api/memory.rs`. Knowledge › Memories: `list`;
//! what Search Cardwave finds of a memory, its entries as they hold on the chat in
//! view, is written anew after each block and change (`index`, `find.rs`).
//! The user without a persona is kept as a mark, read as today's stand-in (`USER_MARK`).

use std::collections::HashMap;

use anyhow::ensure;
use chrono::Datelike;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_prompt::Role;
use futures_util::future::BoxFuture;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use ts_rs::TS;

use crate::chats::{self, Chat, Message};

mod changes;
mod held;
pub mod hybrid;
pub mod text;
mod vectors;

pub use held::{Casts, casts, follow_casts, rename_in, rename_persona};
pub use vectors::{keep_vectors, kept_vectors, unembedded};

/// The messages a block holds.
pub const BLOCK: usize = 20;
/// The memory note's tokens (`text::count`): the room the prompt keeps for it.
pub const BUDGET: usize = cw_prompt::builder::MEMORY_ROOM;
/// The longest text of a memory, in characters.
pub const TEXT_LIMIT: usize = 500;

/// The character of a card whose memory is shared by its chats: its card, and its ID there.
pub(crate) type Personal = (i64, String);

/// Whose memory it is.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Owner {
    /// A roleplay chat's own.
    Chat(i64),
    /// A character's in a personal mode, shared by its chats.
    Character(Personal),
}

/// The kind of chat a block is of: it words the helper's prompt, who may know
/// what, the subjects always shown and whether there are days.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Roleplay,
    Companion,
    Assistant,
}

/// One message as the memory reads it: its number in its chat, who said it
/// (the user's name, a character's, `Narrator`), and its day where there are days.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Said {
    pub n: i64,
    pub speaker: String,
    pub text: String,
    pub day: Option<i64>,
}

impl Said {
    /// The message as `Name: text`.
    pub fn line(&self) -> String {
        format!("{}: {}", self.speaker, self.text)
    }
}

/// Who is away from message `from` to `to`: the app knows none (A10.1).
#[derive(Clone, Debug, Deserialize)]
pub struct Away {
    pub name: String,
    pub from: i64,
    pub to: i64,
}

/// A block to read: its messages and what they are read against.
#[derive(Clone, Debug)]
pub struct Block {
    pub messages: Vec<Said>,
    /// What the user is called, as their messages are prefixed.
    pub user: String,
    /// The chat's characters, in a stable order.
    pub cast: Vec<String>,
    pub mode: Mode,
    pub absent: Vec<Away>,
    /// The chat it is of, which its entries keep.
    pub chat_id: Option<i64>,
}

/// What a reply asks the memory.
#[derive(Clone, Debug)]
pub struct Ask {
    /// The newest message, as `Name: text`.
    pub query: String,
    /// The one before it, as `Name: text`; none where there is none.
    pub prev: Option<String>,
    /// The character about to reply.
    pub speaker: String,
    pub mode: Mode,
    /// The newest message's day; none in roleplay.
    pub today: Option<i64>,
    pub budget: usize,
}

/// Texts' vectors by the search model, by text.
pub type Vectors = HashMap<String, Vec<f32>>;

/// The model that reads a block: it answers a prompt.
pub trait Helper: Send + Sync {
    fn ask<'a>(&'a self, prompt: &'a str) -> BoxFuture<'a, anyhow::Result<String>>;
}

/// A block read: the state after it, and the texts it saved.
pub struct Added {
    pub state: String,
    pub saved: Vec<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export, rename = "MemoryKind")]
pub enum Kind {
    /// What stays true of someone or something.
    Fact,
    /// What happened or was said.
    Event,
}

/// One thing remembered, as Knowledge › Memories and an export show it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    /// Its number in its memory.
    pub id: u64,
    pub kind: Kind,
    pub text: String,
    /// A fact's status (current, open, temporary, done); none of an event.
    pub status: Option<String>,
    pub until: String,
    pub world: bool,
    /// Who know it, lower-case; none where everyone does.
    pub(crate) known_to: Option<Vec<String>>,
    /// The chat it was read from.
    pub chat: Option<i64>,
    /// The number of the chat's message its block began with (`Said::n`).
    pub n: i64,
}

/// A change of an entry; what is left out stays.
#[derive(Clone, Debug, Default)]
pub struct Change {
    pub text: Option<String>,
    pub(crate) known_to: Option<Vec<String>>,
    pub deleted: Option<bool>,
}

/// The hook a memory system is behind. Its state is the JSON it writes, empty before the first block.
pub trait Remembers: Send + Sync {
    /// The state after `block` is read into `state`, asking `helper`.
    fn add<'a>(
        &'a self,
        state: &'a str,
        block: &'a Block,
        helper: &'a dyn Helper,
    ) -> BoxFuture<'a, anyhow::Result<Added>>;
    /// The memory note for `ask`; empty where there is none. `vectors` has
    /// the vectors of `texts` and of the asked texts, where there are any.
    fn render(&self, state: &str, ask: &Ask, vectors: Option<&Vectors>) -> anyhow::Result<String>;
    /// The texts whose vectors `render` uses.
    fn texts(&self, state: &str) -> anyhow::Result<Vec<String>>;
    /// What is remembered, deleted entries left out.
    fn entries(&self, state: &str) -> anyhow::Result<Vec<Entry>>;
    /// The state with the entry `id` changed; none where it has no such entry.
    fn change(&self, state: &str, id: u64, change: &Change) -> anyhow::Result<Option<String>>;
    /// The state without what was read from the chats `chats`.
    fn without(&self, state: &str, chats: &[i64]) -> anyhow::Result<String>;
    /// The state with the name `from` called `to` wherever it names someone.
    fn renamed(&self, state: &str, from: &str, to: &str) -> anyhow::Result<String>;
    /// The entry `id`, deleted or not, and a state holding it alone; none where it has no such entry.
    fn alone(&self, state: &str, id: u64) -> anyhow::Result<Option<(Entry, String)>>;
    /// The state with the entry of `alone` (a state of `alone`'s) put in as a new one, in place
    /// of the live entries it is again: a fact of its subject and key, an entry of a text in `replaces`.
    fn put(&self, state: &str, alone: &str, replaces: &[String]) -> anyhow::Result<String>;
}

/// What a kept state calls the user without a persona, whose stand-in name
/// follows the app's language (`cw_prompt::stand_in_user`): a state is kept
/// with it (`kept_form`) and read with today's stand-in (`read_form`).
const USER_MARK: &str = "{{user}}";

/// The stand-in name of `user` without a persona.
fn stand_in(db: &dyn crate::chats::Storage, user: i64) -> anyhow::Result<&'static str> {
    cw_library::settings::user_stand_in(db, user)
}

/// `state` as it is kept: the stand-in `name` as the mark.
fn kept_form(state: &str, name: &str) -> anyhow::Result<String> {
    system().renamed(state, name, USER_MARK)
}

/// A kept `state` as it is read: the mark as the stand-in `name`.
fn read_form(state: &str, name: &str) -> anyhow::Result<String> {
    system().renamed(state, USER_MARK, name)
}

/// `text` with each whole word `from` written `to`. Writing without spaces
/// between words (Chinese, Japanese, Korean's particles) has no word edge.
pub(crate) fn word_renamed(text: &str, from: &str, to: &str) -> String {
    fn spaced(c: char) -> bool {
        !matches!(c, '\u{1100}'..='\u{11FF}' | '\u{3040}'..='\u{30FF}' | '\u{3400}'..='\u{9FFF}'
            | '\u{AC00}'..='\u{D7AF}' | '\u{F900}'..='\u{FAFF}')
    }
    let edge = |near: Option<char>, end: Option<char>| match (near, end) {
        (Some(near), Some(end)) => near.is_alphanumeric() && spaced(near) && spaced(end),
        _ => false,
    };
    if from.is_empty() {
        return text.to_string();
    }
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(at) = rest.find(from) {
        let before = rest[..at].chars().last().or_else(|| out.chars().last());
        let after = rest[at + from.len()..].chars().next();
        out.push_str(&rest[..at]);
        match edge(before, from.chars().next()) || edge(after, from.chars().last()) {
            true => out.push_str(from),
            false => out.push_str(to),
        }
        rest = &rest[at + from.len()..];
    }
    out.push_str(rest);
    out
}

/// The memory system in use.
pub fn system() -> &'static dyn Remembers {
    &crate::memory::hybrid::HybridFixed
}

/// A memory's block as kept, without its state.
#[derive(Clone, Debug)]
pub struct Kept {
    pub id: i64,
    /// Its chat; none once the chat is deleted.
    pub chat_id: Option<i64>,
    /// Its number in the chat, from 0.
    pub block: i64,
    pub chain: String,
}

/// What the memory needs of the database, which `cw_store::memory` gives.
pub trait Storage: cw_search::Index + cw_search::kept::Storage {
    /// The user's memory of `owner`, with its day 1; made where `make` and there is none.
    fn memory_store(&self, owner: &Owner, make: bool)
    -> anyhow::Result<Option<(i64, Option<i64>)>>;
    /// The memory's blocks, in the order they were read.
    fn memory_blocks(&self, store: i64) -> anyhow::Result<Vec<Kept>>;
    fn memory_state(&self, block: i64) -> anyhow::Result<String>;
    /// Lets go of the memory's blocks from `from` on.
    fn forget_memory_blocks(&self, store: i64, from: i64) -> anyhow::Result<()>;
    /// Keeps a block read after the block `after` (none: the first), unless
    /// another was kept since; and sets day 1 where it has none. Answers
    /// whether it was kept.
    fn keep_memory_block(
        &self,
        store: i64,
        after: Option<i64>,
        kept: &NewBlock,
    ) -> anyhow::Result<bool>;
    /// Every state of the memory, by block.
    fn memory_states(&self, store: i64) -> anyhow::Result<Vec<(i64, String)>>;
    fn set_memory_state(&self, block: i64, state: &str) -> anyhow::Result<()>;
    /// What the user changed of the memory `store`'s entries (`changes`), empty before the first.
    fn memory_changes(&self, store: i64) -> anyhow::Result<String>;
    fn set_memory_changes(&self, store: i64, changes: &str) -> anyhow::Result<()>;
    /// The user's memories: each with its owner.
    fn memory_stores(&self, user: i64) -> anyhow::Result<Vec<(i64, Owner)>>;
    /// The owner of the user's memory `store`.
    fn memory_owner(&self, user: i64, store: i64) -> anyhow::Result<Option<Owner>>;
    /// The chats in the Trash the memory read blocks of.
    fn memory_trashed_chats(&self, store: i64) -> anyhow::Result<Vec<i64>>;
    /// The user's chats with characters of the card `card`, archived and trashed ones too.
    fn card_chats(&self, user: i64, card: i64) -> anyhow::Result<Vec<i64>>;
    /// The chat's characters, by ID and name, in the order they joined.
    fn chat_cast(&self, chat_id: i64) -> anyhow::Result<Vec<(i64, String)>>;
    /// The kept vectors of the memory's texts, by `search::text_hash`.
    fn memory_vectors(&self, store: i64) -> anyhow::Result<HashMap<Vec<u8>, Vec<u8>>>;
    /// Keeps these vectors by hash and lets go of all others of the memory but `keep`.
    fn keep_memory_vectors(
        &self,
        store: i64,
        new: &[(Vec<u8>, Vec<u8>)],
        keep: &[Vec<u8>],
    ) -> anyhow::Result<()>;
    /// Removes the deleted entries from every state.
    fn purge_deleted_memories(&self) -> anyhow::Result<()>;
}

/// A block read, to be kept.
pub struct NewBlock {
    pub chat_id: i64,
    pub block: i64,
    pub chain: String,
    pub state: String,
    pub saved: Vec<String>,
    /// The message whose end had it read, where "Saved to memory" shows.
    pub message_id: Option<i64>,
    pub day_one: Option<i64>,
}

/// The day a moment (ms) falls on, as days since the first day of the era.
fn date(ms: i64) -> i64 {
    // Out of chrono's range only some 262,000 years away, which no message is.
    chrono::DateTime::from_timestamp_millis(ms).map_or(0, |at| {
        i64::from(
            at.with_timezone(&chrono::Local)
                .date_naive()
                .num_days_from_ce(),
        )
    })
}

/// A chat as its memory reads it.
pub struct ChatRead {
    pub chat_id: i64,
    pub user: String,
    pub cast: Vec<String>,
    /// The complete messages with words on the branch, each with its moment.
    pub said: Vec<(Said, i64)>,
    /// Each whole block's chain.
    pub(crate) chains: Vec<String>,
}

/// Who wrote a message, as the memory names them.
fn writer(message: &Message, user: &str, cast: &[(i64, String)]) -> String {
    match message.role {
        Role::User => user.to_string(),
        Role::Assistant => message
            .speaker_id
            .and_then(|id| cast.iter().find(|(c, _)| *c == id))
            .or(cast.first())
            .map_or(String::new(), |(_, name)| name.clone()),
        Role::System => "Narrator".to_string(),
    }
}

/// What the user is called in the chat.
fn user_name(db: &dyn crate::chats::Storage, user: i64, chat: &Chat) -> anyhow::Result<String> {
    Ok(match chats::persona_of(db, user, chat)? {
        Some(persona) => persona.name,
        None => cw_library::settings::user_stand_in(db, user)?.to_string(),
    })
}

/// Whether the memory reads `message`: a finished one with words.
fn is_read(message: &Message) -> bool {
    message.complete && !message.content.trim().is_empty()
}

/// The chat on its branch down to `last` (its head where none), as its memory reads it.
pub fn read_chat(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    last: Option<i64>,
) -> anyhow::Result<ChatRead> {
    let cast = db.chat_cast(chat.id)?;
    let user_name = user_name(db, user, chat)?;
    let path = chats::path_to(db, chat.id, last.or(chat.head_id))?;
    let mut said = Vec::new();
    let mut chains = Vec::new();
    let mut chain = Sha256::new();
    for message in path.iter().filter(|m| is_read(m)) {
        chain.update(message.id.to_le_bytes());
        chain.update(message.speaker_id.unwrap_or(-1).to_le_bytes());
        chain.update([message.role as u8]);
        chain.update(message.content.as_bytes());
        chain.update([0]);
        let n = said.len() as i64 + 1;
        let speaker = writer(message, &user_name, &cast);
        let text = message.content.clone();
        said.push((
            Said {
                n,
                speaker,
                text,
                day: None,
            },
            message.created_at,
        ));
        if said.len() % BLOCK == 0 {
            let done = format!("{:x}", chain.clone().finalize());
            chain = Sha256::new();
            chain.update(done.as_bytes());
            chains.push(done);
        }
    }
    Ok(ChatRead {
        chat_id: chat.id,
        user: user_name,
        cast: cast.into_iter().map(|(_, name)| name).collect(),
        said,
        chains,
    })
}

/// The day of a message at `ms` in a memory whose day 1 is `day_one`; none in roleplay.
fn day(mode: Mode, day_one: Option<i64>, ms: i64) -> Option<i64> {
    (mode != Mode::Roleplay).then(|| (date(ms) - day_one.unwrap_or(date(ms)) + 1).max(1))
}

/// Which of the memory's blocks hold for the chats read: those before the
/// first whose chat is deleted or, of a chat read, no longer one of its whole
/// blocks as it is now. Answers how many hold.
fn holding(blocks: &[Kept], reads: &[&ChatRead]) -> usize {
    blocks
        .iter()
        .position(|kept| match kept.chat_id {
            None => true,
            Some(chat) => reads
                .iter()
                .find(|read| read.chat_id == chat)
                .is_some_and(|read| read.chains.get(kept.block as usize) != Some(&kept.chain)),
        })
        .unwrap_or(blocks.len())
}

/// The chats of `blocks` but `but`, each read down to its head: a memory
/// shared by chats holds a block only while its own chat still holds it.
fn others(
    db: &dyn crate::chats::Storage,
    user: i64,
    blocks: &[Kept],
    but: Option<i64>,
) -> anyhow::Result<Vec<ChatRead>> {
    let mut ids: Vec<i64> = blocks
        .iter()
        .filter_map(|kept| kept.chat_id)
        .filter(|id| Some(*id) != but)
        .collect();
    ids.sort_unstable();
    ids.dedup();
    let mut reads = Vec::new();
    for id in ids {
        if let Some(chat) = chats::get(db, user, id)? {
            reads.push(read_chat(db, user, &chat, None)?);
        }
    }
    Ok(reads)
}

/// How many of `blocks` hold for `read` and the other chats they are of.
fn holding_all(
    db: &dyn crate::chats::Storage,
    user: i64,
    blocks: &[Kept],
    read: Option<&ChatRead>,
) -> anyhow::Result<usize> {
    let others = others(db, user, blocks, read.map(|read| read.chat_id))?;
    let reads: Vec<&ChatRead> = read.into_iter().chain(&others).collect();
    Ok(holding(blocks, &reads))
}

/// The next block a pass reads of the chat, into the memory of `owner`.
pub struct Next {
    pub store: i64,
    /// The block the state is of; none before the first.
    pub after: Option<i64>,
    pub state: String,
    pub block: Block,
    pub new: NewBlock,
    /// The other chats whose blocks were let go, to be read again.
    pub again: Vec<i64>,
}

/// The next block of the chat its memory has not read, after letting go of
/// those that no longer hold; none where every whole block is read.
/// `message_id`: the message whose end has it read.
pub fn next_block(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    (owner, mode): (&Owner, Mode),
    message_id: Option<i64>,
) -> anyhow::Result<Option<Next>> {
    let read = read_chat(db, user, chat, None)?;
    let Some((store, day_one)) = db.memory_store(owner, !read.chains.is_empty())? else {
        return Ok(None);
    };
    let mut blocks = db.memory_blocks(store)?;
    let holds = holding_all(db, user, &blocks, Some(&read))?;
    let mut again = Vec::new();
    if holds < blocks.len() {
        db.forget_memory_blocks(store, blocks[holds].id)?;
        again = blocks[holds..].iter().filter_map(|b| b.chat_id).collect();
        again.retain(|other| *other != chat.id);
        again.sort_unstable();
        again.dedup();
        blocks.truncate(holds);
    }
    let k = blocks.iter().filter(|b| b.chat_id == Some(chat.id)).count();
    let Some(chain) = read.chains.get(k) else {
        return Ok(None);
    };
    let after = blocks.last().map(|b| b.id);
    let state = match after {
        Some(after) => read_form(&db.memory_state(after)?, stand_in(db, user)?)?,
        None => String::new(),
    };
    let taken = &read.said[k * BLOCK..(k + 1) * BLOCK];
    let day_one = day_one.or_else(|| (mode != Mode::Roleplay).then(|| date(taken[0].1)));
    let messages = taken
        .iter()
        .map(|(said, ms)| Said {
            day: day(mode, day_one, *ms),
            ..said.clone()
        })
        .collect();
    Ok(Some(Next {
        store,
        after,
        state,
        block: Block {
            messages,
            user: read.user,
            cast: read.cast,
            mode,
            absent: Vec::new(),
            chat_id: Some(chat.id),
        },
        new: NewBlock {
            chat_id: chat.id,
            block: k as i64,
            chain: chain.clone(),
            state: String::new(),
            saved: Vec::new(),
            message_id,
            day_one,
        },
        again,
    }))
}

/// Keeps the block `next` read, as `added`; false where another was kept meanwhile.
pub fn keep(
    db: &dyn crate::chats::Storage,
    user: i64,
    next: &mut Next,
    added: Added,
) -> anyhow::Result<bool> {
    let state = kept_form(&added.state, stand_in(db, user)?)?;
    let first = next.block.messages.first().map_or(0, |said| said.n);
    next.new.state = changes::held(db, next.store, (next.new.chat_id, first), &state)?;
    next.new.saved = added.saved;
    let kept = db.keep_memory_block(next.store, next.after, &next.new)?;
    // The block is kept all the same: what the search finds of it is written again at its next block or change.
    if let Err(failure) = kept.then(|| index(db, user, next.store)).transpose() {
        tracing::warn!(
            "memory {} cannot be kept for the search: {failure:#}",
            next.store
        );
    }
    Ok(kept)
}

/// Writes the entries of the memory `store` anew as Search Cardwave keeps them (`find`): as Knowledge › Memories
/// shows them (`views`), with who know them, those of chats in the Trash too (the search leaves them out).
pub fn index(db: &dyn crate::chats::Storage, user: i64, store: i64) -> anyhow::Result<()> {
    use cw_search::kept::{Known, Owner as Of, Text};
    let Some(owner) = db.memory_owner(user, store)? else {
        return Ok(());
    };
    let mut texts = Vec::new();
    for view in views(db, user, store, &owner, true)? {
        // As Knowledge › Memories tells it: the user, the last of the names, as "you".
        let known = match &view.known_to {
            Some(known) => {
                let knows = |name: &String| known.contains(&name.to_lowercase());
                let (user, cast) = view.names.split_last().unzip();
                Known::By {
                    names: cast
                        .unwrap_or_default()
                        .iter()
                        .filter(|name| knows(name))
                        .cloned()
                        .collect(),
                    you: user.is_some_and(knows),
                }
            }
            None => Known::Everyone,
        };
        texts.push(Text {
            entry: view.id,
            title: view.text,
            known: Some(known),
            chat_id: Some(view.chat_id),
            ..Default::default()
        });
    }
    db.put_texts(user, Of::Memory(store), &texts)
}

/// What a reply's memory note is made from.
pub struct ToRender {
    pub store: i64,
    pub state: String,
    /// The user's stand-in name the state is read with (`read_form`).
    pub stand_in: &'static str,
    pub ask: Ask,
}

/// What a reply of the chat character `speaker` (the first where none) after
/// the chat `read` (`read_chat` down to its newest message) asks the memory
/// of `owner`; none where it has nothing that holds on the branch (and, of a
/// shared memory, in its other chats as they are now), or there is no message.
pub fn to_render(
    db: &dyn crate::chats::Storage,
    user: i64,
    read: &ChatRead,
    (owner, mode): (&Owner, Mode),
    speaker: Option<i64>,
) -> anyhow::Result<Option<ToRender>> {
    let Some((store, day_one)) = db.memory_store(owner, false)? else {
        return Ok(None);
    };
    let blocks = db.memory_blocks(store)?;
    let holds = holding_all(db, user, &blocks, Some(read))?;
    let (Some(kept), Some((newest, ms))) =
        (holds.checked_sub(1).map(|at| &blocks[at]), read.said.last())
    else {
        return Ok(None);
    };
    let cast = db.chat_cast(read.chat_id)?;
    let speaker = speaker
        .and_then(|id| cast.iter().find(|(c, _)| *c == id))
        .or(cast.first())
        .map_or(String::new(), |(_, name)| name.clone());
    let prev = read
        .said
        .len()
        .checked_sub(2)
        .map(|at| read.said[at].0.line());
    // What a chat in the Trash holds is given to no other.
    let mut trashed = db.memory_trashed_chats(store)?;
    trashed.retain(|chat| *chat != read.chat_id);
    let state = system().without(&db.memory_state(kept.id)?, &trashed)?;
    let user_name = stand_in(db, user)?;
    Ok(Some(ToRender {
        store,
        state: read_form(&state, user_name)?,
        stand_in: user_name,
        ask: Ask {
            query: newest.line(),
            prev,
            speaker,
            mode,
            today: day(mode, day_one, *ms),
            budget: BUDGET,
        },
    }))
}

/// A memory as Knowledge › Memories shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct MemoryView {
    /// Its memory's number and its own, as `<memory>.<entry>`.
    pub id: String,
    /// The chat it was read from, its title and its first character's name.
    pub chat_id: i64,
    pub chat_title: String,
    pub character: String,
    /// When the message it was read from was written (ms); none where that
    /// message is no longer on the chat's branch in view.
    pub said_at: Option<i64>,
    pub kind: Kind,
    pub text: String,
    /// A fact's status: current, open (a promise, task or plan), temporary
    /// (holds until `until`) or done (no longer holds); none of an event.
    pub status: Option<String>,
    pub until: String,
    /// Of the place, its customs, prices or history, which every character knows.
    pub world: bool,
    /// Who know it, lower-case; none where everyone does.
    pub(crate) known_to: Option<Vec<String>>,
    /// Who may know it: the chat's characters, then the user.
    pub names: Vec<String>,
}

/// A change of a memory; what is left out stays.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeMemory {
    pub text: Option<String>,
    /// Who of `names` know it.
    pub(crate) known_to: Option<Vec<String>>,
}

/// The state of `store` that holds now: on the chat's branch in view for a
/// chat's own, on each chat's branch in view for a character's.
fn current(
    db: &dyn crate::chats::Storage,
    user: i64,
    store: i64,
    owner: &Owner,
) -> anyhow::Result<Option<String>> {
    let read = match owner {
        Owner::Chat(chat_id) => match chats::get(db, user, *chat_id)? {
            Some(chat) => Some(read_chat(db, user, &chat, None)?),
            None => return Ok(None),
        },
        Owner::Character(_) => None,
    };
    let blocks = db.memory_blocks(store)?;
    match holding_all(db, user, &blocks, read.as_ref())?.checked_sub(1) {
        Some(at) => Ok(Some(read_form(
            &db.memory_state(blocks[at].id)?,
            stand_in(db, user)?,
        )?)),
        None => Ok(None),
    }
}

/// A chat as its memory's entries show it: the chat, its cast's names and the
/// user's, and when each message it read was written (`said_moments`).
type Shown = (Chat, Vec<String>, Vec<i64>);

/// The entries of `store` as Knowledge › Memories shows them; those of chats in the Trash left out but
/// `trashed_too`.
fn views(
    db: &dyn crate::chats::Storage,
    user: i64,
    store: i64,
    owner: &Owner,
    trashed_too: bool,
) -> anyhow::Result<Vec<MemoryView>> {
    let Some(state) = current(db, user, store, owner)? else {
        return Ok(Vec::new());
    };
    let mut chats: HashMap<i64, Option<Shown>> = HashMap::new();
    let mut out = Vec::new();
    for entry in system().entries(&state)? {
        let Some(chat_id) = entry.chat else { continue };
        if let std::collections::hash_map::Entry::Vacant(slot) = chats.entry(chat_id) {
            let found =
                match chats::get(db, user, chat_id)?.filter(|chat| trashed_too || !chat.trashed) {
                    Some(chat) => {
                        let mut names: Vec<String> = db
                            .chat_cast(chat_id)?
                            .into_iter()
                            .map(|(_, name)| name)
                            .collect();
                        names.push(user_name(db, user, &chat)?);
                        let said = said_moments(db, &chat)?;
                        Some((chat, names, said))
                    }
                    None => None,
                };
            slot.insert(found);
        }
        let Some(Some((chat, names, said))) = chats.get(&chat_id) else {
            continue;
        };
        out.push(MemoryView {
            id: format!("{store}.{}", entry.id),
            chat_id,
            chat_title: chat.title.clone(),
            character: names.first().cloned().unwrap_or_default(),
            said_at: usize::try_from(entry.n - 1)
                .ok()
                .and_then(|at| said.get(at).copied()),
            kind: entry.kind,
            text: entry.text,
            status: entry.status,
            until: entry.until,
            world: entry.world,
            known_to: entry.known_to,
            names: names.clone(),
        });
    }
    Ok(out)
}

/// When each message `read_chat` numbers was written, the first at 0.
fn said_moments(db: &dyn crate::chats::Storage, chat: &Chat) -> anyhow::Result<Vec<i64>> {
    Ok(chats::path_to(db, chat.id, chat.head_id)?
        .iter()
        .filter(|m| is_read(m))
        .map(|m| m.created_at)
        .collect())
}

/// Everything the user's characters remember, the newest first: the memory
/// whose block was read last first, in it the entry set last first.
pub fn list(db: &dyn crate::chats::Storage, user: i64) -> anyhow::Result<Vec<MemoryView>> {
    let mut all = Vec::new();
    for (store, owner) in db.memory_stores(user)? {
        let last = db.memory_blocks(store)?.last().map(|b| b.id);
        let mut views: Vec<(u64, MemoryView)> = views(db, user, store, &owner, false)?
            .into_iter()
            .map(|view| (entry_of(&view.id), view))
            .collect();
        views.sort_by_key(|(entry, _)| std::cmp::Reverse(*entry));
        all.push((last, views));
    }
    all.sort_by_key(|(last, _)| std::cmp::Reverse(*last));
    Ok(all
        .into_iter()
        .flat_map(|(_, views)| views.into_iter().map(|(_, view)| view))
        .collect())
}

/// The entry number of a view's ID `<memory>.<entry>`, which grows as entries are set.
fn entry_of(id: &str) -> u64 {
    // Every ID is made by `views` so; 0 is never reached.
    id.split_once('.')
        .and_then(|(_, entry)| entry.parse().ok())
        .unwrap_or(0)
}

/// The memory and entry numbers of a view's ID, of a memory of the user's.
fn ids(db: &dyn Storage, user: i64, id: &str) -> anyhow::Result<(i64, u64, Owner)> {
    let parsed = id
        .split_once('.')
        .and_then(|(store, entry)| Some((store.parse().ok()?, entry.parse().ok()?)));
    let (store, entry) = parsed.ok_or(NotFound("memory"))?;
    let owner = db.memory_owner(user, store)?.ok_or(NotFound("memory"))?;
    Ok((store, entry, owner))
}

/// One memory of the user's, as Knowledge › Memories shows it.
pub fn view(db: &dyn crate::chats::Storage, user: i64, id: &str) -> anyhow::Result<MemoryView> {
    let (store, _, owner) = ids(db, user, id)?;
    let found = views(db, user, store, &owner, false)?
        .into_iter()
        .find(|v| v.id == id);
    Ok(found.ok_or(NotFound("memory"))?)
}

/// Changes the entry `id` in every state of its memory that has it. Answers whether one had it.
fn change_all(
    db: &dyn crate::chats::Storage,
    user: i64,
    id: &str,
    change: &Change,
) -> anyhow::Result<()> {
    let (store, entry, _) = ids(db, user, id)?;
    let mut last = None;
    let name = stand_in(db, user)?;
    for (block, state) in db.memory_states(store)? {
        if let Some(changed) = system().change(&read_form(&state, name)?, entry, change)? {
            let changed = kept_form(&changed, name)?;
            db.set_memory_state(block, &changed)?;
            last = Some((state, changed));
        }
    }
    let (before, after) = last.ok_or(NotFound("memory"))?;
    changes::note(db, store, entry, (&before, &after), change)?;
    index(db, user, store)
}

/// Changes a memory's text, or who know it: only the names it may have count.
pub fn change(
    db: &dyn crate::chats::Storage,
    user: i64,
    id: &str,
    change: &ChangeMemory,
) -> anyhow::Result<MemoryView> {
    let had = view(db, user, id)?;
    let text = match &change.text {
        Some(text) => {
            let text = cw_ccv4::one_line(text);
            ensure!(
                !text.is_empty(),
                Fail::said(Code::Needed, "a memory needs a text").with("what", "memory_text")
            );
            ensure!(
                text.chars().count() <= TEXT_LIMIT,
                Fail::said(
                    Code::TooLong,
                    format!("a memory has {TEXT_LIMIT} characters at most")
                )
                .with("what", "memory_text")
                .with("text_limit", TEXT_LIMIT)
            );
            Some(text)
        }
        None => None,
    };
    let known_to = change
        .known_to
        .as_ref()
        .map(|names| known_of(&had.names, names));
    let change = Change {
        text,
        known_to,
        deleted: None,
    };
    change_all(db, user, id, &change)?;
    view(db, user, id)
}

/// Who of `may` (a memory's names) are among `asked`, lower-case, each once.
fn known_of(may: &[String], asked: &[String]) -> Vec<String> {
    let mut picked: Vec<String> = Vec::new();
    for name in may.iter().map(|n| n.to_lowercase()) {
        if asked.iter().any(|a| a.to_lowercase() == name) && !picked.contains(&name) {
            picked.push(name);
        }
    }
    picked
}

/// Deletes a memory, which its Undo puts back until the server starts again.
pub fn delete(db: &dyn crate::chats::Storage, user: i64, id: &str) -> anyhow::Result<MemoryView> {
    let had = view(db, user, id)?;
    let deleted = Change {
        deleted: Some(true),
        ..Default::default()
    };
    change_all(db, user, id, &deleted)?;
    Ok(had)
}

/// Puts back a memory that was deleted.
pub fn restore(db: &dyn crate::chats::Storage, user: i64, id: &str) -> anyhow::Result<MemoryView> {
    let back = Change {
        deleted: Some(false),
        ..Default::default()
    };
    change_all(db, user, id, &back)?;
    view(db, user, id)
}

/// The memory of `owner`, where it has one.
pub fn store_of(db: &dyn Storage, owner: &Owner) -> anyhow::Result<Option<i64>> {
    Ok(db.memory_store(owner, false)?.map(|(store, _)| store))
}

/// Removes for good the memories the user deleted: nothing offers their Undo
/// any more once the server starts again.
pub fn purge_deleted(db: &dyn Storage) -> anyhow::Result<()> {
    db.purge_deleted_memories()
}

/// What the chat's memory holds on its branch in view that was read from the
/// chat, for its export: each entry with who know it, by name.
pub fn of_chat(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    owner: &Owner,
) -> anyhow::Result<Vec<(Entry, Vec<String>)>> {
    let Some((store, _)) = db.memory_store(owner, false)? else {
        return Ok(Vec::new());
    };
    let Some(state) = current(db, user, store, owner)? else {
        return Ok(Vec::new());
    };
    let mut names: Vec<String> = db
        .chat_cast(chat.id)?
        .into_iter()
        .map(|(_, name)| name)
        .collect();
    names.push(user_name(db, user, chat)?);
    let named = |lower: &str| {
        names
            .iter()
            .find(|n| n.to_lowercase() == lower)
            .cloned()
            .unwrap_or_else(|| lower.to_string())
    };
    Ok(system()
        .entries(&state)?
        .into_iter()
        .filter(|entry| entry.chat == Some(chat.id))
        .map(|entry| {
            let known = match &entry.known_to {
                Some(who) => who.iter().map(|n| named(n)).collect(),
                None => names.clone(),
            };
            (entry, known)
        })
        .collect())
}

#[cfg(test)]
mod tests;

//! Knowledge › Memories: each memory's entries as the page shows them
//! (`MemoryView`, `list`, `view`), and the user's changes to them (`change`,
//! `delete`, `restore`), each written as a change on the block it holds in.

use std::collections::HashMap;

use anyhow::ensure;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{
    Blocks, Change, Kind, Owner, Storage, TEXT_LIMIT, changes, index, is_read, kept_form,
    owner_name, persona_name, read_chat, read_form, stand_in, system,
};
use crate::chats::{self, Chat};

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
    /// The persona the memory is with, which is the user's name in `names`; none for the user without one.
    pub persona: Option<String>,
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
pub(super) fn current(
    db: &dyn crate::chats::Storage,
    user: i64,
    store: i64,
    owner: &Owner,
) -> anyhow::Result<Option<String>> {
    let read = match owner {
        Owner::Chat(chat_id, _) => match chats::get(db, user, *chat_id)? {
            Some(chat) => Some(read_chat(db, user, &chat, None)?),
            None => return Ok(None),
        },
        Owner::Character(..) => None,
    };
    let memory = Blocks::of(db, store, owner)?;
    match memory.holding_all(db, user, read.as_ref())?.checked_sub(1) {
        Some(at) => Ok(Some(read_form(
            &db.memory_state(memory.kept[at].id)?,
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
pub(super) fn views(
    db: &dyn crate::chats::Storage,
    user: i64,
    store: i64,
    owner: &Owner,
    trashed_too: bool,
) -> anyhow::Result<Vec<MemoryView>> {
    let Some(state) = current(db, user, store, owner)? else {
        return Ok(Vec::new());
    };
    let persona = persona_name(db, user, owner)?;
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
                        names.push(owner_name(db, user, owner)?);
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
            persona: persona.clone(),
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
pub(super) fn known_of(may: &[String], asked: &[String]) -> Vec<String> {
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

//! What the user changed of a memory's entries (Knowledge › Memories: a text,
//! who know it, a deletion), kept beside the memory (`Storage::memory_changes`)
//! so it holds when the entry's block is read again and the helper finds it
//! anew (`held`): an entry the user edited takes the place of what the helper
//! read of it, one deleted stays deleted. A change is found by its kind, chat
//! and text: the helper may word it otherwise, then it is a new entry. All is
//! in a state's kept form (`kept_form`).

use serde::{Deserialize, Serialize};

use super::{Change, Kind, system};

/// What the user changed of one entry.
#[derive(Debug, Serialize, Deserialize)]
struct Record {
    kind: Kind,
    chat: Option<i64>,
    /// The first message of its block (`Entry::n`).
    n: i64,
    /// Its text as the helper read it, and as it is now.
    was: String,
    text: String,
    /// A state holding it alone, as it is now (`Remembers::alone`).
    alone: String,
    edited: bool,
    deleted: bool,
}

fn records(db: &dyn crate::chats::Storage, store: i64) -> anyhow::Result<Vec<Record>> {
    let kept = db.memory_changes(store)?;
    if kept.is_empty() {
        return Ok(Vec::new());
    }
    Ok(serde_json::from_str(&kept)?)
}

fn save(db: &dyn crate::chats::Storage, store: i64, all: &[Record]) -> anyhow::Result<()> {
    db.set_memory_changes(store, &serde_json::to_string(all)?)
}

/// Notes `change` of the entry `entry` of `store`, from the kept state `before` to `after`.
pub(super) fn note(
    db: &dyn crate::chats::Storage,
    store: i64,
    entry: u64,
    (before, after): (&str, &str),
    change: &Change,
) -> anyhow::Result<()> {
    let (Some((had, _)), Some((now, alone))) = (
        system().alone(before, entry)?,
        system().alone(after, entry)?,
    ) else {
        return Ok(());
    };
    let mut all = records(db, store)?;
    let same = |r: &Record| r.kind == had.kind && r.chat == had.chat && r.text == had.text;
    let at = match all.iter().position(same) {
        Some(at) => at,
        None => {
            all.push(Record {
                kind: had.kind,
                chat: had.chat,
                n: had.n,
                was: had.text.clone(),
                text: String::new(),
                alone: String::new(),
                edited: false,
                deleted: false,
            });
            all.len() - 1
        }
    };
    let record = &mut all[at];
    (record.text, record.alone) = (now.text, alone);
    record.edited |= change.text.is_some() || change.known_to.is_some();
    if let Some(deleted) = change.deleted {
        record.deleted = deleted;
    }
    all.retain(|r| r.edited || r.deleted);
    save(db, store, &all)
}

/// The kept state `state` of the block of `chat` that begins with its message
/// `n`, read anew, with what the user changed of the memory `store` held:
/// deleted where found again, an edited entry of this block in place of its new reading.
pub(super) fn held(
    db: &dyn crate::chats::Storage,
    store: i64,
    (chat, n): (i64, i64),
    state: &str,
) -> anyhow::Result<String> {
    let mut state = state.to_string();
    for r in records(db, store)?.iter().filter(|r| r.chat == Some(chat)) {
        let texts = [r.was.clone(), r.text.clone()];
        if r.deleted {
            let again = system().entries(&state)?;
            let gone = Change {
                deleted: Some(true),
                ..Default::default()
            };
            for e in again
                .iter()
                .filter(|e| e.kind == r.kind && texts.contains(&e.text))
            {
                if let Some(changed) = system().change(&state, e.id, &gone)? {
                    state = changed;
                }
            }
        } else if r.n == n {
            state = system().put(&state, &r.alone, &texts)?;
        }
    }
    Ok(state)
}

/// Calls `from` `to` in what the user changed of the memory `store` (`held::rename_in`).
pub(super) fn renamed(
    db: &dyn crate::chats::Storage,
    store: i64,
    from: &str,
    to: &str,
) -> anyhow::Result<()> {
    let mut all = records(db, store)?;
    if all.is_empty() {
        return Ok(());
    }
    for r in &mut all {
        r.was = super::word_renamed(&r.was, from, to);
        r.text = super::word_renamed(&r.text, from, to);
        r.alone = system().renamed(&r.alone, from, to)?;
    }
    save(db, store, &all)
}

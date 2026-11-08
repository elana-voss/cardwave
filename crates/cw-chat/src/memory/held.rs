//! What the user did that a memory's kept states must hold: a character or
//! persona renamed (`rename_in`), which renames it in every state of the
//! memories of its chats: a card's characters by their casts before and after
//! its edit (`casts`, `follow_casts`), a persona by its chats (`rename_persona`).

use super::{Owner, index, system};
use crate::chats;

/// The casts of a card's chats, by chat: each character's ID in the chat and name.
pub type Casts = Vec<(i64, Vec<(i64, String)>)>;

/// The casts of the chats of the card `card`, as they are before its edit
/// (archived and trashed chats too, whose casts the edit renames as well).
pub fn casts(db: &dyn crate::chats::Storage, user: i64, card: i64) -> anyhow::Result<Casts> {
    db.card_chats(user, card)?
        .into_iter()
        .map(|chat| Ok((chat, db.chat_cast(chat)?)))
        .collect()
}

/// Renames in the memories of each chat of `before` a character its card's edit renamed.
pub fn follow_casts(
    db: &dyn crate::chats::Storage,
    user: i64,
    before: &Casts,
) -> anyhow::Result<()> {
    // Each rename once over all its chats: a character's memory reads several
    // chats, and a new name holding the old ("Sam" to "Sam Smith") renamed
    // twice would read "Sam Smith Smith".
    let mut renames: Vec<(&str, String, Vec<i64>)> = Vec::new();
    for (chat, cast) in before {
        let now = db.chat_cast(*chat)?;
        for (id, was) in cast {
            let Some((_, name)) = now.iter().find(|(now, _)| now == id) else {
                continue;
            };
            match renames.iter_mut().find(|(w, n, _)| w == was && n == name) {
                Some((_, _, chats)) => chats.push(*chat),
                None => renames.push((was, name.clone(), vec![*chat])),
            }
        }
    }
    for (was, name, chats) in renames {
        rename_in(db, user, &chats, was, &name)?;
    }
    Ok(())
}

/// Renames the persona `persona`, called `from` until now, in the memories of its chats.
pub fn rename_persona(
    db: &dyn crate::chats::Storage,
    user: i64,
    persona: i64,
    from: &str,
    to: &str,
) -> anyhow::Result<()> {
    if from == to {
        return Ok(());
    }
    let mut of_it = Vec::new();
    for (store, owner) in db.memory_stores(user)? {
        let mut read: Vec<i64> = db
            .memory_blocks(store)?
            .iter()
            .filter_map(|b| b.chat_id)
            .collect();
        if let Owner::Chat(chat) = owner {
            read.push(chat);
        }
        for chat in read {
            let its = chats::get(db, user, chat)?.is_some_and(|c| c.persona_id == Some(persona));
            if its && !of_it.contains(&chat) {
                of_it.push(chat);
            }
        }
    }
    rename_in(db, user, &of_it, from, to)
}

/// Calls `from` `to` in every memory that read a block of `chats` (a renamed
/// character's or persona's chats), in all its states, and writes what the
/// search finds of it anew. The states are renamed in their kept form, in
/// which the user without a persona is a mark, never a name.
pub fn rename_in(
    db: &dyn crate::chats::Storage,
    user: i64,
    chats: &[i64],
    from: &str,
    to: &str,
) -> anyhow::Result<()> {
    if from == to || chats.is_empty() {
        return Ok(());
    }
    for (store, owner) in db.memory_stores(user)? {
        let of_them = match owner {
            Owner::Chat(chat) => chats.contains(&chat),
            Owner::Character(_) => db
                .memory_blocks(store)?
                .iter()
                .any(|b| b.chat_id.is_some_and(|chat| chats.contains(&chat))),
        };
        if !of_them {
            continue;
        }
        for (block, state) in db.memory_states(store)? {
            db.set_memory_state(block, &system().renamed(&state, from, to)?)?;
        }
        super::changes::renamed(db, store, from, to)?;
        index(db, user, store)?;
    }
    Ok(())
}

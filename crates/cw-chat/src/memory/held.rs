//! What the user did that a memory's kept states must hold: a character or
//! persona renamed, which renames it in every state of the memories it is in:
//! a card's characters by their casts before and after its edit (`casts`,
//! `follow_casts`, `rename_in` over their chats), a persona in its own memories
//! (`rename_persona`).

use super::{Owner, index, system};

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
    let mut renames: Renames = Vec::new();
    for (chat, cast) in before {
        let now = db.chat_cast(*chat)?;
        for (id, was) in cast {
            let Some((_, name)) = now.iter().find(|(now, _)| now == id) else {
                continue;
            };
            match renames.iter_mut().find(|(w, n, _)| w == was && n == name) {
                Some((_, _, chats)) => chats.push(*chat),
                None => renames.push((was.clone(), name.clone(), vec![*chat])),
            }
        }
    }
    for (was, name, chats) in at_once(renames) {
        rename_in(db, user, &chats, &was, &name)?;
    }
    Ok(())
}

/// Renames: the name before, the name after, the chats.
type Renames = Vec<(String, String, Vec<i64>)>;

/// The renames of one edit as steps that, one after the other, rename as at
/// once: where a new name is another's old one (two names swapped, or "Ana"
/// to "Bo" while "Bo" becomes "Cy"), each old name first becomes a mark no
/// text holds, then the mark the new name. The mark begins and ends with a
/// letter of a script without spaces, so `word_renamed` replaces it whatever
/// stands beside it.
fn at_once(renames: Renames) -> Renames {
    let clash = renames
        .iter()
        .any(|(_, name, _)| renames.iter().any(|(was, ..)| was == name));
    if !clash {
        return renames;
    }
    let mark = |n: usize| format!("\u{3400}\u{E000}{n}\u{E000}\u{3400}");
    let mut marked = Vec::new();
    let mut named = Vec::new();
    for (n, (was, name, chats)) in renames.into_iter().enumerate() {
        marked.push((was, mark(n), chats.clone()));
        named.push((mark(n), name, chats));
    }
    marked.extend(named);
    marked
}

/// Renames the persona `persona`, called `from` until now, in its memories (the stores with it).
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
    for (store, owner) in db.memory_stores(user)? {
        if owner.persona() == Some(persona) {
            rename_store(db, user, store, from, to)?;
        }
    }
    Ok(())
}

/// Calls `from` `to` in every memory that read a block of `chats` (a renamed
/// character's chats), in all its states, and writes what the search finds of
/// it anew. The states are renamed in their kept form, in which the user
/// without a persona is a mark, never a name.
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
            Owner::Chat(chat, _) => chats.contains(&chat),
            Owner::Character(..) => db
                .memory_blocks(store)?
                .iter()
                .any(|b| b.chat_id.is_some_and(|chat| chats.contains(&chat))),
        };
        if of_them {
            rename_store(db, user, store, from, to)?;
        }
    }
    Ok(())
}

/// Calls `from` `to` in every state of the memory `store`, what the user changed of it and what the search finds.
fn rename_store(
    db: &dyn crate::chats::Storage,
    user: i64,
    store: i64,
    from: &str,
    to: &str,
) -> anyhow::Result<()> {
    for (block, state) in db.memory_states(store)? {
        db.set_memory_state(block, &system().renamed(&state, from, to)?)?;
    }
    super::changes::renamed(db, store, from, to)?;
    index(db, user, store)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn swapped_or_chained_names_are_renamed_as_at_once() {
        let follow = |renames: &[(&str, &str)], text: &str| {
            let renames = renames
                .iter()
                .map(|(was, name)| (was.to_string(), name.to_string(), vec![1]))
                .collect();
            at_once(renames)
                .iter()
                .fold(text.to_string(), |text, (was, name, _)| {
                    super::super::word_renamed(&text, was, name)
                })
        };
        let said = "Ana gave Bo the key.";
        assert_eq!(
            follow(&[("Ana", "Bo"), ("Bo", "Ana")], said),
            "Bo gave Ana the key."
        );
        assert_eq!(
            follow(&[("Ana", "Bo"), ("Bo", "Cy")], said),
            "Bo gave Cy the key."
        );
        assert_eq!(follow(&[("Ana", "Ann")], said), "Ann gave Bo the key.");
    }
}

//! A chat's characters: who is in it, in speaking order by `position`, and
//! adding or removing one. A character's name is kept (`listed_name`), so
//! nothing here reads a card to name it. A reply that drifts into another
//! character's lines is cut at `drift` (`api::generate`).

use std::collections::HashSet;

use anyhow::ensure;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::cards;

use crate::chats::{ensure_kept, listed_name};

/// One character of a chat.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Participant {
    pub id: i64,
    pub position: i64,
    /// The card's version, which is its current one.
    pub version_id: i64,
    /// The card of that version.
    pub card_id: i64,
    /// The character's ID in that card.
    pub character: String,
}

/// What a chat's characters need of the database, which `cw_store::chat_characters` gives.
pub trait Storage {
    fn participants(&self, user: i64, chat_id: i64) -> anyhow::Result<Vec<Participant>>;
    fn speakers(&self, chat_id: i64) -> anyhow::Result<HashSet<i64>>;
    /// Adds the character `character` of the card's version `version_id`,
    /// named `name`, last in speaking order: not where the card is in the
    /// Trash or the chat has it already. The chat character.
    fn add_participant(
        &self,
        chat_id: i64,
        card_id: i64,
        version_id: i64,
        character: &str,
        name: &str,
    ) -> anyhow::Result<anyhow::Result<i64>>;
    /// Takes a character out of a chat as [`remove_character`] says, at once.
    fn remove_participant(&self, user: i64, participant_id: i64) -> anyhow::Result<i64>;
}

/// Where a reply in a chat of several drifts into the lines of another of its
/// characters (`others`, their names): the end of the line before the first
/// line, past the reply's first, that begins with one of the names and a
/// colon (spaces and asterisks before it aside). The reply is cut there.
pub fn drift(reply: &str, others: &[String]) -> Option<usize> {
    reply.match_indices('\n').map(|(at, _)| at).find(|&at| {
        let line = reply[at + 1..].trim_start_matches(|c: char| c.is_whitespace() || c == '*');
        others.iter().any(|name| {
            line.strip_prefix(name.as_str())
                .is_some_and(|rest| rest.starts_with(':'))
        })
    })
}

/// The chat's characters in speaking order.
pub fn participants(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<Vec<Participant>> {
    db.participants(user, chat_id)
}

/// Those of a chat's characters that have written in it: each that a message
/// of the chat names as its speaker, on any branch, a reply in the making too,
/// and none that is deleted.
pub fn written(db: &dyn Storage, chat_id: i64) -> anyhow::Result<HashSet<i64>> {
    db.speakers(chat_id)
}

/// Adds a character of a card of the library to a chat that is there, as its
/// last in speaking order: it replies when it is asked to, and writes no
/// greeting. With it the chat has what its card brings: its lorebooks, those
/// attached to the card, and a place among the card's chats. Taken while a
/// reply is being written. Not in a chat that is in the Trash, not of a card
/// that is there, and not a character the chat has already. Answers with the
/// chat character.
pub fn add_character(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    card_id: i64,
    character: &str,
) -> anyhow::Result<i64> {
    ensure_kept(db, user, chat_id)?;
    ensure!(
        !participants(db, user, chat_id)?.is_empty(),
        Fail::said(Code::NotPossible, "a chat without a character takes none")
            .with("what", "chat_without_character_add")
    );
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    let document = cards::document_of(db, card.version_id)?;
    ensure!(
        document.character(character).is_some(),
        Fail::said(
            Code::NotPossible,
            format!("the card has no character {character:?}")
        )
        .with("what", "card_character")
    );
    let name = listed_name(&document, character);
    db.add_participant(chat_id, card_id, card.version_id, character, &name)?
}

/// Takes a character out of a chat again: one that has written nothing in it
/// (see [`written`]), as a message is under the name of the one who wrote it.
/// A chat keeps one character at least. With the last character of a card the
/// chat lets go what it had left out of that card's lorebooks, and of the
/// library's lorebooks it had through that card alone. Not in a chat that is
/// in the Trash. Answers with the chat.
pub fn remove_character(db: &dyn Storage, user: i64, participant_id: i64) -> anyhow::Result<i64> {
    db.remove_participant(user, participant_id)
}

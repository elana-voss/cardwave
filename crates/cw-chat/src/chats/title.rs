//! A chat names itself once: after the reply that answers the user's first
//! message (in a chat with a character, the second: its greeting tells too
//! little apart), while it is still to be named (`unnamed`: a chat without a
//! character has no title meanwhile, which the page words, one with a character its name),
//! the worker model is asked for a title (`ask`, by the prompt `NAME`) with its
//! first messages, and it is kept (`keep`) unless the user renamed the chat
//! meanwhile. Failing, the next reply asks again; once named, never again.

use anyhow::Context;
use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::Provider;
use cw_provider::{answer, object};
use std::collections::HashSet;
use std::sync::{Arc, Mutex, MutexGuard};

/// The worker model's prompt.
pub const NAME: &str = include_str!("title.txt");
/// The most messages the worker model reads.
const FIRST: usize = 6;
/// The longest a message is shown to it, and the longest title kept, in characters.
const MESSAGE_LIMIT: usize = 1_500;
const TITLE_LIMIT: usize = 60;

/// What naming a chat needs of the database, which `cw_store::chats` gives.
pub trait Storage {
    /// The head of a chat still to be named (`None` while it has no message)
    /// and whether it has a character; none where it is named.
    fn unnamed_head(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<(Option<i64>, bool)>>;
    /// Gives the chat `title`, unless it is named already: whether it did.
    fn name_chat(&self, user: i64, chat_id: i64, title: &str) -> anyhow::Result<bool>;
}

/// The messages of `chat_id` up to the reply named in the head, at most
/// `FIRST` of them, each "User: …", "AI: …" or "Character: …", where it is a
/// chat still to be named whose branch in view has that reply; none otherwise.
pub fn unnamed(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Option<Vec<String>>> {
    let Some((Some(head), with_character)) = db.unnamed_head(user, chat_id)? else {
        return Ok(None);
    };
    let said: Vec<_> = crate::chats::path_to(db, chat_id, Some(head))?
        .into_iter()
        .filter(|m| m.complete && m.role != Role::System && !m.content.trim().is_empty())
        .collect();
    let turns = if with_character { 2 } else { 1 };
    let roles: Vec<Role> = said.iter().map(|m| m.role).collect();
    let Some(end) = exchanged(&roles, turns) else {
        return Ok(None);
    };
    let speaker = if with_character { "Character" } else { "AI" };
    Ok(Some(
        said[end.saturating_sub(FIRST)..end]
            .iter()
            .map(|m| {
                let text: String = m.content.chars().take(MESSAGE_LIMIT).collect();
                match m.role {
                    Role::User => format!("User: {text}"),
                    _ => format!("{speaker}: {text}"),
                }
            })
            .collect(),
    ))
}

/// How many of `roles` hold the first `turns` exchanges, an exchange being the
/// user's messages and the reply that answers them; none before that.
fn exchanged(roles: &[Role], turns: usize) -> Option<usize> {
    let mut done = 0;
    let mut waiting = false;
    for (at, role) in roles.iter().enumerate() {
        if *role == Role::User {
            waiting = true;
        } else if waiting {
            waiting = false;
            done += 1;
            if done >= turns {
                return Some(at + 1);
            }
        }
    }
    None
}

/// The worker model's title for a chat that began with `said`; none where it
/// gave an empty one.
pub async fn ask(
    http: &Http,
    provider: &Provider,
    said: &[String],
) -> anyhow::Result<Option<String>> {
    let prompt = [
        PromptMessage::new(Role::System, NAME),
        PromptMessage::new(
            Role::User,
            format!("<first_messages>\n{}\n</first_messages>", said.join("\n\n")),
        ),
    ];
    let answer = object(&answer(http, provider, &prompt).await?).context(
        Fail::said(Code::ModelAnswer, "the worker model's title cannot be read")
            .with("what", "title"),
    )?;
    Ok(cleaned(answer["title"].as_str().unwrap_or_default()))
}

/// A title as it is kept: on one line, without quotes or a full stop around
/// it, at most `TITLE_LIMIT` characters.
fn cleaned(title: &str) -> Option<String> {
    let line = title.split_whitespace().collect::<Vec<_>>().join(" ");
    let bare =
        line.trim_matches(|c: char| matches!(c, '"' | '\'' | '“' | '”' | '.') || c.is_whitespace());
    let kept: String = bare.chars().take(TITLE_LIMIT).collect();
    let kept = kept.trim_end().to_string();
    (!kept.is_empty()).then_some(kept)
}

/// The chats being titled, one set per server: while a chat is held,
/// `Titles::start` for it answers none, so replies ending together (a chat of
/// several) ask once.
#[derive(Default)]
pub struct Titles(Arc<Mutex<HashSet<(i64, i64)>>>);

/// A chat held while it is titled; dropping it frees the chat.
pub struct Titling(Arc<Mutex<HashSet<(i64, i64)>>>, (i64, i64));

/// The set; a panic while it was held leaves only ids, still sound to use.
fn held(set: &Mutex<HashSet<(i64, i64)>>) -> MutexGuard<'_, HashSet<(i64, i64)>> {
    set.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

impl Titles {
    /// Holds the chat while it is titled; none where it is already.
    pub fn start(&self, user: i64, chat_id: i64) -> Option<Titling> {
        // Not `then_some`: its Titling, built at once, would be dropped while
        // the lock is held, and its drop locks again.
        let free = held(&self.0).insert((user, chat_id));
        free.then(|| Titling(self.0.clone(), (user, chat_id)))
    }

    /// Whether no chat is being titled.
    pub fn is_empty(&self) -> bool {
        held(&self.0).is_empty()
    }
}

impl Drop for Titling {
    fn drop(&mut self) {
        held(&self.0).remove(&self.1);
    }
}

/// Gives the chat `title`, unless it is named already. Answers whether it did.
pub fn keep(db: &dyn Storage, user: i64, chat_id: i64, title: &str) -> anyhow::Result<bool> {
    db.name_chat(user, chat_id, title)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_chat_is_titled_by_one_at_a_time() {
        let titles = Titles::default();
        let first = titles.start(7, 1).unwrap();
        assert!(titles.start(7, 1).is_none());
        assert!(
            titles.start(7, 1).is_none(),
            "a refused start frees nothing"
        );
        assert!(titles.start(7, 2).is_some());
        drop(first);
        assert!(titles.start(7, 1).is_some());
    }

    #[test]
    fn two_messages_before_a_reply_are_one_exchange() {
        use Role::{Assistant as A, User as U};
        assert_eq!(exchanged(&[A, U, U, A], 2), None);
        assert_eq!(exchanged(&[A, U, U, A, U, A], 2), Some(6));
        assert_eq!(exchanged(&[U, A], 1), Some(2));
    }

    #[test]
    fn a_title_is_kept_on_one_line_without_quotes() {
        assert_eq!(
            cleaned(" \"Planning a\n trip.\" ").as_deref(),
            Some("Planning a trip")
        );
        assert_eq!(cleaned("“”"), None);
        assert_eq!(
            cleaned(&"word ".repeat(30)).unwrap().chars().count(),
            TITLE_LIMIT - 1
        );
    }
}

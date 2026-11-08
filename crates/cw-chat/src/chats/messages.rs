//! A chat's messages. They form a tree: a message's children are its swipes
//! and the starts of its branches; `head_id` is the newest of the branch in
//! view. A query down the tree or by ID leaves out a deleted message
//! (`deleted_from is null`, kept for its Undo until the next deletion or the
//! server's start, `purge_deleted`). A message not complete is a reply being written:
//! the chat takes nothing else until it ends (`BUSY`). A reply keeps the lore,
//! the context its prompt took and its parts' tokens (`save_used`), the pages
//! and files it read (`save_reads`), its model and provider (`set_model`) and
//! how long it took (`save_times`): its "Used in this reply" and "Reply statistics".
//! What is stored is `Storage`'s, which `cw_store::chat_messages` gives.

use cw_coding::tools::Read;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::lorebooks;
use cw_prompt::Role;
use serde::Serialize;
use ts_rs::TS;

use anyhow::{bail, ensure};

use crate::chats::{BUSY, Chat, IN_TRASH, Lore, LoreSource, PromptInputs, ensure_idle, get};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Message {
    pub id: i64,
    pub parent_id: Option<i64>,
    pub role: Role,
    /// The participant who wrote it; unset for the user's messages.
    pub speaker_id: Option<i64>,
    pub content: String,
    /// False while the reply is still being generated.
    pub complete: bool,
    pub token_count: Option<usize>,
    pub created_at: i64,
}

/// A message as a chat's screen shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct MessageView {
    #[serde(flatten)]
    pub message: Message,
    /// IDs of this message and its swipes, oldest first.
    pub swipes: Vec<i64>,
    /// The lorebook entries that went into the prompt this reply answers, in
    /// the prompt's order. None on a message that no model wrote.
    pub lore: Vec<Lore>,
    /// What was saved to memory from it, the oldest first ("Saved to memory").
    pub memories: Vec<String>,
    /// Whether it is a picture a model made (`images`), which the chat shows
    /// in its text's place.
    pub picture: bool,
    /// Its own tokens: as the last prompt counted them, else as estimated.
    pub tokens: usize,
    /// The coding task whose card it is (`coding`), which the chat shows in
    /// its text's place.
    pub task_id: Option<i64>,
    /// On a reply, how much of the context the prompt it answers took.
    pub context: Option<ContextUse>,
    /// On a reply, the model it was asked of (`set_model`).
    pub model: Option<String>,
    /// On a reply, whom its model was asked of, in words (`provider::kinds::whose`; empty for a server on this computer).
    pub provider: Option<String>,
    /// On a reply, how long it took (`save_times`).
    pub times: Option<Times>,
    /// On a reply, what its prompt held, part by part ("Sent to the AI").
    pub sent: Option<Sent>,
    /// The pages and files it read with its tools, the first first.
    pub reads: Vec<Read>,
    /// What the user attached to it, the first first (`attachments`).
    pub attachments: Vec<crate::attachments::Attachment>,
}

/// The tokens of a reply's prompt, part by part ("Sent to the AI"): the
/// persona, what memory recalled, the lorebook entries and the chat's
/// messages; all else, the card's texts with what stands around them, is the
/// card's.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, serde::Deserialize, TS)]
#[ts(export)]
pub struct Sent {
    pub card: usize,
    pub persona: usize,
    pub memory: usize,
    pub lorebook: usize,
    pub history: usize,
}

/// How long a reply took, from its model being first asked: to its first
/// word (none where it has none, as a picture alone) and in all, the tools it
/// ran between its rounds with it. A continued reply's are those of its
/// continuation.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, serde::Deserialize, TS)]
#[ts(export)]
pub struct Times {
    #[ts(type = "number | null")]
    pub to_first_word_ms: Option<u64>,
    #[ts(type = "number")]
    pub in_all_ms: u64,
}

/// How much of a model's context a prompt took, in tokens.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct ContextUse {
    pub used: usize,
    pub size: usize,
}

pub struct NewMessage<'a> {
    pub role: Role,
    /// The character speaking, for an assistant message only; the one the
    /// chat began with, which joined first, when unset.
    pub speaker_id: Option<i64>,
    pub content: &'a str,
    pub complete: bool,
}

/// A reply keeps at most this many of the lorebook entries its prompt held.
const MAX_LORE: usize = 64;

/// What a chat's messages need of the database, which `cw_store::chat_messages` gives.
pub trait Storage {
    /// The newest of all messages below `message_id`, that one too.
    fn newest_below(&self, message_id: i64) -> anyhow::Result<i64>;
    /// Ends the incomplete messages of one chat or of all: their IDs, each
    /// with whether the message is still there.
    fn end_unwritten(&self, chat_id: Option<i64>) -> anyhow::Result<Vec<(i64, bool)>>;
    /// Keeps on a reply the lorebook entries its prompt held (JSON), the
    /// context it took and its parts' tokens ([`Sent`], JSON).
    fn keep_used(
        &self,
        user: i64,
        message_id: i64,
        lore: Option<&str>,
        context: ContextUse,
        sent: &str,
    ) -> anyhow::Result<()>;
    /// Keeps on a reply the pages and files it read (JSON), after those it
    /// read before it was continued.
    fn keep_reads(&self, user: i64, message_id: i64, reads: &[Read]) -> anyhow::Result<()>;
    fn append_message(&self, user: i64, chat_id: i64, new: &NewMessage<'_>) -> anyhow::Result<i64>;
    fn add_swipe(
        &self,
        user: i64,
        message_id: i64,
        content: &str,
        complete: bool,
    ) -> anyhow::Result<i64>;
    /// Moves the chat's head as [`set_head`] says: whether it did.
    fn move_head(&self, user: i64, chat_id: i64, message_id: i64) -> anyhow::Result<bool>;
    /// Deletes a message as [`delete_message`] says, with its other versions
    /// where `versions`, else as [`delete_version`] says.
    fn delete_message(&self, user: i64, message_id: i64, versions: bool) -> anyhow::Result<i64>;
    fn restore_messages(&self, user: i64, message_id: i64) -> anyhow::Result<i64>;
    fn purge_deleted_messages(&self) -> anyhow::Result<()>;
    fn reopen(&self, user: i64, chat_id: i64) -> anyhow::Result<Message>;
    /// Replaces a message's text as [`set_content`] says: whether it did.
    fn rewrite_message(&self, user: i64, message_id: i64, content: &str) -> anyhow::Result<bool>;
    /// Whether the message's chat is in the Trash.
    fn message_in_trash(&self, message_id: i64) -> anyhow::Result<bool>;
    fn write_reply(&self, user: i64, message_id: i64, more: &str) -> anyhow::Result<()>;
    /// Ends a reply as [`finish_reply`] says: whether it was removed, none
    /// where there is no such reply being generated.
    fn end_reply(
        &self,
        user: i64,
        message_id: i64,
        content: &str,
        head_before: Option<i64>,
    ) -> anyhow::Result<Option<bool>>;
    fn path_to(&self, chat_id: i64, last: Option<i64>) -> anyhow::Result<Vec<Message>>;
    fn branch(&self, user: i64, chat_id: i64) -> anyhow::Result<(Chat, Vec<MessageView>)>;
    fn view_message(&self, user: i64, message_id: i64) -> anyhow::Result<MessageView>;
    fn swipes(&self, user: i64, message_id: i64) -> anyhow::Result<Vec<Message>>;
    /// Keeps on a reply the model it is asked of and whose it is, in words.
    fn set_model(
        &self,
        user: i64,
        message_id: i64,
        model: &str,
        provider: &str,
    ) -> anyhow::Result<()>;
    /// Keeps on a reply how long it took ([`Times`], JSON).
    fn keep_times(&self, user: i64, message_id: i64, times: &str) -> anyhow::Result<()>;
}

/// Adds a message after the chat's head and makes it the new head. A message
/// that is not complete is a reply being generated: until [`finish_reply`] ends
/// it, the chat takes no other message and its head stays. A chat in the Trash
/// takes none at all.
pub fn append(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    new: &NewMessage<'_>,
) -> anyhow::Result<i64> {
    db.append_message(user, chat_id, new)
}

/// Adds another version of `message_id` beside it (same place, role and
/// speaker) and makes it the chat's head. Not in a chat that is in the Trash.
pub fn add_swipe(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    content: &str,
    complete: bool,
) -> anyhow::Result<i64> {
    db.add_swipe(user, message_id, content, complete)
}

/// Moves the chat's head: to another swipe, another branch, or back to an
/// earlier message, from where the next message starts a new branch. Not in a
/// chat that is in the Trash.
pub fn set_head(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    message_id: i64,
) -> anyhow::Result<()> {
    if !db.move_head(user, chat_id, message_id)? {
        let chat = get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
        ensure!(
            !chat.trashed,
            Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
        );
        ensure_idle(db, chat_id)?;
        bail!(
            Fail::said(Code::NotPossible, "the message is not part of this chat")
                .with("what", "message_not_in_chat")
        );
    }
    Ok(())
}

/// Brings the branch `message_id` belongs to into view, as it was last left: the
/// head moves to the newest of all messages below it.
pub fn show_branch(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    message_id: i64,
) -> anyhow::Result<()> {
    let newest = db.newest_below(message_id)?;
    set_head(db, user, chat_id, newest)
}

/// Deletes a message of the branch in view, with all its versions and all that
/// follows them, and moves the chat's head to the message before it, or to none
/// for the first message. What is deleted stays, hidden, until the chat's next
/// deletion, a character leaving it or the server's start, so that
/// [`restore_messages`] can put it back. Not while a reply is being generated,
/// and not in a chat that is in the Trash. Returns the chat's ID.
pub fn delete_message(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<i64> {
    db.delete_message(user, message_id, true)
}

/// Deletes only the version shown of a message in view, with what follows it,
/// as [`delete_message`] does, and shows the version before it (else the one
/// after it) with the branch last written in below it. A message with no other
/// version is deleted whole.
pub fn delete_version(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<i64> {
    db.delete_message(user, message_id, false)
}

/// Puts back the deletion that took `message_id`: every message it deleted, and
/// the chat's head where it was. What was sent since stays, beside it. Not while
/// a reply is being generated, and not in a chat that is in the Trash. Returns
/// the chat's ID.
pub fn restore_messages(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<i64> {
    db.restore_messages(user, message_id)
}

/// Deletes for good the deleted messages of every chat, at the server's start:
/// the notices that could put them back are gone with the pages.
pub fn purge_deleted(db: &dyn Storage) -> anyhow::Result<()> {
    db.purge_deleted_messages()
}

/// Opens the chat's newest message, a character's reply with text, to be
/// written on: it is a reply being generated again, which keeps the chat busy,
/// until [`finish_reply`] ends it, with what it had at least. Not in a chat
/// that is in the Trash. Returns the message as it was.
pub fn reopen(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<Message> {
    db.reopen(user, chat_id)
}

/// Replaces a message's text. Not while the message is still being generated,
/// and not in a chat that is in the Trash.
pub fn set_content(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    content: &str,
) -> anyhow::Result<()> {
    if !db.rewrite_message(user, message_id, content)? {
        // Not there at all, in a chat in the Trash, or there and not complete.
        view(db, user, message_id)?;
        ensure!(
            !db.message_in_trash(message_id)?,
            Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
        );
        bail!(BUSY);
    }
    Ok(())
}

/// Adds `more` to the text of a reply that is being generated.
pub fn write_reply(db: &dyn Storage, user: i64, message_id: i64, more: &str) -> anyhow::Result<()> {
    db.write_reply(user, message_id, more)
}

/// Ends a reply that was being generated. With text it is a complete message
/// from here on. Without, it is removed and the chat's head goes back to
/// `head_before`. Returns the message if it is still there.
pub fn finish_reply(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    content: &str,
    head_before: Option<i64>,
) -> anyhow::Result<Option<MessageView>> {
    match db.end_reply(user, message_id, content, head_before)? {
        None => Err(NotFound("message").into()),
        Some(true) => Ok(None),
        Some(false) => view(db, user, message_id).map(Some),
    }
}

/// Ends the replies that were being generated when the server last stopped:
/// each is complete as far as it got. One without text is removed; where the
/// chat's head was is not known any more, so it goes to the reply's newest
/// other version, or else to the message the reply answered.
pub fn finish_interrupted(db: &dyn Storage) -> anyhow::Result<()> {
    db.end_unwritten(None)?;
    Ok(())
}

/// Ends the reply in a chat that nothing writes any more, as
/// [`finish_interrupted`] does. Returns each message ended, as it is now, or
/// without it when it was removed.
pub fn finish_abandoned(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Vec<(i64, Option<MessageView>)>> {
    get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    let ended = db.end_unwritten(Some(chat_id))?;
    ended
        .into_iter()
        .map(|(id, kept)| {
            Ok((
                id,
                if kept {
                    Some(view(db, user, id)?)
                } else {
                    None
                },
            ))
        })
        .collect()
}

/// The branch in view: the messages from the first one down to the chat's head.
pub fn path(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Vec<Message>> {
    let chat = get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    path_to(db, chat_id, chat.head_id)
}

/// The messages of the chat from its first one down to `last`.
pub(crate) fn path_to(
    db: &dyn Storage,
    chat_id: i64,
    last: Option<i64>,
) -> anyhow::Result<Vec<Message>> {
    db.path_to(chat_id, last)
}

/// The chat and its branch in view, from the first message down to the head,
/// all read at one moment.
pub fn branch(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<(Chat, Vec<MessageView>)> {
    db.branch(user, chat_id)
}

/// One message as a chat's screen shows it.
pub fn view(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<MessageView> {
    db.view_message(user, message_id)
}

/// A message and its swipes, oldest first.
pub fn swipes(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<Vec<Message>> {
    db.swipes(user, message_id)
}

/// Keeps on a reply the model it is asked of and whose it is, in words.
pub fn set_model(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    model: &str,
    provider: &str,
) -> anyhow::Result<()> {
    db.set_model(user, message_id, model, provider)
}

/// Keeps on a reply how long it took.
pub fn save_times(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    times: Times,
) -> anyhow::Result<()> {
    db.keep_times(user, message_id, &serde_json::to_string(&times)?)
}

/// Keeps on a reply which lorebook entries went into the prompt it answers:
/// `entries` as the build of `inputs` names them, the first [`MAX_LORE`]; how
/// much of the context that prompt took (`context`), and its parts (`sent`).
pub fn save_used(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    inputs: &PromptInputs,
    entries: &[String],
    (context, sent): (ContextUse, Sent),
) -> anyhow::Result<()> {
    let book = inputs
        .character
        .lorebook
        .as_ref()
        .map_or(&[][..], |book| &book.entries);
    let lore: Vec<Lore> = entries
        .iter()
        .filter_map(|key| book.iter().find(|entry| entry.id.as_ref() == Some(key)))
        .take(MAX_LORE)
        .filter_map(|entry| {
            let id = entry.id.as_deref().unwrap_or_default();
            let (source, reference) = match lorebooks::entry_of(id, &inputs.library) {
                Some((book, reference)) => (LoreSource::LorebookId(book), reference),
                None => (LoreSource::CardId(inputs.card_id?), id),
            };
            Some(Lore {
                source,
                reference: reference.to_string(),
                name: entry.name.clone(),
            })
        })
        .collect();
    let lore = (!lore.is_empty())
        .then(|| serde_json::to_string(&lore))
        .transpose()?;
    let sent = serde_json::to_string(&sent)?;
    db.keep_used(user, message_id, lore.as_deref(), context, &sent)
}

/// Keeps on a reply the pages and files it read with its tools.
pub fn save_reads(
    db: &dyn Storage,
    user: i64,
    message_id: i64,
    reads: &[Read],
) -> anyhow::Result<()> {
    if reads.is_empty() {
        return Ok(());
    }
    db.keep_reads(user, message_id, reads)
}

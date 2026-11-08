//! What a user attaches to a message ("Attach picture or document" in the
//! chat's "+"): a picture (PNG, JPEG, WebP), which goes to the chat model with
//! its message, or a document (PDF, Word, text), kept for the chat as "Add
//! document" keeps one (`documents::add`) and shown as a line with its name.
//! One is attached to the chat first and waits (`attach_picture`,
//! `attach_document`), shown over the message field with ×, which takes it off
//! again with its document (`remove`); sending the message takes those it
//! names (`ensure_waiting`, `take`). Those a page left waiting go at the
//! server's start (`purge_waiting`). A message's are its view's
//! `attachments`; its pictures go into its prompt as data URLs (`pictures`).
//!
//! Traps: whether the chat model sees is asked when a picture is attached
//! (`provider::check::sees`), by the provider's refusal, as the models' facts
//! are not known; the handler asks it after `chats::ensure_kept`, before keeping.

use std::collections::HashMap;

use anyhow::ensure;
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::documents::{self, DocumentView, Owner};
use cw_core::NotFound;

/// A message's attachment, as the chat shows it: a picture as a tile, a
/// document as a line with its name.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Attachment {
    pub id: i64,
    /// Its file's name.
    pub name: String,
    pub picture: bool,
}

/// What the attachments need of the database, which `cw_store::attachments` gives.
pub trait Storage {
    /// Keeps an attachment waiting in the chat: none where the chat is not
    /// the user's or is in the Trash.
    fn keep_attachment(
        &self,
        user: i64,
        chat_id: i64,
        name: &str,
        picture: Option<&[u8]>,
        document_id: Option<i64>,
    ) -> anyhow::Result<Option<i64>>;
    /// A picture attached by the user.
    fn attachment_picture(&self, user: i64, id: i64) -> anyhow::Result<Option<Vec<u8>>>;
    /// Removes an attachment that waits: its document, none where it is no
    /// such attachment.
    fn remove_waiting(&self, user: i64, id: i64) -> anyhow::Result<Option<Option<i64>>>;
    /// How many of `ids` wait in the chat.
    fn count_waiting(&self, user: i64, chat_id: i64, ids: &[i64]) -> anyhow::Result<usize>;
    /// Gives the waiting `ids` of the chat to its message.
    fn take_attachments(&self, chat_id: i64, message_id: i64, ids: &[i64]) -> anyhow::Result<()>;
    /// The pictures attached to the messages `ids`, each with its message, the first first.
    fn message_pictures(&self, ids: &[i64]) -> anyhow::Result<Vec<(i64, Vec<u8>)>>;
    fn purge_waiting(&self) -> anyhow::Result<()>;
}

/// The longest name kept, in characters.
const NAME_LIMIT: usize = 200;

/// The type of a picture a chat model is given, from its first bytes: a PNG,
/// a JPEG or a WebP; none for anything else.
pub fn picture_type(file: &[u8]) -> Option<&'static str> {
    match image::guess_format(file).ok()? {
        image::ImageFormat::Png => Some("image/png"),
        image::ImageFormat::Jpeg => Some("image/jpeg"),
        image::ImageFormat::WebP => Some("image/webp"),
        _ => None,
    }
}

fn kept(name: &str) -> String {
    name.trim().chars().take(NAME_LIMIT).collect()
}

/// Keeps a picture (`picture_type`) waiting in the chat; answers it.
pub fn attach_picture(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    name: &str,
    file: &[u8],
) -> anyhow::Result<Attachment> {
    ensure!(
        picture_type(file).is_some(),
        Fail::said(Code::NotReadable, "a picture is a PNG, JPEG or WebP file")
            .with("what", "attachment_picture")
    );
    let name = kept(name);
    let id = db.keep_attachment(user, chat_id, &name, Some(file), None)?;
    let id = id.ok_or(NotFound("chat"))?;
    Ok(Attachment {
        id,
        name,
        picture: true,
    })
}

/// Keeps a document for the chat, as "Add document" does, and waiting in the
/// chat as an attachment; answers both.
pub fn attach_document(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    name: &str,
    file: &[u8],
) -> anyhow::Result<(Attachment, DocumentView)> {
    let text = documents::text_of(name, file)?;
    let document = documents::add(db, user, Owner::Chat(chat_id), name, &text)?;
    let id = db.keep_attachment(user, chat_id, &document.name, None, Some(document.id))?;
    let id = id.ok_or(NotFound("chat"))?;
    let attached = Attachment {
        id,
        name: document.name.clone(),
        picture: false,
    };
    Ok((attached, document))
}

/// A picture attached by the user, with its type.
pub fn picture(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<(&'static str, Vec<u8>)> {
    let data = db
        .attachment_picture(user, id)?
        .ok_or(NotFound("picture"))?;
    Ok((picture_type(&data).unwrap_or("image/png"), data))
}

/// Takes off an attachment that waits, its document with it: whether it had
/// one. One that waits no longer (sent, or let go as the server started) is
/// taken off already, so that the page's × always clears its tile.
pub fn remove(db: &dyn crate::chats::Storage, user: i64, id: i64) -> anyhow::Result<bool> {
    let Some(document) = db.remove_waiting(user, id)? else {
        return Ok(false);
    };
    if let Some(document) = document {
        // The document may have been deleted in Knowledge › Documents meanwhile.
        match documents::delete(db, user, document) {
            Err(error) if !error.is::<NotFound>() => return Err(error),
            _ => {}
        }
    }
    Ok(document.is_some())
}

/// Refuses `ids` of which one does not wait in the chat.
pub fn ensure_waiting(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    ids: &[i64],
) -> anyhow::Result<()> {
    let mut unique = ids.to_vec();
    unique.sort_unstable();
    unique.dedup();
    ensure!(
        unique.len() == ids.len() && db.count_waiting(user, chat_id, ids)? == ids.len(),
        NotFound("attachment")
    );
    Ok(())
}

/// Gives the waiting `ids` (`ensure_waiting`) to the chat's message `message_id`.
pub fn take(db: &dyn Storage, chat_id: i64, message_id: i64, ids: &[i64]) -> anyhow::Result<()> {
    if ids.is_empty() {
        return Ok(());
    }
    db.take_attachments(chat_id, message_id, ids)
}

/// The pictures attached to the messages `ids`, as data URLs, by message.
pub fn pictures(db: &dyn Storage, ids: &[i64]) -> anyhow::Result<HashMap<i64, Vec<String>>> {
    let mut by_message: HashMap<i64, Vec<String>> = HashMap::new();
    for (message, data) in db.message_pictures(ids)? {
        let kind = picture_type(&data).unwrap_or("image/png");
        let url = format!("data:{kind};base64,{}", STANDARD.encode(&data));
        by_message.entry(message).or_default().push(url);
    }
    Ok(by_message)
}

/// Lets go the attachments no message took, as a page that attached them is gone.
pub fn purge_waiting(db: &dyn Storage) -> anyhow::Result<()> {
    db.purge_waiting()
}

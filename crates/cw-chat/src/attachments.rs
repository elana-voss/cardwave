//! What a user attaches to a message ("Attach picture or document" in the
//! chat's "+"): a picture (PNG, JPEG, WebP), which goes to the chat model with
//! its message, or a document (PDF, Word, text), kept for the chat as "Add
//! document" keeps one (`documents::add`) and shown as a line with its name.
//! One is attached to the chat first and waits (`attach_picture`,
//! `attach_document`), shown over the message field with ×, which takes it off
//! again with its document (`remove`); sending the message takes those it
//! names (`ensure_waiting`, `take`). Those waiting stay, across leaving the
//! chat and restarts, and the chat lists them (`waiting`). A message's are its view's
//! `attachments`; its pictures go into its prompt as data URLs (`pictures`),
//! its documents into its reply's whole (`api/memory.rs`'s `recall`).
//!
//! Traps: whether the chat model sees is asked when a picture is attached
//! (`provider::check::sees`), by the provider's refusal, as the models' facts
//! are not known; the handler asks it after `chats::ensure_kept`, before keeping.
//! A picture is kept made `smaller` once, when attached, as it goes whole with each later turn.

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
    /// The documents attached to the user's message, out of the Trash: each
    /// its ID, name and text, the first first.
    fn message_documents(
        &self,
        user: i64,
        message_id: i64,
    ) -> anyhow::Result<Vec<(i64, String, String)>>;
    /// The attachments waiting in the user's chat, the first first.
    fn waiting(&self, user: i64, chat_id: i64) -> anyhow::Result<Vec<Attachment>>;
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

/// The long side an attached picture is kept at most. A picture goes whole with
/// every later turn of its chat, so it is made smaller once, when attached.
/// Anthropic reads at most 1568 px on the long edge on its standard tier and
/// takes 5 MB per picture on Bedrock (docs.claude.com/en/docs/build-with-claude/vision,
/// "Image limits and costs"); OpenAI fits a picture in 2048 x 2048
/// (platform.openai.com/docs/guides/images-vision); Gemini caps a whole request
/// of inline pictures at 20 MB (ai.google.dev/gemini-api/docs/image-understanding).
const LONG_SIDE: u32 = 1568;
/// A picture within [`LONG_SIDE`] and of fewer bytes is kept as it came.
const KEPT_AS_IT_CAME: usize = 3 * 1024 * 1024;
/// A picture of more pixels is kept as it came: read whole, it would take
/// gigabytes. Cameras of phones give 50 million.
const MAX_PIXELS: u64 = 100_000_000;

/// The picture made smaller to be kept: its long side [`LONG_SIDE`] at most,
/// upright, a JPEG or a see-through PNG. `None` to keep it as it came: small
/// enough already, too large to read, or not made smaller by it.
fn smaller(file: &[u8]) -> Option<Vec<u8>> {
    let small = cw_library::thumbnails::scale_down(file, MAX_PIXELS, |(wide, high)| {
        let long = wide.max(high);
        if long <= LONG_SIDE {
            return (file.len() > KEPT_AS_IT_CAME).then_some((wide, high));
        }
        let scaled = |side: u32| (u64::from(side) * u64::from(LONG_SIDE) / u64::from(long)).max(1);
        Some((scaled(wide) as u32, scaled(high) as u32))
    })?;
    (small.len() < file.len()).then_some(small)
}

/// Keeps a picture (`picture_type`) waiting in the chat, made [`smaller`]; answers it.
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
    let smaller = smaller(file);
    let file = smaller.as_deref().unwrap_or(file);
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
/// one. One that waits no longer (sent) is
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

/// The attachments waiting in the user's chat for its next message, so that
/// a page opened again shows their tiles.
pub fn waiting(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Vec<Attachment>> {
    crate::chats::get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    db.waiting(user, chat_id)
}

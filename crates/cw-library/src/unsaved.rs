//! What the user typed and has not saved yet, kept per field (`PUT /api/unsaved/{field}`) so that it survives
//! the window being closed and is brought back when the field shows again: the message field of a chat, a
//! message being edited, a text of a card or of a lorebook entry. A field is named by the page (`chat.12`,
//! `message.40`, `card.3..description`); the server keeps its text as it is and nothing else. An empty text
//! is no unsaved edit: storing one removes the field's. Its rows go with the user; they are in the database,
//! so encrypted like all data.

use anyhow::ensure;
use cw_core::{Code, Fail};

/// The longest name of a field.
pub(crate) const MAX_FIELD: usize = 200;
/// The most signs an unsaved text keeps: at four bytes a sign, it stays under the server's limit of a body.
pub(crate) const MAX_TEXT: usize = 400_000;

/// What the unsaved edits need of the database, which `cw_store::unsaved` gives.
pub trait Storage {
    fn unsaved(&self, user: i64, field: &str) -> anyhow::Result<Option<String>>;
    fn keep_unsaved(&self, user: i64, field: &str, text: &str) -> anyhow::Result<()>;
    fn forget_unsaved(&self, user: i64, field: &str) -> anyhow::Result<()>;
}

/// The unsaved text of `field`, if one is kept.
pub fn get(db: &dyn Storage, user: i64, field: &str) -> anyhow::Result<Option<String>> {
    db.unsaved(user, field)
}

/// Keeps `text` as the unsaved text of `field`, in place of the one before; an empty one removes it.
pub fn keep(db: &dyn Storage, user: i64, field: &str, text: &str) -> anyhow::Result<()> {
    ensure!(
        !field.is_empty() && field.chars().count() <= MAX_FIELD,
        Fail::said(
            Code::TooLong,
            format!("a field's name has 1 to {MAX_FIELD} signs")
        )
        .with("what", "field_name")
        .with("max_field", MAX_FIELD)
    );
    ensure!(
        text.chars().count() <= MAX_TEXT,
        Fail::said(
            Code::TooLong,
            format!("an unsaved text keeps at most {MAX_TEXT} signs")
        )
        .with("what", "unsaved_text")
        .with("max_text", MAX_TEXT)
    );
    if text.is_empty() {
        db.forget_unsaved(user, field)
    } else {
        db.keep_unsaved(user, field, text)
    }
}

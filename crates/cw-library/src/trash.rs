//! The Trash: the cards, chats, personas and lorebooks a user deleted, and
//! the expression packs and 3D figures no card has any more (`expressions`,
//! `figures`). They
//! stay for [`DAYS`] days, in which they can be restored, and are then deleted
//! for good; the user can do that earlier, item by item or all at once. Only
//! what is in the Trash is ever deleted for good.
//!
//! A chat belongs to the cards its characters are from: while one of them is
//! in the Trash, so is the chat. It goes there with the card, comes back with
//! it, and is deleted with it.
//!
//! A persona goes there alone: the chats it is in keep it until it is deleted
//! for good, and go on without one from then. So does a lorebook of the
//! library: the cards it is attached to and the chats that have it keep its
//! entries until then.
//!
//! A new kind of item in the Trash touches `TrashItem`, `list`, its put and
//! restore, `delete_…` and `remove_older` here, and `web/src/views/trash.ts`
//! (`DOORS`, `kindOf`). An item that goes there alone is a pair like
//! `LOREBOOKS`, its table and what one is called, which its module gives to
//! `put` and `restore`, `delete_…` to `remove_alone`, and which stands in the
//! list `remove_older` goes through.

use serde::Serialize;
use ts_rs::TS;

/// How long an item stays in the Trash before it is deleted for good.
pub const DAYS: u32 = 30;
const DAY_MS: i64 = 24 * 60 * 60 * 1000;

/// When what came to the Trash at `trashed_at` is deleted for good.
pub fn deleted_at(trashed_at: i64) -> i64 {
    trashed_at + i64::from(DAYS) * DAY_MS
}

/// One item in the Trash.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[ts(export)]
pub enum TrashItem {
    Card {
        id: i64,
        title: String,
        /// When it was moved to the Trash.
        trashed_at: i64,
        /// Its newest version, which has its picture.
        version_id: i64,
        /// How many chats went to the Trash with it and come back with it.
        chats: u32,
    },
    /// A chat that was deleted by itself. Those that went with their card are
    /// part of the card's item.
    Chat {
        id: i64,
        title: String,
        trashed_at: i64,
        /// The titles of the cards its characters are from, in the order
        /// they joined it, as the list of chats has them.
        cards: Vec<String>,
    },
    Persona {
        id: i64,
        /// Its name.
        title: String,
        trashed_at: i64,
        /// How many chats outside the Trash it is in. They go on without a
        /// persona once it is deleted for good.
        chats: u32,
    },
    Lorebook {
        id: i64,
        /// Its name.
        title: String,
        trashed_at: i64,
        /// How many chats outside the Trash have it, taken along or through
        /// a card. They are without it once it is deleted for good.
        chats: u32,
    },
    /// An expression pack no card has any more, which went there by itself.
    ExpressionPack {
        id: i64,
        /// Its name.
        title: String,
        trashed_at: i64,
    },
    /// A 3D figure no card has any more, which went there by itself.
    Figure {
        id: i64,
        /// Its name.
        title: String,
        trashed_at: i64,
    },
}

impl TrashItem {
    fn trashed_at(&self) -> i64 {
        match self {
            Self::Card { trashed_at, .. }
            | Self::Chat { trashed_at, .. }
            | Self::Persona { trashed_at, .. }
            | Self::Lorebook { trashed_at, .. }
            | Self::ExpressionPack { trashed_at, .. }
            | Self::Figure { trashed_at, .. } => *trashed_at,
        }
    }
}

/// The two kinds of item that go to the Trash alone, each as its table and
/// what one of it is called. The chats a persona is in keep it while it is
/// there, and so do the chats that took a lorebook along.
pub const PERSONAS: (&str, &str) = ("personas", "persona");
pub const LOREBOOKS: (&str, &str) = ("lorebooks", "lorebook");
/// Expression packs go there alone too, when no card has them any more.
pub const EXPRESSIONS: (&str, &str) = ("expression_packs", "expression pack");
/// And so do 3D figures.
pub const FIGURES: (&str, &str) = ("figures", "figure");

/// What the Trash needs of the database, which `cw_store::trash` gives.
pub trait Storage {
    /// What is in the Trash of `user`, the item moved there last first.
    /// Cards, chats, personas, lorebooks, each newest first.
    fn trash_items(&self, user: i64) -> anyhow::Result<Vec<TrashItem>>;
    fn trash_card(&self, user: i64, card_id: i64) -> anyhow::Result<()>;
    fn restore_trashed_card(&self, user: i64, card_id: i64) -> anyhow::Result<()>;
    fn trash_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()>;
    fn restore_trashed_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()>;
    fn trash_item(&self, user: i64, kind: (&str, &'static str), id: i64) -> anyhow::Result<()>;
    fn restore_trashed_item(
        &self,
        user: i64,
        kind: (&str, &'static str),
        id: i64,
    ) -> anyhow::Result<()>;
    fn delete_card(&self, user: i64, card_id: i64) -> anyhow::Result<()>;
    fn delete_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()>;
    fn delete_persona(&self, user: i64, persona_id: i64) -> anyhow::Result<()>;
    fn delete_lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<()>;
    fn delete_expression_pack(&self, user: i64, pack_id: i64) -> anyhow::Result<()>;
    fn delete_figure(&self, user: i64, figure_id: i64) -> anyhow::Result<()>;
    fn remove_trashed_before(&self, user: Option<i64>, before: i64) -> anyhow::Result<usize>;
}

/// What is in the Trash of `user`, the item moved there last first.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<TrashItem>> {
    let mut items = db.trash_items(user)?;
    // Stable: what was trashed in the same moment stays as read, cards first.
    items.sort_by_key(|item| std::cmp::Reverse(item.trashed_at()));
    Ok(items)
}

/// Moves a card to the Trash, and with it the chats its characters are in.
/// One that is there already stays as it is: its days are not counted anew.
pub(crate) fn put_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<()> {
    db.trash_card(user, card_id)
}

/// Takes a card back out of the Trash, and the chats that went there with it.
/// A chat with another card that is still in the Trash waits for that one.
pub(crate) fn restore_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<()> {
    db.restore_trashed_card(user, card_id)
}

/// Moves a chat to the Trash. One that is there already keeps its days, but
/// from now on it was deleted by itself: it no longer comes back with its card.
pub fn put_chat(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<()> {
    db.trash_chat(user, chat_id)
}

/// Takes a chat back out of the Trash. Not while one of its cards is there.
pub fn restore_chat(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<()> {
    db.restore_trashed_chat(user, chat_id)
}

/// Moves an item that goes there alone to the Trash. One that is there
/// already stays as it is: its days are not counted anew.
pub fn put(
    db: &dyn Storage,
    user: i64,
    (table, what): (&str, &'static str),
    id: i64,
) -> anyhow::Result<()> {
    db.trash_item(user, (table, what), id)
}

/// Takes an item that went there alone back out of the Trash.
pub fn restore(
    db: &dyn Storage,
    user: i64,
    (table, what): (&str, &'static str),
    id: i64,
) -> anyhow::Result<()> {
    db.restore_trashed_item(user, (table, what), id)
}

/// Deletes a card for good, with all its versions and the chats its
/// characters are in. It has to be in the Trash.
pub fn delete_card(db: &dyn Storage, user: i64, card_id: i64) -> anyhow::Result<()> {
    db.delete_card(user, card_id)
}

/// Deletes a chat for good, with its messages. It has to be in the Trash.
pub fn delete_chat(db: &dyn Storage, user: i64, chat_id: i64) -> anyhow::Result<()> {
    db.delete_chat(user, chat_id)
}

/// Deletes a persona for good. It has to be in the Trash. The chats it was
/// in go on without a persona, and it is no longer anyone's default.
pub fn delete_persona(db: &dyn Storage, user: i64, persona_id: i64) -> anyhow::Result<()> {
    db.delete_persona(user, persona_id)
}

/// Deletes a lorebook for good. It has to be in the Trash. The cards it was
/// attached to and the chats that had it are without it from the next reply on.
pub fn delete_lorebook(db: &dyn Storage, user: i64, lorebook_id: i64) -> anyhow::Result<()> {
    db.delete_lorebook(user, lorebook_id)
}

/// Deletes an expression pack for good, with its pictures. It has to be in the Trash.
pub fn delete_expression_pack(db: &dyn Storage, user: i64, pack_id: i64) -> anyhow::Result<()> {
    db.delete_expression_pack(user, pack_id)
}

/// Deletes a 3D figure for good, with its file and still. It has to be in the Trash.
pub fn delete_figure(db: &dyn Storage, user: i64, figure_id: i64) -> anyhow::Result<()> {
    db.delete_figure(user, figure_id)
}

/// Deletes for good what has been in the Trash since before `before`: of one
/// user, or of all. Returns how many items went. What a reply is being written
/// in is left for the next time.
fn remove_older(db: &dyn Storage, user: Option<i64>, before: i64) -> anyhow::Result<usize> {
    db.remove_trashed_before(user, before)
}

/// Deletes all that is in the Trash of `user` for good.
pub fn empty(db: &dyn Storage, user: i64) -> anyhow::Result<usize> {
    remove_older(db, Some(user), i64::MAX)
}

/// Deletes for good what has been in the Trash for [`DAYS`] days at the time
/// `now`, whoever it belongs to. Run when the server starts and every hour.
pub fn purge(db: &dyn Storage, now: i64) -> anyhow::Result<usize> {
    remove_older(db, None, now - i64::from(DAYS) * DAY_MS)
}

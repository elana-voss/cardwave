//! "Describe all again" (Settings › Advanced): every character not in the Trash gets its description and
//! its needs anew, one character at a time, its two calls together.
//!
//! Its waiting is apart from `card_descriptions` and `card_needs` (`cw_store::again`), so what a card holds
//! stands, and shows, until the new result has come; a failure or a refusal keeps it. A summary or title the
//! user edited stays. Stop drops what still waits and nothing else of the queue; the character in hand
//! finishes both calls. Pressing it again starts over from all, a character in hand too. The worker is
//! `api/describe.rs`, which takes this after all that is queued, but finishes a character's needs first.

use anyhow::Result;
use cw_core::ErrorBody;
use serde::Serialize;
use ts_rs::TS;

use crate::failures::Failures;
use crate::{describe, needs};

/// How far describing the characters again has come.
#[derive(Debug, Serialize, TS)]
#[ts(export)]
pub struct DescribingAgain {
    /// The characters it would describe: all those not in the Trash.
    pub characters: usize,
    /// Those that still wait, the one in hand among them; after Stop, none.
    pub waiting: usize,
    /// Those whose turn has passed since it was last pressed, the failed among them.
    pub done: usize,
    pub failed: usize,
    /// Why the last of those failed, as the UI words it.
    pub failure: Option<ErrorBody>,
}

/// What describing again asks of the database, which `cw_store::again` gives.
pub trait Storage: Failures {
    /// As [`start`] says.
    fn start_describing_again(&self, user: i64) -> Result<usize>;
    /// As [`stop`] says.
    fn stop_describing_again(&self, user: i64) -> Result<()>;
    /// As [`progress`] says.
    fn describing_again(&self, user: i64) -> Result<DescribingAgain>;
    /// As [`needs_in_hand`] says.
    fn needs_in_hand_again(&self, user: i64) -> Result<Option<(i64, i64)>>;
    /// As [`next`] says.
    fn next_to_describe_again(&self, user: i64) -> Result<Option<(i64, i64)>>;
    fn keep_description_again(
        &self,
        card_id: i64,
        version_id: i64,
        stored: describe::Stored,
    ) -> Result<()>;
    fn keep_needs_again(&self, card_id: i64, version_id: i64, stored: needs::Stored) -> Result<()>;
}

/// Has every character not in the Trash described again, from all of them: how many.
pub fn start(db: &dyn Storage, user: i64) -> Result<usize> {
    db.start_describing_again(user)
}

/// Drops what still waits; what else is queued, and the character in hand, go on.
pub fn stop(db: &dyn Storage, user: i64) -> Result<()> {
    db.stop_describing_again(user)
}

pub fn progress(db: &dyn Storage, user: i64) -> Result<DescribingAgain> {
    db.describing_again(user)
}

/// The character whose description has come and whose needs are next, with its newest version. One put in
/// the Trash while it waited is let go, here, since the worker asks this first.
pub fn needs_in_hand(db: &dyn Storage, user: i64) -> Result<Option<(i64, i64)>> {
    db.needs_in_hand_again(user)
}

/// The next character to describe again, with its newest version; it is in hand from here on.
pub fn next(db: &dyn Storage, user: i64) -> Result<Option<(i64, i64)>> {
    db.next_to_describe_again(user)
}

/// Stores what came of describing the character; the old stays where that is no description.
pub fn keep_description(
    db: &dyn Storage,
    card_id: i64,
    version_id: i64,
    outcome: Result<describe::Outcome>,
) -> Result<()> {
    db.keep_description_again(card_id, version_id, describe::stored(db, outcome))
}

/// Stores what came of asking the character's needs; the old stays where that is no answer.
pub fn keep_needs(
    db: &dyn Storage,
    card_id: i64,
    version_id: i64,
    outcome: Result<needs::Outcome>,
) -> Result<()> {
    db.keep_needs_again(card_id, version_id, needs::stored(db, outcome))
}

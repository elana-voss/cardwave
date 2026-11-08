//! What the app holds once and cards share (expression packs, 3D figures) as SQLite keeps it: a row per item of a
//! user in its own table, kept once by its content's `hash`, with `trashed_at`. It goes to the Trash by itself when
//! no card has it any more, and comes out when a card is given it. Each table is one [`Held`].

use cw_core::{Code, Fail};
use rusqlite::{Connection, OptionalExtension, params};

use cw_core::{NotFound, now_ms};

/// A table of held items.
pub(super) struct Held {
    pub table: &'static str,
    /// SQL that is true where a card has the item `?1`, the cards in the Trash counted; it binds no other.
    pub used: &'static str,
    /// What one is called in an answer: "figure".
    pub(crate) noun: &'static str,
}

impl Held {
    /// The item of `user` whose content is `hash`, where one is held.
    pub fn kept(&self, conn: &Connection, user: i64, hash: &[u8]) -> rusqlite::Result<Option<i64>> {
        conn.query_row(
            &format!(
                "select id from {} where user_id = ?1 and hash = ?2",
                self.table
            ),
            params![user, hash],
            |r| r.get(0),
        )
        .optional()
    }

    /// Moves the item to the Trash where no card has it any more.
    pub(crate) fn trash_if_unused(
        &self,
        conn: &Connection,
        id: Option<i64>,
    ) -> rusqlite::Result<()> {
        conn.execute(
            &format!(
                "update {} set trashed_at = coalesce(trashed_at, ?2) where id = ?1 and not ({})",
                self.table, self.used
            ),
            params![id, now_ms()],
        )?;
        Ok(())
    }

    /// Takes the item of `user` out of the Trash, as a card is given it; `NotFound` where there is no such item.
    pub(crate) fn untrash(
        &self,
        conn: &Connection,
        user: i64,
        id: i64,
    ) -> rusqlite::Result<anyhow::Result<()>> {
        let found = conn.execute(
            &format!(
                "update {} set trashed_at = null where id = ?1 and user_id = ?2",
                self.table
            ),
            [id, user],
        )?;
        Ok(if found == 0 {
            Err(NotFound(self.noun).into())
        } else {
            Ok(())
        })
    }

    /// Moves the item of `user` to the Trash or out; one a card has stays out.
    pub fn set_trashed(
        &self,
        conn: &Connection,
        user: i64,
        id: i64,
        trashed: bool,
    ) -> rusqlite::Result<anyhow::Result<()>> {
        let used: Option<bool> = conn
            .query_row(
                &format!(
                    "select {} from {} where id = ?1 and user_id = ?2",
                    self.used, self.table
                ),
                [id, user],
                |r| r.get(0),
            )
            .optional()?;
        match used {
            None => return Ok(Err(NotFound(self.noun).into())),
            Some(true) if trashed => {
                return Ok(Err(anyhow::anyhow!(
                    Fail::said(
                        Code::NotNow,
                        format!("a card has this {}; take it off the card first", self.noun)
                    )
                    .with("what", "held_by_card")
                    .with("noun", (self.noun).to_string())
                )));
            }
            Some(_) => {}
        }
        let at = trashed.then(now_ms);
        conn.execute(
            &format!(
                "update {} set trashed_at = case when ?2 is null then null else coalesce(trashed_at, ?2) end
                 where id = ?1",
                self.table
            ),
            params![id, at],
        )?;
        Ok(Ok(()))
    }
}

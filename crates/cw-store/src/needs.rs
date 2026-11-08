//! Cards' needs as SQLite keeps them (`needs::Storage`): `card_needs`, a row per card from its queueing on,
//! its `state` queued, asked, refused or failed, `levels` the found needs as JSON. `describe.rs` queues,
//! counts and lets go of these rows together with the descriptions'. "Describe all again" keeps its own (`again.rs`).

use cw_core::now_ms;
use cw_library::needs::{Storage, Stored};
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn queue_needs(&self, user: i64, only: Option<i64>) -> anyhow::Result<usize> {
        Ok(self.with(|conn| queued(conn, user, only))?)
    }

    fn queue_lacking_needs(&self, user: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into card_needs (card_id, state, updated_at)
                 select c.id, 'queued', ?2 from cards c
                 join card_descriptions d on d.card_id = c.id and d.state = 'described'
                 where c.user_id = ?1 and c.trashed_at is null
                   and not exists (select 1 from card_needs n where n.card_id = c.id)",
                params![user, now_ms()],
            )
        })?)
    }

    fn users_lacking_needs(&self) -> anyhow::Result<Vec<i64>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select distinct c.user_id from cards c
                 join card_descriptions d on d.card_id = c.id and d.state = 'described'
                 where c.trashed_at is null
                   and not exists (select 1 from card_needs n where n.card_id = c.id)",
            )?
            .query_map([], |r| r.get(0))?
            .collect()
        })?)
    }

    fn next_for_needs(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
        Ok(self.with(|conn| {
            conn.execute(
                "delete from card_needs where state = 'queued'
                   and card_id in (select id from cards where user_id = ?1 and trashed_at is not null)",
                [user],
            )?;
            conn.query_row(
                    "select c.id, (select v.id from card_versions v where v.card_id = c.id order by v.number desc limit 1)
                     from card_needs n join cards c on c.id = n.card_id
                     where c.user_id = ?1 and n.state = 'queued' order by n.updated_at, n.card_id limit 1",
                    [user],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
            .optional()
        })?)
    }

    fn keep_needs(&self, card_id: i64, version_id: i64, stored: Stored) -> anyhow::Result<()> {
        let (state, levels, reason) = match stored {
            Stored::Asked(levels) => ("asked", levels, String::new()),
            Stored::Ended(state, reason) => (state, "[]".to_string(), reason),
        };
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "insert into card_needs (card_id, state, version_id, levels, reason, updated_at)
                 select id, ?2, ?3, ?4, ?5, ?6 from cards where id = ?1
                 on conflict (card_id) do update set state = excluded.state, version_id = excluded.version_id,
                    levels = excluded.levels, reason = excluded.reason, updated_at = excluded.updated_at
                 where excluded.state <> 'failed' or card_needs.state not in ('asked', 'refused')",
                params![card_id, state, version_id, levels, reason, now_ms()],
            )?;
            tx.commit()
        })?;
        Ok(())
    }

    fn needs_of(&self, card_id: i64) -> anyhow::Result<Option<(String, String)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select state, levels from card_needs where card_id = ?1",
                [card_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn needs_of_user(&self, user: i64) -> anyhow::Result<Vec<(i64, String, String)>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select n.card_id, n.state, n.levels from card_needs n join cards c on c.id = n.card_id
                 where c.user_id = ?1 and c.trashed_at is null",
            )?
            .query_map([user], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect()
        })?)
    }
}

/// Queues the user's cards (with `only`, that one) whose needs are not asked or failed, unless the describer
/// refused the card: how many.
pub(crate) fn queued(conn: &Connection, user: i64, only: Option<i64>) -> rusqlite::Result<usize> {
    conn.execute(
        "insert into card_needs (card_id, state, updated_at)
         select c.id, 'queued', ?2 from cards c
         left join card_needs n on n.card_id = c.id
         left join card_descriptions d on d.card_id = c.id
         where c.user_id = ?1 and c.trashed_at is null and (?3 is null or c.id = ?3)
           and (n.state is null or n.state = 'failed') and d.state is not 'refused'
         on conflict (card_id) do update set state = 'queued', reason = '', updated_at = excluded.updated_at",
        params![user, now_ms(), only],
    )
}

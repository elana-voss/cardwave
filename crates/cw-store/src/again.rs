//! "Describe all again" as SQLite keeps it (`again::Storage`): `card_redos`, a row per character since it was
//! last pressed, its `state` waiting, describing, needs, read or failed. `card_descriptions` and `card_needs`
//! move only when a result has come, so the old stands until then. Each move of a row names the state it
//! expects: a press while a call is out makes the row `waiting`, and that call's end then moves nothing.
//! `stopped` is a character in hand when Stop came: it finishes, and no longer counts as waiting.

use cw_core::now_ms;
use cw_library::again::{DescribingAgain, Storage};
use cw_library::{describe, needs};
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

/// The user's first row in `state`, with its card's newest version.
fn in_state(conn: &Connection, user: i64, state: &str) -> rusqlite::Result<Option<(i64, i64)>> {
    conn.query_row(
        "select c.id, (select v.id from card_versions v where v.card_id = c.id order by v.number desc limit 1)
         from card_redos r join cards c on c.id = r.card_id
         where c.user_id = ?1 and r.state = ?2 order by r.card_id limit 1",
        params![user, state],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )
    .optional()
}

/// Moves the row from the state it was in; a row pressed anew meanwhile stays as it is.
fn advance(conn: &Connection, card_id: i64, from: &str, to: &str) -> rusqlite::Result<usize> {
    conn.execute(
        "update card_redos set state = ?3 where card_id = ?1 and state = ?2",
        params![card_id, from, to],
    )
}

/// A description that came to nothing: stored where the card has none or a failed one, else the old stays.
fn keep_ended(
    conn: &Connection,
    card_id: i64,
    version_id: i64,
    state: &str,
    reason: &str,
) -> rusqlite::Result<usize> {
    conn.execute(
        "insert into card_descriptions (card_id, state, version_id, reason, updated_at)
         select id, ?2, ?3, ?4, ?5 from cards where id = ?1
         on conflict (card_id) do update set state = excluded.state, reason = excluded.reason,
            updated_at = excluded.updated_at
         where card_descriptions.state = 'failed'",
        params![card_id, state, version_id, reason, now_ms()],
    )
}

impl Storage for Db {
    fn start_describing_again(&self, user: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "delete from card_redos where card_id in (select id from cards where user_id = ?1)",
                [user],
            )?;
            let waiting = tx.execute(
                "insert into card_redos (card_id, state)
                 select id, 'waiting' from cards where user_id = ?1 and trashed_at is null",
                [user],
            )?;
            tx.commit()?;
            Ok::<_, rusqlite::Error>(waiting)
        })?)
    }

    fn stop_describing_again(&self, user: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "delete from card_redos where state = 'waiting'
                   and card_id in (select id from cards where user_id = ?1)",
                [user],
            )?;
            conn.execute(
                "update card_redos set stopped = 1 where state in ('describing', 'needs')
                   and card_id in (select id from cards where user_id = ?1)",
                [user],
            )
        })?;
        Ok(())
    }

    fn describing_again(&self, user: i64) -> anyhow::Result<DescribingAgain> {
        Ok(self.with(|conn| {
            let characters: i64 = conn.query_row(
                "select count(*) from cards where user_id = ?1 and trashed_at is null",
                [user],
                |r| r.get(0),
            )?;
            let (waiting, read, failed): (i64, i64, i64) = conn.query_row(
                "select count(*) filter (where r.state in ('waiting', 'describing', 'needs') and not r.stopped),
                        count(*) filter (where r.state = 'read'),
                        count(*) filter (where r.state = 'failed')
                 from card_redos r join cards c on c.id = r.card_id
                 where c.user_id = ?1 and c.trashed_at is null",
                [user],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )?;
            let failure = conn
                .query_row(
                    "select r.reason from card_redos r join cards c on c.id = r.card_id
                     where c.user_id = ?1 and c.trashed_at is null and r.state = 'failed'
                     order by r.card_id desc limit 1",
                    [user],
                    |r| r.get(0),
                )
                .optional()?;
            Ok::<_, rusqlite::Error>(DescribingAgain {
                characters: characters as usize,
                waiting: waiting as usize,
                done: (read + failed) as usize,
                failed: failed as usize,
                // Kept as JSON by `describe::kept_failure`.
                failure: failure.and_then(|kept: String| serde_json::from_str(&kept).ok()),
            })
        })?)
    }

    fn needs_in_hand_again(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
        Ok(self.with(|conn| {
            conn.execute(
                "delete from card_redos where state in ('waiting', 'describing', 'needs')
                   and card_id in (select id from cards where user_id = ?1 and trashed_at is not null)",
                [user],
            )?;
            in_state(conn, user, "needs")
        })?)
    }

    fn next_to_describe_again(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
        Ok(self.with(|conn| {
            // One still in hand is one whose call ended without its result being kept: taken again.
            let next = match in_state(conn, user, "describing")? {
                Some(next) => Some(next),
                None => in_state(conn, user, "waiting")?,
            };
            if let Some((card_id, _)) = next {
                advance(conn, card_id, "waiting", "describing")?;
            }
            Ok::<_, rusqlite::Error>(next)
        })?)
    }

    fn keep_description_again(
        &self,
        card_id: i64,
        version_id: i64,
        stored: describe::Stored,
    ) -> anyhow::Result<()> {
        let now = now_ms();
        self.with(|conn| {
            let tx = conn.transaction()?;
            match &stored {
                describe::Stored::Described { .. } => {
                    // A refusal lifted: its needs are no reading to keep, so a failure of the new says so.
                    tx.execute(
                        "delete from card_needs where card_id = ?1 and state = 'refused'",
                        [card_id],
                    )?;
                    crate::describe::described(&tx, card_id, version_id, &stored, now)?;
                    advance(&tx, card_id, "describing", "needs")?;
                }
                describe::Stored::Ended("refused", reason) => {
                    keep_ended(&tx, card_id, version_id, "refused", reason)?;
                    // Its needs are not asked, so they end here; only a refused card's say refused.
                    tx.execute(
                        "insert into card_needs (card_id, state, reason, updated_at)
                         select card_id, 'refused', ?2, ?3 from card_descriptions
                         where card_id = ?1 and state = 'refused'
                         on conflict (card_id) do update set state = 'refused', levels = '[]',
                            reason = excluded.reason, updated_at = excluded.updated_at
                         where card_needs.state = 'failed'",
                        params![card_id, reason, now],
                    )?;
                    advance(&tx, card_id, "describing", "read")?;
                }
                describe::Stored::Ended(state, reason) => {
                    keep_ended(&tx, card_id, version_id, state, reason)?;
                    tx.execute(
                        "update card_redos set state = 'needs', reason = ?2
                         where card_id = ?1 and state = 'describing'",
                        params![card_id, reason],
                    )?;
                }
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn keep_needs_again(
        &self,
        card_id: i64,
        version_id: i64,
        stored: needs::Stored,
    ) -> anyhow::Result<()> {
        let (state, levels, reason) = match stored {
            needs::Stored::Asked(levels) => ("asked", levels, String::new()),
            needs::Stored::Ended(state, reason) => (state, "[]".to_string(), reason),
        };
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "insert into card_needs (card_id, state, version_id, levels, reason, updated_at)
                 select id, ?2, ?3, ?4, ?5, ?6 from cards where id = ?1
                 on conflict (card_id) do update set state = excluded.state, version_id = excluded.version_id,
                    levels = excluded.levels, reason = excluded.reason, updated_at = excluded.updated_at
                 where excluded.state = 'asked' or card_needs.state = 'failed'",
                params![card_id, state, version_id, levels, reason, now_ms()],
            )?;
            // Failed if this did, or the description before it, whose reason stays unless this has its own.
            tx.execute(
                "update card_redos set reason = case when ?2 = 'failed' then ?3 else reason end,
                    state = case when ?2 = 'failed' or reason <> '' then 'failed' else 'read' end
                 where card_id = ?1 and state = 'needs'",
                params![card_id, state, reason],
            )?;
            // "Describe cards" took the card up meanwhile: what comes of it is told there.
            tx.execute(
                "delete from card_redos where card_id = ?1 and state = 'failed' and (
                    exists (select 1 from card_descriptions d where d.card_id = ?1 and d.state = 'queued')
                    or exists (select 1 from card_needs n where n.card_id = ?1 and n.state = 'queued'))",
                [card_id],
            )?;
            tx.commit()
        })?;
        Ok(())
    }
}

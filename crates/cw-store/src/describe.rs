//! Cards' descriptions as SQLite keeps them (`describe::Storage`):
//! `card_descriptions`, a row per card from its queueing on, its `state`
//! queued, described, refused or failed. What waits and has failed counts a
//! card's needs (`needs.rs`) too: the same worker takes both, the same button
//! queues both, and the describer's refusal stands for its needs as well. What
//! waits to be described again (`card_redos`, `again.rs`) ends here with what is queued. A card whose redo
//! failed is told by that alone, one red line for one failure, until "Describe cards" takes it up.

use cw_core::now_ms;
use cw_library::describe::{Describing, Storage, Stored};
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

fn set_state(
    conn: &Connection,
    card_id: i64,
    state: &str,
    reason: &str,
    now: i64,
) -> rusqlite::Result<usize> {
    conn.execute(
        "update card_descriptions set state = ?2, reason = ?3, updated_at = ?4 where card_id = ?1",
        params![card_id, state, reason, now],
    )
}

/// Stores a description, where it is one: a card may have no row yet, a summary or title the user edited stays.
pub(crate) fn described(
    conn: &Connection,
    card_id: i64,
    version_id: i64,
    stored: &Stored,
    now: i64,
) -> rusqlite::Result<()> {
    let Stored::Described {
        tags,
        terms,
        facets,
        title,
        logline,
        summary,
        tagline,
        mood,
    } = stored
    else {
        return Ok(());
    };
    conn.execute(
        "insert into card_descriptions (card_id, state, version_id, tags, terms, facets, logline, summary, reason, updated_at, tagline, mood)
         select id, 'described', ?2, ?3, ?4, ?5, ?6, ?7, '', ?8, ?9, ?10 from cards where id = ?1
         on conflict (card_id) do update set state = 'described', version_id = excluded.version_id,
            tags = excluded.tags, terms = excluded.terms, facets = excluded.facets, logline = excluded.logline,
            summary = case when card_descriptions.summary_edited then card_descriptions.summary else excluded.summary end,
            reason = '', updated_at = excluded.updated_at, tagline = excluded.tagline, mood = excluded.mood",
        params![card_id, version_id, tags, terms, facets, logline, summary, now, tagline, mood],
    )?;
    if !title.is_empty() {
        conn.execute(
            "update cards set title = ?2 where id = ?1 and not title_edited",
            params![card_id, title],
        )?;
    }
    Ok(())
}

impl Storage for Db {
    fn queue_descriptions(&self, user: i64, only: Option<i64>) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            let described = conn.execute(
                "insert into card_descriptions (card_id, state, updated_at)
                 select c.id, 'queued', ?2 from cards c
                 left join card_descriptions d on d.card_id = c.id
                 where c.user_id = ?1 and c.trashed_at is null and (?3 is null or c.id = ?3)
                   and (d.state is null or d.state = 'failed')
                 on conflict (card_id) do update set state = 'queued', reason = '', updated_at = excluded.updated_at",
                params![user, now_ms(), only],
            )?;
            let needs = crate::needs::queued(conn, user, only)?;
            // A redo's failure is over for a card this takes up: what comes of it is told here.
            conn.execute(
                "delete from card_redos where state = 'failed' and card_id in (
                    select c.id from cards c
                    left join card_descriptions d on d.card_id = c.id
                    left join card_needs n on n.card_id = c.id
                    where c.user_id = ?1 and (d.state = 'queued' or n.state = 'queued'))",
                [user],
            )?;
            Ok::<_, rusqlite::Error>(described + needs)
        })?)
    }

    fn describing(&self, user: i64) -> anyhow::Result<Describing> {
        Ok(self.with(|conn| {
            let (waiting, left, failed): (i64, i64, i64) = conn.query_row(
                "select count(*) filter (where c.trashed_at is null and (d.state = 'queued' or n.state = 'queued')),
                        count(*) filter (where c.trashed_at is null and (d.state is null or d.state = 'failed'
                            or (d.state <> 'refused' and (n.state is null or n.state = 'failed')))),
                        count(*) filter (where c.trashed_at is null and (d.state = 'failed' or n.state = 'failed')
                            and not exists (select 1 from card_redos r where r.card_id = c.id and r.reason <> ''))
                 from cards c left join card_descriptions d on d.card_id = c.id
                 left join card_needs n on n.card_id = c.id where c.user_id = ?1",
                [user],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )?;
            let failure = conn
                .query_row(
                    "select f.reason from (
                        select d.reason, d.updated_at, d.card_id from card_descriptions d where d.state = 'failed'
                        union all
                        select n.reason, n.updated_at, n.card_id from card_needs n where n.state = 'failed'
                     ) f join cards c on c.id = f.card_id
                     where c.user_id = ?1 and c.trashed_at is null
                       and not exists (select 1 from card_redos r where r.card_id = c.id and r.reason <> '')
                     order by f.updated_at desc, f.card_id desc limit 1",
                    [user],
                    |r| r.get(0),
                )
                .optional()?;
            Ok(Describing {
                waiting: waiting as usize,
                left: left as usize,
                failed: failed as usize,
                // Kept as JSON by `describe::kept_failure`.
                failure: failure.and_then(|kept: String| serde_json::from_str(&kept).ok()),
            })
        })?)
    }

    fn next_to_describe(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
        Ok(self.with(|conn| {
            conn.execute(
                "delete from card_descriptions where state = 'queued'
                   and card_id in (select id from cards where user_id = ?1 and trashed_at is not null)",
                [user],
            )?;
            conn.query_row(
                "select c.id, (select v.id from card_versions v where v.card_id = c.id order by v.number desc limit 1)
                 from card_descriptions d join cards c on c.id = d.card_id
                 where c.user_id = ?1 and d.state = 'queued' order by d.updated_at, d.card_id limit 1",
                [user],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn fail_waiting_descriptions(&self, user: i64, reason: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update card_descriptions set state = 'failed', reason = ?2, updated_at = ?3
                 where state = 'queued' and card_id in (select id from cards where user_id = ?1)",
                params![user, reason, now_ms()],
            )?;
            conn.execute(
                "update card_needs set state = 'failed', reason = ?2, updated_at = ?3
                 where state = 'queued' and card_id in (select id from cards where user_id = ?1)",
                params![user, reason, now_ms()],
            )?;
            conn.execute(
                "update card_redos set state = 'failed', reason = ?2
                 where state = 'waiting' and card_id in (select id from cards where user_id = ?1)",
                params![user, reason],
            )
        })?;
        Ok(())
    }

    fn forget_queued_descriptions(&self) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute_batch(
                "delete from card_descriptions where state = 'queued';
                 delete from card_needs where state = 'queued';
                 delete from card_redos where state in ('waiting', 'describing', 'needs');",
            )
        })?;
        Ok(())
    }

    fn description(&self, card_id: i64) -> anyhow::Result<Option<(String, String)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select summary, facets from card_descriptions where card_id = ?1 and state = 'described'",
                [card_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn set_card_summary(&self, card_id: i64, summary: &str) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "update card_descriptions set summary = ?2, summary_edited = 1 where card_id = ?1 and state = 'described'",
                params![card_id, summary],
            )
        })?)
    }

    fn keep_description(
        &self,
        card_id: i64,
        version_id: i64,
        stored: Stored,
    ) -> anyhow::Result<()> {
        let now = now_ms();
        self.with(|conn| {
            let tx = conn.transaction()?;
            match &stored {
                Stored::Described { .. } => {
                    described(&tx, card_id, version_id, &stored, now)?;
                }
                Stored::Ended(state, reason) => {
                    set_state(&tx, card_id, state, reason, now)?;
                    // A card the describer refused is not asked about its needs.
                    if *state == "refused" {
                        tx.execute(
                            "insert into card_needs (card_id, state, reason, updated_at) values (?1, 'refused', ?2, ?3)
                             on conflict (card_id) do update set state = 'refused', levels = '[]',
                                reason = excluded.reason, updated_at = excluded.updated_at",
                            params![card_id, reason, now],
                        )?;
                    }
                }
            }
            tx.commit()
        })?;
        Ok(())
    }
}

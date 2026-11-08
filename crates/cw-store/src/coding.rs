//! Coding tasks as SQLite keeps them (`coding::Storage`): `coding_tasks`, their
//! steps in order (`coding_steps`) and what a step changed (`coding_changes`,
//! each file before and after it). A step's who, what, grey line and checkpoint
//! are JSON text (`json`).

use cw_coding::coding::shown::{Checkpoint, StepDetail, StepWhat, Who};
use cw_coding::coding::snapshot::Change;
use cw_coding::coding::{KeptTask, Progress, Step, Storage, TaskLine, TaskRow, verdict_of};
use cw_core::now_ms;
use rusqlite::{OptionalExtension, Row, params};

use crate::{Db, json};

/// A step's changes, as kept.
fn changes_of(conn: &rusqlite::Connection, step: i64) -> rusqlite::Result<Vec<Change>> {
    let mut select = conn.prepare(
        "select path, before, after from coding_changes where step_id = ?1 order by path",
    )?;
    let changes = select.query_map([step], |r| {
        Ok(Change {
            path: r.get(0)?,
            before: r.get(1)?,
            after: r.get(2)?,
        })
    })?;
    changes.collect()
}

fn step(row: &Row<'_>) -> rusqlite::Result<Step> {
    Ok(Step {
        id: row.get(0)?,
        who: json::of(&row.get::<_, String>(1)?, 1)?,
        what: json::of(&row.get::<_, String>(2)?, 2)?,
        detail: json::of(&row.get::<_, String>(3)?, 3)?,
        state: Progress::of(&row.get::<_, String>(4)?),
        output: row.get(5)?,
        checkpoint: row
            .get::<_, Option<String>>(6)?
            .map(|kept| json::of(&kept, 6))
            .transpose()?,
        undone: row.get(7)?,
        started_at: row.get(8)?,
        files: Vec::new(),
    })
}

impl Storage for Db {
    fn running_folders(&self) -> anyhow::Result<Vec<String>> {
        Ok(self.with(|conn| {
            let mut select =
                conn.prepare("select folder from coding_tasks where state = 'running'")?;
            let folders = select.query_map([], |r| r.get(0))?;
            folders.collect::<rusqlite::Result<Vec<_>>>()
        })?)
    }

    fn add_coding_task(
        &self,
        user: i64,
        chat_id: i64,
        message_id: i64,
        (goal, folder): (&str, &str),
        crew: &str,
    ) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into coding_tasks (user_id, chat_id, message_id, goal, folder, team, state, started_at)
                 values (?1, ?2, ?3, ?4, ?5, ?6, 'running', ?7)",
                params![user, chat_id, message_id, goal, folder, crew, now_ms()],
            )?;
            Ok(conn.last_insert_rowid())
        })?)
    }

    fn add_coding_step(
        &self,
        task: i64,
        who: &Who,
        what: &StepWhat,
        checkpoint: Option<&Checkpoint>,
    ) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            let checkpoint = checkpoint.map(json::to).transpose()?;
            conn.execute(
                "insert into coding_steps (task_id, who, what, detail, checkpoint, state, started_at)
                 values (?1, ?2, ?3, ?4, ?5, 'running', ?6)",
                params![
                    task,
                    json::to(who)?,
                    json::to(what)?,
                    json::to(&StepDetail::None)?,
                    checkpoint,
                    now_ms()
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })?)
    }

    fn set_step_what(&self, step: i64, what: &StepWhat) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_steps set what = ?2 where id = ?1",
                params![step, json::to(what)?],
            )
        })?;
        Ok(())
    }

    fn set_step_detail(&self, step: i64, detail: &StepDetail) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_steps set detail = ?2 where id = ?1",
                params![step, json::to(detail)?],
            )
        })?;
        Ok(())
    }

    fn log_step(&self, step: i64, text: &str, most: usize) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_steps set output = output || ?2 where id = ?1 and length(output) < ?3",
                params![step, text, most as i64],
            )
        })?;
        Ok(())
    }

    fn end_coding_step(&self, step: i64, state: Progress) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_steps set state = ?2 where id = ?1",
                params![step, state.name()],
            )
        })?;
        Ok(())
    }

    fn keep_step_changes(&self, step: i64, changes: &[Change]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            for change in changes {
                tx.execute(
                    "insert into coding_changes (step_id, path, before, after) values (?1, ?2, ?3, ?4)",
                    params![step, change.path, change.before, change.after],
                )?;
            }
            if changes.is_empty() {
                tx.execute(
                    "update coding_steps set checkpoint = null where id = ?1",
                    [step],
                )?;
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn set_planned_steps(&self, task: i64, planned: usize) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_tasks set planned = ?2 where id = ?1",
                params![task, planned as i64],
            )
        })?;
        Ok(())
    }

    fn end_coding_task(
        &self,
        task: i64,
        state: Progress,
        verdict: Option<&str>,
        error: Option<&str>,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "update coding_tasks set state = ?2, verdict = coalesce(?3, verdict), error = ?4, ended_at = ?5
                 where id = ?1",
                params![task, state.name(), verdict, error, now_ms()],
            )?;
            tx.execute(
                "update coding_steps set state = ?2 where task_id = ?1 and state = 'running'",
                params![task, state.name()],
            )?;
            tx.commit()
        })?;
        Ok(())
    }

    fn stop_running_tasks(&self) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update coding_steps set state = 'stopped' where state = 'running'",
                [],
            )?;
            conn.execute(
                "update coding_tasks set state = 'stopped', ended_at = ?1 where state = 'running'",
                [now_ms()],
            )
        })?;
        Ok(())
    }

    fn coding_tasks(
        &self,
        user: i64,
        chat_id: Option<i64>,
        most: usize,
    ) -> anyhow::Result<Vec<TaskLine>> {
        Ok(self.with(|conn| {
            let mut select = conn.prepare(
                "select id, chat_id, goal, folder, state, verdict, started_at from coding_tasks
                 where user_id = ?1 and (?2 is null or chat_id = ?2) order by id desc limit ?3",
            )?;
            let lines = select.query_map(params![user, chat_id, most as i64], |r| {
                Ok(TaskLine {
                    id: r.get(0)?,
                    chat_id: r.get(1)?,
                    goal: r.get(2)?,
                    folder: r.get(3)?,
                    state: Progress::of(&r.get::<_, String>(4)?),
                    verdict: verdict_of(r.get(5)?),
                    started_at: r.get(6)?,
                })
            })?;
            lines.collect::<rusqlite::Result<Vec<_>>>()
        })?)
    }

    fn coding_task_row(&self, user: i64, id: i64) -> anyhow::Result<Option<(String, Progress)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select folder, state from coding_tasks where id = ?1 and user_id = ?2",
                [id, user],
                |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        Progress::of(&r.get::<_, String>(1)?),
                    ))
                },
            )
            .optional()
        })?)
    }

    fn coding_task(&self, user: i64, id: i64) -> anyhow::Result<Option<KeptTask>> {
        Ok(self.with(|conn| {
            let found = conn
                .query_row(
                    "select t.chat_id, coalesce(nullif(c.title, ''), ''), t.message_id, t.goal, t.folder, t.team,
                     t.state, t.planned, t.verdict, t.error, t.started_at, t.ended_at
                     from coding_tasks t join chats c on c.id = t.chat_id where t.id = ?1 and t.user_id = ?2",
                    [id, user],
                    |r| {
                        Ok(TaskRow {
                            chat_id: r.get(0)?,
                            chat_title: r.get(1)?,
                            message_id: r.get(2)?,
                            goal: r.get(3)?,
                            folder: r.get(4)?,
                            team: r.get(5)?,
                            state: r.get(6)?,
                            planned: r.get(7)?,
                            verdict: r.get(8)?,
                            error: r.get(9)?,
                            started_at: r.get(10)?,
                            ended_at: r.get(11)?,
                        })
                    },
                )
                .optional()?;
            let Some(found) = found else {
                return Ok(None);
            };
            let mut select = conn.prepare(
                "select id, who, what, detail, state, output, checkpoint, undone, started_at
                 from coding_steps where task_id = ?1 order by id",
            )?;
            let steps = select
                .query_map([id], step)?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            let steps = steps
                .into_iter()
                .map(|step| Ok((changes_of(conn, step.id)?, step)))
                .collect::<rusqlite::Result<Vec<_>>>()?;
            Ok(Some(KeptTask { task: found, steps }))
        })?)
    }

    fn steps_to_undo(
        &self,
        task: i64,
        from: Option<i64>,
    ) -> anyhow::Result<Vec<(i64, Vec<Change>)>> {
        Ok(self.with(|conn| {
            let mut select = conn.prepare(
                "select id from coding_steps where task_id = ?1 and undone = 0 and checkpoint is not null
                 and id >= coalesce(?2, 0) order by id desc",
            )?;
            let ids = select
                .query_map(params![task, from], |r| r.get::<_, i64>(0))?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            ids.into_iter()
                .map(|step| Ok((step, changes_of(conn, step)?)))
                .collect::<rusqlite::Result<Vec<_>>>()
        })?)
    }

    fn step_undone(&self, step: i64) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("update coding_steps set undone = 1 where id = ?1", [step]))?;
        Ok(())
    }
}

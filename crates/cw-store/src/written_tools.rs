//! The tools the model wrote as SQLite keeps them (`tools::written::Storage`):
//! `written_tools`, a row per tool of an account, with the chat it was made
//! in; a deleted one is flagged (`deleted`) until it is purged.

use anyhow::anyhow;
use cw_coding::tools::written::{MOST_TOOLS, NewTool, Storage, WrittenTool};
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};
use rusqlite::{OptionalExtension, Row, params};

use crate::Db;

const COLUMNS: &str = "t.id, t.name, t.description, t.code, t.enabled, t.created_at, c.id, c.title, t.uses, t.parameters";

fn read(r: &Row) -> rusqlite::Result<WrittenTool> {
    let parameters: String = r.get(9)?;
    Ok(WrittenTool {
        id: r.get(0)?,
        name: r.get(1)?,
        description: r.get(2)?,
        code: r.get(3)?,
        on: r.get(4)?,
        created_at: r.get(5)?,
        chat_id: r.get(6)?,
        chat_title: r.get(7)?,
        uses: r.get(8)?,
        parameters: serde_json::from_str(&parameters).unwrap_or_default(),
    })
}

impl Storage for Db {
    fn written_tools(&self, user: i64) -> anyhow::Result<Vec<WrittenTool>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "select {COLUMNS} from written_tools t left join chats c on c.id = t.chat_id
                 where t.user_id = ?1 and t.deleted = 0 order by t.id desc"
            ))?;
            query.query_map([user], read)?.collect()
        })?)
    }

    fn written_tool(&self, user: i64, id: i64) -> anyhow::Result<Option<WrittenTool>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!(
                    "select {COLUMNS} from written_tools t left join chats c on c.id = t.chat_id
                     where t.id = ?1 and t.user_id = ?2 and t.deleted = 0"
                ),
                [id, user],
                read,
            )
            .optional()
        })?)
    }

    fn add_written_tool(
        &self,
        user: i64,
        chat_id: Option<i64>,
        tool: &NewTool,
    ) -> anyhow::Result<anyhow::Result<i64>> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let (kept, taken): (i64, bool) = tx.query_row(
                "select count(*), coalesce(sum(name = ?2), 0) > 0 from written_tools where user_id = ?1 and deleted = 0",
                params![user, tool.name],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )?;
            if taken {
                return Ok(Err(anyhow!(Fail::said(Code::Taken, format!("a tool named {} exists already; choose another name", tool.name)).with("what", "tool_name").with("name", (tool.name).to_string()))));
            }
            if kept >= MOST_TOOLS as i64 {
                return Ok(Err(anyhow!(Fail::said(Code::NotPossible, format!("the account keeps {MOST_TOOLS} tools at most; the user is to delete one first")).with("what", "written_tools_full").with("most_tools", MOST_TOOLS))));
            }
            // A deleted tool of that name gives it up for good.
            tx.execute(
                "delete from written_tools where user_id = ?1 and name = ?2 and deleted = 1",
                params![user, tool.name],
            )?;
            tx.execute(
                "insert into written_tools (user_id, name, description, parameters, code, chat_id, created_at)
                 values (?1, ?2, ?3, ?4, ?5, (select id from chats where id = ?6 and user_id = ?1), ?7)",
                params![
                    user,
                    tool.name,
                    tool.description,
                    tool.parameters.to_string(),
                    tool.code,
                    chat_id,
                    now_ms()
                ],
            )?;
            let id = tx.last_insert_rowid();
            tx.commit()?;
            Ok(Ok(id))
        })?)
    }

    fn set_written_tool_on(&self, user: i64, id: i64, on: bool) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "update written_tools set enabled = ?3 where id = ?1 and user_id = ?2 and deleted = 0",
                params![id, user, on],
            )
        })?)
    }

    fn delete_written_tool(&self, user: i64, id: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "update written_tools set deleted = 1 where id = ?1 and user_id = ?2 and deleted = 0",
                [id, user],
            )
        })?)
    }

    fn restore_written_tool(&self, user: i64, id: i64) -> anyhow::Result<anyhow::Result<()>> {
        Ok(self.with(|conn| {
            let name: Option<String> = conn
                .query_row(
                    "select name from written_tools where id = ?1 and user_id = ?2 and deleted = 1",
                    [id, user],
                    |r| r.get(0),
                )
                .optional()?;
            let Some(name) = name else {
                return Ok(Err(NotFound("tool").into()));
            };
            let taken: bool = conn.query_row(
                "select exists (select 1 from written_tools where user_id = ?1 and name = ?2 and deleted = 0)",
                params![user, name],
                |r| r.get(0),
            )?;
            if taken {
                return Ok(Err(anyhow!(Fail::said(Code::Changed, format!("another tool is named {name} now")).with("what", "tool_name").with("name", name.to_string()))));
            }
            conn.execute("update written_tools set deleted = 0 where id = ?1", [id])?;
            Ok(Ok(()))
        })?)
    }

    fn written_tool_used(&self, id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update written_tools set uses = uses + 1 where id = ?1",
                [id],
            )
        })?;
        Ok(())
    }

    fn purge_deleted_written_tools(&self) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("delete from written_tools where deleted = 1", []))?;
        Ok(())
    }
}

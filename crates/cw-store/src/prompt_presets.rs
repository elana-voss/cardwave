//! Prompt presets as SQLite keeps them (`prompt_presets::Storage`): a row per
//! preset in `prompt_presets`, the one in use in `users.prompt_preset_id`, and
//! a chat's choice in `chats.prompt_preset_own` and `prompt_preset_id`.

use cw_chat::prompt_presets::{ChatPromptPreset, KeptPromptPresets, Storage};
use cw_core::now_ms;
use cw_provider::presets::Named;
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

fn in_use(conn: &Connection, user: i64) -> rusqlite::Result<Option<i64>> {
    conn.query_row(
        "select prompt_preset_id from users where id = ?1",
        [user],
        |r| r.get(0),
    )
}

impl Storage for Db {
    fn prompt_presets(&self, user: i64) -> anyhow::Result<KeptPromptPresets> {
        Ok(self.with(|conn| {
            let used = in_use(conn, user)?;
            let kept = conn
                .prepare("select id, name, blocks from prompt_presets where user_id = ?1")?
                .query_map([user], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            Ok(KeptPromptPresets {
                in_use: used,
                presets: kept,
            })
        })?)
    }

    fn add_prompt_preset(
        &self,
        user: i64,
        name: &str,
        blocks: &str,
    ) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "insert into prompt_presets (user_id, name, blocks, created_at) values (?1, ?2, ?3, ?4)
                 on conflict do nothing returning id",
                params![user, name, blocks, now_ms()],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn change_prompt_preset(
        &self,
        user: i64,
        id: i64,
        name: &str,
        blocks: &str,
    ) -> anyhow::Result<Option<usize>> {
        Ok(self.with(|conn| {
            let other: bool = conn.query_row(
                "select exists (select 1 from prompt_presets where user_id = ?1 and name = ?2 and id <> ?3)",
                params![user, name, id],
                |r| r.get(0),
            )?;
            if other {
                return Ok(None);
            }
            conn.execute(
                "update prompt_presets set name = ?3, blocks = ?4 where id = ?1 and user_id = ?2",
                params![id, user, name, blocks],
            )
            .map(Some)
        })?)
    }

    fn copy_prompt_preset(&self, user: i64, id: i64, named: &Named) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            let names: Vec<(i64, String)> = conn
                .prepare("select id, name from prompt_presets where user_id = ?1")?
                .query_map([user], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect::<rusqlite::Result<_>>()?;
            let Some(copy) = named(&names) else {
                return Ok(None);
            };
            conn.query_row(
                "insert into prompt_presets (user_id, name, blocks, created_at)
                 select user_id, ?2, blocks, ?3 from prompt_presets where id = ?1 returning id",
                params![id, copy, now_ms()],
                |r| r.get(0),
            )
            .map(Some)
        })?)
    }

    fn delete_prompt_preset(&self, user: i64, id: i64) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "update chats set prompt_preset_own = 0
                 where prompt_preset_id = ?1 and user_id = ?2",
                [id, user],
            )?;
            let gone = tx.execute(
                "delete from prompt_presets where id = ?1 and user_id = ?2",
                [id, user],
            )?;
            tx.commit()?;
            Ok(gone)
        })? == 1)
    }

    fn owns_prompt_preset(&self, user: i64, id: i64) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select exists (select 1 from prompt_presets where id = ?1 and user_id = ?2)",
                [id, user],
                |r| r.get(0),
            )
        })?)
    }

    fn put_prompt_preset_in_use(&self, user: i64, id: Option<i64>) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update users set prompt_preset_id = ?2 where id = ?1",
                params![user, id],
            )
        })?;
        Ok(())
    }

    fn choose_chat_prompt_preset(
        &self,
        user: i64,
        chat_id: i64,
        own: bool,
        id: Option<i64>,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update chats set prompt_preset_own = ?3, prompt_preset_id = ?4 where id = ?1 and user_id = ?2",
                params![chat_id, user, own, id],
            )
        })?;
        Ok(())
    }

    fn prompt_preset_blocks(
        &self,
        user: i64,
        chosen: ChatPromptPreset,
    ) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            let id = match chosen {
                ChatPromptPreset::Settings => in_use(conn, user)?,
                ChatPromptPreset::Card => None,
                ChatPromptPreset::Preset(id) => Some(id),
            };
            let Some(id) = id else { return Ok(None) };
            conn.query_row(
                "select blocks from prompt_presets where id = ?1 and user_id = ?2",
                [id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }
}

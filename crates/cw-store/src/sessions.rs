//! Sessions as SQLite keeps them (`sessions::Storage`).

use std::collections::HashMap;

use cw_accounts::sessions::Storage;
use cw_core::now_ms;
use rusqlite::params;

use crate::Db;

impl Storage for Db {
    fn server_mark(&self) -> anyhow::Result<Option<String>> {
        self.meta("server")
    }

    fn set_server_mark(&self, mark: &str) -> anyhow::Result<()> {
        self.set_meta("server", mark)
    }

    fn sessions(&self) -> anyhow::Result<HashMap<Vec<u8>, i64>> {
        Ok(self.with(|conn| {
            let mut all = conn.prepare("select token, user_id from sessions")?;
            all.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect::<rusqlite::Result<HashMap<Vec<u8>, i64>>>()
        })?)
    }

    fn add_session(&self, key: &[u8], user: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert into sessions (token, user_id, created_at) values (?1, ?2, ?3)",
                params![key, user, now_ms()],
            )
        })?;
        Ok(())
    }

    fn remove_session(&self, key: &[u8]) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("delete from sessions where token = ?1", [key]))?;
        Ok(())
    }

    fn remove_sessions_of(&self, user: i64, kept: &[u8]) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "delete from sessions where user_id = ?1 and token <> ?2",
                params![user, kept],
            )
        })?;
        Ok(())
    }

    fn remove_every_session(&self) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("delete from sessions", []))?;
        Ok(())
    }
}

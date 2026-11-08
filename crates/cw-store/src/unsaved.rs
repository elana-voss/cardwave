//! Unsaved edits as SQLite keeps them (`unsaved::Storage`): a row per user and field.

use cw_core::now_ms;
use cw_library::unsaved::Storage;
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn unsaved(&self, user: i64, field: &str) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select text from unsaved where user_id = ?1 and field = ?2",
                params![user, field],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn keep_unsaved(&self, user: i64, field: &str, text: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert into unsaved (user_id, field, text, updated_at) values (?1, ?2, ?3, ?4)
                 on conflict (user_id, field) do update set text = excluded.text, updated_at = excluded.updated_at",
                params![user, field, text, now_ms()],
            )
        })?;
        Ok(())
    }

    fn forget_unsaved(&self, user: i64, field: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "delete from unsaved where user_id = ?1 and field = ?2",
                params![user, field],
            )
        })?;
        Ok(())
    }
}

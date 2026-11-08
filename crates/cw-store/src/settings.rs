//! A user's settings as SQLite keeps them (`settings::Storage`): a JSON text on
//! the user's row, changed by `json_patch`.

use cw_library::settings::Storage;
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

fn read(conn: &Connection, user: i64) -> rusqlite::Result<Option<String>> {
    conn.query_row("select settings from users where id = ?1", [user], |r| {
        r.get(0)
    })
    .optional()
}

impl Storage for Db {
    fn settings_text(&self, user: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| read(conn, user))?)
    }

    fn patch_settings(&self, user: i64, changes: &str) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "update users set settings = json_patch(settings, ?2) where id = ?1",
                params![user, changes],
            )?;
            let settings = read(&tx, user)?;
            tx.commit()?;
            Ok(settings)
        })?)
    }

    fn default_persona_name(&self, user: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select p.name from users u join personas p on p.id = u.default_persona_id \
                 where u.id = ?1 and p.trashed_at is null",
                [user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }
}

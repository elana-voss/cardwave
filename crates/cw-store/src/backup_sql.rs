//! A backup's copies of the database by SQLite's backup (`backup::Storage`).

use std::path::Path;

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use cw_key::DbKey;
use rusqlite::Connection;
use rusqlite::backup::{Backup, StepResult};

use crate::Db;
use crate::backup::Storage;

/// Copies the database at `live`, encrypted with its `key`, into the new file
/// `to`, by a connection of its own, all in one step: the server writes on
/// meanwhile, and a copy in steps would begin anew at every write.
pub fn copy(live: &Path, key: &DbKey, to: &Path) -> anyhow::Result<()> {
    let keyed = |path: &Path| -> anyhow::Result<Connection> {
        let conn = Connection::open(path).context(Fail::said(
            Code::Internal,
            "cannot open the database to copy it",
        ))?;
        conn.pragma_update(None, "key", format!("x'{}'", key.to_hex()))?;
        Ok(conn)
    };
    let from = keyed(live)?;
    let mut copy = keyed(to)?;
    if !whole(&from, &mut copy)? {
        bail!(busy());
    }
    Ok(())
}

/// Copies all of `from` into `to` in one step, which takes `to`'s write lock
/// first: busy past the connection's busy timeout, `to` stays untouched and
/// false is returned, never retried without end.
fn whole(from: &Connection, to: &mut Connection) -> rusqlite::Result<bool> {
    Ok(Backup::new(from, to)?.step(-1)? == StepResult::Done)
}

/// The refusal of a copy while the database is busy.
fn busy() -> Fail {
    Fail::said(Code::NotNow, "the database was busy; try again").with("what", "database_busy")
}

impl Storage for Db {
    fn replace_with(&self, restored: &Db, key: &DbKey) -> anyhow::Result<()> {
        let done = restored.with(|from| {
            from.pragma_update(None, "rekey", format!("x'{}'", key.to_hex()))?;
            // The caches go while the live connection is still held: no search reads old vectors meanwhile.
            self.with(|live| {
                let done = whole(from, live)?;
                if done {
                    *self.card_vectors() = None;
                    *self.text_vectors() = None;
                }
                Ok(done)
            })
        })?;
        if !done {
            bail!(busy());
        }
        Ok(())
    }
}

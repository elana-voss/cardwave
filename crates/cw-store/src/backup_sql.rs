//! A backup's copies of the database by SQLite's backup (`backup::Storage`).

use std::path::Path;
use std::time::Duration;

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use cw_key::DbKey;
use rusqlite::Connection;
use rusqlite::backup::{Backup, StepResult};

use crate::Db;
use crate::backup::Storage;

/// How many pages a restore copies at a time.
const PAGES: std::ffi::c_int = 1024;

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
    if Backup::new(&from, &mut copy)?.step(-1)? != StepResult::Done {
        bail!(
            Fail::said(Code::NotNow, "the database was busy; try again")
                .with("what", "database_busy")
        );
    }
    Ok(())
}

impl Storage for Db {
    fn replace_with(&self, restored: &Db, key: &DbKey) -> anyhow::Result<()> {
        restored.with(|from| {
            from.pragma_update(None, "rekey", format!("x'{}'", key.to_hex()))?;
            self.with(|live| {
                Backup::new(from, live)?.run_to_completion(PAGES, Duration::ZERO, None)?;
                *self.card_vectors() = None;
                *self.text_vectors() = None;
                Ok(())
            })
        })?;
        Ok(())
    }
}

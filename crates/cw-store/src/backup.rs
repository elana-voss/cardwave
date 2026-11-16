//! A backup: the whole database and its key in one file, which `restore` reads
//! back, on this computer or another.
//!
//! The file is the line [`MAGIC`], a line of JSON (`Header`): the key sealed by a
//! password (cw-accounts' `password`), the one that is on (`locked`: Cardwave
//! asked for it on opening, and a restore brings that lock back) or, where none
//! is, one asked for at the backup (a backup always has a password), and then
//! the database's file, encrypted with that key, as SQLite's backup copies it
//! while the server runs (`snapshot`). An older backup may hold the key plain.
//!
//! `restore` opens that copy with its key, brings its schema up to date, gives it
//! this data folder's key (`PRAGMA rekey`) and copies it page by page over the
//! open database: the server goes on with the same file, key and password. Its
//! files (`RESTORE`, the upload's copy) go when done, or at the next start
//! (`remove_left`).

use std::fs::File;
use std::io::{BufRead, BufReader, Read, Write};
use std::path::Path;

use crate::Db;
use anyhow::{Context, bail};
use cw_accounts::password::{self, Sealed};
use cw_core::{Code, Fail};
use cw_key::DbKey;
use serde::{Deserialize, Serialize};

/// How a backup begins.
pub const MAGIC: &[u8] = b"Cardwave backup 1\n";

/// The database copied out of a backup, in the data folder, while it is restored.
pub(crate) const RESTORE: &str = "restore.db";

/// The longest header read: a sealed key is a few hundred bytes.
const HEADER_LIMIT: u64 = 64 * 1024;

/// The key a backup carries.
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Header {
    /// As it is, in hex: only read, of backups made before every one had a password.
    Key(String),
    /// Sealed by a password chosen for the backup.
    Sealed(Sealed),
    /// Sealed by the password Cardwave asked for on opening when the backup was made.
    Locked(Sealed),
}

/// What a backup needs of the database, which `backup_sql` gives.
pub trait Storage {
    /// Gives `restored` the key `key` and copies it over this database, page
    /// by page: what this one held before is gone.
    fn replace_with(&self, restored: &Db, key: &DbKey) -> anyhow::Result<()>;
}

/// Copies the database at `live`, encrypted with its `key`, into the new file
/// `to`, and answers what goes before that copy in the backup: `sealed` is the
/// key as the backup's password seals it, `locked` whether that password is the
/// one Cardwave asks for on opening. The copy is read by a
/// connection of its own, all in one step: the server writes on meanwhile,
/// and a copy in steps would begin anew at every write.
pub fn snapshot(
    live: &Path,
    key: &DbKey,
    sealed: Sealed,
    locked: bool,
    to: &Path,
) -> anyhow::Result<Vec<u8>> {
    crate::backup_sql::copy(live, key, to)?;
    let mut head = MAGIC.to_vec();
    let header = match locked {
        true => Header::Locked(sealed),
        false => Header::Sealed(sealed),
    };
    serde_json::to_writer(&mut head, &header)?;
    head.push(b'\n');
    Ok(head)
}

/// Puts what the backup `file` holds in the place of what `db` holds. `key`
/// is the database's key, `password` the backup's where it was made with one.
/// Answers whether the backup was made while that password locked Cardwave.
pub fn restore(
    db: &Db,
    key: &DbKey,
    file: &Path,
    password: Option<&str>,
    data_dir: &Path,
) -> anyhow::Result<bool> {
    let mut reader = BufReader::new(File::open(file)?);
    let mut magic = vec![0; MAGIC.len()];
    if reader.read_exact(&mut magic).is_err() || magic != MAGIC {
        bail!(
            Fail::said(Code::NotReadable, "This file is not a Cardwave backup.")
                .with("what", "backup")
        );
    }
    let mut line = Vec::new();
    (&mut reader)
        .take(HEADER_LIMIT)
        .read_until(b'\n', &mut line)?;
    let header: Header = serde_json::from_slice(&line).context(
        Fail::said(
            Code::NotReadable,
            "This backup is damaged: its key cannot be read.",
        )
        .with("what", "backup_key"),
    )?;
    let (theirs, locked) = match header {
        Header::Key(hex) => (DbKey::from_hex(&hex)?, false),
        Header::Sealed(sealed) => (unsealed(&sealed, password)?, false),
        Header::Locked(sealed) => (unsealed(&sealed, password)?, true),
    };
    let copy = data_dir.join(RESTORE);
    let result = (|| {
        let mut out = File::create(&copy)?;
        std::io::copy(&mut reader, &mut out)?;
        out.flush()?;
        drop(out);
        let restored = Db::open(&copy, &theirs).map_err(|failure| {
            let newer = cw_core::failed_as(&failure, crate::schema::NEWER).is_some();
            let told = if newer {
                Fail::said(
                    Code::NotReadable,
                    "This backup was made by a newer Cardwave. Update Cardwave to restore it.",
                )
                .with("what", "backup_newer")
            } else {
                Fail::said(Code::NotReadable, "This backup is damaged.")
                    .with("what", "backup_damaged")
            };
            failure.context(told)
        })?;
        db.replace_with(&restored, key)
    })();
    for end in ["", "-wal", "-shm"] {
        // Not there, or left for `backup::remove_left` at the next start.
        let _ = std::fs::remove_file(data_dir.join(format!("{RESTORE}{end}")));
    }
    result.map(|()| locked)
}

/// The key `sealed` holds, by the backup's `password`, which it needs.
fn unsealed(sealed: &Sealed, password: Option<&str>) -> anyhow::Result<DbKey> {
    let password = password.ok_or(Fail::new(Code::BackupPasswordNeeded))?;
    password::unseal(sealed, password)
}

/// Removes what a backup or a restore left in `data_dir` when the server was
/// stopped in its middle: a copy of the database with its key, maybe.
pub fn remove_left(data_dir: &Path) {
    let Ok(files) = std::fs::read_dir(data_dir) else {
        return;
    };
    for file in files.flatten() {
        let name = file.file_name().to_string_lossy().into_owned();
        let left = (name.starts_with("backup-") && name.ends_with(".db"))
            || name.starts_with("restore.upload-")
            || name.starts_with(RESTORE);
        if left && let Err(failure) = std::fs::remove_file(file.path()) {
            tracing::warn!("{name} is left in the data folder: {failure}");
        }
    }
}

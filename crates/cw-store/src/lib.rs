//! cw-store: the database, one SQLCipher-encrypted SQLite file in the data folder,
//! with sqlite-vec vectors on its connection, and its backup (`backup`). The only
//! crate that knows SQLite (`rusqlite`): each area says what it needs of it in a
//! `Storage` trait (`cards::Storage`, ...), which a module here gives for
//! `Db`, named after the area (`cards.rs`); the search's is `search::Index`.
//!
//! The schema grows by a step appended to `MIGRATIONS` (`schema.rs`).
//! `Db::set` writes one column of an item, for the setters of a flagged one.
//! The cards' vectors, and Search Cardwave's texts' (`Db::text_vectors`), are
//! kept in memory beside the connection once a search read them
//! (`search::card_vectors`, `Db::card_vectors`; the connection is locked
//! first). The HTTP layer tells a database failure by `is_storage_error`.

use std::collections::HashMap;
use std::ffi::{c_char, c_int};
use std::path::Path;
use std::sync::{Arc, Mutex, MutexGuard, Once};
use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_core::{NotFound, lock};
use cw_key::DbKey;
use cw_library::cards::Show;
use cw_search::CardVectors;
use rusqlite::{Connection, ToSql, ffi, params};

mod again;
mod assistant;
mod attachments;
pub(crate) mod backup_sql;
mod cards;
mod chat_characters;
mod chat_messages;
mod chat_turns;
mod chats;
mod coding;
mod copies;
mod describe;
mod documents;
mod expressions;
mod faces;
mod figures;
mod find;
mod held;
mod images;
mod json;
mod lorebooks;
mod mcp;
mod memory;
mod needs;
mod personas;
mod posters;
mod prompt_presets;
mod provider;
mod schema;
pub(crate) mod search;
mod sessions;
mod settings;
mod thumbnails;
mod trash;
mod unsaved;
mod users;
mod voice;
mod written_tools;

pub use schema::schema_version;

/// Whether `error` is, or was caused by, the database failing: the server's
/// fault, never the request's.
pub fn is_storage_error(error: &anyhow::Error) -> bool {
    error.chain().any(|e| e.is::<rusqlite::Error>())
}

impl cw_library::failures::Failures for Db {
    fn failed_in(&self, error: &anyhow::Error) -> bool {
        is_storage_error(error)
    }
}

pub struct Db(
    Mutex<Connection>,
    Mutex<Option<Arc<CardVectors>>>,
    Mutex<Option<Arc<TextVectors>>>,
);

/// The vectors of the rows of `search_texts` (`find.rs`), by row: its user, the stamp of the model that made
/// them, and the vectors of its pieces one after the other.
pub(crate) type TextVectors = HashMap<i64, (i64, String, Vec<u8>)>;

impl Db {
    /// Opens (or creates) the database at `path` and brings its schema up to date.
    /// Fails if `key` is not the key the file was created with.
    pub fn open(path: &Path, key: &DbKey) -> anyhow::Result<Self> {
        register_vec();
        let mut conn = Connection::open(path)
            .with_context(|| format!("cannot open the database {}", path.display()))?;
        // A raw key: SQLCipher uses these 32 bytes as they are, with no password stretching.
        conn.pragma_update(None, "key", format!("x'{}'", key.to_hex()))?;
        // The key is only checked on the first read.
        if conn
            .query_row("select count(*) from sqlite_master", [], |r| {
                r.get::<_, i64>(0)
            })
            .is_err()
        {
            bail!(
                "cannot read the database {}: wrong key, or not a Cardwave database",
                path.display()
            );
        }
        conn.pragma_update_and_check(None, "journal_mode", "wal", |r| r.get::<_, String>(0))?;
        // A commit is not forced to disk on its own; the log is, at every checkpoint.
        // A reply is saved several times a second while it is generated. The file
        // cannot break this way; a power cut can take the last moments of writing.
        conn.pragma_update(None, "synchronous", "normal")?;
        conn.pragma_update(None, "foreign_keys", true)?;
        conn.busy_timeout(Duration::from_secs(5))?;
        crate::schema::migrate(&mut conn)?;
        Ok(Self(Mutex::new(conn), Mutex::default(), Mutex::default()))
    }

    /// Runs `f` on the connection. Calls are serialized; keep them short.
    pub fn with<T>(
        &self,
        f: impl FnOnce(&mut Connection) -> rusqlite::Result<T>,
    ) -> rusqlite::Result<T> {
        let mut conn = lock(&self.0);
        f(&mut conn)
    }

    /// What the server keeps under `key` of its own (`meta`), not a user's.
    pub(crate) fn meta(&self, key: &str) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| meta(conn, key))?)
    }

    /// Keeps `value` under `key` of the server's own.
    pub(crate) fn set_meta(&self, key: &str, value: &str) -> anyhow::Result<()> {
        Ok(self.with(|conn| set_meta(conn, key, value))?)
    }

    /// The cards' vectors where a search read them, which `search::keep` and a
    /// restore forget.
    pub(crate) fn card_vectors(&self) -> MutexGuard<'_, Option<Arc<CardVectors>>> {
        lock(&self.1)
    }

    /// Sets one column of the row `id` of `table`, if it is `user`'s. If not,
    /// that is [`NotFound`], with `what` as the item's name.
    fn set(
        &self,
        (table, what): (&str, &'static str),
        user: i64,
        id: i64,
        column: &str,
        value: &dyn ToSql,
    ) -> anyhow::Result<()> {
        let changed = self.with(|conn| {
            conn.execute(
                &format!("update {table} set {column} = ?3 where id = ?1 and user_id = ?2"),
                params![id, user, value],
            )
        })?;
        ensure!(changed == 1, NotFound(what));
        Ok(())
    }
}

/// Makes sqlite-vec part of every connection opened by this process.
pub(crate) fn register_vec() {
    type Init = unsafe extern "C" fn(
        *mut ffi::sqlite3,
        *mut *mut c_char,
        *const ffi::sqlite3_api_routines,
    ) -> c_int;
    static ONCE: Once = Once::new();
    ONCE.call_once(|| unsafe {
        let init =
            std::mem::transmute::<*const (), Init>(sqlite_vec::sqlite3_vec_init as *const ());
        ffi::sqlite3_auto_extension(Some(init));
    });
}

/// `Db::meta` inside a connection already held.
pub(crate) fn meta(conn: &Connection, key: &str) -> rusqlite::Result<Option<String>> {
    use rusqlite::OptionalExtension;
    conn.query_row("select value from meta where key = ?1", [key], |r| r.get(0))
        .optional()
}

/// `Db::set_meta` inside a connection already held.
fn set_meta(conn: &Connection, key: &str, value: &str) -> rusqlite::Result<()> {
    conn.execute(
        "insert into meta (key, value) values (?1, ?2)
         on conflict (key) do update set value = excluded.value",
        params![key, value],
    )
    .map(drop)
}

/// `show` as conditions to end a query's `where` with, on the table named
/// `t`. Archived items only when they are asked for, or in a search.
pub(crate) fn shown(show: Show, t: &str, searching: bool) -> String {
    let mut sql = match show {
        Show::All => String::new(),
        Show::Favorites => format!(" and {t}.favorite"),
        Show::Archived => format!(" and {t}.archived"),
    };
    if show != Show::Archived && !searching {
        sql.push_str(&format!(" and not {t}.archived"));
    }
    sql
}
pub mod backup;

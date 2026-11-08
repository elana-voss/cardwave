use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};

use cw_key::DbKey;
use cw_key::FILE_NAME;
use cw_store::{Db, schema_version};

static NEXT: AtomicUsize = AtomicUsize::new(0);

/// A scratch folder, removed on drop.
struct Scratch(PathBuf);

impl Scratch {
    fn new() -> Self {
        let n = NEXT.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join(format!("cardwave-db-test-{}-{n}", std::process::id()));
        // A run that was killed leaves its folders, and process numbers come round again.
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        Self(dir)
    }

    fn db(&self) -> PathBuf {
        self.0.join(FILE_NAME)
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn contains(haystack: &[u8], needle: &[u8]) -> bool {
    haystack.windows(needle.len()).any(|w| w == needle)
}

#[test]
fn file_is_encrypted_and_only_the_right_key_opens_it() {
    const MARK: &str = "ZEBRAMARKERPLAINTEXT";
    let scratch = Scratch::new();
    let key = DbKey::generate().unwrap();
    {
        let db = Db::open(&scratch.db(), &key).unwrap();
        db.with(|c| c.execute("insert into meta values ('mark', ?1)", [MARK]))
            .unwrap();
        // Read the files while the WAL still holds the row.
        for name in [FILE_NAME.to_string(), format!("{FILE_NAME}-wal")] {
            let raw = std::fs::read(scratch.0.join(&name)).unwrap();
            assert!(
                !raw.starts_with(b"SQLite format 3"),
                "{name} has a plain header"
            );
            assert!(!contains(&raw, MARK.as_bytes()), "{name} holds plain text");
        }
    }
    assert!(Db::open(&scratch.db(), &DbKey::generate().unwrap()).is_err());

    let reopened = Db::open(&scratch.db(), &DbKey::from_hex(&key.to_hex()).unwrap()).unwrap();
    let mark: String = reopened
        .with(|c| {
            c.query_row("select value from meta where key = 'mark'", [], |r| {
                r.get(0)
            })
        })
        .unwrap();
    assert_eq!(mark, MARK);
}

#[test]
fn schema_is_current_and_wal_is_on() {
    let scratch = Scratch::new();
    let key = DbKey::generate().unwrap();
    for _ in 0..2 {
        let db = Db::open(&scratch.db(), &key).unwrap();
        let (version, journal): (u32, String) = db
            .with(|c| {
                Ok((
                    c.pragma_query_value(None, "user_version", |r| r.get(0))?,
                    c.pragma_query_value(None, "journal_mode", |r| r.get(0))?,
                ))
            })
            .unwrap();
        assert_eq!(version as usize, schema_version());
        assert_eq!(journal, "wal");
    }
}

#[test]
fn text_search_and_vectors_work_in_the_encrypted_file() {
    let scratch = Scratch::new();
    let db = Db::open(&scratch.db(), &DbKey::generate().unwrap()).unwrap();
    let (text_hit, nearest): (i64, i64) = db
        .with(|c| {
            c.execute_batch(
                "create virtual table temp.t using fts5(body, tokenize='trigram');
                 insert into temp.t(rowid, body) values (1, 'a mountain garden'), (2, 'Straßenbahn');
                 create virtual table temp.v using vec0(embedding float[3]);
                 insert into temp.v(rowid, embedding) values (1, '[1, 0, 0]'), (2, '[0, 1, 0]');",
            )?;
            Ok((
                c.query_row("select rowid from temp.t where t match '\"ountai\"'", [], |r| r.get(0))?,
                c.query_row(
                    "select rowid from temp.v where embedding match '[0.1, 0.9, 0]' order by distance limit 1",
                    [],
                    |r| r.get(0),
                )?,
            ))
        })
        .unwrap();
    assert_eq!(text_hit, 1);
    assert_eq!(nearest, 2);
}

#[test]
fn key_hex_is_validated() {
    assert!(DbKey::from_hex("abc").is_err());
    assert!(DbKey::from_hex(&"zz".repeat(32)).is_err());
    assert!(DbKey::from_hex(&"0F".repeat(32)).is_ok());
}

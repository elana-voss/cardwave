//! The pages signed in to an account (`api/accounts.rs`): each holds a token,
//! 32 bytes of chance in hex, in a cookie named after the server's own mark
//! (`cookie`, kept as `meta`'s `server`), as a browser sends the cookies of
//! every port of a host to each: another Cardwave server's is not this one's.
//! The server keeps the token's SHA-256 (`key`) with its user in the table
//! `sessions` and in memory, which every request asks (`user`) and the event
//! socket asks before each event of its user (`alive`). A session lasts until
//! it is signed out of, or its account's password is changed or reset, or the
//! account deleted, or a backup restored.

use std::collections::HashMap;
use std::sync::Mutex;

use cw_core::{Code, Fail};
use sha2::{Digest, Sha256};

/// What the sessions need of the database, which `cw_store::sessions` gives.
pub trait Storage {
    /// Every session's key, with its user.
    fn sessions(&self) -> anyhow::Result<HashMap<Vec<u8>, i64>>;
    fn add_session(&self, key: &[u8], user: i64) -> anyhow::Result<()>;
    fn remove_session(&self, key: &[u8]) -> anyhow::Result<()>;
    /// Removes every session of `user` but the one kept by `kept`.
    fn remove_sessions_of(&self, user: i64, kept: &[u8]) -> anyhow::Result<()>;
    fn remove_every_session(&self) -> anyhow::Result<()>;
    /// The server's mark, which tells its sessions from a restored backup's.
    fn server_mark(&self) -> anyhow::Result<Option<String>>;
    fn set_server_mark(&self, mark: &str) -> anyhow::Result<()>;
}

/// The sessions, by their token's SHA-256, and the name of their cookie.
pub struct Sessions {
    held: Mutex<HashMap<Vec<u8>, i64>>,
    cookie: String,
}

/// What a session is kept by: its token's SHA-256.
pub fn key(token: &str) -> Vec<u8> {
    Sha256::digest(token.as_bytes()).to_vec()
}

/// Eight bytes of chance in hex.
fn chance() -> anyhow::Result<String> {
    let mut bytes = [0u8; 8];
    getrandom::fill(&mut bytes).map_err(|e| {
        anyhow::anyhow!(Fail::said(Code::Internal, format!("no random source: {e}")))
    })?;
    Ok(bytes.iter().map(|b| format!("{b:02x}")).collect())
}

impl Sessions {
    fn held(&self) -> std::sync::MutexGuard<'_, HashMap<Vec<u8>, i64>> {
        cw_core::lock(&self.held)
    }

    /// The sessions `db` keeps, and the server's mark, made on first use.
    pub fn load(db: &dyn Storage) -> anyhow::Result<Self> {
        let kept = db.sessions()?;
        let mark = match db.server_mark()? {
            Some(mark) => mark,
            None => {
                let mark = chance()?;
                db.set_server_mark(&mark)?;
                mark
            }
        };
        Ok(Self {
            held: Mutex::new(kept),
            cookie: format!("cardwave_{mark}"),
        })
    }

    /// The name of the cookie a page's session is held in.
    pub fn cookie(&self) -> &str {
        &self.cookie
    }

    /// A new session of `user`: its token.
    pub fn start(&self, db: &dyn Storage, user: i64) -> anyhow::Result<String> {
        let mut bytes = [0u8; 32];
        getrandom::fill(&mut bytes).map_err(|e| {
            anyhow::anyhow!(Fail::said(Code::Internal, format!("no random source: {e}")))
        })?;
        let token: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
        let key = key(&token);
        db.add_session(&key, user)?;
        self.held().insert(key, user);
        Ok(token)
    }

    /// The user of the session `token`, while it lasts.
    pub fn user(&self, token: &str) -> Option<i64> {
        self.held().get(&key(token)).copied()
    }

    /// Whether the session kept by `key` lasts.
    pub fn alive(&self, key: &[u8]) -> bool {
        self.held().contains_key(key)
    }

    /// Ends the session `token`.
    pub fn end(&self, db: &dyn Storage, token: &str) -> anyhow::Result<()> {
        let key = key(token);
        db.remove_session(&key)?;
        self.held().remove(&key);
        Ok(())
    }

    /// Ends every session of `user` but `except`.
    pub fn end_all(&self, db: &dyn Storage, user: i64, except: Option<&str>) -> anyhow::Result<()> {
        let kept = except.map(key).unwrap_or_default();
        db.remove_sessions_of(user, &kept)?;
        self.held()
            .retain(|token, held| *held != user || *token == kept);
        Ok(())
    }

    /// Ends every session, of all accounts, and keeps this server's mark: a
    /// restored backup's sessions and mark are not this server's.
    pub fn end_every(&self, db: &dyn Storage) -> anyhow::Result<()> {
        db.remove_every_session()?;
        self.held().clear();
        let mark = self.cookie.trim_start_matches("cardwave_");
        db.set_server_mark(mark)
    }
}

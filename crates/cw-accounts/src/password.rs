//! The password a user may switch on over the database key (plan 4.14).
//!
//! Off, the key is where `key::Place` keeps it. On, it is kept only sealed in
//! `password.json` in the data folder: argon2id makes a key of the password and
//! its own salt, which seals the database key with ChaCha20-Poly1305. The server
//! then starts locked (`Gate` in lib.rs) until the password unseals the key; a
//! forgotten one cannot be recovered. The file also holds the account's name for
//! the start screen, and a backup carries the sealed key as it is. Another
//! account's password is argon2id's PHC string (`hash`, `verify`). Wrong
//! passwords in a row from one place are held back (`Tries`, 429).
//!
//! Traps: the file is written beside itself first, then put in place. argon2id
//! is optimized in a debug build too (Cargo.toml; a change took 30 to 43 ms,
//! 2026-10-15). Its cost read from a file is bounded (`MOST`).

use std::collections::HashMap;
use std::net::IpAddr;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use anyhow::{Context, ensure};
use argon2::{Algorithm, Argon2, Params, Version};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use cw_core::{Code, Fail};
use cw_key::DbKey;
use serde::{Deserialize, Serialize};

pub const FILE_NAME: &str = "password.json";

/// argon2id's cost: memory in KiB, passes and lanes (OWASP's first choice).
const MEMORY: u32 = 19 * 1024;
const PASSES: u32 = 2;
const LANES: u32 = 1;

/// The most a sealed key may ask of argon2id: a file (a backup) may come from
/// anywhere, and memory it asks for that is not there ends the program.
const MOST: (u32, u32, u32) = (1024 * 1024, 64, 16);

/// A password that was wrong; the API answers it with 401, as one not given
/// where it is needed (`Code::PasswordNeeded`, `CurrentPasswordNeeded`,
/// `BackupPasswordNeeded`).
pub(crate) const WRONG: Fail = Fail::new(Code::PasswordWrong);

/// Whether `failure` is a password refused: wrong, or not given.
fn refused(failure: &anyhow::Error) -> bool {
    cw_core::coded(failure).is_some_and(|fail| {
        matches!(
            fail.code,
            Code::PasswordWrong
                | Code::PasswordNeeded
                | Code::CurrentPasswordNeeded
                | Code::BackupPasswordNeeded
        )
    })
}

/// The database key sealed by a password, with what unseals it but the
/// password. Bytes are base64.
#[derive(Clone, Serialize, Deserialize)]
pub struct Sealed {
    /// argon2id's cost, kept so that a later build may ask more of a new one.
    pub memory: u32,
    pub passes: u32,
    pub(crate) lanes: u32,
    pub(crate) salt: String,
    pub(crate) nonce: String,
    /// The sealed key with its tag.
    pub key: String,
}

/// What `password.json` holds.
#[derive(Serialize, Deserialize)]
struct File {
    #[serde(flatten)]
    sealed: Sealed,
    /// The account's name, for the start screen.
    name: String,
}

fn path(data_dir: &Path) -> PathBuf {
    data_dir.join(FILE_NAME)
}

/// Whether a password is on for `data_dir`.
pub fn is_on(data_dir: &Path) -> bool {
    path(data_dir).exists()
}

/// The sealed key of `data_dir` and the account's name, where a password is on.
pub fn read(data_dir: &Path) -> anyhow::Result<Option<(Sealed, String)>> {
    let text = match std::fs::read_to_string(path(data_dir)) {
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => {
            return Err(e).context(Fail::said(
                Code::Internal,
                "cannot read the password's file",
            ));
        }
    };
    let file: File = serde_json::from_str(&text)
        .context(Fail::said(Code::Internal, "the password's file is damaged"))?;
    Ok(Some((file.sealed, file.name)))
}

/// Puts the password on for `data_dir`, or another in its place: `sealed` is
/// the key it seals, `name` the account's.
pub fn write(data_dir: &Path, sealed: &Sealed, name: &str) -> anyhow::Result<()> {
    let file = File {
        sealed: sealed.clone(),
        name: name.to_string(),
    };
    let beside = data_dir.join(format!("{FILE_NAME}.new"));
    std::fs::write(&beside, serde_json::to_vec_pretty(&file)?).context(Fail::said(
        Code::Internal,
        "cannot write the password's file",
    ))?;
    std::fs::rename(&beside, path(data_dir)).context(Fail::said(
        Code::Internal,
        "cannot write the password's file",
    ))
}

/// Takes the password off `data_dir`.
pub fn remove(data_dir: &Path) -> anyhow::Result<()> {
    match std::fs::remove_file(path(data_dir)) {
        Err(e) if e.kind() != std::io::ErrorKind::NotFound => Err(e).context(Fail::said(
            Code::Internal,
            "cannot remove the password's file",
        )),
        _ => Ok(()),
    }
}

/// Gives the account's name to the file of `data_dir`, where a password is on.
pub fn rename(data_dir: &Path, name: &str) -> anyhow::Result<()> {
    match read(data_dir)? {
        Some((sealed, _)) => write(data_dir, &sealed, name),
        None => Ok(()),
    }
}

/// The key argon2id makes of `password` with `sealed`'s salt and cost.
fn stretch(
    password: &str,
    salt: &[u8],
    (memory, passes, lanes): (u32, u32, u32),
) -> anyhow::Result<[u8; 32]> {
    let params = Params::new(memory, passes, lanes, Some(32)).map_err(|e| {
        anyhow::anyhow!(Fail::said(Code::Internal, format!("argon2id's cost: {e}")))
    })?;
    let mut out = [0u8; 32];
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(password.as_bytes(), salt, &mut out)
        .map_err(|e| anyhow::anyhow!(Fail::said(Code::Internal, format!("argon2id: {e}"))))?;
    Ok(out)
}

/// Seals `key` by `password`, with a salt and a nonce of its own. A password
/// is not empty.
pub fn seal(key: &DbKey, password: &str) -> anyhow::Result<Sealed> {
    ensure!(
        !password.is_empty(),
        Fail::said(Code::Needed, "A password cannot be empty.").with("what", "password")
    );
    let mut salt = [0u8; 16];
    let mut nonce = [0u8; 12];
    getrandom::fill(&mut salt).map_err(|e| {
        anyhow::anyhow!(Fail::said(Code::Internal, format!("no random source: {e}")))
    })?;
    getrandom::fill(&mut nonce).map_err(|e| {
        anyhow::anyhow!(Fail::said(Code::Internal, format!("no random source: {e}")))
    })?;
    let cost = (MEMORY, PASSES, LANES);
    let stretched = stretch(password, &salt, cost)?;
    let sealed = ChaCha20Poly1305::new(Key::from_slice(&stretched))
        .encrypt(Nonce::from_slice(&nonce), key.bytes().as_slice())
        .map_err(|_| anyhow::anyhow!(Fail::said(Code::Internal, "the key could not be sealed")))?;
    Ok(Sealed {
        memory: cost.0,
        passes: cost.1,
        lanes: cost.2,
        salt: STANDARD.encode(salt),
        nonce: STANDARD.encode(nonce),
        key: STANDARD.encode(sealed),
    })
}

/// The key `sealed` holds, if `password` is the one it was sealed by; else [`WRONG`].
pub fn unseal(sealed: &Sealed, password: &str) -> anyhow::Result<DbKey> {
    let bytes = |text: &str| {
        STANDARD.decode(text).context(
            Fail::said(Code::NotReadable, "the sealed key is damaged").with("what", "damaged_key"),
        )
    };
    let (salt, nonce, key) = (
        bytes(&sealed.salt)?,
        bytes(&sealed.nonce)?,
        bytes(&sealed.key)?,
    );
    // argon2id takes no salt under 8 bytes; `seal` writes 16.
    ensure!(
        nonce.len() == 12 && salt.len() >= argon2::MIN_SALT_LEN,
        Fail::said(Code::NotReadable, "the sealed key is damaged").with("what", "damaged_key")
    );
    ensure!(
        sealed.memory <= MOST.0 && sealed.passes <= MOST.1 && sealed.lanes <= MOST.2,
        Fail::said(
            Code::NotReadable,
            "the sealed key asks too much of argon2id: it is damaged"
        )
        .with("what", "damaged_key")
    );
    let stretched = stretch(
        password,
        &salt,
        (sealed.memory, sealed.passes, sealed.lanes),
    )?;
    let opened = ChaCha20Poly1305::new(Key::from_slice(&stretched))
        .decrypt(Nonce::from_slice(&nonce), key.as_slice())
        .map_err(|_| WRONG)?;
    let opened: [u8; 32] = opened.try_into().map_err(|_| {
        anyhow::anyhow!(
            Fail::said(Code::NotReadable, "the sealed key is damaged").with("what", "damaged_key")
        )
    })?;
    Ok(DbKey::from_bytes(opened))
}

/// Another account's password as it is kept: argon2id's PHC string, with a
/// salt of its own and this cost. A password is not empty.
pub fn hash(password: &str) -> anyhow::Result<String> {
    use argon2::password_hash::{PasswordHasher, SaltString, rand_core::OsRng};
    ensure!(
        !password.is_empty(),
        Fail::said(Code::Needed, "A password cannot be empty.").with("what", "password")
    );
    let params = Params::new(MEMORY, PASSES, LANES, None).map_err(|e| {
        anyhow::anyhow!(Fail::said(Code::Internal, format!("argon2id's cost: {e}")))
    })?;
    let salt = SaltString::generate(&mut OsRng);
    let hashed = Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| anyhow::anyhow!(Fail::said(Code::Internal, format!("argon2id: {e}"))))?;
    Ok(hashed.to_string())
}

/// Whether `password` is the one `kept` was made of (by [`hash`]); else
/// [`WRONG`]. Its cost is bounded as a sealed key's (`MOST`): a restored
/// backup may come from anywhere.
pub fn verify(kept: &str, password: &str) -> anyhow::Result<()> {
    use argon2::password_hash::{PasswordHash, PasswordVerifier};
    let parsed = PasswordHash::new(kept).map_err(|_| {
        anyhow::anyhow!(
            Fail::said(Code::NotReadable, "a password kept is damaged").with("what", "damaged_key")
        )
    })?;
    let cost = Params::try_from(&parsed).map_err(|_| {
        anyhow::anyhow!(
            Fail::said(Code::NotReadable, "a password kept is damaged").with("what", "damaged_key")
        )
    })?;
    ensure!(
        cost.m_cost() <= MOST.0 && cost.t_cost() <= MOST.1 && cost.p_cost() <= MOST.2,
        Fail::said(
            Code::NotReadable,
            "a password kept asks too much of argon2id: it is damaged"
        )
        .with("what", "damaged_key")
    );
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .map_err(|_| WRONG.into())
}

/// What a password is tried for: the database's (the start screen, this
/// computer's account), or another account's.
pub type Scope = Option<i64>;

/// Wrong passwords in a row, by what they were tried for and where from.
/// After `FREE` of them a try waits `WAIT` after the last, so that a password
/// cannot be guessed from the home network at argon2id's pace (about 50 a
/// second); one from another place is not held back, so a device that guesses
/// does not lock the owner out.
#[derive(Default)]
pub struct Tries(Mutex<HashMap<(Scope, IpAddr), (u32, Instant)>>);

/// Wrong passwords let through before tries are held back.
const FREE: u32 = 5;
/// How long a try waits after the last wrong one, once `FREE` were wrong.
const WAIT: Duration = Duration::from_secs(30);

impl Tries {
    /// Runs `check` unless `scope` was tried wrongly too often from `from`
    /// lately (`Code::TooManyTries`, 429), and counts a password refused it ends with.
    pub fn attempt<T>(
        &self,
        scope: Scope,
        from: IpAddr,
        check: impl FnOnce() -> anyhow::Result<T>,
    ) -> anyhow::Result<T> {
        let key = (scope, from);
        {
            let mut tried = cw_core::lock(&self.0);
            // Those not tried for a while are let go, so the map stays small.
            tried.retain(|_, (_, last)| last.elapsed() < WAIT * 10);
            let (wrong, last) = tried.entry(key).or_insert((0, Instant::now()));
            if *wrong >= FREE && last.elapsed() < WAIT {
                let seconds = (WAIT - last.elapsed()).as_secs().max(1);
                return Err(Fail::new(Code::TooManyTries)
                    .with("seconds", seconds)
                    .into());
            }
            // Counted as wrong before it is checked, so that tries sent at once are
            // held back as tries one after the other are.
            *wrong += 1;
            *last = Instant::now();
        }
        let outcome = check();
        let mut tried = cw_core::lock(&self.0);
        match &outcome {
            Ok(_) => {
                tried.remove(&key);
            }
            Err(failure) if refused(failure) => {}
            // Not a wrong password: it is not counted.
            Err(_) => {
                if let Some((wrong, _)) = tried.get_mut(&key) {
                    *wrong = wrong.saturating_sub(1);
                }
            }
        }
        outcome
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_sealed_key_with_a_salt_too_short_is_damaged() {
        let mut sealed = seal(&DbKey::generate().unwrap(), "harbour").unwrap();
        sealed.salt = STANDARD.encode([1u8; 4]);
        let refused = unseal(&sealed, "harbour").unwrap_err();
        let fail = refused.downcast_ref::<Fail>().expect("a Fail");
        assert_eq!(fail.code, Code::NotReadable);
    }
}

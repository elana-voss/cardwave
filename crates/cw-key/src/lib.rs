//! The database key and where it is kept.
//!
//! The key is 32 random bytes made on first run. Where it is kept is a [`Place`]:
//! `CARDWAVE_DB_KEY` (64 hex digits) gives it from outside, for servers, CI and
//! tests, and the app keeps it nowhere; otherwise it lives in the operating
//! system's credential store (Windows Credential Manager, macOS Keychain), one
//! entry per data folder under the service `cardwave` (`SERVICE`; a test's own
//! is another, so that no test touches the installed app's entry), so it is
//! never on disk beside the database. While a
//! password is on (`password.rs`), the store holds nothing: `keep` and `forget`
//! put it back and take it out.

use std::fmt;
use std::path::Path;

use anyhow::{Context, bail};

/// The database file's name in a data folder, which the key is kept for.
pub const FILE_NAME: &str = "cardwave.db";

pub(crate) const KEY_ENV: &str = "CARDWAVE_DB_KEY";

/// The credential store's service the app keeps its keys under.
pub(crate) const SERVICE: &str = "cardwave";

#[derive(Clone)]
pub struct DbKey([u8; 32]);

impl DbKey {
    pub fn generate() -> anyhow::Result<Self> {
        let mut bytes = [0u8; 32];
        getrandom::fill(&mut bytes).map_err(|e| anyhow::anyhow!("no random source: {e}"))?;
        Ok(Self(bytes))
    }

    pub fn from_hex(hex: &str) -> anyhow::Result<Self> {
        let hex = hex.trim();
        if hex.len() != 64 || !hex.is_ascii() {
            bail!("a database key is 64 hex digits");
        }
        let mut bytes = [0u8; 32];
        for (i, byte) in bytes.iter_mut().enumerate() {
            *byte = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16)
                .ok()
                .context("a database key is 64 hex digits")?;
        }
        Ok(Self(bytes))
    }

    pub fn to_hex(&self) -> String {
        self.0.iter().map(|b| format!("{b:02x}")).collect()
    }

    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl PartialEq for DbKey {
    fn eq(&self, other: &Self) -> bool {
        self.0 == other.0
    }
}

impl fmt::Debug for DbKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("DbKey(..)")
    }
}

/// Where the key of a data folder is kept while no password is on.
#[derive(Clone, Debug)]
pub enum Place {
    /// The credential store, made and kept by the app under the service named.
    Store(String),
    /// Given from outside (`CARDWAVE_DB_KEY`, a test), and kept by the app nowhere.
    Given(DbKey),
}

impl Place {
    /// `Given` by `CARDWAVE_DB_KEY` where it is set, else the store.
    pub fn from_env() -> anyhow::Result<Self> {
        match std::env::var(KEY_ENV) {
            Ok(hex) => Ok(Self::Given(
                DbKey::from_hex(&hex).with_context(|| format!("invalid {KEY_ENV}"))?,
            )),
            Err(_) => Ok(Self::Store(SERVICE.into())),
        }
    }

    /// The key given, if it is.
    pub fn given(&self) -> Option<&DbKey> {
        match self {
            Self::Given(key) => Some(key),
            Self::Store(_) => None,
        }
    }

    /// The key for the database in `data_dir`, creating and storing a new one
    /// only when there is no database yet.
    pub fn load_or_create(&self, data_dir: &Path) -> anyhow::Result<DbKey> {
        match self {
            Self::Given(key) => Ok(key.clone()),
            Self::Store(service) => {
                std::fs::create_dir_all(data_dir)?;
                store::load_or_create(service, data_dir)
            }
        }
    }

    /// Keeps `key` as the key of `data_dir`, where the app keeps it.
    pub fn keep(&self, data_dir: &Path, key: &DbKey) -> anyhow::Result<()> {
        match self {
            Self::Given(_) => Ok(()),
            Self::Store(service) => store::keep(service, data_dir, key),
        }
    }

    /// Takes the key of `data_dir` out of where the app keeps it.
    pub fn forget(&self, data_dir: &Path) -> anyhow::Result<()> {
        match self {
            Self::Given(_) => Ok(()),
            Self::Store(service) => store::forget(service, data_dir),
        }
    }
}

#[cfg(any(windows, target_os = "macos"))]
mod store {
    use super::*;

    /// One entry per data folder, so two installs or profiles never share a key.
    pub fn entry(service: &str, data_dir: &Path) -> anyhow::Result<keyring::Entry> {
        let account = data_dir.canonicalize()?.to_string_lossy().into_owned();
        keyring::Entry::new(service, &account).context("cannot reach the credential store")
    }

    pub fn load_or_create(service: &str, data_dir: &Path) -> anyhow::Result<DbKey> {
        let entry = entry(service, data_dir)?;
        match entry.get_password() {
            Ok(hex) => DbKey::from_hex(&hex).context("the stored database key is damaged"),
            Err(keyring::Error::NoEntry) => {
                if data_dir.join(FILE_NAME).exists() {
                    bail!(
                        "the database in {} exists but its key is not in the credential store; set {KEY_ENV} to open it",
                        data_dir.display()
                    );
                }
                let key = DbKey::generate()?;
                keep(service, data_dir, &key)?;
                Ok(key)
            }
            Err(e) => Err(e).context("cannot read the database key from the credential store"),
        }
    }

    pub fn keep(service: &str, data_dir: &Path, key: &DbKey) -> anyhow::Result<()> {
        entry(service, data_dir)?
            .set_password(&key.to_hex())
            .context("cannot store the database key")
    }

    pub fn forget(service: &str, data_dir: &Path) -> anyhow::Result<()> {
        match entry(service, data_dir)?.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(e).context("cannot take the database key out of the credential store"),
        }
    }
}

#[cfg(not(any(windows, target_os = "macos")))]
mod store {
    use super::*;

    const NONE: &str =
        "no credential store on this platform yet; set CARDWAVE_DB_KEY to 64 hex digits";

    pub fn load_or_create(_service: &str, _data_dir: &Path) -> anyhow::Result<DbKey> {
        bail!(NONE)
    }

    pub fn keep(_service: &str, _data_dir: &Path, _key: &DbKey) -> anyhow::Result<()> {
        bail!(NONE)
    }

    pub fn forget(_service: &str, _data_dir: &Path) -> anyhow::Result<()> {
        bail!(NONE)
    }
}

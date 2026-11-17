//! The credential store's entry of a data folder (`keyring`): Windows
//! Credential Manager, Linux's Secret Service. On Linux, where no Secret
//! Service answers (WSL, some light desktops), the key is a file (`file.rs`);
//! once there, that data folder's key stays in the file, so a key is never
//! looked for in one place while it lives in the other. Windows always has its
//! store, so there no file stands in (the `cfg`s below).

use std::path::Path;

use anyhow::{Context, bail};

use crate::{DbKey, FILE_NAME, KEY_ENV};

#[cfg(target_os = "linux")]
mod file;

/// One entry per data folder, so two installs or profiles never share a key.
fn account(data_dir: &Path) -> anyhow::Result<String> {
    Ok(data_dir.canonicalize()?.to_string_lossy().into_owned())
}

fn entry(service: &str, account: &str) -> keyring::Result<keyring::Entry> {
    keyring::Entry::new(service, account)
}

pub fn load_or_create(service: &str, data_dir: &Path) -> anyhow::Result<DbKey> {
    let account = account(data_dir)?;
    #[cfg(target_os = "linux")]
    if let Some(key) = file::load(service, &account)? {
        return Ok(key);
    }
    match entry(service, &account).and_then(|entry| entry.get_password()) {
        Ok(hex) => DbKey::from_hex(&hex).context("the stored database key is damaged"),
        Err(keyring::Error::NoEntry) => create(service, data_dir),
        #[cfg(target_os = "linux")]
        Err(e) if file::takes(&e) => create(service, data_dir),
        Err(e) => Err(e).context("cannot read the database key from the credential store"),
    }
}

/// A new key for a data folder without a database, kept.
fn create(service: &str, data_dir: &Path) -> anyhow::Result<DbKey> {
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

pub fn keep(service: &str, data_dir: &Path, key: &DbKey) -> anyhow::Result<()> {
    let account = account(data_dir)?;
    #[cfg(target_os = "linux")]
    if file::holds(service, &account)? {
        return file::keep(service, &account, key);
    }
    match entry(service, &account).and_then(|entry| entry.set_password(&key.to_hex())) {
        Ok(()) => Ok(()),
        #[cfg(target_os = "linux")]
        Err(e) if file::takes(&e) => file::keep(service, &account, key),
        Err(e) => Err(e).context("cannot store the database key"),
    }
}

pub fn forget(service: &str, data_dir: &Path) -> anyhow::Result<()> {
    let account = account(data_dir)?;
    #[cfg(target_os = "linux")]
    let removed_file = file::forget(service, &account)?;
    match entry(service, &account).and_then(|entry| entry.delete_credential()) {
        Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
        #[cfg(target_os = "linux")]
        Err(e) if file::forgotten(removed_file, &e) => Ok(()),
        Err(e) => Err(e).context("cannot take the database key out of the credential store"),
    }
}

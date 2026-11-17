//! The key in a file, on a Linux where no Secret Service answers: in the
//! system's config folder (`~/.config/<service>/`, mode 700), apart from the
//! data folder, a file per data folder named by the SHA-256 of its path,
//! holding the key's hex, mode 600, as Chromium and VS Code keep theirs there.
//! The owner's question (where the key is kept without a Secret Service) is
//! open; this is what was taken meanwhile.

use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Path, PathBuf};

use anyhow::Context;
use sha2::{Digest, Sha256};

use crate::DbKey;

/// Whether `failure` says no Secret Service answers, so the file stands in.
pub fn takes(failure: &keyring::Error) -> bool {
    matches!(
        failure,
        keyring::Error::PlatformFailure(_) | keyring::Error::NoStorageAccess(_)
    )
}

/// Whether forgetting may count as done though the Secret Service failed with
/// `failure`: the key's file was there (`removed_file`), or no Secret Service
/// runs at all. A locked one (or its prompt dismissed) may still hold the key.
pub fn forgotten(removed_file: bool, failure: &keyring::Error) -> bool {
    removed_file || matches!(failure, keyring::Error::PlatformFailure(_))
}

/// The folder the keys of `service` are kept in.
fn folder(service: &str) -> anyhow::Result<PathBuf> {
    Ok(dirs::config_dir()
        .context("no config folder for the database key")?
        .join(service))
}

fn path(folder: &Path, account: &str) -> PathBuf {
    let name = crate::hex(&Sha256::digest(account.as_bytes()));
    folder.join(format!("{name}.key"))
}

pub fn holds(service: &str, account: &str) -> anyhow::Result<bool> {
    Ok(path(&folder(service)?, account).exists())
}

pub fn load(service: &str, account: &str) -> anyhow::Result<Option<DbKey>> {
    load_in(&folder(service)?, account)
}

pub fn keep(service: &str, account: &str, key: &DbKey) -> anyhow::Result<()> {
    keep_in(&folder(service)?, account, key)
}

/// Whether a file held the key.
pub fn forget(service: &str, account: &str) -> anyhow::Result<bool> {
    forget_in(&folder(service)?, account)
}

fn load_in(folder: &Path, account: &str) -> anyhow::Result<Option<DbKey>> {
    match std::fs::read_to_string(path(folder, account)) {
        Ok(hex) => Ok(Some(
            DbKey::from_hex(&hex).context("the stored database key is damaged")?,
        )),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e).context("cannot read the database key's file"),
    }
}

/// Written beside, then renamed over, so a key is never half written.
fn keep_in(folder: &Path, account: &str, key: &DbKey) -> anyhow::Result<()> {
    std::fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(folder)
        .context("cannot make the database key's folder")?;
    let to = path(folder, account);
    let beside = to.with_extension("new");
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&beside)
        .context("cannot write the database key's file")?;
    file.write_all(key.to_hex().as_bytes())?;
    file.sync_all()?;
    std::fs::rename(&beside, &to).context("cannot write the database key's file")
}

fn forget_in(folder: &Path, account: &str) -> anyhow::Result<bool> {
    match std::fs::remove_file(path(folder, account)) {
        Ok(()) => Ok(true),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(e).context("cannot remove the database key's file"),
    }
}

#[cfg(test)]
mod tests {
    use std::os::unix::fs::PermissionsExt;

    use super::*;

    #[test]
    fn the_key_is_a_file_only_the_user_reads_and_goes_when_forgotten() {
        let folder = std::env::temp_dir()
            .join(format!("cw-key-file-{}", std::process::id()))
            .join("cardwave");
        let key = DbKey::generate().unwrap();
        keep_in(&folder, "/data/one", &key).unwrap();
        let file = path(&folder, "/data/one");
        let mode = |path: &Path| std::fs::metadata(path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode(&file), 0o600);
        assert_eq!(mode(&folder), 0o700);
        assert_eq!(load_in(&folder, "/data/one").unwrap(), Some(key));
        assert_eq!(load_in(&folder, "/data/two").unwrap(), None);
        assert!(forget_in(&folder, "/data/one").unwrap());
        assert!(!file.exists());
        assert!(!forget_in(&folder, "/data/one").unwrap());
        std::fs::remove_dir_all(folder.parent().unwrap()).unwrap();
    }

    #[test]
    fn a_locked_secret_service_without_the_file_is_not_forgotten() {
        let locked = || keyring::Error::NoStorageAccess("locked".into());
        let none = || keyring::Error::PlatformFailure("no service".into());
        assert!(!forgotten(false, &locked()));
        assert!(forgotten(true, &locked()));
        assert!(forgotten(false, &none()));
    }
}

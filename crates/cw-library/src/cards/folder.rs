//! A folder of cards imported: its card files found ([`card_files`], every PNG and JSON file in it and in its
//! subfolders, links not followed, each with its [`Stamp`]) and each imported as a file sent alone is
//! ([`import_file`]), under its file's name. A file the library has already ([`super::in_library`]) is
//! skipped, not failed; a file that holds no card ([`super::not_a_card`]) is passed over silently and kept in
//! the user's list of them ([`KeptFiles::NotCards`], by path, size and time written), so it is not read
//! again while unchanged; a file the watched folder took is kept so too ([`KeptFiles::Watched`]) and
//! skipped unread at every later start while unchanged, even where its card has since gone; a PNG is first checked by its chunks' headers alone (`png::holds_card_chunk`), and only one
//! that may hold a card is read whole. How far an import has come is [`FolderImport`]; the job that runs
//! it, file by file, is `api/card_folder.rs`; which files a watched folder takes, `watch.rs`.

use std::path::{Path, PathBuf};
use std::time::SystemTime;

use cw_ccv4::{png, sillytavern};
use cw_core::{Code, ErrorBody, Fail};
use serde::Serialize;
use ts_rs::TS;

use crate::cards::{Imported, KeptFiles, Storage, import_named, is_in_library, is_not_a_card};
use crate::failures::{self, Failures};

/// How far the import of a folder of cards has come.
#[derive(Clone, Debug, Default, Serialize, TS)]
#[ts(export)]
pub struct FolderImport {
    pub folder: String,
    /// Whether it is still going on.
    pub running: bool,
    /// The card files found in the folder and its subfolders, and the subfolders that could not be read
    /// (failed at once): as many as will be imported, skipped and failed together; 0 until they are found.
    /// A file found to hold no card is taken off again.
    pub found: usize,
    /// Of those, the cards imported, the files the library has already, and those that failed.
    pub imported: usize,
    pub skipped: usize,
    pub failed: Vec<FailedFile>,
}

/// A file of the folder that could not be imported, and why.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct FailedFile {
    /// Its path within the folder.
    pub name: String,
    /// Why, as the UI words it.
    pub reason: ErrorBody,
}

/// Why a file was not imported, as the UI words it; the store failing in it is `internal`.
pub fn why(store: &dyn Failures, error: impl Into<anyhow::Error>) -> ErrorBody {
    failures::told(store, &error.into(), Code::FileNotImported)
}

/// Why a folder or file could not be read, as the UI words it (no store is asked there).
pub fn unread(error: impl Into<anyhow::Error>) -> ErrorBody {
    cw_core::told(&error.into(), Code::FileNotImported)
}

/// What importing one file came to.
pub enum Outcome {
    Imported(Imported),
    Skipped,
    /// The file holds no card.
    NotCard,
    Failed(FailedFile),
}

/// A file's size and when it was last written, by which a watched folder tells it is written completely.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Stamp {
    pub len: u64,
    pub modified: Option<SystemTime>,
}

/// A card file found, with its [`Stamp`].
pub(crate) type CardFile = (PathBuf, Stamp);

/// The card files of `folder` and its subfolders, in the order of their paths; a subfolder that cannot be
/// read is a failed file of its own. Refused: a folder that cannot be read.
pub fn card_files(folder: &Path) -> anyhow::Result<(Vec<CardFile>, Vec<FailedFile>)> {
    let (mut files, mut failed) = (Vec::new(), Vec::new());
    let mut folders = vec![folder.to_path_buf()];
    anyhow::ensure!(
        folder.is_dir(),
        Fail::said(
            Code::NotPossible,
            format!("there is no folder {}", folder.display())
        )
        .with("what", "no_folder")
        .with("folder", (folder.display()).to_string())
    );
    while let Some(next) = folders.pop() {
        let entries = match std::fs::read_dir(&next) {
            Ok(entries) => entries,
            Err(error) => {
                failed.push(FailedFile {
                    name: name_in(folder, &next),
                    reason: unread(error),
                });
                continue;
            }
        };
        for entry in entries.flatten() {
            let Ok(kind) = entry.file_type() else {
                continue;
            };
            let path = entry.path();
            if kind.is_dir() {
                folders.push(path);
            } else if kind.is_file() && is_card_file(&path) {
                // A file gone since the folder was read is left out.
                let Ok(meta) = entry.metadata() else {
                    continue;
                };
                let stamp = Stamp {
                    len: meta.len(),
                    modified: meta.modified().ok(),
                };
                files.push((path, stamp));
            }
        }
    }
    files.sort_by(|(one, _), (other, _)| one.cmp(other));
    Ok((files, failed))
}

/// Whether the file at `path` may be a card by its name: a PNG or JSON file.
pub(crate) fn is_card_file(path: &Path) -> bool {
    path.extension().is_some_and(|extension| {
        extension.eq_ignore_ascii_case("png") || extension.eq_ignore_ascii_case("json")
    })
}

/// The [`Stamp`] of the file at `path`; none where it is gone, or no file.
pub fn stamp(path: &Path) -> Option<Stamp> {
    let meta = std::fs::metadata(path).ok().filter(|meta| meta.is_file())?;
    Some(Stamp {
        len: meta.len(),
        modified: meta.modified().ok(),
    })
}

/// Imports the card file at `path` of `folder` as a new card of `user`, but where it is larger than `max`
/// bytes, holds no card, or the library has it already; where `watched`, also not where the watched folder
/// took it before as it is now, and then one imported or skipped is kept as taken.
pub fn import_file(
    db: &dyn Storage,
    user: i64,
    folder: &Path,
    path: &Path,
    max: usize,
    watched: bool,
) -> Outcome {
    let failed = |reason: ErrorBody| {
        Outcome::Failed(FailedFile {
            name: name_in(folder, path),
            reason,
        })
    };
    let meta = match std::fs::metadata(path) {
        Ok(meta) => meta,
        Err(error) => return failed(why(db, error)),
    };
    let modified = meta
        .modified()
        .ok()
        .and_then(|at| at.duration_since(SystemTime::UNIX_EPOCH).ok())
        .map_or(0, |since| since.as_millis() as i64);
    let (kept, len) = (path.to_string_lossy(), meta.len());
    let is_kept = |list| db.is_kept_file(list, user, &kept, len, modified);
    match is_kept(KeptFiles::NotCards) {
        Ok(true) => return Outcome::NotCard,
        Ok(false) => {}
        Err(error) => return failed(why(db, error)),
    }
    if watched {
        match is_kept(KeptFiles::Watched) {
            Ok(true) => return Outcome::Skipped,
            Ok(false) => {}
            Err(error) => return failed(why(db, error)),
        }
    }
    let not_card = || match db.keep_file(KeptFiles::NotCards, user, &kept, len, modified) {
        Ok(()) => Outcome::NotCard,
        Err(error) => failed(why(db, error)),
    };
    if !may_hold_card(path) {
        return not_card();
    }
    if len > max as u64 {
        let large = Fail::said(
            Code::TooBig,
            format!("larger than {} MB", max / 1024 / 1024),
        )
        .with("what", "card_file")
        .with("most", max / 1024 / 1024);
        return failed(large.into());
    }
    let file = match std::fs::read(path) {
        Ok(file) => file,
        Err(error) => return failed(why(db, error)),
    };
    // A JSON file that is no object (a list, text) would otherwise be read as a PNG and fail.
    if !is_png(path) && !crate::cards::store::is_json_object(&file) {
        return not_card();
    }
    let name = path.file_name().map(|name| name.to_string_lossy());
    let outcome = match import_named(db, user, &file, name.as_deref()) {
        Ok(imported) => Outcome::Imported(imported),
        Err(error) if is_in_library(&error) => Outcome::Skipped,
        Err(error) if is_not_a_card(&error) => return not_card(),
        Err(error) => return failed(why(db, error)),
    };
    // Kept by the stamp read before the file was: one written anew meanwhile is read again.
    if watched && let Err(error) = db.keep_file(KeptFiles::Watched, user, &kept, len, modified) {
        // That costs only a reading of the file at the next start.
        tracing::warn!("{kept} is not kept as taken: {error:#}");
    }
    outcome
}

/// Whether the file at `path` may hold a card before it is read whole: a PNG by its chunks' headers; any
/// other file (JSON) and a PNG that cannot be opened (whose reading then says why) may.
fn may_hold_card(path: &Path) -> bool {
    if !is_png(path) {
        return true;
    }
    // Unbuffered: a header is 8 bytes, and a buffer would be filled anew after each seek.
    let Ok(mut file) = std::fs::File::open(path) else {
        return true;
    };
    png::holds_card_chunk(&mut file, sillytavern::is_card_keyword).unwrap_or(true)
}

/// Whether the file at `path` is a PNG by its name.
fn is_png(path: &Path) -> bool {
    path.extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("png"))
}

/// `path` as it is within `folder`, with `/` between its parts; `.` for the folder itself.
fn name_in(folder: &Path, path: &Path) -> String {
    let within = path.strip_prefix(folder).unwrap_or(path);
    let name = within
        .components()
        .map(|part| part.as_os_str().to_string_lossy())
        .collect::<Vec<_>>()
        .join("/");
    if name.is_empty() {
        ".".to_string()
    } else {
        name
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_folder_itself_is_named_a_dot_and_a_file_by_its_path_within() {
        let folder = Path::new("C:/cards");
        assert_eq!(name_in(folder, folder), ".");
        assert_eq!(
            name_in(folder, &folder.join("more").join("a.png")),
            "more/a.png"
        );
    }
}

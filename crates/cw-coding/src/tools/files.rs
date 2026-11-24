//! The file tools: a folder's files listed, read and written, and nothing
//! outside it. A path is the model's, relative to the folder; one that leads
//! out of it, by `..`, a drive, or a link or junction inside it that points
//! elsewhere or nowhere, is refused (`inside`). Each gives a `Gave`; each
//! failure of its own is a `Fail` with its code and `what`, whose sentence is
//! what the model reads.

use std::fs;
use std::path::{Component, Path, PathBuf};

use anyhow::Context;
use cw_core::{Code, Fail};

use crate::tools::gave::{Gave, Listed};
use crate::tools::web::TEXT_LIMIT;

/// The most of a file that is read, in bytes.
const READ_LIMIT: u64 = 256 * 1024;

/// The most a file written may hold, in bytes.
pub(crate) const WRITE_LIMIT: usize = 1 << 20;

/// The most lines a listing has.
const LISTED: usize = 200;

/// A path that leads out of the folder.
fn outside() -> Fail {
    Fail::said(
        Code::NotPossible,
        "only paths inside the folder are allowed",
    )
    .with("what", "path_outside")
}

/// The place of `path` in `folder`, where it does not lead out of it.
pub fn inside(folder: &Path, path: &str) -> anyhow::Result<PathBuf> {
    let root = fs::canonicalize(folder).context(
        Fail::said(Code::NotReadable, "the folder is not there").with("what", "folder_in_task"),
    )?;
    let path = Path::new(path.trim());
    for part in path.components() {
        match part {
            Component::Normal(_) | Component::CurDir => {}
            _ => return Err(outside().into()),
        }
    }
    let place = root.join(path);
    // What is there of the path already must be in the folder once its links
    // are followed; a link that leads nowhere is there, and is refused.
    let mut there = place.as_path();
    while fs::symlink_metadata(there).is_err() {
        there = there.parent().ok_or_else(outside)?;
    }
    let real = fs::canonicalize(there).context(outside())?;
    if !real.starts_with(&root) {
        return Err(outside().into());
    }
    Ok(place)
}

/// The files and folders in `path` of `folder`, sorted as the model reads them.
pub fn list(folder: &Path, path: &str) -> anyhow::Result<Gave> {
    let place = inside(folder, path)?;
    let mut entries: Vec<Listed> = fs::read_dir(&place)
        .context(Fail::said(Code::NotReadable, "there is no such folder").with("what", "folder"))?
        .filter_map(Result::ok)
        .map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            let meta = entry.metadata().ok();
            let folder = meta.as_ref().is_some_and(fs::Metadata::is_dir);
            let bytes = meta.filter(|_| !folder).map(|meta| meta.len());
            Listed {
                name,
                folder,
                bytes,
            }
        })
        .collect();
    entries.sort_by_cached_key(Listed::line);
    let more = entries.len().saturating_sub(LISTED);
    entries.truncate(LISTED);
    Ok(Gave::Listing { entries, more })
}

/// The text of the file at `path` in `folder`.
pub fn read(folder: &Path, path: &str) -> anyhow::Result<Gave> {
    use std::io::Read;
    let place = inside(folder, path)?;
    let mut bytes = Vec::new();
    fs::File::open(&place)
        .context(Fail::said(Code::NotReadable, "there is no such file").with("what", "file"))?
        .take(READ_LIMIT)
        .read_to_end(&mut bytes)?;
    Ok(Gave::text(&String::from_utf8_lossy(&bytes), TEXT_LIMIT))
}

/// Writes `content` to the file at `path` in `folder`, with the folders it is in.
pub fn write(folder: &Path, path: &str, content: &str) -> anyhow::Result<Gave> {
    let megabytes = WRITE_LIMIT >> 20;
    if content.len() > WRITE_LIMIT {
        let said = format!("a file of more than {megabytes} MB is not written");
        let fail = Fail::said(Code::TooBig, said).with("what", "file_written");
        return Err(fail.with("megabytes", megabytes).into());
    }
    let place = inside(folder, path)?;
    if place.is_dir() {
        let fail = Fail::said(Code::NotPossible, "that is a folder").with("what", "write_folder");
        return Err(fail.into());
    }
    if let Some(parent) = place.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&place, content)?;
    Ok(Gave::Wrote {
        bytes: content.len(),
        path: path.trim().to_string(),
    })
}

//! The file tools: a folder's files listed, read and written, and nothing
//! outside it. A path is the model's, relative to the folder; one that leads
//! out of it, by `..`, a drive, or a link or junction inside it that points
//! elsewhere or nowhere, is refused (`inside`).

use std::fs;
use std::path::{Component, Path, PathBuf};

use anyhow::{Context, bail, ensure};

use crate::tools::web::{TEXT_LIMIT, cut};

/// The most of a file that is read, in bytes.
const READ_LIMIT: u64 = 256 * 1024;

/// The most a file written may hold, in bytes.
pub(crate) const WRITE_LIMIT: usize = 1 << 20;

/// The most lines a listing has.
const LISTED: usize = 200;

/// The place of `path` in `folder`, where it does not lead out of it.
pub fn inside(folder: &Path, path: &str) -> anyhow::Result<PathBuf> {
    let root = fs::canonicalize(folder).context("the folder is not there")?;
    let path = Path::new(path.trim());
    for part in path.components() {
        match part {
            Component::Normal(_) | Component::CurDir => {}
            _ => bail!("only paths inside the folder are allowed"),
        }
    }
    let place = root.join(path);
    // What is there of the path already must be in the folder once its links
    // are followed; a link that leads nowhere is there, and is refused.
    let mut there = place.as_path();
    while fs::symlink_metadata(there).is_err() {
        there = there
            .parent()
            .context("only paths inside the folder are allowed")?;
    }
    let real = fs::canonicalize(there).context("only paths inside the folder are allowed")?;
    ensure!(
        real.starts_with(&root),
        "only paths inside the folder are allowed"
    );
    Ok(place)
}

/// The files and folders in `path` of `folder`, a folder each with `/` after it.
pub fn list(folder: &Path, path: &str) -> anyhow::Result<String> {
    let place = inside(folder, path)?;
    let mut names: Vec<String> = fs::read_dir(&place)
        .context("there is no such folder")?
        .filter_map(Result::ok)
        .map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            match entry.metadata() {
                Ok(meta) if meta.is_dir() => format!("{name}/"),
                Ok(meta) => format!("{name} ({} bytes)", meta.len()),
                Err(_) => name,
            }
        })
        .collect();
    names.sort();
    if names.is_empty() {
        return Ok("The folder is empty.".into());
    }
    let more = names.len().saturating_sub(LISTED);
    names.truncate(LISTED);
    if more > 0 {
        names.push(format!("[{more} more]"));
    }
    Ok(names.join("\n"))
}

/// The text of the file at `path` in `folder`.
pub fn read(folder: &Path, path: &str) -> anyhow::Result<String> {
    use std::io::Read;
    let place = inside(folder, path)?;
    let mut bytes = Vec::new();
    fs::File::open(&place)
        .context("there is no such file")?
        .take(READ_LIMIT)
        .read_to_end(&mut bytes)?;
    Ok(cut(&String::from_utf8_lossy(&bytes), TEXT_LIMIT))
}

/// Writes `content` to the file at `path` in `folder`, with the folders it is in.
pub fn write(folder: &Path, path: &str, content: &str) -> anyhow::Result<String> {
    ensure!(
        content.len() <= WRITE_LIMIT,
        "a file of more than {} MB is not written",
        WRITE_LIMIT >> 20
    );
    let place = inside(folder, path)?;
    ensure!(!place.is_dir(), "that is a folder");
    if let Some(parent) = place.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&place, content)?;
    Ok(format!("Wrote {} bytes to {}.", content.len(), path.trim()))
}

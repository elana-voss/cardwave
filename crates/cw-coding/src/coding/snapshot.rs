//! A task's folder as its files hold it (`Snapshot`), read before the first
//! step and after each, so that what a step changed is the difference of two
//! (`changes`), whoever made it: a file the worker wrote, or one a command
//! wrote. A change keeps the file as it was before and after, which puts it
//! back (`restore`) and draws its diff (`diff`).
//!
//! Left out, as no undo needs them and they would make a snapshot huge: the
//! folders `SKIPPED` (a repository's own, packages installed), those a marker
//! file says are a build or an environment (`MARKED`), and files over
//! `FILE_LIMIT`. A folder that holds more than `MOST_FILES` or `MOST_BYTES`
//! besides is refused. A file that cannot be read (locked, gone meanwhile) is
//! noted as unread, and no change of it is counted.

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};
use similar::{ChangeTag, TextDiff};

/// Folders a snapshot leaves out, wherever they are.
pub(crate) const SKIPPED: [&str; 3] = [".git", "node_modules", "__pycache__"];

/// Folders a snapshot leaves out where they hold their marker: Cargo's build
/// folder, and Python's environments.
pub(crate) const MARKED: [(&str, &str); 3] = [
    ("target", "CACHEDIR.TAG"),
    ("venv", "pyvenv.cfg"),
    (".venv", "pyvenv.cfg"),
];

/// The largest file a snapshot keeps.
pub const FILE_LIMIT: u64 = 1 << 20;

/// The most files and bytes a snapshot holds.
pub(crate) const MOST_FILES: usize = 20_000;
pub(crate) const MOST_BYTES: usize = 200 << 20;

/// The longest diff of a file that is drawn, in lines.
const DIFF_LINES: usize = 2_000;

/// The files of a folder by their paths in it, with `/` between folders, and
/// the paths of those that could not be read.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Snapshot(pub BTreeMap<String, Vec<u8>>, pub BTreeSet<String>);

/// A file a step changed: as it was before and after (`None`: not there).
#[derive(Clone, Debug, PartialEq)]
pub struct Change {
    pub path: String,
    pub before: Option<Vec<u8>>,
    pub after: Option<Vec<u8>>,
}

impl Snapshot {
    /// Reads `folder`. Blocks.
    pub fn read(folder: &Path) -> anyhow::Result<Self> {
        let mut files = BTreeMap::new();
        let mut unread = BTreeSet::new();
        let mut bytes = 0;
        let mut open = vec![folder.to_path_buf()];
        while let Some(dir) = open.pop() {
            let entries = std::fs::read_dir(&dir).with_context(|| {
                Fail::said(
                    Code::NotReadable,
                    format!("{} cannot be read", dir.display()),
                )
                .with("what", "folder_read")
                .with("dir", (dir.display()).to_string())
            })?;
            // What vanished meanwhile is not there.
            for entry in entries.flatten() {
                let Ok(kind) = entry.file_type() else {
                    continue;
                };
                let name = entry.file_name().to_string_lossy().into_owned();
                let path = entry.path();
                if kind.is_dir() {
                    let marked = MARKED
                        .iter()
                        .any(|(folder, marker)| name == *folder && path.join(marker).is_file());
                    if !SKIPPED.contains(&name.as_str()) && !marked {
                        open.push(path);
                    }
                    continue;
                }
                let size = entry.metadata().map(|data| data.len()).unwrap_or(0);
                if !kind.is_file() || size > FILE_LIMIT {
                    continue;
                }
                let inside = path
                    .strip_prefix(folder)?
                    .to_string_lossy()
                    .replace('\\', "/");
                let Ok(data) = std::fs::read(&path) else {
                    unread.insert(inside);
                    continue;
                };
                bytes += data.len();
                files.insert(inside, data);
                ensure!(files.len() <= MOST_FILES && bytes <= MOST_BYTES, Fail::said(Code::TooBig, format!("the folder holds too much to keep checkpoints of (more than {MOST_FILES} files or {} MB); choose the project's own folder", MOST_BYTES >> 20)).with("what", "checkpoint_folder").with("most_files", MOST_FILES));
            }
        }
        Ok(Self(files, unread))
    }

    /// What changed from `self` to `after`, by path; of a file that one of
    /// them could not read, nothing.
    pub fn changes(&self, after: &Snapshot) -> Vec<Change> {
        self.changed(after)
            .into_iter()
            .map(|path| Change {
                path: path.clone(),
                before: self.0.get(path).cloned(),
                after: after.0.get(path).cloned(),
            })
            .collect()
    }

    /// [`Self::changes`], each file as it was before moved out of `self`
    /// rather than copied, where `self` is done with.
    pub(crate) fn into_changes(mut self, after: &Snapshot) -> Vec<Change> {
        let paths: Vec<String> = self.changed(after).into_iter().cloned().collect();
        paths
            .into_iter()
            .map(|path| Change {
                before: self.0.remove(&path),
                after: after.0.get(&path).cloned(),
                path,
            })
            .collect()
    }

    /// The paths of the files that differ from `self` to `after`, in order.
    fn changed<'a>(&'a self, after: &'a Snapshot) -> Vec<&'a String> {
        let mut paths: Vec<&String> = self.0.keys().chain(after.0.keys()).collect();
        paths.sort();
        paths.dedup();
        paths.retain(|path| !self.1.contains(*path) && !after.1.contains(*path));
        paths.retain(|path| self.0.get(*path) != after.0.get(*path));
        paths
    }
}

/// Puts the file of `change` back as it was before it, in `folder`.
pub fn restore(folder: &Path, change: &Change) -> anyhow::Result<()> {
    let path = folder.join(&change.path);
    match &change.before {
        Some(data) => {
            if let Some(parent) = path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::write(&path, data)
        }
        None => match std::fs::remove_file(&path) {
            Err(error) if error.kind() != std::io::ErrorKind::NotFound => Err(error),
            _ => Ok(()),
        },
    }
    .with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("{} cannot be put back", change.path),
        )
        .with("what", "checkpoint_put_back")
        .with("path", (change.path).to_string())
    })
}

/// The lines a change adds and removes, and its diff (unified, three lines
/// around each change); a file that is not text has none.
pub(crate) fn diff(before: Option<&[u8]>, after: Option<&[u8]>) -> (usize, usize, String) {
    fn text(data: Option<&[u8]>) -> Option<&str> {
        match data {
            None => Some(""),
            Some(data) => std::str::from_utf8(data).ok(),
        }
    }
    let (Some(old), Some(new)) = (text(before), text(after)) else {
        return (0, 0, "(not text)".to_string());
    };
    let lines = TextDiff::from_lines(old, new);
    let (mut added, mut removed) = (0, 0);
    for change in lines.iter_all_changes() {
        match change.tag() {
            ChangeTag::Insert => added += 1,
            ChangeTag::Delete => removed += 1,
            ChangeTag::Equal => {}
        }
    }
    let unified = lines.unified_diff().context_radius(3).to_string();
    let mut shown: Vec<&str> = unified.lines().take(DIFF_LINES).collect();
    if unified.lines().count() > DIFF_LINES {
        shown.push("…");
    }
    (added, removed, shown.join("\n"))
}

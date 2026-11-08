//! Which card files of the watched cards folder are imported ("Import new cards automatically"): the
//! folder is walked once, as the watch starts on it ([`Watch::look`] at another folder, after the app's
//! start or the switch turned on); after that the system tells of changes (the `notify` crate:
//! ReadDirectoryChangesW, FSEvents, inotify) and only the files it names are looked at, every few seconds
//! (`api/card_folder.rs`). A file is taken once it is written completely, that is once its [`Stamp`] is the
//! same at two looks in a row, and again only where it is written anew. The first look at a folder takes
//! nothing, the second every file in it then (cards added while the app was closed too; those it took
//! before, unchanged, are skipped unread by their stamp, `folder.rs`). A folder a change names as come in
//! (made, moved in) is walked; where the system lost changes (`need_rescan`, an error) the whole folder is
//! walked again.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{Receiver, channel};

use notify::event::ModifyKind;
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};

use crate::cards::folder::{self, CardFile, Stamp};

/// What the looks at the watched folder have seen and taken.
#[derive(Default)]
pub struct Watch {
    folder: PathBuf,
    /// The system's watch on `folder`, and what it tells; none before the first look at it.
    told: Option<(RecommendedWatcher, Receiver<notify::Result<Event>>)>,
    /// The files to look at, each with its stamp at the last look (none before the first).
    pending: HashMap<PathBuf, Option<Stamp>>,
    /// The files taken, as they were then.
    taken: HashMap<PathBuf, Stamp>,
    /// How often the whole folder was walked, which tests count.
    walks: usize,
}

impl Watch {
    /// Of the card files of `folder`, those to import now: unchanged since the last look and not taken as
    /// they are. Another folder than the last look's starts anew, walked whole. Refused: a folder that
    /// cannot be watched or walked (then the next look starts anew).
    pub fn look(&mut self, folder: &Path) -> anyhow::Result<Vec<PathBuf>> {
        if self.folder != folder || self.told.is_none() {
            self.forget();
            let (send, told) = channel();
            let mut watcher = notify::recommended_watcher(send)?;
            watcher.watch(folder, RecursiveMode::Recursive)?;
            self.folder = folder.to_path_buf();
            self.told = Some((watcher, told));
            self.walk(folder)?;
        } else {
            self.take_changes()?;
        }
        Ok(self.settle(folder::stamp))
    }

    /// Puts the files the system told of among those to look at.
    fn take_changes(&mut self) -> anyhow::Result<()> {
        let changed: Vec<notify::Result<Event>> = match &self.told {
            Some((_, told)) => told.try_iter().collect(),
            None => return Ok(()),
        };
        let mut rescan = false;
        for change in changed {
            match change {
                Ok(event) if event.need_rescan() => rescan = true,
                Ok(Event {
                    kind: EventKind::Access(_),
                    ..
                }) => {}
                Ok(event) => self.take_event(event),
                Err(failure) => {
                    tracing::info!("the folder of cards is walked again: {failure}");
                    rescan = true;
                }
            }
        }
        if rescan {
            let whole = self.folder.clone();
            self.walk(&whole)?;
        }
        Ok(())
    }

    /// Puts the card files a change names among those to look at, and those of a folder it names as come in
    /// (made, or moved in): Windows names a folder also where only a file in it changed, which is not walked.
    /// A folder gone again since is let go.
    fn take_event(&mut self, event: Event) {
        let came_in = matches!(
            event.kind,
            EventKind::Create(_) | EventKind::Modify(ModifyKind::Name(_))
        );
        for path in event.paths {
            if path.is_dir() {
                if !came_in {
                    continue;
                }
                match folder::card_files(&path) {
                    Ok((files, _)) => self.found(files),
                    Err(failure) => tracing::debug!("a folder come in is not walked: {failure:#}"),
                }
            } else if folder::is_card_file(&path) {
                self.pending.entry(path).or_insert(None);
            }
        }
    }

    /// Puts every card file of `within` among those to look at, as they are now.
    fn walk(&mut self, within: &Path) -> anyhow::Result<()> {
        let (files, _) = folder::card_files(within)?;
        if within == self.folder {
            self.walks += 1;
        }
        self.found(files);
        Ok(())
    }

    /// Files found by a walk: stamped at the next look, taken at the one after where they hold still.
    fn found(&mut self, files: Vec<CardFile>) {
        for (path, _) in files {
            self.pending.entry(path).or_insert(None);
        }
    }

    /// Of the files to look at, those whose stamp (`stamp_of`, none for a file gone) is the one of the
    /// last look and not one taken: taken now. A file gone is let go.
    fn settle(&mut self, stamp_of: impl Fn(&Path) -> Option<Stamp>) -> Vec<PathBuf> {
        let mut take = Vec::new();
        let pending = std::mem::take(&mut self.pending);
        for (path, before) in pending {
            let Some(now) = stamp_of(&path) else {
                self.taken.remove(&path);
                continue;
            };
            if before != Some(now) {
                self.pending.insert(path, Some(now));
            } else if self.taken.get(&path) != Some(&now) {
                self.taken.insert(path.clone(), now);
                take.push(path);
            }
        }
        take.sort();
        take
    }

    /// Forgets what was seen and stops the system's watch: the watch is off, or its folder gone.
    pub fn forget(&mut self) {
        let walks = self.walks;
        *self = Self::default();
        self.walks = walks;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use notify::event::CreateKind;
    use std::time::{Duration, Instant, SystemTime};

    fn stamp(len: u64, at: u64) -> Stamp {
        let modified = Some(SystemTime::UNIX_EPOCH + Duration::from_secs(at));
        Stamp { len, modified }
    }

    #[test]
    fn a_file_is_taken_once_unchanged_since_the_last_look_and_again_only_when_written_anew() {
        let mut watch = Watch::default();
        let (a, b) = (PathBuf::from("a.png"), PathBuf::from("b.png"));
        let on_disk = std::cell::RefCell::new(HashMap::from([(a.clone(), stamp(10, 1))]));
        let stamp_of = |path: &Path| on_disk.borrow().get(path).copied();
        watch.found(vec![(a.clone(), stamp(5, 0))]);
        // Stamped at the first look; still being written: larger at the next.
        assert!(watch.settle(stamp_of).is_empty());
        on_disk.borrow_mut().insert(a.clone(), stamp(20, 2));
        on_disk.borrow_mut().insert(b.clone(), stamp(5, 2));
        watch.pending.insert(b.clone(), None);
        assert!(watch.settle(stamp_of).is_empty());
        assert_eq!(watch.settle(stamp_of), [a.clone(), b.clone()]);
        // Told of again, unchanged: not taken again.
        watch.pending.insert(a.clone(), None);
        assert!(watch.settle(stamp_of).is_empty());
        assert!(watch.settle(stamp_of).is_empty());
        // Written anew, it is taken again once it holds still.
        on_disk.borrow_mut().insert(a.clone(), stamp(30, 3));
        watch.pending.insert(a.clone(), None);
        assert!(watch.settle(stamp_of).is_empty());
        assert_eq!(watch.settle(stamp_of), std::slice::from_ref(&a));
        // Gone: let go.
        on_disk.borrow_mut().clear();
        watch.pending.insert(b.clone(), None);
        assert!(watch.settle(stamp_of).is_empty());
        assert!(watch.pending.is_empty() && !watch.taken.contains_key(&b));
    }

    #[test]
    fn a_folder_is_walked_only_where_it_came_in_and_one_gone_again_is_let_go() {
        let folder = std::env::temp_dir().join(format!("cardwave-watch-in-{}", std::process::id()));
        let inner = folder.join("inner.png");
        std::fs::create_dir_all(&folder).unwrap();
        std::fs::write(&inner, b"one").unwrap();
        let mut watch = Watch::default();
        // Named as changed, as Windows names a folder a file in it changed in: not walked.
        let changed = Event::new(EventKind::Modify(ModifyKind::Any)).add_path(folder.clone());
        watch.take_event(changed);
        assert!(watch.pending.is_empty());
        let made = Event::new(EventKind::Create(CreateKind::Folder)).add_path(folder.clone());
        watch.take_event(made);
        assert_eq!(watch.pending.keys().collect::<Vec<_>>(), [&inner]);
        // Moved in and gone again before it is looked at.
        let gone = Event::new(EventKind::Create(CreateKind::Folder)).add_path(folder.join("gone"));
        watch.take_event(gone);
        assert_eq!(watch.pending.len(), 1);
        std::fs::remove_dir_all(&folder).unwrap();
    }

    /// Looks at `folder` until `wanted` is taken, every 50 ms.
    fn until_taken(watch: &mut Watch, folder: &Path, wanted: &[PathBuf]) {
        let since = Instant::now();
        let mut taken = Vec::new();
        while taken != wanted {
            assert!(
                since.elapsed() < Duration::from_secs(10),
                "taken: {taken:?}"
            );
            std::thread::sleep(Duration::from_millis(50));
            taken.extend(watch.look(folder).unwrap());
        }
    }

    #[test]
    fn the_folder_is_walked_once_and_then_only_what_the_system_tells_of_is_looked_at() {
        let folder = std::env::temp_dir().join(format!("cardwave-watch-{}", std::process::id()));
        std::fs::create_dir_all(&folder).unwrap();
        let first = folder.join("first.png");
        std::fs::write(&first, b"one").unwrap();
        let mut watch = Watch::default();
        assert!(watch.look(&folder).unwrap().is_empty());
        until_taken(&mut watch, &folder, std::slice::from_ref(&first));
        // A file written later, and a folder moved in with one, are told of.
        let later = folder.join("later.json");
        std::fs::write(&later, b"two").unwrap();
        until_taken(&mut watch, &folder, std::slice::from_ref(&later));
        let outside = folder.with_extension("moved");
        std::fs::create_dir_all(&outside).unwrap();
        std::fs::write(outside.join("inner.png"), b"three").unwrap();
        std::fs::rename(&outside, folder.join("moved")).unwrap();
        until_taken(
            &mut watch,
            &folder,
            &[folder.join("moved").join("inner.png")],
        );
        // Files that are no cards are not looked at.
        std::fs::write(folder.join("notes.txt"), b"four").unwrap();
        std::thread::sleep(Duration::from_millis(200));
        assert!(watch.look(&folder).unwrap().is_empty());
        assert!(watch.look(&folder).unwrap().is_empty());
        assert_eq!(watch.walks, 1);
        // Another folder starts anew, walked whole.
        let other = folder.join("moved");
        assert!(watch.look(&other).unwrap().is_empty());
        assert_eq!(watch.walks, 2);
        drop(watch);
        std::fs::remove_dir_all(&folder).unwrap();
    }
}

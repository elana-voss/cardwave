//! The sandbox's own tests, on Windows only.

use crate::tools::sandbox::OUTPUT_LIMIT;
use crate::tools::sandbox::keep;
use crate::tools::sandbox::windows::{copied_for_test as copied, resolve};
use std::cell::Cell;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::sync::atomic::AtomicBool;
use std::time::Duration;

/// cmd runs only the first line of a command; one of several lines is
/// refused, not told as that line's success.
#[test]
fn a_command_of_several_lines_is_refused() {
    let folder = std::env::temp_dir().join(format!("cardwave-lines-{}", std::process::id()));
    std::fs::create_dir_all(&folder).unwrap();
    let ran = crate::tools::sandbox::run(
        &folder,
        "echo one\r\necho two",
        Duration::from_secs(20),
        &AtomicBool::new(false),
    );
    let _ = std::fs::remove_dir_all(&folder);
    let failure = ran.map(|ran| ran.output).unwrap_err().to_string();
    assert!(failure.contains("&&"), "{failure}");
}

/// What cmd writes that is not ASCII (a file's name with an umlaut, its
/// own messages on a Windows not in English) reaches the model whole.
#[test]
fn a_commands_output_keeps_letters_that_are_not_ascii() {
    let folder = std::env::temp_dir().join(format!("cardwave-letters-{}", std::process::id()));
    std::fs::create_dir_all(&folder).unwrap();
    let ran = crate::tools::sandbox::run(
        &folder,
        "echo Straße üä",
        Duration::from_secs(20),
        &AtomicBool::new(false),
    );
    let _ = std::fs::remove_dir_all(&folder);
    let ran = ran.unwrap();
    assert_eq!((ran.code, ran.output.trim()), (Some(0), "Straße üä"));
}

/// A command that prints far more than is used is read to its end, and
/// only its first `OUTPUT_LIMIT` bytes are held meanwhile.
#[test]
fn a_commands_output_is_held_only_up_to_its_limit_while_it_is_read() {
    use std::io::Read;
    let kept = Mutex::new(Vec::new());
    let mut printed = std::io::repeat(b'x').take(64 * OUTPUT_LIMIT as u64);
    keep(&mut printed, &kept);
    assert_eq!(printed.limit(), 0, "read to its end");
    assert_eq!(kept.into_inner().unwrap().len(), OUTPUT_LIMIT);
}

/// A `PATH` folder found empty is not remembered: it is looked at again, so
/// a program installed into it while the server runs is found without a
/// restart; a folder found with programs is remembered and not looked at anew.
#[test]
fn a_path_folder_found_empty_is_not_remembered() {
    let data = Path::new(r"C:\data");
    let mut known = BTreeMap::new();
    let empty = PathBuf::from(r"C:\empty");
    let full = PathBuf::from(r"C:\full");
    let has_tool = Cell::new(false);
    let full_looks = Cell::new(0);
    let mut look = |folder: &Path| -> Option<(PathBuf, Vec<(String, String)>)> {
        if folder == full {
            full_looks.set(full_looks.get() + 1);
            return Some((folder.to_path_buf(), Vec::new()));
        }
        (folder == empty && has_tool.get()).then(|| (folder.to_path_buf(), Vec::new()))
    };
    let folders = || [empty.clone(), full.clone()].into_iter();

    // The empty folder holds no programs: not in the PATH, and not remembered.
    let (path, _) = resolve(folders(), data, &mut known, &mut look);
    assert_eq!(path, full.display().to_string());

    // A program installed into it is found at once, without a restart.
    has_tool.set(true);
    let (path, _) = resolve(folders(), data, &mut known, &mut look);
    assert_eq!(path, format!("{};{}", empty.display(), full.display()));

    // The full folder was looked at once only: it was remembered.
    assert_eq!(full_looks.get(), 1);
}

/// A program updated inside a subfolder of its folder is copied anew,
/// though the folder's own files are as they were.
#[test]
fn a_folder_of_programs_is_copied_anew_when_its_tree_changes() {
    let folder = std::env::temp_dir().join(format!("cardwave-copy-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&folder);
    std::fs::create_dir_all(folder.join("lib")).unwrap();
    std::fs::write(folder.join("tool.exe"), "").unwrap();
    std::fs::write(folder.join("lib/part.js"), "one").unwrap();
    let copy = copied(&folder).unwrap();
    std::fs::write(folder.join("lib/part.js"), "one, two").unwrap();
    assert_eq!(copied(&folder).unwrap(), copy);
    let part = std::fs::read_to_string(copy.join("lib/part.js")).unwrap();
    let _ = std::fs::remove_dir_all(&folder);
    let _ = std::fs::remove_dir_all(&copy);
    assert_eq!(part, "one, two");
}

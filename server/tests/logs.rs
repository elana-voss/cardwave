//! The logs: a request noted in the day's debug log without its query, a
//! panic in the day's crash log with its place, and the files of days before
//! the last seven deleted. `logs::start` sets the process's one subscriber
//! and panic hook, so one test starts them.

mod common;

use chrono::{Local, NaiveDate};
use cw_platform::logs;

#[tokio::test]
async fn a_request_goes_to_the_debug_log_and_a_panic_to_the_crash_log() {
    let server = common::server::start().await;
    let data_dir = server.options().data_dir;
    logs::start(&data_dir).unwrap();
    let (status, _) = server.get("/api/status?secret=words").await;
    assert_eq!(status, 200);
    let folder = logs::folder(&data_dir);
    let today = Local::now().date_naive();
    let debug = std::fs::read_to_string(logs::file_of(&folder, "debug", today)).unwrap();
    assert!(debug.contains("GET /api/status 200 in"), "{debug}");
    assert!(!debug.contains("secret"), "{debug}");

    let crashed = std::thread::spawn(|| panic!("the test's own panic")).join();
    assert!(crashed.is_err());
    let crash = std::fs::read_to_string(logs::file_of(&folder, "crash", today)).unwrap();
    assert!(crash.contains("the test's own panic"), "{crash}");
    assert!(
        crash.contains("tests\\logs.rs:") || crash.contains("tests/logs.rs:"),
        "{crash}"
    );
}

#[test]
fn a_days_files_are_kept_seven_days() {
    let folder = common::Folder::new("logs");
    let day = |text: &str| NaiveDate::parse_from_str(text, "%Y-%m-%d").unwrap();
    for name in [
        "debug-2026-10-14.log",
        "crash-2026-10-13.log",
        "debug-2026-10-13.log",
        "debug-2026-10-20.log",
        "notes.txt",
    ] {
        std::fs::write(folder.0.join(name), "").unwrap();
    }
    logs::prune(&folder.0, day("2026-10-20"));
    let mut left: Vec<String> = std::fs::read_dir(&folder.0)
        .unwrap()
        .map(|file| file.unwrap().file_name().into_string().unwrap())
        .collect();
    left.sort();
    assert_eq!(
        left,
        ["debug-2026-10-14.log", "debug-2026-10-20.log", "notes.txt"]
    );
}

//! The logs a bug report is sent with, in the data folder's `logs`: the debug
//! log `debug-<day>.log`, what the program notes as it works (each request, `api::noted`, and what
//! the areas say through `tracing`),
//! and the crash log `crash-<day>.log`, each panic with where it happened and
//! its backtrace. A file a day (this computer's day), kept `KEPT_DAYS` days:
//! older ones are deleted at `start` and when a new day's file begins.
//! `start` is called once by each program (`main.rs`, the desktop's), which
//! also prints what is noted to the terminal as before (`RUST_LOG`, else info).
//!
//! Trap: the logs are plain text, not encrypted as the database is, so nothing
//! written in the app (a chat's, a card's words, a search) goes into a
//! `tracing` call; a request's query is left out for that reason.

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use chrono::{Local, NaiveDate};
use tracing_subscriber::EnvFilter;
use tracing_subscriber::fmt::MakeWriter;
use tracing_subscriber::prelude::*;

/// How many days' files are kept, today's among them.
pub(crate) const KEPT_DAYS: i64 = 7;
/// What the debug log notes: the server's own at debug, the libraries' from info.
const NOTED: &str = "info,cardwave_server=debug";

/// The logs' folder in the data folder `data_dir`.
pub fn folder(data_dir: &Path) -> PathBuf {
    data_dir.join("logs")
}

/// Starts both logs in the data folder `data_dir`, and the terminal's output.
pub fn start(data_dir: &Path) -> anyhow::Result<()> {
    let folder = folder(data_dir);
    std::fs::create_dir_all(&folder)?;
    prune(&folder, today());
    let debug = tracing_subscriber::fmt::layer()
        .with_ansi(false)
        .with_writer(DayFile::new(folder.clone()))
        .with_filter(EnvFilter::new(NOTED));
    let terminal = tracing_subscriber::fmt::layer()
        .with_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")));
    tracing_subscriber::registry()
        .with(debug)
        .with(terminal)
        .try_init()?;
    let before = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        crashed(&folder, info);
        before(info);
    }));
    Ok(())
}

fn today() -> NaiveDate {
    Local::now().date_naive()
}

/// The file of the log `kind` ("debug", "crash") for `day`.
pub fn file_of(folder: &Path, kind: &str, day: NaiveDate) -> PathBuf {
    folder.join(format!("{kind}-{}.log", day.format("%Y-%m-%d")))
}

/// Deletes the logs' files of days before the last `KEPT_DAYS` up to `today`;
/// a file of another name stays.
pub fn prune(folder: &Path, today: NaiveDate) {
    let first = today - chrono::Duration::days(KEPT_DAYS - 1);
    // A folder that cannot be read keeps its files: the logs never stop the app.
    let Ok(entries) = std::fs::read_dir(folder) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(day) = name.to_str().and_then(day_of) else {
            continue;
        };
        if day < first {
            // Deleted at the next start where it cannot be now.
            let _ = std::fs::remove_file(entry.path());
        }
    }
}

/// The day of a log's file name, `debug-2026-10-20.log` or `crash-…`.
fn day_of(name: &str) -> Option<NaiveDate> {
    let day = name
        .strip_prefix("debug-")
        .or_else(|| name.strip_prefix("crash-"))?
        .strip_suffix(".log")?;
    NaiveDate::parse_from_str(day, "%Y-%m-%d").ok()
}

/// Writes a panic to the day's crash log, with its place and backtrace.
fn crashed(folder: &Path, info: &std::panic::PanicHookInfo) {
    let what = info
        .payload()
        .downcast_ref::<&str>()
        .map(|said| said.to_string())
        .or_else(|| info.payload().downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "a panic without words".into());
    let place = info
        .location()
        .map(|at| format!("{}:{}", at.file(), at.line()))
        .unwrap_or_default();
    let thread = std::thread::current();
    let text = format!(
        "{} Cardwave {} crashed in thread {}: {what}\n  at {place}\n{}\n\n",
        Local::now().format("%Y-%m-%d %H:%M:%S"),
        env!("CARGO_PKG_VERSION"),
        thread.name().unwrap_or("unnamed"),
        std::backtrace::Backtrace::force_capture(),
    );
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(file_of(folder, "crash", today()));
    // A crash log that cannot be written leaves the terminal's word alone.
    if let Ok(mut file) = file {
        let _ = file.write_all(text.as_bytes());
    }
}

/// The debug log's file, a new one each day.
struct DayFile {
    folder: PathBuf,
    open: Mutex<Option<(NaiveDate, File)>>,
}

impl DayFile {
    fn new(folder: PathBuf) -> Self {
        Self {
            folder,
            open: Mutex::new(None),
        }
    }
}

impl<'a> MakeWriter<'a> for DayFile {
    type Writer = Day<'a>;

    fn make_writer(&'a self) -> Self::Writer {
        Day(self)
    }
}

/// One event's writing to the day's file.
struct Day<'a>(&'a DayFile);

impl Write for Day<'_> {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        let today = today();
        // A writer that panicked holding the file left it whole: each event is one write.
        let mut open = self.0.open.lock().unwrap_or_else(|held| held.into_inner());
        if open.as_ref().is_none_or(|(day, _)| *day != today) {
            let file = OpenOptions::new().create(true).append(true).open(file_of(
                &self.0.folder,
                "debug",
                today,
            ))?;
            *open = Some((today, file));
            prune(&self.0.folder, today);
        }
        match open.as_mut() {
            Some((_, file)) => file.write(bytes),
            None => Ok(bytes.len()),
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

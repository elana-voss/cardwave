//! The commands' sandbox (the chat's shell tool, the coding team), all the
//! tools' unsafe code: a command reaches no file but its folder's (and the
//! system's programs and libraries, read only), no network, nothing of the
//! server's (no handle but its output's, a few system variables). All its
//! processes end when it has run its time, is stopped or has ended.
//!
//! Windows (`windows.rs`): `cmd.exe` in an AppContainer of the folder's own and
//! a job. Linux (`linux.rs`): `sh` held by Landlock (files) and seccomp
//! (network, other processes) in its own process group and a user systemd
//! scope; without either no command runs and the tool is not offered
//! (`available`). Trap: cmd's `dir` and `vol` read the drive's root and are
//! refused; a refused one is marked `Ran::drive_refused`, whose words for
//! the model are `DRIVE_REFUSED`, naming `LISTING`.
//!
//! The team's commands reach more (`Reach`): the `PATH` folders holding
//! programs (`grantable`), a folder of their own, for installs the internet.

use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex, mpsc};
use std::time::Duration;

/// Whether this computer has the sandbox, so commands may run.
pub fn available() -> bool {
    #[cfg(windows)]
    return true;
    #[cfg(target_os = "linux")]
    return linux::available();
}

/// Why no command runs where the sandbox is missing, as the model and the
/// settings are told: one text, `Code::CommandsUnsafe`'s.
#[cfg(not(windows))]
fn unsafe_here() -> cw_core::Fail {
    cw_core::Fail::new(cw_core::Code::CommandsUnsafe)
}

/// The system commands run on, as the model is told.
pub const SYSTEM: &str = if cfg!(windows) { "Windows" } else { "Linux" };

/// The shell a command runs by, as the model is told.
pub const SHELL: &str = if cfg!(windows) { "cmd.exe" } else { "sh" };

#[cfg(windows)]
macro_rules! listing {
    () => {
        "for %f in (*) do @echo %f"
    };
}
#[cfg(not(windows))]
macro_rules! listing {
    () => {
        "ls -A"
    };
}

/// A command that lists the folder's files in the sandbox, where cmd's `dir`
/// and `vol` are refused: they read the drive's own details first.
pub const LISTING: &str = listing!();

/// What the model is told of the shell beside its name: how to list a folder
/// ([`LISTING`]), and on Windows what is refused.
#[cfg(windows)]
pub const ADVICE: &str = concat!(
    "PowerShell's commands for files do not work there; cmd's do. `dir` is refused there: list the files with `",
    listing!(),
    "`."
);
/// What the model is told of the shell beside its name: how to list a folder
/// ([`LISTING`]).
#[cfg(not(windows))]
pub const ADVICE: &str = concat!("List the files with `", listing!(), "`.");

/// The most of a command's output that is kept, in bytes.
pub(crate) const OUTPUT_LIMIT: usize = 32 * 1024;

/// How long the output is waited for once the command's processes are ended.
const LAST_OUTPUT: Duration = Duration::from_secs(2);

/// How a command went.
#[derive(Debug)]
pub struct Ran {
    /// What it wrote, its errors among it, at most [`OUTPUT_LIMIT`].
    pub output: String,
    /// Its exit code (on Linux 128 and the signal for one a signal ended);
    /// `None` when it ran out of time or was stopped and was ended.
    pub code: Option<u32>,
    /// Whether it failed as `dir` or `vol`, which read the drive and are
    /// refused: the model is then told [`DRIVE_REFUSED`].
    pub drive_refused: bool,
}

/// What the model is told after a refused `dir` or `vol`'s output: how to
/// list the folder instead.
pub const DRIVE_REFUSED: &str = concat!(
    "
(The sandbox lets no command read the drive, so dir and vol are refused. List the folder with `",
    listing!(),
    "`, its folders with `for /d %f in (*) do @echo %f`, or a subfolder with `for /r sub %f in (*) do @echo %f`.)"
);

/// What a command reaches beside its folder.
#[derive(Clone, Debug, Default)]
pub struct Reach {
    /// The internet.
    pub network: bool,
    /// The programs of the server's `PATH`, and a folder of the command's
    /// own for what they keep (its `HOME` on Linux; `LOCALAPPDATA`, `APPDATA`,
    /// `TEMP` and the like on Windows).
    pub programs: bool,
    /// Cardwave's data folder, which no folder let in holds or is in.
    pub data: PathBuf,
}

/// Whether a folder of the server's `PATH` is let in for a team's command:
/// where it holds a program itself (on Windows an .exe, .cmd, .bat or .com;
/// on Linux a file one may run) and is [`allowed`].
pub fn grantable(folder: &Path, data: &Path) -> bool {
    let program = |entry: std::fs::DirEntry| {
        // The program a link leads to (pipx's, snap's): `entry.metadata()`
        // would be the link's own on Unix.
        let Ok(kind) = std::fs::metadata(entry.path()) else {
            return false;
        };
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            kind.is_file() && kind.permissions().mode() & 0o111 != 0
        }
        #[cfg(not(unix))]
        {
            let name = entry.file_name().to_string_lossy().to_lowercase();
            kind.is_file()
                && [".exe", ".cmd", ".bat", ".com"]
                    .iter()
                    .any(|ending| name.ends_with(ending))
        }
    };
    allowed(folder, data)
        && std::fs::read_dir(folder)
            .into_iter()
            .flatten()
            .flatten()
            .any(program)
}

/// Whether a folder may be let in at all: not a drive's root, the user's
/// home folder, nor one that holds the data folder `data` or is in it (the
/// rule of the folder the model's tools work in).
fn allowed(folder: &Path, data: &Path) -> bool {
    let home = std::env::home_dir().and_then(|home| home.canonicalize().ok());
    cw_library::settings::folder_checked(&folder.to_string_lossy(), data).is_ok()
        && folder.canonicalize().ok() != home
}

/// Runs `command` with [`SHELL`] in `folder`, for at most `time` and until
/// `stopped` is set. Blocks.
pub fn run(
    folder: &Path,
    command: &str,
    time: Duration,
    stopped: &AtomicBool,
) -> anyhow::Result<Ran> {
    run_with(folder, command, time, stopped, Reach::default())
}

/// [`run`], reaching what `reach` says too. A refused `dir` or `vol` says how
/// to list the folder (`LISTING`), as the model will try them.
#[cfg(windows)]
pub fn run_with(
    folder: &Path,
    command: &str,
    time: Duration,
    stopped: &AtomicBool,
    reach: Reach,
) -> anyhow::Result<Ran> {
    // cmd ends a command at its first line break and runs only that line.
    anyhow::ensure!(
        !command.contains(['\n', '\r']),
        "a command must be one line: cmd runs only its first; join the commands with && on one line"
    );
    let mut ran = windows::run(folder, command, time, stopped, reach)?;
    let reads_drive = command
        .split(|c: char| !c.is_ascii_alphanumeric())
        .any(|word| word.eq_ignore_ascii_case("dir") || word.eq_ignore_ascii_case("vol"));
    ran.drive_refused = reads_drive && ran.code != Some(0);
    Ok(ran)
}

/// [`run`], reaching what `reach` says too; refused where the sandbox is
/// missing (`available`).
#[cfg(target_os = "linux")]
pub fn run_with(
    folder: &Path,
    command: &str,
    time: Duration,
    stopped: &AtomicBool,
    reach: Reach,
) -> anyhow::Result<Ran> {
    anyhow::ensure!(linux::available(), unsafe_here());
    linux::run(folder, command, time, stopped, reach)
}

/// A command's output, read on a thread of its own as it comes, so the
/// command never waits on a full pipe.
pub(crate) struct Output {
    kept: Arc<Mutex<Vec<u8>>>,
    read: mpsc::Receiver<()>,
}

impl Output {
    /// Starts reading `reader` to its end.
    pub(crate) fn read(reader: impl Read + Send + 'static) -> Self {
        let kept = Arc::new(Mutex::new(Vec::new()));
        let (done, read) = mpsc::channel::<()>();
        let reading = Arc::clone(&kept);
        std::thread::spawn(move || {
            keep(reader, &reading);
            drop(done);
        });
        Self { kept, read }
    }

    /// What was read, once the command's processes are gone. Another program
    /// the server starts meanwhile may hold the pipe open, so its end is
    /// waited for only a moment (`LAST_OUTPUT`).
    pub(crate) fn take(self) -> Vec<u8> {
        // Ignored: the reading ended (the sender dropped) or its time ran out;
        // either way the output is what was read by then.
        let _ = self.read.recv_timeout(LAST_OUTPUT);
        std::mem::take(&mut *cw_core::lock(&self.kept))
    }
}

/// Reads `reader` to its end into `kept`, keeping its first
/// `OUTPUT_LIMIT` bytes and throwing the rest away, so a command that
/// prints without end costs the server no memory.
pub(crate) fn keep(mut reader: impl Read, kept: &Mutex<Vec<u8>>) {
    let mut piece = [0u8; 8192];
    while let Ok(count) = reader.read(&mut piece) {
        if count == 0 {
            break;
        }
        let mut kept = cw_core::lock(kept);
        let room = OUTPUT_LIMIT - kept.len();
        kept.extend_from_slice(&piece[..count.min(room)]);
    }
}

#[cfg(windows)]
mod windows;

#[cfg(target_os = "linux")]
mod linux;

#[cfg(all(test, windows))]
mod tests;

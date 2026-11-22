//! A command's cgroup: its first process, before it runs anything, is put into
//! a transient scope of the user's systemd manager, which holds it and all it
//! starts together to [`MEMORY`] without swap and to [`TASKS`] processes and
//! threads, as Windows' job does; no administrator rights. The scope ends and
//! is dropped with the command's last process.
//! Called by `busctl` (systemd's own D-Bus client), so no D-Bus library, on
//! the manager's bus in the user's runtime folder, never another session bus.
//! Traps: the manager starts the scope after the call has answered, so the
//! process's cgroup is waited for; a controller the system does not hand the
//! user's manager leaves its limit unset without a word, so each limit is read
//! back from the cgroup, and a missing one refuses the command.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

use anyhow::{Context, bail};

/// The most memory a command and all it starts hold together.
pub(super) const MEMORY: u64 = 1 << 30;

/// The most processes and threads a command and all it starts hold together,
/// so a fork bomb stops. A build with a few jobs needs about a hundred (each
/// compiler a few threads, cargo or node a dozen).
pub(super) const TASKS: u64 = 512;

/// How long the manager may take to start the scope.
const START: Duration = Duration::from_secs(5);

/// Where cgroup v2 is mounted.
const CGROUPS: &str = "/sys/fs/cgroup";

/// Whether this computer can hold a command in a scope: cgroup v2 and a
/// systemd manager of the user's with its bus in the user's runtime folder.
pub(super) fn available() -> bool {
    let runtime = runtime();
    Path::new(CGROUPS).join("cgroup.controllers").exists()
        && runtime.join("systemd/private").exists()
        && runtime.join("bus").exists()
}

/// The user's runtime folder, where the manager's and the bus's sockets are.
fn runtime() -> PathBuf {
    match std::env::var_os("XDG_RUNTIME_DIR") {
        Some(folder) => folder.into(),
        // SAFETY: a plain system call.
        None => format!("/run/user/{}", unsafe { libc::getuid() }).into(),
    }
}

/// Puts process `pid` into a new scope holding the limits above; returns once
/// it is in and each limit is read back from its cgroup.
pub(super) fn enter(pid: libc::pid_t) -> anyhow::Result<()> {
    static COUNT: AtomicU64 = AtomicU64::new(0);
    let name = format!(
        "cardwave-command-{}-{}.scope",
        std::process::id(),
        COUNT.fetch_add(1, Ordering::Relaxed)
    );
    let (pid, memory, tasks) = (pid.to_string(), MEMORY.to_string(), TASKS.to_string());
    #[rustfmt::skip]
    let call = std::process::Command::new("busctl")
        .args([
            "--user", "call", "org.freedesktop.systemd1", "/org/freedesktop/systemd1",
            "org.freedesktop.systemd1.Manager", "StartTransientUnit", "ssa(sv)a(sa(sv))",
            &name, "fail", "5",
            "PIDs", "au", "1", &pid,
            "MemoryMax", "t", &memory,
            "MemorySwapMax", "t", "0",
            "TasksMax", "t", &tasks,
            // A scope whose command the kernel killed for memory is dropped too.
            "CollectMode", "s", "inactive-or-failed",
            "0",
        ])
        // The bus `available` found, `$XDG_RUNTIME_DIR/bus`: busctl takes a
        // `DBUS_SESSION_BUS_ADDRESS` first, which may name a session bus
        // without the manager on it (dbus-launch's, dbus-run-session's).
        .env("XDG_RUNTIME_DIR", runtime())
        .env_remove("DBUS_SESSION_BUS_ADDRESS")
        .stdin(std::process::Stdio::null())
        .output()
        .context("the user's systemd manager cannot be called (busctl)")?;
    if !call.status.success() {
        bail!(
            "the user's systemd manager refused the command's scope ({}): {}",
            call.status,
            String::from_utf8_lossy(&call.stderr).trim()
        );
    }
    let cgroup = cgroup_of(&pid, &name)?;
    let swap = cgroup.join("memory.swap.max");
    let mut limits = vec![("memory.max", memory), ("pids.max", tasks)];
    // Without swap accounting there is no file; then only a computer without
    // swap holds the memory to the limit.
    if swap.exists() || swapping() {
        limits.push(("memory.swap.max", "0".to_string()));
    }
    for (file, wanted) in limits {
        let set = std::fs::read_to_string(cgroup.join(file)).unwrap_or_default();
        if set.trim() != wanted {
            bail!(
                "the command's scope holds no {file} of {wanted} (\"{}\")",
                set.trim()
            );
        }
    }
    Ok(())
}

/// The cgroup folder of process `pid` once it is in scope `name`.
fn cgroup_of(pid: &str, name: &str) -> anyhow::Result<PathBuf> {
    let until = Instant::now() + START;
    loop {
        let read = std::fs::read_to_string(format!("/proc/{pid}/cgroup")).unwrap_or_default();
        // cgroup v2's line is `0::<path>`.
        let path = read.lines().find_map(|line| line.strip_prefix("0::"));
        if let Some(path) = path.filter(|path| path.ends_with(&format!("/{name}"))) {
            return Ok(Path::new(CGROUPS).join(path.trim_start_matches('/')));
        }
        if Instant::now() > until {
            bail!("the command never came into its scope (its cgroup: {path:?})");
        }
        std::thread::sleep(Duration::from_millis(5));
    }
}

/// Whether this computer has swap switched on.
fn swapping() -> bool {
    std::fs::read_to_string("/proc/swaps").is_ok_and(|swaps| swaps.lines().count() > 1)
}

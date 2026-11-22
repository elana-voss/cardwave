//! The sandbox on Linux, by the kernel's own means: a command runs by
//! `/bin/sh -c` in its folder, in a process group of its own, held by
//! Landlock (`landlock.rs`: the folder, the system's programs and libraries
//! read only, a folder of its own) and a seccomp filter (`seccomp.rs`: no
//! network, no other process), whose connects and signals the server judges
//! (`supervisor.rs`). Its environment is a few of the system's variables.
//! Before it runs, its first process is put into a scope of the user's
//! systemd manager, which holds it and all it starts together to 1 GiB and
//! 512 processes (`scope.rs`); without Landlock or that manager no command runs,
//! and a scope refused kills the waiting process: its fork's copy of the socket
//! would keep it waiting for ever.
//! At its end, its time or a stop the whole group is killed before its first
//! process is reaped, so the group's id is not taken by another meanwhile;
//! where the server itself ends, its keeper process kills the group.
//! Trap: between fork and exec (`pre_exec`) nothing may allocate or lock:
//! the ruleset, the filter and the socket the filter's descriptor comes back
//! by are all made before.

mod address;
mod caller;
mod landlock;
mod metadata;
mod scope;
mod seccomp;
mod supervisor;

use std::ffi::OsString;
use std::net::IpAddr;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::process::{CommandExt, ExitStatusExt};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use anyhow::{Context, bail};
use sha2::{Digest, Sha256};

use super::{Output, Ran, Reach, allowed, grantable};
use landlock::{DEVICE, READ_EXEC, READ_FILE, Ruleset};

/// How often the command is looked at while it runs.
const LOOK: Duration = Duration::from_millis(100);

/// The system's folders a command reads and runs programs from.
const SYSTEM_FOLDERS: [&str; 7] = ["/usr", "/bin", "/sbin", "/lib", "/lib32", "/lib64", "/etc"];

/// The devices a command reads and writes.
const DEVICES: [&str; 5] = [
    "/dev/null",
    "/dev/zero",
    "/dev/full",
    "/dev/random",
    "/dev/urandom",
];

/// The folders of a command's `PATH` after the server's that are let in.
const DEFAULT_PATH: [&str; 3] = ["/usr/local/bin", "/usr/bin", "/bin"];

/// Whether this computer has Landlock and a scope for a command
/// (`scope::available`), without which no command runs.
pub(super) fn available() -> bool {
    landlock::version() > 0 && scope::available()
}

pub(super) fn run(
    folder: &Path,
    command: &str,
    time: Duration,
    stopped: &AtomicBool,
    reach: Reach,
) -> anyhow::Result<Ran> {
    let own = own_folder(folder)?;
    let rules = Ruleset::new()?;
    rules.allow(folder, u64::MAX)?;
    rules.allow(&own, u64::MAX)?;
    for system in SYSTEM_FOLDERS {
        rules.allow(Path::new(system), READ_EXEC)?;
    }
    for device in DEVICES {
        rules.allow(Path::new(device), DEVICE)?;
    }
    let mut path = Vec::new();
    let mut environment: Vec<(OsString, OsString)> = ["LANG", "LC_ALL", "LC_CTYPE", "TZ"]
        .into_iter()
        .filter_map(|name| Some((name.into(), std::env::var_os(name)?)))
        .collect();
    let tmp = own.join("tmp");
    std::fs::create_dir_all(&tmp).context("no temporary folder for the command")?;
    environment.push(("TMPDIR".into(), tmp.into()));
    if reach.programs {
        for granted in programs(&reach.data) {
            rules.allow(&granted.folder, READ_EXEC)?;
            for needed in &granted.needs {
                rules.allow(needed, READ_EXEC)?;
            }
            path.push(granted.folder);
        }
        if let Some(rustup) = rustup(&path) {
            rules.allow(&rustup, READ_EXEC)?;
            environment.push(("RUSTUP_HOME".into(), rustup.into()));
        }
        environment.push(("HOME".into(), own.clone().into()));
    }
    path.extend(DEFAULT_PATH.map(PathBuf::from));
    environment.push((
        "PATH".into(),
        std::env::join_paths(path).context("a folder of PATH holds a colon")?,
    ));
    let (own_addresses, nameservers) = match reach.network {
        true => {
            // Names are asked over TCP, the only kind of socket let in.
            environment.push(("RES_OPTIONS".into(), "use-vc".into()));
            let servers = nameservers();
            if let Ok(resolv) = std::fs::canonicalize("/etc/resolv.conf") {
                rules.allow(&resolv, READ_FILE)?;
            }
            (own_addresses(), servers)
        }
        false => (Vec::new(), Vec::new()),
    };
    let filter = seccomp::filter(reach.network);
    let (child, listener) = spawn(folder, command, &environment, &rules, &filter)?;
    let output = Output::read(child.reader);
    let done = Arc::new(AtomicBool::new(false));
    supervisor::supervise(
        listener,
        supervisor::Command {
            group: child.process.id() as libc::pid_t,
            own: own_addresses,
            nameservers,
            writable: metadata::writable(&[folder, &own]),
        },
        Arc::clone(&done),
    );
    let code = wait(child.process, child.keeper, time, stopped);
    done.store(true, Ordering::Relaxed);
    Ok(Ran {
        output: String::from_utf8_lossy(&output.take()).into_owned(),
        code,
    })
}

/// The command's process and the reading end of its output.
struct Child {
    process: std::process::Child,
    reader: std::io::PipeReader,
    keeper: Keeper,
}

/// A process of the server's own that kills the command's group when the
/// server ends, however: it waits on a pipe whose writing end only the
/// server holds. `PR_SET_PDEATHSIG` alone ends only `sh`, not its children.
struct Keeper {
    pid: libc::pid_t,
    end: OwnedFd,
}

impl Keeper {
    fn start(group: libc::pid_t) -> anyhow::Result<Self> {
        let mut ends = [0; 2];
        // SAFETY: the pair lives through the call.
        if unsafe { libc::pipe2(ends.as_mut_ptr(), libc::O_CLOEXEC) } != 0 {
            bail!(
                "no pipe for the command's keeper: {}",
                std::io::Error::last_os_error()
            );
        }
        // SAFETY: both descriptors are new and ours.
        let (read, end) = unsafe { (OwnedFd::from_raw_fd(ends[0]), OwnedFd::from_raw_fd(ends[1])) };
        // SAFETY: the new process makes system calls only (the server's other
        // threads may hold locks) and ends by `_exit`.
        match unsafe { libc::fork() } {
            -1 => bail!(
                "no keeper for the command: {}",
                std::io::Error::last_os_error()
            ),
            0 => unsafe { keep(read.as_raw_fd(), group) },
            pid => Ok(Self { pid, end }),
        }
    }

    /// Ends the keeper, which kills the group once more (its first process
    /// is not reaped yet), and reaps it.
    fn end(self) {
        drop(self.end);
        let mut status = 0;
        // Ignored: the keeper is ours; its end is all that is waited for.
        // SAFETY: a plain system call.
        let _ = unsafe { libc::waitpid(self.pid, &mut status, 0) };
    }
}

/// The keeper's life: all its descriptors but the pipe's reading end closed,
/// it waits for the pipe's end, then kills `group`.
/// SAFETY: only in the keeper's new process; it never returns.
unsafe fn keep(read: RawFd, group: libc::pid_t) -> ! {
    // SAFETY: plain system calls on values that live through them.
    unsafe {
        if read > 0 {
            libc::syscall(libc::SYS_close_range, 0u32, (read - 1) as u32, 0u32);
        }
        libc::syscall(libc::SYS_close_range, (read + 1) as u32, u32::MAX, 0u32);
        // A signal to the server's group (Ctrl+C) must not end the keeper first.
        for signal in [libc::SIGINT, libc::SIGTERM, libc::SIGHUP, libc::SIGQUIT] {
            libc::signal(signal, libc::SIG_IGN);
        }
        let mut byte = 0u8;
        while libc::read(read, (&raw mut byte).cast(), 1) < 0
            && *libc::__errno_location() == libc::EINTR
        {}
        libc::killpg(group, libc::SIGKILL);
        libc::_exit(0)
    }
}

/// Starts `command` held by `rules`, `filter` and its scope; the descriptor
/// the filter's notices come by. Its process sends its id and that
/// descriptor, then waits to be let go until a thread of the server's has put
/// it into its scope (`enter`), as `spawn` returns only once it has run `sh`.
fn spawn(
    folder: &Path,
    command: &str,
    environment: &[(OsString, OsString)],
    rules: &Ruleset,
    filter: &[seccomp::Instruction],
) -> anyhow::Result<(Child, OwnedFd)> {
    let (reader, writer) = std::io::pipe().context("no pipe for the command's output")?;
    let errors = writer
        .try_clone()
        .context("no pipe for the command's errors")?;
    let (ours, theirs) = socket_pair()?;
    let length = u16::try_from(filter.len()).context("the seccomp filter is too long")?;
    // As a number, so the closure below may be sent; it lives until spawn returns.
    let instructions = filter.as_ptr() as usize;
    let ruleset = rules.fd();
    let their_end = theirs.as_raw_fd();
    // SAFETY: a plain system call.
    let parent = unsafe { libc::getpid() };
    let mut sh = std::process::Command::new("/bin/sh");
    sh.arg("-c")
        .arg(command)
        .current_dir(folder)
        .env_clear()
        .envs(environment.iter().map(|(name, value)| (name, value)))
        .stdin(std::process::Stdio::null())
        .stdout(writer)
        .stderr(errors)
        .process_group(0);
    // SAFETY: the closure makes system calls only, allocating nothing; what
    // it reads (the program, the descriptors) lives until spawn returns.
    unsafe {
        sh.pre_exec(move || {
            let program = seccomp::Program {
                len: length,
                filter: instructions as *const seccomp::Instruction,
            };
            confine(parent, ruleset, &program, their_end)
        });
    }
    let entering = std::thread::spawn(move || enter(ours));
    let spawned = sh.spawn();
    // The process's end of the socket closed, `enter` waits no longer.
    drop(theirs);
    drop(sh);
    let entered = entering
        .join()
        .unwrap_or_else(|_| Err(anyhow::anyhow!("the command's scope panicked")));
    let (process, listener) = match (spawned, entered) {
        (Ok(process), Ok(listener)) => (process, listener),
        (Ok(process), Err(error)) => {
            kill_and_reap(process);
            return Err(error.context(super::unsafe_here()));
        }
        // The scope failed first: the process, never let go, ended unrun.
        (Err(_), Err(error)) => return Err(error.context(super::unsafe_here())),
        (Err(error), Ok(_)) => return Err(error).context("the command cannot be started"),
    };
    let keeper = match Keeper::start(process.id() as libc::pid_t) {
        Ok(keeper) => keeper,
        Err(error) => {
            kill_and_reap(process);
            return Err(error);
        }
    };
    Ok((
        Child {
            process,
            reader,
            keeper,
        },
        listener,
    ))
}

/// Kills the command's whole group, its first process `process` not yet
/// reaped (so the group's id is not taken meanwhile), then reaps it.
fn kill_and_reap(mut process: std::process::Child) {
    // SAFETY: the group is the command's, its first process not reaped.
    unsafe { libc::killpg(process.id() as libc::pid_t, libc::SIGKILL) };
    // Ignored: the process was killed; its end is all that is waited for.
    let _ = process.wait();
}

/// In the command's process before it runs `sh`: ends it with the server,
/// closes the server's descriptors at exec, lays the Landlock `ruleset` and
/// the seccomp `program` on it, sends its id and the filter's descriptor to
/// the server by `socket` and waits there until the server has put it into
/// its scope.
fn confine(
    parent: libc::pid_t,
    ruleset: RawFd,
    program: &seccomp::Program,
    socket: RawFd,
) -> std::io::Result<()> {
    let failed = || std::io::Error::last_os_error();
    // SAFETY: plain system calls on values that live through them.
    unsafe {
        if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL) != 0 {
            return Err(failed());
        }
        // The server ended before the line above: end now.
        if libc::getppid() != parent {
            return Err(std::io::Error::from_raw_os_error(libc::ESRCH));
        }
        // Ignored: on a kernel before 5.11 it fails, and the server's own
        // descriptors are opened to close at exec anyway (Rust's are).
        let _ = libc::syscall(libc::SYS_close_range, 3u32, u32::MAX, 4u32);
        if libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 {
            return Err(failed());
        }
    }
    landlock::restrict(ruleset)?;
    let listener = seccomp::install(program)?;
    let sent = send_fd(socket, listener);
    // SAFETY: the descriptor is the filter's, ours to close.
    unsafe { libc::close(listener) };
    sent?;
    let mut go = 0u8;
    // SAFETY: the byte lives through the call.
    match unsafe { libc::read(socket, (&raw mut go).cast(), 1) } {
        1 => Ok(()),
        // The server put it into no scope: it ends unrun.
        _ => Err(std::io::Error::from_raw_os_error(libc::ECANCELED)),
    }
}

/// In a thread of the server's while the command's process waits: its id and
/// filter's descriptor read from `socket`, the process put into its scope and
/// let go; on any failure after its id came, the process is killed unrun.
fn enter(socket: OwnedFd) -> anyhow::Result<OwnedFd> {
    let (pid, listener) =
        receive_fd(&socket).context("the command's sandbox could not be set up")?;
    let entered = scope::enter(pid).and_then(|()| {
        // SAFETY: the byte lives through the call.
        match unsafe { libc::write(socket.as_raw_fd(), [1u8].as_ptr().cast(), 1) } {
            1 => Ok(()),
            _ => Err(anyhow::anyhow!(
                "the command could not be let go: {}",
                std::io::Error::last_os_error()
            )),
        }
    });
    if entered.is_err() {
        // The process holds its own copy of `socket` from its fork, so it would
        // never see it close: it is killed, unrun (not reaped: `spawn` waits on it).
        // SAFETY: a plain system call on the process `spawn` still waits for.
        unsafe { libc::kill(pid, libc::SIGKILL) };
    }
    entered.map(|()| listener)
}

fn socket_pair() -> anyhow::Result<(OwnedFd, OwnedFd)> {
    let mut pair = [0; 2];
    // SAFETY: the pair lives through the call.
    let made = unsafe {
        libc::socketpair(
            libc::AF_UNIX,
            libc::SOCK_SEQPACKET | libc::SOCK_CLOEXEC,
            0,
            pair.as_mut_ptr(),
        )
    };
    if made != 0 {
        bail!(
            "no socket for the command's sandbox: {}",
            std::io::Error::last_os_error()
        );
    }
    // SAFETY: both descriptors are new and ours.
    Ok(unsafe { (OwnedFd::from_raw_fd(pair[0]), OwnedFd::from_raw_fd(pair[1])) })
}

/// A buffer for one descriptor's control message, aligned as `cmsghdr`.
#[repr(C)]
union Control {
    header: libc::cmsghdr,
    bytes: [u8; 64],
}

/// A message of the one `part` with room for one descriptor's control
/// message in `control`; both must outlive its use. It allocates nothing.
fn message(part: &mut libc::iovec, control: &mut Control) -> libc::msghdr {
    // SAFETY: a `msghdr` of zeros is an empty one; the macro reads no memory.
    unsafe {
        let mut message: libc::msghdr = std::mem::zeroed();
        message.msg_iov = part;
        message.msg_iovlen = 1;
        message.msg_control = (control as *mut Control).cast();
        message.msg_controllen = libc::CMSG_SPACE(size_of::<RawFd>() as u32) as _;
        message
    }
}

/// Sends this process's id and descriptor `fd` over `socket`; between fork
/// and exec, allocating nothing.
fn send_fd(socket: RawFd, fd: RawFd) -> std::io::Result<()> {
    // SAFETY: every buffer lives through the calls, sized as the macros say.
    unsafe {
        let mut pid = libc::getpid().to_ne_bytes();
        let mut part = libc::iovec {
            iov_base: pid.as_mut_ptr().cast(),
            iov_len: pid.len(),
        };
        let mut control: Control = std::mem::zeroed();
        let message = message(&mut part, &mut control);
        let header = libc::CMSG_FIRSTHDR(&message);
        (*header).cmsg_level = libc::SOL_SOCKET;
        (*header).cmsg_type = libc::SCM_RIGHTS;
        (*header).cmsg_len = libc::CMSG_LEN(size_of::<RawFd>() as u32) as _;
        std::ptr::write_unaligned(libc::CMSG_DATA(header).cast::<RawFd>(), fd);
        match libc::sendmsg(socket, &message, 0) {
            4 => Ok(()),
            _ => Err(std::io::Error::last_os_error()),
        }
    }
}

/// The process id and descriptor the command's process sent over `socket`,
/// waited for until it did or ended.
fn receive_fd(socket: &OwnedFd) -> Option<(libc::pid_t, OwnedFd)> {
    // SAFETY: every buffer lives through the call, sized as the macros say.
    unsafe {
        let mut pid = [0u8; 4];
        let mut part = libc::iovec {
            iov_base: pid.as_mut_ptr().cast(),
            iov_len: pid.len(),
        };
        let mut control: Control = std::mem::zeroed();
        let mut message = message(&mut part, &mut control);
        let read = libc::recvmsg(socket.as_raw_fd(), &mut message, libc::MSG_CMSG_CLOEXEC);
        let header = libc::CMSG_FIRSTHDR(&message);
        if read != 4
            || header.is_null()
            || (*header).cmsg_level != libc::SOL_SOCKET
            || (*header).cmsg_type != libc::SCM_RIGHTS
        {
            return None;
        }
        let fd = std::ptr::read_unaligned(libc::CMSG_DATA(header).cast::<RawFd>());
        Some((libc::pid_t::from_ne_bytes(pid), OwnedFd::from_raw_fd(fd)))
    }
}

/// Waits for the command's first process for at most `time` and until
/// `stopped` is set, then kills its whole group and reaps it: its exit
/// code (128 and the signal for one a signal ended), `None` when it was ended.
fn wait(
    mut process: std::process::Child,
    keeper: Keeper,
    time: Duration,
    stopped: &AtomicBool,
) -> Option<u32> {
    let pid = process.id() as libc::pid_t;
    let until = Instant::now() + time;
    let mut ended = false;
    while !ended && Instant::now() < until && !stopped.load(Ordering::Relaxed) {
        // SAFETY: the info lives through the call; WNOWAIT leaves the process unreaped.
        let mut info: libc::siginfo_t = unsafe { std::mem::zeroed() };
        // SAFETY: as above.
        let looked = unsafe {
            libc::waitid(
                libc::P_PID,
                pid as libc::id_t,
                &mut info,
                libc::WEXITED | libc::WNOHANG | libc::WNOWAIT,
            )
        };
        // SAFETY: waitid filled the info, or left its pid 0.
        ended = looked == 0 && unsafe { info.si_pid() } == pid;
        if !ended {
            std::thread::sleep(LOOK);
        }
    }
    // What the command left running ends with it, before the group's id is freed.
    // SAFETY: the group is the command's, its first process not reaped.
    unsafe { libc::killpg(pid, libc::SIGKILL) };
    keeper.end();
    let status = process.wait().ok()?;
    if !ended {
        return None;
    }
    status
        .code()
        .map(|code| code as u32)
        .or_else(|| status.signal().map(|signal| 128 + signal as u32))
}

/// The command's own folder, for its temporary files and, for a team's,
/// what its programs keep: `cardwave/commands/<the folder's hash>` in the
/// user's cache folder, only the user's.
fn own_folder(folder: &Path) -> anyhow::Result<PathBuf> {
    let cache = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .filter(|cache| cache.is_absolute())
        .or_else(|| std::env::home_dir().map(|home| home.join(".cache")))
        .context("no cache folder for the command")?;
    let hash = Sha256::digest(folder.as_os_str().as_encoded_bytes());
    let name = cw_core::hex(&hash[..16]);
    let own = cache.join("cardwave").join("commands").join(name);
    std::fs::create_dir_all(&own).context("no folder of the command's own")?;
    std::fs::set_permissions(&own, std::fs::Permissions::from_mode(0o700))
        .context("the command's own folder cannot be kept to the user")?;
    Ok(own)
}

/// A folder of the server's `PATH` let in, and what its programs' links lead
/// to (npm's to `lib/node_modules/npm`, pipx's to its venvs; see [`needed`]).
struct Granted {
    folder: PathBuf,
    needs: Vec<PathBuf>,
}

/// The folders of the server's `PATH` a team's command may use.
fn programs(data: &Path) -> Vec<Granted> {
    let Some(path) = std::env::var_os("PATH") else {
        return Vec::new();
    };
    std::env::split_paths(&path)
        .filter(|folder| folder.is_absolute() && grantable(folder, data))
        .map(|folder| {
            let mut needs: Vec<PathBuf> = std::fs::read_dir(&folder)
                .into_iter()
                .flatten()
                .flatten()
                .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_symlink()))
                .filter_map(|entry| entry.path().canonicalize().ok())
                .filter_map(|target| needed(&target))
                .filter(|needed| {
                    let folder = match needed.is_dir() {
                        true => needed.as_path(),
                        false => needed.parent().unwrap_or(needed),
                    };
                    allowed(folder, data) && !holds_home(needed)
                })
                .collect();
            needs.sort();
            needs.dedup();
            Granted { folder, needs }
        })
        .collect()
}

/// What a program's link in a granted folder needs let in, by the real path
/// it leads to: the package it is of (npm's `node_modules/<name>`, a Python
/// venv holding `pyvenv.cfg`), else that file alone.
fn needed(target: &Path) -> Option<PathBuf> {
    let package = target.parent()?.parent()?;
    let whole = package
        .parent()
        .is_some_and(|up| up.file_name() == Some("node_modules".as_ref()))
        || package.join("pyvenv.cfg").is_file();
    Some(match whole {
        true => package.to_path_buf(),
        false => target.to_path_buf(),
    })
}

/// Whether `folder` is the user's home folder or holds it.
fn holds_home(folder: &Path) -> bool {
    std::env::home_dir()
        .and_then(|home| home.canonicalize().ok())
        .is_some_and(|home| home.starts_with(folder))
}

/// Rustup's own folder where a granted folder holds `rustup`: its programs
/// there are links to it, which finds the toolchains in `RUSTUP_HOME`.
fn rustup(granted: &[PathBuf]) -> Option<PathBuf> {
    granted
        .iter()
        .find(|folder| folder.join("rustup").is_file())?;
    std::env::var_os("RUSTUP_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::home_dir().map(|home| home.join(".rustup")))
        .filter(|folder| folder.is_dir())
}

/// The name servers of `/etc/resolv.conf`.
fn nameservers() -> Vec<IpAddr> {
    std::fs::read_to_string("/etc/resolv.conf")
        .unwrap_or_default()
        .lines()
        .filter_map(|line| line.trim().strip_prefix("nameserver"))
        .filter_map(|server| server.trim().split('%').next()?.parse().ok())
        .collect()
}

/// This computer's own addresses, of every network interface.
fn own_addresses() -> Vec<IpAddr> {
    let mut found = Vec::new();
    let mut list: *mut libc::ifaddrs = std::ptr::null_mut();
    // SAFETY: the list is the call's, read here and freed once.
    unsafe {
        if libc::getifaddrs(&mut list) != 0 {
            return found;
        }
        let mut entry = list;
        while !entry.is_null() {
            let address = (*entry).ifa_addr;
            if !address.is_null() {
                match (*address).sa_family as libc::c_int {
                    libc::AF_INET => {
                        let v4 = &*address.cast::<libc::sockaddr_in>();
                        found.push(IpAddr::from(u32::from_be(v4.sin_addr.s_addr).to_be_bytes()));
                    }
                    libc::AF_INET6 => {
                        let v6 = &*address.cast::<libc::sockaddr_in6>();
                        found.push(IpAddr::from(v6.sin6_addr.s6_addr));
                    }
                    _ => {}
                }
            }
            entry = (*entry).ifa_next;
        }
        libc::freeifaddrs(list);
    }
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A link's package is let in only where it is one; else its file alone.
    #[test]
    fn a_programs_link_lets_in_its_package_or_its_file_alone() {
        let root = std::env::temp_dir().join(format!("cw-needed-{}", std::process::id()));
        let file = |path: &str| {
            let path = root.join(path);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(&path, "").unwrap();
            path
        };
        let tool = file("Documents/tools/x");
        let npm = file("lib/node_modules/npm/bin/npm-cli.js");
        let black = file("venvs/black/bin/black");
        file("venvs/black/pyvenv.cfg");
        assert_eq!(needed(&tool), Some(tool.clone()));
        assert_eq!(needed(&npm), Some(root.join("lib/node_modules/npm")));
        assert_eq!(needed(&black), Some(root.join("venvs/black")));
        std::fs::remove_dir_all(&root).unwrap();
    }
}

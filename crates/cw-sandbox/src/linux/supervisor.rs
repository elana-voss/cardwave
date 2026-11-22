//! The server's side of the command's seccomp filter: the system calls the
//! filter sends here (`NOTIFY`) are judged and answered, on a thread of
//! their own, until the command's processes are gone.
//! - `connect` of a team's command with the internet: the address is copied
//!   from the command's memory once and judged (`address.rs`); a reachable
//!   one is connected by the server on a copy of the command's socket, so
//!   the command cannot change the address after the check.
//! - Signals: `kill` of a process or group is sent by the server where the
//!   target is in the command's process group; `tkill`, `tgkill` and
//!   `rt_*sigqueueinfo` go on only to the caller's own process.
//! - A file's mode, times and length (`metadata.rs`).
//!
//! Anything else, or what cannot be read, is refused (`EPERM`). The server
//! reads the command's memory as its ancestor (Yama's `ptrace_scope` 1): a
//! process orphaned out of its tree is refused.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::os::fd::{AsRawFd, OwnedFd};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

use super::address::reachable;
use super::caller::{descriptor, errno, pidfd_open, read_memory, status};
use super::metadata;

const RECEIVE: libc::c_ulong = 0xC050_2100;
const SEND: libc::c_ulong = 0xC018_2101;
const ID_VALID: libc::c_ulong = 0x4008_2102;
const CONTINUE: u32 = 1;

/// The most connects judged at once; one beyond is refused (`EAGAIN`).
const CONNECTS: usize = 64;

#[repr(C)]
#[derive(Clone, Copy)]
struct Data {
    nr: i32,
    arch: u32,
    ip: u64,
    args: [u64; 6],
}

#[repr(C)]
#[derive(Clone, Copy)]
struct Notice {
    id: u64,
    pid: u32,
    flags: u32,
    data: Data,
}

#[repr(C)]
struct Answer {
    id: u64,
    val: i64,
    error: i32,
    flags: u32,
}

/// What the supervisor knows of the command.
pub(super) struct Command {
    /// Its process group, the id of its first process.
    pub(super) group: libc::pid_t,
    /// This computer's own addresses and its name servers, for connects.
    pub(super) own: Vec<IpAddr>,
    pub(super) nameservers: Vec<IpAddr>,
    /// The real paths of the folders it writes.
    pub(super) writable: Vec<std::path::PathBuf>,
}

/// Answers the notices of `listener` until `done` is set.
pub(super) fn supervise(listener: OwnedFd, command: Command, done: Arc<AtomicBool>) {
    let listener = Arc::new(listener);
    let command = Arc::new(command);
    let connecting = Arc::new(AtomicUsize::new(0));
    std::thread::spawn(move || {
        while !done.load(Ordering::Relaxed) {
            let mut look = libc::pollfd {
                fd: listener.as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            };
            // SAFETY: one pollfd, alive through the call.
            let ready = unsafe { libc::poll(&mut look, 1, 100) };
            if ready < 0 || look.revents & (libc::POLLHUP | libc::POLLERR | libc::POLLNVAL) != 0 {
                if ready < 0
                    && std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted
                {
                    continue;
                }
                break;
            }
            if ready == 0 {
                continue;
            }
            // SAFETY: a zeroed notice is what the kernel asks to be given.
            let mut notice: Notice = unsafe { std::mem::zeroed() };
            // SAFETY: the notice lives through the call, of the kernel's size.
            if unsafe { libc::ioctl(listener.as_raw_fd(), RECEIVE as _, &mut notice) } < 0 {
                // The caller was ended meanwhile, or a signal came; look again.
                continue;
            }
            match notice.data.nr as libc::c_long {
                libc::SYS_connect => connect_aside(&listener, &command, &connecting, notice),
                nr if metadata::handled().contains(&nr) => {
                    let fd = listener.as_raw_fd();
                    let standing = || valid(fd, notice.id);
                    let pid = notice.pid as libc::pid_t;
                    let result =
                        metadata::change(pid, nr, notice.data.args, &command.writable, &standing);
                    answer(fd, notice.id, result, false);
                }
                _ => {
                    let (result, go_on) = signal(&notice, &command);
                    answer(listener.as_raw_fd(), notice.id, result, go_on);
                }
            }
        }
    });
}

/// Judges and answers a connect on a thread of its own, as one may take
/// long; past [`CONNECTS`] at once, or with no thread to be had, refused.
fn connect_aside(
    listener: &Arc<OwnedFd>,
    command: &Arc<Command>,
    connecting: &Arc<AtomicUsize>,
    notice: Notice,
) {
    if connecting.fetch_add(1, Ordering::Relaxed) >= CONNECTS {
        connecting.fetch_sub(1, Ordering::Relaxed);
        return answer(listener.as_raw_fd(), notice.id, Err(libc::EAGAIN), false);
    }
    let (inside, command, count) = (
        Arc::clone(listener),
        Arc::clone(command),
        Arc::clone(connecting),
    );
    let started = std::thread::Builder::new().spawn(move || {
        let result = connect(inside.as_raw_fd(), &notice, &command);
        answer(inside.as_raw_fd(), notice.id, result, false);
        count.fetch_sub(1, Ordering::Relaxed);
    });
    if started.is_err() {
        connecting.fetch_sub(1, Ordering::Relaxed);
        answer(listener.as_raw_fd(), notice.id, Err(libc::EAGAIN), false);
    }
}

/// Answers notice `id`: the call returns `result` (an error as `Err(errno)`),
/// or, with `go_on`, the kernel runs it as the caller asked.
fn answer(listener: libc::c_int, id: u64, result: Result<i64, i32>, go_on: bool) {
    let reply = Answer {
        id,
        val: result.unwrap_or(0),
        error: match (go_on, result) {
            (false, Err(code)) => -code,
            _ => 0,
        },
        flags: if go_on { CONTINUE } else { 0 },
    };
    // Ignored: it fails only where the caller was ended meanwhile.
    // SAFETY: the answer lives through the call.
    let _ = unsafe { libc::ioctl(listener, SEND as _, &reply) };
}

/// Whether notice `id` still stands: its caller waits in the same call.
fn valid(listener: libc::c_int, id: u64) -> bool {
    // SAFETY: the id lives through the call.
    unsafe { libc::ioctl(listener, ID_VALID as _, &id) == 0 }
}

/// A process's group, from `/proc/<pid>/stat` (its fifth field, after the
/// name in parentheses, which may hold anything).
fn group_of(pid: libc::pid_t) -> Option<libc::pid_t> {
    let text = std::fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let after = &text[text.rfind(')')? + 1..];
    after.split_whitespace().nth(2)?.parse().ok()
}

fn send_signal(pidfd: &OwnedFd, signal: libc::c_int) -> Result<i64, i32> {
    // SAFETY: a plain system call on an open descriptor.
    let sent = unsafe {
        libc::syscall(
            libc::SYS_pidfd_send_signal,
            pidfd.as_raw_fd(),
            signal,
            std::ptr::null::<libc::siginfo_t>(),
            0u32,
        )
    };
    match sent {
        0 => Ok(0),
        _ => Err(errno()),
    }
}

/// A signal call: its result, and whether the kernel runs it itself.
fn signal(notice: &Notice, command: &Command) -> (Result<i64, i32>, bool) {
    let args = notice.data.args;
    let target = args[0] as i32;
    let caller = notice.pid as libc::pid_t;
    match notice.data.nr as libc::c_long {
        libc::SYS_kill => (kill(target, args[1] as i32, command), false),
        // Only the calling thread itself (raise, abort).
        libc::SYS_tkill => match target == caller {
            true => (Ok(0), true),
            false => (Err(libc::EPERM), false),
        },
        // Only a thread of the caller's own process; the kernel checks the
        // thread is of it.
        libc::SYS_tgkill | libc::SYS_rt_sigqueueinfo | libc::SYS_rt_tgsigqueueinfo => {
            match status(caller, "Tgid:") == Some(target) {
                true => (Ok(0), true),
                false => (Err(libc::EPERM), false),
            }
        }
        _ => (Err(libc::EPERM), false),
    }
}

/// `kill(target, signal)` for the command: sent by the server where
/// `target` is a process of the command's group or the group itself.
fn kill(target: libc::pid_t, signal: libc::c_int, command: &Command) -> Result<i64, i32> {
    match target {
        // The group stays the command's while its first process is not
        // reaped, which the server does only after ending them all.
        _ if target < -1 && target.checked_neg() == Some(command.group) => {
            // SAFETY: a plain system call.
            match unsafe { libc::killpg(command.group, signal) } {
                0 => Ok(0),
                _ => Err(errno()),
            }
        }
        _ if target > 0 => {
            let pidfd = pidfd_open(target).ok_or_else(errno)?;
            // The pidfd holds the process: alive after the group is read,
            // the group read is its.
            let group = group_of(target);
            send_signal(&pidfd, 0)?;
            match group == Some(command.group) {
                true => send_signal(&pidfd, signal),
                false => Err(libc::EPERM),
            }
        }
        _ => Err(libc::EPERM),
    }
}

/// A team command's `connect(fd, address, length)`: judged, then done by the
/// server on a copy of the command's socket. Its result.
fn connect(listener: libc::c_int, notice: &Notice, command: &Command) -> Result<i64, i32> {
    let args = notice.data.args;
    let length = args[2] as u32 as usize;
    if length > 128 {
        return Err(libc::EINVAL);
    }
    let mut address = [0u8; 128];
    let caller = notice.pid as libc::pid_t;
    let read = read_memory(caller, args[1], &mut address[..length]);
    if !read || !valid(listener, notice.id) {
        return Err(libc::EPERM);
    }
    let address = &address[..length];
    if !allowed(address, command)? {
        return Err(libc::ENETUNREACH);
    }
    let copy = descriptor(caller, args[0] as i32, &|| valid(listener, notice.id))?;
    // SAFETY: the address is the bytes judged, with their length.
    let done = unsafe {
        libc::connect(
            copy.as_raw_fd(),
            address.as_ptr().cast(),
            length as libc::socklen_t,
        )
    };
    match done {
        0 => Ok(0),
        _ => Err(errno()),
    }
}

/// Whether the socket address `bytes` may be connected to; `Err` for one
/// that is not of the internet.
fn allowed(bytes: &[u8], command: &Command) -> Result<bool, i32> {
    if bytes.len() < 2 {
        return Err(libc::EINVAL);
    }
    let family = u16::from_ne_bytes([bytes[0], bytes[1]]) as libc::c_int;
    let port = |bytes: &[u8]| u16::from_be_bytes([bytes[2], bytes[3]]);
    let ip = match family {
        libc::AF_UNSPEC => return Ok(true),
        libc::AF_INET if bytes.len() >= 8 => {
            IpAddr::V4(Ipv4Addr::new(bytes[4], bytes[5], bytes[6], bytes[7]))
        }
        libc::AF_INET6 if bytes.len() >= 24 => {
            let octets: [u8; 16] = bytes[8..24].try_into().map_err(|_| libc::EINVAL)?;
            IpAddr::V6(Ipv6Addr::from(octets))
        }
        libc::AF_INET | libc::AF_INET6 => return Err(libc::EINVAL),
        _ => return Err(libc::EAFNOSUPPORT),
    };
    Ok(reachable(
        ip,
        port(bytes),
        &command.own,
        &command.nameservers,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Past the most connects at once one is refused at once, no thread begun.
    #[test]
    fn a_connect_past_the_most_at_once_is_refused_without_a_thread() {
        let listener = Arc::new(OwnedFd::from(std::fs::File::open("/dev/null").unwrap()));
        let command = Arc::new(Command {
            group: 0,
            own: Vec::new(),
            nameservers: Vec::new(),
            writable: Vec::new(),
        });
        let connecting = Arc::new(AtomicUsize::new(CONNECTS));
        // SAFETY: a zeroed notice is a valid value.
        let notice: Notice = unsafe { std::mem::zeroed() };
        connect_aside(&listener, &command, &connecting, notice);
        assert_eq!(connecting.load(Ordering::Relaxed), CONNECTS);
        assert_eq!(Arc::strong_count(&command), 1);
    }
}

//! The calls that change a file's mode, times or length, which Landlock does
//! not hold (`truncate` only from its version 3): the filter sends them to
//! the server (`supervisor.rs`), which does them where the file is in a
//! folder the command may write, else refuses them (`EACCES`).
//! The file is found once as the command named it: its path read once from
//! the command's memory, from its working folder or its descriptor; then held
//! open (`O_PATH`), checked by its real path and changed through that
//! descriptor, so no link swapped meanwhile leads elsewhere. Of a link
//! itself (`AT_SYMLINK_NOFOLLOW` on a link) nothing is changed (`EPERM`).
//! Trap: `chmod`, `utime`, `utimes` and `futimesat` exist on x86_64 alone.

use std::ffi::{CStr, CString};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::path::{Path, PathBuf};

/// Numbers alike on every architecture, which the libc crate may not name.
pub(super) const FCHMODAT2: libc::c_long = 452;

const NOFOLLOW: u64 = libc::AT_SYMLINK_NOFOLLOW as u64;
const EMPTY_PATH: u64 = libc::AT_EMPTY_PATH as u64;

/// The calls handled here.
pub(super) fn handled() -> Vec<libc::c_long> {
    let mut calls = vec![
        libc::SYS_fchmod,
        libc::SYS_fchmodat,
        FCHMODAT2,
        libc::SYS_utimensat,
        libc::SYS_truncate,
    ];
    #[cfg(target_arch = "x86_64")]
    calls.extend([
        libc::SYS_chmod,
        libc::SYS_utime,
        libc::SYS_utimes,
        libc::SYS_futimesat,
    ]);
    calls
}

/// The file a call names: by a path from a folder, or a descriptor alone.
enum Named {
    Path {
        folder: Option<i32>,
        path: u64,
        flags: u64,
    },
    Descriptor(i32),
}

/// What is done to the file.
enum Change {
    Mode(libc::mode_t),
    /// Two `timespec`s, or `None` for now.
    Times(Option<[libc::timespec; 2]>),
    Length(libc::off_t),
}

/// Does call `nr` with `args` of thread `pid` where its file is in one of
/// `writable` (real paths); `standing` tells the call still waits. Its result.
pub(super) fn change(
    pid: libc::pid_t,
    nr: libc::c_long,
    args: [u64; 6],
    writable: &[PathBuf],
    standing: &dyn Fn() -> bool,
) -> Result<i64, i32> {
    let (named, change) = decode(pid, nr, args)?;
    let file = open(pid, named, standing)?;
    let real = std::fs::read_link(format!("/proc/self/fd/{}", file.as_raw_fd()))
        .map_err(|_| libc::EACCES)?;
    if !writable.iter().any(|folder| real.starts_with(folder)) {
        return Err(libc::EACCES);
    }
    apply(&file, change)
}

/// What call `nr` names and asks, its memory read once.
fn decode(pid: libc::pid_t, nr: libc::c_long, a: [u64; 6]) -> Result<(Named, Change), i32> {
    let at = |folder: u64, path: u64, flags: u64| match path {
        0 => Named::Descriptor(folder as i32),
        _ => Named::Path {
            folder: Some(folder as i32),
            path,
            flags,
        },
    };
    let cwd = |path: u64| Named::Path {
        folder: None,
        path,
        flags: 0,
    };
    Ok(match nr {
        libc::SYS_fchmod => (Named::Descriptor(a[0] as i32), Change::Mode(a[1] as _)),
        libc::SYS_fchmodat => (at(a[0], a[1], 0), Change::Mode(a[2] as _)),
        FCHMODAT2 => (at(a[0], a[1], a[3]), Change::Mode(a[2] as _)),
        libc::SYS_utimensat => (at(a[0], a[1], a[3]), Change::Times(timespecs(pid, a[2])?)),
        libc::SYS_truncate => (cwd(a[0]), Change::Length(a[1] as _)),
        #[cfg(target_arch = "x86_64")]
        libc::SYS_chmod => (cwd(a[0]), Change::Mode(a[1] as _)),
        #[cfg(target_arch = "x86_64")]
        libc::SYS_utime => (cwd(a[0]), Change::Times(utimbuf(pid, a[1])?)),
        #[cfg(target_arch = "x86_64")]
        libc::SYS_utimes => (cwd(a[0]), Change::Times(timevals(pid, a[1])?)),
        #[cfg(target_arch = "x86_64")]
        libc::SYS_futimesat => (at(a[0], a[1], 0), Change::Times(timevals(pid, a[2])?)),
        _ => return Err(libc::EPERM),
    })
}

/// Reads `into.len()` bytes at `address` of process `pid`, page by page.
pub(super) fn read_memory(pid: libc::pid_t, address: u64, into: &mut [u8]) -> bool {
    let mut done = 0;
    while done < into.len() {
        let at = address.wrapping_add(done as u64);
        let page = 4096 - (at % 4096) as usize;
        let length = page.min(into.len() - done);
        let local = libc::iovec {
            iov_base: into[done..].as_mut_ptr().cast(),
            iov_len: length,
        };
        let remote = libc::iovec {
            iov_base: at as *mut libc::c_void,
            iov_len: length,
        };
        // SAFETY: the local buffer is ours and as long as asked; the remote
        // one the kernel checks.
        let read = unsafe { libc::process_vm_readv(pid, &local, 1, &remote, 1, 0) };
        if read != length as isize {
            return false;
        }
        done += length;
    }
    true
}

/// A path of at most `PATH_MAX` bytes at `address`, read up to its end.
fn read_path(pid: libc::pid_t, address: u64) -> Result<CString, i32> {
    let mut path = Vec::new();
    let mut at = address;
    while path.len() < libc::PATH_MAX as usize {
        let mut page = vec![0u8; 4096 - (at % 4096) as usize];
        if !read_memory(pid, at, &mut page) {
            return Err(libc::EFAULT);
        }
        if let Some(end) = page.iter().position(|&byte| byte == 0) {
            path.extend_from_slice(&page[..end]);
            return CString::new(path).map_err(|_| libc::EINVAL);
        }
        path.extend_from_slice(&page);
        at += page.len() as u64;
    }
    Err(libc::ENAMETOOLONG)
}

fn timespecs(pid: libc::pid_t, address: u64) -> Result<Option<[libc::timespec; 2]>, i32> {
    times(pid, address, 1)
}

#[cfg(target_arch = "x86_64")]
fn timevals(pid: libc::pid_t, address: u64) -> Result<Option<[libc::timespec; 2]>, i32> {
    times(pid, address, 1000)
}

/// `struct utimbuf`: two whole seconds.
#[cfg(target_arch = "x86_64")]
fn utimbuf(pid: libc::pid_t, address: u64) -> Result<Option<[libc::timespec; 2]>, i32> {
    if address == 0 {
        return Ok(None);
    }
    let mut bytes = [0u8; 16];
    if !read_memory(pid, address, &mut bytes) {
        return Err(libc::EFAULT);
    }
    let second = |at: usize| i64::from_ne_bytes(bytes[at..at + 8].try_into().unwrap_or_default());
    let time = |at| libc::timespec {
        tv_sec: second(at),
        tv_nsec: 0,
    };
    Ok(Some([time(0), time(8)]))
}

/// Two pairs of seconds and a fraction (`timespec`, or `timeval` with `scale`
/// 1000) at `address`, `None` where it is 0.
fn times(pid: libc::pid_t, address: u64, scale: i64) -> Result<Option<[libc::timespec; 2]>, i32> {
    if address == 0 {
        return Ok(None);
    }
    let mut bytes = [0u8; 32];
    if !read_memory(pid, address, &mut bytes) {
        return Err(libc::EFAULT);
    }
    let word = |at: usize| i64::from_ne_bytes(bytes[at..at + 8].try_into().unwrap_or_default());
    let time = |at: usize| {
        let fraction = word(at + 8);
        libc::timespec {
            tv_sec: word(at),
            // UTIME_NOW and UTIME_OMIT pass as they are.
            tv_nsec: match scale {
                1 => fraction,
                _ => fraction.saturating_mul(scale),
            },
        }
    };
    Ok(Some([time(0), time(16)]))
}

/// The file `named` by thread `pid`, held open by the server.
fn open(pid: libc::pid_t, named: Named, standing: &dyn Fn() -> bool) -> Result<OwnedFd, i32> {
    let (folder, path, flags) = match named {
        Named::Descriptor(fd) => return descriptor(pid, fd, standing),
        Named::Path {
            folder,
            path,
            flags,
        } => (folder, read_path(pid, path)?, flags),
    };
    if flags & EMPTY_PATH != 0 && path.is_empty() {
        return match folder {
            Some(fd) => descriptor(pid, fd, standing),
            None => Err(libc::ENOENT),
        };
    }
    let base = match folder {
        Some(fd) if fd != libc::AT_FDCWD && path.as_bytes().first() != Some(&b'/') => {
            descriptor(pid, fd, standing)?
        }
        _ => open_at(
            libc::AT_FDCWD,
            &CString::new(format!("/proc/{pid}/cwd")).map_err(|_| libc::EINVAL)?,
            0,
        )?,
    };
    // The working folder read is the caller's.
    if !standing() {
        return Err(libc::EPERM);
    }
    let nofollow = match flags & NOFOLLOW {
        0 => 0,
        _ => libc::O_NOFOLLOW,
    };
    let file = open_at(base.as_raw_fd(), &path, nofollow)?;
    // SAFETY: a stat of zeroes is a valid value, filled by the call after.
    let mut kind: libc::stat = unsafe { std::mem::zeroed() };
    // SAFETY: the stat lives through the call.
    if unsafe { libc::fstat(file.as_raw_fd(), &mut kind) } != 0
        || kind.st_mode & libc::S_IFMT == libc::S_IFLNK
    {
        return Err(libc::EPERM);
    }
    Ok(file)
}

/// `openat(folder, path, O_PATH | extra)`.
fn open_at(folder: i32, path: &CStr, extra: i32) -> Result<OwnedFd, i32> {
    // SAFETY: the path lives through the call; the descriptor it makes is ours.
    let fd = unsafe {
        libc::openat(
            folder,
            path.as_ptr(),
            libc::O_PATH | libc::O_CLOEXEC | extra,
        )
    };
    match fd < 0 {
        true => Err(errno()),
        // SAFETY: as above.
        false => Ok(unsafe { OwnedFd::from_raw_fd(fd) }),
    }
}

/// A copy of descriptor `fd` of thread `pid`'s process.
fn descriptor(pid: libc::pid_t, fd: i32, standing: &dyn Fn() -> bool) -> Result<OwnedFd, i32> {
    let process = super::supervisor::status(pid, "Tgid:").ok_or(libc::EPERM)?;
    let pidfd = super::supervisor::pidfd_open(process).ok_or(libc::EPERM)?;
    // SAFETY: a plain system call; the descriptor it makes is ours.
    let copy = unsafe { libc::syscall(libc::SYS_pidfd_getfd, pidfd.as_raw_fd(), fd, 0u32) };
    if copy < 0 {
        return Err(libc::EBADF);
    }
    // SAFETY: as above.
    let copy = unsafe { OwnedFd::from_raw_fd(copy as i32) };
    // The process read is the caller's.
    match standing() {
        true => Ok(copy),
        false => Err(libc::EPERM),
    }
}

/// Does `change` to `file` through its descriptor's link in `/proc`.
fn apply(file: &OwnedFd, change: Change) -> Result<i64, i32> {
    let link = format!("/proc/self/fd/{}", file.as_raw_fd());
    let link = CString::new(link).map_err(|_| libc::EINVAL)?;
    // SAFETY: plain system calls on values that live through them.
    let done = unsafe {
        match change {
            Change::Mode(mode) => libc::fchmodat(libc::AT_FDCWD, link.as_ptr(), mode, 0),
            Change::Times(times) => libc::utimensat(
                libc::AT_FDCWD,
                link.as_ptr(),
                times
                    .as_ref()
                    .map_or(std::ptr::null(), |times| times.as_ptr()),
                0,
            ),
            Change::Length(length) => libc::truncate(link.as_ptr(), length),
        }
    };
    match done {
        0 => Ok(0),
        _ => Err(errno()),
    }
}

fn errno() -> i32 {
    std::io::Error::last_os_error()
        .raw_os_error()
        .unwrap_or(libc::EPERM)
}

/// The real paths of the folders a command writes, for [`change`].
pub(super) fn writable(folders: &[&Path]) -> Vec<PathBuf> {
    folders
        .iter()
        .filter_map(|folder| folder.canonicalize().ok())
        .collect()
}

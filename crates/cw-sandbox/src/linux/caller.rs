//! What the server reads of the process whose system call the filter sent it
//! (`supervisor.rs`, `metadata.rs`): its memory, a path in it, a field of its
//! `/proc` status and a copy of one of its descriptors.
//! Trap: the caller may have ended and its id been taken meanwhile; whatever
//! is read is trusted only after the caller is found still waiting in its
//! call (`standing`).

use std::ffi::CString;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};

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
pub(super) fn read_path(pid: libc::pid_t, address: u64) -> Result<CString, i32> {
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

/// A process's field `field` (such as `Tgid:`) from `/proc/<pid>/status`.
pub(super) fn status(pid: libc::pid_t, field: &str) -> Option<libc::pid_t> {
    let text = std::fs::read_to_string(format!("/proc/{pid}/status")).ok()?;
    text.lines()
        .find_map(|line| line.strip_prefix(field))
        .and_then(|value| value.trim().parse().ok())
}

pub(super) fn pidfd_open(pid: libc::pid_t) -> Option<OwnedFd> {
    // SAFETY: a plain system call; the descriptor it makes is ours.
    let fd = unsafe { libc::syscall(libc::SYS_pidfd_open, pid, 0u32) };
    // SAFETY: as above.
    (fd >= 0).then(|| unsafe { OwnedFd::from_raw_fd(fd as libc::c_int) })
}

/// A copy of descriptor `fd` of thread `pid`'s process, kept only where
/// `standing` holds after it is made: the process read is then the caller's.
pub(super) fn descriptor(
    pid: libc::pid_t,
    fd: i32,
    standing: &dyn Fn() -> bool,
) -> Result<OwnedFd, i32> {
    let process = status(pid, "Tgid:").ok_or(libc::EPERM)?;
    let pidfd = pidfd_open(process).ok_or(libc::EPERM)?;
    // SAFETY: a plain system call; the descriptor it makes is ours.
    let copy = unsafe { libc::syscall(libc::SYS_pidfd_getfd, pidfd.as_raw_fd(), fd, 0u32) };
    if copy < 0 {
        return Err(libc::EBADF);
    }
    // SAFETY: as above.
    let copy = unsafe { OwnedFd::from_raw_fd(copy as libc::c_int) };
    match standing() {
        true => Ok(copy),
        false => Err(libc::EPERM),
    }
}

/// The last system call's error number, `EPERM` where there is none.
pub(super) fn errno() -> i32 {
    std::io::Error::last_os_error()
        .raw_os_error()
        .unwrap_or(libc::EPERM)
}

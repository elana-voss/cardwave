//! Landlock, the kernel's own file sandbox, by its raw system calls: a
//! ruleset is made in the server (`Ruleset`) and laid on the command's
//! process before it runs `sh` (`restrict`), after which it reaches only the
//! files its rules let in. Every right of the kernel's Landlock version is
//! handled, so what no rule grants is refused; on version 6 and later the
//! command may also signal no process outside the sandbox.
//! Trap: a rule on a file (not a folder) may hold only a file's rights, else
//! the kernel refuses it (`EINVAL`).

use std::ffi::CString;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::path::Path;
use std::sync::OnceLock;

use anyhow::{Context, bail};

pub(super) const EXECUTE: u64 = 1 << 0;
const WRITE_FILE: u64 = 1 << 1;
pub(super) const READ_FILE: u64 = 1 << 2;
pub(super) const READ_DIR: u64 = 1 << 3;
const TRUNCATE: u64 = 1 << 14;
const IOCTL_DEV: u64 = 1 << 15;
/// The rights a rule on a single file may hold.
const FILE_RIGHTS: u64 = EXECUTE | WRITE_FILE | READ_FILE | TRUNCATE | IOCTL_DEV;
/// Reading a folder's files and running its programs.
pub(super) const READ_EXEC: u64 = EXECUTE | READ_FILE | READ_DIR;
/// Reading and writing a device such as `/dev/null`.
pub(super) const DEVICE: u64 = READ_FILE | WRITE_FILE | TRUNCATE;

const CREATE_RULESET_VERSION: u32 = 1;
const RULE_PATH_BENEATH: libc::c_int = 1;
const SCOPE_ABSTRACT_UNIX_SOCKET: u64 = 1;
const SCOPE_SIGNAL: u64 = 2;

#[repr(C)]
struct RulesetAttr {
    handled_access_fs: u64,
    handled_access_net: u64,
    scoped: u64,
}

#[repr(C, packed)]
struct PathBeneathAttr {
    allowed_access: u64,
    parent_fd: i32,
}

/// The kernel's Landlock version, 0 where it has none (or it is off).
pub(super) fn version() -> i64 {
    static VERSION: OnceLock<i64> = OnceLock::new();
    *VERSION.get_or_init(|| {
        // SAFETY: the version query takes no attributes.
        let version = unsafe {
            libc::syscall(
                libc::SYS_landlock_create_ruleset,
                std::ptr::null::<RulesetAttr>(),
                0usize,
                CREATE_RULESET_VERSION,
            )
        };
        version.max(0)
    })
}

/// Every file right the kernel's version knows.
fn handled() -> u64 {
    match version() {
        1 => (1 << 13) - 1,
        2 => (1 << 14) - 1,
        3 | 4 => (1 << 15) - 1,
        _ => (1 << 16) - 1,
    }
}

/// A ruleset being made: what is not let in by a rule is refused.
pub(super) struct Ruleset(OwnedFd);

impl Ruleset {
    pub(super) fn new() -> anyhow::Result<Self> {
        let attributes = RulesetAttr {
            handled_access_fs: handled(),
            handled_access_net: 0,
            scoped: match version() >= 6 {
                true => SCOPE_ABSTRACT_UNIX_SOCKET | SCOPE_SIGNAL,
                false => 0,
            },
        };
        // SAFETY: the attributes live through the call, with their size; an
        // older kernel takes the larger struct as its fields beyond its own are 0.
        let fd = unsafe {
            libc::syscall(
                libc::SYS_landlock_create_ruleset,
                &attributes,
                size_of::<RulesetAttr>(),
                0u32,
            )
        };
        if fd < 0 {
            bail!(
                "no Landlock ruleset for the command: {}",
                std::io::Error::last_os_error()
            );
        }
        // SAFETY: the descriptor is new and ours.
        Ok(Self(unsafe { OwnedFd::from_raw_fd(fd as RawFd) }))
    }

    /// Lets in `path` and all beneath it with `rights` (those of a file
    /// alone where it is one). A path that does not exist is passed over.
    pub(super) fn allow(&self, path: &Path, rights: u64) -> anyhow::Result<()> {
        let name = CString::new(path.as_os_str().as_bytes()).context("a path with a 0 byte")?;
        // SAFETY: the name ends in 0 and lives through the call.
        let fd = unsafe { libc::open(name.as_ptr(), libc::O_PATH | libc::O_CLOEXEC) };
        if fd < 0 {
            return Ok(());
        }
        // SAFETY: the descriptor is new and ours.
        let parent = unsafe { OwnedFd::from_raw_fd(fd) };
        let folder = std::fs::metadata(path).is_ok_and(|kind| kind.is_dir());
        let rights = rights & handled() & if folder { u64::MAX } else { FILE_RIGHTS };
        let rule = PathBeneathAttr {
            allowed_access: rights,
            parent_fd: parent.as_raw_fd(),
        };
        // SAFETY: the rule lives through the call; both descriptors are open.
        let added = unsafe {
            libc::syscall(
                libc::SYS_landlock_add_rule,
                self.0.as_raw_fd(),
                RULE_PATH_BENEATH,
                &rule,
                0u32,
            )
        };
        if added < 0 {
            bail!(
                "{} cannot be let in for the command: {}",
                path.display(),
                std::io::Error::last_os_error()
            );
        }
        Ok(())
    }

    pub(super) fn fd(&self) -> RawFd {
        self.0.as_raw_fd()
    }
}

/// Lays the ruleset `fd` on this process. Only for the command's process
/// between fork and exec: it allocates nothing. `NO_NEW_PRIVS` must be set.
pub(super) fn restrict(fd: RawFd) -> std::io::Result<()> {
    // SAFETY: a plain system call on an open descriptor.
    match unsafe { libc::syscall(libc::SYS_landlock_restrict_self, fd, 0u32) } {
        0 => Ok(()),
        _ => Err(std::io::Error::last_os_error()),
    }
}

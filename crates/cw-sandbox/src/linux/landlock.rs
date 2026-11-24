//! Landlock, the kernel's own file sandbox, by the `landlock` crate (the
//! kernel feature's own project): a ruleset is made in the server (`Ruleset`)
//! and laid on the command's process before it runs `sh`
//! (`Ruleset::restrict`), after which it reaches only the files its rules let
//! in. Every right of the kernel's Landlock version is handled, so what no
//! rule grants is refused; on version 6 and later the command may also signal
//! no process and reach no abstract socket outside the sandbox. The crate
//! drops what an older kernel lacks, and a rule on a file (not a folder) to a
//! file's rights.
//! Trap: `restrict` runs between fork and exec; the crate's `restrict_self`
//! makes system calls only and allocates nothing (read in landlock 0.4.8), so
//! a newer version of the crate is read again for that.

use std::path::Path;
use std::sync::OnceLock;

use anyhow::Context;
use landlock::{
    ABI, Access, AccessFs, BitFlags, CompatLevel, Compatible, PathBeneath, PathFd, RulesetAttr,
    RulesetCreated, RulesetCreatedAttr, RulesetStatus, Scope, make_bitflags,
};

/// The newest Landlock version the crate knows: all its rights are asked for,
/// the crate keeps those of the kernel's version.
const NEWEST: ABI = ABI::V10;

/// Rights on the files beneath a rule's path.
pub(super) type Rights = BitFlags<AccessFs>;
/// Reading a file.
pub(super) const READ_FILE: Rights = make_bitflags!(AccessFs::{ReadFile});
/// Reading a folder's files and running its programs.
pub(super) const READ_EXEC: Rights = make_bitflags!(AccessFs::{Execute | ReadFile | ReadDir});
/// Reading and writing a device such as `/dev/null`.
pub(super) const DEVICE: Rights = make_bitflags!(AccessFs::{ReadFile | WriteFile | Truncate});

/// Every right, for the command's own folders.
pub(super) fn every_right() -> Rights {
    AccessFs::from_all(NEWEST)
}

/// Whether the kernel has Landlock, and it is on.
pub(super) fn available() -> bool {
    static AVAILABLE: OnceLock<bool> = OnceLock::new();
    *AVAILABLE.get_or_init(|| {
        landlock::Ruleset::default()
            .set_compatibility(CompatLevel::HardRequirement)
            .handle_access(AccessFs::Execute)
            .and_then(|rules| rules.create())
            .is_ok()
    })
}

/// A ruleset being made: what is not let in by a rule is refused.
pub(super) struct Ruleset(RulesetCreated);

impl Ruleset {
    pub(super) fn new() -> anyhow::Result<Self> {
        let rules = landlock::Ruleset::default()
            .handle_access(every_right())
            .and_then(|rules| rules.scope(Scope::from_all(NEWEST)))
            .and_then(|rules| rules.create())
            .context("no Landlock ruleset for the command")?
            // The command's process sets it itself, before its seccomp filter.
            .no_new_privs(false);
        Ok(Self(rules))
    }

    /// Lets in `path` and all beneath it with `rights` (those of a file
    /// alone where it is one). A path that cannot be opened is passed over.
    pub(super) fn allow(&mut self, path: &Path, rights: Rights) -> anyhow::Result<()> {
        let Ok(parent) = PathFd::new(path) else {
            return Ok(());
        };
        (&mut self.0)
            .add_rule(PathBeneath::new(parent, rights))
            .with_context(|| format!("{} cannot be let in for the command", path.display()))?;
        Ok(())
    }

    /// Lays the ruleset on this process. Only for the command's process
    /// between fork and exec: it allocates nothing. `NO_NEW_PRIVS` must be set.
    pub(super) fn restrict(self) -> std::io::Result<()> {
        match self.0.restrict_self() {
            Ok(status) if status.ruleset != RulesetStatus::NotEnforced => Ok(()),
            // No Landlock here: the command must not run unconfined.
            Ok(_) => Err(std::io::ErrorKind::Unsupported.into()),
            // The crate's error holds the failed call's own; read from errno
            // so as to allocate nothing.
            Err(_) => Err(std::io::Error::last_os_error()),
        }
    }
}

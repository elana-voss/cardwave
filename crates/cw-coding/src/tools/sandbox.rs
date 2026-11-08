//! The shell tool's sandbox: a command run by `cmd.exe` in a Windows
//! AppContainer, which reaches no file but those of the folder it is given
//! (and what Windows lets every app read, such as `C:\Windows`), no network,
//! and nothing of the server's: no handle but its output's, no variable of
//! its environment but the system's own. Its processes are in a job that ends
//! them all when the command has run its time or ended.
//!
//! The container is the folder's own (`CONTAINER` and a hash of its path),
//! let in by an entry in the folder's access list that stays there (Windows
//! shows it as an unknown account). A command ends when `stopped` is set.
//! Trap: cmd's `dir` and `vol` read the drive's root and are refused; a refused one says `LISTING`.
//! Elsewhere than on Windows the shell tool is not offered (`AVAILABLE`).
//!
//! The coding team's commands reach more (`Reach`): the folders of the
//! server's `PATH` that hold programs (`grantable`) and what their programs
//! need, read only, through a
//! capability of Cardwave's own each is let in to, or a copy where it cannot
//! be (`programs`); a folder of the container's own for their caches; and for
//! installs the internet (not this computer's own addresses).

use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;
use std::time::Duration;

/// Whether this system has the sandbox.
pub const AVAILABLE: bool = cfg!(windows);

/// The most of a command's output that is kept, in bytes.
pub(crate) const OUTPUT_LIMIT: usize = 32 * 1024;

/// How a command went.
#[derive(Debug)]
pub struct Ran {
    /// What it wrote, its errors among it, at most [`OUTPUT_LIMIT`].
    pub output: String,
    /// Its exit code; `None` when it ran out of time and was ended.
    pub code: Option<u32>,
}

/// What a command reaches beside its folder.
#[derive(Clone, Debug, Default)]
pub struct Reach {
    /// The internet.
    pub network: bool,
    /// The programs of the server's `PATH`, and a folder of the container's
    /// own for what they keep (`LOCALAPPDATA`, `APPDATA`, `TEMP` and the like).
    pub programs: bool,
    /// Cardwave's data folder, which no folder let in holds or is in.
    pub data: PathBuf,
}

/// Whether a folder of the server's `PATH` is let in for a team's command:
/// where it holds a program itself (.exe, .cmd, .bat, .com) and is
/// [`allowed`].
pub fn grantable(folder: &Path, data: &Path) -> bool {
    let program = |entry: std::fs::DirEntry| {
        let name = entry.file_name().to_string_lossy().to_lowercase();
        [".exe", ".cmd", ".bat", ".com"]
            .iter()
            .any(|kind| name.ends_with(kind))
            && entry.file_type().is_ok_and(|kind| kind.is_file())
    };
    allowed(folder, data)
        && std::fs::read_dir(folder)
            .into_iter()
            .flatten()
            .flatten()
            .any(program)
}

/// Whether a folder may be let in at all: not a drive's root, the user's
/// profile folder, nor one that holds the data folder `data` or is in it (the
/// rule of the folder the model's tools work in).
fn allowed(folder: &Path, data: &Path) -> bool {
    let profile =
        std::env::var_os("USERPROFILE").and_then(|home| Path::new(&home).canonicalize().ok());
    cw_library::settings::folder_checked(&folder.to_string_lossy(), data).is_ok()
        && folder.canonicalize().ok() != profile
}

/// Runs `command` with `cmd.exe /c` in `folder`, for at most `time` and
/// until `stopped` is set. Blocks.
pub fn run(
    folder: &Path,
    command: &str,
    time: Duration,
    stopped: &AtomicBool,
) -> anyhow::Result<Ran> {
    run_with(folder, command, time, stopped, Reach::default())
}

/// A command that lists the folder's files in the sandbox, where cmd's `dir`
/// and `vol` are refused: they read the drive's own details first.
pub const LISTING: &str = "for %f in (*) do @echo %f";

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
    let mut ran = crate::tools::sandbox::windows::run(folder, command, time, stopped, reach)?;
    let reads_drive = command
        .split(|c: char| !c.is_ascii_alphanumeric())
        .any(|word| word.eq_ignore_ascii_case("dir") || word.eq_ignore_ascii_case("vol"));
    if reads_drive && ran.code != Some(0) {
        ran.output.push_str(&format!(
            "\n(The sandbox lets no command read the drive, so dir and vol are refused. List the folder with `{LISTING}`, its folders with `for /d %f in (*) do @echo %f`, or a subfolder with `for /r sub %f in (*) do @echo %f`.)"
        ));
    }
    Ok(ran)
}

#[cfg(not(windows))]
pub fn run_with(
    _folder: &Path,
    _command: &str,
    _time: Duration,
    _stopped: &AtomicBool,
    _reach: Reach,
) -> anyhow::Result<Ran> {
    anyhow::bail!("commands are run only on Windows")
}

#[cfg(windows)]
mod windows {
    use std::collections::BTreeMap;
    use std::ffi::OsStr;
    use std::io::{PipeReader, Read};
    use std::os::windows::ffi::OsStrExt;
    use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
    use std::path::{Path, PathBuf};
    use std::ptr::{null, null_mut};
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Mutex, OnceLock, mpsc};
    use std::time::{Duration, Instant};

    use anyhow::{Context, bail, ensure};
    use windows_sys::Win32::Foundation::{
        ERROR_ALREADY_EXISTS, HANDLE, HANDLE_FLAG_INHERIT, LocalFree, SetHandleInformation,
        WAIT_TIMEOUT,
    };
    use windows_sys::Win32::Security::Authorization::{
        ConvertSidToStringSidW, ConvertStringSidToSidW,
    };
    use windows_sys::Win32::Security::Authorization::{
        EXPLICIT_ACCESS_W, GRANT_ACCESS, GetNamedSecurityInfoW, SE_FILE_OBJECT, SetEntriesInAclW,
        SetNamedSecurityInfoW, TRUSTEE_IS_SID, TRUSTEE_IS_WELL_KNOWN_GROUP, TRUSTEE_W,
    };
    use windows_sys::Win32::Security::Isolation::{
        CreateAppContainerProfile, DeriveAppContainerSidFromAppContainerName,
        GetAppContainerFolderPath,
    };
    use windows_sys::Win32::Security::{
        ACCESS_ALLOWED_ACE, ACL, DACL_SECURITY_INFORMATION, DeriveCapabilitySidsFromName, EqualSid,
        FreeSid, GetAce, PSECURITY_DESCRIPTOR, PSID, SECURITY_CAPABILITIES, SID_AND_ATTRIBUTES,
        SUB_CONTAINERS_AND_OBJECTS_INHERIT,
    };
    use windows_sys::Win32::Storage::FileSystem::{
        FILE_ALL_ACCESS, FILE_GENERIC_EXECUTE, FILE_GENERIC_READ,
    };
    use windows_sys::Win32::System::Com::CoTaskMemFree;
    use windows_sys::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_JOB_MEMORY,
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
        JobObjectExtendedLimitInformation, SetInformationJobObject, TerminateJobObject,
    };
    use windows_sys::Win32::System::Threading::{
        CREATE_NO_WINDOW, CREATE_SUSPENDED, CREATE_UNICODE_ENVIRONMENT, CreateProcessW,
        DeleteProcThreadAttributeList, EXTENDED_STARTUPINFO_PRESENT, GetExitCodeProcess,
        InitializeProcThreadAttributeList, LPPROC_THREAD_ATTRIBUTE_LIST,
        PROC_THREAD_ATTRIBUTE_HANDLE_LIST, PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES,
        PROCESS_INFORMATION, ResumeThread, STARTF_USESTDHANDLES, STARTUPINFOEXW, TerminateProcess,
        UpdateProcThreadAttribute, WaitForSingleObject,
    };

    use crate::tools::sandbox::{OUTPUT_LIMIT, Ran, Reach};

    /// The capability of a container that reaches the internet ("internetClient").
    const INTERNET: &str = "S-1-15-3-1";

    /// A capability granted (`SE_GROUP_ENABLED`).
    const ENABLED: u32 = 4;

    /// What every app is (`ALL APPLICATION PACKAGES`).
    const EVERY_APP: &str = "S-1-15-2-1";

    /// The capability of Cardwave's own that program folders let in.
    const PROGRAMS: &str = "cardwavePrograms";

    /// The most a folder of programs is copied at.
    const COPY_LIMIT: u64 = 512 << 20;

    /// The file of a copied folder that says what it was copied from.
    const STAMP: &str = ".cardwave-copy";

    /// An entry that lets a SID in (`ACCESS_ALLOWED_ACE_TYPE`).
    const ALLOWED: u8 = 0;

    /// What the AppContainer profile of a folder is called, before its hash.
    const CONTAINER: &str = "Cardwave.Shell.";

    /// How long the output is waited for once the command's processes are ended.
    const LAST_OUTPUT: Duration = Duration::from_secs(2);

    /// How often a command that runs is asked whether it has ended or is stopped.
    const LOOK: u32 = 100;

    /// The most memory a command's processes take together.
    const MEMORY_LIMIT: usize = 1 << 30;

    /// The variables a command is given, of the server's own where it has them;
    /// without `LOCALAPPDATA` Windows makes no process in a container (error 203).
    const KEPT: [&str; 7] = [
        "SystemRoot",
        "windir",
        "ComSpec",
        "PATHEXT",
        "SystemDrive",
        "NUMBER_OF_PROCESSORS",
        "LOCALAPPDATA",
    ];

    fn wide(text: impl AsRef<OsStr>) -> Vec<u16> {
        text.as_ref().encode_wide().chain([0]).collect()
    }

    /// A capability's SID, made of its text, freed on drop.
    struct Capability(PSID);

    impl Capability {
        fn of(text: &str) -> anyhow::Result<Self> {
            let text = wide(text);
            let mut sid: PSID = null_mut();
            // SAFETY: the text ends in zero, and `sid` is written by the call.
            let made = unsafe { ConvertStringSidToSidW(text.as_ptr(), &mut sid) };
            ensure!(made != 0, "the sandbox's capability cannot be granted");
            Ok(Self(sid))
        }

        /// [`PROGRAMS`].
        fn programs() -> anyhow::Result<Self> {
            static TEXT: OnceLock<String> = OnceLock::new();
            if let Some(text) = TEXT.get() {
                return Self::of(text);
            }
            let name = wide(PROGRAMS);
            let (mut groups, mut sids): (*mut PSID, *mut PSID) = (null_mut(), null_mut());
            let (mut group_count, mut count) = (0u32, 0u32);
            // SAFETY: the name ends in zero; the SIDs and lists the call hands
            // back are freed with `LocalFree`, as it says, and read only before.
            let text = unsafe {
                let made = DeriveCapabilitySidsFromName(
                    name.as_ptr(),
                    &mut groups,
                    &mut group_count,
                    &mut sids,
                    &mut count,
                );
                ensure!(made != 0, "the sandbox's programs cannot be granted");
                let mut text: *mut u16 = null_mut();
                let read = count > 0 && ConvertSidToStringSidW(*sids, &mut text) != 0;
                for at in 0..group_count as usize {
                    LocalFree(*groups.add(at));
                }
                for at in 0..count as usize {
                    LocalFree(*sids.add(at));
                }
                LocalFree(groups.cast());
                LocalFree(sids.cast());
                ensure!(read, "the sandbox's programs cannot be named");
                let length = (0..).take_while(|&at| *text.add(at) != 0).count();
                let said = String::from_utf16_lossy(std::slice::from_raw_parts(text, length));
                LocalFree(text.cast());
                said
            };
            Self::of(TEXT.get_or_init(|| text))
        }
    }

    impl Drop for Capability {
        fn drop(&mut self) {
            // SAFETY: the SID came from `ConvertStringSidToSidW`, which says to free it so.
            unsafe { LocalFree(self.0) };
        }
    }

    /// The container's SID, freed on drop.
    struct Sid(PSID);

    impl Drop for Sid {
        fn drop(&mut self) {
            // SAFETY: the SID came from the container's functions, which say to free it so.
            unsafe { FreeSid(self.0) };
        }
    }

    /// The container of `folder`, made where it is not there yet.
    fn container(folder: &Path) -> anyhow::Result<Sid> {
        use sha2::{Digest, Sha256};
        let real = std::fs::canonicalize(folder).context("the folder is not there")?;
        let hash = Sha256::digest(real.to_string_lossy().to_lowercase().as_bytes());
        let hash: String = hash[..8].iter().map(|byte| format!("{byte:02x}")).collect();
        let name = wide(format!("{CONTAINER}{hash}"));
        let mut sid: PSID = null_mut();
        // SAFETY: the strings end in zero, and `sid` is written by the call.
        let made = unsafe {
            CreateAppContainerProfile(
                name.as_ptr(),
                name.as_ptr(),
                name.as_ptr(),
                null(),
                0,
                &mut sid,
            )
        };
        if made >= 0 {
            return Ok(Sid(sid));
        }
        ensure!(
            made == (0x8007_0000u32 | ERROR_ALREADY_EXISTS) as i32,
            "the sandbox cannot be made (0x{made:08X})"
        );
        // SAFETY: as above.
        let found = unsafe { DeriveAppContainerSidFromAppContainerName(name.as_ptr(), &mut sid) };
        ensure!(found >= 0, "the sandbox cannot be found (0x{found:08X})");
        Ok(Sid(sid))
    }

    /// Lets `sid` into `folder` and all it holds with `rights`, unless it is let in already.
    fn let_in(folder: &Path, sid: PSID, rights: u32) -> anyhow::Result<()> {
        let path = wide(folder);
        let mut old: *mut ACL = null_mut();
        let mut descriptor: PSECURITY_DESCRIPTOR = null_mut();
        // SAFETY: the path ends in zero; what the calls hand back is freed
        // with `LocalFree`, as they say, and read only while it lives.
        unsafe {
            let read = GetNamedSecurityInfoW(
                path.as_ptr(),
                SE_FILE_OBJECT,
                DACL_SECURITY_INFORMATION,
                null_mut(),
                null_mut(),
                &mut old,
                null_mut(),
                &mut descriptor,
            );
            ensure!(
                read == 0,
                "the folder's access cannot be read (error {read})"
            );
            let access = EXPLICIT_ACCESS_W {
                grfAccessPermissions: rights,
                grfAccessMode: GRANT_ACCESS,
                grfInheritance: SUB_CONTAINERS_AND_OBJECTS_INHERIT,
                Trustee: TRUSTEE_W {
                    TrusteeForm: TRUSTEE_IS_SID,
                    TrusteeType: TRUSTEE_IS_WELL_KNOWN_GROUP,
                    ptstrName: sid.cast(),
                    ..Default::default()
                },
            };
            let mut new: *mut ACL = null_mut();
            let merged = SetEntriesInAclW(1, &access, old, &mut new);
            let result = if merged != 0 {
                Err(anyhow::anyhow!(
                    "the folder's access cannot be changed (error {merged})"
                ))
            } else if same(old, new) {
                Ok(())
            } else {
                // Windows hands the new entry down to all the folder holds.
                let set = SetNamedSecurityInfoW(
                    path.as_ptr(),
                    SE_FILE_OBJECT,
                    DACL_SECURITY_INFORMATION,
                    null_mut(),
                    null_mut(),
                    new,
                    null(),
                );
                match set {
                    0 => Ok(()),
                    _ => Err(anyhow::anyhow!(
                        "the folder's access cannot be set (error {set})"
                    )),
                }
            };
            LocalFree(new.cast());
            LocalFree(descriptor);
            result
        }
    }

    /// Whether `folder`'s access list lets every app or `sid` in.
    fn lets_in(folder: &Path, sid: PSID) -> anyhow::Result<bool> {
        let every = Capability::of(EVERY_APP)?;
        let path = wide(folder);
        let mut list: *mut ACL = null_mut();
        let mut descriptor: PSECURITY_DESCRIPTOR = null_mut();
        // SAFETY: the path ends in zero; the list is read only while its
        // descriptor lives, which is freed with `LocalFree`, as the call says.
        unsafe {
            let read = GetNamedSecurityInfoW(
                path.as_ptr(),
                SE_FILE_OBJECT,
                DACL_SECURITY_INFORMATION,
                null_mut(),
                null_mut(),
                &mut list,
                null_mut(),
                &mut descriptor,
            );
            ensure!(
                read == 0,
                "the folder's access cannot be read (error {read})"
            );
            let mut found = list.is_null();
            for at in 0..if found { 0 } else { (*list).AceCount as u32 } {
                let mut entry: *mut std::ffi::c_void = null_mut();
                if GetAce(list, at, &mut entry) == 0 {
                    continue;
                }
                let entry = entry.cast::<ACCESS_ALLOWED_ACE>();
                if (*entry).Header.AceType != ALLOWED {
                    continue;
                }
                let whose = (&raw mut (*entry).SidStart).cast();
                if EqualSid(whose, every.0) != 0 || EqualSid(whose, sid) != 0 {
                    found = true;
                    break;
                }
            }
            LocalFree(descriptor);
            Ok(found)
        }
    }

    /// A team's command's `PATH`, and the variables its programs need.
    type Found = (String, Vec<(String, String)>);

    /// Where a container reaches a `PATH` folder's programs, and what they need.
    type Reached = (PathBuf, Vec<(String, String)>);

    /// The `PATH` of a team's command, and the variables its programs need:
    /// the folders of the server's `PATH` that are [`super::grantable`] and a
    /// container reaches (`reached`).
    fn programs(programs: &Capability, data: &Path) -> Found {
        static KNOWN: Mutex<BTreeMap<(PathBuf, PathBuf), Reached>> = Mutex::new(BTreeMap::new());
        let mut known = cw_core::lock(&KNOWN);
        let host = std::env::var_os("PATH").unwrap_or_default();
        resolve(std::env::split_paths(&host), data, &mut known, |folder| {
            crate::tools::sandbox::grantable(folder, data)
                .then(|| reached(folder, programs, data))
                .flatten()
        })
    }

    /// The `PATH` and variables of the `folders` a container reaches, each
    /// looked at with `look` and kept in `known` (keyed by the data folder too,
    /// a server's own) only where it holds programs: a folder found empty is
    /// looked at again each time, so a program installed while the server runs
    /// is found without a restart.
    pub(super) fn resolve(
        folders: impl Iterator<Item = PathBuf>,
        data: &Path,
        known: &mut BTreeMap<(PathBuf, PathBuf), Reached>,
        mut look: impl FnMut(&Path) -> Option<Reached>,
    ) -> Found {
        let mut path = Vec::new();
        let mut needs = Vec::new();
        for folder in folders {
            let key = (folder.clone(), data.to_path_buf());
            let reach = match known.get(&key).cloned() {
                Some(reach) => Some(reach),
                None => look(&folder).inspect(|reach| {
                    known.insert(key, reach.clone());
                }),
            };
            if let Some((folder, wanted)) = reach {
                path.push(folder.display().to_string());
                needs.extend(wanted);
            }
        }
        (path.join(";"), needs)
    }

    /// Where a container reaches the programs of `folder`: there, where it
    /// lets every app or [`PROGRAMS`] in or can be made to; in a copy, where
    /// it is in `Program Files` and cannot (as Node.js's installer leaves
    /// it); else nowhere. Besides, what its programs need elsewhere is let in:
    /// the runtimes Python's launchers name (`*.__target__`) and rustup's
    /// toolchains, whose folder its proxies are told (`RUSTUP_HOME`). Node.js
    /// is told to load its modules by the paths it is given: finding their
    /// real paths reads the drive's root, which no container may.
    fn reached(
        folder: &Path,
        programs: &Capability,
        data: &Path,
    ) -> Option<(PathBuf, Vec<(String, String)>)> {
        let read = FILE_GENERIC_READ | FILE_GENERIC_EXECUTE;
        let open = |folder: &Path| {
            crate::tools::sandbox::allowed(folder, data)
                && (lets_in(folder, programs.0).unwrap_or(false)
                    || let_in(folder, programs.0, read).is_ok())
        };
        let place = if open(folder) {
            folder.to_path_buf()
        } else {
            let installed = ["ProgramFiles", "ProgramFiles(x86)", "ProgramW6432"]
                .iter()
                .filter_map(std::env::var_os)
                .any(|root| folder.starts_with(root));
            if !folder.is_dir() || !installed {
                return None;
            }
            copied(folder, programs).ok()?
        };
        let mut needs = Vec::new();
        for entry in std::fs::read_dir(folder).into_iter().flatten().flatten() {
            let name = entry.file_name().to_string_lossy().to_lowercase();
            if name.ends_with(".__target__")
                && let Ok(target) = std::fs::read_to_string(entry.path())
                && let Some(runtime) = Path::new(target.trim()).parent()
            {
                open(runtime);
            }
            if name == "node.exe" {
                let flags = "--preserve-symlinks --preserve-symlinks-main";
                needs.push(("NODE_OPTIONS".into(), flags.into()));
            }
            if name == "rustup.exe" {
                let home = std::env::var_os("RUSTUP_HOME")
                    .map(PathBuf::from)
                    .or_else(|| {
                        Some(PathBuf::from(std::env::var_os("USERPROFILE")?).join(".rustup"))
                    });
                if let Some(home) = home.filter(|home| open(home)) {
                    needs.push(("RUSTUP_HOME".into(), home.display().to_string()));
                }
            }
        }
        Some((place, needs))
    }

    /// A copy of `folder` that [`PROGRAMS`] reaches, made anew where the
    /// folder's own files or the size of its whole tree changed since (an
    /// update inside a subfolder); refused over [`COPY_LIMIT`].
    fn copied(folder: &Path, programs: &Capability) -> anyhow::Result<PathBuf> {
        use sha2::{Digest, Sha256};
        let copies = std::env::temp_dir().join("cardwave-programs");
        std::fs::create_dir_all(&copies)?;
        let_in(
            &copies,
            programs.0,
            FILE_GENERIC_READ | FILE_GENERIC_EXECUTE,
        )?;
        let hash = Sha256::digest(folder.to_string_lossy().to_lowercase().as_bytes());
        let hash: String = hash[..8].iter().map(|byte| format!("{byte:02x}")).collect();
        let copy = copies.join(hash);
        fn size(folder: &Path) -> std::io::Result<u64> {
            let mut all = 0;
            for entry in std::fs::read_dir(folder)? {
                let entry = entry?;
                all += match entry.file_type()?.is_dir() {
                    true => size(&entry.path())?,
                    false => entry.metadata()?.len(),
                };
            }
            Ok(all)
        }
        let total = size(folder)?;
        let mut stamp = format!("{}\n{total}\n", folder.display());
        let mut files: Vec<_> = std::fs::read_dir(folder)?.flatten().collect();
        files.sort_by_key(|entry| entry.file_name());
        for entry in files {
            let data = entry.metadata()?;
            let changed = data.modified()?.duration_since(std::time::UNIX_EPOCH)?;
            let name = entry.file_name();
            stamp += &format!("{} {} {}\n", name.display(), data.len(), changed.as_secs());
        }
        if std::fs::read_to_string(copy.join(STAMP)).ok() == Some(stamp.clone()) {
            return Ok(copy);
        }
        fn copy_all(from: &Path, to: &Path) -> std::io::Result<()> {
            std::fs::create_dir_all(to)?;
            for entry in std::fs::read_dir(from)? {
                let entry = entry?;
                let target = to.join(entry.file_name());
                match entry.file_type()?.is_dir() {
                    true => copy_all(&entry.path(), &target)?,
                    false => std::fs::copy(entry.path(), target).map(drop)?,
                }
            }
            Ok(())
        }
        ensure!(total <= COPY_LIMIT, "the folder is too big to copy");
        // Not there the first time; what cannot be removed is written over below.
        let _ = std::fs::remove_dir_all(&copy);
        copy_all(folder, &copy)?;
        std::fs::write(copy.join(STAMP), stamp)?;
        Ok(copy)
    }

    /// [`copied`] with [`PROGRAMS`], for the tests.
    #[cfg(test)]
    pub(super) fn copied_for_test(folder: &Path) -> anyhow::Result<PathBuf> {
        copied(folder, &Capability::programs()?)
    }

    /// Whether two access lists are the same, byte for byte.
    ///
    /// SAFETY: both point to a whole list or are null.
    unsafe fn same(one: *const ACL, other: *const ACL) -> bool {
        if one.is_null() || other.is_null() {
            return one == other;
        }
        unsafe {
            let (a, b) = ((*one).AclSize as usize, (*other).AclSize as usize);
            a == b
                && std::slice::from_raw_parts(one.cast::<u8>(), a)
                    == std::slice::from_raw_parts(other.cast::<u8>(), b)
        }
    }

    /// The folder Windows keeps for the container `sid`, which it may write.
    fn own_folder(sid: &Sid) -> anyhow::Result<String> {
        // SAFETY: what the calls hand back is freed as they say, and read only while it lives.
        unsafe {
            let mut text: *mut u16 = null_mut();
            ensure!(
                ConvertSidToStringSidW(sid.0, &mut text) != 0,
                "the sandbox's name cannot be read"
            );
            let mut path: *mut u16 = null_mut();
            let found = GetAppContainerFolderPath(text, &mut path);
            LocalFree(text.cast());
            ensure!(found >= 0, "the sandbox has no folder (0x{found:08X})");
            let length = (0..).take_while(|&at| *path.add(at) != 0).count();
            let folder = String::from_utf16_lossy(std::slice::from_raw_parts(path, length));
            CoTaskMemFree(path.cast());
            Ok(folder)
        }
    }

    /// The command's environment: `KEPT` of the server's, and a `PATH` of
    /// Windows' own folders, sorted as Windows wants it; with `own`, the
    /// programs' `PATH` after them and their variables, and `own` for what
    /// programs keep.
    fn environment(own: Option<(&str, &Found)>) -> Vec<u16> {
        let root = std::env::var("SystemRoot").unwrap_or_else(|_| r"C:\Windows".into());
        let mut all: Vec<(String, String)> = KEPT
            .iter()
            .filter_map(|name| Some((name.to_string(), std::env::var(name).ok()?)))
            .collect();
        let mut path = format!(r"{root}\System32;{root};{root}\System32\WindowsPowerShell\v1.0");
        if let Some((own, (programs, needs))) = own {
            // Windows itself gives a container's process its own LOCALAPPDATA, TEMP and TMP.
            for name in ["APPDATA", "USERPROFILE", "HOME"] {
                all.push((name.into(), own.to_string()));
            }
            all.extend(needs.iter().cloned());
            path = format!("{path};{programs}");
        }
        all.push(("PATH".into(), path));
        all.sort_by_key(|(name, _)| name.to_uppercase());
        let mut block: Vec<u16> = Vec::new();
        for (name, value) in all {
            block.extend(OsStr::new(&format!("{name}={value}")).encode_wide());
            block.push(0);
        }
        block.push(0);
        block
    }

    /// A process attribute list, deleted on drop.
    struct Attributes(Vec<u8>);

    impl Attributes {
        fn new(count: u32) -> anyhow::Result<Self> {
            let mut size = 0;
            // SAFETY: the first call only says the size; the second is given that much.
            unsafe {
                InitializeProcThreadAttributeList(null_mut(), count, 0, &mut size);
                let mut list = Self(vec![0; size]);
                ensure!(
                    InitializeProcThreadAttributeList(list.list(), count, 0, &mut size) != 0,
                    "the sandbox's process cannot be described"
                );
                Ok(list)
            }
        }

        fn list(&mut self) -> LPPROC_THREAD_ATTRIBUTE_LIST {
            self.0.as_mut_ptr().cast()
        }

        /// SAFETY: `value` lives as long as the list is used.
        unsafe fn set<T>(&mut self, attribute: u32, value: *const T) -> anyhow::Result<()> {
            let list = self.list();
            let set = unsafe {
                UpdateProcThreadAttribute(
                    list,
                    0,
                    attribute as usize,
                    value.cast(),
                    size_of::<T>(),
                    null_mut(),
                    null(),
                )
            };
            ensure!(set != 0, "the sandbox's process cannot be described");
            Ok(())
        }
    }

    impl Drop for Attributes {
        fn drop(&mut self) {
            // SAFETY: the list was initialized by `new`.
            unsafe { DeleteProcThreadAttributeList(self.list()) };
        }
    }

    pub fn run(
        folder: &Path,
        command: &str,
        time: Duration,
        stopped: &AtomicBool,
        reach: Reach,
    ) -> anyhow::Result<Ran> {
        let sid = container(folder)?;
        let_in(folder, sid.0, FILE_ALL_ACCESS)?;
        let reached = match reach.programs {
            true => {
                let capability = Capability::programs()?;
                let found = programs(&capability, &reach.data);
                Some((own_folder(&sid)?, found, capability))
            }
            false => None,
        };
        let internet = match reach.network {
            true => Some(Capability::of(INTERNET)?),
            false => None,
        };
        let mut granted: Vec<SID_AND_ATTRIBUTES> = internet
            .iter()
            .chain(reached.as_ref().map(|(_, _, capability)| capability))
            .map(|capability| SID_AND_ATTRIBUTES {
                Sid: capability.0,
                Attributes: ENABLED,
            })
            .collect();
        let (reader, writer) = std::io::pipe().context("no pipe for the command's output")?;
        let writer = OwnedHandle::from(writer);
        let out = writer.as_raw_handle() as HANDLE;
        // SAFETY: the handle is the pipe's, which lives until the process is made.
        let inherit =
            unsafe { SetHandleInformation(out, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT) };
        ensure!(inherit != 0, "the command's output cannot be handed over");
        let environment = environment(
            reached
                .as_ref()
                .map(|(own, found, _)| (own.as_str(), found)),
        );
        let (child, thread) = spawn(folder, command, (sid.0, &mut granted), &environment, out)?;
        // The process holds its own copy; with ours closed the output ends when its do.
        drop(writer);
        let job = job(&child);
        // SAFETY: the thread is the new process's, held suspended until it is in its job.
        unsafe {
            if job.is_err() {
                TerminateProcess(child.as_raw_handle() as HANDLE, 1);
            } else {
                ResumeThread(thread.as_raw_handle() as HANDLE);
            }
        }
        Ok(wait(&child, &job?, reader, time, stopped))
    }

    /// Makes the process of `command` in `folder`, suspended, in the container
    /// whose SID is `container`'s first with the capabilities its second
    /// grants, its output and errors going to `out`: its process and its
    /// thread, ours to close.
    fn spawn(
        folder: &Path,
        command: &str,
        (sid, granted): (PSID, &mut [SID_AND_ATTRIBUTES]),
        environment: &[u16],
        out: HANDLE,
    ) -> anyhow::Result<(OwnedHandle, OwnedHandle)> {
        let mut attributes = Attributes::new(2)?;
        let capabilities = SECURITY_CAPABILITIES {
            AppContainerSid: sid,
            Capabilities: match granted.is_empty() {
                true => null_mut(),
                false => granted.as_mut_ptr(),
            },
            CapabilityCount: granted.len() as u32,
            Reserved: 0,
        };
        // Only the output's handle goes to the process, not the server's others.
        let handles = [out];
        // SAFETY: both values live until the process is made.
        unsafe {
            attributes.set(PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES, &capabilities)?;
            attributes.set(PROC_THREAD_ATTRIBUTE_HANDLE_LIST, &handles)?;
        }
        let mut startup: STARTUPINFOEXW = unsafe { std::mem::zeroed() };
        startup.StartupInfo.cb = size_of::<STARTUPINFOEXW>() as u32;
        startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
        startup.StartupInfo.hStdOutput = out;
        startup.StartupInfo.hStdError = out;
        startup.lpAttributeList = attributes.list();

        let root = std::env::var("SystemRoot").unwrap_or_else(|_| r"C:\Windows".into());
        let program = wide(format!(r"{root}\System32\cmd.exe"));
        let mut line = wide(format!("cmd.exe /d /s /c \"{command}\""));
        let directory = wide(folder);
        let mut process: PROCESS_INFORMATION = unsafe { std::mem::zeroed() };
        // SAFETY: every string ends in zero and lives through the call; the
        // command line is a buffer of its own, as the call may write to it.
        let made = unsafe {
            CreateProcessW(
                program.as_ptr(),
                line.as_mut_ptr(),
                null(),
                null(),
                1,
                CREATE_SUSPENDED
                    | CREATE_NO_WINDOW
                    | CREATE_UNICODE_ENVIRONMENT
                    | EXTENDED_STARTUPINFO_PRESENT,
                environment.as_ptr().cast(),
                directory.as_ptr(),
                &startup.StartupInfo,
                &mut process,
            )
        };
        if made == 0 {
            bail!(
                "the command cannot be started: {}",
                std::io::Error::last_os_error()
            );
        }
        // SAFETY: the handles are the new process's, ours to close.
        Ok(unsafe {
            (
                OwnedHandle::from_raw_handle(process.hProcess),
                OwnedHandle::from_raw_handle(process.hThread),
            )
        })
    }

    /// Waits for the command's process `child` for at most `time` and until
    /// `stopped` is set, ends its `job` with all it left running, and reads
    /// its output from `reader`.
    fn wait(
        child: &OwnedHandle,
        job: &OwnedHandle,
        mut reader: PipeReader,
        time: Duration,
        stopped: &AtomicBool,
    ) -> Ran {
        // The output comes in pieces, read on a thread of its own. Another
        // program the server starts meanwhile may hold the pipe open, so its
        // end is waited for only a moment once the command's processes are gone.
        let (pieces, read) = mpsc::channel();
        std::thread::spawn(move || {
            let mut piece = [0u8; 8192];
            while let Ok(count) = reader.read(&mut piece) {
                if count == 0 || pieces.send(piece[..count].to_vec()).is_err() {
                    break;
                }
            }
        });
        let until = Instant::now() + time;
        // SAFETY: the handles are the process's and its job's, alive here.
        let code = unsafe {
            let process = child.as_raw_handle() as HANDLE;
            let mut waited = WAIT_TIMEOUT;
            while waited == WAIT_TIMEOUT
                && Instant::now() < until
                && !stopped.load(Ordering::Relaxed)
            {
                waited = WaitForSingleObject(process, LOOK);
            }
            let mut code = 0;
            let ended = waited != WAIT_TIMEOUT && GetExitCodeProcess(process, &mut code) != 0;
            // What the command left running ends with it, and its output with them.
            TerminateJobObject(job.as_raw_handle() as HANDLE, 1);
            ended.then_some(code)
        };
        let last = Instant::now() + LAST_OUTPUT;
        let mut output = Vec::new();
        while let Ok(piece) = read.recv_timeout(last.saturating_duration_since(Instant::now())) {
            let room = OUTPUT_LIMIT - output.len();
            output.extend_from_slice(&piece[..piece.len().min(room)]);
        }
        Ran {
            output: String::from_utf8_lossy(&output).into_owned(),
            code,
        }
    }

    /// A job that holds the process and all it starts, ends them when it is
    /// closed, and keeps them to `MEMORY_LIMIT`.
    fn job(child: &OwnedHandle) -> anyhow::Result<OwnedHandle> {
        // SAFETY: the calls are given a handle they made or the child's, and a
        // limit of their own type.
        unsafe {
            let handle = CreateJobObjectW(null(), null());
            ensure!(!handle.is_null(), "no job object for the command");
            let job = OwnedHandle::from_raw_handle(handle);
            let mut limit: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
            limit.BasicLimitInformation.LimitFlags =
                JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_JOB_MEMORY;
            limit.JobMemoryLimit = MEMORY_LIMIT;
            let set = SetInformationJobObject(
                job.as_raw_handle() as HANDLE,
                JobObjectExtendedLimitInformation,
                (&raw const limit).cast(),
                size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            );
            ensure!(set != 0, "the command's job object cannot be set");
            ensure!(
                AssignProcessToJobObject(
                    job.as_raw_handle() as HANDLE,
                    child.as_raw_handle() as HANDLE
                ) != 0,
                "the command cannot be put in its job object"
            );
            Ok(job)
        }
    }
}

#[cfg(all(test, windows))]
mod tests {
    use crate::tools::sandbox::windows::{copied_for_test as copied, resolve};
    use std::cell::Cell;
    use std::collections::BTreeMap;
    use std::path::{Path, PathBuf};

    /// A `PATH` folder found empty is not remembered: it is looked at again, so
    /// a program installed into it while the server runs is found without a
    /// restart; a folder found with programs is remembered and not looked at anew.
    #[test]
    fn a_path_folder_found_empty_is_not_remembered() {
        let data = Path::new(r"C:\data");
        let mut known = BTreeMap::new();
        let empty = PathBuf::from(r"C:\empty");
        let full = PathBuf::from(r"C:\full");
        let has_tool = Cell::new(false);
        let full_looks = Cell::new(0);
        let mut look = |folder: &Path| -> Option<(PathBuf, Vec<(String, String)>)> {
            if folder == full {
                full_looks.set(full_looks.get() + 1);
                return Some((folder.to_path_buf(), Vec::new()));
            }
            (folder == empty && has_tool.get()).then(|| (folder.to_path_buf(), Vec::new()))
        };
        let folders = || [empty.clone(), full.clone()].into_iter();

        // The empty folder holds no programs: not in the PATH, and not remembered.
        let (path, _) = resolve(folders(), data, &mut known, &mut look);
        assert_eq!(path, full.display().to_string());

        // A program installed into it is found at once, without a restart.
        has_tool.set(true);
        let (path, _) = resolve(folders(), data, &mut known, &mut look);
        assert_eq!(path, format!("{};{}", empty.display(), full.display()));

        // The full folder was looked at once only: it was remembered.
        assert_eq!(full_looks.get(), 1);
    }

    /// A program updated inside a subfolder of its folder is copied anew,
    /// though the folder's own files are as they were.
    #[test]
    fn a_folder_of_programs_is_copied_anew_when_its_tree_changes() {
        let folder = std::env::temp_dir().join(format!("cardwave-copy-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(folder.join("lib")).unwrap();
        std::fs::write(folder.join("tool.exe"), "").unwrap();
        std::fs::write(folder.join("lib/part.js"), "one").unwrap();
        let copy = copied(&folder).unwrap();
        std::fs::write(folder.join("lib/part.js"), "one, two").unwrap();
        assert_eq!(copied(&folder).unwrap(), copy);
        let part = std::fs::read_to_string(copy.join("lib/part.js")).unwrap();
        let _ = std::fs::remove_dir_all(&folder);
        let _ = std::fs::remove_dir_all(&copy);
        assert_eq!(part, "one, two");
    }
}

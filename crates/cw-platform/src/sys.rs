//! The one wrapper of `windows-sys`, `libc` and `trash` for the server
//! (global layer rule; `tools/check.sh` holds it, the tools' sandbox
//! crate cw-sandbox apart): a process ended with the server's (on Windows
//! the job object [`Job`], on Linux [`end_with_this`]'s parent-death signal),
//! the flag that keeps its console window shut ([`NO_WINDOW`]), this
//! computer's memory ([`memory`]), whether Vulkan's loader is there
//! ([`has_vulkan`]; on Windows the server's programs load it at its first
//! call, the `/DELAYLOAD` of `.cargo/config.toml`), and a file moved to the
//! Recycle Bin or freedesktop.org's Trash ([`recycle`]).
//! Trap: Linux sends the parent-death signal when the *thread* that started
//! the process ends, so a process is started from a thread that lives as long
//! as it is wanted (a tokio runtime's worker, never `spawn_blocking`'s).

#[cfg(target_os = "linux")]
pub use linux::end_with_this;
#[cfg(windows)]
pub use windows::{Job, NO_WINDOW};

/// This computer's memory in bytes, where it can be told.
pub fn memory() -> Option<u64> {
    #[cfg(windows)]
    {
        windows::memory()
    }
    #[cfg(not(windows))]
    {
        let info = std::fs::read_to_string("/proc/meminfo").ok()?;
        let line = info.lines().find(|line| line.starts_with("MemTotal:"))?;
        let kb: u64 = line.split_whitespace().nth(1)?.parse().ok()?;
        Some(kb * 1024)
    }
}

/// Whether this computer has Vulkan's loader, which a graphics card's driver
/// installs: without it, the first call of whisper.cpp's Vulkan would end the
/// process. Elsewhere the program does not start without it.
pub fn has_vulkan() -> bool {
    #[cfg(windows)]
    {
        windows::has_vulkan()
    }
    #[cfg(target_os = "linux")]
    {
        linux::has_vulkan()
    }
}

/// Moves the file at `path` to the Recycle Bin (Windows) or the Trash
/// (freedesktop.org's, Linux). On a drive without one, Windows asks before it
/// deletes the file for good.
pub fn recycle(path: &std::path::Path) -> anyhow::Result<()> {
    #[cfg(windows)]
    {
        windows::recycle(path)
    }
    #[cfg(target_os = "linux")]
    {
        linux::recycle(path)
    }
}

#[cfg(windows)]
mod windows {
    use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};

    use anyhow::{Context, ensure};
    use windows_sys::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectExtendedLimitInformation,
        SetInformationJobObject,
    };

    /// `CREATE_NO_WINDOW`: the process opens no console window.
    pub const NO_WINDOW: u32 = 0x0800_0000;

    /// A job whose processes are ended when its last handle closes: when this
    /// is dropped, or when the server's process ends, however it ends.
    pub struct Job(OwnedHandle);

    impl Job {
        pub fn holding(child: &tokio::process::Child) -> anyhow::Result<Self> {
            let process = child.raw_handle().context(cw_core::Fail::said(
                cw_core::Code::Internal,
                "the process has ended",
            ))?;
            // SAFETY: the calls are given a handle they made or the child's,
            // which lives while `child` does, and a limit of their own type.
            unsafe {
                let handle = CreateJobObjectW(std::ptr::null(), std::ptr::null());
                ensure!(
                    !handle.is_null(),
                    cw_core::Fail::said(cw_core::Code::Internal, "no job object for the process")
                );
                let job = Self(OwnedHandle::from_raw_handle(handle));
                let mut limit: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
                limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
                let set = SetInformationJobObject(
                    job.0.as_raw_handle(),
                    JobObjectExtendedLimitInformation,
                    (&raw const limit).cast(),
                    size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
                );
                ensure!(
                    set != 0,
                    cw_core::Fail::said(cw_core::Code::Internal, "the job object cannot be set")
                );
                ensure!(
                    AssignProcessToJobObject(job.0.as_raw_handle(), process) != 0,
                    cw_core::Fail::said(
                        cw_core::Code::Internal,
                        "the process cannot be put in its job object"
                    )
                );
                Ok(job)
            }
        }
    }

    pub fn has_vulkan() -> bool {
        use windows_sys::Win32::System::LibraryLoader::LoadLibraryW;
        let name: Vec<u16> = "vulkan-1.dll".encode_utf16().chain([0]).collect();
        // SAFETY: a NUL-ended name. The module stays loaded, for the delayed
        // import to use next.
        !unsafe { LoadLibraryW(name.as_ptr()) }.is_null()
    }

    pub fn memory() -> Option<u64> {
        use windows_sys::Win32::System::SystemInformation::{GlobalMemoryStatusEx, MEMORYSTATUSEX};
        // SAFETY: a plain struct of numbers, all zero being a valid value.
        let mut status: MEMORYSTATUSEX = unsafe { std::mem::zeroed() };
        status.dwLength = u32::try_from(size_of::<MEMORYSTATUSEX>()).ok()?;
        // SAFETY: `status` is a valid MEMORYSTATUSEX with its length set.
        let told = unsafe { GlobalMemoryStatusEx(&mut status) } != 0;
        told.then_some(status.ullTotalPhys)
    }

    pub fn recycle(path: &std::path::Path) -> anyhow::Result<()> {
        use std::os::windows::ffi::OsStrExt;
        use windows_sys::Win32::UI::Shell::{
            FO_DELETE, FOF_ALLOWUNDO, FOF_NOCONFIRMATION, FOF_NOERRORUI, FOF_SILENT,
            FOF_WANTNUKEWARNING, SHFILEOPSTRUCTW, SHFileOperationW,
        };
        // The shell takes a full path alone.
        let path = std::path::absolute(path)?;
        // A list of paths, each NUL-ended, the list ended by another NUL.
        let from: Vec<u16> = path.as_os_str().encode_wide().chain([0, 0]).collect();
        let flags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT;
        let mut operation = SHFILEOPSTRUCTW {
            wFunc: FO_DELETE,
            pFrom: from.as_ptr(),
            // The flags fit the field's 16 bits.
            fFlags: (flags | FOF_WANTNUKEWARNING) as u16,
            ..Default::default()
        };
        // SAFETY: a doubly NUL-ended list of one path, which lives through the call.
        let failure = unsafe { SHFileOperationW(&mut operation) };
        ensure!(
            failure == 0 && operation.fAnyOperationsAborted == 0,
            cw_core::Fail::said(
                cw_core::Code::NotPossible,
                format!(
                    "{} was not moved to the Recycle Bin (error {failure})",
                    path.display()
                )
            )
            .with("what", "recycle_bin_move")
            .with("path", (path.display()).to_string())
            .with("failure", failure.to_string())
        );
        Ok(())
    }
}

#[cfg(target_os = "linux")]
mod linux {
    use std::ffi::CStr;

    /// Makes the process `command` starts end when this one ends, however it
    /// ends: the kernel sends it SIGKILL when the thread starting it ends
    /// (the module's trap). A process started after this one ended is ended
    /// at once.
    pub fn end_with_this(command: &mut tokio::process::Command) {
        // SAFETY: `getpid` cannot fail.
        let parent = unsafe { libc::getpid() };
        // SAFETY: the closure runs in the child between fork and exec and
        // calls only `prctl` and `getppid`, both safe to call there; it
        // allocates nothing.
        unsafe {
            command.pre_exec(move || {
                if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL) != 0 {
                    return Err(std::io::Error::last_os_error());
                }
                if libc::getppid() != parent {
                    return Err(std::io::Error::from_raw_os_error(libc::ESRCH));
                }
                Ok(())
            });
        }
    }

    pub fn has_vulkan() -> bool {
        const NAME: &CStr = c"libvulkan.so.1";
        // SAFETY: a NUL-ended name. The library stays loaded, as the
        // programs that use it load it anyway.
        !unsafe { libc::dlopen(NAME.as_ptr(), libc::RTLD_NOW | libc::RTLD_LOCAL) }.is_null()
    }

    pub fn recycle(path: &std::path::Path) -> anyhow::Result<()> {
        trash::delete(path).map_err(|failure| {
            anyhow::anyhow!(
                cw_core::Fail::said(
                    cw_core::Code::NotPossible,
                    format!("{} was not moved to the Trash ({failure})", path.display())
                )
                .with("what", "trash_move")
                .with("path", (path.display()).to_string())
                .with("failure", failure.to_string())
            )
        })
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    //! Each test that needs a process of its own (the parent that ends, a
    //! Trash of its own by `XDG_DATA_HOME`) runs this test program again for
    //! itself alone, with `CW_PLATFORM_ROLE` set.
    use std::path::Path;
    use std::process::Command;

    const ROLE: &str = "CW_PLATFORM_ROLE";

    /// Runs the test `name` of this module in a new process with `env`; its output.
    fn again(name: &str, env: &[(&str, &Path)]) -> String {
        let mut command = Command::new(std::env::current_exe().unwrap());
        command.args(["--exact", &format!("sys::tests::{name}"), "--nocapture"]);
        command.env(ROLE, name).envs(env.iter().copied());
        let out = command.output().unwrap();
        let text = String::from_utf8_lossy(&out.stdout).into_owned();
        assert!(
            out.status.success(),
            "{text}{}",
            String::from_utf8_lossy(&out.stderr)
        );
        text
    }

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("cw-platform-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir); // none there is as good
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn a_process_ends_with_the_one_that_started_it() {
        if std::env::var_os(ROLE).is_some() {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            let child = runtime.block_on(async {
                let mut command = tokio::process::Command::new("sleep");
                command.arg("600");
                super::end_with_this(&mut command);
                command.spawn().unwrap()
            });
            println!("child {}", child.id().unwrap());
            std::process::exit(0);
        }
        let out = again("a_process_ends_with_the_one_that_started_it", &[]);
        let pid: u32 = out
            .lines()
            .find_map(|line| line.strip_prefix("child "))
            .unwrap()
            .parse()
            .unwrap();
        let stat = format!("/proc/{pid}/stat");
        let ended = (0..100).any(|_| {
            // Gone, or a zombie its new parent has not yet taken.
            let gone = std::fs::read_to_string(&stat).map_or(true, |s| s.contains(") Z "));
            if !gone {
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
            gone
        });
        if !ended {
            let _ = Command::new("kill").arg(pid.to_string()).status(); // the test fails anyway
        }
        assert!(ended, "sleep {pid} lives on");
    }

    #[test]
    fn has_vulkan_answers_by_the_loader() {
        let loader = ["/usr/lib/x86_64-linux-gnu", "/usr/lib64", "/usr/lib"]
            .iter()
            .any(|dir| Path::new(dir).join("libvulkan.so.1").exists());
        // One way only: the loader may also be found elsewhere (LD_LIBRARY_PATH, the Vulkan SDK).
        assert!(!loader || super::has_vulkan());
    }

    #[test]
    fn a_file_goes_to_the_trash() {
        if let Some(data) =
            std::env::var_os("XDG_DATA_HOME").filter(|_| std::env::var_os(ROLE).is_some())
        {
            let file = Path::new(&data).with_file_name("card.png");
            std::fs::write(&file, b"png").unwrap();
            super::recycle(&file).unwrap();
            assert!(!file.exists());
            return;
        }
        let dir = scratch("trash");
        let data = dir.join("data");
        again("a_file_goes_to_the_trash", &[("XDG_DATA_HOME", &data)]);
        let kept = data.join("Trash/files/card.png");
        assert_eq!(std::fs::read(&kept).unwrap(), b"png");
        assert!(data.join("Trash/info/card.png.trashinfo").exists());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}

//! The one wrapper of `windows-sys` for the server (global layer rule;
//! `tools/check.sh` holds it, the tools' sandbox `tools/sandbox.rs` apart):
//! the job object that ends `llama-server` with the server ([`Job`]), the
//! flag that keeps its console window shut ([`NO_WINDOW`]), and this
//! computer's memory ([`memory`]), read elsewhere from `/proc/meminfo`, and
//! whether Vulkan's loader is there ([`has_vulkan`]), which the server's
//! programs load at its first call (the `/DELAYLOAD` of `.cargo/config.toml`),
//! and a file moved to the Recycle Bin ([`recycle`]), Windows' alone.

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
    #[cfg(not(windows))]
    {
        true
    }
}

/// Whether files can be moved to the Recycle Bin here ([`recycle`]).
pub const RECYCLE_BIN: bool = cfg!(windows);

/// Moves the file at `path` to the Recycle Bin. On a drive
/// without one, Windows asks before it deletes the file for good.
pub fn recycle(path: &std::path::Path) -> anyhow::Result<()> {
    #[cfg(windows)]
    {
        windows::recycle(path)
    }
    #[cfg(not(windows))]
    {
        anyhow::bail!(
            cw_core::Fail::said(
                cw_core::Code::NotPossible,
                format!("there is no Recycle Bin for {}", path.display())
            )
            .with("what", "no_recycle_bin")
            .with("path", (path.display()).to_string())
        )
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

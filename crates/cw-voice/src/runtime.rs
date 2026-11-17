//! ONNX Runtime 1.28.0, the one the crate `ort` 2.0.0-rc.13 is made for, as Microsoft's Python package for the
//! system holds it (MIT): its URL, size and SHA-256, where the library is in the package, and where it is kept.
//! One module per system (Windows and Linux on x86-64); on any other the build fails.

#[cfg(all(windows, target_arch = "x86_64"))]
mod system {
    pub(crate) const RUNTIME: (&str, u64, &str) = (
        "https://files.pythonhosted.org/packages/56/f1/51225c202edba4dfc94e1ea03f3d78f1aaf307da75fd792c0ce1946b2514/onnxruntime-1.28.0-cp313-cp313-win_amd64.whl",
        13_755_033,
        "1a1a19175464665c9b8d50bc916f216cc0b569110045b7bbca8f9f290b186f58",
    );
    pub(crate) const RUNTIME_IN_PACKAGE: &str = "onnxruntime/capi/onnxruntime.dll";
    pub(crate) const RUNTIME_FILE: &str = "onnxruntime.dll";
}

/// Linux on x86-64 (glibc 2.27 on, as the package's manylinux tag says).
#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
mod system {
    pub(crate) const RUNTIME: (&str, u64, &str) = (
        "https://files.pythonhosted.org/packages/78/b6/8c5396e7894e77c5a7d1e026f3acb9dd39c4b5644e412e37a0055eaa3bc5/onnxruntime-1.28.0-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl",
        19_214_329,
        "54fa221d669282bd8f582708ce4c96010a7e9fb0661f9006b37fe2fedafb73fe",
    );
    pub(crate) const RUNTIME_IN_PACKAGE: &str = "onnxruntime/capi/libonnxruntime.so.1.28.0";
    pub(crate) const RUNTIME_FILE: &str = "libonnxruntime.so";
}

#[cfg(not(any(
    all(windows, target_arch = "x86_64"),
    all(target_os = "linux", target_arch = "x86_64")
)))]
compile_error!("reading aloud has ONNX Runtime only for Windows and Linux on x86-64");

pub(crate) use system::{RUNTIME, RUNTIME_FILE, RUNTIME_IN_PACKAGE};

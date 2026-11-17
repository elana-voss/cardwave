//! whisper.cpp's binding alone (`whisper`, the one wrapper of whisper-rs), so
//! its native build with Vulkan is not redone when the server changes. It asks
//! cw-platform's `sys` whether Vulkan is there.
//!
//! Trap: whisper.cpp's release `whisper-bin-x64.zip` runs on the CPU only ("no GPU found"); the GPU build is
//! `whisper-bin-win-cuda-<version>-x64.zip`. Building it fetches ninja.exe, which the virus scanner blocks.

pub mod whisper;

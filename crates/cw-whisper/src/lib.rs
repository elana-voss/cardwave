//! whisper.cpp's binding alone (`whisper`, the one wrapper of whisper-rs), so
//! its native build with Vulkan is not redone when the server changes. It asks
//! cw-platform's `sys` whether Vulkan is there.

pub mod whisper;

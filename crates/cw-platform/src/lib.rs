//! The platform under the services, above the core: this computer's facts and
//! its job object (`sys`, the one wrapper of windows-sys), the HTTP client
//! (`http`, the one of reqwest) and the log files (`logs`). Which crate may
//! name which library is the check `crates` (tools/deps.py, WRAPS).

pub mod http;
pub mod logs;
pub mod sys;

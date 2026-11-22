//! The platform under the services, above the core: this computer's facts and
//! its job object (`sys`, the one wrapper of windows-sys), the HTTP client
//! (`http`, the one of reqwest), the log files (`logs`) and its addresses in
//! the networks it reaches (`net`), gzip undone (`packed`, the one of
//! flate2). Which crate may name which library is the check `crates`
//! (tools/deps.py, WRAPS).

pub mod http;
pub mod logs;
pub mod net;
pub mod packed;
pub mod sys;

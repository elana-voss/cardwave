//! The clock: [`now_ms`], the time as the app stores it.

/// The current time as the app stores it: milliseconds since 1970, UTC.
pub fn now_ms() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

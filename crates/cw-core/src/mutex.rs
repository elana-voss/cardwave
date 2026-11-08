//! Taking a mutex: every mutex of the app is taken with [`lock`].

use std::sync::{Mutex, MutexGuard};

/// Locks `mutex`, going on with what it guards where a thread panicked while
/// holding it, so one failed request does not stop the app.
pub fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|e| e.into_inner())
}

//! A failure the library tells outside a request's answer (a folder's file not imported, a card's describing
//! failed and kept): the store says which failures are its own (`Failures`, the database failing), and those
//! are told as `internal`, the server's fault, never with their words; every other is `cw_core::told`'s.

use cw_core::{Code, ErrorBody, Fail};

/// What the store tells of a failure: whether it failed in it.
pub trait Failures {
    /// Whether the store failed somewhere in `error`.
    fn failed_in(&self, error: &anyhow::Error) -> bool;
}

/// `error` as the UI is told it, `fallback` where it carries no code; one the store failed in is `internal`.
pub fn told(store: &dyn Failures, error: &anyhow::Error, fallback: Code) -> ErrorBody {
    if store.failed_in(error) {
        tracing::error!("failed: {error:#}");
        return Fail::new(Code::Internal).into();
    }
    cw_core::told(error, fallback)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Failing;

    impl Failures for Failing {
        fn failed_in(&self, _: &anyhow::Error) -> bool {
            true
        }
    }

    #[test]
    fn a_failure_of_the_store_is_told_as_internal_without_its_words() {
        let body = told(
            &Failing,
            &anyhow::anyhow!("disk I/O error"),
            Code::FileNotImported,
        );
        assert_eq!(
            (body.code, body.error.as_str()),
            (Code::Internal, "the server failed to handle the request")
        );
    }
}

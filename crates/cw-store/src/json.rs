//! A value kept as JSON in a text column: `to` writes it, `of` reads it back; the one way this crate reads one.
//! A column that does not parse is an error, never a silent default (greenfield: an older form is dropped by its
//! schema step, not read). Trap: `or_none` is for a column read only to be shown (a reply's parts, a card's line
//! in a list), where the screen opens all the same and the log says why the part is missing.

use rusqlite::types::Type;
use serde::Serialize;
use serde::de::DeserializeOwned;

/// `value` as its column keeps it.
pub(crate) fn to(value: &impl Serialize) -> rusqlite::Result<String> {
    serde_json::to_string(value).map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))
}

/// What column `at` of a row, kept by `to`, holds.
pub(crate) fn of<T: DeserializeOwned>(column: &str, at: usize) -> rusqlite::Result<T> {
    serde_json::from_str(column).map_err(|e| unreadable(at, e))
}

/// What a column read only to be shown holds, where it holds any: one that does not parse is logged as
/// `what` (such as "a reply's attachments") and taken as none.
pub(crate) fn or_none<T: DeserializeOwned>(column: Option<&str>, what: &str) -> Option<T> {
    serde_json::from_str(column?)
        .inspect_err(|error| tracing::warn!("{what} cannot be read: {error}"))
        .ok()
}

/// The error of column `at`, a text, that does not hold what it should.
pub(crate) fn unreadable(
    at: usize,
    error: impl Into<Box<dyn std::error::Error + Send + Sync>>,
) -> rusqlite::Error {
    rusqlite::Error::FromSqlConversionFailure(at, Type::Text, error.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_column_that_does_not_parse_is_an_error() {
        assert_eq!(
            of::<Vec<String>>(&to(&vec!["a"]).unwrap(), 0).unwrap(),
            vec!["a"]
        );
        assert!(of::<Vec<String>>("", 0).is_err());
    }

    #[test]
    fn a_column_only_shown_that_does_not_parse_is_none() {
        assert_eq!(
            or_none::<Vec<String>>(Some(r#"["a"]"#), "names"),
            Some(vec!["a".to_string()])
        );
        assert_eq!(or_none::<Vec<String>>(Some("{"), "names"), None);
        assert_eq!(or_none::<Vec<String>>(None, "names"), None);
    }
}

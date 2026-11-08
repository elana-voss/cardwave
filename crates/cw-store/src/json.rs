//! A value kept as JSON in a text column: `to` writes it, `of` reads it back. A column that does not parse is an
//! error, never a default (greenfield: an older form is dropped by its schema step, not read).

use rusqlite::types::Type;
use serde::Serialize;
use serde::de::DeserializeOwned;

/// `value` as its column keeps it.
pub(crate) fn to(value: &impl Serialize) -> rusqlite::Result<String> {
    serde_json::to_string(value).map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))
}

/// What column `at` of a row, kept by `to`, holds.
pub(crate) fn of<T: DeserializeOwned>(column: &str, at: usize) -> rusqlite::Result<T> {
    serde_json::from_str(column)
        .map_err(|e| rusqlite::Error::FromSqlConversionFailure(at, Type::Text, Box::new(e)))
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
}

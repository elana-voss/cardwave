//! A quote a model gave against the text it says it comes from: the gender read and the gender check over a
//! card (`interview::gender`). Both are compared as [`words`]; each caller cuts
//! its quote by its own rule and [`holds`] looks for the parts. [`plain`] is also how the read-back compares.
//!
//! Traps: a match must not split a word, but a script without case has no such check, as its words may run
//! together ([`wordy`]).

/// The text as words are compared: lowercase, one kind of apostrophe, one sigma (the final one depends on
/// what follows).
pub(crate) fn plain(text: &str) -> String {
    text.to_lowercase()
        .replace(['\u{2018}', '\u{2019}'], "'")
        .replace('\u{3C2}', "\u{3C3}")
}

/// Whether a plain character is part of a word that a match must not split: a cased letter or a digit.
pub(crate) fn wordy(c: char) -> bool {
    c.is_lowercase() || c.is_numeric()
}

/// [`plain`], each run of what is no letter or digit one space, none at the ends.
pub(crate) fn words(text: &str) -> String {
    let spaced: String = plain(text)
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { ' ' })
        .collect();
    spaced.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Whether `text` (as [`words`] made it) holds every part of a quote. A part without a letter or digit is
/// none, and no parts are held by nothing.
pub(crate) fn holds<'a>(text: &str, parts: impl IntoIterator<Item = &'a str>) -> bool {
    let parts: Vec<String> = parts
        .into_iter()
        .map(words)
        .filter(|part| !part.is_empty())
        .collect();
    !parts.is_empty() && parts.iter().all(|part| found(text, part))
}

/// Whether `part` stands in `text` somewhere without splitting a word.
fn found(text: &str, part: &str) -> bool {
    let (Some(first), Some(last)) = (part.chars().next(), part.chars().next_back()) else {
        return false;
    };
    let splits = |beside: Option<char>, end: char| beside.is_some_and(wordy) && wordy(end);
    let mut from = 0;
    while let Some(at) = text[from..].find(part) {
        let start = from + at;
        let before = text[..start].chars().next_back();
        let after = text[start + part.len()..].chars().next();
        if !splits(before, first) && !splits(after, last) {
            return true;
        }
        from = start + first.len_utf8();
    }
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_match_that_splits_a_word_does_not_hide_a_whole_one_after_it() {
        assert!(holds(&words("banana ana"), ["ana"]));
        assert!(holds(&words("ba a a"), ["a a"]));
        assert!(!holds(&words("banana"), ["ana"]));
    }
}

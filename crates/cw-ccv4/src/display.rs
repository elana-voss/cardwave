//! Card text as a person reads it outside a chat: on the character page and in
//! the library's list.

use std::sync::LazyLock;

use cw_prompt::Variables;
use cw_prompt::macros::{self, MacroContext};
use regex::Regex;

/// Longest excerpt, in characters.
const EXCERPT_CHARS: usize = 300;
/// How much of a text is read to make its excerpt, in bytes.
pub const EXCERPT_SOURCE: usize = 8 * 1024;

/// A text of the character named `char_name` with its macros resolved, as a
/// chat started without a persona would show it: `{{user}}` is `user_name`,
/// `{{date}}` and `{{time}}` as `language` writes them (macros' `MARKS`: marks).
pub fn render(text: &str, char_name: &str, user_name: &str, language: &str) -> String {
    let mut variables = Variables::new();
    let mut context = MacroContext {
        char_name,
        user_name,
        local: Some(&mut variables),
        global: None,
        tracking_id: None,
        language: Some(language),
        seed: None,
    };
    macros::render(text, &mut context).trim().to_string()
}

/// As much of the start of a text as an excerpt is made of. Cards hold texts
/// of any length; what is done to make an excerpt is done to this much.
pub fn head(text: &str) -> &str {
    let mut end = text.len().min(EXCERPT_SOURCE);
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    &text[..end]
}

/// The start of a text on one line, without markup: HTML tags and comments,
/// pictures, and the asterisks and backticks of Markdown. Cut at a word when
/// it is longer than a list row has room for.
pub fn excerpt(text: &str) -> String {
    // What stands for something (a tag, a picture) leaves a gap; what only
    // marks the words around it goes without one, so `*waves*,` reads `waves,`.
    static BLOCKS: LazyLock<Regex> = LazyLock::new(|| {
        // A fixed pattern, run by this file's tests: it compiles.
        Regex::new(r"(?s)<!--.*?-->|</?[A-Za-z][^>]*>|!\[[^\]]*\]\([^)]*\)").unwrap()
    });
    let plain = BLOCKS.replace_all(head(text), " ").replace(['*', '`'], "");
    let mut out = String::new();
    let mut length = 0;
    for word in plain.split_whitespace() {
        let more = word.chars().count() + usize::from(length > 0);
        if length + more > EXCERPT_CHARS {
            // A first word too long for the row is cut inside.
            if out.is_empty() {
                out.extend(word.chars().take(EXCERPT_CHARS));
            }
            out.push('…');
            return out;
        }
        if length > 0 {
            out.push(' ');
        }
        out.push_str(word);
        length += more;
    }
    out
}

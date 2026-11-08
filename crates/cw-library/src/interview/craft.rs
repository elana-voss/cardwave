//! Code's part of a written card: the craft check, each failure with its rule, and
//! what code does because the model keeps doing otherwise (`four_greetings`, `tidy`).
//! Traps: sizes are in characters, as the source's, never bytes. The regex crate has
//! no lookaround, so speech and sentences are cut by hand; no pattern is ever built
//! from a card's text.

use std::sync::LazyLock;

use regex::Regex;
use serde::Serialize;

use super::gender::{CAST_MAX, first_kind};
use super::texts;
use super::writer::Fields;

/// "about 1,000" and "about 1,500", with the old check's kind of tolerance.
const PERMANENT_MAX: f64 = 1100.0;
const CAST_PERMANENT_MAX: f64 = 1650.0;
/// "about 500" and its cast's share, with the same kind of tolerance.
const PERMANENT_MIN: f64 = 450.0;
const CAST_PERMANENT_MIN: f64 = 675.0;
/// The kind whose card alone may say "a portrait from your memories".
const LOST: &str = "Someone I lost";

/// A first message that acts, perceives, feels or speaks for the user.
static ACTS_FOR_USER: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(concat!(
        r"(?i)(\{\{user\}\}|\byou)\s+(feel|felt|see|saw|hear|heard|walk|walked|say|said|nod|nodded|smile|smiled|",
        r"look|looked|reach|reached|take|took|turn|turned|notice|noticed|decide|decided|think|thought|step|stepped)\b",
    ))
    .expect("a fixed pattern")
});
static INSTRUCTION: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?im)\b(you must|always respond|(roleplay|assistant) mode)\b|(^|[.!?]\s+)(do not\b|never\s*:)",
    )
    .expect("a fixed pattern")
});
static TAG: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<[a-zA-Z/][^<>]*>").expect("a fixed pattern"));
static NOTE_ABOUT_GENDER: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)suits anyone|ungendered|no defined gender").expect("a fixed pattern")
});
static YOU: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(^|[^\w-])(you|your|yours|yourself)([^\w-]|$)").expect("a fixed pattern")
});

/// A field that fails a check, the rule it fails, and why (no text of the card).
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct Failing {
    pub rule: &'static str,
    pub field: &'static str,
    pub why: String,
}

/// What a card has failed so far.
#[derive(Default)]
struct Found(Vec<Failing>);

impl Found {
    fn fail(&mut self, rule: &'static str, field: &'static str, why: impl Into<String>) {
        let why = why.into();
        self.0.push(Failing { rule, field, why });
    }
}

fn text_of<'a>(card: &'a Fields, field: &str) -> &'a str {
    match field {
        "name" => &card.name,
        "description" => &card.description,
        "personality" => &card.personality,
        "scenario" => &card.scenario,
        "first_mes" => &card.first_mes,
        "mes_example" => &card.mes_example,
        "creator_notes" => &card.creator_notes,
        _ => "",
    }
}

fn characters(text: &str) -> usize {
    text.chars().count()
}

fn tokens(text: &str) -> f64 {
    characters(text) as f64 / 4.0
}

/// No letter or digit in it: a colon alone is as empty as nothing.
fn is_blank(text: &str) -> bool {
    !text.chars().any(char::is_alphanumeric)
}

fn is_word(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

/// `text` without what is quoted: double quotes to the next, curly ones to their close,
/// single ones where they neither begin nor end inside a word, so an apostrophe is none,
/// also inside a quote.
fn without_speech(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let close_of = |at: usize| -> Option<usize> {
        let close = match chars[at] {
            '"' => '"',
            '\u{201c}' => '\u{201d}',
            '\'' if at == 0 || !is_word(chars[at - 1]) => '\'',
            _ => return None,
        };
        let mut end = at;
        loop {
            end += 1 + chars[end + 1..].iter().position(|&c| c == close)?;
            let ends_in_word = close == '\'' && chars.get(end + 1).is_some_and(|&c| is_word(c));
            if !ends_in_word {
                return Some(end);
            }
        }
    };
    let mut kept = String::new();
    let mut at = 0;
    while at < chars.len() {
        match close_of(at) {
            Some(end) => at = end + 1,
            None => {
                kept.push(chars[at]);
                at += 1;
            }
        }
    }
    kept
}

/// `text`'s sentences: cut after `.`, `!` or `?` and the white space that follows.
fn sentences(text: &str) -> Vec<String> {
    let mut all = Vec::new();
    let mut current = String::new();
    let mut after_stop = false;
    for c in text.chars() {
        if after_stop && c.is_whitespace() {
            if !current.is_empty() {
                all.push(std::mem::take(&mut current));
            }
            continue;
        }
        after_stop = matches!(c, '.' | '!' | '?');
        current.push(c);
    }
    if !current.is_empty() {
        all.push(current);
    }
    all
}

/// What a repair is told of a size: a target inside the band, in characters and in the
/// words a model counts best; told only a limit, it stops just outside it.
fn about(characters: usize) -> String {
    format!("about {characters} characters ({} words)", characters / 6)
}

fn check_sizes(found: &mut Found, card: &Fields, cast: usize, several: bool) {
    let length = characters(&card.description);
    if length != 0 && !(600..=if several { 2200 } else { 1100 }).contains(&length) {
        let target = about(if several { 1600 } else { 800 });
        found.fail(
            "description size",
            "description",
            format!("{length} characters; rewrite it to {target}"),
        );
    }
    if several && !(2..=CAST_MAX).contains(&cast) {
        found.fail(
            "cast size",
            "description",
            format!("{cast} people, wanted 2-4"),
        );
    }
    let mut largest = (texts::HIDDEN[0], -1.0);
    let mut smallest = (texts::HIDDEN[0], f64::MAX);
    let mut total = 0.0;
    for &field in texts::HIDDEN {
        let size = tokens(text_of(card, field));
        total += size;
        if size > largest.1 {
            largest = (field, size);
        }
        if size < smallest.1 {
            smallest = (field, size);
        }
    }
    let floor = if several {
        CAST_PERMANENT_MIN
    } else {
        PERMANENT_MIN
    };
    let any_empty = texts::HIDDEN
        .iter()
        .any(|field| is_blank(text_of(card, field)));
    if total < floor && !any_empty {
        let length = characters(text_of(card, smallest.0));
        let target = ((floor - total) * 4.0) as usize + length;
        let why = format!(
            "{} is {length} characters; lengthen it to {}",
            smallest.0,
            about(target)
        );
        found.fail("permanent size", smallest.0, why);
    }
    let top = if several {
        CAST_PERMANENT_MAX
    } else {
        PERMANENT_MAX
    };
    if total > top {
        let length = characters(text_of(card, largest.0));
        let target = (length as f64 - (total - 0.8 * top) * 4.0).max(200.0) as usize;
        let why = format!(
            "{} is {length} characters; shorten it to {}",
            largest.0,
            about(target)
        );
        found.fail("permanent size", largest.0, why);
    }
    let length = characters(&card.first_mes);
    if length > 1000 {
        found.fail(
            "first_mes size",
            "first_mes",
            format!("{length} characters; rewrite it to about 700 characters (120 words)"),
        );
    }
}

/// The texts a user reads, by field, and whether they agree on asterisks and end whole.
fn check_marks(found: &mut Found, shown: &[(&'static str, Vec<&str>)]) {
    let all: Vec<&str> = shown
        .iter()
        .flat_map(|(_, texts)| texts.iter().copied())
        .collect();
    let marked = all.iter().filter(|text| text.contains('*')).count();
    if marked > 0 && marked < all.len() {
        // The fields against what most of the texts do get rewritten.
        let wanted = marked * 2 >= all.len();
        for (field, texts) in shown {
            if texts.iter().any(|text| text.contains('*') != wanted) {
                let others = if *field == "alternate_greetings" {
                    "first_mes and the examples"
                } else {
                    "the other greetings"
                };
                let why = if wanted {
                    format!("{others} mark actions with *…*; mark them so here too")
                } else {
                    format!("{others} use no *…*; remove them here")
                };
                found.fail("one convention", field, why);
            }
        }
    }
}

/// Code's check on a written card; `kinds` and `cast` give the exceptions; `several`:
/// the card was asked to be a cast, so no people at all fails too.
pub fn craft_check(card: &Fields, kinds: &[String], cast: usize, several: bool) -> Vec<Failing> {
    let mut found = Found::default();
    let several = several || cast > 0;
    let game = first_kind(kinds) == texts::FRAMEWORK;
    for &field in texts::FIELDS {
        if !matches!(field, "creator_notes" | "alternate_greetings")
            && is_blank(text_of(card, field))
        {
            found.fail("empty", field, "empty");
        }
    }
    check_sizes(&mut found, card, cast, several);
    if ACTS_FOR_USER.is_match(&without_speech(&card.first_mes)) {
        found.fail("acts for user", "first_mes", "acts or speaks for {{user}}");
    }
    let exchanges = card.mes_example.matches("<START>").count();
    if !(3..=5).contains(&exchanges) {
        found.fail(
            "examples",
            "mes_example",
            format!("{exchanges} <START> exchanges, wanted 3-5"),
        );
    }
    let greetings = card.alternate_greetings.len();
    if greetings > 4 || (greetings != 4 && !game) {
        let wanted = if game { "0 to 4" } else { "exactly 4" };
        found.fail(
            "greetings",
            "alternate_greetings",
            format!("{greetings} greetings, wanted {wanted}"),
        );
    }
    for &field in texts::HIDDEN {
        let text = text_of(card, field);
        if text.contains('*') {
            found.fail("hidden markup", field, "asterisks in a field nobody sees");
        }
        if YOU.is_match(&without_speech(text)) {
            found.fail(
                "second person",
                field,
                "you outside quoted speech, where {{user}} belongs",
            );
        }
        if INSTRUCTION.is_match(text) {
            found.fail("instruction", field, "an instruction to the model");
        }
    }
    let names_the_user = texts::HIDDEN
        .iter()
        .any(|field| text_of(card, field).to_lowercase().contains("{{user}}"));
    if !game && !names_the_user {
        found.fail(
            "user unnamed",
            "personality",
            "{{user}} never appears; the user is written by a name or pronoun; write {{user}}",
        );
    }
    let greeting_texts = card
        .alternate_greetings
        .iter()
        .map(String::as_str)
        .collect();
    let shown = [
        ("first_mes", vec![card.first_mes.as_str()]),
        ("mes_example", vec![card.mes_example.as_str()]),
        ("alternate_greetings", greeting_texts),
    ];
    check_marks(&mut found, &shown);
    for (field, texts) in &shown {
        if texts.iter().any(|text| {
            TAG.find_iter(text)
                .any(|tag| *field != "mes_example" || tag.as_str() != "<START>")
        }) {
            found.fail("stray tag", field, "a tag that is no part of the text");
        }
        if texts.iter().any(|text| {
            text.trim()
                .chars()
                .last()
                .is_some_and(char::is_alphanumeric)
        }) {
            found.fail("cut off", field, "a text that stops mid-sentence");
        }
    }
    if !several
        && card
            .mes_example
            .split("<START>")
            .skip(1)
            .any(|part| !part.contains("{{char}}:"))
    {
        found.fail(
            "example speaker",
            "mes_example",
            "an exchange without a line beginning {{char}}:",
        );
    }
    found.0
}

/// A fifth greeting is the one the limit cut off, so code drops it.
pub fn four_greetings(mut card: Fields) -> Fields {
    card.alternate_greetings.truncate(4);
    card
}

/// `text` without a leading `<START>` line and a speaker's name before it begins.
fn without_heading(text: &str, name: &str) -> String {
    let text = text.trim_start();
    let text = text.strip_prefix("<START>").map_or(text, str::trim_start);
    let by_name = format!("{name}:");
    let text = text
        .strip_prefix("{{char}}:")
        .or_else(|| {
            (!name.is_empty())
                .then(|| text.strip_prefix(&by_name))
                .flatten()
        })
        .unwrap_or(text);
    text.trim_start().to_string()
}

/// What the model keeps doing against its prompt, done by code: the lost person's line
/// on other cards, a note that the card suits anyone, an example spoken by the card's
/// name instead of `{{char}}` (a cast's are spoken by name), a greeting headed like an
/// example.
pub fn tidy(mut card: Fields, kinds: &[String], several: bool) -> Fields {
    card.first_mes = without_heading(&card.first_mes, &card.name);
    for greeting in &mut card.alternate_greetings {
        *greeting = without_heading(greeting, &card.name);
    }
    let lost = kinds.iter().any(|kind| kind == LOST);
    let notes: Vec<String> = sentences(&card.creator_notes)
        .into_iter()
        .filter(|sentence| !NOTE_ABOUT_GENDER.is_match(sentence))
        .filter(|sentence| {
            lost || !sentence
                .to_lowercase()
                .contains("portrait from your memories")
        })
        .collect();
    card.creator_notes = notes.join(" ");
    if !several && !card.name.is_empty() {
        let spoken_by_name = format!("{}:", card.name);
        card.mes_example = card
            .mes_example
            .split_inclusive('\n')
            .map(|line| match line.strip_prefix(&spoken_by_name) {
                Some(rest) => format!("{{{{char}}}}:{rest}"),
                None => line.to_string(),
            })
            .collect();
    }
    card
}

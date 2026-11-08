//! The two gender questions, last in every style (milestone 115): one call reads what the answers already
//! state ([`read_gender`], kept in `Interview::read`, cleared by a changed answer), each question is asked only
//! where that leaves it open, and [`settle`] turns the read and the two answers into the [`Choices`] the read-back
//! and the writer use. `settle` is pure and draws from `Interview::seed`, so the same state gives the same choices
//! and only the read and the seed are stored; the seed never goes to a model.
//! Trap: the two slots stay outside the limit ([`guard_count`]) and outside the text the read goes over, and a kept
//! answer whose question is no longer open or offers other choices is dropped ([`drop_stale`]).

use std::collections::hash_map::RandomState;
use std::hash::{BuildHasher, Hasher};
use std::sync::LazyLock;
use std::time::{SystemTime, UNIX_EPOCH};

pub use cw_ccv4::creation::Draw;
use cw_provider::form::{self, Question};
use regex::Regex;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use ts_rs::TS;

use super::readback::JOINTS;
use super::{Asking, Entry, Interview, Models, free_question, texts};
use crate::quotes;

pub(crate) const CAST_MAX: usize = 4;

/// What the answers plainly state: `character` a value of [`texts::CHARACTER_VALUE`] or "unknown", `treat`
/// "man", "woman" or "unknown", `words` the user's words that state it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct GenderRead {
    pub character: String,
    pub treat: String,
    pub words: String,
}

impl GenderRead {
    fn unknown() -> Self {
        GenderRead {
            character: "unknown".to_string(),
            treat: "unknown".to_string(),
            words: String::new(),
        }
    }
}

/// What the interview settled of gender. `character_gender` is a value of [`texts::CHARACTER_VALUE`], "as told"
/// (a free line code could not read) or "they" (the character is the user, anyone).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Choices {
    pub character_gender: String,
    pub treat_user: String,
    pub character_words: String,
    pub cast_genders: Vec<String>,
    pub draw: Option<Draw>,
    pub cast_draw: Option<Draw>,
}

/// The first kind decides, with two.
pub(crate) fn first_kind(kinds: &[String]) -> &str {
    kinds.first().map(String::as_str).unwrap_or_default()
}

/// The answers to the character question.
pub(crate) fn offered(kinds: &[String]) -> Vec<&'static str> {
    let no_cast = texts::NO_CAST.contains(&first_kind(kinds));
    let values = texts::CHARACTER_VALUE.iter().map(|(choice, _)| *choice);
    let mut choices: Vec<&str> = values
        .filter(|choice| !(no_cast && *choice == "Several characters"))
        .collect();
    choices.push(texts::YOU_CHOOSE);
    choices
}

fn value_of(choice: &str) -> Option<&'static str> {
    let value = texts::CHARACTER_VALUE.iter().find(|(c, _)| *c == choice);
    value.map(|(_, value)| *value)
}

fn pick_of<'a>(answer: &'a str, choices: &[&'static str]) -> (Option<&'static str>, &'a str) {
    for choice in choices {
        if answer == *choice {
            return (Some(choice), "");
        }
        if let Some(line) = answer
            .strip_prefix(choice)
            .and_then(|rest| rest.strip_prefix("; "))
        {
            return (Some(choice), line.trim());
        }
    }
    (None, answer.trim())
}

/// What a free line may say of one gender, and of more than one person.
static NAMED: LazyLock<[(&str, Regex); 4]> = LazyLock::new(|| {
    [
        ("woman", r"\b(woman|girl|lady|female)\b"),
        ("man", r"\b(man|guy|boy|male)\b"),
        ("nonbinary", r"\b(non-?binary|enby)\b"),
        ("not human", r"\b(not human|non-?human|robot|android)\b"),
    ]
    .map(|(gender, pattern)| (gender, Regex::new(pattern).expect("a fixed pattern")))
});
static MANY: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"\b(women|men|girls|boys|guys|ladies|people|several|group|couple|two|three|four|five)\b",
    )
    .expect("a fixed pattern")
});

/// A free line with no pick: more than one person where that is offered, one gender it names, else as told.
fn read_free(line: &str, kinds: &[String]) -> String {
    let low = line.to_lowercase();
    let named: Vec<&str> = NAMED
        .iter()
        .filter(|(_, words)| words.is_match(&low))
        .map(|(gender, _)| *gender)
        .collect();
    if MANY.is_match(&low) || named.len() > 1 {
        let offers = offered(kinds).contains(&"Several characters");
        return if offers { "several" } else { "as told" }.to_string();
    }
    named.first().copied().unwrap_or("as told").to_string()
}

/// An even draw over `count`, by the seed alone.
fn drawn_index(seed: &str, count: usize) -> usize {
    let digest = Sha256::digest(seed.as_bytes());
    let mut head = [0; 8];
    head.copy_from_slice(&digest[..8]);
    (u64::from_be_bytes(head) % count as u64) as usize
}

/// What the answers already show of the character.
fn character_shown<'a>(read: &'a GenderRead, kinds: &[String]) -> Option<&'a str> {
    let offers = offered(kinds).contains(&"Several characters");
    let open = read.character == "unknown" || (read.character == "several" && !offers);
    (!open).then_some(read.character.as_str())
}

/// The choices, from the read and the two answers (empty: none, skipped or "I don't know"). "Let Cardwave choose" draws
/// evenly over the other answers offered.
pub fn settle(
    kinds: &[String],
    read: &GenderRead,
    character: &str,
    treat: &str,
    seed: &str,
) -> Choices {
    let treat_user = if read.treat != "unknown" {
        read.treat.clone()
    } else {
        let picked = pick_of(treat, texts::TREAT_CHOICES).0;
        match picked {
            Some(choice) if choice == texts::TREAT_CHOICES[1] => "man",
            Some(choice) if choice == texts::TREAT_CHOICES[2] => "woman",
            _ => "anyone",
        }
        .to_string()
    };
    let mut out = Choices {
        character_gender: String::new(),
        treat_user,
        character_words: String::new(),
        cast_genders: Vec::new(),
        draw: None,
        cast_draw: None,
    };
    let first = first_kind(kinds);
    if first == texts::THE_USER {
        let own = texts::SELF_GENDER
            .iter()
            .find(|(treat, _)| *treat == out.treat_user);
        out.character_gender = own.map_or("they", |(_, gender)| *gender).to_string();
        return out;
    }
    let shown = character_shown(read, kinds);
    let gender = if first == texts::GROUP {
        if shown.is_some() {
            out.character_words.clone_from(&read.words);
        }
        "several".to_string()
    } else if let Some(shown) = shown {
        if shown == "several" {
            out.character_words.clone_from(&read.words);
        }
        shown.to_string()
    } else {
        let choices = offered(kinds);
        let (pick, line) = pick_of(character, &choices);
        out.character_words = line.to_string();
        match (pick.and_then(value_of), line.is_empty()) {
            (Some(value), _) => value.to_string(),
            (None, false) if pick.is_none() => read_free(line, kinds),
            _ => {
                let over: Vec<String> = choices
                    .iter()
                    .filter_map(|choice| value_of(choice).map(str::to_string))
                    .collect();
                let one = over[drawn_index(seed, over.len())].clone();
                out.draw = Some(Draw {
                    seed: seed.to_string(),
                    over,
                    drawn: vec![one.clone()],
                });
                one
            }
        }
    };
    if gender == "several" {
        let seed = format!("{seed}/cast");
        let pick = |at| drawn_index(&format!("{seed}{at}"), texts::CAST_GENDERS.len());
        let cast: Vec<String> = (0..CAST_MAX)
            .map(|at| texts::CAST_GENDERS[pick(at)].to_string())
            .collect();
        out.cast_genders.clone_from(&cast);
        out.cast_draw = Some(Draw {
            seed,
            over: texts::CAST_GENDERS.iter().map(|g| g.to_string()).collect(),
            drawn: cast,
        });
    }
    out.character_gender = gender;
    out
}

/// The interview's choices as it stands.
pub fn choices(interview: &Interview) -> Choices {
    let unknown = GenderRead::unknown();
    settle(
        &interview.kinds,
        interview.read.as_ref().unwrap_or(&unknown),
        interview.answer("character"),
        interview.answer("treat"),
        &interview.seed,
    )
}

/// The log's entries the limit of questions counts.
pub(crate) fn guard_count(log: &[Entry]) -> usize {
    log.iter().filter(|entry| !guard_free(&entry.slot)).count()
}

pub(crate) fn guard_free(slot: &str) -> bool {
    texts::GUARD_FREE.contains(&slot)
}

/// A seed for this making, not told by anything the user does.
pub(crate) fn new_seed() -> String {
    let mut hasher = RandomState::new().build_hasher();
    let now = SystemTime::now().duration_since(UNIX_EPOCH);
    hasher.write_u128(now.map(|since| since.as_nanos()).unwrap_or_default());
    format!("{:016x}", hasher.finish())
}

/// True when the quote, or else each of its passages of three words or more (at least one), is in the text,
/// as [`quotes::words`] compares them.
pub(crate) fn quote_found(quote: &str, text: &str) -> bool {
    let text = quotes::words(text);
    let long = |part: &&str| quotes::words(part).split_whitespace().count() >= 3;
    quotes::holds(&text, [quote]) || quotes::holds(&text, quote.split(JOINTS).filter(long))
}

/// `GENDER_READ` over the log but for the two questions; a failed call, a broken answer or a quote not in the
/// answers counts as unknown, and an empty log needs no call: no quote could be found.
pub(crate) async fn read_gender<M: Models>(models: &M, interview: &Interview) -> GenderRead {
    let told: Vec<&Entry> = interview
        .log
        .iter()
        .filter(|entry| !guard_free(&entry.slot))
        .collect();
    if told.is_empty() {
        return GenderRead::unknown();
    }
    let characters = [
        "woman",
        "man",
        "nonbinary",
        "not human",
        "several",
        "unknown",
    ];
    let treats = ["man", "woman", "unknown"];
    let schema = form::object([
        ("character", form::one_of(&characters)),
        ("treat", form::one_of(&treats)),
        ("words", form::text()),
    ]);
    let user = interview.told_text();
    let question = Question {
        role: "gender read",
        system: texts::GENDER_READ,
        user: &user,
        schema,
        limit: form::LIMIT,
        temperature: Some(0.0),
    };
    let reply = match models.ask(&question).await {
        Ok(reply) => reply,
        Err(failure) => {
            tracing::warn!(%failure, "the gender read failed, so both questions stay open");
            return GenderRead::unknown();
        }
    };
    let read = GenderRead {
        character: reply["character"].as_str().unwrap_or_default().to_string(),
        treat: reply["treat"].as_str().unwrap_or_default().to_string(),
        words: reply["words"].as_str().unwrap_or_default().to_string(),
    };
    let fits =
        characters.contains(&read.character.as_str()) && treats.contains(&read.treat.as_str());
    let answers: Vec<&str> = told
        .iter()
        .map(|entry| entry.answer.as_deref().unwrap_or_default())
        .collect();
    let nothing = read.character == "unknown" && read.treat == "unknown";
    if fits && !nothing && quote_found(&read.words, &answers.join("\n")) {
        read
    } else {
        GenderRead::unknown()
    }
}

fn character_open(interview: &Interview, read: &GenderRead) -> bool {
    let first = first_kind(&interview.kinds);
    first != texts::THE_USER
        && first != texts::GROUP
        && character_shown(read, &interview.kinds).is_none()
}

/// Drops a kept answer of a question no longer open, or whose choices are no longer those offered.
fn drop_stale(interview: &mut Interview, read: &GenderRead) {
    let open = character_open(interview, read);
    let choices = offered(&interview.kinds);
    let treat_open = read.treat == "unknown";
    let keep = |entry: &Entry| match entry.slot.as_str() {
        "character" => open && entry.choices == choices,
        "treat" => treat_open,
        _ => true,
    };
    if let Some(changed) = interview.changed {
        let before = interview.log[..changed.min(interview.log.len())].iter();
        let gone = before.filter(|entry| !keep(entry)).count();
        interview.changed = Some(changed - gone);
    }
    interview.log.retain(keep);
}

/// The read, once, and what it makes stale gone: the end of the questions, also where none more is asked.
pub async fn finish<M: Models>(models: &M, interview: &mut Interview) -> GenderRead {
    let read = match interview.read.clone() {
        Some(read) => read,
        None => read_gender(models, interview).await,
    };
    interview.read = Some(read.clone());
    drop_stale(interview, &read);
    read
}

/// The next gender question, or `None` once the read-back is next.
pub(crate) async fn next<M: Models>(models: &M, interview: &mut Interview) -> Option<Asking> {
    let read = finish(models, interview).await;
    let question = |slot, text, choices: &[&str]| Asking {
        choices: choices.iter().map(|choice| choice.to_string()).collect(),
        multi: false,
        ..free_question(slot, text)
    };
    if character_open(interview, &read) && !interview.has("character") {
        let choices = offered(&interview.kinds);
        return Some(question("character", texts::CHARACTER_QUESTION, &choices));
    }
    (read.treat == "unknown" && !interview.has("treat"))
        .then(|| question("treat", texts::TREAT_QUESTION, texts::TREAT_CHOICES))
}

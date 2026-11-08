//! The read-back: what the interview's answers say the user needs, one sentence
//! beside the words it rests on, and what the user does with each line. An
//! untouched line is kept. "That's not it" finds the line's question by its words
//! and replaces that answer in place, so the limit of questions does not move; what
//! can no longer stand goes (the old kind's own questions, an unpicked need's branch,
//! the old answer's probe), nothing is asked anew; the read-back then runs again and
//! earlier choices are lost.
//!
//! Trap: the finding is Claude's reading of the source (it was never tested there):
//! the model's `words` are pieces of the answers, quoted or joined, so they are cut
//! at their joints and the entry with the most characters found wins. A removed
//! line's pieces are cut from what the writer reads ([`without_words`]), wherever
//! they stand; a short one only where it is all of a part, as "no" in "no pity"
//! carries the meaning of what is left.

use anyhow::{Context, bail};
use cw_ccv4::creation::{Need, NeedState};
use cw_core::{Code, Fail};
use cw_provider::form::{self, Question};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{Interview, Models, Move, clear_own_slots, drop_after, entry_of, gender, texts, tree};
use crate::quotes::{plain, wordy};

/// How many lines that are not gaps are shown.
pub const SHOWN: usize = 8;

/// A line of the read-back.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export, rename = "ReadBackLine")]
pub struct Line {
    pub sentence: String,
    pub words: String,
    pub gap: bool,
}

/// What the user did with a line.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export, rename = "ReadBackVerdict")]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    Keep,
    Change(String),
    Remove,
}

/// What the user is shown: every gap and the first [`SHOWN`] others, in the model's order.
pub fn first_needs(lines: Vec<Line>) -> Vec<Line> {
    let mut others = 0;
    let mut shown = Vec::new();
    for line in lines {
        if !line.gap {
            others += 1;
        }
        if line.gap || others <= SHOWN {
            shown.push(line);
        }
    }
    shown
}

/// The lines to show of `interview`; with nothing answered, none, and no call.
pub async fn read_back<M: Models>(models: &M, interview: &Interview) -> anyhow::Result<Vec<Line>> {
    if interview.log.is_empty() {
        return Ok(Vec::new());
    }
    let line = form::object([
        ("sentence", form::text()),
        ("words", form::text()),
        ("gap", form::yes_no()),
    ]);
    let choices = gender::choices(interview);
    let told = format!(
        "\nThe character's gender: {}. How it treats the user: {}.",
        choices.character_gender, choices.treat_user
    );
    let reply = models
        .ask(&Question {
            role: "read-back",
            system: texts::READ_BACK_FOCUSED,
            user: &format!("{}{told}", interview.answers_text()),
            schema: form::object([("needs", form::list(line))]),
            limit: form::LIMIT,
            temperature: None,
        })
        .await?;
    let lines = serde_json::from_value(reply["needs"].clone()).context(
        Fail::said(Code::ModelAnswer, "the model's read-back cannot be read")
            .with("what", "read_back"),
    )?;
    Ok(first_needs(lines))
}

/// The needs of `lines` after the user's `verdicts`, line by line; a line without
/// one is kept, a change with empty text keeps the old sentence.
pub fn corrected(lines: &[Line], verdicts: &[Verdict]) -> Vec<Need> {
    let need = |(index, line): (usize, &Line)| {
        let (state, changed_to) = match verdicts.get(index) {
            Some(Verdict::Remove) => (NeedState::Removed, None),
            Some(Verdict::Change(text)) if !text.trim().is_empty() => {
                (NeedState::Changed, Some(text.trim().to_string()))
            }
            _ => (NeedState::Kept, None),
        };
        Need {
            sentence: line.sentence.clone(),
            words: line.words.clone(),
            gap: line.gap,
            state,
            changed_to,
        }
    };
    lines.iter().enumerate().map(need).collect()
}

/// The fewest characters of a piece cut from inside a part of an answer.
const LONG_PIECE: usize = 4;
/// Where a line's `words` are joined, and an answer's parts or a quote end.
pub(super) const JOINTS: [char; 5] = ['·', ';', '"', '\u{201C}', '\u{201D}'];

/// The pieces of the answers a line's `words` are made of, plain.
fn pieces(words: &str) -> Vec<String> {
    plain(words)
        .split(JOINTS)
        .map(|piece| piece.trim_matches(|c: char| c.is_whitespace() || "'.,".contains(c)))
        .filter(|piece| !piece.is_empty())
        .map(str::to_string)
        .collect()
}

/// `text` without the pieces of `words`, compared plain. A piece under
/// [`LONG_PIECE`] characters goes only where it is all of a part ("no" stays in
/// "no pity"), a longer one unless it is inside a longer word ("know" stays in
/// "knowing"); scripts without case have no such check, as their words may run together.
pub fn without_words(text: &str, words: &[&str]) -> String {
    let split = |one: Option<&(usize, char)>, other: char| {
        one.is_some_and(|(_, c)| wordy(*c)) && wordy(other)
    };
    let at_edge = |mut outward: Box<dyn Iterator<Item = char> + '_>| {
        let next = outward.find(|c| !c.is_whitespace() && !"'.,".contains(*c));
        next.is_none_or(|c| JOINTS.contains(&c))
    };
    // Each plain character beside the place of the character it came from.
    let said: Vec<(usize, char)> = text
        .chars()
        .enumerate()
        .flat_map(|(at, c)| {
            let plain = plain(c.encode_utf8(&mut [0; 4]));
            plain.chars().map(|c| (at, c)).collect::<Vec<_>>()
        })
        .collect();
    let mut cut = vec![false; text.chars().count()];
    for piece in words.iter().flat_map(|words| pieces(words)) {
        let piece: Vec<char> = piece.chars().collect();
        for start in 0..(said.len() + 1).saturating_sub(piece.len()) {
            let end = start + piece.len();
            let found = said[start..end].iter().map(|(_, c)| c).eq(piece.iter());
            let before = start.checked_sub(1).and_then(|at| said.get(at));
            let whole = found
                && if piece.len() < LONG_PIECE {
                    at_edge(Box::new(said[..start].iter().rev().map(|(_, c)| *c)))
                        && at_edge(Box::new(said[end..].iter().map(|(_, c)| *c)))
                } else {
                    !split(before, piece[0]) && !split(said.get(end), piece[piece.len() - 1])
                };
            if whole {
                said[start..end].iter().for_each(|(at, _)| cut[*at] = true);
            }
        }
    }
    let kept = text.chars().zip(cut).filter(|(_, cut)| !cut);
    kept.map(|(c, _)| c).collect()
}

/// Whether the entry is the kinds question answered by no real kind, which is not shown changeable.
fn bare_kind(entry: &super::Entry) -> bool {
    entry.slot == "kinds"
        && entry
            .picks
            .iter()
            .all(|pick| matches!(pick.as_str(), "Something else" | "Not sure"))
}

/// The log's index of the question `words` rest on; `None` where no answer holds them.
pub fn question_of(interview: &Interview, words: &str) -> Option<usize> {
    let pieces = pieces(words);
    let mut best = None;
    for (index, entry) in interview.log.iter().enumerate() {
        let Some(said) = entry.said().filter(|_| !bare_kind(entry)) else {
            continue;
        };
        let said = plain(said);
        let found = pieces.iter().filter(|piece| said.contains(piece.as_str()));
        let score: usize = found.map(|piece| piece.chars().count()).sum();
        if score > 0 && best.is_none_or(|(most, _)| score > most) {
            best = Some((score, index));
        }
    }
    best.map(|(_, index)| index)
}

/// Whether a line is the model's own guess: no piece of its `words` stands in any
/// answer, a bare kind's included (it was said, though not asked again).
pub fn guessed(interview: &Interview, words: &str) -> bool {
    let said: Vec<String> = interview
        .log
        .iter()
        .filter_map(|entry| entry.said().map(plain))
        .collect();
    !pieces(words)
        .iter()
        .any(|piece| said.iter().any(|said| said.contains(piece.as_str())))
}

/// The answer of the log's entry `index` replaced by `action`, in place: the log
/// never grows and no further question comes. Back, "Just make it" and an answer that ends
/// the questions are no answers here.
pub fn reanswer(interview: &Interview, index: usize, action: Move) -> anyhow::Result<Interview> {
    if matches!(action, Move::Back | Move::JustMakeIt | Move::EndAfter(_)) {
        bail!(Fail::said(
            Code::OutOfRange,
            "that is no answer to the question"
        ));
    }
    let Some(old) = interview.log.get(index) else {
        bail!(Fail::said(
            Code::OutOfRange,
            "the interview has no such question"
        ));
    };
    let mut next = interview.clone();
    let mut entry = entry_of(interview, old.asking(), action);
    (entry.lit, entry.tag) = (old.lit.clone(), old.tag.clone());
    if entry.slot == "kinds" {
        next.kinds = entry.picks.clone();
    }
    if !gender::guard_free(&old.slot) {
        next.read = None;
    }
    let probe = format!("{} probe", old.slot);
    next.log[index] = entry;
    clear_own_slots(&mut next, index, old);
    if old.slot == "needs" {
        tree::drop_unpicked_branches(&mut next, index);
    }
    drop_after(&mut next, index, |entry| entry.probe && entry.slot == probe);
    Ok(next)
}

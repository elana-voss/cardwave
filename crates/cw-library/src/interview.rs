//! "Make a character together": the interview's engine (milestone 110). The page holds an [`Interview`] and sends it back with each
//! [`Move`]; [`step`] gives the next state, and on an error the page keeps the
//! state it had, so a retry repeats the step. `asking` empty means the read-back
//! is next. The words are in [`texts`]; each style's rules in its own module; then
//! [`readback`] and [`writer`].
//!
//! All state of a style is folded from the log, so Back needs no replay of model
//! calls: a Cloud or Hybrid entry with a real answer and no `lit`/`tag` yet is
//! "due", and `advance` makes that call first. Back moves the log's end to
//! `ahead` and stashes the shown question in `waiting`; the same answer puts both
//! back, another drops from `ahead` what rests on the old one (each style's
//! `clear`), and new questions append, so the log is not always in asked order.
//! A question a model words is asked in the step's language (`in_language`); English
//! keeps the prompt as it was.
//! Trap: a probe is told by `Entry::probe`, never by its slot's ending: the Cloud's
//! model names slots.

pub mod cloud;
mod craft;
pub mod gender;
pub mod hybrid;
pub mod private;
pub mod readback;
pub mod shown;
pub mod texts;
pub mod tree;
pub mod writer;

#[cfg(test)]
mod tests;
#[cfg(test)]
mod tests_craft;
#[cfg(test)]
mod tests_gender;
#[cfg(test)]
mod tests_readback;
#[cfg(test)]
mod tests_wire;
#[cfg(test)]
mod tests_writer;

use std::future::Future;

use anyhow::bail;
use cw_core::{Code, Fail};
use cw_provider::form::{self, Question};
use cw_provider::{Http, Provider};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use ts_rs::TS;

/// The questions of one interview, every entry of the log but the two gender
/// questions counted. Reaching it is an error to log, not a normal end.
pub const GUARD: usize = 16;
/// The room the Cloud keeps under [`GUARD`] for the kinds, the relation, three kind questions and a probe.
pub const RESERVE: usize = 6;
/// A free answer under this many words is vague.
pub const VAGUE_WORDS: usize = 5;

/// How the models are asked; tests answer it with a script.
pub trait Models: Sync {
    fn ask(&self, question: &Question<'_>) -> impl Future<Output = anyhow::Result<Value>> + Send;
}

/// The models of the user's provider.
pub struct Asker<'a> {
    pub http: &'a Http,
    pub provider: &'a Provider,
}

impl Models for Asker<'_> {
    fn ask(&self, question: &Question<'_>) -> impl Future<Output = anyhow::Result<Value>> + Send {
        form::ask(self.http, self.provider, question)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
#[serde(rename_all = "lowercase")]
pub enum Style {
    Tree,
    Cloud,
    Hybrid,
}

/// The question shown. With choices: pills, one only where not `multi`, and a
/// free line beside, except on the kinds question, whose `choices` are the six
/// that fit best (the rest of `texts::KIND_NAMES` under "More").
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Asking {
    pub slot: String,
    pub question: shown::Text,
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub choices: Vec<String>,
    pub multi: bool,
    pub probe: bool,
}

/// What the Hybrid's tagger said of an answer.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Tag {
    pub fills: Vec<String>,
    pub touched: Vec<String>,
    /// The answer was vague and the one probe went to it.
    pub probing: bool,
}

/// A question asked and what came of it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
#[serde(from = "shown::EntryForm")]
pub struct Entry {
    pub slot: String,
    pub question: shown::Text,
    /// `None` for Skip, empty for "I don't know", else the picks and free line joined;
    /// the page does not get it, the server makes it anew ([`answer_of`]).
    #[serde(skip_serializing)]
    #[ts(skip)]
    pub answer: Option<String>,
    pub skipped: bool,
    pub dont_know: bool,
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub choices: Vec<String>,
    pub multi: bool,
    pub probe: bool,
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub picks: Vec<String>,
    pub free: String,
    /// What the answer lit up (Cloud).
    pub lit: Option<Vec<String>>,
    /// The tagger's word on the answer (Hybrid).
    pub tag: Option<Tag>,
}

impl Entry {
    /// The answer, where it is one: not skipped, not "I don't know".
    pub fn said(&self) -> Option<&str> {
        self.answer.as_deref().filter(|said| !said.is_empty())
    }

    fn asking(&self) -> Asking {
        Asking {
            slot: self.slot.clone(),
            question: self.question.clone(),
            choices: self.choices.clone(),
            multi: self.multi,
            probe: self.probe,
        }
    }
}

/// An interview, whole, as the page holds it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Interview {
    pub style: Style,
    pub log: Vec<Entry>,
    /// The question shown; `None` once the read-back is next.
    pub asking: Option<Asking>,
    /// What Back stepped over; its first is the entry being asked again.
    pub ahead: Vec<Entry>,
    /// The question shown when Back was first pressed.
    pub waiting: Option<Asking>,
    /// The kinds that fit best, once asked for.
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub top: Vec<String>,
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub kinds: Vec<String>,
    /// The limit of questions ended it, with something left to ask.
    pub guard_hit: bool,
    /// The log's entry a changed answer replaced, until the next new answer: what
    /// the Hybrid asks next rests on it, not on the later answers kept after it.
    pub changed: Option<usize>,
    /// What the answers state of gender, once read; a changed answer clears it.
    pub read: Option<gender::GenderRead>,
    /// What "Let Cardwave choose" draws by; never told to a model.
    pub seed: String,
}

/// What the user did on a question.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export, rename = "InterviewMove")]
#[serde(rename_all = "snake_case")]
pub enum Move {
    Answer {
        #[serde(with = "shown::many")]
        #[ts(as = "Vec<shown::Text>")]
        picks: Vec<String>,
        free: String,
    },
    Skip,
    DontKnow,
    Back,
    JustMakeIt,
    /// Just make it after this move, which failed at its model call: the move is
    /// recorded with no call, so the answer it holds is kept, then the interview ends.
    EndAfter(Box<Move>),
}

impl Interview {
    /// An interview at its opening question.
    pub fn new(style: Style) -> Self {
        Interview {
            style,
            log: Vec::new(),
            asking: Some(free_question("wanted", texts::WANTED)),
            ahead: Vec::new(),
            waiting: None,
            top: Vec::new(),
            kinds: Vec::new(),
            guard_hit: false,
            changed: None,
            read: None,
            seed: gender::new_seed(),
        }
    }

    /// The answers as the models see them.
    pub fn answers_text(&self) -> String {
        self.lines_of(|_| true)
    }

    /// The answers without the two gender questions.
    pub fn told_text(&self) -> String {
        self.lines_of(|entry| !gender::guard_free(&entry.slot))
    }

    fn lines_of(&self, keep: impl Fn(&Entry) -> bool) -> String {
        let line = |entry: &Entry| {
            let said = if entry.skipped {
                "(skipped)"
            } else if entry.dont_know {
                "(don't know)"
            } else {
                entry.answer.as_deref().unwrap_or_default()
            };
            format!("- {} -> {said}", entry.question)
        };
        let lines: Vec<String> = self.log.iter().filter(|e| keep(e)).map(line).collect();
        lines.join("\n")
    }

    /// The answer of `slot`; empty where there is none.
    pub fn answer(&self, slot: &str) -> &str {
        let entry = self.log.iter().find(|entry| entry.slot == slot);
        entry
            .and_then(|entry| entry.answer.as_deref())
            .unwrap_or_default()
    }

    fn has(&self, slot: &str) -> bool {
        self.log.iter().any(|entry| entry.slot == slot)
    }
}

/// The state after `action` on `now`; a question a model words is in `language`, the page's (a BCP 47 code).
pub async fn step<M: Models>(
    models: &M,
    now: &Interview,
    action: Move,
    language: &str,
) -> anyhow::Result<Interview> {
    let mut interview = now.clone();
    match action {
        Move::Back => back(&mut interview),
        Move::JustMakeIt => just_make_it(models, &mut interview).await,
        Move::EndAfter(last) => {
            if !matches!(*last, Move::Answer { .. } | Move::Skip | Move::DontKnow) {
                bail!(Fail::said(
                    Code::OutOfRange,
                    "only an answer can come before the end"
                ));
            }
            record(&mut interview, *last)?;
            just_make_it(models, &mut interview).await;
        }
        answer => answered(models, &mut interview, answer, language).await?,
    }
    Ok(interview)
}

/// Back to the log's last answer; from a probe, to the answer it probes, which a
/// changed answer can have left before answers kept.
fn back(interview: &mut Interview) {
    let Some(last) = interview.log.len().checked_sub(1) else {
        return;
    };
    let asking = interview.asking.as_ref();
    let probed = asking
        .filter(|asking| asking.probe && interview.ahead.is_empty())
        .and_then(|asking| asking.slot.strip_suffix(" probe"))
        .and_then(|slot| interview.log.iter().rposition(|entry| entry.slot == slot));
    let mut stepped = interview.log.split_off(probed.unwrap_or(last));
    if interview.ahead.is_empty() {
        interview.waiting = interview.asking.take();
    }
    interview.asking = Some(stepped[0].asking());
    stepped.append(&mut interview.ahead);
    interview.ahead = stepped;
}

async fn just_make_it<M: Models>(models: &M, interview: &mut Interview) {
    let ahead = std::mem::take(&mut interview.ahead);
    interview.log.extend(ahead);
    (interview.asking, interview.waiting) = (None, None);
    if !interview.has("kinds") {
        interview.kinds = vec!["Not sure".to_string()];
    }
    gender::finish(models, interview).await;
}

async fn answered<M: Models>(
    models: &M,
    interview: &mut Interview,
    action: Move,
    language: &str,
) -> anyhow::Result<()> {
    match record(interview, action)? {
        Some(just) => advance(models, interview, just, language).await,
        None => Ok(()),
    }
}

/// The move written into the log, no model called. Gives the entry `advance` goes
/// on from; none where Back's same answer put everything back.
fn record(interview: &mut Interview, action: Move) -> anyhow::Result<Option<usize>> {
    let Some(asking) = interview.asking.take() else {
        bail!(Fail::said(
            Code::OutOfRange,
            "the interview has no question open"
        ));
    };
    let entry = entry_of(interview, asking, action);
    if entry.slot == "kinds" {
        interview.kinds = entry.picks.clone();
    }
    if interview.ahead.is_empty() {
        interview.log.push(entry);
        interview.changed = None;
        return Ok(Some(interview.log.len() - 1));
    }
    let old = interview.ahead.remove(0);
    let ahead = std::mem::take(&mut interview.ahead);
    let same = (&old.answer, old.skipped, old.dont_know)
        == (&entry.answer, entry.skipped, entry.dont_know);
    if same {
        interview.log.push(old);
        interview.log.extend(ahead);
        interview.asking = interview.waiting.take();
        return Ok(None);
    }
    interview.waiting = None;
    if !gender::guard_free(&old.slot) {
        interview.read = None;
    }
    interview.log.push(entry);
    let just = interview.log.len() - 1;
    interview.changed = Some(just);
    interview.log.extend(ahead);
    clear_own_slots(interview, just, &old);
    match interview.style {
        Style::Tree => tree::clear(interview, just, &old),
        Style::Cloud => cloud::clear(interview, just, &old),
        Style::Hybrid => hybrid::clear(interview, just, &old),
    }
    let probe = format!("{} probe", old.slot);
    drop_after(interview, just, |entry| entry.probe && entry.slot == probe);
    Ok(Some(just))
}

/// An entry's answer: `None` where skipped, else its picks and free line joined.
pub(crate) fn answer_of(picks: &[String], free: &str, skipped: bool) -> Option<String> {
    (!skipped).then(|| {
        let mut parts = picks.to_vec();
        if !free.is_empty() {
            parts.push(free.to_string());
        }
        parts.join("; ")
    })
}

/// The log's entry of a question and what was done on it.
fn entry_of(interview: &Interview, asking: Asking, action: Move) -> Entry {
    let (mut picks, mut free, mut skipped, mut dont_know) = match action {
        Move::Answer { picks, free } => (picks, free.trim().to_string(), false, false),
        Move::DontKnow => (Vec::new(), String::new(), false, true),
        _ => (Vec::new(), String::new(), true, false),
    };
    if asking.slot == "kinds" {
        picks.retain(|pick| texts::KIND_NAMES.contains(&pick.as_str()));
        picks.truncate(2);
        if picks.is_empty() {
            picks.extend(interview.top.first().cloned());
        }
        (free, skipped, dont_know) = (String::new(), false, false);
    } else if !asking.multi {
        picks.truncate(1);
    }
    if asking.slot == "treat" {
        free = String::new();
    }
    let blank = picks.is_empty() && free.is_empty();
    let skipped = skipped || (blank && !dont_know);
    let answer = answer_of(&picks, &free, skipped);
    Entry {
        slot: asking.slot,
        question: asking.question,
        answer,
        skipped,
        dont_know,
        choices: asking.choices,
        multi: asking.multi,
        probe: asking.probe,
        picks,
        free,
        lit: None,
        tag: None,
    }
}

/// What a style asks next.
pub(crate) enum Planned {
    Done,
    Fixed(Asking),
    /// A question the interviewer words: its slot and the call's user message.
    Worded(String, String),
    Kinds,
}

/// Moves on to the next question, after the answer at `just`.
async fn advance<M: Models>(
    models: &M,
    interview: &mut Interview,
    just: usize,
    language: &str,
) -> anyhow::Result<()> {
    interview.asking = None;
    // The two gender questions stand outside the limit: answering them keeps its mark.
    interview.guard_hit &= gender::guard_free(&interview.log[just].slot);
    if let Some(probe) = probe_due(interview, just) {
        if gender::guard_count(&interview.log) < GUARD {
            interview.asking = Some(probe);
        } else {
            limit_hit(interview);
            interview.asking = gender::next(models, interview).await;
        }
        return Ok(());
    }
    let planned = match interview.style {
        Style::Tree => tree::plan(interview),
        Style::Cloud => {
            // At the limit nothing more is asked, so nothing more can light up.
            if gender::guard_count(&interview.log) < GUARD {
                cloud::light_due(models, interview).await?;
            }
            cloud::plan(interview)
        }
        Style::Hybrid => {
            hybrid::tag_due(models, interview).await?;
            hybrid::plan(interview)
        }
    };
    if !matches!(planned, Planned::Done) && gender::guard_count(&interview.log) >= GUARD {
        limit_hit(interview);
        interview.asking = gender::next(models, interview).await;
        return Ok(());
    }
    interview.asking = match planned {
        Planned::Done => gender::next(models, interview).await,
        Planned::Fixed(asking) => Some(asking),
        Planned::Worded(slot, user) => {
            let user = in_language(&user, language);
            Some(worded(models, slot, &user).await?)
        }
        Planned::Kinds => Some(kinds_question(models, interview).await?),
    };
    Ok(())
}

fn limit_hit(interview: &mut Interview) {
    interview.guard_hit = true;
    tracing::warn!(style = ?interview.style, "an interview reached its limit of {GUARD} questions");
}

/// The one probe, where the answer of entry `just` is vague and the style probes it.
fn probe_due(interview: &Interview, just: usize) -> Option<Asking> {
    let entry = &interview.log[just];
    let probes = match interview.style {
        Style::Tree => {
            !tree::OPENING.contains(&entry.slot.as_str())
                && !["kinds", "known_character"].contains(&entry.slot.as_str())
        }
        Style::Cloud => cloud::lights(entry),
        Style::Hybrid => false,
    };
    let said = entry.said()?;
    let vague = said.split_whitespace().count() < VAGUE_WORDS;
    let used = interview.log.iter().any(|entry| entry.probe);
    (probes && !entry.probe && entry.choices.is_empty() && vague && !used).then(|| Asking {
        probe: true,
        question: shown::Text::quoting(true, Some(entry)),
        ..free_question(&format!("{} probe", entry.slot), "")
    })
}

/// `user` with the line asking for `language`'s words; as it is where that is English.
/// Chinese is named with its script, as the page's language file has it.
fn in_language(user: &str, language: &str) -> String {
    let code = cw_core::languages::file_code(language);
    if code.is_empty() || code == "en" {
        return user.to_string();
    }
    let name = match code.as_str() {
        "zh-Hant" => "Chinese (traditional)".to_string(),
        "zh-Hans" => "Chinese (simplified)".to_string(),
        _ => cw_core::languages::name_of(language),
    };
    format!("{user}\n\n{}", texts::WORD_IN.replacen("{}", &name, 1))
}

async fn worded<M: Models>(models: &M, slot: String, user: &str) -> anyhow::Result<Asking> {
    let schema = form::object([
        ("question", form::text()),
        ("choices", form::list(form::text())),
    ]);
    let reply = models
        .ask(&Question {
            role: "interviewer",
            system: texts::INTERVIEWER,
            user,
            schema,
            limit: form::LIMIT,
            temperature: None,
        })
        .await?;
    let slot_multi = slot != "which_me";
    Ok(Asking {
        slot,
        question: shown::Text::of(reply["question"].as_str().unwrap_or_default()),
        choices: strings(&reply["choices"]),
        multi: slot_multi,
        probe: false,
    })
}

/// The kinds question; its six are ranked once.
async fn kinds_question<M: Models>(
    models: &M,
    interview: &mut Interview,
) -> anyhow::Result<Asking> {
    if interview.top.is_empty() {
        let names: Vec<String> = texts::KIND_NAMES.iter().map(|n| n.to_string()).collect();
        let user = format!(
            "What the user told:\n{}\n\nKinds: {}",
            interview.answers_text(),
            dumps(&names)
        );
        let schema = form::object([("kinds", form::list(form::text()))]);
        let reply = models
            .ask(&Question {
                role: "rank kinds",
                system: texts::RANK_KINDS,
                user: &user,
                schema,
                limit: form::LIMIT,
                temperature: None,
            })
            .await?;
        let mut top: Vec<String> = Vec::new();
        for kind in strings(&reply["kinds"]) {
            if names.contains(&kind) && !top.contains(&kind) {
                top.push(kind);
            }
        }
        top.truncate(6);
        let lacking = 6 - top.len();
        let rest = names.iter().filter(|name| !top.contains(name));
        let rest: Vec<String> = rest.take(lacking).cloned().collect();
        top.extend(rest);
        interview.top = top;
    }
    Ok(Asking {
        choices: interview.top.clone(),
        ..free_question("kinds", texts::KINDS_QUESTION)
    })
}

/// The first question of the Tree's and the Hybrid's opening still open.
pub(crate) fn opening(interview: &Interview) -> Option<Planned> {
    let question = |slot, text, choices: &[&str], multi| {
        Planned::Fixed(Asking {
            choices: choices.iter().map(|choice| choice.to_string()).collect(),
            multi,
            ..free_question(slot, text)
        })
    };
    if !interview.has("wanted") {
        Some(question("wanted", texts::WANTED, &[], true))
    } else if !interview.has("moments") {
        Some(question(
            "moments",
            texts::MOMENTS_QUESTION,
            texts::MOMENTS,
            true,
        ))
    } else if !interview.has("needs") {
        Some(question(
            "needs",
            texts::NEEDS_QUESTION,
            &texts::NEEDS,
            true,
        ))
    } else if !interview.has("kinds") {
        Some(Planned::Kinds)
    } else if relation_due(interview) {
        Some(relation_question())
    } else {
        None
    }
}

/// The relation is asked after the kinds, only for the kinds that do not say it.
pub(crate) fn relation_due(interview: &Interview) -> bool {
    relation_asked(&interview.kinds) && !interview.has("relation")
}

fn relation_asked(kinds: &[String]) -> bool {
    texts::RELATION_ASKED.contains(&gender::first_kind(kinds))
}

/// The relation question, one pick only.
pub(crate) fn relation_question() -> Planned {
    Planned::Fixed(Asking {
        choices: texts::RELATIONS.iter().map(|r| r.to_string()).collect(),
        multi: false,
        ..free_question("relation", texts::RELATION_QUESTION)
    })
}

/// A question without choices, as written.
pub(crate) fn free_question(slot: &str, text: &str) -> Asking {
    Asking {
        slot: slot.to_string(),
        question: shown::Text::of(text),
        choices: Vec::new(),
        multi: true,
        probe: false,
    }
}

/// The source's fixed question of `slot`.
pub(crate) fn fixed_question(slot: &str) -> Option<Asking> {
    let (_, text, choices) = texts::FIXED.iter().find(|(name, ..)| *name == slot)?;
    Some(Asking {
        choices: choices.iter().map(|choice| choice.to_string()).collect(),
        multi: slot != "which_me",
        ..free_question(slot, text)
    })
}

/// The slots the kinds add, in the source's order.
pub(crate) fn kind_slots(kinds: &[String]) -> Vec<&'static str> {
    let wanted = |names: &[&str]| kinds.iter().any(|kind| names.contains(&kind.as_str()));
    let own = texts::KIND_SLOT.iter().filter(|(_, names)| wanted(names));
    own.map(|(slot, _)| *slot).collect()
}

/// Removes the log's entries after `after` that `gone` names, and their probes.
pub(crate) fn drop_after(interview: &mut Interview, after: usize, gone: impl Fn(&Entry) -> bool) {
    let later = &interview.log[after + 1..];
    let dropped: Vec<String> = later
        .iter()
        .filter(|entry| gone(entry))
        .map(|entry| format!("{} probe", entry.slot))
        .collect();
    let mut index = 0;
    interview.log.retain(|entry| {
        index += 1;
        index <= after + 1 || !(gone(entry) || (entry.probe && dropped.contains(&entry.slot)))
    });
}

/// A changed kinds answer drops the own questions no longer wanted and a relation no longer asked.
fn clear_own_slots(interview: &mut Interview, just: usize, old: &Entry) {
    if old.slot != "kinds" {
        return;
    }
    let wanted = kind_slots(&interview.kinds);
    drop_after(interview, just, |entry| {
        let own = texts::KIND_SLOT.iter().any(|(slot, _)| *slot == entry.slot);
        own && !wanted.contains(&entry.slot.as_str())
    });
    if !relation_asked(&interview.kinds) {
        drop_after(interview, just, |entry| entry.slot == "relation");
    }
}

/// The strings of a JSON list.
pub(crate) fn strings(list: &Value) -> Vec<String> {
    let items = list.as_array().map(Vec::as_slice).unwrap_or_default();
    items
        .iter()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect()
}

/// `value` as the source's `json.dumps` writes it, but for non-ASCII kept as it is.
pub(crate) fn dumps(value: &impl Serialize) -> String {
    // Empty on a failure: the interview's plain data has nothing that fails to serialize.
    crate::describe::sent(value).unwrap_or_default()
}

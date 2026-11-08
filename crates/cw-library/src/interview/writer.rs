//! The writer: from the interview, the corrected needs and the private list to a
//! card and how it was made, in two model calls, three when the card fails. The order:
//! plan; code settles the plan; card, with the first greeting's rule repeated at the
//! end of its request; a fifth greeting dropped; a name left unfilled takes the plan's;
//! `tidy`; the craft check ([`super::craft`]); what fails gets one repair call
//! ([`repaired`]), never a second, then `tidy` and the check once more; what still fails
//! is only logged, without the card's text. The card is then shown. A refusal
//! or an unfit answer on the plan or the card is the caller's to tell
//! ([`form::declined`]); on the repair it leaves the card. The two gender answers
//! choose the rules in each system prompt; drawn seeds never reach a model.
//!
//! Traps: a card that starts like a refusal with no provider signal is only logged,
//! without its content. A model's plan comes back with sorted keys (serde_json keeps
//! no order), so the card's call sees it in another key order than the source's.
//! Lengths are in characters, as the source's Python counts them. A removed line is
//! gone for the writer: its words are cut from the log and the relation the plan reads
//! ([`told`]), while the saved `Creation` keeps the whole log.

use std::sync::LazyLock;

use anyhow::Context;
use cw_ccv4::creation::{Asked, Creation, Need, NeedState, Private};
use cw_ccv4::new::NewCard;
use cw_core::{Code, Fail};
use cw_provider::form::{self, Question};
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::craft::{Failing, craft_check, four_greetings, tidy};
use super::gender::{self, CAST_MAX, Choices};
use super::private::sensitive_lines;
use super::readback::without_words;
use super::{Entry, Interview, Models, Style, dumps, strings, texts};

/// The most tokens the plan may take; a model's reasoning counts as output, and at
/// the limit its strict JSON closes a text mid-sentence, so the answer still parses.
const PLAN_OUT: u32 = 12_000;
/// The most tokens the card and its rewrite may take.
const CARD_OUT: u32 = 16_000;
/// How long the writer's calls may stay silent; one may run past 300 s.
pub const SILENCE: std::time::Duration = std::time::Duration::from_secs(900);
/// How many of the plan's lines about the user are offered for the persona.
const PERSONA_SHOWN: usize = 8;

/// A card with no provider's signal that begins like a refusal.
static UNSIGNALLED: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)^\W*(I'm sorry|I am sorry|I can(no|')t|I won't|I'm not able|As an AI)")
        .expect("a fixed pattern")
});

/// What the writer works from.
pub struct Making<'a> {
    pub interview: &'a Interview,
    /// Every line of the read-back, with what the user did with it.
    pub needs: &'a [Need],
    pub private: &'a Private,
    /// The model that writes, as it is kept with the card.
    pub model: &'a str,
}

/// What the writer gives.
#[derive(Debug)]
pub struct Written {
    pub card: NewCard,
    /// The lines to offer for the persona; nothing goes there unseen.
    pub persona: Vec<String>,
}

/// The card's fields as the model writes them.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Fields {
    pub name: String,
    pub description: String,
    pub personality: String,
    pub scenario: String,
    pub first_mes: String,
    pub mes_example: String,
    pub alternate_greetings: Vec<String>,
    pub creator_notes: String,
}

/// A need as the writer gets it.
#[derive(Serialize)]
struct NeedLine<'a> {
    sentence: &'a str,
    words: &'a str,
    gap: bool,
}

/// What the plan's call reads, in the source's order.
#[derive(Serialize)]
struct Profile<'a> {
    kinds: &'a [String],
    /// Null where skipped, empty where it was not asked.
    relation: Option<&'a str>,
    nevers_from_list: &'a [String],
    sensitive_lines: &'a [String],
    question_log: &'a [Asked],
    needs: Vec<NeedLine<'a>>,
    character_gender: &'a str,
    treat_user: &'a str,
    character_words: &'a str,
    cast_genders: &'a [String],
}

fn asked(entry: &Entry) -> Asked {
    Asked {
        slot: entry.slot.clone(),
        question: entry.question.english(),
        answer: entry.answer.clone(),
        skipped: entry.skipped,
        dont_know: entry.dont_know,
    }
}

/// `entry` as the plan reads it, without the `removed` lines' words: an answer of
/// nothing else goes as skipped; a question goes without them too, as "why" and a probe
/// quote the answer they ask about. The kinds stay: they choose the card's mode, and
/// the profile holds them apart.
fn told(entry: &Entry, removed: &[&str]) -> Asked {
    let mut told = asked(entry);
    if entry.slot == "kinds" {
        return told;
    }
    told.question = without_words(&entry.question.english(), removed);
    let Some(said) = entry.said() else {
        return told;
    };
    let left = without_words(said, removed);
    if left != said {
        let has_words = |part: &&str| part.chars().any(char::is_alphanumeric);
        let parts: Vec<&str> = left.split(';').map(str::trim).filter(has_words).collect();
        told.skipped = parts.is_empty();
        told.answer = (!parts.is_empty()).then(|| parts.join("; "));
    }
    told
}

fn plan_schema() -> Value {
    let lines = || form::list(form::text());
    let trait_line = form::object([("trait", form::text()), ("when", form::text())]);
    form::object([
        (
            "mode",
            form::one_of(&["Roleplay", "Companion", "Assistant"]),
        ),
        ("role", form::text()),
        ("name", form::text()),
        ("need_as_reason", form::text()),
        ("relation", form::text()),
        ("traits", form::list(trait_line)),
        ("nevers", lines()),
        ("user_words", lines()),
        ("openings", lines()),
        ("persona_lines", lines()),
        ("promise", form::text()),
        (
            "core",
            form::object(
                [
                    "wants_now",
                    "why_not",
                    "habitual_way",
                    "gains",
                    "costs",
                    "when_it_fails",
                ]
                .map(|key| (key, form::text())),
            ),
        ),
        ("without_user", form::text()),
        (
            "changes",
            form::list(form::object([
                ("step", form::text()),
                ("trigger", form::text()),
            ])),
        ),
        (
            "cast",
            form::list(form::object(
                [
                    "name", "gender", "role", "crossing", "details", "talk", "hook", "wants",
                    "ties",
                ]
                .map(|key| (key, form::text())),
            )),
        ),
    ])
}

fn card_schema() -> Value {
    form::object([
        ("name", form::text()),
        ("description", form::text()),
        ("personality", form::text()),
        ("scenario", form::text()),
        ("first_mes", form::text()),
        ("mes_example", form::text()),
        ("alternate_greetings", form::list(form::text())),
        ("creator_notes", form::text()),
    ])
}

/// The text under `key`, empty where the table has none ("several" in the character's rules).
fn row(table: &[(&str, &'static str)], key: &str) -> &'static str {
    let found = table.iter().find(|(name, _)| *name == key);
    found.map_or("", |(_, text)| text)
}

pub(super) fn plan_system(treat: &str, character: &str) -> String {
    let own = match character {
        "several" => texts::CAST_PLAN,
        _ => row(texts::CHARACTER_RULES, character),
    };
    format!(
        "{}\n{}\n{own}",
        texts::WRITER_PLAN,
        row(texts::TREAT_RULES, treat)
    )
}

fn character_rules(character: &str) -> &'static str {
    match character {
        "several" => texts::CAST_CARD,
        _ => row(texts::CHARACTER_RULES, character),
    }
}

fn system_of(head: &str, treat: &str, character: &str) -> String {
    let (craft, treated) = (texts::CRAFT, row(texts::TREAT_RULES, treat));
    format!("{head}{craft}\n{treated}\n{}", character_rules(character))
}

/// The system prompt of the card's call.
pub(super) fn card_system(treat: &str, character: &str) -> String {
    system_of(texts::WRITER_CARD, treat, character)
}

/// The code's part of the plan: the choices, the kinds, a cast only for "several", at
/// most four, with the drawn genders unless the user's words told them.
pub(super) fn settle_plan(mut plan: Value, kinds: &[String], choices: &Choices) -> Value {
    let several = choices.character_gender == "several";
    let mut cast: Vec<Value> = Vec::new();
    if several {
        let people = plan["cast"].as_array().into_iter().flatten();
        cast = people
            .filter(|person| person.is_object())
            .take(CAST_MAX)
            .cloned()
            .collect();
    }
    if several && choices.character_words.is_empty() {
        cast.truncate(choices.cast_genders.len());
        for (person, gender) in cast.iter_mut().zip(&choices.cast_genders) {
            person["gender"] = Value::from(gender.as_str());
        }
    }
    if several {
        plan["mode"] = Value::from("Roleplay");
    }
    plan["cast"] = Value::from(cast);
    plan["kinds"] = Value::from(kinds);
    plan["character_gender"] = Value::from(choices.character_gender.as_str());
    plan["treat_user"] = Value::from(choices.treat_user.as_str());
    plan["character_words"] = Value::from(choices.character_words.as_str());
    plan
}

fn fields_of(reply: Value) -> anyhow::Result<Fields> {
    serde_json::from_value(reply).context(
        Fail::said(Code::ModelAnswer, "the model's card cannot be read").with("what", "card"),
    )
}

/// `card` with the fields of `failing` taken from `fix`; one `fix` leaves blank stays
/// as it was, as a model outside its schema may send only part of a card.
fn merged(card: &Fields, fix: &Fields, failing: &[Failing]) -> anyhow::Result<Fields> {
    let unmergeable = || Fail::said(Code::Internal, "a card cannot be merged");
    let mut whole = serde_json::to_value(card).with_context(unmergeable)?;
    let fixed = serde_json::to_value(fix).with_context(unmergeable)?;
    for fail in failing {
        let new = &fixed[fail.field];
        if new != "" && new != &Value::Array(Vec::new()) {
            whole[fail.field] = new.clone();
        }
    }
    fields_of(whole)
}

/// The one repair of what fails; whatever goes wrong with it, the card stands.
async fn repaired<M: Models>(
    models: &M,
    card: Fields,
    failing: &[Failing],
    choices: &Choices,
) -> Fields {
    let reply = models
        .ask(&Question {
            role: "writer rewrite",
            system: &system_of(
                texts::WRITER_REWRITE,
                &choices.treat_user,
                &choices.character_gender,
            ),
            user: &format!(
                "Card:\n{}\nFailing: {}{}",
                dumps(&card),
                dumps(&failing),
                texts::REWRITE_ASK
            ),
            schema: card_schema(),
            limit: CARD_OUT,
            temperature: None,
        })
        .await;
    let fix = reply.and_then(fields_of);
    match fix.and_then(|fix| merged(&card, &fix, failing)) {
        Ok(mended) => four_greetings(mended),
        Err(failure) => {
            let declined = form::declined(&failure);
            tracing::warn!(declined, "a card's repair call failed; the card stands");
            card
        }
    }
}

/// A need as the writer gets it; a removed one is not sent.
fn need_line(need: &Need) -> Option<NeedLine<'_>> {
    (need.state != NeedState::Removed).then(|| NeedLine {
        sentence: need.changed_to.as_deref().unwrap_or(&need.sentence),
        words: &need.words,
        gap: need.gap,
    })
}

/// The list's nevers and then the plan's, without exact repeats.
fn all_nevers(from_list: Vec<String>, plan: &Value) -> Vec<String> {
    let mut nevers: Vec<String> = Vec::new();
    for never in from_list.into_iter().chain(strings(&plan["nevers"])) {
        if !nevers.contains(&never) {
            nevers.push(never);
        }
    }
    nevers
}

fn style_name(style: Style) -> &'static str {
    match style {
        Style::Tree => "tree",
        Style::Cloud => "cloud",
        Style::Hybrid => "hybrid",
    }
}

/// The card from the settled plan: its call and, if the check fails, its one repair;
/// what the check still finds only goes to the log.
async fn card_of<M: Models>(
    models: &M,
    plan: &Value,
    lines: &[String],
    kinds: &[String],
    choices: &Choices,
) -> anyhow::Result<Fields> {
    let card = models
        .ask(&Question {
            role: "writer card",
            system: &card_system(&choices.treat_user, &choices.character_gender),
            user: &format!(
                "Plan:\n{}\nSensitive list as written: {}\n{}",
                dumps(plan),
                dumps(&lines),
                texts::FIRST_MES_RULE
            ),
            schema: card_schema(),
            limit: CARD_OUT,
            temperature: None,
        })
        .await?;
    let mut card = four_greetings(fields_of(card)?);
    let planned = plan["name"].as_str().filter(|name| is_named(name));
    if let Some(name) = planned.filter(|_| !is_named(&card.name)) {
        card.name = name.trim().to_string();
    }
    if UNSIGNALLED.is_match(&card.description) || UNSIGNALLED.is_match(&card.first_mes) {
        tracing::warn!("a written card begins like a refusal, with no signal from the provider");
    }
    let several = choices.character_gender == "several";
    let cast = plan["cast"].as_array().map_or(0, Vec::len);
    let card = tidy(card, kinds, several);
    let failing = craft_check(&card, kinds, cast, several);
    if failing.is_empty() {
        return Ok(card);
    }
    let found: Vec<_> = failing.iter().map(|f| (f.rule, f.field, &f.why)).collect();
    tracing::warn!(?found, "a written card fails a check");
    let card = tidy(
        repaired(models, card, &failing, choices).await,
        kinds,
        several,
    );
    let failing = craft_check(&card, kinds, cast, several);
    if !failing.is_empty() {
        let found: Vec<_> = failing.iter().map(|f| (f.rule, f.field, &f.why)).collect();
        tracing::warn!(?found, "a repaired card still fails a check");
    }
    Ok(card)
}

/// What a model writes for a name it left unfilled (seen on the worker model: "Placeholder").
const NO_NAME: &[&str] = &[
    "",
    "placeholder",
    "unnamed",
    "unknown",
    "name",
    "character",
    "{{char}}",
    "none",
    "tbd",
    "n/a",
];

fn is_named(name: &str) -> bool {
    !NO_NAME.contains(&name.trim().to_lowercase().as_str())
}

/// The card written from `making`, with what went into it.
pub async fn write_card<M: Models>(models: &M, making: &Making<'_>) -> anyhow::Result<Written> {
    let interview = making.interview;
    let (lines, nevers) = sensitive_lines(making.private);
    let choices = gender::choices(interview);
    let question_log: Vec<Asked> = interview.log.iter().map(asked).collect();
    let is_removed = |need: &&Need| need.state == NeedState::Removed;
    let removed: Vec<&str> = making
        .needs
        .iter()
        .filter(is_removed)
        .map(|need| need.words.as_str())
        .collect();
    let sent: Vec<Asked> = interview
        .log
        .iter()
        .map(|entry| told(entry, &removed))
        .collect();
    let relation = sent.iter().find(|entry| entry.slot == "relation");
    let profile = Profile {
        kinds: &interview.kinds,
        relation: relation.map_or(Some(""), |entry| entry.answer.as_deref()),
        nevers_from_list: &nevers,
        sensitive_lines: &lines,
        question_log: &sent,
        needs: making.needs.iter().filter_map(need_line).collect(),
        character_gender: &choices.character_gender,
        treat_user: &choices.treat_user,
        character_words: &choices.character_words,
        cast_genders: &choices.cast_genders,
    };
    let plan = models
        .ask(&Question {
            role: "writer plan",
            system: &plan_system(&choices.treat_user, &choices.character_gender),
            user: &dumps(&profile),
            schema: plan_schema(),
            limit: PLAN_OUT,
            temperature: None,
        })
        .await?;
    let plan = settle_plan(plan, &interview.kinds, &choices);
    let card = card_of(models, &plan, &lines, &interview.kinds, &choices).await?;
    let persona_facts = strings(&plan["persona_lines"]);
    let persona = persona_facts.iter().take(PERSONA_SHOWN).cloned().collect();
    let moments = interview.log.iter().find(|entry| entry.slot == "moments");
    let creation = Creation {
        kinds: interview.kinds.clone(),
        mode: plan["mode"].as_str().unwrap_or_default().to_string(),
        relation: interview.answer("relation").to_string(),
        moments: moments.map(|entry| entry.picks.clone()).unwrap_or_default(),
        needs: making.needs.to_vec(),
        nevers: all_nevers(nevers, &plan),
        private: making.private.clone(),
        persona_facts,
        style: style_name(interview.style).to_string(),
        model: making.model.to_string(),
        question_log,
        plan,
        character_gender: choices.character_gender,
        treat_user: choices.treat_user,
        character_words: choices.character_words,
        cast_genders: choices.cast_genders,
        draw: choices.draw,
        cast_draw: choices.cast_draw,
    };
    let greetings = std::iter::once(card.first_mes).chain(card.alternate_greetings);
    let greetings = greetings.filter(|greeting| !greeting.is_empty()).collect();
    Ok(Written {
        card: NewCard {
            creation: Some(creation),
            title: card.name.clone(),
            tags: Vec::new(),
            creator: String::new(),
            name: card.name,
            greetings,
            description: card.description,
            personality: card.personality,
            scenario: card.scenario,
            example_dialogue: card.mes_example,
            creator_notes: card.creator_notes,
            system_prompt: None,
            post_history: None,
            talkativeness: None,
            picture: None,
        },
        persona,
    })
}

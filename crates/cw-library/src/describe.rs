//! Cards described by the worker model (`provider::for_work`): Circe's
//! classifier picks a card's terms from a fixed vocabulary (`VOCABULARY`), and a
//! second call writes its library title, logline and three-sentence summary
//! (option C). `facts` are what a card's page shows without a model.
//!
//! The prompts are `describe/classify.txt` and `describe/write.txt`. A card goes
//! to both whole, every greeting too, as SillyTavern's JSON (`card_text`); one
//! longer than the worker model reads fails (`fits`). It goes on one spaced line,
//! title first (`describe/sent.rs`): a compact card gets compact answers, whose JSON some
//! models break (glm-5.3 on the needs: 10 of 49, the app's first ten 82 of 107,
//! against 87 on this line; milestone 121). Answers are read field by field
//! (`Facets::read`), "reject" refuses the card, unknown terms are dropped; a
//! logline that copies a greeting is asked once more, then left empty (`copies_a_greeting`).
//!
//! A description is a row of `card_descriptions`: queued, described, refused
//! (never asked again) or failed. A title the user gave (`title_edited`) is never
//! replaced, the user's tags (`own_tags`) and the file's stand after the terms, a summary the
//! user wrote (`summary_edited`) stays, also when described again. The worker is
//! `api/describe.rs`.

use std::sync::LazyLock;

use anyhow::{Context, ensure};
use cw_ccv4::{Document, mapping, tag_key};
use cw_core::{Code, ErrorBody, Fail};
use cw_prompt::{PromptMessage, Role, tokens};
use cw_provider::Http;
use cw_provider::{Provider, answer, object};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use ts_rs::TS;

use crate::failures::{self, Failures};
use crate::posters::{self, Mood};

mod sent;
pub(crate) use sent::{asked_and_read, sent};
pub use sent::{card_json, card_text, fits};

pub const CLASSIFY: &str = include_str!("describe/classify.txt");
pub const WRITE: &str = include_str!("describe/write.txt");

/// The longest title and logline kept, in characters.
const TITLE_LIMIT: usize = 80;
const LINE_LIMIT: usize = 300;
/// A description longer than this, in tokens, is called long on the card's page.
const LONG_DESCRIPTION: usize = 1_500;

/// The classifier's vocabulary, its one list: `classify.txt` has each group
/// where it names it (`{engine}`), and `Facets::tidied` keeps of an answer only
/// the terms of the group a field is of (`known`: "frame" is every `frame-…`
/// group). A term is an entry's first word; what follows is said to the model
/// with it, an engine on a line of its own.
const VOCABULARY: &[(&str, &[&str])] = &[
    (
        "gender",
        &[
            "female",
            "male",
            "nonbinary",
            "trans-female",
            "trans-male",
            "futanari",
            "femboy",
            "nonhuman-ungendered",
            "user-defined",
        ],
    ),
    (
        "age",
        &[
            "young-adult (18-24)",
            "adult (25-39)",
            "mature (40-59)",
            "older (60+)",
        ],
    ),
    (
        "pairing",
        &["for-male-user", "for-female-user", "for-any-user"],
    ),
    (
        "engine",
        &[
            "romance: attraction and relationship progression is the payload.",
            "smut: erotic content is the payload; the scenario exists to enable sex.",
            "power-struggle: control is contested or exercised (dominance, submission, ownership). Sex serving the power dynamic => power-struggle, not smut.",
            "corruption: gradual directional transformation (innocence to depravity, training); power-struggle is static control, corruption is change.",
            "rivalry: competition with non-violent stakes (pride, not blood).",
            "conflict: hostile stakes — enemy, war, captor-hunts-you, violence.",
            "psychological: manipulation, obsession, gaslighting, mind games; yandere's home. No open hostility needed.",
            "mystery: something hidden the chat works to uncover.",
            "survival: scarcity, danger, escape; the world threatens.",
            "adventure: exploration, quests, forward motion; the world invites.",
            "comfort: caretaking, reassurance, healing; emotional safety is the product.",
            "slice-of-life: low-stakes everyday coexistence; no caretaking mandate.",
            "drama: interpersonal fallout (betrayal, grief, divorce); the payload is the fallout, not the falling.",
            "worship: stable devotion asymmetry — char adores/serves user or demands adoration; nothing is contested.",
            "sandbox: world/setting/system card; the user supplies direction.",
            "utility: non-roleplay function (assistant, tutor, text game engine).",
        ],
    ),
    (
        "frame-hierarchy",
        &[
            "boss",
            "subordinate",
            "teacher",
            "student",
            "master",
            "servant",
            "servant-domestic",
            "captor",
            "captive",
            "owner",
            "pet",
            "bodyguard",
            "monarch",
            "knight",
        ],
    ),
    (
        "frame-intimacy",
        &[
            "spouse",
            "partner",
            "ex",
            "crush",
            "admirer",
            "betrothed",
            "stranger",
            "sugar-benefactor",
            "sex-worker",
        ],
    ),
    (
        "frame-kinship",
        &["step-family", "in-law", "guardian", "ward", "found-family"],
    ),
    (
        "frame-social",
        &[
            "friend",
            "childhood-friend",
            "roommate",
            "neighbor",
            "coworker",
            "classmate",
            "rival",
            "enemy",
            "bully",
            "stalker",
            "client",
            "customer",
            "caretaker-medical",
            "patient",
            "landlord",
            "tenant",
            "celebrity",
            "fan",
        ],
    ),
    (
        "frame-otherworldly",
        &[
            "deity", "demon", "angel", "monster", "spirit", "vampire", "shifter", "ai", "alien",
            "summon",
        ],
    ),
    (
        "frame-structural",
        &[
            "narrator (storyteller/GM voice, not a single character)",
            "ensemble (multiple defined characters)",
            "scenario (the product is a premise/situation, not a persona — \"scenario card\", \"setting card\", \"CYOA\"; if one persistent character anchors the premise, use that character's frame)",
            "self-insert-target (user plays the defined character)",
            "none (utility cards without a relationship)",
        ],
    ),
    ("rating", &["sfw", "suggestive", "nsfw", "nsfw-extreme"]),
    (
        "flag-consent",
        &[
            "noncon",
            "dubcon",
            "cnc",
            "somnophilia",
            "mind-control",
            "free-use",
        ],
    ),
    (
        "flag-power",
        &[
            "bdsm",
            "femdom",
            "maledom",
            "pet-play",
            "humiliation",
            "degradation",
            "praise",
            "orgasm-control",
            "chastity",
            "cbt",
            "spanking/impact",
        ],
    ),
    (
        "flag-body",
        &[
            "size-difference",
            "breeding",
            "pregnancy",
            "lactation",
            "oviposition",
            "tentacles",
            "monster-sex",
            "group",
            "exhibitionism",
            "voyeurism",
            "feet",
            "watersports",
            "transformation",
            "futa-content",
            "incest-themes",
        ],
    ),
    (
        "flag-relational",
        &["netorare", "netori", "netorase", "age-gap", "yandere"],
    ),
    (
        "flag-dark",
        &[
            "violence",
            "gore",
            "torture",
            "death",
            "abuse-themes",
            "self-harm-themes",
            "substance-use",
            "body-horror",
            "psychological-abuse",
        ],
    ),
    (
        "archetype",
        &[
            "hot-cold",
            "stoic",
            "shy",
            "openly-loving",
            "yandere",
            "grump",
            "sunny",
            "brooding",
            "dangerous-seducer",
            "entitled-royal",
            "refined-aristocrat",
            "teasing-sadist",
            "provocative-brat",
            "lovable-fool",
            "gentle-giant",
            "next-door",
            "rebel",
            "nerd",
            "caretaker",
            "trickster",
            "animal-eared",
            "gyaru",
            "tomboy",
            "clingy",
            "maternal",
        ],
    ),
];

/// The term an entry of the vocabulary stands for: its first word.
fn term(entry: &str) -> &str {
    entry.split([' ', ':']).next().unwrap_or_default()
}

/// Whether `word` is of the vocabulary's `group`, or of a group `group-…`.
fn known(group: &str, word: &str) -> bool {
    VOCABULARY
        .iter()
        .filter(|(name, _)| name.split('-').next() == Some(group))
        .any(|(_, entries)| entries.iter().any(|entry| term(entry) == word))
}

/// The classifier's prompt: `classify.txt` with the vocabulary's groups in their places.
fn classify() -> &'static str {
    static PROMPT: LazyLock<String> = LazyLock::new(|| {
        VOCABULARY
            .iter()
            .fold(CLASSIFY.to_string(), |prompt, (name, entries)| {
                let lines = entries.iter().any(|entry| entry.contains(':'));
                prompt.replace(
                    &format!("{{{name}}}"),
                    &entries.join(if lines { "\n  " } else { ", " }),
                )
            })
    });
    &PROMPT
}

/// How far the describing of a user's cards has come.
#[derive(Debug, Serialize, TS)]
#[ts(export)]
pub struct Describing {
    /// Cards queued that the worker model has yet to describe, those in the Trash aside.
    pub waiting: usize,
    /// Cards "Describe characters" would queue: those not in the Trash that have no
    /// description and were not refused, the failed ones among them.
    pub left: usize,
    /// Cards whose describing failed.
    pub failed: usize,
    /// Why the last of those failed, as the UI words it.
    pub failure: Option<ErrorBody>,
}

/// What the card's page says of a character without a model: the facts by
/// which a card is judged (the plan's quality checks).
#[derive(Debug, Default, Serialize, TS)]
#[ts(export)]
pub struct Facts {
    pub example_dialogue: bool,
    /// How many greetings a chat can open with.
    pub greetings: usize,
    /// Whether the first greeting writes what the user says or does: a line
    /// that begins `{{user}}:`, or `{{user}}` before a word that ends in -s or
    /// -ed ("{{user}} walks in").
    pub(crate) speaks_for_user: bool,
    /// An estimate of the tokens of the character's texts that go with every
    /// message: the system prompt, description, personality, scenario, example
    /// dialogue and the instructions after the chat.
    pub(crate) permanent_tokens: usize,
    /// Whether the description alone is over 1,500 tokens.
    pub(crate) long_description: bool,
}

/// The facts of the character `id` of `document`.
pub fn facts(document: &Document, id: &str) -> Facts {
    let Some(texts) = mapping::character(document, id) else {
        return Facts::default();
    };
    let greetings = document.greetings(id, false);
    let permanent = [
        &texts.system_prompt,
        &texts.description,
        &texts.personality,
        &texts.scenario,
        &texts.mes_example,
        &texts.post_history_instructions,
    ];
    Facts {
        example_dialogue: !texts.mes_example.trim().is_empty(),
        speaks_for_user: greetings
            .first()
            .is_some_and(|first| speaks_for_user(first)),
        greetings: greetings.len(),
        permanent_tokens: permanent.iter().map(|text| tokens::estimate(text)).sum(),
        long_description: tokens::estimate(&texts.description) > LONG_DESCRIPTION,
    }
}

/// Words after `{{user}}` that end in -s or -ed and say what is, not what the user does.
const NOT_DONE: &[&str] = &["was", "has", "does", "his", "this", "is", "as", "us"];

fn speaks_for_user(greeting: &str) -> bool {
    let lower = greeting.to_lowercase();
    if lower
        .lines()
        .any(|line| line.trim_start().starts_with("{{user}}:"))
    {
        return true;
    }
    lower.split("{{user}}").skip(1).any(|after| {
        let Some(rest) = after.strip_prefix(' ') else {
            return false;
        };
        let word: String = rest.chars().take_while(|c| c.is_alphabetic()).collect();
        word.len() > 2
            && (word.ends_with('s') || word.ends_with("ed"))
            && !NOT_DONE.contains(&word.as_str())
    })
}

/// What the classifier answered, as far as it is read.
#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Facets {
    verdict: String,
    reject_reason: String,
    characters: Vec<Person>,
    pairing: String,
    engine: String,
    multi_mode: bool,
    per_greeting: Vec<Value>,
    frame: String,
    frame_display: String,
    rating: String,
    content_flags: Vec<String>,
    archetype: Vec<String>,
    mechanism: String,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct Person {
    name: String,
    gender: String,
    age: String,
}

/// A text field of an answer; anything else there counts as none.
fn text(answer: &Value, key: &str) -> String {
    answer[key].as_str().unwrap_or_default().to_string()
}

/// A list of texts of an answer, without what is no text.
fn texts(answer: &Value, key: &str) -> Vec<String> {
    let items = answer[key]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    items
        .iter()
        .filter_map(|item| item.as_str().map(str::to_string))
        .collect()
}

impl Facets {
    /// The classifier's answer read field by field.
    fn read(answer: &Value) -> Self {
        let characters = answer["characters"].as_array().map(Vec::as_slice);
        Self {
            verdict: text(answer, "verdict"),
            reject_reason: text(answer, "reject_reason"),
            characters: characters
                .unwrap_or_default()
                .iter()
                .map(|person| Person {
                    name: text(person, "name"),
                    gender: text(person, "gender"),
                    age: text(person, "age"),
                })
                .collect(),
            pairing: text(answer, "pairing"),
            engine: text(answer, "engine"),
            multi_mode: answer["multi_mode"].as_bool().unwrap_or_default(),
            per_greeting: answer["per_greeting"]
                .as_array()
                .cloned()
                .unwrap_or_default(),
            frame: text(answer, "frame"),
            frame_display: text(answer, "frame_display"),
            rating: text(answer, "rating"),
            content_flags: texts(answer, "content_flags"),
            archetype: texts(answer, "archetype"),
            mechanism: text(answer, "mechanism"),
        }
    }

    /// The facets with what is not of the vocabulary left out. A rating is
    /// needed: it is what filters a card.
    fn tidied(mut self) -> anyhow::Result<Self> {
        let keep = |group: &str, term: &mut String| {
            *term = term.trim().to_lowercase();
            if !known(group, term) {
                term.clear();
            }
        };
        keep("rating", &mut self.rating);
        ensure!(
            !self.rating.is_empty(),
            Fail::said(
                Code::ModelAnswer,
                "the worker model's classification has no rating"
            )
            .with("what", "rating")
        );
        keep("engine", &mut self.engine);
        keep("frame", &mut self.frame);
        keep("pairing", &mut self.pairing);
        let only = |group: &str, terms: &mut Vec<String>, most: usize| {
            let mut kept: Vec<String> = Vec::new();
            for term in terms.iter().map(|term| term.trim().to_lowercase()) {
                if known(group, &term) && !kept.contains(&term) && kept.len() < most {
                    kept.push(term);
                }
            }
            *terms = kept;
        };
        only("flag", &mut self.content_flags, usize::MAX);
        only("archetype", &mut self.archetype, 2);
        for person in &mut self.characters {
            keep("gender", &mut person.gender);
            keep("age", &mut person.age);
        }
        // The frame as the card's gender inflects it: a word or two, else the frame.
        let display = self.frame_display.trim().to_lowercase();
        let fits = !display.is_empty()
            && display.len() <= 24
            && display.split_whitespace().count() <= 2
            && display
                .chars()
                .all(|c| c.is_alphabetic() || c == ' ' || c == '-');
        self.frame_display = if fits && !self.frame.is_empty() {
            display
        } else {
            self.frame.clone()
        };
        Ok(self)
    }

    /// The rating and the content flags: the content level, shown as chips.
    fn content(&self) -> Vec<String> {
        let mut content = vec![self.rating.clone()];
        content.extend(self.content_flags.iter().cloned());
        content
    }

    /// The terms the library shows as the card's tags.
    fn shown(&self) -> Vec<String> {
        let frame =
            (!self.frame.is_empty() && self.frame != "none").then(|| self.frame_display.clone());
        let mut shown: Vec<String> = frame.into_iter().collect();
        shown.extend((!self.engine.is_empty()).then(|| self.engine.clone()));
        shown.extend(self.archetype.iter().cloned());
        shown.extend(self.content());
        shown
    }

    /// What a search finds the card by beside its tags, lower case.
    fn searched(&self) -> String {
        let mut terms = self.shown();
        terms.push(self.frame.clone());
        terms.push(self.pairing.clone());
        for person in &self.characters {
            terms.push(person.gender.clone());
            terms.push(person.age.clone());
        }
        terms.retain(|term| !term.is_empty());
        terms.join("\n")
    }
}

/// What came of asking the worker model about one card.
#[derive(Debug)]
pub enum Outcome {
    Described {
        facets: Box<Facets>,
        title: String,
        logline: String,
        summary: String,
        tagline: String,
        mood: Option<Mood>,
    },
    /// The classifier's verdict "reject", with its reason.
    Refused(String),
}

/// What `{{user}}` may read as in a logline that copies a greeting.
const USER_AS: [&str; 3] = ["you", "user", "the user"];

/// `greeting` with `{{char}}` as `name` and `{{user}}` as `user`, whatever their case.
fn named(greeting: &str, name: &str, user: &str) -> String {
    let is = |rest: &str, mark: &str| {
        rest.get(..mark.len())
            .is_some_and(|it| it.eq_ignore_ascii_case(mark))
    };
    let mut out = String::new();
    let mut at = 0;
    while at < greeting.len() {
        let rest = &greeting[at..];
        if is(rest, "{{char}}") {
            out.push_str(name);
            at += "{{char}}".len();
        } else if is(rest, "{{user}}") {
            out.push_str(user);
            at += "{{user}}".len();
        } else {
            let c = rest.chars().next().unwrap_or(' ');
            out.push(c);
            at += c.len_utf8();
        }
    }
    out
}

/// Whether `logline` is a greeting of `card` (`card_text`), or its start where
/// the logline was cut: by its words alone, whatever their case and marks, its
/// `{{char}}` as the character's name and `{{user}}` as any of [`USER_AS`].
fn copies_a_greeting(card: &str, logline: &str) -> bool {
    let words = |text: &str| -> String {
        text.split(|c: char| !c.is_alphanumeric())
            .filter(|word| !word.is_empty())
            .collect::<Vec<_>>()
            .join(" ")
            .to_lowercase()
    };
    let logline = words(logline);
    let Ok(card) = serde_json::from_str::<Value>(card) else {
        return false;
    };
    let characters = card["characters"].as_array().cloned().unwrap_or_default();
    !logline.is_empty()
        && characters.iter().any(|character| {
            let others = character["alternate_greetings"].as_array().cloned();
            let name = character["name"].as_str().unwrap_or_default();
            std::iter::once(character["first_mes"].clone())
                .chain(others.unwrap_or_default())
                .filter_map(|greeting| greeting.as_str().map(str::to_string))
                .any(|greeting| {
                    USER_AS
                        .iter()
                        .any(|user| words(&named(&greeting, name, user)).starts_with(&logline))
                })
        })
}

/// Asks the provider's model to classify the card and, unless it refuses the
/// card, to write its texts.
pub async fn ask(http: &Http, provider: &Provider, card: &str) -> anyhow::Result<Outcome> {
    fits(provider, classify(), card)?;
    let classify = [
        PromptMessage::new(Role::System, classify()),
        PromptMessage::new(
            Role::User,
            format!("<card_to_classify>\n{card}\n</card_to_classify>"),
        ),
    ];
    let rejected = |facets: &Facets| facets.verdict.trim().to_lowercase().starts_with("reject");
    let facets = asked_and_read(http, provider, &classify, |said| {
        let facets = Facets::read(
            &object(said).context(
                Fail::said(
                    Code::ModelAnswer,
                    "the worker model's classification cannot be read",
                )
                .with("what", "classification"),
            )?,
        );
        if rejected(&facets) {
            Ok(facets)
        } else {
            facets.tidied()
        }
    })
    .await?;
    if rejected(&facets) {
        let reason = facets.reject_reason.trim();
        return Ok(Outcome::Refused(if reason.is_empty() {
            "the card was refused".into()
        } else {
            reason.chars().take(LINE_LIMIT).collect()
        }));
    }
    let write = [
        PromptMessage::new(Role::System, WRITE),
        PromptMessage::new(
            Role::User,
            format!(
                "<card>\n{card}\n</card>\n<facets>\n{}\n</facets>",
                sent(&facets)?
            ),
        ),
    ];
    let line = |text: &str, most: usize| -> String {
        text.split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
            .chars()
            .take(most)
            .collect()
    };
    let read = |said: &str| {
        let written = object(said).context(
            Fail::said(Code::ModelAnswer, "the worker model's texts cannot be read")
                .with("what", "worker_texts"),
        )?;
        let logline = line(&text(&written, "logline"), LINE_LIMIT);
        ensure!(
            !logline.is_empty(),
            Fail::said(Code::ModelAnswer, "the worker model wrote no logline")
                .with("what", "logline")
        );
        Ok((written, logline))
    };
    let (mut written, mut logline) = asked_and_read(http, provider, &write, read).await?;
    if copies_a_greeting(card, &logline) {
        // Asked once more; a second copy, or a second answer that fails, keeps the first without its logline.
        match answer(http, provider, &write)
            .await
            .and_then(|said| read(&said))
        {
            Ok((again, line)) if !copies_a_greeting(card, &line) => {
                (written, logline) = (again, line)
            }
            _ => logline.clear(),
        }
    }
    Ok(Outcome::Described {
        facets: Box::new(facets),
        title: line(&text(&written, "title"), TITLE_LIMIT),
        logline,
        summary: text(&written, "summary").trim().to_string(),
        tagline: posters::tagline(&text(&written, "tagline")),
        mood: Mood::read(&text(&written, "mood")),
    })
}

/// What describing a card came to, as it is stored.
pub enum Stored {
    /// Its tags and facets as JSON, the words it is found by, and what the
    /// worker model wrote of it.
    Described {
        tags: String,
        terms: String,
        facets: String,
        title: String,
        logline: String,
        summary: String,
        /// Empty where the model wrote none that fits (`poster`).
        tagline: String,
        /// A [`Mood`]'s word, or empty.
        mood: String,
    },
    /// "refused" or "failed", with the reason.
    Ended(&'static str, String),
}

/// What describing cards needs of the database, which `cw_store::describe` gives.
pub trait Storage: crate::failures::Failures {
    /// As [`queue`] says: how many were queued.
    fn queue_descriptions(&self, user: i64, only: Option<i64>) -> anyhow::Result<usize>;
    fn describing(&self, user: i64) -> anyhow::Result<Describing>;
    /// As [`next`] says.
    fn next_to_describe(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>>;
    /// Stores what describing the card's version came to, the title where it
    /// is one the user did not give, at once.
    fn keep_description(&self, card_id: i64, version_id: i64, stored: Stored)
    -> anyhow::Result<()>;
    fn fail_waiting_descriptions(&self, user: i64, reason: &str) -> anyhow::Result<()>;
    fn forget_queued_descriptions(&self) -> anyhow::Result<()>;
    /// Drops the user's cards that wait to be described, and their needs that wait; `in_hand`, the card the
    /// worker has, stays to finish.
    fn stop_describing(&self, user: i64, in_hand: Option<i64>) -> anyhow::Result<()>;
    /// The summary and facets (JSON) of a card that is described.
    fn description(&self, card_id: i64) -> anyhow::Result<Option<(String, String)>>;
    /// How many cards it gave the summary: none where it is not described.
    fn set_card_summary(&self, card_id: i64, summary: &str) -> anyhow::Result<usize>;
}

/// Queues the user's cards not in the Trash that have no description or a
/// failed one; with `only`, of those that one alone. Answers how many were
/// queued.
pub fn queue(db: &dyn Storage, user: i64, only: Option<i64>) -> anyhow::Result<usize> {
    db.queue_descriptions(user, only)
}

/// Stops "Describe characters": what waits is dropped; `in_hand`, the card a worker has, finishes.
pub fn stop(db: &dyn Storage, user: i64, in_hand: Option<i64>) -> anyhow::Result<()> {
    db.stop_describing(user, in_hand)
}

/// How far the describing of the user's cards has come.
pub fn progress(db: &dyn Storage, user: i64) -> anyhow::Result<Describing> {
    db.describing(user)
}

/// The card the worker takes next: the user's oldest queued, with its newest
/// version. A card put in the Trash while it waited is let go: out of it, it
/// waits for "Describe cards" again.
pub fn next(db: &dyn Storage, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
    db.next_to_describe(user)
}

/// Stores what came of describing the version `version_id` of the card.
pub fn keep(
    db: &dyn Storage,
    card_id: i64,
    version_id: i64,
    outcome: anyhow::Result<Outcome>,
) -> anyhow::Result<()> {
    db.keep_description(card_id, version_id, stored(db, outcome))
}

/// What came of describing, as it is stored.
pub(crate) fn stored(db: &dyn Failures, outcome: anyhow::Result<Outcome>) -> Stored {
    match outcome {
        Ok(Outcome::Described {
            facets,
            title,
            logline,
            summary,
            tagline,
            mood,
        }) => Stored::Described {
            tags: json!(facets.shown()).to_string(),
            terms: format!("{}\n{}", title.to_lowercase(), facets.searched()),
            facets: serde_json::to_string(&facets).unwrap_or_default(),
            title,
            logline,
            summary,
            tagline,
            mood: mood.map(Mood::word).unwrap_or_default().to_string(),
        },
        Ok(Outcome::Refused(reason)) => Stored::Ended("refused", reason),
        Err(failure) => Stored::Ended("failed", kept_failure(db, &failure)),
    }
}

/// Why a card's describing failed, as it is kept: its [`ErrorBody`] as JSON, `error` cut to a line.
pub fn kept_failure(store: &dyn Failures, failure: &anyhow::Error) -> String {
    let mut body = failures::told(store, failure, Code::DescribingFailed);
    body.error = body.error.chars().take(LINE_LIMIT).collect();
    serde_json::to_string(&body).unwrap_or_default()
}

/// Fails every queued card of the user with `reason` (a [`kept_failure`]): there is no model to ask.
pub fn fail_waiting(db: &dyn Storage, user: i64, reason: &str) -> anyhow::Result<()> {
    db.fail_waiting_descriptions(user, reason)
}

/// Drops what is queued: when the server starts nothing works on it.
pub fn forget_unfinished(db: &dyn Storage) -> anyhow::Result<()> {
    db.forget_queued_descriptions()
}

/// What a card's page shows of its description: the summary and the content
/// level. Empty for a card not described.
pub fn of_card(db: &dyn Storage, card_id: i64) -> anyhow::Result<(String, Vec<String>)> {
    let found = db.description(card_id)?;
    Ok(found.map_or_else(Default::default, |(summary, facets)| {
        let facets: Facets = serde_json::from_str(&facets).unwrap_or_default();
        let content = if facets.rating.is_empty() {
            Vec::new()
        } else {
            facets.content()
        };
        (summary, content)
    }))
}

/// Gives the described card `card_id` the summary `summary`, as the user
/// wrote it on the card's page; it stays when the card is described again.
/// Refused: an empty summary, and a card not described, which has none.
pub fn set_summary(db: &dyn Storage, card_id: i64, summary: &str) -> anyhow::Result<()> {
    let summary = summary.trim();
    ensure!(
        !summary.is_empty(),
        Fail::said(Code::Needed, "a summary needs words").with("what", "summary")
    );
    let changed = db.set_card_summary(card_id, summary)?;
    ensure!(
        changed == 1,
        Fail::said(Code::NotPossible, "the card has no summary yet").with("what", "no_summary")
    );
    Ok(())
}

/// The tags a user wrote as they are after an edit from the tags `before` to
/// `after`: those kept of `own`, and those the edit added.
pub(crate) fn own_after(own: &[String], before: &[String], after: &[String]) -> Vec<String> {
    let has = |tags: &[String], tag: &str| tags.iter().any(|one| tag_key(one) == tag_key(tag));
    after
        .iter()
        .filter(|tag| has(own, tag) || !has(before, tag))
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every group of the vocabulary has its place in the classifier's prompt, and no place is left unfilled.
    #[test]
    fn the_classifier_is_told_every_term_it_may_answer() {
        let prompt = classify();
        for (name, entries) in VOCABULARY {
            assert!(!prompt.contains(&format!("{{{name}}}")), "{name}");
            assert!(entries.iter().all(|entry| prompt.contains(entry)), "{name}");
        }
        let marks = CLASSIFY.matches('{').count() - prompt.matches('{').count();
        assert_eq!(marks, VOCABULARY.len());
        assert!(known("frame", "self-insert-target") && known("flag", "spanking/impact"));
        assert!(known("age", "older") && !known("age", "unspecified") && !known("frame", "frame"));
    }

    #[test]
    fn a_logline_that_copies_a_greeting_is_no_logline() {
        let card = r#"{"characters": [{"first_mes": "*She looks up.* Course plotted. Coffee is in the galley, captain.", "alternate_greetings": ["Morning."]}]}"#;
        assert!(copies_a_greeting(
            card,
            "She looks up. Course plotted. Coffee is in the galley, captain."
        ));
        assert!(copies_a_greeting(card, "Morning"));
        assert!(!copies_a_greeting(
            card,
            "A ship's navigator who keeps the coffee hot."
        ));
    }

    #[test]
    fn a_greeting_is_compared_with_its_names_in_place() {
        let card =
            r#"{"characters": [{"name": "Mira", "first_mes": "{{char}} hands {{User}} a cup."}]}"#;
        assert!(copies_a_greeting(card, "Mira hands you a cup."));
        assert!(copies_a_greeting(card, "Mira hands the user a cup."));
        assert!(!copies_a_greeting(card, "Mira hands nobody a cup."));
    }
}

//! Extras › Character generator: a card made from a few picks ([`GeneratorPicks`]), as
//! Circe's generator does (`circe/memory-bank/card-creation/generator-logic.md`),
//! with the picks the design draws. A look left "Any" is picked at random first
//! ([`GeneratorPicks::looks`]), so the card is whole. Two stages: the description, personality
//! and scenario are composed from the picks without a model ([`description`],
//! [`personality`], [`scenario`]), and one call to the chat model (the
//! stronger one, as the card is kept for good) writes the greeting and the
//! example messages from them and from how the character talks ([`rubric`]),
//! by the prompt `generator/write.txt` ([`prompt`]). [`make`] answers the card
//! for `cards::create`; nothing is stored before the model has answered.
//!
//! A slider is 0 to 100, its first word at 0: within 10 of the middle it says
//! nothing; further out "somewhat", "quite" and "extremely" in the prose, and
//! "a little" or not in how it talks (two levels, as a few lines of talk show
//! no finer ones). Trap: the model is told to write `{{char}}` and `{{user}}`,
//! and its examples become `<START>` blocks here, not as it writes them.

use anyhow::{Context, bail, ensure};
use cw_ccv4::new::NewCard;
use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::Provider;
use rand::Rng;
use serde::Deserialize;
use serde_json::Value;
use ts_rs::TS;

/// The prompt for the greeting and the example messages.
pub const WRITE: &str = include_str!("generator/write.txt");

/// The character's gender, which says how it is spoken of.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub enum Gender {
    Woman,
    Man,
    #[serde(rename = "Non-binary")]
    NonBinary,
}

/// Whether the character is human; one who is not keeps its gender's pronouns.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub enum Being {
    Human,
    #[serde(rename = "Not human")]
    NotHuman,
}

#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub(crate) enum Age {
    #[serde(rename = "20s")]
    Twenties,
    #[serde(rename = "30s")]
    Thirties,
    #[serde(rename = "40s")]
    Forties,
    #[serde(rename = "50s and older")]
    Older,
}

#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub enum Build {
    Slim,
    Average,
    Athletic,
    Strong,
}

#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub(crate) enum Hair {
    Short,
    Medium,
    Long,
}

#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub(crate) enum HairColour {
    Black,
    Brown,
    Blonde,
    Red,
    Grey,
    White,
}

/// How the character relates to the user.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[ts(export)]
pub enum Relationship {
    Stranger,
    Friend,
    Partner,
    Rival,
    Colleague,
    Mentor,
}

/// The generator's picks. A look left `null` is "Any", picked at random by
/// [`GeneratorPicks::looks`]. Each slider is 0 to 100, at 0 its first word.
#[derive(Debug, Deserialize, TS)]
#[ts(export)]
pub struct GeneratorPicks {
    pub(crate) gender: Option<Gender>,
    pub(crate) being: Option<Being>,
    pub(crate) age: Option<Age>,
    pub(crate) build: Option<Build>,
    pub(crate) hair: Option<Hair>,
    pub(crate) hair_colour: Option<HairColour>,
    pub(crate) shy_outgoing: u8,
    pub(crate) gentle_harsh: u8,
    pub(crate) serious_playful: u8,
    pub(crate) cautious_bold: u8,
    pub(crate) relationship: Relationship,
    /// The character's name, which is the card's title too.
    pub name: String,
    /// Who made the card (the account's name); empty to say nothing.
    pub creator: String,
}

/// A slider's two words, with what each says of how the character talks.
struct Axis {
    low: &'static str,
    high: &'static str,
    talks_low: &'static str,
    talks_high: &'static str,
}

const AXES: [Axis; 4] = [
    Axis {
        low: "shy",
        high: "outgoing",
        talks_low: "speaks briefly, hedges and waits to be drawn out",
        talks_high: "starts talk, says more than asked and asks questions",
    },
    Axis {
        low: "gentle",
        high: "harsh",
        talks_low: "speaks softly and kindly, careful of feelings",
        talks_high: "is blunt and cutting, and does not soften a word",
    },
    Axis {
        low: "serious",
        high: "playful",
        talks_low: "is earnest and literal, and stays on topic",
        talks_high: "teases, banters and jokes",
    },
    Axis {
        low: "cautious",
        high: "bold",
        talks_low: "weighs each step and avoids risks",
        talks_high: "is decisive and direct, and takes the lead",
    },
];

impl GeneratorPicks {
    fn sliders(&self) -> [u8; 4] {
        [
            self.shy_outgoing,
            self.gentle_harsh,
            self.serious_playful,
            self.cautious_bold,
        ]
    }

    /// The looks picked, each "Any" taken from its values at `choose(count)`,
    /// an index below `count` (at random in [`make`]; fixed in a test).
    pub fn looks(&self, mut choose: impl FnMut(usize) -> usize) -> Looks {
        fn pick<T: Copy>(set: Option<T>, all: &[T], choose: &mut impl FnMut(usize) -> usize) -> T {
            set.unwrap_or_else(|| all[choose(all.len())])
        }
        use {Age::*, Being::*, Build::*, Gender::*, Hair::*, HairColour::*};
        Looks {
            gender: pick(self.gender, &[Woman, Man, NonBinary], &mut choose),
            being: pick(self.being, &[Human, NotHuman], &mut choose),
            age: pick(self.age, &[Twenties, Thirties, Forties, Older], &mut choose),
            build: pick(self.build, &[Slim, Average, Athletic, Strong], &mut choose),
            hair: pick(self.hair, &[Short, Medium, Long], &mut choose),
            hair_colour: pick(
                self.hair_colour,
                &[Black, Brown, Blonde, Red, Grey, White],
                &mut choose,
            ),
        }
    }
}

/// The character's looks, each "Any" of the picks resolved.
#[derive(Debug)]
pub struct Looks {
    gender: Gender,
    being: Being,
    age: Age,
    build: Build,
    hair: Hair,
    hair_colour: HairColour,
}

impl Looks {
    /// The pronouns the character is spoken of by: subject, possessive.
    fn pronouns(&self) -> (&'static str, &'static str) {
        match self.gender {
            Gender::Woman => ("she/her", "her"),
            Gender::Man => ("he/him", "his"),
            Gender::NonBinary => ("they/them", "their"),
        }
    }
}

/// Each slider's word and how far from the middle it is (1 to 3), where it is
/// more than 10 from the middle: the slider's side, and its strength.
fn traits(picks: &GeneratorPicks) -> Vec<(&'static Axis, bool, u8)> {
    AXES.iter()
        .zip(picks.sliders())
        .filter_map(|(axis, value)| {
            let off = (i16::from(value) - 50).unsigned_abs();
            let strength = match off {
                0..=10 => return None,
                11..=25 => 1,
                26..=40 => 2,
                _ => 3,
            };
            Some((axis, value > 50, strength))
        })
        .collect()
}

/// The card's description: its looks, in one sentence that says how it is spoken of.
pub fn description(looks: &Looks) -> String {
    let (pronouns, their) = looks.pronouns();
    let age = match looks.age {
        Age::Twenties => format!("in {their} twenties"),
        Age::Thirties => format!("in {their} thirties"),
        Age::Forties => format!("in {their} forties"),
        Age::Older => "fifty or older".to_string(),
    };
    let what = match (looks.being, looks.gender) {
        (Being::Human, Gender::Woman) => format!("a woman ({pronouns}) {age}"),
        (Being::Human, Gender::Man) => format!("a man ({pronouns}) {age}"),
        (Being::Human, Gender::NonBinary) => format!("non-binary ({pronouns}), {age}"),
        (Being::NotHuman, gender) => {
            let gender = match gender {
                Gender::Woman => "female",
                Gender::Man => "male",
                Gender::NonBinary => "non-binary",
            };
            format!("not human, {gender} ({pronouns}), looking {age}")
        }
    };
    let build = match looks.build {
        Build::Slim => "slim",
        Build::Average => "of average build",
        Build::Athletic => "athletic",
        Build::Strong => "strongly built",
    };
    let hair = format!("{:?}", looks.hair).to_lowercase();
    let colour = format!("{:?}", looks.hair_colour).to_lowercase();
    format!("{{{{char}}}} is {what}, {build}, with {hair} {colour} hair.")
}

/// The card's personality: the sliders off the middle, each with how strongly.
pub fn personality(picks: &GeneratorPicks) -> String {
    let words: Vec<String> = traits(picks)
        .into_iter()
        .map(|(axis, high, strength)| {
            let word = if high { axis.high } else { axis.low };
            let how = ["somewhat", "quite", "extremely"][usize::from(strength - 1)];
            format!("{how} {word}")
        })
        .collect();
    match words.as_slice() {
        [] => "{{char}} keeps to the middle in everything: neither shy nor outgoing, gentle nor harsh, serious nor playful, cautious nor bold.".to_string(),
        [one] => format!("{{{{char}}}} is {one}."),
        [first @ .., last] => format!("{{{{char}}}} is {} and {last}.", first.join(", ")),
    }
}

/// The card's scenario: how the character relates to the user.
pub fn scenario(relationship: Relationship) -> &'static str {
    match relationship {
        Relationship::Stranger => {
            "{{char}} and {{user}} have just met: they are strangers to each other."
        }
        Relationship::Friend => {
            "{{char}} is {{user}}'s friend: they know each other well and are at ease together."
        }
        Relationship::Partner => "{{char}} is {{user}}'s romantic partner: they share their lives.",
        Relationship::Rival => {
            "{{char}} is {{user}}'s rival, a competitor who keeps {{user}} on their toes."
        }
        Relationship::Colleague => {
            "{{char}} is {{user}}'s colleague: they work together every day."
        }
        Relationship::Mentor => "{{char}} is {{user}}'s mentor, who teaches and guides {{user}}.",
    }
}

/// How the character talks, for the model alone: each slider off the middle,
/// "a little" where it is near.
pub fn rubric(picks: &GeneratorPicks) -> String {
    let lines: Vec<String> = traits(picks)
        .into_iter()
        .map(|(axis, high, strength)| {
            let talks = if high {
                axis.talks_high
            } else {
                axis.talks_low
            };
            if strength == 1 {
                format!("a little: {talks}")
            } else {
                talks.to_string()
            }
        })
        .collect();
    if lines.is_empty() {
        "even and plain, neither one way nor the other.".to_string()
    } else {
        format!("{}.", lines.join("; "))
    }
}

/// The prompt for the greeting and the example messages.
pub fn prompt(picks: &GeneratorPicks, looks: &Looks) -> Vec<PromptMessage> {
    let system = WRITE
        .replace("{description}", &description(looks))
        .replace("{personality}", &personality(picks))
        .replace("{scenario}", scenario(picks.relationship))
        .replace("{rubric}", &rubric(picks));
    vec![
        PromptMessage::new(Role::System, system),
        PromptMessage::new(
            Role::User,
            "Write the card's greeting and example messages.",
        ),
    ]
}

/// A text of the model's answer, trimmed; `what` names it where it is missing.
fn text(answer: &Value, key: &str, what: &str) -> anyhow::Result<String> {
    let text = answer[key].as_str().unwrap_or_default().trim();
    ensure!(
        !text.is_empty(),
        Fail::said(Code::ModelAnswer, format!("the model wrote no {what}"))
            .with("what", format!("no_{}", what.replace(' ', "_")))
    );
    Ok(text.to_string())
}

/// The greeting and the example messages (as `<START>` blocks) of the model's answer.
pub fn read(answer: &str) -> anyhow::Result<(String, String)> {
    let answer = cw_provider::object(answer).context(
        Fail::said(
            Code::ModelAnswer,
            "the model's answer was not the card's texts",
        )
        .with("what", "card_texts"),
    )?;
    let greeting = text(&answer, "greeting", "greeting")?;
    let examples = answer["examples"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    let blocks = examples
        .iter()
        .map(|pair| {
            let user = text(pair, "user", "example message")?;
            let char = text(pair, "char", "example message")?;
            Ok(format!(
                "<START>\n{{{{user}}}}: {user}\n{{{{char}}}}: {char}"
            ))
        })
        .collect::<anyhow::Result<Vec<_>>>()?;
    if blocks.is_empty() {
        bail!(
            Fail::said(Code::ModelAnswer, "the model wrote no example messages")
                .with("what", "example_messages")
        );
    }
    Ok((greeting, blocks.join("\n")))
}

/// The card of `picks`, its greeting and example messages written by `provider`'s model.
pub async fn make(
    http: &Http,
    provider: &Provider,
    picks: GeneratorPicks,
) -> anyhow::Result<NewCard> {
    let name = picks.name.trim().to_string();
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "the character needs a name").with("what", "character_name")
    );
    let sliders = picks.sliders();
    ensure!(
        sliders.iter().all(|value| *value <= 100),
        Fail::said(Code::OutOfRange, "a slider goes from 0 to 100").with("what", "slider")
    );
    let looks = {
        let mut rng = rand::rng();
        picks.looks(|count| rng.random_range(0..count))
    };
    let answer = cw_provider::answer(http, provider, &prompt(&picks, &looks)).await?;
    let (greeting, example_dialogue) = read(&answer)?;
    Ok(NewCard {
        creation: None,
        title: name.clone(),
        tags: Vec::new(),
        creator: picks.creator.trim().to_string(),
        name,
        greetings: vec![greeting],
        description: description(&looks),
        personality: personality(&picks),
        scenario: scenario(picks.relationship).to_string(),
        example_dialogue,
        creator_notes: String::new(),
        system_prompt: None,
        post_history: None,
        talkativeness: None,
        picture: None,
    })
}

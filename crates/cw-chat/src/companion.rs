//! The companion's animator, the AI that steers the figure (the provider is
//! the caller's), told who the character is, its card's content level, what
//! the figure stands on, what Cardwave's window shows, what was said last in
//! the companion's chat, what its chat's memory holds (`remembered`), what it
//! did and said in its bubble lately (`told`) and why it is asked now
//! (`Occasion`: after a reply, after the hand handled it, after a touch of a
//! part of its body, or now and then while left alone), answers what the
//! figure does next, as steps the companion window runs
//! (web/src/companion/live.ts). Only the companion's card and its chats are
//! steered by (`question`), as its card's character (also in a group chat
//! begun with another card); the settings are `settings::Companion`.
//! What the model answers is never trusted: a step that cannot be read or run
//! is left out, each kept one held within the screen and the limits (`keep`,
//! `held`, for other programs' steps too). The steps are also the companion's
//! actions, and its state what it knows (`live`).

use anyhow::Context;
use cw_core::{Code, Fail};
use cw_library::cards;
use cw_library::settings;
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::Provider;
use cw_provider::{answer, object};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use ts_rs::TS;

use crate::{assistant, chats, memory};

mod live;
mod told;
pub use live::{AppScreen, ChatShown, CompanionAct, CompanionFigure, CompanionState, Point, Said};
pub use told::{BodyPart, Bubbled, Bubbles, bubble_note, lately};

/// The animator's question, its `{clips}` the list `CLIPS` (`animator`); a test's stand-in for the provider tells it
/// by its first words.
pub const ANIMATE: &str = include_str!("companion/animate.txt");
/// Every clip of `Clip::ALL` in its order, a line `name: what it shows`; written by hand, to fit each version of the
/// clip the figure may play.
const CLIPS: &str = include_str!("companion/clips.txt");
/// `ANIMATE` with the clips and what each shows.
fn animator() -> String {
    ANIMATE.replace("{clips}", CLIPS.trim_end())
}

/// The newest messages the animator reads.
const NEWEST: usize = 4;
/// The longest a message is shown to it, in characters.
const MESSAGE_LIMIT: usize = 600;
/// The most steps kept of an answer.
const MOST_STEPS: usize = 6;
/// The longest wait of a step, in ms.
const LONGEST_WAIT: u32 = 10_000;
/// The longest the character's description and personality are told, in characters.
const PERSONA_LIMIT: usize = 1500;
/// The longest message the figure says, in characters.
const SAY_LIMIT: usize = 300;
/// The room of the memory note the animator is told, in tokens (`memory::text::count`);
/// the facts always shown (`hybrid` render's part 1) may take more, at most 450.
const MEMORY_ROOM: usize = 300;
/// The most stages of a handling told, the first of them, as the window keeps.
const MOST_HANDLED: usize = 16;

/// What the companion window asks: its chat (none: the newest chat with the
/// companion's card), the screen it has (CSS pixels, the floor at `height`),
/// where the figure's feet are and what it does, why it asks (a reply where
/// not said), for `Occasion::Handled` what the hand did, in order, for
/// `Occasion::Alone` how long it has been alone, in seconds, and for
/// `Occasion::Touched` the part of the body touched (none: it was not found).
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct CompanionPlan {
    pub chat_id: Option<i64>,
    pub width: f64,
    pub height: f64,
    pub x: f64,
    pub y: f64,
    pub state: String,
    #[serde(default)]
    pub occasion: Occasion,
    #[serde(default)]
    pub handled: Vec<Handling>,
    #[serde(default)]
    pub alone_s: u32,
    #[serde(default)]
    #[ts(optional)]
    pub touched: Option<BodyPart>,
}

/// Why the animator is asked now.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Occasion {
    /// The character has just replied in the compact chat.
    #[default]
    Reply,
    /// The hand has handled the figure, which rests again.
    Handled,
    /// Nobody has used the figure or its chat for a while; asked again and
    /// again while that lasts.
    Alone,
    /// The user has just touched the figure (clicked it); the character
    /// answers in the figure's bubble.
    Touched,
}

/// What happened to the figure while the hand had it, and after.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Handling {
    /// It was asleep when taken.
    Woken,
    Held,
    Shaken,
    Thrown,
    /// Let go without a throw.
    Dropped,
    HitEdge,
    Bounced,
    Landed,
}

impl Handling {
    fn said(self) -> &'static str {
        match self {
            Handling::Woken => "woke it",
            Handling::Held => "picked it up",
            Handling::Shaken => "shook it",
            Handling::Thrown => "threw it",
            Handling::Dropped => "let it drop",
            Handling::HitEdge => "it hit the edge of the screen",
            Handling::Bounced => "it bounced on the floor",
            Handling::Landed => "it landed",
        }
    }
}

/// The sentence that tells the animator why it is asked now.
fn occasion(plan: &CompanionPlan) -> String {
    match plan.occasion {
        Occasion::Reply => "The character has just replied.".to_string(),
        Occasion::Alone => format!(
            "Nobody has used the figure or the chat for {} s; it stands about alone.",
            plan.alone_s
        ),
        Occasion::Handled => {
            let what: Vec<&str> = plan
                .handled
                .iter()
                .take(MOST_HANDLED)
                .map(|one| one.said())
                .collect();
            format!(
                "The user has just handled the figure: {}. It stands on the floor again.",
                what.join(", ")
            )
        }
        Occasion::Touched => match plan.touched {
            Some(part) => format!("The user has just touched the figure's {}.", part.said()),
            None => "The user has just touched the figure.".to_string(),
        },
    }
}

/// What the figure is to do, in this order.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct CompanionMoves {
    pub steps: Vec<Move>,
}

/// One thing the figure does.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[serde(tag = "do", rename_all = "snake_case")]
#[ts(export)]
pub enum Move {
    /// Walks along the floor to `x`.
    Walk { x: f64 },
    /// Walks to that edge of the screen and climbs it to `height`, a share of
    /// the screen's height from the floor.
    Climb { side: Edge, height: f64 },
    /// Lets go of the edge it climbed, and falls.
    LetGo,
    /// Plays a clip once over what the figure does, or, with `ms`, over and
    /// over for that long.
    Play {
        clip: Clip,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        #[ts(optional)]
        ms: Option<u32>,
    },
    /// Looks at the point `x`, `y` of the screen; without it, at the user.
    Look {
        #[serde(default, skip_serializing_if = "Option::is_none")]
        #[ts(optional)]
        x: Option<f64>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        #[ts(optional)]
        y: Option<f64>,
    },
    /// Shows a feeling: its face where the figure has one, and its clip.
    React { feeling: Feeling },
    /// Says `text` in a bubble above the figure, for as long as it takes to read.
    Say { text: String },
    /// Stands still for `ms`.
    Wait { ms: u32 },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Edge {
    Left,
    Right,
}

/// Writes `Clip` and `Clip::ALL` from one list of its variants.
macro_rules! clips {
    ($($clip:ident,)*) => {
        /// The clips the companion plays by name (tools/companion_assets.py:
        /// the owner's 100); a figure without one plays none.
        #[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
        #[serde(rename_all = "snake_case")]
        #[ts(export)]
        pub enum Clip {
            $($clip,)*
        }

        impl Clip {
            /// Every clip, in the order the animator is told them.
            pub const ALL: &[Clip] = &[$(Clip::$clip,)*];
        }
    };
}

clips! {
    Acknowledging,
    Agreeing,
    Angry,
    ArmStretching,
    Bashful,
    BeingCocky,
    Bellydancing,
    BlowAKiss,
    Bored,
    BracedHangShimmy,
    BreathingIdle,
    CanCan,
    Cheering,
    ChickenDance,
    Clapping,
    ClimbingDownWall,
    ClimbingUpWall,
    Crying,
    Dancing,
    Defeat,
    Disappointed,
    DismissingGesture,
    Excited,
    FallLanding,
    FallLoop,
    FallingDown,
    FallingIdle,
    FreehangClimb,
    FreehangDrop,
    GettingUp,
    HandRaising,
    HangingIdle,
    Happy,
    HappyIdle,
    HappyWalk,
    HardLanding,
    HeadNodYes,
    HipHopDancing,
    Idle,
    JoyfulJump,
    Jump,
    Laughing,
    LayingIdle,
    LayingSleeping,
    Leaning,
    LookAround,
    Looking,
    LookingAround,
    MacarenaDance,
    NervouslyLookAround,
    NeutralIdle,
    No,
    OneShoulderLean,
    PointingGesture,
    Pouting,
    QuickFormalBow,
    QuickInformalBow,
    Reacting,
    RelievedSigh,
    RunForward,
    SadIdle,
    SadWalk,
    ScratchIdle,
    SeatedIdle,
    ShakeFist,
    ShakingHeadNo,
    Shrugging,
    Shuffling,
    SillyDancing,
    SittingIdle,
    SleepingIdle,
    SnakeHipHopDance,
    SneakWalk,
    StandToSit,
    StandUp,
    StandardIdle,
    StandingGreeting,
    StandingThumbsUp,
    StandingUp,
    StartWalking,
    StopWalking,
    StumbleBackwards,
    Surprised,
    Talking,
    TellingASecret,
    Terrified,
    Thankful,
    Thinking,
    ThoughtfulHeadNod,
    TwistDance,
    VictoryIdle,
    Waking,
    WalkBackwards,
    Walking,
    WaveHipHopDance,
    Waving,
    WeightShift,
    WhateverGesture,
    Yawn,
    YmcaDance,
}

/// The feelings the figure shows (`Move::React`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Feeling {
    Happy,
    Excited,
    Surprised,
    Sad,
    Angry,
    Agree,
    Disagree,
    Puzzled,
    Afraid,
    Playful,
    Bashful,
    Tired,
}

/// The question to the animator about the companion's card and the chat
/// `plan` names, else its newest chat, if any; `app` is what Cardwave's window
/// shows, `last` the steps it answered the last time. None without a
/// companion, or where `plan` names a chat that is not one of the companion
/// card's chats in its list (an archived or trashed one is not). `known` is
/// the persona the last question was told, used again while its card's
/// version is the card's; the persona told is returned beside the question.
pub fn question(
    db: &dyn crate::chats::Storage,
    user: i64,
    plan: &CompanionPlan,
    app: Option<&AppScreen>,
    last: &[Move],
    known: Option<Persona>,
    bubbled: &[Bubbled],
) -> anyhow::Result<Option<(String, Persona)>> {
    let Some(card_id) = settings::get(db, user)?.companion.card_id else {
        return Ok(None);
    };
    let listed = chats::of_card(db, user, card_id)?;
    let chat = match plan.chat_id {
        Some(id) => match listed.iter().find(|chat| chat.id == id) {
            Some(chat) => Some(chat),
            None => return Ok(None),
        },
        None => listed.first(),
    };
    let Some((persona, rating)) = persona(db, user, card_id, known)? else {
        return Ok(None);
    };
    let (shown, remembered) = match chat {
        Some(chat) => {
            let (shown, companion) = said_in(db, user, card_id, chat, NEWEST)?;
            let remembered = remembered(db, user, card_id, chat, &companion, &listed);
            (Some(shown), remembered)
        }
        None => (None, String::new()),
    };
    let said: Vec<String> = shown
        .iter()
        .flat_map(|chat| &chat.said)
        .map(|one| format!("{}: {}", one.who, one.text))
        .collect();
    let character = shown
        .as_ref()
        .map_or(persona.name.as_str(), |chat| chat.character.as_str());
    let question = told::Asked {
        character,
        persona: &persona.text,
        rating: &rating,
        plan,
        app,
        last,
        bubbled: told::lately(bubbled, card_id, std::time::Instant::now()),
        said,
        remembered: &remembered,
    }
    .text();
    Ok(Some((question, persona)))
}

/// What the companion's character `companion` (of the card `card_id`)
/// remembers in `chat`, as a reply's memory note renders it after the chat's
/// newest message, ranked by words alone (no search model: the idle steering
/// asks often) within `MEMORY_ROOM`; empty where it remembers nothing. Where
/// nothing is said yet in `chat`, a personal memory (the same in each of the
/// card's chats) is read with the first other chat of `listed` with something
/// said. A memory that cannot be read is gone without.
fn remembered(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    chat: &chats::Chat,
    companion: &chats::Participant,
    listed: &[chats::Chat],
) -> String {
    let note = || -> anyhow::Result<String> {
        let document = cards::document_of(db, companion.version_id)?;
        let mode = assistant::mode_of(&document, chat);
        let remembering =
            assistant::remembering(db, card_id, &companion.character, mode.as_deref())?;
        let Some((owner, mode)) = remembering.owner(chat) else {
            return Ok(String::new());
        };
        let mut read = memory::read_chat(db, user, chat, None)?;
        if read.said.is_empty() && !matches!(owner, memory::Owner::Chat(..)) {
            let same_persona = |other: &&chats::Chat| other.persona_id == chat.persona_id;
            for other in listed
                .iter()
                .filter(|other| other.id != chat.id)
                .filter(same_persona)
            {
                let other = memory::read_chat(db, user, other, None)?;
                if !other.said.is_empty() {
                    read = other;
                    break;
                }
            }
        }
        let Some(mut to_render) = memory::to_render(db, user, &read, (&owner, mode), None)? else {
            return Ok(String::new());
        };
        to_render.ask.budget = MEMORY_ROOM;
        memory::system().render(&to_render.state, &to_render.ask, None)
    };
    note().unwrap_or_else(|failure| {
        let id = chat.id;
        tracing::error!("chat {id}'s memory cannot be read for the companion: {failure:#}");
        String::new()
    })
}

/// The companion card's character as the animator is told it, read from the
/// card's version `version_id`.
#[derive(Clone)]
pub struct Persona {
    card_id: i64,
    version_id: i64,
    name: String,
    text: String,
}

impl Persona {
    /// The companion card it was read of.
    pub fn card_id(&self) -> i64 {
        self.card_id
    }

    /// The name of the card's character the figure is.
    pub fn name(&self) -> &str {
        &self.name
    }
}

/// The name of the companion card `card_id`'s character its figure is, as
/// [`persona`] reads it; none where the card is gone or has no character.
pub fn figure_name(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
) -> anyhow::Result<Option<String>> {
    Ok(persona(db, user, card_id, None)?.map(|(persona, _)| persona.name))
}

/// The name of the companion card `card_id`'s character and its description
/// and personality, `{{char}}` and `{{user}}` said, cut at `PERSONA_LIMIT`
/// characters, beside the card's content level (`CardSummary::rating`, read
/// each time: a card is described after it is made); none where the card is
/// gone. `known` is kept where it was read from the card's version.
fn persona(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    known: Option<Persona>,
) -> anyhow::Result<Option<(Persona, String)>> {
    let Some(card) = cards::get(db, user, card_id)? else {
        return Ok(None);
    };
    if let Some(known) = known.filter(|known| known.version_id == card.version_id) {
        return Ok(Some((known, card.rating)));
    }
    let document = cards::document_of(db, card.version_id)?;
    let Some(id) = document.characters().first().map(|id| id.to_string()) else {
        return Ok(None);
    };
    let name = document.character_name(&id);
    let texts = cw_ccv4::mapping::character(&document, &id).unwrap_or_default();
    let text = [texts.description.trim(), texts.personality.trim()]
        .into_iter()
        .filter(|text| !text.is_empty())
        .collect::<Vec<_>>()
        .join("\n\n")
        .replace("{{char}}", &name)
        .replace("{{user}}", "the user")
        .chars()
        .take(PERSONA_LIMIT)
        .collect();
    Ok(Some((
        Persona {
            card_id,
            version_id: card.version_id,
            name,
            text,
        },
        card.rating,
    )))
}

/// The newest chat with the companion's card `card_id`, as [`said_in`]
/// shows it; none where there is no such chat.
pub fn newest_said(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    newest: usize,
) -> anyhow::Result<Option<ChatShown>> {
    match chats::of_card(db, user, card_id)?.first() {
        Some(chat) => Ok(Some(said_in(db, user, card_id, chat, newest)?.0)),
        None => Ok(None),
    }
}

/// `chat` as the companion's character's name and its `newest` messages,
/// each cut at `MESSAGE_LIMIT` characters, beside that character: the chat's
/// character of the companion's card `card_id`, else (the card left the
/// chat) the one the chat began with.
fn said_in(
    db: &dyn crate::chats::Storage,
    user: i64,
    card_id: i64,
    chat: &chats::Chat,
    newest: usize,
) -> anyhow::Result<(ChatShown, chats::Participant)> {
    let participants = chats::participants(db, user, chat.id)?;
    let first = participants.iter().min_by_key(|one| one.id);
    let companion = participants
        .iter()
        .find(|one| one.card_id == card_id)
        .or(first)
        .context(
            Fail::said(Code::NotPossible, "the chat has no character")
                .with("what", "chat_no_character"),
        )?
        .clone();
    let name_of = |one: &chats::Participant| -> anyhow::Result<String> {
        Ok(cards::document_of(db, one.version_id)?.character_name(&one.character))
    };
    let character = name_of(&companion)?;
    let mut said = Vec::new();
    for message in chats::path_to(db, chat.id, chat.head_id)? {
        if !message.complete || message.content.trim().is_empty() {
            continue;
        }
        let who = match message.role {
            Role::User => "User".to_string(),
            Role::Assistant => name_of(
                participants
                    .iter()
                    .find(|one| Some(one.id) == message.speaker_id)
                    .or(first)
                    .unwrap_or(&companion),
            )?,
            Role::System => "Narrator".to_string(),
        };
        let text: String = message.content.chars().take(MESSAGE_LIMIT).collect();
        said.push(Said { who, text });
    }
    let said = said.split_off(said.len().saturating_sub(newest));
    let shown = ChatShown {
        chat_id: chat.id,
        character,
        said,
    };
    Ok((shown, companion))
}

/// Asks the worker model what the figure does next.
pub async fn plan(
    http: &Http,
    provider: &Provider,
    question: String,
    plan: &CompanionPlan,
) -> anyhow::Result<Vec<Move>> {
    let prompt = [
        PromptMessage::new(Role::System, animator()),
        PromptMessage::new(Role::User, question),
    ];
    let text = answer(http, provider, &prompt).await?;
    let Ok(answered) = object(&text) else {
        return Ok(Vec::new());
    };
    Ok(keep(&answered["steps"], plan))
}

/// The steps of `steps` that can be read, each held within the screen of `plan`
/// and the limits, at most `MOST_STEPS`.
fn keep(steps: &Value, plan: &CompanionPlan) -> Vec<Move> {
    let Some(steps) = steps.as_array() else {
        return Vec::new();
    };
    steps
        .iter()
        .filter_map(|step| serde_json::from_value::<Move>(step.clone()).ok())
        .map(|step| held(step, plan.width, plan.height))
        .take(MOST_STEPS)
        .collect()
}

/// `step` held within a screen `width` by `height` and the limits: a step
/// asked from outside is never trusted.
pub fn held(step: Move, width: f64, height: f64) -> Move {
    let within = |value: f64, most: f64| match value.is_finite() {
        true => value.clamp(0.0, most.max(0.0)),
        false => 0.0,
    };
    match step {
        Move::Walk { x } => Move::Walk {
            x: within(x, width),
        },
        Move::Climb { side, height } => Move::Climb {
            side,
            height: within(height, 1.0),
        },
        Move::Wait { ms } => Move::Wait {
            ms: ms.min(LONGEST_WAIT),
        },
        Move::Play { clip, ms } => Move::Play {
            clip,
            ms: ms.map(|ms| ms.min(LONGEST_WAIT)),
        },
        Move::Look { x, y } => Move::Look {
            x: x.map(|x| within(x, width)),
            y: y.map(|y| within(y, height)),
        },
        Move::Say { text } => Move::Say {
            text: text.trim().chars().take(SAY_LIMIT).collect(),
        },
        other => other,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_animator_is_told_every_clip_once_with_what_it_shows() {
        let told = animator();
        assert!(!told.contains("{clips}"));
        let list = told
            .split("The clips, each with what it shows:\n")
            .nth(1)
            .unwrap()
            .split("\n\n")
            .next()
            .unwrap();
        let lines: Vec<&str> = list.lines().collect();
        assert_eq!(lines.len(), 100);
        assert_eq!(Clip::ALL.len(), 100);
        for (clip, line) in Clip::ALL.iter().zip(lines) {
            let (name, what) = line.split_once(": ").unwrap();
            assert_eq!(serde_json::to_value(clip).unwrap(), name);
            assert!(!what.trim().is_empty(), "{name} tells nothing");
        }
    }
}

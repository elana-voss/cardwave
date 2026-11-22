//! The steering model's question laid out in its tags (`Asked`), and what the
//! companion's models are told besides the figure and the chat: the
//! part of the body the user touched (`BodyPart`, said in words that assume
//! no gender), the card's content level (`content_level`, the classifier's
//! rating; none until the card is described) and what the figure said in its
//! bubble lately (`Bubbles`, kept by the server in memory only, never with the
//! chat, for `BUBBLED_FOR`), told to the steering model (`lately`) and to the
//! character's chat model (`bubble_note`, which names the figure's character:
//! the chat's speaker may be another of its card). A line counts as said only
//! once the window says its bubble shows it, and only where the server gave it
//! as the character's (`Bubbles::offer`): the window drops answers that come
//! too late, and its bubble also shows the app's own words (why it could not
//! hide). A line goes into a prompt that expands macros, so its `{{` are taken
//! out (`plain`).

use std::time::{Duration, Instant};

use serde::Deserialize;
use ts_rs::TS;

use super::{AppScreen, CompanionPlan, Move, occasion};

/// The most bubble lines told, the newest.
pub const MOST_BUBBLED: usize = 4;
/// The most lines given to the figure and not yet shown, the newest.
const MOST_OFFERED: usize = 16;

/// How long a bubble line counts as said lately.
pub const BUBBLED_FOR: Duration = Duration::from_secs(30 * 60);

/// A part of the figure's body the user can touch, found by the companion
/// window from where the click lands.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum BodyPart {
    Head,
    Hair,
    Face,
    Neck,
    Shoulder,
    Chest,
    Belly,
    Back,
    Arm,
    Hand,
    Hip,
    Leg,
    Foot,
}

impl BodyPart {
    /// The part in words, the same for any figure.
    pub fn said(self) -> &'static str {
        match self {
            BodyPart::Head => "head",
            BodyPart::Hair => "hair",
            BodyPart::Face => "face",
            BodyPart::Neck => "neck",
            BodyPart::Shoulder => "shoulder",
            BodyPart::Chest => "chest",
            BodyPart::Belly => "belly",
            BodyPart::Back => "back",
            BodyPart::Arm => "arm",
            BodyPart::Hand => "hand",
            BodyPart::Hip => "hip",
            BodyPart::Leg => "leg",
            BodyPart::Foot => "foot",
        }
    }
}

/// The card's content level `rating` (the classifier's: "sfw", "suggestive",
/// "nsfw", "nsfw-extreme") as the steering model is told it; none where the
/// card is not described yet or the rating is unknown.
pub fn content_level(rating: &str) -> Option<&'static str> {
    Some(match rating {
        "sfw" => "for everyone: nothing sexual, nothing graphic",
        "suggestive" => "suggestive: flirting and innuendo, nothing explicit",
        "nsfw" => "for adults: explicit content may be shown",
        "nsfw-extreme" => "for adults, extreme: explicit and extreme content may be shown",
        _ => return None,
    })
}

/// A line the figure said in its bubble at `at`, as the character `name` of
/// the companion card `card_id`.
#[derive(Clone, Debug, PartialEq)]
pub struct Bubbled {
    pub card_id: i64,
    pub name: String,
    pub text: String,
    pub at: Instant,
}

/// What the figure said in its bubble lately (`lines`), and the lines given to
/// it as a character's that its bubble has not shown yet.
#[derive(Clone, Debug, Default)]
pub struct Bubbles {
    offered: Vec<Bubbled>,
    kept: Vec<Bubbled>,
    /// What the window said its bubble shows, as it said last.
    showing: Option<String>,
}

impl Bubbles {
    /// Gives the lines `steps` say to the figure as the character `name` of the
    /// card `card_id`, at `at`; said once its bubble shows them (`shown`).
    pub fn offer(&mut self, card_id: i64, name: &str, steps: &[Move], at: Instant) {
        for step in steps {
            if let Move::Say { text } = step {
                self.offered.push(Bubbled {
                    card_id,
                    name: name.to_string(),
                    text: text.clone(),
                    at,
                });
            }
        }
        let over = self.offered.len().saturating_sub(MOST_OFFERED);
        self.offered.drain(..over);
    }

    /// The window says its bubble shows `saying` at `at`: a line newly shown that
    /// was given as a character's is kept as said, once.
    pub fn shown(&mut self, saying: Option<&str>, at: Instant) {
        if self.showing.as_deref() == saying {
            return;
        }
        self.showing = saying.map(str::to_string);
        let Some(text) = saying else { return };
        let Some(given) = self.offered.iter().rposition(|line| line.text == text) else {
            return;
        };
        let line = self.offered.remove(given);
        self.kept.push(Bubbled {
            card_id: line.card_id,
            name: plain(&line.name),
            text: plain(&line.text),
            at,
        });
        let over = self.kept.len().saturating_sub(MOST_BUBBLED);
        self.kept.drain(..over);
    }

    /// The lines said lately, oldest first, of every card.
    pub fn lines(&self) -> &[Bubbled] {
        &self.kept
    }
}

/// The lines of `kept` said as the card `card_id`'s within `BUBBLED_FOR`
/// before `now`, oldest first.
pub fn lately(kept: &[Bubbled], card_id: i64, now: Instant) -> Vec<&Bubbled> {
    kept.iter()
        .filter(|line| {
            line.card_id == card_id && now.saturating_duration_since(line.at) < BUBBLED_FOR
        })
        .collect()
}

/// What the character's chat model is told of the bubble's lines `lines`,
/// after the chat's log, naming the figure's character as the newest line
/// does; none without a line.
pub fn bubble_note(lines: &[&Bubbled]) -> Option<String> {
    let name = &lines.last()?.name;
    let quoted: Vec<String> = lines
        .iter()
        .map(|line| format!("\"{}\"", line.text))
        .collect();
    Some(format!(
        "[Outside this chat, {name}'s small figure on {{{{user}}}}'s screen lately said in its speech bubble: {}]",
        quoted.join(" / ")
    ))
}

/// What the steering model is asked about, each part told in its tag: the
/// character `character` and the persona's `persona` text, the card's content
/// level (by `rating`), why it is asked now, the screen, Cardwave's window
/// (`app`), the figure, its `last` steps, what its bubble said lately
/// (`bubbled`), the newest messages of its chat (`said`) and what the chat's
/// memory holds (`remembered`, none when empty).
pub struct Asked<'a> {
    pub character: &'a str,
    pub persona: &'a str,
    pub rating: &'a str,
    pub plan: &'a CompanionPlan,
    pub app: Option<&'a AppScreen>,
    pub last: &'a [Move],
    pub bubbled: Vec<&'a Bubbled>,
    pub said: Vec<String>,
    pub remembered: &'a str,
}

impl Asked<'_> {
    /// The question's text.
    pub fn text(&self) -> String {
        let plan = self.plan;
        let level = content_level(self.rating).map_or(String::new(), |level| {
            format!(
                "
<content_level>{level}</content_level>"
            )
        });
        let app = self.app.map_or("not open".to_string(), |app| {
            format!("{} ({})", app.title, app.route)
        });
        let last: Vec<String> = self
            .last
            .iter()
            .filter_map(|step| serde_json::to_string(step).ok())
            .collect();
        let bubble: Vec<String> = self
            .bubbled
            .iter()
            .map(|line| format!("\"{}\"", line.text))
            .collect();
        let remembered = match self.remembered.is_empty() {
            true => String::new(),
            false => format!(
                "
<memory>
{}
</memory>",
                self.remembered
            ),
        };
        format!(
            "<character>{}</character>
<persona>
{}
</persona>{level}
<now>{}</now>
<screen>{:.0} wide, {:.0} high; the floor is at y = {:.0}</screen>
<cardwave_window>{app}</cardwave_window>
<figure>x = {:.0}, y = {:.0}, {}</figure>
<last_steps>{}</last_steps>
<bubble_lately>{}</bubble_lately>
<newest_messages>
{}
</newest_messages>{remembered}",
            self.character,
            self.persona,
            occasion(plan),
            plan.width,
            plan.height,
            plan.height,
            plan.x,
            plan.y,
            plan.state,
            last.join(", "),
            bubble.join(" / "),
            self.said.join(
                "

"
            ),
        )
    }
}

/// `text` without the `{{` and `}}` a prompt's macros begin and end with.
fn plain(text: &str) -> String {
    let mut text = text.to_string();
    while text.contains("{{") || text.contains("}}") {
        text = text.replace("{{", "{").replace("}}", "}");
    }
    text
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_the_newest_lines_of_the_card_are_kept_and_told() {
        let mut bubbles = Bubbles::default();
        let say = |text: &str| Move::Say {
            text: text.to_string(),
        };
        let now = Instant::now();
        let said = |bubbles: &Bubbles, at| -> Vec<String> {
            lately(bubbles.lines(), 1, at)
                .iter()
                .map(|line| line.text.clone())
                .collect()
        };
        let mut shown = |card_id, name, steps: &[Move]| {
            bubbles.offer(card_id, name, steps, now);
            for step in steps {
                if let Move::Say { text } = step {
                    bubbles.shown(Some(text), now);
                }
            }
        };
        shown(1, "Gwen", &[say("a"), Move::Wait { ms: 10 }, say("b")]);
        shown(2, "Other", &[say("other")]);
        shown(1, "Gwen", &[say("c"), say("d")]);
        assert_eq!(said(&bubbles, now), ["b", "c", "d"]);
        assert_eq!(said(&bubbles, now + BUBBLED_FOR), Vec::<String>::new());
        assert_eq!(bubble_note(&[]), None);
    }

    #[test]
    fn a_line_is_said_once_its_bubble_shows_it_and_only_where_it_was_given_as_the_characters() {
        let mut bubbles = Bubbles::default();
        let now = Instant::now();
        let said = |bubbles: &Bubbles| -> Vec<String> {
            let lines = lately(bubbles.lines(), 1, now);
            lines.iter().map(|line| line.text.clone()).collect()
        };
        let say = |text: &str| Move::Say {
            text: text.to_string(),
        };
        bubbles.offer(1, "Gwen", &[say("Never shown."), say("Hi.")], now);
        assert_eq!(said(&bubbles), Vec::<String>::new());
        // The app's own words in the bubble are no line of the character's.
        bubbles.shown(Some("The server could not be reached."), now);
        bubbles.shown(Some("Hi."), now);
        bubbles.shown(Some("Hi."), now);
        bubbles.shown(None, now);
        assert_eq!(said(&bubbles), ["Hi."]);
    }

    #[test]
    fn the_note_names_the_figures_character_and_carries_no_macro_of_a_line() {
        let mut bubbles = Bubbles::default();
        let text = "{{setvar::mood::angry}} {{{{roll}}}}";
        let now = Instant::now();
        let line = Move::Say {
            text: text.to_string(),
        };
        bubbles.offer(1, "{{user}}Gwen", &[line], now);
        bubbles.shown(Some(text), now);
        let note = bubble_note(&lately(bubbles.lines(), 1, now)).unwrap();
        assert_eq!(
            note,
            "[Outside this chat, {user}Gwen's small figure on {{user}}'s screen lately said in its speech bubble: \"{setvar::mood::angry} {roll}\"]"
        );
    }
}

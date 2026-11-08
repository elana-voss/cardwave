//! What the pretend model (`provider::pretend`) answers each of the worker
//! model's questions, known by its prompt's opening: an answer its reader
//! takes that changes nothing (no memory, no mode, no move, the card's own
//! title kept; a chat without a character is named "A talk with the pretend
//! model", a generated card gets fixed texts). `router` hands `FIXED` to the
//! provider's client (`provider::Http`).

use cw_chat::{assistant, chats, companion, images, memory};
use cw_library::{describe, generator, needs};

/// The character generator's greeting and example messages.
const CARD_TEXTS: &str = r#"{"greeting": "*{{char}} looks up.* Hello, {{user}}. This greeting is the pretend model's.", "examples": [{"user": "How are you?", "char": "Well enough, {{user}}."}]}"#;

/// A memory helper's answer that remembers nothing.
const NOTHING_REMEMBERED: &str = "PRESENT:
FACTS:
EVENTS:";
pub const PICTURE_WORDS: &str = "a pretend picture, soft colours";

/// The worker model's questions, each by its prompt, and what the pretend model answers.
pub static FIXED: [(&str, &str); 12] = [
    (assistant::PICK, r#"{"mode": ""}"#),
    (companion::ANIMATE, r#"{"steps": []}"#),
    (memory::hybrid::OPENING, NOTHING_REMEMBERED),
    (
        describe::CLASSIFY,
        r#"{"verdict": "classified", "rating": "sfw"}"#,
    ),
    (
        describe::WRITE,
        r#"{"title": "", "logline": "A card the pretend model described.", "summary": "The pretend model gives every card these words.", "tagline": "Every card hears the same words.", "mood": "drama"}"#,
    ),
    (needs::ASK, r#"{"verdict": "classified", "needs": []}"#),
    (images::WORDS, PICTURE_WORDS),
    (images::SCENE, PICTURE_WORDS),
    (images::CARD, PICTURE_WORDS),
    (images::comfy::PLACE, r#"{"place": 1}"#),
    (generator::WRITE, CARD_TEXTS),
    (
        chats::title::NAME,
        r#"{"title": "A talk with the pretend model"}"#,
    ),
];

#[cfg(test)]
mod tests {
    use super::*;
    use cw_provider::pretend::opening;

    /// An empty opening would be in every message, and take every chat; two
    /// alike would answer one question with the other's answer.
    #[test]
    fn every_question_is_known_by_an_opening() {
        for (index, (prompt, _)) in FIXED.iter().enumerate() {
            assert!(opening(prompt).len() > 20, "{prompt}");
            for (other, _) in &FIXED[index + 1..] {
                assert_ne!(opening(prompt), opening(other), "{prompt}");
            }
        }
    }
}

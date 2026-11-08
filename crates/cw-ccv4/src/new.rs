//! A card made from scratch, in the app: what its form gives ([`NewCard`])
//! written as the one TOML file of a CCV4 card ([`files`]).
//!
//! The file is first written with what a card cannot be without (the format's
//! version, the title, one character with its name and a prompt of the name,
//! the lorebooks and the chat), and all else is an edit of that card
//! ([`super::edit::apply`]): a card made here reads as one that was imported
//! bare and then filled in its editor, and a text left empty has no block, as
//! the talkativeness left at 0.5 has no key.
//! The character's ID is made of its name as an imported SillyTavern card's is.
//! What went into making it ([`Creation`]) is a `user/` file of its own.

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};
use serde::Deserialize;
use toml::{Table, Value};
use ts_rs::TS;

use crate::creation::{self, Creation};
use crate::edit::{self, CardEdit, EditText};
use crate::{Document, ONE_FILE, plain, slug_or, written_date};

/// What the form "New card" gives: a card of one character.
#[derive(Debug, Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct NewCard {
    /// What the library calls the card. A card needs one.
    pub title: String,
    pub tags: Vec<String>,
    /// Who made the card; empty to say nothing.
    pub creator: String,
    /// The name its character has in a chat. A character needs one.
    pub name: String,
    /// The messages a chat can open with, in their order; an empty one is none.
    pub greetings: Vec<String>,
    pub description: String,
    pub personality: String,
    pub scenario: String,
    pub example_dialogue: String,
    /// What the card's creator tells its users; never sent to a model.
    pub creator_notes: String,
    /// The character's system prompt and post-history instructions; without one, or empty, none.
    pub system_prompt: Option<String>,
    pub post_history: Option<String>,
    /// How readily its character replies where a chat of several has one
    /// reply by chance, from 0 to 1. Without it, or at 0.5, the card says
    /// nothing, which counts as 0.5.
    pub talkativeness: Option<f64>,
    /// The card's picture, a PNG in base64. Without one the card has no art.
    pub picture: Option<String>,
    /// What went into making it, kept with it; only the app sets it, never the form.
    #[serde(skip)]
    #[ts(skip)]
    pub creation: Option<Creation>,
}

fn table<const N: usize>(pairs: [(&str, Value); N]) -> Value {
    Value::Table(
        pairs
            .into_iter()
            .map(|(key, value)| (key.to_string(), value))
            .collect(),
    )
}

/// The TOML files of the card `new`, made at the moment `now` (milliseconds),
/// each as (file name, TOML). Refused: a card without a title, and one whose
/// character has no name.
pub fn files(new: &NewCard, now: i64) -> anyhow::Result<Vec<(String, String)>> {
    let title = plain(&new.title);
    ensure!(
        !title.is_empty(),
        Fail::said(Code::Needed, "a card needs a title").with("what", "card_title")
    );
    let name = plain(&new.name);
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "a character needs a name").with("what", "character_name")
    );
    let id = slug_or(&name, "character");
    let own_name = format!("name.{id}");

    let date = Value::Datetime(written_date(now)?.parse()?);
    let mut root = Table::new();
    root.insert("spec".to_string(), "ccv4:1.0.0".into());
    root.insert(
        "meta-info".to_string(),
        table([
            ("title", title.as_str().into()),
            ("created", date.clone()),
            ("modified", date),
        ]),
    );
    root.insert(
        "name".to_string(),
        table([(id.as_str(), table([("text", name.as_str().into())]))]),
    );
    let prompt: Vec<Value> = [own_name.as_str(), "LOREBOOK", "CHAT-HISTORY"]
        .into_iter()
        .map(Value::from)
        .collect();
    let character = table([
        ("name-card", name.as_str().into()),
        ("name-char", own_name.as_str().into()),
        ("prompt", Value::Array(prompt)),
    ]);
    root.insert("character".to_string(), table([(id.as_str(), character)]));
    let bare = vec![(
        ONE_FILE.to_string(),
        toml::to_string_pretty(&root).context(Fail::said(
            Code::Internal,
            "the card cannot be written as TOML",
        ))?,
    )];

    // All else is what an editor would give that card.
    let mut asked = CardEdit::of(&Document::parse(&bare)?, 1, &title, None);
    let text = |text: &String| EditText {
        reference: None,
        text: text.clone(),
        modes: Vec::new(),
    };
    asked.tags = new.tags.clone();
    asked.creator = new.creator.clone();
    let one = asked.characters.first_mut();
    let one = one.context(
        Fail::said(Code::NotPossible, "the card has no character")
            .with("what", "card_no_character"),
    )?;
    one.greetings = new.greetings.iter().map(text).collect();
    one.description = vec![text(&new.description)];
    one.personality = vec![text(&new.personality)];
    one.scenario = vec![text(&new.scenario)];
    one.example_dialogue = vec![text(&new.example_dialogue)];
    one.creator_notes = new.creator_notes.clone();
    for (asked, given) in [
        (&mut one.system_prompt, &new.system_prompt),
        (&mut one.post_history, &new.post_history),
    ] {
        if let Some(given) = given {
            *asked = vec![text(given)];
        }
    }
    one.talkativeness = new.talkativeness.unwrap_or(one.talkativeness);
    let mut files = match edit::apply(&bare, &asked, None, now)? {
        Some(filled) => filled.files,
        None => bare,
    };
    if let Some(made) = &new.creation {
        files.push(creation::file(made)?);
    }
    Ok(files)
}

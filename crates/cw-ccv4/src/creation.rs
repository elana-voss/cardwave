//! What went into making a card with the app's help: the answers, what was
//! made of them and the plan ([`Creation`]). It is the card's own `user/` file
//! ([`FILE`]) of the type `cardwave_creation`, so it is versioned with the card and
//! kept by the app's backup, while an export, which keeps only `card/` files
//! and the card's own fields, leaves it out, and no prompt reads it.
//!
//! Trap: it is one JSON document in one TOML string, as TOML has no null and a
//! plan is any JSON, and has no `text` key, which would make it a block with a
//! history (`drafts`).

use anyhow::Context;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use toml::Table;
use ts_rs::TS;

use crate::Document;

/// The file of a card that holds it.
pub const FILE: &str = "user/0002_creation.toml";
/// The element of the type `cardwave_creation` that holds it.
const ELEMENT: &str = "made";

/// What went into making a card.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Creation {
    pub kinds: Vec<String>,
    pub mode: String,
    pub relation: String,
    pub moments: Vec<String>,
    pub needs: Vec<Need>,
    pub nevers: Vec<String>,
    pub private: Private,
    pub persona_facts: Vec<String>,
    pub style: String,
    pub model: String,
    pub question_log: Vec<Asked>,
    pub plan: Value,
    /// A value of the character question, "as told" or "they".
    pub character_gender: String,
    pub treat_user: String,
    /// The user's own line where code could not read it.
    pub character_words: String,
    pub cast_genders: Vec<String>,
    pub draw: Option<Draw>,
    pub cast_draw: Option<Draw>,
}

/// A draw by code, kept with the card and never told to a model.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Draw {
    pub seed: String,
    pub over: Vec<String>,
    pub drawn: Vec<String>,
}

/// What the user was found to need, and what the user did with it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Need {
    /// The sentence inferred.
    pub sentence: String,
    /// The user's words it rests on.
    pub words: String,
    pub gap: bool,
    pub state: NeedState,
    /// The user's sentence, where it was changed.
    pub changed_to: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NeedState {
    Kept,
    Changed,
    Removed,
}

/// The private list of sensitive matters.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Private {
    pub open: bool,
    pub rows: Vec<PrivateRow>,
    pub free: String,
}

/// A row of the private list; "don't know" rows are left out.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct PrivateRow {
    pub topic: String,
    /// "yes", "no", "maybe" or "fantasy only".
    pub answer: String,
    pub never: bool,
}

/// A question of the interview and what came of it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Asked {
    pub slot: String,
    pub question: String,
    pub answer: Option<String>,
    pub skipped: bool,
    pub dont_know: bool,
}

/// `made` as the card's file: (file name, TOML).
pub fn file(made: &Creation) -> anyhow::Result<(String, String)> {
    let unwritable = || Fail::said(Code::Internal, "how a card was made cannot be written");
    let json = serde_json::to_string(made).with_context(unwritable)?;
    let mut element = Table::new();
    element.insert("json".to_string(), json.into());
    let mut elements = Table::new();
    elements.insert(ELEMENT.to_string(), element.into());
    let mut root = Table::new();
    root.insert("cardwave_creation".to_string(), elements.into());
    let text = toml::to_string_pretty(&root).with_context(unwritable)?;
    Ok((FILE.to_string(), text))
}

/// What went into making the card `document`, where it has that.
pub fn read(document: &Document) -> anyhow::Result<Option<Creation>> {
    let json = document
        .root
        .get("cardwave_creation")
        .and_then(|elements| elements.get(ELEMENT))
        .and_then(|element| element.get("json"))
        .and_then(toml::Value::as_str);
    let Some(json) = json else {
        return Ok(None);
    };
    let made = serde_json::from_str(json).context(
        Fail::said(Code::NotReadable, "how the card was made cannot be read")
            .with("what", "card_creation"),
    )?;
    Ok(Some(made))
}

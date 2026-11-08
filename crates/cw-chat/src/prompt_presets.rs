//! Prompt presets: a system prompt and an author's note kept under a name,
//! as CCV4 `prompt` blocks (`[prompt.system]`, and `[prompt.authors-note]`
//! with its `depth`) in one TOML text, `blocks`. One of them is in use for
//! all the user's chats (`users.prompt_preset_id`; none is "Default", the
//! card's own prompt), and a chat may choose its own ([`ChatPromptPreset`],
//! kept as `chats.prompt_preset_own` and `chats.prompt_preset_id`).
//!
//! [`apply`] gives a character what the chat's preset says: its system prompt
//! in the card's place where it has one, and its author's note as one more
//! depth prompt; the builder expands their macros as it does the card's.
//! A deleted preset that was in use leaves the user with the card's own
//! prompt (the column's `on delete set null`), and a chat that chose it
//! with the one in use ([`delete`]). Over HTTP:
//! `server/src/api/prompt_presets.rs`.

use anyhow::ensure;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_prompt::{Character, DepthPrompt, Role};
use cw_provider::NAME_LIMIT;
use cw_provider::presets::{self, Named, taken};
use serde::{Deserialize, Serialize};
use toml::{Table, Value};
use ts_rs::TS;

use crate::chats::{self, Chat};

/// The blocks' IDs in `blocks`.
const SYSTEM: &str = "system";
const NOTE: &str = "authors-note";

/// What a prompt preset holds.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct PromptTexts {
    /// Takes the place of the card's system prompt; empty leaves the card's.
    pub system_prompt: String,
    /// Put into the chat `authors_note_depth` messages before its newest; empty for none.
    pub authors_note: String,
    pub authors_note_depth: u32,
}

/// A prompt preset as its list shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct PromptPreset {
    pub id: i64,
    pub name: String,
    #[serde(flatten)]
    #[ts(flatten)]
    pub texts: PromptTexts,
    /// The one every chat is given that does not choose its own.
    pub in_use: bool,
}

/// The prompt preset a chat goes by.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum ChatPromptPreset {
    /// The one in use on the page Advanced.
    #[default]
    Settings,
    /// None: the card's own prompt.
    Card,
    Preset(i64),
}

impl ChatPromptPreset {
    /// As a chat's two columns keep it: whether the chat chose, and what.
    pub fn of(own: bool, id: Option<i64>) -> Self {
        match (own, id) {
            (false, _) => Self::Settings,
            (true, None) => Self::Card,
            (true, Some(id)) => Self::Preset(id),
        }
    }
}

/// `texts` as CCV4 `prompt` blocks.
fn blocks(texts: &PromptTexts) -> String {
    let block = |text: &str| Table::from_iter([("text".to_string(), Value::from(text))]);
    let mut note = block(&texts.authors_note);
    note.insert("depth".into(), Value::from(texts.authors_note_depth));
    let prompt = Table::from_iter([
        (
            SYSTEM.to_string(),
            Value::Table(block(&texts.system_prompt)),
        ),
        (NOTE.to_string(), Value::Table(note)),
    ]);
    let all = Table::from_iter([("prompt".to_string(), Value::Table(prompt))]);
    // A table of strings and a number always writes as TOML.
    toml::to_string(&all).expect("a table of strings and a number is TOML")
}

/// What `blocks` hold; a block or a key that is not there is empty.
fn texts_of(blocks: &str) -> PromptTexts {
    let all: Table = toml::from_str(blocks).unwrap_or_default();
    let block = |id| all.get("prompt").and_then(|prompt| prompt.get(id));
    let text = |id| {
        let text = block(id).and_then(|block| block.get("text"));
        text.and_then(Value::as_str).unwrap_or_default().to_string()
    };
    let depth = block(NOTE).and_then(|note| note.get("depth"));
    PromptTexts {
        system_prompt: text(SYSTEM),
        authors_note: text(NOTE),
        authors_note_depth: depth
            .and_then(Value::as_integer)
            .and_then(|depth| u32::try_from(depth).ok())
            .unwrap_or(cw_prompt::DEFAULT_DEPTH as u32),
    }
}

fn checked(texts: &PromptTexts) -> anyhow::Result<()> {
    // The spec's depth is a positive number.
    ensure!(
        texts.authors_note_depth >= 1,
        Fail::said(
            Code::OutOfRange,
            "the author's note is put one message back or more"
        )
        .with("what", "authors_note_depth")
    );
    Ok(())
}

/// The user's prompt presets as `Storage::prompt_presets` reads them.
pub struct KeptPromptPresets {
    /// The ID of the one in use.
    pub in_use: Option<i64>,
    /// Each as (ID, name, blocks).
    pub presets: Vec<(i64, String, String)>,
}

/// What the prompt presets need of the database, which `cw_store::prompt_presets`
/// gives. A preset's texts are its `blocks`.
pub trait Storage {
    fn prompt_presets(&self, user: i64) -> anyhow::Result<KeptPromptPresets>;
    /// Its ID; none where another is called `name`.
    fn add_prompt_preset(&self, user: i64, name: &str, blocks: &str)
    -> anyhow::Result<Option<i64>>;
    /// How many presets it changed; none where another is called `name`.
    fn change_prompt_preset(
        &self,
        user: i64,
        id: i64,
        name: &str,
        blocks: &str,
    ) -> anyhow::Result<Option<usize>>;
    /// Copies the preset `id` under the name `named` gives of the user's
    /// presets as (ID, name), at once: the copy, none where it has no name.
    fn copy_prompt_preset(&self, user: i64, id: i64, named: &Named) -> anyhow::Result<Option<i64>>;
    /// Deletes it, the chats that chose it going by the one in use: whether it was there.
    fn delete_prompt_preset(&self, user: i64, id: i64) -> anyhow::Result<bool>;
    fn owns_prompt_preset(&self, user: i64, id: i64) -> anyhow::Result<bool>;
    fn put_prompt_preset_in_use(&self, user: i64, id: Option<i64>) -> anyhow::Result<()>;
    /// Whether the chat goes by its own choice (`own`), and which preset that is.
    fn choose_chat_prompt_preset(
        &self,
        user: i64,
        chat_id: i64,
        own: bool,
        id: Option<i64>,
    ) -> anyhow::Result<()>;
    /// The blocks of the preset a chat that chose `chosen` goes by.
    fn prompt_preset_blocks(
        &self,
        user: i64,
        chosen: ChatPromptPreset,
    ) -> anyhow::Result<Option<String>>;
}

/// The user's prompt presets in the order of their names, whatever their case.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<PromptPreset>> {
    let KeptPromptPresets {
        in_use: used,
        presets: kept,
    } = db.prompt_presets(user)?;
    let mut presets: Vec<PromptPreset> = kept
        .into_iter()
        .map(|(id, name, blocks)| PromptPreset {
            id,
            name,
            texts: texts_of(&blocks),
            in_use: used == Some(id),
        })
        .collect();
    presets.sort_by_cached_key(|preset| (preset.name.to_lowercase(), preset.id));
    Ok(presets)
}

/// The preset `id` as the list shows it.
fn one(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<PromptPreset> {
    let found = list(db, user)?.into_iter().find(|preset| preset.id == id);
    Ok(found.ok_or(NotFound("prompt preset"))?)
}

/// Keeps `texts` under `name`, which no other preset of the user's has.
pub fn create(
    db: &dyn Storage,
    user: i64,
    name: &str,
    texts: &PromptTexts,
) -> anyhow::Result<PromptPreset> {
    let name = presets::called(name)?;
    checked(texts)?;
    let id = db.add_prompt_preset(user, &name, &blocks(texts))?;
    one(db, user, id.ok_or_else(|| taken(&name))?)
}

/// Calls the preset `id` `name` and has it hold `texts`.
pub fn change(
    db: &dyn Storage,
    user: i64,
    id: i64,
    name: &str,
    texts: &PromptTexts,
) -> anyhow::Result<PromptPreset> {
    let name = presets::called(name)?;
    checked(texts)?;
    let changed = db.change_prompt_preset(user, id, &name, &blocks(texts))?;
    ensure!(
        changed.ok_or_else(|| taken(&name))? == 1,
        NotFound("prompt preset")
    );
    one(db, user, id)
}

/// Makes a copy of the preset `id` under a name of its own
/// (`cw_core::copy_name`, with the word `copy`).
pub fn duplicate(db: &dyn Storage, user: i64, id: i64, copy: &str) -> anyhow::Result<PromptPreset> {
    let named = |names: &[(i64, String)]| {
        let (_, name) = names.iter().find(|(preset, _)| *preset == id)?;
        Some(cw_core::copy_name(copy, name, NAME_LIMIT, |made| {
            names.iter().any(|(_, name)| name == made)
        }))
    };
    let copy = db.copy_prompt_preset(user, id, &named)?;
    one(db, user, copy.ok_or(NotFound("prompt preset"))?)
}

/// Makes a copy of Default, the card's own prompt, called `name` in the
/// user's language: an empty preset under a name of its own
/// (`cw_core::copy_name`, with the word `copy`).
pub fn duplicate_default(
    db: &dyn Storage,
    user: i64,
    name: &str,
    copy: &str,
) -> anyhow::Result<PromptPreset> {
    let names = list(db, user)?;
    let name = cw_core::copy_name(copy, name.trim(), NAME_LIMIT, |made| {
        names.iter().any(|preset| preset.name == made)
    });
    let empty = PromptTexts {
        system_prompt: String::new(),
        authors_note: String::new(),
        authors_note_depth: 4,
    };
    create(db, user, &name, &empty)
}

/// Deletes the preset `id` for good.
/// A chat that chose it goes by the one in use from then on.
pub fn delete(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    let gone = db.delete_prompt_preset(user, id)?;
    ensure!(gone, NotFound("prompt preset"));
    Ok(())
}

/// Refuses a preset that is not the user's.
fn ensure_own(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    let own = db.owns_prompt_preset(user, id)?;
    ensure!(own, NotFound("prompt preset"));
    Ok(())
}

/// Puts the preset `id` in use for every chat that does not choose its own;
/// `None` is "Default", the card's own prompt.
pub fn put_in_use(db: &dyn Storage, user: i64, id: Option<i64>) -> anyhow::Result<()> {
    if let Some(id) = id {
        ensure_own(db, user, id)?;
    }
    db.put_prompt_preset_in_use(user, id)
}

/// Has the chat go by `choice` from its next reply on.
pub fn choose_for_chat(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    choice: ChatPromptPreset,
) -> anyhow::Result<()> {
    chats::ensure_kept(db, user, chat_id)?;
    let (own, id) = match choice {
        ChatPromptPreset::Settings => (false, None),
        ChatPromptPreset::Card => (true, None),
        ChatPromptPreset::Preset(id) => {
            ensure_own(db, user, id)?;
            (true, Some(id))
        }
    };
    db.choose_chat_prompt_preset(user, chat_id, own, id)
}

/// Gives `character` what the preset `chat` goes by says.
pub fn apply(
    db: &dyn Storage,
    user: i64,
    chat: &Chat,
    character: &mut Character,
) -> anyhow::Result<()> {
    let blocks = db.prompt_preset_blocks(user, chat.prompt_preset)?;
    let Some(texts) = blocks.as_deref().map(texts_of) else {
        return Ok(());
    };
    if !texts.system_prompt.trim().is_empty() {
        character.system_prompt = texts.system_prompt;
    }
    if !texts.authors_note.trim().is_empty() {
        character.depth_prompts.push(DepthPrompt {
            prompt: texts.authors_note,
            depth: texts.authors_note_depth as usize,
            role: Role::System,
        });
    }
    Ok(())
}

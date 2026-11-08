//! Assistant and companion: a chat's mode, and a character's personality, its
//! card with its tools and its memory (Decided: "one personality = card +
//! tools + memory").
//!
//! A card with modes (`Document::modes`) has its chat in one: the one the user
//! set (`chats.mode`), else the one the worker model picked last
//! (`chats.auto_mode`, `pick`, before a reply), else the card's first
//! (`mode_of`). A chat offers its first character's card's modes (`first`); a
//! character of another card is in the mode of that name, else its card's first.
//!
//! A mode called Assistant or Companion is personal (`is_personal`): there a
//! character goes by its personality, kept per card and character: the tools
//! it may use of those the account offers (`offered`, `restrict`), and whether
//! it remembers, with the assistant's memory (`remembering`).

use anyhow::{Context, ensure};
use cw_ccv4::{Document, same_mode};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::cards;
use cw_library::settings::Tools;
use cw_prompt::{PromptMessage, Role, tokens};
use cw_provider::Http;
use cw_provider::Provider;
use cw_provider::{answer, object};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::chats::{self, Chat};

/// The worker model's question that picks a chat's mode; a test's stand-in for
/// the provider tells it by its first sentence.
pub const PICK: &str = include_str!("assistant/pick.txt");
/// The newest messages the picker reads.
const NEWEST: usize = 6;
/// The longest a message is shown to the picker, in characters.
const MESSAGE_LIMIT: usize = 1_500;

/// The mode a character of `document` is in, in the chat `chat`: the one the
/// user set, else the one the chat picked last, where the card has it; else
/// the card's first. None for a card without modes.
pub fn mode_of(document: &Document, chat: &Chat) -> Option<String> {
    let wanted: Vec<&str> = [&chat.mode, &chat.auto_mode]
        .into_iter()
        .flatten()
        .map(String::as_str)
        .collect();
    document.mode_or_first(&wanted)
}

/// Whether a character goes by its personality in the mode `mode`.
pub fn is_personal(mode: Option<&str>) -> bool {
    mode.is_some_and(|mode| same_mode(mode, "assistant") || same_mode(mode, "companion"))
}

/// The chat's first character, the one it began with: its card, its ID there
/// and the card as the chat has it.
pub fn first(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<(i64, String, Document)> {
    first_if_any(db, user, chat_id)?.context(
        Fail::said(Code::NotPossible, "the chat has no character")
            .with("what", "chat_no_character"),
    )
}

/// [`first`], none in a chat without a character.
fn first_if_any(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
) -> anyhow::Result<Option<(i64, String, Document)>> {
    let Some(first) = chats::participants(db, user, chat_id)?
        .into_iter()
        .min_by_key(|one| one.id)
    else {
        return Ok(None);
    };
    let card_id = cards::card_of(db, user, first.version_id)?.ok_or(NotFound("card"))?;
    Ok(Some((
        card_id,
        first.character,
        cards::document_of(db, first.version_id)?,
    )))
}

/// What an assistant needs of the database, which `cw_store::assistant` gives.
pub trait Storage {
    /// Sets the chat to the mode `mode`, or none.
    fn set_chat_mode(&self, user: i64, chat_id: i64, mode: Option<&str>) -> anyhow::Result<()>;
    /// Keeps the mode the chat picked: whether it is another than before.
    fn keep_auto_mode(&self, user: i64, chat_id: i64, mode: &str) -> anyhow::Result<bool>;
    /// A character's tools switched off (a JSON list) and whether it remembers,
    /// where they were kept.
    fn personality(&self, card_id: i64, character: &str) -> anyhow::Result<Option<(String, bool)>>;
    /// Keeps them for a character of the user's card: whether the user has it.
    fn keep_personality(
        &self,
        user: i64,
        card_id: i64,
        character: &str,
        off: &str,
        memory: bool,
    ) -> anyhow::Result<bool>;
}

/// Sets the chat to the mode `mode` of its card, or has it pick by itself
/// (none). Answers the chat as it is then.
pub fn set_mode(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    mode: Option<&str>,
) -> anyhow::Result<Chat> {
    let mode = match mode {
        Some(asked) => {
            let modes = first(db, user, chat_id)?.2.modes();
            let mode = modes.into_iter().find(|mode| same_mode(mode, asked));
            Some(mode.with_context(|| {
                Fail::said(
                    Code::NotPossible,
                    format!("{asked:?} is no mode of this chat"),
                )
                .with("what", "chat_mode")
            })?)
        }
        None => None,
    };
    db.set_chat_mode(user, chat_id, mode.as_deref())?;
    Ok(chats::get(db, user, chat_id)?.ok_or(NotFound("chat"))?)
}

/// What the picker of the chat's mode is given, where the chat picks by itself
/// among two modes or more.
pub struct ToPick {
    pub modes: Vec<String>,
    /// The mode it is in now.
    pub current: String,
    /// The newest messages, each as "who: text".
    pub newest: Vec<String>,
}

/// What the picker of the chat's mode is given; none where the user set the
/// mode, or the chat's card has fewer than two, or nothing is said yet.
pub fn to_pick(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
) -> anyhow::Result<Option<ToPick>> {
    let Some((_, _, document)) = first_if_any(db, user, chat.id)? else {
        return Ok(None);
    };
    let modes = document.modes();
    if !picks_itself(chat.mode.as_deref(), &modes) {
        return Ok(None);
    }
    let Some(current) = mode_of(&document, chat).filter(|_| modes.len() > 1) else {
        return Ok(None);
    };
    let said: Vec<String> = chats::path_to(db, chat.id, chat.head_id)?
        .into_iter()
        .filter(|m| m.complete && !m.content.trim().is_empty())
        .map(|m| {
            let who = match m.role {
                Role::User => "User",
                Role::Assistant => "Character",
                Role::System => "Narrator",
            };
            let text: String = m.content.chars().take(MESSAGE_LIMIT).collect();
            format!("{who}: {text}")
        })
        .collect();
    if said.is_empty() {
        return Ok(None);
    }
    let newest = said[said.len().saturating_sub(NEWEST)..].to_vec();
    Ok(Some(ToPick {
        modes,
        current,
        newest,
    }))
}

/// Whether a chat set to `set` picks its mode by itself: the user set none,
/// or one its card no longer has.
fn picks_itself(set: Option<&str>, modes: &[String]) -> bool {
    set.is_none_or(|set| !modes.iter().any(|mode| same_mode(mode, set)))
}

/// Keeps the mode the chat picked; answers whether it is another than before.
pub fn keep_picked(db: &dyn Storage, user: i64, chat_id: i64, mode: &str) -> anyhow::Result<bool> {
    db.keep_auto_mode(user, chat_id, mode)
}

/// Asks the worker model which of the modes the newest messages are in; none
/// where it names none of them.
pub async fn pick(
    http: &Http,
    provider: &Provider,
    asked: &ToPick,
) -> anyhow::Result<Option<String>> {
    let (modes, newest) = (&asked.modes, &asked.newest[..]);
    let room = provider
        .sampling
        .context()
        .saturating_sub(tokens::estimate(PICK) + 200);
    let mut shown = newest;
    let question = loop {
        let text = format!(
            "<modes>{}</modes>\n<current_mode>{}</current_mode>\n<newest_messages>\n{}\n</newest_messages>",
            modes.join(", "),
            asked.current,
            shown.join("\n\n")
        );
        if tokens::estimate(&text) <= room || shown.len() <= 1 {
            break text;
        }
        shown = &shown[1..];
    };
    let prompt = [
        PromptMessage::new(Role::System, PICK),
        PromptMessage::new(Role::User, question),
    ];
    let answer = object(&answer(http, provider, &prompt).await?).context(
        Fail::said(Code::ModelAnswer, "the worker model's mode cannot be read")
            .with("what", "worker_mode"),
    )?;
    let named = answer["mode"].as_str().unwrap_or_default().trim();
    Ok(modes.iter().find(|mode| same_mode(mode, named)).cloned())
}

/// A kind of tool a character may be let use as an assistant.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Tool {
    Web,
    Files,
    Commands,
    Pictures,
    /// Code mode, which is the chat's own since milestone 47 and no longer
    /// offered here; kept for personalities stored before.
    Code,
    /// Starting a coding task (`start_coding_task`), this computer's account's alone.
    Coding,
    /// Cardwave itself (`tools::app`).
    Cardwave,
}

/// The tools the account offers a reply: those its settings switch on and it
/// can use (files and commands with a folder and on this computer's account,
/// pictures with an image model), and coding tasks on this computer's account.
pub fn offered(tools: &Tools, owner: bool, image: bool) -> Vec<Tool> {
    let folder = owner && tools.folder.is_some();
    [
        (Tool::Web, tools.web),
        (Tool::Files, folder && tools.files),
        (
            Tool::Commands,
            folder && tools.commands && cw_coding::tools::sandbox::AVAILABLE,
        ),
        (Tool::Pictures, tools.pictures && image),
        (Tool::Coding, owner),
        (Tool::Cardwave, tools.app),
    ]
    .into_iter()
    .filter_map(|(tool, on)| on.then_some(tool))
    .collect()
}

/// Switches off in `tools` those of `off`; answers whether coding tasks stay on.
pub fn restrict(tools: &mut Tools, off: &[Tool]) -> bool {
    let on = |tool| !off.contains(&tool);
    tools.web &= on(Tool::Web);
    tools.files &= on(Tool::Files);
    tools.commands &= on(Tool::Commands);
    tools.pictures &= on(Tool::Pictures);
    tools.app &= on(Tool::Cardwave);
    on(Tool::Coding)
}

/// A character's personality, as the chat's side panel shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Personality {
    /// The tools the account offers, in their order.
    pub offered: Vec<Tool>,
    /// Those of all tools it may not use as an assistant.
    pub tools_off: Vec<Tool>,
    /// Whether it remembers, with the assistant's memory.
    pub memory: bool,
}

/// A change of a personality; what is left out stays.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangePersonality {
    pub tools_off: Option<Vec<Tool>>,
    pub memory: Option<bool>,
}

/// The tools the character `character` of the user's card `card_id` may not
/// use, and whether it remembers: none and yes where nothing was kept.
pub fn kept(db: &dyn Storage, card_id: i64, character: &str) -> anyhow::Result<(Vec<Tool>, bool)> {
    let row = db.personality(card_id, character)?;
    Ok(match row {
        Some((off, memory)) => (serde_json::from_str(&off).unwrap_or_default(), memory),
        None => (Vec::new(), true),
    })
}

/// Changes the personality of the character `character` of the user's card `card_id`.
pub fn change(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    character: &str,
    change: &ChangePersonality,
) -> anyhow::Result<()> {
    let (mut off, mut memory) = kept(db, card_id, character)?;
    if let Some(tools) = &change.tools_off {
        off.clear();
        for tool in tools {
            if !off.contains(tool) {
                off.push(*tool);
            }
        }
    }
    memory = change.memory.unwrap_or(memory);
    let off = serde_json::to_string(&off).unwrap_or_else(|_| "[]".into());
    let changed = db.keep_personality(user, card_id, character, &off, memory)?;
    ensure!(changed, NotFound("card"));
    Ok(())
}

/// Which memory a character has.
pub enum Remembering {
    /// The roleplay's, of the chat and the scene.
    Roleplay,
    /// The assistant's or companion's, of the user, kept with the character
    /// and shared by its chats; with the mode it is in.
    Personal(crate::memory::Personal, crate::memory::Mode),
    /// None: it is in a personal mode, and its personality does not remember.
    Off,
}

impl Remembering {
    /// Whose memory it is in the chat `chat_id`, in which mode; none where it does not remember.
    pub fn owner(self, chat_id: i64) -> Option<(crate::memory::Owner, crate::memory::Mode)> {
        use crate::memory::{Mode, Owner};
        match self {
            Self::Roleplay => Some((Owner::Chat(chat_id), Mode::Roleplay)),
            Self::Personal(personal, mode) => Some((Owner::Character(personal), mode)),
            Self::Off => None,
        }
    }
}

/// Which memory the character `character` of the card `card_id` has in the mode `mode`.
pub fn remembering(
    db: &dyn Storage,
    card_id: i64,
    character: &str,
    mode: Option<&str>,
) -> anyhow::Result<Remembering> {
    if !is_personal(mode) {
        return Ok(Remembering::Roleplay);
    }
    let mode = match mode.is_some_and(|mode| same_mode(mode, "assistant")) {
        true => crate::memory::Mode::Assistant,
        false => crate::memory::Mode::Companion,
    };
    Ok(match kept(db, card_id, character)?.1 {
        true => Remembering::Personal((card_id, character.to_string()), mode),
        false => Remembering::Off,
    })
}

/// Which memory the chat's first character has, in the mode it is in; none
/// in a chat without a character, as nobody there knows.
pub fn chat_remembering(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
) -> anyhow::Result<Remembering> {
    let Some((card_id, character, document)) = first_if_any(db, user, chat.id)? else {
        return Ok(Remembering::Off);
    };
    remembering(db, card_id, &character, mode_of(&document, chat).as_deref())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_chat_set_to_a_mode_its_card_no_longer_has_picks_by_itself() {
        let modes = ["Roleplay".to_string(), "Assistant".to_string()];
        assert!(picks_itself(None, &modes));
        assert!(!picks_itself(Some("assistant"), &modes));
        assert!(picks_itself(Some("Companion"), &modes));
    }
}

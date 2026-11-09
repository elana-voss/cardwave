//! What a reply's prompt is built from (`prompt_inputs`): the character with
//! its prompt preset (`prompt_presets::apply`) and its mode
//! (`assistant::mode_of`), its lore, and the messages of the branch in view.
//! The character is the card's in the language the AI writes in (Settings)
//! where the card has it; where its texts are in another, the AI is told to
//! reply in that one (`language_of_reply`, `written_in`, at the end of
//! post-history).
//! A build's variables and the lorebook's timed state are kept on the message
//! it ended at (`Snapshot`, `save_prompt_state`), so going back in a chat
//! starts from what was true there.

use std::collections::{HashMap, HashSet};

use anyhow::Context;
use cw_ccv4::{Document, mapping};
use cw_core::NotFound;
use cw_core::languages;
use cw_core::{Code, Fail};
use cw_library::cards;
use cw_library::lorebooks;
use cw_prompt::{Character, ChatMessage, ChatState, Variables};
use serde::{Deserialize, Serialize};

use crate::prompt_presets;

use crate::chats::{Chat, LoreSource, get, lore_off, participants, path_to, persona_of};

/// What the prompt builder needs for the next reply in a chat.
pub struct PromptInputs {
    pub character: Character,
    pub state: ChatState,
    /// The card the character is from, its ID there, and the mode it is in
    /// (`assistant::mode_of`); no card in a chat without a character.
    pub card_id: Option<i64>,
    pub character_id: String,
    pub mode: Option<String>,
    /// The lorebooks of the library whose entries are among the character's:
    /// those the chat has, through its cards or taken along.
    pub library: Vec<i64>,
    /// The names of the chat's other characters, as the prompt has them.
    pub others: Vec<String>,
    /// When each of `state.messages` was written, in milliseconds since 1970.
    pub times: Vec<i64>,
}

/// What a prompt build leaves behind, kept on the message the build ended at.
#[derive(Default, Serialize, Deserialize)]
pub(super) struct Snapshot {
    pub(super) variables: Variables,
    pub(super) stickies: HashMap<String, usize>,
    pub(super) cooldowns: HashMap<String, usize>,
    /// On a greeting: the variables its own macros set, which a reply made
    /// straight after it starts from.
    #[serde(default, skip_serializing_if = "Variables::is_empty")]
    pub(super) opening: Variables,
    /// How many messages the build saw (the branch up to the one it is kept
    /// on), whose macros' effects the variables hold (`ChatState::settled`).
    #[serde(default)]
    pub(super) settled: usize,
}

/// Loads what the prompt builder needs for the next reply of `speaker` (a
/// participant id; when unset the one the chat began with, which joined
/// first).
///
/// The variables and the lorebook's timed state are those of the branch in
/// view, as they stood before its newest message was answered: going back in a
/// chat or asking for another reply starts from what was true at that point.
/// In a chat with several characters the others' messages carry their names.
pub fn prompt_inputs(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    speaker: Option<i64>,
) -> anyhow::Result<PromptInputs> {
    let chat = get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    prompt_inputs_after(db, user, &chat, speaker, chat.head_id)
}

/// [`prompt_inputs`] for a reply that comes after the message `after` instead
/// of after the chat's head. Another version of a message is written for the
/// chat as it was before that message.
pub fn prompt_inputs_after(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    speaker: Option<i64>,
    after: Option<i64>,
) -> anyhow::Result<PromptInputs> {
    let chat_id = chat.id;
    let participants = participants(db, user, chat_id)?;
    if participants.is_empty() && speaker.is_none() {
        return plain_inputs(db, user, chat_id, after);
    }
    let participant = match speaker {
        Some(id) => participants.iter().find(|p| p.id == id),
        None => participants.iter().min_by_key(|p| p.id),
    }
    .context(
        Fail::said(Code::NotPossible, "the chat has no such character")
            .with("what", "chat_character"),
    )?;

    let card_id =
        cards::card_of(db, user, participant.version_id)?.ok_or(NotFound("card version"))?;
    // What the chat adds to the character's own lorebooks, and what it leaves out of all of them.
    let off = lore_off(db, chat_id)?;
    let nothing = HashSet::new();
    let left_out = |source| off.get(&source).unwrap_or(&nothing);
    let taken = lorebooks::of_chat(db, chat_id)?;
    let added: Vec<mapping::Added<'_>> = taken
        .iter()
        .map(|book| mapping::Added {
            key: lorebooks::key(book.id),
            document: &book.document,
            reference: &book.reference,
            off: left_out(LoreSource::LorebookId(book.id)),
        })
        .collect();
    let mut character = None;
    let mut mode = None;
    let mut other_language = false;
    // A card in the language the AI writes in, where it has it (`Document::in_language`).
    let language = cw_library::settings::get(db, user)?.language;
    let mut names = HashMap::new();
    for other in &participants {
        let document = cards::document_of(db, other.version_id)?;
        if other.id == participant.id {
            mode = crate::assistant::mode_of(&document, chat);
            let (used, in_other) = language_of_reply(&document, &other.character, &language);
            other_language = in_other;
            character = mapping::character_in(
                &document,
                used,
                left_out(LoreSource::CardId(card_id)),
                &added,
                mode.as_deref(),
            );
        } else {
            names.insert(other.id, document.character_name(&other.character));
        }
    }
    let mut character = character.with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("the card has no character {:?}", participant.character),
        )
        .with("what", "card_character")
    })?;
    prompt_presets::apply(db, user, chat, &mut character)?;
    if other_language {
        let line = format!("Write your replies in {}.", languages::name_of(&language));
        after_chat(&mut character, &line);
    }
    if participants.len() > 1 {
        after_chat(&mut character, ONLY_AS);
    }

    let (persona_name, persona_description) = match persona_of(db, user, chat)? {
        Some(persona) => (persona.name, persona.description),
        None => (
            cw_library::settings::user_stand_in(db, user)?.to_string(),
            String::new(),
        ),
    };
    let (messages, times) = chat_messages(db, chat_id, after, &names)?;
    let snapshot = snapshot_at(db, chat_id, after)?;
    let others = participants
        .iter()
        .filter_map(|p| names.get(&p.id).cloned())
        .collect();
    Ok(PromptInputs {
        character,
        state: ChatState {
            persona_name,
            persona_description,
            messages,
            local_variables: snapshot.variables,
            active_stickies: snapshot.stickies,
            active_cooldowns: snapshot.cooldowns,
            meaning: None,
            settled: snapshot.settled,
        },
        card_id: Some(card_id),
        character_id: participant.character.clone(),
        mode,
        library: taken.iter().map(|book| book.id).collect(),
        others,
        times,
    })
}

/// The character `id` of `document` as the reply is written: its texts in
/// `language` where the card has them (`Document::in_language`), and whether
/// they are in another, which the AI is then told to reply in. A card whose
/// language cannot be told is left as it is.
fn language_of_reply<'a>(document: &'a Document, id: &'a str, language: &str) -> (&'a str, bool) {
    let used = document.in_language(id, language);
    let other = document
        .language_of(used)
        .is_some_and(|own| !languages::same(&own, language));
    (used, other)
}

/// What the builds before left at the message `after` (`Snapshot`).
fn snapshot_at(db: &dyn Storage, chat_id: i64, after: Option<i64>) -> anyhow::Result<Snapshot> {
    let stored: Option<String> = match after {
        Some(head) => db.state_above(head)?,
        None => None,
    };
    Ok(match stored {
        Some(text) => serde_json::from_str(&text)?,
        // No reply was built on the way to the message. If it is a greeting,
        // there is what its own macros set.
        None => Snapshot {
            variables: opening_of(db, chat_id, after)?,
            ..Default::default()
        },
    })
}

/// The messages up to `after` as the prompt has them, another character's
/// with its name (`names`) before it, each with the pictures attached to it,
/// and when each was written.
fn chat_messages(
    db: &dyn crate::chats::Storage,
    chat_id: i64,
    after: Option<i64>,
    names: &HashMap<i64, String>,
) -> anyhow::Result<(Vec<ChatMessage>, Vec<i64>)> {
    let path = path_to(db, chat_id, after)?;
    let ids: Vec<i64> = path.iter().map(|m| m.id).collect();
    let times = path.iter().map(|m| m.created_at).collect();
    let mut pictures = crate::attachments::pictures(db, &ids)?;
    let messages = path
        .into_iter()
        .map(|m| {
            let said = crate::images::told(&m.content).unwrap_or(m.content);
            let content = match m.speaker_id.and_then(|id| names.get(&id)) {
                Some(name) => format!("{name}: {said}"),
                None => said,
            };
            ChatMessage {
                id: m.id.to_string(),
                role: m.role,
                content,
                token_count: m.token_count,
                complete: m.complete,
                pictures: pictures.remove(&m.id).unwrap_or_default(),
            }
        })
        .collect();
    Ok((messages, times))
}

/// [`prompt_inputs_after`] of a chat without a character: the chat alone, with
/// no card, persona, prompt preset, lore or variables, for the AI itself, told
/// the user's one text of Settings (`plain_prompt`) as its system prompt.
fn plain_inputs(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    after: Option<i64>,
) -> anyhow::Result<PromptInputs> {
    let (messages, times) = chat_messages(db, chat_id, after, &HashMap::new())?;
    Ok(PromptInputs {
        character: Character {
            system_prompt: cw_library::settings::get(db, user)?.plain_prompt,
            ..Character::default()
        },
        state: ChatState {
            messages,
            ..Default::default()
        },
        card_id: None,
        character_id: String::new(),
        mode: None,
        library: Vec::new(),
        others: Vec::new(),
        times,
    })
}

/// What a prompt's inputs need of the database, which `cw_store::chat_messages` gives.
pub trait Storage {
    /// The state kept on the nearest message above `head` that has one.
    fn state_above(&self, head: i64) -> anyhow::Result<Option<String>>;
    /// The state kept on a message of the chat: `None` where there is no such
    /// message, `Some(None)` where it keeps none.
    fn message_state(
        &self,
        chat_id: i64,
        message_id: Option<i64>,
    ) -> anyhow::Result<Option<Option<String>>>;
    /// Keeps `state` on the message `newest` and the token counts
    /// `(message, tokens)` on those of the chat that have none yet, at once.
    fn keep_prompt_state(
        &self,
        chat_id: i64,
        newest: Option<i64>,
        state: &str,
        counted: &[(i64, i64)],
    ) -> anyhow::Result<()>;
}

/// What a reply in a chat of several is told after the chat, as SillyTavern's
/// group nudge has it: else a model may answer as someone the user named.
const ONLY_AS: &str = "[Write the next reply only as {{char}}.]";

/// Tells the AI `line` after the chat: to write in the language of Settings'
/// "Language the AI writes in" where the card is in another, or [`ONLY_AS`].
fn after_chat(character: &mut Character, line: &str) {
    let after = &mut character.post_history_instructions;
    if !after.trim().is_empty() {
        after.push_str(
            "

",
        );
    }
    after.push_str(line);
}

/// What a message's own macros set, if it is a greeting that set any.
fn opening_of(
    db: &dyn Storage,
    chat_id: i64,
    message_id: Option<i64>,
) -> anyhow::Result<Variables> {
    let stored = db.message_state(chat_id, message_id)?;
    let snapshot = stored
        .flatten()
        .map(|text| serde_json::from_str::<Snapshot>(&text))
        .transpose()?;
    Ok(snapshot
        .map(|snapshot| snapshot.opening)
        .unwrap_or_default())
}

/// Keeps what a prompt build changed: the variables and the lorebook's timed
/// state on the newest message the build saw, and the messages' token counts.
pub fn save_prompt_state(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    state: &ChatState,
) -> anyhow::Result<()> {
    get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    let newest = state.messages.last().and_then(|m| m.id.parse::<i64>().ok());
    let snapshot = serde_json::to_string(&Snapshot {
        variables: state.local_variables.clone(),
        stickies: state.active_stickies.clone(),
        cooldowns: state.active_cooldowns.clone(),
        opening: opening_of(db, chat_id, newest)?,
        settled: state.messages.len(),
    })?;
    let counted: Vec<(i64, i64)> = state
        .messages
        .iter()
        .filter_map(
            |message| match (message.id.parse::<i64>(), message.token_count) {
                (Ok(id), Some(tokens)) => Some((id, tokens as i64)),
                _ => None,
            },
        )
        .collect();
    db.keep_prompt_state(chat_id, newest, &snapshot, &counted)
}

//! "New chat with these characters", in the menu of a chat of several: a new
//! chat with the same characters in the same speaking order, the first's
//! greeting opening it as `create` has it and each other's first greeting,
//! where it has one, after it, keeping what its macros set as `create` keeps
//! the first's; with the chat's settings: its persona, turn
//! order and the character picked to reply, prompt preset, mode, reply length,
//! Code mode, the characters muted, the lore it leaves out and the lorebooks
//! it took along.

use anyhow::ensure;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::cards;
use cw_library::personas;
use cw_library::settings;
use cw_prompt::Role;

use crate::chats::inputs::Snapshot;
use crate::chats::{IN_TRASH, NewChat, NewMessage, append, create, get, greeted, participants};

/// Starts the new chat of `chat_id`'s characters; answers its ID.
pub fn again(db: &dyn crate::chats::Storage, user: i64, chat_id: i64) -> anyhow::Result<i64> {
    let chat = get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    ensure!(
        !chat.trashed,
        Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
    );
    let cast = participants(db, user, chat_id)?;
    ensure!(
        !cast.is_empty(),
        Fail::said(
            Code::NotPossible,
            "a chat without a character has no characters"
        )
        .with("what", "chat_without_character")
    );
    let characters: Vec<(i64, &str)> = cast
        .iter()
        .map(|p| (p.version_id, p.character.as_str()))
        .collect();
    let new = NewChat {
        characters: &characters,
        persona_id: chat.persona_id,
        greeting: 0,
    };
    let to = create(db, user, &new)?;
    let joined = participants(db, user, to)?;
    let pairs: Vec<(i64, i64)> = cast
        .iter()
        .zip(&joined)
        .map(|(o, n)| (o.id, n.id))
        .collect();
    db.copy_chat_settings(chat_id, to, &pairs)?;
    let user_name = match chat.persona_id {
        Some(id) => personas::usable(db, user, id)?.name,
        None => settings::user_stand_in(db, user)?.to_string(),
    };
    let language = settings::get(db, user)?.language;
    for one in joined.iter().skip(1) {
        let document = cards::document(db, user, one.version_id)?;
        let shown = document.in_language(&one.character, &language);
        let Some(greeting) = document.greetings(shown, true).into_iter().next() else {
            continue;
        };
        let (text, set) = greeted(&greeting, &document.character_name(shown), &user_name);
        let message = NewMessage {
            role: Role::Assistant,
            speaker_id: Some(one.id),
            content: &text,
            complete: true,
        };
        let id = append(db, user, to, &message)?;
        // What its macros set joins what the greetings before it set, as a reply after it starts from.
        if !set.is_empty() {
            let before: Option<Snapshot> = db
                .state_above(id)?
                .map(|text| serde_json::from_str(&text))
                .transpose()?;
            let mut opening = before.map(|snapshot| snapshot.opening).unwrap_or_default();
            opening.extend(set);
            let snapshot = Snapshot {
                variables: opening.clone(),
                opening,
                ..Default::default()
            };
            db.keep_prompt_state(to, Some(id), &serde_json::to_string(&snapshot)?, &[])?;
        }
    }
    Ok(to)
}

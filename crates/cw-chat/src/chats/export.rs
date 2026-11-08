//! A chat written out as the file SillyTavern keeps a chat in and takes on
//! "Import chat" (`.jsonl`: the head, then one line per message, oldest first),
//! for one character and a group alike; `GET /api/chats/{id}/export`.
//!
//! It holds the branch in view, each character's message with the versions that
//! character wrote in its place (`swipes`, `swipe_id`), and in the head the
//! memories read from it that hold there (`cardwave_memories`). Left out: other branches,
//! the user's other versions, a reply still being written, and what a chat
//! keeps besides (persona beyond its name, turn order, lorebooks, versions,
//! the star).
//!
//! Read from SillyTavern's source (`release`, 2026-09-14): `saveChat`,
//! `saveReply`, `ensureSwipes`, `getFirstMessage` in `public/script.js` write
//! the lines; `/api/chats/import` and `/api/chats/group/import` take the file.

use chrono::{DateTime, SecondsFormat, Utc};
use cw_core::NotFound;
use cw_library::cards::{Exported, file_stem};
use cw_prompt::Role;
use serde::Serialize;

use crate::chats::Message;
use crate::memory::{self, Kind};

/// A chat as it is written out: the chat, its characters as (ID, name) in the
/// order they joined, and for each message of the branch in view what its
/// writer wrote in its place, oldest first, each with whether it is in view.
pub type WrittenOut = (crate::chats::Chat, Vec<(i64, String)>, Vec<(Message, bool)>);

/// What writing a chat out needs of the database, which `cw_store::chat_messages` gives.
pub trait Storage {
    /// The chat of `user` as [`export`] writes it out, all read at one moment.
    fn chat_written_out(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<WrittenOut>>;
}

/// What a message is under that neither the user nor a character wrote, as
/// SillyTavern's own narrator is.
const NARRATOR: &str = "System";

/// The file's first line. An import asks it for one of these keys.
/// `chat_metadata` is where SillyTavern keeps a chat's own settings, of which a
/// chat from here has none, and where its memories go. The names it writes as
/// "unused" and does not read: they are told for whoever else reads the file.
#[derive(Serialize)]
struct Head<'a> {
    chat_metadata: Settings,
    user_name: &'a str,
    character_name: &'a str,
}

/// A chat's own settings in SillyTavern: none, and the chat's memories that
/// hold on the branch in view, under a key of the app's own, which SillyTavern
/// keeps and does not read.
#[derive(Serialize)]
struct Settings {
    #[serde(rename = "cardwave_memories", skip_serializing_if = "Vec::is_empty")]
    memories: Vec<Remembered>,
}

/// A memory read from this chat as the file has it: who know it by name.
#[derive(Serialize)]
struct Remembered {
    kind: Kind,
    text: String,
    known_by: Vec<String>,
}

/// One message.
#[derive(Serialize)]
struct Line<'a> {
    /// Who wrote it, which is what it is shown under.
    name: &'a str,
    is_user: bool,
    /// True hides a message from SillyTavern's prompts; no message here is hidden.
    is_system: bool,
    send_date: String,
    mes: &'a str,
    extra: Extra,
    #[serde(flatten)]
    versions: Option<Versions<'a>>,
}

/// The versions of a character's message, oldest first.
#[derive(Serialize)]
struct Versions<'a> {
    /// Which of them is the message: its place in `swipes`.
    swipe_id: usize,
    swipes: Vec<&'a str>,
    /// What is known of each besides its text.
    swipe_info: Vec<SwipeInfo>,
}

#[derive(Serialize)]
struct SwipeInfo {
    send_date: String,
    extra: Extra,
}

/// What SillyTavern keeps of a message besides its text. From here only that
/// a message is the narrator's.
#[derive(Default, Serialize)]
struct Extra {
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    kind: Option<&'static str>,
}

fn moment(ms: i64) -> DateTime<Utc> {
    DateTime::from_timestamp_millis(ms).unwrap_or_default()
}

/// A moment as SillyTavern writes one: `2026-10-12T09:15:02.123Z`.
fn date(ms: i64) -> String {
    moment(ms).to_rfc3339_opts(SecondsFormat::Millis, true)
}

/// The chat as a file SillyTavern opens as a chat: its branch in view, every
/// character's message with its other versions. The user is called what the
/// chat's persona is called now, and a character what the list of chats calls
/// it. The file is named after the chat and the moment it was started, as
/// SillyTavern names a chat: `Mira - 2026-10-12@09h15m02s.jsonl`.
pub fn export(db: &dyn crate::chats::Storage, user: i64, chat_id: i64) -> anyhow::Result<Exported> {
    // The chat, its characters as (ID, name) in the order they joined, the first
    // the one the chat is called after (`turn::reorder`), and for each
    // message of the branch in view what its writer wrote in its place to the
    // end, oldest first, each with whether it is the one in view. A writer is
    // a role and a speaker: a character whose place in the chat is gone has no
    // speaker, as the user and the narrator have none. All read at one moment.
    let read = db.chat_written_out(user, chat_id)?;
    let (chat, characters, messages) = read.ok_or(NotFound("chat"))?;
    let persona = crate::chats::persona_of(db, user, &chat)?;
    let stand_in = cw_library::settings::user_stand_in(db, user)?;
    let user_name = persona.as_ref().map_or(stand_in, |persona| &persona.name);
    // A chat without a character is with the AI itself.
    let first = characters.first().map_or("AI", |(_, name)| name);
    let called = |speaker| {
        characters
            .iter()
            .find(|(id, _)| Some(*id) == speaker)
            .map_or(first, |(_, name)| name)
    };

    let memories = match crate::assistant::chat_remembering(db, user, &chat)?.owner(chat.id) {
        Some((owner, _)) => memory::of_chat(db, user, &chat, &owner)?
            .into_iter()
            .map(|(entry, known_by)| Remembered {
                kind: entry.kind,
                text: entry.text,
                known_by,
            })
            .collect(),
        None => Vec::new(),
    };
    let head = Head {
        chat_metadata: Settings { memories },
        user_name,
        character_name: first,
    };
    let mut lines = vec![serde_json::to_string(&head)?];
    // The messages in one place have one message before them. A place of which
    // nothing was read (a first reply that is still being written) is not here.
    for place in messages.chunk_by(|(one, _), (other, _)| one.parent_id == other.parent_id) {
        // For a reply that is still being written stands the newest that is whole.
        let at = place
            .iter()
            .position(|(_, shown)| *shown)
            .unwrap_or(place.len() - 1);
        let shown = &place[at].0;
        let (name, extra) = match shown.role {
            Role::User => (user_name, Extra::default()),
            Role::Assistant => (called(shown.speaker_id), Extra::default()),
            Role::System => (
                NARRATOR,
                Extra {
                    kind: Some("narrator"),
                },
            ),
        };
        let versions = (shown.role == Role::Assistant).then(|| Versions {
            swipe_id: at,
            swipes: place
                .iter()
                .map(|(version, _)| version.content.as_str())
                .collect(),
            swipe_info: place
                .iter()
                .map(|(version, _)| SwipeInfo {
                    send_date: date(version.created_at),
                    extra: Extra::default(),
                })
                .collect(),
        });
        let line = Line {
            name,
            is_user: shown.role == Role::User,
            is_system: false,
            send_date: date(shown.created_at),
            mes: &shown.content,
            extra,
            versions,
        };
        lines.push(serde_json::to_string(&line)?);
    }
    let started = moment(chat.created_at).format("%Y-%m-%d@%Hh%Mm%Ss");
    Ok(Exported {
        file_name: format!("{} - {started}.jsonl", file_stem(&chat.title, "chat")),
        data: lines.join("\n").into_bytes(),
    })
}

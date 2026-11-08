//! Chats as SQLite keeps them (`chats::Storage`): a chat's row, its
//! characters (`chat_characters`), what it leaves out of its lore, the
//! lorebooks it took along and the tools it lets act without asking.

use std::collections::{HashMap, HashSet};

use anyhow::anyhow;
use cw_ccv4::display;
use cw_chat::chats::{
    CARD_IN_TRASH, Chat, ChatCard, ChatReply, ChatSummary, ChatTalk, LoreSource, NewMessage,
    Opening, Storage,
};
use cw_chat::prompt_presets::ChatPromptPreset;
use cw_core::now_ms;
use cw_core::{Code, Fail};
use cw_library::cards::Show;
use cw_prompt::Role;
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::chat_messages::insert_message;
use crate::{Db, shown};

/// Whether a reply is being generated in the chat: it has a message that is not complete.
pub(super) fn writing(conn: &Connection, chat_id: i64) -> rusqlite::Result<bool> {
    conn.query_row(
        "select exists (select 1 from messages where chat_id = ?1 and complete = 0)",
        [chat_id],
        |r| r.get(0),
    )
}

pub(super) fn chat(row: &Row<'_>) -> rusqlite::Result<Chat> {
    let title: String = row.get(1)?;
    let trashed_at: Option<i64> = row.get(6)?;
    Ok(Chat {
        id: row.get(0)?,
        title,
        persona_id: row.get(2)?,
        head_id: row.get(3)?,
        favorite: row.get(4)?,
        archived: row.get(5)?,
        trashed: trashed_at.is_some(),
        deleted_at: trashed_at.map(cw_library::trash::deleted_at),
        created_at: row.get(7)?,
        updated_at: row.get(8)?,
        turn_order: crate::chat_turns::turn_order(row.get_ref(9)?).map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(9, rusqlite::types::Type::Text, e.into())
        })?,
        replier_id: row.get(10)?,
        prompt_preset: ChatPromptPreset::of(row.get(11)?, row.get(12)?),
        mode: row.get(13)?,
        auto_mode: row.get(14)?,
        reply_length: row.get(15)?,
        code_mode: row.get(16)?,
        talk_pause: row.get(17)?,
        talk_replies: row.get(18)?,
    })
}

pub(super) fn chat_of(
    conn: &Connection,
    user: i64,
    chat_id: i64,
) -> rusqlite::Result<Option<Chat>> {
    conn.query_row(
        &format!("select {CHAT} from chats where id = ?1 and user_id = ?2"),
        [chat_id, user],
        chat,
    )
    .optional()
}

/// What [`chat`] reads of a chat, in its order: the columns to select from `chats`.
const CHAT: &str = "id, title, persona_id, head_id, favorite, archived, trashed_at, created_at, updated_at,
    turn_order, replier_id, prompt_preset_own, prompt_preset_id, mode, auto_mode, reply_length, code_mode,
    talk_pause, talk_replies";

impl Storage for Db {
    fn writing(&self, chat_id: i64) -> anyhow::Result<bool> {
        Ok(self.with(|conn| writing(conn, chat_id))?)
    }

    fn start_plain_chat(&self, user: i64) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into chats (user_id, title, titled, created_at, updated_at) values (?1, '', 0, ?2, ?2)",
                params![user, now_ms()],
            )?;
            Ok(conn.last_insert_rowid())
        })?)
    }

    fn start_chat(&self, user: i64, opening: &Opening<'_>) -> anyhow::Result<anyhow::Result<i64>> {
        let Opening {
            title,
            new,
            names,
            greetings,
        } = *opening;
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            // A chat is in the trash while one of its cards is, so none starts with such a card; and it has a
            // character once, whichever versions of its card are named.
            let mut seen = HashSet::new();
            for ((version_id, character), name) in new.characters.iter().zip(names) {
                let (card_id, trashed): (i64, bool) = tx.query_row(
                    "select c.id, c.trashed_at is not null from card_versions v join cards c on c.id = v.card_id where v.id = ?1",
                    [version_id],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )?;
                if trashed {
                    return Ok(Err(anyhow!(Fail::said(Code::InTrash, CARD_IN_TRASH).with("what", "card_to_chat"))));
                }
                if !seen.insert((card_id, *character)) {
                    return Ok(Err(anyhow!(Fail::said(Code::Taken, format!("{name} is in this chat twice")).with("what", "chat_character_twice").with("name", name.to_string()))));
                }
            }
            let now = now_ms();
            tx.execute(
                "insert into chats (user_id, title, titled, persona_id, created_at, updated_at) values (?1, ?2, 0, ?3, ?4, ?4)",
                params![user, title, new.persona_id, now],
            )?;
            let chat_id = tx.last_insert_rowid();
            let mut first_speaker = None;
            for (position, ((version_id, character), name)) in new.characters.iter().zip(names).enumerate() {
                tx.execute(
                    "insert into chat_characters (chat_id, position, version_id, character, name)
                     values (?1, ?2, ?3, ?4, ?5)",
                    params![chat_id, position as i64, version_id, character, name],
                )?;
                first_speaker.get_or_insert(tx.last_insert_rowid());
            }
            let mut opening = None;
            for (index, (greeting, state)) in greetings.iter().enumerate() {
                let message =
                    NewMessage { role: Role::Assistant, speaker_id: first_speaker, content: greeting, complete: true };
                let id = insert_message(&tx, chat_id, None, &message, state.as_deref())?;
                if index == new.greeting || opening.is_none() {
                    opening = Some(id);
                }
            }
            tx.execute("update chats set head_id = ?2 where id = ?1", params![chat_id, opening])?;
            tx.commit()?;
            Ok(Ok(chat_id))
        })?)
    }

    fn chat_summaries(
        &self,
        user: i64,
        show: Show,
        searching: bool,
    ) -> anyhow::Result<Vec<ChatSummary>> {
        // Both queries ask for the same chats: the chats, then their characters.
        let shown = |chats: &str| shown(show, chats, searching);
        Ok(self.with(|conn| {
            // Only the start of the newest message is read: it can be of any length.
            // It stands in `excerpt` as it is written until the chats to list are known.
            let mut query = conn.prepare(&format!(
                "select {CHAT}, (select substr(m.content, 1, ?2) from messages m where m.id = chats.head_id) as newest
                 from chats where user_id = ?1 and trashed_at is null{}",
                shown("chats")
            ))?;
            let mut chats: Vec<ChatSummary> = query
                .query_map(params![user, display::EXCERPT_SOURCE as i64], |row| {
                    let newest: Option<String> = row.get("newest")?;
                    Ok(ChatSummary { chat: chat(row)?, names: Vec::new(), cards: Vec::new(), excerpt: newest.unwrap_or_default() })
                })?
                .collect::<rusqlite::Result<_>>()?;
            let listed: HashMap<i64, usize> = chats.iter().enumerate().map(|(at, one)| (one.chat.id, at)).collect();
            let mut query = conn.prepare(&format!(
                "select p.chat_id, coalesce(p.name, p.character), c.id, c.title, p.version_id
                 from chat_characters p join chats t on t.id = p.chat_id
                 join card_versions v on v.id = p.version_id join cards c on c.id = v.card_id
                 where t.user_id = ?1 and t.trashed_at is null{} order by p.chat_id, p.id",
                shown("t")
            ))?;
            let mut characters = query.query([user])?;
            while let Some(row) = characters.next()? {
                let Some(&at) = listed.get(&row.get(0)?) else { continue };
                let one = &mut chats[at];
                one.names.push(row.get(1)?);
                let id = row.get(2)?;
                if one.cards.iter().all(|card| card.id != id) {
                    one.cards.push(ChatCard { id, title: row.get(3)?, version_id: row.get(4)? });
                }
            }
            Ok(chats)
        })?)
    }

    fn unnamed_characters(&self) -> anyhow::Result<Vec<(i64, i64, String)>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select id, version_id, character from chat_characters where name is null",
            )?;
            query
                .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
                .collect()
        })?)
    }

    fn name_characters(&self, named: &[(i64, String)]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            for (id, name) in named {
                tx.execute(
                    "update chat_characters set name = ?2 where id = ?1",
                    params![id, name],
                )?;
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn set_chat_favorite(&self, user: i64, chat_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(("chats", "chat"), user, chat_id, "favorite", &on)
    }

    fn set_chat_archived(&self, user: i64, chat_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(("chats", "chat"), user, chat_id, "archived", &on)
    }

    fn set_chat_reply(&self, user: i64, chat_id: i64, reply: &ChatReply) -> anyhow::Result<()> {
        let chat = ("chats", "chat");
        self.set(chat, user, chat_id, "reply_length", &reply.reply_length)?;
        self.set(chat, user, chat_id, "code_mode", &reply.code_mode)
    }

    fn set_chat_talk(&self, user: i64, chat_id: i64, talk: &ChatTalk) -> anyhow::Result<()> {
        let chat = ("chats", "chat");
        self.set(chat, user, chat_id, "talk_pause", &talk.talk_pause)?;
        self.set(chat, user, chat_id, "talk_replies", &talk.talk_replies)
    }

    fn set_chat_persona(
        &self,
        user: i64,
        chat_id: i64,
        persona_id: Option<i64>,
    ) -> anyhow::Result<()> {
        self.set(("chats", "chat"), user, chat_id, "persona_id", &persona_id)?;
        // What it left out of the persona's lorebooks it no longer has goes.
        self.with(|conn| crate::lorebooks::forget_gone(conn, chat_id))?;
        Ok(())
    }

    fn lore_off(&self, chat_id: i64) -> anyhow::Result<Vec<(bool, i64, String)>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select 0, card_id, reference from chat_lore_off where chat_id = ?1
                 union all select 1, lorebook_id, reference from chat_lorebook_off where chat_id = ?1",
            )?;
            query
                .query_map([chat_id], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
                .collect()
        })?)
    }

    fn set_lore_off(
        &self,
        chat_id: i64,
        source: LoreSource,
        reference: &str,
        on: bool,
    ) -> anyhow::Result<()> {
        let (table, column, id) = match source {
            LoreSource::CardId(id) => ("chat_lore_off", "card_id", id),
            LoreSource::LorebookId(id) => ("chat_lorebook_off", "lorebook_id", id),
        };
        let change = if on {
            format!("delete from {table} where chat_id = ?1 and {column} = ?2 and reference = ?3")
        } else {
            format!(
                "insert or ignore into {table} (chat_id, {column}, reference) values (?1, ?2, ?3)"
            )
        };
        self.with(|conn| conn.execute(&change, params![chat_id, id, reference]))?;
        Ok(())
    }

    fn take_lorebook(&self, chat_id: i64, lorebook_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert or ignore into chat_lorebooks (chat_id, lorebook_id, added_at) values (?1, ?2, ?3)",
                params![chat_id, lorebook_id, now_ms()],
            )
        })?;
        Ok(())
    }

    fn rename_chat(&self, user: i64, chat_id: i64, title: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update chats set title = ?3, titled = 1 where id = ?1 and user_id = ?2",
                params![chat_id, user, title],
            )
        })?;
        Ok(())
    }

    fn copy_chat_settings(&self, from: i64, to: i64, pairs: &[(i64, i64)]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "update chats set (turn_order, prompt_preset_own, prompt_preset_id, mode, reply_length, code_mode, talk_pause, talk_replies) =
                    (select turn_order, prompt_preset_own, prompt_preset_id, mode, reply_length, code_mode, talk_pause, talk_replies
                     from chats where id = ?1)
                 where id = ?2",
                [from, to],
            )?;
            for &(old, new) in pairs {
                tx.execute(
                    "update chat_characters set muted = (select muted from chat_characters where id = ?1) where id = ?2",
                    [old, new],
                )?;
                tx.execute(
                    "update chats set replier_id = ?3 where id = ?2 and (select replier_id from chats where id = ?1) = ?4",
                    [from, to, new, old],
                )?;
            }
            tx.execute(
                "insert or ignore into chat_lore_off (chat_id, card_id, reference)
                 select ?2, card_id, reference from chat_lore_off where chat_id = ?1",
                [from, to],
            )?;
            tx.execute(
                "insert or ignore into chat_lorebooks (chat_id, lorebook_id, added_at)
                 select ?2, lorebook_id, added_at from chat_lorebooks where chat_id = ?1",
                [from, to],
            )?;
            tx.execute(
                "insert or ignore into chat_lorebook_off (chat_id, lorebook_id, reference)
                 select ?2, lorebook_id, reference from chat_lorebook_off where chat_id = ?1",
                [from, to],
            )?;
            tx.commit()
        })?;
        Ok(())
    }

    fn chat(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<Chat>> {
        Ok(self.with(|conn| chat_of(conn, user, chat_id))?)
    }

    fn chats_of_card(&self, user: i64, card_id: i64) -> anyhow::Result<Vec<Chat>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "select {CHAT} from chats where user_id = ?1 and trashed_at is null and not archived and id in
                    (select p.chat_id from chat_characters p join card_versions v on v.id = p.version_id
                     where v.card_id = ?2)
                 order by updated_at desc, id desc"
            ))?;
            query.query_map([user, card_id], chat)?.collect()
        })?)
    }

    fn allow_tool(
        &self,
        user: i64,
        chat_id: i64,
        kind: cw_coding::tools::AskKind,
    ) -> anyhow::Result<()> {
        let kind = serde_json::to_value(kind)?;
        self.with(|conn| {
            conn.execute(
                "insert or ignore into chat_tools_allowed (chat_id, kind)
                 select id, ?3 from chats where id = ?1 and user_id = ?2",
                params![chat_id, user, kind.as_str()],
            )
        })?;
        Ok(())
    }

    fn tool_allowed(
        &self,
        user: i64,
        chat_id: i64,
        kind: cw_coding::tools::AskKind,
    ) -> anyhow::Result<bool> {
        let kind = serde_json::to_value(kind)?;
        Ok(self.with(|conn| {
            conn.query_row(
                "select exists (select 1 from chat_tools_allowed a join chats c on c.id = a.chat_id
                 where a.chat_id = ?1 and c.user_id = ?2 and a.kind = ?3)",
                params![chat_id, user, kind.as_str()],
                |r| r.get(0),
            )
        })?)
    }
}

impl cw_chat::chats::title::Storage for Db {
    fn unnamed_head(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<(Option<i64>, bool)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select head_id, exists (select 1 from chat_characters where chat_id = chats.id)
                   from chats where id = ?1 and user_id = ?2 and titled = 0",
                [chat_id, user],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn name_chat(&self, user: i64, chat_id: i64, title: &str) -> anyhow::Result<bool> {
        let named = self.with(|conn| {
            conn.execute(
                "update chats set title = ?3, titled = 1 where id = ?1 and user_id = ?2 and titled = 0",
                params![chat_id, user, title],
            )
        })?;
        Ok(named == 1)
    }
}

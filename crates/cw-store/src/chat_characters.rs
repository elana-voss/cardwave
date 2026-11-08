//! A chat's characters as SQLite keeps them (`chats::characters::Storage`):
//! `chat_characters`, a row per character in speaking order by `position`.

use std::collections::HashSet;

use anyhow::anyhow;
use cw_chat::chats::characters::{Participant, Storage};
use cw_chat::chats::{CARD_IN_TRASH, IN_TRASH};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use rusqlite::{OptionalExtension, params};

use crate::Db;
use crate::chat_messages::purge;

/// A chat's characters as named in it, in the order they joined: the export's and the memory's.
pub(super) fn cast_of(
    conn: &rusqlite::Connection,
    chat_id: i64,
) -> rusqlite::Result<Vec<(i64, String)>> {
    let mut query = conn.prepare_cached(
        "select id, coalesce(name, character) from chat_characters where chat_id = ?1 order by id",
    )?;
    query
        .query_map([chat_id], |r| Ok((r.get(0)?, r.get(1)?)))?
        .collect()
}

impl Storage for Db {
    fn add_participant(
        &self,
        chat_id: i64,
        card_id: i64,
        version_id: i64,
        character: &str,
        name: &str,
    ) -> anyhow::Result<anyhow::Result<i64>> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            // Asked where it is written: a chat is in the Trash while one of its cards is.
            let card_trashed: bool = tx.query_row(
                "select trashed_at is not null from cards where id = ?1",
                [card_id],
                |r| r.get(0),
            )?;
            if card_trashed {
                return Ok(Err(anyhow!(Fail::said(Code::InTrash, CARD_IN_TRASH).with("what", "card_to_chat"))));
            }
            let there: bool = tx.query_row(
                "select exists (select 1 from chat_characters p join card_versions v on v.id = p.version_id
                 where p.chat_id = ?1 and v.card_id = ?2 and p.character = ?3)",
                params![chat_id, card_id, character],
                |r| r.get(0),
            )?;
            if there {
                return Ok(Err(anyhow!(Fail::said(Code::Taken, format!("{name} is in this chat already")).with("what", "chat_character").with("name", name.to_string()))));
            }
            tx.execute(
                "insert into chat_characters (chat_id, position, version_id, character, name)
                 select ?1, coalesce(max(position), -1) + 1, ?2, ?3, ?4 from chat_characters where chat_id = ?1",
                params![chat_id, version_id, character, name],
            )?;
            let id = tx.last_insert_rowid();
            tx.commit()?;
            Ok(Ok(id))
        })?)
    }

    fn participants(&self, user: i64, chat_id: i64) -> anyhow::Result<Vec<Participant>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select p.id, p.position, p.version_id, v.card_id, p.character from chat_characters p
                 join chats c on c.id = p.chat_id join card_versions v on v.id = p.version_id
                 where p.chat_id = ?1 and c.user_id = ?2 order by p.position",
            )?;
            query
                .query_map([chat_id, user], |r| {
                    Ok(Participant {
                        id: r.get(0)?,
                        position: r.get(1)?,
                        version_id: r.get(2)?,
                        card_id: r.get(3)?,
                        character: r.get(4)?,
                    })
                })?
                .collect()
        })?)
    }

    fn speakers(&self, chat_id: i64) -> anyhow::Result<HashSet<i64>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select distinct speaker_id from messages
                 where chat_id = ?1 and speaker_id is not null and deleted_from is null",
            )?;
            query.query_map([chat_id], |r| r.get(0))?.collect()
        })?)
    }

    fn remove_participant(&self, user: i64, participant_id: i64) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(i64, String, bool, i64)> = tx
                .query_row(
                    "select p.chat_id, coalesce(p.name, p.character), c.trashed_at is not null, v.card_id
                     from chat_characters p join chats c on c.id = p.chat_id
                     join card_versions v on v.id = p.version_id
                     where p.id = ?1 and c.user_id = ?2",
                    [participant_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
                )
                .optional()?;
            let Some((chat_id, name, trashed, card_id)) = found else {
                return Ok(Err(NotFound("chat character").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(Fail::said(Code::InTrash, IN_TRASH).with("what", "chat"))));
            }
            // What was deleted goes for good: put back, it would name a character the chat has no more.
            purge(&tx, chat_id)?;
            let (wrote, alone): (bool, bool) = tx.query_row(
                "select exists (select 1 from messages where chat_id = ?1 and speaker_id = ?2),
                        not exists (select 1 from chat_characters where chat_id = ?1 and id <> ?2)",
                [chat_id, participant_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )?;
            if wrote {
                return Ok(Err(anyhow!(Fail::said(Code::NotNow, format!("{name} has written in this chat and stays in it")).with("what", "character_has_written").with("name", name.to_string()))));
            }
            if alone {
                return Ok(Err(anyhow!(Fail::said(Code::Needed, "a chat needs a character").with("what", "chat_character"))));
            }
            tx.execute(
                "delete from chat_characters where id = ?1",
                [participant_id],
            )?;
            tx.execute(
                "delete from chat_lore_off where chat_id = ?1 and card_id = ?2 and not exists
                    (select 1 from chat_characters p join card_versions v on v.id = p.version_id
                     where p.chat_id = ?1 and v.card_id = ?2)",
                [chat_id, card_id],
            )?;
            crate::lorebooks::forget_gone(&tx, chat_id)?;
            tx.commit()?;
            Ok(Ok(chat_id))
        })?
    }
}

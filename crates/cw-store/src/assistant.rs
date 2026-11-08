//! A chat's mode and a character's personality as SQLite keeps them
//! (`assistant::Storage`): `chats.mode` and `auto_mode`, and `personalities`,
//! a row per character of a card that was given one.

use cw_chat::assistant::Storage;
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn set_chat_mode(&self, user: i64, chat_id: i64, mode: Option<&str>) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update chats set mode = ?3 where id = ?1 and user_id = ?2",
                params![chat_id, user, mode],
            )
        })?;
        Ok(())
    }

    fn keep_auto_mode(&self, user: i64, chat_id: i64, mode: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.execute(
                "update chats set auto_mode = ?3 where id = ?1 and user_id = ?2 and auto_mode is not ?3",
                params![chat_id, user, mode],
            )
        })? > 0)
    }

    fn personality(&self, card_id: i64, character: &str) -> anyhow::Result<Option<(String, bool)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select tools_off, memory from personalities where card_id = ?1 and character = ?2",
                params![card_id, character],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn keep_personality(
        &self,
        user: i64,
        card_id: i64,
        character: &str,
        off: &str,
        memory: bool,
    ) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into personalities (card_id, character, tools_off, memory)
                 select id, ?3, ?4, ?5 from cards where id = ?1 and user_id = ?2
                 on conflict (card_id, character) do update set tools_off = ?4, memory = ?5",
                params![card_id, user, character, off, memory],
            )
        })? > 0)
    }
}

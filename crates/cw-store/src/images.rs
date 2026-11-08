//! Pictures as SQLite keeps them (`images::Storage`): the pictures made in
//! chats (`pictures`, a row per message that shows one). The image model is
//! a kind of model (`provider`).

use cw_chat::images::Storage;
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn keep_picture(&self, message_id: i64, data: &[u8], prompt: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert into pictures (message_id, data, prompt) values (?1, ?2, ?3)",
                params![message_id, data, prompt],
            )
        })?;
        Ok(())
    }

    fn picture(&self, user: i64, message_id: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select p.data from pictures p join messages m on m.id = p.message_id
                 join chats c on c.id = m.chat_id where p.message_id = ?1 and c.user_id = ?2",
                [message_id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn picture_chat(
        &self,
        user: i64,
        message_id: i64,
    ) -> anyhow::Result<Option<(i64, Option<i64>)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select m.chat_id, m.speaker_id from pictures p join messages m on m.id = p.message_id
                 join chats c on c.id = m.chat_id where p.message_id = ?1 and c.user_id = ?2",
                [message_id, user],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }
}

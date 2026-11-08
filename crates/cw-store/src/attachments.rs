//! Attachments as SQLite keeps them (`attachments::Storage`): `attachments`, a
//! row per picture (its file in `picture`) or document (`document_id`) of a
//! chat, waiting while it has no message.

use cw_chat::attachments::{Attachment, Storage};
use cw_core::now_ms;
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn keep_attachment(
        &self,
        user: i64,
        chat_id: i64,
        name: &str,
        picture: Option<&[u8]>,
        document_id: Option<i64>,
    ) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            let added = conn.execute(
                "insert into attachments (user_id, chat_id, name, picture, document_id, created_at)
                 select ?1, id, ?3, ?4, ?5, ?6 from chats where id = ?2 and user_id = ?1 and trashed_at is null",
                params![user, chat_id, name, picture, document_id, now_ms()],
            )?;
            Ok((added == 1).then(|| conn.last_insert_rowid()))
        })?)
    }

    fn attachment_picture(&self, user: i64, id: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select picture from attachments where id = ?1 and user_id = ?2 and picture is not null",
                [id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn remove_waiting(&self, user: i64, id: i64) -> anyhow::Result<Option<Option<i64>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "delete from attachments where id = ?1 and user_id = ?2 and message_id is null
                 returning document_id",
                [id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn count_waiting(&self, user: i64, chat_id: i64, ids: &[i64]) -> anyhow::Result<usize> {
        let ids = serde_json::to_string(ids)?;
        let count: i64 = self.with(|conn| {
            conn.query_row(
                "select count(*) from attachments
                 where user_id = ?1 and chat_id = ?2 and message_id is null and id in (select value from json_each(?3))",
                params![user, chat_id, ids],
                |r| r.get(0),
            )
        })?;
        Ok(usize::try_from(count)?)
    }

    fn take_attachments(&self, chat_id: i64, message_id: i64, ids: &[i64]) -> anyhow::Result<()> {
        let ids = serde_json::to_string(ids)?;
        self.with(|conn| {
            conn.execute(
                "update attachments set message_id = ?2
                 where chat_id = ?1 and message_id is null and id in (select value from json_each(?3))",
                params![chat_id, message_id, ids],
            )
        })?;
        Ok(())
    }

    fn message_pictures(&self, ids: &[i64]) -> anyhow::Result<Vec<(i64, Vec<u8>)>> {
        let ids = serde_json::to_string(ids)?;
        Ok(self.with(|conn| {
            conn.prepare(
                "select message_id, picture from attachments
                 where picture is not null and message_id in (select value from json_each(?1)) order by id",
            )?
            .query_map([ids], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect()
        })?)
    }

    fn message_documents(
        &self,
        user: i64,
        message_id: i64,
    ) -> anyhow::Result<Vec<(i64, String, String)>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select d.id, d.name, d.text from attachments a join documents d on d.id = a.document_id
                 where a.message_id = ?1 and a.user_id = ?2 and d.deleted = 0 order by a.id",
            )?
            .query_map(params![message_id, user], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect()
        })?)
    }

    fn waiting(&self, user: i64, chat_id: i64) -> anyhow::Result<Vec<Attachment>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select id, name, picture is not null from attachments
                 where user_id = ?1 and chat_id = ?2 and message_id is null order by id",
            )?
            .query_map([user, chat_id], |r| {
                Ok(Attachment {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    picture: r.get(2)?,
                })
            })?
            .collect()
        })?)
    }
}

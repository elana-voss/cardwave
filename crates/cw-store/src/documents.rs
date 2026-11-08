//! Documents as SQLite keeps them (`documents::Storage`): `documents`, a row
//! per document of a chat or a card with its text; a deleted one is flagged
//! (`deleted`) until it is purged. Its pieces are `search::Index`'s.

use cw_chat::documents::{DocumentView, Storage};
use cw_core::now_ms;
use rusqlite::{OptionalExtension, Row, params};

use crate::Db;
use crate::search::stamp_sql;

/// The user's documents, ?1; read where its search model read it.
fn view() -> String {
    format!("{HEAD}{}{TAIL}", stamp_sql("?1"))
}

const HEAD: &str = "select d.id, d.name, d.words, d.model is not null and d.model = ";

const TAIL: &str = ",
        d.chat_id, d.card_id,
        coalesce(k.title, nullif(c.title, ''),
          (select coalesce(name, character) from chat_characters where chat_id = c.id order by id limit 1), ''),
        d.created_at
     from documents d left join chats c on c.id = d.chat_id left join cards k on k.id = d.card_id
     where d.user_id = ?1 and d.deleted = 0 and c.trashed_at is null and k.trashed_at is null";

fn view_of(row: &Row<'_>) -> rusqlite::Result<DocumentView> {
    Ok(DocumentView {
        id: row.get(0)?,
        name: row.get(1)?,
        words: row.get(2)?,
        read: row.get(3)?,
        chat_id: row.get(4)?,
        card_id: row.get(5)?,
        owner_name: row.get(6)?,
        created_at: row.get(7)?,
    })
}

impl Storage for Db {
    fn document(&self, user: i64, id: i64) -> anyhow::Result<Option<DocumentView>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("{} and d.id = ?2", view()),
                params![user, id],
                view_of,
            )
            .optional()
        })?)
    }

    fn add_document(
        &self,
        user: i64,
        (chat, card): (Option<i64>, Option<i64>),
        name: &str,
        text: &str,
    ) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            let mine: bool = conn.query_row(
                "select exists (select 1 from chats where id = ?1 and user_id = ?3 and trashed_at is null)
                     or exists (select 1 from cards where id = ?2 and user_id = ?3 and trashed_at is null)",
                params![chat, card, user],
                |r| r.get(0),
            )?;
            if !mine {
                return Ok(None);
            }
            conn.execute(
                "insert into documents (user_id, chat_id, card_id, name, text, words, created_at)
                 values (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![
                    user,
                    chat,
                    card,
                    name,
                    text,
                    text.split_whitespace().count() as i64,
                    now_ms()
                ],
            )?;
            Ok(Some(conn.last_insert_rowid()))
        })?)
    }

    fn documents(&self, user: i64) -> anyhow::Result<Vec<DocumentView>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!("{} order by d.id desc", view()))?;
            query.query_map(params![user], view_of)?.collect()
        })?)
    }

    fn delete_document(&self, user: i64, id: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "update documents set deleted = 1 where id = ?1 and user_id = ?2",
                params![id, user],
            )
        })?)
    }

    fn restore_document(&self, user: i64, id: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            conn.execute(
                "update documents set deleted = 0 where id = ?1 and user_id = ?2
                   and not exists (select 1 from chats c where c.id = chat_id and c.trashed_at is not null)
                   and not exists (select 1 from cards k where k.id = card_id and k.trashed_at is not null)",
                params![id, user],
            )
        })?)
    }

    fn purge_deleted_documents(&self) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("delete from documents where deleted = 1", []))?;
        Ok(())
    }
}

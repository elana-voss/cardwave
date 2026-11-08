//! The search's SQL (`search::Index`): the stamp of a user's vectors (`stamp_sql`, `stamp_on`), the cards'
//! vectors read once into memory (`card_vectors`), the texts' and the documents' pieces.

use std::collections::HashMap;
use std::sync::Arc;

use cw_core::now_ms;
use cw_provider::embedder::{self, MODEL};
use cw_search::{CardVectors, Index, Piece, UNUSED, Unread};
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;

/// SQL of the stamp of the account whose ID is `user` (a column or a
/// parameter): its search kind's model, address and entry, as `At::stamp`
/// writes them, else this computer's model.
pub(crate) fn stamp_sql(user: &str) -> String {
    format!(
        "coalesce((select k.model || ' at ' || e.base_url || ' #' || e.id from model_kinds k
            join provider_entries e on e.id = k.entry_id
            where k.user_id = {user} and k.kind = 'search'), '{MODEL}')"
    )
}

/// The stamp of `user`'s vectors, read on `conn`.
pub(crate) fn stamp_on(conn: &Connection, user: i64) -> rusqlite::Result<String> {
    conn.query_row(&format!("select {}", stamp_sql("?1")), [user], |r| r.get(0))
}

/// The cards' vectors, read once into memory beside the connection, until
/// `keep_card_vectors` or a restore changes them: read at each search, they
/// took about 0.3 s for 2,000 cards (12,000 pieces, a release build; the work
/// log, "Search by description"), as SQLCipher decrypts every page they fill.
/// Called with the connection held, which is taken before them, as `keep_card_vectors` takes it.
pub(crate) fn card_vectors(db: &Db, conn: &Connection) -> rusqlite::Result<Arc<CardVectors>> {
    let mut kept = db.card_vectors();
    Ok(match &*kept {
        Some(vectors) => vectors.clone(),
        None => {
            let mut read: CardVectors = HashMap::new();
            let mut rows = conn.prepare(
                "select ch.card_id, s.model, ch.embedding from card_chunks ch
                 join card_search s on s.card_id = ch.card_id",
            )?;
            let mut found = rows.query([])?;
            while let Some(row) = found.next()? {
                let (stamp, pieces) = read.entry(row.get(0)?).or_default();
                *stamp = row.get(1)?;
                pieces.push(row.get(2)?);
            }
            kept.insert(Arc::new(read)).clone()
        }
    })
}

impl Index for Db {
    fn search_stamp(&self, user: i64) -> anyhow::Result<String> {
        Ok(self.with(|conn| stamp_on(conn, user))?)
    }

    fn unread_document(
        &self,
        skip: &[String],
    ) -> anyhow::Result<Option<(i64, i64, String, String)>> {
        let skip = serde_json::to_string(skip)?;
        Ok(self.with(|conn| {
            conn.query_row(
                &format!(
                    "select id, user_id, text, stamp from
                        (select id, user_id, text, model, {} as stamp from documents d where deleted = 0)
                     where (model is null or model <> stamp)
                       and stamp not in (select value from json_each(?1))
                     order by id limit 1",
                    stamp_sql("d.user_id")
                ),
                [skip],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
            )
            .optional()
        })?)
    }

    fn keep_document_pieces(
        &self,
        id: i64,
        stamp: &str,
        pieces: &[(String, Vec<u8>)],
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            // A document deleted for good meanwhile has nothing to keep.
            if tx.execute(
                "update documents set model = ?2 where id = ?1",
                params![id, stamp],
            )? == 1
            {
                tx.execute("delete from document_pieces where document_id = ?1", [id])?;
                let mut insert = tx.prepare(
                    "insert into document_pieces (document_id, text, embedding) values (?1, ?2, ?3)",
                )?;
                for (text, embedding) in pieces {
                    insert.execute(params![id, text, embedding])?;
                }
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn document_pieces(
        &self,
        user: i64,
        chat: Option<(i64, Option<i64>)>,
    ) -> anyhow::Result<Vec<Piece>> {
        let (chat_id, card_id) = chat.map_or((None, None), |(chat, card)| (Some(chat), card));
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select d.id, d.name, p.text, p.embedding from document_pieces p join documents d on d.id = p.document_id
                 where d.user_id = ?1 and d.deleted = 0 and d.model = ?4
                   and (?2 is null or d.chat_id = ?2 or d.card_id = ?3)
                   and not exists (select 1 from cards k where k.id = d.card_id and k.trashed_at is not null)
                   and not exists (select 1 from chats h where h.id = d.chat_id and h.trashed_at is not null)
                 order by p.id",
            )?;
            let stamp = stamp_on(conn, user)?;
            query
                .query_map(params![user, chat_id, card_id, stamp], |r| {
                    Ok(Piece {
                        document: r.get(0)?,
                        name: r.get(1)?,
                        text: r.get(2)?,
                        embedding: r.get(3)?,
                    })
                })?
                .collect()
        })?)
    }

    /// The next card to read, of any user but those whose stamp is in
    /// `skip`: one not in the Trash whose newest version has no vectors of its
    /// user's model.
    fn unread_card(&self, skip: &[String]) -> anyhow::Result<Option<Unread>> {
        let skip = serde_json::to_string(skip)?;
        Ok(self.with(|conn| {
            conn.query_row(
                &format!(
                    "select id, user_id, version_id, title, stamp from
                        (select c.id, c.user_id, i.version_id, c.title, {} as stamp,
                            s.card_id is null or s.version_id <> i.version_id as old, s.model as made_by
                         from cards c join card_index i on i.card_id = c.id
                         left join card_search s on s.card_id = c.id
                         where c.trashed_at is null)
                     where (old or made_by <> stamp) and stamp not in (select value from json_each(?1))
                     order by id limit 1",
                    stamp_sql("c.user_id")
                ),
                [skip],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?)),
            )
            .optional()
        })?)
    }

    /// How many of the user's cards, those in the Trash aside, wait to be read.
    fn cards_unread(&self, user: i64) -> anyhow::Result<usize> {
        let left: i64 = self.with(|conn| {
            conn.query_row(
                "select count(*) from cards c join card_index i on i.card_id = c.id
                 left join card_search s on s.card_id = c.id
                 where c.user_id = ?1 and c.trashed_at is null
                   and (s.card_id is null or s.version_id <> i.version_id or s.model <> ?2)",
                params![user, stamp_on(conn, user)?],
                |r| r.get(0),
            )
        })?;
        Ok(left as usize)
    }

    /// Keeps `vectors`, each with its field, as the card's in place of those it
    /// had, as of its version `version_id`. None where the card cannot be read:
    /// it is not tried again until it has another version.
    fn keep_card_vectors(
        &self,
        card_id: i64,
        version_id: i64,
        stamp: &str,
        vectors: &[(usize, Vec<f32>)],
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute("delete from card_chunks where card_id = ?1", [card_id])?;
            {
                let mut insert = tx.prepare(
                    "insert into card_chunks (card_id, field, embedding) values (?1, ?2, ?3)",
                )?;
                for (field, vector) in vectors {
                    insert.execute(params![card_id, *field as i64, embedder::to_bytes(vector)])?;
                }
            }
            tx.execute(
                "insert into card_search (card_id, version_id, model, read_at) values (?1, ?2, ?3, ?4)
                 on conflict (card_id) do update set version_id = excluded.version_id,
                    model = excluded.model, read_at = excluded.read_at",
                params![card_id, version_id, stamp, now_ms()],
            )?;
            tx.commit()?;
            // Under the connection's lock, so that no search keeps what was there before.
            *self.card_vectors() = None;
            Ok(())
        })?;
        Ok(())
    }

    /// The vectors kept by these hashes (`text_hash`), each where there is one,
    /// which counts as a use of it.
    fn kept_vectors(&self, hashes: &[Vec<u8>]) -> anyhow::Result<Vec<Option<Vec<u8>>>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "update text_vectors set used_at = ?2 where hash = ?1 returning embedding",
            )?;
            let now = now_ms();
            hashes
                .iter()
                .map(|hash| query.query_row(params![hash, now], |r| r.get(0)).optional())
                .collect()
        })?)
    }

    /// Lets go of the texts' vectors that were not used for `UNUSED`: those of
    /// memories and entries deleted or changed since.
    fn forget_unused_vectors(&self) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "delete from text_vectors where used_at < ?1",
                [now_ms() - UNUSED],
            )
        })?;
        Ok(())
    }

    /// Keeps vectors, as `embedder::to_bytes` makes them, by their texts' hashes.
    fn keep_vectors(&self, vectors: &[(Vec<u8>, Vec<u8>)]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.unchecked_transaction()?;
            for (hash, vector) in vectors {
                tx.execute(
                    "insert or replace into text_vectors (hash, embedding, used_at) values (?1, ?2, ?3)",
                    params![hash, vector, now_ms()],
                )?;
            }
            tx.commit()
        })?;
        Ok(())
    }
}

//! Search Cardwave as SQLite keeps it (`cw_search::kept::Storage`): the cards by `card_index`, the documents, and
//! `search_texts`, the rows of lorebooks, their entries, personas and memories (`put_texts_on`, which a card's
//! index writes in its own transaction). Words are matched by `like`, which knows the case of a to z alone, so
//! `find` compares them again. The rows' vectors are kept in memory once a search read them (`Db::text_vectors`),
//! until a row is written; read at each search they cost as the cards' did (`search::card_vectors`).
//! Traps: a row written anew gets a new ID, its vectors carried over where it reads the same; a row the search
//! model could not read has an empty `embedding`, which is never near.

use std::collections::HashMap;
use std::sync::Arc;

use cw_search::kept::{Among, CardRow, DocumentRow, Owner, Storage, Text, TextRow};
use rusqlite::types::Value;
use rusqlite::{Connection, params, params_from_iter};

use crate::cards::escape_like;
use crate::search::{card_vectors, stamp_on, stamp_sql};
use crate::{Db, TextVectors, json};
use cw_search as search;

/// The column of `search_texts` that holds `owner`, and its ID.
fn column(owner: Owner) -> (&'static str, i64) {
    match owner {
        Owner::Lorebook(id) => ("lorebook_id", id),
        Owner::Card(id) => ("card_id", id),
        Owner::Persona(id) => ("persona_id", id),
        Owner::Memory(id) => ("store_id", id),
    }
}

/// `sql` with what `among` asks for appended: every word in `searched`, or the ID `id` among the IDs; with its values after `values`.
fn narrowed(
    mut sql: String,
    values: &mut Vec<Value>,
    among: &Among<'_>,
    searched: &str,
    id: &str,
) -> String {
    match among {
        Among::Words(words) => {
            for word in *words {
                values.push(Value::Text(format!("%{}%", escape_like(word))));
                sql.push_str(&format!(
                    " and ({searched}) like ?{} escape '\\'",
                    values.len()
                ));
            }
        }
        Among::Ids(ids) => {
            values.push(Value::Text(serde_json::json!(ids).to_string()));
            sql.push_str(&format!(
                " and {id} in (select value from json_each(?{}))",
                values.len()
            ));
        }
    }
    sql
}

/// A row's vector, by the stamp of the model that made it.
type Kept = (Option<String>, Option<Vec<u8>>);

/// Writes the rows of `owner` anew, keeping the vectors of those whose words stayed; a part of the caller's transaction.
pub(super) fn put_texts_on(
    conn: &Connection,
    user: i64,
    owner: Owner,
    texts: &[Text],
) -> rusqlite::Result<()> {
    let (column, id) = column(owner);
    let mut kept: HashMap<(String, String, String), Kept> = HashMap::new();
    {
        let mut old = conn.prepare(&format!(
            "select title, keys, text, model, embedding from search_texts where {column} = ?1"
        ))?;
        let mut rows = old.query([id])?;
        while let Some(row) = rows.next()? {
            kept.insert(
                (row.get(0)?, row.get(1)?, row.get(2)?),
                (row.get(3)?, row.get(4)?),
            );
        }
    }
    conn.execute(
        &format!("delete from search_texts where {column} = ?1"),
        [id],
    )?;
    let mut insert = conn.prepare(&format!(
        "insert into search_texts (user_id, {column}, chat_id, book, entry, title, within, keys, text, line, model, embedding)
         values (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)"
    ))?;
    for text in texts {
        let (model, embedding) = kept
            .get(&(text.title.clone(), text.keys.clone(), text.text.clone()))
            .cloned()
            .unwrap_or_default();
        insert.execute(params![
            user,
            id,
            text.chat_id,
            text.book,
            text.entry,
            text.title,
            text.within,
            text.keys,
            text.text,
            text.known
                .as_ref()
                .map(json::to)
                .transpose()?
                .unwrap_or_default(),
            model,
            embedding
        ])?;
    }
    Ok(())
}

impl Db {
    /// The rows' vectors where a search read them, which a write of `search_texts` forgets.
    pub(crate) fn text_vectors(&self) -> std::sync::MutexGuard<'_, Option<Arc<TextVectors>>> {
        cw_core::lock(&self.2)
    }
}

impl cw_find::Storage for Db {}

impl Storage for Db {
    fn find_cards(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<CardRow>> {
        let mut values = vec![Value::Integer(user)];
        let sql = narrowed(
            "select c.id, c.title, i.names, i.tags, i.texts, i.version_id from cards c join card_index i on i.card_id = c.id
             where c.user_id = ?1 and c.trashed_at is null"
                .to_string(),
            &mut values,
            &among,
            "i.search || char(10) || i.texts",
            "c.id",
        );
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&sql)?;
            query
                .query_map(params_from_iter(values), |r| {
                    let list = |at: usize| -> rusqlite::Result<Vec<String>> {
                        Ok(serde_json::from_str(&r.get::<_, String>(at)?).unwrap_or_default())
                    };
                    Ok(CardRow {
                        id: r.get(0)?,
                        title: r.get(1)?,
                        names: list(2)?,
                        tags: list(3)?,
                        texts: r.get(4)?,
                        version_id: r.get(5)?,
                    })
                })?
                .collect()
        })?)
    }

    fn find_texts(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<TextRow>> {
        let mut values = vec![Value::Integer(user)];
        // A library lorebook's name is its row's (a rename writes no rows).
        let sql = narrowed(
            "select s.id, s.lorebook_id, s.card_id, s.persona_id, s.store_id, s.chat_id, s.book, s.entry,
                case when l.id is not null and s.entry = '' then l.name else s.title end,
                case when l.id is not null then l.name else s.within end,
                s.keys, s.text, s.line, coalesce(c.title, ''), coalesce(l.entries, 0)
             from search_texts s
             left join lorebooks l on l.id = s.lorebook_id
             left join cards c on c.id = s.card_id
             left join personas p on p.id = s.persona_id
             left join chats ch on ch.id = s.chat_id
             where s.user_id = ?1
               and (s.lorebook_id is null or l.trashed_at is null)
               and (s.card_id is null or c.trashed_at is null)
               and (s.persona_id is null or p.trashed_at is null)
               and (s.store_id is null or (ch.id is not null and ch.trashed_at is null))"
                .to_string(),
            &mut values,
            &among,
            "coalesce(l.name, '') || char(10) || s.title || char(10) || s.keys || char(10) || s.text",
            "s.id",
        );
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&sql)?;
            query
                .query_map(params_from_iter(values), |r| {
                    let owner = match (
                        r.get::<_, Option<i64>>(1)?,
                        r.get::<_, Option<i64>>(2)?,
                        r.get::<_, Option<i64>>(3)?,
                    ) {
                        (Some(id), _, _) => Owner::Lorebook(id),
                        (_, Some(id), _) => Owner::Card(id),
                        (_, _, Some(id)) => Owner::Persona(id),
                        // The table's check has one owner in every row.
                        _ => Owner::Memory(r.get(4)?),
                    };
                    let text = Text {
                        chat_id: r.get(5)?,
                        book: r.get(6)?,
                        entry: r.get(7)?,
                        title: r.get(8)?,
                        within: r.get(9)?,
                        keys: r.get(10)?,
                        text: r.get(11)?,
                        known: match owner {
                            Owner::Memory(_) => Some(json::of(&r.get::<_, String>(12)?, 12)?),
                            _ => None,
                        },
                    };
                    Ok(TextRow {
                        id: r.get(0)?,
                        owner,
                        text,
                        name: r.get(13)?,
                        entries: r.get(14)?,
                    })
                })?
                .collect()
        })?)
    }

    fn find_documents(&self, user: i64, among: Among<'_>) -> anyhow::Result<Vec<DocumentRow>> {
        let mut values = vec![Value::Integer(user)];
        let sql = narrowed(
            "select d.id, d.name, d.text, d.words from documents d
             where d.user_id = ?1 and d.deleted = 0
               and not exists (select 1 from cards k where k.id = d.card_id and k.trashed_at is not null)
               and not exists (select 1 from chats h where h.id = d.chat_id and h.trashed_at is not null)"
                .to_string(),
            &mut values,
            &among,
            "d.name || char(10) || d.text",
            "d.id",
        );
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&sql)?;
            query
                .query_map(params_from_iter(values), |r| {
                    Ok(DocumentRow {
                        id: r.get(0)?,
                        name: r.get(1)?,
                        text: r.get(2)?,
                        words: r.get(3)?,
                    })
                })?
                .collect()
        })?)
    }

    fn near_cards(&self, user: i64, query: &[f32]) -> anyhow::Result<Vec<(i64, f32)>> {
        Ok(self.with(|conn| {
            let mut ids = conn
                .prepare_cached("select id from cards where user_id = ?1 and trashed_at is null")?;
            let ids: Vec<i64> = ids
                .query_map([user], |r| r.get(0))?
                .collect::<rusqlite::Result<_>>()?;
            let stamp = stamp_on(conn, user)?;
            let vectors = card_vectors(self, conn)?;
            Ok(search::rank(&vectors, &ids, &stamp, query)
                .into_iter()
                .collect())
        })?)
    }

    fn near_texts(&self, user: i64, query: &[f32]) -> anyhow::Result<Vec<(i64, f32)>> {
        Ok(self.with(|conn| {
            let stamp = stamp_on(conn, user)?;
            let mut kept = self.text_vectors();
            let vectors = match &*kept {
                Some(vectors) => vectors.clone(),
                None => {
                    let mut read: TextVectors = HashMap::new();
                    let mut rows = conn.prepare(
                        "select id, user_id, model, embedding from search_texts where model is not null and length(embedding) > 0",
                    )?;
                    let mut found = rows.query([])?;
                    while let Some(row) = found.next()? {
                        read.insert(row.get(0)?, (row.get(1)?, row.get(2)?, row.get(3)?));
                    }
                    kept.insert(Arc::new(read)).clone()
                }
            };
            Ok(vectors
                .iter()
                .filter(|(_, (of, model, _))| *of == user && *model == stamp)
                .map(|(id, (_, _, embedding))| (*id, search::nearest(query, embedding)))
                .collect())
        })?)
    }

    fn unindexed(&self) -> anyhow::Result<Vec<(i64, Owner)>> {
        Ok(self.with(|conn| {
            let mut out = Vec::new();
            for (table, column, owner) in [
                ("lorebooks", "lorebook_id", Owner::Lorebook as fn(i64) -> Owner),
                ("personas", "persona_id", Owner::Persona),
                ("memory_stores", "store_id", Owner::Memory),
            ] {
                // A memory without a block read has nothing to search, and would be asked again at every start.
                let read = match table {
                    "memory_stores" => " and exists (select 1 from memory_blocks b where b.store_id = o.id)",
                    _ => "",
                };
                let mut query = conn.prepare(&format!(
                    "select user_id, id from {table} o where not exists (select 1 from search_texts s where s.{column} = o.id){read}"
                ))?;
                let found = query.query_map([], |r| Ok((r.get(0)?, owner(r.get(1)?))))?;
                out.extend(found.collect::<rusqlite::Result<Vec<_>>>()?);
            }
            Ok(out)
        })?)
    }

    fn put_texts(&self, user: i64, owner: Owner, texts: &[Text]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            put_texts_on(&tx, user, owner, texts)?;
            tx.commit()
        })?;
        *self.text_vectors() = None;
        Ok(())
    }

    /// The next rows of `search_texts` to read, up to `count`, all of one user and stamp, but those whose stamp is
    /// in `skip`: with what the model reads of each.
    fn unread_texts(
        &self,
        skip: &[String],
        count: usize,
    ) -> anyhow::Result<Vec<(i64, i64, String, String)>> {
        let skip = serde_json::to_string(skip)?;
        let rows: Vec<(i64, i64, Text, String)> = self.with(|conn| {
            // Each user's stamp once, not each row's: the rows read are many and stay.
            let users: Vec<(i64, String)> = conn
                .prepare(&format!(
                    "select id, stamp from (select id, {} as stamp from users u
                       where exists (select 1 from search_texts s where s.user_id = u.id))
                     where stamp not in (select value from json_each(?1))",
                    stamp_sql("u.id")
                ))?
                .query_map([&skip], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect::<rusqlite::Result<_>>()?;
            let mut query = conn.prepare(
                "select id, title, keys, text from search_texts where user_id = ?1 and (model is null or model <> ?2)
                 order by id limit ?3",
            )?;
            for (user, stamp) in users {
                let rows: Vec<_> = query
                    .query_map(params![user, stamp, count as i64], |r| {
                        let text = Text { title: r.get(1)?, keys: r.get(2)?, text: r.get(3)?, ..Default::default() };
                        Ok((r.get(0)?, user, text, stamp.clone()))
                    })?
                    .collect::<rusqlite::Result<_>>()?;
                if !rows.is_empty() {
                    return Ok(rows);
                }
            }
            Ok(Vec::new())
        })?;
        Ok(rows
            .into_iter()
            .map(|(id, user, text, stamp)| (id, user, text.read(), stamp))
            .collect())
    }

    /// Keeps the vectors of the rows `read` by the model of `stamp` (empty where it could not read one).
    fn keep_text_vectors(&self, stamp: &str, read: &[(i64, Vec<u8>)]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            for (id, embedding) in read {
                tx.execute(
                    "update search_texts set model = ?2, embedding = ?3 where id = ?1",
                    params![id, stamp, embedding],
                )?;
            }
            tx.commit()
        })?;
        *self.text_vectors() = None;
        Ok(())
    }
}

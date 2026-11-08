//! The memories as SQLite keeps them (`memory::Storage`): a memory
//! (`memory_stores`) is a chat's or a card's character's, with its day 1; its
//! state after each block read (`memory_blocks`, in the order read, the
//! `autoincrement` ID never reused), told by its chat, number and chain, with
//! the texts it saved and the message whose end had it read; and the vectors
//! of its texts by `search::text_hash` (`memory_vectors`), which a pass makes.
//! A block keeps its row when its chat is deleted, its `chat_id` gone, so the
//! memory lets it go and reads the blocks after it again.

use std::collections::HashMap;

use cw_chat::memory::{Kept, NewBlock, Owner, Storage};
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn memory_store(
        &self,
        owner: &Owner,
        make: bool,
    ) -> anyhow::Result<Option<(i64, Option<i64>)>> {
        Ok(self.with(|conn| {
            let pair = |r: &rusqlite::Row<'_>| Ok((r.get(0)?, r.get(1)?));
            let found = match owner {
                Owner::Chat(chat) => conn
                    .query_row("select id, day_one from memory_stores where chat_id = ?1", [chat], pair)
                    .optional()?,
                Owner::Character((card, character)) => conn
                    .query_row(
                        "select id, day_one from memory_stores where card_id = ?1 and character = ?2",
                        params![card, character],
                        pair,
                    )
                    .optional()?,
            };
            if found.is_some() || !make {
                return Ok(found);
            }
            let made = match owner {
                Owner::Chat(chat) => conn.execute(
                    "insert into memory_stores (user_id, chat_id) select user_id, id from chats where id = ?1",
                    [chat],
                )?,
                Owner::Character((card, character)) => conn.execute(
                    "insert into memory_stores (user_id, card_id, character)
                     select user_id, id, ?2 from cards where id = ?1",
                    params![card, character],
                )?,
            };
            Ok((made == 1).then(|| (conn.last_insert_rowid(), None)))
        })?)
    }

    fn memory_blocks(&self, store: i64) -> anyhow::Result<Vec<Kept>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select id, chat_id, block, chain from memory_blocks where store_id = ?1 order by id",
            )?;
            query
                .query_map([store], |r| {
                    Ok(Kept {
                        id: r.get(0)?,
                        chat_id: r.get(1)?,
                        block: r.get(2)?,
                        chain: r.get(3)?,
                    })
                })?
                .collect()
        })?)
    }

    fn memory_state(&self, block: i64) -> anyhow::Result<String> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select state from memory_blocks where id = ?1",
                [block],
                |r| r.get(0),
            )
        })?)
    }

    fn forget_memory_blocks(&self, store: i64, from: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "delete from memory_blocks where store_id = ?1 and id >= ?2",
                [store, from],
            )
        })?;
        Ok(())
    }

    fn keep_memory_block(
        &self,
        store: i64,
        after: Option<i64>,
        kept: &NewBlock,
    ) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.unchecked_transaction()?;
            let last: Option<i64> = tx.query_row(
                "select max(id) from memory_blocks where store_id = ?1",
                [store],
                |r| r.get(0),
            )?;
            if last != after {
                return Ok(false);
            }
            tx.execute(
                "insert into memory_blocks (store_id, chat_id, block, chain, state, saved, message_id)
                 values (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![
                    store,
                    kept.chat_id,
                    kept.block,
                    kept.chain,
                    kept.state,
                    // A list of strings always writes as JSON.
                    serde_json::to_string(&kept.saved).unwrap_or_else(|_| "[]".into()),
                    kept.message_id
                ],
            )?;
            tx.execute(
                "update memory_stores set day_one = coalesce(day_one, ?2) where id = ?1",
                params![store, kept.day_one],
            )?;
            tx.commit()?;
            Ok(true)
        })?)
    }

    fn memory_states(&self, store: i64) -> anyhow::Result<Vec<(i64, String)>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select id, state from memory_blocks where store_id = ?1 order by id",
            )?;
            query
                .query_map([store], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect()
        })?)
    }

    fn set_memory_state(&self, block: i64, state: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update memory_blocks set state = ?2 where id = ?1",
                params![block, state],
            )
        })?;
        Ok(())
    }

    fn memory_changes(&self, store: i64) -> anyhow::Result<String> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select changes from memory_stores where id = ?1",
                [store],
                |r| r.get(0),
            )
        })?)
    }

    fn set_memory_changes(&self, store: i64, changes: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update memory_stores set changes = ?2 where id = ?1",
                params![store, changes],
            )
        })?;
        Ok(())
    }

    fn memory_stores(&self, user: i64) -> anyhow::Result<Vec<(i64, Owner)>> {
        let rows: Vec<(i64, Option<Owner>)> = self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select id, chat_id, card_id, character from memory_stores where user_id = ?1 order by id",
            )?;
            query
                .query_map([user], |r| Ok((r.get(0)?, owner(r.get(1)?, r.get(2)?, r.get(3)?))))?
                .collect::<rusqlite::Result<_>>()
        })?;
        Ok(rows
            .into_iter()
            .filter_map(|(id, owner)| Some((id, owner?)))
            .collect())
    }

    fn memory_owner(&self, user: i64, store: i64) -> anyhow::Result<Option<Owner>> {
        let found = self.with(|conn| {
            conn.query_row(
                "select chat_id, card_id, character from memory_stores where id = ?1 and user_id = ?2",
                [store, user],
                |r| Ok(owner(r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()
        })?;
        Ok(found.flatten())
    }

    fn memory_trashed_chats(&self, store: i64) -> anyhow::Result<Vec<i64>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select distinct c.id from memory_blocks b join chats c on c.id = b.chat_id
                 where b.store_id = ?1 and c.trashed_at is not null",
            )?;
            query.query_map([store], |r| r.get(0))?.collect()
        })?)
    }

    fn card_chats(&self, user: i64, card: i64) -> anyhow::Result<Vec<i64>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare_cached(
                "select distinct c.id from chats c join chat_characters p on p.chat_id = c.id
                 join card_versions v on v.id = p.version_id where c.user_id = ?1 and v.card_id = ?2",
            )?;
            query.query_map([user, card], |r| r.get(0))?.collect()
        })?)
    }

    fn chat_cast(&self, chat_id: i64) -> anyhow::Result<Vec<(i64, String)>> {
        Ok(self.with(|conn| crate::chat_characters::cast_of(conn, chat_id))?)
    }

    fn memory_vectors(&self, store: i64) -> anyhow::Result<HashMap<Vec<u8>, Vec<u8>>> {
        Ok(self.with(|conn| {
            let mut query = conn
                .prepare_cached("select hash, embedding from memory_vectors where store_id = ?1")?;
            query
                .query_map([store], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect()
        })?)
    }

    fn keep_memory_vectors(
        &self,
        store: i64,
        new: &[(Vec<u8>, Vec<u8>)],
        keep: &[Vec<u8>],
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.unchecked_transaction()?;
            for (hash, embedding) in new {
                tx.execute(
                    "insert or replace into memory_vectors (store_id, hash, embedding) values (?1, ?2, ?3)",
                    params![store, hash, embedding],
                )?;
            }
            let have: Vec<Vec<u8>> = {
                let mut query = tx.prepare("select hash from memory_vectors where store_id = ?1")?;
                query.query_map([store], |r| r.get(0))?.collect::<rusqlite::Result<_>>()?
            };
            for hash in have {
                if keep.contains(&hash) || new.iter().any(|(h, _)| *h == hash) {
                    continue;
                }
                tx.execute(
                    "delete from memory_vectors where store_id = ?1 and hash = ?2",
                    params![store, hash],
                )?;
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn purge_deleted_memories(&self) -> anyhow::Result<()> {
        let states: Vec<(i64, String)> = self.with(|conn| {
            let mut query = conn.prepare(
                r#"select id, state from memory_blocks where state like '%"deleted":true%'"#,
            )?;
            query
                .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect::<rusqlite::Result<_>>()
        })?;
        for (block, state) in states {
            let mut value: serde_json::Value = serde_json::from_str(&state)?;
            for list in ["facts", "events"] {
                if let Some(entries) = value.get_mut(list).and_then(|l| l.as_array_mut()) {
                    entries.retain(|e| e.get("deleted") != Some(&serde_json::Value::Bool(true)));
                }
            }
            self.set_memory_state(block, &serde_json::to_string(&value)?)?;
        }
        Ok(())
    }
}

/// A memory's owner by its columns.
fn owner(chat: Option<i64>, card: Option<i64>, character: Option<String>) -> Option<Owner> {
    match (chat, card, character) {
        (Some(chat), _, _) => Some(Owner::Chat(chat)),
        (None, Some(card), Some(character)) => Some(Owner::Character((card, character))),
        _ => None,
    }
}

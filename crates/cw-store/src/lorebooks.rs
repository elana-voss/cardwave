//! Lorebooks as SQLite keeps them (`lorebooks::Storage`): a row per lorebook
//! with its document and what the library lists of it, the lorebooks attached
//! to cards (`card_lorebooks`), given to personas (`persona_lorebooks`, written
//! by `personas`), for every chat (`everywhere_at`) and taken along by
//! chats (`chat_lorebooks`), and
//! what chats left out of them (`chat_lorebook_off`). `HAD` is the one piece
//! of SQL that says which chats have which lorebook.

use std::collections::HashSet;

use cw_core::{NotFound, now_ms};
use cw_library::cards::Show;
use cw_library::lorebooks::{
    CardLoreSource, CardLorebook, ChatLorebookRow, KeptLorebook, Listed, Lorebook, Storage,
};
use cw_search::kept::Owner;
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::{Db, shown};

const SELECT: &str =
    "select l.id, l.name, l.description, l.entries, l.entry_names, l.favorite, l.archived,
        l.trashed_at is not null, l.everywhere_at is not null,
        (select json_group_array(name) from (
            select 0 as persona, a.added_at as at, c.title as name
              from card_lorebooks a join cards c on c.id = a.card_id
             where a.lorebook_id = l.id and c.trashed_at is null
            union all
            select 1, g.added_at, p.name from persona_lorebooks g join personas p on p.id = g.persona_id
             where g.lorebook_id = l.id and p.trashed_at is null
            order by persona, at)),
        (select count(*) from chat_lorebooks t join chats c on c.id = t.chat_id
          where t.lorebook_id = l.id and c.trashed_at is null)
     from lorebooks l";

fn lorebook(row: &Row<'_>) -> rusqlite::Result<Lorebook> {
    let names: String = row.get(4)?;
    Ok(Lorebook {
        id: row.get(0)?,
        name: row.get(1)?,
        description: row.get(2)?,
        entries: row.get(3)?,
        entry_names: serde_json::from_str(&names).unwrap_or_default(),
        favorite: row.get(5)?,
        archived: row.get(6)?,
        trashed: row.get(7)?,
        everywhere: row.get(8)?,
        used_by: serde_json::from_str(&row.get::<_, String>(9)?).unwrap_or_default(),
        chats: row.get(10)?,
        card: None,
    })
}

/// The lorebooks of the library that chats have, to select from as a table
/// `(chat_id, lorebook_id, attached_at, taken_at)`: a row for each card of a
/// chat's characters that the lorebook is attached to, with when it was, and
/// one where the chat took it along itself, with when it did. Both halves give
/// columns of the same kind, the empty ones too: only then does SQLite search
/// each half by its index for the chat or the lorebook asked for.
///
/// A lorebook for every chat counts as attached, from when it was made one, to
/// each chat with a character (a chat without one has no lore); one of a
/// persona to each chat the user is that persona in, from when it was given.
/// `through` says which half a row is of: 0 a card's, 1 the chat's own, 2 for
/// every chat, 3 the persona's.
pub(super) const HAD: &str =
    "(select p.chat_id, a.lorebook_id, a.added_at as attached_at, cast(null as integer) as taken_at, 0 as through
        from card_lorebooks a join card_versions v on v.card_id = a.card_id
        join chat_characters p on p.version_id = v.id
      union all
      select chat_id, lorebook_id, cast(null as integer), added_at, 1 from chat_lorebooks
      union all
      select c.id, l.id, l.everywhere_at, cast(null as integer), 2
        from lorebooks l join chats c on c.user_id = l.user_id
        where l.everywhere_at is not null
          and exists (select 1 from chat_characters p where p.chat_id = c.id)
      union all
      select c.id, g.lorebook_id, g.added_at, cast(null as integer), 3
        from persona_lorebooks g join chats c on c.persona_id = g.persona_id)";

/// Forgets what was left out of a lorebook by a chat that no longer has it,
/// among the rows whose `column` (the chat's or the lorebook's) is `id`.
fn forget(conn: &Connection, column: &str, id: i64) -> rusqlite::Result<()> {
    conn.execute(
        &format!(
            "delete from chat_lorebook_off as o where o.{column} = ?1 and not exists
               (select 1 from {HAD} h where h.chat_id = o.chat_id and h.lorebook_id = o.lorebook_id)"
        ),
        [id],
    )?;
    Ok(())
}

/// Forgets what chats had left out of the lorebook `lorebook_id` where they no
/// longer have it, as it is no longer for every chat or a persona's.
pub(super) fn forget_lorebook(conn: &Connection, lorebook_id: i64) -> rusqlite::Result<()> {
    forget(conn, "lorebook_id", lorebook_id)
}

/// Forgets what a chat had left out of the lorebooks it no longer has, as a
/// character through whose card it had them, or its persona, has left it.
pub(super) fn forget_gone(conn: &Connection, chat_id: i64) -> rusqlite::Result<()> {
    forget(conn, "chat_id", chat_id)
}

impl Db {
    /// Takes a lorebook from the card or the chat that has it, with `delete`,
    /// which is given that `owner` and the lorebook, and forgets what chats
    /// had left out of it where they no longer have it. Answers how many rows went.
    fn let_go(&self, delete: &str, owner: i64, lorebook_id: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let gone = tx.execute(delete, [owner, lorebook_id])?;
            forget(&tx, "lorebook_id", lorebook_id)?;
            tx.commit()?;
            Ok(gone)
        })?)
    }
}

impl Storage for Db {
    fn add_lorebook(
        &self,
        user: i64,
        name: &str,
        toml: &str,
        listed: &Listed,
    ) -> anyhow::Result<i64> {
        let id = self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "insert into lorebooks (user_id, name, description, toml, entries, entry_names, created_at)
                 values (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![user, name, listed.about, toml, listed.entries, listed.entry_names, now_ms()],
            )?;
            let id = tx.last_insert_rowid();
            crate::find::put_texts_on(&tx, user, Owner::Lorebook(id), &listed.texts)?;
            tx.commit()?;
            Ok(id)
        })?;
        *self.text_vectors() = None;
        Ok(id)
    }

    fn lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<Option<Lorebook>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("{SELECT} where l.id = ?1 and l.user_id = ?2"),
                [lorebook_id, user],
                lorebook,
            )
            .optional()
        })?)
    }

    fn lorebooks(&self, user: i64, show: Show, searching: bool) -> anyhow::Result<Vec<Lorebook>> {
        Ok(self.with(|conn| {
            let shown = shown(show, "l", searching);
            let mut query = conn.prepare(&format!(
                "{SELECT} where l.user_id = ?1 and l.trashed_at is null{shown}"
            ))?;
            query.query_map([user], lorebook)?.collect()
        })?)
    }

    fn kept_lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<Option<KeptLorebook>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select name, toml, trashed_at is not null, created_at from lorebooks where id = ?1 and user_id = ?2",
                [lorebook_id, user],
                |r| {
                    Ok(KeptLorebook {
                        name: r.get(0)?,
                        toml: r.get(1)?,
                        trashed: r.get(2)?,
                        created_at: r.get(3)?,
                    })
                },
            )
            .optional()
        })?)
    }

    fn left_out_entries(&self, lorebook_id: i64) -> anyhow::Result<HashSet<String>> {
        Ok(self.with(|conn| {
            let mut left_out = conn.prepare(
                "select distinct reference from chat_lorebook_off where lorebook_id = ?1",
            )?;
            left_out.query_map([lorebook_id], |r| r.get(0))?.collect()
        })?)
    }

    fn write_lorebook(
        &self,
        lorebook_id: i64,
        was: &str,
        toml: &str,
        listed: &Listed,
        name: Option<&str>,
    ) -> anyhow::Result<bool> {
        let written = self.with(|conn| {
            let tx = conn.transaction()?;
            let written = tx.execute(
                "update lorebooks set toml = ?3, entries = ?4, entry_names = ?5, description = ?6,
                    name = coalesce(?7, name)
                 where id = ?1 and toml = ?2",
                params![
                    lorebook_id,
                    was,
                    toml,
                    listed.entries,
                    listed.entry_names,
                    listed.about,
                    name
                ],
            )?;
            if written == 1 {
                let user: i64 = tx.query_row(
                    "select user_id from lorebooks where id = ?1",
                    [lorebook_id],
                    |r| r.get(0),
                )?;
                crate::find::put_texts_on(&tx, user, Owner::Lorebook(lorebook_id), &listed.texts)?;
            }
            tx.commit()?;
            Ok(written)
        })?;
        *self.text_vectors() = None;
        Ok(written == 1)
    }

    fn rename_lorebook(&self, lorebook_id: i64, name: Option<&str>) -> anyhow::Result<bool> {
        let written = self.with(|conn| {
            conn.execute(
                "update lorebooks set name = coalesce(?2, name) where id = ?1",
                params![lorebook_id, name],
            )
        })?;
        Ok(written == 1)
    }

    fn set_lorebook_favorite(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(
            ("lorebooks", "lorebook"),
            user,
            lorebook_id,
            "favorite",
            &on,
        )
    }

    fn set_lorebook_archived(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(
            ("lorebooks", "lorebook"),
            user,
            lorebook_id,
            "archived",
            &on,
        )
    }

    fn attached_lorebooks(&self, card_id: i64) -> anyhow::Result<Vec<CardLorebook>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select l.id, l.name, l.entries, l.trashed_at is not null
                 from card_lorebooks a join lorebooks l on l.id = a.lorebook_id
                 where a.card_id = ?1 order by a.added_at, l.id",
            )?;
            let lorebook = |r: &Row<'_>| {
                Ok(CardLorebook {
                    source: CardLoreSource::LorebookId(r.get(0)?),
                    name: r.get(1)?,
                    entries: r.get(2)?,
                    trashed: r.get(3)?,
                })
            };
            query.query_map([card_id], lorebook)?.collect()
        })?)
    }

    fn attach_lorebook(&self, card_id: i64, lorebook_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert or ignore into card_lorebooks (card_id, lorebook_id, added_at) values (?1, ?2, ?3)",
                params![card_id, lorebook_id, now_ms()],
            )
        })?;
        Ok(())
    }

    fn lorebook_uses(&self, lorebook_id: i64) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select (select count(*) from card_lorebooks where lorebook_id = ?1)
                      + (select count(*) from chat_lorebooks where lorebook_id = ?1)
                      + (select count(*) from persona_lorebooks where lorebook_id = ?1)
                      + (select count(*) from lorebooks where id = ?1 and everywhere_at is not null)",
                [lorebook_id],
                |row| row.get(0),
            )
        })?)
    }

    fn set_lorebook_everywhere(&self, user: i64, lorebook_id: i64, on: bool) -> anyhow::Result<()> {
        let found = self.with(|conn| {
            let tx = conn.transaction()?;
            let found = tx.execute(
                "update lorebooks set everywhere_at = case when ?3 then coalesce(everywhere_at, ?4) end
                 where id = ?1 and user_id = ?2",
                params![lorebook_id, user, on, now_ms()],
            )?;
            forget(&tx, "lorebook_id", lorebook_id)?;
            tx.commit()?;
            Ok(found)
        })?;
        anyhow::ensure!(found == 1, NotFound("lorebook"));
        Ok(())
    }

    fn detach_lorebook(&self, card_id: i64, lorebook_id: i64) -> anyhow::Result<bool> {
        let gone = self.let_go(
            "delete from card_lorebooks where card_id = ?1 and lorebook_id = ?2",
            card_id,
            lorebook_id,
        )?;
        Ok(gone == 1)
    }

    fn drop_chat_lorebook(&self, chat_id: i64, lorebook_id: i64) -> anyhow::Result<bool> {
        let gone = self.let_go(
            "delete from chat_lorebooks where chat_id = ?1 and lorebook_id = ?2",
            chat_id,
            lorebook_id,
        )?;
        Ok(gone == 1)
    }

    fn chat_lorebooks(&self, chat_id: i64) -> anyhow::Result<Vec<ChatLorebookRow>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "select l.id, l.name, l.trashed_at is not null, l.toml, max(h.taken_at) is not null,
                        max(h.through = 2), max(h.through = 3)
                 from {HAD} h join lorebooks l on l.id = h.lorebook_id
                 where h.chat_id = ?1
                 group by l.id
                 order by min(h.attached_at) is null, coalesce(min(h.attached_at), max(h.taken_at)), l.id"
            ))?;
            query
                .query_map([chat_id], |r| {
                    Ok(ChatLorebookRow {
                        id: r.get(0)?,
                        name: r.get(1)?,
                        trashed: r.get(2)?,
                        toml: r.get(3)?,
                        by_chat: r.get(4)?,
                        everywhere: r.get(5)?,
                        persona: r.get(6)?,
                    })
                })?
                .collect()
        })?)
    }
}

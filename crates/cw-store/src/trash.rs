//! The Trash as SQLite keeps it (`trash::Storage`): `trashed_at` on an item's
//! row, and `trashed_with` on a chat that went with its card.

use cw_chat::chats::BUSY;
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};
use cw_library::trash::{EXPRESSIONS, FIGURES, LOREBOOKS, PERSONAS, Storage, TrashItem};
use rusqlite::{Connection, OptionalExtension, params};

use crate::Db;
use crate::lorebooks::HAD;

/// Whether an item of `user` is in the Trash; `None` when there is no such item.
fn trashed(conn: &Connection, table: &str, user: i64, id: i64) -> rusqlite::Result<Option<bool>> {
    conn.query_row(
        &format!("select trashed_at is not null from {table} where id = ?1 and user_id = ?2"),
        [id, user],
        |r| r.get(0),
    )
    .optional()
}

/// Deletes one item of `user` for good with `remove`. It has to be in the
/// Trash, and no reply may be being written in what goes.
fn delete(
    db: &Db,
    user: i64,
    (table, what): (&str, &'static str),
    id: i64,
    remove: fn(&Connection, i64) -> rusqlite::Result<bool>,
) -> anyhow::Result<()> {
    db.with(|conn| {
        let tx = conn.transaction()?;
        match trashed(&tx, table, user, id)? {
            None => return Ok(Err(NotFound(what).into())),
            Some(false) => {
                let refusal = format!(
                    "only a {what} in the Trash can be deleted for good; move it there first"
                );
                return Ok(Err(anyhow::Error::new(
                    Fail::said(Code::NotPossible, refusal).with("what", "delete_not_in_trash"),
                )));
            }
            Some(true) => {}
        }
        if !remove(&tx, id)? {
            return Ok(Err(BUSY.into()));
        }
        tx.commit()?;
        Ok(Ok(()))
    })?
}

/// Deletes an item that went to the Trash alone. Nothing stands in its way,
/// so it always tells that it did.
fn remove_alone(conn: &Connection, table: &str, id: i64) -> rusqlite::Result<bool> {
    conn.execute(&format!("delete from {table} where id = ?1"), [id])?;
    Ok(true)
}

/// Deletes a persona; its chats go on without one, and forget what they left
/// out of the lorebooks they had through it. Always does.
fn remove_persona(conn: &Connection, persona_id: i64) -> rusqlite::Result<bool> {
    let chats: Vec<i64> = conn
        .prepare("select id from chats where persona_id = ?1")?
        .query_map([persona_id], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    remove_alone(conn, PERSONAS.0, persona_id)?;
    for chat_id in chats {
        crate::lorebooks::forget_gone(conn, chat_id)?;
    }
    Ok(true)
}

/// Deletes a chat unless a reply is being written in it; tells whether it did.
fn remove_chat(conn: &Connection, chat_id: i64) -> rusqlite::Result<bool> {
    let deleted = conn.execute(
        "delete from chats where id = ?1
           and not exists (select 1 from messages where chat_id = ?1 and complete = 0)",
        [chat_id],
    )?;
    Ok(deleted == 1)
}

/// Deletes a card and the chats its characters are in, unless a reply is
/// being written in one of them; tells whether it did. The pictures and files
/// it leaves unused are for [`cards::remove_unused_blobs`]; its expression pack
/// and figures go to the Trash where no other card has them.
fn remove_card(conn: &Connection, card_id: i64) -> rusqlite::Result<bool> {
    if card_writing(conn, card_id)? {
        return Ok(false);
    }
    conn.execute(
        &format!("delete from chats where id in ({CHATS_OF_CARD})"),
        [card_id],
    )?;
    let pack: Option<i64> = conn.query_row(
        "select expression_pack_id from cards where id = ?1",
        [card_id],
        |r| r.get(0),
    )?;
    let figures = crate::figures::figures_of_card(conn, card_id)?;
    conn.execute("delete from cards where id = ?1", [card_id])?;
    crate::expressions::HELD.trash_if_unused(conn, pack)?;
    for figure in figures {
        crate::figures::HELD.trash_if_unused(conn, Some(figure))?;
    }
    Ok(true)
}

/// The chats the characters of the card `?1` are in.
/// Whether a reply is being written in one of the card's chats.
fn card_writing(conn: &Connection, card_id: i64) -> rusqlite::Result<bool> {
    conn.query_row(
        &format!("select exists (select 1 from messages where complete = 0 and chat_id in ({CHATS_OF_CARD}))"),
        [card_id],
        |r| r.get(0),
    )
}

const CHATS_OF_CARD: &str = "select p.chat_id from chat_characters p
     join card_versions v on v.id = p.version_id where v.card_id = ?1";

/// A card of the chat `chats.id` that is in the Trash, if any.
const TRASHED_CARD_OF_CHAT: &str = "select c.id from chat_characters p
     join card_versions v on v.id = p.version_id join cards c on c.id = v.card_id
     where p.chat_id = chats.id and c.trashed_at is not null order by c.id limit 1";

impl Storage for Db {
    fn trash_items(&self, user: i64) -> anyhow::Result<Vec<TrashItem>> {
        let items: Vec<TrashItem> = self.with(|conn| {
            let mut cards = conn.prepare(
                "select c.id, c.title, c.trashed_at, v.id, (select count(*) from chats where trashed_with = c.id)
                 from cards c join card_versions v on v.card_id = c.id
                 where c.user_id = ?1 and c.trashed_at is not null
                   and v.number = (select max(number) from card_versions where card_id = c.id)
                 order by c.id desc",
            )?;
            let mut chats = conn.prepare(
                "select t.id, t.title, t.trashed_at,
                    (select json_group_array(title) from
                        (select distinct c.title from chat_characters p
                         join card_versions v on v.id = p.version_id join cards c on c.id = v.card_id
                         where p.chat_id = t.id order by p.id))
                 from chats t where t.user_id = ?1 and t.trashed_at is not null and t.trashed_with is null
                 order by t.id desc",
            )?;
            let cards = cards.query_map([user], |r| {
                Ok(TrashItem::Card {
                    id: r.get(0)?,
                    title: r.get(1)?,
                    trashed_at: r.get(2)?,
                    version_id: r.get(3)?,
                    chats: r.get(4)?,
                })
            })?;
            let chats = chats.query_map([user], |r| {
                let cards: String = r.get(3)?;
                Ok(TrashItem::Chat {
                    id: r.get(0)?,
                    title: r.get(1)?,
                    trashed_at: r.get(2)?,
                    cards: serde_json::from_str(&cards).unwrap_or_default(),
                })
            })?;
            let mut personas = conn.prepare(
                "select p.id, p.name, p.trashed_at,
                    (select count(*) from chats where persona_id = p.id and trashed_at is null)
                 from personas p where p.user_id = ?1 and p.trashed_at is not null order by p.id desc",
            )?;
            let personas = personas.query_map([user], |r| {
                Ok(TrashItem::Persona { id: r.get(0)?, title: r.get(1)?, trashed_at: r.get(2)?, chats: r.get(3)? })
            })?;
            let mut lorebooks = conn.prepare(&format!(
                "select l.id, l.name, l.trashed_at,
                    (select count(*) from chats c where c.trashed_at is null
                        and exists (select 1 from {HAD} h where h.chat_id = c.id and h.lorebook_id = l.id))
                 from lorebooks l where l.user_id = ?1 and l.trashed_at is not null order by l.id desc"
            ))?;
            let lorebooks = lorebooks.query_map([user], |r| {
                Ok(TrashItem::Lorebook { id: r.get(0)?, title: r.get(1)?, trashed_at: r.get(2)?, chats: r.get(3)? })
            })?;
            let mut packs = conn.prepare(
                "select id, name, trashed_at from expression_packs
                 where user_id = ?1 and trashed_at is not null order by id desc",
            )?;
            let packs = packs.query_map([user], |r| {
                Ok(TrashItem::ExpressionPack { id: r.get(0)?, title: r.get(1)?, trashed_at: r.get(2)? })
            })?;
            let mut figures = conn.prepare(
                "select id, name, trashed_at from figures
                 where user_id = ?1 and trashed_at is not null order by id desc",
            )?;
            let figures = figures.query_map([user], |r| {
                Ok(TrashItem::Figure { id: r.get(0)?, title: r.get(1)?, trashed_at: r.get(2)? })
            })?;
            cards.chain(chats).chain(personas).chain(lorebooks).chain(packs).chain(figures).collect()
        })?;
        Ok(items)
    }

    fn trash_card(&self, user: i64, card_id: i64) -> anyhow::Result<()> {
        let now = now_ms();
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found = tx.execute(
                "update cards set trashed_at = coalesce(trashed_at, ?3) where id = ?1 and user_id = ?2",
                params![card_id, user, now],
            )?;
            if found == 0 {
                return Ok(Err(NotFound("card").into()));
            }
            // Not while a reply is written in one of its chats: it would go on into the Trash.
            if card_writing(&tx, card_id)? {
                return Ok(Err(BUSY.into()));
            }
            tx.execute(
                &format!(
                    "update chats set trashed_at = ?2, trashed_with = ?1
                     where trashed_at is null and id in ({CHATS_OF_CARD})"
                ),
                params![card_id, now],
            )?;
            tx.commit()?;
            Ok(Ok(()))
        })?
    }

    fn restore_trashed_card(&self, user: i64, card_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found =
                tx.execute("update cards set trashed_at = null where id = ?1 and user_id = ?2", [card_id, user])?;
            if found == 0 {
                return Ok(Err(NotFound("card").into()));
            }
            tx.execute(
                &format!(
                    "update chats set trashed_with = ({TRASHED_CARD_OF_CHAT}),
                        trashed_at = case when ({TRASHED_CARD_OF_CHAT}) is null then null else trashed_at end
                     where trashed_with = ?1"
                ),
                [card_id],
            )?;
            tx.commit()?;
            Ok(Ok(()))
        })?
    }

    /// Not while a reply is written in the chat: it would go on into the Trash.
    fn trash_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            if crate::chats::writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            let found = tx.execute(
                "update chats set trashed_at = coalesce(trashed_at, ?3), trashed_with = null
                 where id = ?1 and user_id = ?2",
                params![chat_id, user, now_ms()],
            )?;
            if found != 1 {
                return Ok(Err(NotFound("chat").into()));
            }
            tx.commit()?;
            Ok(Ok(()))
        })?
    }

    fn restore_trashed_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let card: Option<Option<String>> = tx
                .query_row(
                    &format!(
                        "select (select title from cards where id = ({TRASHED_CARD_OF_CHAT}))
                         from chats where id = ?1 and user_id = ?2"
                    ),
                    [chat_id, user],
                    |r| r.get(0),
                )
                .optional()?;
            match card {
                None => return Ok(Err(NotFound("chat").into())),
                Some(Some(title)) => {
                    return Ok(Err(anyhow::anyhow!(
                        Fail::said(
                            Code::InTrash,
                            format!("its card “{title}” is in the Trash; restore the card first")
                        )
                        .with("what", "chat_card")
                        .with("title", title.to_string())
                    )));
                }
                Some(None) => {}
            }
            tx.execute(
                "update chats set trashed_at = null, trashed_with = null where id = ?1",
                [chat_id],
            )?;
            tx.commit()?;
            Ok(Ok(()))
        })?
    }

    fn trash_item(
        &self,
        user: i64,
        (table, what): (&str, &'static str),
        id: i64,
    ) -> anyhow::Result<()> {
        let found = self.with(|conn| {
            conn.execute(
                &format!("update {table} set trashed_at = coalesce(trashed_at, ?3) where id = ?1 and user_id = ?2"),
                params![id, user, now_ms()],
            )
        })?;
        anyhow::ensure!(found == 1, NotFound(what));
        Ok(())
    }

    fn restore_trashed_item(
        &self,
        user: i64,
        (table, what): (&str, &'static str),
        id: i64,
    ) -> anyhow::Result<()> {
        let found = self.with(|conn| {
            conn.execute(
                &format!("update {table} set trashed_at = null where id = ?1 and user_id = ?2"),
                [id, user],
            )
        })?;
        anyhow::ensure!(found == 1, NotFound(what));
        Ok(())
    }

    fn delete_card(&self, user: i64, card_id: i64) -> anyhow::Result<()> {
        delete(self, user, ("cards", "card"), card_id, |conn, card_id| {
            let gone = remove_card(conn, card_id)?;
            crate::cards::remove_unused_blobs(conn)?;
            Ok(gone)
        })
    }

    fn delete_chat(&self, user: i64, chat_id: i64) -> anyhow::Result<()> {
        delete(self, user, ("chats", "chat"), chat_id, remove_chat)
    }

    fn delete_persona(&self, user: i64, persona_id: i64) -> anyhow::Result<()> {
        delete(self, user, PERSONAS, persona_id, remove_persona)
    }

    fn delete_lorebook(&self, user: i64, lorebook_id: i64) -> anyhow::Result<()> {
        delete(self, user, LOREBOOKS, lorebook_id, |conn, id| {
            remove_alone(conn, LOREBOOKS.0, id)
        })
    }

    fn delete_expression_pack(&self, user: i64, pack_id: i64) -> anyhow::Result<()> {
        delete(self, user, EXPRESSIONS, pack_id, |conn, id| {
            remove_alone(conn, EXPRESSIONS.0, id)?;
            crate::cards::remove_unused_blobs(conn)?;
            Ok(true)
        })
    }

    fn delete_figure(&self, user: i64, figure_id: i64) -> anyhow::Result<()> {
        delete(self, user, FIGURES, figure_id, |conn, id| {
            remove_alone(conn, FIGURES.0, id)?;
            crate::cards::remove_unused_blobs(conn)?;
            Ok(true)
        })
    }

    fn remove_trashed_before(&self, user: Option<i64>, before: i64) -> anyhow::Result<usize> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let due = |table: &str, more: &str| -> rusqlite::Result<Vec<i64>> {
                let mut query = tx.prepare(&format!(
                    "select id from {table} where trashed_at < ?1 and (?2 is null or user_id = ?2) {more} order by id"
                ))?;
                query.query_map(params![before, user], |r| r.get(0))?.collect()
            };
            let mut gone = 0;
            // A card takes its chats along; the chats left are those deleted by themselves.
            for card in due("cards", "")? {
                gone += usize::from(remove_card(&tx, card)?);
            }
            crate::cards::remove_unused_blobs(&tx)?;
            for chat in due("chats", "and trashed_with is null")? {
                gone += usize::from(remove_chat(&tx, chat)?);
            }
            for persona in due(PERSONAS.0, "")? {
                gone += usize::from(remove_persona(&tx, persona)?);
            }
            for (table, _) in [LOREBOOKS, EXPRESSIONS, FIGURES] {
                for id in due(table, "")? {
                    gone += usize::from(remove_alone(&tx, table, id)?);
                }
            }
            crate::cards::remove_unused_blobs(&tx)?;
            tx.commit()?;
            Ok(gone)
        })?)
    }
}

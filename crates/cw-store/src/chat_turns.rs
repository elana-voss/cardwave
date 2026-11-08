//! Who replies next in a chat as SQLite keeps it (`chats::turn::Storage`): the
//! chat's `turn_order` by its name (`TurnOrder::name`) or its `replier_id`, and
//! the characters' places in speaking order (`chat_characters.position`).

use anyhow::anyhow;
use cw_chat::chats::IN_TRASH;
use cw_chat::chats::turn::{Storage, TurnOrder};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use rusqlite::types::{FromSqlError, FromSqlResult, ValueRef};
use rusqlite::{OptionalExtension, params};

use crate::Db;

/// The order a `turn_order` column holds, by its name (the order lives in
/// cw-chat, so rusqlite's `FromSql` cannot be implemented for it here).
pub(super) fn turn_order(value: ValueRef<'_>) -> FromSqlResult<TurnOrder> {
    let name = value.as_str()?;
    [TurnOrder::Natural, TurnOrder::List, TurnOrder::Random]
        .into_iter()
        .find(|order| order.name() == name)
        .ok_or_else(|| FromSqlError::Other(format!("no turn order is called {name:?}").into()))
}

impl Storage for Db {
    fn set_turn_order(&self, chat_id: i64, order: TurnOrder) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update chats set turn_order = ?2, replier_id = null where id = ?1",
                params![chat_id, order.name()],
            )
        })?;
        Ok(())
    }

    fn set_replier(&self, chat_id: i64, replier: i64) -> anyhow::Result<bool> {
        let set = self.with(|conn| {
            conn.execute(
                "update chats set replier_id = ?2 where id = ?1 and exists
                    (select 1 from chat_characters where id = ?2 and chat_id = ?1)",
                [chat_id, replier],
            )
        })?;
        Ok(set == 1)
    }

    fn reorder_participant(
        &self,
        user: i64,
        participant_id: i64,
        place: usize,
    ) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(i64, bool)> = tx
                .query_row(
                    "select p.chat_id, c.trashed_at is not null from chat_characters p
                     join chats c on c.id = p.chat_id where p.id = ?1 and c.user_id = ?2",
                    [participant_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .optional()?;
            let Some((chat_id, trashed)) = found else {
                return Ok(Err(NotFound("chat character").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(
                    Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
                )));
            }
            let mut order: Vec<i64> = tx
                .prepare("select id from chat_characters where chat_id = ?1 order by position")?
                .query_map([chat_id], |r| r.get(0))?
                .collect::<rusqlite::Result<_>>()?;
            order.retain(|one| *one != participant_id);
            order.insert(place.min(order.len()), participant_id);
            // A chat's places are each one character's: they go below 0 first, where none stands, so that no two meet.
            tx.execute(
                "update chat_characters set position = -1 - position where chat_id = ?1",
                [chat_id],
            )?;
            for (at, one) in order.iter().enumerate() {
                tx.execute(
                    "update chat_characters set position = ?2 where id = ?1",
                    params![one, at as i64],
                )?;
            }
            tx.commit()?;
            Ok(Ok(chat_id))
        })?
    }
}

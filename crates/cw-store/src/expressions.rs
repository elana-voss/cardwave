//! Expression packs as SQLite keeps them (`expressions::Storage`): `expression_packs`, a picture per mood in
//! `expression_pictures` (its bytes in `blobs`, once per content), and a card's pack in `cards.expression_pack_id`.
//! What it shares with figures (kept once, to the Trash alone) is `HELD`'s.

use cw_core::{NotFound, now_ms};
use cw_library::expressions::{ExpressionPack, MOODS, PackMoods, Picture, Storage};
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::Db;
use crate::cards::put_blob;
use crate::held::Held;

/// A pack's columns: its id, name, moods (as JSON) and the cards outside the Trash that have it.
const PACK: &str = "select e.id, e.name,
        (select json_group_array(mood) from expression_pictures where pack_id = e.id),
        (select count(*) from cards c where c.expression_pack_id = e.id and c.trashed_at is null)
     from expression_packs e";

fn pack(row: &Row<'_>) -> rusqlite::Result<ExpressionPack> {
    let moods: String = row.get(2)?;
    // `json_group_array` writes valid JSON of strings: the default is never taken.
    let mut moods: Vec<String> = serde_json::from_str(&moods).unwrap_or_default();
    // In `MOODS`' order, neutral last.
    moods.sort_by_key(|mood| {
        MOODS
            .iter()
            .position(|(one, _)| one == mood)
            .unwrap_or(MOODS.len())
    });
    Ok(ExpressionPack {
        id: row.get(0)?,
        name: row.get(1)?,
        moods,
        cards: row.get(3)?,
    })
}

/// Packs as held items: one is used where a card has it.
pub(super) const HELD: Held = Held {
    table: "expression_packs",
    used: "exists (select 1 from cards where expression_pack_id = ?1)",
    noun: "expression pack",
};

/// The pack a card has, if any; `None` where there is no such card of `user`.
fn pack_of_card(
    conn: &Connection,
    user: i64,
    card_id: i64,
) -> rusqlite::Result<Option<Option<i64>>> {
    conn.query_row(
        "select expression_pack_id from cards where id = ?1 and user_id = ?2",
        [card_id, user],
        |r| r.get(0),
    )
    .optional()
}

impl Storage for Db {
    fn store_pack(
        &self,
        user: i64,
        name: &str,
        hash: &[u8],
        pictures: &[Picture],
    ) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            if let Some(id) = HELD.kept(&tx, user, hash)? {
                return Ok(id);
            }
            tx.execute(
                "insert into expression_packs (user_id, name, hash, created_at) values (?1, ?2, ?3, ?4)",
                params![user, name, hash, now_ms()],
            )?;
            let id = tx.last_insert_rowid();
            for picture in pictures {
                let image = put_blob(&tx, &picture.hash, &picture.data)?;
                tx.execute(
                    "insert into expression_pictures (pack_id, mood, image_id) values (?1, ?2, ?3)",
                    params![id, picture.mood, image],
                )?;
            }
            tx.commit()?;
            Ok(id)
        })?)
    }

    fn packs(&self, user: i64) -> anyhow::Result<Vec<ExpressionPack>> {
        Ok(self.with(|conn| {
            conn.prepare(&format!(
                "{PACK} where e.user_id = ?1 and e.trashed_at is null order by e.name collate nocase, e.id"
            ))?
            .query_map([user], pack)?
            .collect()
        })?)
    }

    fn card_pack(&self, user: i64, card_id: i64) -> anyhow::Result<Option<ExpressionPack>> {
        let found = self.with(|conn| {
            let Some(pack_id) = pack_of_card(conn, user, card_id)? else {
                return Ok(None);
            };
            let found = match pack_id {
                Some(id) => conn
                    .query_row(&format!("{PACK} where e.id = ?1"), [id], pack)
                    .optional()?,
                None => None,
            };
            Ok(Some(found))
        })?;
        Ok(found.ok_or(NotFound("card"))?)
    }

    fn set_card_pack(
        &self,
        user: i64,
        card_id: i64,
        pack: Option<i64>,
    ) -> anyhow::Result<Option<i64>> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let Some(before) = pack_of_card(&tx, user, card_id)? else {
                return Ok(Err(NotFound("card").into()));
            };
            if let Some(pack) = pack
                && let Err(e) = HELD.untrash(&tx, user, pack)?
            {
                return Ok(Err(e));
            }
            tx.execute(
                "update cards set expression_pack_id = ?2 where id = ?1",
                params![card_id, pack],
            )?;
            if before != pack {
                HELD.trash_if_unused(&tx, before)?;
            }
            tx.commit()?;
            Ok(Ok(before))
        })?
    }

    fn pack_picture(&self, user: i64, pack: i64, mood: &str) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select b.data from expression_pictures p join expression_packs e on e.id = p.pack_id
                 join blobs b on b.id = p.image_id where p.pack_id = ?1 and e.user_id = ?2 and p.mood = ?3",
                params![pack, user, mood],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn message_pack(
        &self,
        user: i64,
        message_id: i64,
    ) -> anyhow::Result<(String, Option<PackMoods>)> {
        let found = self.with(|conn| {
            let Some((content, pack)) = conn
                .query_row(
                    "select m.content, k.expression_pack_id from messages m join chats c on c.id = m.chat_id
                     left join chat_characters p on p.id = m.speaker_id
                     left join card_versions v on v.id = p.version_id left join cards k on k.id = v.card_id
                     where m.id = ?1 and c.user_id = ?2 and m.deleted_from is null",
                    [message_id, user],
                    |r| Ok((r.get::<_, String>(0)?, r.get::<_, Option<i64>>(1)?)),
                )
                .optional()?
            else {
                return Ok(None);
            };
            let pack = match pack {
                Some(id) => {
                    let moods = conn
                        .prepare("select mood from expression_pictures where pack_id = ?1")?
                        .query_map([id], |r| r.get(0))?
                        .collect::<rusqlite::Result<Vec<String>>>()?;
                    Some((id, moods))
                }
                None => None,
            };
            Ok(Some((content, pack)))
        })?;
        Ok(found.ok_or(NotFound("message"))?)
    }

    fn set_pack_trashed(&self, user: i64, pack: i64, trashed: bool) -> anyhow::Result<()> {
        self.with(|conn| HELD.set_trashed(conn, user, pack, trashed))?
    }
}

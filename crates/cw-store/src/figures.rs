//! 3D figures as SQLite keeps them (`figures::Storage`): `figures`, the file and still of each in `blobs` (once per
//! content), a card's figure in `cards.figure_id` and its modes' in `card_mode_figures`. What it shares with
//! expression packs (kept once, to the Trash alone) is `HELD`'s.

use cw_chat::figures::{CardFigures, Figure, FigureFile, ModeFigure, Storage};
use cw_core::{NotFound, now_ms};
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::Db;
use crate::cards::put_blob;
use crate::held::Held;

/// A figure's columns: its id, name, kind and the cards outside the Trash that have it, as theirs or a mode's.
const FIGURE: &str = "select f.id, f.name, f.kind,
        (select count(*) from cards c where c.trashed_at is null and (c.figure_id = f.id
           or exists (select 1 from card_mode_figures m where m.card_id = c.id and m.figure_id = f.id)))
     from figures f";

fn figure(row: &Row<'_>) -> rusqlite::Result<Figure> {
    Ok(Figure {
        id: row.get(0)?,
        name: row.get(1)?,
        kind: row.get(2)?,
        cards: row.get(3)?,
    })
}

/// Figures as held items: one is used where a card has it, as its own or a mode's.
pub(super) const HELD: Held = Held {
    table: "figures",
    used: "(exists (select 1 from cards where figure_id = ?1)
            or exists (select 1 from card_mode_figures where figure_id = ?1))",
    noun: "figure",
};

/// The figures a card has, as its own and its modes'.
pub(super) fn figures_of_card(conn: &Connection, card_id: i64) -> rusqlite::Result<Vec<i64>> {
    conn.prepare(
        "select figure_id from cards where id = ?1 and figure_id is not null
         union select figure_id from card_mode_figures where card_id = ?1",
    )?
    .query_map([card_id], |r| r.get(0))?
    .collect()
}

/// The figure a card, or its mode, has; `None` where there is no such card of `user`.
fn figure_of(
    conn: &Connection,
    user: i64,
    card_id: i64,
    mode: Option<&str>,
) -> rusqlite::Result<Option<Option<i64>>> {
    let Some(own) = conn
        .query_row(
            "select figure_id from cards where id = ?1 and user_id = ?2",
            [card_id, user],
            |r| r.get::<_, Option<i64>>(0),
        )
        .optional()?
    else {
        return Ok(None);
    };
    let Some(mode) = mode else {
        return Ok(Some(own));
    };
    conn.query_row(
        "select figure_id from card_mode_figures where card_id = ?1 and mode = ?2",
        params![card_id, mode],
        |r| r.get(0),
    )
    .optional()
    .map(Some)
}

impl Storage for Db {
    fn store_figure(&self, user: i64, file: &FigureFile<'_>) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            if let Some(id) = HELD.kept(&tx, user, file.hash)? {
                return Ok(id);
            }
            let data = put_blob(&tx, file.hash, file.data)?;
            let still = put_blob(&tx, file.still_hash, file.still)?;
            tx.execute(
                "insert into figures (user_id, name, kind, hash, file_id, still_id, created_at)
                 values (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![user, file.name, file.kind, file.hash, data, still, now_ms()],
            )?;
            let id = tx.last_insert_rowid();
            tx.commit()?;
            Ok(id)
        })?)
    }

    fn figures(&self, user: i64) -> anyhow::Result<Vec<Figure>> {
        Ok(self.with(|conn| {
            conn.prepare(&format!(
                "{FIGURE} where f.user_id = ?1 and f.trashed_at is null order by f.name collate nocase, f.id"
            ))?
            .query_map([user], figure)?
            .collect()
        })?)
    }

    fn card_figures(&self, user: i64, card_id: i64) -> anyhow::Result<CardFigures> {
        let found = self.with(|conn| {
            let Some(own) = figure_of(conn, user, card_id, None)? else {
                return Ok(None);
            };
            let one = |id: i64| conn.query_row(&format!("{FIGURE} where f.id = ?1"), [id], figure);
            let figure = own.map(one).transpose()?;
            let modes = conn
                .prepare(
                    "select mode, figure_id from card_mode_figures where card_id = ?1 order by mode collate nocase",
                )?
                .query_map([card_id], |r| Ok((r.get::<_, String>(0)?, r.get::<_, i64>(1)?)))?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            let modes = modes
                .into_iter()
                .map(|(mode, id)| Ok(ModeFigure { mode, figure: one(id)? }))
                .collect::<rusqlite::Result<Vec<_>>>()?;
            Ok(Some(CardFigures { figure, modes }))
        })?;
        Ok(found.ok_or(NotFound("card"))?)
    }

    fn set_card_figure(
        &self,
        user: i64,
        card_id: i64,
        mode: Option<&str>,
        figure: Option<i64>,
    ) -> anyhow::Result<Option<i64>> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let Some(before) = figure_of(&tx, user, card_id, mode)? else {
                return Ok(Err(NotFound("card").into()));
            };
            if let Some(figure) = figure
                && let Err(e) = HELD.untrash(&tx, user, figure)?
            {
                return Ok(Err(e));
            }
            match (mode, figure) {
                (None, _) => {
                    tx.execute(
                        "update cards set figure_id = ?2 where id = ?1",
                        params![card_id, figure],
                    )?;
                }
                (Some(mode), Some(figure)) => {
                    tx.execute(
                        "insert into card_mode_figures (card_id, mode, figure_id) values (?1, ?2, ?3)
                         on conflict (card_id, mode) do update set figure_id = excluded.figure_id",
                        params![card_id, mode, figure],
                    )?;
                }
                (Some(mode), None) => {
                    tx.execute(
                        "delete from card_mode_figures where card_id = ?1 and mode = ?2",
                        params![card_id, mode],
                    )?;
                }
            }
            if before != figure {
                HELD.trash_if_unused(&tx, before)?;
            }
            tx.commit()?;
            Ok(Ok(before))
        })?
    }

    fn figure_bytes(
        &self,
        user: i64,
        figure: i64,
        still: bool,
    ) -> anyhow::Result<Option<(String, Vec<u8>)>> {
        let blob = if still { "still_id" } else { "file_id" };
        Ok(self.with(|conn| {
            conn.query_row(
                &format!(
                    "select f.kind, b.data from figures f join blobs b on b.id = f.{blob}
                     where f.id = ?1 and f.user_id = ?2"
                ),
                [figure, user],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn set_figure_trashed(&self, user: i64, figure: i64, trashed: bool) -> anyhow::Result<()> {
        self.with(|conn| HELD.set_trashed(conn, user, figure, trashed))?
    }
}

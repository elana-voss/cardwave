//! Personas as SQLite keeps them (`personas::Storage`), with the lorebooks of
//! the library given to each (`persona_lorebooks`), read with it as JSON, and
//! each as Search Cardwave keeps it (`put_texts`).

use cw_core::now_ms;
use cw_library::personas::{Persona, Storage, picture_address};
use cw_search::kept::{Owner, Text};
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::Db;

/// A persona in plain view: not in the Trash.
const IN_VIEW: &str = "p.trashed_at is null";

fn select() -> String {
    format!(
        "select p.id, p.name, p.description, p.trashed_at is not null,
            {IN_VIEW} and exists (select 1 from users u where u.id = p.user_id and u.default_persona_id = p.id),
            p.picture_at,
            (select json_group_array(json_object('id', id, 'name', name, 'trashed', json(trashed)))
               from (select l.id, l.name, iif(l.trashed_at is null, 'false', 'true') as trashed
                     from persona_lorebooks a join lorebooks l on l.id = a.lorebook_id
                     where a.persona_id = p.id order by a.added_at, l.id))
         from personas p"
    )
}

fn persona(row: &Row<'_>) -> rusqlite::Result<Persona> {
    Ok(Persona {
        id: row.get(0)?,
        name: row.get(1)?,
        description: row.get(2)?,
        trashed: row.get(3)?,
        is_default: row.get(4)?,
        picture: picture_address(row.get(0)?, row.get(5)?),
        lorebooks: serde_json::from_str(&row.get::<_, String>(6)?).map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(6, rusqlite::types::Type::Text, error.into())
        })?,
    })
}

/// Writes the persona `id` anew as Search Cardwave keeps it (`find`).
fn put_texts(conn: &Connection, user: i64, id: i64) -> rusqlite::Result<()> {
    let (title, text) = conn.query_row(
        "select name, description from personas where id = ?1",
        [id],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    crate::find::put_texts_on(
        conn,
        user,
        Owner::Persona(id),
        &[Text::persona(title, text)],
    )
}

impl Storage for Db {
    fn add_persona(&self, user: i64, name: &str, description: &str) -> anyhow::Result<i64> {
        let id = self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "insert into personas (user_id, name, description, created_at) values (?1, ?2, ?3, ?4)",
                params![user, name, description, now_ms()],
            )?;
            let id = tx.last_insert_rowid();
            put_texts(&tx, user, id)?;
            tx.commit()?;
            Ok(id)
        })?;
        *self.text_vectors() = None;
        Ok(id)
    }

    fn persona(&self, user: i64, persona_id: i64) -> anyhow::Result<Option<Persona>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("{} where p.id = ?1 and p.user_id = ?2", select()),
                [persona_id, user],
                persona,
            )
            .optional()
        })?)
    }

    fn personas(&self, user: i64) -> anyhow::Result<Vec<Persona>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "{} where p.user_id = ?1 and p.trashed_at is null",
                select()
            ))?;
            query.query_map([user], persona)?.collect()
        })?)
    }

    fn change_persona(
        &self,
        user: i64,
        persona_id: i64,
        name: Option<&str>,
        description: Option<&str>,
    ) -> anyhow::Result<bool> {
        let changed = self.with(|conn| {
            let tx = conn.transaction()?;
            let changed = tx.execute(
                "update personas set name = coalesce(?3, name), description = coalesce(?4, description)
                 where id = ?1 and user_id = ?2",
                params![persona_id, user, name, description],
            )?;
            if changed == 1 {
                put_texts(&tx, user, persona_id)?;
            }
            tx.commit()?;
            Ok(changed)
        })?;
        *self.text_vectors() = None;
        Ok(changed == 1)
    }

    fn set_persona_picture(
        &self,
        user: i64,
        persona_id: i64,
        picture: Option<&[u8]>,
        at: Option<i64>,
    ) -> anyhow::Result<bool> {
        let changed = self.with(|conn| {
            conn.execute(
                "update personas set picture = ?1, picture_at = ?2 where id = ?3 and user_id = ?4",
                params![picture, at, persona_id, user],
            )
        })?;
        Ok(changed == 1)
    }

    fn persona_picture(&self, user: i64, persona_id: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self
            .with(|conn| {
                conn.query_row(
                    "select picture from personas where id = ?1 and user_id = ?2",
                    [persona_id, user],
                    |r| r.get(0),
                )
                .optional()
            })?
            .flatten())
    }

    fn set_default_persona(&self, user: i64, persona_id: i64, default: bool) -> anyhow::Result<()> {
        let sql = if default {
            "update users set default_persona_id = ?2 where id = ?1"
        } else {
            "update users set default_persona_id = null where id = ?1 and default_persona_id = ?2"
        };
        self.with(|conn| conn.execute(sql, [user, persona_id]))?;
        Ok(())
    }

    fn set_persona_lorebooks(&self, persona_id: i64, lorebooks: &[i64]) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let had: Vec<i64> = tx
                .prepare("select lorebook_id from persona_lorebooks where persona_id = ?1")?
                .query_map([persona_id], |r| r.get(0))?
                .collect::<rusqlite::Result<_>>()?;
            for gone in had.iter().filter(|id| !lorebooks.contains(id)) {
                tx.execute(
                    "delete from persona_lorebooks where persona_id = ?1 and lorebook_id = ?2",
                    [persona_id, *gone],
                )?;
                crate::lorebooks::forget_lorebook(&tx, *gone)?;
            }
            for (at, id) in lorebooks.iter().enumerate() {
                // In the order given, after those it had.
                tx.execute(
                    "insert or ignore into persona_lorebooks (persona_id, lorebook_id, added_at) values (?1, ?2, ?3)",
                    params![persona_id, id, now_ms() + at as i64],
                )?;
            }
            tx.commit()
        })?;
        Ok(())
    }

    fn default_persona(&self, user: i64) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("select p.id from users u join personas p on p.id = u.default_persona_id where u.id = ?1 and {IN_VIEW}"),
                [user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }
}

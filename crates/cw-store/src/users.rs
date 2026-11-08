//! Accounts as SQLite keeps them (`users::Storage`).

use cw_accounts::users::{Called, Listed, Storage};
use cw_core::{NotFound, now_ms};
use rusqlite::{Connection, OptionalExtension, params};

use anyhow::ensure;

use crate::Db;

/// Whether no account but `except` is called `name`, upper and lower case
/// aside: the database knows them from a to z only.
fn free(conn: &Connection, name: &str, except: Option<i64>) -> rusqlite::Result<bool> {
    let wanted = name.to_lowercase();
    let mut names = conn.prepare("select id, name from users")?;
    let mut rows = names.query([])?;
    while let Some(row) = rows.next()? {
        let (id, had): (i64, String) = (row.get(0)?, row.get(1)?);
        if Some(id) != except && had.to_lowercase() == wanted {
            return Ok(false);
        }
    }
    Ok(true)
}

impl Storage for Db {
    fn reached(&self) -> anyhow::Result<bool> {
        Ok(self.meta("network")?.as_deref() == Some("on"))
    }

    fn set_reached(&self, on: bool) -> anyhow::Result<()> {
        self.set_meta("network", if on { "on" } else { "off" })
    }

    fn add_user(&self, name: &str) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into users (name, created_at) values (?1, ?2)",
                params![name, now_ms()],
            )?;
            Ok(conn.last_insert_rowid())
        })?)
    }

    fn account(&self, user: i64) -> anyhow::Result<Called> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select name, local, picture_at from users where id = ?1",
                [user],
                |r| {
                    Ok(Called {
                        name: r.get(0)?,
                        local: r.get(1)?,
                        picture_at: r.get(2)?,
                    })
                },
            )
        })?)
    }

    fn accounts(&self) -> anyhow::Result<Vec<Listed>> {
        Ok(self.with(|conn| {
            let mut all = conn.prepare(
                "select id, name, local, password is not null from users
                 order by local desc, name collate nocase, id",
            )?;
            all.query_map([], |r| {
                Ok(Listed {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    local: r.get(2)?,
                    password: r.get(3)?,
                })
            })?
            .collect()
        })?)
    }

    fn password_of(&self, user: i64) -> anyhow::Result<Option<String>> {
        Ok(self
            .with(|conn| {
                conn.query_row("select password from users where id = ?1", [user], |r| {
                    r.get(0)
                })
                .optional()
            })?
            .flatten())
    }

    fn delete_account(&self, user: i64) -> anyhow::Result<()> {
        let deleted = self.with(|conn| {
            let tx = conn.transaction()?;
            let gone = tx.execute("delete from users where id = ?1 and local = 0", [user])?;
            crate::cards::remove_unused_blobs(&tx)?;
            tx.commit()?;
            Ok(gone)
        })?;
        ensure!(deleted == 1, NotFound("account"));
        Ok(())
    }

    fn user_picture(&self, user: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self
            .with(|conn| {
                conn.query_row("select picture from users where id = ?1", [user], |r| {
                    r.get(0)
                })
                .optional()
            })?
            .flatten())
    }

    fn local_user(&self, name: &str) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<i64> = tx
                .query_row("select id from users where local = 1", [], |r| r.get(0))
                .optional()?;
            let user = match found {
                Some(user) => user,
                None => tx.query_row(
                    "insert into users (name, created_at, local) values (?1, ?2, 1)
                     on conflict (name) do update set local = 1
                     returning id",
                    params![name, now_ms()],
                    |r| r.get(0),
                )?,
            };
            tx.commit()?;
            Ok(user)
        })?)
    }

    fn add_account(&self, name: &str, hash: &str) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            if !free(&tx, name, None)? {
                return Ok(None);
            }
            tx.execute(
                "insert into users (name, created_at, password) values (?1, ?2, ?3)",
                params![name, now_ms(), hash],
            )?;
            let id = tx.last_insert_rowid();
            tx.commit()?;
            Ok(Some(id))
        })?)
    }

    fn rename_account(&self, user: i64, name: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            if !free(&tx, name, Some(user))? {
                return Ok(false);
            }
            tx.execute(
                "update users set name = ?1 where id = ?2",
                params![name, user],
            )?;
            tx.commit()?;
            Ok(true)
        })?)
    }

    fn set_password(&self, user: i64, hash: &str) -> anyhow::Result<bool> {
        let set = self.with(|conn| {
            conn.execute(
                "update users set password = ?1 where id = ?2 and local = 0",
                params![hash, user],
            )
        })?;
        Ok(set == 1)
    }

    fn set_user_picture(
        &self,
        user: i64,
        picture: Option<&[u8]>,
        at: Option<i64>,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update users set picture = ?1, picture_at = ?2 where id = ?3",
                params![picture, at, user],
            )
        })?;
        Ok(())
    }
}

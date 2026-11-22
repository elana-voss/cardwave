//! The names a chat's names tool used (`tools::names::Storage`):
//! `chat_used_names`, a row per name, which goes with its chat.

use cw_coding::tools::names::Storage;
use rusqlite::params;

use crate::Db;

impl Storage for Db {
    fn used_names(&self, chat_id: i64) -> anyhow::Result<(Vec<String>, Vec<String>)> {
        let rows: Vec<(bool, String)> = self.with(|conn| {
            let mut query =
                conn.prepare("select last, name from chat_used_names where chat_id = ?1")?;
            query
                .query_map([chat_id], |row| Ok((row.get(0)?, row.get(1)?)))?
                .collect()
        })?;
        let (last, first): (Vec<_>, Vec<_>) = rows.into_iter().partition(|(last, _)| *last);
        let names = |rows: Vec<(bool, String)>| rows.into_iter().map(|(_, name)| name).collect();
        Ok((names(first), names(last)))
    }

    fn keep_used_names(
        &self,
        chat_id: i64,
        first: &[String],
        last: &[String],
    ) -> anyhow::Result<()> {
        Ok(self.with(|conn| {
            let done = conn.transaction()?;
            done.execute("delete from chat_used_names where chat_id = ?1", [chat_id])?;
            {
                let mut add = done.prepare(
                    "insert or ignore into chat_used_names (chat_id, last, name) values (?1, ?2, ?3)",
                )?;
                for (names, is_last) in [(first, false), (last, true)] {
                    for name in names {
                        add.execute(params![chat_id, is_last, name])?;
                    }
                }
            }
            done.commit()
        })?)
    }
}

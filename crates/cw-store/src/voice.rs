//! The account's voices as SQLite keeps them (`voice::own::Storage`): `own_voices`, each with its recording,
//! and `card_voices`, a card's voice by the card. A card's character is named by its card's newest version
//! as the library's index keeps it (`card_index.names`, the first).

use cw_core::now_ms;
use cw_voice::own::{CharacterVoice, OwnVoice, Storage};
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn own_voices(&self, user: i64) -> anyhow::Result<Vec<OwnVoice>> {
        Ok(self.with(|conn| {
            conn.prepare("select id, name from own_voices where user_id = ?1 order by id")?
                .query_map([user], |r| {
                    Ok(OwnVoice {
                        id: r.get(0)?,
                        name: r.get(1)?,
                    })
                })?
                .collect()
        })?)
    }

    fn own_recording(&self, user: i64, id: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select recording from own_voices where id = ?1 and user_id = ?2",
                [id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn add_own_voice(&self, user: i64, name: &str, recording: &[u8]) -> anyhow::Result<OwnVoice> {
        Ok(self.with(|conn| {
            conn.execute(
                "insert into own_voices (user_id, name, recording, created_at) values (?1, ?2, ?3, ?4)",
                params![user, name, recording, now_ms()],
            )?;
            Ok(OwnVoice {
                id: conn.last_insert_rowid(),
                name: name.to_string(),
            })
        })?)
    }

    fn rename_own_voice(&self, user: i64, id: i64, name: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.execute(
                "update own_voices set name = ?3 where id = ?1 and user_id = ?2",
                params![id, user, name],
            )
            .map(|changed| changed > 0)
        })?)
    }

    fn delete_own_voice(&self, user: i64, id: i64, voice_id: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let gone = tx.execute(
                "delete from own_voices where id = ?1 and user_id = ?2",
                [id, user],
            )? > 0;
            if gone {
                tx.execute(
                    "delete from card_voices where voice = ?2
                       and card_id in (select id from cards where user_id = ?1)",
                    params![user, voice_id],
                )?;
            }
            tx.commit()?;
            Ok(gone)
        })?)
    }

    fn character_voices(&self, user: i64) -> anyhow::Result<Vec<CharacterVoice>> {
        let rows: Vec<(i64, Option<String>, String, String)> = self.with(|conn| {
            conn.prepare(
                "select c.id, i.names, c.title, v.voice from card_voices v
                 join cards c on c.id = v.card_id left join card_index i on i.card_id = c.id
                 where c.user_id = ?1 and c.trashed_at is null",
            )?
            .query_map([user], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))?
            .collect()
        })?;
        let mut voices: Vec<CharacterVoice> = rows
            .into_iter()
            .map(|(card_id, names, title, voice)| {
                let names: Vec<String> = names
                    .and_then(|names| serde_json::from_str(&names).ok())
                    .unwrap_or_default();
                CharacterVoice {
                    card_id,
                    name: names.into_iter().next().unwrap_or_else(|| title.clone()),
                    title,
                    voice,
                }
            })
            .collect();
        voices.sort_by_key(|voice| (voice.name.to_lowercase(), voice.card_id));
        Ok(voices)
    }

    fn character_voice(&self, user: i64, card_id: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select v.voice from card_voices v join cards c on c.id = v.card_id
                 where v.card_id = ?1 and c.user_id = ?2",
                [card_id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn set_character_voice(
        &self,
        user: i64,
        card_id: i64,
        voice: Option<&str>,
    ) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let had = tx
                .query_row(
                    "select 1 from cards where id = ?1 and user_id = ?2",
                    [card_id, user],
                    |_| Ok(()),
                )
                .optional()?
                .is_some();
            if had {
                match voice {
                    Some(voice) => tx.execute(
                        "insert into card_voices (card_id, voice) values (?1, ?2)
                         on conflict (card_id) do update set voice = excluded.voice",
                        params![card_id, voice],
                    )?,
                    None => tx.execute("delete from card_voices where card_id = ?1", [card_id])?,
                };
            }
            tx.commit()?;
            Ok(had)
        })?)
    }
}

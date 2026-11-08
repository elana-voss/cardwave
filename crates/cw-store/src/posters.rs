//! The letter of a card's poster design as SQLite keeps it (`posters::Storage`): on its row in `cards`, with its
//! picture's means as JSON. Written once, never again.

use cw_library::posters::{Earlier, Letter, Means, Storage, Waiting};
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn next_without_letter(&self) -> anyhow::Result<Option<Waiting>> {
        Ok(self.with(|conn| {
            // The picture only of the one row: in the outer query, as a sort would carry every waiting card's file.
            conn.query_row(
                "select n.id, n.user_id, n.mood,
                    (select b.data from blobs b where b.id =
                        (select v.image_id from card_versions v where v.card_id = n.id
                         order by v.number desc limit 1))
                 from (select c.id, c.user_id, d.mood from cards c join card_descriptions d on d.card_id = c.id
                       where d.state = 'described' and d.mood <> '' and c.poster_letter is null
                       order by d.updated_at, c.id limit 1) n",
                [],
                |r| {
                    Ok(Waiting {
                        card: r.get(0)?,
                        user: r.get(1)?,
                        mood: r.get(2)?,
                        picture: r.get(3)?,
                    })
                },
            )
            .optional()
        })?)
    }

    fn letters_of_mood(&self, user: i64, mood: &str) -> anyhow::Result<Vec<Earlier>> {
        let rows: Vec<(String, Option<String>)> = self.with(|conn| {
            conn.prepare_cached(
                "select c.poster_letter, c.poster_means from cards c join card_descriptions d on d.card_id = c.id
                 where c.user_id = ?1 and d.mood = ?2 and c.poster_letter is not null",
            )?
            .query_map(params![user, mood], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect()
        })?;
        Ok(rows
            .into_iter()
            .filter_map(|(letter, means)| {
                Some(Earlier {
                    letter: Letter::read(&letter)?,
                    means: means.and_then(|json| serde_json::from_str(&json).ok()),
                })
            })
            .collect())
    }

    fn keep_letter(&self, card: i64, letter: Letter, means: Option<Means>) -> anyhow::Result<()> {
        let means = means
            .map(|means| serde_json::to_string(&means))
            .transpose()?;
        self.with(|conn| {
            conn.execute(
                "update cards set poster_letter = ?2, poster_means = ?3 where id = ?1 and poster_letter is null",
                params![card, letter.word(), means],
            )
        })?;
        Ok(())
    }
}

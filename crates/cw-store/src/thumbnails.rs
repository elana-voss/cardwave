//! Small pictures as SQLite keeps them (`thumbnails::Storage`): `thumbnails`,
//! by the picture's row in `blobs` and the box's pixels. `OF_USER` is the SQL
//! that says which are a user's.

use cw_library::thumbnails::{Kept, Storage};
use rusqlite::{OptionalExtension, params};

use crate::Db;

/// Which small pictures are a user's: those of the pictures of that user's
/// cards, in the Trash too. The table names no user, and a picture that two
/// users have is one picture, so its small ones are both users'.
const OF_USER: &str = "blob_id in (
    select v.image_id from card_versions v join cards c on c.id = v.card_id
    where c.user_id = ?1)";

impl Storage for Db {
    fn small_image(
        &self,
        user: i64,
        version_id: i64,
        (width, height): (u32, u32),
    ) -> anyhow::Result<Option<Kept>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select v.image_id, t.data from card_versions v
                 join cards c on c.id = v.card_id
                 left join thumbnails t
                    on t.blob_id = v.image_id and t.width = ?3 and t.height = ?4
                 where v.id = ?1 and c.user_id = ?2",
                params![version_id, user, width, height],
                |r| {
                    Ok(match r.get::<_, Option<Vec<u8>>>(1)? {
                        Some(small) => Kept::Small(small),
                        None => Kept::NotYet(r.get(0)?),
                    })
                },
            )
            .optional()
        })?)
    }

    fn keep_small_image(
        &self,
        picture: i64,
        (width, height): (u32, u32),
        small: &[u8],
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "insert into thumbnails (blob_id, width, height, data)
                 select ?1, ?2, ?3, ?4 where exists (select 1 from blobs where id = ?1)
                 on conflict do nothing",
                params![picture, width, height, small],
            )
        })?;
        Ok(())
    }

    fn remove_small_images_but(&self, asked: &[(u32, u32)]) -> anyhow::Result<()> {
        let asked = asked
            .iter()
            .map(|(width, height)| format!("({width}, {height})"))
            .collect::<Vec<_>>()
            .join(", ");
        self.with(|conn| {
            conn.execute(
                &format!(
                    "delete from thumbnails where rowid in (
                        select rowid from thumbnails
                        where (width, height) not in (values {asked}))"
                ),
                [],
            )
        })?;
        Ok(())
    }

    fn small_images_size(&self, user: i64) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("select coalesce(sum(length(data)), 0) from thumbnails where {OF_USER}"),
                [user],
                |r| r.get(0),
            )
        })?)
    }

    fn clear_small_images(&self, user: i64) -> anyhow::Result<()> {
        self.with(|conn| conn.execute(&format!("delete from thumbnails where {OF_USER}"), [user]))?;
        Ok(())
    }
}

//! The faces on a picture as SQLite keeps them (`faces::Storage`): `picture_faces`, JSON by the picture's row in
//! `blobs`, going with that row.

use cw_library::faces::{Face, Storage};
use rusqlite::{OptionalExtension, params};

use crate::Db;

impl Storage for Db {
    fn next_without_faces(&self) -> anyhow::Result<Option<(i64, Vec<u8>)>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select b.id, b.data from card_versions v join blobs b on b.id = v.image_id
                 where v.number = (select max(number) from card_versions where card_id = v.card_id)
                    and b.id not in (select blob_id from picture_faces)
                 limit 1",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
        })?)
    }

    fn keep_faces(&self, picture: i64, faces: &[Face]) -> anyhow::Result<()> {
        let faces = serde_json::to_string(faces)?;
        self.with(|conn| {
            conn.execute(
                "insert into picture_faces (blob_id, faces)
                 select ?1, ?2 where exists (select 1 from blobs where id = ?1)
                 on conflict do nothing",
                params![picture, faces],
            )
        })?;
        Ok(())
    }
}

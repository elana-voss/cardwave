//! An exact copy of a card known at import (`is_copy`): each version keeps the SHA-256 of what it holds
//! (`card_versions.content`: its picture's hash and its files, sorted), written by `seal` wherever a
//! version's files are written, so a copy is found by one indexed lookup, not by reading the files of every
//! card of the same picture (all JSON cards share the picture of one pixel). A version written before the
//! column has none and is no copy of anything (greenfield: nothing is rebuilt).

use cw_ccv4::png::Container;
use rusqlite::{Connection, params};
use sha2::{Digest, Sha256};

/// A file of a version as compared: its name, its TOML text or its asset's SHA-256.
type File = (String, Option<String>, Option<Vec<u8>>);

/// Hashes `bytes` with its length before it, so no two lists of parts hash alike.
fn put(hash: &mut Sha256, bytes: &[u8]) {
    hash.update((bytes.len() as u64).to_le_bytes());
    hash.update(bytes);
}

/// The content hash of a version of the picture of SHA-256 `image_hash` and `files`, in any order.
fn content_of(image_hash: &[u8], mut files: Vec<File>) -> Vec<u8> {
    files.sort_unstable();
    let mut hash = Sha256::new();
    put(&mut hash, image_hash);
    for (name, toml, asset) in &files {
        put(&mut hash, name.as_bytes());
        match (toml, asset) {
            (Some(toml), _) => put(&mut hash, &[b"t", toml.as_bytes()].concat()),
            (None, Some(asset)) => put(&mut hash, &[b"a", asset.as_slice()].concat()),
            (None, None) => put(&mut hash, b"-"),
        }
    }
    hash.finalize().to_vec()
}

/// Writes the content hash of the version `version_id` from what it holds now.
pub(crate) fn seal(conn: &Connection, version_id: i64) -> rusqlite::Result<()> {
    let image: Vec<u8> = conn.query_row(
        "select b.hash from card_versions v join blobs b on b.id = v.image_id where v.id = ?1",
        [version_id],
        |r| r.get(0),
    )?;
    let files = conn
        .prepare_cached(
            "select f.name, f.toml, b.hash from card_files f left join blobs b on b.id = f.asset_id
             where f.version_id = ?1",
        )?
        .query_map([version_id], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
        .collect::<rusqlite::Result<Vec<File>>>()?;
    conn.execute(
        "update card_versions set content = ?2 where id = ?1",
        params![version_id, content_of(&image, files)],
    )?;
    Ok(())
}

/// Whether `user` has a card not in the Trash whose newest version is `container` exactly: the picture of
/// SHA-256 `image_hash`, and the same files, each TOML text and each asset (by its SHA-256 in `asset_hashes`).
pub(crate) fn is_copy(
    conn: &Connection,
    user: i64,
    image_hash: &[u8],
    container: &Container,
    asset_hashes: &[Vec<u8>],
) -> rusqlite::Result<bool> {
    let files: Vec<File> = container
        .toml
        .iter()
        .map(|(name, text)| (name.clone(), Some(text.clone()), None))
        .chain(
            container
                .assets
                .iter()
                .zip(asset_hashes)
                .map(|((name, _), hash)| (name.clone(), None, Some(hash.clone()))),
        )
        .collect();
    conn.query_row(
        "select exists (select 1 from card_versions v join cards c on c.id = v.card_id
           where v.content = ?2 and c.user_id = ?1 and c.trashed_at is null
             and v.number = (select max(number) from card_versions where card_id = c.id))",
        params![user, content_of(image_hash, files)],
        |r| r.get(0),
    )
}

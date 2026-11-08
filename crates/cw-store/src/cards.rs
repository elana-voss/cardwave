//! Cards as SQLite keeps them (`cards::Storage`): a card's row, its one
//! version with its files and pictures as blobs (once per content), the
//! library's view of it (`card_index`), and its pictures (`card_pictures`).
//! Trap: `save_edit` asks for the card's version again inside its transaction.
//! Trap: every write of a version's files ends with `copies::seal`, or a copy of it is not known.

use cw_ccv4::Document;
use cw_ccv4::png::Container;
use cw_chat::chats;
use cw_library::cards::pictures;
use cw_library::cards::{
    ByMeaning, CardIndex, CardSummary, CardVersion, FoundCards, KeptFiles, NewestFiles, Poster,
    Show, Storage, each_once,
};
use cw_library::posters::Letter;
use cw_library::posters::Mood;
use cw_search::kept::Owner;
use rusqlite::types::Value;
use rusqlite::{Connection, OptionalExtension, params, params_from_iter};

use crate::{Db, copies, shown};
use cw_search as search;

const SUMMARY: &str = "select c.id, c.title, c.favorite, c.archived, c.trashed_at is not null, v.id, v.number,
        c.created_at, i.names, i.tags, i.excerpt,
        (select max(t.updated_at) from chats t
         join chat_characters p on p.chat_id = t.id
         join card_versions pv on pv.id = p.version_id
         where pv.card_id = c.id and t.trashed_at is null and not t.archived),
        d.state, d.tags, d.logline, c.own_tags, d.tagline, d.mood, f.faces, c.poster_letter,
        (select t.title from chats t
         join chat_characters p on p.chat_id = t.id
         join card_versions pv on pv.id = p.version_id
         where pv.card_id = c.id and t.trashed_at is null and not t.archived
         order by t.updated_at desc, t.id desc limit 1)
     from cards c join card_versions v on v.card_id = c.id left join card_index i on i.card_id = c.id
     left join card_descriptions d on d.card_id = c.id
     left join picture_faces f on f.blob_id = v.image_id
     where v.number = (select max(number) from card_versions where card_id = c.id) and c.user_id = ?1";

fn summary(row: &rusqlite::Row<'_>) -> rusqlite::Result<CardSummary> {
    let list = |column: usize| -> rusqlite::Result<Vec<String>> {
        let json: Option<String> = row.get(column)?;
        Ok(json
            .and_then(|json| serde_json::from_str(&json).ok())
            .unwrap_or_default())
    };
    let state: Option<String> = row.get(12)?;
    let described = state.as_deref() == Some("described");
    let of_description = |column: usize| -> rusqlite::Result<String> {
        let text: Option<String> = if described { row.get(column)? } else { None };
        Ok(text.unwrap_or_default())
    };
    let (tags, excerpt) = if described {
        // The terms, the user's own tags, then the file's (the owner: "keep
        // them"), each once.
        let mut tags = list(13)?;
        tags.extend(list(15)?);
        tags.extend(list(9)?);
        let tags = each_once(&tags)
            .into_iter()
            .map(|(_, tag)| tag.to_string())
            .collect();
        (tags, row.get(14)?)
    } else {
        let excerpt: Option<String> = row.get(10)?;
        (list(9)?, excerpt.unwrap_or_default())
    };
    Ok(CardSummary {
        id: row.get(0)?,
        title: row.get(1)?,
        favorite: row.get(2)?,
        archived: row.get(3)?,
        trashed: row.get(4)?,
        version_id: row.get(5)?,
        version: row.get(6)?,
        created_at: row.get(7)?,
        names: list(8)?,
        tags,
        excerpt,
        last_chat_at: row.get(11)?,
        last_chat_title: row.get(20)?,
        describing: state.as_deref() == Some("queued"),
        poster: Some(Poster {
            tagline: of_description(16)?,
            mood: Mood::read(&of_description(17)?),
            faces: row
                .get::<_, Option<String>>(18)?
                .and_then(|json| serde_json::from_str(&json).ok())
                .unwrap_or_default(),
            design: row
                .get::<_, Option<String>>(19)?
                .as_deref()
                .and_then(Letter::read),
        }),
    })
}

/// A word as it is, where `like` would read `%` and `_` as "anything".
pub(super) fn escape_like(word: &str) -> String {
    let mut out = String::with_capacity(word.len());
    for c in word.chars() {
        if matches!(c, '%' | '_' | '\\') {
            out.push('\\');
        }
        out.push(c);
    }
    out
}

/// The cards of `user` (`args[0]`) that `clause`, a fixed SQL text binding
/// any further `args`, keeps after `SUMMARY`.
fn summaries_on(
    conn: &Connection,
    clause: &str,
    args: &[i64],
) -> rusqlite::Result<Vec<CardSummary>> {
    let mut query = conn.prepare(&format!("{SUMMARY} {clause}"))?;
    query.query_map(params_from_iter(args), summary)?.collect()
}

/// A card of `user`, on a connection held.
fn card_on(conn: &Connection, user: i64, card_id: i64) -> rusqlite::Result<Option<CardSummary>> {
    Ok(summaries_on(conn, "and c.id = ?2", &[user, card_id])?
        .into_iter()
        .next())
}

/// Stores `files` (name, TOML text) as the files of the version `version_id`.
fn put_toml(
    conn: &Connection,
    version_id: i64,
    files: &[(String, String)],
) -> rusqlite::Result<()> {
    for (name, text) in files {
        conn.execute(
            "insert into card_files (version_id, name, toml) values (?1, ?2, ?3)",
            params![version_id, name, text],
        )?;
    }
    Ok(())
}

/// The TOML files of a version, on a connection held; none where it has none.
fn toml_on(conn: &Connection, version_id: i64) -> rusqlite::Result<Vec<(String, String)>> {
    let mut query = conn
        .prepare("select name, toml from card_files where version_id = ?1 and toml is not null")?;
    query
        .query_map([version_id], |r| Ok((r.get(0)?, r.get(1)?)))?
        .collect()
}

/// Stores `data` (with its SHA-256 `hash`) unless the same bytes are already
/// there; returns the blob's id.
pub(super) fn put_blob(conn: &Connection, hash: &[u8], data: &[u8]) -> rusqlite::Result<i64> {
    conn.execute(
        "insert into blobs (hash, data) values (?1, ?2) on conflict (hash) do nothing",
        params![hash, data],
    )?;
    conn.query_row("select id from blobs where hash = ?1", [hash], |r| r.get(0))
}

/// Keeps the blob `image_id` among the card's pictures, as come from `source`;
/// one kept already stays as it came.
fn keep_picture(
    conn: &Connection,
    card_id: i64,
    image_id: i64,
    source: &str,
    now: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "insert or ignore into card_pictures (card_id, image_id, added_at, source) values (?1, ?2, ?3, ?4)",
        params![card_id, image_id, now, source],
    )?;
    Ok(())
}

/// Deletes the pictures and files no card, expression pack or figure uses any more.
pub(super) fn remove_unused_blobs(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute(
        "delete from blobs where id not in (select image_id from card_versions)
           and id not in (select image_id from card_pictures)
           and id not in (select asset_id from card_files where asset_id is not null)
           and id not in (select image_id from expression_pictures)
           and id not in (select file_id from figures)
           and id not in (select still_id from figures)",
        [],
    )?;
    Ok(())
}

/// Writes what the library shows and searches of a card (`card_index`).
fn put_index(
    conn: &Connection,
    card_id: i64,
    version_id: i64,
    index: &CardIndex,
) -> rusqlite::Result<()> {
    conn.execute(
        "insert into card_index (card_id, version_id, names, tags, excerpt, search, texts, brings) values (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
         on conflict (card_id) do update set version_id = excluded.version_id, names = excluded.names,
            tags = excluded.tags, excerpt = excluded.excerpt, search = excluded.search, texts = excluded.texts,
            brings = excluded.brings",
        params![
            card_id,
            version_id,
            index.names,
            index.tags,
            index.excerpt,
            index.search,
            index.texts,
            index.brings
        ],
    )?;
    let user: i64 = conn.query_row("select user_id from cards where id = ?1", [card_id], |r| {
        r.get(0)
    })?;
    crate::find::put_texts_on(conn, user, Owner::Card(card_id), &index.lore)
}

/// Adds a version to the card of the version `old`, as its newest: with that
/// one's picture and assets, without its TOML files.
fn version_after(
    conn: &Connection,
    old: i64,
    now: i64,
    image: Option<i64>,
) -> rusqlite::Result<CardVersion> {
    // The new version tells its own id and number: were the card deleted in the
    // meantime, there would be none, and nothing would be written.
    let (id, number) = conn.query_row(
        "insert into card_versions (id, card_id, number, image_id, created_at)
         select (select last + 1 from version_seq), old.card_id, (select max(number) from card_versions where card_id = old.card_id) + 1,
                coalesce(?3, old.image_id), ?2
         from card_versions old where old.id = ?1
         returning id, number",
        params![old, now, image],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    conn.execute(
        "insert into card_files (version_id, name, asset_id)
         select ?2, name, asset_id from card_files where version_id = ?1 and toml is null",
        [old, id],
    )?;
    Ok(CardVersion {
        id,
        number,
        created_at: now,
    })
}

/// Puts `keep` in the place of the card's version `only`, or of all its others:
/// the chats with them move to it, each character called as `document`
/// (`keep`'s) calls it, and the versions go with their files. A chat character
/// `keep` lacks stays where it is, with its version: as an older build could
/// leave it. The pictures stay the card's (`card_pictures`).
fn retire(
    conn: &Connection,
    card_id: i64,
    keep: i64,
    only: Option<i64>,
    document: &Document,
) -> rusqlite::Result<()> {
    let behind: Vec<(i64, String)> = conn
        .prepare(
            "select p.id, p.character from chat_characters p join card_versions v on v.id = p.version_id
             where v.card_id = ?1 and p.version_id <> ?2 and (?3 is null or v.id = ?3)",
        )?
        .query_map(params![card_id, keep, only], |r| Ok((r.get(0)?, r.get(1)?)))?
        .collect::<rusqlite::Result<_>>()?;
    for (id, character) in behind {
        if document.character(&character).is_none() {
            continue;
        }
        conn.execute(
            "update chat_characters set version_id = ?2, name = ?3 where id = ?1",
            params![id, keep, chats::listed_name(document, &character)],
        )?;
    }
    conn.execute(
        "delete from card_versions where card_id = ?1 and id <> ?2 and (?3 is null or id = ?3)
         and id not in (select version_id from chat_characters)",
        params![card_id, keep, only],
    )?;
    Ok(())
}

impl Storage for Db {
    fn card_summaries(&self, user: i64) -> anyhow::Result<Vec<CardSummary>> {
        Ok(self.with(|conn| summaries_on(conn, "order by c.id", &[user]))?)
    }

    fn cards_bringing_lore(&self, user: i64) -> anyhow::Result<Vec<CardSummary>> {
        Ok(self.with(|conn| summaries_on(conn, "and i.brings > 0 order by c.id", &[user]))?)
    }

    fn find_cards(
        &self,
        user: i64,
        show: Show,
        words: &[&str],
        near: Option<&[f32]>,
    ) -> anyhow::Result<FoundCards> {
        let searching = !words.is_empty();
        let shown = format!(
            "{SUMMARY} and c.trashed_at is null{}",
            shown(show, "c", searching)
        );
        let mut sql = shown.clone();
        let mut values = vec![Value::Integer(user)];
        for word in words {
            values.push(Value::Text(format!("%{}%", escape_like(word))));
            sql.push_str(&format!(
                " and (i.search || char(10) || coalesce(d.terms, '')) like ?{} escape '\\'",
                values.len()
            ));
        }
        let (cards, all) = self.with(|conn| {
            let mut query = conn.prepare(&sql)?;
            let cards: Vec<CardSummary> = query
                .query_map(params_from_iter(values), summary)?
                .collect::<rusqlite::Result<_>>()?;
            // The cards and their vectors are read at one moment.
            let all = match near {
                Some(_) if searching => {
                    let mut all = conn.prepare(&shown)?;
                    let all: Vec<CardSummary> = all
                        .query_map([user], summary)?
                        .collect::<rusqlite::Result<_>>()?;
                    let stamp = crate::search::stamp_on(conn, user)?;
                    Some((all, stamp, crate::search::card_vectors(self, conn)?))
                }
                _ => None,
            };
            Ok((cards, all))
        })?;
        let meaning = match (all, near) {
            (Some((all, stamp, vectors)), Some(near)) => {
                let ids: Vec<i64> = all.iter().map(|card| card.id).collect();
                let near = search::rank(&vectors, &ids, &stamp, near);
                Some(ByMeaning { all, near })
            }
            _ => None,
        };
        Ok(FoundCards { cards, meaning })
    }

    fn card(&self, user: i64, card_id: i64) -> anyhow::Result<Option<CardSummary>> {
        Ok(self.with(|conn| card_on(conn, user, card_id))?)
    }

    fn set_card_favorite(&self, user: i64, card_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(("cards", "card"), user, card_id, "favorite", &on)
    }

    fn set_card_archived(&self, user: i64, card_id: i64, on: bool) -> anyhow::Result<()> {
        self.set(("cards", "card"), user, card_id, "archived", &on)
    }

    fn card_title(&self, user: i64, card_id: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select title from cards where id = ?1 and user_id = ?2",
                [card_id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn edited_at(&self, version_id: i64) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select created_at from card_versions where id = ?1 and number > 1",
                [version_id],
                |row| row.get(0),
            )
            .optional()
        })?)
    }

    fn card_of_version(&self, user: i64, version_id: i64) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select c.id from card_versions v join cards c on c.id = v.card_id where v.id = ?1 and c.user_id = ?2",
                [version_id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn knows_file(&self, user: i64, fingerprint: &[u8]) -> anyhow::Result<bool> {
        Ok(self.with(|conn| is_known(conn, user, Some(fingerprint)))?)
    }

    fn is_kept_file(
        &self,
        kept: KeptFiles,
        user: i64,
        path: &str,
        len: u64,
        modified: i64,
    ) -> anyhow::Result<bool> {
        let table = kept_table(kept);
        Ok(self.with(|conn| {
            conn.query_row(
                &format!("select 1 from {table} where user_id = ?1 and path = ?2 and len = ?3 and modified = ?4"),
                params![user, path, len as i64, modified],
                |_| Ok(()),
            )
            .optional()
            .map(|found| found.is_some())
        })?)
    }

    fn keep_file(
        &self,
        kept: KeptFiles,
        user: i64,
        path: &str,
        len: u64,
        modified: i64,
    ) -> anyhow::Result<()> {
        let table = kept_table(kept);
        Ok(self.with(|conn| {
            conn.execute(
                &format!("insert or replace into {table} (user_id, path, len, modified) values (?1, ?2, ?3, ?4)"),
                params![user, path, len as i64, modified],
            )
            .map(drop)
        })?)
    }

    #[allow(clippy::too_many_arguments)]
    fn store_card(
        &self,
        user: i64,
        title: &str,
        container: &Container,
        hashes: (&[u8], &[Vec<u8>]),
        source: &str,
        fingerprint: Option<&[u8]>,
        index: &CardIndex,
        now: i64,
    ) -> anyhow::Result<(i64, i64)> {
        let (image_hash, asset_hashes) = hashes;
        let stored = self.with(|conn| {
            let tx = conn.transaction()?;
            // Checked in the transaction, so two imports of one card at once store it once.
            if source == "imported"
                && (is_known(&tx, user, fingerprint)?
                    || copies::is_copy(&tx, user, image_hash, container, asset_hashes)?)
            {
                return Ok(None);
            }
            tx.execute(
                "insert into cards (user_id, title, created_at, updated_at, fingerprint)
                 values (?1, ?2, ?3, ?3, ?4)",
                params![user, title, now, fingerprint],
            )?;
            let (card_id, number) = (tx.last_insert_rowid(), 1);
            let image_id = put_blob(&tx, image_hash, &container.image)?;
            tx.execute(
                "insert into card_versions (id, card_id, number, image_id, created_at)
                 values ((select last + 1 from version_seq), ?1, ?2, ?3, ?4)",
                params![card_id, number, image_id, now],
            )?;
            let version_id = tx.last_insert_rowid();
            keep_picture(&tx, card_id, image_id, source, now)?;
            put_toml(&tx, version_id, &container.toml)?;
            for ((name, data), hash) in container.assets.iter().zip(asset_hashes) {
                let asset_id = put_blob(&tx, hash, data)?;
                tx.execute(
                    "insert into card_files (version_id, name, asset_id) values (?1, ?2, ?3)",
                    params![version_id, name, asset_id],
                )?;
            }
            copies::seal(&tx, version_id)?;
            put_index(&tx, card_id, version_id, index)?;
            tx.commit()?;
            Ok(Some((card_id, version_id)))
        })?;
        *self.text_vectors() = None;
        stored.ok_or_else(|| cw_library::cards::in_library().into())
    }

    fn mark_card_made(&self, card_id: i64) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update cards set title_edited = 1, own_tags = (select tags from card_index where card_id = ?1)
                 where id = ?1",
                [card_id],
            )
        })?;
        Ok(())
    }

    fn set_card_file(&self, card_id: i64, name: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update cards set file_name = ?2 where id = ?1",
                rusqlite::params![card_id, name],
            )
        })?;
        Ok(())
    }

    fn card_file(&self, card_id: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select file_name from cards where id = ?1",
                [card_id],
                |row| row.get(0),
            )
        })?)
    }

    fn stale_indexes(&self) -> anyhow::Result<Vec<(i64, i64, String)>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(
                "select c.id, v.id, c.title from cards c join card_versions v on v.card_id = c.id
                 left join card_index i on i.card_id = c.id
                 where v.number = (select max(number) from card_versions where card_id = c.id)
                   and (i.version_id is null or i.version_id <> v.id)",
            )?;
            query
                .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
                .collect()
        })?)
    }

    fn put_index(&self, card_id: i64, version_id: i64, index: &CardIndex) -> anyhow::Result<()> {
        self.with(|conn| put_index(conn, card_id, version_id, index))?;
        *self.text_vectors() = None;
        Ok(())
    }

    fn save_edit(
        &self,
        edit: &cw_library::cards::SavedEdit<'_>,
    ) -> anyhow::Result<Result<CardVersion, Option<i64>>> {
        let card_id = edit.card_id;
        let saved = self.with(|conn| {
            let tx = conn.transaction()?;
            // Asked again where it is written: an edit saved since the card was read is not written over.
            let newest: Option<i64> = tx.query_row(
                "select max(number) from card_versions where card_id = ?1",
                [card_id],
                |r| r.get(0),
            )?;
            if newest != Some(edit.version) {
                return Ok(Err(newest));
            }
            let new = version_after(&tx, edit.version_id, edit.now, edit.image)?;
            put_toml(&tx, new.id, edit.files)?;
            copies::seal(&tx, new.id)?;
            // A title the user gives is not replaced by a generated one, and the
            // tags the edit adds are the user's own.
            let (own, before): (String, String) = tx.query_row(
                "select c.own_tags, coalesce(i.tags, '[]') from cards c
                 left join card_index i on i.card_id = c.id where c.id = ?1",
                [card_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )?;
            let own = (edit.own_tags)(&own, &before);
            tx.execute(
                "update cards set title = ?2, updated_at = ?3, own_tags = ?4,
                    title_edited = title_edited or ?5 where id = ?1",
                params![card_id, edit.title, edit.now, own, edit.renamed],
            )?;
            put_index(&tx, card_id, new.id, edit.index)?;
            retire(&tx, card_id, new.id, Some(edit.version_id), edit.document)?;
            tx.commit()?;
            Ok(Ok(new))
        })?;
        *self.text_vectors() = None;
        Ok(saved)
    }

    fn version_made(&self, version_id: i64) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select created_at from card_versions where id = ?1",
                [version_id],
                |r| r.get(0),
            )
        })?)
    }

    fn cards_with_versions(&self) -> anyhow::Result<Vec<i64>> {
        Ok(self.with(|conn| {
            conn.prepare("select card_id from card_versions group by card_id having count(*) > 1")?
                .query_map([], |r| r.get(0))?
                .collect()
        })?)
    }

    fn remove_unused_blobs(&self) -> anyhow::Result<()> {
        Ok(self.with(|conn| remove_unused_blobs(conn))?)
    }

    fn versions_of(&self, card_id: i64) -> anyhow::Result<Vec<(i64, i64)>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select id, created_at from card_versions where card_id = ?1 order by number",
            )?
            .query_map([card_id], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect()
        })?)
    }

    fn characters_chatted(&self, card_id: i64) -> anyhow::Result<Vec<String>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select distinct p.character from chat_characters p join card_versions v on v.id = p.version_id
                 where v.card_id = ?1",
            )?
            .query_map([card_id], |r| r.get(0))?
            .collect()
        })?)
    }

    fn fold_into(
        &self,
        card_id: i64,
        keep: i64,
        files: &[(String, String)],
        document: &Document,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "delete from card_files where version_id = ?1 and toml is not null",
                [keep],
            )?;
            put_toml(&tx, keep, files)?;
            copies::seal(&tx, keep)?;
            retire(&tx, card_id, keep, None, document)?;
            tx.commit()
        })?;
        Ok(())
    }

    fn toml_files(&self, version_id: i64) -> anyhow::Result<Vec<(String, String)>> {
        Ok(self.with(|conn| toml_on(conn, version_id))?)
    }

    fn newest_files(&self, user: i64, card_id: i64) -> anyhow::Result<Option<NewestFiles>> {
        Ok(self.with(|conn| match card_on(conn, user, card_id)? {
            Some(card) => Ok(Some(NewestFiles {
                files: toml_on(conn, card.version_id)?,
                card,
            })),
            None => Ok(None),
        })?)
    }

    fn has_asset(&self, version_id: i64, name: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select exists (select 1 from card_files where version_id = ?1 and name = ?2 and asset_id is not null)",
                params![version_id, name],
                |r| r.get(0),
            )
        })?)
    }

    fn asset(&self, user: i64, version_id: i64, name: &str) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select b.data from card_files f
                 join blobs b on b.id = f.asset_id
                 join card_versions v on v.id = f.version_id
                 join cards c on c.id = v.card_id
                 where f.version_id = ?1 and f.name = ?2 and c.user_id = ?3",
                params![version_id, name, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn card_files(&self, version_id: i64) -> anyhow::Result<Container> {
        Ok(self.with(|conn| {
            let image = conn.query_row(
                "select b.data from card_versions v join blobs b on b.id = v.image_id where v.id = ?1",
                [version_id],
                |r| r.get(0),
            )?;
            let mut container = Container {
                image,
                ..Default::default()
            };
            let mut query = conn.prepare(
                "select f.name, f.toml, b.data from card_files f left join blobs b on b.id = f.asset_id
                 where f.version_id = ?1 order by f.name",
            )?;
            let mut rows = query.query([version_id])?;
            while let Some(row) = rows.next()? {
                let name: String = row.get(0)?;
                match row.get::<_, Option<String>>(1)? {
                    Some(text) => container.toml.push((name, text)),
                    None => container.assets.push((name, row.get(2)?)),
                }
            }
            Ok(container)
        })?)
    }

    fn card_image(&self, user: i64, version_id: i64) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select b.data from card_versions v
                 join blobs b on b.id = v.image_id
                 join cards c on c.id = v.card_id
                 where v.id = ?1 and c.user_id = ?2",
                [version_id, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn add_card_picture(
        &self,
        card_id: i64,
        hash: &[u8],
        data: &[u8],
        source: &str,
        now: i64,
    ) -> anyhow::Result<i64> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let image_id = put_blob(&tx, hash, data)?;
            keep_picture(&tx, card_id, image_id, source, now)?;
            tx.commit()?;
            Ok(image_id)
        })?)
    }

    fn card_pictures(&self, user: i64, card_id: i64) -> anyhow::Result<Vec<pictures::Kept>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select p.image_id, p.source, p.added_at, substr(b.data, 1, 24), p.image_id = v.image_id
                 from card_pictures p join blobs b on b.id = p.image_id
                 join cards c on c.id = p.card_id
                 join card_versions v on v.card_id = c.id
                    and v.number = (select max(number) from card_versions where card_id = c.id)
                 where p.card_id = ?1 and c.user_id = ?2
                 order by p.image_id = v.image_id desc, p.added_at desc, p.image_id desc",
            )?
            .query_map([card_id, user], |r| {
                Ok(pictures::Kept {
                    id: r.get(0)?,
                    source: r.get(1)?,
                    added_at: r.get(2)?,
                    head: r.get(3)?,
                    in_use: r.get(4)?,
                })
            })?
            .collect()
        })?)
    }

    fn card_picture(
        &self,
        user: i64,
        card_id: i64,
        picture: i64,
    ) -> anyhow::Result<Option<Vec<u8>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select b.data from card_pictures p join blobs b on b.id = p.image_id
                 join cards c on c.id = p.card_id
                 where p.card_id = ?1 and p.image_id = ?2 and c.user_id = ?3",
                [card_id, picture, user],
                |r| r.get(0),
            )
            .optional()
        })?)
    }
}

/// The table that holds the list `kept`.
fn kept_table(kept: KeptFiles) -> &'static str {
    match kept {
        KeptFiles::NotCards => "not_cards",
        KeptFiles::Watched => "watched_files",
    }
}

/// Whether a card of `user` outside the Trash came from a file of this fingerprint.
fn is_known(conn: &Connection, user: i64, fingerprint: Option<&[u8]>) -> rusqlite::Result<bool> {
    let Some(fingerprint) = fingerprint else {
        return Ok(false);
    };
    conn.query_row(
        "select exists (select 1 from cards where user_id = ?1 and fingerprint = ?2 and trashed_at is null)",
        params![user, fingerprint],
        |row| row.get(0),
    )
}

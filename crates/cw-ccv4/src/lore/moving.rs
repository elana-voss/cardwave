//! A card's own lorebook moved into the library ("Move to library") and back
//! (its Undo): [`alone`] is the lorebook as a library lorebook's text, with
//! its entries' history; [`take_out`] takes it out of the card's files; and
//! [`put_in`] puts a library lorebook into a card's files as the card's own,
//! for its first character, with the history its entries gathered in the
//! library (`drafts::adopt`).
//!
//! Trap: `toml` writes a list of tables as `[[…]]`, while a revision's drafts
//! are an inline list (`drafts.rs`): `inline_drafts` makes them so again.

use std::collections::HashSet;

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};
use toml::{Table, Value};
use toml_edit::{DocumentMut, Item};

use crate::edit::{find, set_list};
use crate::lore::{Open, Rewritten, joined, unplace};
use crate::{Document, drafts, mapping, split_reference, strings};

/// The lorebook `book` of a card's `document` as a library lorebook's one
/// text: the lorebook and its entries, as `Document::lorebook_alone` has them,
/// with the history of each entry. `None` when there is no such lorebook.
pub fn alone(document: &Document, book: &str) -> anyhow::Result<Option<String>> {
    let Some(toml) = document.lorebook_alone(book) else {
        return Ok(None);
    };
    let revisions = document.root.get("revision").and_then(Value::as_table);
    let history: Table = mapping::entries(document, book)
        .into_iter()
        .filter_map(|entry| Some((entry.to_string(), revisions?.get(entry)?.clone())))
        .collect();
    if history.is_empty() {
        return Ok(Some(toml));
    }
    let mut file = Table::new();
    file.insert("revision".into(), Value::Table(history));
    let history = inline_drafts(&toml::to_string(&file)?)?;
    Ok(Some(joined(&[
        (String::new(), toml),
        (String::new(), history),
    ])))
}

/// A file of revisions with each revision's drafts as one inline list, as `drafts.rs` adds to them.
fn inline_drafts(toml: &str) -> anyhow::Result<String> {
    let mut file: DocumentMut = toml.parse()?;
    if let Some(revisions) = file.get_mut("revision").and_then(Item::as_table_like_mut) {
        for (_, revision) in revisions.iter_mut() {
            if let Some(drafts) = revision
                .as_table_like_mut()
                .and_then(|r| r.get_mut("drafts"))
            {
                drafts.make_value();
            }
        }
    }
    Ok(file.to_string())
}

/// Takes the lorebook `book` out of a card's `files`: its block, the blocks of
/// its entries that no other lorebook of the card lists, and its line in each
/// character's `lorebooks`.
pub fn take_out(files: &[(String, String)], book: &str) -> anyhow::Result<Rewritten> {
    let mut open = Open::of(files, book)?;
    let id = open.id.clone();
    let others: HashSet<String> = open
        .document
        .ids("lorebook")
        .into_iter()
        .filter(|other| *other != id)
        .flat_map(|other| {
            let listed = open.document.lookup(&format!("lorebook.{other}"));
            strings(listed.and_then(|other| other.get("entries")))
        })
        .map(str::to_string)
        .collect();
    for entry in open.listed.clone() {
        if let Some(("lore", entry_id)) = split_reference(&entry)
            && !others.contains(&entry)
        {
            open.take(entry_id);
        }
    }
    for file in &mut open.files {
        if let Some(books) = file.get_mut("lorebook").and_then(Item::as_table_like_mut) {
            books.remove(&id);
        }
    }
    let characters: Vec<String> = open
        .document
        .ids("character")
        .into_iter()
        .map(str::to_string)
        .collect();
    for character in characters {
        let had = open
            .document
            .character(&character)
            .and_then(|one| one.get("lorebooks"));
        let had: Vec<String> = strings(had).into_iter().map(str::to_string).collect();
        if !had.iter().any(|reference| reference == book) {
            continue;
        }
        let kept: Vec<String> = had
            .into_iter()
            .filter(|reference| reference != book)
            .collect();
        let table = open
            .at(&["character", &character])
            .and_then(Item::as_table_like_mut);
        set_list(
            table.context(
                Fail::said(
                    Code::NotPossible,
                    "the character cannot be changed in this card",
                )
                .with("what", "card_character_change"),
            )?,
            "lorebooks",
            &kept,
        );
    }
    let rewritten = open.finish()?;
    ensure!(
        rewritten.document.lookup(book).is_none(),
        Fail::said(
            Code::NotPossible,
            "the lorebook cannot be taken out of this card"
        )
        .with("what", "lorebook_take_out")
    );
    Ok(rewritten)
}

/// Puts the lorebook `book` of `from` (a library lorebook) into a card's
/// `files` as its own: its block and its entries' into the file of the card's
/// first character, and its line last in that character's `lorebooks`; its
/// entries' history is the one `from` has.
/// Refused where the card has a block of one of their IDs by now.
pub fn put_in(
    files: &[(String, String)],
    from: &Document,
    book: &str,
) -> anyhow::Result<Rewritten> {
    let document = Document::parse(files)?;
    let character = document.characters().first().map(|one| one.to_string());
    let character = character.context(
        Fail::said(Code::NotPossible, "the card has no character")
            .with("what", "card_no_character"),
    )?;
    let (_, id) = split_reference(book).context(
        Fail::said(Code::NotReadable, "this is no lorebook").with("what", "no_lorebook"),
    )?;
    let entries = mapping::entries(from, book);
    let taken = std::iter::once(book).chain(entries.iter().copied());
    ensure!(
        taken
            .into_iter()
            .all(|reference| document.lookup(reference).is_none()),
        Fail::said(
            Code::Taken,
            "the card has a lorebook or an entry of the same name by now"
        )
        .with("what", "lorebook_same_name")
    );
    let mut blocks = Table::new();
    let block = from
        .lookup(book)
        .context(Fail::said(Code::NotReadable, "this is no lorebook").with("what", "no_lorebook"))?
        .clone();
    blocks.insert(
        "lorebook".into(),
        Value::Table(Table::from_iter([(id.to_string(), Value::Table(block))])),
    );
    let lore: Table = entries
        .iter()
        .filter_map(|entry| {
            Some((
                split_reference(entry)?.1.to_string(),
                Value::Table(from.lookup(entry)?.clone()),
            ))
        })
        .collect();
    blocks.insert("lore".into(), Value::Table(lore));
    let blocks: DocumentMut = toml::to_string(&blocks)?.parse()?;
    let mut written = files.to_vec();
    let home = files.iter().position(|(_, text)| {
        let file: Option<DocumentMut> = text.parse().ok();
        file.is_some_and(|file| {
            file.get("character")
                .and_then(|all| all.get(&character))
                .is_some()
        })
    });
    let home = home.context(
        Fail::said(Code::NotPossible, "the card's character cannot be changed")
            .with("what", "card_character_change"),
    )?;
    let owned: Vec<String> = entries.iter().map(|entry| entry.to_string()).collect();
    drafts::adopt(&mut written, from, &owned)?;
    let mut file: DocumentMut = files[home].1.parse()?;
    for kind in ["lorebook", "lore"] {
        let Some(added) = blocks.get(kind).and_then(Item::as_table_like) else {
            continue;
        };
        let into = file.entry(kind).or_insert_with(|| {
            let mut table = toml_edit::Table::new();
            table.set_implicit(true);
            Item::Table(table)
        });
        let into = into.as_table_like_mut().context(
            Fail::said(Code::NotPossible, "the card takes no lorebook")
                .with("what", "card_takes_no_lorebook"),
        )?;
        for (key, item) in added.iter() {
            let mut table = item.clone().into_table().ok().context(
                Fail::said(Code::NotReadable, "this is no lorebook").with("what", "no_lorebook"),
            )?;
            unplace(&mut table);
            into.insert(key, Item::Table(table));
        }
    }
    let had = document
        .character(&character)
        .and_then(|one| one.get("lorebooks"));
    let mut listed: Vec<String> = strings(had).into_iter().map(str::to_string).collect();
    listed.push(book.to_string());
    let table =
        find(file.as_item_mut(), &["character", &character]).and_then(Item::as_table_like_mut);
    set_list(
        table.context(
            Fail::said(Code::NotPossible, "the card's character cannot be changed")
                .with("what", "card_character_change"),
        )?,
        "lorebooks",
        &listed,
    );
    written[home].1 = file.to_string();
    let document = Document::parse(&written).context(
        Fail::said(
            Code::NotPossible,
            "the card would not read after this change",
        )
        .with("what", "edit_breaks_card"),
    )?;
    ensure!(
        mapping::entries(&document, book).len() == entries.len(),
        Fail::said(
            Code::NotPossible,
            "the lorebook cannot be put into this card"
        )
        .with("what", "lorebook_put_in")
    );
    Ok(Rewritten {
        files: written,
        document,
    })
}

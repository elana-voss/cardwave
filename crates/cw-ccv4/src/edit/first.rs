//! [`first_only`]: a card imported with several characters keeps the first.

use anyhow::Context;
use cw_core::{Code, Fail};
use toml_edit::visit::Visit;
use toml_edit::{DocumentMut, Item};

use crate::{Document, ImportNote, is_placeholder, plain, split_reference, strings};

use crate::edit::{Named, find};

/// Keeps the first character of a card imported with several, as a card holds
/// one (the owner, 2026-10-18): the others go from its `files`, with its groups
/// and every block that only they named. Answers what the import tells the
/// user then; none where the card had one character or none.
pub fn first_only(files: &mut [(String, String)]) -> anyhow::Result<Option<ImportNote>> {
    // A SillyTavern card, which has none yet, has one character.
    if files.is_empty() {
        return Ok(None);
    }
    let document = Document::parse(files)?;
    let ids = document.ids("character");
    let [first, others @ ..] = ids.as_slice() else {
        return Ok(None);
    };
    if others.is_empty() {
        return Ok(None);
    }
    let mut gone: Vec<String> = Vec::new();
    for id in others {
        // `others` are ids the document listed.
        let block = document.character(id).expect("listed");
        for key in ["prompt", "greetings", "group-greetings", "lorebooks"] {
            gone.extend(strings(block.get(key)).into_iter().map(str::to_string));
        }
        for key in ["name-char", "creator-note"] {
            gone.extend(
                block
                    .get(key)
                    .and_then(toml::Value::as_str)
                    .map(str::to_string),
            );
        }
    }
    // A lorebook that goes takes the entries only it named.
    let entries: Vec<String> = gone
        .iter()
        .filter_map(|reference| document.lookup(reference))
        .flat_map(|book| strings(book.get("entries")))
        .map(str::to_string)
        .collect();
    gone.extend(entries);
    gone.retain(|reference| !is_placeholder(reference));
    let note = ImportNote::FirstCharacterKept {
        name: plain(&document.character_name(first)),
    };

    let mut open = Vec::new();
    for (name, text) in files.iter() {
        let mut file = text.parse::<DocumentMut>().with_context(|| {
            Fail::said(Code::NotReadable, format!("{name} is not valid TOML"))
                .with("what", "toml")
                .with("name", name.to_string())
        })?;
        file.remove("group");
        if let Some(all) =
            find(file.as_item_mut(), &["character"]).and_then(Item::as_table_like_mut)
        {
            for id in others {
                all.remove(id);
            }
        }
        open.push(file);
    }
    drop_unnamed(&mut open, gone);
    for ((_, text), file) in files.iter_mut().zip(open) {
        let written = file.to_string();
        if text
            .parse::<DocumentMut>()
            .map(|before| before.to_string())
            .ok()
            != Some(written.clone())
        {
            *text = written;
        }
    }
    Ok(Some(note))
}

/// Takes the blocks of `gone` out of `open` once nothing names them, until
/// every block left is named: a block named by one that went may be named no
/// more.
fn drop_unnamed(open: &mut [DocumentMut], mut gone: Vec<String>) {
    loop {
        let mut named = Named::default();
        for file in open.iter() {
            named.visit_document(file);
        }
        let unnamed: Vec<String> = gone
            .iter()
            .filter(|reference| !named.0.contains(reference.as_str()))
            .cloned()
            .collect();
        drop(named);
        let mut removed = false;
        for reference in &unnamed {
            let Some((kind, id)) = split_reference(reference) else {
                continue;
            };
            for file in open.iter_mut() {
                if let Some(all) =
                    find(file.as_item_mut(), &[kind]).and_then(Item::as_table_like_mut)
                {
                    removed |= all.remove(id).is_some();
                }
            }
        }
        gone.retain(|reference| !unnamed.contains(reference));
        if !removed {
            break;
        }
    }
}

//! A card's texts with their history (section 3.3.4): every text block (an
//! element of the card's with a `text`) keeps its earlier drafts in a
//! `revision`, in the card's `user/` files. [`record`] adds a draft of each
//! block a change made or gave other words (not other modes alone); the newest draft is the text as it is, so a
//! block taken out of the card still has its last words there. A block whose
//! newest draft is not how it read before (it never had one, or it came with
//! drafts of other wordings) is given one of that first (at `since`, as
//! "imported"): an imported card's texts get drafts only once they change.
//! [`only_history`] is the history alone, for a card exported with it;
//! [`adopt`] gives blocks the history another document has of them (a
//! lorebook moved back into its card from the library): words the history
//! already ends in get no draft again.
//!
//! Beyond the spec, a draft says what made it in `made`: "imported", "edited",
//! "restored", "translated" or the AI tool's key (`made_by`). A text an imported
//! pin stands in for is edited in the pinned draft (edit.rs): `record` gives
//! that draft its words back and pins the new one, which then stands in. A
//! new revision goes into [`FILE`]; one a card brought is added to where it
//! stands, as an ID may be in one file only. [`list`] is a text's drafts as
//! its "Earlier drafts" shows them, with the greetings taken out of the card.

use std::collections::BTreeMap;

use anyhow::Context;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use toml::{Table, Value};
use toml_edit::{Array, DocumentMut, Item};
use ts_rs::TS;

use crate::Document;

/// The file this app writes revisions into.
pub const FILE: &str = "user/0001_revision.toml";

/// What made a draft, as `made` says it.
pub(crate) const IMPORTED: &str = "imported";
pub const EDITED: &str = "edited";
pub const RESTORED: &str = "restored";
pub const TRANSLATED: &str = "translated";

/// Whether an edit's drafts may be made by `made`: the user, an earlier draft
/// gone back to, or an AI tool, by its key ([`AiTool`]; Translate… as
/// [`TRANSLATED`]).
pub fn made_by(made: &str) -> bool {
    [EDITED, RESTORED, TRANSLATED].contains(&made)
        || serde_json::from_value::<AiTool>(made.into()).is_ok()
}

/// The AI tools of a text (`rewrite`); a draft one made is named by its key.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum AiTool {
    Improve,
    Fix,
    Shorter,
    Longer,
    /// Into the language in `given`.
    Translate,
    /// As `given` says.
    Ask,
}

/// One draft of a text, as "Earlier drafts" lists it.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct TextDraft {
    /// When it was saved, in milliseconds.
    pub saved: i64,
    /// What made it, as `made` says it.
    pub made: String,
    /// Its text as it is written.
    pub text: String,
}

/// A text's drafts, the newest first, the first of them the text as it is;
/// and, for a greeting, the newest words of each greeting taken out of the
/// card (that no greeting of it reads as now), the newest first.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct TextDrafts {
    pub drafts: Vec<TextDraft>,
    pub deleted: Vec<TextDraft>,
    /// The name of the file the card was imported from, which its imported drafts show; a card's alone.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[ts(optional)]
    pub file: Option<String>,
}

/// Every text block of a card as it reads (pins applied), by its reference.
fn texts(document: &Document) -> BTreeMap<String, &Table> {
    let mut texts = BTreeMap::new();
    for (kind, elements) in &document.root {
        if kind == "revision" || kind == "session" || kind == "user-state" {
            continue;
        }
        let Some(elements) = elements.as_table() else {
            continue;
        };
        for (id, element) in elements {
            if let Some(block) = element
                .as_table()
                .filter(|block| block.contains_key("text"))
            {
                texts.insert(format!("{kind}.{id}"), block);
            }
        }
    }
    texts
}

/// A moment as a draft's `saved`: to the millisecond, as edits can come within one second.
fn saved(at: i64) -> anyhow::Result<toml_edit::Value> {
    let moment = chrono::DateTime::from_timestamp_millis(at)
        .context(Fail::said(Code::Internal, "the clock tells no time"))?;
    let written = moment.format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
    Ok(toml_edit::Value::Datetime(toml_edit::Formatted::new(
        written.parse()?,
    )))
}

/// A block as a draft's `payload`.
fn payload(block: &Table) -> anyhow::Result<toml_edit::Value> {
    Ok(Value::Table(block.clone()).to_string().parse()?)
}

/// One draft as the array of a revision holds it.
fn draft(at: i64, made: &str, block: &Table, pinned: bool) -> anyhow::Result<toml_edit::Value> {
    let mut draft = toml_edit::InlineTable::new();
    draft.insert("saved", saved(at)?);
    if pinned {
        draft.insert("pinned", true.into());
    }
    draft.insert("made", made.into());
    draft.insert("payload", payload(block)?);
    let mut draft = toml_edit::Value::InlineTable(draft);
    draft.decor_mut().set_prefix("\n  ");
    Ok(draft)
}

/// Adds to `files`, a card's TOML files as (name, text), a draft of each text
/// block that `after` has and `before` had not, or had in other words, made by
/// `made` at `now`. A block with no drafts yet is first given one of how it
/// read in `before`, as imported at `since`. Without `before` (a card just
/// made) every block of `after` gets its first draft. A file is written anew
/// only where a draft is added to it.
pub fn record(
    files: &mut Vec<(String, String)>,
    before: Option<&Document>,
    after: &Document,
    made: &str,
    now: i64,
    since: i64,
) -> anyhow::Result<()> {
    let had = before.map(texts).unwrap_or_default();
    let now_texts = texts(after);
    // Per block: its new drafts, and the pinned draft to be given back its words.
    type Added = (
        String,
        Vec<toml_edit::Value>,
        Option<(usize, toml_edit::Value)>,
    );
    let mut added: Vec<Added> = Vec::new();
    for (reference, block) in &now_texts {
        let old = had.get(reference);
        // A change of a block's modes alone is no new wording: "Earlier drafts" would show none.
        if old.is_some_and(|old| same_words(old, block)) {
            continue;
        }
        // Words the history already ends in (given it by `adopt`) are no new draft.
        if newest(after, reference).is_some_and(|newest| same_words(newest, block)) {
            continue;
        }
        if let (Some(old), Some(pin)) = (old, after.pin(reference)) {
            let back = Some((pin, payload(old)?));
            added.push((
                reference.clone(),
                vec![draft(now, made, block, true)?],
                back,
            ));
            continue;
        }
        let mut drafts = Vec::new();
        if let Some(old) = old
            && !newest(after, reference).is_some_and(|newest| same_words(newest, old))
        {
            drafts.push(draft(since, IMPORTED, old, false)?);
        }
        drafts.push(draft(now, made, block, false)?);
        added.push((reference.clone(), drafts, None));
    }
    // A block taken out keeps its words in its drafts.
    for (reference, old) in &had {
        if !now_texts.contains_key(reference)
            && !newest(after, reference).is_some_and(|newest| same_words(newest, old))
        {
            added.push((
                reference.clone(),
                vec![draft(since, IMPORTED, old, false)?],
                None,
            ));
        }
    }
    if added.is_empty() {
        return Ok(());
    }
    let mut open = revision_files(files);
    let mut changed = vec![false; files.len()];
    for (reference, drafts, back) in added {
        let file = slot(files, &mut open, &mut changed, &reference)?;
        let list = drafts_of(file, &reference).with_context(|| {
            Fail::said(
                Code::Internal,
                format!("the drafts of {reference} cannot be added to"),
            )
        })?;
        if let Some((pin, words)) = back {
            list.get_mut(pin)
                .and_then(toml_edit::Value::as_inline_table_mut)
                .with_context(|| {
                    Fail::said(
                        Code::Internal,
                        format!("the pinned draft of {reference} cannot be changed"),
                    )
                })?
                .insert("payload", words);
        }
        for draft in drafts {
            list.push_formatted(draft);
        }
        list.set_trailing("\n");
    }
    write_back(files, open, &changed);
    Ok(())
}

/// The file of `files` that `reference`'s revision goes into, opened and
/// marked as changed: the one that holds it, else [`FILE`], made where the
/// card has none.
fn slot<'a>(
    files: &mut Vec<(String, String)>,
    open: &'a mut Vec<Option<DocumentMut>>,
    changed: &mut Vec<bool>,
    reference: &str,
) -> anyhow::Result<&'a mut DocumentMut> {
    let at = open
        .iter()
        .position(|file| file.as_ref().is_some_and(|file| holds(file, reference)))
        .or_else(|| files.iter().position(|(name, _)| name == FILE));
    let at = match at {
        Some(at) => at,
        None => {
            files.push((FILE.to_string(), String::new()));
            open.push(None);
            changed.push(false);
            files.len() - 1
        }
    };
    if open[at].is_none() {
        open[at] = Some(files[at].1.parse().with_context(|| {
            Fail::said(
                Code::NotReadable,
                format!("{} is not valid TOML", files[at].0),
            )
            .with("what", "toml")
        })?);
    }
    changed[at] = true;
    // Opened just above where it was not.
    Ok(open[at].as_mut().expect("opened above"))
}

/// Gives the blocks `references` of a card's `files` the drafts `from` has
/// of them, in place of those the card kept: a lorebook moved back into its
/// card brings the history it gathered in the library. A block `from` has no
/// drafts of keeps the card's.
pub(crate) fn adopt(
    files: &mut Vec<(String, String)>,
    from: &Document,
    references: &[String],
) -> anyhow::Result<()> {
    let Some(theirs) = from.root.get("revision").and_then(Value::as_table) else {
        return Ok(());
    };
    let mut open = revision_files(files);
    let mut changed = vec![false; files.len()];
    for reference in references {
        let Some(drafts) = theirs
            .get(reference)
            .and_then(|revision| revision.get("drafts"))
            .and_then(Value::as_array)
        else {
            continue;
        };
        let file = slot(files, &mut open, &mut changed, reference)?;
        let list = drafts_of(file, reference).with_context(|| {
            Fail::said(
                Code::Internal,
                format!("the drafts of {reference} cannot be added to"),
            )
        })?;
        list.clear();
        for one in drafts {
            let mut one: toml_edit::Value = one.to_string().parse()?;
            one.decor_mut().set_prefix(
                "
  ",
            );
            list.push_formatted(one);
        }
        list.set_trailing(
            "
",
        );
    }
    write_back(files, open, &changed);
    Ok(())
}

/// The `user/` files of `files` that hold revisions, each parsed once; None for any other.
fn revision_files(files: &[(String, String)]) -> Vec<Option<DocumentMut>> {
    files
        .iter()
        .map(|(name, text)| {
            (name.starts_with("user/") && text.contains("revision"))
                .then(|| text.parse().ok())
                .flatten()
        })
        .collect()
}

/// Writes into `files` each of `open` that was `changed`.
fn write_back(files: &mut [(String, String)], open: Vec<Option<DocumentMut>>, changed: &[bool]) {
    for ((file, written), changed) in files.iter_mut().zip(open).zip(changed) {
        if let (Some(written), true) = (written, changed) {
            file.1 = written.to_string();
        }
    }
}

/// Whether two blocks read the same, whatever else (their modes) differs.
fn same_words(one: &Table, other: &Table) -> bool {
    one.get("text") == other.get("text")
}

/// The drafts of the block `reference`, as one of them reads.
fn drafts_listed(document: &Document, reference: &str) -> Vec<TextDraft> {
    let Some(drafts) = document
        .root
        .get("revision")
        .and_then(|all| all.get(reference))
        .and_then(|revision| revision.get("drafts"))
        .and_then(Value::as_array)
    else {
        return Vec::new();
    };
    let mut listed: Vec<TextDraft> = drafts
        .iter()
        .filter_map(|draft| {
            Some(TextDraft {
                saved: crate::saved_at(draft.get("saved")),
                made: draft
                    .get("made")
                    .and_then(Value::as_str)
                    .unwrap_or(IMPORTED)
                    .to_string(),
                text: crate::plain(draft.get("payload")?.get("text")?.as_str()?),
            })
        })
        .collect();
    // Newest first; of two saved alike, the later in the list.
    listed.reverse();
    listed.sort_by_key(|draft| std::cmp::Reverse(draft.saved));
    listed
}

/// The drafts of the text `reference` of `document` (see [`TextDrafts`]). A
/// text whose newest draft is not how it reads (an imported text never
/// changed) has it first, as imported at `since`.
pub fn list(document: &Document, reference: &str, since: i64) -> TextDrafts {
    let all = texts(document);
    let words =
        |block: &Table| crate::plain(block.get("text").and_then(Value::as_str).unwrap_or(""));
    let mut drafts = drafts_listed(document, reference);
    if let Some(block) = all.get(reference)
        && drafts
            .first()
            .is_none_or(|newest| newest.text != words(block))
    {
        drafts.insert(
            0,
            TextDraft {
                saved: since,
                made: IMPORTED.to_string(),
                text: words(block),
            },
        );
    }
    let mut deleted = Vec::new();
    if reference.starts_with("greeting.") {
        let greetings: Vec<String> = all
            .iter()
            .filter(|(key, _)| key.starts_with("greeting."))
            .map(|(_, block)| words(block))
            .collect();
        let gone = document.root.get("revision").and_then(Value::as_table);
        for key in gone.into_iter().flat_map(|gone| gone.keys()) {
            if !key.starts_with("greeting.") || all.contains_key(key) {
                continue;
            }
            if let Some(last) = drafts_listed(document, key).into_iter().next()
                && !last.text.is_empty()
                && !greetings.contains(&last.text)
            {
                deleted.push(last);
            }
        }
        deleted.sort_by_key(|draft| std::cmp::Reverse(draft.saved));
    }
    TextDrafts {
        drafts,
        deleted,
        file: None,
    }
}

/// The newest draft of the block `reference` (by `saved`, the later of two alike; drafts may stand in any
/// order), if it has one.
fn newest<'a>(document: &'a Document, reference: &str) -> Option<&'a Table> {
    document
        .root
        .get("revision")?
        .get(reference)?
        .get("drafts")?
        .as_array()?
        .iter()
        .max_by_key(|draft| crate::saved_at(draft.get("saved")))?
        .get("payload")?
        .as_table()
}

/// The draft of `reference` at `at` in `document`, as its `payload`.
fn payload_at<'a>(document: &'a Document, reference: &str, at: usize) -> Option<&'a Table> {
    document
        .root
        .get("revision")?
        .get(reference)?
        .get("drafts")?
        .get(at)?
        .get("payload")?
        .as_table()
}

/// Gives each pinned draft in `files` the words it has in `from`, the same card's files as a later version of
/// an older build had them: that build edited a text a pin stands in for in the pinned draft.
pub fn take_pins(files: &mut [(String, String)], from: &Document) -> anyhow::Result<()> {
    let Some(revisions) = from.root.get("revision").and_then(Value::as_table) else {
        return Ok(());
    };
    let had = Document::parse(files)?;
    let mut open = revision_files(files);
    let mut changed = vec![false; files.len()];
    for reference in revisions.keys() {
        let Some(at) = from.pin(reference) else {
            continue;
        };
        let Some(words) = payload_at(from, reference, at) else {
            continue;
        };
        if payload_at(&had, reference, at) == Some(words) {
            continue;
        }
        let Some(file) = open
            .iter()
            .position(|file| file.as_ref().is_some_and(|file| holds(file, reference)))
        else {
            continue;
        };
        changed[file] = true;
        // `position` found it holding a file just above.
        let written = open[file].as_mut().expect("found above");
        drafts_of(written, reference)
            .and_then(|list| list.get_mut(at))
            .and_then(toml_edit::Value::as_inline_table_mut)
            .with_context(|| {
                Fail::said(
                    Code::Internal,
                    format!("the pinned draft of {reference} cannot be changed"),
                )
            })?
            .insert("payload", payload(words)?);
    }
    write_back(files, open, &changed);
    Ok(())
}

/// Whether `file` holds the revision of `reference`.
fn holds(file: &DocumentMut, reference: &str) -> bool {
    file.get("revision")
        .and_then(|all| all.get(reference))
        .is_some()
}

/// The list of drafts of `reference` in `file`, made where it has none.
fn drafts_of<'a>(file: &'a mut DocumentMut, reference: &str) -> Option<&'a mut Array> {
    let all = file
        .entry("revision")
        .or_insert_with(|| {
            let mut table = toml_edit::Table::new();
            table.set_implicit(true);
            Item::Table(table)
        })
        .as_table_like_mut()?;
    let revision = all
        .entry(reference)
        .or_insert_with(|| Item::Table(toml_edit::Table::new()))
        .as_table_like_mut()?;
    revision
        .entry("drafts")
        .or_insert_with(|| Item::Value(toml_edit::Value::Array(Array::new())))
        .as_array_mut()
}

/// The history of a card alone, as one `user/` file: every revision it has,
/// for a card exported with its texts' history. None where it has none.
pub fn only_history(document: &Document) -> anyhow::Result<Option<(String, String)>> {
    let Some(revisions) = document.root.get("revision").and_then(Value::as_table) else {
        return Ok(None);
    };
    if revisions.is_empty() {
        return Ok(None);
    }
    let mut file = Table::new();
    file.insert("revision".into(), Value::Table(revisions.clone()));
    Ok(Some((FILE.to_string(), toml::to_string(&file)?)))
}

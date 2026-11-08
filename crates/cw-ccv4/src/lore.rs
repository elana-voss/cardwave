//! A lorebook as its editor shows it ([`entries`]), and an edit written back
//! into its files: an entry changed ([`change`]), added ([`add`]), taken out
//! ([`remove`]) and put back ([`restore`]), and the lorebook's name and
//! description ([`describe`]); [`empty`] is the file of a lorebook made from
//! scratch. The files are a library lorebook's one text split by [`files_of`]
//! (its entries' history apart, joined again by [`joined`]) or a card's, with
//! the lorebook named (`lorebook.ID`); a block is changed in the file that has
//! it. Moving a card's own into the library and back is `moving.rs`.
//!
//! An edit is made in the files as they are written, with `toml_edit` through
//! `set`, `set_list` and `find` of `edit.rs`. Only a key whose value differs
//! from what the entry reads as is written, and every key the editor does not
//! show (`priority`, `sticky`, `role`, …) stays; a key that would say what
//! holds without it (`enabled = true`, a probability of 100) is taken out.
//! Every function answers with the files and the document they read as, after
//! it has checked that the entry reads as it was asked.
//!
//! [`EditEntry`] is an entry read as the prompt reads it (`mapping::lore_entry`);
//! its secondary keywords are those that count (`selective`), and `scan_depth`
//! is 0 where the lorebook's own counts. An entry taken out is answered as
//! [`RemovedEntry`], all that puts it back; a new entry's ID is its lorebook's
//! with its name, never one in use, listed, with a history kept or `taken`.

use anyhow::{Context, ensure};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_prompt::{DEFAULT_DEPTH, SelectiveLogic};
use serde::{Deserialize, Serialize};
use toml::{Table, Value};
use toml_edit::{DocumentMut, Item, TableLike};
use ts_rs::TS;

use crate::edit::{find, set, set_list};
use crate::mapping::{self, lore_name};
use crate::{Document, drafts, free_id, one_line, plain, slug_or, split_reference, strings};

mod moving;
pub use moving::*;

/// The one TOML file a lorebook's document consists of.
const FILE: &str = "card/0001_lorebook.toml";
/// How many letters an entry's name may have.
const MAX_NAME: usize = 64;
/// The order a new entry has, as an entry from SillyTavern that names none.
const NEW_ORDER: i32 = 100;

/// How an entry comes to be used (section 3.3.2, `trigger`).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Trigger {
    /// When one of its keywords is in the newest messages.
    #[default]
    Keyword,
    /// In every reply.
    Always,
    /// When the newest messages are about the same thing. Until the app has a
    /// search model, such an entry goes by its keywords.
    Vector,
}

/// What the secondary keywords ask for, as a `lore` block writes it; `None`
/// for what holds without a key.
fn written(logic: SelectiveLogic) -> Option<&'static str> {
    match logic {
        SelectiveLogic::AndAny => None,
        SelectiveLogic::AndAll => Some("and-all"),
        SelectiveLogic::NotAny => Some("not-any"),
        SelectiveLogic::NotAll => Some("not-all"),
    }
}

/// One entry of a lorebook, as its editor shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct EditEntry {
    /// The block it is, `lore.ID`.
    pub reference: String,
    /// What the lists call it: its name, else its first keyword, else its ID.
    pub label: String,
    /// Its name as written; empty where it has none.
    pub name: String,
    pub trigger: Trigger,
    pub keywords: Vec<String>,
    /// What the model is told when the entry is used.
    pub content: String,
    pub enabled: bool,
    /// It goes into the chat, `depth` messages before its end, and not to the
    /// lorebook's place in the prompt.
    pub at_depth: bool,
    pub depth: u32,
    /// Its place among the entries used together: a higher one stands later.
    pub order: i32,
    /// The secondary keywords that count.
    pub secondary: Vec<String>,
    /// What the secondary keywords ask for, beside a keyword that matched.
    pub logic: SelectiveLogic,
    /// The chance in percent that the entry is used when it applies.
    pub probability: u32,
    /// How many of the newest messages are read for its keywords; 0 where the
    /// lorebook's own number counts.
    pub scan_depth: u32,
    pub case_sensitive: bool,
    pub whole_words: bool,
}

/// What is changed of an entry; what is left out stays as it is. For a new
/// entry it is what the entry begins with.
#[derive(Clone, Debug, Default, Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct EntryChange {
    pub name: Option<String>,
    pub trigger: Option<Trigger>,
    pub keywords: Option<Vec<String>>,
    pub content: Option<String>,
    pub enabled: Option<bool>,
    pub at_depth: Option<bool>,
    pub depth: Option<u32>,
    pub order: Option<i32>,
    pub secondary: Option<Vec<String>>,
    pub logic: Option<SelectiveLogic>,
    pub probability: Option<u32>,
    pub scan_depth: Option<u32>,
    pub case_sensitive: Option<bool>,
    pub whole_words: Option<bool>,
}

/// An entry that was taken out of its lorebook: all that puts it back.
#[derive(Clone, Debug, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct RemovedEntry {
    /// The block as it was written, a TOML file of its own.
    pub toml: String,
    /// Where it stood among the lorebook's entries, from 0.
    pub position: u32,
}

/// A lorebook's files after an edit, with the document they read as.
pub struct Rewritten {
    pub files: Vec<(String, String)>,
    pub document: Document,
}

/// Reads a lorebook's one file.
pub fn parse(toml: &str) -> anyhow::Result<Document> {
    Document::parse(&[(FILE.to_string(), toml.to_string())])
}

/// The lorebook of a library document: its first, which by the way such a
/// document is made is its only one.
pub fn book(document: &Document) -> Option<String> {
    document
        .ids("lorebook")
        .first()
        .map(|id| format!("lorebook.{id}"))
}

/// Keywords as they are kept: each without the space around it and once, none empty.
fn tidy(keywords: Vec<String>) -> Vec<String> {
    let mut kept: Vec<String> = Vec::new();
    for keyword in keywords {
        let keyword = keyword.trim();
        if !keyword.is_empty() && !kept.iter().any(|other| other == keyword) {
            kept.push(keyword.to_string());
        }
    }
    kept
}

impl EditEntry {
    /// The block `reference` of `document` as the editor shows it; one that is
    /// not there reads as an entry that says nothing.
    fn of(document: &Document, reference: &str) -> Self {
        let none = Table::new();
        let lore = document.lookup(reference).unwrap_or(&none);
        Self::read(reference, lore_name(document, reference), lore)
    }

    /// An entry that is not written yet: what its block would read as, but
    /// for its order. It is what the editor begins a new entry with.
    pub fn blank() -> Self {
        Self {
            order: NEW_ORDER,
            ..Self::read("", String::new(), &Table::new())
        }
    }

    /// The block `lore` as the editor shows it, under its `reference` and
    /// `label`: what the prompt reads of it (`mapping::lore_entry`), so the
    /// editor shows what a chat goes by.
    fn read(reference: &str, label: String, lore: &Table) -> Self {
        let read = mapping::lore_entry(reference.to_string(), lore);
        let said = |key: &str| lore.get(key).and_then(Value::as_str);
        let secondary = if read.selective {
            read.secondary_keys
        } else {
            Vec::new()
        };
        Self {
            reference: reference.to_string(),
            label,
            name: said("name").unwrap_or("").to_string(),
            trigger: match said("trigger") {
                Some("always") => Trigger::Always,
                Some("vector") => Trigger::Vector,
                _ => Trigger::Keyword,
            },
            keywords: read.keys,
            content: plain(&read.content),
            enabled: read.enabled,
            at_depth: read.at_depth,
            depth: read.depth as u32,
            order: read.insertion_order.clamp(i32::MIN.into(), i32::MAX.into()) as i32,
            // Without secondary keywords there is nothing the choice is about.
            logic: if secondary.is_empty() {
                SelectiveLogic::AndAny
            } else {
                read.selective_logic
            },
            secondary,
            probability: read.probability,
            scan_depth: read.scan_depth.unwrap_or(0) as u32,
            case_sensitive: read.case_sensitive,
            whole_words: read.match_whole_words,
        }
    }

    /// The entry with `change` made, as it is kept. Refused: a name that is too
    /// long, and a chance of more than 100 percent.
    fn with(&self, change: &EntryChange) -> anyhow::Result<Self> {
        let change = change.clone();
        let mut after = self.clone();
        if let Some(name) = change.name {
            after.name = one_line(&name);
        }
        ensure!(
            after.name.chars().count() <= MAX_NAME || after.name == self.name,
            Fail::said(
                Code::TooLong,
                format!("an entry's name has at most {MAX_NAME} characters")
            )
            .with("what", "entry_name")
            .with("max_name", MAX_NAME)
        );
        after.trigger = change.trigger.unwrap_or(after.trigger);
        if let Some(keywords) = change.keywords {
            after.keywords = tidy(keywords);
        }
        if let Some(content) = change.content {
            after.content = plain(&content);
        }
        after.enabled = change.enabled.unwrap_or(after.enabled);
        after.at_depth = change.at_depth.unwrap_or(after.at_depth);
        after.depth = change.depth.unwrap_or(after.depth);
        if !after.at_depth {
            after.depth = DEFAULT_DEPTH as u32;
        }
        after.order = change.order.unwrap_or(after.order);
        if let Some(secondary) = change.secondary {
            after.secondary = tidy(secondary);
        }
        after.logic = change.logic.unwrap_or(after.logic);
        // Without secondary keywords there is nothing the choice is about.
        if after.secondary.is_empty() {
            after.logic = SelectiveLogic::AndAny;
        }
        after.probability = change.probability.unwrap_or(after.probability);
        ensure!(
            after.probability <= 100,
            Fail::said(Code::OutOfRange, "an entry's chance is at most 100 percent")
                .with("what", "entry_chance")
        );
        after.scan_depth = change.scan_depth.unwrap_or(after.scan_depth);
        after.case_sensitive = change.case_sensitive.unwrap_or(after.case_sensitive);
        after.whole_words = change.whole_words.unwrap_or(after.whole_words);
        Ok(after)
    }
}

/// Gives the key `key` of `block` the value `new`, or takes the key out where
/// there is none: what the block says then holds without it.
fn put(block: &mut dyn TableLike, key: &str, new: Option<toml_edit::Value>) {
    match new {
        Some(new) => set(block, key, new),
        None => _ = block.remove(key),
    }
}

/// Lets a block stand where it is put: neither it nor a table under it keeps
/// the place it had in the file it was read from, which would part them.
fn unplace(block: &mut toml_edit::Table) {
    block.set_position(None);
    for (_, under) in block.iter_mut() {
        match under {
            Item::Table(under) => unplace(under),
            Item::ArrayOfTables(several) => several.iter_mut().for_each(unplace),
            _ => {}
        }
    }
}

/// Writes into `block` what `after` says otherwise than `before`; all of it
/// where there is no `before`, for a block that is new.
fn write(block: &mut dyn TableLike, before: Option<&EditEntry>, after: &EditEntry) {
    let all = before.is_none();
    let old = before.unwrap_or(after);
    let on = |flag: bool| flag.then(|| true.into());
    if all || old.name != after.name {
        let name = Some(after.name.as_str()).filter(|name| !name.is_empty());
        put(block, "name", name.map(Into::into));
    }
    if all || old.keywords != after.keywords {
        set_list(block, "keywords", &after.keywords);
    }
    if all || old.secondary != after.secondary || old.logic != after.logic {
        if after.secondary.is_empty() {
            block.remove("secondary-keywords");
        } else {
            set_list(block, "secondary-keywords", &after.secondary);
        }
        put(block, "selective", on(!after.secondary.is_empty()));
        put(
            block,
            "selective-logic",
            written(after.logic).map(Into::into),
        );
    }
    if all || old.case_sensitive != after.case_sensitive {
        put(block, "case-sensitive", on(after.case_sensitive));
    }
    if all || old.whole_words != after.whole_words {
        put(block, "match-whole-words", on(after.whole_words));
    }
    if all || old.trigger != after.trigger {
        let trigger = match after.trigger {
            Trigger::Keyword => None,
            Trigger::Always => Some("always"),
            Trigger::Vector => Some("vector"),
        };
        put(block, "trigger", trigger.map(Into::into));
    }
    if all || old.enabled != after.enabled {
        put(block, "enabled", (!after.enabled).then(|| false.into()));
    }
    if all || old.order != after.order {
        set(block, "insertion-order", i64::from(after.order));
    }
    if all || old.probability != after.probability {
        let percent = Some(i64::from(after.probability)).filter(|percent| *percent < 100);
        put(block, "probability", percent.map(Into::into));
    }
    if all || old.scan_depth != after.scan_depth {
        let depth = Some(i64::from(after.scan_depth)).filter(|depth| *depth > 0);
        put(block, "scan-depth", depth.map(Into::into));
    }
    if all || old.at_depth != after.at_depth || old.depth != after.depth {
        let depth = after.at_depth.then(|| i64::from(after.depth));
        put(block, "depth", depth.map(Into::into));
    }
    if all || old.content != after.content {
        set(block, "text", after.content.as_str());
    }
}

/// A lorebook's files, open for an edit: a library lorebook's (`files_of`) or
/// a card's. A block is changed in the one file that has it; a new entry goes
/// into the file of the lorebook's own block.
struct Open {
    /// Each file's name, and its text as it was given.
    names: Vec<String>,
    given: Vec<String>,
    files: Vec<DocumentMut>,
    /// How each file is written when nothing was changed in it.
    untouched: Vec<String>,
    /// What the files read as when they were opened.
    document: Document,
    /// The lorebook, `lorebook.ID`, and its ID.
    book: String,
    id: String,
    /// The entries it lists, as they are written: one that names no block is among them.
    listed: Vec<String>,
}

impl Open {
    fn of(files: &[(String, String)], book: &str) -> anyhow::Result<Self> {
        let document = Document::parse(files)?;
        let id = split_reference(book)
            .filter(|(kind, _)| *kind == "lorebook" && document.lookup(book).is_some())
            .ok_or(NotFound("lorebook"))?
            .1
            .to_string();
        let mut opened = Vec::new();
        for (name, text) in files {
            let file: DocumentMut = text.parse().with_context(|| {
                Fail::said(Code::NotReadable, format!("{name} is not valid TOML"))
                    .with("what", "toml")
                    .with("name", name.to_string())
            })?;
            opened.push(file);
        }
        let listed = strings(document.lookup(book).and_then(|book| book.get("entries")));
        let listed = listed.into_iter().map(str::to_string).collect();
        Ok(Self {
            names: files.iter().map(|(name, _)| name.clone()).collect(),
            given: files.iter().map(|(_, text)| text.clone()).collect(),
            untouched: opened.iter().map(DocumentMut::to_string).collect(),
            files: opened,
            document,
            book: book.to_string(),
            id,
            listed,
        })
    }

    /// What stands under `keys` in the one file that has it.
    fn at(&mut self, keys: &[&str]) -> Option<&mut Item> {
        self.files
            .iter_mut()
            .find_map(|file| find(file.as_item_mut(), keys))
    }

    /// Whether the ID `id` is an entry's: a block's, one in the lorebook's
    /// list, or one whose history is kept.
    fn has(&self, id: &str) -> bool {
        let block = self.files.iter().any(|file| {
            let blocks = file.get("lore");
            blocks.and_then(|all| all.get(id)).is_some()
        });
        let reference = format!("lore.{id}");
        block || self.listed.contains(&reference) || self.document.has_revision(&reference)
    }

    /// The lorebook's own table, to be changed.
    fn lorebook(&mut self) -> anyhow::Result<&mut dyn TableLike> {
        let id = self.id.clone();
        self.at(&["lorebook", &id])
            .and_then(Item::as_table_like_mut)
            .context(
                Fail::said(Code::NotPossible, "this lorebook cannot be changed")
                    .with("what", "lorebook_change"),
            )
    }

    /// The table of the entry `id`, to be changed.
    fn lore(&mut self, id: &str) -> anyhow::Result<&mut dyn TableLike> {
        self.at(&["lore", id])
            .and_then(Item::as_table_like_mut)
            .with_context(|| {
                Fail::said(
                    Code::NotPossible,
                    format!("lore.{id} cannot be changed in this lorebook"),
                )
                .with("what", "entry_change")
                .with("id", id.to_string())
            })
    }

    /// The ID of the entry `reference`, if the lorebook lists it and has it.
    fn entry<'a>(&self, reference: &'a str) -> anyhow::Result<&'a str> {
        let listed = mapping::entries(&self.document, &self.book).contains(&reference);
        let id = split_reference(reference).filter(|(kind, _)| listed && *kind == "lore");
        Ok(id.ok_or(NotFound("lorebook entry"))?.1)
    }

    /// The table that holds the entries' blocks, each under a header of its
    /// own, in the file of the lorebook's block.
    fn blocks(&mut self) -> anyhow::Result<&mut dyn TableLike> {
        let id = self.id.clone();
        let home = self.files.iter_mut().find(|file| {
            let books = file.get("lorebook");
            books.and_then(|all| all.get(&id)).is_some()
        });
        let home = home.context(
            Fail::said(Code::NotPossible, "this lorebook takes no new entry")
                .with("what", "lorebook_new_entry"),
        )?;
        let blocks = home.entry("lore").or_insert_with(|| {
            let mut blocks = toml_edit::Table::new();
            blocks.set_implicit(true);
            Item::Table(blocks)
        });
        blocks.as_table_like_mut().context(
            Fail::said(Code::NotPossible, "this lorebook takes no new entry")
                .with("what", "lorebook_new_entry"),
        )
    }

    /// Takes the block of the entry `id` out of the file that has it.
    fn take(&mut self, id: &str) -> Option<toml_edit::Table> {
        self.files.iter_mut().find_map(|file| {
            let blocks = file.get_mut("lore")?.as_table_like_mut()?;
            blocks.remove(id)?.into_table().ok()
        })
    }

    /// Gives the lorebook the list of entries `listed`.
    fn list(&mut self, listed: &[String]) -> anyhow::Result<()> {
        set_list(self.lorebook()?, "entries", listed);
        Ok(())
    }

    /// The files as they are now, read anew; one the edit did not change as it was given.
    fn finish(self) -> anyhow::Result<Rewritten> {
        let mut files = Vec::new();
        let opened = self.files.into_iter().zip(self.untouched);
        for ((name, given), (file, untouched)) in self.names.into_iter().zip(self.given).zip(opened)
        {
            let written = file.to_string();
            files.push((name, if written == untouched { given } else { written }));
        }
        let document = Document::parse(&files).context(
            Fail::said(
                Code::NotPossible,
                "the lorebook would not read after this change",
            )
            .with("what", "lorebook_change_breaks"),
        )?;
        Ok(Rewritten { files, document })
    }

    /// The files as they are now, read anew, with the entry `expected` as it
    /// reads there, which has to be as `expected` says: an edit that the files
    /// do not take as asked is refused.
    fn finish_as(self, expected: &EditEntry) -> anyhow::Result<(Rewritten, EditEntry)> {
        let book = self.book.clone();
        let rewritten = self.finish()?;
        let read = EditEntry::of(&rewritten.document, &expected.reference);
        let listed = mapping::entries(&rewritten.document, &book);
        let asked = EditEntry {
            label: read.label.clone(),
            ..expected.clone()
        };
        ensure!(
            read == asked && listed.contains(&expected.reference.as_str()),
            Fail::said(
                Code::NotPossible,
                format!(
                    "the entry {} cannot be changed as asked in this lorebook",
                    expected.reference
                )
            )
            .with("what", "entry_change")
            .with("reference", (expected.reference).to_string())
        );
        Ok((rewritten, read))
    }
}

/// A library lorebook's one text as the files an edit is made in: the
/// lorebook, and its entries' history (`revision`) in `drafts::FILE` where it
/// has any, which is where `drafts::record` adds to it.
pub fn files_of(toml: &str) -> anyhow::Result<Vec<(String, String)>> {
    let mut file: DocumentMut = toml.parse().context(
        Fail::said(Code::NotReadable, "the lorebook cannot be read").with("what", "lorebook_file"),
    )?;
    let Some(history) = file.remove("revision") else {
        return Ok(vec![(FILE.to_string(), toml.to_string())]);
    };
    let mut kept = DocumentMut::new();
    kept.insert("revision", history);
    Ok(vec![
        (FILE.to_string(), file.to_string()),
        (drafts::FILE.to_string(), kept.to_string()),
    ])
}

/// The files of a library lorebook (`files_of`) as its one text again.
pub fn joined(files: &[(String, String)]) -> String {
    let texts: Vec<&str> = files.iter().map(|(_, text)| text.trim_end()).collect();
    let texts: Vec<&str> = texts.into_iter().filter(|text| !text.is_empty()).collect();
    format!("{}\n", texts.join("\n\n"))
}

/// What the lorebook `book` of `document` says of itself, as a field holds it.
pub fn description(document: &Document, book: &str) -> String {
    let said = document
        .lookup(book)
        .and_then(|book| book.get("description")?.as_str());
    plain(said.unwrap_or(""))
}

/// The number `key` of the lorebook `book` of `document` (`scan-depth`,
/// `token-budget`), where it has one above 0.
pub fn book_number(document: &Document, book: &str, key: &str) -> Option<u32> {
    let said = document.lookup(book)?.get(key)?.as_integer()?;
    u32::try_from(said).ok().filter(|n| *n > 0)
}

/// The entries of the lorebook `book` of `document`, as its editor shows them.
pub fn entries(document: &Document, book: &str) -> Vec<EditEntry> {
    let listed = mapping::entries(document, book).into_iter();
    listed
        .map(|reference| EditEntry::of(document, reference))
        .collect()
}

/// Makes `change` to the entry `reference` of the lorebook `book` in `files`.
/// No files where the entry reads so already: they stay as they are. Answers
/// with the entry as it reads then.
pub fn change(
    files: &[(String, String)],
    book: &str,
    reference: &str,
    change: &EntryChange,
) -> anyhow::Result<(Option<Rewritten>, EditEntry)> {
    let mut open = Open::of(files, book)?;
    let id = open.entry(reference)?;
    let before = EditEntry::of(&open.document, reference);
    let after = before.with(change)?;
    if after == before {
        return Ok((None, before));
    }
    write(open.lore(id)?, Some(&before), &after);
    let (rewritten, entry) = open.finish_as(&after)?;
    Ok((Some(rewritten), entry))
}

/// Adds an entry that begins with `change` to the lorebook `book` in `files`,
/// as its last. Its ID is the lorebook's with its name, with a number behind
/// it where that is an entry's already (or was, and has its history kept) or
/// `taken` says so of its reference. Refused: an entry without a name.
/// Answers with the entry too.
pub fn add(
    files: &[(String, String)],
    book: &str,
    change: &EntryChange,
    taken: impl Fn(&str) -> bool,
) -> anyhow::Result<(Rewritten, EditEntry)> {
    let mut open = Open::of(files, book)?;
    let mut after = EditEntry::blank().with(change)?;
    ensure!(
        !after.name.is_empty(),
        Fail::said(Code::Needed, "an entry needs a name").with("what", "entry_name")
    );
    let named = format!("{}-{}", open.id, slug_or(&after.name, "entry"));
    let id = free_id(&named, |id| open.has(id) || taken(&format!("lore.{id}")));
    after.reference = format!("lore.{id}");
    let mut block = toml_edit::Table::new();
    write(&mut block, None, &after);
    open.blocks()?.insert(&id, Item::Table(block));
    let mut listed = open.listed.clone();
    listed.push(after.reference.clone());
    open.list(&listed)?;
    open.finish_as(&after)
}

/// Takes the entry `reference` out of the lorebook `book` in `files`: its
/// block, and its line in the lorebook's list. Answers with what puts it back.
pub fn remove(
    files: &[(String, String)],
    book: &str,
    reference: &str,
) -> anyhow::Result<(Rewritten, RemovedEntry)> {
    let mut open = Open::of(files, book)?;
    let id = open.entry(reference)?;
    let block = open.take(id).ok_or(NotFound("lorebook entry"))?;
    let mut blocks = toml_edit::Table::new();
    blocks.set_implicit(true);
    blocks.insert(id, Item::Table(block));
    let mut alone = DocumentMut::new();
    alone.insert("lore", Item::Table(blocks));
    let position = open.listed.iter().position(|entry| entry == reference);
    let listed = open.listed.iter().filter(|entry| *entry != reference);
    let listed: Vec<String> = listed.cloned().collect();
    open.list(&listed)?;
    let removed = RemovedEntry {
        toml: alone.to_string(),
        position: position.unwrap_or(0) as u32,
    };
    Ok((open.finish()?, removed))
}

/// Puts an entry that was taken out back into the lorebook `book` in `files`,
/// at its place among the entries, or as the last where there are fewer now.
/// Refused: what is no entry's block, and an entry whose ID is another's by
/// now. Answers with the entry too.
pub fn restore(
    files: &[(String, String)],
    book: &str,
    removed: &RemovedEntry,
) -> anyhow::Result<(Rewritten, EditEntry)> {
    const NO_ENTRY: &str = "this is no lorebook entry that was taken out";
    let mut open = Open::of(files, book)?;
    let alone: DocumentMut = removed
        .toml
        .parse()
        .context(Fail::said(Code::NotPossible, NO_ENTRY).with("what", "entry_taken_out"))?;
    let blocks = alone.get("lore").and_then(Item::as_table_like);
    let mut blocks = blocks
        .context(Fail::said(Code::NotPossible, NO_ENTRY).with("what", "entry_taken_out"))?
        .iter();
    let (Some((id, block)), None, 1) = (blocks.next(), blocks.next(), alone.len()) else {
        anyhow::bail!(Fail::said(Code::NotPossible, NO_ENTRY).with("what", "entry_taken_out"));
    };
    let mut block = block
        .clone()
        .into_table()
        .ok()
        .context(Fail::said(Code::NotPossible, NO_ENTRY).with("what", "entry_taken_out"))?;
    let reference = format!("lore.{id}");
    let elsewhere = open.files.iter().any(|file| {
        let blocks = file.get("lore");
        blocks.and_then(|all| all.get(id)).is_some()
    });
    ensure!(
        !elsewhere && !open.listed.contains(&reference),
        Fail::said(
            Code::Changed,
            format!("the lorebook has another entry {reference} by now")
        )
        .with("what", "lorebook_entry")
        .with("reference", reference.to_string())
    );
    unplace(&mut block);
    open.blocks()?.insert(id, Item::Table(block));
    let mut listed = open.listed.clone();
    listed.insert(
        (removed.position as usize).min(listed.len()),
        reference.clone(),
    );
    open.list(&listed)?;
    let book = open.book.clone();
    let rewritten = open.finish()?;
    // A block without an ID would stand in the file and in the list, and be
    // no entry of the lorebook.
    ensure!(
        mapping::entries(&rewritten.document, &book).contains(&reference.as_str()),
        Fail::said(Code::NotPossible, NO_ENTRY).with("what", "entry_taken_out")
    );
    let entry = EditEntry::of(&rewritten.document, &reference);
    Ok((rewritten, entry))
}

/// The file of a lorebook without entries, called `name` and saying
/// `description` of itself, which is no line where it is empty, as
/// `describe` has it; its ID is the name's.
pub fn empty(name: &str, description: &str) -> String {
    let quoted = |text: &str| Value::String(text.to_string()).to_string();
    let description = plain(description);
    let about = if description.is_empty() {
        String::new()
    } else {
        format!("description = {}\n", quoted(&description))
    };
    format!(
        "spec = \"ccv4:1.0.0\"\n\n[lorebook.{}]\nname = {}\n{about}entries = []\n",
        slug_or(name, "lorebook"),
        quoted(name)
    )
}

/// Writes what the lorebook `book` in `files` says of itself: its `name`, and
/// its `description`, which is no line where it is empty. What is `None`
/// stays. `None` where the lorebook says so already: the files stay as they are.
pub fn describe(
    files: &[(String, String)],
    book: &str,
    name: Option<&str>,
    description: Option<&str>,
    numbers: [Option<u32>; 2],
) -> anyhow::Result<Option<Rewritten>> {
    let mut open = Open::of(files, book)?;
    let book = open.document.lookup(&open.book);
    let was_called = book.and_then(|book| book.get("name")?.as_str());
    let was_called = was_called.unwrap_or("").to_string();
    let was_described = crate::lore::description(&open.document, &open.book);
    let mut changed = false;
    if let Some(name) = name.filter(|name| *name != was_called) {
        set(open.lorebook()?, "name", name);
        changed = true;
    }
    if let Some(description) = description.map(plain).filter(|text| *text != was_described) {
        let text = Some(description.as_str()).filter(|text| !text.is_empty());
        put(open.lorebook()?, "description", text.map(Into::into));
        changed = true;
    }
    // The lorebook's own scan depth and token budget; 0 takes one away.
    for (key, number) in ["scan-depth", "token-budget"].into_iter().zip(numbers) {
        let Some(number) = number else { continue };
        let new = Some(i64::from(number)).filter(|n| *n > 0);
        if book_number(&open.document, &open.book, key).map(i64::from) != new {
            put(open.lorebook()?, key, new.map(Into::into));
            changed = true;
        }
    }
    if !changed {
        return Ok(None);
    }
    open.finish().map(Some)
}

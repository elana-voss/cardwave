//! `Card`: a card's TOML files open for an edit with `toml_edit`, the checks
//! an edit must pass once the card is read again, and a character's greetings
//! written into it (`greetings`). `Named` lists every reference a file names.

use std::collections::{HashMap, HashSet};

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};
use toml_edit::visit::Visit;
use toml_edit::{Array, DocumentMut, Formatted, Item, Table, TableLike};

use crate::mapping::SECTIONS;
use crate::{Document, free_id, is_placeholder, plain, split_reference, strings};

use crate::edit::{EditText, find, line_of, named, of_block, set, set_list, text_of};

/// Whether the edited card reads as the edit asks; told the card after the edit.
type Check<'a> = Box<dyn Fn(&Document) -> bool + 'a>;

/// A card's files open for an edit.
pub(super) struct Card<'a> {
    /// The card as it reads before the edit.
    document: &'a Document,
    /// Each file, in the order they were given in.
    pub(super) files: Vec<DocumentMut>,
    /// How each file is written when nothing was changed in it.
    pub(super) untouched: Vec<String>,
    /// The texts the edit has written, by their blocks, and the modes.
    written: HashMap<String, String>,
    moded: HashMap<String, Vec<String>>,
    /// What the edit has to have brought about, each with what it is about.
    pub(super) checks: Vec<(String, Check<'a>)>,
}

impl<'a> Card<'a> {
    pub(super) fn open(
        document: &'a Document,
        files: &'a [(String, String)],
    ) -> anyhow::Result<Self> {
        let mut open = Vec::new();
        for (name, text) in files {
            open.push(text.parse::<DocumentMut>().with_context(|| {
                Fail::said(Code::NotReadable, format!("{name} is not valid TOML"))
                    .with("what", "toml")
                    .with("name", name.to_string())
            })?);
        }
        let untouched = open.iter().map(DocumentMut::to_string).collect();
        Ok(Self {
            document,
            files: open,
            untouched,
            written: HashMap::new(),
            moded: HashMap::new(),
            checks: Vec::new(),
        })
    }

    /// What stands under `keys` in the one file that has it.
    pub(super) fn at(&mut self, keys: &[&str]) -> Option<&mut Item> {
        self.files
            .iter_mut()
            .find_map(|file| find(file.as_item_mut(), keys))
    }

    /// The edit has to bring `holds` about, or `what` cannot be changed in this card.
    pub(super) fn expect(&mut self, what: String, holds: impl Fn(&Document) -> bool + 'a) {
        self.checks.push((what, Box::new(holds)));
    }

    /// The edit has to leave the block `reference` reading `text`.
    pub(super) fn expect_text(&mut self, reference: &str, text: &str) {
        let (reference, text) = (reference.to_string(), text.to_string());
        self.expect(reference.clone(), move |after| {
            text_of(after, &reference).as_deref() == Some(&text)
        });
    }

    /// Writes the text of the block `reference`: into the draft that stands in
    /// for the block, where one does. A block two characters have is written
    /// once, and not with two texts.
    pub(super) fn write(&mut self, reference: &str, text: &str) -> anyhow::Result<()> {
        if let Some(other) = self.written.insert(reference.to_string(), text.to_string()) {
            ensure!(
                other == text,
                Fail::said(Code::Changed, format!("{reference} is changed in two ways"))
                    .with("what", "two_ways")
                    .with("reference", reference.to_string())
            );
            return Ok(());
        }
        set(self.block(reference)?, "text", text);
        self.expect_text(reference, text);
        Ok(())
    }

    /// The block `reference` to be changed: the draft that stands in for it,
    /// where one does.
    pub(super) fn block(&mut self, reference: &str) -> anyhow::Result<&mut dyn TableLike> {
        let (kind, id) = split_reference(reference).with_context(|| {
            Fail::said(Code::NotReadable, format!("{reference:?} names no block"))
                .with("what", "card_reference")
        })?;
        let block = match self.document.pin(reference) {
            Some(draft) => self
                .at(&["revision", reference, "drafts"])
                .and_then(|drafts| find(drafts.get_mut(draft)?, &["payload"])),
            None => self.at(&[kind, id]),
        };
        block.and_then(Item::as_table_like_mut).with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("{reference} cannot be changed in this card"),
            )
            .with("what", "card_change")
            .with("reference", reference.to_string())
        })
    }

    /// Gives the block `reference` the modes it is used in; none for all.
    pub(super) fn set_modes(&mut self, reference: &str, modes: &[String]) -> anyhow::Result<()> {
        if let Some(other) = self.moded.insert(reference.to_string(), modes.to_vec()) {
            ensure!(
                other == modes,
                Fail::said(Code::Changed, format!("{reference} is changed in two ways"))
                    .with("what", "two_ways")
                    .with("reference", reference.to_string())
            );
            return Ok(());
        }
        let block = self.block(reference)?;
        if modes.is_empty() {
            block.remove("modes");
        } else {
            set_list(block, "modes", modes);
        }
        let (reference, modes) = (reference.to_string(), modes.to_vec());
        self.expect(format!("the modes of {reference}"), move |after| {
            after.block_modes(&reference) == modes
        });
        Ok(())
    }

    /// The character `id`, in its file.
    pub(super) fn character(&mut self, id: &str) -> anyhow::Result<&mut dyn TableLike> {
        let block = self
            .at(&["character", id])
            .and_then(Item::as_table_like_mut);
        block.with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("the character {id} cannot be changed in this card"),
            )
            .with("what", "character_change")
            .with("id", id.to_string())
        })
    }

    /// Makes a block of `kind` with `text` in the file of the character `id`,
    /// under the character's ID or, where that is taken, under `ID-2`, `ID-3`, …
    /// An ID is taken by a block, and by the drafts of a block that is gone,
    /// which are that one's history and not the new one's. Returns its reference.
    pub(super) fn add(&mut self, id: &str, kind: &str, text: &str) -> anyhow::Result<String> {
        let taken = |card: &Self, free: &str| {
            let block = card
                .files
                .iter()
                .any(|file| file.get(kind).and_then(|blocks| blocks.get(free)).is_some());
            block || card.document.has_revision(&format!("{kind}.{free}"))
        };
        let free = free_id(id, |free| taken(self, free));
        let home = self
            .files
            .iter_mut()
            .find(|file| file.get("character").and_then(|all| all.get(id)).is_some());
        let file = home.with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("the character {id} cannot be changed in this card"),
            )
            .with("what", "character_change")
            .with("id", id.to_string())
        })?;
        // Blocks stand under headers of their own (`[greeting.ID]`), not under one of their kind.
        let blocks = file.entry(kind).or_insert_with(|| {
            let mut blocks = Table::new();
            blocks.set_implicit(true);
            Item::Table(blocks)
        });
        let blocks = blocks.as_table_like_mut().with_context(|| {
            Fail::said(Code::NotPossible, format!("this card takes no new {kind}"))
                .with("what", "card_takes_no")
                .with("kind", kind.to_string())
        })?;
        let mut block = Table::new();
        set(&mut block, "text", text);
        // A text of a character in a language of its own is in that language too.
        if let Some(language) = self.document.character_language(id) {
            set(&mut block, "language", language);
        }
        blocks.insert(&free, Item::Table(block));
        let reference = format!("{kind}.{free}");
        self.expect_text(&reference, text);
        Ok(reference)
    }

    /// Gives a text of the character `id` that one of its keys names (`key`, a
    /// reference to a block of `kind`) the words `text`: in the block the key
    /// names, or in a new one when it names none.
    pub(super) fn write_under(
        &mut self,
        id: &str,
        key: &str,
        kind: &str,
        text: &str,
    ) -> anyhow::Result<()> {
        match named(self.document, id, key) {
            Some(reference) => self.write(reference, text),
            None => {
                let reference = self.add(id, kind, text)?;
                set(self.character(id)?, key, reference);
                Ok(())
            }
        }
    }

    /// Puts the new block `reference` into the prompt of the character `id`:
    /// behind the last block of its kind or of a kind that comes before it,
    /// else before the first block of a kind that comes after it, else before
    /// the chat and the lorebooks, else at the end.
    pub(super) fn place(&mut self, id: &str, reference: &str) -> anyhow::Result<()> {
        // The order a prompt has its kinds of block in: the name, then the sections' kinds.
        let rank = |item: &str| {
            let (kind, _) = split_reference(item)?;
            if kind == "name" {
                Some(0)
            } else {
                SECTIONS
                    .iter()
                    .position(|(one, _)| *one == kind)
                    .map(|at| at + 1)
            }
        };
        let own = rank(reference);
        let character = self.character(id)?;
        if character.get("prompt").is_none() {
            set(character, "prompt", Array::new());
        }
        let template = character.get_mut("prompt").and_then(Item::as_array_mut);
        let template = template.with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("the prompt of {id} cannot be changed in this card"),
            )
            .with("what", "prompt_change")
            .with("id", id.to_string())
        })?;
        let items: Vec<&str> = template
            .iter()
            .map(|item| item.as_str().unwrap_or(""))
            .collect();
        let behind = items
            .iter()
            .rposition(|item| rank(item).is_some_and(|other| Some(other) <= own));
        let before = || {
            items
                .iter()
                .position(|item| rank(item).is_some() || is_placeholder(item))
        };
        let index = behind
            .map(|last| last + 1)
            .or_else(before)
            .unwrap_or(items.len());

        // Written as the list's other lines are: on a line of its own where they are.
        let line = line_of(template);
        template.insert(index, reference);
        match line {
            Some(line) => template
                .get_mut(index)
                // `insert` just put an item at `index`.
                .expect("just put there")
                .decor_mut()
                .set_prefix(line),
            // On one line, what was the first has a space before it now.
            None if index == 0 && template.len() > 1 => template
                .get_mut(1)
                // The guard says the list has more than one item.
                .expect("more than one")
                .decor_mut()
                .set_prefix(" "),
            None => {}
        }
        let (id, reference) = (id.to_string(), reference.to_string());
        self.expect(reference.clone(), move |after| {
            after
                .character(&id)
                .is_some_and(|block| strings(block.get("prompt")).contains(&reference.as_str()))
        });
        Ok(())
    }

    /// Puts the new block `reference` at the end of the prompt of the character
    /// `id`, after the chat, which is put there first where the prompt has none.
    pub(super) fn place_after_chat(&mut self, id: &str, reference: &str) -> anyhow::Result<()> {
        let character = self.character(id)?;
        if character.get("prompt").is_none() {
            set(character, "prompt", Array::new());
        }
        let template = character.get_mut("prompt").and_then(Item::as_array_mut);
        let template = template.with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("the prompt of {id} cannot be changed in this card"),
            )
            .with("what", "prompt_change")
            .with("id", id.to_string())
        })?;
        // Written as the list's other lines are: on a line of its own where they are.
        let line = line_of(template);
        let chat = template
            .iter()
            .any(|item| item.as_str() == Some("CHAT-HISTORY"));
        let mut push = |item: &str| {
            template.push(item);
            if let Some(line) = &line {
                let last = template.len() - 1;
                template
                    .get_mut(last)
                    // `push` just put an item at `last`.
                    .expect("just put there")
                    .decor_mut()
                    .set_prefix(line);
            }
        };
        if !chat {
            push("CHAT-HISTORY");
        }
        push(reference);
        let (id, reference) = (id.to_string(), reference.to_string());
        self.expect(reference.clone(), move |after| {
            after
                .character(&id)
                .is_some_and(|block| strings(block.get("prompt")).contains(&reference.as_str()))
        });
        Ok(())
    }

    /// The card's `meta-info` for its key `key` to be written in: that of the
    /// file that has the key, else of the first that has a `meta-info`, else one
    /// made in the file that says the format's version.
    pub(super) fn meta(&mut self, key: &str) -> anyhow::Result<&mut dyn TableLike> {
        let file_with = |keys: &[&str]| {
            let has = |file: &DocumentMut| {
                keys.iter()
                    .try_fold(file.as_item(), |item, key| item.get(key))
                    .is_some()
            };
            self.files.iter().position(has)
        };
        let at = [&["meta-info", key][..], &["meta-info"], &["spec"]]
            .into_iter()
            .find_map(file_with);
        let file = &mut self.files[at.context(
            Fail::said(Code::NotReadable, "the card says no format version")
                .with("what", "format_version"),
        )?];
        let meta = file
            .entry("meta-info")
            .or_insert_with(|| Item::Table(Table::new()));
        meta.as_table_like_mut().context(
            Fail::said(
                Code::NotPossible,
                "what the card says about itself cannot be changed",
            )
            .with("what", "card_about_itself"),
        )
    }

    /// Takes the block `reference` out of the card. Its drafts stay, and with
    /// them its words (see `drafts`).
    pub(super) fn remove(&mut self, reference: &str) {
        let Some((kind, id)) = split_reference(reference) else {
            return;
        };
        for file in &mut self.files {
            if let Some(all) = find(file.as_item_mut(), &[kind]).and_then(Item::as_table_like_mut) {
                all.remove(id);
            }
        }
    }
}

/// Every text a file holds as a value: what its lists name is among them.
#[derive(Default)]
pub(super) struct Named<'doc>(pub(super) HashSet<&'doc str>);

impl<'doc> Visit<'doc> for Named<'doc> {
    fn visit_string(&mut self, node: &'doc Formatted<String>) {
        self.0.insert(node.value().as_str());
    }
}

/// Writes the greetings `asked` of the character `id` under its key `key`
/// (`greetings`, `group-greetings`), which shows `shown`, each in the modes
/// `modes_of` keeps: one left empty is taken off, and one taken off goes into
/// `dropped`.
#[allow(clippy::too_many_arguments)]
pub(super) fn greetings(
    card: &mut Card<'_>,
    document: &Document,
    id: &str,
    key: &str,
    asked: &[EditText],
    shown: &[EditText],
    modes_of: &dyn Fn(&EditText) -> anyhow::Result<Vec<String>>,
    dropped: &mut Vec<String>,
) -> anyhow::Result<()> {
    let mut greetings: Vec<String> = Vec::new();
    for part in asked {
        let text = plain(&part.text);
        // A greeting left empty is taken off, and a new one without words is none.
        if text.is_empty() {
            continue;
        }
        let used_in = modes_of(part)?;
        match &part.reference {
            Some(reference) => {
                let before = of_block(shown, reference);
                let before = before.with_context(|| {
                    Fail::said(
                        Code::NotPossible,
                        format!("{reference} is no greeting of {id}"),
                    )
                    .with("what", "greeting")
                    .with("reference", reference.to_string())
                    .with("id", id.to_string())
                })?;
                if greetings.contains(reference) {
                    continue;
                }
                if text != before.text {
                    card.write(reference, &text)?;
                }
                if used_in != before.modes {
                    card.set_modes(reference, &used_in)?;
                }
                greetings.push(reference.clone());
            }
            None => {
                let reference = card.add(id, "greeting", &text)?;
                if !used_in.is_empty() {
                    card.set_modes(&reference, &used_in)?;
                }
                greetings.push(reference);
            }
        }
    }
    if greetings
        .iter()
        .map(Some)
        .eq(shown.iter().map(|one| one.reference.as_ref()))
    {
        return Ok(());
    }
    let before = document
        .character(id)
        .map(|block| strings(block.get(key)))
        .unwrap_or_default();
    dropped.extend(
        before
            .into_iter()
            .filter(|one| !greetings.iter().any(|kept| kept == one))
            .map(str::to_string),
    );
    set_list(card.character(id)?, key, &greetings);
    let (id, key) = (id.to_string(), key.to_string());
    card.expect(format!("the {key} of {id}"), move |after| {
        after
            .character(&id)
            .is_some_and(|block| strings(block.get(&key)) == greetings)
    });
    Ok(())
}

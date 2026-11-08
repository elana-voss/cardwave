//! A card in several languages (section 3.3): parallel text blocks with a
//! `language` key and a character of that language that names them, in the
//! same file. A character's language is its texts' ([`Document::character_language`]);
//! its first character's is the card's first language, often named by no key
//! and then told by its words ([`shown`]). Characters of one language stand
//! for those of another by their order in the file ([`Document::in_language`]).
//!
//! [`add`] writes a translation kept as a whole ("Keep all"): a copy of the
//! first character under `ID-CODE`, each of its texts (not its name, which
//! both share) a new block `ID-CODE` with the translated words and the
//! `language` key, and, where its lorebook was translated too, a copy of each
//! own lorebook with its entries. [`lore_texts`] is that lorebook as it is
//! translated. Nothing beyond the spec is written.

use std::collections::{HashMap, HashSet};

use anyhow::{Context, ensure};
use cw_core::languages::{self, Language};
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use toml::{Table, Value};
use toml_edit::{DocumentMut, Item};
use ts_rs::TS;

use crate::edit::Edited;
use crate::{Document, free_id, is_placeholder, split_reference, strings};

/// The keys of a character that name its texts in its language: all but its name.
const TEXT_KEYS: [&str; 4] = ["greetings", "group-greetings", "prompt", "creator-note"];

/// One text in the new language, by the block of the card's first language it translates.
#[derive(Clone, Debug, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct TranslatedText {
    pub reference: String,
    pub text: String,
}

/// A lorebook entry of the card's own, its words and keywords (each list in
/// its order); translated, or as it is to be translated.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct LoreText {
    pub reference: String,
    pub text: String,
    pub keywords: Vec<String>,
    #[serde(default)]
    pub secondary_keywords: Vec<String>,
}

/// A card's translation as the page keeps it ("Keep all").
#[derive(Clone, Debug, Deserialize, TS)]
#[ts(export)]
pub struct Translation {
    /// The number of the card's version it was translated from; another is refused.
    pub version: i64,
    /// The new language's code.
    pub language: String,
    pub texts: Vec<TranslatedText>,
    /// The creator notes in it, which the page shows without their block.
    #[serde(default)]
    #[ts(optional)]
    pub creator_notes: Option<String>,
    /// Its own lorebooks' entries, where they were translated too.
    #[serde(default)]
    pub lore: Vec<LoreText>,
}

/// A key's value as a list of the strings in it: a list's, or one string's.
fn named(value: Option<&Value>) -> Vec<&str> {
    match value {
        Some(Value::String(one)) => vec![one.as_str()],
        other => strings(other),
    }
}

impl Document {
    /// The blocks of the texts the character `id` names (not its name), each once, in their order.
    fn texts_of(&self, id: &str) -> Vec<&str> {
        let Some(character) = self.character(id) else {
            return Vec::new();
        };
        let mut seen = HashSet::new();
        TEXT_KEYS
            .iter()
            .flat_map(|key| named(character.get(*key)))
            .filter(|item| !is_placeholder(item) && self.lookup(item).is_some())
            .filter(|item| seen.insert(*item))
            .collect()
    }

    /// The language the character `id` is written in: the `language` of the
    /// first of its texts that names one. None where none does.
    pub(crate) fn character_language(&self, id: &str) -> Option<String> {
        self.texts_of(id).into_iter().find_map(|reference| {
            let language = self.lookup(reference)?.get("language")?.as_str()?.trim();
            (!language.is_empty()).then(|| language.to_string())
        })
    }

    /// The card's characters written in `language` (none: in no language named), in the file's order.
    fn characters_in(&self, language: Option<&str>) -> Vec<&str> {
        let fits = |id: &&str| match (self.character_language(id), language) {
            (None, None) => true,
            (Some(own), Some(asked)) => languages::same(&own, asked),
            _ => false,
        };
        self.ids("character").into_iter().filter(fits).collect()
    }

    /// The languages the card is translated into: those of its characters
    /// besides its first character's, each once, in the file's order.
    pub(crate) fn translations(&self) -> Vec<String> {
        let first = self
            .characters()
            .first()
            .and_then(|id| self.character_language(id));
        let mut found: Vec<String> = Vec::new();
        for id in self.ids("character") {
            let Some(language) = self.character_language(id) else {
                continue;
            };
            let known = first
                .iter()
                .chain(&found)
                .any(|one| languages::same(one, &language));
            if !known {
                found.push(language);
            }
        }
        found
    }

    /// The character that stands for `id` in `language`: the one of that
    /// language at `id`'s place among the characters of its own, else `id`.
    pub fn in_language<'a>(&'a self, id: &'a str, language: &str) -> &'a str {
        let own = self.character_language(id);
        if own
            .as_deref()
            .is_some_and(|own| languages::same(own, language))
        {
            return id;
        }
        let Some(at) = self
            .characters_in(own.as_deref())
            .iter()
            .position(|one| *one == id)
        else {
            return id;
        };
        self.characters_in(Some(language))
            .get(at)
            .copied()
            .unwrap_or(id)
    }

    /// The card's first language: its first character's, or the one its words are in.
    pub(crate) fn first_language(&self) -> Option<String> {
        self.language_of(self.characters().first()?)
    }

    /// The language the character `id` is in: the one its texts name, else the one its words are in.
    pub fn language_of(&self, id: &str) -> Option<String> {
        self.character_language(id).or_else(|| {
            let words: Vec<&str> = self
                .texts_of(id)
                .into_iter()
                .filter_map(|reference| self.text(reference))
                .collect();
            languages::detect(&words.join("\n\n")).map(str::to_string)
        })
    }
}

/// The card's languages as its page names them, its first language first
/// (the page's language bar shows from two on). A first language that cannot
/// be told is "Original", with no code.
pub fn shown(document: &Document) -> Vec<Language> {
    let translations = document.translations();
    let first = document.first_language().map_or_else(
        || Language {
            code: String::new(),
            name: "Original".to_string(),
        },
        |code| Language {
            name: languages::name_of(&code),
            code,
        },
    );
    let others = translations.into_iter().map(|code| Language {
        name: languages::name_of(&code),
        code,
    });
    std::iter::once(first).chain(others).collect()
}

/// The own lorebooks of the card's first character (those in its file), each once.
fn own_lorebooks(document: &Document) -> Vec<&str> {
    let Some(id) = document.characters().first().copied() else {
        return Vec::new();
    };
    let mut seen = HashSet::new();
    named(document.character(id).and_then(|one| one.get("lorebooks")))
        .into_iter()
        .filter(|book| document.lookup(book).is_some() && seen.insert(*book))
        .collect()
}

/// The entries of the card's own lorebooks that have words, as they are translated.
pub fn lore_texts(document: &Document) -> Vec<LoreText> {
    let mut seen = HashSet::new();
    let entries = own_lorebooks(document)
        .into_iter()
        .flat_map(|book| named(document.lookup(book).and_then(|book| book.get("entries"))))
        .filter(|entry| seen.insert(*entry));
    entries
        .filter_map(|reference| {
            let block = document.lookup(reference)?;
            let text = block.get("text")?.as_str()?.trim();
            // Keywords that are patterns are not words to translate: they stay as they are.
            let patterns = block.get("use-regex").and_then(Value::as_bool) == Some(true);
            let list = |key: &str| {
                let words = named(block.get(key)).into_iter().map(str::to_string);
                words.filter(|_| !patterns).collect()
            };
            (!text.is_empty()).then(|| LoreText {
                reference: reference.to_string(),
                text: text.to_string(),
                keywords: list("keywords"),
                secondary_keywords: list("secondary-keywords"),
            })
        })
        .collect()
}

/// A block of the card as `toml_edit` writes it, from the card as it reads.
fn editable(block: &Table) -> anyhow::Result<toml_edit::Table> {
    let text = toml::to_string(block)?;
    let parsed: DocumentMut = text.parse()?;
    Ok(parsed.as_table().clone())
}

/// The blocks a translation copies, each under its new ID.
struct Copies<'d> {
    document: &'d Document,
    /// The new language's code.
    code: &'d str,
    /// Each block copied, by the reference of the one it copies, and the copies.
    renamed: HashMap<String, String>,
    blocks: Vec<(String, String, toml_edit::Table)>,
}

impl Copies<'_> {
    /// Copies the block `reference` under `ID-CODE` (or the first free ID
    /// after it), changed by `change`; a text's copy names its language.
    fn copy(
        &mut self,
        reference: &str,
        text: bool,
        change: impl FnOnce(&mut toml_edit::Table),
    ) -> anyhow::Result<()> {
        let (kind, id) = split_reference(reference)
            .context(Fail::said(Code::Internal, "a reference names no block"))?;
        let block = self
            .document
            .lookup(reference)
            .context(Fail::said(Code::Internal, "a text has no block"))?;
        let mut block = editable(block)?;
        change(&mut block);
        if text {
            crate::edit::set(&mut block, "language", self.code);
        }
        let new_id = free_id(&format!("{id}-{}", self.code), |free| {
            let reference = format!("{kind}.{free}");
            self.document.element(kind, free).is_some()
                || self.document.has_revision(&reference)
                || self.renamed.values().any(|made| *made == reference)
        });
        self.renamed
            .insert(reference.to_string(), format!("{kind}.{new_id}"));
        self.blocks.push((kind.to_string(), new_id, block));
        Ok(())
    }

    /// Copies the card's own lorebooks whose entries `lore` translates, each
    /// with those entries copied in its words and the others as they are.
    fn lorebooks(&mut self, lore: &[LoreText]) -> anyhow::Result<()> {
        let lore: HashMap<&str, &LoreText> = lore
            .iter()
            .map(|one| (one.reference.as_str(), one))
            .collect();
        for book in own_lorebooks(self.document) {
            let listed = self
                .document
                .lookup(book)
                .and_then(|book| book.get("entries"));
            let entries = named(listed);
            if !entries.iter().any(|entry| lore.contains_key(entry)) {
                continue;
            }
            for entry in &entries {
                // An entry two of the lorebooks share is copied once.
                let Some(words) = lore
                    .get(entry)
                    .filter(|_| !self.renamed.contains_key(*entry))
                else {
                    continue;
                };
                self.copy(entry, true, |block| {
                    crate::edit::set(block, "text", words.text.trim());
                    for (key, list) in [
                        ("keywords", &words.keywords),
                        ("secondary-keywords", &words.secondary_keywords),
                    ] {
                        if !list.is_empty() {
                            crate::edit::set_list(block, key, list);
                        }
                    }
                })?;
            }
            let entries: Vec<String> = entries
                .iter()
                .map(|entry| {
                    let copied = self.renamed.get(*entry).cloned();
                    copied.unwrap_or_else(|| entry.to_string())
                })
                .collect();
            self.copy(book, false, |block| {
                crate::edit::set_list(block, "entries", &entries);
            })?;
        }
        Ok(())
    }

    /// The character `id` of the new language: `id`'s, naming the copies.
    fn character(&self, id: &str) -> anyhow::Result<toml_edit::Table> {
        let mut character = self
            .document
            .character(id)
            .context(
                Fail::said(Code::NotPossible, "the card has no character")
                    .with("what", "card_no_character"),
            )?
            .clone();
        let rename = |one: &mut String| {
            if let Some(new) = self.renamed.get(one.as_str()) {
                *one = new.clone();
            }
        };
        for key in TEXT_KEYS.iter().chain(&["lorebooks"]) {
            match character.get_mut(*key) {
                Some(Value::String(one)) => rename(one),
                Some(Value::Array(items)) => {
                    for item in items {
                        if let Value::String(one) = item {
                            rename(one);
                        }
                    }
                }
                _ => {}
            }
        }
        editable(&character)
    }
}

/// Puts each of `blocks` (kind, ID, block) into `file`, each under a header
/// of its own (`[greeting.ID]`), not under one of its kind.
fn put(
    file: &mut DocumentMut,
    blocks: Vec<(String, String, toml_edit::Table)>,
) -> anyhow::Result<()> {
    for (kind, id, block) in blocks {
        let all = file.entry(&kind).or_insert_with(|| {
            let mut all = toml_edit::Table::new();
            all.set_implicit(true);
            Item::Table(all)
        });
        all.as_table_like_mut()
            .with_context(|| {
                Fail::said(Code::NotPossible, format!("this card takes no new {kind}"))
                    .with("what", "card_takes_no")
                    .with("kind", kind.to_string())
            })?
            .insert(&id, Item::Table(block));
    }
    Ok(())
}

/// The card's files as `open` has them where `changed` names them, else as given.
fn written(
    files: &[(String, String)],
    open: &[DocumentMut],
    changed: &[usize],
) -> Vec<(String, String)> {
    files
        .iter()
        .zip(open)
        .enumerate()
        .map(|(at, ((file, text), now))| {
            let text = if changed.contains(&at) {
                now.to_string()
            } else {
                text.clone()
            };
            (file.clone(), text)
        })
        .collect()
}

/// The card's files with the translation `translation` in them, made at
/// `now` (milliseconds): its first character in the new language beside the
/// one it has. Refused: a language the app does not know, or one the card is
/// in already.
pub fn add(
    files: &[(String, String)],
    translation: &Translation,
    now: i64,
) -> anyhow::Result<Edited> {
    let document = Document::parse(files)?;
    let code = languages::known(&translation.language).with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("{:?} is no language this app knows", translation.language),
        )
        .with("what", "unknown_language")
    })?;
    let name = languages::name_of(code);
    let id = *document.characters().first().context(
        Fail::said(Code::NotPossible, "the card has no character")
            .with("what", "card_no_character"),
    )?;
    let mut has = document
        .first_language()
        .into_iter()
        .chain(document.translations());
    ensure!(
        !has.any(|one| languages::same(&one, code)),
        Fail::said(Code::Taken, format!("the card is in {name} already"))
            .with("what", "card_language")
            .with("name", name.to_string())
    );
    let mut open = Vec::new();
    for (file, text) in files {
        let parsed = text.parse::<DocumentMut>();
        open.push(parsed.with_context(|| {
            Fail::said(Code::NotReadable, format!("{file} is not valid TOML"))
                .with("what", "toml")
                .with("file", file.to_string())
        })?);
    }
    let home = open
        .iter()
        .position(|file| file.get("character").and_then(|all| all.get(id)).is_some())
        .with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("the character {id} cannot be changed in this card"),
            )
            .with("what", "character_change")
            .with("id", id.to_string())
        })?;

    let mut copies = Copies {
        document: &document,
        code,
        renamed: HashMap::new(),
        blocks: Vec::new(),
    };
    let mut texts: HashMap<&str, &str> = translation
        .texts
        .iter()
        .map(|one| (one.reference.as_str(), one.text.as_str()))
        .collect();
    let note = document
        .character(id)
        .and_then(|one| one.get("creator-note")?.as_str());
    if let (Some(note), Some(text)) = (note, &translation.creator_notes) {
        texts.insert(note, text);
    }
    for reference in document.texts_of(id) {
        copies.copy(reference, true, |block| {
            if let Some(text) = texts.get(reference) {
                crate::edit::set(block, "text", text.trim());
            }
        })?;
    }
    copies.lorebooks(&translation.lore)?;
    let new_id = free_id(&format!("{id}-{code}"), |free| {
        document.character(free).is_some()
    });
    let character = copies.character(id)?;
    copies
        .blocks
        .push(("character".to_string(), new_id.clone(), character));
    put(&mut open[home], copies.blocks)?;

    let mut changed = vec![home];
    // The card says when it was last changed where it says anything of itself.
    if let Some(at) = open.iter().position(|file| file.get("meta-info").is_some())
        && let Some(meta) = open[at]
            .get_mut("meta-info")
            .and_then(Item::as_table_like_mut)
    {
        let modified: toml_edit::Datetime = crate::written_date(now)?.parse()?;
        crate::edit::set(meta, "modified", modified);
        changed.push(at);
    }
    let files = written(files, &open, &changed);
    let document = Document::parse(&files)?;
    ensure!(
        document.in_language(id, code) == new_id,
        Fail::said(
            Code::NotPossible,
            format!("the card cannot hold {name} beside its first language")
        )
        .with("what", "card_language_beside")
        .with("name", name.to_string())
    );
    Ok(Edited { files, document })
}

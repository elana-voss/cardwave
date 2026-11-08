//! SillyTavern cards (Character Card V2 and V3, and the older bare form)
//! converted to CCV4 on import, after the mapping in spec section 6.1.
//!
//! Such a card is one JSON object, base64-encoded in a `tEXt` chunk of the PNG
//! (`ccv3` or `chara`). Cards in the wild come from many tools, so fields are
//! read leniently: a missing or oddly typed field is skipped or coerced, never
//! a reason to refuse the card. Nothing is fetched from the web.
//!
//! Beyond the spec's keys the conversion writes a few of its own, so that
//! nothing the prompt builder understands is lost: on `lore` blocks `name`,
//! `selective-logic`, `match-whole-words`, `probability`, `ignore-budget`,
//! `character-filter`, `scan-depth` (how many messages are read for that
//! entry's keys, where it says so itself), and `depth` with `role` (the entry goes into the chat
//! like a `prompt` with `depth`); `role` on a `prompt` with `depth`; `asset`
//! elements for the card's embedded files; and one `sillytavern` element that
//! keeps the card's `extensions` as the JSON text they came as.
//!
//! `plain_picture` is a PNG without the card it may hold, for a picture that
//! is to be another card's.

use std::collections::{HashMap, HashSet};

use anyhow::{Context, bail};
use base64::Engine;
use base64::engine::DecodePaddingMode;
use base64::engine::general_purpose::{GeneralPurpose, GeneralPurposeConfig};
use cw_core::{Code, Fail};
use serde_json::{Map, Value as Json};
use toml::{Table, Value};

mod export;
pub mod world;

pub use export::{export, world};

use crate::png::{self, Container};
use crate::{DEFAULT_TALKATIVENESS, ImportNote, ONE_FILE, slug, slug_or, written_date};

/// Keywords of the `tEXt` chunks that hold the card. A V3 chunk wins over the V2
/// copy most tools write next to it.
const CARD_CHUNKS: [&str; 2] = ["ccv3", "chara"];
/// Keyword prefix of the `tEXt` chunks that carry a V3 card's embedded assets.
const ASSET_CHUNK: &str = "chara-ext-asset_";
/// Order of the types in the written file.
const ORDER: [&str; 15] = [
    "spec",
    "meta-info",
    "name",
    "description",
    "personality",
    "scenario",
    "greeting",
    "dialogue-example",
    "prompt",
    "creator-note",
    "lore",
    "lorebook",
    "character",
    "asset",
    "sillytavern",
];
/// Types that make a card worth importing.
const CONTENT: [&str; 8] = [
    "name",
    "description",
    "personality",
    "scenario",
    "greeting",
    "dialogue-example",
    "prompt",
    "lore",
];
/// SillyTavern's values where a card names none.
const DEFAULT_DEPTH: i64 = 4;
const DEFAULT_INSERTION_ORDER: i64 = 100;

/// Base64 as tools write it: with or without padding.
const BASE64: GeneralPurpose = GeneralPurpose::new(
    &base64::alphabet::STANDARD,
    GeneralPurposeConfig::new()
        .with_decode_padding_mode(DecodePaddingMode::Indifferent)
        .with_decode_allow_trailing_bits(true),
);

type Object = Map<String, Json>;

/// Converts the SillyTavern card in `picture`, a PNG without CCV4 data. Returns
/// the card as a CCV4 container (its picture without the card data) and notes on
/// what was not taken over, or `None` when the PNG holds no SillyTavern card.
pub fn convert(picture: &[u8]) -> anyhow::Result<Option<(Container, Vec<ImportNote>)>> {
    let (image, texts) = png::take_text(picture, is_card_chunk)?;
    // A chunk that cannot be read, or holds nothing, gives way to the next one.
    let candidates = CARD_CHUNKS.into_iter().flat_map(|keyword| {
        texts
            .iter()
            .filter(move |(found, _)| found.eq_ignore_ascii_case(keyword))
    });
    let mut failure = None;
    for (_, text) in candidates {
        match decode(text).and_then(|root| Card::build(&root, &texts)) {
            Ok(mut card) => {
                let toml = vec![(ONE_FILE.to_string(), card.toml()?)];
                return Ok(Some((
                    Container {
                        image,
                        toml,
                        assets: card.assets,
                    },
                    card.notes,
                )));
            }
            Err(error) => {
                failure.get_or_insert(error);
            }
        }
    }
    match failure {
        Some(error) => Err(error.context(
            Fail::said(
                Code::NotReadable,
                "the SillyTavern card in this PNG cannot be read",
            )
            .with("what", "sillytavern_png"),
        )),
        None => Ok(None),
    }
}

/// Converts the SillyTavern card in a JSON file: V2 or V3 (`spec` `chara_card_…`), or the oldest bare
/// fields (a `name` and a `first_mes`). Returns it as [`convert`] does, its picture empty, or `None` where the
/// file is not such a card (any other JSON, or no JSON at all).
pub fn convert_json(file: &[u8]) -> anyhow::Result<Option<(Container, Vec<ImportNote>)>> {
    let file = file
        .strip_prefix([0xEF, 0xBB, 0xBF].as_slice())
        .unwrap_or(file);
    let Ok(root) = decode(file) else {
        return Ok(None);
    };
    let spec = root.get("spec").and_then(Json::as_str).unwrap_or("");
    let oldest = root.get("name").is_some() && root.get("first_mes").is_some();
    if !spec.starts_with("chara_card") && !oldest {
        return Ok(None);
    }
    let mut card = Card::build(&root, &[]).context(
        Fail::said(
            Code::NotReadable,
            "the SillyTavern card in this file cannot be read",
        )
        .with("what", "sillytavern_file"),
    )?;
    let toml = vec![(ONE_FILE.to_string(), card.toml()?)];
    let container = Container {
        image: Vec::new(),
        toml,
        assets: std::mem::take(&mut card.assets),
    };
    Ok(Some((container, card.notes)))
}

/// Whether a `tEXt` chunk of this keyword holds a SillyTavern card.
pub fn is_card_keyword(keyword: &str) -> bool {
    CARD_CHUNKS
        .iter()
        .any(|card| keyword.eq_ignore_ascii_case(card))
}

/// A PNG without the SillyTavern card it may hold: the plain picture.
pub fn plain_picture(picture: &[u8]) -> anyhow::Result<Vec<u8>> {
    Ok(png::take_text(picture, is_card_chunk)?.0)
}

/// Whether a `tEXt` chunk of this keyword is part of a SillyTavern card.
fn is_card_chunk(keyword: &str) -> bool {
    CARD_CHUNKS
        .iter()
        .any(|card| keyword.eq_ignore_ascii_case(card))
        || keyword.starts_with(ASSET_CHUNK)
}

/// Whether this can be a file's extension, as a card names it.
fn is_extension(text: &str) -> bool {
    !text.is_empty() && text.len() <= 8 && text.chars().all(|c| c.is_ascii_alphanumeric())
}

/// The JSON object in a card chunk: base64 as SillyTavern writes it, or plain JSON.
fn decode(text: &[u8]) -> anyhow::Result<Object> {
    let plain = text.iter().find(|b| !b.is_ascii_whitespace()) == Some(&b'{');
    let bytes = if plain {
        text.to_vec()
    } else {
        unbase64(text).context(
            Fail::said(Code::NotReadable, "the card data is not base64")
                .with("what", "sillytavern_base64"),
        )?
    };
    let json = String::from_utf8_lossy(&bytes);
    // Only the first value counts; some tools leave padding behind it.
    let first = serde_json::Deserializer::from_str(json.trim_start_matches('\u{feff}'))
        .into_iter::<Json>()
        .next();
    match first {
        Some(Ok(Json::Object(object))) => Ok(object),
        Some(Err(error)) => Err(error).context(
            Fail::said(Code::NotReadable, "the card data is not valid JSON")
                .with("what", "sillytavern_json"),
        ),
        _ => bail!(
            Fail::said(Code::NotReadable, "the card data is not a JSON object")
                .with("what", "sillytavern_object")
        ),
    }
}

fn unbase64(text: &[u8]) -> Option<Vec<u8>> {
    let compact: Vec<u8> = text
        .iter()
        .copied()
        .filter(|b| !b.is_ascii_whitespace() && *b != 0)
        .collect();
    BASE64.decode(compact).ok()
}

/// A text field without surrounding space and with plain line breaks. Numbers
/// count as text (a version written as `1.2`); anything else as nothing.
fn string(value: Option<&Json>) -> String {
    match value {
        Some(Json::String(text)) => crate::plain(text),
        Some(Json::Number(number)) => number.to_string(),
        _ => String::new(),
    }
}

/// A list of texts without its empty items. One text alone is a list of one.
fn strings(value: Option<&Json>) -> Vec<String> {
    let items = match value {
        Some(Json::Array(items)) => items.iter().map(|item| string(Some(item))).collect(),
        other => vec![string(other)],
    };
    items.into_iter().filter(|item| !item.is_empty()).collect()
}

fn int(value: Option<&Json>) -> Option<i64> {
    match value? {
        // The cast cuts fractions off and stops at the ends of the range.
        Json::Number(number) => number
            .as_i64()
            .or_else(|| number.as_f64().map(|n| n as i64)),
        Json::String(text) => text.trim().parse().ok(),
        Json::Bool(flag) => Some(i64::from(*flag)),
        _ => None,
    }
}

fn float(value: Option<&Json>) -> Option<f64> {
    match value? {
        Json::Number(number) => number.as_f64(),
        Json::String(text) => text.trim().parse().ok(),
        _ => None,
    }
    .filter(|n| n.is_finite())
}

fn flag(value: Option<&Json>) -> Option<bool> {
    match value? {
        Json::Bool(flag) => Some(*flag),
        Json::Number(number) => Some(number.as_f64() != Some(0.0)),
        Json::String(text) => match text.trim().to_ascii_lowercase().as_str() {
            "true" | "1" => Some(true),
            "false" | "0" => Some(false),
            _ => None,
        },
        _ => None,
    }
}

/// The role a text is sent under when it is not the system's: a name, or
/// SillyTavern's number for it.
fn role(value: Option<&Json>) -> Option<&'static str> {
    let named = value
        .and_then(Json::as_str)
        .map(|name| name.trim().to_ascii_lowercase());
    match (named.as_deref(), int(value)) {
        (Some("user"), _) | (_, Some(1)) => Some("user"),
        (Some("assistant"), _) | (_, Some(2)) => Some("assistant"),
        _ => None,
    }
}

/// A date the card gives in seconds (or milliseconds) since 1970.
fn date(value: Option<&Json>) -> Option<Value> {
    let stamp = int(value).filter(|stamp| *stamp > 0)?;
    let seconds = if stamp > 100_000_000_000 {
        stamp / 1000
    } else {
        stamp
    };
    let text = written_date(seconds.checked_mul(1000)?).ok()?;
    text.parse().ok().map(Value::Datetime)
}

fn table<const N: usize>(pairs: [(&str, Value); N]) -> Table {
    pairs
        .into_iter()
        .map(|(key, value)| (key.to_string(), value))
        .collect()
}

fn list(items: Vec<String>) -> Value {
    Value::Array(items.into_iter().map(Value::String).collect())
}

/// The CCV4 card being built.
#[derive(Default)]
struct Card {
    root: Table,
    /// How often an ID was asked for, by reference.
    asked: HashMap<String, usize>,
    assets: Vec<(String, Vec<u8>)>,
    notes: Vec<ImportNote>,
    /// Lorebook entries switched off because the prompt has no place for them.
    outlets: usize,
}

impl Card {
    fn build(root: &Object, chunks: &[png::Text<'_>]) -> anyhow::Result<Self> {
        // V2 and V3 wrap the card in `data`; the oldest cards are the bare fields.
        let data = match root.get("data") {
            Some(Json::Object(data)) => data,
            _ => root,
        };
        let mut card = Self::default();
        card.fill(root, data, chunks);
        if !CONTENT.iter().any(|kind| card.root.contains_key(*kind)) {
            bail!(
                Fail::said(Code::NotReadable, "the card is empty")
                    .with("what", "sillytavern_empty")
            );
        }
        Ok(card)
    }

    /// The card as its one TOML file, the types in [`ORDER`].
    fn toml(&mut self) -> anyhow::Result<String> {
        let mut ordered = Table::new();
        for kind in ORDER {
            if let Some(elements) = self.root.remove(kind) {
                ordered.insert(kind.to_string(), elements);
            }
        }
        ordered.extend(std::mem::take(&mut self.root));
        toml::to_string_pretty(&ordered).context(Fail::said(
            Code::Internal,
            "the converted card cannot be written as TOML",
        ))
    }

    /// Adds an element under `id`, or under `id-2`, `id-3`, … when that is
    /// taken, and returns its reference.
    fn add(&mut self, kind: &str, id: &str, element: Table) -> String {
        let asked = self.asked.entry(format!("{kind}.{id}")).or_insert(0);
        let mut free = id.to_string();
        if let Value::Table(elements) = self
            .root
            .entry(kind)
            .or_insert_with(|| Value::Table(Table::new()))
        {
            loop {
                *asked += 1;
                if *asked > 1 {
                    free = format!("{id}-{asked}");
                }
                if !elements.contains_key(&free) {
                    break;
                }
            }
            elements.insert(free.clone(), Value::Table(element));
        }
        format!("{kind}.{free}")
    }

    /// Adds a text block, unless there is no text.
    fn text(&mut self, kind: &str, id: &str, text: &str) -> Option<String> {
        (!text.is_empty()).then(|| self.add(kind, id, table([("text", text.into())])))
    }

    fn texts(&mut self, kind: &str, id: &str, texts: Vec<String>) -> Vec<String> {
        texts
            .iter()
            .enumerate()
            .filter_map(|(i, text)| self.text(kind, &format!("{id}-{}", i + 1), text))
            .collect()
    }

    fn fill(&mut self, root: &Object, data: &Object, chunks: &[png::Text<'_>]) {
        self.root.insert("spec".to_string(), "ccv4:1.0.0".into());
        self.meta(data);
        let field = |key: &str| string(data.get(key));
        let name = field("name");
        let nickname = field("nickname");
        let id = &slug_or(&name, "character");
        let mut character = Table::new();
        let mut set = |key: &str, value: Value| {
            character.insert(key.to_string(), value);
        };

        if let Some(label) = [&name, &nickname]
            .into_iter()
            .find(|label| !label.is_empty())
        {
            set("name-card", label.as_str().into());
        }
        let own_name = self.text("name", id, &name);
        // A nickname is what {{char}} stands for; the model is still told the name.
        let chat_name = self
            .text("name", &format!("{id}-nickname"), &nickname)
            .or(own_name.clone());
        if let Some(reference) = &chat_name {
            set("name-char", reference.as_str().into());
        }
        if let Some(avatar) = self.embedded_assets(id, data, chunks) {
            set("avatar", avatar.into());
        }

        let (greetings, group_greetings) = self.greetings(id, data);
        if !greetings.is_empty() {
            set("greetings", list(greetings));
        }
        if !group_greetings.is_empty() {
            set("group-greetings", list(group_greetings));
        }

        let extensions = data.get("extensions").and_then(Json::as_object);
        let talkativeness =
            float(extensions.and_then(|e| e.get("talkativeness"))).map(|n| n.clamp(0.0, 1.0));
        if let Some(talkativeness) = talkativeness.filter(|n| *n != DEFAULT_TALKATIVENESS) {
            set("group-talkativeness", talkativeness.into());
        }
        if let Some(Json::Object(book)) = data.get("character_book")
            && let Some(lorebook) = self.lorebook(id, book)
        {
            set("lorebooks", list(vec![lorebook]));
        }
        if let Some(note) = self.creator_notes(id, data) {
            set("creator-note", note.into());
        }

        // The order SillyTavern sends a card's parts in.
        let mut template: Vec<String> = Vec::new();
        template.extend(self.text("prompt", &format!("{id}-system"), &field("system_prompt")));
        template.extend(own_name.or(chat_name));
        for (kind, key) in [
            ("description", "description"),
            ("personality", "personality"),
            ("scenario", "scenario"),
            ("dialogue-example", "mes_example"),
        ] {
            template.extend(self.text(kind, id, &field(key)));
        }
        template.extend(self.character_note(id, extensions));
        template.extend(["LOREBOOK".to_string(), "CHAT-HISTORY".to_string()]);
        template.extend(self.text(
            "prompt",
            &format!("{id}-post-history"),
            &field("post_history_instructions"),
        ));
        set("prompt", list(template));
        self.add("character", id, character);
        self.origin(id, root, extensions);
    }

    /// The greetings, and those only for a chat of several characters.
    fn greetings(&mut self, id: &str, data: &Object) -> (Vec<String>, Vec<String>) {
        let mut openings = strings(data.get("first_mes"));
        openings.extend(strings(data.get("alternate_greetings")));
        let greetings = self.texts("greeting", id, openings);
        let group = self.texts(
            "greeting",
            &format!("{id}-group"),
            strings(data.get("group_only_greetings")),
        );
        (greetings, group)
    }

    /// The character's note, a `prompt` placed into the chat at its depth.
    fn character_note(&mut self, id: &str, extensions: Option<&Object>) -> Option<String> {
        let Some(Json::Object(note)) = extensions.and_then(|e| e.get("depth_prompt")) else {
            return None;
        };
        let mut block = table([(
            "depth",
            int(note.get("depth"))
                .unwrap_or(DEFAULT_DEPTH)
                .max(0)
                .into(),
        )]);
        if let Some(role) = role(note.get("role")) {
            block.insert("role".to_string(), role.into());
        }
        let text = string(note.get("prompt"));
        if text.is_empty() {
            return None;
        }
        block.insert("text".to_string(), text.into());
        Some(self.add("prompt", &format!("{id}-note"), block))
    }

    /// Where the card came from, with the extensions CCV4 has no place for.
    fn origin(&mut self, id: &str, root: &Object, extensions: Option<&Object>) {
        let mut origin = Table::new();
        for (key, source) in [("spec", "spec"), ("spec-version", "spec_version")] {
            let value = string(root.get(source));
            if !value.is_empty() {
                origin.insert(key.to_string(), value.into());
            }
        }
        if let Some(extensions) = extensions.filter(|e| !e.is_empty()) {
            origin.insert(
                "extensions".to_string(),
                serde_json::to_string(extensions).unwrap_or_default().into(),
            );
        }
        if !origin.is_empty() {
            self.add("sillytavern", id, origin);
        }
    }

    fn meta(&mut self, data: &Object) {
        let mut meta = Table::new();
        for (key, source) in [("creator", "creator"), ("version", "character_version")] {
            let value = string(data.get(source));
            if !value.is_empty() {
                meta.insert(key.to_string(), value.into());
            }
        }
        // Some cards give their tags as one comma-separated text. Tags are kept
        // in lower case, as the Flutter app keeps them.
        let tags = match data.get("tags") {
            Some(Json::String(tags)) => tags.split(',').map(str::to_string).collect(),
            other => strings(other),
        };
        let mut seen = HashSet::new();
        let tags: Vec<String> = tags
            .iter()
            .map(|tag| tag.trim().to_lowercase())
            .filter(|tag| !tag.is_empty() && seen.insert(tag.clone()))
            .collect();
        if !tags.is_empty() {
            meta.insert("tags".to_string(), list(tags));
        }
        let sources = strings(data.get("source"));
        if let [source] = sources.as_slice() {
            meta.insert("source".to_string(), source.as_str().into());
        } else if !sources.is_empty() {
            meta.insert("source".to_string(), list(sources));
        }
        for (key, source) in [
            ("created", "creation_date"),
            ("modified", "modification_date"),
        ] {
            if let Some(date) = date(data.get(source)) {
                meta.insert(key.to_string(), date);
            }
        }
        if !meta.is_empty() {
            self.root
                .insert("meta-info".to_string(), Value::Table(meta));
        }
    }

    /// The creator's notes, one block per language. Returns the one the card
    /// points at: the note without a language, else the English one, else the first.
    fn creator_notes(&mut self, id: &str, data: &Object) -> Option<String> {
        let plain = self.text("creator-note", id, &string(data.get("creator_notes")));
        let mut translated = Vec::new();
        if let Some(Json::Object(notes)) = data.get("creator_notes_multilingual") {
            for (language, text) in notes {
                let (language, text) = (language.trim(), string(Some(text)));
                if !text.is_empty() {
                    let mut block = table([("text", text.into())]);
                    if !language.is_empty() {
                        block.insert("language".to_string(), language.into());
                    }
                    let note_id = format!("{id}-{}", slug_or(language, "translated"));
                    translated.push((language, self.add("creator-note", &note_id, block)));
                }
            }
        }
        let english = translated
            .iter()
            .position(|(language, _)| language.to_ascii_lowercase().starts_with("en"));
        plain.or_else(|| {
            translated
                .into_iter()
                .nth(english.unwrap_or(0))
                .map(|(_, reference)| reference)
        })
    }

    /// The card's embedded lorebook; `None` when it has no entries.
    fn lorebook(&mut self, id: &str, book: &Object) -> Option<String> {
        let Some(Json::Array(entries)) = book.get("entries") else {
            if book
                .get("entries")
                .is_some_and(|entries| !entries.is_null())
            {
                self.notes.push(ImportNote::EntriesNotAList);
            }
            return None;
        };
        let entries: Vec<String> = entries
            .iter()
            .filter_map(Json::as_object)
            .map(|entry| self.lore(id, entry))
            .collect();
        if entries.is_empty() {
            return None;
        }
        if self.outlets > 0 {
            let count = self.outlets;
            self.notes.push(ImportNote::OutletEntriesOff { count });
        }
        let mut lorebook = Table::new();
        for key in ["name", "description"] {
            let value = string(book.get(key));
            if !value.is_empty() {
                lorebook.insert(key.to_string(), value.into());
            }
        }
        for (key, source) in [
            ("scan-depth", "scan_depth"),
            ("token-budget", "token_budget"),
        ] {
            if let Some(count) = int(book.get(source)).filter(|n| *n > 0) {
                lorebook.insert(key.to_string(), count.into());
            }
        }
        if flag(book.get("recursive_scanning")) == Some(true) {
            lorebook.insert("recursive-scanning".to_string(), true.into());
        }
        lorebook.insert("entries".to_string(), list(entries));
        Some(self.add("lorebook", id, lorebook))
    }

    /// One lorebook entry (spec sections 3.3.2 and 6.1).
    fn lore(&mut self, id: &str, entry: &Object) -> String {
        let entry = Entry {
            fields: entry,
            extensions: entry.get("extensions").and_then(Json::as_object),
        };
        let keywords = strings(entry.fields.get("keys"));
        let name = [
            string(entry.fields.get("comment")),
            string(entry.fields.get("name")),
        ]
        .into_iter()
        .find(|n| !n.is_empty());
        let lore_id = [name.as_deref(), keywords.first().map(String::as_str)]
            .into_iter()
            .flatten()
            .map(slug)
            .find(|id| !id.is_empty())
            .unwrap_or_else(|| "entry".to_string());

        let mut lore = Table::new();
        if let Some(name) = name {
            lore.insert("name".to_string(), name.into());
        }
        entry.matching(&mut lore, keywords);
        // An outlet entry shows only where a prompt asks for it by name, which no prompt here does.
        let outlet = entry.placed(7, "outlet");
        if outlet || flag(entry.fields.get("enabled")) == Some(false) {
            lore.insert("enabled".to_string(), false.into());
        }
        entry.placement(&mut lore);
        entry.character_filter(&mut lore);
        lore.insert(
            "text".to_string(),
            string(entry.fields.get("content")).into(),
        );
        self.outlets += usize::from(outlet);
        self.add("lore", &format!("{id}-{lore_id}"), lore)
    }

    /// The card's files besides its picture (V3 `assets`). Embedded ones become
    /// assets of the CCV4 card; links are noted, not followed. Returns the
    /// `asset://` reference of the character's icon, unless that is the picture itself.
    fn embedded_assets(
        &mut self,
        id: &str,
        data: &Object,
        chunks: &[png::Text<'_>],
    ) -> Option<String> {
        let carried = carried_files(chunks);
        let items = match data.get("assets") {
            Some(Json::Array(items)) => items.as_slice(),
            _ => &[],
        };
        // What became of each carried file an item asked for: its reference, or nothing
        // when it is missing or unreadable. Items may share a file, which is kept once.
        let mut asked: HashMap<String, Option<String>> = HashMap::new();
        let mut stems: HashMap<String, usize> = HashMap::new();
        let (mut main_icon, mut first_icon, mut picture_is_icon) = (None, None, false);
        for item in items.iter().filter_map(Json::as_object) {
            let field = |key: &str| string(item.get(key));
            let (kind, name, uri) = (field("type"), field("name"), field("uri"));
            if uri.is_empty() || uri == "ccdefault:" {
                picture_is_icon |= kind == "icon";
                continue;
            }
            let (kind_id, name_id) = (slug_or(&kind, "other"), slug_or(&name, "asset"));
            let element_id = format!("{id}-{kind_id}-{name_id}");
            let mut element = Table::new();
            for (key, value) in [("kind", &kind), ("name", &name)] {
                if !value.is_empty() {
                    element.insert(key.to_string(), value.as_str().into());
                }
            }
            let (carried_path, inline) = (uri.strip_prefix("__asset:"), uri.strip_prefix("data:"));
            let reference = if let Some(known) = carried_path.and_then(|path| asked.get(path)) {
                known.clone()
            } else if carried_path.is_some() || inline.is_some() {
                let bytes = match carried_path {
                    Some(path) => carried.get(path).and_then(|text| unbase64(text)),
                    None => inline
                        .and_then(|inline| inline.split_once(";base64,"))
                        .and_then(|(_, text)| unbase64(text.as_bytes())),
                };
                let reference = bytes.map(|bytes| {
                    let stem = format!("card/assets/{kind_id}/{name_id}");
                    self.store_asset(&mut stems, stem, &field("ext"), bytes)
                });
                if let Some(path) = carried_path {
                    asked.insert(path.to_string(), reference.clone());
                }
                reference
            } else {
                self.notes.push(ImportNote::AssetOnlyLinked {
                    kind: kind.clone(),
                    name: name.clone(),
                });
                element.insert("uri".to_string(), uri.into());
                self.add("asset", &element_id, element);
                continue;
            };
            let Some(reference) = reference else {
                self.notes.push(ImportNote::AssetUnreadable {
                    kind: kind.clone(),
                    name: name.clone(),
                });
                continue;
            };
            if kind == "icon" {
                if name == "main" {
                    main_icon.get_or_insert(reference.clone());
                }
                first_icon.get_or_insert(reference.clone());
            }
            element.insert("file".to_string(), reference.into());
            self.add("asset", &element_id, element);
        }
        let unlisted = carried
            .keys()
            .filter(|path| !asked.contains_key(**path))
            .count();
        if unlisted > 0 {
            self.notes
                .push(ImportNote::UnlistedFiles { count: unlisted });
        }
        // The icon named `main` is the character's; without one the picture is, if the card calls it an icon.
        main_icon.or(if picture_is_icon { None } else { first_icon })
    }

    /// Keeps an embedded file as `<stem>.<extension>`, numbered when the name is
    /// taken (`stems` counts each name's uses), and returns its `asset://` reference.
    fn store_asset(
        &mut self,
        stems: &mut HashMap<String, usize>,
        stem: String,
        extension: &str,
        bytes: Vec<u8>,
    ) -> String {
        let extension = Some(extension.to_ascii_lowercase())
            .filter(|extension| is_extension(extension))
            .unwrap_or_else(|| "bin".to_string());
        // An underscore never comes out of `slug`, so a numbered name is free.
        let uses = stems.entry(stem.clone()).or_insert(0);
        *uses += 1;
        let numbered = if *uses == 1 {
            stem
        } else {
            format!("{stem}_{uses}")
        };
        let file = format!("{numbered}.{extension}");
        let reference = format!("asset://{file}");
        self.assets.push((file, bytes));
        reference
    }
}

/// The files the PNG carries in chunks of their own, by the path a card's
/// `assets` items name them with.
fn carried_files<'c>(chunks: &'c [png::Text<'_>]) -> HashMap<&'c str, &'c [u8]> {
    let mut carried: HashMap<&str, &[u8]> = HashMap::new();
    for (keyword, text) in chunks {
        if let Some(path) = keyword.strip_prefix(ASSET_CHUNK) {
            carried
                .entry(path.strip_prefix(':').unwrap_or(path))
                .or_insert(*text);
        }
    }
    carried
}

/// A SillyTavern lorebook entry being read.
struct Entry<'a> {
    fields: &'a Object,
    extensions: Option<&'a Object>,
}

impl<'a> Entry<'a> {
    /// A setting, on the entry or else in its extensions: tools disagree on which
    /// sit where.
    fn find(&self, key: &str) -> Option<&'a Json> {
        self.fields
            .get(key)
            .filter(|v| !v.is_null())
            .or_else(|| self.extensions?.get(key))
    }

    /// Whether the entry goes where SillyTavern's `number` or `name` puts it.
    fn placed(&self, number: i64, name: &str) -> bool {
        [
            self.fields.get("position"),
            self.extensions.and_then(|e| e.get("position")),
        ]
        .into_iter()
        .any(|position| match position {
            Some(Json::String(text)) => {
                text.replace('_', "").eq_ignore_ascii_case(name)
                    || text.trim().parse() == Ok(number)
            }
            other => int(other) == Some(number),
        })
    }

    /// The keywords and how they are matched, and what triggers the entry.
    fn matching(&self, lore: &mut Table, keywords: Vec<String>) {
        let mut set = |key: &str, value: Value| {
            lore.insert(key.to_string(), value);
        };
        let (entry, find) = (self.fields, |key: &str| self.find(key));
        let secondary = strings(entry.get("secondary_keys"));
        set("keywords", list(keywords));
        let selective = flag(entry.get("selective")) == Some(true) && !secondary.is_empty();
        if !secondary.is_empty() {
            set("secondary-keywords", list(secondary));
        }
        if selective {
            set("selective", true.into());
            let logic = match int(find("selectiveLogic")) {
                Some(1) => Some("not-all"),
                Some(2) => Some("not-any"),
                Some(3) => Some("and-all"),
                _ => None,
            };
            if let Some(logic) = logic {
                set("selective-logic", logic.into());
            }
        }
        for (key, source) in [
            ("use-regex", "use_regex"),
            ("case-sensitive", "case_sensitive"),
            ("match-whole-words", "match_whole_words"),
            ("ignore-budget", "ignore_budget"),
        ] {
            if flag(find(source)) == Some(true) {
                set(key, true.into());
            }
        }
        if flag(entry.get("constant")) == Some(true) {
            set("trigger", "always".into());
        } else if flag(find("vectorized")) == Some(true) {
            set("trigger", "vector".into());
        }
    }

    /// The entry's order, chance, timing and scan depth, and its depth in the chat.
    fn placement(&self, lore: &mut Table) {
        let mut set = |key: &str, value: Value| {
            lore.insert(key.to_string(), value);
        };
        let (entry, find) = (self.fields, |key: &str| self.find(key));
        if let Some(priority) = int(entry.get("priority")).filter(|n| *n != 0) {
            set("priority", priority.into());
        }
        let order = int(entry.get("insertion_order")).unwrap_or(DEFAULT_INSERTION_ORDER);
        if order != 0 {
            set("insertion-order", order.into());
        }
        if flag(find("useProbability")) != Some(false)
            && let Some(percent) = int(find("probability")).filter(|n| *n < 100)
        {
            set("probability", percent.max(0).into());
        }
        for key in ["sticky", "cooldown", "delay"] {
            if let Some(count) = int(find(key)).filter(|n| *n > 0) {
                set(key, count.into());
            }
        }
        // How many messages are read for this entry's keys, where it says so itself.
        if let Some(depth) = int(find("scan_depth")).filter(|n| *n > 0) {
            set("scan-depth", depth.into());
        }
        // Position 4 puts the entry into the chat instead of the lorebook's place in the prompt.
        if self.placed(4, "atdepth") {
            set(
                "depth",
                int(find("depth")).unwrap_or(DEFAULT_DEPTH).max(0).into(),
            );
            if let Some(role) = role(find("role")) {
                set("role", role.into());
            }
        }
    }

    /// Which characters the entry is for, or not for.
    fn character_filter(&self, lore: &mut Table) {
        let Some(Json::Object(filter)) = self.find("character_filter") else {
            return;
        };
        let (names, tags) = (strings(filter.get("names")), strings(filter.get("tags")));
        if !names.is_empty() || !tags.is_empty() {
            let exclude = flag(filter.get("is_exclude")) == Some(true);
            let filter = table([
                ("names", list(names)),
                ("tags", list(tags)),
                ("exclude", exclude.into()),
            ]);
            lore.insert("character-filter".to_string(), Value::Table(filter));
        }
    }
}

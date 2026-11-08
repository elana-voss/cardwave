//! The way back: one character of a CCV4 card written as a SillyTavern card.
//!
//! The card is one JSON object, base64-encoded in two `tEXt` chunks of the
//! picture: `ccv3` (Character Card V3) and `chara`, the same data as V2 for the
//! tools that read only that. The files the card lists travel in chunks of
//! their own. A card that came from SillyTavern goes back as it came.
//!
//! A SillyTavern card is one character with one lorebook and one note at a
//! depth. Of a card that has more, the rest stays behind: the other characters,
//! the finer order of the prompt, all but the first note at a depth, and files
//! that neither an `asset` element nor the character's picture names. Several
//! lorebooks become one.

use std::collections::HashSet;

use anyhow::Context;
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_core::{Code, Fail};
use cw_prompt::{Character, Role};
use serde_json::{Value as Json, json};
use toml::{Table, Value};

use crate::png::{self, Container};
use crate::sillytavern::{
    ASSET_CHUNK, DEFAULT_DEPTH, DEFAULT_TALKATIVENESS, Object, float, int, is_card_chunk,
    is_extension, role, string,
};
use crate::{Document, mapping, saved_at, strings as listed};

/// Writes the character `id` of `card`, its first one when none is named, as a
/// SillyTavern card file.
pub fn export(card: &Container, id: Option<&str>) -> anyhow::Result<Vec<u8>> {
    let document = Document::parse(&card.toml)?;
    let id = match id {
        Some(id) => id,
        None => document.characters().first().copied().context(
            Fail::said(Code::NotPossible, "the card has no character to export")
                .with("what", "export_no_character"),
        )?,
    };
    let character = document.character(id).with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("the card has no character {id:?}"),
        )
        .with("what", "card_character")
    })?;
    let (data, files) = card_data(&document, id, character, card);

    let chunk = |keyword: &str, spec: &str, version: &str| {
        let card = json!({ "spec": spec, "spec_version": version, "data": &data });
        (
            keyword.to_string(),
            STANDARD.encode(card.to_string()).into_bytes(),
        )
    };
    let mut chunks = vec![
        chunk("chara", "chara_card_v2", "2.0"),
        chunk("ccv3", "chara_card_v3", "3.0"),
    ];
    chunks.extend(files);
    // A picture that still carries a card of its own would end up with two.
    let (picture, _) = png::take_text(&card.image, is_card_chunk)?;
    png::add_text(&picture, &chunks)
}

/// The card's `data`, as both chunks carry it, and the chunks of the files it
/// lists.
fn card_data(
    document: &Document,
    id: &str,
    character: &Table,
    card: &Container,
) -> (Object, Vec<(String, Vec<u8>)>) {
    // What the model is told of the character is what the card says of it.
    let told = mapping::character(document, id).unwrap_or_default();
    let texts = |key: &str| -> Vec<&str> {
        listed(character.get(key))
            .into_iter()
            .filter_map(|reference| document.text(reference))
            .map(str::trim)
            .filter(|text| !text.is_empty())
            .collect()
    };
    let mut greetings = texts("greetings");
    let first_greeting = if greetings.is_empty() {
        ""
    } else {
        greetings.remove(0)
    };
    let version = match document.meta("version") {
        Some(Value::String(version)) => version.trim().to_string(),
        Some(version @ (Value::Integer(_) | Value::Float(_))) => version.to_string(),
        _ => String::new(),
    };
    let (note, translated) = creator_notes(document, character);

    let mut data = Object::new();
    let mut put = |key: &str, value: Json| {
        data.insert(key.to_string(), value);
    };
    put("name", told.name.as_str().into());
    if let Some(nickname) = &told.nickname {
        put("nickname", nickname.as_str().into());
    }
    put("description", told.description.as_str().into());
    put("personality", told.personality.as_str().into());
    put("scenario", told.scenario.as_str().into());
    put("first_mes", first_greeting.into());
    put("mes_example", told.mes_example.as_str().into());
    put("creator_notes", note.into());
    put("system_prompt", told.system_prompt.as_str().into());
    put(
        "post_history_instructions",
        told.post_history_instructions.as_str().into(),
    );
    put("alternate_greetings", greetings.into());
    put("group_only_greetings", texts("group-greetings").into());
    put("tags", document.tags().into());
    put("creator", document.creator().unwrap_or("").into());
    put("character_version", version.into());
    if !translated.is_empty() {
        put("creator_notes_multilingual", Json::Object(translated));
    }
    let sources = match document.meta("source") {
        Some(Value::String(source)) => vec![source.as_str()],
        other => listed(other),
    };
    if !sources.is_empty() {
        put("source", sources.into());
    }
    for (key, source) in [
        ("creation_date", "created"),
        ("modification_date", "modified"),
    ] {
        // Seconds since 1970.
        let stamp = saved_at(document.meta(source));
        if stamp > 0 {
            put(key, (stamp / 1000).into());
        }
    }
    put("extensions", Json::Object(extensions(document, id, &told)));
    if let Some(book) = lorebook(document, character) {
        put("character_book", book);
    }
    let (items, files) = assets(document, id, card);
    if !items.is_empty() {
        put("assets", items.into());
    }
    (data, files)
}

/// A block's text without the line breaks TOML's `"""` blocks leave around it.
fn text_of(block: &Table) -> &str {
    block
        .get("text")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
}

/// The creator's notes: the one the character points at, unless it is a
/// translation, and all translations by their language.
fn creator_notes<'a>(document: &'a Document, character: &Table) -> (&'a str, Object) {
    let language = |block: &'a Table| {
        block
            .get("language")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|l| !l.is_empty())
    };
    let own = character
        .get("creator-note")
        .and_then(Value::as_str)
        .and_then(|reference| document.lookup(reference))
        .filter(|block| language(block).is_none())
        .map_or("", text_of);
    let mut translated = Object::new();
    for id in document.ids("creator-note") {
        if let Some(block) = document.element("creator-note", id)
            && let Some(language) = language(block)
        {
            translated.insert(language.to_string(), text_of(block).into());
        }
    }
    (own, translated)
}

/// The card's `extensions`: as they came, for a card from SillyTavern. The two
/// values CCV4 keeps itself (how talkative the character is in a group, and its
/// note at a depth) are written anew only where they no longer say the same.
fn extensions(document: &Document, id: &str, told: &Character) -> Object {
    let mut kept: Object = document
        .element("sillytavern", id)
        .and_then(|origin| origin.get("extensions")?.as_str())
        .and_then(|text| serde_json::from_str(text).ok())
        .unwrap_or_default();

    let talkativeness = document.talkativeness(id);
    let kept_talkativeness =
        float(kept.get("talkativeness")).map_or(DEFAULT_TALKATIVENESS, |n| n.clamp(0.0, 1.0));
    if kept_talkativeness != talkativeness {
        kept.insert("talkativeness".to_string(), talkativeness.into());
    }

    let note = told.depth_prompts.first().map(|note| {
        let role = match note.role {
            Role::System => "system",
            Role::User => "user",
            Role::Assistant => "assistant",
        };
        (note.prompt.clone(), note.depth as i64, role)
    });
    let kept_note = kept
        .get("depth_prompt")
        .and_then(Json::as_object)
        .and_then(|note| {
            let text = string(note.get("prompt"));
            let depth = int(note.get("depth")).unwrap_or(DEFAULT_DEPTH).max(0);
            (!text.is_empty()).then(|| (text, depth, role(note.get("role")).unwrap_or("system")))
        });
    if kept_note != note {
        match note {
            Some((prompt, depth, role)) => {
                kept.insert(
                    "depth_prompt".to_string(),
                    json!({ "prompt": prompt, "depth": depth, "role": role }),
                );
            }
            None => _ = kept.remove("depth_prompt"),
        }
    }
    kept
}

/// The lorebook `book` of `document` as SillyTavern's lorebook of a card (a
/// "character book"), which SillyTavern and the library import as a lorebook;
/// one without entries has its name alone.
pub fn world(document: &Document, book: &str) -> Json {
    let mut character = Table::new();
    character.insert("lorebooks".into(), Value::Array(vec![book.into()]));
    lorebook(document, &character).unwrap_or_else(|| {
        let name = document
            .lookup(book)
            .and_then(|book| book.get("name")?.as_str());
        json!({ "name": name.unwrap_or_default(), "extensions": {}, "entries": [] })
    })
}

/// The character's lorebooks as the one book a SillyTavern card has; `None`
/// without entries. Budgets add up, and one book without a budget lifts the
/// limit, as in a chat.
fn lorebook(document: &Document, character: &Table) -> Option<Json> {
    let mut book = Object::new();
    let mut entries = Vec::new();
    let mut seen = HashSet::new();
    let (mut scan_depth, mut budget, mut recursive) = (None::<i64>, Some(0i64), false);
    for reference in listed(character.get("lorebooks")) {
        let Some(source) = document.lookup(reference) else {
            continue;
        };
        for key in ["name", "description"] {
            // A block without a name is named by its ID, which comes back as its name.
            let own = (key == "name").then(|| id_of(reference)).flatten();
            if let Some(text) = source.get(key).and_then(Value::as_str).or(own)
                && !book.contains_key(key)
            {
                book.insert(key.to_string(), text.into());
            }
        }
        let count = |key: &str| {
            source
                .get(key)
                .and_then(Value::as_integer)
                .filter(|n| *n > 0)
        };
        scan_depth = scan_depth.max(count("scan-depth"));
        budget = budget
            .zip(count("token-budget"))
            .map(|(sum, more)| sum.saturating_add(more));
        recursive |= source.get("recursive-scanning").and_then(Value::as_bool) == Some(true);
        for entry in listed(source.get("entries")) {
            if let Some(lore) = document.lookup(entry)
                && seen.insert(entry)
            {
                entries.push(lore_entry(entries.len(), lore));
            }
        }
    }
    if entries.is_empty() {
        return None;
    }
    if let Some(depth) = scan_depth {
        book.insert("scan_depth".to_string(), depth.into());
    }
    if let Some(budget) = budget {
        book.insert("token_budget".to_string(), budget.into());
    }
    if recursive {
        book.insert("recursive_scanning".to_string(), true.into());
    }
    book.insert("extensions".to_string(), json!({}));
    book.insert("entries".to_string(), entries.into());
    Some(Json::Object(book))
}

/// The ID of the block a reference (`lore.lamp`) names.
fn id_of(reference: &str) -> Option<&str> {
    reference.split_once('.').map(|(_, id)| id)
}

/// One `lore` block as a lorebook entry: the import's mapping read backwards.
/// One without a name gets no comment, which would name it on the way back.
/// What SillyTavern itself keeps in an entry's `extensions` goes there.
fn lore_entry(index: usize, lore: &Table) -> Json {
    let flag = |key: &str| lore.get(key).and_then(Value::as_bool) == Some(true);
    let count = |key: &str| lore.get(key).and_then(Value::as_integer);
    let trigger = lore.get("trigger").and_then(Value::as_str);
    let secondary = listed(lore.get("secondary-keywords"));

    let mut extensions = Object::new();
    let mut extend = |key: &str, value: Json| {
        extensions.insert(key.to_string(), value);
    };
    let logic = match lore.get("selective-logic").and_then(Value::as_str) {
        Some("not-all") => Some(1),
        Some("not-any") => Some(2),
        Some("and-all") => Some(3),
        _ => None,
    };
    if let Some(logic) = logic {
        extend("selectiveLogic", logic.into());
    }
    for (key, source) in [
        ("case_sensitive", "case-sensitive"),
        ("match_whole_words", "match-whole-words"),
        ("ignore_budget", "ignore-budget"),
    ] {
        if flag(source) {
            extend(key, true.into());
        }
    }
    if trigger == Some("vector") {
        extend("vectorized", true.into());
    }
    if let Some(percent) = count("probability") {
        extend("probability", percent.into());
        extend("useProbability", true.into());
    }
    for key in ["sticky", "cooldown", "delay"] {
        if let Some(turns) = count(key) {
            extend(key, turns.into());
        }
    }
    if let Some(depth) = count("scan-depth") {
        extend("scan_depth", depth.into());
    }
    // An entry with a depth goes into the chat: SillyTavern's position 4.
    if let Some(depth) = count("depth") {
        extend("position", 4.into());
        extend("depth", depth.into());
        let role = match lore.get("role").and_then(Value::as_str) {
            Some("user") => 1,
            Some("assistant") => 2,
            _ => 0,
        };
        extend("role", role.into());
    }
    if let Some(filter) = lore.get("character-filter").and_then(Value::as_table) {
        let exclude = filter.get("exclude").and_then(Value::as_bool) == Some(true);
        extend(
            "character_filter",
            json!({ "names": listed(filter.get("names")), "tags": listed(filter.get("tags")), "is_exclude": exclude }),
        );
    }

    let mut entry = Object::new();
    let mut put = |key: &str, value: Json| {
        entry.insert(key.to_string(), value);
    };
    put("id", index.into());
    put("keys", listed(lore.get("keywords")).into());
    if !secondary.is_empty() {
        put("secondary_keys", secondary.into());
    }
    if let Some(name) = lore.get("name").and_then(Value::as_str) {
        put("comment", name.into());
        put("name", name.into());
    }
    put("content", text_of(lore).into());
    put(
        "enabled",
        (lore.get("enabled").and_then(Value::as_bool) != Some(false)).into(),
    );
    put(
        "insertion_order",
        count("insertion-order").unwrap_or(0).into(),
    );
    put("constant", (trigger == Some("always")).into());
    put("selective", flag("selective").into());
    put("use_regex", flag("use-regex").into());
    if flag("case-sensitive") {
        put("case_sensitive", true.into());
    }
    if let Some(priority) = count("priority") {
        put("priority", priority.into());
    }
    put("extensions", Json::Object(extensions));
    Json::Object(entry)
}

/// The card's files as a V3 card lists them: those its `asset` elements name,
/// and the character's picture where none of them is it. Returns the list and
/// the chunks that carry the files.
fn assets(document: &Document, id: &str, card: &Container) -> (Vec<Json>, Vec<(String, Vec<u8>)>) {
    let avatar = document.avatar(id);
    // The files carried along; an item names one by its place here.
    let mut carried: Vec<&[u8]> = Vec::new();
    let mut places: Vec<&str> = Vec::new();
    let mut carry = |file: &str| -> Option<String> {
        let (name, data) = card.assets.iter().find(|(name, _)| name == file)?;
        let place = places
            .iter()
            .position(|known| *known == name)
            .unwrap_or_else(|| {
                places.push(name);
                carried.push(data);
                places.len() - 1
            });
        Some(format!("__asset:{place}"))
    };
    let item = |kind: &str, name: &str, uri: &str, extension: &str| json!({ "type": kind, "name": name, "uri": uri, "ext": extension });

    let mut items = Vec::new();
    let mut avatar_listed = false;
    for element in document
        .ids("asset")
        .into_iter()
        .filter_map(|id| document.element("asset", id))
    {
        let field = |key: &str| element.get(key).and_then(Value::as_str).unwrap_or("");
        let (kind, name, link) = (field("kind"), field("name"), field("uri"));
        let file = field("file").strip_prefix("asset://");
        match file {
            Some(file) => {
                // A file the card no longer holds is left out.
                let Some(uri) = carry(file) else { continue };
                let listed = item(kind, name, &uri, &extension(file));
                // The character's picture leads: without an icon named `main`, the first icon is it.
                if !avatar_listed && avatar == Some(file) {
                    avatar_listed = true;
                    items.insert(0, listed);
                } else {
                    items.push(listed);
                }
            }
            None if !link.is_empty() => items.push(item(kind, name, link, &extension(link))),
            None => {}
        }
    }
    if !avatar_listed {
        match avatar.and_then(|file| Some((carry(file)?, file))) {
            Some((uri, file)) => items.insert(0, item("icon", "main", &uri, &extension(file))),
            // The card's picture is the character's, which a list of files has to say.
            None if !items.is_empty() => items.insert(0, item("icon", "main", "ccdefault:", "png")),
            None => {}
        }
    }
    let files = carried
        .iter()
        .enumerate()
        .map(|(place, data)| {
            (
                format!("{ASSET_CHUNK}:{place}"),
                STANDARD.encode(data).into_bytes(),
            )
        })
        .collect();
    (items, files)
}

/// A file's extension as a V3 card gives it; `unknown` when the name shows none.
fn extension(name: &str) -> String {
    name.rsplit('/')
        .next()
        .and_then(|last| last.rsplit_once('.'))
        .map(|(_, extension)| extension.to_ascii_lowercase())
        .filter(|extension| is_extension(extension))
        .unwrap_or_else(|| "unknown".to_string())
}

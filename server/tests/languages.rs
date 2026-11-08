//! A card translated ("Translate…" of its menu, kept as a whole): the card
//! holds the new language beside its first, as CCV4 has it (a character of
//! that language naming blocks with the `language` key), each text a draft
//! "translated"; the page reads and edits either language; a chat uses the
//! card in the language the AI writes in (Settings) where the card has it,
//! and where it has not, the AI is told to write in it. Over HTTP the card's
//! own lorebook is translated by the background model, a few entries at once.

mod common;

use common::Scratch;
use common::api::{Api, JSON, says};
use common::server::start;
use cw_ccv4::languages::{self, LoreText, TranslatedText, Translation};
use cw_ccv4::png::{self, Container};
use cw_chat::chats::{self, NewChat};
use cw_library::cards;
use cw_library::settings::{self, ChangeSettings};
use serde_json::json;

/// A text in German, by the block it translates.
fn german(reference: &str, text: &str) -> TranslatedText {
    TranslatedText {
        reference: reference.to_string(),
        text: text.to_string(),
    }
}

/// The sample card's translation into German, made of its version `version`: two texts and one entry.
fn translation(version: i64) -> Translation {
    Translation {
        version,
        language: "de".to_string(),
        texts: vec![
            german(
                "description.mira",
                "Hüterin des Nordlichts. {{char}} zählt Schiffe.",
            ),
            german(
                "greeting.door",
                "„Du hast dir eine Nacht ausgesucht, {{user}}.“",
            ),
        ],
        creator_notes: Some("Nie an das Modell gesendet.".to_string()),
        lore: vec![LoreText {
            reference: "lore.wreck".to_string(),
            text: "Die Asta sank hier 1911.".to_string(),
            keywords: vec!["Wrack".to_string()],
            secondary_keywords: Vec::new(),
        }],
    }
}

/// Sets the language the AI writes in.
fn writes_in(scratch: &Scratch, language: &str) {
    let change = ChangeSettings {
        language: Some(language.to_string()),
        ..Default::default()
    };
    settings::change(&scratch.db, scratch.user, &change).unwrap();
}

#[test]
fn a_kept_translation_is_a_language_of_the_card_with_texts_of_its_own() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let before = cards::editable(db, me, card.card_id, None).unwrap();
    // A card in one language names it, so that a translation can say what it is from.
    let names: Vec<&str> = before
        .languages
        .iter()
        .map(|one| one.name.as_str())
        .collect();
    assert_eq!(names, ["English"]);

    let saved = cards::translate(db, me, card.card_id, &translation(card.version)).unwrap();
    assert_eq!(saved.number, card.version + 1);

    // The card's first language is told by its words; the page names both.
    let first = cards::editable(db, me, card.card_id, None).unwrap();
    let names: Vec<&str> = first
        .languages
        .iter()
        .map(|one| one.name.as_str())
        .collect();
    assert_eq!(names, ["English", "German"]);
    assert_eq!(first.language, None);
    assert_eq!(
        first.characters[0].description[0].text,
        "Keeper of the north light. {{char}} counts ships."
    );

    let shown = cards::editable(db, me, card.card_id, Some("de")).unwrap();
    assert_eq!(shown.language.as_deref(), Some("de"));
    let one = &shown.characters[0];
    assert_eq!(
        one.description[0].text,
        "Hüterin des Nordlichts. {{char}} zählt Schiffe."
    );
    assert_eq!(
        one.greetings[0].text,
        "„Du hast dir eine Nacht ausgesucht, {{user}}.“"
    );
    // A text not translated is copied as it was; the name is the one both share.
    assert_eq!(one.greetings[1].text, "Hold the lamp. Don't ask.");
    assert_eq!(one.name, "Mira");
    assert_eq!(one.creator_notes, "Nie an das Modell gesendet.");
    let reference = one.description[0].reference.clone().unwrap();
    assert_eq!(reference, "description.mira-de");
    let history = cards::drafts(db, me, card.card_id, &reference).unwrap();
    let made: Vec<&str> = history.drafts.iter().map(|one| one.made.as_str()).collect();
    assert_eq!(made, ["translated"]);

    // An edit of the German text changes it alone, with a draft of its own.
    let mut edit = shown.clone();
    edit.version = saved.number;
    edit.characters[0].description[0].text = "Hüterin des Lichts.".to_string();
    cards::edit(db, me, card.card_id, &edit).unwrap();
    let after = cards::editable(db, me, card.card_id, Some("de")).unwrap();
    assert_eq!(
        after.characters[0].description[0].text,
        "Hüterin des Lichts."
    );
    let first = cards::editable(db, me, card.card_id, None).unwrap();
    assert_eq!(
        first.characters[0].description[0].text,
        "Keeper of the north light. {{char}} counts ships."
    );
    let history = cards::drafts(db, me, card.card_id, &reference).unwrap();
    assert_eq!(history.drafts.len(), 2);

    // A language the card is in, and one the app does not know, are refused; so is a stale translation.
    let mut again = translation(after.version);
    let refused = cards::translate(db, me, card.card_id, &again).unwrap_err();
    assert_eq!(refused.to_string(), "the card is in German already");
    again.language = "en".to_string();
    assert!(cards::translate(db, me, card.card_id, &again).is_err());
    again.language = "xx".to_string();
    assert!(cards::translate(db, me, card.card_id, &again).is_err());
    let stale = Translation {
        language: "fr".to_string(),
        ..translation(card.version)
    };
    assert!(cards::translate(db, me, card.card_id, &stale).is_err());
}

#[test]
fn a_chat_uses_the_card_in_the_language_the_ai_writes_in() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    cards::translate(db, me, card.card_id, &translation(card.version)).unwrap();
    let version = cards::newest(db, me, card.card_id).unwrap().0.version_id;
    let start = || {
        let new = NewChat {
            characters: &[(version, "mira")],
            persona_id: None,
            greeting: 0,
        };
        chats::create(db, me, &new).unwrap()
    };

    writes_in(&scratch, "de");
    let chat = start();
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert_eq!(
        inputs.state.messages[0].content,
        "„Du hast dir eine Nacht ausgesucht, Guest.“"
    );
    assert!(
        inputs
            .character
            .description
            .contains("Hüterin des Nordlichts."),
        "{}",
        inputs.character.description
    );
    let lore = inputs.character.lorebook.as_ref().unwrap();
    let wreck = lore
        .entries
        .iter()
        .find(|entry| entry.content.contains("Asta"))
        .unwrap();
    assert_eq!(wreck.content, "Die Asta sank hier 1911.");
    assert_eq!(wreck.keys, ["Wrack"]);
    // The card is in the language the AI writes in: it is told nothing more.
    assert!(
        !inputs
            .character
            .post_history_instructions
            .contains("Write your replies")
    );

    writes_in(&scratch, "en");
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert!(
        inputs
            .character
            .description
            .contains("Keeper of the north light.")
    );
    assert!(
        !inputs
            .character
            .post_history_instructions
            .contains("Write your replies")
    );

    // A language the card is not in: the card's first, and the AI is told to write in it.
    writes_in(&scratch, "fr");
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert!(
        inputs
            .character
            .description
            .contains("Keeper of the north light.")
    );
    assert!(
        inputs
            .character
            .post_history_instructions
            .ends_with("Write your replies in French."),
        "{}",
        inputs.character.post_history_instructions
    );
    let chat = start();
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert_eq!(
        inputs.state.messages[0].content,
        "\"You picked a night for it, Guest.\""
    );

    let refused = ChangeSettings {
        language: Some("Klingon".to_string()),
        ..Default::default()
    };
    assert!(settings::change(db, me, &refused).is_err());
}

#[tokio::test]
async fn the_cards_own_lorebook_is_translated_by_the_background_model() {
    let api = Api::start(says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": "Wrack" } }] }).to_string(),
    ))
    .await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "big-1", "worker_model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (status, card) = server.upload("/api/cards", common::card_file()).await;
    assert_eq!(status, 201, "{card}");
    let id = &card["card_id"];

    let (status, entries) = server
        .post(
            &format!("/api/cards/{id}/lore-translation"),
            json!({ "language": "de" }),
        )
        .await;
    assert_eq!(status, 200, "{entries}");
    // Each entry with words, its words and its keywords; one that is always used has none to translate.
    let references: Vec<&str> = entries
        .as_array()
        .unwrap()
        .iter()
        .map(|one| one["reference"].as_str().unwrap())
        .collect();
    assert_eq!(references, ["lore.wreck", "lore.lamp", "lore.off"]);
    assert_eq!(entries[0]["keywords"], json!(["Wrack"]));
    assert_eq!(entries[1]["keywords"], json!([]));
    assert_eq!(api.asked().len(), 5);
    let prompt = api.asked()[0].body.clone();
    assert!(prompt.contains("Translate it into German."), "{prompt}");

    let (status, languages) = server.get("/api/languages").await;
    assert_eq!(status, 200);
    assert_eq!(languages[1], json!({ "code": "de", "name": "German" }));
}

/// A card of `blocks` alone, its character `one`.
fn card_of(blocks: &str) -> Vec<u8> {
    let toml = vec![("card/0001_blocks.toml".to_string(), blocks.to_string())];
    let container = Container {
        image: common::picture(),
        toml,
        assets: Vec::new(),
    };
    png::write(&container).unwrap()
}

#[test]
fn a_card_whose_language_cannot_be_told_is_left_as_it_is() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let file = card_of(
        r#"
spec = "ccv4:1.0.0"

[name.one]
text = "Io"

[description.one]
text = "Ok."

[character.one]
name-char = "name.one"
prompt = ["name.one", "description.one", "CHAT-HISTORY"]
"#,
    );
    let card = cards::import(db, me, &file).unwrap();
    let version = cards::newest(db, me, card.card_id).unwrap().0.version_id;
    writes_in(&scratch, "de");
    let new = NewChat {
        characters: &[(version, "one")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert!(
        !inputs
            .character
            .post_history_instructions
            .contains("Write your replies")
    );
}

#[test]
fn an_entry_two_lorebooks_share_is_translated_once() {
    let file = vec![(
        "card/0001_blocks.toml".to_string(),
        r#"
spec = "ccv4:1.0.0"

[name.one]
text = "Mira"

[description.one]
text = "Mira keeps the north light, and she counts the ships that pass the rocks at night."

[lore.wreck]
keywords = ["wreck"]
text = "The Asta sank here in 1911."

[lorebook.coast]
entries = ["lore.wreck"]

[lorebook.sea]
entries = ["lore.wreck"]

[character.one]
name-char = "name.one"
lorebooks = ["lorebook.coast", "lorebook.sea"]
prompt = ["name.one", "description.one", "LOREBOOK", "CHAT-HISTORY"]
"#
        .to_string(),
    )];
    let mut german = translation(0);
    german.texts.clear();
    let document = languages::add(&file, &german, 0).unwrap().document;
    // Both books of the new language name one copy, in German.
    let entry = |book: &str| {
        let entries = document.lookup(book).unwrap().get("entries").unwrap();
        entries.as_array().unwrap()[0].as_str().unwrap().to_string()
    };
    let copy = entry("lorebook.coast-de");
    assert_eq!(entry("lorebook.sea-de"), copy);
    let text = document.lookup(&copy).unwrap().get("text").unwrap();
    assert_eq!(text.as_str(), Some("Die Asta sank hier 1911."));
}

#[tokio::test]
async fn a_chat_of_a_translated_card_lists_the_lorebooks_its_prompt_reads() {
    let server = start().await;
    let (card_id, version) = server.add_card(common::card_file(), false).await;
    let lore = json!([{ "reference": "lore.wreck", "text": "Die Asta sank hier 1911.", "keywords": ["Wrack"], "secondary_keywords": [] }]);
    let kept = json!({ "version": version, "language": "de", "texts": [], "lore": lore });
    let (status, saved) = server
        .post(&format!("/api/cards/{card_id}/languages"), kept)
        .await;
    assert_eq!(status, 200, "{saved}");
    let (status, _) = server
        .patch("/api/settings", json!({ "language": "de" }))
        .await;
    assert_eq!(status, 200);
    let chat = server
        .chat_with(&[(saved["id"].as_i64().unwrap(), "mira")], 0)
        .await;

    // A switch answers the lorebooks the prompt reads: the chat's own view lists the same.
    let switch = json!({ "card_id": card_id, "reference": "lorebook.coast-de", "on": true });
    let (status, switched) = server
        .put(&format!("/api/chats/{}/lore", chat["chat"]["id"]), switch)
        .await;
    assert_eq!(status, 200, "{switched}");
    assert_eq!(chat["lorebooks"], switched);
}

#[test]
fn a_user_without_a_persona_is_named_in_the_apps_language() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let change = ChangeSettings {
        app_language: Some("pt-BR".to_string()),
        language: Some("en".to_string()),
        ..Default::default()
    };
    settings::change(db, me, &change).unwrap();
    let new = NewChat {
        characters: &[(card.version, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    // What the user reads, and the name the model is told.
    assert_eq!(
        inputs.state.messages[0].content,
        "\"You picked a night for it, Você.\""
    );
    assert_eq!(inputs.state.persona_name, "Você");
}

#[test]
fn a_greetings_date_is_written_in_the_apps_language() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let file = common::card_png(&json!({"data": {"name": "Aki", "first_mes": "Today: {{date}}"}}));
    let card = cards::import(db, me, &file).unwrap();
    let change = ChangeSettings {
        app_language: Some("ja".to_string()),
        language: Some("en".to_string()),
        ..Default::default()
    };
    settings::change(db, me, &change).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "aki")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    let shown = &chats::prompt_inputs(db, me, chat, None)
        .unwrap()
        .state
        .messages[0]
        .content;
    // Japanese's "2026年11月9日", not "November 9, 2026".
    let date = shown.strip_prefix("Today: ").unwrap();
    assert!(
        date.ends_with('日') && date.contains('年') && date.contains('月'),
        "{shown}"
    );
}

#[test]
fn the_librarys_excerpt_names_the_user_in_the_apps_language() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // Indexed before the language is chosen: the stored excerpt holds no word.
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let change = ChangeSettings {
        app_language: Some("pt-BR".to_string()),
        ..Default::default()
    };
    settings::change(db, me, &change).unwrap();
    let listed = cards::list(db, me).unwrap();
    assert_eq!(listed[0].excerpt, "\"You picked a night for it, Você.\"");
    let one = cards::get(db, me, card.card_id).unwrap().unwrap();
    assert_eq!(one.excerpt, listed[0].excerpt);
}

#[test]
fn the_librarys_excerpt_names_the_user_by_the_default_persona_where_there_is_one() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let ines = cw_library::personas::create(db, me, "Ines", "A surveyor.").unwrap();
    cw_library::personas::set_default(db, me, ines, true).unwrap();
    let listed = cards::list(db, me).unwrap();
    assert_eq!(listed[0].excerpt, "\"You picked a night for it, Ines.\"");
    let one = cards::get(db, me, card.card_id).unwrap().unwrap();
    assert_eq!(one.excerpt, listed[0].excerpt);
}

#[test]
fn the_librarys_excerpt_stays_in_its_length_with_the_users_name_put_in() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // The name and a word, two hundred times: past the excerpt's 300 characters.
    let greeting = "{{user}} a ".repeat(200);
    let file = common::card_png(&json!({"data": {"name": "Long", "first_mes": greeting}}));
    cards::import(db, me, &file).unwrap();
    let change = ChangeSettings {
        app_language: Some("es".to_string()),
        ..Default::default()
    };
    settings::change(db, me, &change).unwrap();
    let excerpt = &cards::list(db, me).unwrap()[0].excerpt;
    assert!(excerpt.starts_with("Visitante a Visitante"));
    assert!(
        excerpt.chars().count() <= 301 && excerpt.ends_with('…'),
        "{excerpt}"
    );
}

#[test]
fn the_ai_writes_in_the_apps_language_until_its_own_is_changed() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let app_in = |code: &str| {
        let change = ChangeSettings {
            app_language: Some(code.to_string()),
            ..Default::default()
        };
        settings::change(db, me, &change)
    };
    // None chosen at first: the page follows the computer.
    assert_eq!(settings::get(db, me).unwrap().app_language, None);
    // The app's language taken: the AI's follows it, by its own code ("pt" of "pt-BR").
    let taken = app_in("pt-BR").unwrap();
    assert_eq!(
        (taken.app_language.as_deref(), taken.language.as_str()),
        (Some("pt-BR"), "pt")
    );
    assert!(app_in("xx").is_err());
    // The AI's changed: it stays where the app's changes after.
    writes_in(&scratch, "fr");
    let after = app_in("de").unwrap();
    assert_eq!(
        (after.app_language.as_deref(), after.language.as_str()),
        (Some("de"), "fr")
    );
}

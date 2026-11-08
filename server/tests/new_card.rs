//! A card made from scratch, in the app: what the form "New card" gives is a
//! card of the library, written as a CCV4 file and stored as an imported one.
//!
//! `form` is a form filled in, as JSON, which a test changes; `made` makes a
//! card of one on a `Scratch`, and `toml` reads the one file such a card has.

mod common;

use std::io::Cursor;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::server::start;
use common::{Scratch, card_png, picture};
use cw_ccv4::new::NewCard;
use cw_ccv4::png::{self, Container};
use cw_library::cards::{self, Find, Imported};
use cw_store::Db;
use serde_json::{Value, json};

/// A form "New card" filled in.
fn form() -> Value {
    json!({
        "title": "The Keeper of Tern Rock",
        "tags": ["lighthouse", "slow burn"],
        "creator": "elana",
        "name": "Wren Halloway",
        "greetings": ["\"You are late, {{user}},\" {{char}} says.", "The lamp is lit."],
        "description": "{{char}} keeps the light on Tern Rock.",
        "personality": "Dry, exact.",
        "scenario": "The supply boat is a week overdue.",
        "example_dialogue": "{{user}}: Is it far?\n{{char}}: Far enough.",
        "creator_notes": "Best with a patient persona.",
    })
}

#[test]
fn a_new_card_is_made_with_its_system_prompt_and_post_history_instructions() {
    let scratch = Scratch::new();
    let mut with = form();
    with["system_prompt"] = json!("Stay on the rock.");
    with["post_history"] = json!("Answer in short lines.");
    let card = made(&scratch, &with);
    let form = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    let words = |texts: &[cw_ccv4::edit::EditText]| {
        texts.iter().map(|one| one.text.clone()).collect::<Vec<_>>()
    };
    assert_eq!(
        (
            words(&form.characters[0].system_prompt),
            words(&form.characters[0].post_history)
        ),
        (
            vec!["Stay on the rock.".to_string()],
            vec!["Answer in short lines.".to_string()]
        )
    );
}

fn new(form: &Value) -> NewCard {
    serde_json::from_value(form.clone()).unwrap()
}

/// Makes a card of `form` for the scratch database's user.
fn made(scratch: &Scratch, form: &Value) -> Imported {
    cards::create(&scratch.db, scratch.user, new(form)).unwrap()
}

/// The one TOML file of a card version, as it is kept.
fn toml(db: &Db, version: i64) -> String {
    db.with(|conn| {
        conn.query_row(
            "select toml from card_files where version_id = ?1 and toml is not null",
            [version],
            |r| r.get(0),
        )
    })
    .unwrap()
}

/// How many cards the library lists.
fn listed(scratch: &Scratch) -> usize {
    cards::find(&scratch.db, scratch.user, &Find::default())
        .unwrap()
        .len()
}

#[tokio::test]
async fn a_card_made_from_scratch_is_a_card_of_the_library() {
    let server = start().await;
    let (status, made) = server.post("/api/cards/new", form()).await;
    assert_eq!(status, 201, "{made}");
    assert_eq!(
        (&made["version"], &made["title"], &made["warnings"]),
        (&json!(1), &json!("The Keeper of Tern Rock"), &json!([])),
        "{made}"
    );
    let id = made["card_id"].as_i64().unwrap();

    // Its page reads the texts as a chat would show them.
    let (status, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(status, 200, "{detail}");
    assert_eq!(detail["card"]["title"], "The Keeper of Tern Rock");
    assert_eq!(detail["tags"], json!(["lighthouse", "slow burn"]));
    assert_eq!(detail["creator"], "elana");
    let one = &detail["characters"][0];
    assert_eq!(detail["characters"].as_array().unwrap().len(), 1);
    assert_eq!(
        (&one["id"], &one["name"], &one["label"]),
        (
            &json!("wren-halloway"),
            &json!("Wren Halloway"),
            &json!("Wren Halloway")
        )
    );
    assert_eq!(
        one["greetings"],
        json!([
            "\"You are late, User,\" Wren Halloway says.",
            "The lamp is lit."
        ])
    );
    assert_eq!(
        one["description"],
        "Wren Halloway keeps the light on Tern Rock."
    );
    assert_eq!(one["personality"], "Dry, exact.");
    assert_eq!(one["scenario"], "The supply boat is a week overdue.");
    assert_eq!(
        one["example_dialogue"],
        "User: Is it far?\nWren Halloway: Far enough."
    );
    assert_eq!(one["creator_notes"], "Best with a patient persona.");

    // The library lists it, by its title, with its character's name and its first words.
    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list.as_array().unwrap().len(), 1, "{list}");
    assert_eq!(list[0]["names"], json!(["Wren Halloway"]));
    assert_eq!(
        list[0]["excerpt"],
        "\"You are late, User,\" Wren Halloway says."
    );

    // Without a picture it has one of a single pixel, which is a card without art.
    let version = made["version_id"].as_i64().unwrap();
    let (_, image) = server
        .download(&format!("/api/card-versions/{version}/image"))
        .await;
    let size = image::ImageReader::new(Cursor::new(&image))
        .with_guessed_format()
        .unwrap()
        .into_dimensions()
        .unwrap();
    assert_eq!(size, (1, 1));

    // A chat starts with it, with the greeting asked for.
    let start = json!({ "characters": [{ "version_id": version, "character": "wren-halloway" }], "greeting": 1 });
    let (status, chat) = server.post("/api/chats", start).await;
    assert_eq!(status, 201, "{chat}");
    assert_eq!(chat["messages"][0]["content"], "The lamp is lit.", "{chat}");

    // And its editor shows what the form gave, as it was written, each text in a block of its own.
    let (_, edit) = server.get(&format!("/api/cards/{id}/edit")).await;
    assert_eq!(
        edit["characters"][0]["greetings"],
        json!([
            { "reference": "greeting.wren-halloway", "text": "\"You are late, {{user}},\" {{char}} says." },
            { "reference": "greeting.wren-halloway-2", "text": "The lamp is lit." },
        ])
    );
    assert_eq!(
        edit["characters"][0]["description"],
        json!([{ "reference": "description.wren-halloway", "text": "{{char}} keeps the light on Tern Rock." }])
    );
}

#[test]
fn a_new_card_is_written_as_a_card_file_with_its_texts_in_the_prompts_order() {
    let scratch = Scratch::new();
    let card = made(&scratch, &form());
    let file = toml(&scratch.db, card.version_id);
    assert!(file.starts_with("spec = \"ccv4:1.0.0\"\n"), "{file}");
    let document = cards::document(&scratch.db, scratch.user, card.version_id).unwrap();
    assert_eq!(document.title(), "The Keeper of Tern Rock");
    let character = document.character("wren-halloway").unwrap();
    let prompt: Vec<&str> = character["prompt"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|item| item.as_str())
        .collect();
    assert_eq!(
        prompt,
        [
            "name.wren-halloway",
            "description.wren-halloway",
            "personality.wren-halloway",
            "scenario.wren-halloway",
            "dialogue-example.wren-halloway",
            "LOREBOOK",
            "CHAT-HISTORY"
        ]
    );
    assert_eq!(
        character["name-char"].as_str(),
        Some("name.wren-halloway"),
        "{file}"
    );
    // The file says when the card was made.
    let meta = toml::from_str::<toml::Table>(&file).unwrap()["meta-info"].clone();
    assert!(
        meta["created"].is_datetime() && meta["created"] == meta["modified"],
        "{file}"
    );
}

#[test]
fn what_a_new_card_leaves_empty_it_has_no_block_for() {
    let scratch = Scratch::new();
    let mut bare = form();
    for key in [
        "creator",
        "description",
        "personality",
        "scenario",
        "example_dialogue",
        "creator_notes",
    ] {
        bare[key] = json!("  ");
    }
    bare["tags"] = json!([]);
    // A greeting without words is none, wherever it stands.
    bare["greetings"] = json!(["", "The lamp is lit.", " \n "]);
    let card = made(&scratch, &bare);
    let file = toml(&scratch.db, card.version_id);
    for kind in [
        "description",
        "personality",
        "scenario",
        "dialogue-example",
        "creator-note",
    ] {
        assert!(!file.contains(&format!("[{kind}.")), "{kind} in {file}");
    }
    assert!(
        !file.contains("creator") && !file.contains("tags"),
        "{file}"
    );
    let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    let one = &edit.characters[0];
    let texts: Vec<&str> = one.greetings.iter().map(|one| one.text.as_str()).collect();
    assert_eq!(texts, ["The lamp is lit."]);
    assert_eq!(one.description.len(), 1);
    assert_eq!(
        (
            &one.description[0].reference,
            one.description[0].text.as_str()
        ),
        (&None, "")
    );

    // A card of a title and a name alone is a card: nothing else is needed.
    bare["greetings"] = json!([]);
    let least = made(&scratch, &bare);
    assert_eq!(listed(&scratch), 2);
    let edit = cards::editable(&scratch.db, scratch.user, least.card_id, None).unwrap();
    assert!(edit.characters[0].greetings.is_empty());
    assert_eq!(edit.characters[0].name, "Wren Halloway");
}

#[test]
fn a_new_cards_talkativeness_is_written_where_it_is_not_what_a_card_says_by_saying_nothing() {
    let scratch = Scratch::new();
    let talkative = |value: Value| {
        let mut asked = form();
        asked["talkativeness"] = value;
        asked
    };
    // Not given, or 0.5: the card says nothing, which counts as 0.5.
    for asked in [form(), talkative(json!(0.5))] {
        let card = made(&scratch, &asked);
        let file = toml(&scratch.db, card.version_id);
        assert!(!file.contains("talkativeness"), "{file}");
        let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
        assert_eq!(edit.characters[0].talkativeness, 0.5);
    }
    let card = made(&scratch, &talkative(json!(0.3)));
    let file = toml(&scratch.db, card.version_id);
    assert!(file.contains("group-talkativeness = 0.3\n"), "{file}");
    let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    assert_eq!(edit.characters[0].talkativeness, 0.3);

    // Beyond 0 and 1 it is refused, and no card is made.
    let refused =
        cards::create(&scratch.db, scratch.user, new(&talkative(json!(1.5)))).unwrap_err();
    assert_eq!(
        format!("{refused:#}"),
        "the talkativeness of wren-halloway is not between 0 and 1"
    );
    assert_eq!(listed(&scratch), 3);
}

#[test]
fn a_new_card_keeps_its_title_its_tags_and_its_texts_as_they_are_tidied() {
    let scratch = Scratch::new();
    let mut untidy = form();
    untidy["title"] = json!("  Tern Rock  ");
    untidy["name"] = json!(" Wren\r\n");
    untidy["tags"] = json!([" Sea ", "sea", "", "Slow Burn, keeper"]);
    untidy["description"] = json!("First line.\r\nSecond line.  ");
    let card = made(&scratch, &untidy);
    assert_eq!(card.title, "Tern Rock");
    let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    // A tag stands once, whatever its case, as it was first written.
    assert_eq!(edit.tags, ["Sea", "Slow Burn", "keeper"]);
    assert_eq!(edit.characters[0].name, "Wren");
    assert_eq!(edit.characters[0].id, "wren");
    assert_eq!(
        edit.characters[0].description[0].text,
        "First line.\nSecond line."
    );
}

#[test]
fn a_new_card_needs_a_title_and_a_name_for_its_character() {
    let scratch = Scratch::new();
    for (key, why) in [
        ("title", "a card needs a title"),
        ("name", "a character needs a name"),
    ] {
        let mut lacking = form();
        lacking[key] = json!("  \n");
        let refused = cards::create(&scratch.db, scratch.user, new(&lacking)).unwrap_err();
        assert_eq!(refused.to_string(), why);
    }
    assert_eq!(listed(&scratch), 0);
}

#[tokio::test]
async fn a_new_card_without_a_title_is_refused_over_http() {
    let server = start().await;
    let mut lacking = form();
    lacking["title"] = json!("");
    let (status, refused) = server.post("/api/cards/new", lacking).await;
    assert_eq!(
        (status, &refused["error"]),
        (400, &json!("a card needs a title")),
        "{refused}"
    );
    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list, json!([]));
}

#[test]
fn a_character_whose_name_has_no_letter_of_an_id_is_called_character_in_the_file() {
    let scratch = Scratch::new();
    let mut named = form();
    named["name"] = json!("灯台守");
    let card = made(&scratch, &named);
    let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    assert_eq!(
        (
            edit.characters[0].id.as_str(),
            edit.characters[0].name.as_str()
        ),
        ("character", "灯台守")
    );
    assert_eq!(
        edit.characters[0].greetings[0].reference.as_deref(),
        Some("greeting.character")
    );
}

#[test]
fn a_new_cards_picture_is_the_png_given_without_a_card_it_holds() {
    let scratch = Scratch::new();
    // A picture that is itself a card file, of both kinds at once.
    let other = card_png(
        &json!({ "spec": "chara_card_v2", "data": { "name": "Someone Else", "first_mes": "Hello." } }),
    );
    let both = png::write(&Container {
        image: other,
        toml: common::files(),
        assets: Vec::new(),
    })
    .unwrap();
    let mut with = form();
    with["picture"] = json!(STANDARD.encode(&both));
    let card = made(&scratch, &with);
    assert_eq!(card.title, "The Keeper of Tern Rock");
    let kept = cards::image(&scratch.db, scratch.user, card.version_id)
        .unwrap()
        .unwrap();
    assert_eq!(kept, picture());
    // The card is the form's alone: one character, and no lorebook of the picture's card.
    let edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    assert_eq!(edit.characters.len(), 1);
    assert_eq!(edit.characters[0].name, "Wren Halloway");
    assert!(card.lorebooks.is_empty());
}

#[test]
fn a_picture_that_cannot_be_read_is_refused_and_no_card_is_made() {
    let scratch = Scratch::new();
    let refused = |picture: Value| {
        let mut with = form();
        with["picture"] = picture;
        cards::create(&scratch.db, scratch.user, new(&with))
            .unwrap_err()
            .to_string()
    };
    assert_eq!(refused(json!("not base64!")), "the picture is not base64");
    assert_eq!(
        refused(json!(STANDARD.encode(b"GIF89a"))),
        "the picture is no PNG, JPEG or WebP"
    );
    // The first bytes of a JPEG alone.
    let jpeg = STANDARD.encode([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, b'J', b'F', b'I', b'F']);
    assert_eq!(refused(json!(jpeg)), "the picture cannot be read");
    // A PNG by its chunks, whose header names no picture a reader knows.
    let odd = common::png_of(&[
        common::chunk(b"IHDR", &[0, 0, 0, 1, 0, 0, 0, 1, 7, 9, 0, 0, 0]),
        common::pixels(),
        common::chunk(b"IEND", &[]),
    ]);
    assert_eq!(
        refused(json!(STANDARD.encode(odd))),
        "the picture cannot be read"
    );
    assert_eq!(listed(&scratch), 0);
}

#[test]
fn a_new_card_is_edited_as_any_other() {
    let scratch = Scratch::new();
    let card = made(&scratch, &form());
    let mut edit = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    edit.characters[0].scenario[0].text = "The boat came in at dawn.".to_string();
    let saved = cards::edit(&scratch.db, scratch.user, card.card_id, &edit).unwrap();
    assert_eq!(saved.number, 2);
    let after = cards::editable(&scratch.db, scratch.user, card.card_id, None).unwrap();
    assert_eq!(
        after.characters[0].scenario[0].text,
        "The boat came in at dawn."
    );
    assert_eq!(
        after.characters[0].description[0].text,
        "{{char}} keeps the light on Tern Rock."
    );
}

#[tokio::test]
async fn a_new_cards_picture_may_be_larger_than_a_request_may_be_elsewhere() {
    let server = start().await;
    // A picture of three megabytes: what it shows is small, and a note in it is long.
    let mut note = b"Comment\0".to_vec();
    note.resize(3 * 1024 * 1024, b'a');
    let large = common::png_with(vec![common::chunk(b"tEXt", &note)]);
    let mut with = form();
    with["picture"] = json!(STANDARD.encode(&large));
    let (status, made) = server.post("/api/cards/new", with).await;
    assert_eq!(status, 201, "{made}");
    let version = made["version_id"].as_i64().unwrap();
    let (_, kept) = server
        .download(&format!("/api/card-versions/{version}/image"))
        .await;
    assert_eq!(kept, large);
}

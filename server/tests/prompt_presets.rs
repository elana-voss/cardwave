//! Prompt presets: a system prompt and an author's note kept under a name as
//! CCV4 `prompt` blocks, one of which is in use for every chat, and which a
//! chat may choose for itself.
//!
//! `texts` is what an editor holds, `preset` keeps it under a name, `told` is
//! what the sample card's Mira is told in a chat (her system prompt and her
//! depth prompts as text with their depth). Mira's own system prompt is
//! "Write tersely."; her depth prompts are at 2 and 0.

mod common;

use common::Scratch;
use common::server::start;
use cw_chat::chats::{self, NewChat};
use cw_chat::prompt_presets::{self, ChatPromptPreset, PromptPreset, PromptTexts};
use cw_library::cards;
use cw_store::Db;
use serde_json::json;

fn texts(system_prompt: &str, authors_note: &str, depth: u32) -> PromptTexts {
    PromptTexts {
        system_prompt: system_prompt.to_string(),
        authors_note: authors_note.to_string(),
        authors_note_depth: depth,
    }
}

fn preset(scratch: &Scratch, name: &str, holds: PromptTexts) -> PromptPreset {
    prompt_presets::create(&scratch.db, scratch.user, name, &holds).unwrap()
}

/// A chat with Mira of the sample card.
fn chat_with_mira(db: &Db, user: i64) -> i64 {
    let card = cards::import(db, user, &common::card_copy()).unwrap();
    let characters = [(card.version_id, "mira")];
    let new = NewChat {
        characters: &characters,
        persona_id: None,
        greeting: 0,
    };
    chats::create(db, user, &new).unwrap()
}

/// Mira's system prompt in the chat, and her depth prompts with their depths.
fn told(db: &Db, user: i64, chat: i64) -> (String, Vec<(String, usize)>) {
    let mira = chats::prompt_inputs(db, user, chat, None)
        .unwrap()
        .character;
    let depth = mira.depth_prompts.into_iter().map(|d| (d.prompt, d.depth));
    (mira.system_prompt, depth.collect())
}

/// Mira's own depth prompts, as her card has them.
fn her_own() -> Vec<(String, usize)> {
    vec![
        ("[The light flickers.]".to_string(), 2),
        ("[The tide is rising.]".to_string(), 0),
    ]
}

#[test]
fn a_preset_is_kept_as_ccv4_prompt_blocks_and_listed_by_name() {
    let scratch = Scratch::new();
    let noir = preset(&scratch, "Noir", texts("Write as noir.", "[Rain.]", 4));
    preset(&scratch, "brief", texts("", "", 1));
    let listed = prompt_presets::list(&scratch.db, scratch.user).unwrap();
    let names: Vec<&str> = listed.iter().map(|p| p.name.as_str()).collect();
    assert_eq!(names, ["brief", "Noir"]);
    assert_eq!(listed[1], noir);
    assert_eq!(noir.texts, texts("Write as noir.", "[Rain.]", 4));
    assert!(!noir.in_use);

    let blocks: String = scratch
        .db
        .with(|conn| {
            conn.query_row(
                "select blocks from prompt_presets where id = ?1",
                [noir.id],
                |r| r.get(0),
            )
        })
        .unwrap();
    let blocks: toml::Table = toml::from_str(&blocks).unwrap();
    let prompt = blocks["prompt"].as_table().unwrap();
    assert_eq!(prompt["system"]["text"].as_str(), Some("Write as noir."));
    assert_eq!(prompt["system"].get("depth"), None);
    assert_eq!(prompt["authors-note"]["text"].as_str(), Some("[Rain.]"));
    assert_eq!(prompt["authors-note"]["depth"].as_integer(), Some(4));
}

#[test]
fn a_name_is_needed_its_own_and_a_depth_is_one_or_more() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let noir = preset(&scratch, "Noir", texts("", "", 4));
    let refused = |name: &str, depth: u32| {
        prompt_presets::create(db, me, name, &texts("", "", depth))
            .unwrap_err()
            .to_string()
    };
    assert_eq!(refused("  ", 4), "the preset needs a name");
    assert_eq!(refused("Noir", 4), "another preset is called “Noir”");
    assert_eq!(
        refused(&"n".repeat(61), 4),
        "a preset's name has at most 60 characters"
    );
    assert_eq!(
        refused("Deep", 0),
        "the author's note is put one message back or more"
    );

    let other = preset(&scratch, "Other", texts("", "", 4));
    let change = |id, name: &str| prompt_presets::change(db, me, id, name, &texts("", "", 4));
    assert_eq!(
        change(other.id, " Noir ").unwrap_err().to_string(),
        "another preset is called “Noir”"
    );
    let changed = prompt_presets::change(db, me, noir.id, "Noir", &texts("Now.", "[Then.]", 2));
    assert_eq!(changed.unwrap().texts, texts("Now.", "[Then.]", 2));
}

#[test]
fn a_copy_holds_the_same_under_a_name_of_its_own() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let noir = preset(&scratch, "Noir", texts("Write as noir.", "[Rain.]", 3));
    let copy = prompt_presets::duplicate(db, me, noir.id, "copy").unwrap();
    assert_eq!(
        (copy.name.as_str(), &copy.texts),
        ("Noir (copy)", &noir.texts)
    );
    let again = prompt_presets::duplicate(db, me, noir.id, "copy").unwrap();
    assert_eq!(again.name, "Noir (copy 2)");
}

#[test]
fn a_copy_of_default_is_empty_under_a_name_of_its_own() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let copy = prompt_presets::duplicate_default(db, me, "Default", "copy").unwrap();
    assert_eq!(
        (copy.name.as_str(), &copy.texts),
        ("Default (copy)", &texts("", "", 4))
    );
    let again = prompt_presets::duplicate_default(db, me, "Default", "copy").unwrap();
    assert_eq!(again.name, "Default (copy 2)");
}

#[test]
fn the_preset_in_use_tells_every_chat_and_default_leaves_the_card_as_it_is() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat = chat_with_mira(db, me);
    let noir = preset(
        &scratch,
        "Noir",
        texts("Write as noir, {{char}}.", "[Rain.]", 4),
    );
    let notes = preset(&scratch, "Notes", texts(" \n", "[Keep it short.]", 1));

    assert_eq!(
        told(db, me, chat),
        ("Write tersely.".to_string(), her_own())
    );

    prompt_presets::put_in_use(db, me, Some(noir.id)).unwrap();
    let mut with_note = her_own();
    with_note.push(("[Rain.]".to_string(), 4));
    // The builder expands its macros, as it does the card's.
    assert_eq!(
        told(db, me, chat),
        ("Write as noir, {{char}}.".to_string(), with_note)
    );
    let listed = prompt_presets::list(db, me).unwrap();
    assert_eq!(
        listed.iter().map(|p| p.in_use).collect::<Vec<_>>(),
        [true, false]
    );

    // A system prompt of nothing but blanks leaves the card's.
    prompt_presets::put_in_use(db, me, Some(notes.id)).unwrap();
    let mut with_note = her_own();
    with_note.push(("[Keep it short.]".to_string(), 1));
    assert_eq!(
        told(db, me, chat),
        ("Write tersely.".to_string(), with_note)
    );

    prompt_presets::put_in_use(db, me, None).unwrap();
    assert_eq!(
        told(db, me, chat),
        ("Write tersely.".to_string(), her_own())
    );
    assert!(
        prompt_presets::list(db, me)
            .unwrap()
            .iter()
            .all(|p| !p.in_use)
    );
}

#[test]
fn a_chat_chooses_a_preset_of_its_own_or_the_card_or_what_is_in_use() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat = chat_with_mira(db, me);
    let noir = preset(&scratch, "Noir", texts("Write as noir.", "", 4));
    let gothic = preset(&scratch, "Gothic", texts("Write as gothic.", "", 4));
    prompt_presets::put_in_use(db, me, Some(noir.id)).unwrap();
    let choice = |db, chat| chats::get(db, me, chat).unwrap().unwrap().prompt_preset;
    assert_eq!(choice(db, chat), ChatPromptPreset::Settings);

    prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Preset(gothic.id)).unwrap();
    assert_eq!(choice(db, chat), ChatPromptPreset::Preset(gothic.id));
    assert_eq!(told(db, me, chat).0, "Write as gothic.");

    prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Card).unwrap();
    assert_eq!(choice(db, chat), ChatPromptPreset::Card);
    assert_eq!(told(db, me, chat).0, "Write tersely.");

    prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Settings).unwrap();
    assert_eq!(told(db, me, chat).0, "Write as noir.");

    let other = cw_accounts::users::create(db, "olga").unwrap();
    let theirs = prompt_presets::create(db, other, "Theirs", &texts("", "", 4)).unwrap();
    let refused =
        prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Preset(theirs.id));
    assert_eq!(refused.unwrap_err().to_string(), "no such prompt preset");
    assert!(prompt_presets::put_in_use(db, me, Some(theirs.id)).is_err());

    chats::set_trashed(db, me, chat, true).unwrap();
    let refused = prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Card);
    assert_eq!(
        refused.unwrap_err().to_string(),
        "the chat is in the Trash; restore it first"
    );
}

#[test]
fn a_chat_whose_preset_is_deleted_goes_by_the_one_in_use_and_without_one_by_the_card() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat = chat_with_mira(db, me);
    let card = chat_with_mira(db, me);
    let noir = preset(&scratch, "Noir", texts("Write as noir.", "", 4));
    let gothic = preset(&scratch, "Gothic", texts("Write as gothic.", "", 4));
    prompt_presets::put_in_use(db, me, Some(gothic.id)).unwrap();
    prompt_presets::choose_for_chat(db, me, chat, ChatPromptPreset::Preset(noir.id)).unwrap();
    prompt_presets::choose_for_chat(db, me, card, ChatPromptPreset::Card).unwrap();

    prompt_presets::delete(db, me, noir.id).unwrap();
    let choice = |chat| chats::get(db, me, chat).unwrap().unwrap().prompt_preset;
    assert_eq!(choice(chat), ChatPromptPreset::Settings);
    assert_eq!(told(db, me, chat).0, "Write as gothic.");
    assert_eq!(choice(card), ChatPromptPreset::Card);

    prompt_presets::delete(db, me, gothic.id).unwrap();
    assert!(prompt_presets::list(db, me).unwrap().is_empty());
    assert_eq!(told(db, me, chat).0, "Write tersely.");
    assert!(prompt_presets::delete(db, me, noir.id).is_err());
}

#[tokio::test]
async fn prompt_presets_over_http() {
    let server = start().await;
    let (status, made) = server
        .post(
            "/api/prompt-presets",
            json!({ "name": "Noir", "system_prompt": "Write as noir.", "authors_note": "[Rain.]", "authors_note_depth": 4 }),
        )
        .await;
    assert_eq!(status, 201);
    let id = made["id"].as_i64().unwrap();
    let changed = json!({ "name": "Noir", "system_prompt": "Darker.", "authors_note": "", "authors_note_depth": 2 });
    let (status, after) = server
        .put(&format!("/api/prompt-presets/{id}"), changed)
        .await;
    assert_eq!((status, &after["system_prompt"]), (200, &json!("Darker.")));
    let (status, copy) = server
        .post(
            &format!("/api/prompt-presets/{id}/duplicate"),
            json!({ "copy": "Kopie" }),
        )
        .await;
    assert_eq!((status, &copy["name"]), (201, &json!("Noir (Kopie)")));
    let (status, _) = server
        .put("/api/prompt-presets/in-use", json!({ "id": id }))
        .await;
    assert_eq!(status, 204);
    let (_, listed) = server.get("/api/prompt-presets").await;
    assert_eq!(listed[0]["in_use"], json!(true));

    let (_, card) = server.upload("/api/cards", common::card_copy()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    assert_eq!(view["chat"]["prompt_preset"], json!("settings"));
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let (status, chat_now) = server
        .put(&format!("{chat}/prompt-preset"), json!({ "preset": id }))
        .await;
    assert_eq!(
        (status, &chat_now["prompt_preset"]),
        (200, &json!({ "preset": id }))
    );

    let (status, _) = server
        .call(
            reqwest::Method::DELETE,
            &format!("/api/prompt-presets/{id}"),
            None,
        )
        .await;
    assert_eq!(status, 204);
    let (_, chat_now) = server.get(&chat).await;
    assert_eq!(chat_now["chat"]["prompt_preset"], json!("settings"));
}

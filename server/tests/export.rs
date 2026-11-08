//! A card written out as a file: as CCV4 or as a SillyTavern card, in the
//! format the user has chosen in the settings. That a SillyTavern card goes
//! back as it came is tested in `sillytavern.rs`.

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::server::{Server, start};
use common::{Scratch, card_data, card_png, picture};
use cw_ccv4::creation::{self, Creation};
use cw_ccv4::new::NewCard;
use cw_ccv4::png::{self, Container};
use cw_ccv4::sillytavern;
use cw_library::cards::{self, ExportFormat};
use cw_library::settings::{self, ChangeSettings};
use serde_json::json;

async fn add(server: &Server, file: Vec<u8>) -> i64 {
    server.add_card(file, false).await.0
}

/// The file name a download is given.
fn file_name(headers: &reqwest::header::HeaderMap) -> String {
    let disposition = headers["content-disposition"].to_str().unwrap();
    let encoded = disposition
        .strip_prefix("attachment; filename*=UTF-8''")
        .expect(disposition);
    percent_encoding::percent_decode_str(encoded)
        .decode_utf8()
        .unwrap()
        .to_string()
}

#[test]
fn a_ccv4_export_is_the_card_without_its_users_files() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // A card from before, with both its characters, is exported as it is.
    let imported = common::import_whole(db, me, &common::card_file()).unwrap();
    let exported =
        cards::export(db, me, imported.card_id, ExportFormat::Ccv4, false, None).unwrap();
    assert_eq!(exported.file_name, "Mira of the North Light.png");

    let mut expected: Container = common::container();
    assert_eq!(expected.toml.len(), 3);
    expected.toml.retain(|(name, _)| name.starts_with("card/"));
    assert_eq!(expected.toml.len(), 2);
    assert_eq!(png::read(&exported.data).unwrap(), expected);

    // The card as it is now is the one exported.
    let mut form = cards::editable(db, me, imported.card_id, None).unwrap();
    form.characters[0].scenario[0].text = "Rebuilt.".to_string();
    cards::edit(db, me, imported.card_id, &form).unwrap();
    let exported =
        cards::export(db, me, imported.card_id, ExportFormat::Ccv4, false, None).unwrap();
    assert!(
        png::read(&exported.data).unwrap().toml[0]
            .1
            .contains("Rebuilt.")
    );

    // Nobody exports another user's card.
    let other = cw_accounts::users::create(db, "olga").unwrap();
    assert!(cards::export(db, other, imported.card_id, ExportFormat::Ccv4, false, None).is_err());
}

#[test]
fn how_a_card_was_made_stays_with_the_card_and_out_of_its_exports() {
    const MARK: &str = "what-the-user-told-the-interview";
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = Creation {
        nevers: vec![MARK.to_string()],
        plan: json!({ "persona_lines": [MARK], "nothing": null }),
        ..Creation::default()
    };
    let new = serde_json::from_value::<NewCard>(json!({
        "title": "Ada", "tags": [], "creator": "", "name": "Ada", "greetings": ["Hi."],
        "description": "A guide.", "personality": "", "scenario": "", "example_dialogue": "",
        "creator_notes": "",
    }));
    let new = NewCard {
        creation: Some(made.clone()),
        ..new.unwrap()
    };
    let card = cards::create(db, me, new).unwrap().card_id;

    // A new version of the card keeps it.
    let mut form = cards::editable(db, me, card, None).unwrap();
    form.characters[0].description[0].text = "Rebuilt.".to_string();
    cards::edit(db, me, card, &form).unwrap();
    let version = cards::get(db, me, card).unwrap().unwrap().version_id;
    let kept = cards::document(db, me, version).unwrap();
    assert_eq!(creation::read(&kept).unwrap(), Some(made));

    // No export has it, with its history or without.
    for history in [false, true] {
        let exported = cards::export(db, me, card, ExportFormat::Ccv4, history, None).unwrap();
        let file = png::read(&exported.data).unwrap();
        assert!(file.toml.iter().all(|(_, text)| !text.contains(MARK)));
        assert!(file.toml.iter().all(|(name, _)| name != creation::FILE));
    }
    let exported = cards::export(db, me, card, ExportFormat::SillytavernV3, false, None).unwrap();
    let data = card_data(&exported.data);
    assert_eq!(data["name"], "Ada");
    assert!(!data.to_string().contains(MARK));
}

#[test]
fn a_ccv4_character_becomes_a_sillytavern_card() {
    let container = common::container();
    let file = sillytavern::export(&container, Some("mira")).unwrap();
    let data = card_data(&file);
    assert_eq!(data["name"], "Mira");
    assert!(data.get("nickname").is_none());
    // An outfit describes the character; the user's own pinned text is the card's.
    assert_eq!(
        data["description"],
        "Keeper of the north light. {{char}} counts ships.\n\nA patched oilskin coat."
    );
    assert_eq!(data["personality"], "Wry, patient.");
    assert_eq!(
        data["scenario"],
        "A storm has cut the causeway. {{user}} is stranded."
    );
    assert_eq!(
        data["first_mes"],
        "\"You picked a night for it, {{user}}.\""
    );
    assert_eq!(
        data["alternate_greetings"],
        json!(["Hold the lamp. Don't ask."])
    );
    assert_eq!(data["group_only_greetings"], json!(["All of you, inside."]));
    assert_eq!(
        data["mes_example"],
        "<START>\n{{user}}: Tea?\n{{char}}: \"Black.\""
    );
    // Prompt text before the chat is the system prompt, after it the instructions that follow the chat.
    assert_eq!(data["system_prompt"], "Write tersely.");
    assert_eq!(
        data["post_history_instructions"],
        "Stay in the scene.\n\n[Under 100 words.]"
    );
    assert_eq!(data["creator_notes"], "Never sent to the model.");
    assert_eq!(data["tags"], json!(["sea", "mystery"]));
    assert_eq!(
        (&data["creator"], &data["character_version"]),
        (&json!(""), &json!(""))
    );
    // The first note at a depth is the card's one; a card not from SillyTavern has no other extensions.
    assert_eq!(
        data["extensions"],
        json!({"depth_prompt": {"prompt": "[The light flickers.]", "depth": 2, "role": "system"}})
    );

    let book = &data["character_book"];
    // A block without a name of its own is named by its ID, so that it comes back as itself.
    assert_eq!(
        (&book["name"], &book["scan_depth"], &book["token_budget"]),
        (&json!("coast"), &json!(3), &json!(300))
    );
    let entries = book["entries"].as_array().unwrap();
    assert_eq!(entries.len(), 3);
    assert_eq!(
        entries[0],
        json!({
            "id": 0, "keys": ["wreck"], "content": "The Asta sank here in 1911.", "enabled": true, "insertion_order": 0,
            "constant": false, "selective": false, "use_regex": false, "priority": 5, "extensions": {"sticky": 2}
        })
    );
    assert_eq!(
        (&entries[1]["constant"], &entries[1]["insertion_order"]),
        (&json!(true), &json!(1))
    );
    assert_eq!(entries[2]["enabled"], false);

    // The character's picture is a file of the card: it goes along as the main icon.
    assert_eq!(
        data["assets"],
        json!([{"type": "icon", "name": "main", "uri": "__asset:0", "ext": "png"}])
    );
    let (_, chunks) =
        png::take_text(&file, |keyword| keyword.starts_with("chara-ext-asset_")).unwrap();
    assert_eq!(chunks.len(), 1);
    assert_eq!(chunks[0].0, "chara-ext-asset_:0");
    assert_eq!(STANDARD.decode(chunks[0].1).unwrap(), common::AVATAR);

    // What comes out is a card the import takes: the same character in a chat.
    let (again, notes) = sillytavern::convert(&file).unwrap().unwrap();
    assert!(notes.is_empty(), "{notes:?}");
    assert_eq!(
        again.assets,
        [(
            "card/assets/icon/main.png".to_string(),
            common::AVATAR.to_vec()
        )]
    );
}

#[test]
fn a_sillytavern_card_is_one_character_the_named_one_or_the_first() {
    let container = common::container();
    let name =
        |character| card_data(&sillytavern::export(&container, character).unwrap())["name"].clone();
    assert_eq!(name(None), "Mira");
    assert_eq!(name(Some("bare")), "bare");
    let error = sillytavern::export(&container, Some("nobody")).unwrap_err();
    assert!(
        format!("{error:#}").contains("no character \"nobody\""),
        "{error:#}"
    );

    let mut empty = container.clone();
    empty.toml = vec![(
        "card/0001_card.toml".to_string(),
        "spec = \"ccv4:1.0.0\"\n".to_string(),
    )];
    let error = sillytavern::export(&empty, None).unwrap_err();
    assert!(
        format!("{error:#}").contains("no character to export"),
        "{error:#}"
    );
}

#[test]
fn a_picture_that_carries_a_card_of_its_own_ends_up_with_one() {
    let mut container = common::container();
    container.image = card_png(&json!({"data": {"name": "Stale", "description": "x"}}));
    let file = sillytavern::export(&container, None).unwrap();
    let (image, texts) = png::take_text(&file, |_| true).unwrap();
    assert_eq!(image, picture());
    let keywords: Vec<&str> = texts.iter().map(|(keyword, _)| keyword.as_str()).collect();
    assert_eq!(keywords, ["chara", "ccv3", "chara-ext-asset_:0"]);
    assert_eq!(card_data(&file)["name"], "Mira");
}

#[tokio::test]
async fn export_writes_the_format_chosen_in_the_settings() {
    let server = start().await;
    let card = add(&server, common::card_file()).await;
    let path = format!("/api/cards/{card}/export");

    // Until the user chooses, it is a SillyTavern card.
    let (status, settings) = server.get("/api/settings").await;
    assert_eq!(
        (status, &settings),
        (
            200,
            &json!({"export_format": "sillytavern_v3", "export_history": false, "describe_imported": false, "interview_style": "tree", "web_pictures": false, "check_updates": true, "voice": null, "voice_speed": 100,
                "tools": {"web": false, "files": false, "ask_writes": true, "commands": false,
                    "ask_commands": true, "pictures": false, "ask_new_tools": true, "app": false, "dice": false, "folder": null},
                "coding": {"team": "balanced", "planner_model": null, "worker_model": null, "auditor_model": null,
                    "workers": 2, "audit": "end"},
                "companion": {"card_id": null, "starts": false, "hidden_until": null, "figure": "woman", "size": 21, "muted": false},
                "card_folder": {"folder": null, "watch": true, "recycle": false},
                "plain_prompt": "You are a helpful, honest assistant. It is now {{date}}, {{time}}.",
                "setup_downloads": [],
                "language_chosen": false, "app_language": null,
                "own_css": "",
                // The language the AI writes in is this computer's at first.
                "language": cw_core::languages::of_computer()})
        )
    );
    let (headers, file) = server.download(&path).await;
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!(file_name(&headers), "Mira of the North Light.png");
    assert!(png::read(&file).unwrap().toml.is_empty());
    assert_eq!(card_data(&file)["name"], "Mira");
    let (status, error) = server.get(&format!("{path}?character=nobody")).await;
    assert_eq!(status, 400, "{error}");

    let (status, settings) = server
        .patch("/api/settings", json!({"export_format": "ccv4"}))
        .await;
    assert_eq!((status, &settings["export_format"]), (200, &json!("ccv4")));
    // Pictures from the web are off until switched on, and stay on once they are.
    let (status, settings) = server
        .patch("/api/settings", json!({"web_pictures": true}))
        .await;
    assert_eq!((status, &settings["web_pictures"]), (200, &json!(true)));
    assert_eq!(server.get("/api/settings").await.1["web_pictures"], true);
    // The desktop app looks for a new version by itself until switched off.
    server
        .patch("/api/settings", json!({"check_updates": false}))
        .await;
    assert_eq!(server.get("/api/settings").await.1["check_updates"], false);
    let (_, file) = server.download(&path).await;
    assert_eq!(png::read(&file).unwrap().toml.len(), 2);
    assert!(
        png::take_text(&file, |keyword| keyword == "chara" || keyword == "ccv3")
            .unwrap()
            .1
            .is_empty()
    );
    // With the texts' history where the settings ask for it.
    server
        .edit_card(&json!(card), |form| {
            form["characters"][0]["scenario"][0]["text"] = json!("Dry.")
        })
        .await;
    let (status, settings) = server
        .patch("/api/settings", json!({"export_history": true}))
        .await;
    assert_eq!((status, &settings["export_history"]), (200, &json!(true)));
    let (_, file) = server.download(&path).await;
    let names: Vec<String> = png::read(&file)
        .unwrap()
        .toml
        .into_iter()
        .map(|(name, _)| name)
        .collect();
    assert!(
        names.contains(&"user/0001_revision.toml".to_string()),
        "{names:?}"
    );

    // A change that names nothing changes nothing, and a format there is none of is refused.
    let (status, settings) = server.patch("/api/settings", json!({})).await;
    assert_eq!((status, &settings["export_format"]), (200, &json!("ccv4")));
    let (status, _) = server
        .patch("/api/settings", json!({"export_format": "charx"}))
        .await;
    assert_eq!(status, 422);
    // The choice outlives the server.
    let server = server.restart().await;
    let (_, settings) = server.get("/api/settings").await;
    assert_eq!(settings["export_format"], "ccv4");

    let (status, _) = server.get("/api/cards/999/export").await;
    assert_eq!(status, 404);
}

#[test]
fn a_changed_setting_leaves_what_a_newer_build_wrote() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let stored = || -> serde_json::Value {
        let text: String = db
            .with(|conn| {
                conn.query_row("select settings from users where id = ?1", [me], |r| {
                    r.get(0)
                })
            })
            .unwrap();
        serde_json::from_str(&text).unwrap()
    };
    // A format this build has none of, and a choice it does not know.
    db.with(|conn| {
        conn.execute(
            "update users set settings = ?1",
            [r#"{"export_format":"charx","theme":"dark"}"#],
        )
    })
    .unwrap();
    assert_eq!(
        settings::get(db, me).unwrap().export_format,
        ExportFormat::SillytavernV3
    );

    // A change that names nothing writes nothing.
    settings::change(db, me, &ChangeSettings::default()).unwrap();
    assert_eq!(stored(), json!({"export_format": "charx", "theme": "dark"}));
    let changed = settings::change(
        db,
        me,
        &ChangeSettings {
            export_format: Some(ExportFormat::Ccv4),
            ..ChangeSettings::default()
        },
    )
    .unwrap();
    assert_eq!(changed.export_format, ExportFormat::Ccv4);
    assert_eq!(stored(), json!({"export_format": "ccv4", "theme": "dark"}));
    assert!(settings::change(db, me + 99, &ChangeSettings::default()).is_err());
}

#[tokio::test]
async fn an_exported_file_is_named_after_the_card() {
    let server = start().await;
    let titled = |title: &str| {
        let mut container = common::container();
        container.toml[0].1 = container.toml[0]
            .1
            .replace("\"Mira of the North Light\"", &json!(title).to_string());
        png::write(&container).unwrap()
    };
    for (title, name) in [
        ("Who/What: \"Why\"? <*|>\\", "Who_What_ _Why__ _____.png"),
        ("Søren & 灯台.", "Søren & 灯台.png"),
        (" ... ", "card.png"),
        (
            &"long ".repeat(40),
            &format!("{}.png", "long ".repeat(16).trim_end()),
        ),
    ] {
        let card = add(&server, titled(title)).await;
        let (headers, _) = server.download(&format!("/api/cards/{card}/export")).await;
        assert_eq!(file_name(&headers), name, "{title:?}");
    }
}

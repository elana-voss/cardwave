//! SillyTavern's card exported and imported again (`ccv4::sillytavern::export`).
// The sample card is one large `json!`.
#![recursion_limit = "256"]

mod common;
#[path = "common/sillytavern_sample.rs"]
mod shared;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::{card_data, card_png, encoded, picture, png_with, text_chunk};
use cw_ccv4::png::{self, Container};
use cw_ccv4::sillytavern;
use serde_json::{Value as Json, json};
use shared::{Converted, built_cards, convert, sample};

/// The sample card with files: one in a chunk of its own, one inline, one only linked.
fn sample_with_files() -> Vec<u8> {
    const HAPPY: &[u8] = &[0, 1, 2, 255, 254];
    let mut card = sample();
    card["data"]["assets"] = json!([
        {"type": "icon", "uri": "ccdefault:", "name": "main", "ext": "png"},
        {"type": "icon", "uri": format!("data:image/png;base64,{}", STANDARD.encode(b"alt icon")), "name": "alt", "ext": "png"},
        {"type": "emotion", "uri": "__asset:happy.webp", "name": "happy", "ext": "webp"},
        {"type": "background", "uri": "https://example.com/bg.png", "name": "forest", "ext": "png"},
    ]);
    png_with(vec![
        text_chunk(
            "chara-ext-asset_:happy.webp",
            STANDARD.encode(HAPPY).as_bytes(),
        ),
        text_chunk("ccv3", &encoded(&card)),
    ])
}

/// Asserts that `file`, exported and imported again, is the card it was. `same_spec`
/// is false for a card that was not V3: the export always is.
fn assert_goes_back(name: &str, first: &Converted, same_spec: bool) -> Vec<u8> {
    let exported = sillytavern::export(&first.container, None)
        .unwrap_or_else(|error| panic!("{name}: {error:#}"));
    let again = convert(&exported);
    let (mut was, mut is) = (first.raw.clone(), again.raw.clone());
    if !same_spec {
        for card in [&mut was, &mut is] {
            for (_, origin) in card["sillytavern"].as_table_mut().unwrap() {
                let origin = origin.as_table_mut().unwrap();
                origin.remove("spec");
                origin.remove("spec-version");
            }
        }
    }
    assert_eq!(is, was, "{name}");
    let sorted = |container: &Container| {
        let mut assets = container.assets.clone();
        assets.sort();
        assets
    };
    assert_eq!(sorted(&again.container), sorted(&first.container), "{name}");
    assert_eq!(again.container.image, first.container.image, "{name}");
    assert_eq!(again.notes, first.notes, "{name}");
    exported
}

#[test]
fn an_exported_card_imports_as_the_card_it_was() {
    let first = convert(&sample_with_files());
    assert_eq!(first.container.assets.len(), 2);
    let exported = assert_goes_back("sample", &first, true);

    // The file says what the card said, in SillyTavern's own fields.
    let (was, is) = (&sample()["data"], card_data(&exported));
    for key in [
        "name",
        "nickname",
        "personality",
        "scenario",
        "first_mes",
        "group_only_greetings",
        "mes_example",
        "system_prompt",
        "post_history_instructions",
        "creator_notes",
        "creator_notes_multilingual",
        "creator",
        "character_version",
        "source",
        "creation_date",
        // What CCV4 has no place for comes back untouched.
        "extensions",
    ] {
        assert_eq!(is[key], was[key], "{key}");
    }
    assert_eq!(is["description"], "A maintenance robot.\nIt hums.");
    assert_eq!(is["alternate_greetings"], json!(["Boop.", "Whirr."]));
    assert_eq!(is["tags"], json!(["robot", "sci-fi"]));
    assert_eq!(is["modification_date"], 1777802024);
    let book = &is["character_book"];
    assert_eq!(
        (&book["name"], &book["scan_depth"], &book["token_budget"]),
        (&json!("Station log"), &json!(5), &json!(500))
    );
    let entries = book["entries"].as_array().unwrap();
    assert_eq!(entries.len(), 3);
    let wiper = &entries[0];
    assert_eq!(wiper["keys"], json!(["wiper", "virus"]));
    assert_eq!(wiper["secondary_keys"], json!(["fear"]));
    assert_eq!(
        (&wiper["comment"], &wiper["content"]),
        (&json!("The Wiper"), &json!("A virus."))
    );
    assert_eq!(
        (&wiper["selective"], &wiper["use_regex"], &wiper["constant"]),
        (&json!(true), &json!(true), &json!(false))
    );
    assert_eq!(
        wiper["extensions"],
        json!({
            "position": 4, "depth": 3, "role": 2, "probability": 40, "useProbability": true, "selectiveLogic": 2,
            "match_whole_words": true, "sticky": 2, "delay": 1, "scan_depth": 6, "ignore_budget": true
        })
    );
    assert_eq!(
        (
            &entries[1]["constant"],
            &entries[1]["enabled"],
            &entries[1]["priority"]
        ),
        (&json!(true), &json!(false), &json!(7))
    );
    assert_eq!(entries[1]["insertion_order"], 100);
    assert_eq!(
        entries[1]["extensions"]["character_filter"],
        json!({"names": ["Seven"], "tags": [], "is_exclude": true})
    );
    assert_eq!(entries[2]["extensions"], json!({"vectorized": true}));
    // The picture is the character's icon, and each file is named by its chunk.
    assert_eq!(
        is["assets"],
        json!([
            {"type": "icon", "name": "main", "uri": "ccdefault:", "ext": "png"},
            {"type": "icon", "name": "alt", "uri": "__asset:0", "ext": "png"},
            {"type": "emotion", "name": "happy", "uri": "__asset:1", "ext": "webp"},
            {"type": "background", "name": "forest", "uri": "https://example.com/bg.png", "ext": "png"},
        ])
    );
}

#[test]
fn an_exported_card_is_v3_with_a_v2_copy() {
    let exported = sillytavern::export(&convert(&card_png(&sample())).container, None).unwrap();
    let (picture_left, texts) = png::take_text(&exported, |_| true).unwrap();
    assert_eq!(picture_left, picture());
    let cards: Vec<(String, Json)> = texts
        .iter()
        .map(|(keyword, text)| {
            (
                keyword.clone(),
                serde_json::from_slice(&STANDARD.decode(text).unwrap()).unwrap(),
            )
        })
        .collect();
    let [(v2_keyword, v2), (v3_keyword, v3)] = cards.as_slice() else {
        panic!("{} chunks", cards.len())
    };
    assert_eq!(
        (v2_keyword.as_str(), &v2["spec"], &v2["spec_version"]),
        ("chara", &json!("chara_card_v2"), &json!("2.0"))
    );
    assert_eq!(
        (v3_keyword.as_str(), &v3["spec"], &v3["spec_version"]),
        ("ccv3", &json!("chara_card_v3"), &json!("3.0"))
    );
    assert_eq!(v2["data"], v3["data"]);
    assert_eq!(v3["data"]["name"], "Unit 734");
    // A card without files lists none.
    assert!(v3["data"].get("assets").is_none());
}

#[test]
fn what_ccv4_keeps_itself_wins_over_the_extensions_as_they_came() {
    let mut container = convert(&card_png(&sample())).container;
    let toml = &mut container.toml[0].1;
    assert!(toml.contains("group-talkativeness = 0.8") && toml.contains("Remember the hum."));
    *toml = toml
        .replace("group-talkativeness = 0.8", "group-talkativeness = 0.25")
        .replace("Remember the hum.", "Forget the hum.");
    let extensions =
        card_data(&sillytavern::export(&container, None).unwrap())["extensions"].clone();
    assert_eq!(extensions["talkativeness"], 0.25);
    // A talkativeness beyond the most there is, is written as the most.
    container.toml[0].1 = container.toml[0]
        .1
        .replace("group-talkativeness = 0.25", "group-talkativeness = 1.5");
    let most = card_data(&sillytavern::export(&container, None).unwrap());
    assert_eq!(most["extensions"]["talkativeness"], 1.0);
    assert_eq!(
        extensions["depth_prompt"],
        json!({"prompt": "Forget the hum.", "depth": 2, "role": "user"})
    );
    assert_eq!(extensions["fav"], true);

    // A note the card no longer has is no longer in the file.
    let without = container.toml[0].1.replace("\"prompt.unit-734-note\",", "");
    assert_ne!(without, container.toml[0].1);
    container.toml[0].1 = without;
    let extensions =
        card_data(&sillytavern::export(&container, None).unwrap())["extensions"].clone();
    assert!(extensions.get("depth_prompt").is_none(), "{extensions}");
}

#[test]
fn the_avatar_stays_the_avatar_on_the_way_back() {
    let icon =
        |name: &str, uri: &str| json!({"type": "icon", "uri": uri, "name": name, "ext": "png"});
    for (assets, avatar) in [
        (
            vec![icon("alt", "__asset:a"), icon("main", "__asset:b")],
            Some("card/assets/icon/main.png"),
        ),
        (
            vec![icon("alt", "__asset:a"), icon("other", "__asset:b")],
            Some("card/assets/icon/alt.png"),
        ),
        (
            vec![icon("alt", "__asset:a"), icon("main", "ccdefault:")],
            None,
        ),
    ] {
        let card = json!({"spec": "chara_card_v3", "spec_version": "3.0", "data": {"name": "Ada", "description": "x", "assets": assets}});
        // Only the files the card lists: one it does not list is left behind, with a note.
        let mut chunks: Vec<Vec<u8>> = ["a", "b"]
            .into_iter()
            .filter(|file| card.to_string().contains(&format!("__asset:{file}")))
            .map(|file| {
                text_chunk(
                    &format!("chara-ext-asset_:{file}"),
                    STANDARD.encode(file).as_bytes(),
                )
            })
            .collect();
        chunks.push(text_chunk("ccv3", &encoded(&card)));
        let first = convert(&png_with(chunks));
        assert_eq!(first.document.avatar("ada"), avatar);
        let exported = assert_goes_back("avatar", &first, true);
        assert_eq!(convert(&exported).document.avatar("ada"), avatar);
    }
}

/// What this does not cover: the doc of `every_built_card_imports_field_for_field`.
#[test]
fn every_built_card_goes_back_as_it_came() {
    for (name, file, is_v3) in built_cards() {
        assert_goes_back(name, &convert(&file), is_v3);
    }
}

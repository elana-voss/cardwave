// The sample card is one large `json!`.
#![recursion_limit = "256"]

mod common;

use base64::Engine;
use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD};
use common::{Scratch, card_data, card_png, encoded, picture, png_with, text_chunk};
use cw_ccv4::png;
use cw_ccv4::{mapping, sillytavern};
use cw_chat::chats::{self, NewChat};
use cw_library::cards;
use cw_prompt::lorebook::evaluate;
use cw_prompt::{ChatMessage, ChatState, Role, SelectiveLogic};
use serde_json::{Value as Json, json};
use shared::{Converted, built_cards, convert, sample};

#[path = "common/sillytavern_sample.rs"]
mod shared;

fn error_of(file: &[u8]) -> String {
    format!("{:#}", sillytavern::convert(file).unwrap_err())
}

#[test]
fn a_card_lands_where_the_spec_puts_it() {
    let Converted {
        container,
        notes,
        document,
        raw,
    } = convert(&card_png(&sample()));
    assert!(notes.is_empty(), "{notes:?}");
    // The picture no longer carries the card.
    assert_eq!(container.image, picture());
    assert!(container.assets.is_empty());

    assert_eq!(document.ids("character"), ["unit-734"]);
    assert_eq!(document.title(), "Unit 734");
    assert_eq!(document.character_label("unit-734"), "Unit 734");
    assert_eq!(document.character_name("unit-734"), "Seven");
    assert_eq!(document.text("name.unit-734"), Some("Unit 734"));
    assert_eq!(
        document.text("description.unit-734"),
        Some("A maintenance robot.\nIt hums.")
    );
    assert_eq!(
        document.greetings("unit-734", false),
        ["Beep.", "Boop.", "Whirr."]
    );
    assert_eq!(document.greetings("unit-734", true), ["Hello, all."]);
    assert_eq!(document.tags(), ["robot", "sci-fi"]);
    assert_eq!(document.avatar("unit-734"), None);

    let character = &raw["character"]["unit-734"];
    let template: Vec<&str> = character["prompt"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|v| v.as_str())
        .collect();
    assert_eq!(
        template,
        [
            "prompt.unit-734-system",
            "name.unit-734",
            "description.unit-734",
            "personality.unit-734",
            "scenario.unit-734",
            "dialogue-example.unit-734",
            "prompt.unit-734-note",
            "LOREBOOK",
            "CHAT-HISTORY",
            "prompt.unit-734-post-history",
        ]
    );
    assert_eq!(character["group-talkativeness"].as_float(), Some(0.8));
    assert_eq!(
        character["creator-note"].as_str(),
        Some("creator-note.unit-734")
    );
    assert_eq!(
        raw["creator-note"]["unit-734-de"]["language"].as_str(),
        Some("de")
    );
    assert_eq!(
        raw["creator-note"]["unit-734-de"]["text"].as_str(),
        Some("Viel Spaß.")
    );

    let meta = &raw["meta-info"];
    assert_eq!(meta["creator"].as_str(), Some("erin"));
    assert_eq!(meta["version"].as_str(), Some("1.2"));
    assert_eq!(
        meta["source"].as_str(),
        Some("https://example.com/unit-734")
    );
    assert_eq!(meta["created"].to_string(), "2026-05-03T09:53:10Z");
    assert_eq!(meta["modified"].to_string(), "2026-05-03T09:53:44Z");

    let lorebook = &raw["lorebook"]["unit-734"];
    assert_eq!(lorebook["name"].as_str(), Some("Station log"));
    assert!(lorebook.get("recursive-scanning").is_none());
    assert_eq!(
        raw["lore"]["unit-734-the-wiper"]["name"].as_str(),
        Some("The Wiper")
    );
    assert_eq!(
        raw["lore"]["unit-734-the-wiper-2"]["trigger"].as_str(),
        Some("vector")
    );

    // What CCV4 has no place for is kept as it came.
    let origin = &raw["sillytavern"]["unit-734"];
    assert_eq!(origin["spec"].as_str(), Some("chara_card_v3"));
    assert_eq!(origin["spec-version"].as_str(), Some("3.0"));
    let kept: Json = serde_json::from_str(origin["extensions"].as_str().unwrap()).unwrap();
    assert_eq!(kept, sample()["data"]["extensions"]);
}

#[test]
fn the_prompt_builder_gets_what_the_card_meant() {
    let document = convert(&card_png(&sample())).document;
    let character = mapping::character(&document, "unit-734").unwrap();
    // The model is told the name; {{char}} is the nickname.
    assert_eq!(
        (character.name.as_str(), character.display_name()),
        ("Unit 734", "Seven")
    );
    assert_eq!(character.system_prompt, "Stay in character.");
    assert_eq!(character.description, "A maintenance robot.\nIt hums.");
    assert_eq!(character.personality, "Curious.");
    assert_eq!(character.scenario, "A dead station.");
    assert_eq!(
        character.mes_example,
        "<START>\n{{user}}: Hi\n{{char}}: Beep."
    );
    assert_eq!(character.post_history_instructions, "Short replies.");
    let [note] = character.depth_prompts.as_slice() else {
        panic!("{:?}", character.depth_prompts)
    };
    assert_eq!(
        (note.prompt.as_str(), note.depth, note.role),
        ("Remember the hum.", 2, Role::User)
    );

    let book = character.lorebook.unwrap();
    assert_eq!((book.scan_depth, book.token_budget), (Some(5), 500));
    let [wiper, constant, vector] = book.entries.as_slice() else {
        panic!("{:?}", book.entries)
    };

    assert_eq!(wiper.id.as_deref(), Some("lore.unit-734-the-wiper"));
    assert_eq!(wiper.keys, ["wiper", "virus"]);
    assert_eq!(wiper.secondary_keys, ["fear"]);
    assert_eq!(wiper.content, "A virus.");
    assert!(
        wiper.enabled
            && wiper.selective
            && wiper.use_regex
            && wiper.match_whole_words
            && wiper.ignore_budget
    );
    assert!(!wiper.constant && !wiper.case_sensitive);
    assert_eq!(wiper.selective_logic, SelectiveLogic::NotAny);
    assert_eq!(
        (wiper.at_depth, wiper.depth, wiper.role),
        (true, 3, Role::Assistant)
    );
    assert_eq!(
        (wiper.probability, wiper.insertion_order, wiper.priority),
        (40, 1, 0)
    );
    assert_eq!((wiper.sticky, wiper.cooldown, wiper.delay), (2, 0, 1));
    // An entry's own scan depth is kept; one that names none goes by its lorebook's.
    assert_eq!((wiper.scan_depth, constant.scan_depth), (Some(6), None));
    assert!(wiper.character_filter.is_none());

    assert_eq!(constant.id.as_deref(), Some("lore.unit-734-entry"));
    assert!(constant.constant && !constant.enabled && !constant.at_depth);
    assert_eq!(constant.content, "Always there.");
    // SillyTavern's order for an entry that names none.
    assert_eq!(
        (
            constant.priority,
            constant.insertion_order,
            constant.probability
        ),
        (7, 100, 100)
    );
    let filter = constant.character_filter.as_ref().unwrap();
    assert_eq!(filter.names, ["Seven"]);
    assert!(filter.tags.is_empty() && filter.is_exclude);

    // Two entries of one name, and a chance the card had switched off.
    assert_eq!(vector.id.as_deref(), Some("lore.unit-734-the-wiper-2"));
    assert_eq!((vector.content.as_str(), vector.probability), ("", 100));
}

#[test]
fn the_v3_chunk_wins_and_a_broken_one_gives_way() {
    let named = |name: &str| encoded(&json!({"data": {"name": name, "description": "x"}}));
    let both = png_with(vec![
        text_chunk("chara", &named("Two")),
        text_chunk("ccv3", &named("Three")),
    ]);
    assert_eq!(convert(&both).document.title(), "Three");

    let fallback = png_with(vec![
        text_chunk("ccv3", b"!!! not base64 !!!"),
        text_chunk("chara", &named("Two")),
    ]);
    assert_eq!(convert(&fallback).document.title(), "Two");

    // So does one that holds nothing.
    let hollow = encoded(&json!({"spec": "chara_card_v3", "data": {}}));
    let filled = png_with(vec![
        text_chunk("ccv3", &hollow),
        text_chunk("chara", &named("Two")),
    ]);
    assert_eq!(convert(&filled).document.title(), "Two");

    let broken = png_with(vec![text_chunk(
        "chara",
        &STANDARD.encode("{\"name\": ").into_bytes(),
    )]);
    assert!(error_of(&broken).contains("cannot be read"));
    let list = png_with(vec![text_chunk(
        "chara",
        &STANDARD.encode("[1, 2]").into_bytes(),
    )]);
    assert!(error_of(&list).contains("not a JSON object"));
    // Nesting deep enough to exhaust a naive parser's stack.
    let deep = format!(
        "{{\"name\": \"x\", \"extensions\": {}{}}}",
        "[".repeat(100_000),
        "]".repeat(100_000)
    );
    assert!(
        error_of(&png_with(vec![text_chunk(
            "chara",
            &STANDARD.encode(deep).into_bytes()
        )]))
        .contains("JSON")
    );
    let empty =
        card_png(&json!({"spec": "chara_card_v2", "data": {"tags": ["a"], "creator": "nobody"}}));
    assert!(error_of(&empty).contains("empty"));

    // Other text in a PNG is not a card.
    assert!(sillytavern::convert(&picture()).unwrap().is_none());
    assert!(
        sillytavern::convert(&png_with(vec![text_chunk("Comment", b"made with love")]))
            .unwrap()
            .is_none()
    );
    assert!(sillytavern::convert(b"GIF89a").is_err());
}

#[test]
fn card_data_is_read_however_a_tool_wrote_it() {
    let card = json!({"spec": "chara_card_v2", "data": {"name": "Wren", "first_mes": "Hello there, traveller."}});
    let plain = card.to_string();
    // Broken into lines and without padding, as some encoders leave it.
    let unpadded = STANDARD_NO_PAD.encode(&plain);
    assert_ne!(unpadded.len() % 4, 0);
    let wrapped: Vec<u8> = unpadded
        .as_bytes()
        .chunks(20)
        .flat_map(|line| [line, b"\r\n"].concat())
        .collect();
    let trailing = STANDARD
        .encode(format!("\u{feff}{plain}\0\0 left over"))
        .into_bytes();
    for (keyword, text) in [
        ("chara", wrapped),
        ("Chara", trailing),
        ("ccv3", format!("  {plain}").into_bytes()),
    ] {
        let document = convert(&png_with(vec![text_chunk(keyword, &text)])).document;
        assert_eq!(document.title(), "Wren", "{keyword}");
        assert_eq!(
            document.greetings("wren", false),
            ["Hello there, traveller."]
        );
    }
}

#[test]
fn oddly_typed_fields_are_coerced_or_skipped() {
    // The oldest form: the fields without a `data` wrapper.
    let card = json!({
        "name": null,
        "nickname": "Ghost",
        "description": 42,
        "personality": ["not", "text"],
        "scenario": {"not": "text"},
        "first_mes": "",
        "alternate_greetings": "Only one.",
        "group_only_greetings": null,
        "tags": "Fantasy, dark , fantasy",
        "character_version": 1.5,
        "creator_notes_multilingual": ["wrong"],
        "extensions": "none",
        "assets": "none",
        "source": "a site",
        "creation_date": "yesterday",
        "modification_date": -5,
        "character_book": {
            "scan_depth": "3",
            "token_budget": -5,
            "entries": [
                "not an entry",
                {
                    "keys": "single",
                    "secondary_keys": ["a", 2, null],
                    "content": 7,
                    "enabled": "false",
                    "constant": 1,
                    "insertion_order": "5",
                    "priority": 2.9,
                    "selective": "true",
                    "selectiveLogic": "3",
                    "position": "atDepth",
                    "extensions": []
                },
                {
                    "keys": [],
                    "content": "x",
                    "insertion_order": 1e300,
                    "extensions": {"sticky": true, "depth": -3, "position": "4"}
                }
            ]
        }
    });
    let Converted {
        document,
        raw,
        notes,
        ..
    } = convert(&card_png(&card));
    assert!(notes.is_empty(), "{notes:?}");
    assert_eq!(document.ids("character"), ["character"]);
    assert_eq!(document.title(), "Ghost");
    assert_eq!(document.character_name("character"), "Ghost");
    assert_eq!(document.text("description.character"), Some("42"));
    assert!(raw.get("personality").is_none() && raw.get("scenario").is_none());
    assert_eq!(document.greetings("character", false), ["Only one."]);
    assert_eq!(document.tags(), ["fantasy", "dark"]);
    let meta = raw["meta-info"].as_table().unwrap();
    assert_eq!(meta["version"].as_str(), Some("1.5"));
    assert_eq!(meta["source"].as_str(), Some("a site"));
    assert!(!meta.contains_key("created") && !meta.contains_key("modified"));
    assert!(!raw.contains_key("sillytavern"));

    let lorebook = raw["lorebook"]["character"].as_table().unwrap();
    assert_eq!(lorebook["scan-depth"].as_integer(), Some(3));
    assert!(!lorebook.contains_key("token-budget"));
    let book = mapping::character(&document, "character")
        .unwrap()
        .lorebook
        .unwrap();
    let [first, second] = book.entries.as_slice() else {
        panic!("{:?}", book.entries)
    };
    assert_eq!(first.id.as_deref(), Some("lore.character-single"));
    assert_eq!(
        (first.keys.as_slice(), first.content.as_str()),
        (&["single".to_string()][..], "7")
    );
    assert_eq!(first.secondary_keys, ["a", "2"]);
    assert!(!first.enabled && first.constant && first.selective);
    assert_eq!(
        (first.insertion_order, first.priority, first.selective_logic),
        (5, 2, SelectiveLogic::AndAll)
    );
    assert_eq!((first.at_depth, first.depth), (true, 4));
    assert_eq!(second.id.as_deref(), Some("lore.character-entry"));
    assert_eq!(
        (
            second.insertion_order,
            second.sticky,
            second.at_depth,
            second.depth
        ),
        (i64::MAX, 1, true, 0)
    );
}

#[test]
fn any_text_survives_the_way_into_toml() {
    let nasty = [
        "three \"\"\" quotes and '''",
        "back\\slash \\n and a trailing \\",
        "tab\tand \u{0} nul, \u{7f} and \u{1b}[31m escapes",
        "line one\nline two\n\n[lore.fake]\ntext = \"x\"",
        "\"",
        "\"\"\"",
        "'''",
        "ends with a quote\"",
        "text = \"\"\"",
        "# not a comment",
        "{{char}} 🤖 ấ 日本語 \u{202e}reversed",
        "a\u{2028}b",
    ];
    let entry = |text: &&str| json!({"keys": [text], "comment": text, "content": text});
    let entries: Vec<Json> = nasty.iter().map(entry).collect();
    let card = json!({"data": {
        "name": "ấ 日本語 🤖",
        "description": "one\r\ntwo\rthree",
        "first_mes": nasty[0],
        "alternate_greetings": nasty[1..],
        "tags": nasty,
        "creator_notes_multilingual": {"\"]\n[x": "note", "": "blank language"},
        "character_book": {"name": nasty[3], "entries": entries},
        "extensions": {"\"key\"\n": nasty}
    }});
    let Converted { document, raw, .. } = convert(&card_png(&card));
    // A name without a single ASCII letter gives no usable ID.
    assert_eq!(document.ids("character"), ["character"]);
    assert_eq!(document.title(), "ấ 日本語 🤖");
    assert_eq!(
        document.text("description.character"),
        Some("one\ntwo\nthree")
    );
    assert_eq!(document.greetings("character", false), nasty);
    assert_eq!(document.tags(), nasty.map(str::to_lowercase));
    assert!(document.lookup("lore.fake").is_none());
    assert_eq!(
        raw["creator-note"]["character-x"]["language"].as_str(),
        Some("\"]\n[x")
    );
    let kept: Json = serde_json::from_str(
        raw["sillytavern"]["character"]["extensions"]
            .as_str()
            .unwrap(),
    )
    .unwrap();
    assert_eq!(kept, card["data"]["extensions"]);

    let book = mapping::character(&document, "character")
        .unwrap()
        .lorebook
        .unwrap();
    let contents: Vec<&str> = book
        .entries
        .iter()
        .map(|entry| entry.content.as_str())
        .collect();
    assert_eq!(contents, nasty);
    for (entry, text) in book.entries.iter().zip(nasty) {
        assert_eq!(entry.keys, [text]);
    }
    // IDs hold nothing but lowercase letters, digits and dashes.
    for kind in ["lore", "greeting", "creator-note", "lorebook", "name"] {
        for id in document.ids(kind) {
            assert!(
                id.chars()
                    .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-'),
                "{kind}.{id}"
            );
        }
    }
}

#[test]
fn thousands_of_entries_of_one_name_get_ids_of_their_own() {
    let entries: Vec<Json> = (0..5000)
        .map(|n| json!({"keys": ["k"], "comment": "Same", "content": n}))
        .collect();
    // One that already has the name a later one would be numbered to.
    let mut all = vec![json!({"keys": ["k"], "comment": "same 3", "content": "taken"})];
    all.extend(entries);
    let card = json!({"data": {"name": "Hive", "character_book": {"entries": all}}});
    let document = convert(&card_png(&card)).document;
    let ids = document.ids("lore");
    assert_eq!(ids.len(), 5001);
    assert_eq!(
        ids.iter().collect::<std::collections::HashSet<_>>().len(),
        5001
    );
    assert_eq!(document.text("lore.hive-same-3"), Some("taken"));
    assert_eq!(document.text("lore.hive-same-4"), Some("2"));
}

#[test]
fn a_converted_lorebook_works_in_a_chat() {
    let entry = |content: &str, more: Json| {
        let mut entry = json!({"keys": ["dragon"], "content": content});
        entry
            .as_object_mut()
            .unwrap()
            .extend(more.as_object().unwrap().clone());
        entry
    };
    let both = |logic: i64| json!({"selective": true, "secondary_keys": ["red", "gold"], "selectiveLogic": logic});
    let card = json!({"data": {
        "name": "Unit 734",
        "nickname": "Seven",
        "extensions": {"depth_prompt": {"prompt": "A note."}},
        "character_book": {"entries": [
            entry("By name.", json!({"character_filter": {"names": ["Unit 734"]}})),
            entry("By nickname.", json!({"extensions": {"character_filter": {"names": ["Seven"]}}})),
            entry("Not for Seven.", json!({"character_filter": {"names": ["Seven"], "is_exclude": true}})),
            entry("No second keys.", json!({"selective": true, "secondary_keys": []})),
            entry("Not both.", both(1)),
            entry("Both.", both(3)),
            entry("Always.", json!({"keys": [], "constant": true, "extensions": {"vectorized": true}})),
            entry("Outlet.", json!({"extensions": {"position": 7, "outlet_name": "facts"}})),
            entry("Off.", json!({"enabled": false})),
        ]}
    }});
    let Converted {
        document, notes, ..
    } = convert(&card_png(&card));
    assert_eq!(notes, [cw_ccv4::ImportNote::OutletEntriesOff { count: 1 }]);
    let character = mapping::character(&document, "unit-734").unwrap();
    // A note that names no depth sits where SillyTavern puts it.
    assert_eq!(character.depth_prompts[0].depth, 4);
    let mut chat = ChatState::default();
    chat.messages.push(ChatMessage::new(
        "1".to_string(),
        Role::User,
        "a red dragon",
    ));
    let mut active: Vec<String> = evaluate(&character, &mut chat)
        .into_iter()
        .map(|found| found.content)
        .collect();
    active.sort();
    assert_eq!(
        active,
        [
            "Always.",
            "By name.",
            "By nickname.",
            "No second keys.",
            "Not both."
        ]
    );

    // Entries in a form of their own are reported, not dropped in silence.
    let keyed = json!({"data": {"name": "x", "character_book": {"entries": {"0": {"keys": ["a"], "content": "b"}}}}});
    let Converted { notes, raw, .. } = convert(&card_png(&keyed));
    assert!(
        notes == [cw_ccv4::ImportNote::EntriesNotAList] && !raw.contains_key("lorebook"),
        "{notes:?}"
    );
}

#[test]
fn embedded_assets_come_along_and_links_are_not_followed() {
    const ICON: &[u8] = b"\x89PNG not really";
    const HAPPY: &[u8] = &[0, 1, 2, 255, 254];
    let inline = format!("data:image/png;base64,{}", STANDARD.encode(ICON));
    let card = json!({"spec": "chara_card_v3", "data": {
        "name": "Ada",
        "description": "x",
        "assets": [
            {"type": "icon", "uri": "ccdefault:", "name": "main", "ext": "png"},
            {"type": "icon", "uri": inline, "name": "alt", "ext": "png"},
            {"type": "emotion", "uri": "__asset:happy.webp", "name": "../../Happy", "ext": "WebP"},
            {"type": "emotion", "uri": "__asset:happy.webp", "name": "happy", "ext": "we/bp"},
            {"type": "background", "uri": "https://example.com/bg.png", "name": "forest", "ext": "png"},
            {"type": "emotion", "uri": "__asset:missing", "name": "sad", "ext": "png"},
            {"type": "..\\..", "uri": "data:image/png;base64,***", "name": "bad", "ext": "png"},
            {"type": "background", "uri": "__asset:0", "name": "room", "ext": "we/bp"},
            "junk"
        ]
    }});
    let comment = text_chunk("Comment", b"made with love");
    let file = png_with(vec![
        text_chunk(
            "chara-ext-asset_:happy.webp",
            STANDARD.encode(HAPPY).as_bytes(),
        ),
        text_chunk("chara-ext-asset_:unused", b"AAAA"),
        // Some tools leave the colon out.
        text_chunk("chara-ext-asset_0", STANDARD.encode(ICON).as_bytes()),
        comment.clone(),
        text_chunk("ccv3", &encoded(&card)),
    ]);
    let Converted {
        container,
        notes,
        document,
        raw,
    } = convert(&file);
    // Text that is not the card's stays in the picture.
    assert_eq!(container.image, png_with(vec![comment]));
    // A file two items share is kept once.
    assert_eq!(
        container.assets,
        [
            ("card/assets/icon/alt.png".to_string(), ICON.to_vec()),
            ("card/assets/emotion/happy.webp".to_string(), HAPPY.to_vec()),
            ("card/assets/background/room.bin".to_string(), ICON.to_vec()),
        ]
    );
    // The picture is the card's main icon.
    assert_eq!(document.avatar("ada"), None);
    use cw_ccv4::ImportNote::{AssetOnlyLinked, AssetUnreadable, UnlistedFiles};
    let [linked, sad, bad, unlisted] = notes.as_slice() else {
        panic!("{notes:?}")
    };
    let asset = |kind: &str, name: &str| (kind.to_string(), name.to_string());
    assert!(
        matches!(linked, AssetOnlyLinked { kind, name } if (kind.clone(), name.clone()) == asset("background", "forest"))
            && matches!(sad, AssetUnreadable { kind, name } if (kind.clone(), name.clone()) == asset("emotion", "sad"))
            && matches!(bad, AssetUnreadable { name, .. } if name == "bad")
            && *unlisted == UnlistedFiles { count: 1 },
        "{notes:?}"
    );

    let assets = raw["asset"].as_table().unwrap();
    assert_eq!(
        assets.keys().collect::<Vec<_>>(),
        [
            "ada-icon-alt",
            "ada-emotion-happy",
            "ada-emotion-happy-2",
            "ada-background-forest",
            "ada-background-room"
        ]
    );
    assert_eq!(
        assets["ada-emotion-happy"]["kind"].as_str(),
        Some("emotion")
    );
    assert_eq!(
        assets["ada-emotion-happy"]["name"].as_str(),
        Some("../../Happy")
    );
    for id in ["ada-emotion-happy", "ada-emotion-happy-2"] {
        assert_eq!(
            assets[id]["file"].as_str(),
            Some("asset://card/assets/emotion/happy.webp")
        );
    }
    assert_eq!(
        assets["ada-background-forest"]["uri"].as_str(),
        Some("https://example.com/bg.png")
    );
    // The result is a card file the CCV4 reader takes back.
    assert_eq!(
        png::read(&png::write(&container).unwrap()).unwrap(),
        container
    );
}

#[test]
fn the_avatar_is_the_main_icon_and_a_shared_file_is_decoded_once() {
    let icon =
        |name: &str, uri: &str| json!({"type": "icon", "uri": uri, "name": name, "ext": "png"});
    let converted = |assets: Vec<Json>| {
        let card = json!({"data": {"name": "Ada", "description": "x", "assets": assets}});
        let file = png_with(vec![
            text_chunk("chara-ext-asset_:a", STANDARD.encode("a").as_bytes()),
            text_chunk("chara-ext-asset_:b", STANDARD.encode("b").as_bytes()),
            text_chunk("chara", &encoded(&card)),
        ]);
        convert(&file)
    };
    let avatar = |assets: Vec<Json>| converted(assets).document.avatar("ada").map(str::to_string);
    // An icon named `main` wins wherever it stands; without one the first icon does.
    assert_eq!(
        avatar(vec![icon("alt", "__asset:a"), icon("main", "__asset:b")]).unwrap(),
        "card/assets/icon/main.png"
    );
    assert_eq!(
        avatar(vec![icon("alt", "__asset:a"), icon("other", "__asset:b")]).unwrap(),
        "card/assets/icon/alt.png"
    );
    assert_eq!(
        avatar(vec![icon("alt", "__asset:a"), icon("main", "ccdefault:")]),
        None
    );

    let many: Vec<Json> = (0..3000)
        .map(|n| icon(&format!("pose {n}"), "__asset:a"))
        .collect();
    let Converted { container, raw, .. } = converted(many);
    assert_eq!(
        container.assets,
        [("card/assets/icon/pose-0.png".to_string(), b"a".to_vec())]
    );
    assert_eq!(raw["asset"].as_table().unwrap().len(), 3000);
}

#[test]
fn an_imported_sillytavern_card_is_a_card_like_any_other() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let imported = cards::import(db, me, &card_png(&sample())).unwrap();
    assert_eq!((imported.title.as_str(), imported.version), ("Unit 734", 1));
    assert!(imported.warnings.is_empty(), "{:?}", imported.warnings);
    assert_eq!(
        cards::image(db, me, imported.version_id).unwrap().unwrap(),
        picture()
    );
    let document = cards::document(db, me, imported.version_id).unwrap();
    assert_eq!(document.character_name("unit-734"), "Seven");

    let new = NewChat {
        characters: &[(imported.version_id, "unit-734")],
        persona_id: None,
        greeting: 1,
    };
    let chat = chats::create(db, me, &new).unwrap();
    let opening: Vec<String> = chats::path(db, me, chat)
        .unwrap()
        .into_iter()
        .map(|m| m.content)
        .collect();
    assert_eq!(opening, ["Boop."]);
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert_eq!(
        inputs.character.description,
        "A maintenance robot.\nIt hums."
    );

    // A link the card only points at is reported, and the card still imports.
    let mut linked = sample();
    linked["data"]["assets"] =
        json!([{"type": "background", "uri": "https://example.com/a.png", "name": "a"}]);
    let warned = cards::import(db, me, &card_png(&linked)).unwrap();
    assert_eq!(warned.warnings.len(), 1, "{:?}", warned.warnings);

    // A file that is both stays the CCV4 card it is.
    let mut both = common::container();
    both.image = card_png(&sample());
    let ccv4 = cards::import(db, me, &png::write(&both).unwrap()).unwrap();
    assert_eq!(ccv4.title, "Mira of the North Light");

    let empty = card_png(&json!({"data": {}}));
    assert!(cards::import(db, me, &empty).is_err());
    assert_eq!(cards::list(db, me).unwrap().len(), 3);
}

/// Every card `built_cards` builds lands field for field, whatever chunks hold it. `card_data`
/// reads the file without the importer and prefers `ccv3`, as the importer must: the file with
/// both holds different cards in them. What this does not cover, accepted by the owner when the
/// tests stopped reading another project's real files (2026-11-03): pictures as real tools write
/// them, and whatever field quirks those files had. Of the Flutter app's shape the code shows only
/// tags in lower case or as one comma-separated text, tested on their own in this file.
#[test]
fn every_built_card_imports_field_for_field() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let clean = |value: &Json| {
        value
            .as_str()
            .unwrap_or("")
            .replace("\r\n", "\n")
            .trim()
            .to_string()
    };
    for (name, bytes, _) in built_cards() {
        let expected = card_data(&bytes);
        let imported =
            cards::import(db, me, &bytes).unwrap_or_else(|error| panic!("{name}: {error:#}"));
        assert!(
            imported.warnings.is_empty(),
            "{name}: {:?}",
            imported.warnings
        );
        assert_eq!(imported.title, clean(&expected["name"]), "{name}");

        let document = cards::document(db, me, imported.version_id).unwrap();
        let ids = document.ids("character");
        assert_eq!(ids.len(), 1, "{name}");
        let character = mapping::character(&document, ids[0]).unwrap();
        assert_eq!(character.name, clean(&expected["name"]), "{name}");
        let nickname = Some(clean(&expected["nickname"])).filter(|nickname| !nickname.is_empty());
        assert_eq!(
            character.display_name(),
            nickname.as_ref().unwrap_or(&character.name),
            "{name}"
        );
        for (got, key) in [
            (&character.description, "description"),
            (&character.personality, "personality"),
            (&character.scenario, "scenario"),
            (&character.system_prompt, "system_prompt"),
            (
                &character.post_history_instructions,
                "post_history_instructions",
            ),
            (&character.mes_example, "mes_example"),
        ] {
            assert_eq!(got, &clean(&expected[key]), "{name}: {key}");
        }
        let mut greetings = vec![clean(&expected["first_mes"])];
        greetings.extend(
            expected["alternate_greetings"]
                .as_array()
                .into_iter()
                .flatten()
                .map(clean),
        );
        greetings.retain(|greeting| !greeting.is_empty());
        assert_eq!(document.greetings(ids[0], false), greetings, "{name}");
        let entries = expected["character_book"]["entries"]
            .as_array()
            .map_or(0, Vec::len);
        assert_eq!(
            character.lorebook.map_or(0, |book| book.entries.len()),
            entries,
            "{name}"
        );
        let note = expected["extensions"]["depth_prompt"]["prompt"]
            .as_str()
            .unwrap_or("");
        let notes: Vec<&str> = character
            .depth_prompts
            .iter()
            .map(|p| p.prompt.as_str())
            .collect();
        assert_eq!(notes.concat(), note, "{name}");

        // The stored picture is the file without its card data.
        let image = cards::image(db, me, imported.version_id).unwrap().unwrap();
        assert!(image.len() < bytes.len(), "{name}");
        assert!(
            png::take_text(&image, |keyword| keyword == "ccv3" || keyword == "chara")
                .unwrap()
                .1
                .is_empty()
        );
    }
}

/// C4: a card whose data has no name (or one of spaces) takes its file's name, as a PNG and as a JSON
/// file, for its title and for what the chat calls it; never its internal ID.
#[test]
fn a_card_without_a_name_is_named_by_its_file() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let mut nameless = sample();
    nameless["data"]["name"] = json!("  ");
    nameless["data"].as_object_mut().unwrap().remove("nickname");
    let as_json = serde_json::to_vec(&nameless).unwrap();
    for (file, name) in [
        (card_png(&nameless), "Wren draft.png"),
        (as_json, "Bram v2.JSON"),
    ] {
        let imported = cards::import_named(db, me, &file, Some(name)).unwrap();
        let stem = name.rsplit_once('.').unwrap().0;
        assert_eq!(imported.title, stem);
        let document = cards::document(db, me, imported.version_id).unwrap();
        let first = &document.ids("character")[0];
        assert_eq!(document.character_name(first), stem);
    }
}

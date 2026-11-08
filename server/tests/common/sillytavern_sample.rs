//! What both SillyTavern test files share: the converting of a file, the sample card (V3) and
//! the files `built_cards` makes of it and of a V2 card, included by `#[path]` (its `json!` needs
//! the including file's `recursion_limit`).

use crate::common::{card_png, encoded, png_with, text_chunk};
use cw_ccv4::png::Container;
use cw_ccv4::{Document, ImportNote, sillytavern};
use serde_json::{Value as Json, json};

pub struct Converted {
    pub container: Container,
    pub notes: Vec<ImportNote>,
    pub document: Document,
    /// The written TOML as it parses, for keys the document has no accessor for.
    pub raw: toml::Table,
}

pub fn convert(file: &[u8]) -> Converted {
    let (container, notes) = sillytavern::convert(file).unwrap().expect("no card found");
    assert_eq!(container.toml.len(), 1);
    let document = Document::parse(&container.toml).unwrap();
    let assets: Vec<&str> = container
        .assets
        .iter()
        .map(|(name, _)| name.as_str())
        .collect();
    assert_eq!(document.warnings(&assets), []);
    let raw = toml::from_str(&container.toml[0].1).unwrap();
    Converted {
        container,
        notes,
        document,
        raw,
    }
}

pub fn sample() -> Json {
    json!({
        "spec": "chara_card_v3",
        "spec_version": "3.0",
        "data": {
            "name": "Unit 734",
            "nickname": "Seven",
            "description": "  A maintenance robot.\r\nIt hums.  ",
            "personality": "Curious.",
            "scenario": "A dead station.",
            "first_mes": "Beep.",
            "alternate_greetings": ["Boop.", "", "Whirr."],
            "group_only_greetings": ["Hello, all."],
            "mes_example": "<START>\n{{user}}: Hi\n{{char}}: Beep.",
            "system_prompt": "Stay in character.",
            "post_history_instructions": "Short replies.",
            "creator_notes": "Have fun.",
            "creator_notes_multilingual": {"de": "Viel Spaß.", "en": "Have fun."},
            "tags": ["Robot", "sci-fi", "robot", " "],
            "creator": "erin",
            "character_version": "1.2",
            "source": ["https://example.com/unit-734"],
            "creation_date": 1777801990,
            "modification_date": 1777802024000i64,
            "extensions": {
                "talkativeness": "0.8",
                "depth_prompt": {"prompt": "Remember the hum.", "depth": 2, "role": "user"},
                "fav": true,
                "world": null
            },
            "character_book": {
                "name": "Station log",
                "description": "What happened",
                "scan_depth": 5,
                "token_budget": 500,
                "recursive_scanning": false,
                "entries": [
                    {
                        "id": 1,
                        "keys": ["wiper", "virus"],
                        "secondary_keys": ["fear"],
                        "comment": "The Wiper",
                        "content": "A virus.",
                        "constant": false,
                        "selective": true,
                        "insertion_order": 1,
                        "enabled": true,
                        "position": "before_char",
                        "use_regex": true,
                        "extensions": {
                            "position": 4,
                            "depth": 3,
                            "role": 2,
                            "probability": 40,
                            "useProbability": true,
                            "selectiveLogic": 2,
                            "match_whole_words": true,
                            "case_sensitive": null,
                            "sticky": 2,
                            "cooldown": null,
                            "delay": 1,
                            "scan_depth": 6,
                            "vectorized": false,
                            "ignore_budget": true
                        }
                    },
                    {
                        "keys": [],
                        "content": "Always there.",
                        "constant": true,
                        "enabled": false,
                        "priority": 7,
                        "character_filter": {"names": ["Seven"], "tags": [], "is_exclude": true}
                    },
                    {
                        "keys": ["hum"],
                        "comment": "The Wiper",
                        "content": "",
                        "extensions": {"vectorized": true, "probability": 10, "useProbability": false}
                    }
                ]
            }
        }
    })
}

/// A real V2 card: only V2's fields in `data`, V1's copied at the top, as SillyTavern writes them.
pub fn v2_card() -> Json {
    json!({
        "name": "Pell Marsh",
        "description": "A ferryman.",
        "personality": "Patient.",
        "scenario": "A flooded valley.",
        "first_mes": "Mind the step.",
        "mes_example": "<START>
    {{char}}: Mind the step.",
        "spec": "chara_card_v2",
        "spec_version": "2.0",
        "data": {
            "name": "Pell Marsh",
            "description": "  A ferryman.
    He counts the bells.  ",
            "personality": "Patient.",
            "scenario": "A flooded valley.",
            "first_mes": "Mind the step.",
            "alternate_greetings": ["The river is high."],
            "mes_example": "<START>
    {{char}}: Mind the step.",
            "creator_notes": "For slow evenings.",
            "system_prompt": "Stay in character.",
            "post_history_instructions": "Short replies.",
            "tags": ["ferry", "river"],
            "creator": "erin",
            "character_version": "2",
            "extensions": {
                "talkativeness": "0.4",
                "depth_prompt": {"prompt": "Remember the bells.", "depth": 3, "role": "system"},
                "fav": false
            },
            "character_book": {
                "name": "The valley",
                "entries": [
                    {"keys": ["bell"], "content": "Nine bells drowned.", "enabled": true, "insertion_order": 1},
                    {"keys": ["ferry"], "content": "It has no name.", "enabled": true, "insertion_order": 2}
                ]
            }
        }
    })
}

/// The files both test files take through import and export: each one's name, its bytes, and
/// whether its card is V3 (the export always is). The one with both chunks holds different cards
/// in them, so that it shows which one is read; `chara` comes first, as SillyTavern writes them.
pub fn built_cards() -> Vec<(&'static str, Vec<u8>, bool)> {
    let least = json!({
        "spec": "chara_card_v2",
        "spec_version": "2.0",
        "data": {"name": "Ada", "first_mes": "Hello."}
    });
    vec![
        ("V2", card_png(&v2_card()), false),
        (
            "V2 with a name and a greeting alone",
            card_png(&least),
            false,
        ),
        (
            "V2 and V3",
            png_with(vec![
                text_chunk("chara", &encoded(&v2_card())),
                text_chunk("ccv3", &encoded(&sample())),
            ]),
            true,
        ),
    ]
}

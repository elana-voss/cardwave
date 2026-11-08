mod common;

use common::{chunk, header, picture, pixels, png_of};
use cw_ccv4::png::{self, Container};
use cw_ccv4::{Document, mapping};
use cw_prompt::Role;

fn ccv4_chunk(kind: &[u8; 4], name: &str, content: &[u8]) -> Vec<u8> {
    let mut payload = b"ccv4\0".to_vec();
    payload.extend_from_slice(name.as_bytes());
    payload.push(0);
    payload.extend_from_slice(content);
    chunk(kind, &payload)
}

fn file_with(chunks: Vec<Vec<u8>>) -> Vec<u8> {
    let mut all = vec![header(), pixels()];
    all.extend(chunks);
    all.push(chunk(b"IEND", &[]));
    png_of(&all)
}

fn error_of<T>(result: anyhow::Result<T>) -> String {
    match result {
        Ok(_) => panic!("expected an error"),
        Err(e) => format!("{e:#}"),
    }
}

fn one(name: &str, text: &str) -> Vec<(String, String)> {
    vec![(name.to_string(), text.to_string())]
}

#[test]
fn a_card_file_comes_apart_and_goes_back_together() {
    let container = common::container();
    let file = png::write(&container).unwrap();
    assert_eq!(png::read(&file).unwrap(), container);
    // The picture alone is still a PNG, and writing it back changes nothing.
    assert_eq!(
        png::read(&picture()).unwrap(),
        Container {
            image: picture(),
            ..Default::default()
        }
    );
    assert_eq!(
        png::write(&Container {
            image: picture(),
            ..Default::default()
        })
        .unwrap(),
        picture()
    );
}

#[test]
fn chunks_of_other_apps_stay_in_the_picture() {
    let foreign = chunk(b"toMl", b"someone else's data");
    let text = chunk(b"tEXt", b"chara\0e30=");
    let file = file_with(vec![
        foreign.clone(),
        ccv4_chunk(b"toMl", "card/a.toml", b"spec = \"ccv4:1.0.0\""),
        text.clone(),
    ]);
    let container = png::read(&file).unwrap();
    assert_eq!(container.toml, one("card/a.toml", "spec = \"ccv4:1.0.0\""));
    assert_eq!(container.image, file_with(vec![foreign, text]));
}

#[test]
fn broken_files_are_refused() {
    assert!(error_of(png::read(b"GIF89a")).contains("not a PNG"));
    let cut_short = &picture()[..picture().len() - 12];
    assert!(error_of(png::read(cut_short)).contains("ends before"));

    // A byte inside the first TOML file's text.
    let mut damaged = common::card_file();
    damaged[100] ^= 0xFF;
    assert!(error_of(png::read(&damaged)).contains("damaged"));

    for name in [
        "card/../secret.toml",
        "card/./a.toml",
        "notes.toml",
        "card/a\\b.toml",
        "/card/a.toml",
    ] {
        let file = file_with(vec![ccv4_chunk(b"asEt", name, b"x")]);
        assert!(png::read(&file).is_err(), "{name} was accepted");
    }
    let twice = file_with(vec![
        ccv4_chunk(b"asEt", "card/a", b"x"),
        ccv4_chunk(b"toMl", "card/a", b""),
    ]);
    assert!(error_of(png::read(&twice)).contains("used twice"));
    let nameless = file_with(vec![chunk(b"asEt", b"ccv4\0card/a")]);
    assert!(error_of(png::read(&nameless)).contains("no file name"));
}

#[test]
fn files_merge_into_one_document() {
    let document = Document::parse(&common::files()).unwrap();
    assert_eq!(document.title(), "Mira of the North Light");
    assert_eq!(document.tags(), ["sea", "mystery"]);
    assert_eq!(document.ids("character"), ["mira", "bare"]);
    assert_eq!(document.character_name("mira"), "Mira");
    assert_eq!(document.character_label("mira"), "Mira (storm night)");
    assert_eq!(document.avatar("mira"), Some("card/images/mira.png"));
    assert_eq!(
        document.greetings("mira", false),
        [
            "\"You picked a night for it, {{user}}.\"",
            "Hold the lamp. Don't ask."
        ]
    );
    assert_eq!(document.greetings("mira", true), ["All of you, inside."]);
    assert!(document.warnings(&["card/images/mira.png"]).is_empty());
    // A character without names goes by its ID.
    assert_eq!(document.character_name("bare"), "bare");
    assert_eq!(document.character_label("bare"), "bare");
    assert!(document.greetings("bare", false).is_empty());
}

#[test]
fn the_newest_pinned_draft_replaces_its_block() {
    let document = Document::parse(&common::files()).unwrap();
    assert_eq!(document.text("personality.mira"), Some("Wry, patient."));

    // A pin never brings back a block that is gone.
    let orphan = "spec = \"ccv4:1.0.0\"\n[revision.\"scenario.gone\"]\n\
                  drafts = [{ saved = 2026-07-08T09:00:00Z, pinned = true, payload = { text = \"Back.\" } }]";
    let document = Document::parse(&one("user/r.toml", orphan)).unwrap();
    assert_eq!(document.text("scenario.gone"), None);
}

#[test]
fn documents_that_cannot_be_trusted_are_refused() {
    let spec = "spec = \"ccv4:1.0.0\"\n";
    assert!(
        error_of(Document::parse(&one(
            "card/a.toml",
            "[name.a]\ntext = \"A\""
        )))
        .contains("no spec version")
    );
    assert!(
        error_of(Document::parse(&one(
            "card/a.toml",
            "spec = \"ccv4:2.0.0\""
        )))
        .contains("version 2")
    );
    assert!(
        error_of(Document::parse(&one("card/a.toml", "spec = \"v4\""))).contains("not of the form")
    );
    assert!(
        error_of(Document::parse(&one("card/a.toml", "spec = ")))
            .contains("card/a.toml is not valid TOML")
    );

    let mut files = one("card/a.toml", &format!("{spec}[name.a]\ntext = \"A\""));
    files.push((
        "card/b.toml".to_string(),
        "[name.b]\ntext = \"B\"".to_string(),
    ));
    assert_eq!(Document::parse(&files).unwrap().ids("name"), ["a", "b"]);
    files.push((
        "card/c.toml".to_string(),
        "[name.a]\ntext = \"Again\"".to_string(),
    ));
    assert!(error_of(Document::parse(&files)).contains("name.a is defined in more than one file"));

    let mut files = one("card/a.toml", spec);
    files.push(("card/b.toml".to_string(), spec.to_string()));
    assert!(error_of(Document::parse(&files)).contains("spec is defined in more than one file"));
}

#[test]
fn loose_ends_are_reported_as_warnings() {
    let card = "spec = \"ccv4:1.0.0\"\n\
                [character.a]\n\
                name-char = \"description.a\"\n\
                avatar = \"asset://card/missing.png\"\n\
                greetings = [\"greeting.none\"]\n\
                prompt = [\"description.a\", \"prompt.none\", \"GREETING\", \"CHAT-HISTORY\"]\n\
                [description.a]\ntext = \"A\"\n\
                [session.s]\ncharacters = [\"character.a\"]\n";
    let user = "[persona.me]\nname = \"Me\"\ntext = \"\"\n[mood.custom]\ntext = \"app data\"\n";
    let mut files = one("card/a.toml", card);
    files.push(("user/u.toml".to_string(), user.to_string()));
    let warnings = Document::parse(&files).unwrap().warnings(&[]);
    let misplaced = |kind: &str, file: &str| cw_ccv4::ImportNote::Misplaced {
        kind: kind.into(),
        file: file.into(),
    };
    let dangling = |key: &str, reference: &str| cw_ccv4::ImportNote::Dangling {
        owner: "character.a".into(),
        key: key.into(),
        reference: reference.into(),
    };
    assert_eq!(
        warnings,
        [
            misplaced("session", "card/a.toml"),
            misplaced("persona", "user/u.toml"),
            cw_ccv4::ImportNote::UnknownPlaceholder {
                owner: "character.a".into(),
                placeholder: "GREETING".into()
            },
            dangling("name-char", "description.a"),
            dangling("greetings", "greeting.none"),
            dangling("prompt", "prompt.none"),
            cw_ccv4::ImportNote::MissingAsset {
                owner: "character.a".into(),
                key: "avatar".into(),
                file: "card/missing.png".into()
            },
        ]
    );
}

#[test]
fn a_character_maps_onto_the_prompt_sections() {
    let document = Document::parse(&common::files()).unwrap();
    let mira = mapping::character(&document, "mira").unwrap();
    assert_eq!(mira.name, "Mira");
    assert_eq!(mira.tags, ["sea", "mystery"]);
    assert_eq!(mira.system_prompt, "Write tersely.");
    assert_eq!(
        mira.description,
        "Keeper of the north light. {{char}} counts ships.\n\nA patched oilskin coat."
    );
    assert_eq!(mira.personality, "Wry, patient.");
    assert_eq!(
        mira.scenario,
        "A storm has cut the causeway. {{user}} is stranded."
    );
    assert_eq!(
        mira.mes_example,
        "<START>\n{{user}}: Tea?\n{{char}}: \"Black.\""
    );
    assert_eq!(
        mira.post_history_instructions,
        "Stay in the scene.\n\n[Under 100 words.]"
    );
    let depths: Vec<_> = mira
        .depth_prompts
        .iter()
        .map(|d| (d.prompt.as_str(), d.depth, d.role))
        .collect();
    assert_eq!(
        depths,
        [
            ("[The light flickers.]", 2, Role::System),
            ("[The tide is rising.]", 0, Role::System)
        ]
    );

    let book = mira.lorebook.unwrap();
    assert_eq!(book.scan_depth, Some(3));
    assert_eq!(book.token_budget, 300);
    let [wreck, lamp, off] = book.entries.as_slice() else {
        panic!("expected three entries")
    };
    assert_eq!(wreck.id.as_deref(), Some("lore.wreck"));
    assert_eq!(wreck.keys, ["wreck"]);
    assert_eq!(
        (wreck.priority, wreck.sticky, wreck.constant, wreck.enabled),
        (5, 2, false, true)
    );
    assert_eq!(wreck.content, "The Asta sank here in 1911.");
    assert_eq!((lamp.constant, lamp.insertion_order), (true, 1));
    assert!(!off.enabled);

    // Absurd numbers in a card are capped, so adding them up cannot overflow.
    let huge = common::CARDS.replace(
        "sticky = 2",
        "sticky = 9223372036854775807\ncooldown = 9223372036854775807",
    );
    let huge = huge.replace("token-budget = 300", "token-budget = 9223372036854775807");
    let mut files = common::files();
    files[1].1 = huge;
    let book = mapping::character(&Document::parse(&files).unwrap(), "mira")
        .unwrap()
        .lorebook
        .unwrap();
    assert!(
        book.entries[0]
            .sticky
            .checked_add(book.entries[0].cooldown)
            .is_some()
    );
    assert!(book.token_budget.checked_mul(8).is_some());

    let bare = mapping::character(&document, "bare").unwrap();
    assert_eq!(bare.name, "bare");
    assert!(
        bare.description.is_empty() && bare.lorebook.is_none() && bare.depth_prompts.is_empty()
    );
    assert!(mapping::character(&document, "nobody").is_none());
}

#[test]
fn the_lorebook_is_left_out_when_the_template_has_no_place_for_it() {
    let card = common::CARDS.replace("  \"LOREBOOK\",\n", "");
    let mut files = common::files();
    files[1].1 = card;
    let document = Document::parse(&files).unwrap();
    assert!(
        mapping::character(&document, "mira")
            .unwrap()
            .lorebook
            .is_none()
    );
    assert!(mapping::lorebooks(&document, "mira").is_empty());
}

#[test]
fn a_characters_lorebooks_and_their_entries_are_listed_by_name() {
    let named = common::CARDS
        .replace(
            "[lorebook.coast]",
            "[lorebook.coast]\nname = \" The North Coast \"",
        )
        .replace(
            "[lore.wreck]",
            &format!("[lore.wreck]\nname = \"{}\"", "w".repeat(70)),
        )
        // A lorebook and an entry the card does not have are not listed.
        .replace(
            "lorebooks = [\"lorebook.coast\"]",
            "lorebooks = [\"lorebook.coast\", \"lorebook.gone\"]",
        )
        .replace("\"lore.off\"]", "\"lore.off\", \"lore.gone\"]");
    let mut files = common::files();
    files[1].1 = named;
    let document = Document::parse(&files).unwrap();
    assert_eq!(mapping::lorebooks(&document, "mira"), ["lorebook.coast"]);
    assert!(
        mapping::lorebooks(&document, "bare").is_empty()
            && mapping::lorebooks(&document, "nobody").is_empty()
    );
    assert_eq!(
        mapping::entries(&document, "lorebook.coast"),
        ["lore.wreck", "lore.lamp", "lore.off"]
    );

    // A name of its own, cut to 64 characters; else an entry's first keyword; else the ID.
    assert_eq!(
        mapping::lore_name(&document, "lorebook.coast"),
        "The North Coast"
    );
    assert_eq!(mapping::lore_name(&document, "lore.wreck"), "w".repeat(64));
    assert_eq!(mapping::lore_name(&document, "lore.off"), "wreck");
    assert_eq!(mapping::lore_name(&document, "lore.lamp"), "lamp");
    let book = mapping::character(&document, "mira")
        .unwrap()
        .lorebook
        .unwrap();
    assert_eq!(
        book.entries
            .iter()
            .map(|entry| entry.name.as_str())
            .collect::<Vec<_>>(),
        ["w".repeat(64).as_str(), "lamp", "wreck"]
    );
}

#[test]
fn a_character_is_mapped_without_the_lore_a_chat_leaves_out() {
    let document = Document::parse(&common::files()).unwrap();
    let ids = |off: &[&str]| {
        let off = off.iter().map(|reference| reference.to_string()).collect();
        let book = mapping::character_in(&document, "mira", &off, &[], None)
            .unwrap()
            .lorebook;
        book.map(|book| {
            book.entries
                .into_iter()
                .filter_map(|entry| entry.id)
                .collect::<Vec<_>>()
        })
    };
    assert_eq!(ids(&[]).unwrap(), ["lore.wreck", "lore.lamp", "lore.off"]);
    assert_eq!(
        ids(&["lore.lamp", "lore.nothing"]).unwrap(),
        ["lore.wreck", "lore.off"]
    );
    assert_eq!(ids(&["lorebook.coast"]), None);

    // An entry in two lorebooks stays in through the one that is on, and a
    // lorebook that is off no longer lifts the others' budget.
    let two = format!(
        "{}\n[lorebook.open]\nentries = [\"lore.lamp\"]\n",
        common::CARDS
    )
    .replace(
        "lorebooks = [\"lorebook.coast\"]",
        "lorebooks = [\"lorebook.coast\", \"lorebook.open\"]",
    );
    let mut files = common::files();
    files[1].1 = two;
    let document = Document::parse(&files).unwrap();
    let book = |off: &str| {
        mapping::character_in(&document, "mira", &[off.to_string()].into(), &[], None)
            .unwrap()
            .lorebook
            .unwrap()
    };
    assert_eq!((book("").token_budget, book("").entries.len()), (0, 3));
    assert_eq!(
        (
            book("lorebook.open").token_budget,
            book("lorebook.open").entries.len()
        ),
        (300, 3)
    );
    // Nor does one that is on with no entry left.
    assert_eq!(
        (
            book("lore.lamp").token_budget,
            book("lore.lamp").entries.len()
        ),
        (300, 2)
    );
    let coast_off = book("lorebook.coast");
    assert_eq!(
        coast_off
            .entries
            .iter()
            .map(|entry| entry.id.as_deref().unwrap())
            .collect::<Vec<_>>(),
        ["lore.lamp"]
    );
}

#[test]
fn a_lorebook_is_taken_out_of_a_card_as_a_document_of_its_own() {
    let doc = Document::parse(&common::files()).unwrap();
    let alone = Document::parse(&one(
        "card/0001_lorebook.toml",
        &doc.lorebook_alone("lorebook.coast").unwrap(),
    ))
    .unwrap();
    // The lorebook and its entries, as they read in the card, and nothing else of the card.
    assert_eq!(alone.ids("lorebook"), ["coast"]);
    assert_eq!(
        mapping::entries(&alone, "lorebook.coast"),
        ["lore.wreck", "lore.lamp", "lore.off"]
    );
    assert_eq!(alone.lookup("lorebook.coast"), doc.lookup("lorebook.coast"));
    for entry in ["lore.wreck", "lore.lamp", "lore.off"] {
        assert_eq!(alone.lookup(entry), doc.lookup(entry), "{entry}");
    }
    assert!(
        alone.ids("character").is_empty()
            && alone.ids("prompt").is_empty()
            && alone.tags().is_empty()
    );

    // Only a lorebook is taken out, and only the lore it lists comes along.
    let odd = r#"
spec = "ccv4:1.0.0"

[description.spare]
text = "Not lore."

[lore.gate]
keywords = ["gate"]
text = "The gate is shut."

[lore.spare]
text = "Listed by nobody."

[lorebook.gate]
entries = ["description.spare", "lore.gate", "lore.missing"]
"#;
    let doc = Document::parse(&one("card/0001_card.toml", odd)).unwrap();
    for reference in [
        "lore.gate",
        "description.gate",
        "lorebook.nothing",
        "lorebook",
        "",
    ] {
        assert_eq!(doc.lorebook_alone(reference), None, "{reference:?}");
    }
    let alone = Document::parse(&one(
        "card/0001_lorebook.toml",
        &doc.lorebook_alone("lorebook.gate").unwrap(),
    ))
    .unwrap();
    assert_eq!(
        (alone.ids("lore"), alone.ids("description")),
        (vec!["gate"], vec![])
    );
}

#[test]
fn a_card_chunk_is_found_by_the_chunks_headers_alone() {
    let check = |file: Vec<u8>| {
        let mut file = std::io::Cursor::new(file);
        png::holds_card_chunk(&mut file, |keyword| keyword == "chara").unwrap()
    };
    let text = |keyword: &str| {
        let mut data = keyword.as_bytes().to_vec();
        data.extend_from_slice(b"\0some text");
        chunk(b"tEXt", &data)
    };
    // CCV4's chunk, and a text chunk the check accepts, after other chunks.
    assert!(check(file_with(vec![
        text("Comment"),
        ccv4_chunk(b"toMl", "card.toml", b"x")
    ])));
    assert!(check(file_with(vec![text("Comment"), text("chara")])));
    // A picture without one, no PNG, and one that ends before its end.
    assert!(!check(picture()));
    assert!(!check(file_with(vec![text("Comment"), text("charax")])));
    assert!(!check(b"GIF89a, no PNG at all".to_vec()));
    let mut cut = file_with(vec![text("Comment")]);
    cut.truncate(cut.len() - 20);
    assert!(!check(cut));
    // A chunk after the end is not looked at.
    let mut after = picture();
    after.extend(text("chara"));
    assert!(!check(after));
}

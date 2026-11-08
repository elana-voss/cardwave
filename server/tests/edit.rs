//! A card's editor: what it shows of a card, and an edit saved as a new
//! version in the card's one's place, in which what the editor does not show
//! stays as it is written. The drafts an edit adds are `history.rs`'s.
//!
//! Cards of one file for what the sample card has not: `SPARSE` (characters
//! that lack texts, blocks without words), `NOTED` (written by hand, with comments and a list on lines of its
//! own) and `TALKATIVE` (in `common/edit.rs`, a talkativeness beyond 1, which a test changes);
//! the cards written untidily, shared blocks, refusals, HTTP and modes are `edit_more.rs`'s. The test of edits
//! made at once starts them as threads on one `Scratch`, behind a `Barrier`.

mod common;

use common::Scratch;
use common::edit::*;
use cw_ccv4::Document;
use cw_ccv4::mapping;
use cw_ccv4::png;
use cw_library::cards::{self, Find};
use cw_library::lorebooks;
use serde_json::json;

#[test]
fn an_edit_is_one_more_version_and_what_it_does_not_show_stays() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    // Another card first, so that the id of a version is not its number.
    cards::import(db, user, &common::card_file()).unwrap();
    let mut container = common::container();
    container.toml[0].1 = container.toml[0]
        .1
        .replace("[name.mira]", "# Kept as it is written.\n[name.mira]");
    // What the card says about itself stands in another file than the format's version.
    let about = "[meta-info]\ntitle = \"Mira of the North Light\"\ntags = [\"sea\", \"mystery\"]\n";
    assert!(container.toml[0].1.contains(about));
    container.toml[0].1 = container.toml[0].1.replace(about, "");
    container.toml[1].1.push_str(&format!("\n{about}"));
    // A file the edit changes nothing in, with the line ends of Windows and none at its end.
    let more = "# Kept to the letter.\r\n[mood.night]\r\ntext = 'A type this build does not know.'";
    container
        .toml
        .insert(2, ("card/0003_more.toml".to_string(), more.to_string()));
    // An older wording of the greeting that the edit takes off.
    let older = "\n[revision.\"greeting.door\"]\ndrafts = [{ saved = 2026-07-01T09:00:00Z, payload = { text = \"An older door.\" } }]\n";
    container.toml[3].1.push_str(older);
    let card = common::import_whole(db, user, &png::write(&container).unwrap()).unwrap();
    let (id, v1) = (card.card_id, card.version_id);
    assert_ne!(v1, 1);

    // The editor shows the texts as they are written, each with its block; a pinned draft reads in its block's
    // place. It shows the card's first character alone; a prompt block by where it stands.
    let mut form = cards::editable(db, user, id, None).unwrap();
    let shown = json!({
        "version": 1,
        "title": "Mira of the North Light",
        "tags": ["sea", "mystery"],
        "creator": "",
        "languages": [{ "code": "en", "name": "English" }],
        "characters": [
            {
                "id": "mira",
                "label": "Mira (storm night)",
                "name": "Mira",
                "name_block": "name.mira",
                "greetings": [
                    { "reference": "greeting.door", "text": "\"You picked a night for it, {{user}}.\"" },
                    { "reference": "greeting.lamp", "text": "Hold the lamp. Don't ask." },
                ],
                "description": [
                    { "reference": "description.mira", "text": "Keeper of the north light. {{char}} counts ships." },
                    { "reference": "wardrobe.oilskin", "text": "A patched oilskin coat." },
                ],
                "personality": [{ "reference": "personality.mira", "text": "Wry, patient." }],
                "scenario": [{ "reference": "scenario.storm", "text": "A storm has cut the causeway. {{user}} is stranded." }],
                "example_dialogue": [{ "reference": "dialogue-example.tea", "text": "<START>\n{{user}}: Tea?\n{{char}}: \"Black.\"" }],
                "group_greetings": [{ "reference": "greeting.crowd", "text": "All of you, inside." }],
                "system_prompt": [{ "reference": "prompt.main", "text": "Write tersely." }],
                "post_history": [{ "reference": "prompt.style", "text": "[Under 100 words.]" }],
                "depth_prompts": [
                    { "reference": "prompt.whisper", "text": "[The light flickers.]", "depth": 2 },
                    { "reference": "prompt.tide", "text": "[The tide is rising.]", "depth": 0 },
                ],
                "creator_notes": "Never sent to the model.",
                "talkativeness": 0.5,
            },
        ],
    });
    assert_eq!(serde_json::to_value(&form).unwrap(), shown);

    form.title = "  Mira, Keeper ".to_string();
    form.tags = ["sea", "Lighthouse", " lighthouse ", "storm, night", ""]
        .map(str::to_string)
        .to_vec();
    form.creator = " Erin ".to_string();
    let mira = &mut form.characters[0];
    mira.name = "Mira Vale".to_string();
    mira.description[1].text = "A yellow oilskin coat.".to_string();
    mira.personality[0].text = "Sharp,\r\npatient.\n".to_string();
    // The second greeting comes first, the first is taken off, and one is new. One named twice is there once.
    let lamp = "Hold the lamp. Don't ask.";
    mira.greetings = vec![
        part("greeting.lamp", lamp),
        new("A new night.\nCome in."),
        part("greeting.lamp", "Said twice."),
    ];
    mira.creator_notes = "Read this first.".to_string();
    let before = cards::get(db, user, id).unwrap().unwrap();
    let found = |query: &str| {
        cards::find(
            db,
            user,
            &Find {
                query,
                ..Default::default()
            },
        )
        .unwrap()
        .len()
    };
    // Both cards have the old title.
    assert_eq!((found("keeper vale lighthouse"), found("north")), (0, 2));
    let (old, was) = (cards::document(db, user, v1).unwrap(), texts(db, v1));
    let (old_image, old_assets) = (cards::image(db, user, v1).unwrap(), assets(db, v1));
    let saved = cards::edit(db, user, id, &form).unwrap();
    assert_eq!(saved.number, 2);

    // The card is the new version: in the library's list and search, under its new title.
    let now = cards::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (now.version_id, now.version, now.title.as_str()),
        (saved.id, 2, "Mira, Keeper")
    );
    assert_eq!(now.names, ["Mira Vale"]);
    assert_eq!(now.tags, ["sea", "Lighthouse", "storm", "night"]);
    assert_eq!(now.excerpt, "Hold the lamp. Don't ask.");
    assert_eq!(
        (now.favorite, now.archived, now.created_at),
        (before.favorite, before.archived, before.created_at)
    );
    assert_eq!((found("keeper vale lighthouse"), found("north")), (1, 1));
    // The version before is gone: a card has one.
    assert!(texts(db, v1).is_empty());

    // It reads as the edit asked, in the editor and for the model.
    let after = cards::editable(db, user, id, None).unwrap();
    let mut expected = shown.clone();
    expected["version"] = json!(2);
    expected["title"] = json!("Mira, Keeper");
    expected["tags"] = json!(["sea", "Lighthouse", "storm", "night"]);
    expected["creator"] = json!("Erin");
    let mira = &mut expected["characters"][0];
    mira["name"] = json!("Mira Vale");
    mira["description"][1]["text"] = json!("A yellow oilskin coat.");
    mira["personality"][0]["text"] = json!("Sharp,\npatient.");
    mira["greetings"] = json!([
        { "reference": "greeting.lamp", "text": "Hold the lamp. Don't ask." },
        { "reference": "greeting.mira", "text": "A new night.\nCome in." },
    ]);
    mira["creator_notes"] = json!("Read this first.");
    assert_eq!(serde_json::to_value(&after).unwrap(), expected);
    let document = cards::document(db, user, saved.id).unwrap();
    let told = mapping::character(&document, "mira").unwrap();
    assert_eq!(
        (told.name.as_str(), told.personality.as_str()),
        ("Mira Vale", "Sharp,\npatient.")
    );
    assert_eq!(
        told.description,
        "Keeper of the north light. {{char}} counts ships.\n\nA yellow oilskin coat."
    );

    // What the editor does not show is as it was: the other blocks, the lorebook, the prompt's order, unknown types.
    for kind in [
        "lore",
        "lorebook",
        "prompt",
        "scenario",
        "dialogue-example",
        "mood",
        "name",
    ] {
        assert!(!old.ids(kind).is_empty(), "{kind}");
        assert_eq!(old.ids(kind), document.ids(kind), "{kind}");
        for block in old
            .ids(kind)
            .into_iter()
            .filter(|block| (kind, *block) != ("name", "mira"))
        {
            assert_eq!(
                old.element(kind, block),
                document.element(kind, block),
                "{kind}.{block}"
            );
        }
    }
    for kept in [
        "name-card",
        "name-char",
        "avatar",
        "group-greetings",
        "lorebooks",
        "creator-note",
        "prompt",
    ] {
        assert_eq!(
            key(&old, "mira", kept),
            key(&document, "mira", kept),
            "{kept}"
        );
    }
    assert_eq!(old.character("bare"), document.character("bare"));
    assert_eq!(
        told.system_prompt,
        mapping::character(&old, "mira").unwrap().system_prompt
    );
    assert_eq!(lorebooks::of_card(db, user, id).unwrap().len(), 1);
    // The picture and the assets are the same stored files, kept once.
    assert_eq!(old_image, cards::image(db, user, saved.id).unwrap());
    assert_eq!(old_assets, assets(db, saved.id));
    assert_eq!(old_assets.len(), 1);

    // The files are changed where the edit is: a comment stays, and a file's other lines to the letter.
    let is = texts(db, saved.id);
    assert_eq!(was, container.toml);
    // One file more: the drafts' (see `history.rs`).
    assert_eq!(
        is.iter().map(|(name, _)| name.as_str()).collect::<Vec<_>>(),
        was.iter()
            .map(|(name, _)| name.as_str())
            .chain(["user/0001_revision.toml"])
            .collect::<Vec<_>>()
    );
    assert!(
        is[0]
            .1
            .contains("# Kept as it is written.\n[name.mira]\ntext = \"Mira Vale\"\n"),
        "{}",
        is[0].1
    );
    // A text a pinned draft stands in for is written into that draft.
    let pinned = "payload = { text = \"Wry, patient.\" }";
    assert!(was[3].1.contains(pinned));
    // And the drafts of a block that is gone stay, with its last words.
    let file = &is[3].1;
    assert!(
        file.contains("payload = { text = \"\"\"\nSharp,\npatient.\"\"\" }")
            && file.contains("An older door.")
            && file.contains("You picked a night"),
        "{file}"
    );
    assert_eq!(is[2].1, more);
    assert!(
        is[0]
            .1
            .contains("[personality.mira]\ntext = \"Dry, patient.\"\n")
    );
    // A greeting taken off is gone from the card; one that the character's other list names is not.
    assert!(
        was[0].1.contains("[greeting.door]")
            && !is[0].1.contains("[greeting.door]")
            && !is[0].1.contains("You picked")
    );
    assert!(is[0].1.contains("[greeting.crowd]") && is[0].1.contains("[greeting.lamp]"));
    assert_eq!(
        key(&document, "mira", "greetings"),
        json!(["greeting.lamp", "greeting.mira"])
    );
    // A new block stands in the character's file, and the card says when it was changed.
    assert!(
        is[1]
            .1
            .contains("[greeting.mira]\ntext = \"\"\"\nA new night.\nCome in.\"\"\"\n"),
        "{}",
        is[1].1
    );
    assert!(
        is[1].1.contains("title = \"Mira, Keeper\"\n") && is[1].1.contains("\nmodified = 20"),
        "{}",
        is[1].1
    );
    assert!(!was[1].1.contains("modified") && !is[0].1.contains("meta-info"));

    assert_eq!(old.text("name.mira"), Some("Mira"));
    // The title is the card's own.
    assert_eq!(
        cards::get(db, user, id).unwrap().unwrap().title,
        "Mira, Keeper"
    );
    // So the editor shows it, and a title typed there is the card's from then on: that is an edit.
    let mut form = cards::editable(db, user, id, None).unwrap();
    assert_eq!((form.version, form.title.as_str()), (2, "Mira, Keeper"));
    form.title = "Mira of the North Light".to_string();
    assert_eq!(cards::edit(db, user, id, &form).unwrap().number, 3);
    assert_eq!(
        cards::get(db, user, id).unwrap().unwrap().title,
        "Mira of the North Light"
    );
    assert_eq!(found("north"), 2);
}

/// A card written by hand: comments over a line and behind it, and a list on lines of its own.
const NOTED: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
# Where it is found.
tags = ["sea"] # few
creator = "Erin" # for now
modified = 2026-07-11 # by hand

[name.ada]
# Her name in the chat.
text = "Ada" # as she signs

[greeting.hi]
text = "Hi."

[greeting.bye]
text = "Bye."

[character.ada]
name-card = "Ada" # the label
name-char = "name.ada"
# How a chat opens.
greetings = [
  "greeting.hi",
  "greeting.bye",
] # one of them
prompt = ["name.ada", "CHAT-HISTORY"]
"#;

#[test]
fn a_line_that_is_edited_keeps_its_comments_and_a_list_the_way_it_is_written() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = cards::import(db, user, &card_of(NOTED)).unwrap();
    let mut form = cards::editable(db, user, card.card_id, None).unwrap();
    form.tags.push("lab".to_string());
    form.creator = "Olga".to_string();
    form.characters[0].name = "Ada L.".to_string();
    form.characters[0].greetings.reverse();
    let saved = cards::edit(db, user, card.card_id, &form).unwrap();
    assert_eq!(saved.number, 2);

    let file = &texts(db, saved.id)[0].1;
    let written = NOTED
        .replace("tags = [\"sea\"] # few", "tags = [\"sea\", \"lab\"] # few")
        .replace(
            "creator = \"Erin\" # for now",
            "creator = \"Olga\" # for now",
        )
        .replace(
            "text = \"Ada\" # as she signs",
            "text = \"Ada L.\" # as she signs",
        )
        .replace(
            "name-card = \"Ada\" # the label",
            "name-card = \"Ada L.\" # the label",
        )
        .replace(
            "  \"greeting.hi\",\n  \"greeting.bye\",\n",
            "  \"greeting.bye\",\n  \"greeting.hi\",\n",
        );
    let stamp = |line: &&str| line.starts_with("modified = 20");
    assert_eq!(
        file.lines().filter(|line| !stamp(line)).collect::<Vec<_>>(),
        written
            .lines()
            .filter(|line| !stamp(line))
            .collect::<Vec<_>>()
    );
    // When it was changed is told on the line that told it, in its place.
    let told: Vec<&str> = file.lines().filter(stamp).collect();
    assert!(
        told.len() == 1 && told[0].ends_with("Z # by hand") && !told[0].contains("2026-07-11"),
        "{file}"
    );

    // A list that loses all it names is an empty one, on its line.
    let mut form = cards::editable(db, user, card.card_id, None).unwrap();
    form.characters[0].greetings.clear();
    let saved = cards::edit(db, user, card.card_id, &form).unwrap();
    assert!(
        texts(db, saved.id)[0]
            .1
            .contains("# How a chat opens.\ngreetings = [] # one of them\n"),
        "{}",
        texts(db, saved.id)[0].1
    );
}

#[test]
fn a_characters_talkativeness_is_written_into_it_once_it_is_changed() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let given = "group-talkativeness = 1.5 # beyond the most\n";
    // Of three cards: beyond the most, none, and one with a comment behind it; each as shown, as changed, and
    // how the changed one is written: on its line where it has one, with what stands behind it.
    let cases = [
        (
            given,
            1.0,
            0.3,
            "group-talkativeness = 0.3 # beyond the most\n",
        ),
        (
            "",
            0.5,
            0.8,
            "prompt = [\"name.ada\", \"CHAT-HISTORY\"]\ngroup-talkativeness = 0.8\n",
        ),
        (
            "group-talkativeness = 0.25 # a quiet one\n",
            0.25,
            0.75,
            "group-talkativeness = 0.75 # a quiet one\n",
        ),
    ];
    for (line, shown, changed, written) in cases {
        let card = cards::import(db, user, &card_of(&TALKATIVE.replace(given, line))).unwrap();
        let id = card.card_id;
        // Shown as it counts: beyond the most as the most, and 0.5 where the card says nothing. Saved so, it
        // stays as the card wrote it, and no version is added.
        let mut form = cards::editable(db, user, id, None).unwrap();
        assert_eq!(form.characters[0].talkativeness, shown);
        assert_eq!(cards::edit(db, user, id, &form).unwrap().number, 1);
        form.characters[0].talkativeness = changed;
        let saved = cards::edit(db, user, id, &form).unwrap();
        assert_eq!(saved.number, 2);
        let file = &texts(db, saved.id)[0].1;
        assert!(file.contains(written), "{file}");
        let form = cards::editable(db, user, id, None).unwrap();
        assert_eq!(form.characters[0].talkativeness, changed);
    }

    // Set to 0.5, it is written as any other: it is what the user gave, not what a card says by saying nothing.
    let card = cards::import(
        db,
        user,
        &card_of(&common::unique(&TALKATIVE.replace(given, ""))),
    )
    .unwrap();
    let id = card.card_id;
    let mut form = cards::editable(db, user, id, None).unwrap();
    form.characters[0].talkativeness = 0.8;
    cards::edit(db, user, id, &form).unwrap();
    let mut form = cards::editable(db, user, id, None).unwrap();
    form.characters[0].talkativeness = 0.5;
    let saved = cards::edit(db, user, id, &form).unwrap();
    assert_eq!(
        key(
            &Document::parse(&texts(db, saved.id)).unwrap(),
            "ada",
            "group-talkativeness"
        ),
        json!(0.5)
    );

    // Beyond 0 and 1 it is refused, and nothing is written.
    let mut form = cards::editable(db, user, id, None).unwrap();
    for wrong in [1.01, -0.1] {
        form.characters[0].talkativeness = wrong;
        assert_eq!(
            refusal(cards::edit(db, user, id, &form)),
            "the talkativeness of ada is not between 0 and 1"
        );
    }
    assert_eq!(cards::get(db, user, id).unwrap().unwrap().version, 3);
}

#[test]
fn what_a_card_says_about_itself_is_changed_in_the_file_that_says_it() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    // The tags stand in another file than the title.
    let mut container = common::container();
    let tags = "tags = [\"sea\", \"mystery\"]\n";
    assert!(container.toml[0].1.contains(&format!(
        "[meta-info]\ntitle = \"Mira of the North Light\"\n{tags}"
    )));
    container.toml[0].1 = container.toml[0].1.replace(tags, "");
    container.toml[1]
        .1
        .push_str(&format!("\n[meta-info]\n{tags}"));
    let card = cards::import(db, user, &png::write(&container).unwrap()).unwrap();

    let mut form = cards::editable(db, user, card.card_id, None).unwrap();
    form.title = "Mira".to_string();
    form.tags = vec!["storm".to_string()];
    form.creator = "Erin".to_string();
    let saved = cards::edit(db, user, card.card_id, &form).unwrap();
    assert_eq!(saved.number, 2);
    let after = cards::editable(db, user, card.card_id, None).unwrap();
    assert_eq!(
        (after.title.as_str(), after.tags, after.creator.as_str()),
        ("Mira", vec!["storm".to_string()], "Erin")
    );
    // Each where it stood; what stood nowhere, where the card first says something about itself.
    let files = texts(db, saved.id);
    assert!(
        files[0]
            .1
            .contains("[meta-info]\ntitle = \"Mira\"\ncreator = \"Erin\"\nmodified = 20"),
        "{}",
        files[0].1
    );
    assert!(
        files[1].1.ends_with("\n[meta-info]\ntags = [\"storm\"]\n"),
        "{}",
        files[1].1
    );
}

#[test]
fn of_two_edits_of_one_version_made_at_once_one_is_saved() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = cards::import(db, user, &common::card_file())
        .unwrap()
        .card_id;
    let form = cards::editable(db, user, card, None).unwrap();
    // Each asks whether the card is still at v1 before another has written: all are told yes.
    let together = std::sync::Barrier::new(8);
    let saved: Vec<Result<i64, String>> = std::thread::scope(|scope| {
        let edits: Vec<_> = (0..8)
            .map(|n| {
                let (form, together) = (&form, &together);
                scope.spawn(move || {
                    let mut edit = form.clone();
                    edit.creator = format!("Editor {n}");
                    together.wait();
                    cards::edit(db, user, card, &edit)
                        .map(|version| version.number)
                        .map_err(|error| format!("{error:#}"))
                })
            })
            .collect();
        edits.into_iter().map(|edit| edit.join().unwrap()).collect()
    });
    // One made v2; the others were of v1 when they came to be written, and are refused as any late edit.
    let late = "the card was changed meanwhile (v2, not v1); it is read anew".to_string();
    assert_eq!(
        saved.iter().filter(|one| **one == Ok(2)).count(),
        1,
        "{saved:?}"
    );
    assert_eq!(
        saved
            .iter()
            .filter(|one| **one == Err(late.clone()))
            .count(),
        7,
        "{saved:?}"
    );
    assert_eq!(cards::get(db, user, card).unwrap().unwrap().version, 2);
}

/// A card read for its editor while edits are saved is read whole, at one
/// version or the next: never "not found" for a version just put away.
#[test]
fn a_card_read_while_it_is_edited_is_always_found() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = cards::import(db, user, &common::card_file())
        .unwrap()
        .card_id;
    let done = std::sync::atomic::AtomicBool::new(false);
    let failed: Vec<String> = std::thread::scope(|scope| {
        scope.spawn(|| {
            for n in 0..100 {
                let mut edit = cards::editable(db, user, card, None).unwrap();
                edit.creator = format!("Editor {n}");
                cards::edit(db, user, card, &edit).unwrap();
            }
            done.store(true, std::sync::atomic::Ordering::Relaxed);
        });
        let readers: Vec<_> = (0..3)
            .map(|_| {
                scope.spawn(|| {
                    let mut failed = Vec::new();
                    while !done.load(std::sync::atomic::Ordering::Relaxed) {
                        if let Err(error) = cards::editable(db, user, card, None) {
                            failed.push(format!("{error:#}"));
                        }
                    }
                    failed
                })
            })
            .collect();
        readers
            .into_iter()
            .flat_map(|reader| reader.join().unwrap())
            .collect()
    });
    assert!(failed.is_empty(), "{failed:?}");
}

/// A card whose characters lack texts: `ada` has a prompt on several lines,
/// `bob` one on one line, `cy` none, `dee` has blocks without words, and in
/// the prompt of `eve` the name is followed by what has no place of its own.
const SPARSE: &str = r#"spec = "ccv4:1.0.0"

[name.ada]
text = "Ada"

[scenario.ada]
text = "A lab."

[scenario.blank]
text = ""

[description.bob]
text = "Taken: no character's prompt has it."

[personality.dee]
text = ""

[personality.dee-too]
text = "  "

[greeting.blank]
text = ""

[prompt.main]
text = "Write."

[character.ada]
name-char = "name.ada"
prompt = [
  "prompt.main",
  # The name comes first.
  "name.ada",
  "scenario.ada",
  "scenario.blank",
  "LOREBOOK",
  "CHAT-HISTORY",
]

[character.bob]
prompt = ["CHAT-HISTORY"]

[character.cy]
name-card = "Cy"

[character.dee]
greetings = ["greeting.blank"]
prompt = ["personality.dee", "personality.dee-too"]

[character.eve]
prompt = ["name.ada", "prompt.main", "CHAT-HISTORY"]

[revision."greeting.ada"]
drafts = [{ saved = 2026-07-10T18:30:00Z, pinned = true, payload = { text = "A draft of a greeting that is gone." } }]
"#;

#[test]
fn a_text_the_card_has_no_block_for_gets_one_in_its_place() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, user, &card_of(SPARSE)).unwrap();
    let mut form = cards::editable(db, user, card.card_id, None).unwrap();
    form.characters = each_shown(SPARSE);
    assert_eq!(
        form.characters
            .iter()
            .map(|one| one.id.as_str())
            .collect::<Vec<_>>(),
        ["ada", "bob", "cy", "dee", "eve"]
    );
    // A text shows as its blocks that have words. Without any, as its first block, to be given words there, or
    // as a text without a block. A greeting without words is none.
    assert_eq!(
        form.characters[0].scenario,
        [part("scenario.ada", "A lab.")]
    );
    assert_eq!(
        form.characters[3].personality,
        [part("personality.dee", "")]
    );
    assert_eq!(
        (
            &form.characters[1].description,
            &form.characters[2].personality
        ),
        (&vec![new("")], &vec![new("")])
    );
    assert!(form.characters[3].greetings.is_empty());

    form.tags = vec!["lab".to_string()];
    let [ada, bob, cy, dee, eve] = &mut form.characters[..] else {
        panic!()
    };
    ada.description = vec![new("Ad.")];
    ada.personality = vec![new("Ap.")];
    ada.scenario.push(new("As."));
    ada.example_dialogue = vec![new("Ae.")];
    ada.greetings = vec![new("Ag."), new("  ")];
    ada.creator_notes = "An.".to_string();
    bob.name = "Bob".to_string();
    bob.description = vec![new("Bd.")];
    bob.scenario = vec![new("Bs.")];
    cy.personality = vec![new("Cp.")];
    cy.scenario = vec![new("")];
    dee.personality[0].text = "Dp.".to_string();
    eve.description = vec![new("Ed.")];
    let saved = cards::edit(db, user, card.card_id, &form).unwrap();
    assert_eq!(saved.number, 2);

    let document = cards::document(db, user, saved.id).unwrap();
    // A new block goes where its kind belongs in the prompt: behind the last of its kind or of one that comes
    // before it. It is named after its character.
    let prompt = [
        "prompt.main",
        "name.ada",
        "description.ada",
        "personality.ada",
        "scenario.ada",
        "scenario.blank",
        "scenario.ada-2",
        "dialogue-example.ada",
        "LOREBOOK",
        "CHAT-HISTORY",
    ];
    assert_eq!(key(&document, "ada", "prompt"), json!(prompt));
    assert_eq!(
        key(&document, "ada", "creator-note"),
        json!("creator-note.ada")
    );
    // The name comes before all of them: a text stands right behind it, before what has no place of its own.
    assert_eq!(
        key(&document, "eve", "prompt"),
        json!(["name.ada", "description.eve", "prompt.main", "CHAT-HISTORY"])
    );
    // An ID that is taken is not taken again: not a block's, and not that of a draft pinned for a block that is gone.
    assert_eq!(
        key(&document, "bob", "prompt"),
        json!(["description.bob-2", "scenario.bob", "CHAT-HISTORY"])
    );
    assert_eq!(
        document.text("description.bob"),
        Some("Taken: no character's prompt has it.")
    );
    assert_eq!(
        key(&document, "ada", "greetings"),
        json!(["greeting.ada-2"])
    );
    // A name for a character that had its ID for one; its label was the ID too, and follows.
    assert_eq!(
        (
            key(&document, "bob", "name-char"),
            key(&document, "bob", "name-card")
        ),
        (json!("name.bob"), json!("Bob"))
    );
    // A character without a prompt gets one; a text left empty makes no block.
    assert_eq!(
        (
            key(&document, "cy", "prompt"),
            document.text("personality.cy")
        ),
        (json!(["personality.cy"]), Some("Cp."))
    );
    assert!(document.ids("scenario").iter().all(|id| *id != "cy"));
    assert_eq!(key(&document, "cy", "name-card"), json!("Cy"));
    // An empty block is given the words, and a list that was not changed stays as it is written.
    assert_eq!(
        (
            key(&document, "dee", "prompt"),
            document.text("personality.dee")
        ),
        (
            json!(["personality.dee", "personality.dee-too"]),
            Some("Dp.")
        )
    );
    assert_eq!(
        key(&document, "dee", "greetings"),
        json!(["greeting.blank"])
    );
    assert_eq!(document.tags(), ["lab"]);

    let told = |id: &str| mapping::character(&document, id).unwrap();
    assert_eq!(
        (
            told("ada").description.as_str(),
            told("ada").personality.as_str(),
            told("ada").mes_example.as_str()
        ),
        ("Ad.", "Ap.", "Ae.")
    );
    assert_eq!(
        (
            told("bob").name.as_str(),
            told("bob").description.as_str(),
            told("bob").scenario.as_str()
        ),
        ("Bob", "Bd.", "Bs.")
    );
    assert_eq!(told("ada").scenario, "A lab.\n\nAs.");
    assert_eq!(document.greetings("ada", false), ["Ag."]);
    assert_eq!(document.creator_note("ada"), Some("An."));

    // Each list is written as it was: on lines of its own, or on one line.
    let file = &texts(db, saved.id)[0].1;
    let lines = prompt
        .map(|item| format!("  \"{item}\",\n"))
        .concat()
        .replace(
            "  \"name.ada\"",
            "  # The name comes first.\n  \"name.ada\"",
        );
    assert!(file.contains(&format!("prompt = [\n{lines}]\n")), "{file}");
    assert!(
        file.contains("prompt = [\"description.bob-2\", \"scenario.bob\", \"CHAT-HISTORY\"]\n"),
        "{file}"
    );
    assert!(
        file.contains("\n[meta-info]\ntags = [\"lab\"]\nmodified = 20"),
        "{file}"
    );
    // A kind of block the card had none of has no header of its own.
    assert!(
        !SPARSE.contains("dialogue-example") && file.contains("\n[dialogue-example.ada]\n"),
        "{file}"
    );
    assert!(!file.contains("[dialogue-example]"), "{file}");
}

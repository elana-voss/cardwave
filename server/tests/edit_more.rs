//! A card's editor, continued from `edit.rs`: cards written as no tool writes them (`UNTIDY`), saving what
//! the editor showed, a block two characters have (`SHARED`), edits refused, the editor over HTTP, and a
//! card given modes (`MODED`); its helpers are `common/edit.rs`'s.

mod common;

use common::edit::*;
use common::server::start;
use common::{Scratch, card_data, card_png};
use cw_accounts::users;
use cw_ccv4::Document;
use cw_ccv4::edit::{CardEdit, DepthText, EditText};
use cw_ccv4::mapping;
use cw_ccv4::png;
use cw_core::NotFound;
use cw_library::cards::{self, ExportFormat};
use serde_json::{Value, json};

/// A card written as no tool would write it: the line ends of Windows and
/// none at its end, texts between single quotes, tags and a creator with space
/// around them, a line end of Windows in a text, and lists that name a block
/// twice and a greeting without words.
const UNTIDY: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
tags = ["sea ", "Sea", "a, b"]
creator = " Erin "

[name.ada]
text = 'Ada'

[scenario.ada]
text = "A lab.\r\nAt night.\r"

[greeting.hi]
text = 'Hi.'

[greeting.blank]
text = ""

[creator-note.ada]
text = 'A note.'

[character.ada]
name-char = "name.ada"
greetings = ["greeting.blank", "greeting.hi", "greeting.hi"]
creator-note = "creator-note.ada"
prompt = ["name.ada", "scenario.ada", "scenario.ada", "CHAT-HISTORY"]"#;

/// A card as SillyTavern writes it, with a nickname.
fn tavern() -> Value {
    json!({
        "spec": "chara_card_v3",
        "spec_version": "3.0",
        "data": {
            "name": "Unit 734",
            "nickname": "Seven",
            "description": "A maintenance robot.\r\nIt hums.",
            "personality": "Curious.",
            "scenario": "A dead station.",
            "first_mes": "Beep.",
            "alternate_greetings": ["Boop."],
            "mes_example": "<START>\r\n{{user}}: Hi\r\n{{char}}: Beep.",
            "system_prompt": "Stay in character.",
            "post_history_instructions": "Short replies.",
            "creator_notes": "Have fun.",
            "tags": ["Robot", "sci-fi"],
            "creator": "erin",
            "extensions": { "depth_prompt": { "prompt": "Remember the hum.", "depth": 2, "role": "user" }, "fav": true },
            "character_book": { "name": "Station log", "entries": [{ "keys": ["wiper"], "comment": "The Wiper", "content": "A virus." }] },
        },
    })
}

#[test]
fn saving_what_the_editor_showed_adds_no_version() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let unchanged = |file: &[u8]| {
        let card = cards::import(db, user, file).unwrap();
        let form = cards::editable(db, user, card.card_id, None).unwrap();
        let saved = cards::edit(db, user, card.card_id, &form).unwrap();
        assert_eq!((saved.id, saved.number), (card.version_id, 1));
        assert_eq!(
            cards::get(db, user, card.card_id).unwrap().unwrap().version,
            1
        );
        (card.card_id, form)
    };
    unchanged(&common::card_file());

    // Not for a file that would be written otherwise, nor for line ends a text field does not keep, nor for
    // tags and lists that are told tidier than they are written: each block once, each tag once.
    let untidy = UNTIDY.replace('\n', "\r\n");
    let (id, mut form) = unchanged(&card_of(&untidy));
    assert_eq!(
        texts(db, cards::get(db, user, id).unwrap().unwrap().version_id)[0].1,
        untidy
    );
    assert_eq!(
        form.characters[0].scenario,
        [part("scenario.ada", "A lab.\nAt night.")]
    );
    assert_eq!(form.characters[0].greetings, [part("greeting.hi", "Hi.")]);
    assert_eq!(
        (
            form.characters[0].name.as_str(),
            form.characters[0].creator_notes.as_str()
        ),
        ("Ada", "A note.")
    );
    assert_eq!(
        (form.tags.clone(), form.creator.as_str()),
        (
            vec!["sea".to_string(), "a".to_string(), "b".to_string()],
            "Erin"
        )
    );
    // Nor for space around what is typed.
    form.title = format!("  {}\n", form.title);
    form.characters[0].name = " Ada ".to_string();
    form.characters[0].scenario[0].text = "\nA lab.\nAt night.  ".to_string();
    form.tags = vec![" sea,a ".to_string(), "B".to_string(), "b".to_string()];
    // But a tag in another case is another tag, and that a version. A creator that is taken out is no line.
    form.creator = "  ".to_string();
    assert_eq!(cards::edit(db, user, id, &form).unwrap().number, 2);
    let now = cards::get(db, user, id).unwrap().unwrap();
    assert_eq!(now.tags, ["sea", "a", "B"]);
    // The edit is where it was made: the other lines are as they were, with the line ends of a file that was written anew.
    let written = untidy
        .replace("\r\n", "\n")
        .replace(
            "tags = [\"sea \", \"Sea\", \"a, b\"]",
            "tags = [\"sea\", \"a\", \"B\"]",
        )
        .replace("creator = \" Erin \"\n", "");
    let file = &texts(db, now.version_id)[0].1;
    let lines: Vec<&str> = file
        .lines()
        .filter(|line| !line.starts_with("modified = 20"))
        .collect();
    assert_eq!(lines.join("\n"), written);
    assert!(
        file.contains("\ntags = [\"sea\", \"a\", \"B\"]\nmodified = 20")
            && file.ends_with("\"CHAT-HISTORY\"]\n"),
        "{file}"
    );
    let mut form = cards::editable(db, user, id, None).unwrap();
    assert_eq!(form.creator, "");
    form.title = format!("  {}\n", form.title);
    form.characters[0].name = " Ada ".to_string();
    form.characters[0].scenario[0].text = "\nA lab.\r\nAt night.  ".to_string();
    form.tags = vec![" sea,a ".to_string(), "B".to_string(), "b".to_string()];
    assert_eq!(cards::edit(db, user, id, &form).unwrap().number, 2);
    assert_eq!(cards::get(db, user, id).unwrap().unwrap().version, 2);

    // A card that came from SillyTavern goes back there with the edit, and with all else as it came.
    let (id, mut form) = unchanged(&card_png(&tavern()));
    let export = || {
        card_data(
            &cards::export(db, user, id, ExportFormat::SillytavernV3, false, None)
                .unwrap()
                .data,
        )
    };
    let came = export();
    assert_eq!(came["description"], "A maintenance robot.\nIt hums.");
    // The name in the chat is the nickname; the name the model is told stays.
    assert_eq!(form.characters[0].name, "Seven");
    form.characters[0].name = "Sev".to_string();
    form.characters[0].description[0].text = "A repair robot.\nIt hums.".to_string();
    form.characters[0].greetings.remove(0);
    assert_eq!(cards::edit(db, user, id, &form).unwrap().number, 2);
    let mut went = export();
    assert_eq!(
        (&went["nickname"], &went["name"]),
        (&json!("Sev"), &json!("Unit 734"))
    );
    assert_eq!(went["description"], "A repair robot.\nIt hums.");
    assert_eq!(
        (&went["first_mes"], &went["alternate_greetings"]),
        (&json!("Boop."), &json!([]))
    );
    assert!(went["modification_date"].as_i64().unwrap() > 1_700_000_000);
    for changed in [
        "nickname",
        "description",
        "first_mes",
        "alternate_greetings",
        "modification_date",
    ] {
        match came.get(changed) {
            Some(before) => went[changed] = before.clone(),
            None => _ = went.as_object_mut().unwrap().remove(changed),
        }
    }
    assert_eq!(went, came);
    for kept in [
        "mes_example",
        "system_prompt",
        "post_history_instructions",
        "character_book",
        "extensions",
        "tags",
        "creator",
    ] {
        assert!(!came[kept].is_null(), "{kept}");
    }
}

/// Two characters with a name, a scenario and a greeting in common.
const SHARED: &str = r#"spec = "ccv4:1.0.0"

[name.host]
text = "Host"

[scenario.inn]
text = "An inn."

[greeting.hello]
text = "Hello."

[greeting.late]
text = "You are late."

[character.ann]
name-card = "Host"
name-char = "name.host"
greetings = ["greeting.hello", "greeting.late"]
prompt = ["scenario.inn", "CHAT-HISTORY"]

[character.ben]
name-card = "Host (at night)"
name-char = "name.host"
greetings = ["greeting.hello"]
prompt = ["scenario.inn", "CHAT-HISTORY"]
"#;

#[test]
fn a_block_two_characters_have_is_changed_for_both_and_stays_while_one_names_it() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, user, &card_of(SHARED)).unwrap();
    let mut form = cards::editable(db, user, card.card_id, None).unwrap();
    form.characters = each_shown(SHARED);
    // Changed for one character; what the edit says of the other is what the editor showed, and changes nothing.
    form.characters[0].scenario[0].text = "A burnt inn.".to_string();
    form.characters[0].greetings = vec![];
    // The editor is told which block a name stands in, so that it shows a name of two characters as one.
    let block = |form: &CardEdit, at: usize| form.characters[at].name_block.clone();
    assert_eq!(
        (block(&form, 0), block(&form, 1)),
        (Some("name.host".to_string()), Some("name.host".to_string()))
    );
    form.characters[0].name = "Keeper".to_string();
    let saved = cards::edit(db, user, card.card_id, &form).unwrap();
    assert_eq!(saved.number, 2);
    let mut after = cards::editable(db, user, card.card_id, None).unwrap();
    after.characters = each_shown(&texts(db, saved.id)[0].1);
    assert_eq!(
        (
            after.characters[0].name.as_str(),
            after.characters[1].name.as_str()
        ),
        ("Keeper", "Keeper")
    );
    // A label follows the name where it was the name.
    assert_eq!(
        (
            after.characters[0].label.as_str(),
            after.characters[1].label.as_str()
        ),
        ("Keeper", "Host (at night)")
    );
    assert_eq!(
        after.characters[1].scenario,
        [part("scenario.inn", "A burnt inn.")]
    );
    assert_eq!(
        after.characters[1].greetings,
        [part("greeting.hello", "Hello.")]
    );
    assert!(after.characters[0].greetings.is_empty());
    // The greeting only the one character had is gone from the file, the other's is there.
    let file = &texts(db, saved.id)[0].1;
    assert!(
        file.contains("[greeting.hello]")
            && !file.contains("greeting.late")
            && !file.contains("You are late."),
        "{file}"
    );

    // An edit that changes one block in two ways is not made.
    let mut form = after.clone();
    form.characters[0].scenario[0].text = "A new inn.".to_string();
    form.characters[1].scenario[0].text = "An old inn.".to_string();
    assert_eq!(
        refusal(cards::edit(db, user, card.card_id, &form)),
        "scenario.inn is changed in two ways"
    );
    assert_eq!(
        cards::get(db, user, card.card_id).unwrap().unwrap().version,
        2
    );
}

#[test]
fn an_edit_that_cannot_be_made_is_refused_and_adds_nothing() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let card = cards::import(db, user, &common::card_file()).unwrap();
    let id = card.card_id;
    let form = cards::editable(db, user, id, None).unwrap();
    let with = |change: &dyn Fn(&mut CardEdit)| {
        let mut edit = form.clone();
        change(&mut edit);
        edit
    };
    let refused =
        |change: &dyn Fn(&mut CardEdit)| refusal(cards::edit(db, user, id, &with(change)));

    assert_eq!(
        refused(&|edit| edit.title = " \n".to_string()),
        "a card needs a title"
    );
    assert_eq!(
        refused(&|edit| edit.characters[0].name = " ".to_string()),
        "a character needs a name"
    );
    assert_eq!(
        refused(&|edit| edit.characters[0].id = "nobody".to_string()),
        "the card has no character \"nobody\""
    );
    let note = EditText {
        reference: None,
        text: "[The light flickers.]".into(),
        modes: vec![],
    };
    assert_eq!(
        refused(&|edit| edit.characters[0].depth_prompts.push(DepthText {
            part: note.clone(),
            depth: 4
        })),
        "a note at a depth cannot be added"
    );
    // Only the blocks the editor shows of a character are written: no other block of the card, none of another kind.
    let other = |reference: &'static str| {
        move |edit: &mut CardEdit| {
            edit.characters[0].description = vec![part(reference, "Mine now.")]
        }
    };
    assert_eq!(
        refused(&other("prompt.main")),
        "prompt.main is no description of mira to change"
    );
    assert_eq!(
        refused(&other("lore.wreck")),
        "lore.wreck is no description of mira to change"
    );
    assert_eq!(
        refused(&other("personality.mira")),
        "personality.mira is no description of mira to change"
    );
    assert_eq!(
        refused(&other("description.nowhere")),
        "description.nowhere is no description of mira to change"
    );
    assert_eq!(
        refused(&|edit| edit.characters[0]
            .greetings
            .push(part("greeting.crowd", "Mine now."))),
        "greeting.crowd is no greeting of mira"
    );

    // Nobody edits another user's card, or reads it for that.
    let other = users::create(db, "olga").unwrap();
    assert!(
        cards::edit(db, other, id, &form)
            .unwrap_err()
            .downcast_ref::<NotFound>()
            .is_some()
    );
    assert!(
        cards::editable(db, other, id, None)
            .unwrap_err()
            .downcast_ref::<NotFound>()
            .is_some()
    );
    assert!(
        cards::editable(db, user, 99, None)
            .unwrap_err()
            .downcast_ref::<NotFound>()
            .is_some()
    );
    // Not a card in the Trash.
    cards::set_trashed(db, user, id, true).unwrap();
    assert_eq!(
        refused(&|edit| edit.title = "Gone".to_string()),
        "the card is in the Trash; restore it first"
    );
    assert_eq!(
        format!("{:#}", cards::editable(db, user, id, None).unwrap_err()),
        "the card is in the Trash; restore it first"
    );
    cards::set_trashed(db, user, id, false).unwrap();
    assert_eq!(
        (
            cards::get(db, user, id).unwrap().unwrap().version,
            count(db, "card_files")
        ),
        (1, 4)
    );
    assert_eq!(
        cards::get(db, user, id).unwrap().unwrap().title,
        "Mira of the North Light"
    );

    // An edit of a version that is no longer the newest: the card was changed after the editor was opened.
    assert_eq!(
        cards::edit(
            db,
            user,
            id,
            &with(&|edit| edit.creator = "Erin".to_string())
        )
        .unwrap()
        .number,
        2
    );
    let late = refused(&|edit| edit.creator = "Olga".to_string());
    assert_eq!(
        late,
        "the card was changed meanwhile (v2, not v1); it is read anew"
    );
    assert_eq!(cards::editable(db, user, id, None).unwrap().creator, "Erin");
    assert_eq!(cards::get(db, user, id).unwrap().unwrap().version, 2);

    // A character that a pinned draft stands in for: what is written of it would not be read.
    let mut container = common::container();
    container.toml[2].1.push_str(
        "\n[revision.\"character.mira\"]\ndrafts = [{ saved = 2026-07-10T18:30:00Z, pinned = true, payload = { name-card = \"Pinned\" } }]\n",
    );
    let pinned = cards::import(db, user, &png::write(&container).unwrap()).unwrap();
    let mut form = cards::editable(db, user, pinned.card_id, None).unwrap();
    assert_eq!(form.characters[0].label, "Pinned");
    form.characters[0].name = "Mira One".to_string();
    assert_eq!(
        refusal(cards::edit(db, user, pinned.card_id, &form)),
        "the name of mira cannot be changed in this card"
    );
    let mut form = cards::editable(db, user, pinned.card_id, None).unwrap();
    form.characters[0].talkativeness = 0.9;
    assert_eq!(
        refusal(cards::edit(db, user, pinned.card_id, &form)),
        "the talkativeness of mira cannot be changed in this card"
    );
    assert_eq!(
        cards::get(db, user, pinned.card_id)
            .unwrap()
            .unwrap()
            .version,
        1
    );
}

/// A number of the card's that says more than a short one reads back over HTTP as it is written: the form
/// saved as it was shown adds no version.
#[tokio::test]
async fn a_talkativeness_of_many_digits_is_no_change_when_saved_as_shown() {
    let server = start().await;
    let exact = TALKATIVE.replace("1.5 # beyond the most", "0.9856906946328695");
    let (status, imported) = server.upload("/api/cards", card_of(&exact)).await;
    assert_eq!(status, 201, "{imported}");
    let path = format!("/api/cards/{}/edit", imported["card_id"]);
    let (_, form) = server.get(&path).await;
    assert_eq!(
        form["characters"][0]["talkativeness"],
        json!(0.9856906946328695)
    );
    let (status, same) = server.put(&path, form).await;
    assert_eq!((status, &same["number"]), (200, &json!(1)), "{same}");
}

#[tokio::test]
async fn a_card_is_edited_over_http() {
    let server = start().await;
    let (status, imported) = server.upload("/api/cards", common::card_file()).await;
    assert_eq!(status, 201, "{imported}");
    let id = imported["card_id"].as_i64().unwrap();
    let path = format!("/api/cards/{id}/edit");

    let (status, mut form) = server.get(&path).await;
    assert_eq!(status, 200, "{form}");
    assert_eq!(
        (&form["version"], &form["title"]),
        (&json!(1), &json!("Mira of the North Light"))
    );
    assert_eq!(
        form["characters"][0]["personality"],
        json!([{ "reference": "personality.mira", "text": "Wry, patient." }])
    );

    // Saved as it was shown: the card's newest version is the one it had.
    let (status, same) = server.put(&path, form.clone()).await;
    assert_eq!(
        (status, &same["number"], &same["id"]),
        (200, &json!(1), &imported["version_id"]),
        "{same}"
    );

    form["title"] = json!("Mira");
    form["characters"][0]["scenario"][0]["text"] =
        json!("The causeway is dry. {{user}} may leave.");
    let (status, saved) = server.put(&path, form.clone()).await;
    assert_eq!((status, &saved["number"]), (200, &json!(2)), "{saved}");
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(
        (&detail["card"]["version_id"], &detail["card"]["title"]),
        (&saved["id"], &json!("Mira"))
    );
    // The page reads the text as a chat would show it.
    assert_eq!(
        detail["characters"][0]["scenario"],
        "The causeway is dry. User may leave."
    );
    let (_, again) = server.get(&path).await;
    assert_eq!(
        (
            &again["version"],
            &again["characters"][0]["scenario"][0]["text"]
        ),
        (&json!(2), &form["characters"][0]["scenario"][0]["text"])
    );

    // A card's texts may be long: longer than a request may be elsewhere.
    form["version"] = json!(2);
    form["characters"][0]["scenario"][0]["text"] = json!("The tide. ".repeat(300_000));
    let (status, long) = server.put(&path, form.clone()).await;
    assert_eq!((status, &long["number"]), (200, &json!(3)), "{long}");
    form["version"] = json!(1);

    // What was shown before the save is an edit of an older version now.
    let late = json!({ "code": "changed", "error": "the card was changed meanwhile (v3, not v1); it is read anew", "details": { "what": "card_version", "newest": "3", "version": "1" } });
    assert_eq!(server.put(&path, form.clone()).await, (400, late));
    form["version"] = json!(3);
    form["characters"][0]["name"] = json!("");
    assert_eq!(
        server.put(&path, form).await,
        (
            400,
            json!({ "code": "needed", "error": "a character needs a name", "details": { "what": "character_name" } })
        )
    );
    let missing =
        json!({ "code": "not_found", "error": "no such card", "details": { "what": "card" } });
    assert_eq!(
        server.get("/api/cards/99/edit").await,
        (404, missing.clone())
    );
    assert_eq!(
        server.put("/api/cards/99/edit", again).await,
        (404, missing)
    );
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["card"]["version"], 3);
}

const MODED: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
modified = 2026-07-11

[name.gwen]
text = "Gwen"

[description.gwen]
text = "Who she is."

[personality.gwen]
text = "How she speaks in a scene."

[greeting.gwen]
text = "Well met."

[character.gwen]
name-char = "name.gwen"
greetings = ["greeting.gwen"]
prompt = ["name.gwen", "description.gwen", "personality.gwen", "CHAT-HISTORY"]
"#;

#[test]
fn a_card_has_modes_and_a_text_is_used_in_the_modes_it_names() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = cards::import(db, user, &card_of(MODED)).unwrap().card_id;
    let told = |version: i64, mode: Option<&str>| {
        let document = Document::parse(&texts(db, version)).unwrap();
        let gwen =
            mapping::character_in(&document, "gwen", &Default::default(), &[], mode).unwrap();
        (gwen.description, gwen.personality)
    };

    // Modes, a text in one of them and a new text in another: the first mode is the one a chat begins in.
    let mut form = cards::editable(db, user, id, None).unwrap();
    assert!(form.modes.is_empty());
    form.modes = vec!["Roleplay".into(), " assistant ".into(), "ROLEPLAY".into()];
    let one = &mut form.characters[0];
    one.personality[0].modes = vec!["roleplay".into()];
    one.greetings[0].modes = vec!["ROLEPLAY".into()];
    one.personality.push(EditText {
        modes: vec!["Assistant".into()],
        ..new("How she answers at work.")
    });
    let saved = cards::edit(db, user, id, &form).unwrap();
    let file = &texts(db, saved.id)[0].1;
    assert!(
        file.contains("modes = [\"Roleplay\", \"assistant\"]")
            && file.contains(
                "[personality.gwen]\ntext = \"How she speaks in a scene.\"\nmodes = [\"Roleplay\"]"
            )
            && file.contains("text = \"How she answers at work.\"\nmodes = [\"assistant\"]"),
        "{file}"
    );
    let scene = (
        "Who she is.".to_string(),
        "How she speaks in a scene.".to_string(),
    );
    let work = (
        "Who she is.".to_string(),
        "How she answers at work.".to_string(),
    );
    assert_eq!(told(saved.id, None), scene);
    assert_eq!(told(saved.id, Some("ASSISTANT")), work);
    assert_eq!(told(saved.id, Some("no such mode")), scene);
    let form = cards::editable(db, user, id, None).unwrap();
    assert_eq!(form.modes, ["Roleplay", "assistant"]);
    let modes: Vec<&Vec<String>> = form.characters[0]
        .personality
        .iter()
        .map(|one| &one.modes)
        .collect();
    assert_eq!(
        modes,
        [
            &vec!["Roleplay".to_string()],
            &vec!["assistant".to_string()]
        ]
    );
    // A greeting is in its modes too.
    assert_eq!(form.characters[0].greetings[0].modes, ["Roleplay"]);

    // A text in a mode the card has not is refused; the modes taken off, every text is used again.
    let mut wrong = form.clone();
    wrong.characters[0].description[0].modes = vec!["Companion".into()];
    assert_eq!(
        refusal(cards::edit(db, user, id, &wrong)),
        "\"Companion\" is no mode of this card"
    );
    let mut none = form;
    none.modes.clear();
    let gwen = &mut none.characters[0];
    for part in gwen.personality.iter_mut().chain(&mut gwen.greetings) {
        part.modes.clear();
    }
    let saved = cards::edit(db, user, id, &none).unwrap();
    assert!(!texts(db, saved.id)[0].1.contains("modes"));
    assert_eq!(
        told(saved.id, Some("assistant")).1,
        "How she speaks in a scene.\n\nHow she answers at work."
    );
}

#[test]
fn a_texts_modes_the_card_has_not_are_not_shown_and_do_not_hold_an_edit_back() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let written = MODED.replace(
        "text = \"How she speaks in a scene.\"",
        "text = \"How she speaks in a scene.\"\nmodes = [\"Roleplay\"]",
    );
    let id = cards::import(db, user, &card_of(&written)).unwrap().card_id;
    let mut form = cards::editable(db, user, id, None).unwrap();
    assert!(form.characters[0].personality[0].modes.is_empty());
    form.characters[0].personality[0].text = "Quiet.".into();
    let saved = cards::edit(db, user, id, &form).unwrap();
    assert_eq!(saved.number, 2);
}

#[test]
fn a_cards_prompt_blocks_and_greetings_for_a_chat_of_several_are_edited_too() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = cards::import(db, user, &common::card_file())
        .unwrap()
        .card_id;
    let mut form = cards::editable(db, user, id, None).unwrap();
    let mira = &mut form.characters[0];
    mira.system_prompt[0].text = "Write warmly.".into();
    mira.post_history[0].text = "[Under 50 words.]".into();
    mira.depth_prompts[0].part.text = "[The light dies.]".into();
    mira.group_greetings = vec![new("Everyone, sit.")];
    let saved = cards::edit(db, user, id, &form).unwrap();
    let document = cards::document(db, user, saved.id).unwrap();
    let told = mapping::character(&document, "mira").unwrap();
    assert_eq!(
        (
            told.system_prompt.as_str(),
            told.post_history_instructions.as_str()
        ),
        ("Write warmly.", "Stay in the scene.\n\n[Under 50 words.]")
    );
    // A block at a depth keeps its depth; a greeting for a chat of several taken off goes from the card.
    assert_eq!(told.depth_prompts[0].prompt, "[The light dies.]");
    assert_eq!(told.depth_prompts[0].depth, 2);
    assert_eq!(document.greetings("mira", true), ["Everyone, sit."]);
    assert!(document.text("greeting.crowd").is_none());

    // A card without prompt blocks gets them: before the chat first in the prompt, after it at its end.
    let id = cards::import(db, user, &card_of(UNTIDY)).unwrap().card_id;
    let mut form = cards::editable(db, user, id, None).unwrap();
    let ada = &mut form.characters[0];
    assert_eq!(
        (
            &ada.system_prompt,
            &ada.post_history,
            ada.depth_prompts.len()
        ),
        (&vec![new("")], &vec![new("")], 0)
    );
    ada.system_prompt = vec![new("Be brief.")];
    ada.post_history = vec![new("[Stay in character.]")];
    let saved = cards::edit(db, user, id, &form).unwrap();
    let document = cards::document(db, user, saved.id).unwrap();
    assert_eq!(
        key(&document, "ada", "prompt"),
        json!([
            "prompt.ada",
            "name.ada",
            "scenario.ada",
            "scenario.ada",
            "CHAT-HISTORY",
            "prompt.ada-2"
        ])
    );
    let told = mapping::character(&document, "ada").unwrap();
    assert_eq!(
        (
            told.system_prompt.as_str(),
            told.post_history_instructions.as_str()
        ),
        ("Be brief.", "[Stay in character.]")
    );
}

#[test]
fn of_a_card_imported_with_several_characters_the_first_is_kept() {
    let file = r#"spec = "ccv4:1.0.0"

[name.ada]
text = "Ada"

[name.bo]
text = "Bo"

[scenario.both]
text = "A ship."

[personality.bo]
text = "Bo's own."

[lore.bo]
keywords = ["bo"]
text = "Of Bo's lorebook."

[lorebook.bo]
entries = ["lore.bo"]

[character.ada]
name-char = "name.ada"
prompt = ["name.ada", "scenario.both", "CHAT-HISTORY"]

[character.bo]
name-char = "name.bo"
lorebooks = ["lorebook.bo"]
prompt = ["name.bo", "personality.bo", "scenario.both", "LOREBOOK", "CHAT-HISTORY"]

[group.crew]
characters = ["character.ada", "character.bo"]
"#;
    let mut files = vec![("card/0001_card.toml".to_string(), file.to_string())];
    let note = cw_ccv4::edit::first_only(&mut files).unwrap();
    assert_eq!(
        note,
        Some(cw_ccv4::ImportNote::FirstCharacterKept { name: "Ada".into() })
    );
    // The other goes with its group and what it alone named, its lorebook's entries too; what both named stays.
    let document = Document::parse(&files).unwrap();
    assert_eq!(document.ids("character"), ["ada"]);
    assert!(document.ids("group").is_empty());
    for gone in ["name.bo", "personality.bo", "lorebook.bo", "lore.bo"] {
        assert!(document.lookup(gone).is_none(), "{gone}");
    }
    assert_eq!(document.text("scenario.both"), Some("A ship."));
    // A card of one character stays as it is.
    let before = files.clone();
    assert_eq!(cw_ccv4::edit::first_only(&mut files).unwrap(), None);
    assert_eq!(files, before);
}

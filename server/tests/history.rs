//! A card's texts with their history: an edit gives each text it changed a
//! draft and puts the card's one version in its place, with the chats moved
//! to it; a greeting taken off keeps its words; a new card's texts have their
//! first drafts; the versions of an older build become drafts at the start
//! (but where a chat's character is gone, or another server runs); a version's
//! id is never given again; and the history goes into an exported card only
//! where the settings ask.
//!
//! A test reads the drafts from the file they are written in (`HISTORY`).

mod common;

use common::Scratch;
use common::server::start;
use cw_ccv4::new::NewCard;
use cw_ccv4::png;
use cw_chat::chats::{self, NewChat};
use cw_key::FILE_NAME;
use cw_library::cards::{self, ExportFormat};
use cw_store::Db;
use toml::{Table, Value};

/// The file of a card the drafts are written in.
const HISTORY: &str = "user/0001_revision.toml";

/// The drafts of the block `reference` in the card's version `version`: what made each, and its text.
fn drafts(db: &Db, version: i64, reference: &str) -> Vec<(String, String)> {
    let file: Option<String> = db
        .with(|conn| {
            conn.query_row(
                "select toml from card_files where version_id = ?1 and name = ?2",
                rusqlite::params![version, HISTORY],
                |r| r.get(0),
            )
        })
        .ok();
    let Some(file) = file else { return Vec::new() };
    let table: Table = toml::from_str(&file).unwrap();
    let Some(drafts) = table
        .get("revision")
        .and_then(|all| all.get(reference))
        .and_then(|revision| revision.get("drafts"))
        .and_then(Value::as_array)
    else {
        return Vec::new();
    };
    drafts
        .iter()
        .map(|draft| {
            assert!(draft["saved"].as_datetime().is_some(), "{draft:?}");
            (
                draft["made"].as_str().unwrap().to_string(),
                draft["payload"]["text"]
                    .as_str()
                    .unwrap()
                    .trim()
                    .to_string(),
            )
        })
        .collect()
}

fn versions(db: &Db, card: i64) -> Vec<i64> {
    db.with(|conn| {
        conn.prepare("select id from card_versions where card_id = ?1 order by number")?
            .query_map([card], |r| r.get(0))?
            .collect()
    })
    .unwrap()
}

fn pair(made: &str, text: &str) -> (String, String) {
    (made.to_string(), text.to_string())
}

/// Adds to the card of `version` a newer version as an older build kept it: a copy of its files, each with
/// `from` replaced by `to`. Returns its id.
fn older_build_version(
    conn: &rusqlite::Connection,
    version: i64,
    from: &str,
    to: &str,
) -> rusqlite::Result<i64> {
    conn.execute(
        "insert into card_versions (card_id, number, image_id, created_at)
         select card_id, number + 1, image_id, created_at + 1000 from card_versions where id = ?1",
        [version],
    )?;
    let newer = conn.last_insert_rowid();
    conn.execute(
        "insert into card_files (version_id, name, toml, asset_id)
         select ?2, name, replace(toml, ?3, ?4), asset_id from card_files where version_id = ?1",
        rusqlite::params![version, newer, from, to],
    )?;
    Ok(newer)
}

/// The pinned flag and the words of each draft of the sample card's personality, in the version `version`.
fn pinned_drafts(db: &Db, version: i64) -> Vec<(Option<bool>, String)> {
    let file: String = db
        .with(|conn| {
            conn.query_row(
                "select toml from card_files where version_id = ?1 and name = 'user/0000_state.toml'",
                [version],
                |r| r.get(0),
            )
        })
        .unwrap();
    let table: Table = toml::from_str(&file).unwrap();
    table["revision"]["personality.mira"]["drafts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|draft| {
            (
                draft.get("pinned").and_then(Value::as_bool),
                draft["payload"]["text"].as_str().unwrap().to_string(),
            )
        })
        .collect()
}

#[test]
fn a_pinned_text_an_older_build_edited_keeps_both_wordings_when_its_versions_are_folded() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    // That build wrote the edit into the pinned draft of the newer version's own file.
    let newer = db
        .with(|conn| older_build_version(conn, card.version_id, "Wry, patient.", "Wry, kind."))
        .unwrap();
    cards::fold_versions(db).unwrap();
    assert_eq!(versions(db, card.card_id), [newer]);
    let form = cards::editable(db, me, card.card_id, None).unwrap();
    assert_eq!(form.characters[0].personality[0].text, "Wry, kind.");
    let some = |pinned: Option<bool>, text: &str| (pinned, text.to_string());
    assert_eq!(
        pinned_drafts(db, newer),
        [
            some(Some(true), "Old pin."),
            some(Some(true), "Wry, patient."),
            some(None, "Not pinned."),
            some(Some(true), "Wry, kind.")
        ]
    );
}

#[test]
fn a_card_whose_newest_version_lacks_a_chats_character_keeps_that_chats_version() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let chat = chats::create(
        db,
        me,
        &NewChat {
            characters: &[(card.version_id, "mira")],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    // The newer version has another character in Mira's place.
    let newer = db
        .with(|conn| older_build_version(conn, card.version_id, "mira", "vale"))
        .unwrap();
    cards::fold_versions(db).unwrap();
    assert_eq!(versions(db, card.card_id), [card.version_id, newer]);
    // Its versions stay as they are, to be folded at a later start (as drafts once only).
    let history: i64 = db
        .with(|conn| {
            conn.query_row(
                "select count(*) from card_files where name = ?1",
                [HISTORY],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(history, 0);

    // An edit puts its version in the newest's place alone: the chat stays where it is.
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.title = "Renamed".to_string();
    let edited = cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(versions(db, card.card_id), [card.version_id, edited.id]);
    let mira = chats::participants(db, me, chat).unwrap().remove(0);
    assert_eq!(mira.version_id, card.version_id);
}

#[test]
fn a_texts_newest_draft_is_the_one_saved_last_whatever_its_place() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let mut container = common::container();
    let state = container
        .toml
        .iter_mut()
        .find(|(name, _)| name == "user/0000_state.toml")
        .unwrap();
    // The card's words are its newest draft's, which stands first.
    state.1.push_str(
        r#"
[revision."scenario.storm"]
drafts = [
  { saved = 2026-07-12T18:30:00Z, payload = { text = "A storm has cut the causeway. {{user}} is stranded." } },
  { saved = 2026-07-01T09:00:00Z, payload = { text = "Older words." } },
]
"#,
    );
    let card = cards::import(db, me, &png::write(&container).unwrap()).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.characters[0].scenario[0].text = "Calm.".to_string();
    let edited = cards::edit(db, me, card.card_id, &form).unwrap();
    // No draft of how it read before is added: the newest has those words.
    let file: String = db
        .with(|conn| {
            conn.query_row(
                "select toml from card_files where version_id = ?1 and name = 'user/0000_state.toml'",
                [edited.id],
                |r| r.get(0),
            )
        })
        .unwrap();
    let table: Table = toml::from_str(&file).unwrap();
    let texts: Vec<&str> = table["revision"]["scenario.storm"]["drafts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|draft| draft["payload"]["text"].as_str().unwrap())
        .collect();
    assert_eq!(
        texts,
        [
            "A storm has cut the causeway. {{user}} is stranded.",
            "Older words.",
            "Calm."
        ]
    );
}

#[test]
fn a_card_versions_id_is_never_given_again() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let gone = cards::import(db, me, &common::card_file()).unwrap();
    db.with(|conn| conn.execute("delete from cards where id = ?1", [gone.card_id]))
        .unwrap();
    let next = cards::import(db, me, &common::card_file()).unwrap();
    assert!(next.version_id > gone.version_id);
}

#[tokio::test]
async fn the_versions_are_folded_only_by_a_server_alone_on_its_data() {
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    let version = card["version_id"].as_i64().unwrap();
    let card_id = card["card_id"].as_i64().unwrap();
    db.with(|conn| older_build_version(conn, version, "Dry, patient.", "Warm."))
        .unwrap();

    // A second server started on the same data folder leaves the versions alone.
    drop(cardwave_server::router(server.options()).unwrap());
    assert_eq!(versions(&db, card_id).len(), 2);
    drop(db);
    let server = server.restart().await;
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    assert_eq!(versions(&db, card_id).len(), 1);
}

#[test]
fn an_edit_gives_each_text_it_changed_a_draft_and_moves_the_chats_to_the_card_as_it_is() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let chat = chats::create(
        db,
        me,
        &NewChat {
            characters: &[(card.version_id, "mira")],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    // An imported card's texts have no drafts until they change.
    assert!(drafts(db, card.version_id, "description.mira").is_empty());

    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let mira = &mut form.characters[0];
    mira.name = "Mira Vale".to_string();
    let description = mira
        .description
        .iter_mut()
        .find(|text| text.reference.as_deref() == Some("description.mira"))
        .unwrap();
    description.text = "Counts the ships twice.".to_string();
    let first = cards::edit(db, me, card.card_id, &form).unwrap();

    // The card has one version, the edited one, and its chat is with it under the new name.
    assert_eq!(versions(db, card.card_id), [first.id]);
    let with = chats::participants(db, me, chat).unwrap();
    assert_eq!(with[0].version_id, first.id);
    let name: String = db
        .with(|conn| {
            conn.query_row(
                "select name from chat_characters where chat_id = ?1",
                [chat],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(name, "Mira Vale");
    // Each text changed has how it read before and how it reads now; the others have nothing.
    assert_eq!(
        drafts(db, first.id, "description.mira"),
        [
            pair(
                "imported",
                "Keeper of the north light. {{char}} counts ships."
            ),
            pair("edited", "Counts the ships twice.")
        ]
    );
    assert_eq!(
        drafts(db, first.id, "name.mira"),
        [pair("imported", "Mira"), pair("edited", "Mira Vale")]
    );
    assert!(drafts(db, first.id, "scenario.storm").is_empty());

    // The next edit adds one more draft, the newest last.
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let description = form.characters[0]
        .description
        .iter_mut()
        .find(|text| text.reference.as_deref() == Some("description.mira"))
        .unwrap();
    description.text = "Counts nothing.".to_string();
    let second = cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(versions(db, card.card_id), [second.id]);
    assert_eq!(
        drafts(db, second.id, "description.mira").last(),
        Some(&pair("edited", "Counts nothing."))
    );
    assert_eq!(drafts(db, second.id, "description.mira").len(), 3);

    // A text put in a mode keeps its words: no draft; its next words are one draft, not two.
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.modes = vec!["Roleplay".to_string()];
    let description = form.characters[0]
        .description
        .iter_mut()
        .find(|text| text.reference.as_deref() == Some("description.mira"))
        .unwrap();
    description.modes = vec!["Roleplay".to_string()];
    let moded = cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(drafts(db, moded.id, "description.mira").len(), 3);
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let description = form.characters[0]
        .description
        .iter_mut()
        .find(|text| text.reference.as_deref() == Some("description.mira"))
        .unwrap();
    description.text = "Counts the gulls.".to_string();
    let third = cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(
        drafts(db, third.id, "description.mira")[3..],
        [pair("edited", "Counts the gulls.")]
    );
    // The card's own user file stays as it came.
    let state: i64 = db
        .with(|conn| {
            conn.query_row(
                "select count(*) from card_files where version_id = ?1 and name = 'user/0000_state.toml'",
                [third.id],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(state, 1);
}

#[test]
fn a_text_a_pin_stands_in_for_keeps_the_pinned_words_and_the_edit_stands_in_after_it() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    assert_eq!(form.characters[0].personality[0].text, "Wry, patient.");
    form.characters[0].personality[0].text = "Warm.".to_string();
    let edited = cards::edit(db, me, card.card_id, &form).unwrap();

    let form = cards::editable(db, me, card.card_id, None).unwrap();
    assert_eq!(form.characters[0].personality[0].text, "Warm.");
    // The card's own file keeps the revision it brought, with the edit after its drafts.
    let file: String = db
        .with(|conn| {
            conn.query_row(
                "select toml from card_files where version_id = ?1 and name = 'user/0000_state.toml'",
                [edited.id],
                |r| r.get(0),
            )
        })
        .unwrap();
    let table: Table = toml::from_str(&file).unwrap();
    let drafts: Vec<(Option<bool>, &str)> = table["revision"]["personality.mira"]["drafts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|draft| {
            (
                draft.get("pinned").and_then(Value::as_bool),
                draft["payload"]["text"].as_str().unwrap(),
            )
        })
        .collect();
    assert_eq!(
        drafts,
        [
            (Some(true), "Old pin."),
            (Some(true), "Wry, patient."),
            (None, "Not pinned."),
            (Some(true), "Warm.")
        ]
    );
}

#[test]
fn a_greeting_taken_off_keeps_its_words_and_a_new_one_does_not_take_its_history() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let lamp = form.characters[0]
        .greetings
        .iter()
        .position(|one| one.reference.as_deref() == Some("greeting.lamp"))
        .unwrap();
    form.characters[0].greetings.remove(lamp);
    let gone = cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(
        drafts(db, gone.id, "greeting.lamp"),
        [pair("imported", "Hold the lamp. Don't ask.")]
    );

    // A greeting added later is a block of its own.
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.characters[0].greetings.push(cw_ccv4::edit::EditText {
        reference: None,
        text: "Shut the door.".to_string(),
        modes: Vec::new(),
    });
    let added = cards::edit(db, me, card.card_id, &form).unwrap();
    let form = cards::editable(db, me, card.card_id, None).unwrap();
    let new = form.characters[0].greetings.last().unwrap();
    let reference = new.reference.clone().unwrap();
    assert_ne!(reference, "greeting.lamp");
    assert_eq!(
        drafts(db, added.id, &reference),
        [pair("edited", "Shut the door.")]
    );
    assert_eq!(drafts(db, added.id, "greeting.lamp").len(), 1);
}

#[test]
fn a_new_cards_texts_have_their_first_drafts() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let new = NewCard {
        creation: None,
        title: "Ada".to_string(),
        tags: Vec::new(),
        creator: String::new(),
        name: "Ada".to_string(),
        greetings: vec!["Hello.".to_string()],
        description: "A mathematician.".to_string(),
        personality: String::new(),
        scenario: String::new(),
        example_dialogue: String::new(),
        creator_notes: String::new(),
        system_prompt: None,
        post_history: None,
        talkativeness: None,
        picture: None,
    };
    let made = cards::create(db, me, new).unwrap();
    let document = cards::document(db, me, made.version_id).unwrap();
    let description = document
        .ids("description")
        .first()
        .map(|id| format!("description.{id}"))
        .unwrap();
    assert_eq!(
        drafts(db, made.version_id, &description),
        [pair("edited", "A mathematician.")]
    );
}

#[test]
fn the_versions_of_an_older_build_become_the_texts_drafts_and_its_chats_move_to_the_newest() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let chat = chats::create(
        db,
        me,
        &NewChat {
            characters: &[(card.version_id, "mira")],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    // A second and third version as an older build kept them: a copy of the
    // files with the personality changed, and the second with another picture.
    let other_picture = common::png_with(vec![common::text_chunk("Comment", b"older")]);
    let newest = db
        .with(|conn| {
            conn.execute(
                "insert into blobs (hash, data) values (x'00', ?1)",
                [&other_picture],
            )?;
            let picture = conn.last_insert_rowid();
            let mut newest = 0;
            for (number, picture, scenario) in
                [(2, Some(picture), "Warm."), (3, None, "Cold.")]
            {
                conn.execute(
                    "insert into card_versions (card_id, number, image_id, created_at)
                     select card_id, ?2, coalesce(?3, image_id), created_at + ?2 * 1000 from card_versions where id = ?1",
                    rusqlite::params![card.version_id, number, picture],
                )?;
                newest = conn.last_insert_rowid();
                conn.execute(
                    "insert into card_files (version_id, name, toml, asset_id)
                     select ?2, name, replace(toml, 'A storm has cut the causeway.', ?3), asset_id from card_files where version_id = ?1",
                    rusqlite::params![card.version_id, newest, scenario],
                )?;
            }
            // As the schema step that brought `card_pictures` lists them.
            conn.execute(
                "insert or ignore into card_pictures (card_id, image_id, added_at)
                 select card_id, image_id, min(created_at) from card_versions group by card_id, image_id",
                [],
            )?;
            Ok(newest)
        })
        .unwrap();

    cards::fold_versions(db).unwrap();
    assert_eq!(versions(db, card.card_id), [newest]);
    assert_eq!(
        chats::participants(db, me, chat).unwrap()[0].version_id,
        newest
    );
    assert_eq!(
        drafts(db, newest, "scenario.storm"),
        [
            pair(
                "imported",
                "A storm has cut the causeway. {{user}} is stranded."
            ),
            pair("edited", "Warm. {{user}} is stranded."),
            pair("edited", "Cold. {{user}} is stranded.")
        ]
    );
    assert!(drafts(db, newest, "description.mira").is_empty());
    // The picture of the version folded in stays the card's.
    let pictures: i64 = db
        .with(|conn| {
            conn.query_row(
                "select count(*) from card_pictures p join blobs b on b.id = p.image_id where p.card_id = ?1",
                [card.card_id],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(pictures, 2);
    // Done once: a second start changes nothing.
    cards::fold_versions(db).unwrap();
    assert_eq!(drafts(db, newest, "scenario.storm").len(), 3);
}

#[test]
fn an_exported_card_has_its_texts_history_only_where_asked() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.characters[0].scenario[0].text = "Warm.".to_string();
    cards::edit(db, me, card.card_id, &form).unwrap();
    let names = |history: bool| {
        let file = cards::export(db, me, card.card_id, ExportFormat::Ccv4, history, None).unwrap();
        let container = png::read(&file.data).unwrap();
        container
            .toml
            .into_iter()
            .map(|(name, _)| name)
            .collect::<Vec<_>>()
    };
    assert!(names(false).iter().all(|name| name.starts_with("card/")));
    let with = names(true);
    assert!(with.contains(&HISTORY.to_string()), "{with:?}");
    // Nothing else of the user's goes along.
    assert!(!with.contains(&"user/0000_state.toml".to_string()));

    // Imported again, the card has its history.
    let file = cards::export(db, me, card.card_id, ExportFormat::Ccv4, true, None).unwrap();
    let again = cards::import(db, me, &file.data).unwrap();
    assert_eq!(drafts(db, again.version_id, "scenario.storm").len(), 2);
}

#[test]
fn a_texts_drafts_are_listed_newest_first_and_a_greeting_taken_off_with_any_greetings() {
    use cw_ccv4::drafts::RESTORED;
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let listed = |reference: &str| {
        let all = cards::drafts(db, me, card.card_id, reference).unwrap();
        let pairs = |drafts: &[cw_ccv4::drafts::TextDraft]| {
            drafts
                .iter()
                .map(|one| pair(&one.made, &one.text))
                .collect::<Vec<_>>()
        };
        (pairs(&all.drafts), pairs(&all.deleted))
    };
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let description = form.characters[0].description[0].clone();
    let reference = description.reference.clone().unwrap();
    // An imported text never changed is its one draft.
    assert_eq!(listed(&reference).0, [pair("imported", &description.text)]);

    form.characters[0].description[0].text = "A keeper of lamps.".to_string();
    cards::edit(db, me, card.card_id, &form).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.characters[0].description[0].text = description.text.clone();
    cards::edit_as(db, me, card.card_id, &form, RESTORED).unwrap();
    assert_eq!(
        listed(&reference).0,
        [
            pair("restored", &description.text),
            pair("edited", "A keeper of lamps."),
            pair("imported", &description.text),
        ]
    );
    form.version += 1;
    assert!(cards::edit_as(db, me, card.card_id, &form, "guessed").is_err());

    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let greetings = &mut form.characters[0].greetings;
    let lamp = greetings
        .iter()
        .position(|one| one.reference.as_deref() == Some("greeting.lamp"))
        .unwrap();
    greetings.remove(lamp);
    let other = greetings[0].reference.clone().unwrap();
    cards::edit(db, me, card.card_id, &form).unwrap();
    assert_eq!(
        listed(&other).1,
        [pair("imported", "Hold the lamp. Don't ask.")]
    );
    assert!(listed(&reference).1.is_empty());

    // Brought back as a greeting of its own, it is no longer one taken off.
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    form.characters[0].greetings.push(cw_ccv4::edit::EditText {
        reference: None,
        text: "Hold the lamp. Don't ask.".to_string(),
        modes: Vec::new(),
    });
    cards::edit_as(db, me, card.card_id, &form, RESTORED).unwrap();
    assert!(listed(&other).1.is_empty());
}

#[test]
fn an_ai_tools_change_is_a_draft_named_after_the_tool_and_nothing_else_names_one() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cards::import(db, me, &common::card_file()).unwrap();
    let mut form = cards::editable(db, me, card.card_id, None).unwrap();
    let description = form.characters[0]
        .description
        .iter_mut()
        .find(|text| text.reference.as_deref() == Some("description.mira"))
        .unwrap();
    description.text = "Counts the ships twice, and the stars.".to_string();
    assert!(cards::edit_as(db, me, card.card_id, &form, "made up").is_err());
    let edited = cards::edit_as(db, me, card.card_id, &form, "longer").unwrap();
    let made = drafts(db, edited.id, "description.mira");
    assert!(made.iter().any(|(by, _)| by == "longer"), "{made:?}");
}

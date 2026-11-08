//! Lorebooks of the library for every chat and for a persona: a chat has them
//! as it has those attached to its cards, merged with its characters' own
//! under one budget, and can leave them out.

mod common;

use common::Scratch;
use common::lore::{count, single};
use common::server::start;
use cw_chat::chats::{self, LoreSource, NewChat};
use cw_library::cards::Imported;
use cw_library::lorebooks;
use cw_library::personas;
use serde_json::{Value, json};

fn chat_as(scratch: &Scratch, card: &Imported, persona_id: Option<i64>) -> i64 {
    let new = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id,
        greeting: 0,
    };
    chats::create(&scratch.db, scratch.user, &new).unwrap()
}

/// The chat's lorebooks as (name, on, whether the chat took it along itself).
fn had(scratch: &Scratch, chat_id: i64) -> Vec<(String, bool, bool)> {
    chats::lorebooks(&scratch.db, scratch.user, chat_id)
        .unwrap()
        .into_iter()
        .map(|book| (book.name, book.on, book.taken))
        .collect()
}

/// The IDs of the library's lorebooks the chat's next prompt is built with.
fn library(scratch: &Scratch, chat_id: i64) -> Vec<i64> {
    chats::prompt_inputs(&scratch.db, scratch.user, chat_id, None)
        .unwrap()
        .library
}

/// The reference of the chat's lorebook `id` of the library, as the chat leaves it out by.
fn book_of(scratch: &Scratch, chat_id: i64, id: i64) -> String {
    chats::lorebooks(&scratch.db, scratch.user, chat_id)
        .unwrap()
        .into_iter()
        .find(|book| book.source == LoreSource::LorebookId(id))
        .expect("the chat has the lorebook")
        .reference
}

fn line(name: &str, on: bool) -> (String, bool, bool) {
    (name.to_string(), on, false)
}

#[test]
fn a_lorebook_for_every_chat_is_had_by_each_chat_with_a_character() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let world = single(&scratch, "World");
    let before = chat_as(&scratch, &card, None);
    let plain = chats::create(
        db,
        me,
        &NewChat {
            characters: &[],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();

    // A chat that was there has it from then on, after its characters' own, in its prompt too; so has a new one.
    lorebooks::set_everywhere(db, me, world, true).unwrap();
    assert!(lorebooks::get(db, me, world).unwrap().unwrap().everywhere);
    let after = chat_as(&scratch, &card, None);
    for chat_id in [before, after] {
        assert_eq!(
            had(&scratch, chat_id),
            [line("coast", true), line("World", true)]
        );
        assert_eq!(library(&scratch, chat_id), [world]);
    }
    let entry = format!(".{world}.lore.lorebook-world");
    let ids = |chat_id| -> Vec<String> {
        chats::prompt_inputs(db, me, chat_id, None)
            .unwrap()
            .character
            .lorebook
            .unwrap()
            .entries
            .into_iter()
            .filter_map(|entry| entry.id)
            .collect()
    };
    assert!(ids(before).contains(&entry), "{:?}", ids(before));
    // A chat without a character, the AI itself, has no lore.
    assert_eq!(had(&scratch, plain), []);

    // A chat leaves it out as it would one of its card's; once it is for every chat no longer, that is forgotten.
    chats::set_lore(
        db,
        me,
        before,
        LoreSource::LorebookId(world),
        &book_of(&scratch, before, world),
        false,
    )
    .unwrap();
    assert_eq!(had(&scratch, before)[1], line("World", false));
    assert!(!ids(before).contains(&entry));
    assert_eq!(had(&scratch, after)[1], line("World", true));
    lorebooks::set_everywhere(db, me, world, false).unwrap();
    assert_eq!(
        (had(&scratch, before), count(db, "chat_lorebook_off")),
        (vec![line("coast", true)], 0)
    );
    lorebooks::set_everywhere(db, me, world, true).unwrap();
    assert_eq!(had(&scratch, before)[1], line("World", true));

    // Turned on twice, it keeps its place; one in the Trash cannot be made one.
    lorebooks::set_everywhere(db, me, world, true).unwrap();
    let ocean = single(&scratch, "Ocean");
    lorebooks::set_trashed(db, me, ocean, true).unwrap();
    let refused = lorebooks::set_everywhere(db, me, ocean, true).unwrap_err();
    assert!(
        format!("{refused:#}").contains("in the Trash"),
        "{refused:#}"
    );
}

#[test]
fn a_personas_lorebooks_are_had_by_the_chats_it_is_in() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let (diary, map, attic) = (
        single(&scratch, "Diary"),
        single(&scratch, "Map"),
        single(&scratch, "Attic"),
    );
    let ada = personas::create(db, me, "Ada", "").unwrap();
    let bo = personas::create(db, me, "Bo", "").unwrap();
    personas::set_lorebooks(db, me, ada, &[map, diary]).unwrap();
    let names = |id| -> Vec<String> {
        personas::get(db, me, id)
            .unwrap()
            .unwrap()
            .lorebooks
            .into_iter()
            .map(|book| book.name)
            .collect()
    };
    assert_eq!(names(ada), ["Map", "Diary"]);

    let as_ada = chat_as(&scratch, &card, Some(ada));
    let as_nobody = chat_as(&scratch, &card, None);
    assert_eq!(
        had(&scratch, as_ada),
        [line("coast", true), line("Map", true), line("Diary", true)]
    );
    assert_eq!(library(&scratch, as_ada), [map, diary]);
    assert_eq!(had(&scratch, as_nobody), [line("coast", true)]);

    // What the chat left out goes with the persona; the other persona brings its own.
    chats::set_lore(
        db,
        me,
        as_ada,
        LoreSource::LorebookId(map),
        &book_of(&scratch, as_ada, map),
        false,
    )
    .unwrap();
    personas::set_lorebooks(db, me, bo, &[attic]).unwrap();
    chats::set_persona(db, me, as_ada, Some(bo)).unwrap();
    assert_eq!(
        (had(&scratch, as_ada), count(db, "chat_lorebook_off")),
        (vec![line("coast", true), line("Attic", true)], 0)
    );
    chats::set_persona(db, me, as_ada, Some(ada)).unwrap();
    assert_eq!(had(&scratch, as_ada)[1], line("Map", true));

    // Its lorebooks are set as a whole: one taken away is gone from its chats, with what they left out of it.
    chats::set_lore(
        db,
        me,
        as_ada,
        LoreSource::LorebookId(diary),
        &book_of(&scratch, as_ada, diary),
        false,
    )
    .unwrap();
    personas::set_lorebooks(db, me, ada, &[map]).unwrap();
    assert_eq!(
        (
            names(ada),
            had(&scratch, as_ada),
            count(db, "chat_lorebook_off")
        ),
        (
            vec!["Map".to_string()],
            vec![line("coast", true), line("Map", true)],
            0
        )
    );

    // One in the Trash is not given, but one it has stays while it is there.
    lorebooks::set_trashed(db, me, attic, true).unwrap();
    assert!(personas::set_lorebooks(db, me, ada, &[map, attic]).is_err());
    personas::set_lorebooks(db, me, bo, &[attic]).unwrap();
    let kept = personas::get(db, me, bo).unwrap().unwrap().lorebooks;
    assert_eq!((kept.len(), kept[0].trashed), (1, true));
    // Deleted for good, the persona no longer has it.
    lorebooks::set_trashed(db, me, map, true).unwrap();
    cw_library::trash::delete_lorebook(db, me, map).unwrap();
    assert_eq!(names(ada), [] as [&str; 0]);
}

#[test]
fn a_persona_deleted_for_good_takes_what_its_chats_left_out_of_its_lorebooks() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let map = single(&scratch, "Map");
    let ada = personas::create(db, me, "Ada", "").unwrap();
    personas::set_lorebooks(db, me, ada, &[map]).unwrap();
    let chat_id = chat_as(&scratch, &card, Some(ada));
    let reference = book_of(&scratch, chat_id, map);
    chats::set_lore(
        db,
        me,
        chat_id,
        LoreSource::LorebookId(map),
        &reference,
        false,
    )
    .unwrap();
    personas::set_trashed(db, me, ada, true).unwrap();
    cw_library::trash::delete_persona(db, me, ada).unwrap();
    assert_eq!(count(db, "chat_lorebook_off"), 0);
    // Made one for every chat later, the chat has it whole.
    lorebooks::set_everywhere(db, me, map, true).unwrap();
    assert_eq!(had(&scratch, chat_id)[1], line("Map", true));
}

/// A persona's lorebooks are given with it over HTTP; a change of them that is
/// refused changes nothing of the persona.
#[tokio::test]
async fn a_persona_is_given_lorebooks_and_a_lorebook_every_chat_over_http() {
    let server = start().await;
    let file =
        json!({ "entries": { "0": { "key": ["map"], "comment": "Map", "content": "The map." } } });
    let (status, map) = server
        .upload(
            "/api/lorebooks?name=Map.json",
            file.to_string().into_bytes(),
        )
        .await;
    assert_eq!(status, 201, "{map}");
    let map = map["lorebook"]["id"].clone();

    let (status, ada) = server
        .post(
            "/api/personas",
            json!({ "name": "Ada", "lorebooks": [map] }),
        )
        .await;
    assert_eq!(status, 201, "{ada}");
    assert_eq!(
        ada["lorebooks"],
        json!([{ "id": map, "name": "Map", "trashed": false }])
    );
    let at = format!("/api/personas/{}", ada["id"]);
    let (status, _) = server
        .patch(&at, json!({ "name": "Ada Two", "lorebooks": [map, 999] }))
        .await;
    assert_eq!(status, 404);
    let (_, list) = server.get("/api/personas").await;
    assert_eq!(list[0]["name"], "Ada");
    let (status, changed) = server.patch(&at, json!({ "lorebooks": [] })).await;
    assert_eq!((status, changed["lorebooks"].clone()), (200, json!([])));

    // Not one going to the Trash, and the refusal changes nothing.
    let at = format!("/api/lorebooks/{map}");
    let refused = json!({ "name": "Chart", "trashed": true, "everywhere": true });
    assert_eq!(server.patch(&at, refused).await.0, 400);
    let (_, book) = server.patch(&at, json!({})).await;
    assert_eq!(
        (&book["name"], &book["trashed"], &book["everywhere"]),
        (&json!("Map"), &json!(false), &json!(false))
    );
    let (status, book) = server
        .patch(
            &format!("/api/lorebooks/{map}"),
            json!({ "everywhere": true }),
        )
        .await;
    assert_eq!(
        (status, book["everywhere"].clone()),
        (200, Value::Bool(true))
    );
}

#[test]
fn a_chat_tells_which_of_its_lorebooks_are_its_personas_and_which_are_for_every_chat() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let (diary, world, harbour) = (
        single(&scratch, "Diary"),
        single(&scratch, "World"),
        single(&scratch, "Harbour"),
    );
    let ada = personas::create(db, me, "Ada", "").unwrap();
    personas::set_lorebooks(db, me, ada, &[diary]).unwrap();
    lorebooks::set_everywhere(db, me, world, true).unwrap();
    let chat_id = chat_as(&scratch, &card, Some(ada));
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    // (name, taken by the chat, for every chat, the persona's): the card's, the persona's and every chat's as they came, the chat's own.
    let why: Vec<_> = chats::lorebooks(db, me, chat_id)
        .unwrap()
        .into_iter()
        .map(|book| (book.name, book.taken, book.everywhere, book.persona))
        .collect();
    assert_eq!(
        why,
        [
            ("coast".to_string(), false, false, false),
            ("Diary".to_string(), false, false, true),
            ("World".to_string(), false, true, false),
            ("Harbour".to_string(), true, false, false),
        ]
    );
}

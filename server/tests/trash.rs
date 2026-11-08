//! The Trash: what goes there together, what comes back together, and what is
//! deleted for good, by the user or after its days are up.

mod common;

use common::Scratch;
use common::server::{Server, event, start};
use cw_ccv4::png;
use cw_chat::chats::{self, LoreSource, NewChat, NewMessage, turn};
use cw_key::FILE_NAME;
use cw_library::trash::{self, DAYS, TrashItem};
use cw_library::{cards, personas};
use cw_prompt::Role;
use cw_store::Db;
use serde_json::{Value, json};

const DAY: i64 = 24 * 60 * 60 * 1000;

/// The sample card under another title. With `own_files` its picture's asset is its own.
fn card_file(title: &str, own_files: bool) -> Vec<u8> {
    let mut container = common::container();
    container.toml[0].1 = container.toml[0]
        .1
        .replace("\"Mira of the North Light\"", &json!(title).to_string());
    assert!(container.toml[0].1.contains(title));
    if own_files {
        container.assets[0].1 = title.as_bytes().to_vec();
    }
    png::write(&container).unwrap()
}

/// Imports a card; returns its id and its version's.
fn card(scratch: &Scratch, title: &str) -> (i64, i64) {
    let imported = cards::import(&scratch.db, scratch.user, &card_file(title, true)).unwrap();
    (imported.card_id, imported.version_id)
}

fn chat(scratch: &Scratch, versions: &[i64]) -> i64 {
    let characters: Vec<(i64, &str)> = versions.iter().map(|version| (*version, "mira")).collect();
    chats::create(
        &scratch.db,
        scratch.user,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap()
}

fn card_trashed(scratch: &Scratch, id: i64) -> bool {
    cards::get(&scratch.db, scratch.user, id)
        .unwrap()
        .expect("the card is gone")
        .trashed
}

fn chat_trashed(scratch: &Scratch, id: i64) -> bool {
    chats::get(&scratch.db, scratch.user, id)
        .unwrap()
        .expect("the chat is gone")
        .trashed
}

fn count(db: &Db, table: &str) -> i64 {
    db.with(|conn| conn.query_row(&format!("select count(*) from {table}"), [], |r| r.get(0)))
        .unwrap()
}

/// Makes an item look as if it went to the Trash at `at`.
fn trashed_at(db: &Db, table: &str, id: i64, at: i64) {
    let changed = db
        .with(|conn| {
            conn.execute(
                &format!(
                    "update {table} set trashed_at = ?2 where id = ?1 and trashed_at is not null"
                ),
                [id, at],
            )
        })
        .unwrap();
    assert_eq!(changed, 1, "{table} {id} is not in the Trash");
}

/// What the Trash lists, as (kind, id, chats that went along).
fn listed(scratch: &Scratch) -> Vec<(&'static str, i64, u32)> {
    trash::list(&scratch.db, scratch.user)
        .unwrap()
        .into_iter()
        .map(|item| match item {
            TrashItem::Card { id, chats, .. } => ("card", id, chats),
            TrashItem::Chat { id, .. } => ("chat", id, 0),
            TrashItem::Persona { id, chats, .. } => ("persona", id, chats),
            TrashItem::Lorebook { id, chats, .. } => ("lorebook", id, chats),
            TrashItem::ExpressionPack { id, .. } => ("expression pack", id, 0),
            TrashItem::Figure { id, .. } => ("figure", id, 0),
        })
        .collect()
}

#[test]
fn a_card_takes_its_chats_to_the_trash_and_brings_them_back() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let (other, other_version) = card(&scratch, "Other");
    let [first, second, alone] = [
        chat(&scratch, &[version]),
        chat(&scratch, &[version]),
        chat(&scratch, &[version]),
    ];
    let stranger = chat(&scratch, &[other_version]);
    // One of them was deleted by itself before.
    chats::set_trashed(db, me, alone, true).unwrap();
    trashed_at(db, "chats", alone, 1000);

    cards::set_trashed(db, me, mira, true).unwrap();
    assert!(card_trashed(&scratch, mira));
    assert!(
        chat_trashed(&scratch, first)
            && chat_trashed(&scratch, second)
            && chat_trashed(&scratch, alone)
    );
    // Another card and its chat have nothing to do with it.
    assert!(!card_trashed(&scratch, other) && !chat_trashed(&scratch, stranger));
    // The chats that went with the card are part of its item; the one deleted before has its own.
    assert_eq!(listed(&scratch), [("card", mira, 2), ("chat", alone, 0)]);
    // They went in the same moment, so they are due in the same moment.
    let moments: Vec<i64> = db
        .with(|conn| {
            let mut query = conn.prepare("select trashed_at from cards where id = ?1 union all select trashed_at from chats where id in (?2, ?3)")?;
            query.query_map([mira, first, second], |r| r.get(0))?.collect()
        })
        .unwrap();
    assert!(
        moments[0] > 1000 && moments.iter().all(|moment| *moment == moments[0]),
        "{moments:?}"
    );

    cards::set_trashed(db, me, mira, false).unwrap();
    assert!(!card_trashed(&scratch, mira));
    assert!(!chat_trashed(&scratch, first) && !chat_trashed(&scratch, second));
    // What was deleted by itself is still deleted.
    assert!(chat_trashed(&scratch, alone));
    assert_eq!(listed(&scratch), [("chat", alone, 0)]);

    // A chat brought back by itself does not go back in when its card comes out again later.
    chats::set_trashed(db, me, alone, false).unwrap();
    assert!(listed(&scratch).is_empty());
}

#[test]
fn deleting_again_does_not_count_the_days_anew() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let talk = chat(&scratch, &[version]);
    let moment = |table: &str, id: i64| -> i64 {
        db.with(|conn| {
            conn.query_row(
                &format!("select trashed_at from {table} where id = ?1"),
                [id],
                |r| r.get(0),
            )
        })
        .unwrap()
    };
    chats::set_trashed(db, me, talk, true).unwrap();
    trashed_at(db, "chats", talk, 1000);
    chats::set_trashed(db, me, talk, true).unwrap();
    assert_eq!(moment("chats", talk), 1000);

    cards::set_trashed(db, me, mira, true).unwrap();
    trashed_at(db, "cards", mira, 2000);
    cards::set_trashed(db, me, mira, true).unwrap();
    assert_eq!((moment("cards", mira), moment("chats", talk)), (2000, 1000));
}

#[test]
fn a_chat_deleted_after_it_went_with_its_card_does_not_come_back_with_it() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let [talk, other] = [chat(&scratch, &[version]), chat(&scratch, &[version])];
    cards::set_trashed(db, me, mira, true).unwrap();
    trashed_at(db, "chats", talk, 1000);
    assert_eq!(listed(&scratch), [("card", mira, 2)]);

    // Deleted by itself now: an item of its own, with the days it had.
    chats::set_trashed(db, me, talk, true).unwrap();
    assert_eq!(listed(&scratch), [("card", mira, 1), ("chat", talk, 0)]);
    let since: i64 = db
        .with(|conn| {
            conn.query_row("select trashed_at from chats where id = ?1", [talk], |r| {
                r.get(0)
            })
        })
        .unwrap();
    assert_eq!(since, 1000);
    cards::set_trashed(db, me, mira, false).unwrap();
    assert!(chat_trashed(&scratch, talk) && !chat_trashed(&scratch, other));
    assert_eq!(listed(&scratch), [("chat", talk, 0)]);
}

#[test]
fn what_a_chat_left_out_of_its_lorebooks_goes_with_the_chat_and_with_the_card() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let (first, second) = (chat(&scratch, &[version]), chat(&scratch, &[version]));
    for talk in [first, second] {
        chats::set_lore(
            db,
            me,
            talk,
            LoreSource::CardId(mira),
            "lorebook.coast",
            false,
        )
        .unwrap();
        chats::set_lore(db, me, talk, LoreSource::CardId(mira), "lore.lamp", false).unwrap();
    }
    assert_eq!(count(db, "chat_lore_off"), 4);

    chats::set_trashed(db, me, first, true).unwrap();
    trash::delete_chat(db, me, first).unwrap();
    assert_eq!(count(db, "chat_lore_off"), 2);
    cards::set_trashed(db, me, mira, true).unwrap();
    trash::delete_card(db, me, mira).unwrap();
    assert_eq!(
        (
            count(db, "chat_lore_off"),
            count(db, "chats"),
            count(db, "cards")
        ),
        (0, 0, 0)
    );
}

#[test]
fn a_chat_in_the_trash_is_only_read() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let talk = chat(&scratch, &[version]);
    let hello = NewMessage {
        role: Role::User,
        speaker_id: None,
        content: "Hello",
        complete: true,
    };
    let first = chats::append(db, me, talk, &hello).unwrap();
    let second = chats::append(db, me, talk, &hello).unwrap();
    let before = chats::path(db, me, talk).unwrap();
    chats::set_trashed(db, me, talk, true).unwrap();

    let refused = |result: anyhow::Result<()>, what: &str| {
        let error = result.expect_err(what);
        assert_eq!(
            format!("{error:#}"),
            "the chat is in the Trash; restore it first",
            "{what}"
        );
    };
    refused(chats::append(db, me, talk, &hello).map(drop), "a message");
    refused(
        chats::add_swipe(db, me, second, "Hi", true).map(drop),
        "another version",
    );
    refused(chats::set_head(db, me, talk, first), "going back");
    refused(chats::show_branch(db, me, talk, first), "another branch");
    refused(chats::set_content(db, me, second, "Bye"), "an edit");
    let ines = personas::create(db, me, "Ines", "").unwrap();
    refused(chats::set_persona(db, me, talk, Some(ines)), "a persona");
    refused(
        chats::set_lore(
            db,
            me,
            talk,
            LoreSource::CardId(mira),
            "lorebook.coast",
            false,
        )
        .map(drop),
        "a lorebook switched off",
    );
    // It is what it was, and is read as before.
    assert_eq!(chats::path(db, me, talk).unwrap(), before);
    let kept = chats::get(db, me, talk).unwrap().unwrap();
    assert_eq!((kept.head_id, kept.persona_id), (Some(second), None));
    assert!(chats::lorebooks(db, me, talk).unwrap()[0].on);

    // Restored, it goes on.
    chats::set_trashed(db, me, talk, false).unwrap();
    chats::set_content(db, me, second, "Bye").unwrap();
    chats::add_swipe(db, me, second, "Hi", true).unwrap();
    chats::set_head(db, me, talk, first).unwrap();
    chats::append(db, me, talk, &hello).unwrap();
    chats::set_persona(db, me, talk, Some(ines)).unwrap();
    chats::set_lore(
        db,
        me,
        talk,
        LoreSource::CardId(mira),
        "lorebook.coast",
        false,
    )
    .unwrap();
}

#[test]
fn a_chat_neither_leaves_the_trash_nor_starts_while_its_card_is_there() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let [with_card, alone] = [chat(&scratch, &[version]), chat(&scratch, &[version])];
    chats::set_trashed(db, me, alone, true).unwrap();
    cards::set_trashed(db, me, mira, true).unwrap();

    for talk in [with_card, alone] {
        let error = chats::set_trashed(db, me, talk, false).unwrap_err();
        assert_eq!(
            format!("{error:#}"),
            "its card “Mira” is in the Trash; restore the card first"
        );
        assert!(chat_trashed(&scratch, talk));
    }
    let new = NewChat {
        characters: &[(version, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let error = chats::create(db, me, &new).unwrap_err();
    assert_eq!(
        format!("{error:#}"),
        "the card is in the Trash; restore it to chat with it"
    );
    assert_eq!(count(db, "chats"), 2);

    cards::set_trashed(db, me, mira, false).unwrap();
    chats::set_trashed(db, me, alone, false).unwrap();
    assert!(!chat_trashed(&scratch, alone));
    chats::create(db, me, &new).unwrap();
    // What is not there is not there, for restoring too.
    assert!(chats::set_trashed(db, me, 999, false).is_err());
    assert!(cards::set_trashed(db, me, 999, false).is_err());
}

#[test]
fn a_chat_with_characters_of_two_cards_waits_for_both() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (ada, ada_version) = card(&scratch, "Ada");
    let (ben, ben_version) = card(&scratch, "Ben");
    let both = chat(&scratch, &[ada_version, ben_version]);

    cards::set_trashed(db, me, ada, true).unwrap();
    assert!(chat_trashed(&scratch, both));
    assert_eq!(listed(&scratch), [("card", ada, 1)]);
    cards::set_trashed(db, me, ben, true).unwrap();
    // Ada comes back; the chat stays for as long as Ben is there, and is his now.
    cards::set_trashed(db, me, ada, false).unwrap();
    assert!(chat_trashed(&scratch, both));
    assert_eq!(listed(&scratch), [("card", ben, 1)]);
    cards::set_trashed(db, me, ben, false).unwrap();
    assert!(!chat_trashed(&scratch, both));
    assert!(listed(&scratch).is_empty());

    // Deleting one of the cards for good takes the chat along.
    cards::set_trashed(db, me, ben, true).unwrap();
    trash::delete_card(db, me, ben).unwrap();
    assert!(chats::get(db, me, both).unwrap().is_none());
    assert!(!card_trashed(&scratch, ada));
}

#[test]
fn only_what_is_in_the_trash_is_deleted_for_good_and_all_of_it_goes() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let sam = cw_accounts::users::create(db, "sam").unwrap();
    let (mira, version) = card(&scratch, "Mira");
    let (keep, keep_version) = card(&scratch, "Keep");
    let [talk, archived, alone] = [
        chat(&scratch, &[version]),
        chat(&scratch, &[version]),
        chat(&scratch, &[version]),
    ];
    let kept_talk = chat(&scratch, &[keep_version]);
    chats::set_archived(db, me, archived, true).unwrap();
    chats::set_trashed(db, me, alone, true).unwrap();
    let (blobs, messages) = (count(db, "blobs"), count(db, "messages"));
    // Each card has its own asset; the picture is the same one, kept once.
    assert_eq!(blobs, 3);

    for (error, what) in [
        (trash::delete_card(db, me, mira), "card"),
        (trash::delete_chat(db, me, talk), "chat"),
    ] {
        let expected =
            format!("only a {what} in the Trash can be deleted for good; move it there first");
        assert_eq!(format!("{:#}", error.unwrap_err()), expected);
    }
    cards::set_trashed(db, me, mira, true).unwrap();
    // Nobody deletes what is another user's.
    assert!(trash::delete_card(db, sam, mira).is_err());
    assert!(trash::delete_chat(db, sam, alone).is_err());
    assert_eq!((count(db, "cards"), count(db, "chats")), (2, 4));

    // A chat goes with its messages, and nothing else does.
    trash::delete_chat(db, me, alone).unwrap();
    assert!(chats::get(db, me, alone).unwrap().is_none());
    assert_eq!(
        (
            count(db, "cards"),
            count(db, "chats"),
            count(db, "messages")
        ),
        (2, 3, messages / 4 * 3)
    );

    // A card goes with its versions, its files and all its chats, archived ones too.
    trash::delete_card(db, me, mira).unwrap();
    assert!(cards::get(db, me, mira).unwrap().is_none());
    for table in [
        "cards",
        "card_versions",
        "card_index",
        "chats",
        "chat_characters",
    ] {
        assert_eq!(count(db, table), 1, "{table}");
    }
    assert_eq!(count(db, "messages"), messages / 4);
    // The picture is still the other card's; the asset was this card's alone.
    assert_eq!(count(db, "blobs"), blobs - 1);
    assert_eq!(
        cards::image(db, me, keep_version).unwrap().unwrap(),
        common::picture()
    );
    assert!(!card_trashed(&scratch, keep) && !chat_trashed(&scratch, kept_talk));
    assert!(chats::path(db, me, kept_talk).is_ok());
    assert!(listed(&scratch).is_empty());

    assert!(trash::delete_card(db, me, mira).is_err());
    cards::set_trashed(db, me, keep, true).unwrap();
    trash::delete_card(db, me, keep).unwrap();
    assert_eq!(
        (
            count(db, "blobs"),
            count(db, "card_files"),
            count(db, "messages")
        ),
        (0, 0, 0)
    );
}

#[test]
fn the_trash_empties_itself_of_what_has_been_there_for_thirty_days() {
    assert_eq!(DAYS, 30);
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let now = 1_800_000_000_000;
    let due = now - 30 * DAY - 1;
    let not_yet = now - 30 * DAY;

    let (old, old_version) = card(&scratch, "Old");
    let (recent, recent_version) = card(&scratch, "Recent");
    let (live, live_version) = card(&scratch, "Live");
    let old_talk = chat(&scratch, &[old_version]);
    let recent_talk = chat(&scratch, &[recent_version]);
    let [old_alone, recent_alone, live_talk] = [
        chat(&scratch, &[live_version]),
        chat(&scratch, &[live_version]),
        chat(&scratch, &[live_version]),
    ];
    for (card, at) in [(old, due), (recent, not_yet)] {
        cards::set_trashed(db, me, card, true).unwrap();
        trashed_at(db, "cards", card, at);
    }
    for (chat, at) in [(old_alone, due), (recent_alone, not_yet)] {
        chats::set_trashed(db, me, chat, true).unwrap();
        trashed_at(db, "chats", chat, at);
    }
    // Another user's Trash is emptied by the same clock.
    let sam = cw_accounts::users::create(db, "sam").unwrap();
    let sams = cards::import(db, sam, &card_file("Sam's", true))
        .unwrap()
        .card_id;
    cards::set_trashed(db, sam, sams, true).unwrap();
    trashed_at(db, "cards", sams, due);

    // A card, its chat and a chat deleted by itself: the card's chat is not counted on its own.
    assert_eq!(trash::purge(db, now).unwrap(), 3);
    assert!(
        cards::get(db, me, old).unwrap().is_none() && cards::get(db, sam, sams).unwrap().is_none()
    );
    assert!(
        chats::get(db, me, old_talk).unwrap().is_none()
            && chats::get(db, me, old_alone).unwrap().is_none()
    );
    assert!(
        card_trashed(&scratch, recent)
            && chat_trashed(&scratch, recent_talk)
            && chat_trashed(&scratch, recent_alone)
    );
    assert!(!card_trashed(&scratch, live) && !chat_trashed(&scratch, live_talk));
    assert_eq!(trash::purge(db, now).unwrap(), 0);
    // A moment later the rest is due.
    assert_eq!(trash::purge(db, now + 1).unwrap(), 2);
    assert!(listed(&scratch).is_empty());
    assert_eq!((count(db, "cards"), count(db, "chats")), (1, 1));
}

#[test]
fn emptying_the_trash_takes_all_of_one_users_and_nothing_else() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (gone, gone_version) = card(&scratch, "Gone");
    let (live, live_version) = card(&scratch, "Live");
    chat(&scratch, &[gone_version]);
    let [alone, live_talk] = [
        chat(&scratch, &[live_version]),
        chat(&scratch, &[live_version]),
    ];
    cards::set_trashed(db, me, gone, true).unwrap();
    chats::set_trashed(db, me, alone, true).unwrap();
    let sam = cw_accounts::users::create(db, "sam").unwrap();
    let sams = cards::import(db, sam, &card_file("Sam's", true))
        .unwrap()
        .card_id;
    cards::set_trashed(db, sam, sams, true).unwrap();
    // The picture all three cards share, and an asset each.
    assert_eq!(count(db, "blobs"), 4);

    assert_eq!(trash::empty(db, me).unwrap(), 2);
    // The files only the card that went used go with it.
    assert_eq!(count(db, "blobs"), 3);
    assert!(listed(&scratch).is_empty());
    assert!(!card_trashed(&scratch, live) && !chat_trashed(&scratch, live_talk));
    assert_eq!((count(db, "cards"), count(db, "chats")), (2, 1));
    assert_eq!(trash::list(db, sam).unwrap().len(), 1);
}

async fn add(server: &Server, title: &str) -> (i64, i64) {
    server.add_card(card_file(title, true), false).await
}

async fn chat_with(server: &Server, version: i64) -> i64 {
    server.chat_with(&[(version, "mira")], 0).await["chat"]["id"]
        .as_i64()
        .unwrap()
}

async fn delete(server: &Server, path: &str) -> (u16, Value) {
    server.call(reqwest::Method::DELETE, path, None).await
}

#[tokio::test]
async fn the_trash_is_listed_restored_from_and_emptied_over_http() {
    let server = start().await;
    let (mira, version) = add(&server, "Mira").await;
    let (cove, cove_version) = add(&server, "Cove").await;
    let talk = chat_with(&server, version).await;
    let alone = chat_with(&server, cove_version).await;
    let (_, empty) = server.get("/api/trash").await;
    assert_eq!(empty, json!({ "days": 30, "items": [] }));

    server
        .patch(&format!("/api/chats/{alone}"), json!({ "trashed": true }))
        .await;
    tokio::time::sleep(std::time::Duration::from_millis(5)).await;
    let (status, card) = server
        .patch(&format!("/api/cards/{mira}"), json!({ "trashed": true }))
        .await;
    assert_eq!((status, &card["trashed"]), (200, &json!(true)));
    let (status, list) = server.get("/api/trash").await;
    assert_eq!(status, 200);
    let items = list["items"].as_array().unwrap();
    // The item deleted last comes first.
    assert_eq!(items.len(), 2, "{list}");
    assert_eq!(items[0]["kind"], "card");
    assert_eq!(
        (
            &items[0]["id"],
            &items[0]["title"],
            &items[0]["version_id"],
            &items[0]["chats"]
        ),
        (&json!(mira), &json!("Mira"), &json!(version), &json!(1))
    );
    assert_eq!(
        items[1],
        json!({ "kind": "chat", "id": alone, "title": "Mira (storm night)", "trashed_at": items[1]["trashed_at"], "cards": ["Cove"] })
    );
    assert!(items[0]["trashed_at"].as_i64().unwrap() > items[1]["trashed_at"].as_i64().unwrap());
    // The card's chat is in the Trash with it: not among the chats to go on with.
    let (_, chat) = server.get(&format!("/api/chats/{talk}")).await;
    assert_eq!(chat["chat"]["trashed"], true);
    // A chat in the Trash tells when it is deleted for good.
    let (_, kept) = server.get(&format!("/api/chats/{alone}")).await;
    let day = 24 * 60 * 60 * 1000;
    let due = items[1]["trashed_at"].as_i64().unwrap() + i64::from(DAYS) * day;
    assert_eq!(kept["chat"]["deleted_at"], due);

    // It takes no message there.
    let (status, error) = server
        .post(
            &format!("/api/chats/{talk}/messages"),
            json!({ "content": "Hello" }),
        )
        .await;
    assert_eq!(
        (status, error["error"].as_str().unwrap()),
        (400, "the chat is in the Trash; restore it first")
    );

    // A chat does not come back before its card, and none starts with a card in the Trash.
    let (status, error) = server
        .patch(&format!("/api/chats/{talk}"), json!({ "trashed": false }))
        .await;
    assert_eq!(
        (status, error["error"].as_str().unwrap()),
        (
            400,
            "its card “Mira” is in the Trash; restore the card first"
        )
    );
    let (status, _) = server
        .post(
            "/api/chats",
            json!({ "characters": [{ "version_id": version, "character": "mira" }] }),
        )
        .await;
    assert_eq!(status, 400);
    let (status, _) = server
        .patch(&format!("/api/cards/{mira}"), json!({ "trashed": false }))
        .await;
    assert_eq!(status, 200);
    let (_, chat) = server.get(&format!("/api/chats/{talk}")).await;
    assert_eq!(chat["chat"]["trashed"], false);

    // Deleting for good: only from the Trash, and then it is gone.
    for path in [format!("/api/cards/{cove}"), format!("/api/chats/{talk}")] {
        let (status, error) = delete(&server, &path).await;
        assert_eq!(status, 400, "{path}");
        assert!(
            error["error"].as_str().unwrap().contains("in the Trash"),
            "{error}"
        );
    }
    assert_eq!(delete(&server, &format!("/api/chats/{alone}")).await.0, 204);
    assert_eq!(delete(&server, &format!("/api/chats/{alone}")).await.0, 404);
    assert_eq!(server.get(&format!("/api/chats/{alone}")).await.0, 404);
    server
        .patch(&format!("/api/cards/{mira}"), json!({ "trashed": true }))
        .await;
    assert_eq!(delete(&server, &format!("/api/cards/{mira}")).await.0, 204);
    assert_eq!(server.get(&format!("/api/cards/{mira}")).await.0, 404);
    assert_eq!(server.get(&format!("/api/chats/{talk}")).await.0, 404);
    assert_eq!(delete(&server, "/api/cards/999").await.0, 404);

    // Emptying takes what is left in it, and only that.
    server
        .patch(&format!("/api/cards/{cove}"), json!({ "trashed": true }))
        .await;
    let (keep, _) = add(&server, "Keep").await;
    assert_eq!(delete(&server, "/api/trash").await.0, 204);
    let (_, list) = server.get("/api/trash").await;
    assert_eq!(list["items"], json!([]));
    assert_eq!(server.get(&format!("/api/cards/{cove}")).await.0, 404);
    assert_eq!(server.get(&format!("/api/cards/{keep}")).await.0, 200);
}

#[tokio::test]
async fn what_is_due_goes_when_the_server_starts() {
    let server = start().await;
    let (old, old_version) = add(&server, "Old").await;
    let (recent, _) = add(&server, "Recent").await;
    let talk = chat_with(&server, old_version).await;
    for card in [old, recent] {
        server
            .patch(&format!("/api/cards/{card}"), json!({ "trashed": true }))
            .await;
    }
    {
        let options = server.options();
        let db = Db::open(
            &options.data_dir.join(FILE_NAME),
            options.key.given().unwrap(),
        )
        .unwrap();
        let month_ago = chrono::Utc::now().timestamp_millis() - 30 * DAY - 60_000;
        trashed_at(&db, "cards", old, month_ago);
        trashed_at(&db, "cards", recent, month_ago + 2 * 60_000);
    }
    let server = server.restart().await;
    let (_, list) = server.get("/api/trash").await;
    let ids: Vec<i64> = list["items"]
        .as_array()
        .unwrap()
        .iter()
        .map(|item| item["id"].as_i64().unwrap())
        .collect();
    assert_eq!(ids, [recent]);
    assert_eq!(server.get(&format!("/api/cards/{old}")).await.0, 404);
    assert_eq!(server.get(&format!("/api/chats/{talk}")).await.0, 404);
}

#[tokio::test]
async fn the_server_starts_though_the_trash_cannot_be_emptied() {
    let server = start().await;
    let (old, _) = add(&server, "Old").await;
    server
        .patch(&format!("/api/cards/{old}"), json!({ "trashed": true }))
        .await;
    {
        let options = server.options();
        let db = Db::open(
            &options.data_dir.join(FILE_NAME),
            options.key.given().unwrap(),
        )
        .unwrap();
        trashed_at(
            &db,
            "cards",
            old,
            chrono::Utc::now().timestamp_millis() - 31 * DAY,
        );
        db.with(|conn| {
            conn.execute_batch("create trigger kept before delete on cards begin select raise(abort, 'kept'); end;")
        })
        .unwrap();
        assert!(trash::purge(&db, chrono::Utc::now().timestamp_millis()).is_err());
    }
    // What could not be deleted is still there, and so is the server.
    let server = server.restart().await;
    assert_eq!(server.get(&format!("/api/cards/{old}")).await.0, 200);
    let (status, list) = server.get("/api/trash").await;
    assert_eq!((status, list["items"].as_array().unwrap().len()), (200, 1));
}

/// The cards a chat in the Trash is with are named in the order its characters
/// joined, as the list of chats names them, whatever the speaking order.
#[test]
fn a_chat_in_the_trash_names_its_cards_in_the_order_its_characters_joined() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (_, mira) = card(&scratch, "Mira");
    let (_, sol) = card(&scratch, "Sol");
    let talk = chat(&scratch, &[mira, sol]);
    let cast = chats::participants(db, me, talk).unwrap();
    turn::reorder(db, me, cast[1].id, 0).unwrap();
    chats::set_trashed(db, me, talk, true).unwrap();
    let named = trash::list(db, me)
        .unwrap()
        .into_iter()
        .find_map(|item| match item {
            TrashItem::Chat { cards, .. } => Some(cards),
            _ => None,
        })
        .unwrap();
    assert_eq!(named, ["Mira", "Sol"]);
}

#[tokio::test]
async fn every_page_of_the_user_is_told_of_a_change_of_the_trash() {
    let server = start().await;
    let (mira, version) = add(&server, "Mira").await;
    let alone = chat_with(&server, version).await;
    let mut socket = server.listen().await;
    let (card, trash) = (
        json!({ "type": "card", "id": mira }),
        json!({ "type": "trash" }),
    );

    // A chat in and out, which tells of the chat too, and a card in, which tells of the card too; a star alone
    // tells no Trash.
    let chat = format!("/api/chats/{alone}");
    let told_chat = json!({ "type": "chat", "id": alone });
    for trashed in [true, false] {
        assert_eq!(
            server.patch(&chat, json!({ "trashed": trashed })).await.0,
            200
        );
        assert_eq!(event(&mut socket).await, told_chat);
        assert_eq!(event(&mut socket).await, trash);
    }
    assert_eq!(
        server.patch(&chat, json!({ "favorite": true })).await.0,
        200
    );
    assert_eq!(event(&mut socket).await, told_chat);
    let path = format!("/api/cards/{mira}");
    assert_eq!(server.patch(&path, json!({ "trashed": true })).await.0, 200);
    assert_eq!(event(&mut socket).await, card);
    assert_eq!(event(&mut socket).await, trash);

    // Deleted for good, and the Trash emptied.
    assert_eq!(delete(&server, &path).await.0, 204);
    assert_eq!(event(&mut socket).await, card);
    assert_eq!(event(&mut socket).await, trash);
    assert_eq!(delete(&server, "/api/trash").await.0, 204);
    assert_eq!(event(&mut socket).await, trash);
}

/// A chat whose reply is being written does not go to the Trash: the reply would go on into it, and at its
/// end the worker model would read and name a chat the user has thrown away.
#[test]
fn a_chat_does_not_go_to_the_trash_while_a_reply_is_written() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let (mira, version) = card(&scratch, "Mira");
    let talk = chat(&scratch, &[version]);
    let writing = NewMessage {
        role: Role::Assistant,
        speaker_id: None,
        content: "",
        complete: false,
    };
    chats::append(db, me, talk, &writing).unwrap();
    let refused = trash::put_chat(db, me, talk).expect_err("the chat went to the Trash");
    assert_eq!(
        format!("{refused:#}"),
        "a reply is being generated in this chat; stop it first"
    );
    assert!(!chat_trashed(&scratch, talk));
    // Nor does its card, which takes the chat along.
    cards::set_trashed(db, me, mira, true).expect_err("the card went to the Trash");
    assert!(!card_trashed(&scratch, mira) && !chat_trashed(&scratch, talk));
}

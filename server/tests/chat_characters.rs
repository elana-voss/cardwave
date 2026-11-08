//! A chat that starts with several characters, a character that joins a chat
//! that is there, and one that leaves it again; "New chat with these
//! characters", Rename, a reply told to write only as its character and cut
//! where it goes on in another's lines, and
//! the pause and count of the characters' replying by themselves.
//!
//! Through `card_with` the sample card is here as `later` (Mira called
//! Mirabel), `of_three` (with a third character, `odd`); `harbour`
//! is a lorebook of the library with two entries.

mod common;

use common::Scratch;
use common::server::start;
use cw_accounts::users;
use cw_ccv4::png;
use cw_chat::chats::{self, ChatSort, Find, LoreSource, NewChat, NewMessage};
use cw_core::NotFound;
use cw_library::cards::{self, Show};
use cw_library::lorebooks;
use cw_prompt::Role;
use cw_store::Db;
use reqwest::Method;
use serde_json::{Value, json};

const IN_TRASH: &str = "the chat is in the Trash; restore it first";

/// The sample card with other files: its blocks and its cards as `change` makes them.
fn card_with(change: impl Fn(&str, &str) -> (String, String)) -> Vec<u8> {
    let mut container = common::container();
    let (blocks, cards) = change(common::BLOCKS, common::CARDS);
    assert!(blocks != common::BLOCKS || cards != common::CARDS);
    container.toml[0].1 = blocks;
    container.toml[1].1 = cards;
    png::write(&container).unwrap()
}

/// The sample card with Mira called Mirabel.
fn later() -> Vec<u8> {
    card_with(|blocks, cards| {
        (
            blocks.replace(
                "[name.mira]\ntext = \"Mira\"",
                "[name.mira]\ntext = \"Mirabel\"",
            ),
            cards.to_string(),
        )
    })
}

/// The sample card with a third character, `odd`.
fn of_three() -> Vec<u8> {
    card_with(|blocks, cards| {
        (
            blocks.to_string(),
            format!("{cards}\n[character.odd]\nprompt = [\"CHAT-HISTORY\"]\n"),
        )
    })
}

fn begin(db: &Db, user: i64, characters: &[(i64, &str)]) -> i64 {
    chats::create(
        db,
        user,
        &NewChat {
            characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap()
}

/// A chat's characters in speaking order: each as its ID in its card and the version it is with.
fn cast(db: &Db, user: i64, chat: i64) -> Vec<(String, i64)> {
    chats::participants(db, user, chat)
        .unwrap()
        .into_iter()
        .map(|one| (one.character, one.version_id))
        .collect()
}

/// The chat character that is `character` of a card version.
fn who(db: &Db, user: i64, chat: i64, character: &str, version: i64) -> i64 {
    chats::participants(db, user, chat)
        .unwrap()
        .into_iter()
        .find(|one| one.character == character && one.version_id == version)
        .unwrap()
        .id
}

/// Why a change was refused.
fn refused<T>(change: anyhow::Result<T>) -> String {
    format!("{:#}", change.err().expect("the change was taken"))
}

/// A message of the chat character `speaker`, complete or still being written.
fn says(speaker: i64, complete: bool) -> NewMessage<'static> {
    NewMessage {
        role: Role::Assistant,
        speaker_id: Some(speaker),
        content: "Hm.",
        complete,
    }
}

/// A lorebook of the library with the entries `tide` and `fog`.
fn harbour(db: &Db, user: i64) -> i64 {
    let entry = |name: &str| json!({ "key": [name], "comment": name, "content": format!("About the {name}.") });
    let file = json!({ "entries": { "0": entry("tide"), "1": entry("fog") } });
    lorebooks::import(db, user, file.to_string().as_bytes(), "harbour.json")
        .unwrap()
        .lorebook
        .id
}

/// The chat's lorebooks: each as where it is from and whether it is on, with what the chat left out of it.
fn books(db: &Db, user: i64, chat: i64) -> Vec<(LoreSource, bool, Vec<String>)> {
    chats::lorebooks(db, user, chat)
        .unwrap()
        .into_iter()
        .map(|book| {
            let removed = book.removed.into_iter().map(|lore| lore.reference);
            (book.source, book.on, removed.collect())
        })
        .collect()
}

#[test]
fn a_character_of_a_card_of_the_library_joins_a_chat_that_is_there() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &later()).unwrap();
    let attached = harbour(db, me);
    lorebooks::attach(db, me, other.card_id, attached).unwrap();
    let chat = begin(db, me, &[(card.version_id, "mira")]);
    let before = chats::get(db, me, chat).unwrap().unwrap();
    let greeting = chats::path(db, me, chat).unwrap();
    assert_eq!(greeting.len(), 1);
    let listed = |card_id| {
        chats::of_card(db, me, card_id)
            .unwrap()
            .iter()
            .map(|chat| chat.id)
            .collect::<Vec<_>>()
    };
    assert_eq!(listed(other.card_id), [] as [i64; 0]);

    let joined = chats::add_character(db, me, chat, other.card_id, "mira").unwrap();

    // The last in speaking order, with the card's newest version.
    assert_eq!(
        cast(db, me, chat),
        [
            ("mira".to_string(), card.version_id),
            ("mira".to_string(), other.version_id)
        ]
    );
    assert_eq!(joined, who(db, me, chat, "mira", other.version_id));
    // It writes no greeting, and the chat is as it was: its title, its head, when it was written in.
    assert_eq!(chats::path(db, me, chat).unwrap(), greeting);
    assert_eq!(chats::get(db, me, chat).unwrap().unwrap(), before);
    // The list of chats has the name the card's version gives it, and its card's page the chat.
    let found = chats::find(
        db,
        me,
        &Find {
            query: "",
            show: Show::default(),
            sort: ChatSort::default(),
        },
    )
    .unwrap();
    assert_eq!(found[0].names, ["Mira", "Mirabel"]);
    assert_eq!(
        found[0]
            .cards
            .iter()
            .map(|card| card.id)
            .collect::<Vec<_>>(),
        [card.card_id, other.card_id]
    );
    assert_eq!(listed(other.card_id), [chat]);
    // The chat has the lorebook its card brings and the one attached to its card.
    assert_eq!(
        books(db, me, chat),
        [
            (LoreSource::CardId(card.card_id), true, vec![]),
            (LoreSource::CardId(other.card_id), true, vec![]),
            (LoreSource::LorebookId(attached), true, vec![]),
        ]
    );

    // Asked to, it replies: as itself, to a chat in which the other's words are under her name.
    let inputs = chats::prompt_inputs(db, me, chat, Some(joined)).unwrap();
    assert_eq!(
        (inputs.character.name.as_str(), inputs.card_id),
        ("Mirabel", Some(other.card_id))
    );
    assert_eq!(
        inputs.state.messages[0].content,
        format!("Mira: {}", greeting[0].content)
    );
    let reply = chats::append(db, me, chat, &says(joined, true)).unwrap();
    assert_eq!(
        chats::view(db, me, reply).unwrap().message.speaker_id,
        Some(joined)
    );
    // And the first character goes on as before, with the newcomer's words under its name.
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    assert_eq!(inputs.character.name, "Mira");
    assert_eq!(inputs.state.messages[1].content, "Mirabel: Hm.");

    // The chat goes to the Trash with the newcomer's card, as with any of its cards, and comes back with it.
    let trashed = || chats::get(db, me, chat).unwrap().unwrap().trashed;
    cards::set_trashed(db, me, other.card_id, true).unwrap();
    assert!(trashed());
    cards::set_trashed(db, me, other.card_id, false).unwrap();
    assert!(!trashed());
}

#[test]
fn a_character_joins_with_its_cards_version() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &of_three()).unwrap();
    let v1 = card.version_id;

    let stranger = common::import_whole(db, me, &common::card_file()).unwrap();
    let fresh = begin(db, me, &[(stranger.version_id, "mira")]);
    chats::add_character(db, me, fresh, card.card_id, "odd").unwrap();
    assert_eq!(cast(db, me, fresh)[1], ("odd".to_string(), v1));

    let chat = begin(db, me, &[(v1, "mira")]);
    chats::add_character(db, me, chat, card.card_id, "bare").unwrap();
    assert_eq!(
        cast(db, me, chat),
        [("mira".to_string(), v1), ("bare".to_string(), v1)]
    );
}

#[test]
fn a_chat_starts_with_several_characters_each_once() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    // Two of one card and one of another, in the order given; the chat is called after the first.
    let chat = begin(
        db,
        me,
        &[
            (other.version_id, "mira"),
            (card.version_id, "bare"),
            (card.version_id, "mira"),
        ],
    );
    let started = cast(db, me, chat);
    assert_eq!(
        started,
        [
            ("mira".to_string(), other.version_id),
            ("bare".to_string(), card.version_id),
            ("mira".to_string(), card.version_id),
        ]
    );
    assert_eq!(
        chats::get(db, me, chat).unwrap().unwrap().title,
        "Mira (storm night)"
    );

    // A character twice starts no chat.
    let new = NewChat {
        characters: &[(card.version_id, "mira"), (card.version_id, "mira")],
        persona_id: None,
        greeting: 0,
    };
    assert_eq!(
        refused(chats::create(db, me, &new)),
        "Mira is in this chat twice"
    );
    let all = Find {
        query: "",
        show: Show::default(),
        sort: ChatSort::default(),
    };
    assert_eq!(chats::find(db, me, &all).unwrap().len(), 1);
}

#[test]
fn a_chat_takes_no_character_it_has_or_cannot_have() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    let chat = begin(db, me, &[(card.version_id, "mira")]);
    let same = cast(db, me, chat);

    // One it has.
    assert_eq!(
        refused(chats::add_character(db, me, chat, card.card_id, "mira")),
        "Mira is in this chat already"
    );
    // One its card has not.
    assert_eq!(
        refused(chats::add_character(db, me, chat, other.card_id, "ghost")),
        "the card has no character \"ghost\""
    );
    // A card that is not there, or is another user's, and a chat that is.
    let sam = users::create(db, "sam").unwrap();
    let sams = common::import_whole(db, sam, &common::card_file()).unwrap();
    let sams_chat = begin(db, sam, &[(sams.version_id, "mira")]);
    for (chat, card, what) in [
        (chat, 99, "card"),
        (chat, sams.card_id, "card"),
        (99, other.card_id, "chat"),
        (sams_chat, other.card_id, "chat"),
    ] {
        let error = chats::add_character(db, me, chat, card, "mira").unwrap_err();
        assert_eq!(error.downcast_ref::<NotFound>().unwrap().0, what);
    }
    assert_eq!(cast(db, sam, sams_chat).len(), 1);
    // A card in the Trash: the chat would be there with it.
    cards::set_trashed(db, me, other.card_id, true).unwrap();
    assert_eq!(
        refused(chats::add_character(db, me, chat, other.card_id, "mira")),
        "the card is in the Trash; restore it to chat with it"
    );
    cards::set_trashed(db, me, other.card_id, false).unwrap();
    // A chat in the Trash, which is only read.
    chats::set_trashed(db, me, chat, true).unwrap();
    assert_eq!(
        refused(chats::add_character(db, me, chat, other.card_id, "mira")),
        IN_TRASH
    );
    chats::set_trashed(db, me, chat, false).unwrap();
    assert_eq!(cast(db, me, chat), same);

    // An archived chat takes a character of an archived card, and a chat in which a reply is being written does.
    cards::set_archived(db, me, other.card_id, true).unwrap();
    chats::set_archived(db, me, chat, true).unwrap();
    let mira = who(db, me, chat, "mira", card.version_id);
    chats::append(db, me, chat, &says(mira, false)).unwrap();
    chats::add_character(db, me, chat, other.card_id, "mira").unwrap();
    assert_eq!(cast(db, me, chat).len(), 2);
}

#[test]
fn a_character_that_has_written_nothing_leaves_a_chat_again() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    let (attached, taken) = (harbour(db, me), harbour(db, me));
    lorebooks::attach(db, me, other.card_id, attached).unwrap();
    lorebooks::attach(db, me, other.card_id, taken).unwrap();
    // A chat before it, so that the chat's number is not that of the lorebook it loses.
    begin(db, me, &[(card.version_id, "mira")]);
    let chat = begin(db, me, &[(card.version_id, "mira")]);
    assert_ne!(chat, attached);
    chats::add_lorebook(db, me, chat, taken).unwrap();
    let join = |character: &str| chats::add_character(db, me, chat, other.card_id, character);
    let (mira, bare) = (join("mira").unwrap(), join("bare").unwrap());

    // What the chat leaves out: of the first card's lorebook, of the other's, and of the library's two.
    let (own, theirs) = (
        LoreSource::CardId(card.card_id),
        LoreSource::CardId(other.card_id),
    );
    let (through, along) = (
        LoreSource::LorebookId(attached),
        LoreSource::LorebookId(taken),
    );
    let entry = |book: i64| {
        chats::lorebooks(db, me, chat)
            .unwrap()
            .into_iter()
            .find(|one| one.source == LoreSource::LorebookId(book))
            .unwrap()
            .entries
            .remove(0)
    };
    let (first, second) = (entry(attached), entry(taken));
    let off = |source, reference: &str| {
        chats::set_lore(db, me, chat, source, reference, false).unwrap();
    };
    off(own, "lore.wreck");
    off(theirs, "lore.lamp");
    off(theirs, "lorebook.coast");
    off(through, &first);
    off(along, &second);
    let all = vec![
        (own, true, vec!["lore.wreck".to_string()]),
        (theirs, false, vec!["lore.lamp".to_string()]),
        (through, true, vec![first.clone()]),
        (along, true, vec![second.clone()]),
    ];
    assert_eq!(books(db, me, chat), all);

    // One of the card's two leaves: the chat is with the card still, and leaves out what it did.
    assert_eq!(chats::remove_character(db, me, bare).unwrap(), chat);
    assert_eq!(
        cast(db, me, chat),
        [
            ("mira".to_string(), card.version_id),
            ("mira".to_string(), other.version_id)
        ]
    );
    assert_eq!(books(db, me, chat), all);

    // The card's last leaves: its lorebooks go, but for the one the chat took along itself.
    chats::remove_character(db, me, mira).unwrap();
    assert_eq!(cast(db, me, chat), [("mira".to_string(), card.version_id)]);
    let kept = vec![all[0].clone(), all[3].clone()];
    assert_eq!(books(db, me, chat), kept);
    assert_eq!(chats::of_card(db, me, other.card_id).unwrap(), []);

    // Back again, it is the last in speaking order, and what the chat had left out of what went is forgotten.
    let (bare, mira) = (join("bare").unwrap(), join("mira").unwrap());
    assert_eq!(
        chats::participants(db, me, chat)
            .unwrap()
            .iter()
            .map(|one| one.id)
            .collect::<Vec<_>>()[1..],
        [bare, mira]
    );
    assert_eq!(
        books(db, me, chat),
        [
            all[0].clone(),
            (theirs, true, vec![]),
            (through, true, vec![]),
            all[3].clone()
        ]
    );
}

#[test]
fn a_character_that_has_written_stays_and_a_chat_keeps_one_character() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &later()).unwrap();
    let chat = begin(db, me, &[(card.version_id, "mira")]);
    let first = who(db, me, chat, "mira", card.version_id);
    let greeting = chats::get(db, me, chat).unwrap().unwrap().head_id.unwrap();
    let joined = chats::add_character(db, me, chat, other.card_id, "mira").unwrap();
    let wrote = |id| chats::written(db, chat).unwrap().contains(&id);
    assert_eq!((wrote(first), wrote(joined)), (true, false));
    let stays = "Mirabel has written in this chat and stays in it";

    // The one who wrote the greeting stays.
    assert_eq!(
        refused(chats::remove_character(db, me, first)),
        "Mira has written in this chat and stays in it"
    );
    // A reply that is being written counts, and one that ended without a word does not.
    let half = chats::append(db, me, chat, &says(joined, false)).unwrap();
    assert!(wrote(joined));
    assert_eq!(refused(chats::remove_character(db, me, joined)), stays);
    assert!(
        chats::finish_reply(db, me, half, "", Some(greeting))
            .unwrap()
            .is_none()
    );
    assert!(!wrote(joined));
    // A message on a branch that is not in view counts.
    chats::append(db, me, chat, &says(joined, true)).unwrap();
    chats::set_head(db, me, chat, greeting).unwrap();
    assert_eq!(chats::path(db, me, chat).unwrap().len(), 1);
    assert!(wrote(joined));
    assert_eq!(refused(chats::remove_character(db, me, joined)), stays);
    assert_eq!(cast(db, me, chat).len(), 2);

    // Not another user's, not one that is not there, and none of a chat in the Trash.
    let silent = chats::add_character(db, me, chat, card.card_id, "bare").unwrap();
    let sam = users::create(db, "sam").unwrap();
    for (user, id) in [(sam, silent), (me, 99)] {
        let error = chats::remove_character(db, user, id).unwrap_err();
        assert_eq!(
            error.downcast_ref::<NotFound>().unwrap().0,
            "chat character"
        );
    }
    chats::set_trashed(db, me, chat, true).unwrap();
    assert_eq!(refused(chats::remove_character(db, me, silent)), IN_TRASH);
    chats::set_trashed(db, me, chat, false).unwrap();
    assert_eq!(cast(db, me, chat).len(), 3);
    chats::remove_character(db, me, silent).unwrap();

    // A chat whose one character has written nothing keeps it.
    let quiet = begin(db, me, &[(card.version_id, "bare")]);
    assert_eq!(chats::path(db, me, quiet).unwrap(), []);
    let bare = who(db, me, quiet, "bare", card.version_id);
    assert_eq!(
        refused(chats::remove_character(db, me, bare)),
        "a chat needs a character"
    );
    // With a second one, either leaves.
    chats::add_character(db, me, quiet, other.card_id, "mira").unwrap();
    chats::remove_character(db, me, bare).unwrap();
    assert_eq!(
        cast(db, me, quiet),
        [("mira".to_string(), other.version_id)]
    );
}

#[tokio::test]
async fn characters_join_and_leave_a_chat_over_http() {
    let server = start().await;
    let (_, card) = server.upload_whole(common::card_file()).await;
    let (_, other) = server.upload_whole(later()).await;
    let id = |card: &Value| card["card_id"].as_i64().unwrap();
    let start =
        json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, chat) = server.post("/api/chats", start).await;
    let chat_id = chat["chat"]["id"].as_i64().unwrap();
    assert_eq!(chat["characters"][0]["written"], true);
    let characters = format!("/api/chats/{chat_id}/characters");
    let add = |card_id: i64, character: &str| json!({ "card_id": card_id, "character": character });

    // Joining answers with the chat, of which the newcomer is the last character.
    let (status, joined) = server.post(&characters, add(id(&other), "mira")).await;
    assert_eq!(status, 201, "{joined}");
    let cast = joined["characters"].as_array().unwrap();
    assert_eq!(cast.len(), 2);
    let newcomer = &cast[1];
    assert_eq!(
        (
            &newcomer["name"],
            &newcomer["card_id"],
            &newcomer["position"],
            &newcomer["written"]
        ),
        (
            &json!("Mirabel"),
            &other["card_id"],
            &json!(1),
            &json!(false)
        )
    );
    assert_eq!(joined["messages"], chat["messages"]);
    assert_eq!(joined["lorebooks"].as_array().unwrap().len(), 2);
    let (_, read) = server.get(&format!("/api/chats/{chat_id}")).await;
    assert_eq!(read, joined);

    // What is refused says why, and what is not there is not found.
    let (status, why) = server.post(&characters, add(id(&other), "mira")).await;
    assert_eq!(
        (status, why["error"].as_str().unwrap()),
        (400, "Mirabel is in this chat already")
    );
    let (status, _) = server.post(&characters, add(99, "mira")).await;
    assert_eq!(status, 404);
    let (status, _) = server
        .post("/api/chats/99/characters", add(id(&other), "bare"))
        .await;
    assert_eq!(status, 404);

    // Leaving answers with the chat as well.
    let place = format!("/api/chat-characters/{}", newcomer["id"]);
    let (status, left) = server.call(Method::DELETE, &place, None).await;
    assert_eq!(status, 200, "{left}");
    assert_eq!(left, chat);
    let (status, _) = server.call(Method::DELETE, &place, None).await;
    assert_eq!(status, 404);

    // One that has written is told so, and stays.
    let (_, joined) = server.post(&characters, add(id(&other), "mira")).await;
    let newcomer = &joined["characters"][1];
    let says = json!({ "content": "Hm.", "role": "assistant", "speaker_id": newcomer["id"] });
    let (status, _) = server
        .post(&format!("/api/chats/{chat_id}/messages"), says)
        .await;
    assert_eq!(status, 201);
    let (_, read) = server.get(&format!("/api/chats/{chat_id}")).await;
    assert_eq!(read["characters"][1]["written"], true);
    let place = format!("/api/chat-characters/{}", newcomer["id"]);
    let (status, why) = server.call(Method::DELETE, &place, None).await;
    assert_eq!(
        (status, why["error"].as_str().unwrap()),
        (400, "Mirabel has written in this chat and stays in it")
    );
    let (_, read) = server.get(&format!("/api/chats/{chat_id}")).await;
    assert_eq!(read["characters"].as_array().unwrap().len(), 2);
}

/// A chat of Mira and Mirabel over HTTP, with the chat provider at `provider` where it is given. Answers its address.
async fn of_two(server: &common::server::Server, provider: Option<&str>) -> String {
    if let Some(url) = provider {
        let provider = json!({ "base_url": url, "model": "test-model", "api_key": "sk-test" });
        assert_eq!(server.put("/api/provider", provider).await.0, 200);
    }
    let (_, card) = server.upload_whole(common::card_file()).await;
    let (_, other) = server.upload_whole(later()).await;
    let character = |card: &Value| json!({ "version_id": card["version_id"], "character": "mira" });
    let new = json!({ "characters": [character(&card), character(&other)] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    format!("/api/chats/{}", view["chat"]["id"])
}

#[tokio::test]
async fn a_new_chat_with_these_characters_has_their_order_and_the_chats_settings() {
    let server = start().await;
    let chat = of_two(&server, None).await;
    let (_, view) = server.get(&chat).await;
    let mirabel = view["characters"][1]["id"].clone();
    // Mirabel speaks first, the chat takes turns in order and replies at length.
    let place = format!("/api/chat-characters/{mirabel}/position");
    assert_eq!(server.put(&place, json!({ "position": 0 })).await.0, 200);
    assert_eq!(
        server
            .put(&format!("{chat}/turn"), json!({ "order": "list" }))
            .await
            .0,
        200
    );
    assert_eq!(
        server
            .put(
                &format!("{chat}/reply"),
                json!({ "reply_length": 800, "code_mode": true })
            )
            .await
            .0,
        200
    );
    let talk = json!({ "talk_pause": 0, "talk_replies": 3 });
    assert_eq!(server.put(&format!("{chat}/talk"), talk).await.0, 200);

    let (status, made) = server.post(&format!("{chat}/again"), json!({})).await;
    assert_eq!(status, 201, "{made}");
    assert_ne!(made["chat"]["id"], view["chat"]["id"]);
    let names = |view: &Value| {
        let mut cast: Vec<(i64, String)> = view["characters"]
            .as_array()
            .unwrap()
            .iter()
            .map(|one| {
                (
                    one["position"].as_i64().unwrap(),
                    one["name"].as_str().unwrap().to_string(),
                )
            })
            .collect();
        cast.sort();
        cast.into_iter().map(|(_, name)| name).collect::<Vec<_>>()
    };
    assert_eq!(names(&made), ["Mirabel", "Mira"]);
    let settings = |view: &Value| {
        let chat = &view["chat"];
        (
            chat["turn_order"].clone(),
            chat["reply_length"].clone(),
            chat["code_mode"].clone(),
            (chat["talk_pause"].clone(), chat["talk_replies"].clone()),
        )
    };
    assert_eq!(
        settings(&made),
        (json!("list"), json!(800), json!(true), (json!(0), json!(3)))
    );
    // Each greets: the first as a chat begins, the other after it.
    let messages = made["messages"].as_array().unwrap();
    assert_eq!(messages.len(), 2, "{messages:?}");
    let speakers: Vec<_> = messages
        .iter()
        .map(|message| message["speaker_id"].clone())
        .collect();
    let ids: Vec<_> = [0, 1]
        .iter()
        .map(|at| made["characters"][at]["id"].clone())
        .collect();
    assert!(speakers.iter().all(|speaker| ids.contains(speaker)) && speakers[0] != speakers[1]);

    // A chat in the Trash is only read.
    assert_eq!(server.patch(&chat, json!({ "trashed": true })).await.0, 200);
    let (status, why) = server.post(&format!("{chat}/again"), json!({})).await;
    assert_eq!((status, why["error"].as_str().unwrap()), (400, IN_TRASH));
}

/// A chat's characters wait 4 s between their own replies and write 10 in a
/// row until the side panel sets other numbers, within their bounds.
#[tokio::test]
async fn a_chat_sets_the_pause_and_count_of_its_characters_own_replies() {
    let server = start().await;
    let chat = of_two(&server, None).await;
    let (_, view) = server.get(&chat).await;
    let numbers = |chat: &Value| (chat["talk_pause"].clone(), chat["talk_replies"].clone());
    assert_eq!(numbers(&view["chat"]), (json!(4), json!(10)));

    let talk = format!("{chat}/talk");
    let (status, changed) = server
        .put(&talk, json!({ "talk_pause": 30, "talk_replies": 25 }))
        .await;
    assert_eq!(status, 200, "{changed}");
    assert_eq!(numbers(&changed), (json!(30), json!(25)));
    for (pause, replies) in [(601, 10), (4, 0), (4, 101)] {
        let wrong = json!({ "talk_pause": pause, "talk_replies": replies });
        assert_eq!(server.put(&talk, wrong).await.0, 400);
    }
    let (_, view) = server.get(&chat).await;
    assert_eq!(numbers(&view["chat"]), (json!(30), json!(25)));
}

#[tokio::test]
async fn a_chat_is_renamed_with_a_title_neither_empty_nor_too_long() {
    let server = start().await;
    let chat = of_two(&server, None).await;
    let title = format!("{chat}/title");
    let (status, renamed) = server
        .put(&title, json!({ "title": "  The skerry  " }))
        .await;
    assert_eq!(status, 200, "{renamed}");
    assert_eq!(renamed["title"], "The skerry");
    assert_eq!(server.get(&chat).await.1["chat"]["title"], "The skerry");
    for wrong in [" ".to_string(), "a".repeat(101)] {
        let (status, why) = server.put(&title, json!({ "title": wrong })).await;
        assert_eq!(status, 400, "{why}");
    }
}

#[tokio::test]
async fn a_reply_that_goes_on_in_another_characters_lines_is_cut_to_its_own() {
    let server = start().await;
    let piece = |text: &str| {
        format!(
            "data: {}\n\n",
            json!({ "choices": [{ "delta": { "content": text } }] })
        )
    };
    let body = [
        piece("It is late.\n\n*Mira"),
        piece("bel shrugs.*\nMi"),
        piece("rabel: No, it is not.\nMira: Is too."),
        "data: [DONE]\n\n".to_string(),
    ]
    .concat();
    let api = common::api::Api::start(common::api::says(200, "text/event-stream", &body)).await;
    let chat = of_two(&server, Some(&api.url)).await;
    let (_, view) = server.get(&chat).await;
    let mira = view["characters"][0]["id"].clone();
    assert_eq!(
        server
            .put(&format!("{chat}/turn"), json!({ "replier_id": mira }))
            .await
            .0,
        200
    );
    assert_eq!(
        server
            .post(&format!("{chat}/messages"), json!({ "content": "Well?" }))
            .await
            .0,
        201
    );

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let mut newest = Value::Null;
    for _ in 0..250 {
        let (_, view) = server.get(&chat).await;
        newest = view["messages"].as_array().unwrap().last().unwrap().clone();
        if newest["role"] == "assistant" && newest["complete"] == true {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    // A name in the narration is no line of another; the line "Mirabel:" is, and the reply ends before it.
    assert_eq!(
        newest["content"], "It is late.\n\n*Mirabel shrugs.*",
        "{newest}"
    );
}

#[test]
fn a_greeting_after_the_first_in_a_new_chat_keeps_what_its_macros_set() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let mira = common::import_whole(db, me, &common::card_file()).unwrap();
    let setting = card_with(|blocks, cards| {
        let blocks = blocks.replace(
            "[name.mira]\ntext = \"Mira\"",
            "[name.mira]\ntext = \"Mirabel\"",
        );
        (
            blocks.replace(
                "All of you, inside.",
                "{{setvar::mood::wry}}All of you, inside.",
            ),
            cards.to_string(),
        )
    });
    let mirabel = common::import_whole(db, me, &setting).unwrap();
    let chat = begin(
        db,
        me,
        &[(mira.version_id, "mira"), (mirabel.version_id, "mira")],
    );

    let made = chats::again::again(db, me, chat).unwrap();
    let states: Vec<(String, Option<String>)> = db
        .with(|conn| {
            let mut query =
                conn.prepare("select content, state from messages where chat_id = ?1 order by id")?;
            query
                .query_map([made], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect()
        })
        .unwrap();
    assert_eq!(states.len(), 2, "{states:?}");
    assert_eq!(states[1].0, "All of you, inside.");
    let kept: Value = serde_json::from_str(states[1].1.as_deref().expect("no state kept")).unwrap();
    assert_eq!(kept["opening"]["mood"], "wry");
}

#[tokio::test]
async fn a_reply_in_a_chat_of_several_is_told_to_write_only_as_its_character() {
    let server = start().await;
    let reply = "data: {\"choices\":[{\"delta\":{\"content\":\"Yes.\"}}]}\n\ndata: [DONE]\n\n";
    let api = common::api::Api::start(common::api::says(200, "text/event-stream", reply)).await;
    let chat = of_two(&server, Some(&api.url)).await;
    let said = json!({ "content": "Bram, you're here too?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    for _ in 0..250 {
        if !api.asked().is_empty() {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    let body: Value = serde_json::from_str(&api.asked()[0].body).unwrap();
    let last = body["messages"].as_array().unwrap().last().unwrap().clone();
    assert!(
        last["content"]
            .as_str()
            .unwrap()
            .contains("[Write the next reply only as Mira"),
        "{last}"
    );
}

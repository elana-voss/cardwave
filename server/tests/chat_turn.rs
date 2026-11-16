//! Who replies next in a stored chat of several characters: the character
//! picked by hand, the speaking order the user changes, and a reply that names
//! nobody; no character is muted, one muted before neither. The turn orders
//! alone: `chat_turn_order.rs`.
//!
//! `card` is a card of three, Ada, Bo and Cy, each as talkative as told and the
//! third called as told; `speaking` a chat's characters in speaking order with
//! their places. The tests over HTTP have `common::api::Api` write the replies
//! and wait for a reply's end by reading the chat (`reply`).

mod common;

use std::time::Duration;

use common::Scratch;
use common::api::{Api, says};
use common::server::{Server, WAIT, start};
use cw_accounts::users;
use cw_ccv4::png::{self, Container};
use cw_chat::chats::turn::{self, Turn};
use cw_chat::chats::{self, ChatSort, Find, NewChat, NewMessage, TurnOrder};
use cw_core::NotFound;
use cw_library::cards::Show;
use cw_library::trash;
use cw_prompt::Role;
use cw_store::Db;
use serde_json::{Value, json};
use tokio::time::{sleep, timeout};

/// A card of three, Ada, who greets, Bo and Cy, who is called as `cy` says.
/// Each is as talkative as `talk` says, a value as TOML writes it; an empty
/// one says nothing.
fn card(cy: &str, talk: [&str; 3]) -> Vec<u8> {
    let character = |id: &str, name: &str, talk: &str, greets: bool| {
        let talk = match talk {
            "" => String::new(),
            value => format!("group-talkativeness = {value}\n"),
        };
        let greetings = if greets { r#""greeting.ada""# } else { "" };
        format!(
            "[name.{id}]\ntext = \"{name}\"\n\n[character.{id}]\nname-char = \"name.{id}\"\n\
             greetings = [{greetings}]\n{talk}prompt = [\"CHAT-HISTORY\"]\n\n"
        )
    };
    let toml = format!(
        "spec = \"ccv4:1.0.0\"\n\n[meta-info]\ntitle = \"The Skerry Crew\"\n\n\
         [greeting.ada]\ntext = \"Ada looks up.\"\n\n{}{}{}",
        character("ada", "Ada", talk[0], true),
        character("bo", "Bo", talk[1], false),
        character("cy", cy, talk[2], false),
    );
    png::write(&Container {
        image: common::picture(),
        toml: vec![("card/0001_card.toml".to_string(), toml)],
        assets: Vec::new(),
    })
    .unwrap()
}

fn begin(db: &Db, user: i64, characters: &[(i64, &str)]) -> i64 {
    let new = NewChat {
        characters,
        persona_id: None,
        greeting: 0,
    };
    chats::create(db, user, &new).unwrap()
}

/// Adds a complete message to the chat: the user's, or the chat character `by`'s.
fn write(db: &Db, user: i64, chat: i64, by: Option<i64>, content: &str) -> i64 {
    let new = NewMessage {
        role: if by.is_some() {
            Role::Assistant
        } else {
            Role::User
        },
        speaker_id: by,
        content,
        complete: true,
    };
    chats::append(db, user, chat, &new).unwrap()
}

/// Who replies next in the chat at this chance.
fn next(db: &Db, user: i64, chat: i64, chance: f64) -> Option<i64> {
    let chat = chats::get(db, user, chat).unwrap().unwrap();
    turn::next(db, user, &chat, chance).unwrap()
}

/// The chat's turn as it is stored: its order, and who is picked by hand.
fn stored(db: &Db, user: i64, chat: i64) -> (TurnOrder, Option<i64>) {
    let chat = chats::get(db, user, chat).unwrap().unwrap();
    (chat.turn_order, chat.replier_id)
}

/// Why a change was refused.
fn refused<T>(change: anyhow::Result<T>) -> String {
    format!("{:#}", change.err().expect("the change was taken"))
}

#[test]
fn a_chat_picks_among_its_characters_as_the_versions_it_is_with_tell_them() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // Ada's talkativeness is beyond the most there is, Bo's a number with a point, Cy's none at all.
    let made = common::import_whole(db, me, &card("Cy Vane", ["3", "0.9", "nan"])).unwrap();
    let chat = begin(
        db,
        me,
        &[
            (made.version_id, "ada"),
            (made.version_id, "bo"),
            (made.version_id, "cy"),
        ],
    );
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];

    // A chat starts with the natural order and nobody picked by hand.
    assert_eq!(stored(db, me, chat), (TurnOrder::Natural, None));
    // Ada greeted, and her greeting names herself alone: chance picks between Bo, as talkative as his card
    // says (0.9), and Cy, as talkative as a card that says nothing (0.5).
    assert_eq!(next(db, me, chat, 0.64), Some(bo));
    assert_eq!(next(db, me, chat, 0.65), Some(cy));
    // After Bo it is between Ada, who is as talkative as can be (1) and no more, and Cy.
    let asked = write(db, me, chat, None, "Well?");
    write(db, me, chat, Some(bo), "Hm.");
    assert_eq!(next(db, me, chat, 0.66), Some(ada));
    assert_eq!(next(db, me, chat, 0.67), Some(cy));

    // A character is named by the name its card gives it now. A word of that name will do.
    write(db, me, chat, None, "Cyrus, your watch.");
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    // The page edits a card's first character alone: Cy's card is given another name as a card from before is.
    let renamed = card("Cyrus Vane", ["3", "0.9", "nan"]);
    common::plant_whole(db, made.version_id, &renamed);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));

    // Who spoke last is asked of the branch in view: where Bo's answer is not on it, Ada was the last.
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    assert_eq!(next(db, me, chat, 0.99), Some(cy));
    chats::set_head(db, me, chat, asked).unwrap();
    assert_eq!(next(db, me, chat, 0.99), Some(bo));
}

#[test]
fn one_picked_by_hand_replies_in_the_orders_place_until_it_leaves() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [
        (made.version_id, "ada"),
        (made.version_id, "bo"),
        (made.version_id, "cy"),
    ];
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.99), Some(bo));

    // The one picked replies whatever the order says, and the order stays the chat's.
    turn::set(db, me, chat, Turn::ReplierId(cy)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, Some(cy)));
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    write(db, me, chat, None, "Ada?");
    assert_eq!(next(db, me, chat, 0.99), Some(cy));
    // Another picked takes its place, and an order takes the pick away.
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    turn::set(db, me, chat, Turn::Order(TurnOrder::Random)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::Random, None));
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // When the one picked leaves the chat, its order picks again.
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    turn::set(db, me, chat, Turn::ReplierId(cy)).unwrap();
    chats::remove_character(db, me, cy).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // Refused, with nothing changed: a character of another chat, one that is none, a chat in the
    // Trash, and a chat that is another user's or not there.
    let other = begin(db, me, &all[..2]);
    let foreign = chats::participants(db, me, other).unwrap()[0].id;
    for nobody in [foreign, 999] {
        let why = refused(turn::set(db, me, chat, Turn::ReplierId(nobody)));
        assert_eq!(why, "the speaker is not part of this chat");
    }
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    let stranger = users::create(db, "sam").unwrap();
    for (who, which) in [(stranger, chat), (me, 999)] {
        for turn in [Turn::Order(TurnOrder::Random), Turn::ReplierId(ada)] {
            let failure = turn::set(db, who, which, turn).unwrap_err();
            assert!(failure.is::<NotFound>(), "{failure:#}");
        }
    }
    chats::set_trashed(db, me, chat, true).unwrap();
    for turn in [Turn::Order(TurnOrder::Random), Turn::ReplierId(ada)] {
        let why = refused(turn::set(db, me, chat, turn));
        assert_eq!(why, "the chat is in the Trash; restore it first");
    }
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    // A chat with one picked by hand is deleted for good as any other.
    turn::set(db, me, other, Turn::ReplierId(foreign)).unwrap();
    chats::set_trashed(db, me, other, true).unwrap();
    trash::delete_chat(db, me, other).unwrap();
    assert!(chats::get(db, me, other).unwrap().is_none());

    // A chat of one has that one reply under every order.
    let alone = begin(db, me, &all[..1]);
    let only = chats::participants(db, me, alone).unwrap()[0].id;
    for order in [TurnOrder::Natural, TurnOrder::List, TurnOrder::Random] {
        turn::set(db, me, alone, Turn::Order(order)).unwrap();
        assert_eq!(next(db, me, alone, 0.5), Some(only));
    }
}

#[test]
fn a_character_muted_before_takes_its_turn() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [(made.version_id, "ada"), (made.version_id, "bo")];
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo] = [cast[0].id, cast[1].id];
    // Muted when there was muting (the column is read by nothing now).
    db.with(|conn| conn.execute("update chat_characters set muted = 1", []))
        .unwrap();
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
}

/// The chat's characters in speaking order, each with its place.
fn speaking(db: &Db, user: i64, chat: i64) -> Vec<(i64, i64)> {
    let cast = chats::participants(db, user, chat).unwrap();
    cast.iter().map(|one| (one.id, one.position)).collect()
}

#[test]
fn a_character_moved_in_the_speaking_order_speaks_in_its_new_place() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [
        (made.version_id, "ada"),
        (made.version_id, "bo"),
        (made.version_id, "cy"),
    ];
    let other = begin(db, me, &all);
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];
    let theirs = speaking(db, me, other);
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // Cy moved between Ada, who spoke last, and Bo is next from the next reply on.
    assert_eq!(turn::reorder(db, me, cy, 1).unwrap(), chat);
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    // To the first place; a place past the last is the last; a character's own place changes nothing.
    turn::reorder(db, me, bo, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(bo, 0), (ada, 1), (cy, 2)]);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    turn::reorder(db, me, bo, 99).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    turn::reorder(db, me, cy, 1).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    // Another chat of the same characters keeps its own order.
    assert_eq!(speaking(db, me, other), theirs);

    // Of two named alike, the first in speaking order replies.
    turn::set(db, me, chat, Turn::Order(TurnOrder::Natural)).unwrap();
    write(db, me, chat, None, "Bo and Ada, a word.");
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    turn::reorder(db, me, bo, 0).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));
    // Who is picked by hand stays as it was.
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    turn::reorder(db, me, cy, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(cy, 0), (bo, 1), (ada, 2)]);
    assert_eq!(stored(db, me, chat), (TurnOrder::Natural, Some(ada)));
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();

    // The chat is called after the one it began with: the list of chats and the export name them in the
    // order they joined.
    let find = Find {
        query: "",
        show: Show::default(),
        sort: ChatSort::default(),
    };
    let found = chats::find(db, me, &find).unwrap();
    let listed = found.iter().find(|one| one.chat.id == chat).unwrap();
    assert_eq!(listed.names, ["Ada", "Bo", "Cy Vane"]);
    let file = String::from_utf8(chats::export(db, me, chat).unwrap().data).unwrap();
    let head: Value = serde_json::from_str(file.lines().next().unwrap()).unwrap();
    assert_eq!(head["character_name"], "Ada");

    // One that joins after a move is the last; one that leaves leaves its place empty, which a move fills.
    let two = begin(db, me, &all[..2]);
    let pair = chats::participants(db, me, two).unwrap();
    let [first, second] = [pair[0].id, pair[1].id];
    turn::reorder(db, me, second, 0).unwrap();
    let third = chats::add_character(db, me, two, made.card_id, "cy").unwrap();
    assert_eq!(speaking(db, me, two), [(second, 0), (first, 1), (third, 2)]);
    chats::remove_character(db, me, second).unwrap();
    assert_eq!(speaking(db, me, two), [(first, 1), (third, 2)]);
    turn::reorder(db, me, third, 0).unwrap();
    assert_eq!(speaking(db, me, two), [(third, 0), (first, 1)]);
    // A character's message without a speaker, and a prompt for nobody named, are the one's the chat began with.
    let unnamed = NewMessage {
        role: Role::Assistant,
        speaker_id: None,
        content: "Hm.",
        complete: true,
    };
    let said = chats::append(db, me, two, &unnamed).unwrap();
    assert_eq!(
        chats::view(db, me, said).unwrap().message.speaker_id,
        Some(first)
    );
    assert_eq!(
        chats::prompt_inputs(db, me, two, None)
            .unwrap()
            .character
            .name,
        "Ada"
    );

    // A character is moved while a reply is being written, its own too.
    let reply = NewMessage {
        role: Role::Assistant,
        speaker_id: Some(ada),
        content: "",
        complete: false,
    };
    chats::append(db, me, chat, &reply).unwrap();
    turn::reorder(db, me, ada, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);

    // Refused, with nothing changed: one that is none or another user's, and one of a chat in the Trash.
    let stranger = users::create(db, "sam").unwrap();
    for (who, which) in [(stranger, bo), (me, 999)] {
        let failure = turn::reorder(db, who, which, 0).unwrap_err();
        assert!(failure.is::<NotFound>(), "{failure:#}");
    }
    // The reply ends first: a chat is not moved to the Trash while one is written in it.
    chats::finish_interrupted(db).unwrap();
    chats::set_trashed(db, me, chat, true).unwrap();
    let why = refused(turn::reorder(db, me, bo, 0));
    assert_eq!(why, "the chat is in the Trash; restore it first");
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
}

/// One piece of a streamed reply, as OpenAI's API sends it, and the reply's end.
const REPLY: &str = "data: {\"choices\":[{\"delta\":{\"content\":\"Hm.\"}}]}\n\ndata: [DONE]\n\n";

/// Asks for a reply in the chat, waits for its end and tells who wrote it.
async fn reply(server: &Server, chat: &str, how: Value) -> i64 {
    let (status, message) = server.post(&format!("{chat}/generate"), how).await;
    assert_eq!(status, 202, "{message}");
    let written = async {
        loop {
            let (_, view) = server.get(chat).await;
            let newest = view["messages"].as_array().unwrap().last().unwrap().clone();
            if newest["complete"] == true {
                break newest;
            }
            sleep(Duration::from_millis(20)).await;
        }
    };
    let newest = timeout(WAIT, written).await.expect("the reply did not end");
    assert_eq!(newest["content"], "Hm.");
    newest["speaker_id"].as_i64().unwrap()
}

#[tokio::test]
async fn a_reply_that_names_nobody_is_written_by_the_one_the_chats_turn_says() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", REPLY)).await;
    let provider =
        json!({ "base_url": api.url, "model": "test-model", "api_key": "sk-test", "sampling": {} });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, made) = server.upload_whole(card("Cy Vane", ["", "", ""])).await;
    let character = |id: &str| json!({ "version_id": made["version_id"], "character": id });
    let new = json!({ "characters": [character("ada"), character("bo")] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let turn = format!("{chat}/turn");
    let [ada, bo] = [0, 1].map(|at| view["characters"][at]["id"].as_i64().unwrap());
    // What the chat says of its turn: its order, and who is picked by hand.
    let told = |chat: &Value| (chat["turn_order"].clone(), chat["replier_id"].clone());
    assert_eq!(told(&view["chat"]), (json!("natural"), Value::Null));

    // The natural order: after Ada's greeting Bo replies, and Ada replies to him.
    let said = json!({ "content": "Well?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    assert_eq!(reply(&server, &chat, json!({})).await, ada);
    // Written again, a reply is its writer's, whoever the order would pick.
    assert_eq!(
        reply(&server, &chat, json!({ "regenerate": true })).await,
        ada
    );

    // An order set answers with the chat, and holds from the next reply on.
    let (status, set) = server.put(&turn, json!({ "order": "list" })).await;
    assert_eq!((status, told(&set)), (200, (json!("list"), Value::Null)));
    assert_eq!(set["id"], view["chat"]["id"]);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // One picked by hand replies every time,
    let (status, set) = server.put(&turn, json!({ "replier_id": bo })).await;
    assert_eq!((status, told(&set)), (200, (json!("list"), json!(bo))));
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // but for a reply that names its writer.
    assert_eq!(
        reply(&server, &chat, json!({ "speaker_id": ada })).await,
        ada
    );
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // The chat is read with its turn, and listed with it.
    let (_, read) = server.get(&chat).await;
    assert_eq!(told(&read["chat"]), (json!("list"), json!(bo)));
    let (_, listed) = server.get("/api/chats").await;
    assert_eq!(told(&listed[0]), (json!("list"), json!(bo)));
    let (status, set) = server.put(&turn, json!({ "order": "random" })).await;
    assert_eq!((status, told(&set)), (200, (json!("random"), Value::Null)));
    assert_eq!(reply(&server, &chat, json!({})).await, ada);

    // What is no turn is refused, and a chat that is not there is not found.
    let (status, why) = server.put(&turn, json!({ "replier_id": 999 })).await;
    assert_eq!(
        (status, &why["error"]),
        (400, &json!("the speaker is not part of this chat"))
    );
    for none in [
        json!({ "order": "sideways" }),
        json!({}),
        json!({ "order": "list", "replier_id": bo }),
    ] {
        let (status, _) = server.put(&turn, none.clone()).await;
        assert!([400, 422].contains(&status), "{none}: {status}");
    }
    let (status, _) = server
        .put("/api/chats/999/turn", json!({ "order": "list" }))
        .await;
    assert_eq!(status, 404);
    let (_, read) = server.get(&chat).await;
    assert_eq!(told(&read["chat"]), (json!("random"), Value::Null));
}

#[tokio::test]
async fn a_character_is_moved_in_the_speaking_order_over_http() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", REPLY)).await;
    let provider =
        json!({ "base_url": api.url, "model": "test-model", "api_key": "sk-test", "sampling": {} });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, made) = server.upload_whole(card("Cy Vane", ["", "", ""])).await;
    let character = |id: &str| json!({ "version_id": made["version_id"], "character": id });
    let new = json!({ "characters": [character("ada"), character("bo"), character("cy")] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let [ada, cy] = [0, 2].map(|at| view["characters"][at]["id"].as_i64().unwrap());
    let place = |one: i64, position: Value| {
        let server = &server;
        async move {
            let path = format!("/api/chat-characters/{one}/position");
            server.put(&path, json!({ "position": position })).await
        }
    };
    // The names of a view's characters, and their places.
    let order = |view: &Value| {
        let cast = view["characters"].as_array().unwrap();
        let named = |one: &Value| {
            (
                one["name"].as_str().unwrap().to_string(),
                one["position"].as_i64().unwrap(),
            )
        };
        cast.iter().map(named).collect::<Vec<_>>()
    };
    let at = |names: [&str; 3]| {
        (0..)
            .zip(names)
            .map(|(at, name)| (name.to_string(), at))
            .collect::<Vec<_>>()
    };
    let (_, set) = server
        .put(&format!("{chat}/turn"), json!({ "order": "list" }))
        .await;
    assert_eq!(set["turn_order"], "list");

    // Moving answers with the chat, its characters in their new order; in turn Cy, moved after Ada, is next.
    let (status, moved) = place(cy, json!(1)).await;
    assert_eq!(status, 200, "{moved}");
    assert_eq!(moved["chat"]["id"], view["chat"]["id"]);
    assert_eq!(order(&moved), at(["Ada", "Cy Vane", "Bo"]));
    assert_eq!(reply(&server, &chat, json!({})).await, cy);
    // The chat read anew has it so.
    let (_, read) = server.get(&chat).await;
    assert_eq!(order(&read), at(["Ada", "Cy Vane", "Bo"]));
    let (_, moved) = place(ada, json!(5)).await;
    assert_eq!(order(&moved), at(["Cy Vane", "Bo", "Ada"]));
    // The list of chats names them in the order they joined.
    let (_, list) = server.get("/api/chats").await;
    assert_eq!(list[0]["names"], json!(["Ada", "Bo", "Cy Vane"]));

    // A chat character that is not there is not found, and what is no place is refused.
    assert_eq!(place(999, json!(0)).await.0, 404);
    let path = format!("/api/chat-characters/{ada}/position");
    for none in [
        json!({}),
        json!({ "position": -1 }),
        json!({ "position": "first" }),
    ] {
        let (status, _) = server.put(&path, none.clone()).await;
        assert!([400, 422].contains(&status), "{none}: {status}");
    }
    let (_, read) = server.get(&chat).await;
    assert_eq!(order(&read), at(["Cy Vane", "Bo", "Ada"]));
}

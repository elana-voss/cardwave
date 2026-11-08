//! A chat written out as a file SillyTavern opens as a chat: what the file's
//! lines hold, which of a chat's messages are in it, and what it is called.
//!
//! `plant` runs a change on a running server's database (the messages' times, a
//! reply as still being written, a chat's title), and `file` reads a chat's
//! export as its headers, its text and its lines.

mod common;

use common::Scratch;
use common::server::{Server, start};
use cw_accounts::users;
use cw_chat::chats::{self, NewChat};
use cw_core::NotFound;
use cw_key::FILE_NAME;
use cw_store::Db;
use serde_json::{Value, json};

/// When the chats of these tests were started: 2025-10-09T08:53:20.123Z.
const STARTED: i64 = 1_760_000_000_123;

/// Uploads the sample card and returns the id of its version.
async fn add(server: &Server) -> i64 {
    server.add_card(common::card_file(), true).await.1
}

/// Starts a chat with characters of the sample card and returns its view.
async fn chat_with(server: &Server, characters: &[&str], greeting: usize) -> Value {
    let version = add(server).await;
    let characters: Vec<_> = characters.iter().map(|id| (version, *id)).collect();
    server.chat_with(&characters, greeting).await
}

/// Writes a message at the end of the chat's branch in view and returns its id.
async fn write(server: &Server, chat: i64, message: Value) -> i64 {
    let (status, written) = server
        .post(&format!("/api/chats/{chat}/messages"), message)
        .await;
    assert_eq!(status, 201, "{written}");
    written["id"].as_i64().unwrap()
}

/// What the user says next.
async fn say(server: &Server, chat: i64, content: &str) -> i64 {
    write(server, chat, json!({ "content": content })).await
}

/// What a character says next: the chat's first, or the chat character `speaker`.
async fn answer(server: &Server, chat: i64, speaker: Option<i64>, content: &str) -> i64 {
    write(
        server,
        chat,
        json!({ "content": content, "role": "assistant", "speaker_id": speaker }),
    )
    .await
}

/// Writes another version of a message, which comes into view, and returns its id.
async fn again(server: &Server, message: i64, content: &str) -> i64 {
    let (status, written) = server
        .post(
            &format!("/api/messages/{message}/swipes"),
            json!({ "content": content }),
        )
        .await;
    assert_eq!(status, 201, "{written}");
    written["id"].as_i64().unwrap()
}

/// Ends the view at a message, or with `follow` shows its branch down to where it was left.
async fn show(server: &Server, chat: i64, message: i64, follow: bool) {
    let to = json!({ "message_id": message, "follow": follow });
    assert_eq!(
        server.put(&format!("/api/chats/{chat}/head"), to).await.0,
        200
    );
}

/// Runs `change` on the database of a running server, through a connection of its own.
fn plant(server: &Server, change: impl FnOnce(&rusqlite::Connection) -> rusqlite::Result<usize>) {
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    db.with(|conn| change(conn)).unwrap();
}

/// The chat as its file: the answer's headers, the file as text, and its lines.
async fn file(server: &Server, chat: i64) -> (reqwest::header::HeaderMap, String, Vec<Value>) {
    let (headers, data) = server.download(&format!("/api/chats/{chat}/export")).await;
    let text = String::from_utf8(data).unwrap();
    let lines = text
        .split('\n')
        .map(|line| serde_json::from_str(line).expect(line))
        .collect();
    (headers, text, lines)
}

/// The lines of the chat's file.
async fn lines(server: &Server, chat: i64) -> Vec<Value> {
    file(server, chat).await.2
}

/// What the messages of a file say, in the file's order.
fn said(lines: &[Value]) -> Vec<&str> {
    lines[1..]
        .iter()
        .map(|line| line["mes"].as_str().unwrap())
        .collect()
}

/// The file name a download is given.
fn file_name(headers: &reqwest::header::HeaderMap) -> String {
    let disposition = headers["content-disposition"].to_str().unwrap();
    let encoded = disposition
        .strip_prefix("attachment; filename*=UTF-8''")
        .expect(disposition);
    percent_encoding::percent_decode_str(encoded)
        .decode_utf8()
        .unwrap()
        .to_string()
}

/// When a message planted as written `id` milliseconds after the chat's start was sent, as the file says it.
fn sent(id: i64) -> String {
    format!("2025-10-09T08:53:20.{}Z", 123 + id)
}

#[tokio::test]
async fn a_chat_is_written_as_the_file_sillytavern_keeps_a_chat_in() {
    let server = start().await;
    // The second greeting opens the chat; the first is its other version.
    let view = chat_with(&server, &["mira"], 1).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let greeting = &view["messages"][0];
    assert_eq!(greeting["content"], "Hold the lamp. Don't ask.");
    let (door, lamp) = (
        greeting["swipes"][0].as_i64().unwrap(),
        greeting["swipes"][1].as_i64().unwrap(),
    );
    let asked = say(&server, chat, "Why \"now\"?\nTell me.").await;
    let first = answer(&server, chat, None, "Because.").await;
    let second = again(&server, first, "Because of the tide.").await;
    let third = again(&server, first, "No reason.").await;
    // The second of the three is the one in view.
    show(&server, chat, second, false).await;
    plant(&server, |conn| {
        conn.execute("update messages set created_at = ?1 + id", [STARTED])
    });
    plant(&server, |conn| {
        conn.execute("update chats set created_at = ?1", [STARTED])
    });

    let (headers, text, lines) = file(&server, chat).await;
    assert_eq!(headers["content-type"], "application/jsonl");
    assert_eq!(
        file_name(&headers),
        "Mira (storm night) - 2025-10-09@08h53m20s.jsonl"
    );
    // One object on each line, and no line after the last.
    assert_eq!(text.matches('\n').count(), 3, "{text}");
    assert_eq!(lines.len(), 4);
    assert_eq!(
        lines[0],
        json!({ "chat_metadata": {}, "user_name": "User", "character_name": "Mira" })
    );
    // A character's message carries its versions, oldest first, and which one it is.
    let opening = "\"You picked a night for it, User.\"";
    assert_eq!(
        lines[1],
        json!({
            "name": "Mira",
            "is_user": false,
            "is_system": false,
            "send_date": sent(lamp),
            "mes": "Hold the lamp. Don't ask.",
            "extra": {},
            "swipe_id": 1,
            "swipes": [opening, "Hold the lamp. Don't ask."],
            "swipe_info": [{ "send_date": sent(door), "extra": {} }, { "send_date": sent(lamp), "extra": {} }],
        })
    );
    // The user's has none.
    assert_eq!(
        lines[2],
        json!({
            "name": "User",
            "is_user": true,
            "is_system": false,
            "send_date": sent(asked),
            "mes": "Why \"now\"?\nTell me.",
            "extra": {},
        })
    );
    assert_eq!(
        lines[3],
        json!({
            "name": "Mira",
            "is_user": false,
            "is_system": false,
            "send_date": sent(second),
            "mes": "Because of the tide.",
            "extra": {},
            "swipe_id": 1,
            "swipes": ["Because.", "Because of the tide.", "No reason."],
            "swipe_info": [
                { "send_date": sent(first), "extra": {} },
                { "send_date": sent(second), "extra": {} },
                { "send_date": sent(third), "extra": {} },
            ],
        })
    );

    // The user is called what the chat's persona is called now, in the messages written before too.
    let (status, vera) = server
        .post(
            "/api/personas",
            json!({ "name": "Vera", "description": "A pilot." }),
        )
        .await;
    assert_eq!(status, 201, "{vera}");
    assert_eq!(
        server
            .put(
                &format!("/api/chats/{chat}/persona"),
                json!({ "persona_id": vera["id"] })
            )
            .await
            .0,
        200
    );
    let (_, text, lines) = file(&server, chat).await;
    assert_eq!(
        (&lines[0]["user_name"], &lines[2]["name"], &lines[3]["name"]),
        (&json!("Vera"), &json!("Vera"), &json!("Mira"))
    );
    // What was written stays as it was written, and of the persona the name is all the file has.
    assert_eq!(lines[1]["swipes"][0], opening);
    assert!(!text.contains("A pilot."), "{text}");
}

#[tokio::test]
async fn the_file_holds_the_branch_in_view() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let greeting = view["messages"][0]["content"].as_str().unwrap();
    say(&server, chat, "First.").await;
    let one = answer(&server, chat, None, "One.").await;
    let second = say(&server, chat, "Second.").await;
    answer(&server, chat, None, "Two.").await;
    assert_eq!(
        said(&lines(&server, chat).await),
        [greeting, "First.", "One.", "Second.", "Two."]
    );

    // The talk goes another way after "One.": that way is the file now, and the other is in none.
    show(&server, chat, one, false).await;
    say(&server, chat, "Another way.").await;
    answer(&server, chat, None, "Three.").await;
    let (_, text, lines) = file(&server, chat).await;
    assert_eq!(
        said(&lines),
        [greeting, "First.", "One.", "Another way.", "Three."]
    );
    assert!(
        !text.contains("Second.") && !text.contains("Two."),
        "{text}"
    );
    // The user's message has no versions in the file, though another stands in its place.
    assert_eq!(lines[4].get("swipes"), None);

    // Back on the first way, as it was left.
    show(&server, chat, second, true).await;
    let (_, text, lines) = file(&server, chat).await;
    assert_eq!(
        said(&lines),
        [greeting, "First.", "One.", "Second.", "Two."]
    );
    assert!(
        !text.contains("Another way.") && !text.contains("Three."),
        "{text}"
    );

    // Another version of a message in the middle is in the file with the message, whichever is in view:
    // the first, with all that follows it, or the other, after which nothing was written.
    let other = again(&server, one, "One, again.").await;
    show(&server, chat, second, true).await;
    let lines = self::lines(&server, chat).await;
    assert_eq!(
        said(&lines),
        [greeting, "First.", "One.", "Second.", "Two."]
    );
    assert_eq!(
        (&lines[3]["swipes"], &lines[3]["swipe_id"]),
        (&json!(["One.", "One, again."]), &json!(0))
    );
    show(&server, chat, other, true).await;
    let lines = self::lines(&server, chat).await;
    assert_eq!(said(&lines), [greeting, "First.", "One, again."]);
    assert_eq!(
        (&lines[3]["swipes"], &lines[3]["swipe_id"]),
        (&json!(["One.", "One, again."]), &json!(1))
    );
}

#[tokio::test]
async fn a_chat_of_several_is_one_file_with_each_message_under_its_speakers_name() {
    let server = start().await;
    let view = chat_with(&server, &["mira", "bare"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let greeting = view["messages"][0]["id"].as_i64().unwrap();
    let (mira, bare) = (
        view["characters"][0]["id"].as_i64().unwrap(),
        view["characters"][1]["id"].as_i64().unwrap(),
    );
    // A character is called what the chat keeps as its name, whatever stands in it.
    plant(&server, |conn| {
        conn.execute(
            "update chat_characters set name = 'Odo \"the Quiet\"' where id = ?1",
            [bare],
        )
    });

    // Both answer the greeting, each on a way of its own, and the first of them twice.
    let quiet = answer(&server, chat, Some(bare), "Hm.").await;
    show(&server, chat, greeting, false).await;
    let loud = answer(&server, chat, Some(mira), "Speak up.").await;
    again(&server, loud, "Speak up, Odo.").await;

    let lines = self::lines(&server, chat).await;
    assert_eq!(
        lines[0],
        json!({ "chat_metadata": {}, "user_name": "User", "character_name": "Mira" })
    );
    assert_eq!(said(&lines), ["All of you, inside.", "Speak up, Odo."]);
    // What another character wrote in the same place is no version of the message.
    assert_eq!(
        (
            &lines[2]["name"],
            &lines[2]["swipes"],
            &lines[2]["swipe_id"]
        ),
        (
            &json!("Mira"),
            &json!(["Speak up.", "Speak up, Odo."]),
            &json!(1)
        )
    );
    show(&server, chat, quiet, true).await;
    let lines = self::lines(&server, chat).await;
    assert_eq!(said(&lines), ["All of you, inside.", "Hm."]);
    assert_eq!(
        (
            &lines[2]["name"],
            &lines[2]["swipes"],
            &lines[2]["swipe_id"]
        ),
        (&json!("Odo \"the Quiet\""), &json!(["Hm."]), &json!(0))
    );
    assert_eq!(lines[2]["is_user"], false);

    // A character the chat keeps no name for goes by its ID in its card.
    plant(&server, |conn| {
        conn.execute(
            "update chat_characters set name = null where id = ?1",
            [bare],
        )
    });
    assert_eq!(self::lines(&server, chat).await[2]["name"], "bare");
}

#[tokio::test]
async fn what_the_user_wrote_in_a_replys_place_is_no_version_of_the_reply() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let greeting = view["messages"][0]["id"].as_i64().unwrap();
    // After the greeting the user writes, and on another way the character goes on by itself, twice.
    say(&server, chat, "Go on.").await;
    show(&server, chat, greeting, false).await;
    let alone = answer(&server, chat, None, "And another thing.").await;
    again(&server, alone, "One more thing.").await;
    let reply = |lines: &[Value]| {
        (
            lines[2]["name"].clone(),
            lines[2]["swipes"].clone(),
            lines[2]["swipe_id"].clone(),
        )
    };
    let whole = (
        json!("Mira"),
        json!(["And another thing.", "One more thing."]),
        json!(1),
    );
    assert_eq!(reply(&lines(&server, chat).await), whole);

    // Nor is it once the messages say no longer who spoke, as those of a character whose place
    // in the chat is gone: they go under the first character's name, with their own versions.
    plant(&server, |conn| {
        conn.execute("update messages set speaker_id = null", [])
    });
    assert_eq!(reply(&lines(&server, chat).await), whole);
}

#[tokio::test]
async fn a_reply_that_is_still_being_written_is_not_in_the_file() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    say(&server, chat, "Well?").await;
    let whole = answer(&server, chat, None, "Whole.").await;
    again(&server, whole, "Whole again.").await;
    let half = again(&server, whole, "Half of a").await;
    let writing = |message: i64, complete: bool| {
        plant(&server, |conn| {
            conn.execute(
                "update messages set complete = ?2 where id = ?1",
                (message, complete),
            )
        });
    };

    // As another version of a reply: the newest that is whole stands in its place.
    writing(half, false);
    let (_, text, lines) = file(&server, chat).await;
    assert_eq!(lines.len(), 4);
    assert_eq!(
        (&lines[3]["mes"], &lines[3]["swipes"], &lines[3]["swipe_id"]),
        (
            &json!("Whole again."),
            &json!(["Whole.", "Whole again."]),
            &json!(1)
        )
    );
    assert_eq!(lines[3]["swipe_info"].as_array().unwrap().len(), 2);
    assert!(!text.contains("Half of a"), "{text}");
    // Once it has ended it is the message.
    writing(half, true);
    let lines = self::lines(&server, chat).await;
    assert_eq!(
        (&lines[3]["mes"], &lines[3]["swipes"], &lines[3]["swipe_id"]),
        (
            &json!("Half of a"),
            &json!(["Whole.", "Whole again.", "Half of a"]),
            &json!(2)
        )
    );

    // As the first reply to a message: the file ends before it.
    say(&server, chat, "And?").await;
    let unfinished = answer(&server, chat, None, "Unfinished").await;
    writing(unfinished, false);
    let (_, text, lines) = file(&server, chat).await;
    assert_eq!(said(&lines).last(), Some(&"And?"));
    assert!(!text.contains("Unfinished"), "{text}");
    writing(unfinished, true);
    assert_eq!(
        said(&self::lines(&server, chat).await).last(),
        Some(&"Unfinished")
    );
}

#[tokio::test]
async fn a_message_of_neither_is_the_narrators() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let night = write(
        &server,
        chat,
        json!({ "content": "Night falls.", "role": "system" }),
    )
    .await;
    plant(&server, |conn| {
        conn.execute("update messages set created_at = ?1 + id", [STARTED])
    });
    assert_eq!(
        lines(&server, chat).await[2],
        json!({
            "name": "System",
            "is_user": false,
            "is_system": false,
            "send_date": sent(night),
            "mes": "Night falls.",
            "extra": { "type": "narrator" },
        })
    );
}

#[tokio::test]
async fn a_chat_without_a_message_is_the_files_head_alone() {
    let server = start().await;
    // The sample card's second character has no greeting, and no name but its ID.
    let view = chat_with(&server, &["bare"], 0).await;
    assert_eq!(view["messages"], json!([]));
    let (_, text, lines) = file(&server, view["chat"]["id"].as_i64().unwrap()).await;
    assert_eq!(
        lines,
        [json!({ "chat_metadata": {}, "user_name": "User", "character_name": "bare" })]
    );
    assert!(!text.contains('\n'), "{text}");
}

#[tokio::test]
async fn an_archived_chat_and_one_in_the_trash_are_exported_and_a_missing_one_is_not() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    say(&server, chat, "Still here.").await;
    for flags in [json!({ "archived": true }), json!({ "trashed": true })] {
        assert_eq!(
            server.patch(&format!("/api/chats/{chat}"), flags).await.0,
            200
        );
        assert_eq!(
            said(&lines(&server, chat).await).last(),
            Some(&"Still here.")
        );
    }
    let (status, missing) = server.get("/api/chats/999/export").await;
    assert_eq!((status, &missing["error"]), (404, &json!("no such chat")));
}

#[test]
fn nobody_exports_another_users_chat() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let imported = common::import_whole(db, me, &common::card_file()).unwrap();
    let new = NewChat {
        characters: &[(imported.version_id, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    assert!(chats::export(db, me, chat).is_ok());
    let other = users::create(db, "olga").unwrap();
    assert!(chats::export(db, other, chat).is_err_and(|error| error.is::<NotFound>()));
}

#[tokio::test]
async fn the_file_is_named_after_the_chat_and_its_start() {
    let server = start().await;
    let view = chat_with(&server, &["mira"], 0).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    // The last second of a year, and half a second more: the day and the time are those of the start, to the second.
    plant(&server, |conn| {
        conn.execute("update chats set created_at = 1798761599500", [])
    });
    for (title, name) in [
        (
            "Who/What: \"Why\"? <*|>\\",
            "Who_What_ _Why__ _____ - 2026-12-31@23h59m59s.jsonl",
        ),
        ("Søren & 灯台.", "Søren & 灯台 - 2026-12-31@23h59m59s.jsonl"),
        // A chat without a character that has not named itself yet: no title, as a title of no letters.
        ("", "chat - 2026-12-31@23h59m59s.jsonl"),
        (" ... ", "chat - 2026-12-31@23h59m59s.jsonl"),
        (
            &"long ".repeat(40),
            &format!(
                "{} - 2026-12-31@23h59m59s.jsonl",
                "long ".repeat(16).trim_end()
            ),
        ),
    ] {
        plant(&server, |conn| {
            conn.execute("update chats set title = ?1", [title])
        });
        let (headers, _, _) = file(&server, chat).await;
        assert_eq!(file_name(&headers), name, "{title:?}");
    }
}

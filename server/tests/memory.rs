//! A chat's memory: each block of 20 messages read by the Worker model, the
//! memory note a later reply is given just before its newest message, a block
//! read again once its messages change, a helper that fails, a reply whose
//! documents do not read still given its note, and Knowledge ›
//! Memories, which Search Cardwave finds; a lorebook's entry used by meaning, which the search model tells;
//! and documents, added to a chat or a card, and the pieces of them a reply is
//! given. How the system itself reads and tells is `memory_port.rs`.
//!
//! `Fake` stands in for the provider: a reply is "Hello."; the memory's helper
//! (a question beginning `OPENING`) is answered as the test says, or fails
//! where it says so, and both are noted.

mod common;

use std::sync::{Arc, Mutex};

use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use common::embedder::Embedder;
use common::server::{Server, Socket, WAIT, event, start, start_searching};
use cw_chat::memory::hybrid::OPENING;
use cw_key::FILE_NAME;
use cw_store::Db;
use reqwest::Method;
use serde_json::{Value, json};
use tokio::net::TcpListener;
use tokio::time::{Instant, sleep, timeout};

/// A helper's answer that finds nothing.
const NOTHING: &str = "PRESENT:\nFACTS:\nEVENTS:";

#[derive(Default)]
struct Noted {
    /// The messages of each reply's question.
    replies: Vec<Value>,
    /// Each prompt the helper was asked.
    passes: Vec<String>,
    /// What the helper answers, and how many of its askings fail first.
    pass_says: String,
    failing: usize,
}

struct Fake {
    url: String,
    noted: Arc<Mutex<Noted>>,
}

impl Fake {
    async fn start() -> Self {
        let noted = Arc::new(Mutex::new(Noted {
            pass_says: NOTHING.into(),
            ..Default::default()
        }));
        let log = noted.clone();
        let answer = move |Json(body): Json<Value>| {
            let log = log.clone();
            async move {
                let messages = body["messages"].clone();
                let first = messages[0]["content"]
                    .as_str()
                    .unwrap_or_default()
                    .to_string();
                let text = {
                    let mut noted = log.lock().unwrap();
                    if !first.starts_with(OPENING) {
                        noted.replies.push(messages);
                        "Hello.".to_string()
                    } else if noted.failing > 0 {
                        noted.failing -= 1;
                        return (StatusCode::INTERNAL_SERVER_ERROR, "down").into_response();
                    } else {
                        noted.passes.push(first);
                        noted.pass_says.clone()
                    }
                };
                let piece = json!({ "choices": [{ "delta": { "content": text } }] });
                (
                    [("content-type", "text/event-stream")],
                    format!("data: {piece}\n\ndata: [DONE]\n\n"),
                )
                    .into_response()
            }
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(answer));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, noted }
    }

    fn noted(&self) -> std::sync::MutexGuard<'_, Noted> {
        self.noted.lock().unwrap()
    }

    /// What the helper answers from now on.
    fn finds(&self, reply: &str) {
        self.noted().pass_says = reply.into();
    }
}

async fn setup(server: &Server, fake: &Fake) {
    let provider = json!({ "base_url": fake.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
}

/// Starts a chat with Mira of the sample card. Answers its address.
async fn chat(server: &Server) -> String {
    let (_, card) = server.upload_whole(common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    format!("/api/chats/{}", view["chat"]["id"])
}

async fn say(server: &Server, chat: &str, text: &str) {
    let (status, sent) = server
        .post(&format!("{chat}/messages"), json!({ "content": text }))
        .await;
    assert_eq!(status, 201, "{sent}");
}

/// The user's messages "Message <n>." until the chat holds `n` on its branch.
async fn fill(server: &Server, chat: &str, n: usize) {
    let mut held = server.get(chat).await.1["messages"]
        .as_array()
        .unwrap()
        .len();
    while held < n {
        held += 1;
        say(server, chat, &format!("Message {held}.")).await;
    }
}

/// Has a reply written as `how` asks, and waits for its end. Answers the
/// reply's message ID and the question its prompt was.
async fn reply(
    server: &Server,
    fake: &Fake,
    socket: &mut Socket,
    chat: &str,
    how: Value,
) -> (i64, Value) {
    let asked = fake.noted().replies.len();
    let (status, message) = server.post(&format!("{chat}/generate"), how).await;
    assert_eq!(status, 202, "{message}");
    let id = message["id"].as_i64().unwrap();
    loop {
        let event = event(socket).await;
        if event["type"] == "reply_ended" && event["message_id"] == id {
            assert_eq!(event["error"], Value::Null);
            break;
        }
    }
    let prompt = fake.noted().replies[asked].clone();
    (id, prompt)
}

/// Waits for the event that says the chat's memories were changed.
async fn remembered(socket: &mut Socket) {
    loop {
        if event(socket).await["type"] == "memories" {
            return;
        }
    }
}

/// Waits until the helper has been asked `n` times.
async fn passes(fake: &Fake, n: usize) {
    let end = Instant::now() + WAIT;
    while fake.noted().passes.len() < n {
        assert!(Instant::now() < end, "the memory pass was not asked");
        sleep(std::time::Duration::from_millis(20)).await;
    }
}

/// The memory note of a reply's prompt, which stands just before its newest
/// message (after it only what stands at depth 0 and after the chat).
fn memory_of(prompt: &Value) -> Option<String> {
    let messages = prompt.as_array().unwrap();
    let at = messages.iter().position(|m| {
        m["content"]
            .as_str()
            .is_some_and(|text| text.starts_with("[Memory]\n"))
    })?;
    assert_eq!(messages[at]["role"], "system");
    let newest = messages[at + 1..]
        .iter()
        .filter(|m| m["role"] != "system")
        .count();
    assert_eq!(newest, 1, "{prompt}");
    Some(messages[at]["content"].as_str().unwrap()["[Memory]\n".len()..].to_string())
}

async fn memories(server: &Server) -> Vec<Value> {
    let (status, list) = server.get("/api/memories").await;
    assert_eq!(status, 200, "{list}");
    list.as_array().unwrap().clone()
}

/// The memories Search Cardwave finds by the words `query`: each its text and grey line.
async fn found(server: &Server, query: &str) -> Vec<(String, Value)> {
    let (status, hits) = server.get(&format!("/api/find?q={query}")).await;
    assert_eq!(status, 200, "{hits}");
    let hits = hits
        .as_array()
        .unwrap()
        .iter()
        .filter(|hit| hit["kind"] == "memory");
    hits.map(|hit| (hit["name"].as_str().unwrap().into(), hit["known"].clone()))
        .collect()
}

/// What the helper finds of the sister: a fact and an event, which Mira and the user know.
const SISTER: &str = "PRESENT: Mira, Guest\nFACTS:\nuser | sister | The user's sister is called Ana | personal | Mira, Guest | current\nEVENTS:\nThe user said Ana comes tonight | Ana visits | Mira waits | Mira, Guest | personal";

#[tokio::test]
async fn a_block_of_20_messages_is_read_by_the_worker_model_and_its_note_stands_before_the_newest_message()
 {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;

    fill(&server, &chat, 18).await;
    say(&server, &chat, "My sister Ana is coming tonight.").await;
    fake.finds(SISTER);
    let (first, _) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;

    // The pass read the 20 messages as a roleplay's.
    let asked = fake.noted().passes[0].clone();
    assert!(
        asked.starts_with("Read these new messages of a roleplay chat"),
        "{asked}"
    );
    assert!(
        asked.contains("[19] Guest: My sister Ana is coming tonight.\n[20] Mira: Hello."),
        "{asked}"
    );
    // What it saved shows on the reply whose end had it read.
    let (_, view) = server.get(&chat).await;
    let shown = view["messages"].as_array().unwrap().last().unwrap().clone();
    let saved = [
        "The user's sister is called Ana",
        "The user said Ana comes tonight (cause: Ana visits; result: Mira waits)",
    ];
    assert_eq!(
        (shown["id"].as_i64(), &shown["memories"]),
        (Some(first), &json!(saved))
    );
    // Knowledge › Memories lists them, the newest first.
    let listed = memories(&server).await;
    let fact = &listed[1];
    assert_eq!(
        (
            &fact["kind"],
            &fact["text"],
            &fact["status"],
            &fact["known_to"],
            &fact["names"],
            &fact["chat_id"]
        ),
        (
            &json!("fact"),
            &json!(saved[0]),
            &json!("current"),
            &json!(["mira", "guest"]),
            &json!(["Mira", "Guest"]),
            &view["chat"]["id"]
        )
    );
    assert_eq!(
        (&listed[0]["kind"], &listed[0]["text"]),
        (&json!("event"), &json!(saved[1]))
    );

    // A later reply is given the note just before its newest message; no
    // block is read until the next 20 messages are complete.
    fake.finds(NOTHING);
    say(&server, &chat, "Will you like her?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(
        memory_of(&prompt).as_deref(),
        Some(
            "Known:\n- The user's sister is called Ana\nEarlier:\n- The user said Ana comes tonight (cause: Ana visits; result: Mira waits)"
        )
    );
    assert!(!prompt[0]["content"].as_str().unwrap().contains("Ana"));
    sleep(std::time::Duration::from_millis(200)).await;
    assert_eq!(fake.noted().passes.len(), 1);
    // The next block's prompt shows what is open and the end of the block before.
    fill(&server, &chat, 39).await;
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    passes(&fake, 2).await;
    let asked = fake.noted().passes[1].clone();
    assert!(asked.contains("[21] Guest: Will you like her?"), "{asked}");
    assert!(!asked.contains("[19] Guest: My sister"), "{asked}");
}

#[tokio::test]
async fn a_block_whose_messages_change_is_read_again_and_its_memory_follows_the_branch() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    let fact = |town: &str| {
        format!(
            "PRESENT: Mira\nFACTS:\nmira | home | Mira lives in {town} | personal | Mira | current\nEVENTS:"
        )
    };
    fake.finds(&fact("Saltmere"));
    let (first, _) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let texts = async || -> Vec<Value> {
        memories(&server)
            .await
            .iter()
            .map(|m| m["text"].clone())
            .collect()
    };
    assert_eq!(texts().await, [json!("Mira lives in Saltmere")]);

    // Another version of the reply changes the block: it is read again.
    fake.finds(&fact("Varn"));
    let (again, _) = reply(
        &server,
        &fake,
        &mut socket,
        &chat,
        json!({ "regenerate": true }),
    )
    .await;
    assert_ne!(again, first);
    passes(&fake, 2).await;
    remembered(&mut socket).await;
    assert_eq!(texts().await, [json!("Mira lives in Varn")]);
    // The export holds what the chat's memory holds there, with who know it.
    let (_, file) = server.download(&format!("{chat}/export")).await;
    let head: Value = serde_json::from_slice(file.split(|b| *b == b'\n').next().unwrap()).unwrap();
    assert_eq!(
        head["chat_metadata"]["cardwave_memories"],
        json!([{ "kind": "fact", "text": "Mira lives in Varn", "known_by": ["Mira"] }])
    );

    // Back on the first version, its block no longer holds: the next reply is
    // given no note, and its pass reads the block there again.
    let head = json!({ "message_id": first });
    assert_eq!(server.put(&format!("{chat}/head"), head).await.0, 200);
    fake.finds(&fact("Saltmere"));
    say(&server, &chat, "Where do you live?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(memory_of(&prompt), None);
    passes(&fake, 3).await;
    remembered(&mut socket).await;
    assert_eq!(texts().await, [json!("Mira lives in Saltmere")]);

    // An edit of a message inside the block has it read again too.
    let (_, view) = server.get(&chat).await;
    let third = view["messages"][2]["id"].clone();
    let (status, edited) = server
        .patch(
            &format!("/api/messages/{third}"),
            json!({ "content": "Message three, changed." }),
        )
        .await;
    assert_eq!(status, 200, "{edited}");
    say(&server, &chat, "And now?").await;
    // The reply after the edit is given no note of the block as it was.
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(memory_of(&prompt), None);
    passes(&fake, 4).await;
    assert!(fake.noted().passes[3].contains("Message three, changed."));
    remembered(&mut socket).await;

    // A message of the block deleted (with those after it), the next reply
    // is given no note either.
    let (_, view) = server.get(&chat).await;
    let fifth = view["messages"][4]["id"].clone();
    let (status, _) = server
        .call(Method::DELETE, &format!("/api/messages/{fifth}"), None)
        .await;
    assert_eq!(status, 200);
    say(&server, &chat, "Still there?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(memory_of(&prompt), None);
}

#[tokio::test]
async fn a_block_the_helper_fails_on_is_read_by_the_next_pass() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(SISTER);
    fake.noted().failing = 1;
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    let end = Instant::now() + WAIT;
    while fake.noted().failing > 0 {
        assert!(Instant::now() < end, "the helper was not asked");
        sleep(std::time::Duration::from_millis(20)).await;
    }
    assert!(memories(&server).await.is_empty());
    say(&server, &chat, "Are you there?").await;
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    assert_eq!(memories(&server).await.len(), 2);
    assert!(fake.noted().passes[0].contains("[20] Mira: Hello."));
}

#[tokio::test]
async fn a_reply_whose_documents_do_not_read_is_still_given_its_memory_note() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(SISTER);
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;

    // The documents' pieces can no longer be read.
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    db.with(|conn| conn.execute_batch("drop table document_pieces"))
        .unwrap();
    fake.finds(NOTHING);
    say(&server, &chat, "Will you like her?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert!(
        memory_of(&prompt).is_some_and(|note| note.contains("Ana")),
        "{prompt}"
    );
}

#[tokio::test]
async fn a_memory_names_when_what_it_was_read_from_was_said() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let before = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    fill(&server, &chat, 19).await;
    fake.finds("PRESENT: Mira, Guest\nFACTS:\nuser | fear | The user is afraid of the dark | personal | Mira, Guest | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let said_at = memories(&server).await[0]["said_at"].as_i64().unwrap();
    assert!(
        before - 1000 <= said_at && said_at <= before + 60_000,
        "{said_at} {before}"
    );
}

#[tokio::test]
async fn a_memory_names_the_user_without_a_persona_in_the_apps_language_of_now() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds("PRESENT: Mira, Guest\nFACTS:\nuser | fear | Guest is afraid of the dark | personal | Mira, Guest | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let german = json!({ "app_language": "de" });
    let (status, body) = server
        .call(Method::PATCH, "/api/settings", Some(german))
        .await;
    assert_eq!(status, 200, "{body}");
    let listed = &memories(&server).await[0];
    assert_eq!(
        (&listed["text"], &listed["known_to"]),
        (
            &json!("Gast is afraid of the dark"),
            &json!(["mira", "gast"])
        )
    );
}

#[tokio::test]
async fn a_memory_is_changed_deleted_and_put_back() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds("PRESENT: Mira, Guest\nFACTS:\nuser | fear | The user is afraid of the dark | personal | Mira, Guest | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let id = memories(&server).await[0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    let path = format!("/api/memories/{id}");
    let afraid = found(&server, "afraid").await;
    assert_eq!(
        afraid,
        [(
            "The user is afraid of the dark".to_string(),
            json!({"code": "by", "names": ["Mira"], "you": true})
        )]
    );

    let (status, changed) = server
        .patch(&path, json!({ "text": "  The user fears\nthe dark. " }))
        .await;
    assert_eq!(
        (status, &changed["text"], &changed["known_to"]),
        (
            200,
            &json!("The user fears the dark."),
            &json!(["mira", "guest"])
        )
    );
    remembered(&mut socket).await;
    // Search Cardwave finds it by its new words alone.
    assert!(found(&server, "afraid").await.is_empty());
    assert_eq!(found(&server, "fears").await.len(), 1);
    // Only who may know it count.
    let (status, changed) = server
        .patch(&path, json!({ "known_to": ["Guest", "Odo"] }))
        .await;
    assert_eq!((status, &changed["known_to"]), (200, &json!(["guest"])));
    assert_eq!(server.patch(&path, json!({ "text": " " })).await.0, 400);
    let missing = ["/api/memories/999.1", "/api/memories/x"];
    for missing in missing {
        assert_eq!(server.patch(missing, json!({ "text": "x" })).await.0, 404);
    }
    // The next reply is given the changed text, which only the user knows now: Mira is not.
    say(&server, &chat, "Do you remember?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(memory_of(&prompt), None);

    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    assert!(memories(&server).await.is_empty());
    assert!(found(&server, "fears").await.is_empty());
    let (status, back) = server.post(&format!("{path}/restore"), json!({})).await;
    assert_eq!(
        (status, &back["text"]),
        (200, &json!("The user fears the dark."))
    );
    assert_eq!(memories(&server).await.len(), 1);
    assert_eq!(
        found(&server, "fears").await[0].1,
        json!({"code": "by", "names": [], "you": true})
    );
    // Deleted for good once the server starts again.
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    let server = server.restart().await;
    assert_eq!(
        server.post(&format!("{path}/restore"), json!({})).await.0,
        404
    );
}

#[tokio::test]
async fn memories_are_listed_newest_first_and_an_undo_after_a_later_block_puts_one_back() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(SISTER);
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let texts =
        |list: Vec<Value>| -> Vec<Value> { list.iter().map(|m| m["text"].clone()).collect() };
    let sister = memories(&server).await[1]["id"]
        .as_str()
        .unwrap()
        .to_string();
    let path = format!("/api/memories/{sister}");
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    remembered(&mut socket).await;
    // A later block, read while the fact is deleted, sets a fact after the event.
    fill(&server, &chat, 39).await;
    fake.finds("PRESENT: Mira, Guest\nFACTS:\nuser | job | The user bakes bread | personal | Mira, Guest | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    assert_eq!(
        texts(memories(&server).await),
        [
            json!("The user bakes bread"),
            json!("The user said Ana comes tonight (cause: Ana visits; result: Mira waits)")
        ]
    );
    let (status, back) = server.post(&format!("{path}/restore"), json!({})).await;
    assert_eq!(
        (status, &back["text"]),
        (200, &json!("The user's sister is called Ana"))
    );
    assert_eq!(texts(memories(&server).await).len(), 3);
}

/// The database of `server` and the memory of the memory view ID `id`.
fn store_of(server: &Server, id: &str) -> (Db, i64) {
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    (db, id.split_once('.').unwrap().0.parse().unwrap())
}

/// A server whose search model is `stand_in`, downloaded and ready, with the
/// fake as its provider, and a chat with Mira. Answers the server and the chat.
async fn searching(stand_in: &Embedder, fake: &Fake) -> (Server, String) {
    let server = start_searching(stand_in.setup()).await;
    assert_eq!(server.post("/api/search/download", json!({})).await.0, 200);
    let end = Instant::now() + WAIT;
    loop {
        let (_, state) = server.get("/api/search").await;
        if state["state"] == "ready" && state["left"] == 0 {
            break;
        }
        assert!(Instant::now() < end, "the search model is not ready");
        sleep(std::time::Duration::from_millis(20)).await;
    }
    setup(&server, fake).await;
    let chat = chat(&server).await;
    (server, chat)
}

/// `searching`, whose chat took along a lorebook of entries used by meaning:
/// one of the sea, and one long one of the forest whose words of the sea are
/// in its second piece.
async fn meaning(stand_in: &Embedder, fake: &Fake) -> (Server, String) {
    let (server, chat) = searching(stand_in, fake).await;
    let long = format!(
        "Deep moss. {}{}",
        "moss ".repeat(320),
        "storm harbor ship ".repeat(60)
    );
    let file = json!({ "name": "Coast", "entries": [
        { "keys": ["zzz"], "comment": "Light", "content": "The keeper watches the storm over the harbor.", "vectorized": true },
        { "keys": ["yyy"], "comment": "Wood", "content": long, "vectorized": true },
    ]});
    let (_, imported) = server
        .upload("/api/lorebooks", file.to_string().into_bytes())
        .await;
    let lorebook_id = imported["lorebook"]["id"].clone();
    assert_eq!(
        server
            .post(
                &format!("{chat}/lorebooks"),
                json!({ "lorebook_id": lorebook_id })
            )
            .await
            .0,
        200
    );
    (server, chat)
}

#[tokio::test]
async fn a_lorebook_entry_used_by_meaning_is_given_when_the_newest_messages_are_about_it() {
    let stand_in = Embedder::start().await;
    let fake = Fake::start().await;
    let (server, chat) = meaning(&stand_in, &fake).await;
    let mut socket = server.listen().await;
    let given = |prompt: &Value| prompt.to_string().contains("The keeper watches the storm");
    // A long entry is as near as its nearest piece.
    let long = |prompt: &Value| prompt.to_string().contains("Deep moss.");

    say(
        &server,
        &chat,
        "The waves crash on the ship, the tide is high.",
    )
    .await;
    // The model is started by the first need; a reply never waits for it.
    timeout(WAIT, async {
        loop {
            let (_, prompt) = reply(
                &server,
                &fake,
                &mut socket,
                &chat,
                json!({ "regenerate": false }),
            )
            .await;
            if given(&prompt) {
                break;
            }
            say(
                &server,
                &chat,
                "The waves crash on the ship, the tide is high.",
            )
            .await;
        }
    })
    .await
    .expect("the entry was not given by its meaning");
    let (_, prompt) = reply(
        &server,
        &fake,
        &mut socket,
        &chat,
        json!({ "regenerate": true }),
    )
    .await;
    assert!(long(&prompt));
    say(
        &server,
        &chat,
        "Deer walk among the moss and trees of the forest.",
    )
    .await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert!(!given(&prompt));
    // Its keyword does not count while the meaning is known.
    say(&server, &chat, "zzz in the forest").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert!(!given(&prompt));
}

#[tokio::test]
async fn a_search_model_that_hangs_holds_no_reply_back() {
    let stand_in = Embedder::start().await;
    let fake = Fake::start().await;
    let (server, chat) = meaning(&stand_in, &fake).await;
    let mut socket = server.listen().await;
    stand_in.stall();
    say(&server, &chat, "zzz: the waves crash on the ship.").await;
    // The reply waits for it no longer than a moment, and the entry goes by its keyword, as without the model.
    let (_, prompt) = timeout(WAIT, reply(&server, &fake, &mut socket, &chat, json!({})))
        .await
        .expect("the reply waited for the search model");
    assert!(prompt.to_string().contains("The keeper watches the storm"));
}

#[tokio::test]
async fn a_texts_vector_unused_for_30_days_is_let_go_at_the_start() {
    let server = start().await;
    let day = 24 * 60 * 60 * 1000_i64;
    let now = chrono::Utc::now().timestamp_millis();
    let plant = |hash: &[u8], used_at: i64| {
        let options = server.options();
        let db = Db::open(
            &options.data_dir.join(FILE_NAME),
            options.key.given().unwrap(),
        )
        .unwrap();
        db.with(|conn| {
            conn.execute(
                "insert into text_vectors (hash, embedding, used_at) values (?1, x'00000000', ?2)",
                rusqlite::params![hash, used_at],
            )
        })
        .unwrap();
    };
    plant(b"old", now - 31 * day);
    plant(b"new", now - 29 * day);
    let server = server.restart().await;
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    let kept: Vec<Vec<u8>> = db
        .with(|conn| {
            let mut query = conn.prepare("select hash from text_vectors order by hash")?;
            query.query_map([], |r| r.get(0))?.collect()
        })
        .unwrap();
    assert_eq!(kept, [b"new".to_vec()]);
}

async fn documents(server: &Server) -> Vec<Value> {
    let (status, list) = server.get("/api/documents").await;
    assert_eq!(status, 200, "{list}");
    list.as_array().unwrap().clone()
}

#[tokio::test]
async fn a_document_is_added_to_a_chat_or_a_card_listed_deleted_and_put_back() {
    let server = start().await;
    let chat = chat(&server).await;
    let (_, view) = server.get(&chat).await;
    let card = view["characters"][0]["card_id"].clone();

    let (status, added) = server
        .upload(
            &format!("{chat}/documents?name=Coast%20notes.txt"),
            b"\xEF\xBB\xBFThe lamp is lit at dusk.\r\nThe tide turns at nine.".to_vec(),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    assert_eq!(
        (
            &added["name"],
            &added["words"],
            &added["read"],
            &added["chat_id"],
            &added["owner_name"]
        ),
        (
            &json!("Coast notes.txt"),
            &json!(11),
            &json!(false),
            &view["chat"]["id"],
            &view["chat"]["title"]
        )
    );
    let (status, guide) = server
        .upload(
            &format!("/api/cards/{card}/documents?name=Guide.md"),
            b"# Saltmere\nA town by the sea.".to_vec(),
        )
        .await;
    assert_eq!(status, 201, "{guide}");
    assert_eq!(
        (&guide["card_id"], &guide["chat_id"]),
        (&card, &Value::Null)
    );
    // A file of another kind, and one without text, are refused.
    let (status, refused) = server
        .upload(
            &format!("{chat}/documents?name=lamp.png"),
            common::picture(),
        )
        .await;
    assert_eq!(status, 400);
    assert!(
        refused["error"]
            .as_str()
            .unwrap()
            .contains(".txt, .md, .pdf or .docx")
    );
    let (status, _) = server
        .upload(&format!("{chat}/documents?name=empty.txt"), b"  ".to_vec())
        .await;
    assert_eq!(status, 400);

    let names = |list: Vec<Value>| list.iter().map(|d| d["name"].clone()).collect::<Vec<_>>();
    assert_eq!(
        names(documents(&server).await),
        [json!("Guide.md"), json!("Coast notes.txt")]
    );
    let path = format!("/api/documents/{}", added["id"]);
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    assert_eq!(names(documents(&server).await), [json!("Guide.md")]);
    let (status, back) = server.post(&format!("{path}/restore"), json!({})).await;
    assert_eq!((status, &back["name"]), (200, &json!("Coast notes.txt")));
    assert_eq!(documents(&server).await.len(), 2);
    // The Undo of a document whose chat went to the Trash meanwhile puts back nothing.
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    let trash = |trashed: bool| server.patch(&chat, json!({ "trashed": trashed }));
    assert_eq!(trash(true).await.0, 200);
    assert_eq!(
        server.post(&format!("{path}/restore"), json!({})).await.0,
        404
    );
    assert_eq!(trash(false).await.0, 200);
    assert_eq!(names(documents(&server).await), [json!("Guide.md")]);
}

#[tokio::test]
async fn a_reply_is_given_the_pieces_of_its_documents_near_its_newest_messages() {
    let stand_in = Embedder::start().await;
    let fake = Fake::start().await;
    let (server, chat) = searching(&stand_in, &fake).await;
    let (_, view) = server.get(&chat).await;
    let card = view["characters"][0]["card_id"].clone();
    let sea = "The keeper of the lighthouse watches the storm over the harbor. ".repeat(10);
    let forest = "Deer walk among the moss and trees of the forest. ".repeat(14);
    let space = "The pilot flies the starship past the planet to the stars. ".repeat(10);
    let add = |path: String, text: String| {
        let server = &server;
        async move {
            let (status, added) = server.upload(&path, text.into_bytes()).await;
            assert_eq!(status, 201, "{added}");
        }
    };
    add(
        format!("{chat}/documents?name=Coast.txt"),
        format!("{sea}\n{forest}"),
    )
    .await;
    add(
        format!("/api/cards/{card}/documents?name=Sky.txt"),
        space.clone(),
    )
    .await;
    let other = server
        .post("/api/chats", json!({ "characters": [{ "version_id": view["characters"][0]["version_id"], "character": "mira" }] }))
        .await
        .1;
    add(
        format!(
            "/api/chats/{}/documents?name=Other.txt",
            other["chat"]["id"]
        ),
        "OTHER: the storm hits the ship in the harbor.".into(),
    )
    .await;
    let end = Instant::now() + WAIT;
    while documents(&server).await.iter().any(|d| d["read"] != true) {
        assert!(Instant::now() < end, "the documents were not read");
        sleep(std::time::Duration::from_millis(20)).await;
    }

    let mut socket = server.listen().await;
    // The pieces stand in a message of their own, near the newest message.
    let given = |prompt: &Value| {
        let messages = prompt.as_array().unwrap();
        let pieces = messages.iter().position(|m| {
            m["content"]
                .as_str()
                .is_some_and(|text| text.starts_with("<supplemental_data_context>"))
        });
        let after = |at: usize| {
            messages[at..]
                .iter()
                .filter(|m| m["role"] != "system")
                .count()
        };
        assert!(pieces.is_none_or(|at| after(at) == 1), "{prompt}");
        pieces
            .and_then(|at| messages[at]["content"].as_str())
            .unwrap_or_default()
            .split_once("<supplemental_data_context>\n")
            .map(|(_, rest)| {
                rest.split("\n</supplemental_data_context>")
                    .next()
                    .unwrap()
                    .to_string()
            })
            .unwrap_or_default()
    };
    say(
        &server,
        &chat,
        "The waves crash on the ship, the tide is high.",
    )
    .await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    let excerpts = given(&prompt);
    assert!(
        excerpts.starts_with(&format!("From \"Coast.txt\":\n{}", sea.trim())),
        "{excerpts}"
    );
    assert!(
        !excerpts.contains("Deer") && !excerpts.contains("OTHER") && !excerpts.contains("pilot")
    );
    // A card's document is its character's.
    say(&server, &chat, "Look at the stars, a starship in orbit.").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert!(given(&prompt).starts_with("From \"Sky.txt\":\nThe pilot"));

    // A memory that does not read leaves the documents to the reply.
    fill(&server, &chat, 19).await;
    fake.finds(SISTER);
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let (db, _) = store_of(&server, memories(&server).await[0]["id"].as_str().unwrap());
    db.with(|conn| conn.execute("update memory_blocks set state = '{'", []))
        .unwrap();
    say(
        &server,
        &chat,
        "The waves crash on the ship, the tide is high.",
    )
    .await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    assert_eq!(memory_of(&prompt), None);
    assert!(
        given(&prompt).starts_with("From \"Coast.txt\":"),
        "{prompt}"
    );
}

#[tokio::test]
async fn a_pass_that_read_an_older_state_lets_go_of_no_vector_of_the_newest() {
    let stand_in = Embedder::start().await;
    let fake = Fake::start().await;
    let (server, chat) = searching(&stand_in, &fake).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(SISTER);
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let (db, store) = store_of(&server, memories(&server).await[0]["id"].as_str().unwrap());
    let count = || -> i64 {
        db.with(|conn| {
            conn.query_row(
                "select count(*) from memory_vectors where store_id = ?1",
                [store],
                |r| r.get(0),
            )
        })
        .unwrap()
    };
    let end = Instant::now() + WAIT;
    while count() < 2 {
        assert!(Instant::now() < end, "the memory's vectors were not made");
        sleep(std::time::Duration::from_millis(20)).await;
    }
    // What a pass that read the state before the block keeps: nothing new.
    cw_chat::memory::keep_vectors(&db, store, cw_provider::embedder::MODEL, &[]).unwrap();
    assert_eq!(count(), 2);
}

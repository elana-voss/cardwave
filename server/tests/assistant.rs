//! Assistant and companion (`assistant.rs`): a chat's mode, picked by the
//! worker model or set by hand, and the texts a reply has in it; a
//! character's personality in a personal mode (its tools, its memory), the
//! assistant's memory across its chats (which the companion's figure is told
//! too), and the coding task it offers.
//!
//! `Model` stands in for a model's server: it answers the picker with
//! `picked`, the memory's questions as `memories` says (each replacing all
//! it is shown), and each reply with the next of the test's answers (`FAIL`
//! fails), and notes every request by its kind.

mod common;

use std::sync::{Arc, Mutex};

use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use common::picture;
use common::server::{Server, Socket, event, start};
use cw_ccv4::png::{self, Container};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::net::TcpListener;

/// How the questions are told apart, by their system prompt's start.
const PICKER: &str = "You pick the mode of a chat.";
/// How the memory's helper is asked (`memory::hybrid::OPENING`), and in which kind of chat.
const HELPER: &str = "Read these new messages of a ";
const PERSONAL: &str = "Read these new messages of a assistant chat";

const GWEN: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
modes = ["Roleplay", "Assistant"]

[name.gwen]
text = "Gwen"

[greeting.hi]
text = "Hello."

[personality.scene]
text = "SCENE-TEXT"
modes = ["Roleplay"]

[personality.work]
text = "WORK-TEXT"
modes = ["Assistant"]

[character.gwen]
name-char = "name.gwen"
greetings = ["greeting.hi"]
prompt = ["name.gwen", "personality.scene", "personality.work", "CHAT-HISTORY"]
"#;

/// What the stand-in was asked: each request's kind ("pick", "keep",
/// "personal" or "reply") and body.
type Asked = Arc<Mutex<Vec<(&'static str, Value)>>>;

struct Model {
    url: String,
    asked: Asked,
}

fn stream(pieces: &[Value]) -> String {
    let mut text: String = pieces
        .iter()
        .map(|piece| format!("data: {piece}\n\n"))
        .collect();
    text.push_str("data: [DONE]\n\n");
    text
}

fn text(text: &str) -> String {
    stream(&[json!({ "choices": [{ "delta": { "content": text } }] })])
}

fn call(name: &str, arguments: Value) -> String {
    stream(&[
        json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "id": "call_1", "type": "function", "function": { "name": name, "arguments": arguments.to_string() } }] } }] }),
    ])
}

/// A reply that fails.
const FAIL: &str = "FAIL";

impl Model {
    /// Answers the picker with `picked`, the memory's helper in an assistant
    /// chat with `memories` (in roleplay with nothing), and the replies with
    /// `replies` in turn, the last again and again.
    async fn start(picked: &'static str, memories: &'static str, replies: Vec<String>) -> Self {
        let asked: Asked = Arc::default();
        let log = asked.clone();
        let complete = move |Json(body): Json<Value>| async move {
            let system = body["messages"][0]["content"].as_str().unwrap_or_default();
            let mut log = log.lock().unwrap();
            let (kind, answer) = if system.starts_with(PICKER) {
                ("pick", text(&json!({ "mode": picked }).to_string()))
            } else if system.starts_with(PERSONAL) {
                ("personal", text(memories))
            } else if system.starts_with(HELPER) {
                ("keep", text("PRESENT:\nFACTS:\nEVENTS:"))
            } else if system.starts_with(common::model::TITLE) {
                ("title", text(r#"{"title": "A chat"}"#))
            } else {
                let replies_so_far = log.iter().filter(|(kind, _)| *kind == "reply").count();
                (
                    "reply",
                    replies[replies_so_far.min(replies.len() - 1)].clone(),
                )
            };
            log.push((kind, body));
            if answer == FAIL {
                let failed = Json(json!({ "error": { "message": "overloaded" } }));
                return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, failed).into_response();
            }
            ([(header::CONTENT_TYPE, "text/event-stream")], answer).into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(complete));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }

    /// The requests of one kind.
    fn asked(&self, kind: &str) -> Vec<Value> {
        let asked = self.asked.lock().unwrap();
        asked
            .iter()
            .filter(|(one, _)| *one == kind)
            .map(|(_, body)| body.clone())
            .collect()
    }
}

/// The server's provider is `model`, and Gwen is a card: answers the card's version.
async fn set_up(server: &Server, model: &Model) -> Value {
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let file = png::write(&Container {
        image: picture(),
        toml: vec![("card/0001_card.toml".to_string(), GWEN.to_string())],
        assets: Vec::new(),
    })
    .unwrap();
    let (status, card) = server.upload("/api/cards", file).await;
    assert_eq!(status, 201, "{card}");
    card["version_id"].clone()
}

/// A new chat with Gwen: its address.
async fn chat_with(server: &Server, version: &Value) -> String {
    let view = server
        .chat_with(&[(version.as_i64().unwrap(), "gwen")], 0)
        .await;
    format!("/api/chats/{}", view["chat"]["id"])
}

/// The next event of `kind` on the socket.
async fn next(socket: &mut Socket, kind: &str) -> Value {
    loop {
        let event = event(socket).await;
        if event["type"] == kind {
            return event;
        }
    }
}

/// The user says `said` and the chat replies: answers the reply's end.
async fn talk(server: &Server, socket: &mut Socket, chat: &str, said: &str) -> Value {
    let said = json!({ "content": said });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    let (status, started) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202, "{started}");
    next(socket, "reply_ended").await
}

fn system(request: &Value) -> String {
    request["messages"][0]["content"]
        .as_str()
        .unwrap()
        .to_string()
}

fn tool_names(request: &Value) -> Vec<String> {
    let Some(tools) = request["tools"].as_array() else {
        return Vec::new();
    };
    tools
        .iter()
        .map(|tool| tool["function"]["name"].as_str().unwrap().to_string())
        .collect()
}

#[tokio::test]
async fn a_chat_picks_its_mode_and_a_reply_has_the_texts_of_its_mode() {
    let server = start().await;
    let model = Model::start("assistant", "", vec![text("Done.")]).await;
    let version = set_up(&server, &model).await;
    let chat = chat_with(&server, &version).await;
    let mut socket = server.listen().await;
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["modes"], json!(["Roleplay", "Assistant"]));
    assert_eq!(
        (&view["chat"]["mode"], &view["chat"]["auto_mode"]),
        (&Value::Null, &Value::Null)
    );

    // The worker model picks the mode before the reply, which has the texts of that mode.
    let said = json!({ "content": "Help me sort my receipts." });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let picked = next(&mut socket, "chat_mode").await;
    assert_eq!(picked["mode"], "Assistant");
    next(&mut socket, "reply_ended").await;
    let pick = &model.asked("pick")[0];
    let question = pick["messages"][1]["content"].as_str().unwrap();
    assert!(
        question.contains("<modes>Roleplay, Assistant</modes>")
            && question.contains("<current_mode>Roleplay</current_mode>")
            && question.contains("User: Help me sort my receipts."),
        "{question}"
    );
    let reply = &model.asked("reply")[0];
    assert!(system(reply).contains("WORK-TEXT") && !system(reply).contains("SCENE-TEXT"));
    assert_eq!(server.get(&chat).await.1["chat"]["auto_mode"], "Assistant");

    // Another version of the reply is in the same mode, and asks no one.
    let again = json!({ "regenerate": true });
    assert_eq!(server.post(&format!("{chat}/generate"), again).await.0, 202);
    next(&mut socket, "reply_ended").await;
    assert_eq!(model.asked("pick").len(), 1);

    // A mode set by hand holds, whatever is said, and is asked of no one.
    let (status, set) = server
        .put(&format!("{chat}/mode"), json!({ "mode": "roleplay" }))
        .await;
    assert_eq!((status, &set["mode"]), (200, &json!("Roleplay")), "{set}");
    talk(&server, &mut socket, &chat, "Back to the story.").await;
    assert_eq!(model.asked("pick").len(), 1);
    let reply = model.asked("reply").pop().unwrap();
    assert!(system(&reply).contains("SCENE-TEXT") && !system(&reply).contains("WORK-TEXT"));

    assert_eq!(
        server
            .put(&format!("{chat}/mode"), json!({ "mode": "Pirate" }))
            .await,
        (
            400,
            json!({ "code": "not_possible", "error": "\"Pirate\" is no mode of this chat", "details": { "what": "chat_mode" } })
        )
    );
    let (_, set) = server
        .put(&format!("{chat}/mode"), json!({ "mode": null }))
        .await;
    assert_eq!(set["mode"], Value::Null);
}

#[tokio::test]
async fn an_assistant_goes_by_its_personality_and_offers_a_coding_task() {
    let server = start().await;
    let offer = call(
        "start_coding_task",
        json!({ "goal": "Add a test for the export." }),
    );
    let replies = vec![
        offer.clone(),
        text("I offered it."),
        offer,
        FAIL.into(),
        text("Fine."),
    ];
    let model = Model::start("assistant", "", replies).await;
    let version = set_up(&server, &model).await;
    let chat = chat_with(&server, &version).await;
    let mut socket = server.listen().await;
    let tools = json!({ "tools": { "web": true } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let (_, set) = server
        .put(&format!("{chat}/mode"), json!({ "mode": "Assistant" }))
        .await;
    assert_eq!(set["mode"], "Assistant");

    let personality = format!("{chat}/personality");
    assert_eq!(
        server.get(&personality).await,
        (
            200,
            json!({ "offered": ["web", "coding"], "tools_off": [], "memory": true })
        )
    );

    // The assistant has its tools and offers a coding task, which the page is told once the reply has ended.
    // It does not remember here.
    let forget = json!({ "memory": false });
    assert_eq!(server.patch(&personality, forget).await.1["memory"], false);
    talk(&server, &mut socket, &chat, "Can your team add a test?").await;
    let offered = next(&mut socket, "coding_offer").await;
    assert_eq!(offered["goal"], "Add a test for the export.");
    let replies = model.asked("reply");
    assert_eq!(
        tool_names(&replies[0]),
        ["web_search", "read_web_page", "start_coding_task"]
    );
    assert!(
        replies[1]
            .to_string()
            .contains("The user is shown the task to start")
    );

    // A reply that fails after it offered a task offers none.
    let ended = talk(&server, &mut socket, &chat, "And another?").await;
    assert!(ended["error"]["code"].is_string(), "{ended}");
    let said = json!({ "content": "Never mind." });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    loop {
        let event = event(&mut socket).await;
        assert_ne!(event["type"], "coding_offer");
        if event["type"] == "reply_ended" {
            break;
        }
    }

    // Without its tools, it is offered none; and it remembers nothing.
    let off = json!({ "tools_off": ["web", "coding", "web"] });
    let (status, changed) = server.patch(&personality, off).await;
    assert_eq!(
        (status, changed),
        (
            200,
            json!({ "offered": ["web", "coding"], "tools_off": ["web", "coding"], "memory": false })
        )
    );
    talk(&server, &mut socket, &chat, "Thanks.").await;
    assert!(tool_names(&model.asked("reply").pop().unwrap()).is_empty());
    assert!(model.asked("personal").is_empty());

    // In roleplay the character is no assistant: it has the account's tools, and offers no task.
    server
        .put(&format!("{chat}/mode"), json!({ "mode": "Roleplay" }))
        .await;
    talk(&server, &mut socket, &chat, "Back to the story.").await;
    assert_eq!(
        tool_names(&model.asked("reply").pop().unwrap()),
        ["web_search", "read_web_page"]
    );
}

#[tokio::test]
async fn an_assistant_remembers_the_user_in_all_its_chats() {
    let server = start().await;
    let bees = "PRESENT: Gwen, User\nFACTS:\nuser | hobby | Erin keeps bees | personal | everyone | current\nEVENTS:";
    let model = Model::start("assistant", bees, vec![text("Noted.")]).await;
    let version = set_up(&server, &model).await;
    let mut socket = server.listen().await;
    let first = chat_with(&server, &version).await;
    server
        .put(&format!("{first}/mode"), json!({ "mode": "Assistant" }))
        .await;
    for n in 2..19 {
        let said = json!({ "content": format!("Message {n}.") });
        assert_eq!(server.post(&format!("{first}/messages"), said).await.0, 201);
    }
    talk(&server, &mut socket, &first, "I keep bees, by the way.").await;
    next(&mut socket, "memories").await;
    let asked = model.asked("personal");
    let prompt = asked[0]["messages"][0]["content"].as_str().unwrap();
    assert!(
        prompt.contains("assistant chat") && prompt.contains("Today is day 1."),
        "{prompt}"
    );
    assert!(model.asked("keep").is_empty());

    // Another chat with the same character is reminded of it.
    let second = chat_with(&server, &version).await;
    server
        .put(&format!("{second}/mode"), json!({ "mode": "Assistant" }))
        .await;
    talk(
        &server,
        &mut socket,
        &second,
        "What should I plant this spring?",
    )
    .await;
    let reply = model.asked("reply").pop().unwrap();
    let given = reply["messages"].to_string();
    assert!(
        given.contains("[Memory]\\nKnown:\\n- day 1: Erin keeps bees"),
        "{given}"
    );
    let (_, memories) = server.get("/api/memories").await;
    assert_eq!(memories.as_array().unwrap().len(), 1, "{memories}");
    assert_eq!(memories[0]["text"], "Erin keeps bees");

    // In roleplay the character remembers the scene, not the assistant's memories.
    let third = chat_with(&server, &version).await;
    server
        .put(&format!("{third}/mode"), json!({ "mode": "Roleplay" }))
        .await;
    talk(&server, &mut socket, &third, "Once upon a time.").await;
    let reply = model.asked("reply").pop().unwrap();
    assert!(!reply["messages"].to_string().contains("Erin keeps bees"));

    // What a chat in the Trash told it is given to no other.
    assert_eq!(
        server.patch(&first, json!({ "trashed": true })).await.0,
        200
    );
    talk(&server, &mut socket, &second, "Hello again.").await;
    let reply = model.asked("reply").pop().unwrap();
    assert!(!reply["messages"].to_string().contains("Erin keeps bees"));
}

#[tokio::test]
async fn what_a_chat_no_longer_holds_is_given_to_no_other_chat_of_its_memory() {
    let server = start().await;
    let bees = "PRESENT: Gwen, User\nFACTS:\nuser | hobby | Erin keeps bees | personal | everyone | current\nEVENTS:";
    let model = Model::start("assistant", bees, vec![text("Noted.")]).await;
    let version = set_up(&server, &model).await;
    let mut socket = server.listen().await;
    let first = chat_with(&server, &version).await;
    server
        .put(&format!("{first}/mode"), json!({ "mode": "Assistant" }))
        .await;
    for n in 2..19 {
        let said = json!({ "content": format!("Message {n}.") });
        assert_eq!(server.post(&format!("{first}/messages"), said).await.0, 201);
    }
    talk(&server, &mut socket, &first, "I keep bees, by the way.").await;
    next(&mut socket, "memories").await;

    // The first chat's block loses a message (and those after it): another
    // chat of the same character is no longer reminded of what it told.
    let (_, view) = server.get(&first).await;
    let fifth = view["messages"][4]["id"].as_i64().unwrap();
    let (status, _) = server
        .call(Method::DELETE, &format!("/api/messages/{fifth}"), None)
        .await;
    assert_eq!(status, 200);
    let second = chat_with(&server, &version).await;
    server
        .put(&format!("{second}/mode"), json!({ "mode": "Assistant" }))
        .await;
    talk(&server, &mut socket, &second, "What do I keep?").await;
    let reply = model.asked("reply").pop().unwrap();
    assert!(
        !reply["messages"].to_string().contains("Erin keeps bees"),
        "{reply}"
    );
}

#[tokio::test]
async fn the_companions_figure_is_told_what_its_character_remembers() {
    let server = start().await;
    let bees = "PRESENT: Gwen, User\nFACTS:\nuser | hobby | Erin keeps bees | personal | everyone | current\nEVENTS:";
    let model = Model::start("assistant", bees, vec![text("Noted.")]).await;
    let version = set_up(&server, &model).await;
    let mut socket = server.listen().await;
    let first = chat_with(&server, &version).await;
    server
        .put(&format!("{first}/mode"), json!({ "mode": "Assistant" }))
        .await;
    for n in 2..19 {
        let said = json!({ "content": format!("Message {n}.") });
        assert_eq!(server.post(&format!("{first}/messages"), said).await.0, 201);
    }
    talk(&server, &mut socket, &first, "I keep bees, by the way.").await;
    next(&mut socket, "memories").await;
    let (_, view) = server.get(&first).await;
    let companion = json!({ "card_id": view["characters"][0]["card_id"], "starts": false, "hidden_until": null });
    let (status, set) = server
        .patch("/api/settings", json!({ "companion": companion }))
        .await;
    assert_eq!(status, 200, "{set}");

    // Left alone, its figure is told the memory its chats share.
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "alone", "alone_s": 60 });
    assert_eq!(server.post("/api/companion/plan", asked).await.0, 200);
    let animator = model.asked("reply").pop().unwrap();
    assert!(system(&animator).starts_with("You move a character's figure"));
    let question = animator["messages"][1]["content"].as_str().unwrap();
    let told = "<memory>\nKnown:\n- day 1: Erin keeps bees\n</memory>";
    assert!(question.ends_with(told), "{question}");

    // So it is while its newest chat has nothing said yet.
    let second = chat_with(&server, &version).await;
    server
        .put(&format!("{second}/mode"), json!({ "mode": "Assistant" }))
        .await;
    let (_, view) = server.get(&second).await;
    let greeting = view["messages"][0]["id"].as_i64().unwrap();
    let gone = server
        .call(Method::DELETE, &format!("/api/messages/{greeting}"), None)
        .await;
    assert_eq!(gone.0, 200);
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "alone", "alone_s": 90 });
    assert_eq!(server.post("/api/companion/plan", asked).await.0, 200);
    let animator = model.asked("reply").pop().unwrap();
    let question = animator["messages"][1]["content"].as_str().unwrap();
    assert!(question.ends_with(told), "{question}");
    assert!(!question.contains("Hello."), "{question}");
}

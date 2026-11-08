//! The memory tests' stand-in provider (`Fake`): a reply is "Hello."; the
//! memory's helper (a question beginning `OPENING`) is answered as the test
//! says (`finds`), or fails where it says so (`failing`), and both are noted;
//! and the steps of a chat those tests take.

use std::sync::{Arc, Mutex};

use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use cw_chat::memory::hybrid::OPENING;
use serde_json::{Value, json};
use tokio::net::TcpListener;
use tokio::time::{Instant, sleep};

use super::server::{Server, Socket, WAIT, event};

/// A helper's answer that finds nothing.
pub const NOTHING: &str = "PRESENT:\nFACTS:\nEVENTS:";

#[derive(Default)]
pub struct Noted {
    /// The messages of each reply's question.
    pub replies: Vec<Value>,
    /// Each prompt the helper was asked.
    pub passes: Vec<String>,
    /// What the helper answers, and how many of its askings fail first.
    pub pass_says: String,
    pub failing: usize,
}

pub struct Fake {
    pub url: String,
    noted: Arc<Mutex<Noted>>,
}

impl Fake {
    pub async fn start() -> Self {
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

    pub fn noted(&self) -> std::sync::MutexGuard<'_, Noted> {
        self.noted.lock().unwrap()
    }

    /// What the helper answers from now on.
    pub fn finds(&self, reply: &str) {
        self.noted().pass_says = reply.into();
    }
}

pub async fn setup(server: &Server, fake: &Fake) {
    let provider = json!({ "base_url": fake.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
}

/// Starts a chat with Mira of the sample card. Answers its address.
pub async fn chat(server: &Server) -> String {
    let (_, card) = server.upload_whole(super::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    format!("/api/chats/{}", view["chat"]["id"])
}

pub async fn say(server: &Server, chat: &str, text: &str) {
    let (status, sent) = server
        .post(&format!("{chat}/messages"), json!({ "content": text }))
        .await;
    assert_eq!(status, 201, "{sent}");
}

/// The user's messages "Message <n>." until the chat holds `n` on its branch.
pub async fn fill(server: &Server, chat: &str, n: usize) {
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
pub async fn reply(
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
pub async fn remembered(socket: &mut Socket) {
    loop {
        if event(socket).await["type"] == "memories" {
            return;
        }
    }
}

/// Waits until the helper has been asked `n` times.
pub async fn passes(fake: &Fake, n: usize) {
    let end = Instant::now() + WAIT;
    while fake.noted().passes.len() < n {
        assert!(Instant::now() < end, "the memory pass was not asked");
        sleep(std::time::Duration::from_millis(20)).await;
    }
}

/// The memory note of a reply's prompt, which stands just before its newest
/// message (after it only what stands at depth 0 and after the chat).
pub fn memory_of(prompt: &Value) -> Option<String> {
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

pub async fn memories(server: &Server) -> Vec<Value> {
    let (status, list) = server.get("/api/memories").await;
    assert_eq!(status, 200, "{list}");
    list.as_array().unwrap().clone()
}

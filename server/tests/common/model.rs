//! A stand-in for a model's server that answers each reply's request with the
//! next of the test's answers, the chat's memory with nothing and a chat's
//! title with "A chat" (`tools.rs`, `written_tools.rs`, `app_tools.rs`), and what a test reads of
//! the socket and of a request's tools; `chat_at` a chat with Mira asking it,
//! `code_mode` switches a chat's Code mode.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::http::{StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use futures_util::StreamExt;
use serde_json::{Value, json};
use tokio::net::TcpListener;

use super::server::{Server, Socket, event};

/// How the memory's helper is asked (`memory::hybrid::OPENING`).
pub const KEEPER: &str = "Read these new messages of a ";

/// How a chat is asked its title (`chats::title::NAME`): answered without
/// taking a scripted answer or counting in `asked`.
pub const TITLE: &str = "You title a chat";

/// Where an answer of `Model` pauses a moment before it goes on.
pub const PAUSE: &str = "<pause>";

/// A model's server that answers each reply's request with the next of its
/// answers (a whole stream each, which pauses at `PAUSE`), and notes what it
/// was sent.
pub struct Model {
    pub url: String,
    asked: Arc<Mutex<Vec<Value>>>,
}

impl Model {
    pub async fn start(answers: Vec<(u16, String)>) -> Self {
        let asked = Arc::new(Mutex::new(Vec::new()));
        let log = asked.clone();
        let complete = move |Json(body): Json<Value>| async move {
            let system = body["messages"][0]["content"].as_str().unwrap_or_default();
            let (status, text) = if system.starts_with(KEEPER) {
                (200, stream(&[text_piece("PRESENT:\nFACTS:\nEVENTS:")]))
            } else if system.starts_with(TITLE) {
                (200, stream(&[text_piece(r#"{"title": "A chat"}"#)]))
            } else {
                let mut log = log.lock().unwrap();
                log.push(body);
                answers[(log.len() - 1).min(answers.len() - 1)].clone()
            };
            let parts: Vec<String> = text.split(PAUSE).map(String::from).collect();
            let body = futures_util::stream::iter(parts).then(|part| async move {
                tokio::time::sleep(Duration::from_millis(30)).await;
                Ok::<_, std::convert::Infallible>(part)
            });
            let kind = if status == 200 {
                "text/event-stream"
            } else {
                "application/json"
            };
            (
                StatusCode::from_u16(status).unwrap(),
                [(header::CONTENT_TYPE, kind)],
                axum::body::Body::from_stream(body),
            )
                .into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(complete));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }

    pub fn asked(&self) -> Vec<Value> {
        self.asked.lock().unwrap().clone()
    }
}

pub fn text_piece(text: &str) -> Value {
    json!({ "choices": [{ "delta": { "content": text } }] })
}

/// A call of `name` with `arguments`, streamed in two pieces as OpenAI does.
pub fn call_pieces(name: &str, arguments: &Value) -> Vec<Value> {
    let arguments = arguments.to_string();
    let (head, tail) = arguments.split_at(arguments.len() / 2);
    vec![
        json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "id": "call_1", "type": "function", "function": { "name": name, "arguments": head } }] } }] }),
        json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "function": { "arguments": tail } }] } }] }),
    ]
}

pub fn stream(pieces: &[Value]) -> String {
    let mut text: String = pieces
        .iter()
        .map(|piece| format!("data: {piece}\n\n"))
        .collect();
    text.push_str("data: [DONE]\n\n");
    text
}

/// The next event of the socket that is not a piece of a reply's text.
pub async fn next_event(socket: &mut Socket) -> Value {
    loop {
        let event = event(socket).await;
        // The test's own changes of the settings are told too, and passed by.
        if !["reply_text", "memories", "settings"].contains(&event["type"].as_str().unwrap()) {
            return event;
        }
    }
}

pub fn names(tools: &Value) -> Vec<&str> {
    tools
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| tool["function"]["name"].as_str().unwrap())
        .collect()
}

/// A server with the model at `model` and a chat with Mira in which the user
/// asked something: its address.
pub async fn chat_at(server: &Server, model: &Model) -> String {
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let (_, card) = server.upload("/api/cards", super::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let said = json!({ "content": "What does my note say?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    chat
}

/// Switches the chat's Code mode on or off, its reply length as a new chat has it.
pub async fn code_mode(server: &Server, chat: &str, on: bool) {
    let reply = json!({ "reply_length": 350, "code_mode": on });
    let (status, changed) = server.put(&format!("{chat}/reply"), reply).await;
    assert_eq!(
        (status, &changed["code_mode"]),
        (200, &json!(on)),
        "{changed}"
    );
}

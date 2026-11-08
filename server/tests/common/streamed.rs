//! The stand-in model server of the reply tests (`generate.rs`, `generate_lore.rs`):
//! `Provider` hands each request for a reply to the test, which writes the
//! answer piece by piece (`says`, then `DONE`), and answers the memory's helper
//! itself with nothing found; `follow` reads a reply's events to its end.

use std::convert::Infallible;
use std::sync::{Arc, Mutex};

use axum::body::Body;
use axum::http::{HeaderMap, StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use futures_util::stream;
use serde_json::{Value, json};
use tokio::net::TcpListener;
use tokio::sync::mpsc;
use tokio::time::timeout;

use super::server::{Server, Socket, WAIT, event};

pub const DONE: &[u8] = b"data: [DONE]\n\n";

/// How the memory's helper is asked (`memory::hybrid::OPENING`).
pub const KEEPER: &str = "Read these new messages of a ";

/// One request the fake provider got.
pub struct Asked {
    pub key: Option<String>,
    pub body: Value,
    /// Writes the answer's body. Dropping it ends the answer.
    pub answer: mpsc::UnboundedSender<Vec<u8>>,
}

/// A stand-in for a model's server, started inside the test. It hands every
/// request for a reply to the test, which writes the answer piece by piece,
/// and answers the chat's memory itself.
pub struct Provider {
    pub url: String,
    pub asked: mpsc::UnboundedReceiver<Asked>,
    /// While set, requests are answered with this status and JSON body instead
    /// of a stream.
    pub refusal: Arc<Mutex<Option<(u16, String)>>>,
}

impl Provider {
    pub async fn start() -> Self {
        let (tell, asked) = mpsc::unbounded_channel();
        let refusal = Arc::new(Mutex::new(None::<(u16, String)>));
        let refuse = refusal.clone();
        let complete = move |headers: HeaderMap, Json(body): Json<Value>| async move {
            if let Some((status, text)) = refuse.lock().unwrap().clone() {
                let json = [(header::CONTENT_TYPE, "application/json")];
                return (StatusCode::from_u16(status).unwrap(), json, text).into_response();
            }
            // The chat's memory's helper asks too, after 20 messages
            // (`memory.rs`): it finds nothing here.
            let system = body["messages"][0]["content"].as_str().unwrap_or_default();
            if system.starts_with(KEEPER) {
                let mut nothing = says("PRESENT:\nFACTS:\nEVENTS:");
                nothing.extend_from_slice(DONE);
                return ([(header::CONTENT_TYPE, "text/event-stream")], nothing).into_response();
            }
            let (answer, pieces) = mpsc::unbounded_channel::<Vec<u8>>();
            let key = headers
                .get(header::AUTHORIZATION)
                .map(|key| key.to_str().unwrap().to_string());
            let _ = tell.send(Asked { key, body, answer });
            let pieces = stream::unfold(pieces, |mut pieces| async {
                pieces
                    .recv()
                    .await
                    .map(|piece| (Ok::<_, Infallible>(piece), pieces))
            });
            (
                [(header::CONTENT_TYPE, "text/event-stream")],
                Body::from_stream(pieces),
            )
                .into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(complete));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self {
            url,
            asked,
            refusal,
        }
    }

    /// The next request the server makes.
    pub async fn next(&mut self) -> Asked {
        timeout(WAIT, self.asked.recv())
            .await
            .expect("the provider was not asked")
            .unwrap()
    }
}

/// One piece of a streamed reply, as OpenAI's API sends it.
pub fn says(text: &str) -> Vec<u8> {
    format!(
        "data: {}\n\n",
        json!({ "choices": [{ "delta": { "content": text } }] })
    )
    .into_bytes()
}

pub async fn use_provider(server: &Server, url: &str) {
    let provider = json!({
        "base_url": url,
        "model": "test-model",
        "api_key": "sk-test",
        "sampling": { "temperature": 0.7 },
    });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
}

/// Starts a chat with Mira in which the user has asked something. Returns its address.
pub async fn chat(server: &Server) -> String {
    let (_, card) = server.upload("/api/cards", super::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    assert_eq!(
        server
            .post(
                &format!("{chat}/messages"),
                json!({ "content": "Why tonight?" })
            )
            .await
            .0,
        201
    );
    chat
}

pub async fn generate(server: &Server, chat: &str, how: Value) -> (u16, Value) {
    server.post(&format!("{chat}/generate"), how).await
}

/// Follows a reply to its end, as a page does: every piece has to start where
/// the text so far ends. Returns the text and the event that ended the reply.
/// What the test changed itself over HTTP before (a lorebook, the provider, a card) is
/// told on the socket too, and passed by.
pub async fn follow(socket: &mut Socket, so_far: &str) -> (String, Value) {
    let mut text = so_far.to_string();
    loop {
        let event = event(socket).await;
        match event["type"].as_str().unwrap() {
            "reply_text" => {
                assert_eq!(event["start"], text.encode_utf16().count());
                text.push_str(event["text"].as_str().unwrap());
            }
            "reply_ended" => return (text, event),
            "lorebook" | "presets" | "provider" | "card" | "trash" | "settings" | "personas"
            | "chat" | "messages" => {}
            other => panic!("unexpected event {other}"),
        }
    }
}

pub fn has(prompt: &Value, text: &str) -> bool {
    prompt
        .as_array()
        .unwrap()
        .iter()
        .any(|message| message["content"].as_str().unwrap().contains(text))
}

/// Has a reply written in the chat to its end. Returns the lorebook entries
/// its message says it was given, and the prompt the provider got.
pub async fn written(
    server: &Server,
    provider: &mut Provider,
    socket: &mut Socket,
    chat: &str,
    how: Value,
) -> (Value, Value) {
    let (status, message) = generate(server, chat, how).await;
    assert_eq!(status, 202, "{message}");
    let asked = provider.next().await;
    asked
        .answer
        .send([says("The causeway floods.").as_slice(), DONE].concat())
        .unwrap();
    let (_, ended) = follow(socket, "").await;
    assert_eq!(ended["message"]["lore"], message["lore"]);
    (message["lore"].clone(), asked.body["messages"].clone())
}

/// The text of the last message of a prompt.
pub fn last(prompt: &Value) -> &str {
    prompt.as_array().unwrap().last().unwrap()["content"]
        .as_str()
        .unwrap()
}

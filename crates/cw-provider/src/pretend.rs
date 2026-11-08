//! The pretend model: a provider built into the server, for going through
//! setup and chatting without one, and for the tests. The list of providers
//! has it as "Pretend model", whose keys begin `sk-cardwave-fake-`, at
//! `ADDRESS`, whose host never resolves (`.invalid`), so nothing asked of it
//! can leave this computer: `provider::send` hands a request for that host to
//! `answer`, which answers here as an OpenAI-compatible API does, whatever the
//! key.
//!
//! It lists `MODELS`, chat models and image models (`facts::by_name`
//! tells them apart); answers a chat with `REPLY`, a word at a time `PACE`
//! apart; each of the worker model's questions, known by its prompt's opening
//! (the server's table, which comes with the provider's client, `Http`),
//! with the answer given there; a request for a fixed answer ([`crate::form`])
//! with JSON filled from its schema, where the table has none, a marker in its
//! messages making it decline ([`DECLINE`]), cut its answer off ([`CUT_OFF`]) or
//! reject the format ([`NO_FORMAT`]); and a picture asked for with `picture`.
//! Anything else is not found (404).

use std::convert::Infallible;
use std::io::Cursor;
use std::time::Duration;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_platform::http::header::CONTENT_TYPE;
use cw_platform::http::{Body, Request, Response, ResponseBuilder};
use futures_util::{StreamExt, stream};
use serde_json::{Value, json};

use crate::Fixed;

/// Where the list of providers has it (`crates/cw-provider/providers/own.toml`).
pub const ADDRESS: &str = "https://pretend.cardwave.invalid/v1";
const HOST: &str = "pretend.cardwave.invalid";

/// The models it lists: two for chats, two for pictures.
pub const MODELS: [&str; 4] = [
    "pretend-chat",
    "pretend-chat-mini",
    "pretend-image",
    "pretend-image-mini",
];

/// What it answers every chat with.
pub const REPLY: &str = "This is Cardwave's pretend model. It gives every message this same reply, so the app can be tried without a provider.";

/// In a request for a fixed answer: the model declines it.
pub const DECLINE: &str = "[pretend: decline]";
/// In a request for a fixed answer: an answer is cut off below `WHOLE_FROM`
/// tokens of limit.
pub const CUT_OFF: &str = "[pretend: cut off]";
/// In a request for a fixed answer: `response_format` is rejected (400).
pub const NO_FORMAT: &str = "[pretend: no format]";
/// The smallest limit a [`CUT_OFF`] answer comes whole at.
const WHOLE_FROM: u64 = 16_000;

/// The time between two words of a reply.
const PACE: Duration = Duration::from_millis(30);

/// Whether `request` is for the pretend model.
pub fn asked(request: &Request) -> bool {
    request.url().host_str() == Some(HOST)
}

/// The pretend model's answer to `request`.
pub fn answer(request: &Request, table: Fixed) -> Response {
    let path = request.url().path();
    if path.ends_with("/models") {
        let data = MODELS.map(|id| json!({ "id": id, "object": "model" }));
        whole(200, json!({ "object": "list", "data": data }))
    } else if path.ends_with("/images/generations") {
        whole(
            200,
            json!({ "data": [{ "b64_json": STANDARD.encode(picture()) }] }),
        )
    } else if path.ends_with("/chat/completions") {
        let asked: Value = request
            .body()
            .and_then(Body::as_bytes)
            .and_then(|body| serde_json::from_slice(body).ok())
            .unwrap_or_default();
        match (fixed(&asked["messages"], table), schema_of(&asked)) {
            (Some(answer), _) => streamed(vec![answer.to_string()], "stop"),
            (None, Some(schema)) => fixed_answer(&asked, &schema),
            (None, None) => streamed(
                REPLY.split_inclusive(' ').map(str::to_string).collect(),
                "stop",
            ),
        }
    } else {
        whole(
            404,
            json!({ "error": { "message": "the pretend model has nothing here" } }),
        )
    }
}

/// The answer to a question of the worker model, if `messages` are one: their
/// first message holds the opening of its prompt (the picture's words come
/// after the description and the chat in it), not a later one, where a user
/// may quote it.
fn fixed(messages: &Value, table: Fixed) -> Option<&'static str> {
    let first = messages[0]["content"].as_str()?;
    table
        .iter()
        .find(|(prompt, _)| first.contains(opening(prompt)))
        .map(|(_, answer)| *answer)
}

/// The schema `asked` wants its answer in: its `response_format`, or the one
/// its system message tells ([`crate::form`]).
fn schema_of(asked: &Value) -> Option<Value> {
    let sent = &asked["response_format"]["json_schema"]["schema"];
    if !sent.is_null() {
        return Some(sent.clone());
    }
    let (_, told) = asked["messages"][0]["content"]
        .as_str()?
        .split_once(crate::form::TOLD)?;
    serde_json::from_str(told).ok()
}

/// The answer to a request for a fixed answer in `schema`, as its markers say.
fn fixed_answer(asked: &Value, schema: &Value) -> Response {
    let messages = asked["messages"].to_string();
    if messages.contains(NO_FORMAT) && !asked["response_format"].is_null() {
        let error = json!({ "error": { "message": "response_format is not supported" } });
        return whole(400, error);
    }
    if messages.contains(DECLINE) {
        let words = json!({ "refusal": "I would rather not write this." });
        return paced(vec![
            json!({ "choices": [{ "delta": words }] }),
            ended("stop"),
        ]);
    }
    let text = filled(schema).to_string();
    let short = asked["max_tokens"].as_u64().is_some_and(|l| l < WHOLE_FROM);
    if messages.contains(CUT_OFF) && short {
        let half = text.chars().take(text.chars().count() / 2).collect();
        return streamed(vec![half], "length");
    }
    streamed(vec![text], "stop")
}

/// A value of `schema`: an enumeration's first, every key of an object, a list of one.
fn filled(schema: &Value) -> Value {
    match schema["type"].as_str() {
        Some("object") => {
            let fields = schema["properties"].as_object().into_iter().flatten();
            let fields = fields.map(|(key, kind)| (key.clone(), filled(kind)));
            Value::Object(fields.collect())
        }
        Some("array") => json!([filled(&schema["items"])]),
        Some("boolean") => json!(false),
        Some("integer") => json!(1),
        _ => schema["enum"][0].as_str().unwrap_or("pretend").into(),
    }
}

/// How a prompt begins: up to its first line end or placeholder.
pub fn opening(prompt: &str) -> &str {
    prompt.split(['\n', '{']).next().unwrap_or_default().trim()
}

/// An answer of one JSON document.
pub(super) fn whole(status: u16, said: Value) -> Response {
    let answer = ResponseBuilder::new()
        .status(status)
        .header(CONTENT_TYPE, "application/json")
        .body(Body::from(said.to_string()))
        // A fixed status and header always make an answer.
        .expect("an answer");
    Response::from(answer)
}

/// A reply of `pieces` ended for the reason `finish` says, streamed.
fn streamed(pieces: Vec<String>, finish: &str) -> Response {
    let pieces = pieces
        .into_iter()
        .map(|piece| json!({ "choices": [{ "delta": { "content": piece } }] }));
    paced(pieces.chain([ended(finish)]).collect())
}

/// The last event of a reply, which says why it ended.
fn ended(finish: &str) -> Value {
    json!({ "choices": [{ "delta": {}, "finish_reason": finish }] })
}

/// `events` as server-sent events, one `PACE` after the one before.
fn paced(events: Vec<Value>) -> Response {
    let events = events
        .into_iter()
        .map(|event| format!("data: {event}\n\n"))
        .chain(["data: [DONE]\n\n".to_string()]);
    let spaced = stream::iter(events).then(|event| async move {
        tokio::time::sleep(PACE).await;
        Ok::<_, Infallible>(event)
    });
    let answer = ResponseBuilder::new()
        .status(200)
        .header(CONTENT_TYPE, "text/event-stream")
        .body(Body::wrap_stream(spaced))
        // A fixed status and header always make an answer.
        .expect("an answer");
    Response::from(answer)
}

/// A picture of 256 by 256 pixels, a blend of blue and violet, as a PNG.
fn picture() -> Vec<u8> {
    let painted = image::RgbImage::from_fn(256, 256, |x, y| {
        image::Rgb([90 + (x / 4) as u8, 110, 200 - (y / 4) as u8])
    });
    let mut png = Cursor::new(Vec::new());
    painted
        .write_to(&mut png, image::ImageFormat::Png)
        // A picture in memory always writes as a PNG.
        .expect("a picture");
    png.into_inner()
}

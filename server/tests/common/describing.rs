//! What the card-description tests share: a server whose provider is a stand-in
//! that answers the askings in turn, and the stand-in's answers.
//!
//! `classified` is what the classifier answers of the sample card, `written` what
//! the writer does, `done` waits until nothing waits to be described.

use std::time::Duration;

use serde_json::{Value, json};

use super::api::{Api, JSON, Says, says};
use super::server::{Server, start, until};

/// A model's whole answer of `content`, as one JSON document.
pub fn reply(content: &Value) -> Says {
    let text = match content {
        Value::String(text) => text.clone(),
        other => other.to_string(),
    };
    says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": text } }] }).to_string(),
    )
}

pub fn classified() -> Value {
    json!({
        "verdict": "classified",
        "reject_reason": "",
        "characters": [{ "name": "Mira", "gender": "female", "age": "unspecified" }],
        "pairing": "unspecified",
        "engine": "mystery",
        "multi_mode": false,
        "per_greeting": [{ "greeting_index": 0, "engine": "mystery", "rating": "sfw", "content_flags": [] }],
        "frame": "stranger",
        "frame_display": "stranger",
        "rating": "suggestive",
        "content_flags": ["substance-use", "made-up-flag"],
        "archetype": ["stoic", "made-up"],
        "mechanism": "keeps you inside the lighthouse",
        "confidence": 0.8,
        "evidence": "The first greeting."
    })
}

pub fn written(title: &str) -> Value {
    json!({
        "title": title,
        "logline": "A storm strands you in the lighthouse its keeper never leaves.",
        "summary": "She keeps the north light. A storm has cut you off. It is quiet and wary.",
        "tagline": "Some lights are kept for you.",
        "mood": "drama"
    })
}

/// A server whose provider is a stand-in that answers as `answers` say, in turn.
pub async fn model(answers: Vec<Says>) -> (Server, Api) {
    // The needs of a card come after its description: the last answer stands for them, unless a test's does.
    let mut answers = answers;
    answers.push(reply(
        &json!({ "verdict": "classified", "needs": [{ "need": "sex", "level": 0 }] }),
    ));
    let api = Api::start_each(answers).await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    (server, api)
}

pub async fn import(server: &Server) -> i64 {
    let (status, imported) = server.upload("/api/cards", super::card_copy()).await;
    assert_eq!(status, 201, "{imported}");
    imported["card_id"].as_i64().unwrap()
}

/// Waits until no card waits to be described, and answers how far that is.
pub async fn done(server: &Server) -> Value {
    until(|| async {
        let (status, progress) = server.get("/api/describe").await;
        assert_eq!(status, 200, "{progress}");
        match progress["waiting"] == 0 {
            true => Ok(progress),
            false => Err(format!("still describing: {progress}")),
        }
    })
    .await
}

pub async fn row(server: &Server, id: i64) -> Value {
    let (_, list) = server.get("/api/cards?show=all&posters=true").await;
    let row = list
        .as_array()
        .unwrap()
        .iter()
        .find(|card| card["id"] == id);
    row.expect("the card is not listed").clone()
}

/// The needs asker's answer of `needs`.
pub fn asked(needs: Value) -> Says {
    reply(&json!({ "verdict": "classified", "reject_reason": "", "needs": needs }))
}

pub async fn needs_of(server: &Server, id: i64) -> Value {
    server.get(&format!("/api/cards/{id}")).await.1["needs"].clone()
}

/// The needs asker's answer that finds `need`.
pub fn finds(need: &str) -> Says {
    asked(json!([{ "need": need, "quote": "Mira", "level": 3 }]))
}

/// The same answer, long enough in coming for a test to act while it is on its way.
pub fn slowly(mut says: Says) -> Says {
    says.after = Duration::from_millis(1500);
    says
}

/// Waits until `id`'s stored needs are `state`.
pub async fn needs_become(server: &Server, id: i64, state: &str) -> Value {
    until(|| async {
        let needs = needs_of(server, id).await;
        match needs["state"] == state {
            true => Ok(needs),
            false => Err(format!("needs are not {state}: {needs}")),
        }
    })
    .await
}

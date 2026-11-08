//! A card's text changed by an AI tool (`POST /api/rewrite`): the background
//! model is asked with the tool's instruction and the text, and its answer is
//! the new text, nothing stored.

mod common;

use common::api::{Api, JSON, says};
use common::server::start;
use serde_json::{Value, json};

/// A server whose chat model is a stand-in answering `answer`, and whose
/// background model is `small-1`.
async fn model(answer: &str) -> (common::server::Server, Api) {
    let api = Api::start(says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": answer } }] }).to_string(),
    ))
    .await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "big-1", "worker_model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    (server, api)
}

#[tokio::test]
async fn a_tool_asks_the_background_model_and_answers_its_text() {
    let (server, api) = model("```\nShe keeps the north light, {{user}}.\n```").await;
    let asked = json!({ "text": "She keep the north lite, {{user}}.", "tool": "fix", "what": "Description" });
    let (status, answer) = server.post("/api/rewrite", asked).await;
    assert_eq!(status, 200, "{answer}");
    // A code fence around the answer is not the text's.
    assert_eq!(answer["text"], "She keeps the north light, {{user}}.");

    let sent: Value = serde_json::from_str(&api.asked().last().unwrap().body).unwrap();
    assert_eq!(sent["model"], "small-1");
    let prompt = sent["messages"].to_string();
    assert!(prompt.contains("grammar and spelling"), "{prompt}");
    assert!(
        prompt.contains("She keep the north lite, {{user}}."),
        "{prompt}"
    );
    assert!(prompt.contains("Description"), "{prompt}");
}

#[tokio::test]
async fn a_text_that_is_a_code_fence_keeps_it() {
    let fenced = "```\n{{char}} says hi.\n```";
    let (server, _api) = model(fenced).await;
    let asked = json!({ "text": fenced, "tool": "fix", "what": "Description" });
    let (status, answer) = server.post("/api/rewrite", asked).await;
    assert_eq!(status, 200, "{answer}");
    assert_eq!(answer["text"], fenced);
}

#[tokio::test]
async fn translate_and_ask_send_what_the_user_typed() {
    let (server, api) = model("Sie hütet das Nordlicht.").await;
    let asked = json!({ "text": "She keeps the north light.", "tool": "translate", "what": "Description", "given": "German" });
    let (status, answer) = server.post("/api/rewrite", asked).await;
    assert_eq!(status, 200, "{answer}");
    assert_eq!(answer["text"], "Sie hütet das Nordlicht.");
    let sent = api.asked().last().unwrap().body.clone();
    assert!(sent.contains("German"), "{sent}");

    let asked = json!({ "text": "She keeps the north light.", "tool": "ask", "what": "Description", "given": "Make her older" });
    assert_eq!(server.post("/api/rewrite", asked).await.0, 200);
    let sent = api.asked().last().unwrap().body.clone();
    assert!(sent.contains("Make her older"), "{sent}");

    // Either without what the user typed is refused, as is an empty text.
    let asked = json!({ "text": "She keeps the north light.", "tool": "ask", "what": "Description", "given": " " });
    assert_eq!(server.post("/api/rewrite", asked).await.0, 400);
    let asked = json!({ "text": " ", "tool": "shorter", "what": "Description" });
    assert_eq!(server.post("/api/rewrite", asked).await.0, 400);
}

#[tokio::test]
async fn the_card_a_text_belongs_to_is_given_as_context() {
    let (server, api) = model("Sie hütet das Nordlicht.").await;
    let card = json!({ "name": "Guinivere", "description": "The queen's sworn sword.", "personality": "", "scenario": "The court is at feast." });
    let asked =
        json!({ "text": "Dry, watchful.", "tool": "improve", "what": "Personality", "card": card });
    let (status, answer) = server.post("/api/rewrite", asked).await;
    assert_eq!(status, 200, "{answer}");
    let sent: Value = serde_json::from_str(&api.asked().last().unwrap().body).unwrap();
    let system = sent["messages"][0]["content"].as_str().unwrap().to_string();
    for part in [
        "<name>Guinivere</name>",
        "<description>The queen's sworn sword.</description>",
        "<scenario>The court is at feast.</scenario>",
    ] {
        assert!(system.contains(part), "{system}");
    }
    // An empty text of the card is left out.
    assert!(!system.contains("<personality>"), "{system}");
}

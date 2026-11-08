//! How a chat's replies are written (`chats::set_reply`, `api/generate.rs`):
//! the side panel's reply length and Code mode, the length sent to the
//! provider as the most tokens of an answer of a model that does not think,
//! a reply never cut by Cardwave, and the thinking told apart from the reply,
//! shown as its newest sentence and never kept; a model seen thinking is kept
//! as one that thinks.

mod common;

use common::api::{Api, says};
use common::server::{Server, Socket, event, start};
use serde_json::{Value, json};

/// One piece of a streamed reply: `delta` as OpenAI's API sends it.
fn piece(delta: Value) -> String {
    format!("data: {}\n\n", json!({ "choices": [{ "delta": delta }] }))
}

/// Starts a chat with Mira at the stand-in `api`, in which the user has asked something. Returns its address.
async fn chat_at(server: &Server, api: &Api) -> String {
    chat_with(server, api, "test-model").await
}

/// [`chat_at`], with the stand-in's `model`.
async fn chat_with(server: &Server, api: &Api, model: &str) -> String {
    let provider = json!({ "base_url": api.url, "model": model, "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, version) = server.add_card(common::card_file(), false).await;
    let view = server.chat_with(&[(version, "mira")], 0).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let said = json!({ "content": "Why tonight?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    chat
}

/// The events of a reply up to its end, without its pieces of text.
async fn told(socket: &mut Socket) -> Vec<Value> {
    let mut told = Vec::new();
    loop {
        let event = event(socket).await;
        match event["type"].as_str().unwrap() {
            "reply_text" | "memories" | "provider" => {}
            "reply_ended" => {
                told.push(event);
                return told;
            }
            _ => told.push(event),
        }
    }
}

#[tokio::test]
async fn a_chat_sets_its_reply_length_and_code_mode() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", "")).await;
    let chat = chat_at(&server, &api).await;
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        (&view["chat"]["reply_length"], &view["chat"]["code_mode"]),
        (&json!(350), &json!(false))
    );

    let reply = format!("{chat}/reply");
    let (status, changed) = server
        .put(&reply, json!({ "reply_length": 800, "code_mode": true }))
        .await;
    assert_eq!(status, 200, "{changed}");
    assert_eq!(
        (&changed["reply_length"], &changed["code_mode"]),
        (&json!(800), &json!(true))
    );
    for wrong in [0, 100_001] {
        let wrong = json!({ "reply_length": wrong, "code_mode": false });
        assert_eq!(server.put(&reply, wrong).await.0, 400);
    }
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["chat"]["reply_length"], 800);
}

#[tokio::test]
async fn a_model_that_thinks_is_given_no_limit_and_its_thinking_is_told_not_kept() {
    let server = start().await;
    let thinking =
        piece(json!({ "reasoning_content": "She asks why. The tide is high! And the lamp" }));
    let mut words = piece(json!({ "content": "The tide turns tonight, " }));
    words.push_str(&piece(
        json!({ "content": "and the lamp must be lit before the dark comes in." }),
    ));
    words.push_str("data: [DONE]\n\n");
    let mut answer = says(200, "text/event-stream", &thinking);
    answer.then = Some(words);
    let api = Api::start(answer).await;
    // models.dev says it thinks.
    let chat = chat_with(&server, &api, "deepseek-v3-1").await;
    // The side panel is told, so its Reply length says it is not used.
    assert_eq!(server.get(&chat).await.1["thinks"], true);
    let short = json!({ "reply_length": 10, "code_mode": false });
    assert_eq!(server.put(&format!("{chat}/reply"), short).await.0, 200);
    let mut socket = server.listen().await;

    let (status, message) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202, "{message}");
    let told = told(&mut socket).await;
    // While it thinks, the chat is told the newest sentence that ended.
    assert_eq!(
        (&told[0]["type"], &told[0]["message_id"], &told[0]["line"]),
        (
            &json!("reply_thinking"),
            &message["id"],
            &json!("The tide is high!")
        ),
        "{told:?}"
    );
    // The whole reply, past its ten tokens: Cardwave cuts none.
    let ended = told.last().unwrap();
    assert_eq!(ended["error"], Value::Null, "{ended}");
    let content = "The tide turns tonight, and the lamp must be lit before the dark comes in.";
    assert_eq!(ended["message"]["content"], content, "{ended}");
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        view["messages"].as_array().unwrap().last().unwrap()["content"],
        content
    );
    // No `max_tokens`, which would count the thinking.
    let asked: Value = serde_json::from_str(&api.asked()[0].body).unwrap();
    assert!(asked.get("max_tokens").is_none(), "{asked}");
}

#[tokio::test]
async fn a_model_seen_thinking_is_given_no_limit_from_then_on() {
    let server = start().await;
    let mut answer = piece(json!({ "reasoning_content": "She asks why." }));
    answer.push_str(&piece(json!({ "content": "The tide turns tonight." })));
    answer.push_str(
        "data: [DONE]

",
    );
    let api = Api::start(says(200, "text/event-stream", &answer)).await;
    // Neither models.dev nor its name says it thinks.
    let chat = chat_with(&server, &api, "my-rig-7b").await;
    assert_eq!(server.get(&chat).await.1["thinks"], false);
    let mut socket = server.listen().await;
    for limit in [json!(350), Value::Null] {
        let (status, message) = server.post(&format!("{chat}/generate"), json!({})).await;
        assert_eq!(status, 202, "{message}");
        let ended = told(&mut socket).await.pop().unwrap();
        assert_eq!(ended["error"], Value::Null, "{ended}");
        let asked: Value = serde_json::from_str(&api.asked().last().unwrap().body).unwrap();
        assert_eq!(asked["max_tokens"], limit, "{asked}");
    }
    assert_eq!(server.get(&chat).await.1["thinks"], true);
}

#[tokio::test]
async fn a_model_that_does_not_think_is_given_the_reply_length_where_offered_no_tool_but_the_dice()
{
    let server = start().await;
    let mut words = piece(json!({ "content": "The tide turns tonight, " }));
    words.push_str(&piece(
        json!({ "content": "and the lamp must be lit before the dark comes in." }),
    ));
    words.push_str("data: [DONE]\n\n");
    let api = Api::start(says(200, "text/event-stream", &words)).await;
    let chat = chat_at(&server, &api).await;
    let dice = json!({ "tools": { "dice": true } });
    assert_eq!(server.patch("/api/settings", dice).await.0, 200);
    // The side panel is told that the length is sent: the model does not think and no tool but the dice is on.
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        (&view["thinks"], &view["tools"]),
        (&json!(false), &json!(false))
    );
    let mut socket = server.listen().await;
    for (code_mode, limit) in [(false, json!(10)), (true, Value::Null)] {
        let reply = json!({ "reply_length": 10, "code_mode": code_mode });
        assert_eq!(server.put(&format!("{chat}/reply"), reply).await.0, 200);
        let (status, message) = server.post(&format!("{chat}/generate"), json!({})).await;
        assert_eq!(status, 202, "{message}");
        let told = told(&mut socket).await;
        // What the provider sends is the reply, as long as it is.
        let ended = told.last().unwrap();
        assert_eq!(
            ended["message"]["content"],
            "The tide turns tonight, and the lamp must be lit before the dark comes in.",
            "{ended}"
        );
        // Code mode offers a tool (`make_tool`), whose call is not to be cut short; the dice are not.
        let asked: Value = serde_json::from_str(&api.asked().last().unwrap().body).unwrap();
        assert_eq!(asked["max_tokens"], limit, "{asked}");
        assert_eq!(asked["tools"][0]["function"]["name"], "dice", "{asked}");
    }
    // A tool of the settings is on: the panel is told by the rule the reply goes by.
    let web = json!({ "tools": { "web": true } });
    assert_eq!(server.patch("/api/settings", web).await.0, 200);
    assert_eq!(server.get(&chat).await.1["tools"], true);
}

#[tokio::test]
async fn a_think_part_at_the_start_of_the_words_is_no_part_of_the_reply() {
    let server = start().await;
    let mut body = String::new();
    for text in ["<thi", "nk>Plan the answer.</th", "ink>\n\nIt is late."] {
        body.push_str(&piece(json!({ "content": text })));
    }
    body.push_str("data: [DONE]\n\n");
    let api = Api::start(says(200, "text/event-stream", &body)).await;
    let chat = chat_at(&server, &api).await;
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let told = told(&mut socket).await;
    assert_eq!(
        told.last().unwrap()["message"]["content"],
        "It is late.",
        "{told:?}"
    );
}

#[tokio::test]
async fn a_reply_ends_at_done_though_the_server_sends_on() {
    let server = start().await;
    let mut body = piece(json!({ "content": "It is late." }));
    body.push_str("data: [DONE]\n\n: still here");
    let mut answer = says(200, "text/event-stream", &body);
    answer.endless = true;
    let api = Api::start(answer).await;
    let chat = chat_at(&server, &api).await;
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let told = told(&mut socket).await;
    assert_eq!(
        told.last().unwrap()["message"]["content"],
        "It is late.",
        "{told:?}"
    );
}

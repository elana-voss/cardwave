//! The companion (`companion.rs`): the card its figure is and its mute, kept
//! with the settings, and its animator (the chat model after a reply, else the
//! worker model), which answers what the
//! figure does after a reply in its card's chats (not another card's), after
//! the hand handled it and while it stands idle, as steps the window can run,
//! told the persona, Cardwave's screen and its last steps; and the companion
//! as one interface: what it knows (`/api/companion/state`) and does
//! (`/api/companion/act`), which a test's socket answers as its window would.
//!
//! `Model` stands in for a model's server: it answers the animator with
//! `steps` and notes what it was asked; it answers no other question.

mod common;

use std::sync::{Arc, Mutex};

use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use common::server::{Server, event, start};
use serde_json::{Value, json};
use tokio::net::TcpListener;

/// How the animator's question is told apart, by its system prompt's start.
const ANIMATOR: &str = "You move a character's figure";

struct Model {
    url: String,
    asked: Arc<Mutex<Vec<Value>>>,
}

impl Model {
    async fn start(answer: &'static str) -> Self {
        let asked: Arc<Mutex<Vec<Value>>> = Arc::default();
        let log = asked.clone();
        let complete = move |Json(body): Json<Value>| async move {
            let system = body["messages"][0]["content"].as_str().unwrap_or_default();
            assert!(
                system.starts_with(ANIMATOR),
                "asked something else: {system}"
            );
            log.lock().unwrap().push(body);
            let piece = json!({ "choices": [{ "delta": { "content": answer } }] });
            let stream = format!("data: {piece}\n\ndata: [DONE]\n\n");
            ([(header::CONTENT_TYPE, "text/event-stream")], stream).into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(complete));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }
}

/// A new card of `name` with `description`, at the provider `model`: its
/// version and character, as a new chat names them.
async fn card(server: &Server, model: &Model, name: &str, description: &str) -> Value {
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let card = json!({ "title": name, "tags": [], "creator": "", "name": name, "greetings": ["Hello, you."], "description": description, "personality": "", "scenario": "", "example_dialogue": "", "creator_notes": "" });
    let (status, made) = server.post("/api/cards/new", card).await;
    assert_eq!(status, 201, "{made}");
    let (_, shown) = server.get(&format!("/api/cards/{}", made["card_id"])).await;
    json!({ "card_id": made["card_id"], "version_id": shown["card"]["version_id"], "character": shown["characters"][0]["id"] })
}

/// A new card of Gwen made the companion, at the provider `model`.
async fn gwen(server: &Server, model: &Model, description: &str) -> Value {
    let made = card(server, model, "Gwen", description).await;
    let companion = json!({ "card_id": made["card_id"], "starts": false, "hidden_until": null });
    let (status, set) = server
        .patch("/api/settings", json!({ "companion": companion }))
        .await;
    assert_eq!(status, 200, "{set}");
    made
}

/// A chat with `made` (`card`): the chat's number.
async fn chat_with(server: &Server, made: &Value) -> i64 {
    let new = json!({ "characters": [{ "version_id": made["version_id"], "character": made["character"] }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    view["chat"]["id"].as_i64().unwrap()
}

/// A chat with a new card of Gwen, the companion, at the provider `model`: the chat's number.
async fn chat(server: &Server, model: &Model) -> i64 {
    let made = gwen(server, model, "").await;
    chat_with(server, &made).await
}

/// The model the animator was asked of, the `nth` time.
fn asked_of(model: &Model, nth: usize) -> String {
    model.asked.lock().unwrap()[nth]["model"]
        .as_str()
        .unwrap()
        .to_string()
}

/// The animator's question, the `nth` it was asked.
fn question(model: &Model, nth: usize) -> String {
    model.asked.lock().unwrap()[nth]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string()
}

#[tokio::test]
async fn the_companion_whether_it_starts_with_the_app_its_figure_its_size_and_its_mute_are_kept_with_the_settings()
 {
    let server = start().await;
    let (_, before) = server.get("/api/settings").await;
    assert_eq!(
        before["companion"],
        json!({ "card_id": null, "starts": false, "hidden_until": null, "figure": "woman", "size": 21, "muted": false })
    );
    let companion = json!({ "card_id": 4, "starts": true, "hidden_until": "2026-10-16", "figure": "man", "size": 35, "muted": true });
    let (status, after) = server
        .patch("/api/settings", json!({ "companion": companion }))
        .await;
    assert_eq!(status, 200, "{after}");
    assert_eq!(after["companion"], companion);
    // Shown again: the day it was hidden until is gone, the rest stays.
    let shown = json!({ "card_id": 4, "starts": true, "hidden_until": null, "figure": "robot", "size": 35, "muted": true });
    let (_, after) = server
        .patch("/api/settings", json!({ "companion": shown }))
        .await;
    assert_eq!(after["companion"], shown);
    // A size outside 10 to 50 percent of the screen's height is refused, and the one kept stays.
    for size in [9, 51] {
        let mut asked = shown.clone();
        asked["size"] = json!(size);
        let (status, said) = server
            .patch("/api/settings", json!({ "companion": asked }))
            .await;
        assert_eq!(status, 400, "{said}");
    }
    let (_, kept) = server.get("/api/settings").await;
    assert_eq!(kept["companion"], shown);
}

#[tokio::test]
async fn the_animator_is_told_the_screen_and_the_newest_messages_and_its_steps_are_kept_where_they_can_run()
 {
    let answer = r#"Here: {"steps": [
        {"do": "walk", "x": 5000},
        {"do": "play", "clip": "wave"},
        {"do": "say", "text": "  Hi  "},
        {"do": "fly", "to": "moon"},
        {"do": "play", "clip": "backflip"},
        {"do": "climb", "side": "left", "height": 1.7},
        {"do": "wait", "ms": 600000},
        {"do": "let_go"},
        {"do": "walk", "x": 20},
        {"do": "walk", "x": 30}
    ]}"#;
    let model = Model::start(answer).await;
    let server = start().await;
    let id = chat(&server, &model).await;
    let asked =
        json!({ "chat_id": id, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle" });
    let (status, planned) = server.post("/api/companion/plan", asked).await;
    assert_eq!(status, 200, "{planned}");
    // Each step kept within the screen and the limits, those it cannot run left out, and no more than six.
    assert_eq!(
        planned["steps"],
        json!([
            { "do": "walk", "x": 1600.0 },
            { "do": "play", "clip": "wave" },
            { "do": "say", "text": "Hi" },
            { "do": "climb", "side": "left", "height": 1.0 },
            { "do": "wait", "ms": 10000 },
            { "do": "let_go" },
        ])
    );
    let question = model.asked.lock().unwrap()[0]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string();
    for told in ["Gwen", "Hello, you.", "1600", "900", "300", "idle"] {
        assert!(question.contains(told), "{told} is not in {question}");
    }
}

#[tokio::test]
async fn an_answer_without_steps_is_no_steps() {
    let model = Model::start("I would rather not move.").await;
    let server = start().await;
    let id = chat(&server, &model).await;
    let asked =
        json!({ "chat_id": id, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle" });
    let (status, planned) = server.post("/api/companion/plan", asked).await;
    assert_eq!(status, 200, "{planned}");
    assert_eq!(planned["steps"], json!([]));
}

#[tokio::test]
async fn after_the_hand_handled_the_figure_the_animator_is_told_what_it_did_in_the_companions_newest_chat()
 {
    let model = Model::start(r#"{"steps": [{"do": "play", "clip": "no"}]}"#).await;
    let server = start().await;
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "handled", "handled": ["held", "shaken", "thrown", "hit_edge", "landed"] });
    // Without a companion nothing is asked.
    let (status, planned) = server.post("/api/companion/plan", asked.clone()).await;
    assert_eq!(status, 200, "{planned}");
    assert_eq!(planned["steps"], json!([]));
    assert!(model.asked.lock().unwrap().is_empty());

    chat(&server, &model).await;
    let (status, planned) = server.post("/api/companion/plan", asked).await;
    assert_eq!(status, 200, "{planned}");
    assert_eq!(planned["steps"], json!([{ "do": "play", "clip": "no" }]));
    let question = model.asked.lock().unwrap()[0]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string();
    for told in [
        "Gwen",
        "Hello, you.",
        "picked it up, shook it, threw it, it hit the edge of the screen, it landed",
    ] {
        assert!(question.contains(told), "{told} is not in {question}");
    }
}

#[tokio::test]
async fn left_alone_before_any_chat_the_animator_is_told_the_persona_the_screen_how_long_and_its_last_moves()
 {
    let model = Model::start(r#"{"steps": [{"do": "say", "text": "Hm."}]}"#).await;
    let server = start().await;
    gwen(&server, &model, "Gwen loves the sea and old maps.").await;
    let app = json!({ "route": "#/library", "title": "Library" });
    assert_eq!(server.put("/api/companion/app", app).await.0, 204);
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "alone", "alone_s": 95 });
    let (status, planned) = server.post("/api/companion/plan", asked.clone()).await;
    assert_eq!(status, 200, "{planned}");
    assert_eq!(planned["steps"], json!([{ "do": "say", "text": "Hm." }]));
    let first = question(&model, 0);
    for told in [
        "Gwen loves the sea and old maps.",
        "Library",
        "#/library",
        "it stands about alone",
        "95 s",
    ] {
        assert!(first.contains(told), "{told} is not in {first}");
    }
    // Asked again, it is told what it did the last time.
    server.post("/api/companion/plan", asked).await;
    let second = question(&model, 1);
    assert!(second.contains(r#"{"do":"say","text":"Hm."}"#), "{second}");
}

#[tokio::test]
async fn the_animator_is_told_the_persona_of_the_companions_newest_version() {
    let model = Model::start(r#"{"steps": []}"#).await;
    let server = start().await;
    let made = gwen(&server, &model, "Gwen loves the sea.").await;
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "alone", "alone_s": 30 });
    server.post("/api/companion/plan", asked.clone()).await;
    assert!(question(&model, 0).contains("Gwen loves the sea."));
    let path = format!("/api/cards/{}/edit", made["card_id"]);
    let (_, mut form) = server.get(&path).await;
    form["characters"][0]["description"][0]["text"] = json!("Gwen fears the dark.");
    let (status, saved) = server.put(&path, form).await;
    assert_eq!(status, 200, "{saved}");
    server.post("/api/companion/plan", asked).await;
    let second = question(&model, 1);
    assert!(second.contains("Gwen fears the dark."), "{second}");
}

#[tokio::test]
async fn a_reply_in_a_chat_that_is_not_the_companions_has_it_do_nothing() {
    let model = Model::start(r#"{"steps": [{"do": "play", "clip": "wave"}]}"#).await;
    let server = start().await;
    gwen(&server, &model, "").await;
    let other = card(&server, &model, "Mira", "").await;
    let id = chat_with(&server, &other).await;
    let asked = json!({ "chat_id": id, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "reply" });
    let (status, planned) = server.post("/api/companion/plan", asked).await;
    assert_eq!(status, 200, "{planned}");
    assert_eq!(planned["steps"], json!([]));
    assert!(model.asked.lock().unwrap().is_empty());
}

#[tokio::test]
async fn the_animator_is_told_at_most_sixteen_stages_of_a_handling() {
    let model = Model::start(r#"{"steps": []}"#).await;
    let server = start().await;
    let id = chat(&server, &model).await;
    let handled: Vec<&str> = std::iter::repeat_n(["held", "shaken"], 50)
        .flatten()
        .collect();
    let asked = json!({ "chat_id": id, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "handled", "handled": handled });
    let (status, planned) = server.post("/api/companion/plan", asked).await;
    assert_eq!(status, 200, "{planned}");
    let question = model.asked.lock().unwrap()[0]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string();
    assert_eq!(question.matches("shook it").count(), 8, "{question}");
}

/// What the companion window says of its figure, as it has begun the act `acted`.
fn figure(acted: u64) -> Value {
    json!({ "width": 1600, "height": 900, "x": 400, "y": 900, "state": "idle", "clip": "idle", "looking": null, "feeling": null, "saying": null, "steps": [], "chat_open": false, "acted": acted })
}

#[tokio::test]
async fn an_act_reaches_the_companion_window_held_within_its_screen_and_answers_what_it_knows_once_begun()
 {
    let model = Model::start(r#"{"steps": []}"#).await;
    let server = start().await;
    // No window shows the figure: nothing is known of it, and an act is refused.
    let (status, known) = server.get("/api/companion/state").await;
    assert_eq!(status, 200, "{known}");
    assert_eq!(
        known,
        json!({ "shown": false, "figure": null, "app": null, "chat": null })
    );
    let walk = json!({ "steps": [{ "do": "walk", "x": 9000 }, { "do": "say", "text": "Hi" }] });
    let (status, refused) = server.post("/api/companion/act", walk.clone()).await;
    assert_eq!(status, 400, "{refused}");
    assert_eq!(refused["details"]["what"], "companion_not_shown");

    chat(&server, &model).await;
    let app = json!({ "route": "#/library", "title": "Library" });
    assert_eq!(server.put("/api/companion/app", app.clone()).await.0, 204);
    assert_eq!(server.put("/api/companion/live", figure(0)).await.0, 204);
    let mut window = server.listen().await;
    let answering = async {
        let told = loop {
            let told = event(&mut window).await;
            if told["type"] == "companion_act" {
                break told;
            }
        };
        assert_eq!(
            told["steps"],
            json!([{ "do": "walk", "x": 1600.0 }, { "do": "say", "text": "Hi" }])
        );
        let mut now = figure(told["act"].as_u64().unwrap());
        now["saying"] = json!("Hi");
        assert_eq!(server.put("/api/companion/live", now).await.0, 204);
    };
    let ((status, known), ()) = tokio::join!(server.post("/api/companion/act", walk), answering);
    assert_eq!(status, 200, "{known}");
    assert_eq!(known["shown"], true);
    assert_eq!(known["figure"]["saying"], "Hi");
    assert_eq!(known["app"], app);
    assert_eq!(known["chat"]["character"], "Gwen");
    assert_eq!(
        known["chat"]["said"],
        json!([{ "who": "Gwen", "text": "Hello, you." }])
    );
}

#[tokio::test]
async fn an_act_the_window_does_not_begin_is_refused() {
    let server = start().await;
    assert_eq!(server.put("/api/companion/live", figure(0)).await.0, 204);
    let (status, refused) = server
        .post("/api/companion/act", json!({ "steps": [{ "do": "look" }] }))
        .await;
    assert_eq!(status, 400, "{refused}");
    assert_eq!(refused["details"]["what"], "companion_not_answering");
}

#[tokio::test]
async fn after_a_reply_the_animator_is_asked_of_the_chat_model_and_else_of_the_helper_model() {
    let model = Model::start(r#"{"steps": []}"#).await;
    let server = start().await;
    let id = chat(&server, &model).await;
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test", "worker_model": "helper-model" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let figure =
        json!({ "chat_id": id, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle" });
    for occasion in ["reply", "handled", "alone"] {
        let mut asked = figure.clone();
        asked["occasion"] = json!(occasion);
        let (status, planned) = server.post("/api/companion/plan", asked).await;
        assert_eq!(status, 200, "{planned}");
    }
    assert_eq!(asked_of(&model, 0), "test-model");
    assert_eq!(asked_of(&model, 1), "helper-model");
    assert_eq!(asked_of(&model, 2), "helper-model");
}

#[tokio::test]
async fn in_a_group_chat_begun_with_another_card_the_animator_is_told_the_companions_character() {
    let model = Model::start(r#"{"steps": []}"#).await;
    let server = start().await;
    let ann = card(&server, &model, "Ann", "").await;
    let gwen = gwen(&server, &model, "").await;
    let both = [&ann, &gwen]
        .map(|made| json!({ "version_id": made["version_id"], "character": made["character"] }));
    let (status, view) = server
        .post("/api/chats", json!({ "characters": both }))
        .await;
    assert_eq!(status, 201, "{view}");
    let asked = json!({ "chat_id": null, "width": 1600, "height": 900, "x": 300, "y": 900, "state": "idle", "occasion": "alone", "alone_s": 30 });
    server.post("/api/companion/plan", asked).await;
    let told = question(&model, 0);
    assert!(told.contains("<character>Gwen</character>"), "{told}");
}

//! "Make a character together" over HTTP: a new interview, a step, a refused step,
//! no provider, the read-back, "That's not it", the writing with its refusal and
//! another model. The questions and the writing itself are the engine's tests.

mod common;

use common::server::start;
use cw_provider::pretend;
use serde_json::{Value, json};

async fn with_pretend() -> common::server::Server {
    let server = start().await;
    let provider = json!({ "base_url": pretend::ADDRESS, "model": "pretend-chat", "api_key": "sk-cardwave-fake-0000" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    server
}

fn answer(free: &str) -> Value {
    json!({ "answer": { "picks": [], "free": free } })
}

#[tokio::test]
async fn an_interview_starts_in_the_settings_style_and_tells_who_gets_the_answers() {
    let server = with_pretend().await;
    let (status, started) = server.get("/api/interview").await;
    assert_eq!(status, 200);
    assert_eq!(started["interview"]["style"], "tree");
    assert_eq!(started["interview"]["asking"]["slot"], "wanted");
    assert!(started["goes_to"].is_string());
    assert!(started["kinds"].as_array().unwrap().len() > 6);

    let cloud = json!({ "interview_style": "cloud" });
    assert_eq!(server.patch("/api/settings", cloud).await.0, 200);
    let (_, started) = server.get("/api/interview").await;
    assert_eq!(started["interview"]["style"], "cloud");
}

#[tokio::test]
async fn a_step_gives_the_next_state_and_no_provider_is_not_set_up() {
    let server = with_pretend().await;
    let (_, started) = server.get("/api/interview").await;
    let body = json!({ "interview": started["interview"], "language": "en", "action": answer("A friend who listens to me") });
    let (status, next) = server.post("/api/interview/step", body.clone()).await;
    assert_eq!(status, 200);
    assert_eq!(next["log"][0]["slot"], "wanted");
    assert!(next["asking"].is_object());

    assert_eq!(start().await.get("/api/interview").await.0, 424);
}

#[tokio::test]
async fn a_step_with_no_question_open_is_refused() {
    let server = with_pretend().await;
    let (_, started) = server.get("/api/interview").await;
    let mut ended = started["interview"].clone();
    ended["asking"] = Value::Null;
    let body = json!({ "interview": ended, "language": "en", "action": answer("late") });
    assert_eq!(server.post("/api/interview/step", body).await.0, 400);
}

/// An interview of one answered question, the rest left: "Just make it".
async fn answered(server: &common::server::Server, words: &str) -> Value {
    let (_, started) = server.get("/api/interview").await;
    let body =
        json!({ "interview": started["interview"], "language": "en", "action": answer(words) });
    let (status, next) = server.post("/api/interview/step", body).await;
    assert_eq!(status, 200, "{next}");
    let body = json!({ "interview": next, "language": "en", "action": "just_make_it" });
    let (status, ended) = server.post("/api/interview/step", body).await;
    assert_eq!(status, 200, "{ended}");
    assert!(ended["asking"].is_null());
    ended
}

fn write_body(interview: &Value, other_model: Value) -> Value {
    json!({
        "interview": interview,
        "lines": [{ "sentence": "A friend", "words": "friend", "gap": false }],
        "verdicts": ["keep"],
        "private": { "open": false, "rows": [{ "topic": { "id": "pick-romance" }, "answer": "yes", "never": false }], "free": "" },
        "other_model": other_model,
    })
}

#[tokio::test]
async fn the_start_gives_the_private_lists_topics_and_the_picks_that_stand_alone() {
    let (_, started) = with_pretend().await.get("/api/interview").await;
    assert_eq!(started["topics"].as_array().unwrap().len(), 13);
    assert_eq!(started["alone"][0]["id"], "pick-any-time");
}

#[tokio::test]
async fn a_read_back_gives_lines_with_their_question_and_not_it_changes_the_answer() {
    let server = with_pretend().await;
    let interview = answered(&server, "A friend who listens").await;
    let (status, back) = server
        .post(
            "/api/interview/read-back",
            json!({ "interview": interview }),
        )
        .await;
    assert_eq!(status, 200, "{back}");
    let lines = back["lines"].as_array().unwrap();
    assert_eq!(lines.len(), back["questions"].as_array().unwrap().len());

    let body =
        json!({ "interview": interview, "question": 0, "action": answer("A rival who teases") });
    let (status, next) = server.post("/api/interview/not-it", body).await;
    assert_eq!(status, 200, "{next}");
    assert_eq!(next["interview"]["log"][0]["free"], "A rival who teases");
    assert!(next["read_back"]["lines"].is_array());
    assert_eq!(next["interview"]["read"]["character"], "unknown");

    let body = json!({ "interview": interview, "question": 9, "action": answer("late") });
    assert_eq!(server.post("/api/interview/not-it", body).await.0, 400);
}

#[tokio::test]
async fn writing_makes_a_card_and_says_what_to_offer_for_the_persona() {
    let server = with_pretend().await;
    let interview = answered(&server, "A friend who listens").await;
    let (status, written) = server
        .post("/api/interview/write", write_body(&interview, Value::Null))
        .await;
    assert_eq!(status, 201, "{written}");
    let id = written["card_id"].as_i64().unwrap();
    assert!(written["persona"].is_array());
    let (status, card) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(status, 200);
    // The card's creator is the account that answered the interview.
    let (_, account) = server.get("/api/account").await;
    assert_eq!(card["creator"], account["name"], "{card}");
}

#[tokio::test]
async fn a_refusal_names_the_model_and_another_model_is_used_for_that_writing_only() {
    let server = with_pretend().await;
    let marked = format!("A friend {}", pretend::DECLINE);
    let interview = answered(&server, &marked).await;
    let (status, failed) = server
        .post("/api/interview/write", write_body(&interview, Value::Null))
        .await;
    assert_eq!(status, 400, "{failed}");
    assert_eq!(failed["code"], "model_declined");
    assert_eq!(failed["details"]["model"], "pretend-chat");

    let (_, list) = server.get("/api/provider-list").await;
    let id = &list["providers"][0]["id"];
    let other = json!({ "provider_id": id, "model": "pretend-other" });
    let (_, failed) = server
        .post("/api/interview/write", write_body(&interview, other))
        .await;
    assert_eq!(failed["details"]["model"], "pretend-other");
    let (_, chat) = server.get("/api/provider").await;
    assert_eq!(chat["model"], "pretend-chat");
}

#[tokio::test]
async fn a_card_the_interview_made_is_asked_its_needs() {
    let server = with_pretend().await;
    let interview = answered(&server, "A friend who listens").await;
    let (status, written) = server
        .post("/api/interview/write", write_body(&interview, Value::Null))
        .await;
    assert_eq!(status, 201, "{written}");
    let path = format!("/api/cards/{}", written["card_id"]);
    let end = tokio::time::Instant::now() + common::server::WAIT;
    while server.get(&path).await.1["needs"]["state"] != "zero" {
        assert!(tokio::time::Instant::now() < end, "its needs are not asked");
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
}

#[tokio::test]
async fn texts_go_as_ids_and_an_unknown_id_is_refused() {
    let server = with_pretend().await;
    let (_, started) = server.get("/api/interview").await;
    assert!(
        started["kinds"][0]["id"]
            .as_str()
            .unwrap()
            .starts_with("pick-")
    );
    assert!(
        started["topics"][0]["id"]
            .as_str()
            .unwrap()
            .starts_with("pick-")
    );
    assert!(started["interview"]["asking"]["question"]["id"].is_string());
    let unknown = json!({ "answer": { "picks": [{ "id": "pick-nothing-such" }], "free": "" } });
    let body = json!({ "interview": started["interview"], "language": "en", "action": unknown });
    let status = server.post("/api/interview/step", body).await.0;
    assert!((400..500).contains(&status), "{status}");
}

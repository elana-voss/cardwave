//! First run's picks (`POST /api/provider/picks`): the rules' candidates of
//! each kind, by models.dev's list, and the final picks by the rules' first chat
//! model in one request; models.dev's list fetched at most once a day. No test
//! asks a provider or models.dev: both are a server of the test's own.

mod common;

use common::api::{Api, JSON, says};
use common::server::{Server, start, start_asking};
use serde_json::{Value, json};

const STREAM: &str = "text/event-stream";

/// A reply streamed as OpenAI's API sends it, in one piece.
fn streamed(text: &str) -> String {
    let piece = json!({ "choices": [{ "delta": { "content": text } }] });
    format!("data: {piece}\n\ndata: [DONE]\n\n")
}

/// A provider listing `models`, whose model answers `reply`, with models.dev's list `listed` where given.
async fn provider(models: &[&str], reply: &str, listed: Option<Value>) -> Api {
    let data: Vec<Value> = models.iter().map(|id| json!({ "id": id })).collect();
    let mut routes = vec![
        (
            "/v1/models",
            says(200, JSON, &json!({ "data": data }).to_string()),
        ),
        ("/chat/completions", says(200, STREAM, &streamed(reply))),
    ];
    if let Some(listed) = listed {
        routes.push(("/models.dev/api.json", says(200, JSON, &listed.to_string())));
    }
    Api::start_routed(routes).await
}

async fn picks(server: &Server, api: &Api) -> Value {
    let (status, picks) = server
        .post(
            "/api/provider/picks",
            json!({ "base_url": api.url, "api_key": "key-1" }),
        )
        .await;
    assert_eq!(status, 200, "{picks}");
    picks
}

/// The models the chat requests were of, and the last one's request.
fn asked_chats(api: &Api) -> (Vec<String>, Value) {
    let chats: Vec<Value> = api
        .asked()
        .into_iter()
        .filter(|asked| asked.path.ends_with("/chat/completions"))
        .map(|asked| serde_json::from_str(&asked.body).unwrap())
        .collect();
    let models = chats
        .iter()
        .map(|chat| chat["model"].as_str().unwrap().to_string())
        .collect();
    (models, chats.last().cloned().unwrap_or_default())
}

const OPENAI: [&str; 5] = ["dall-e-3", "gpt-4o", "gpt-5", "gpt-5-mini", "gpt-image-1"];

#[tokio::test]
async fn the_rules_first_chat_model_makes_the_final_picks_among_the_candidates() {
    let answer = r#"Here: {"chat": "gpt-4o", "background": "gpt-5-mini", "images": "dall-e-3"}"#;
    let api = provider(&OPENAI, answer, None).await;
    let server = start().await;
    let mut picked = picks(&server, &api).await;
    // The models' names: provider_models.rs.
    picked.as_object_mut().unwrap().remove("names");
    assert_eq!(
        picked,
        json!({ "chat": "gpt-4o", "background": "gpt-5-mini", "images": "dall-e-3", "listed": 5, "failed": null })
    );
    // One request, of the newest chat model by models.dev's list, with the candidates of each kind.
    let (models, request) = asked_chats(&api);
    assert_eq!(models, ["gpt-5"]);
    let lists = request["messages"][1]["content"].as_str().unwrap();
    assert!(
        lists.starts_with("chat:\n- gpt-5 (released 2025-08-07"),
        "{lists}"
    );
    assert!(lists.contains("background:\n- gpt-5-mini"), "{lists}");
    assert!(lists.contains("images:\n- gpt-image-1"), "{lists}");
    assert!(!lists.contains("chat:\n- gpt-5-mini"), "{lists}");
}

#[tokio::test]
async fn an_answer_that_names_no_candidate_leaves_the_rules_picks() {
    let api = provider(&OPENAI, "I like them all.", None).await;
    let server = start().await;
    let mut picked = picks(&server, &api).await;
    // The models' names: provider_models.rs.
    picked.as_object_mut().unwrap().remove("names");
    // The newest of each kind, and as background the cheap model of the chat model's maker.
    assert_eq!(
        picked,
        json!({ "chat": "gpt-5", "background": "gpt-5-mini", "images": "gpt-image-1", "listed": 5, "failed": null })
    );
    // A list that does not come is told, with nothing picked and nothing asked.
    let refused = Api::start(says(401, JSON, r#"{"error": {"message": "bad key"}}"#)).await;
    let picked = picks(&server, &refused).await;
    assert_eq!(
        (&picked["chat"], &picked["listed"]),
        (&Value::Null, &json!(0))
    );
    assert_eq!(picked["failed"]["code"], "answered", "{picked}");
    assert!(asked_chats(&refused).0.is_empty());
}

#[tokio::test]
async fn models_devs_list_is_fetched_at_most_once_a_day_and_kept() {
    let listed = json!({ "reef": { "models": {
        "tide-1": { "id": "tide-1", "release_date": "2025-01-01" },
        "tide-2": { "id": "tide-2", "release_date": "2026-01-01" } } } });
    let api = provider(&["tide-1", "tide-2"], "no", Some(listed)).await;
    let server = start_asking(Some(api.url.clone())).await;
    // Unknown to the shipped list, tide-1 came first by its name; the list fetched knows tide-2 is newer.
    assert_eq!(picks(&server, &api).await["chat"], "tide-2");
    assert_eq!(picks(&server, &api).await["chat"], "tide-2");
    let fetched = api
        .asked()
        .iter()
        .filter(|asked| asked.path.ends_with("/models.dev/api.json"))
        .count();
    assert_eq!(fetched, 1);
    assert!(server.dir.join("models.dev.json").exists());
}

#[tokio::test]
async fn a_kept_list_of_the_day_that_does_not_read_is_fetched_anew() {
    let listed = json!({ "reef": { "models": {
        "tide-1": { "id": "tide-1", "release_date": "2025-01-01" },
        "tide-2": { "id": "tide-2", "release_date": "2026-01-01" } } } });
    let api = provider(&["tide-1", "tide-2"], "no", Some(listed)).await;
    let server = start_asking(Some(api.url.clone())).await;
    // Cut short, as by a crash while it was written.
    std::fs::write(server.dir.join("models.dev.json"), "{\"reef\": {").unwrap();
    assert_eq!(picks(&server, &api).await["chat"], "tide-2");
    let fetched = api
        .asked()
        .iter()
        .filter(|asked| asked.path.ends_with("/models.dev/api.json"))
        .count();
    assert_eq!(fetched, 1);
}

//! This computer's models (`provider::local`): a folder's GGUF files as chat
//! models, run by a stand-in that answers as `llama-server` does. What runs
//! them is the process's, so these tests run one at a time (`ONE`).

mod common;

use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use axum::Router;
use axum::body::Body;
use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use common::server::{Server, device, event, start_searching};
use cw_modelfiles::ModelFile;
use cw_prompt::{PromptMessage, Role};
use cw_provider::embedder::{Runner, Setup};
use cw_provider::{self as provider, Provider, Sampling, local};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::net::TcpListener;
use tokio::sync::Mutex;

static ONE: Mutex<()> = Mutex::const_new(());

/// How often the stand-in was asked whether it is up.
static HEALTH: AtomicUsize = AtomicUsize::new(0);

/// A stand-in for `llama-server`: it is ready at once, and replies to a chat
/// "Hello from [the model asked for]", or, offered tools, to "Write the plan."
/// by writing the file `plan.txt`.
async fn stand_in() -> String {
    async fn chat(axum::Json(asked): axum::Json<Value>) -> impl IntoResponse {
        let last = asked["messages"].as_array().unwrap().last().unwrap();
        let piece = if asked["tools"].is_array() && last["content"] == "Write the plan." {
            let arguments = json!({ "path": "plan.txt", "content": "Sail at dawn." }).to_string();
            json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "id": "call_1", "type": "function", "function": { "name": "write_file", "arguments": arguments } }] } }] })
        } else {
            json!({ "choices": [{ "delta": { "content": format!("Hello from {}", asked["model"].as_str().unwrap()) } }] })
        };
        let events = format!("data: {piece}\n\ndata: [DONE]\n\n");
        (
            [(header::CONTENT_TYPE, "text/event-stream")],
            Body::from(events),
        )
    }
    let app = Router::new()
        .route(
            "/health",
            get(|| async {
                HEALTH.fetch_add(1, Ordering::SeqCst);
                "ok"
            }),
        )
        .route("/v1/chat/completions", post(chat));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    url
}

/// A server whose models run at a stand-in, and a folder of model files.
async fn started() -> (Server, std::path::PathBuf) {
    let search = Setup {
        model: ModelFile {
            url: String::new(),
            size: 0,
            sha256: String::new(),
        },
        runner: Runner::At(stand_in().await),
    };
    let server = start_searching(search).await;
    let folder = server.dir.join("my models");
    std::fs::create_dir_all(&folder).unwrap();
    for file in [
        "Qwen3-4B.gguf",
        "big-00001-of-00002.gguf",
        "big-00002-of-00002.gguf",
        "mmproj-Qwen3.gguf",
        "Qwen2-VL-mmproj-f16.gguf",
        "notes.txt",
    ] {
        std::fs::write(folder.join(file), b"GGUF").unwrap();
    }
    (server, folder)
}

fn at(folder: &Path, model: &str) -> Provider {
    Provider {
        base_url: local::address_of(folder).unwrap(),
        api_key: String::new(),
        model: model.into(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    }
}

async fn reply(provider: &Provider) -> anyhow::Result<String> {
    let http = provider::client().unwrap();
    let prompt = [PromptMessage::new(Role::User, "Hello there.")];
    let mut reply = provider::ask(&http, provider, &prompt).await?;
    let mut text = String::new();
    while let Some(piece) = reply.next().await? {
        text.push_str(&piece);
    }
    Ok(text)
}

#[tokio::test]
async fn a_folder_chosen_makes_its_gguf_files_chat_models() {
    let _one = ONE.lock().await;
    let (server, folder) = started().await;
    let (status, view) = server
        .put("/api/this-computer", json!({ "folder": folder }))
        .await;
    assert_eq!(status, 200, "{view}");
    let entry = &view["providers"][0];
    assert_eq!(entry["name"], "This computer");
    assert_eq!(entry["folder"], folder.display().to_string());
    assert_eq!(entry["has_key"], false);

    let (_, catalog) = server
        .get(&format!("/api/provider-list/{}/models", entry["id"]))
        .await;
    let ids: Vec<&str> = catalog["models"]
        .as_array()
        .unwrap()
        .iter()
        .map(|model| model["id"].as_str().unwrap())
        .collect();
    assert_eq!(ids, ["big-00001-of-00002.gguf", "Qwen3-4B.gguf"]);
    assert_eq!(catalog["models"][1]["text"], true);
    assert_eq!(catalog["said"], true);

    // Chosen again elsewhere, the entry moves with its kinds.
    let other = server.dir.join("other models");
    std::fs::create_dir_all(&other).unwrap();
    let pick = json!({ "provider_id": entry["id"], "model": "Qwen3-4B.gguf" });
    assert_eq!(server.put("/api/kinds/chat", pick).await.0, 200);
    let (_, moved) = server
        .put("/api/this-computer", json!({ "folder": other }))
        .await;
    assert_eq!(moved["providers"].as_array().unwrap().len(), 1);
    assert_eq!(moved["providers"][0]["id"], entry["id"]);
    assert_eq!(moved["kinds"][0]["model"], "Qwen3-4B.gguf");

    let (status, _) = server
        .put(
            "/api/this-computer",
            json!({ "folder": folder.join("none") }),
        )
        .await;
    assert_eq!(status, 400);
}

#[tokio::test]
async fn first_run_picks_and_stores_this_computers_models_once_its_folder_is_set() {
    let _one = ONE.lock().await;
    let (server, folder) = started().await;
    let address = local::address_of(&folder).unwrap();
    let asked = json!({ "base_url": address });
    assert_eq!(
        server.post("/api/provider/picks", asked.clone()).await.0,
        400
    );

    let (_, view) = server
        .put("/api/this-computer", json!({ "folder": folder }))
        .await;
    let (status, picks) = server.post("/api/provider/picks", asked).await;
    assert_eq!(status, 200, "{picks}");
    assert_eq!(
        (&picks["chat"], &picks["listed"]),
        (&json!("Qwen3-4B.gguf"), &json!(2))
    );
    let set = json!({ "base_url": address, "model": "Qwen3-4B.gguf" });
    assert_eq!(server.put("/api/provider", set).await.0, 200);
    let (_, list) = server.get("/api/provider-list").await;
    assert_eq!(list["providers"].as_array().unwrap().len(), 1);
    assert_eq!(list["kinds"][0]["provider_id"], view["providers"][0]["id"]);
}

#[tokio::test]
async fn its_address_is_not_typed_and_another_account_cannot_set_it() {
    let _one = ONE.lock().await;
    let (server, folder) = started().await;
    let typed = json!({ "base_url": local::address_of(&folder).unwrap() });
    let (status, said) = server.post("/api/provider-list", typed).await;
    assert_eq!(status, 400);
    assert!(said.to_string().contains("by their folder"), "{said}");

    let mut ada = device(&server, false).await;
    let asked = json!({ "folder": folder });
    let put = ada
        .call(Method::PUT, "/api/this-computer", Some(asked))
        .await;
    assert_eq!(put.0, 403);
}

#[tokio::test]
async fn a_chat_loads_its_model_which_is_let_go_when_idle() {
    let _one = ONE.lock().await;
    let (_server, folder) = started().await;
    let said = reply(&at(&folder, "Qwen3-4B.gguf")).await.unwrap();
    assert_eq!(said, "Hello from Qwen3-4B.gguf");
    let loaded = local::idle_for(Duration::from_secs(3600)).await;
    assert_eq!(loaded, Some(folder.join("Qwen3-4B.gguf")));

    // Another model takes its place; one not in the folder is refused.
    let said = reply(&at(&folder, "big-00001-of-00002.gguf")).await;
    assert_eq!(said.unwrap(), "Hello from big-00001-of-00002.gguf");
    let missing = reply(&at(&folder, "big-00002-of-00002.gguf")).await;
    let missing = missing.unwrap_err();
    assert!(
        format!("{missing:#}").contains("there is no model"),
        "{missing:#}"
    );
    // Its code comes through, not the model server's refusal.
    let told = cw_core::told(&missing, cw_core::Code::RequestFailed);
    assert_eq!(
        (told.code, told.details["what"].clone()),
        (cw_core::Code::NotPossible, "no_local_model".into())
    );

    // Unused, it is let go.
    assert_eq!(local::idle_for(Duration::ZERO).await, None);
}

#[tokio::test]
async fn a_model_is_not_let_go_while_its_answer_is_read() {
    let _one = ONE.lock().await;
    let (_server, folder) = started().await;
    let http = provider::client().unwrap();
    let prompt = [PromptMessage::new(Role::User, "Hello there.")];
    let reading = provider::ask(&http, &at(&folder, "Qwen3-4B.gguf"), &prompt)
        .await
        .unwrap();
    assert!(local::idle_for(Duration::ZERO).await.is_some());
    drop(reading);
    assert_eq!(local::idle_for(Duration::ZERO).await, None);
}

#[tokio::test]
async fn a_model_loaded_is_asked_whether_it_still_runs() {
    let _one = ONE.lock().await;
    let (_server, folder) = started().await;
    let http = provider::client().unwrap();
    let prompt = [PromptMessage::new(Role::User, "Hello there.")];
    let model = at(&folder, "Qwen3-4B.gguf");
    let mut first = provider::ask(&http, &model, &prompt).await.unwrap();
    while first.next().await.unwrap().is_some() {}
    drop(first);
    // Asked again, the model loaded is first asked whether it still runs.
    let before = HEALTH.load(Ordering::SeqCst);
    assert_eq!(reply(&model).await.unwrap(), "Hello from Qwen3-4B.gguf");
    assert!(HEALTH.load(Ordering::SeqCst) > before);
    assert_eq!(local::idle_for(Duration::ZERO).await, None);
}

#[tokio::test]
async fn another_model_asked_for_and_given_up_on_leaves_the_one_loaded() {
    let _one = ONE.lock().await;
    let (_server, folder) = started().await;
    let http = provider::client().unwrap();
    let prompt = [PromptMessage::new(Role::User, "Hello there.")];
    let reading = provider::ask(&http, &at(&folder, "Qwen3-4B.gguf"), &prompt)
        .await
        .unwrap();
    let other = at(&folder, "big-00001-of-00002.gguf");
    let given_up = tokio::time::timeout(Duration::from_millis(300), reply(&other)).await;
    assert!(given_up.is_err());
    let loaded = local::idle_for(Duration::from_secs(3600)).await;
    assert_eq!(loaded, Some(folder.join("Qwen3-4B.gguf")));
    drop(reading);
    assert_eq!(local::idle_for(Duration::ZERO).await, None);
}

#[tokio::test]
async fn a_reply_waiting_on_its_tool_does_not_hold_its_model() {
    let _one = ONE.lock().await;
    let (server, folder) = started().await;
    let (_, view) = server
        .put("/api/this-computer", json!({ "folder": folder }))
        .await;
    let pick = json!({ "provider_id": view["providers"][0]["id"], "model": "Qwen3-4B.gguf" });
    assert_eq!(server.put("/api/kinds/chat", pick).await.0, 200);
    let tools = std::env::temp_dir().join(format!("cardwave-local-tools-{}", std::process::id()));
    std::fs::create_dir_all(&tools).unwrap();
    let on = json!({ "tools": { "files": true, "folder": tools } });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);
    let (_, chat) = server.post("/api/chats", json!({ "characters": [] })).await;
    let chat = format!("/api/chats/{}", chat["chat"]["id"]);
    let asked = json!({ "content": "Write the plan." });
    assert_eq!(server.post(&format!("{chat}/messages"), asked).await.0, 201);
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    while event(&mut socket).await["type"] != "tool_asks" {}

    // While the write waits for the user, the reply's model may be let go.
    let mut loaded = local::idle_for(Duration::ZERO).await;
    for _ in 0..40 {
        if loaded.is_none() {
            break;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
        loaded = local::idle_for(Duration::ZERO).await;
    }
    assert_eq!(loaded, None);
    let answering = format!("{chat}/answer");
    let denied = server.post(&answering, json!({ "allow": false })).await;
    assert_eq!(denied.0, 204);
    while event(&mut socket).await["type"] != "reply_ended" {}
    let _ = std::fs::remove_dir_all(&tools);
}

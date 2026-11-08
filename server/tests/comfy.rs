//! Picture providers beside the image APIs: a ComfyUI's saved workflow turned
//! into the form `POST /prompt` takes (`images::graph`), picked on Settings ›
//! Providers with the background model finding where the words go, and a
//! picture made by it; an Automatic1111 (or Forge) listing its checkpoints
//! and making a picture. `comfy/saved.json` is a workflow as ComfyUI's page
//! saves it, with a subgraph, a reroute, a primitive, a bypassed, a muted and
//! a note node; `comfy/prompt.json` is what ComfyUI's page (frontend 1.53.6)
//! sent of it, `comfy/object_info.json` the nodes it uses as ComfyUI 0.37
//! lists them. No test asks a ComfyUI: `Api` stand-ins answer in turn, a
//! picture server's first asked whether it is a ComfyUI (`/system_stats`).

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::api::{Api, JSON, Says, says};
use common::server::{Server, start};
use cw_chat::images::graph;
use serde_json::{Value, json};

fn fixture(name: &str) -> Value {
    let path = format!("{}/tests/comfy/{name}", env!("CARGO_MANIFEST_DIR"));
    serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap()
}

/// The worker model's whole answer.
fn worded(words: &str) -> Says {
    says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": words } }] }).to_string(),
    )
}

/// A ComfyUI's answer to `/system_stats`.
fn comfy() -> Says {
    says(200, JSON, r#"{"system": {}, "devices": []}"#)
}

/// A server whose chat provider is `worker`, with a chat with Mira of the
/// sample card. Answers the chat's address.
async fn chat(server: &Server, worker: &Api) -> String {
    let provider = json!({ "base_url": worker.url, "model": "small-1", "api_key": "sk-chat" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    format!("/api/chats/{}", view["chat"]["id"])
}

#[test]
fn a_saved_workflow_becomes_what_comfyuis_page_sends() {
    let prompt = graph::prompt_of(&fixture("saved.json"), &fixture("object_info.json")).unwrap();
    assert_eq!(Value::Object(prompt.nodes.clone()), fixture("prompt.json"));
    // The KSampler's seed is to change with each picture, as its widget says "randomize".
    assert_eq!(
        prompt.seeds,
        [("3".to_string(), "seed".to_string(), u64::MAX)]
    );
    let places: Vec<_> = graph::places(&prompt, &fixture("object_info.json"))
        .into_iter()
        .map(|place| (place.node, place.input, place.title))
        .collect();
    assert_eq!(
        places,
        [
            ("6".into(), "text".into(), "Positive".into()),
            ("7".into(), "text".into(), "Negative".into()),
            ("9".into(), "filename_prefix".into(), "Save Image".into()),
        ]
    );
}

#[test]
fn a_workflow_cardwave_cannot_send_says_why() {
    let info = fixture("object_info.json");
    // Saved in the form for the API.
    let error = graph::prompt_of(&fixture("prompt.json"), &info).unwrap_err();
    assert!(error.to_string().contains("form for the API"), "{error}");
    // A node this ComfyUI lacks, whose output is used.
    let mut saved = fixture("saved.json");
    for node in saved["nodes"].as_array_mut().unwrap() {
        if node["id"] == 1 {
            node["type"] = "CheckpointLoaderFancy".into();
        }
    }
    let error = graph::prompt_of(&saved, &info).unwrap_err();
    assert!(
        error.to_string().contains("CheckpointLoaderFancy"),
        "{error}"
    );
    // A widget's value of another type than the widget's: an extension's widgets in between.
    let mut saved = fixture("saved.json");
    for node in saved["nodes"].as_array_mut().unwrap() {
        if node["id"] == 3 {
            node["widgets_values"][2] = "twenty".into();
        }
    }
    let error = graph::prompt_of(&saved, &info).unwrap_err();
    assert!(error.to_string().contains("“KSampler”"), "{error}");
}

#[tokio::test]
async fn a_saved_workflow_is_picked_and_makes_the_chats_pictures() {
    let saved = fixture("saved.json").to_string();
    let info = fixture("object_info.json").to_string();
    let done = json!({ "p1": {
        "outputs": {
            "13": { "images": [{ "filename": "preview.png", "subfolder": "", "type": "temp" }] },
            "9": { "images": [{ "filename": "Cardwave_00001_.png", "subfolder": "", "type": "output" }] }
        },
        "status": { "status_str": "success", "completed": true }
    } });
    let comfyui = Api::start_each(vec![
        // Picked: the workflow, ComfyUI's nodes.
        says(200, JSON, &saved),
        says(200, JSON, &info),
        // A picture: is it a ComfyUI, the workflow and nodes anew, queued, done, fetched.
        comfy(),
        says(200, JSON, &saved),
        says(200, JSON, &info),
        says(
            200,
            JSON,
            r#"{"prompt_id": "p1", "number": 1, "node_errors": {}}"#,
        ),
        says(200, JSON, &done.to_string()),
        Says {
            bytes: Some(common::picture()),
            ..says(200, "image/png", "")
        },
    ])
    .await;
    // The background model names the first field, then writes the picture's words.
    let worker =
        Api::start_each(vec![worded(r#"{"place": 1}"#), worded("lighthouse, storm")]).await;
    let server = start().await;
    let chat = chat(&server, &worker).await;
    let own = json!({ "model": "model.safetensors", "base_url": comfyui.url });
    assert_eq!(server.set_images(own).await.0, 200);
    let (_, list) = server.get("/api/provider-list").await;
    let id = list["providers"][1]["id"].clone();
    assert_eq!(list["providers"][1]["workflow"], Value::Null);

    let at = format!("/api/provider-list/{id}/workflow");
    let (status, view) = server.put(&at, json!({ "name": "Cardwave.json" })).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(view["providers"][1]["workflow"], "Cardwave.json");
    let asked = &worker.asked()[0].body;
    assert!(
        asked.contains("1. CLIPTextEncode “Positive”, text: \\\"a lighthouse at dusk\\\""),
        "{asked}"
    );
    assert!(
        asked.contains("3. SaveImage “Save Image”, filename_prefix"),
        "{asked}"
    );

    let (status, message) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 201, "{message}");
    let asked = comfyui.asked();
    let paths: Vec<_> = asked.iter().map(|asked| asked.path.as_str()).collect();
    assert_eq!(
        paths,
        [
            "/v1/userdata/workflows%2FCardwave.json",
            "/v1/object_info",
            "/v1/system_stats",
            "/v1/userdata/workflows%2FCardwave.json",
            "/v1/object_info",
            "/v1/prompt",
            "/v1/history/p1",
            // The saved picture, not the preview.
            "/v1/view?filename=Cardwave_00001_.png&subfolder=&type=output"
        ]
    );
    // The words go where the background model said, a new seed into the KSampler; the rest is the workflow's.
    let queued: Value = serde_json::from_str(&asked[5].body).unwrap();
    let mut meant = fixture("prompt.json");
    meant["6"]["inputs"]["text"] = "lighthouse, storm".into();
    meant["3"]["inputs"]["seed"] = queued["prompt"]["3"]["inputs"]["seed"].clone();
    assert_eq!(queued["prompt"], meant);
    assert!(queued["prompt"]["3"]["inputs"]["seed"].as_u64().unwrap() < 1 << 53);

    // Renamed, it keeps the workflow; at another address, whose ComfyUI is another, not.
    let path = format!("/api/provider-list/{id}");
    let renamed = json!({ "base_url": comfyui.url, "name": "Rig" });
    assert_eq!(
        server.patch(&path, renamed).await.1["workflow"],
        "Cardwave.json"
    );
    let moved = json!({ "base_url": "http://127.0.0.1:1/v1", "name": "Rig" });
    assert_eq!(server.patch(&path, moved).await.1["workflow"], Value::Null);
    let (_, list) = server.get("/api/provider-list").await;
    assert_eq!(list["providers"][1]["workflow"], Value::Null);

    // ComfyUI's default workflow again.
    let (status, view) = server.put(&at, json!({})).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(view["providers"][1]["workflow"], Value::Null);
}

#[tokio::test]
async fn a_workflow_whose_field_the_background_model_cannot_find_is_not_kept() {
    let comfyui = Api::start_each(vec![
        says(200, JSON, &fixture("saved.json").to_string()),
        says(200, JSON, &fixture("object_info.json").to_string()),
    ])
    .await;
    let worker = Api::start(worded(r#"{"place": 0}"#)).await;
    let server = start().await;
    chat(&server, &worker).await;
    let own = json!({ "model": "model.safetensors", "base_url": comfyui.url });
    assert_eq!(server.set_images(own).await.0, 200);
    let (_, list) = server.get("/api/provider-list").await;
    let id = &list["providers"][1]["id"];
    let at = format!("/api/provider-list/{id}/workflow");
    let (status, said) = server.put(&at, json!({ "name": "Cardwave.json" })).await;
    assert_eq!(status, 400, "{said}");
    let error = said["error"].as_str().unwrap();
    assert!(error.contains("found no field"), "{error}");
    assert_eq!(
        server.get("/api/provider-list").await.1["providers"][1]["workflow"],
        Value::Null
    );
}

#[tokio::test]
async fn an_automatic1111_lists_its_checkpoints_and_makes_a_picture() {
    let models = json!([
        { "title": "sdxl.safetensors [31e35c80fc]", "model_name": "sdxl" },
        { "title": "SDXL.safetensors [aaaaaaaaaa]", "model_name": "SDXL" },
        { "title": "sdxl.safetensors [31e35c80fc]", "model_name": "sdxl" },
        { "title": "anime.safetensors [0123456789]", "model_name": "Anime" }
    ]);
    let made =
        json!({ "images": [STANDARD.encode(common::picture())], "parameters": {}, "info": "" });
    let forge = Api::start_each(vec![
        says(404, JSON, r#"{"detail": "Not Found"}"#),
        says(200, JSON, &models.to_string()),
        says(200, JSON, &models.to_string()),
        says(404, JSON, r#"{"detail": "Not Found"}"#),
        says(200, JSON, &models.to_string()),
        says(200, JSON, &made.to_string()),
    ])
    .await;
    let worker = Api::start(worded("lighthouse")).await;
    let server = start().await;
    let chat = chat(&server, &worker).await;

    let (status, listed) = server
        .post("/api/images/models", json!({ "base_url": forge.url }))
        .await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(listed["models"], json!(["Anime", "SDXL", "sdxl"]));
    let own = json!({ "model": "sdxl", "base_url": forge.url });
    assert_eq!(server.set_images(own).await.0, 200);

    let (status, message) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 201, "{message}");
    let asked = forge.asked();
    let paths: Vec<_> = asked.iter().map(|asked| asked.path.as_str()).collect();
    assert_eq!(
        paths,
        [
            "/v1/system_stats",
            "/v1/sdapi/v1/sd-models",
            "/v1/sdapi/v1/sd-models",
            "/v1/system_stats",
            "/v1/sdapi/v1/sd-models",
            "/v1/sdapi/v1/txt2img"
        ]
    );
    let body: Value = serde_json::from_str(&asked[5].body).unwrap();
    assert_eq!(
        body,
        json!({
            "prompt": "lighthouse",
            "negative_prompt": "text, watermark",
            "width": 1024,
            "height": 1024,
            "override_settings": { "sd_model_checkpoint": "sdxl" }
        })
    );
    let (_, picture) = server
        .download(&format!("/api/messages/{}/picture", message["id"]))
        .await;
    assert_eq!(picture, common::picture());
}

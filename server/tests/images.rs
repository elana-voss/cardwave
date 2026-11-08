//! Pictures made by a model: the image model kept, an address's image models
//! listed, and a picture made for a chat through OpenAI's image API,
//! OpenRouter's and a ComfyUI, and made anew of words changed. No test asks a provider or a ComfyUI: `Api`
//! stand-ins answer the askings in turn, the worker model's at the chat
//! provider's address. A stand-in is asked first whether it is a ComfyUI
//! (`/system_stats`), then whether an Automatic1111 (`/sdapi/v1/sd-models`,
//! which only a list of models answers), so a list of answers begins with
//! the first one's.

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::api::{Api, JSON, Says, says};
use common::server::{Server, start};
use cw_chat::images;
use cw_provider::images::Whom;
use serde_json::{Value, json};

/// The worker model's whole answer, the words for a picture.
fn worded(words: &str) -> Says {
    says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": words } }] }).to_string(),
    )
}

/// An answer that says the address is no ComfyUI.
fn no_comfy() -> Says {
    says(404, JSON, "{}")
}

/// OpenAI's answer with `common::picture()` in it.
fn generated() -> Says {
    says(
        200,
        JSON,
        &json!({ "data": [{ "b64_json": STANDARD.encode(common::picture()) }] }).to_string(),
    )
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

#[tokio::test]
async fn the_chat_providers_image_models_are_listed_and_one_is_kept() {
    let models = json!({ "data": [{ "id": "gpt-4o" }, { "id": "gpt-image-1" }, { "id": "dall-e-3" }, { "id": "text-embedding-3" }] });
    let api = Api::start_each(vec![no_comfy(), says(200, JSON, &models.to_string())]).await;
    let server = start().await;
    assert_eq!(server.get("/api/images").await.1, Value::Null);
    let provider =
        json!({ "base_url": api.url, "model": "gpt-4o", "api_key": "sk-chat-0123456789" });
    assert_eq!(server.set_provider(provider).await.0, 200);

    let (status, listed) = server
        .post("/api/images/models", json!({ "base_url": api.url }))
        .await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        listed,
        json!({ "models": ["dall-e-3", "gpt-image-1"], "more": false })
    );
    assert_eq!(api.last_key().as_deref(), Some("Bearer sk-chat-0123456789"));

    let (status, kept) = server.set_images(json!({ "model": "gpt-image-1" })).await;
    assert_eq!(status, 200, "{kept}");
    let view =
        json!({ "model": "gpt-image-1", "base_url": null, "has_key": false, "key_end": null });
    assert_eq!(kept, view);
    assert_eq!(server.get("/api/images").await.1, view);
}

#[tokio::test]
async fn a_picture_of_the_scene_comes_as_a_message_of_the_character() {
    let worker = Api::start(worded("lighthouse, storm, 1 woman")).await;
    let image = Api::start_each(vec![no_comfy(), generated()]).await;
    let server = start().await;
    let chat = chat(&server, &worker).await;
    // Without an image model, and in a chat in the Trash, nothing is asked.
    let (status, said) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 400, "{said}");
    assert_eq!(server.patch(&chat, json!({ "trashed": true })).await.0, 200);
    let (status, said) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 400, "{said}");
    assert!(said["error"].as_str().unwrap().contains("Trash"), "{said}");
    assert!(worker.asked().is_empty());
    assert_eq!(
        server.patch(&chat, json!({ "trashed": false })).await.0,
        200
    );
    let own =
        json!({ "model": "dall-e-3", "base_url": image.url, "api_key": "sk-image-0123456789" });
    let (status, kept) = server.set_images(own).await;
    assert_eq!(status, 200, "{kept}");
    assert_eq!(kept["key_end"], "6789");

    let (status, message) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 201, "{message}");
    assert_eq!(message["picture"], true);
    assert_eq!(message["role"], "assistant");
    assert_eq!(
        message["content"],
        "*(sends a picture: lighthouse, storm, 1 woman)*"
    );
    // The worker model is given the character and the newest messages, and the scene's template.
    let asked = &worker.asked()[0].body;
    assert!(
        asked.contains("Recent chat history:\\nMira: \\\"You picked a night for it, Guest.\\\""),
        "{asked}"
    );
    assert!(
        asked.contains("describe the visual details included in the last chat message"),
        "{asked}"
    );
    // The image model is asked at its own address, with its own key, for the worker's words.
    // Its key was checked as it was added (its list of models), and each picture asks what it is first.
    let asked = image.asked();
    let made = asked.last().unwrap();
    assert_eq!(made.path, "/v1/images/generations");
    assert_eq!(made.key.as_deref(), Some("Bearer sk-image-0123456789"));
    let body: Value = serde_json::from_str(&made.body).unwrap();
    assert_eq!(
        body,
        json!({ "model": "dall-e-3", "prompt": "lighthouse, storm, 1 woman", "n": 1 })
    );

    let (headers, picture) = server
        .download(&format!("/api/messages/{}/picture", message["id"]))
        .await;
    assert_eq!(headers["content-type"], "image/png");
    // A message's number may come again after it was deleted, so its picture is asked for anew.
    assert_eq!(headers["cache-control"], "private, no-cache");
    assert_eq!(picture, common::picture());
    let (_, shown) = server.get(&chat).await;
    assert_eq!(
        shown["messages"].as_array().unwrap().last().unwrap()["picture"],
        true
    );
}

#[tokio::test]
async fn a_picture_of_the_words_typed_is_asked_for_them() {
    let worker = Api::start(worded("\"red kite, beach\"")).await;
    let image = Api::start_each(vec![no_comfy(), generated()]).await;
    let server = start().await;
    let chat = chat(&server, &worker).await;
    let own = json!({ "model": "flux", "base_url": image.url });
    assert_eq!(server.set_images(own).await.0, 200);

    let (status, message) = server
        .post(&format!("{chat}/picture"), json!({ "words": "a red kite" }))
        .await;
    assert_eq!(status, 201, "{message}");
    // The message holds the words as the user typed them, which "Edit
    // description" shows; the image model gets the worker model's.
    assert_eq!(message["content"], "*(sends a picture: a red kite)*");
    let body: Value = serde_json::from_str(&image.asked().last().unwrap().body).unwrap();
    assert_eq!(body["prompt"], "red kite, beach");
    let asked = &worker.asked()[0].body;
    assert!(asked.contains("a picture of \\\"a red kite\\\""), "{asked}");
    assert!(asked.contains("Mira's appearance"), "{asked}");
    assert!(!asked.contains("Recent chat history"), "{asked}");
}

#[tokio::test]
async fn a_comfyui_lists_its_checkpoints_and_makes_a_picture_by_its_workflow() {
    let comfy = || says(200, JSON, r#"{"system": {}, "devices": []}"#);
    let saved = json!({ "p1": {
        "outputs": { "9": { "images": [{ "filename": "Cardwave_00001_.png", "subfolder": "", "type": "output" }] } },
        "status": { "status_str": "success", "completed": true }
    } });
    let answers = vec![
        comfy(),
        says(200, JSON, r#"["sdxl.safetensors", "anime.safetensors"]"#),
        comfy(),
        says(
            200,
            JSON,
            r#"{"prompt_id": "p1", "number": 1, "node_errors": {}}"#,
        ),
        says(200, JSON, "{}"),
        says(200, JSON, &saved.to_string()),
        Says {
            bytes: Some(common::picture()),
            ..says(200, "image/png", "")
        },
    ];
    let comfyui = Api::start_each(answers).await;
    let worker = Api::start(worded("lighthouse")).await;
    let server = start().await;
    let chat = chat(&server, &worker).await;

    let (status, listed) = server
        .post("/api/images/models", json!({ "base_url": comfyui.url }))
        .await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        listed["models"],
        json!(["anime.safetensors", "sdxl.safetensors"])
    );
    let own = json!({ "model": "sdxl.safetensors", "base_url": comfyui.url });
    assert_eq!(server.set_images(own).await.0, 200);

    let (status, message) = server.post(&format!("{chat}/picture"), json!({})).await;
    assert_eq!(status, 201, "{message}");
    let asked = comfyui.asked();
    let paths: Vec<_> = asked.iter().map(|asked| asked.path.as_str()).collect();
    assert_eq!(
        paths,
        [
            "/v1/system_stats",
            "/v1/models/checkpoints",
            "/v1/system_stats",
            "/v1/prompt",
            "/v1/history/p1",
            "/v1/history/p1",
            "/v1/view?filename=Cardwave_00001_.png&subfolder=&type=output"
        ]
    );
    let queued: Value = serde_json::from_str(&asked[3].body).unwrap();
    assert_eq!(
        queued["prompt"]["4"]["inputs"]["ckpt_name"],
        "sdxl.safetensors"
    );
    assert_eq!(queued["prompt"]["6"]["inputs"]["text"], "lighthouse");
    let (_, picture) = server
        .download(&format!("/api/messages/{}/picture", message["id"]))
        .await;
    assert_eq!(picture, common::picture());
}

#[tokio::test]
async fn a_comfyui_that_fails_says_why_and_is_asked_with_the_key() {
    let failed = json!({ "p1": { "outputs": {}, "status": { "status_str": "error", "completed": false,
        "messages": [["execution_start", {}], ["execution_error", { "exception_message": "out of memory\n" }]] } } });
    let comfyui = Api::start_each(vec![
        says(200, JSON, r#"{"system": {}, "devices": []}"#),
        says(200, JSON, r#"{"prompt_id": "p1"}"#),
        says(200, JSON, &failed.to_string()),
    ])
    .await;
    let whom = Whom {
        provider: String::new(),
        base_url: comfyui.url.clone(),
        api_key: "sk-comfy".into(),
        model: "sdxl.safetensors".into(),
        workflow: None,
    };
    let error = images::make(&reqwest::Client::new(), &whom, "lighthouse")
        .await
        .unwrap_err();
    assert_eq!(error.to_string(), "ComfyUI: out of memory");
    // A ComfyUI behind a server that asks for a key is given it.
    let keys: Vec<_> = comfyui.asked().into_iter().map(|asked| asked.key).collect();
    assert_eq!(keys, vec![Some("Bearer sk-comfy".to_string()); 3]);
}

#[tokio::test]
async fn a_picture_at_an_address_that_is_no_web_sites_is_not_fetched() {
    let at = json!({ "data": [{ "url": "http://127.0.0.1:8477/api/provider" }] });
    let api = Api::start(says(200, JSON, &at.to_string())).await;
    let whom = Whom {
        provider: String::new(),
        base_url: api.url.clone(),
        api_key: String::new(),
        model: "dall-e-3".into(),
        workflow: None,
    };
    let client = reqwest::Client::new();
    let error = images::make_with(
        &client,
        cw_provider::images::ImageApi::OpenAi,
        &whom,
        "lighthouse",
    )
    .await
    .unwrap_err();
    assert_eq!(
        error.to_string(),
        "the image model's picture is at an address that is not fetched"
    );
}

#[test]
fn the_words_leave_out_a_reasoning_models_thoughts_and_are_kept_short() {
    let thought = "<think>The user wants a lighthouse.</think>\n\n\"lighthouse, storm\"";
    assert_eq!(images::words_of(thought).unwrap(), "lighthouse, storm");
    assert_eq!(
        images::words_of(&"a, ".repeat(600))
            .unwrap()
            .chars()
            .count(),
        1000
    );
    assert!(images::words_of("  \"\" ").is_err());
}

#[tokio::test]
async fn openrouter_is_asked_at_its_images_api() {
    assert!(cw_provider::images::is_openrouter(
        "https://openrouter.ai/api/v1"
    ));
    assert!(!cw_provider::images::is_openrouter(
        "https://api.openai.com/v1"
    ));
    // Its list of image models, and a picture, at the paths OpenRouter has them;
    // here asked of a stand-in in its place.
    let api = Api::start(generated()).await;
    let whom = Whom {
        provider: String::new(),
        base_url: api.url.clone(),
        api_key: "sk-or".into(),
        model: "google/gemini-2.5-flash-image".into(),
        workflow: None,
    };
    let picture = images::make_with(
        &reqwest::Client::new(),
        cw_provider::images::ImageApi::OpenRouter,
        &whom,
        "lighthouse",
    )
    .await
    .unwrap();
    assert_eq!(picture.data, common::picture());
    assert_eq!(picture.mime, "image/png");
    let made = &api.asked()[0];
    assert_eq!(made.path, "/v1/images");
    let body: Value = serde_json::from_str(&made.body).unwrap();
    assert_eq!(
        body,
        json!({ "model": "google/gemini-2.5-flash-image", "prompt": "lighthouse" })
    );
}

#[tokio::test]
async fn change_prompt_makes_the_picture_anew_of_the_words_as_another_version() {
    let worker = Api::start(worded("lighthouse, storm")).await;
    let image = Api::start_each(vec![
        no_comfy(),
        no_comfy(),
        generated(),
        no_comfy(),
        no_comfy(),
        generated(),
    ])
    .await;
    let server = start().await;
    let chat = chat(&server, &worker).await;
    let own = json!({ "model": "dall-e-3", "base_url": image.url });
    assert_eq!(server.set_images(own).await.0, 200);
    let (_, first) = server.post(&format!("{chat}/picture"), json!({})).await;
    let again = format!("/api/messages/{}/picture", first["id"]);

    let (status, said) = server.post(&again, json!({ "words": "  " })).await;
    assert_eq!(status, 400, "{said}");
    let (status, made) = server
        .post(&again, json!({ "words": " lighthouse, dawn " }))
        .await;
    assert_eq!(status, 201, "{made}");
    // The words changed go through the worker model, as typed words do, so the
    // character keeps the looks of their description; the message holds them as typed.
    let asked = &worker.asked()[1].body;
    assert!(
        asked.contains("a picture of \\\"lighthouse, dawn\\\""),
        "{asked}"
    );
    assert!(asked.contains("Character description"), "{asked}");
    let body: Value = serde_json::from_str(&image.asked().last().unwrap().body).unwrap();
    assert_eq!(body["prompt"], "lighthouse, storm");
    assert_eq!(made["content"], "*(sends a picture: lighthouse, dawn)*");
    assert_eq!(made["picture"], true);
    assert_eq!(made["parent_id"], first["parent_id"]);
    assert_eq!(made["swipes"].as_array().unwrap().len(), 2);
    let (_, picture) = server
        .download(&format!("/api/messages/{}/picture", made["id"]))
        .await;
    assert_eq!(picture, common::picture());
}

#[tokio::test]
async fn a_form_left_without_a_key_lists_with_the_key_of_the_provider_at_its_address() {
    let models = json!({ "data": [{ "id": "dall-e-3" }] });
    let api = Api::start_each(vec![no_comfy(), says(200, JSON, &models.to_string())]).await;
    let server = start().await;
    let chat = json!({ "base_url": "https://rig.example.test/v1", "model": "rig-1", "api_key": "sk-rig-0123456789" });
    assert_eq!(server.set_provider(chat).await.0, 200);
    // A provider added on the page Providers, with its key, that no kind is at.
    let entry = json!({ "base_url": api.url, "api_key": "sk-entry-0123456789" });
    assert_eq!(server.post("/api/provider-list", entry).await.0, 201);
    let asked = json!({ "base_url": api.url });
    let (status, listed) = server.post("/api/images/models", asked).await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        api.last_key().as_deref(),
        Some("Bearer sk-entry-0123456789")
    );
}

#[tokio::test]
async fn a_form_left_without_a_key_lists_with_the_image_models_key_where_it_is_at_that_address() {
    let models = json!({ "data": [{ "id": "dall-e-3" }] });
    let api = Api::start_each(vec![no_comfy(), says(200, JSON, &models.to_string())]).await;
    let server = start().await;
    let chat = json!({ "base_url": api.url, "model": "rig-1", "api_key": "sk-chat-0123456789" });
    assert_eq!(server.set_provider(chat).await.0, 200);
    let own =
        json!({ "model": "dall-e-3", "base_url": api.url, "api_key": "sk-images-0123456789" });
    assert_eq!(server.set_images(own).await.0, 200);
    let (status, listed) = server
        .post("/api/images/models", json!({ "base_url": api.url }))
        .await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        api.last_key().as_deref(),
        Some("Bearer sk-images-0123456789")
    );
}

#[test]
fn the_chat_model_is_told_of_a_picture_sent_in_words_it_cannot_take_for_its_own() {
    use cw_chat::chats::{self, NewChat};
    let scratch = common::Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = cw_library::cards::import(db, me, &common::card_file()).unwrap();
    let new = NewChat {
        characters: &[(card.version, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    let picture = cw_provider::images::Picture {
        data: common::picture(),
        mime: "image/png",
    };
    images::keep(
        db,
        me,
        chat,
        None,
        ("a lighthouse at night", "a lighthouse at night"),
        &picture,
    )
    .unwrap();
    let inputs = chats::prompt_inputs(db, me, chat, None).unwrap();
    let told = &inputs.state.messages.last().unwrap().content;
    // Not the character's own words, which the model went on to write instead of calling its tool.
    assert!(!told.contains("sends a picture"), "{told}");
    assert!(
        told.starts_with('[') && told.contains("a lighthouse at night"),
        "{told}"
    );
}

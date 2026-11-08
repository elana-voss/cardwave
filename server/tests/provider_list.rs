//! Settings › Providers over HTTP: the account's providers, the kind of
//! model each serves, the models one offers with their kinds, a model's
//! thinking turned off, and the account's values for a reply. No test asks a
//! provider: the API is a server of the test's own (`common::api`).
//!
//! A form left without a key (a model test, a list of models) sends the key
//! of the provider at its address. `add` adds a provider and answers its
//! number; `kinds` is the list's kinds as (kind, provider, model, thinking).

mod common;

use axum::http::Method;
use common::api::{Api, JSON, says};
use common::server::{Server, event, start};
use serde_json::{Value, json};

const RIG: &str = "https://rig.example.test/v1";
const OTHER: &str = "https://other.example.test/v1";
const STREAM: &str = "text/event-stream";

async fn add(server: &Server, asked: Value) -> i64 {
    let (status, added) = server.post("/api/provider-list", asked).await;
    assert_eq!(status, 201, "{added}");
    added["id"].as_i64().unwrap()
}

async fn kinds(server: &Server) -> Vec<(String, i64, String, String)> {
    let listed = server.get("/api/provider-list").await.1;
    listed["kinds"]
        .as_array()
        .unwrap()
        .iter()
        .map(|kind| {
            (
                kind["kind"].as_str().unwrap().to_string(),
                kind["provider_id"].as_i64().unwrap(),
                kind["model"].as_str().unwrap().to_string(),
                kind["thinking"].as_str().unwrap().to_string(),
            )
        })
        .collect()
}

fn kind(kind: &str, provider: i64, model: &str, thinking: &str) -> (String, i64, String, String) {
    (kind.into(), provider, model.into(), thinking.into())
}

/// This computer's models, which the server names for the page.
fn own() -> Value {
    json!([{ "kind": "search", "model": "bge-m3" }, { "kind": "voice", "model": "Pocket TTS" }])
}

#[tokio::test]
async fn providers_are_added_changed_and_removed_and_no_answer_tells_a_key() {
    let server = start().await;
    let mut socket = server.listen().await;
    assert_eq!(
        server.get("/api/provider-list").await,
        (200, json!({ "providers": [], "kinds": [], "own": own() }))
    );

    let rig = json!({ "base_url": format!(" {RIG}/ "), "api_key": " sk-rig-secret-1234 ", "name": " The rig " });
    let id = add(&server, rig.clone()).await;
    assert_eq!(event(&mut socket).await, json!({ "type": "provider" }));
    // The same address with the same key is the same provider.
    assert_eq!(add(&server, rig).await, id);
    event(&mut socket).await;
    let other = add(&server, json!({ "base_url": OTHER })).await;
    event(&mut socket).await;
    let listed = server.get("/api/provider-list").await.1;
    assert_eq!(
        listed["providers"],
        json!([
            { "id": id, "name": "The rig", "own_name": "The rig", "base_url": RIG, "has_key": true, "key_end": "1234", "workflow": null, "folder": null },
            { "id": other, "name": "other.example.test", "own_name": null, "base_url": OTHER, "has_key": false, "key_end": null, "workflow": null, "folder": null },
        ])
    );

    // A key left out stays while the address does, and only then.
    let path = format!("/api/provider-list/{id}");
    let (status, changed) = server
        .patch(&path, json!({ "base_url": RIG, "name": "Rig" }))
        .await;
    assert_eq!(status, 200, "{changed}");
    assert_eq!(
        (&changed["name"], &changed["key_end"]),
        (&json!("Rig"), &json!("1234"))
    );
    let (_, moved) = server
        .patch(&path, json!({ "base_url": "https://rig.example.test/v2" }))
        .await;
    assert_eq!(
        (&moved["has_key"], &moved["name"]),
        (&json!(false), &json!("Rig"))
    );
    let (_, keyed) = server
        .patch(
            &path,
            json!({ "base_url": RIG, "api_key": "sk-rig-secret-5678" }),
        )
        .await;
    assert_eq!(keyed["key_end"], "5678");
    // Refused: no address, a provider that is not there.
    assert_eq!(server.patch(&path, json!({ "base_url": " " })).await.0, 400);
    let missing = json!({ "base_url": RIG });
    assert_eq!(server.patch("/api/provider-list/999", missing).await.0, 404);

    // Removed, it takes the kinds at it along.
    let pick = json!({ "provider_id": id, "model": "tide-1" });
    assert_eq!(server.put("/api/kinds/images", pick).await.0, 200);
    let removed = server.call(Method::DELETE, &path, None).await;
    assert_eq!(removed, (204, Value::Null));
    assert_eq!(kinds(&server).await, []);
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 404);
    let listed = server.get("/api/provider-list").await.1;
    assert_eq!(listed["providers"].as_array().unwrap().len(), 1);
    for answer in [&changed, &moved, &keyed, &listed] {
        assert!(!answer.to_string().contains("secret"), "{answer}");
    }
}

#[tokio::test]
async fn each_kind_is_at_one_provider_and_the_background_at_the_chat_model_is_none() {
    let server = start().await;
    let rig = add(
        &server,
        json!({ "base_url": RIG, "api_key": "sk-rig-long-0000" }),
    )
    .await;
    let other = add(&server, json!({ "base_url": OTHER })).await;

    let chat = json!({ "provider_id": rig, "model": " tide-1 " });
    let (status, all) = server.put("/api/kinds/chat", chat).await;
    assert_eq!(status, 200, "{all}");
    let stored = server.get("/api/provider").await.1;
    assert_eq!(
        (&stored["base_url"], &stored["model"], &stored["key_end"]),
        (&json!(RIG), &json!("tide-1"), &json!("0000"))
    );

    let background = json!({ "provider_id": other, "model": "small-1" });
    assert_eq!(server.put("/api/kinds/background", background).await.0, 200);
    let images = json!({ "provider_id": other, "model": "paint-1" });
    assert_eq!(server.put("/api/kinds/images", images).await.0, 200);
    assert_eq!(
        kinds(&server).await,
        [
            kind("chat", rig, "tide-1", "on"),
            kind("background", other, "small-1", "on"),
            kind("images", other, "paint-1", "on"),
        ]
    );
    assert_eq!(
        server.get("/api/provider").await.1["worker_model"],
        "small-1"
    );

    // A kind taken to another provider moves there: it is at one alone.
    let moved = json!({ "provider_id": rig, "model": "paint-2" });
    assert_eq!(server.put("/api/kinds/images", moved).await.0, 200);
    // The background model picked as the chat model is none of its own.
    let same = json!({ "provider_id": rig, "model": "tide-1" });
    assert_eq!(server.put("/api/kinds/background", same).await.0, 200);
    assert_eq!(
        kinds(&server).await,
        [
            kind("chat", rig, "tide-1", "on"),
            kind("images", rig, "paint-2", "on"),
        ]
    );

    // Search and voice at a provider, and back to this computer's; the chat stays.
    let search = json!({ "provider_id": rig, "model": "embed-1" });
    assert_eq!(server.put("/api/kinds/search", search).await.0, 200);
    let voice = json!({ "provider_id": rig, "model": "tts-1" });
    assert_eq!(server.put("/api/kinds/voice", voice).await.0, 200);
    assert_eq!(
        kinds(&server).await,
        [
            kind("chat", rig, "tide-1", "on"),
            kind("images", rig, "paint-2", "on"),
            kind("search", rig, "embed-1", "on"),
            kind("voice", rig, "tts-1", "on"),
        ]
    );
    let (status, all) = server.call(Method::DELETE, "/api/kinds/search", None).await;
    assert_eq!(status, 200, "{all}");
    assert_eq!(all["kinds"].as_array().unwrap().len(), 3);
    assert_eq!(
        server.call(Method::DELETE, "/api/kinds/chat", None).await.0,
        400
    );

    // Refused: a kind there is none of, no model, a provider that is not the user's.
    let pick = json!({ "provider_id": rig, "model": "x" });
    assert_eq!(server.put("/api/kinds/speech", pick).await.0, 404);
    let nameless = json!({ "provider_id": rig, "model": " " });
    assert_eq!(server.put("/api/kinds/chat", nameless).await.0, 400);
    let nowhere = json!({ "provider_id": 999, "model": "x" });
    assert_eq!(server.put("/api/kinds/chat", nowhere).await.0, 404);
}

#[tokio::test]
async fn thinking_is_turned_off_by_the_first_form_the_provider_takes() {
    let piece = format!(
        "data: {}\n\ndata: [DONE]\n\n",
        json!({ "choices": [{ "delta": { "content": "OK" } }] })
    );
    let refused = says(400, JSON, r#"{"error":{"message":"unknown parameter"}}"#);
    // It refuses OpenAI's form and takes OpenRouter's.
    let api = Api::start_each(vec![refused.clone(), says(200, STREAM, &piece)]).await;
    let server = start().await;
    let id = add(&server, json!({ "base_url": api.url })).await;
    let chat = json!({ "provider_id": id, "model": "tide-1" });
    assert_eq!(server.put("/api/kinds/chat", chat).await.0, 200);

    let (status, all) = server
        .put("/api/kinds/chat/thinking", json!({ "on": false }))
        .await;
    assert_eq!(status, 200, "{all}");
    assert_eq!(kinds(&server).await, [kind("chat", id, "tide-1", "off")]);
    let asked = api.asked();
    assert_eq!(asked.len(), 2);
    let sent: Vec<Value> = asked
        .iter()
        .map(|asked| serde_json::from_str(&asked.body).unwrap())
        .collect();
    assert_eq!(sent[0]["reasoning_effort"], "none");
    assert_eq!(sent[1]["reasoning"], json!({ "enabled": false }));
    // Turned on, nothing is asked.
    let on = server
        .put("/api/kinds/chat/thinking", json!({ "on": true }))
        .await;
    assert_eq!(on.0, 200);
    assert_eq!(api.asked().len(), 2);
    assert_eq!(kinds(&server).await, [kind("chat", id, "tide-1", "on")]);

    // A provider that takes no form: the model cannot.
    let none = Api::start(refused).await;
    let other = add(&server, json!({ "base_url": none.url })).await;
    let images = json!({ "provider_id": other, "model": "tide-2" });
    assert_eq!(server.put("/api/kinds/background", images).await.0, 200);
    let off = json!({ "on": false });
    assert_eq!(
        server.put("/api/kinds/background/thinking", off).await.0,
        200
    );
    assert_eq!(none.asked().len(), 3);
    assert_eq!(
        kinds(&server).await[1],
        kind("background", other, "tide-2", "cannot")
    );
    // A kind with no model has nothing to turn off.
    let off = json!({ "on": false });
    assert_eq!(server.put("/api/kinds/images/thinking", off).await.0, 404);
}

#[tokio::test]
async fn a_providers_models_come_with_their_kinds() {
    let listed = json!({ "object": "list", "data": [
        { "id": "tide-1" }, { "id": "gpt-image-1" }, { "id": "text-embedding-3-small" },
        { "id": "o3-mini" }, { "id": "rig-tts-2" },
    ] });
    let api = Api::start(says(200, JSON, &listed.to_string())).await;
    let server = start().await;
    let id = add(
        &server,
        json!({ "base_url": api.url, "api_key": "sk-rig-0000" }),
    )
    .await;
    let (status, offered) = server.get(&format!("/api/provider-list/{id}/models")).await;
    assert_eq!(status, 200, "{offered}");
    // The kinds are models.dev's where it lists the model, else guessed; a voice's and a search model's by their names.
    let no = |id: &str, text: bool, image: bool, thinks: bool, said: bool| json!({ "id": id, "text": text, "image": image, "search": false, "voice": false, "thinks": thinks, "said": said, "name": null });
    assert_eq!(
        offered,
        json!({
            "models": [
                no("gpt-image-1", false, true, false, true),
                no("o3-mini", true, false, true, true),
                { "id": "rig-tts-2", "text": false, "image": false, "search": false, "voice": true, "thinks": false, "said": false, "name": null },
                { "id": "text-embedding-3-small", "text": false, "image": false, "search": true, "voice": false, "thinks": false, "said": true, "name": null },
                no("tide-1", true, false, false, false),
            ],
            "more": false,
            "failed": null,
            "workflows": null,
        })
    );
    assert_eq!(api.last_key().as_deref(), Some("Bearer sk-rig-0000"));
    assert_eq!(server.get("/api/provider-list/999/models").await.0, 404);

    // A list that does not come says why.
    let down = Api::start(says(500, JSON, "{}")).await;
    let id = add(&server, json!({ "base_url": down.url })).await;
    let (_, offered) = server.get(&format!("/api/provider-list/{id}/models")).await;
    assert_eq!(offered["models"], json!([]));
    assert_eq!(offered["failed"]["code"], "answered", "{offered}");
}

#[tokio::test]
async fn the_values_for_a_reply_are_kept_as_typed_each_in_its_range() {
    let server = start().await;
    let empty = server.get("/api/sampling").await;
    assert_eq!((empty.0, &empty.1["temperature"]), (200, &Value::Null));
    let typed = json!({ "temperature": 0.7, "seed": 3 });
    let (status, kept) = server.put("/api/sampling", typed).await;
    assert_eq!(status, 200, "{kept}");
    assert_eq!(
        (&kept["temperature"], &kept["seed"]),
        (&json!(0.7), &json!(3))
    );
    assert_eq!(server.get("/api/sampling").await.1, kept);

    let (status, why) = server
        .put("/api/sampling", json!({ "temperature": 2.5 }))
        .await;
    assert_eq!(status, 400);
    assert_eq!(why["error"], "temperature must be from 0 to 2");
    assert_eq!(server.get("/api/sampling").await.1, kept);

    // The chat model is asked with them.
    let rig = add(&server, json!({ "base_url": RIG })).await;
    let chat = json!({ "provider_id": rig, "model": "tide-1" });
    server.put("/api/kinds/chat", chat).await;
    assert_eq!(server.get("/api/provider").await.1["sampling"], kept);
}

#[tokio::test]
async fn a_form_left_without_a_key_sends_the_key_of_the_provider_at_its_address() {
    let list = json!({ "data": [{ "id": "tide-1" }] }).to_string();
    let api = Api::start(says(200, JSON, &list)).await;
    let server = start().await;
    // The chat model is elsewhere; the provider at the form's address has a key.
    let chat = json!({ "base_url": RIG, "model": "rig-1", "api_key": "sk-rig-0123456789" });
    assert_eq!(server.put("/api/provider", chat).await.0, 200);
    add(
        &server,
        json!({ "base_url": api.url, "api_key": "sk-entry-0123456789" }),
    )
    .await;
    let (status, listed) = server
        .post("/api/provider/models", json!({ "base_url": api.url }))
        .await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        api.last_key().as_deref(),
        Some("Bearer sk-entry-0123456789")
    );
}

#[tokio::test]
async fn the_values_for_a_reply_stay_when_the_last_provider_goes_and_another_is_set_up() {
    let server = start().await;
    let values = json!({ "temperature": 0.4, "context_size": 8000 });
    assert_eq!(server.put("/api/sampling", values).await.0, 200);
    let id = add(&server, json!({ "base_url": RIG })).await;
    let chat = json!({ "provider_id": id, "model": "rig-1" });
    assert_eq!(server.put("/api/kinds/chat", chat).await.0, 200);
    let path = format!("/api/provider-list/{id}");
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 204);
    // First run again, without values: the account's stay.
    let again = json!({ "base_url": OTHER, "model": "other-1" });
    assert_eq!(server.put("/api/provider", again).await.0, 200);
    let kept = server.get("/api/sampling").await.1;
    assert_eq!(
        (kept["temperature"].clone(), kept["context_size"].clone()),
        (json!(0.4), json!(8000))
    );
}

#[tokio::test]
async fn a_providers_new_key_goes_to_its_presets() {
    let server = start().await;
    let chat = json!({ "base_url": RIG, "model": "rig-1", "api_key": "sk-old-0123456789" });
    assert_eq!(server.put("/api/provider", chat).await.0, 200);
    let (status, preset) = server.post("/api/presets", json!({ "name": "Fast" })).await;
    assert_eq!(status, 201, "{preset}");
    let id = server.get("/api/provider-list").await.1["providers"][0]["id"].clone();
    let path = format!("/api/provider-list/{id}");
    let new_key = json!({ "base_url": RIG, "api_key": "sk-new-0123459999" });
    assert_eq!(server.patch(&path, new_key).await.0, 200);
    // Still the preset in use; put in use, it is at the provider, with the new key.
    assert_eq!(server.get("/api/presets").await.1[0]["in_use"], true);
    let used = format!("/api/presets/{}/use", preset["id"]);
    assert_eq!(server.post(&used, json!({})).await.0, 200);
    let listed = server.get("/api/provider-list").await.1;
    assert_eq!(listed["providers"].as_array().unwrap().len(), 1);
    assert_eq!(listed["providers"][0]["key_end"], "9999");
}

#[tokio::test]
async fn a_provider_added_without_a_key_is_the_one_with_the_key_kept_at_its_address() {
    let server = start().await;
    let stored = json!({ "base_url": RIG, "model": "tide-1", "api_key": "sk-rig-0123456789" });
    assert_eq!(server.set_provider(stored).await.0, 200);
    let (status, added) = server
        .post("/api/provider-list", json!({ "base_url": RIG }))
        .await;
    assert_eq!(status, 201, "{added}");
    assert_eq!(added["has_key"], true);
    let listed = server.get("/api/provider-list").await.1;
    assert_eq!(listed["providers"].as_array().unwrap().len(), 1);
}

#[tokio::test]
async fn first_run_stores_all_of_it_or_nothing_and_leaves_the_values_where_none_are_given() {
    let server = start().await;
    let first = json!({ "base_url": RIG, "model": "tide-1", "api_key": "sk-rig-0123456789" });
    assert_eq!(server.put("/api/provider", first).await.0, 200);
    let before = server.get("/api/provider-list").await.1;

    // A new provider, a new name and a background model, refused for its image model: none of it is kept.
    let wrong = json!({ "base_url": OTHER, "model": "tide-2", "api_key": "sk-other-0123456789",
        "name": "Other", "worker_model": "tide-3", "image_model": " " });
    let (status, _) = server.put("/api/provider", wrong).await;
    assert_eq!(status, 400);
    assert_eq!(server.get("/api/provider-list").await.1, before);

    // All of it at once: the image model at the chat model's provider.
    let whole = json!({ "base_url": OTHER, "model": "tide-2", "api_key": "sk-other-0123456789",
        "worker_model": "tide-3", "image_model": "paint-1" });
    assert_eq!(server.put("/api/provider", whole).await.0, 200);
    let other = add(
        &server,
        json!({ "base_url": OTHER, "api_key": "sk-other-0123456789" }),
    )
    .await;
    assert_eq!(
        kinds(&server).await,
        [
            kind("chat", other, "tide-2", "on"),
            kind("background", other, "tide-3", "on"),
            kind("images", other, "paint-1", "on"),
        ]
    );

    let values = json!({ "temperature": 0.5 });
    assert_eq!(server.put("/api/sampling", values).await.0, 200);
    let again = json!({ "base_url": RIG, "model": "tide-1" });
    assert_eq!(server.put("/api/provider", again).await.0, 200);
    assert_eq!(server.get("/api/sampling").await.1["temperature"], 0.5);
}

#[tokio::test]
async fn a_key_the_providers_list_of_models_refuses_is_not_saved_at_add_or_change() {
    // As xAI refuses a made-up key: 400 with words of the key.
    let refusing = r#"{"code":"invalid-argument","error":"Incorrect API key provided."}"#;
    let api = Api::start(says(400, JSON, refusing)).await;
    let server = start().await;
    let asked = json!({ "base_url": api.url, "api_key": "xai-0000000000000000" });
    let (status, refused) = server.post("/api/provider-list", asked).await;
    assert_eq!(
        (status, &refused["details"]["what"]),
        (400, &json!("key_refused")),
        "{refused}"
    );

    let id = add(&server, json!({ "base_url": RIG })).await;
    let changed = json!({ "base_url": api.url, "api_key": "xai-0000000000000000" });
    let (status, refused) = server
        .patch(&format!("/api/provider-list/{id}"), changed)
        .await;
    assert_eq!(
        (status, &refused["details"]["what"]),
        (400, &json!("key_refused")),
        "{refused}"
    );
}

/// Setup run again with a corrected key for an address that has a provider
/// gives that provider the key, rather than adding a second beside it.
#[tokio::test]
async fn setup_again_with_another_key_corrects_the_provider_at_its_address() {
    let list = json!({ "data": [{ "id": "tide-1" }] }).to_string();
    let api = Api::start(says(200, JSON, &list)).await;
    let server = start().await;
    let old = json!({ "base_url": api.url, "api_key": "sk-old-0123456789" });
    add(&server, old).await;
    let new = json!({ "base_url": api.url, "model": "tide-1", "api_key": "sk-new-0123456789" });
    assert_eq!(server.put("/api/provider", new).await.0, 200);

    let listed = server.get("/api/provider-list").await.1;
    assert_eq!(listed["providers"].as_array().unwrap().len(), 1, "{listed}");
    let asked = json!({ "base_url": api.url });
    assert_eq!(server.post("/api/provider/models", asked).await.0, 200);
    assert_eq!(api.last_key().as_deref(), Some("Bearer sk-new-0123456789"));
}

#[tokio::test]
async fn a_provider_added_with_no_chat_model_picked_says_none_is_chosen() {
    let server = start().await;
    add(
        &server,
        json!({ "base_url": RIG, "api_key": "sk-rig-secret-1234" }),
    )
    .await;
    let picks = json!({
        "gender": "Woman", "being": "Human", "age": "30s", "build": "Athletic", "hair": "Long", "hair_colour": "Red",
        "shy_outgoing": 20, "gentle_harsh": 55, "serious_playful": 70, "cautious_bold": 95,
        "relationship": "Rival", "name": "Mara", "creator": "local",
    });
    let (status, refused) = server.post("/api/generator", picks).await;
    assert_eq!(
        (status, &refused["details"]),
        (424, &json!({ "what": "chat_model" })),
        "{refused}"
    );
}

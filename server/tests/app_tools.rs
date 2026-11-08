//! Cardwave's own API as tools (`tools/app.rs`): a tool per route, listed at
//! build with its types, and a chat without a character that reads Cardwave
//! unasked and changes it once the user allows it, asking as the device the
//! chat is on; a cut answer says so. MCP's side is in `mcp.rs`.

mod common;

use cardwave_server::api::app_tools::tool_routes;
use common::model::{Model, call_pieces, names, stream, text_piece};
use common::server::{Server, Socket, WAIT, device, event, start};
use cw_chat::assistant::{self, Tool};
use cw_coding::tools::app;
use cw_library::settings::Tools;
use serde_json::{Value, json};
use tokio::time::timeout;

#[test]
fn every_route_of_the_api_is_a_tool_once() {
    let all = tool_routes();
    let mut seen = std::collections::HashSet::new();
    for route in all {
        assert!(seen.insert(route.name), "{} twice", route.name);
        let fits = route.name.len() <= 64
            && route
                .name
                .chars()
                .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_');
        assert!(fits, "{}", route.name);
    }
    assert!(all.len() > 150, "{}", all.len());

    let new = app::named(tool_routes(), "post_cards_new").expect("a card is made by a tool");
    assert!(new.changes());
    let help = new.help();
    assert!(help.starts_with("POST /api/cards/new"), "{help}");
    assert!(help.contains("greetings: Array<string>"), "{help}");
    let read = app::named(tool_routes(), "get_cards_id").unwrap();
    assert!(!read.changes());
    assert_eq!(read.params, [("id", "integer")]);
    // Its query's type, and the types the body names, declared after it.
    let drafts = app::named(tool_routes(), "get_cards_id_drafts")
        .unwrap()
        .help();
    assert!(drafts.contains("query: {"), "{drafts}");
    let sent = app::named(tool_routes(), "post_chats_id_messages")
        .unwrap()
        .help();
    assert!(sent.contains("content: string"), "{sent}");
    assert!(sent.contains("type Role = "), "{sent}");
    // A file sent as the body, MCP itself, the gate before the app opens and
    // what counts tries by the address it came from are no tools.
    for none in [
        "post_cards",
        "post_mcp",
        "get_lock",
        "post_unlock",
        "put_password",
    ] {
        assert!(app::named(tool_routes(), none).is_none(), "{none}");
    }
    // A doc's links of rustdoc are their words alone.
    for route in all {
        assert!(
            !route.doc.contains(['`', '[']),
            "{}: {}",
            route.name,
            route.doc
        );
    }
}

#[test]
fn a_personality_can_be_let_use_cardwave_or_not() {
    let mut tools = Tools {
        app: true,
        ..Tools::default()
    };
    assert!(assistant::offered(&tools, false, false).contains(&Tool::Cardwave));
    assistant::restrict(&mut tools, &[Tool::Cardwave]);
    assert!(!tools.app);
}

/// The next event of the socket of the kind `kind`, those before passed by.
async fn next_of(socket: &mut Socket, kind: &str) -> Value {
    loop {
        let event = timeout(WAIT, event(socket)).await.expect("an event");
        if event["type"] == kind {
            return event;
        }
    }
}

/// A chat without a character at `model`, with Cardwave's tools on: its address.
async fn plain_chat(server: &Server, model: &Model) -> String {
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let on = json!({ "tools": { "app": true } });
    assert_eq!(
        server.patch("/api/settings", on).await.1["tools"]["app"],
        true
    );
    let (_, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    format!("/api/chats/{}", view["chat"]["id"])
}

#[tokio::test]
async fn a_chat_reads_cardwave_unasked_and_changes_it_once_allowed() {
    let server = start().await;
    let card = json!({ "title": "North Light", "tags": [], "creator": "", "name": "Mira", "greetings": ["You came."], "description": "A keeper.", "personality": "", "scenario": "", "example_dialogue": "", "creator_notes": "" });
    let list = json!({ "tool": "get_cards", "arguments": {} });
    let make = json!({ "tool": "post_cards_new", "arguments": { "body": card } });
    let mut long = card.clone();
    long["description"] = json!("a".repeat(10_000));
    let again = json!({ "tool": "post_cards_new", "arguments": { "body": long } });
    let model = Model::start(vec![
        (200, stream(&call_pieces(app::CALL, &list))),
        (200, stream(&[text_piece("Your library is empty.")])),
        (200, stream(&call_pieces(app::CALL, &make))),
        (200, stream(&[text_piece("Made.")])),
        (200, stream(&call_pieces(app::CALL, &again))),
        (200, stream(&[text_piece("Not made.")])),
    ])
    .await;
    let chat = plain_chat(&server, &model).await;
    let mut socket = server.listen().await;

    let said = json!({ "content": "What cards do I have?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_of(&mut socket, "reply_ended").await;
    assert_eq!(
        ended["message"]["content"], "Your library is empty.",
        "{ended}"
    );
    let asked = model.asked();
    assert_eq!(names(&asked[0]["tools"]), [app::CALL, app::HELP]);
    let given = asked[1]["messages"].as_array().unwrap().last().unwrap();
    assert_eq!(given["role"], "tool");
    assert_eq!(
        given["content"],
        server.get("/api/cards").await.1.to_string()
    );

    let said = json!({ "content": "Make me a lighthouse keeper." });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let asks = next_of(&mut socket, "tool_asks").await;
    assert_eq!(asks["ask"]["kind"], "app", "{asks}");
    assert_eq!(asks["ask"]["what"], "post_cards_new");
    let detail = asks["ask"]["detail"].as_str().unwrap();
    assert!(detail.starts_with("POST /api/cards/new\n"), "{detail}");
    assert!(detail.contains("\"North Light\""), "{detail}");
    assert_eq!(server.get("/api/cards").await.1, json!([]));

    // Allowed "for the chat", a change is asked about the next time too.
    let allow = json!({ "allow": true, "for_chat": true });
    assert_eq!(server.post(&format!("{chat}/answer"), allow).await.0, 204);
    let ended = next_of(&mut socket, "reply_ended").await;
    assert_eq!(ended["message"]["content"], "Made.", "{ended}");
    let (_, cards) = server.get("/api/cards").await;
    assert_eq!(cards[0]["title"], "North Light", "{cards}");
    let given = model.asked()[3]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()
        .clone();
    assert!(
        given["content"].as_str().unwrap().contains("North Light"),
        "{given}"
    );

    let said = json!({ "content": "Once more, at length." });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let asks = next_of(&mut socket, "tool_asks").await;
    let detail = asks["ask"]["detail"].as_str().unwrap();
    // What the user is shown is cut, with "…".
    assert_eq!(detail.chars().count(), 4_001, "{}", detail.len());
    assert!(detail.ends_with('…'));
    let deny = json!({ "allow": false });
    assert_eq!(server.post(&format!("{chat}/answer"), deny).await.0, 204);
    next_of(&mut socket, "reply_ended").await;
    assert_eq!(
        server.get("/api/cards").await.1.as_array().unwrap().len(),
        1
    );
}

#[tokio::test]
async fn a_chat_with_a_character_in_roleplay_has_no_cardwave() {
    let server = start().await;
    let model = Model::start(vec![(200, stream(&[text_piece("Hello.")]))]).await;
    plain_chat(&server, &model).await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    next_of(&mut socket, "reply_ended").await;
    assert!(model.asked()[0].get("tools").is_none());
}

#[tokio::test]
async fn a_tool_asks_as_the_device_the_chat_is_on() {
    use reqwest::Method;
    let server = start().await;
    let mut device = device(&server, true).await;
    let list = json!({ "tool": "get_accounts", "arguments": {} });
    let signing = json!({ "tool": "get_sign_in", "arguments": {} });
    let model = Model::start(vec![
        (200, stream(&call_pieces(app::CALL, &list))),
        (200, stream(&call_pieces(app::CALL, &signing))),
        (200, stream(&[text_piece("Listed.")])),
    ])
    .await;
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    let (status, _) = device
        .call(Method::PUT, "/api/provider", Some(provider))
        .await;
    assert_eq!(status, 200);
    let on = json!({ "tools": { "app": true } });
    let (_, settings) = device.call(Method::PATCH, "/api/settings", Some(on)).await;
    assert_eq!(settings["tools"]["app"], true);
    let empty = json!({ "characters": [] });
    let (_, view) = device.call(Method::POST, "/api/chats", Some(empty)).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let said = json!({ "content": "Who uses Cardwave?" });
    let messages = format!("{chat}/messages");
    assert_eq!(
        device.call(Method::POST, &messages, Some(said)).await.0,
        201
    );
    let generate = format!("{chat}/generate");
    let started = device.call(Method::POST, &generate, Some(json!({}))).await;
    assert_eq!(started.0, 202, "{}", started.1);

    timeout(WAIT, async {
        while model.asked().len() < 3 {
            tokio::time::sleep(std::time::Duration::from_millis(30)).await;
        }
    })
    .await
    .expect("the tool's answer");
    let given = model.asked()[1]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()
        .clone();
    // The accounts as the device sees them: not this computer's, which it cannot sign in to.
    let (_, seen) = device.call(Method::GET, "/api/accounts", None).await;
    let given: Value = serde_json::from_str(given["content"].as_str().unwrap()).unwrap();
    assert_eq!(given, seen);
    assert_eq!(seen.as_array().unwrap().len(), 1, "{seen}");
    // The sign-in screen's routes, which read it from the request, see another device too.
    let given = model.asked()[2]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()
        .clone();
    let given: Value = serde_json::from_str(given["content"].as_str().unwrap()).unwrap();
    assert_eq!(given["remote"], true, "{given}");
}

#[test]
fn a_cut_answer_says_where_and_of_how_many() {
    use cw_coding::tools::web::cut;
    let text = "é".repeat(30);
    assert_eq!(
        cut(&text, 20),
        format!("{}\n… (cut at 20 characters of 30)", "é".repeat(20))
    );
    assert_eq!(cut(&text, 30), text);
}

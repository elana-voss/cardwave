//! The MCP server (`api/mcp.rs`): an older client's `initialize`, a newer
//! one's `server/discover` and its headers, the cards and chats read as the API
//! gives them, a long chat in pages, a message sent and its reply, the tools
//! Settings › Tools switches on with Cardwave's own one per route, who
//! reaches it, and Account › Server's switch, account and programs.
//!
//! `serving` is a server whose MCP server is switched on. `older` sends as a
//! client of 2025-11-25 does, `newer` as one of 2026-07-28, with the request's
//! `_meta` and the headers that mirror it.

mod common;

use common::api::{Api, says};
use common::model::{Model, call_pieces, stream};
use common::server::{Server, device, start};
use cw_coding::tools::{self, written};
use cw_key::FILE_NAME;
use cw_provider::pretend;
use cw_store::Db;
use serde_json::{Value, json};

const PATH: &str = "/api/mcp";

/// A server whose MCP server is switched on.
async fn serving() -> Server {
    let server = start().await;
    let (status, set) = server.put("/api/mcp/settings", json!({ "on": true })).await;
    assert_eq!(status, 200, "{set}");
    server
}

/// `initialize` as the program `name` sends it: the status and the answer.
async fn hello(server: &Server, name: &str) -> (u16, Value) {
    let hello = json!({ "protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": { "name": name, "version": "1" } });
    let body = json!({ "jsonrpc": "2.0", "id": 0, "method": "initialize", "params": hello });
    post(server, &[], &body).await
}

/// Posts `body` to the MCP server with `headers`; the status and the JSON body (`Null` when it has none).
async fn post(server: &Server, headers: &[(&str, &str)], body: &Value) -> (u16, Value) {
    let mut request = reqwest::Client::new()
        .post(format!("http://{}{PATH}", server.addr))
        .header("accept", "application/json, text/event-stream")
        .json(body);
    for (name, value) in headers {
        request = request.header(*name, *value);
    }
    let response = request.send().await.unwrap();
    let status = response.status().as_u16();
    (status, response.json().await.unwrap_or(Value::Null))
}

/// A request as a client of 2025-11-25 sends it, after `initialize`.
async fn older(server: &Server, method: &str, params: Value) -> (u16, Value) {
    let body = json!({ "jsonrpc": "2.0", "id": 1, "method": method, "params": params });
    post(server, &[("mcp-protocol-version", "2025-11-25")], &body).await
}

/// A request as a client of 2026-07-28 sends it.
async fn newer(server: &Server, method: &str, mut params: Value) -> (u16, Value) {
    params["_meta"] = json!({
        "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": {},
        "io.modelcontextprotocol/clientInfo": { "name": "test", "version": "1" },
    });
    let name = params["name"].as_str().unwrap_or_default().to_string();
    let mut headers = vec![
        ("mcp-protocol-version", "2026-07-28"),
        ("mcp-method", method),
    ];
    if !name.is_empty() {
        headers.push(("mcp-name", &name));
    }
    let body = json!({ "jsonrpc": "2.0", "id": "a", "method": method, "params": params });
    post(server, &headers, &body).await
}

/// What a call of the tool `name` gave: its result.
async fn call(server: &Server, name: &str, arguments: Value) -> Value {
    let (status, answer) = newer(
        server,
        "tools/call",
        json!({ "name": name, "arguments": arguments }),
    )
    .await;
    assert_eq!(status, 200, "{answer}");
    answer["result"].clone()
}

/// The text a call gave, read as JSON.
fn json_of(result: &Value) -> Value {
    assert_eq!(result["isError"], false, "{result}");
    serde_json::from_str(result["content"][0]["text"].as_str().unwrap()).unwrap()
}

fn names(listed: &Value) -> Vec<&str> {
    listed["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| tool["name"].as_str().unwrap())
        .collect()
}

#[tokio::test]
async fn an_older_client_begins_with_initialize_and_lists_the_tools() {
    let server = serving().await;
    let hello = json!({
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": { "name": "test", "version": "1" },
    });
    let body = json!({ "jsonrpc": "2.0", "id": 0, "method": "initialize", "params": hello });
    let (status, answer) = post(&server, &[], &body).await;
    assert_eq!(status, 200, "{answer}");
    let result = &answer["result"];
    assert_eq!(answer["id"], 0);
    assert_eq!(result["protocolVersion"], "2025-06-18");
    assert_eq!(result["serverInfo"]["name"], "cardwave");
    assert!(result["capabilities"]["tools"].is_object(), "{answer}");
    // A version it does not know is answered with the newest of the older ones.
    let mut later = body.clone();
    later["params"]["protocolVersion"] = json!("2099-01-01");
    let (_, answer) = post(&server, &[], &later).await;
    assert_eq!(answer["result"]["protocolVersion"], "2025-11-25");

    let told = json!({ "jsonrpc": "2.0", "method": "notifications/initialized" });
    assert_eq!(post(&server, &[], &told).await, (202, Value::Null));
    assert_eq!(
        older(&server, "ping", json!({})).await.1["result"],
        json!({})
    );
    let nameless = json!({ "jsonrpc": "2.0", "id": 6 });
    let (status, refused) = post(&server, &[], &nameless).await;
    assert_eq!((status, &refused["error"]["code"]), (400, &json!(-32600)));
    let answered = json!({ "jsonrpc": "2.0", "id": 6, "result": {} });
    assert_eq!(post(&server, &[], &answered).await.0, 202);
    let batch = json!([{ "jsonrpc": "2.0", "id": 5, "method": "ping" }]);
    let (status, refused) = post(&server, &[], &batch).await;
    assert_eq!((status, &refused["error"]["code"]), (400, &json!(-32600)));
    // JSON-RPC: an error whose request's id is not known has a null id.
    assert_eq!(refused.get("id"), Some(&Value::Null), "{refused}");
    let (status, listed) = older(&server, "tools/list", json!({})).await;
    assert_eq!(status, 200, "{listed}");
    // What the newer revision adds to a result an older client is not given.
    assert_eq!(listed["result"].get("resultType"), None, "{listed}");
    // Without a tool switched on in the settings, the cards and the chats alone.
    assert_eq!(
        names(&listed),
        [
            "list_cards",
            "read_card",
            "list_chats",
            "read_chat",
            "send_message"
        ]
    );
    let schema = &listed["result"]["tools"][1]["inputSchema"];
    assert_eq!(schema["required"], json!(["card_id"]), "{listed}");
}

#[tokio::test]
async fn cards_and_chats_are_read_as_the_api_gives_them() {
    let server = serving().await;
    let (_, imported) = server.upload("/api/cards", common::card_file()).await;
    let card = imported["card_id"].as_i64().unwrap();
    let characters = json!([{ "version_id": imported["version_id"], "character": "mira" }]);
    let (_, started) = server
        .post("/api/chats", json!({ "characters": characters }))
        .await;
    let chat = started["chat"]["id"].as_i64().unwrap();

    let found = json_of(&call(&server, "list_cards", json!({ "query": "north" })).await);
    assert_eq!(found, server.get("/api/cards?q=north").await.1);
    assert_eq!(found[0]["id"], card);
    let none = json_of(&call(&server, "list_cards", json!({ "query": "harbour" })).await);
    assert_eq!(none, json!([]));
    let read = json_of(&call(&server, "read_card", json!({ "card_id": card })).await);
    assert_eq!(read, server.get(&format!("/api/cards/{card}")).await.1);
    let chats = json_of(&call(&server, "list_chats", json!({})).await);
    assert_eq!(chats, server.get("/api/chats").await.1);
    let read = json_of(&call(&server, "read_chat", json!({ "chat_id": chat })).await);
    assert_eq!(read, server.get(&format!("/api/chats/{chat}")).await.1);

    let missing = call(&server, "read_chat", json!({ "chat_id": chat + 100 })).await;
    assert_eq!(missing["isError"], true, "{missing}");
    assert!(
        missing["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("no such chat"),
        "{missing}"
    );
}

#[tokio::test]
async fn a_newer_client_is_answered_by_its_revision() {
    let server = serving().await;
    let (status, found) = newer(&server, "server/discover", json!({})).await;
    assert_eq!(status, 200, "{found}");
    let result = &found["result"];
    assert_eq!(result["resultType"], "complete");
    assert_eq!(result["supportedVersions"][0], "2026-07-28");
    assert!(result["capabilities"]["tools"].is_object(), "{found}");
    assert_eq!(
        result["_meta"]["io.modelcontextprotocol/serverInfo"]["name"],
        "cardwave"
    );
    let (_, listed) = newer(&server, "tools/list", json!({})).await;
    assert_eq!(listed["result"]["cacheScope"], "private", "{listed}");
    assert_eq!(listed["result"]["resultType"], "complete", "{listed}");

    let meta = json!({ "io.modelcontextprotocol/protocolVersion": "2026-07-28" });
    let list =
        json!({ "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": { "_meta": meta } });
    let version = ("mcp-protocol-version", "2026-07-28");
    // The headers mirror the body, or the request is refused.
    let (status, wrong) = post(&server, &[version, ("mcp-method", "tools/call")], &list).await;
    assert_eq!(
        (status, &wrong["error"]["code"]),
        (400, &json!(-32020)),
        "{wrong}"
    );
    let (status, wrong) = post(&server, &[("mcp-method", "tools/list")], &list).await;
    assert_eq!(
        (status, &wrong["error"]["code"]),
        (400, &json!(-32020)),
        "{wrong}"
    );
    // A name may come in Base64.
    let read = json!({ "jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
        "_meta": meta, "name": "list_chats", "arguments": {} } });
    let named = [
        version,
        ("mcp-method", "tools/call"),
        ("mcp-name", "=?base64?bGlzdF9jaGF0cw==?="),
    ];
    let (status, answer) = post(&server, &named, &read).await;
    assert_eq!(status, 200, "{answer}");
    let named = [
        version,
        ("mcp-method", "tools/call"),
        ("mcp-name", "list_cards"),
    ];
    assert_eq!(post(&server, &named, &read).await.0, 400);

    let later = json!({ "io.modelcontextprotocol/protocolVersion": "2099-01-01" });
    let list =
        json!({ "jsonrpc": "2.0", "id": 4, "method": "tools/list", "params": { "_meta": later } });
    let headers = [
        ("mcp-protocol-version", "2099-01-01"),
        ("mcp-method", "tools/list"),
    ];
    let (status, refused) = post(&server, &headers, &list).await;
    assert_eq!(status, 400, "{refused}");
    assert_eq!(refused["error"]["code"], -32022);
    assert_eq!(refused["error"]["data"]["requested"], "2099-01-01");
    assert!(
        refused["error"]["data"]["supported"]
            .as_array()
            .unwrap()
            .contains(&json!("2025-11-25"))
    );

    let (status, unknown) = newer(&server, "prompts/list", json!({})).await;
    assert_eq!((status, &unknown["error"]["code"]), (404, &json!(-32601)));
    let got = reqwest::get(format!("http://{}{PATH}", server.addr))
        .await
        .unwrap();
    assert_eq!(got.status(), 405);
}

#[tokio::test]
async fn the_tools_the_settings_switch_on_are_offered_and_one_that_asks_refused() {
    let server = serving().await;
    let folder = common::Folder::new("mcp");
    let path = folder.path();
    let tools = json!({ "tools": { "files": true, "web": true, "folder": path } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);

    let (_, listed) = newer(&server, "tools/list", json!({})).await;
    let names = names(&listed);
    for name in ["read_web_page", "list_files", "read_file", "write_file"] {
        assert!(names.contains(&name), "{name}: {names:?}");
    }
    let write = json!({ "path": "note.txt", "content": "the lamp is lit" });
    let refused = call(&server, "write_file", write.clone()).await;
    assert_eq!(refused["isError"], true, "{refused}");
    assert!(
        refused["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("Ask before writing"),
        "{refused}"
    );
    assert!(!folder.0.join("note.txt").exists());
    // A program writes no tool: that is a chat's Code mode, and it has no chat.
    assert!(!names.contains(&"make_tool"), "{names:?}");
    let tool = json!({ "name": "shout", "description": "Shouts.", "parameters": { "type": "object" }, "code": "export default () => 'HI'" });
    let made = json!({ "name": "make_tool", "arguments": tool });
    let (_, unknown) = newer(&server, "tools/call", made).await;
    assert!(
        unknown["error"]["message"]
            .as_str()
            .unwrap()
            .contains("Unknown tool"),
        "{unknown}"
    );

    // A tool the model wrote in a chat reads the folder, and its write is refused, as nobody here can allow it.
    std::fs::write(folder.0.join("lamp.txt"), "lit").unwrap();
    let code = "export default () => { const said = readFile('lamp.txt'); try { writeFile('copy.txt', said); return 'wrote'; } catch (e) { return 'refused ' + said; } }";
    let tool = json!({ "name": "copy_lamp", "description": "Copies.", "parameters": { "type": "object" }, "code": code });
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    let user = db
        .with(|conn| conn.query_row("select min(id) from users", [], |r| r.get(0)))
        .unwrap();
    written::add(
        &db,
        user,
        None,
        &written::check(&tool.to_string(), |_| false).unwrap(),
    )
    .unwrap();
    let copied = call(&server, "copy_lamp", json!({})).await;
    assert_eq!(copied["content"][0]["text"], "refused lit", "{copied}");
    assert!(!folder.0.join("copy.txt").exists());

    let unasked = json!({ "tools": { "ask_writes": false } });
    assert_eq!(server.patch("/api/settings", unasked).await.0, 200);
    let written = call(&server, "write_file", write).await;
    assert_eq!(written["isError"], false, "{written}");
    let read = call(&server, "read_file", json!({ "path": "note.txt" })).await;
    assert_eq!(read["content"][0]["text"], "the lamp is lit");
    // What a file says is no failure, whatever its words.
    std::fs::write(folder.0.join("log.txt"), "Failed: the lamp").unwrap();
    let read = call(&server, "read_file", json!({ "path": "log.txt" })).await;
    assert_eq!(read["isError"], false, "{read}");

    let (status, unknown) = newer(
        &server,
        "tools/call",
        json!({ "name": "run_command", "arguments": {} }),
    )
    .await;
    assert_eq!(
        (status, &unknown["error"]["code"]),
        (200, &json!(-32602)),
        "{unknown}"
    );
}

#[tokio::test]
async fn a_picture_comes_as_an_image() {
    use base64::Engine;
    let picture = common::picture();
    let made = base64::engine::general_purpose::STANDARD.encode(&picture);
    let images = Api::start(says(
        200,
        "application/json",
        &json!({ "data": [{ "b64_json": made }] }).to_string(),
    ))
    .await;
    let server = serving().await;
    let own = json!({ "base_url": images.url, "api_key": "sk-img", "model": "gpt-image-1" });
    assert_eq!(server.set_images(own).await.0, 200);
    let on = json!({ "tools": { "pictures": true } });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);

    let result = call(
        &server,
        "make_picture",
        json!({ "description": "a lighthouse" }),
    )
    .await;
    assert_eq!(result["isError"], false, "{result}");
    let image = &result["content"][1];
    assert_eq!(
        (&image["type"], &image["mimeType"]),
        (&json!("image"), &json!("image/png"))
    );
    assert_eq!(image["data"], made);
}

#[tokio::test]
async fn only_this_computer_reaches_it() {
    let server = serving().await;
    let list = json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/list" });
    // A page of another site, whose name was made to lead to this computer.
    let (status, _) = post(&server, &[("host", "cards.example:8477")], &list).await;
    assert_eq!(status, 403);

    // Another device, signed in to an account.
    let mut ada = device(&server, true).await;
    assert_eq!(ada.post(PATH, list).await.0, 403);
}

#[tokio::test]
async fn the_owner_switches_it_on_picks_the_account_and_removes_a_program() {
    let server = start().await;
    let (_, settings) = server.get("/api/mcp/settings").await;
    let local = settings["account"].clone();
    assert_eq!(
        settings,
        json!({ "on": false, "account": local, "programs": [] })
    );
    // Off at first: nothing is served.
    let (status, refused) = hello(&server, "Claude").await;
    assert_eq!(status, 403, "{refused}");
    // It names the switch and its page as the app shows them.
    let told = refused["error"]["message"].as_str().unwrap();
    assert!(
        told.contains("\"Let AI apps on this computer use Cardwave\"")
            && told.contains("Account › Sharing"),
        "{told}"
    );

    assert_eq!(
        server
            .put("/api/mcp/settings", json!({ "on": true }))
            .await
            .0,
        200
    );
    assert_eq!(hello(&server, "Claude").await.0, 200);
    assert_eq!(hello(&server, "Inspector").await.0, 200);
    let (_, settings) = server.get("/api/mcp/settings").await;
    assert_eq!(settings["programs"], json!(["Claude", "Inspector"]));

    // Another account's cards, as the account it serves.
    let (_, ada) = server
        .post(
            "/api/accounts",
            json!({ "name": "Ada", "password": "lantern" }),
        )
        .await;
    server.upload("/api/cards", common::card_file()).await;
    let (status, set) = server
        .put("/api/mcp/settings", json!({ "account": ada["id"] }))
        .await;
    assert_eq!((status, &set["account"]), (200, &ada["id"]), "{set}");
    assert_eq!(
        json_of(&call(&server, "list_cards", json!({})).await),
        json!([])
    );
    assert_eq!(
        server
            .put("/api/mcp/settings", json!({ "account": 999 }))
            .await
            .0,
        404
    );

    // An older client is given its name as its session id, which it sends back.
    let body = json!({ "jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {
        "protocolVersion": "2025-11-25", "clientInfo": { "name": "Claude", "version": "1" } } });
    let given = reqwest::Client::new()
        .post(format!("http://{}{PATH}", server.addr))
        .json(&body)
        .send()
        .await
        .unwrap();
    let session = given.headers()["mcp-session-id"]
        .to_str()
        .unwrap()
        .to_string();
    let list = json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/list" });
    let named = [("mcp-session-id", session.as_str())];
    assert_eq!(post(&server, &named, &list).await.0, 200);

    // A program removed is refused until the switch is switched on anew.
    let (_, set) = server
        .put("/api/mcp/settings", json!({ "remove": "Claude" }))
        .await;
    assert_eq!(set["programs"], json!(["Inspector", "test"]));
    let (status, refused) = hello(&server, "Claude").await;
    assert_eq!(status, 403, "{refused}");
    let told = refused["error"]["message"].as_str().unwrap();
    assert!(
        told.contains("\"Let AI apps on this computer use Cardwave\"")
            && told.contains("Account › Sharing"),
        "{told}"
    );
    assert_eq!(post(&server, &named, &list).await.0, 403);
    assert_eq!(
        server
            .put("/api/mcp/settings", json!({ "on": false }))
            .await
            .0,
        200
    );
    let (_, set) = server.put("/api/mcp/settings", json!({ "on": true })).await;
    assert_eq!(set["programs"], json!([]));
    assert_eq!(hello(&server, "Claude").await.0, 200);
}

#[tokio::test]
async fn cardwaves_own_tools_come_one_per_route_and_run_as_the_api() {
    let server = serving().await;
    // A tool the model wrote before a route had its name.
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    let user = db
        .with(|conn| conn.query_row("select min(id) from users", [], |r| r.get(0)))
        .unwrap();
    let tool = json!({ "name": "old_documents", "description": "Says.", "parameters": { "type": "object" }, "code": "export default () => 'mine'" });
    let mut tool = written::check(&tool.to_string(), |_| false).unwrap();
    tool.name = "get_documents".into();
    written::add(&db, user, None, &tool).unwrap();
    let (_, listed) = newer(&server, "tools/list", json!({})).await;
    assert!(!names(&listed).contains(&"post_cards_new"), "{listed}");
    assert!(names(&listed).contains(&"get_documents"), "{listed}");
    let on = json!({ "tools": { "app": true } });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);

    let (_, listed) = newer(&server, "tools/list", json!({})).await;
    let all = names(&listed);
    // Not the chat model's two, which name the others.
    assert!(!all.contains(&tools::app::CALL), "{all:?}");
    assert!(all.len() > 150, "{}", all.len());
    // The route's, once.
    assert_eq!(
        all.iter().filter(|name| **name == "get_documents").count(),
        1
    );
    let documents = json_of(&call(&server, "get_documents", json!({})).await);
    assert!(documents.is_array(), "{documents}");
    let tools = listed["result"]["tools"].as_array().unwrap();
    let new = tools
        .iter()
        .find(|tool| tool["name"] == "post_cards_new")
        .unwrap();
    assert_eq!(new["annotations"]["readOnlyHint"], false);
    assert_eq!(new["inputSchema"]["required"], json!(["body"]));
    let removed = tools
        .iter()
        .find(|tool| tool["name"] == "delete_cards_id")
        .unwrap();
    assert_eq!(removed["annotations"]["destructiveHint"], true);
    assert_eq!(
        removed["inputSchema"]["properties"]["id"]["type"],
        "integer"
    );

    // The program asks its user; Cardwave does not.
    let card = json!({ "title": "North Light", "tags": [], "creator": "", "name": "Mira", "greetings": ["You came."], "description": "A keeper.", "personality": "", "scenario": "", "example_dialogue": "", "creator_notes": "" });
    let made = json_of(&call(&server, "post_cards_new", json!({ "body": card })).await);
    let id = made["card_id"].as_i64().expect("the new card's id");
    let read = json_of(&call(&server, "get_cards_id", json!({ "id": id })).await);
    assert_eq!(read, server.get(&format!("/api/cards/{id}")).await.1);
    let missing = call(&server, "get_cards_id", json!({ "id": id + 100 })).await;
    assert_eq!(missing["isError"], true, "{missing}");
}

#[tokio::test]
async fn a_program_sends_a_message_and_is_given_the_reply() {
    let server = serving().await;
    let provider = json!({ "base_url": pretend::ADDRESS, "model": "pretend-chat", "api_key": "sk-cardwave-fake-0000" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    let chat = view["chat"]["id"].as_i64().unwrap();

    let sent = json!({ "chat_id": chat, "text": "Plan a trip to Lisbon." });
    let reply = json_of(&call(&server, "send_message", sent).await);
    assert_eq!(reply.as_array().unwrap().len(), 1, "{reply}");
    assert_eq!(reply[0]["content"], pretend::REPLY);
    let (_, view) = server.get(&format!("/api/chats/{chat}")).await;
    assert_eq!(view["messages"][0]["content"], "Plan a trip to Lisbon.");
    let missing = call(
        &server,
        "send_message",
        json!({ "chat_id": chat + 100, "text": "Hi" }),
    )
    .await;
    assert_eq!(missing["isError"], true, "{missing}");
}

#[tokio::test]
async fn a_long_chat_is_read_in_pages_of_fifty_the_newest_first() {
    let server = serving().await;
    let (_, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    for n in 1..=120 {
        let said = json!({ "content": format!("message {n}") });
        assert_eq!(
            server
                .post(&format!("/api/chats/{chat}/messages"), said)
                .await
                .0,
            201
        );
    }
    let page = |n: Option<u64>| {
        let mut asked = json!({ "chat_id": chat });
        if let Some(n) = n {
            asked["page"] = json!(n);
        }
        call(&server, "read_chat", asked)
    };
    let first = json_of(&page(None).await);
    let messages = first["messages"].as_array().unwrap();
    assert_eq!(
        (messages.len(), &first["page"], &first["pages"]),
        (50, &json!(1), &json!(3))
    );
    assert_eq!(messages[0]["content"], "message 71");
    assert_eq!(messages[49]["content"], "message 120");
    let last = json_of(&page(Some(3)).await);
    let messages = last["messages"].as_array().unwrap();
    assert_eq!(messages.len(), 20);
    assert_eq!(messages[0]["content"], "message 1");
    assert_eq!(json_of(&page(Some(4)).await)["messages"], json!([]));
    assert_eq!(json_of(&page(Some(u64::MAX)).await)["messages"], json!([]));
}

#[tokio::test]
async fn a_reply_that_waits_for_the_user_is_not_waited_for() {
    let server = serving().await;
    let on = json!({ "tools": { "app": true } });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);
    let make = json!({ "tool": "post_personas", "arguments": { "body": { "name": "Ada", "description": "" } } });
    let model = Model::start(vec![(200, stream(&call_pieces(tools::app::CALL, &make)))]).await;
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let (_, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    let chat = view["chat"]["id"].as_i64().unwrap();

    let sent = json!({ "chat_id": chat, "text": "Make me a persona." });
    let said = call(&server, "send_message", sent).await;
    assert_eq!(said["isError"], false, "{said}");
    let text = said["content"][0]["text"].as_str().unwrap();
    assert!(text.contains("waits for the user"), "{text}");
    let (_, view) = server.get(&format!("/api/chats/{chat}")).await;
    assert_eq!(view["asking"]["kind"], "app", "{view}");
}

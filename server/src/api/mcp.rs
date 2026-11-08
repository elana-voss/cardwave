//! The MCP server at `POST /api/mcp`: a program on this computer reads an
//! account's cards and chats as the API answers in-process (`api`), a long
//! chat in pages (`paged`), writes into a chat and waits for the reply at
//! most `REPLY_WAIT` (`send`), and calls the tools Settings › Tools switch on
//! (`tools::Toolbox`), with "Cardwave" one per route (`tools::app`), which the
//! program asks its user about (`readOnlyHint`, `destructiveHint`). Streamable HTTP, stateless;
//! a request whose `_meta` names its version is of 2026-07-28 (`checked`), one
//! without an older client's, which begins with `initialize`. Only this
//! computer reaches it (`this_computer`). Account › Server's "Other programs"
//! (`/api/mcp/settings`, `cw_coding::mcp`): the switch, the account served, the
//! programs by the name each gives itself (`program`). Traps: an older client
//! names itself in `initialize` alone, so its session id is its name; a call
//! the settings ask about first is refused, as MCP cannot ask the user.

use axum::Router;
use axum::body::Bytes;
use axum::extract::State;
use axum::http::{HeaderMap, HeaderValue, Method, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Extension, Json};
use base64::Engine;
use base64::engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD};
use cw_coding::mcp::{self, ChangeMcp, McpSettings};
use cw_coding::tools::{Toolbox, app, dice};
use cw_provider::Call;
use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use serde_json::{Value, json};

use super::app_tools::{self, tool_routes};
use super::{Api, ApiResult, Caller, Owner};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/mcp", post(mcp))
        .route("/api/mcp/settings", get(settings).put(change))
}

/// Most characters of a program's name that are kept.
const NAME: usize = 64;

async fn settings(
    State(state): State<AppState>,
    Owner(local): Owner,
) -> ApiResult<Json<McpSettings>> {
    let settings = state.run(move |db| mcp::settings(db, local));
    Ok(Json(settings.await?))
}

async fn change(
    State(state): State<AppState>,
    Owner(local): Owner,
    Json(change): Json<ChangeMcp>,
) -> ApiResult<Json<McpSettings>> {
    let changed = state.run(move |db| mcp::change(db, local, change));
    Ok(Json(changed.await?))
}

/// The name a program gives itself in a request, cut to [`NAME`] characters:
/// in `initialize`, the newer `_meta`, or the session id an older one was given.
fn program(headers: &HeaderMap, params: &Value) -> Option<String> {
    let info = match &params["clientInfo"] {
        Value::Null => &params["_meta"]["io.modelcontextprotocol/clientInfo"],
        info => info,
    };
    let session = || {
        let id = headers.get(SESSION)?.to_str().ok()?;
        String::from_utf8(URL_SAFE_NO_PAD.decode(id).ok()?).ok()
    };
    let name = match info["name"].as_str() {
        Some(name) => name.to_string(),
        None => session()?,
    };
    let name = name.trim();
    (!name.is_empty()).then(|| name.chars().take(NAME).collect())
}

/// The revision a request says it is of in its `_meta`.
const NEWER: &str = "2026-07-28";

/// The revisions it speaks, the newest first: [`NEWER`], then those that begin with `initialize`.
const SUPPORTED: [&str; 5] = [
    NEWER,
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
];

/// The revisions that begin with `initialize`, the newest first.
const OLDER: &[&str] = SUPPORTED.split_at(1).1;

const VERSION_KEY: &str = "io.modelcontextprotocol/protocolVersion";

const INSTRUCTIONS: &str = "Cardwave holds the user's character cards and their chats with the characters. list_cards and list_chats find them, read_card and read_chat read one by its id, send_message writes into a chat and gives the reply; the other tools are those the user switched on in Cardwave's settings, with Cardwave's own one per request of its API.";

/// What send_message says of a reply that waits for the user.
const WAITS: &str = "The reply waits for the user to allow a tool in Cardwave; read_chat gives it once they have answered.";

/// How long `send_message` waits for the reply: as long as a reply waits for
/// its provider to say anything (`provider::SILENCE_LIMIT`).
const REPLY_WAIT: std::time::Duration = cw_provider::SILENCE_LIMIT;

/// What `send_message` says of a reply still being written after [`REPLY_WAIT`].
const WRITING: &str = "The reply is still being written; read_chat gives it once it is done.";

/// How a wait for a reply ended.
#[derive(Debug, PartialEq)]
enum Waited {
    /// The reply left the replies: it is done.
    Done,
    /// It waits for the user to allow a tool.
    Asks,
    /// It was still being written when the wait ran out.
    Writing,
}

/// Looks every 100 ms at how the reply stands (`now`, none while it is
/// written) until it says, or `limit` has passed.
async fn waited(limit: std::time::Duration, now: impl Fn() -> Option<Waited>) -> Waited {
    let looked = async {
        loop {
            if let Some(waited) = now() {
                return waited;
            }
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        }
    };
    tokio::time::timeout(limit, looked)
        .await
        .unwrap_or(Waited::Writing)
}

/// The most messages of a chat that read_chat gives at once.
const PAGE: usize = 50;

/// A JSON-RPC error: its HTTP status, code and message, and what it adds.
struct Failed(StatusCode, i64, String, Option<Value>);

impl Failed {
    fn new(status: StatusCode, code: i64, message: impl Into<String>) -> Self {
        Self(status, code, message.into(), None)
    }
}

/// The headers do not mirror the body.
fn mismatch(what: &str) -> Failed {
    Failed::new(
        StatusCode::BAD_REQUEST,
        -32020,
        format!("Header mismatch: {what}"),
    )
}

fn unsupported(requested: &str) -> Failed {
    let data = json!({ "supported": SUPPORTED, "requested": requested });
    Failed(
        StatusCode::BAD_REQUEST,
        -32022,
        "Unsupported protocol version".into(),
        Some(data),
    )
}

fn invalid(message: impl Into<String>) -> Failed {
    Failed::new(StatusCode::OK, -32602, message)
}

fn answer(status: StatusCode, body: Value) -> Response {
    (status, axum::Json(body)).into_response()
}

async fn mcp(
    State(state): State<AppState>,
    Extension(app): Extension<Api>,
    caller: Caller,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    if caller.remote || !this_computer(&headers) {
        let text = "Only apps on this computer reach Cardwave's MCP server.";
        return failure(
            Value::Null,
            Failed::new(StatusCode::FORBIDDEN, -32600, text),
        );
    }
    let Ok(message) = serde_json::from_slice::<Value>(&body) else {
        return failure(
            Value::Null,
            Failed::new(StatusCode::BAD_REQUEST, -32700, "Parse error"),
        );
    };
    // A batch, which 2025-03-26 allowed and later revisions do not.
    if !message.is_object() {
        let text = "Send one message at a time";
        return failure(
            Value::Null,
            Failed::new(StatusCode::BAD_REQUEST, -32600, text),
        );
    }
    // A notification, or an answer, wants none.
    let id = message.get("id").cloned();
    let answers = message.get("result").is_some() || message.get("error").is_some();
    let (Some(id), Some(method)) = (id.clone(), message["method"].as_str()) else {
        if id.is_none() || answers {
            return StatusCode::ACCEPTED.into_response();
        }
        let text = "Invalid Request: no method";
        return failure(
            id.unwrap_or_default(),
            Failed::new(StatusCode::BAD_REQUEST, -32600, text),
        );
    };
    let params = &message["params"];
    let newer = match checked(&headers, method, params) {
        Ok(newer) => newer,
        Err(failed) => return failure(id, failed),
    };
    let name = program(&headers, params);
    let session = (method == "initialize").then(|| name.clone()).flatten();
    let local = state.local_user();
    let admitted = state
        .work(move |db| mcp::admit(db, local, name.as_deref()))
        .await;
    let account = match admitted {
        Ok(Ok(account)) => account,
        Ok(Err(refused)) => {
            return failure(id, Failed::new(StatusCode::FORBIDDEN, -32600, refused));
        }
        Err(failed) => {
            let text = format!("{failed:#}");
            return failure(
                id,
                Failed::new(StatusCode::INTERNAL_SERVER_ERROR, -32603, text),
            );
        }
    };
    // As the account it serves, on this computer.
    let caller = Caller {
        user: account,
        session: None,
        remote: false,
    };
    match respond(&state, &app, &caller, method, params, newer).await {
        Ok(mut result) => {
            // Of the newer revision alone.
            if newer {
                result["resultType"] = json!("complete");
            }
            let body = json!({ "jsonrpc": "2.0", "id": id, "result": result });
            let mut answered = answer(StatusCode::OK, body);
            // An older client sends it back with every request, and so names itself.
            let session = session.map(|name| URL_SAFE_NO_PAD.encode(name));
            if let Some(value) = session.and_then(|id| HeaderValue::from_str(&id).ok()) {
                answered.headers_mut().insert(SESSION, value);
            }
            answered
        }
        Err(failed) => failure(id, failed),
    }
}

/// The header in which an older client sends back its session id.
const SESSION: &str = "mcp-session-id";

fn failure(id: Value, Failed(status, code, text, data): Failed) -> Response {
    let mut error = json!({ "code": code, "message": text });
    if let Some(data) = data {
        error["data"] = data;
    }
    answer(
        status,
        json!({ "jsonrpc": "2.0", "id": id, "error": error }),
    )
}

/// Whether the request was sent to this computer by its name or address.
fn this_computer(headers: &HeaderMap) -> bool {
    let host = headers
        .get(header::HOST)
        .and_then(|host| host.to_str().ok())
        .unwrap_or("");
    matches!(crate::host_name(host), "127.0.0.1" | "localhost" | "::1")
}

async fn respond(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    method: &str,
    params: &Value,
    newer: bool,
) -> Result<Value, Failed> {
    match method {
        "initialize" if !newer => {
            let asked = params["protocolVersion"].as_str().unwrap_or_default();
            let version = OLDER.iter().find(|one| **one == asked).unwrap_or(&OLDER[0]);
            Ok(json!({
                "protocolVersion": version,
                "capabilities": { "tools": {} },
                "serverInfo": server_info(),
                "instructions": INSTRUCTIONS,
            }))
        }
        "ping" if !newer => Ok(json!({})),
        "server/discover" => Ok(json!({
                "supportedVersions": SUPPORTED,
                "capabilities": { "tools": {} },
                "_meta": { "io.modelcontextprotocol/serverInfo": server_info() },
                "instructions": INSTRUCTIONS,
                "ttlMs": 0,
                "cacheScope": "private",
        })),
        "tools/list" => {
            let toolbox = toolbox(state, app, caller).await?;
            let mut tools = own_tools();
            let app = toolbox.as_ref().is_some_and(Toolbox::offers_app);
            let theirs = toolbox
                .map(|toolbox| toolbox.definitions())
                .unwrap_or_default();
            // Cardwave's own come one per route, not as the chat model's two,
            // and in place of a written tool of a route's name; the dice are a chat's.
            let theirs = theirs.iter().filter(|tool| {
                let name = tool["function"]["name"].as_str().unwrap_or_default();
                name != dice::NAME
                    && !(app
                        && (name == app::CALL
                            || name == app::HELP
                            || app::named(tool_routes(), name).is_some()))
            });
            tools.extend(theirs.map(|tool| {
                let function = &tool["function"];
                json!({
                    "name": function["name"],
                    "description": function["description"],
                    "inputSchema": function["parameters"],
                })
            }));
            if app {
                tools.extend(app::mcp_definitions(tool_routes()));
            }
            let mut listed = json!({ "tools": tools });
            if newer {
                listed["ttlMs"] = json!(0);
                listed["cacheScope"] = json!("private");
            }
            Ok(listed)
        }
        "tools/call" => call(state, app, caller, params).await,
        _ => Err(Failed::new(
            // An older client reads the error of an answer that is not 404.
            match newer {
                true => StatusCode::NOT_FOUND,
                false => StatusCode::OK,
            },
            -32601,
            format!("Method not found: {method}"),
        )),
    }
}

/// Checks a request's headers against its body; whether it is of the newer revision.
fn checked(headers: &HeaderMap, method: &str, params: &Value) -> Result<bool, Failed> {
    let header = |name: &str| headers.get(name).and_then(|value| value.to_str().ok());
    let said = header("mcp-protocol-version");
    let Some(version) = params["_meta"][VERSION_KEY].as_str() else {
        return match said {
            Some(NEWER) => Err(mismatch("the body's _meta names no protocol version")),
            Some(said) if !OLDER.contains(&said) => Err(unsupported(said)),
            _ => Ok(false),
        };
    };
    if said != Some(version) {
        return Err(mismatch("MCP-Protocol-Version differs from the body's"));
    }
    if version != NEWER {
        return Err(unsupported(version));
    }
    if header("mcp-method") != Some(method) {
        return Err(mismatch("Mcp-Method differs from the body's method"));
    }
    if method == "tools/call" {
        let name = header("mcp-name").and_then(decoded);
        if name.as_deref() != params["name"].as_str() {
            return Err(mismatch("Mcp-Name differs from the body's name"));
        }
    }
    Ok(true)
}

/// A header's value, which may come in Base64 as `=?base64?…?=`.
fn decoded(value: &str) -> Option<String> {
    match value
        .strip_prefix("=?base64?")
        .and_then(|rest| rest.strip_suffix("?="))
    {
        Some(coded) => String::from_utf8(STANDARD.decode(coded).ok()?).ok(),
        None => Some(value.to_string()),
    }
}

fn server_info() -> Value {
    json!({ "name": "cardwave", "title": "Cardwave", "version": super::version() })
}

/// The tools of the cards and the chats, which every account has.
fn own_tools() -> Vec<Value> {
    let query =
        json!({ "type": "string", "description": "Words to search for; leave it out for all" });
    let id = |what: &str| json!({ "type": "integer", "description": format!("The {what}'s id, as the list gives it") });
    let tool = |name: &str, description: &str, properties: Value, required: Value| {
        json!({
            "name": name,
            "description": description,
            "inputSchema": { "type": "object", "properties": properties, "required": required },
        })
    };
    vec![
        tool(
            "list_cards",
            "Lists the character cards of the user's library, each with its id, title, characters' names, tags and logline. A query finds those that have all its words in their title, names or tags, and, where the search model is set up, those about it.",
            json!({ "query": query }),
            json!([]),
        ),
        tool(
            "read_card",
            "Reads a character card: its characters, each with its description, personality, scenario, example dialogue and greetings.",
            json!({ "card_id": id("card") }),
            json!(["card_id"]),
        ),
        tool(
            "list_chats",
            "Lists the user's chats with the characters, the one written in last first, each with its id, title, characters and the start of its newest message. A query finds those that have all its words in their title, characters' names or cards' titles.",
            json!({ "query": query }),
            json!([]),
        ),
        tool(
            "read_chat",
            "Reads a chat: its characters, and its messages from the first to the newest, each with who wrote it. A chat of more than 50 messages comes in pages of 50, page 1 the newest, with how many pages it has.",
            json!({ "chat_id": id("chat"), "page": { "type": "integer", "description": "Which 50 messages, 1 the newest; 1 when left out" } }),
            json!(["chat_id"]),
        ),
        tool(
            "send_message",
            "Writes a message into a chat as the user, waits for the character's reply and gives it, with whatever came after the message.",
            json!({ "chat_id": id("chat"), "text": { "type": "string", "description": "The message" } }),
            json!(["chat_id", "text"]),
        ),
    ]
}

/// The tools the user's settings switch on, as a reply has them.
async fn toolbox(state: &AppState, app: &Api, caller: &Caller) -> Result<Option<Toolbox>, Failed> {
    let user = caller.user;
    let owner = user == state.local_user();
    let api = Some((app.clone(), caller.clone()));
    state
        .work(move |db| super::generate::toolbox(db, user, (owner, false), None, api))
        .await
        .map_err(|failure| Failed::new(StatusCode::OK, -32603, format!("{failure:#}")))
}

async fn call(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    params: &Value,
) -> Result<Value, Failed> {
    let name = params["name"].as_str().unwrap_or_default();
    let arguments = &params["arguments"];
    let words = |name: &str| {
        let text = arguments[name].as_str().unwrap_or_default();
        utf8_percent_encode(text, NON_ALPHANUMERIC).to_string()
    };
    let id = |name: &str| {
        arguments[name]
            .as_i64()
            .ok_or_else(|| invalid(format!("{name} is to be a number")))
    };
    let asked = match name {
        "list_cards" => format!("/api/cards?q={}", words("query")),
        "read_card" => format!("/api/cards/{}", id("card_id")?),
        "list_chats" => format!("/api/chats?q={}", words("query")),
        "read_chat" => format!("/api/chats/{}", id("chat_id")?),
        "send_message" => {
            let (chat, text) = (
                id("chat_id")?,
                arguments["text"].as_str().unwrap_or_default(),
            );
            return Ok(match send(state, app, caller, chat, text).await {
                Ok(text) => text_result(text, false),
                Err(failure) => text_result(failure, true),
            });
        }
        _ => return their_tool(state, app, caller, name, arguments).await,
    };
    let page = arguments["page"].as_u64().unwrap_or(1).max(1) as usize;
    Ok(match api(app, caller, &asked).await {
        Ok(text) if name == "read_chat" => text_result(paged(text, page), false),
        Ok(text) => text_result(text, false),
        Err(failure) => text_result(failure, true),
    })
}

/// A chat's answer with the `page`th [`PAGE`] of its messages, the first the
/// newest, where it has more than that.
fn paged(text: String, page: usize) -> String {
    let Ok(mut chat) = serde_json::from_str::<Value>(&text) else {
        return text;
    };
    let Some(messages) = chat["messages"].as_array().filter(|all| all.len() > PAGE) else {
        return text;
    };
    let pages = messages.len().div_ceil(PAGE);
    let end = messages
        .len()
        .saturating_sub((page - 1).saturating_mul(PAGE));
    let shown = messages[end.saturating_sub(PAGE)..end].to_vec();
    chat["messages"] = json!(shown);
    chat["page"] = json!(page);
    chat["pages"] = json!(pages);
    chat.to_string()
}

/// Sends `text` into the chat `chat` as the user and waits for the reply:
/// the messages after it, as the chat's answer has them.
async fn send(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    chat: i64,
    text: &str,
) -> Result<String, String> {
    let message = json!({ "content": text });
    let path = format!("/api/chats/{chat}/messages");
    let sent = ask(app, caller, Method::POST, &path, Some(message)).await?;
    let sent = serde_json::from_str::<Value>(&sent).map_err(|e| e.to_string())?["id"].clone();
    let path = format!("/api/chats/{chat}/generate");
    ask(app, caller, Method::POST, &path, Some(json!({}))).await?;
    // The reply is written on a task of its own, until it leaves the replies;
    // one that waits for the user to allow a tool is not waited for.
    let key = (caller.user, chat);
    let now = || match (
        state.replies().contains_key(&key),
        state.asks().contains_key(&key),
    ) {
        (false, _) => Some(Waited::Done),
        (true, true) => Some(Waited::Asks),
        (true, false) => None,
    };
    match waited(REPLY_WAIT, now).await {
        Waited::Done => {}
        Waited::Asks => return Ok(WAITS.to_string()),
        Waited::Writing => return Ok(WRITING.to_string()),
    }
    let read = api(app, caller, &format!("/api/chats/{chat}")).await?;
    let read: Value = serde_json::from_str(&read).map_err(|e| e.to_string())?;
    let messages = read["messages"].as_array().cloned().unwrap_or_default();
    let after: Vec<Value> = messages
        .into_iter()
        .skip_while(|message| message["id"] != sent)
        .skip(1)
        .collect();
    Ok(json!(after).to_string())
}

/// Asks the API for `path` as the caller: its answer's body, or what it said went wrong.
async fn api(app: &Api, caller: &Caller, path: &str) -> Result<String, String> {
    ask(app, caller, Method::GET, path, None).await
}

/// Asks the API with `method` at `path`, with the JSON `body`, as the caller.
async fn ask(
    app: &Api,
    caller: &Caller,
    method: Method,
    path: &str,
    body: Option<Value>,
) -> Result<String, String> {
    let body = body.map(|body| body.to_string());
    app_tools::request(app, caller, method, path, body).await
}

async fn their_tool(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    name: &str,
    arguments: &Value,
) -> Result<Value, Failed> {
    let toolbox = toolbox(state, app, caller).await?;
    // The dice are a chat's, not listed here.
    let offered = |toolbox: &Toolbox| {
        name != dice::NAME
            && toolbox
                .definitions()
                .iter()
                .any(|tool| tool["function"]["name"] == name)
    };
    let offers_app = toolbox.as_ref().is_some_and(Toolbox::offers_app);
    if let Some(route) = app::named(tool_routes(), name).filter(|_| offers_app) {
        return Ok(match app_tools::call(app, caller, route, arguments).await {
            Ok(text) => text_result(text, false),
            Err(failure) => text_result(failure, true),
        });
    }
    let Some(toolbox) = toolbox.filter(offered) else {
        return Err(invalid(format!("Unknown tool: {name}")));
    };
    let call = Call {
        id: String::new(),
        name: name.to_string(),
        arguments: arguments.to_string(),
    };
    if let Some(ask) = toolbox.asks(&call).await {
        let switch = match ask.kind {
            cw_coding::tools::AskKind::Write => "Ask before writing",
            cw_coding::tools::AskKind::Command => "Ask before running",
            cw_coding::tools::AskKind::NewTool => "Tools the AI wrote › Ask before a new tool runs",
            // The coding team's, which a chat's tools never ask.
            _ => "Ask before running",
        };
        let refused = format!(
            "Cardwave's settings ask the user first, which it cannot do over MCP. The user may switch \"{switch}\" off in Cardwave's Settings › Tools to allow it."
        );
        return Ok(text_result(refused, true));
    }
    let done = toolbox.run(&state.actions(), &call).await;
    let mut result = text_result(done.text, done.failed);
    if let Some((_, picture)) = done.picture {
        let image = json!({ "type": "image", "data": STANDARD.encode(&picture.data), "mimeType": picture.mime });
        if let Some(content) = result["content"].as_array_mut() {
            content.push(image);
        }
    }
    Ok(result)
}

fn text_result(text: String, error: bool) -> Value {
    json!({ "content": [{ "type": "text", "text": text }], "isError": error })
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/mcp.rs"));

#[cfg(test)]
mod tests {
    use super::{Waited, waited};
    use std::time::Duration;

    #[tokio::test]
    async fn a_reply_still_written_is_waited_for_no_longer_than_the_limit() {
        let limit = Duration::from_millis(250);
        assert_eq!(waited(limit, || None).await, Waited::Writing);
        assert_eq!(waited(limit, || Some(Waited::Done)).await, Waited::Done);
    }
}

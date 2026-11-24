//! The MCP server at `POST /api/mcp`: a program on this computer reads an
//! account's cards and chats as the API answers in-process (`api`), a long
//! chat in pages (`paged`), writes into a chat and waits for the reply at
//! most `REPLY_WAIT` (`send`), and calls the tools Settings switches on
//! (`tools::Toolbox`), with "Cardwave" one per route (`tools::app`), which the
//! program asks its user about (`readOnlyHint`, `destructiveHint`). The
//! protocol is rmcp's (`StreamableHttpService`, stateless, JSON answers), of
//! revision 2026-07-28 alone, whose every request names its program in
//! `_meta`; rmcp refuses a host other than this computer, `mcp` another device.
//! Account › Server's "Other programs" (`/api/mcp/settings`, `cw_coding::mcp`):
//! the switch, the account served, the programs by their names (`admitted`).
//! Traps: rmcp hands the HTTP request's parts to the handler, from which
//! `admitted` takes the state and the API; a call the settings ask about first
//! is refused, as MCP cannot ask the user, and so are the routes that answer
//! such an ask or switch it off, or decide who is served (`the_users_alone`).

use std::borrow::Cow;
use std::sync::Arc;

use axum::Json;
use axum::Router;
use axum::extract::{Request, State};
use axum::http::{Method, StatusCode, request::Parts};
use axum::response::IntoResponse;
use axum::routing::{get, post};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_coding::mcp::{self, ChangeMcp, McpSettings};
use cw_coding::tools::{Toolbox, app, chat};
use cw_provider::Call;
use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use rmcp::model::{
    CallToolRequestParams, CallToolResponse, CallToolResult, DiscoverResult, Implementation,
    ListToolsResult, PaginatedRequestParams, ProtocolVersion, ResultType, ServerCapabilities,
    ServerConfig,
};
use rmcp::service::RequestContext;
use rmcp::transport::streamable_http_server::session::never::NeverSessionManager;
use rmcp::transport::streamable_http_server::{StreamableHttpServerConfig, StreamableHttpService};
use rmcp::{ErrorData as McpError, RoleServer, ServerHandler};
use serde_json::{Value, json};

use super::app_tools::{self, tool_routes};
use super::{Api, ApiResult, Caller, Owner, events};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    // Stateless, so each request is served as it comes; plain JSON answers.
    let config = StreamableHttpServerConfig::default()
        .with_legacy_session_mode(false)
        .with_json_response(true)
        .with_stateless_protocol_metadata_required(true);
    let service = StreamableHttpService::new(
        || Ok(Server),
        Arc::new(NeverSessionManager::default()),
        config,
    );
    let mcp = move |State(state): State<AppState>, caller: Caller, mut request: Request| {
        let service = service.clone();
        async move {
            if caller.remote {
                let text = "Only apps on this computer reach Cardwave's MCP server.";
                return (StatusCode::FORBIDDEN, text).into_response();
            }
            request.extensions_mut().insert(state);
            service.handle(request).await.into_response()
        }
    };
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

/// The name a program gives itself in a request's `_meta`, cut to [`NAME`] characters.
fn program(info: Option<Implementation>) -> Option<String> {
    let name = info?.name;
    let name = name.trim();
    (!name.is_empty()).then(|| name.chars().take(NAME).collect())
}

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

/// The MCP server's handler: rmcp answers the protocol, this the tools.
struct Server;

impl ServerHandler for Server {
    fn get_info(&self) -> ServerConfig {
        let info = Implementation::new("cardwave", super::version()).with_title("Cardwave");
        ServerConfig::new(ServerCapabilities::builder().enable_tools().build())
            .with_server_info(info)
            .with_instructions(INSTRUCTIONS)
    }

    fn supported_protocol_versions(&self) -> Cow<'static, [ProtocolVersion]> {
        Cow::Borrowed(&[ProtocolVersion::V_2026_07_28])
    }

    async fn discover(
        &self,
        context: RequestContext<RoleServer>,
    ) -> Result<DiscoverResult, McpError> {
        admitted(&context).await?;
        let versions = self.supported_protocol_versions().into_owned();
        Ok(DiscoverResult::from_server_info(versions, self.get_info()))
    }

    async fn list_tools(
        &self,
        _request: Option<PaginatedRequestParams>,
        context: RequestContext<RoleServer>,
    ) -> Result<ListToolsResult, McpError> {
        let (state, app, caller) = admitted(&context).await?;
        let tools = listed(&state, &app, &caller).await?;
        let listed = json!({ "tools": tools, "ttlMs": 0, "cacheScope": "private", "resultType": "complete" });
        serde_json::from_value(listed).map_err(|e| McpError::internal_error(e.to_string(), None))
    }

    async fn call_tool(
        &self,
        request: CallToolRequestParams,
        context: RequestContext<RoleServer>,
    ) -> Result<CallToolResponse, McpError> {
        let (state, app, caller) = admitted(&context).await?;
        let params = json!({ "name": request.name, "arguments": request.arguments });
        let result = call(&state, &app, &caller, &params).await?;
        let mut result: CallToolResult = serde_json::from_value(result)
            .map_err(|e| McpError::internal_error(e.to_string(), None))?;
        result.result_type = Some(ResultType::COMPLETE);
        Ok(result.into())
    }
}

/// Admits the program a request comes from, as the settings say: the state,
/// the API and the account it is served as, on this computer; why not, where not.
async fn admitted(
    context: &RequestContext<RoleServer>,
) -> Result<(AppState, Api, Caller), McpError> {
    let parts = context.extensions.get::<Parts>();
    let state = parts.and_then(|parts| parts.extensions.get::<AppState>().cloned());
    let app = parts.and_then(|parts| parts.extensions.get::<Api>().cloned());
    let (Some(state), Some(app)) = (state, app) else {
        return Err(McpError::internal_error(
            "the request's state is missing",
            None,
        ));
    };
    let name = program(context.client_info());
    let local = state.local_user();
    let admitted = state
        .work(move |db| mcp::admit(db, local, name.as_deref()))
        .await;
    let account = match admitted {
        Ok(Ok(account)) => account,
        Ok(Err(refused)) => return Err(McpError::invalid_request(refused, None)),
        Err(failed) => return Err(McpError::internal_error(format!("{failed:#}"), None)),
    };
    // As the account it serves, on this computer.
    let caller = Caller {
        user: account,
        session: None,
        remote: false,
    };
    Ok((state, app, caller))
}

/// The tools a program is offered: the cards' and chats', those the settings
/// switch on, and Cardwave's own one per route in place of the chat model's two.
async fn listed(state: &AppState, app: &Api, caller: &Caller) -> Result<Vec<Value>, McpError> {
    let toolbox = toolbox(state, app, caller).await?;
    let mut tools = own_tools();
    let app = toolbox.as_ref().is_some_and(Toolbox::offers_app);
    let theirs = toolbox
        .map(|toolbox| toolbox.definitions())
        .unwrap_or_default();
    // Cardwave's own come one per route, not as the chat model's two,
    // and in place of a written tool of a route's name; a chat tool is a chat's.
    let theirs = theirs.iter().filter(|tool| {
        let name = tool["function"]["name"].as_str().unwrap_or_default();
        chat::named(name).is_none()
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
    Ok(tools)
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
            mcp::LIST_CARDS,
            "Lists the character cards of the user's library, each with its id, title, characters' names, tags and logline. A query finds those that have all its words in their title, names or tags, and, where the search model is set up, those about it.",
            json!({ "query": query }),
            json!([]),
        ),
        tool(
            mcp::READ_CARD,
            "Reads a character card: its characters, each with its description, personality, scenario, example dialogue and greetings.",
            json!({ "card_id": id("card") }),
            json!(["card_id"]),
        ),
        tool(
            mcp::LIST_CHATS,
            "Lists the user's chats with the characters, the one written in last first, each with its id, title, characters and the start of its newest message. A query finds those that have all its words in their title, characters' names or cards' titles.",
            json!({ "query": query }),
            json!([]),
        ),
        tool(
            mcp::READ_CHAT,
            "Reads a chat: its characters, and its messages from the first to the newest, each with who wrote it. A chat of more than 50 messages comes in pages of 50, page 1 the newest, with how many pages it has.",
            json!({ "chat_id": id("chat"), "page": { "type": "integer", "description": "Which 50 messages, 1 the newest; 1 when left out" } }),
            json!(["chat_id"]),
        ),
        tool(
            mcp::SEND_MESSAGE,
            "Writes a message into a chat as the user, waits for the character's reply and gives it, with whatever came after the message.",
            json!({ "chat_id": id("chat"), "text": { "type": "string", "description": "The message" } }),
            json!(["chat_id", "text"]),
        ),
    ]
}

/// The tools the user's settings switch on, as a reply has them.
async fn toolbox(
    state: &AppState,
    app: &Api,
    caller: &Caller,
) -> Result<Option<Toolbox>, McpError> {
    let user = caller.user;
    let owner = user == state.local_user();
    let api = Some((app.clone(), caller.clone()));
    state
        .work(move |db| super::generate::toolbox(db, user, (owner, false), None, api))
        .await
        .map_err(|failure| McpError::internal_error(format!("{failure:#}"), None))
}

async fn call(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    params: &Value,
) -> Result<Value, McpError> {
    let name = params["name"].as_str().unwrap_or_default();
    let arguments = &params["arguments"];
    let words = |name: &str| {
        let text = arguments[name].as_str().unwrap_or_default();
        utf8_percent_encode(text, NON_ALPHANUMERIC).to_string()
    };
    let id = |name: &str| {
        arguments[name]
            .as_i64()
            .ok_or_else(|| McpError::invalid_params(format!("{name} is to be a number"), None))
    };
    let asked = match name {
        mcp::LIST_CARDS => format!("/api/cards?q={}", words("query")),
        mcp::READ_CARD => format!("/api/cards/{}", id("card_id")?),
        mcp::LIST_CHATS => format!("/api/chats?q={}", words("query")),
        mcp::READ_CHAT => format!("/api/chats/{}", id("chat_id")?),
        mcp::SEND_MESSAGE => {
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
        Ok(text) if name == mcp::READ_CHAT => text_result(paged(text, page), false),
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

/// Whether the route `name` does what only the user does, in Cardwave itself:
/// allows what Cardwave asks the user first (a tool call's answer, a coding
/// task's) or switches the asking off, which would let a program allow by
/// itself what the direct call of the tool is refused for; or decides who is
/// served and who signs in (the account served, accounts, their passwords, the
/// home network), which would let a program read another account's data.
fn the_users_alone(name: &str, arguments: &Value) -> bool {
    match name {
        _ if USERS_ALONE.contains(&name) => true,
        ASKING => ["ask_writes", "ask_commands", "ask_new_tools"]
            .iter()
            .any(|ask| !arguments["body"]["tools"][ask].is_null()),
        _ => false,
    }
}

/// The routes `the_users_alone` refuses whatever they are given; a test holds
/// each to be a route, and each route that takes `Owner` to be here or excused.
const USERS_ALONE: [&str; 6] = [
    "post_chats_id_answer",
    "post_coding_tasks_id_answer",
    "put_mcp_settings",
    "post_accounts",
    "put_accounts_id_password",
    "put_network",
];

/// The route that switches the asking off among other settings.
const ASKING: &str = "patch_settings";

/// Sends `text` into the chat `chat` as the user and waits for the reply:
/// the messages after it, as the chat's answer has them; why it failed, where it did.
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
    let (end_to, end) = events::reply_end();
    let body = Some(json!({}).to_string());
    app_tools::request(app, caller, Method::POST, &path, body, Some(end_to)).await?;
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
        Waited::Done => {
            if let Some(failure) = end.failure() {
                return Err(failure);
            }
        }
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
    app_tools::request(app, caller, method, path, body, None).await
}

async fn their_tool(
    state: &AppState,
    app: &Api,
    caller: &Caller,
    name: &str,
    arguments: &Value,
) -> Result<Value, McpError> {
    let toolbox = toolbox(state, app, caller).await?;
    // A chat tool is a chat's, not listed here.
    let offered = |toolbox: &Toolbox| {
        chat::named(name).is_none()
            && toolbox
                .definitions()
                .iter()
                .any(|tool| tool["function"]["name"] == name)
    };
    let offers_app = toolbox.as_ref().is_some_and(Toolbox::offers_app);
    if let Some(route) = app::named(tool_routes(), name).filter(|_| offers_app) {
        if the_users_alone(name, arguments) {
            let refused = "Only the user does this, in Cardwave itself; a program cannot over MCP.";
            return Ok(text_result(refused.to_string(), true));
        }
        return Ok(match app_tools::call(app, caller, route, arguments).await {
            Ok(text) => text_result(text, false),
            Err(failure) => text_result(failure, true),
        });
    }
    let Some(toolbox) = toolbox.filter(offered) else {
        return Err(McpError::invalid_params(
            format!("Unknown tool: {name}"),
            None,
        ));
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
            "Cardwave's settings ask the user first, which it cannot do over MCP. The user may switch \"{switch}\" off in Cardwave's Settings › Advanced › Tools for the AI to allow it."
        );
        return Ok(text_result(refused, true));
    }
    let done = toolbox.run(&state.actions(), &call).await;
    let failed = done.failed();
    let text = done.text;
    let mut result = text_result(text, failed);
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
    use super::{ASKING, USERS_ALONE, Waited, waited};
    use crate::api::OWNER_ROUTES;
    use crate::api::app_tools::tool_routes;
    use std::time::Duration;

    /// The routes that take `Owner` which a program may still call: each
    /// answers this computer's account and changes neither who is served nor
    /// what is asked first.
    const OWNER_OPEN: [&str; 18] = [
        // What the user reads in Settings, changing nothing.
        "get_network",
        "get_mcp_settings",
        // The folder of cards the library takes in, this computer's alone.
        "get_card_folder_import",
        "post_card_folder_import",
        "get_card_folder_offered",
        // This computer's models: fetched, stopped and removed.
        "delete_dictation",
        "delete_dictation_download",
        "post_dictation_download",
        "get_this_computer_models",
        "delete_this_computer_models_file",
        "post_this_computer_models_file",
        "delete_search",
        "delete_search_download",
        "post_search_download",
        "delete_voice_download",
        "post_voice_download",
        "delete_voice_languages_id",
        "post_voice_languages_id",
    ];

    #[test]
    fn each_route_kept_from_programs_is_a_route_and_each_owners_route_is_kept_or_excused() {
        let names: Vec<&str> = tool_routes().iter().map(|route| route.name).collect();
        for name in USERS_ALONE.iter().chain([&ASKING]) {
            assert!(names.contains(name), "{name} is no route");
        }
        assert!(!OWNER_ROUTES.is_empty());
        let open: Vec<_> = OWNER_ROUTES
            .iter()
            .filter(|name| !USERS_ALONE.contains(name) && !OWNER_OPEN.contains(name))
            .collect();
        assert!(
            open.is_empty(),
            "take Owner, neither kept from programs nor excused: {open:?}"
        );
    }

    #[tokio::test]
    async fn a_reply_still_written_is_waited_for_no_longer_than_the_limit() {
        let limit = Duration::from_millis(250);
        assert_eq!(waited(limit, || None).await, Waited::Writing);
        assert_eq!(waited(limit, || Some(Waited::Done)).await, Waited::Done);
    }
}

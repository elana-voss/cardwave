//! Cardwave's own API as tools ("Cardwave" in Settings › Tools): one tool per
//! route, listed at build from the routes and their handlers' types (build.rs,
//! the server's `api::app_tools::tool_routes`, passed in as `routes`), so every
//! feature is also a tool. A model's server
//! takes 128 functions at most, so the chat model is offered two, `cardwave`
//! (a tool by name, with its arguments) and `cardwave_help` (what a tool
//! takes, from its `ts_rs` types); MCP lists each tool as its own
//! (`mcp_definitions`). A tool is a request of the app (`request_of`), which
//! the app asks of its API in-process (`AskApp`, the server's `app_tools`);
//! its answer is the result, cut at `TEXT_LIMIT` characters (`web::cut`).
//! Every method but GET changes something,
//! which a chat asks the user about first, each time (`changes`). The
//! arguments: the path's parts by name, `query` and `body`.

use std::collections::HashSet;
use std::sync::Arc;

use futures_util::future::BoxFuture;
use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use serde_json::{Map, Value, json};
use ts_rs::{Config, TS, TypeVisitor};

/// The function by which the chat model calls a tool of Cardwave's.
pub const CALL: &str = "cardwave";
/// The function by which it reads what one takes.
pub const HELP: &str = "cardwave_help";
/// What asks the app for one of its tools: the route and its arguments, the
/// answer, cut at `web::TEXT_LIMIT`, or what went wrong.
pub type AskApp =
    Arc<dyn Fn(&'static Route, Value) -> BoxFuture<'static, Result<String, String>> + Send + Sync>;

/// A route of the API, as build.rs lists it.
pub struct Route {
    /// The method and the path after `/api/`, `get_cards_id_chats`.
    pub name: &'static str,
    pub method: &'static str,
    pub path: &'static str,
    /// The handler's doc comment, its first paragraph.
    pub doc: &'static str,
    /// The path's parts, each with its JSON type.
    pub params: &'static [(&'static str, &'static str)],
    /// The TypeScript of the query and of the body it takes, where it takes one.
    pub query: Option<fn() -> String>,
    pub body: Option<fn() -> String>,
}

impl Route {
    /// Whether it changes or deletes something, which is asked first.
    pub fn changes(&self) -> bool {
        self.method != "GET"
    }

    /// Its doc, or its method and path where it has none.
    fn says(&self) -> String {
        match self.doc.is_empty() {
            true => format!("{} {}", self.method, self.path),
            false => format!("{} {}. {}", self.method, self.path, self.doc),
        }
    }

    /// What it takes, as the model reads it: its doc and its types.
    pub fn help(&self) -> String {
        let mut said = self.says();
        if !self.params.is_empty() {
            let parts: Vec<String> = self
                .params
                .iter()
                .map(|(name, kind)| format!("{name} ({kind})"))
                .collect();
            said.push_str(&format!("\nThe path's parts: {}.", parts.join(", ")));
        }
        if let Some(query) = self.query {
            said.push_str(&format!("\nquery: {}", query()));
        }
        if let Some(body) = self.body {
            said.push_str(&format!("\nbody: {}", body()));
        }
        said
    }
}

/// The TypeScript of `T`, followed by the types it names.
pub fn typed<T: TS + 'static>() -> String {
    struct Named<'a> {
        config: &'a Config,
        seen: HashSet<String>,
        texts: Vec<String>,
    }
    impl TypeVisitor for Named<'_> {
        fn visit<U: TS + 'static + ?Sized>(&mut self) {
            if U::output_path().is_none() {
                return;
            }
            let declared = U::decl(self.config);
            if self.seen.insert(declared.clone()) {
                self.texts.push(declared);
                U::visit_dependencies(self);
            }
        }
    }
    let config = Config::new().with_large_int("number");
    let mut named = Named {
        config: &config,
        seen: HashSet::new(),
        texts: Vec::new(),
    };
    T::visit_dependencies(&mut named);
    T::visit_generics(&mut named);
    let mut text = T::inline(&config);
    for declared in named.texts {
        text.push('\n');
        text.push_str(&declared);
    }
    text
}

/// The tool `name`.
pub fn named(routes: &'static [Route], name: &str) -> Option<&'static Route> {
    routes.iter().find(|route| route.name == name)
}

/// The two functions the chat model is offered.
pub fn definitions(routes: &[Route]) -> Vec<Value> {
    // No enum of the names: the description lists them, which twice would double what each reply sends.
    let tool =
        json!({ "type": "string", "description": "The tool's name, as cardwave lists them" });
    let lines: Vec<String> = routes
        .iter()
        .map(|route| match route.doc.is_empty() {
            true => route.name.to_string(),
            false => format!("{}: {}", route.name, route.doc),
        })
        .collect();
    vec![
        crate::tools::tool(
            CALL,
            &format!(
                "Uses Cardwave, the app this chat is in, as its screens do: its cards, chats, lorebooks, personas, settings and the rest. Each tool is a request of its API, named by its method and path. Give the tool and its arguments: the path's parts by name (id, chat_id, …), and query and body as {HELP} says. What changes or deletes is asked of the user first. The tools:\n{}",
                lines.join("\n")
            ),
            json!({ "tool": tool, "arguments": { "type": "object", "description": "The path's parts by name, and query and body where the tool takes them" } }),
        ),
        crate::tools::tool(
            HELP,
            "Says what a tool of Cardwave's takes: the path's parts, and its query and body as TypeScript types.",
            json!({ "tool": tool }),
        ),
    ]
}

/// Each tool as MCP lists it.
pub fn mcp_definitions(routes: &[Route]) -> Vec<Value> {
    routes
        .iter()
        .map(|route| {
            let mut properties = Map::new();
            let mut required = Vec::new();
            for (name, kind) in route.params {
                properties.insert(name.to_string(), json!({ "type": kind }));
                required.push(json!(name));
            }
            if route.query.is_some() {
                properties.insert("query".into(), json!({ "type": "object" }));
            }
            if route.body.is_some() {
                properties.insert("body".into(), json!({ "type": "object" }));
                required.push(json!("body"));
            }
            json!({
                "name": route.name,
                "description": route.help(),
                "inputSchema": { "type": "object", "properties": properties, "required": required },
                "annotations": {
                    "readOnlyHint": !route.changes(),
                    "destructiveHint": route.method == "DELETE",
                },
            })
        })
        .collect()
}

/// The route and arguments a call of `cardwave` names.
pub fn asked(routes: &'static [Route], arguments: &str) -> Result<(&'static Route, Value), String> {
    let arguments: Value = serde_json::from_str(arguments).unwrap_or_default();
    let name = arguments["tool"].as_str().unwrap_or_default();
    let route = named(routes, name).ok_or_else(|| format!("Cardwave has no tool {name:?}"))?;
    Ok((route, arguments["arguments"].clone()))
}

/// The path, with its parts filled in, and the query of a call of `route`.
fn uri(route: &Route, arguments: &Value) -> Result<String, String> {
    let mut path = String::new();
    for segment in route.path.split('/').filter(|s| !s.is_empty()) {
        path.push('/');
        let Some(part) = segment.strip_prefix('{').and_then(|s| s.strip_suffix('}')) else {
            path.push_str(segment);
            continue;
        };
        let (name, rest) = match part.strip_prefix('*') {
            Some(name) => (name, true),
            None => (part, false),
        };
        let value = match &arguments[name] {
            Value::String(text) => text.clone(),
            Value::Number(number) => number.to_string(),
            _ => return Err(format!("say {name}, a part of the path")),
        };
        let encode = |text: &str| utf8_percent_encode(text, NON_ALPHANUMERIC).to_string();
        // The rest of a path keeps its slashes.
        let value = match rest {
            true => value.split('/').map(encode).collect::<Vec<_>>().join("/"),
            false => encode(&value),
        };
        path.push_str(&value);
    }
    if let Some(query) = arguments["query"].as_object() {
        let encode = |text: &str| utf8_percent_encode(text, NON_ALPHANUMERIC).to_string();
        let pair = |name: &str, value: &Value| {
            let value = match value {
                Value::String(text) => text.clone(),
                other => other.to_string(),
            };
            format!("{}={}", encode(name), encode(&value))
        };
        // A list is its key once per item, as `tag=a&tag=b`.
        let pairs: Vec<String> = query
            .iter()
            .flat_map(|(name, value)| match value {
                Value::Array(items) => items.iter().map(|item| pair(name, item)).collect(),
                Value::Null => Vec::new(),
                value => vec![pair(name, value)],
            })
            .collect();
        if !pairs.is_empty() {
            path = format!("{path}?{}", pairs.join("&"));
        }
    }
    Ok(path)
}

/// The method, the path with its query, and the JSON body a call of `route`
/// with `arguments` asks the app with.
pub fn request_of(
    route: &Route,
    arguments: &Value,
) -> Result<(&'static str, String, Option<String>), String> {
    let uri = uri(route, arguments)?;
    let body = route.body.map(|_| match &arguments["body"] {
        Value::Null => "{}".to_string(),
        body => body.to_string(),
    });
    Ok((route.method, uri, body))
}

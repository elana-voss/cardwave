//! Code mode: small JavaScript tools the model writes for itself with
//! `make_tool` (Circe's self-extending tools), kept for the account in
//! `written_tools` and offered while Code mode and the tool are switched on.
//!
//! A tool is an ES module whose default export is a function of the call's
//! arguments; what it returns (or its promise comes to) is the result, a
//! string as it is, else JSON. Each call runs in a QuickJS of its own (`run`)
//! without imports or timers, for `TIME` of its own work and within `MEMORY`.
//! It reaches the computer by the host's functions alone (`HOST`), each the
//! chat model's own tool under its switch, folder, sandbox and asking (the
//! owner, 2026-10-15), whose time does not count. An account keeps
//! `MOST_TOOLS`; a deleted one waits, flagged, for Undo until the server
//! starts again (`purge_deleted`).

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use anyhow::{Context as _, anyhow, ensure};
use cw_core::NotFound;
use rquickjs::function::Rest;
use rquickjs::{
    CaughtError, Context, Ctx, Exception, Function, Module, Runtime, Value as Js,
    promise::MaybePromise,
};
use serde::Serialize;
use serde_json::{Value, json};
use ts_rs::TS;

/// The tool by which the model writes a tool.
pub(crate) const MAKE: &str = "make_tool";

/// The longest a call of a written tool runs.
pub(crate) const TIME: Duration = Duration::from_secs(5);

/// The most memory a call of a written tool takes.
pub const MEMORY: usize = 64 << 20;

/// The longest code a tool has, and the longest result the model is given.
/// The most tools an account keeps, as each switched on is told to every reply.
pub const MOST_TOOLS: usize = 50;
const MOST_CODE: usize = 20_000;
const MOST_RESULT: usize = 20_000;

/// The types an argument's schema may name (JSON schema's).
const TYPES: [&str; 7] = [
    "string", "number", "integer", "boolean", "array", "object", "null",
];

/// The longest description, and the longest schema of the arguments, as JSON.
const MOST_DESCRIPTION: usize = 300;
const MOST_SCHEMA: usize = 4_000;

/// Names a written tool cannot have: the app's own tools, a reply's and the
/// MCP server's; nor those of Cardwave's routes (`app`).
const TAKEN: [&str; 16] = [
    crate::tools::app::CALL,
    crate::tools::dice::NAME,
    crate::tools::app::HELP,
    "send_message",
    "web_search",
    "read_web_page",
    "list_files",
    "read_file",
    "write_file",
    "run_command",
    "make_picture",
    MAKE,
    "list_cards",
    "read_card",
    "list_chats",
    "read_chat",
];

/// The host's functions a written tool may call: its name in JavaScript, the
/// tool it is, and that tool's arguments in the order the function takes them.
pub const HOST: [(&str, &str, &[&str]); 7] = [
    ("listFiles", "list_files", &["path"]),
    ("readFile", "read_file", &["path"]),
    ("writeFile", "write_file", &["path", "content"]),
    ("runCommand", "run_command", &["command"]),
    ("searchWeb", "web_search", &["query"]),
    ("readWebPage", "read_web_page", &["url"]),
    ("makePicture", "make_picture", &["description"]),
];

/// Runs a host's tool by its name with its arguments: what it gave, or why
/// it failed or was not allowed, which the script is thrown. Called on the
/// script's thread, which it may block.
pub type Host = Arc<dyn Fn(&str, Value) -> Result<String, String> + Send + Sync>;

/// A tool the AI wrote, as the page "Tools the AI wrote" shows it.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct WrittenTool {
    pub id: i64,
    pub name: String,
    /// What it does, in the model's words.
    pub description: String,
    pub code: String,
    /// Whether replies are offered it.
    pub on: bool,
    pub created_at: i64,
    /// The chat it was made in and its title; none where that chat is gone
    /// or it was made over MCP.
    pub chat_id: Option<i64>,
    pub chat_title: Option<String>,
    /// How often it ran.
    pub uses: i64,
    /// Its arguments, a JSON schema, as the model is told of them.
    #[serde(skip)]
    #[ts(skip)]
    pub parameters: Value,
}

/// A tool `make_tool` was asked for, checked.
#[derive(Clone, Debug)]
pub struct NewTool {
    pub name: String,
    pub description: String,
    pub parameters: Value,
    pub code: String,
}

/// `make_tool` as the model is told of it.
pub(crate) fn make_definition() -> Value {
    json!({
        "type": "function",
        "function": {
            "name": MAKE,
            "description": "Writes a small JavaScript tool for yourself, which you can call like any other tool from then on, in this reply and in later chats. Write one for work you would otherwise do by hand and could get wrong, such as counting, arithmetic, dates, dice or converting units. `code` is an ES module whose default export is a function that is given the call's arguments as one object and returns a string, or a value that is sent to you as JSON; it may be async. It runs in QuickJS without imports or timers, at most 5 seconds of its own and 64 MB. Your tools are its functions, each returning a string and throwing where it fails or is not allowed: listFiles(path), readFile(path), writeFile(path, content), runCommand(command), searchWeb(query), readWebPage(url), makePicture(description); only those you are offered work, as they work for you. Example code: export default function word_count({ text }) { return text.trim().split(/\\s+/).filter(Boolean).length; }",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": { "type": "string", "description": "The tool's name: a lowercase letter, then 2 to 31 lowercase letters, digits or underscores, such as word_count" },
                    "description": { "type": "string", "description": "What the tool does, in one line" },
                    "parameters": { "type": "object", "description": "The tool's arguments as a JSON schema of type object, such as {\"type\": \"object\", \"properties\": {\"text\": {\"type\": \"string\"}}, \"required\": [\"text\"]}" },
                    "code": { "type": "string", "description": "The tool's code, an ES module with a default export function" },
                },
                "required": ["name", "description", "parameters", "code"],
            },
        },
    })
}

/// A written tool as the model is told of it.
pub(crate) fn definition(tool: &WrittenTool) -> Value {
    json!({
        "type": "function",
        "function": { "name": tool.name, "description": tool.description, "parameters": tool.parameters },
    })
}

/// The tool `make_tool`'s `arguments` ask for, where it can be taken: its
/// name free (`taken` says which of the account's and Cardwave's are not), its parameters a
/// schema of an object (each argument's with a `type`, `required` naming
/// them, and so inside an argument's `items` and `properties`), and its
/// code a module whose default export is a function. Else what is wrong, for
/// the model.
pub fn check(arguments: &str, taken: impl Fn(&str) -> bool) -> anyhow::Result<NewTool> {
    let arguments: Value = serde_json::from_str(arguments).context("the arguments are not JSON")?;
    let text = |key: &str| {
        arguments[key]
            .as_str()
            .unwrap_or_default()
            .trim()
            .to_string()
    };
    let name = text("name");
    let named = name.len() >= 3
        && name.len() <= 32
        && name.starts_with(|c: char| c.is_ascii_lowercase())
        && name
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_');
    ensure!(
        named,
        "\"name\" is to be a lowercase letter, then 2 to 31 lowercase letters, digits or underscores, such as word_count"
    );
    ensure!(
        !TAKEN.contains(&name.as_str()) && !taken(&name),
        "a tool named {name} exists already; choose another name"
    );
    let description = text("description")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    ensure!(!description.is_empty(), "\"description\" is empty");
    ensure!(
        description.chars().count() <= MOST_DESCRIPTION,
        "\"description\" is longer than {MOST_DESCRIPTION} characters"
    );
    // Some models send the schema as text.
    let parameters = match &arguments["parameters"] {
        Value::String(schema) => serde_json::from_str(schema).unwrap_or(Value::Null),
        schema => schema.clone(),
    };
    ensure!(
        parameters.is_object() && parameters["type"] == "object",
        "\"parameters\" is to be a JSON schema of type object"
    );
    // A schema the provider refuses would make every reply go without tools.
    arguments_of(&parameters, "")?;
    ensure!(
        parameters.to_string().chars().count() <= MOST_SCHEMA,
        "\"parameters\" is a schema longer than {MOST_SCHEMA} characters"
    );
    let code = arguments["code"].as_str().unwrap_or_default().to_string();
    ensure!(!code.trim().is_empty(), "\"code\" is empty");
    ensure!(
        code.chars().count() <= MOST_CODE,
        "\"code\" is longer than {MOST_CODE} characters"
    );
    engine(&code, None, |_, _| Ok(()))
        .map_err(|failure| anyhow!("the code does not work: {failure}"))?;
    Ok(NewTool {
        name,
        description,
        parameters,
        code,
    })
}

/// Checks the schemas of an object schema's arguments (`properties`) and that
/// `required` names only those, each schema inside another too. `path` is
/// where the object stands ("" for the tool's arguments, "place" for one of
/// them), which a refusal names, as `a.b` for a property and `a[]` for an
/// array's items.
fn arguments_of(object: &Value, path: &str) -> anyhow::Result<()> {
    let of = if path.is_empty() {
        String::new()
    } else {
        format!(" of \"{path}\"")
    };
    let properties = match &object["properties"] {
        Value::Null => serde_json::Map::new(),
        Value::Object(properties) => properties.clone(),
        _ => anyhow::bail!("\"properties\"{of} is to be an object of the arguments' schemas"),
    };
    for (key, property) in &properties {
        let at = if path.is_empty() {
            key.clone()
        } else {
            format!("{path}.{key}")
        };
        argument(property, &at)?;
    }
    if let Some(required) = object.get("required") {
        let named = required.as_array().is_some_and(|names| {
            names.iter().all(|name| {
                name.as_str()
                    .is_some_and(|name| properties.contains_key(name))
            })
        });
        ensure!(
            named,
            "\"required\"{of} is to be a list of names in its \"properties\""
        );
    }
    Ok(())
}

/// Checks one argument's schema, at `at`: a `type` of `TYPES`, an array's
/// `items`, and an object's own arguments.
fn argument(schema: &Value, at: &str) -> anyhow::Result<()> {
    let typed = |kind: &Value| kind.as_str().is_some_and(|kind| TYPES.contains(&kind));
    let kinds: Vec<&Value> = match &schema["type"] {
        Value::Array(kinds) => kinds.iter().collect(),
        kind => vec![kind],
    };
    ensure!(
        !kinds.is_empty() && kinds.iter().all(|kind| typed(kind)),
        "the argument \"{at}\" is to be a schema with a \"type\", one of {}",
        TYPES.join(", ")
    );
    // A provider refuses an array without the schema of its items (OpenAI's: "array schema missing items").
    if kinds.iter().any(|kind| *kind == "array") {
        ensure!(
            schema["items"].is_object(),
            "the argument \"{at}\" is an array, and is to have \"items\", the schema of each"
        );
        argument(&schema["items"], &format!("{at}[]"))?;
    }
    if kinds.iter().any(|kind| *kind == "object") {
        arguments_of(schema, at)?;
    }
    Ok(())
}

/// Runs a tool's `code` with the call's `arguments` (a JSON object as text)
/// and the `host`'s functions, and gives what it returned, or what it threw.
pub fn run(code: &str, arguments: &str, host: Host) -> anyhow::Result<String> {
    let arguments = match arguments.trim() {
        "" => "{}",
        arguments => arguments,
    };
    let mut result = engine(code, Some(host), |ctx, tool| {
        let arguments = ctx.json_parse(arguments)?;
        let returned: MaybePromise = tool.call((arguments,))?;
        let value: Js = returned.finish()?;
        if let Some(text) = value.as_string() {
            return text.to_string();
        }
        let json = ctx.json_stringify(value)?;
        Ok(match json {
            Some(text) => text.to_string()?,
            None => "undefined".into(),
        })
    })
    .map_err(|failure| anyhow!("{failure}"))?;
    if let Some((cut, _)) = result.char_indices().nth(MOST_RESULT) {
        result.truncate(cut);
        result.push_str(
            "
[cut: the result was longer]",
        );
    }
    Ok(result)
}

/// Evaluates `code` as a module in a QuickJS of its own, under the limits,
/// with the `host`'s functions, and gives `work` its default export, a
/// function; what went wrong, or what was thrown, as text. The time the
/// host's functions take moves the deadline on.
fn engine<T>(
    code: &str,
    host: Option<Host>,
    work: impl for<'js> FnOnce(&Ctx<'js>, Function<'js>) -> rquickjs::Result<T>,
) -> Result<T, String> {
    let runtime = Runtime::new().map_err(|failure| failure.to_string())?;
    runtime.set_memory_limit(MEMORY);
    runtime.set_max_stack_size(1 << 20);
    let deadline = Arc::new(Mutex::new(Instant::now() + TIME));
    let due = deadline.clone();
    let past = move || Instant::now() > *cw_core::lock(&due);
    let over = past.clone();
    runtime.set_interrupt_handler(Some(Box::new(past)));
    let context = Context::full(&runtime).map_err(|failure| failure.to_string())?;
    let done = context.with(|ctx| {
        if let Some(host) = host {
            lend(&ctx, host, deadline).map_err(|failure| thrown(&ctx, failure))?;
        }
        let exported = (|| {
            let declared = Module::declare(ctx.clone(), "tool", code)?;
            let (module, evaluated) = declared.eval()?;
            evaluated.finish::<()>()?;
            module.get::<_, Js>("default")
        })();
        let exported = exported.map_err(|failure| thrown(&ctx, failure))?;
        let tool = exported
            .into_function()
            .ok_or("its default export is not a function")?;
        work(&ctx, tool).map_err(|failure| thrown(&ctx, failure))
    });
    match done {
        Err(_) if over() => Err(format!("it ran longer than {} s", TIME.as_secs())),
        done => done,
    }
}

/// Gives the script the host's functions: each takes its tool's arguments as
/// strings, in order, and returns what the tool gave, or throws.
fn lend<'js>(ctx: &Ctx<'js>, host: Host, deadline: Arc<Mutex<Instant>>) -> rquickjs::Result<()> {
    for (name, tool, parameters) in HOST {
        let (host, deadline) = (host.clone(), deadline.clone());
        let function = Function::new(ctx.clone(), move |ctx: Ctx<'js>, given: Rest<String>| {
            let arguments: serde_json::Map<String, Value> = parameters
                .iter()
                .zip(
                    given
                        .0
                        .iter()
                        .map(String::as_str)
                        .chain(std::iter::repeat("")),
                )
                .map(|(parameter, value)| (parameter.to_string(), Value::from(value)))
                .collect();
            let began = Instant::now();
            let done = host(tool, Value::Object(arguments));
            *cw_core::lock(&deadline) += began.elapsed();
            done.map_err(|failure| Exception::throw_message(&ctx, &failure))
        })?
        .with_name(name)?;
        ctx.globals().set(name, function)?;
    }
    Ok(())
}

/// What a failure of QuickJS says: the error thrown, with where.
fn thrown(ctx: &Ctx<'_>, failure: rquickjs::Error) -> String {
    match CaughtError::from_error(ctx, failure) {
        CaughtError::Exception(exception) => {
            let name: String = exception.get("name").unwrap_or_default();
            let message = format!("{name}: {}", exception.message().unwrap_or_default());
            match exception.stack() {
                Some(stack) if !stack.trim().is_empty() => {
                    format!("{message}\n{}", stack.trim_end())
                }
                _ => message,
            }
        }
        CaughtError::Value(value) => ctx
            .json_stringify(value)
            .ok()
            .flatten()
            .and_then(|text| text.to_string().ok())
            .map(|text| format!("it threw {text}"))
            .unwrap_or_else(|| "it threw".into()),
        CaughtError::Error(rquickjs::Error::WouldBlock) => "its promise never settled".into(),
        CaughtError::Error(failure) => failure.to_string(),
    }
}

/// What the written tools need of the database, which `cw_store::written_tools` gives.
pub trait Storage {
    /// The account's tools that are not deleted, the newest first.
    fn written_tools(&self, user: i64) -> anyhow::Result<Vec<WrittenTool>>;
    fn written_tool(&self, user: i64, id: i64) -> anyhow::Result<Option<WrittenTool>>;
    /// As [`add`] says, at once: its ID, or why it was refused.
    fn add_written_tool(
        &self,
        user: i64,
        chat_id: Option<i64>,
        tool: &NewTool,
    ) -> anyhow::Result<anyhow::Result<i64>>;
    /// How many tools it switched.
    fn set_written_tool_on(&self, user: i64, id: i64, on: bool) -> anyhow::Result<usize>;
    /// How many tools it deleted.
    fn delete_written_tool(&self, user: i64, id: i64) -> anyhow::Result<usize>;
    /// As [`restore`] says, at once: why it was refused, if it was.
    fn restore_written_tool(&self, user: i64, id: i64) -> anyhow::Result<anyhow::Result<()>>;
    fn written_tool_used(&self, id: i64) -> anyhow::Result<()>;
    fn purge_deleted_written_tools(&self) -> anyhow::Result<()>;
}

/// The account's tools, the newest first.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<WrittenTool>> {
    db.written_tools(user)
}

/// One of the account's tools.
pub fn get(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<WrittenTool> {
    let found = db.written_tool(user, id)?;
    Ok(found.ok_or(NotFound("tool"))?)
}

/// Keeps `tool` for the account, made in the chat `chat_id` where there is
/// one, unless another took its name meanwhile or the account has
/// `MOST_TOOLS`.
pub fn add(
    db: &dyn Storage,
    user: i64,
    chat_id: Option<i64>,
    tool: &NewTool,
) -> anyhow::Result<WrittenTool> {
    let id = db.add_written_tool(user, chat_id, tool)?;
    get(db, user, id?)
}

/// Switches the tool on or off.
pub fn set_on(db: &dyn Storage, user: i64, id: i64, on: bool) -> anyhow::Result<WrittenTool> {
    let changed = db.set_written_tool_on(user, id, on)?;
    ensure!(changed == 1, NotFound("tool"));
    get(db, user, id)
}

/// Deletes the tool, which `restore` puts back until the server starts again.
pub fn delete(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    let changed = db.delete_written_tool(user, id)?;
    ensure!(changed == 1, NotFound("tool"));
    Ok(())
}

/// Puts back a tool that was deleted, unless another took its name meanwhile.
pub fn restore(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<WrittenTool> {
    let restored = db.restore_written_tool(user, id)?;
    restored?;
    get(db, user, id)
}

/// Counts a run of the tool.
pub fn used(db: &dyn Storage, id: i64) -> anyhow::Result<()> {
    db.written_tool_used(id)
}

/// Deletes for good the tools that were deleted: nothing offers their Undo
/// any more once the server starts again.
pub fn purge_deleted(db: &dyn Storage) -> anyhow::Result<()> {
    db.purge_deleted_written_tools()
}

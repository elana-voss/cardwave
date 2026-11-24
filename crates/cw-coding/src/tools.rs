//! Tools the chat model calls while it writes a reply (OpenAI's function tools,
//! the call `cw_provider::Call`): a chat's own (`chat`: the dice, `dice`, and
//! names for new characters, `names`), the web (`web`), a folder's
//! files (`files`), sandboxed commands (`cw_sandbox`), pictures, the model's own
//! tools (`written`, Code mode's `make_tool`), a coding task (`builtin::START_CODING`) and
//! Cardwave's own (`app`). Which are offered is the account's settings and the
//! chat (`Toolbox::of`): files, commands and coding are this computer's
//! account's alone, pictures need an image model; a written tool switched on is
//! offered in every chat (the owner, 2026-10-17).
//!
//! A file written, a command run and a tool made are first shown to the user
//! (`Toolbox::asks`) unless the settings allow; Cardwave's changes always, cut
//! at `ASKED` characters. A written tool runs on its own thread
//! (`start_written`); its host calls come back as `HostCall`s. A picture is kept
//! by the reply (`Done::picture`), a coding goal until it ends (`task_offered`);
//! a reply's own calls are noted by its loop for "Used in this reply"
//! (`keep_call`, `used`). What a tool asks of the app and the chats is
//! `ports::AppActions`. The app's tools' names are `names`, the MCP server's
//! `crate::mcp`. What a call gives, its failure too, is a `gave::Gave`, whose
//! `for_model` is the text the model reads.

pub mod app;
pub mod chat;
pub mod dice;
pub mod files;
pub mod gave;
pub mod names;
pub mod used;
pub mod web;
pub mod written;

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::Duration;

use crate::tools::gave::Gave;
use crate::tools::web::Web;
use cw_core::{Code, Fail};
use cw_library::settings::Tools;
use cw_provider::Call;
use cw_provider::images::{Picture, Whom};
use tokio::sync::{mpsc, oneshot};
use tokio::task::JoinHandle;

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use ts_rs::TS;

use crate::ports::AppActions;
use used::{CallEnd, UsedCall};
use written::WrittenTool;

/// The longest a command runs.
pub(crate) const COMMAND_TIME: Duration = Duration::from_secs(60);

/// What the model is told of a call the user refused.
pub const REFUSED: &str = "The user did not allow this.";

/// The names of the app's own tools, as the models call them: one place for
/// the offer, the run, the ask, "Used in this reply" and the names a written
/// tool cannot take.
pub(crate) mod builtin {
    pub(crate) const WEB_SEARCH: &str = "web_search";
    pub(crate) const READ_WEB_PAGE: &str = "read_web_page";
    pub(crate) const LIST_FILES: &str = "list_files";
    pub(crate) const READ_FILE: &str = "read_file";
    pub(crate) const WRITE_FILE: &str = "write_file";
    pub(crate) const RUN_COMMAND: &str = "run_command";
    /// A coding task's alone: a command with the internet.
    pub(crate) const INSTALL_PACKAGES: &str = "install_packages";
    pub(crate) const MAKE_PICTURE: &str = "make_picture";
    /// The tool by which an assistant offers the user a coding task.
    pub(crate) const START_CODING: &str = "start_coding_task";
}

/// What the user is asked in the chat before a call runs.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct ToolAsk {
    pub kind: AskKind,
    /// The file's path in the folder, the command, the tool's name, or what
    /// is searched for or read on the web.
    pub what: String,
    /// What the file is to hold, or the tool's code; empty for a command.
    pub detail: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum AskKind {
    Write,
    Command,
    NewTool,
    /// The coding team's: a file read, packages installed, the web used.
    Read,
    Install,
    Web,
    /// A tool of Cardwave's own that changes or deletes something (`app`).
    App,
}

/// A written tool's call of a host's tool, which waits for what it comes to.
pub struct HostCall {
    pub call: Call,
    pub answer: oneshot::Sender<Result<String, String>>,
}

/// A written tool that runs: what it comes to, and its calls of the host's tools.
pub struct WrittenRun {
    pub done: JoinHandle<anyhow::Result<String>>,
    pub calls: mpsc::UnboundedReceiver<HostCall>,
}

/// The most characters of a change of Cardwave's that the user is shown.
const ASKED: usize = 4_000;

/// `text` cut at [`ASKED`] characters, with "…" where it goes on.
fn shown(text: String) -> String {
    match text.char_indices().nth(ASKED) {
        Some((at, _)) => format!("{}…", &text[..at]),
        None => text,
    }
}

/// What the script is told of a call the reply's end cut off.
const CUT_OFF: &str = "the reply was stopped";

/// The tools a reply is offered, with what they need.
pub struct Toolbox {
    tools: Tools,
    /// Code mode: `make_tool` is offered.
    code: bool,
    /// The folder of files and commands, where they are offered.
    folder: Option<PathBuf>,
    /// The image model, where pictures are offered.
    pictures: Option<Whom>,
    /// The account a tool made is kept for, and the chat it is made in.
    user: i64,
    chat_id: Option<i64>,
    /// The account's written tools, those made meanwhile too.
    written: Mutex<Vec<WrittenTool>>,
    /// Whether a coding task may be offered, and the goal of the one offered.
    coding: bool,
    task: Mutex<Option<String>>,
    /// The reply's calls so far, the first first ("Used in this reply").
    used: Mutex<Vec<UsedCall>>,
    /// Cardwave's own tools, and what asks the app for them (`with_app`).
    routes: &'static [crate::tools::app::Route],
    ask_app: Option<crate::tools::app::AskApp>,
}

/// What a call came to.
pub struct Done {
    /// For the model.
    pub text: String,
    /// A picture made, with the words it was made of.
    pub picture: Option<(String, Picture)>,
    /// How it ended; a call that did not succeed says why in `text`.
    pub end: CallEnd,
    /// What "Used in this reply" says of it where its result tells more than
    /// what was asked: a roll, a page's title.
    pub shown: Option<String>,
}

impl Toolbox {
    /// The tools `tools` switch on for `user`, of which files and commands
    /// only for this computer's account (`owner`) and pictures only with an
    /// image model, and with Code mode (`code`) `make_tool` (the account's
    /// written tools come by `with_written`); with `coding`, on this computer's
    /// account, `builtin::START_CODING`. [`Toolbox::offers`] says whether any is offered.
    pub fn of(
        tools: Tools,
        (owner, code): (bool, bool),
        image: Option<Whom>,
        user: i64,
        (coding, routes): (bool, &'static [crate::tools::app::Route]),
    ) -> Self {
        let folder = match (owner, &tools.folder) {
            (true, Some(folder)) if tools.files || tools.commands => Some(PathBuf::from(folder)),
            _ => None,
        };
        let pictures = image.filter(|_| tools.pictures);
        Self {
            folder,
            pictures,
            tools,
            code,
            user,
            chat_id: None,
            written: Mutex::default(),
            coding: coding && owner,
            task: Mutex::default(),
            used: Mutex::default(),
            routes,
            ask_app: None,
        }
    }

    /// Whether any tool is offered.
    pub fn offers(&self) -> bool {
        !self.definitions().is_empty()
    }

    /// Whether a tool is offered that keeps the Reply length from being sent
    /// (`chat::cuts`): any but a chat tool with short arguments.
    pub fn cuts(&self) -> bool {
        crate::tools::chat::cuts(&self.definitions())
    }

    /// What the chat tools offered tell the model before the latest message.
    /// Told by the switches: the definitions (the names tool's lists of
    /// thousands of names) are not built for it.
    pub fn notes(&self) -> Vec<String> {
        crate::tools::chat::ALL
            .into_iter()
            .filter(|tool| (tool.on)(&self.tools))
            .filter_map(|tool| tool.note.map(|note| note()))
            .collect()
    }

    /// The toolbox with the account's written tools.
    pub fn with_written(self, written: Vec<WrittenTool>) -> Self {
        *self.written() = written;
        self
    }

    /// The toolbox whose Cardwave tools are asked of the app by `ask`, where any.
    pub fn with_app(mut self, ask: Option<crate::tools::app::AskApp>) -> Self {
        self.ask_app = ask;
        self
    }

    /// The toolbox of a reply in the chat `chat_id`, where tools are made.
    pub fn in_chat(mut self, chat_id: i64) -> Self {
        self.chat_id = Some(chat_id);
        self
    }

    fn written(&self) -> MutexGuard<'_, Vec<WrittenTool>> {
        cw_core::lock(&self.written)
    }

    /// The written tool `name`, where it is switched on.
    fn written_on(&self, name: &str) -> Option<WrittenTool> {
        let written = self.written();
        written
            .iter()
            .find(|tool| tool.on && tool.name == name)
            .cloned()
    }

    /// Checks the tool `make_tool`'s call asks for, on a thread that may
    /// block, as its code is run to see that it loads.
    async fn checked(&self, call: &Call) -> anyhow::Result<crate::tools::written::NewTool> {
        let taken: Vec<String> = self
            .written()
            .iter()
            .map(|tool| tool.name.clone())
            .collect();
        let (arguments, routes) = (call.arguments.clone(), self.routes);
        tokio::task::spawn_blocking(move || {
            crate::tools::written::check(&arguments, |name| {
                taken.iter().any(|taken| taken == name)
                    || crate::tools::app::named(routes, name).is_some()
            })
        })
        .await?
    }

    fn files(&self) -> bool {
        self.tools.files && self.folder.is_some()
    }

    fn commands(&self) -> bool {
        self.tools.commands && self.folder.is_some() && cw_sandbox::available()
    }

    /// Whether Cardwave's own tools (`app`) are offered.
    pub fn offers_app(&self) -> bool {
        self.tools.app
    }

    /// The tools as the model is told of them.
    pub fn definitions(&self) -> Vec<Value> {
        let mut all = self.switched();
        if self.tools.app {
            all.extend(crate::tools::app::definitions(self.routes));
        }
        if self.code {
            all.push(crate::tools::written::make_definition());
        }
        let written = self.written();
        all.extend(
            written
                .iter()
                // One written before a chat tool took its name is not offered
                // twice under it (the providers refuse that).
                .filter(|tool| tool.on && crate::tools::chat::named(&tool.name).is_none())
                .map(crate::tools::written::definition),
        );
        all
    }

    /// The tools of the settings' switches.
    fn switched(&self) -> Vec<Value> {
        let mut all: Vec<Value> = crate::tools::chat::ALL
            .into_iter()
            .filter(|tool| (tool.on)(&self.tools))
            .map(|tool| (tool.definition)())
            .collect();
        let path = json!({ "type": "string", "description": "A path relative to the folder, such as notes/today.txt" });
        if self.tools.web {
            all.push(tool(
                builtin::WEB_SEARCH,
                "Searches the web. Gives the first results, each with its title, address and a few words of it. Call it whenever the user asks you to search or look something up, and for anything that may have changed since your training (versions, news, prices, dates): do not answer those from memory.",
                json!({ "query": { "type": "string", "description": "What to search for" } }),
            ));
            all.push(tool(
                builtin::READ_WEB_PAGE,
                "Reads a web page and gives its text.",
                json!({ "url": { "type": "string", "description": "The page's address, beginning with https:// or http://" } }),
            ));
        }
        if self.files() {
            all.push(tool(
                builtin::LIST_FILES,
                "Lists the files and folders in the user's shared folder, or in a folder inside it.",
                json!({ "path": { "type": "string", "description": "A folder inside the shared folder; empty for the shared folder itself" } }),
            ));
            all.push(tool(
                builtin::READ_FILE,
                "Reads a text file in the user's shared folder.",
                json!({ "path": path }),
            ));
            all.push(tool(
                builtin::WRITE_FILE,
                "Writes a text file in the user's shared folder, in place of what it held.",
                json!({ "path": path, "content": { "type": "string", "description": "What the file is to hold" } }),
            ));
        }
        if self.commands() {
            all.push(tool(
                builtin::RUN_COMMAND,
                &format!("Runs a command with {} on {} in the user's shared folder and gives what it printed. It runs in a sandbox: it reaches only the files of that folder and has no network. {}", cw_sandbox::SHELL, cw_sandbox::SYSTEM, cw_sandbox::ADVICE),
                json!({ "command": { "type": "string", "description": "The command line" } }),
            ));
        }
        if self.coding {
            all.push(tool(
                builtin::START_CODING,
                "Offers the user a coding task: a team of models works on a goal in a folder of the user's computer, with a checkpoint before each step. The user is shown the task to start, with this goal, after your message, and starts it or not.",
                json!({ "goal": { "type": "string", "description": "What the team is to do, in a sentence or two" } }),
            ));
        }
        if self.pictures.is_some() {
            all.push(tool(
                builtin::MAKE_PICTURE,
                "Makes a picture with the image model; it is shown in the chat after your message. The only way to send a picture: one told of in words is not sent.",
                json!({ "description": { "type": "string", "description": "What the picture shows, in a few sentences" } }),
            ));
        }
        all
    }

    /// What the user is asked before `call` runs, where the settings say so.
    pub async fn asks(&self, call: &Call) -> Option<ToolAsk> {
        // A call that cannot be read is not run, so nobody is asked about it.
        if unreadable(call).is_some() {
            return None;
        }
        match call.name.as_str() {
            builtin::WRITE_FILE if self.files() && self.tools.ask_writes => Some(ToolAsk {
                kind: AskKind::Write,
                what: call.argument("path"),
                detail: call.argument("content"),
            }),
            builtin::RUN_COMMAND if self.commands() && self.tools.ask_commands => Some(ToolAsk {
                kind: AskKind::Command,
                what: call.argument("command"),
                detail: String::new(),
            }),
            // A tool that cannot be made is not asked about: the model is told
            // why. What it does stands over its code, as the model reads it.
            crate::tools::written::MAKE if self.code && self.tools.ask_new_tools => {
                self.checked(call).await.ok().map(|tool| ToolAsk {
                    kind: AskKind::NewTool,
                    what: tool.name,
                    detail: format!("// {}\n{}", tool.description, tool.code),
                })
            }
            crate::tools::app::CALL if self.tools.app => {
                match crate::tools::app::asked(self.routes, &call.arguments) {
                    Ok((route, arguments)) if route.changes() => Some(ToolAsk {
                        kind: AskKind::App,
                        what: route.name.to_string(),
                        detail: shown(format!(
                            "{} {}\n{}",
                            route.method,
                            route.path,
                            serde_json::to_string_pretty(&arguments).unwrap_or_default()
                        )),
                    }),
                    _ => None,
                }
            }
            _ => None,
        }
    }

    /// The reply's calls so far, the first first.
    pub fn used(&self) -> Vec<UsedCall> {
        cw_core::lock(&self.used).clone()
    }

    /// Keeps `call`, which ended as `end`, among [`Self::used`].
    pub fn keep_call(&self, call: &Call, end: CallEnd, shown: Option<String>) {
        cw_core::lock(&self.used).push(used::of(call, end, shown));
    }

    /// Runs `call`. What went wrong is told to the model, as its result.
    pub async fn run(&self, app: &Arc<dyn AppActions>, call: &Call) -> Done {
        let web = app.web();
        if let Some(why) = unreadable(call) {
            return gave(Err(why.into()));
        }
        if let Some(tool) =
            crate::tools::chat::named(&call.name).filter(|tool| (tool.on)(&self.tools))
        {
            return self.run_chat(app, tool, call).await;
        }
        let folder = self.folder.clone().unwrap_or_default();
        match call.name.as_str() {
            builtin::WEB_SEARCH if self.tools.web => {
                gave(web.search(&call.argument("query")).await)
            }
            builtin::READ_WEB_PAGE if self.tools.web => read_page(web, call).await,
            builtin::LIST_FILES if self.files() => {
                gave(crate::tools::files::list(&folder, &call.argument("path")))
            }
            builtin::READ_FILE if self.files() => gave(crate::tools::files::read(
                &folder,
                call.argument("path").trim(),
            )),
            builtin::WRITE_FILE if self.files() => gave(crate::tools::files::write(
                &folder,
                &call.argument("path"),
                &call.argument("content"),
            )),
            builtin::RUN_COMMAND if self.commands() => {
                gave(run_command(folder, call.argument("command")).await)
            }
            builtin::MAKE_PICTURE => self.make_picture(app, call).await,
            crate::tools::written::MAKE if self.code => told(self.make(app, call).await),
            crate::tools::app::CALL if self.tools.app => told(self.ask_app(call).await),
            crate::tools::app::HELP if self.tools.app => told(
                crate::tools::app::named(self.routes, &call.argument("tool"))
                    .map(crate::tools::app::Route::help)
                    .ok_or_else(|| anyhow::anyhow!("Cardwave has no such tool")),
            ),
            builtin::START_CODING if self.coding => {
                let goal = call.argument("goal").trim().to_string();
                told(match goal.is_empty() {
                    true => Err(anyhow::anyhow!("say what the team is to do")),
                    false => {
                        *cw_core::lock(&self.task) = Some(goal);
                        Ok("The user is shown the task to start after your message; the team begins once they start it.".into())
                    }
                })
            }
            _ => match self.start_written(app, call) {
                Some(running) => told(self.unasked(app, running).await),
                None => gave(Err(no_such_tool().into())),
            },
        }
    }

    /// Makes the picture `call` describes, where pictures are offered.
    async fn make_picture(&self, app: &Arc<dyn AppActions>, call: &Call) -> Done {
        let Some(whom) = &self.pictures else {
            return gave(Err(no_such_tool().into()));
        };
        let words = call.argument("description");
        let chat = app.chat();
        match chat.picture(app.http(), whom, &words).await {
            Ok(picture) => Done {
                text: "The picture was made and is shown after your message.".into(),
                picture: Some((words, picture)),
                end: CallEnd::Done,
                shown: None,
            },
            Err(failure) => told(Err(failure)),
        }
    }

    /// Asks Cardwave's own route `call` names, where Cardwave's tools are offered.
    async fn ask_app(&self, call: &Call) -> anyhow::Result<String> {
        match (
            crate::tools::app::asked(self.routes, &call.arguments),
            &self.ask_app,
        ) {
            (Ok((route, arguments)), Some(ask)) => ask(route, arguments).await,
            (Err(failure), _) => Err(failure),
            (Ok(_), None) => Err("Cardwave's tools are not offered here".into()),
        }
        .map_err(|failure| anyhow::anyhow!(failure))
    }

    /// Starts the written tool `call` calls, where it is offered.
    pub fn start_written(&self, app: &Arc<dyn AppActions>, call: &Call) -> Option<WrittenRun> {
        let tool = self.written_on(&call.name)?;
        let (send, calls) = mpsc::unbounded_channel();
        let host: crate::tools::written::Host = Arc::new(move |name, arguments| {
            let (answer, answered) = oneshot::channel();
            let call = Call {
                id: String::new(),
                name: name.to_string(),
                arguments: arguments.to_string(),
            };
            send.send(HostCall { call, answer })
                .map_err(|_| CUT_OFF.to_string())?;
            answered.blocking_recv().unwrap_or(Err(CUT_OFF.into()))
        });
        let (app, arguments) = (app.clone(), call.arguments.clone());
        let done = tokio::task::spawn_blocking(move || {
            let ran = crate::tools::written::run(&tool.code, &arguments, host);
            if let Err(failure) = crate::tools::written::used(app.store(), tool.id) {
                tracing::warn!("a written tool's run was not counted: {failure:#}");
            }
            ran
        });
        Some(WrittenRun { done, calls })
    }

    /// What a written tool comes to where nobody can be asked: its calls that
    /// would ask the user are refused.
    async fn unasked(
        &self,
        app: &Arc<dyn AppActions>,
        mut running: WrittenRun,
    ) -> anyhow::Result<String> {
        // The calls end with the script, which lets their sender go.
        while let Some(request) = running.calls.recv().await {
            let answer = match self.asks(&request.call).await {
                Some(_) => Err(REFUSED.to_string()),
                None => Box::pin(self.run(app, &request.call)).await.result(),
            };
            // Its receiver gone, nobody waits for the answer.
            let _ = request.answer.send(answer);
        }
        running.done.await?
    }
}

/// Why `call`'s arguments cannot be read, where they are not a JSON object (cut
/// short by the provider, a stray quote): the model is told so and may call
/// again. None at all ("") is no fault: a tool without arguments.
pub(crate) fn unreadable(call: &Call) -> Option<Fail> {
    let arguments = call.arguments.trim();
    let read = serde_json::from_str::<serde_json::Map<String, Value>>(arguments);
    match read {
        Err(failure) if !arguments.is_empty() => Some(
            Fail::said(Code::NotReadable, format!(
                "the arguments were not valid JSON ({failure}), so the tool did not run; call it again with its arguments as one JSON object"
            ))
            .with("what", "tool_arguments")
            .with("reason", failure.to_string()),
        ),
        _ => None,
    }
}

/// A call of a tool that is not offered.
pub(crate) fn no_such_tool() -> Fail {
    Fail::said(Code::NotFound, "there is no such tool").with("what", "tool")
}

impl Done {
    /// What a written tool's script is given of the call: its text, or the
    /// failure it throws.
    pub fn result(self) -> Result<String, String> {
        match self.failed() {
            true => Err(self.text),
            false => Ok(self.text),
        }
    }

    /// Whether the call did not succeed, which `text` then says.
    pub fn failed(&self) -> bool {
        self.end != CallEnd::Done
    }
}

impl Toolbox {
    /// Runs the chat tool `tool`'s `call`, on a thread that may block.
    async fn run_chat(
        &self,
        app: &Arc<dyn AppActions>,
        tool: &'static crate::tools::chat::ChatTool,
        call: &Call,
    ) -> Done {
        let (app, chat_id, arguments) = (app.clone(), self.chat_id, call.arguments.clone());
        let ran = tokio::task::spawn_blocking(move || {
            (tool.run)(crate::tools::chat::Turn {
                arguments: &arguments,
                store: app.store(),
                chat_id,
            })
        })
        .await;
        match ran {
            Ok(Ok((text, shown))) => Done {
                shown,
                ..told(Ok(text))
            },
            Ok(Err(failure)) => told(Err(failure)),
            Err(_) => told(Err(anyhow::anyhow!("the tool failed"))),
        }
    }

    /// The goal of the coding task the reply offered, the last where it offered several.
    pub fn task_offered(&self) -> Option<String> {
        cw_core::lock(&self.task).clone()
    }

    /// Keeps the tool `call` asks for, and offers it from then on.
    async fn make(&self, app: &Arc<dyn AppActions>, call: &Call) -> anyhow::Result<String> {
        let tool = self.checked(call).await?;
        let (app, user, chat_id) = (app.clone(), self.user, self.chat_id);
        let made = tokio::task::spawn_blocking(move || {
            crate::tools::written::add(app.store(), user, chat_id, &tool)
        })
        .await??;
        let said = format!(
            "Made the tool {0}. Call it as {0} from now on, in this reply and in later chats.",
            made.name
        );
        self.written().push(made);
        Ok(said)
    }
}

/// Set when it is dropped: a command's sign to end.
#[derive(Default)]
struct Stop(Arc<AtomicBool>);

impl Drop for Stop {
    fn drop(&mut self) {
        self.0.store(true, Ordering::Relaxed);
    }
}

/// A tool's text `result` as the model is told it.
fn told(result: anyhow::Result<String>) -> Done {
    gave(result.map(|text| Gave::Text { text, whole: None }))
}

/// What a tool gave as the model is told it ([`Gave::for_model`]).
fn gave(result: anyhow::Result<Gave>) -> Done {
    let gave = Gave::of(result);
    Done {
        end: match gave.failed() {
            true => CallEnd::Failed,
            false => CallEnd::Done,
        },
        text: gave.for_model(),
        picture: None,
        shown: None,
    }
}

/// The text of the web page `call` names, shown in "Used in this reply" by its
/// title and site.
async fn read_page(web: &Web, call: &Call) -> Done {
    let address = call.argument("url");
    match web.page(address.trim()).await {
        Ok(page) => Done {
            shown: Some(used::page_line(&page.title, &address)),
            ..gave(Ok(page.gave()))
        },
        Err(failure) => gave(Err(failure)),
    }
}

/// Runs `command` in `folder`'s sandbox, at most [`COMMAND_TIME`].
async fn run_command(folder: PathBuf, command: String) -> anyhow::Result<Gave> {
    // A reply stopped lets this go, and so ends the command.
    let stop = Stop::default();
    let stopped = stop.0.clone();
    let ran = tokio::task::spawn_blocking(move || {
        cw_sandbox::run(&folder, &command, COMMAND_TIME, &stopped)
    })
    .await;
    drop(stop);
    match ran {
        Ok(Ok(ran)) => Ok(Gave::ran(ran, COMMAND_TIME)),
        Ok(Err(failure)) => Err(failure),
        Err(_) => Err(anyhow::anyhow!("the command failed")),
    }
}

/// A function tool as the API describes one: every property is required.
pub(crate) fn tool(name: &str, description: &str, properties: Value) -> Value {
    let required: Vec<&String> = properties
        .as_object()
        .map(|all| all.keys().collect())
        .unwrap_or_default();
    json!({
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": { "type": "object", "properties": properties, "required": required },
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_written_tool_named_as_a_chat_tool_is_not_offered() {
        let tools = Tools {
            names: true,
            ..Tools::default()
        };
        let written = |name: &str| WrittenTool {
            id: 1,
            name: name.to_string(),
            description: "A tool.".to_string(),
            code: String::new(),
            on: true,
            created_at: 0,
            chat_id: None,
            chat_title: None,
            uses: 0,
            parameters: serde_json::json!({ "type": "object" }),
        };
        let toolbox = Toolbox::of(tools, (false, false), None, 1, (false, &[])).with_written(vec![
            written(crate::tools::names::NAME),
            written("word_count"),
        ]);
        let offered: Vec<Value> = toolbox.definitions();
        let named: Vec<&str> = offered
            .iter()
            .filter_map(|definition| definition["function"]["name"].as_str())
            .collect();
        assert_eq!(named, [crate::tools::names::NAME, "word_count"]);
    }
}

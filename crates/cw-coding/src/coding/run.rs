//! A coding task as it runs (`spawn`) until it is done, fails or is stopped
//! (`stop`): the planner calls `plan`, each step goes to the next worker in
//! turn, who calls `report`, and the auditor, given the diff of the changes,
//! runs the tests and calls `verdict`; a verdict not passed gets one worker's
//! pass to fix it and one check more (Foreman's auditor). With a check after
//! each step, the task keeps the first verdict that failed.
//!
//! Each role asks the stored provider with its model (`Crew`). A tool whose
//! permission is Ask waits for `answer`; Never is not offered. What a worker's
//! step changed is its checkpoint, however it ends (`snapshot`). Commands run
//! in the sandbox with the server's programs, installing packages with the
//! internet too. Each change is told to the pages as `coding_task`. What it
//! asks of the app (storage, clients, the running tasks) is `ports::AppActions`.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use anyhow::{anyhow, bail};
use cw_core::PageEvent;
use cw_core::{Code, Fail};
use cw_library::settings::{Audit, Permit};
use cw_provider::Call;
use cw_provider::{self as provider, Provider};
use serde_json::{Value, json};
use tokio::sync::oneshot;
use tokio_util::sync::CancellationToken;

use crate::coding::shown::{Checkpoint, StepDetail, StepTool, StepWhat, Who};
use crate::coding::snapshot::Snapshot;
use crate::coding::{Crew, Progress, Verdict};
use crate::ports::{AppActions, Storage};
use crate::tools::sandbox::{self, Reach};
use crate::tools::{AskKind, REFUSED, ToolAsk, files, tool};

/// The most rounds of a role's questions to its model.
const ROUNDS: usize = 30;

/// The longest a command runs.
pub(crate) const COMMAND_TIME: Duration = Duration::from_secs(300);

/// The most of a tool's result that goes into a step's output, in characters.
const LOGGED: usize = 2_000;

/// The most of the changes' diff the auditor is given, in bytes.
const DIFF_LIMIT: usize = 60_000;

/// The most steps of a plan.
const MOST_STEPS: usize = 12;

const PLANNER: &str = "You are the planner of a small coding team that works in a folder on the user's Windows computer. Read what you need of the folder with the tools, then call `plan` with the steps that reach the goal, in order, each a piece of work one worker can do alone (one step for a small goal, at most 8), and the command that runs the project's tests, if it has tests or the steps add them (empty where none). Change nothing yourself.";

const WORKER: &str = "You are a worker of a small coding team that works in a folder on the user's Windows computer. Do your step of the plan, and only it, with the tools: paths are relative to the folder, and commands run with cmd.exe in it, in a sandbox. When your step is done, call `report` with what you did, in a sentence or two.";

const AUDITOR: &str = "You are the auditor of a small coding team. You are given the goal, the plan, what the workers reported and the changes they made as a diff. Check that the changes reach the goal and are right; run the tests with run_command where you can, and read their output yourself. Then call `verdict`: passed is true only if the goal is reached and every test passes; tests_passed and tests_total as the tests' output counts them (left out where no tests ran); each failure with its output; and notes on what is wrong.";

/// The running tasks, by ID.
pub type Tasks = HashMap<i64, Running>;

/// A task that runs: whose it is, what stops it, and its call that waits.
pub struct Running {
    user: i64,
    stop: CancellationToken,
    asking: Option<Asking>,
}

impl Running {
    /// Whose task it is.
    pub fn user(&self) -> i64 {
        self.user
    }
}

/// A tool's call that waits for the user.
struct Asking {
    ask: ToolAsk,
    answer: oneshot::Sender<bool>,
}

/// A task stopped by the user.
#[derive(Debug)]
struct Stopped;

impl std::fmt::Display for Stopped {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("stopped")
    }
}

impl std::error::Error for Stopped {}

/// What waits for the user in the running task `id` of `user`.
pub fn asking(app: &dyn AppActions, user: i64, id: i64) -> Option<ToolAsk> {
    let tasks = app.tasks();
    let running = tasks.get(&id).filter(|running| running.user == user)?;
    running.asking.as_ref().map(|asking| asking.ask.clone())
}

/// Answers the call that waits in the task; false where none waits.
pub fn answer(app: &dyn AppActions, user: i64, id: i64, allow: bool) -> bool {
    let asking = app
        .tasks()
        .get_mut(&id)
        .filter(|running| running.user == user)
        .and_then(|running| running.asking.take());
    match asking {
        Some(asking) => asking.answer.send(allow).is_ok(),
        None => false,
    }
}

/// Stops the task; false where it does not run.
pub fn stop(app: &dyn AppActions, user: i64, id: i64) -> bool {
    let tasks = app.tasks();
    match tasks.get(&id).filter(|running| running.user == user) {
        Some(running) => {
            running.stop.cancel();
            true
        }
        None => false,
    }
}

/// What a task is run with.
pub struct Started {
    pub user: i64,
    pub id: i64,
    pub chat_id: i64,
    pub goal: String,
    pub folder: PathBuf,
    pub crew: Crew,
    /// The stored provider, whose model each role replaces with its own.
    pub provider: Provider,
}

struct Ctx {
    app: Arc<dyn AppActions>,
    started: Started,
    stop: CancellationToken,
}

/// Runs the task on a task of its own.
pub fn spawn(app: Arc<dyn AppActions>, started: Started) {
    let stop = CancellationToken::new();
    let running = Running {
        user: started.user,
        stop: stop.clone(),
        asking: None,
    };
    app.tasks().insert(started.id, running);
    let ctx = Ctx { app, started, stop };
    tokio::spawn(async move {
        let worked = work(&ctx).await;
        let (progress, verdict, error) = match worked {
            Ok(verdict) => (Progress::Done, verdict, None),
            Err(failure) if failure.is::<Stopped>() => (Progress::Stopped, None, None),
            Err(failure) => {
                let body = cw_library::failures::told(&*ctx.app, &failure, Code::RequestFailed);
                // An ErrorBody is always written as JSON.
                (Progress::Failed, None, serde_json::to_string(&body).ok())
            }
        };
        let id = ctx.started.id;
        let ended = ctx
            .stored(move |db| {
                crate::coding::end(db, id, progress, verdict.as_ref(), error.as_deref())
            })
            .await;
        if let Err(failure) = ended {
            tracing::error!("a coding task's end could not be kept: {failure:#}");
        }
        ctx.app.tasks().remove(&id);
        ctx.tell();
    });
}

/// A role at work: who it is, its step, its model and its tools.
struct Role {
    who: String,
    step: i64,
    model: String,
    tools: Vec<Value>,
    /// The tool that ends its work.
    finish: &'static str,
    /// Whether words without a call end its work, as their report.
    words_end: bool,
}

impl Ctx {
    /// Tells the user's pages that the task changed.
    fn tell(&self) {
        let event = PageEvent::CodingTask {
            id: self.started.id,
            chat_id: self.started.chat_id,
        };
        self.app.push(self.started.user, &event);
    }

    /// Storage work, told to the pages after.
    async fn keep<T: Send + 'static>(
        &self,
        work: impl FnOnce(&dyn Storage) -> anyhow::Result<T> + Send + 'static,
    ) -> anyhow::Result<T> {
        let done = self.stored(work).await;
        self.tell();
        done
    }

    /// Storage work on a thread that may block.
    async fn stored<T: Send + 'static>(
        &self,
        work: impl FnOnce(&dyn Storage) -> anyhow::Result<T> + Send + 'static,
    ) -> anyhow::Result<T> {
        let app = self.app.clone();
        tokio::task::spawn_blocking(move || work(app.store())).await?
    }

    async fn snapshot(&self) -> anyhow::Result<Snapshot> {
        let folder = self.started.folder.clone();
        tokio::task::spawn_blocking(move || Snapshot::read(&folder)).await?
    }

    fn permit(&self, name: &str) -> Permit {
        let permissions = &self.started.crew.permissions;
        match name {
            "list_files" | "read_file" => permissions.read,
            "write_file" => permissions.write,
            "run_command" if sandbox::AVAILABLE => permissions.commands,
            "install_packages" if sandbox::AVAILABLE => permissions.install,
            "web_search" | "read_web_page" => permissions.web,
            _ => Permit::Never,
        }
    }

    /// Adds a step, running.
    async fn step(
        &self,
        who: Who,
        what: StepWhat,
        checkpoint: Option<Checkpoint>,
    ) -> anyhow::Result<i64> {
        let task = self.started.id;
        self.keep(move |db| crate::coding::add_step(db, task, &who, &what, checkpoint.as_ref()))
            .await
    }

    /// The tools of `names` the team allows, with the role's own last.
    fn tools(&self, names: &[&str], finish: Value) -> Vec<Value> {
        let path = json!({ "type": "string", "description": "A path relative to the task's folder, such as src/main.rs" });
        let command = json!({ "type": "string", "description": "The command line" });
        let mut all: Vec<Value> = names
            .iter()
            .filter(|name| self.permit(name) != Permit::Never)
            .map(|name| match *name {
                "list_files" => tool(
                    "list_files",
                    "Lists the files and folders in the task's folder, or in a folder inside it.",
                    json!({ "path": { "type": "string", "description": "A folder inside the task's folder; empty for the folder itself" } }),
                ),
                "read_file" => tool("read_file", "Reads a text file in the task's folder.", json!({ "path": path })),
                "write_file" => tool(
                    "write_file",
                    "Writes a text file in the task's folder, in place of what it held.",
                    json!({ "path": path, "content": { "type": "string", "description": "What the file is to hold, whole" } }),
                ),
                "run_command" => tool(
                    "run_command",
                    "Runs a command with cmd.exe in the task's folder and gives what it printed and its exit code. It runs in a sandbox without network that reaches only the folder's files; the computer's installed programs, such as node, npm, python or cargo, run there, but git does not. `dir` is refused there: list the files with `for %f in (*) do @echo %f`.",
                    json!({ "command": command }),
                ),
                "install_packages" => tool(
                    "install_packages",
                    "Runs a command that installs packages (npm install, pip install, cargo fetch and the like) in the task's folder, in the sandbox but with the internet.",
                    json!({ "command": command }),
                ),
                "web_search" => tool(
                    "web_search",
                    "Searches the web. Gives the first results, each with its title, address and a few words of it.",
                    json!({ "query": { "type": "string", "description": "What to search for" } }),
                ),
                _ => tool(
                    "read_web_page",
                    "Reads a web page and gives its text.",
                    json!({ "url": { "type": "string", "description": "The page's address, beginning with https:// or http://" } }),
                ),
            })
            .collect();
        all.push(finish);
        all
    }

    /// Has `role` work on `task` until it calls its tool that ends, whose
    /// arguments are the answer; words alone end the work of a role that
    /// takes them, as its answer's `summary`.
    async fn work(&self, role: &Role, system: &str, task: String) -> anyhow::Result<Value> {
        // The chat model's thinking turned off holds for it alone: another
        // model may not take the same form.
        let chat = &self.started.provider;
        let provider = Provider {
            model: role.model.clone(),
            thinking_off: chat.thinking_off.filter(|_| role.model == chat.model),
            seen_thinking: chat.seen_thinking && role.model == chat.model,
            ..chat.clone()
        };
        let http = self.app.http();
        let mut prompt = vec![
            json!({ "role": "system", "content": system }),
            json!({ "role": "user", "content": task }),
        ];
        for _ in 0..ROUNDS {
            let asked = tokio::select! {
                _ = self.stop.cancelled() => bail!(Stopped),
                asked = provider::ask_with(http, &provider, &prompt, &role.tools) => asked,
            };
            let mut reply = asked.map_err(|failure| failure.context(role.who.clone()))?;
            let mut words = String::new();
            loop {
                let piece = tokio::select! {
                    _ = self.stop.cancelled() => bail!(Stopped),
                    piece = reply.next() => piece.map_err(|failure| failure.context(role.who.clone()))?,
                };
                match piece {
                    Some(piece) => words.push_str(&piece),
                    None => break,
                }
            }
            let calls = reply.calls();
            if !words.trim().is_empty() {
                let (step, said) = (role.step, format!("{}\n\n", words.trim()));
                self.keep(move |db| crate::coding::log(db, step, &said))
                    .await?;
            }
            if calls.is_empty() {
                if role.words_end && !words.trim().is_empty() {
                    return Ok(json!({ "summary": words.trim() }));
                }
                prompt.push(json!({ "role": "assistant", "content": words }));
                let nudge = format!("Call `{}` when you are done.", role.finish);
                prompt.push(json!({ "role": "user", "content": nudge }));
                continue;
            }
            let sent: Vec<Value> = calls.iter().map(Call::sent).collect();
            prompt.push(json!({ "role": "assistant", "content": words, "tool_calls": sent }));
            for call in &calls {
                if call.name == role.finish {
                    return Ok(serde_json::from_str(&call.arguments).unwrap_or_default());
                }
                let result = self.call(role, call).await?;
                prompt.push(json!({ "role": "tool", "tool_call_id": call.id, "content": result }));
            }
        }
        bail!(
            Fail::said(
                Code::ModelAnswer,
                format!("{} did not end its work in {ROUNDS} rounds", role.who)
            )
            .with("what", "rounds")
            .with("rounds", ROUNDS)
        )
    }

    /// Runs a tool's call, asking the user first where the team says so.
    /// What went wrong is the model's to read, as the call's result.
    async fn call(&self, role: &Role, call: &Call) -> anyhow::Result<String> {
        let arguments: Value = serde_json::from_str(&call.arguments).unwrap_or_default();
        let argument = |name: &str| arguments[name].as_str().unwrap_or_default().to_string();
        let permit = self.permit(&call.name);
        let (kind, what, detail, doing) = match call.name.as_str() {
            "list_files" => {
                let path = argument("path");
                (
                    AskKind::Read,
                    path.clone(),
                    String::new(),
                    (StepTool::ListFiles, path),
                )
            }
            "read_file" => {
                let path = argument("path");
                (
                    AskKind::Read,
                    path.clone(),
                    String::new(),
                    (StepTool::ReadFile, path),
                )
            }
            "write_file" => {
                let path = argument("path");
                (
                    AskKind::Write,
                    path.clone(),
                    argument("content"),
                    (StepTool::WriteFile, path),
                )
            }
            "run_command" => {
                let command = argument("command");
                (
                    AskKind::Command,
                    command.clone(),
                    String::new(),
                    (StepTool::RunCommand, command),
                )
            }
            "install_packages" => {
                let command = argument("command");
                (
                    AskKind::Install,
                    command.clone(),
                    String::new(),
                    (StepTool::InstallPackages, command),
                )
            }
            "web_search" => {
                let query = argument("query");
                (
                    AskKind::Web,
                    query.clone(),
                    String::new(),
                    (StepTool::WebSearch, query),
                )
            }
            "read_web_page" => {
                let url = argument("url");
                (
                    AskKind::Web,
                    url.clone(),
                    String::new(),
                    (StepTool::ReadWebPage, url),
                )
            }
            _ => return Ok("Failed: there is no such tool".into()),
        };
        if permit == Permit::Never {
            return Ok("Failed: there is no such tool".into());
        }
        let step = role.step;
        let (tool, target) = doing;
        // The log tells each call as the team made it: the tool and what it is called on.
        let doing = format!("{} {target}", call.name).trim_end().to_string();
        let shown = StepDetail::Tool { tool, target };
        self.keep(move |db| crate::coding::set_detail(db, step, &shown))
            .await?;
        if permit == Permit::Ask {
            let ask = ToolAsk { kind, what, detail };
            if !self.ask(ask).await? {
                let logged = format!("> {doing}\n{REFUSED}\n\n");
                self.keep(move |db| crate::coding::log(db, step, &logged))
                    .await?;
                return Ok(REFUSED.into());
            }
        }
        let result = self
            .run(call, &arguments)
            .await?
            .unwrap_or_else(|failure| format!("Failed: {failure:#}"));
        let cut: String = result.chars().take(LOGGED).collect();
        let more = if cut.len() < result.len() {
            "\n…"
        } else {
            ""
        };
        let logged = format!("> {doing}\n{cut}{more}\n\n");
        self.keep(move |db| crate::coding::log(db, step, &logged))
            .await?;
        Ok(result)
    }

    /// Runs a call; the outer error is a stop.
    async fn run(&self, call: &Call, arguments: &Value) -> anyhow::Result<anyhow::Result<String>> {
        let argument = |name: &str| arguments[name].as_str().unwrap_or_default().to_string();
        let folder = self.started.folder.clone();
        let web = self.app.web();
        let done = match call.name.as_str() {
            "list_files" => files::list(&folder, &argument("path")),
            "read_file" => files::read(&folder, &argument("path")),
            "write_file" => files::write(&folder, &argument("path"), &argument("content")),
            "web_search" => self.stopping(web.search(&argument("query"))).await?,
            "read_web_page" => self.stopping(web.read(&argument("url"))).await?,
            name => {
                let reach = Reach {
                    network: name == "install_packages",
                    programs: true,
                    data: self.app.data_dir().to_path_buf(),
                };
                let command = argument("command");
                let stopped = Arc::new(AtomicBool::new(false));
                let flag = stopped.clone();
                let ran = tokio::task::spawn_blocking(move || {
                    sandbox::run_with(&folder, &command, COMMAND_TIME, &flag, reach)
                });
                let ran = tokio::select! {
                    _ = self.stop.cancelled() => {
                        stopped.store(true, Ordering::Relaxed);
                        bail!(Stopped)
                    }
                    ran = ran => ran?,
                };
                ran.map(|ran| match ran.code {
                    Some(code) => format!("Exit code {code}.\n{}", ran.output),
                    None => format!(
                        "Stopped after {} s.\n{}",
                        COMMAND_TIME.as_secs(),
                        ran.output
                    ),
                })
            }
        };
        Ok(done)
    }

    async fn stopping<T>(&self, work: impl Future<Output = T>) -> anyhow::Result<T> {
        tokio::select! {
            _ = self.stop.cancelled() => bail!(Stopped),
            done = work => Ok(done),
        }
    }

    /// Asks the user whether a call may run, and waits for the answer.
    async fn ask(&self, ask: ToolAsk) -> anyhow::Result<bool> {
        let (answer, answered) = oneshot::channel();
        if let Some(running) = self.app.tasks().get_mut(&self.started.id) {
            running.asking = Some(Asking { ask, answer });
        }
        self.tell();
        let allowed = tokio::select! {
            _ = self.stop.cancelled() => Err(anyhow!(Stopped)),
            allowed = answered => Ok(allowed.unwrap_or(false)),
        };
        if let Some(running) = self.app.tasks().get_mut(&self.started.id) {
            running.asking = None;
        }
        self.tell();
        allowed
    }

    /// What every role is told of the task: the goal, and the plan with
    /// what the workers reported, where there are.
    fn brief(&self, plan: Option<&Plan>, reports: &[String]) -> String {
        let mut brief = format!("The goal: {}\n", self.started.goal);
        if let Some(plan) = plan {
            brief.push_str(&format!("\nThe plan:\n{}", plan.text()));
        }
        if !reports.is_empty() {
            brief.push_str(&format!(
                "\nWhat was done so far:\n{}\n",
                reports.join("\n")
            ));
        }
        brief
    }
}

/// The plan: its steps and the command of the tests.
struct Plan {
    steps: Vec<String>,
    tests: String,
}

impl Plan {
    fn text(&self) -> String {
        let mut text: String = self
            .steps
            .iter()
            .enumerate()
            .map(|(at, step)| format!("{}. {step}\n", at + 1))
            .collect();
        if !self.tests.is_empty() {
            text.push_str(&format!("Tests: {}\n", self.tests));
        }
        text
    }
}

async fn work(ctx: &Ctx) -> anyhow::Result<Option<Verdict>> {
    let baseline = ctx.snapshot().await?;
    let mut now = baseline.clone();
    let plan = plan(ctx).await?;
    let mut reports = Vec::new();
    let mut verdict = None;
    let workers = usize::from(ctx.started.crew.workers.clamp(1, 3));
    for (at, title) in plan.steps.iter().enumerate() {
        let worker = at % workers + 1;
        let each = ctx.started.crew.audit == Audit::EachStep;
        let before = each.then(|| now.clone());
        let order = Order {
            worker,
            what: title,
            checkpoint: Checkpoint::BeforeStep { step: at + 1 },
            findings: None,
        };
        now = build(ctx, &plan, &mut reports, order, now).await?;
        if let Some(before) = before {
            let audit = Scope {
                from: &before,
                fixer: worker,
                shown: StepWhat::CheckStep { step: at + 1 },
            };
            let checked = audit_and_fix(ctx, &plan, &mut reports, audit, &mut now).await?;
            // A step left failing is not hidden by a later one that passes.
            if verdict.as_ref().is_none_or(|kept: &Verdict| kept.passed) {
                verdict = Some(checked);
            }
        }
    }
    if ctx.started.crew.audit == Audit::End {
        let audit = Scope {
            from: &baseline,
            fixer: 1,
            shown: StepWhat::CheckAll,
        };
        verdict = Some(audit_and_fix(ctx, &plan, &mut reports, audit, &mut now).await?);
    }
    Ok(verdict)
}

/// The planner's step: the plan.
async fn plan(ctx: &Ctx) -> anyhow::Result<Plan> {
    let step = ctx.step(Who::Planner, StepWhat::Plan, None).await?;
    let finish = tool(
        "plan",
        "Hands the plan to the workers.",
        json!({
            "steps": { "type": "array", "items": { "type": "string" }, "description": "The steps in order, each a sentence that says what is to be done" },
            "test_command": { "type": "string", "description": "The command that runs the tests; empty where there are none" },
        }),
    );
    let role = Role {
        who: "Planner".into(),
        step,
        model: ctx.started.crew.planner_model.clone(),
        tools: ctx.tools(&["list_files", "read_file"], finish),
        finish: "plan",
        words_end: false,
    };
    let task = format!(
        "{}\nThe team has {} worker(s).",
        ctx.brief(None, &[]),
        ctx.started.crew.workers
    );
    let planned = ctx.work(&role, PLANNER, task).await?;
    let steps: Vec<String> = planned["steps"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|step| match step {
            Value::String(text) => Some(text.trim().to_string()),
            other => other["title"].as_str().map(|text| text.trim().to_string()),
        })
        .filter(|step| !step.is_empty())
        .take(MOST_STEPS)
        .collect();
    if steps.is_empty() {
        bail!(Fail::said(Code::ModelAnswer, "the planner made no plan").with("what", "no_plan"));
    }
    let plan = Plan {
        steps,
        tests: planned["test_command"]
            .as_str()
            .unwrap_or_default()
            .trim()
            .to_string(),
    };
    let (task, count, text) = (ctx.started.id, plan.steps.len(), plan.text());
    let what = StepWhat::Planned { steps: count };
    ctx.keep(move |db| {
        crate::coding::set_planned(db, task, count)?;
        crate::coding::set_what(db, step, &what)?;
        crate::coding::set_detail(db, step, &StepDetail::ShowPlan)?;
        crate::coding::log(db, step, &format!("The plan:\n{text}"))?;
        crate::coding::end_step(db, step, Progress::Done)
    })
    .await?;
    Ok(plan)
}

/// What a worker is given to do.
struct Order<'a> {
    worker: usize,
    what: &'a str,
    checkpoint: Checkpoint,
    /// What the auditor found, for a pass that fixes it.
    findings: Option<&'a str>,
}

/// A worker's step on the folder as `now` holds it, which gives the folder
/// as the step left it. What it changed is kept, however it ends.
async fn build(
    ctx: &Ctx,
    plan: &Plan,
    reports: &mut Vec<String>,
    order: Order<'_>,
    now: Snapshot,
) -> anyhow::Result<Snapshot> {
    let who = format!("Worker {}", order.worker);
    let shown = match order.findings {
        Some(_) => StepWhat::Fix,
        None => StepWhat::Work {
            step: order.what.to_string(),
        },
    };
    let worker = Who::Worker {
        number: order.worker,
    };
    let step = ctx.step(worker, shown, Some(order.checkpoint)).await?;
    let finish = tool(
        "report",
        "Ends your step with what you did.",
        json!({ "summary": { "type": "string", "description": "What you did, in a sentence or two" } }),
    );
    let names = [
        "list_files",
        "read_file",
        "write_file",
        "run_command",
        "install_packages",
        "web_search",
        "read_web_page",
    ];
    let role = Role {
        who: who.clone(),
        step,
        model: ctx.started.crew.worker_model.clone(),
        tools: ctx.tools(&names, finish),
        finish: "report",
        words_end: true,
    };
    let mut task = format!(
        "{}\nYour step: {}\n",
        ctx.brief(Some(plan), reports),
        order.what
    );
    if let Some(findings) = order.findings {
        task.push_str(&format!(
            "\nThe auditor found this wrong; fix it:\n{findings}\n"
        ));
    }
    let worked = ctx.work(&role, WORKER, task).await;
    // What the step changed is its checkpoint, also where it failed or was stopped.
    let after = ctx.snapshot().await?;
    let changes = now.into_changes(&after);
    let (added, removed) = changes.iter().fold((0, 0), |(added, removed), change| {
        let (more, less, _) =
            crate::coding::snapshot::diff(change.before.as_deref(), change.after.as_deref());
        (added + more, removed + less)
    });
    let detail = StepDetail::Changed {
        added,
        removed,
        files: changes.len(),
    };
    let state = match &worked {
        Ok(_) => Progress::Done,
        Err(failure) if failure.is::<Stopped>() => Progress::Stopped,
        Err(_) => Progress::Failed,
    };
    ctx.keep(move |db| {
        crate::coding::keep_changes(db, step, &changes)?;
        crate::coding::set_detail(db, step, &detail)?;
        crate::coding::end_step(db, step, state)
    })
    .await?;
    let report = worked?;
    let summary = report["summary"].as_str().unwrap_or_default().trim();
    reports.push(format!("{who} ({}): {summary}", order.what));
    Ok(after)
}

/// An auditor's check: of the changes since `from`, by the worker `fixer`
/// where they fail.
struct Scope<'a> {
    from: &'a Snapshot,
    fixer: usize,
    /// What its step shows.
    shown: StepWhat,
}

/// Has the auditor check the changes, and where they fail, a worker fix
/// them once and the auditor check again.
async fn audit_and_fix(
    ctx: &Ctx,
    plan: &Plan,
    reports: &mut Vec<String>,
    audit: Scope<'_>,
    now: &mut Snapshot,
) -> anyhow::Result<Verdict> {
    let verdict = check(ctx, plan, reports, audit.from.changes(now), &audit).await?;
    if verdict.passed {
        return Ok(verdict);
    }
    let mut findings: String = verdict
        .failures
        .iter()
        .map(|failure| format!("- {}\n{}\n", failure.name, failure.output))
        .collect();
    findings.push_str(&verdict.notes);
    let order = Order {
        worker: audit.fixer,
        what: "Fixes what the auditor found",
        checkpoint: Checkpoint::BeforeFix,
        findings: Some(&findings),
    };
    *now = build(ctx, plan, reports, order, std::mem::take(now)).await?;
    check(ctx, plan, reports, audit.from.changes(now), &audit).await
}

/// The auditor's step: the verdict on `changes`.
async fn check(
    ctx: &Ctx,
    plan: &Plan,
    reports: &[String],
    changes: Vec<crate::coding::snapshot::Change>,
    audit: &Scope<'_>,
) -> anyhow::Result<Verdict> {
    let step = ctx.step(Who::Auditor, audit.shown.clone(), None).await?;
    let finish = tool(
        "verdict",
        "Gives your verdict on the changes.",
        json!({
            "passed": { "type": "boolean", "description": "True only if the goal is reached and every test passes" },
            "tests_passed": { "type": "integer", "description": "How many tests passed; leave out where none ran" },
            "tests_total": { "type": "integer", "description": "How many tests ran; leave out where none ran" },
            "failures": { "type": "array", "items": { "type": "object", "properties": { "name": { "type": "string" }, "output": { "type": "string" } } }, "description": "Each test that failed, or other thing wrong, with its output" },
            "notes": { "type": "string", "description": "What is wrong or missing, briefly" },
        }),
    );
    let mut function = finish;
    // Only these two are asked for; the counts are left out where no tests ran.
    function["function"]["parameters"]["required"] = json!(["passed", "notes"]);
    let role = Role {
        who: "Auditor".into(),
        step,
        model: ctx.started.crew.auditor_model.clone(),
        tools: ctx.tools(&["list_files", "read_file", "run_command"], function),
        finish: "verdict",
        words_end: false,
    };
    let mut diff = String::new();
    for change in &changes {
        let (_, _, text) =
            crate::coding::snapshot::diff(change.before.as_deref(), change.after.as_deref());
        diff.push_str(&format!("=== {}\n{text}\n", change.path));
    }
    if diff.len() > DIFF_LIMIT {
        let mut end = DIFF_LIMIT;
        while !diff.is_char_boundary(end) {
            end -= 1;
        }
        diff.truncate(end);
        diff.push_str("\n… (cut off; read the files for the rest)\n");
    }
    if changes.is_empty() {
        diff = "(nothing was changed)\n".into();
    }
    let task = format!("{}\nThe changes:\n{diff}", ctx.brief(Some(plan), reports));
    let worked = ctx.work(&role, AUDITOR, task).await;
    let verdict = match worked {
        Ok(given) => verdict_of(&given),
        Err(failure) => {
            let state = match failure.is::<Stopped>() {
                true => Progress::Stopped,
                false => Progress::Failed,
            };
            ctx.keep(move |db| crate::coding::end_step(db, step, state))
                .await?;
            return Err(failure);
        }
    };
    let said = StepWhat::Verdict {
        passed: verdict.passed,
        tests_passed: verdict.tests_passed,
        tests_total: verdict.tests_total,
    };
    let notes = verdict.notes.clone();
    ctx.keep(move |db| {
        crate::coding::set_what(db, step, &said)?;
        crate::coding::set_detail(db, step, &StepDetail::None)?;
        if !notes.is_empty() {
            crate::coding::log(db, step, &format!("{notes}\n"))?;
        }
        crate::coding::end_step(db, step, Progress::Done)
    })
    .await?;
    Ok(verdict)
}

/// The verdict the auditor's call gives, each field read as far as it can be:
/// a count sent as text or a failure's output as an object loses nothing else.
fn verdict_of(given: &Value) -> Verdict {
    let count = |value: &Value| {
        value
            .as_u64()
            .or_else(|| value.as_f64().map(|count| count as u64))
            .or_else(|| value.as_str()?.trim().parse().ok())
            .and_then(|count| u32::try_from(count).ok())
    };
    let text = |value: &Value| match value {
        Value::String(text) => text.clone(),
        Value::Null => String::new(),
        other => other.to_string(),
    };
    let passed = match &given["passed"] {
        Value::String(said) => said.trim().eq_ignore_ascii_case("true"),
        said => said.as_bool().unwrap_or(false),
    };
    let failures = given["failures"].as_array().into_iter().flatten();
    Verdict {
        passed,
        tests_passed: count(&given["tests_passed"]),
        tests_total: count(&given["tests_total"]),
        failures: failures
            .map(|failure| crate::coding::Failure {
                name: text(&failure["name"]),
                output: text(&failure["output"]),
            })
            .collect(),
        notes: text(&given["notes"]),
    }
}

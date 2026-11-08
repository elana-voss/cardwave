//! The coding team (Foreman's, in Rust): a task given to it in a chat is
//! planned by the planner, built step by step by its workers and checked by
//! its auditor (`run`); the team and its models are the account's settings
//! (`settings::CodingTeam`), its tools' permissions its Settings › Tools
//! (`settings::Permissions::of`).
//!
//! Here the tasks as kept: a task's card is a message of the chat's character
//! (`start`), its steps are kept in order, and a step that changed files keeps
//! them as they were before and after it (`snapshot`), its checkpoint: `undo`
//! puts the folder back to before a step and those after it. A task's `files`
//! are what its steps changed that is not undone, their diffs drawn when the
//! task is read. A task is this computer's account's alone, and one that was
//! running when the server stopped is stopped (`stop_interrupted`).

pub mod run;
pub mod shown;
pub mod snapshot;

use std::collections::BTreeMap;
use std::path::Path;

use anyhow::{Context as _, ensure};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_library::settings::{Audit, Permissions, Team};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::ports::ChatSide;
use crate::tools::ToolAsk;
use shown::{Checkpoint, StepDetail, StepWhat, Who};
use snapshot::Change;

/// How far a task or a step is.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Progress {
    Running,
    Done,
    Failed,
    Stopped,
}

impl Progress {
    pub fn name(self) -> &'static str {
        match self {
            Self::Running => "running",
            Self::Done => "done",
            Self::Failed => "failed",
            Self::Stopped => "stopped",
        }
    }

    pub fn of(name: &str) -> Self {
        match name {
            "running" => Self::Running,
            "done" => Self::Done,
            "failed" => Self::Failed,
            _ => Self::Stopped,
        }
    }
}

/// The team a task was given, as it was when the task began.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Crew {
    pub team: Team,
    pub workers: u8,
    pub audit: Audit,
    pub planner_model: String,
    pub worker_model: String,
    pub auditor_model: String,
    pub permissions: Permissions,
}

/// What the auditor found.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct Verdict {
    pub(crate) passed: bool,
    /// The tests that passed, of all that ran, where tests ran.
    pub(crate) tests_passed: Option<u32>,
    pub(crate) tests_total: Option<u32>,
    pub failures: Vec<Failure>,
    pub notes: String,
}

/// A test that failed, or another thing the auditor found wrong, with what
/// it printed.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct Failure {
    pub name: String,
    pub output: String,
}

/// A file changed, with the lines added and removed, and its diff.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct FileChange {
    pub path: String,
    pub added: usize,
    pub removed: usize,
    pub(crate) diff: String,
}

/// A step of a task, as its page shows it.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct Step {
    pub id: i64,
    pub who: Who,
    pub what: StepWhat,
    /// The grey line: what runs now, or what it changed.
    pub detail: StepDetail,
    pub state: Progress,
    pub output: String,
    pub files: Vec<FileChange>,
    /// Its checkpoint, for a worker's step.
    pub checkpoint: Option<Checkpoint>,
    pub undone: bool,
    pub started_at: i64,
}

/// A task with its steps.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct Task {
    pub id: i64,
    pub chat_id: i64,
    pub chat_title: String,
    pub message_id: Option<i64>,
    pub goal: String,
    pub folder: String,
    pub crew: Crew,
    pub state: Progress,
    /// How many steps the planner planned.
    pub planned: usize,
    pub verdict: Option<Verdict>,
    /// Why it failed, when it did; a provider's own words are its detail `reason`.
    pub error: Option<cw_core::ErrorBody>,
    pub started_at: i64,
    pub ended_at: Option<i64>,
    pub steps: Vec<Step>,
    /// What the steps changed that is not undone.
    pub files: Vec<FileChange>,
    /// A tool's call that waits for the user.
    pub ask: Option<ToolAsk>,
}

/// A task as a list of tasks shows it.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct TaskLine {
    pub id: i64,
    pub chat_id: i64,
    pub goal: String,
    pub folder: String,
    pub state: Progress,
    pub verdict: Option<Verdict>,
    pub started_at: i64,
}

/// A task as kept.
pub struct TaskRow {
    pub chat_id: i64,
    pub chat_title: String,
    /// The message with its card.
    pub message_id: Option<i64>,
    pub goal: String,
    pub folder: String,
    /// The crew, as JSON.
    pub team: String,
    pub state: String,
    /// How many steps were planned.
    pub planned: i64,
    /// As JSON.
    pub verdict: Option<String>,
    /// As JSON, an `ErrorBody`.
    pub error: Option<String>,
    pub started_at: i64,
    pub ended_at: Option<i64>,
}

/// A task with each of its steps (its files empty) and the step's changes.
pub struct KeptTask {
    pub task: TaskRow,
    pub steps: Vec<(Vec<Change>, Step)>,
}

/// What the coding tasks need of the database, which `cw_store::coding` gives.
pub trait Storage {
    /// The folders of the tasks that run.
    fn running_folders(&self) -> anyhow::Result<Vec<String>>;
    /// Adds a task, running, of `goal` in `folder` by `crew` (JSON).
    fn add_coding_task(
        &self,
        user: i64,
        chat_id: i64,
        message_id: i64,
        goal_folder: (&str, &str),
        crew: &str,
    ) -> anyhow::Result<i64>;
    fn add_coding_step(
        &self,
        task: i64,
        who: &Who,
        what: &StepWhat,
        checkpoint: Option<&Checkpoint>,
    ) -> anyhow::Result<i64>;
    fn set_step_what(&self, step: i64, what: &StepWhat) -> anyhow::Result<()>;
    fn set_step_detail(&self, step: i64, detail: &StepDetail) -> anyhow::Result<()>;
    /// Adds `text` to the step's output while that is shorter than `most`.
    fn log_step(&self, step: i64, text: &str, most: usize) -> anyhow::Result<()>;
    fn end_coding_step(&self, step: i64, state: Progress) -> anyhow::Result<()>;
    /// As [`keep_changes`] says, at once.
    fn keep_step_changes(&self, step: i64, changes: &[Change]) -> anyhow::Result<()>;
    fn set_planned_steps(&self, task: i64, planned: usize) -> anyhow::Result<()>;
    /// As [`end`] says, at once; `verdict` as JSON.
    fn end_coding_task(
        &self,
        task: i64,
        state: Progress,
        verdict: Option<&str>,
        error: Option<&str>,
    ) -> anyhow::Result<()>;
    /// Stops the tasks and steps that run.
    fn stop_running_tasks(&self) -> anyhow::Result<()>;
    /// As [`list`] says.
    fn coding_tasks(
        &self,
        user: i64,
        chat_id: Option<i64>,
        most: usize,
    ) -> anyhow::Result<Vec<TaskLine>>;
    fn coding_task_row(&self, user: i64, id: i64) -> anyhow::Result<Option<(String, Progress)>>;
    /// The user's task, with each step (its files empty) and its changes, at once.
    fn coding_task(&self, user: i64, id: i64) -> anyhow::Result<Option<KeptTask>>;
    /// The task's steps with a checkpoint that are not undone, from `from`
    /// (all where none), the newest first, with their changes.
    fn steps_to_undo(
        &self,
        task: i64,
        from: Option<i64>,
    ) -> anyhow::Result<Vec<(i64, Vec<Change>)>>;
    fn step_undone(&self, step: i64) -> anyhow::Result<()>;
}

/// Adds the task's card to the chat, as a message of its first character,
/// and the task, running, and answers its ID; not while another task runs in
/// the folder.
pub fn start(
    db: &dyn Storage,
    chat: &dyn ChatSide,
    user: i64,
    chat_id: i64,
    goal: &str,
    folder: &str,
    crew: &Crew,
) -> anyhow::Result<i64> {
    // Two tasks in one folder would take each other's changes for their own.
    let same = |other: &str| {
        let real = |path: &str| {
            std::fs::canonicalize(path)
                .ok()
                .map(|path| path.to_string_lossy().to_lowercase())
        };
        real(other).is_some() && real(other) == real(folder)
    };
    let running = db.running_folders()?;
    ensure!(
        !running.iter().any(|other| same(other)),
        Fail::said(
            Code::NotNow,
            "another coding task is running in that folder; wait for it, or stop it"
        )
        .with("what", "coding_folder_busy")
    );
    let content = format!("(Coding task: {goal})");
    let message_id = chat.post(user, chat_id, &content)?;
    let crew = serde_json::to_string(crew)?;
    db.add_coding_task(user, chat_id, message_id, (goal, folder), &crew)
}

/// Adds a step to the task, running.
pub(crate) fn add_step(
    db: &dyn Storage,
    task: i64,
    who: &Who,
    what: &StepWhat,
    checkpoint: Option<&Checkpoint>,
) -> anyhow::Result<i64> {
    db.add_coding_step(task, who, what, checkpoint)
}

/// Sets what a step says it does.
pub(crate) fn set_what(db: &dyn Storage, step: i64, what: &StepWhat) -> anyhow::Result<()> {
    db.set_step_what(step, what)
}

/// Sets what a step's grey line says.
pub(crate) fn set_detail(db: &dyn Storage, step: i64, detail: &StepDetail) -> anyhow::Result<()> {
    db.set_step_detail(step, detail)
}

/// The most of a step's output that is kept.
const OUTPUT_LIMIT: usize = 200_000;

/// Adds `text` to a step's output, while it has room.
pub fn log(db: &dyn Storage, step: i64, text: &str) -> anyhow::Result<()> {
    db.log_step(step, text, OUTPUT_LIMIT)
}

/// Ends a step.
pub(crate) fn end_step(db: &dyn Storage, step: i64, state: Progress) -> anyhow::Result<()> {
    db.end_coding_step(step, state)
}

/// Keeps what a step changed; a step that changed nothing has no checkpoint.
pub(crate) fn keep_changes(db: &dyn Storage, step: i64, changes: &[Change]) -> anyhow::Result<()> {
    db.keep_step_changes(step, changes)
}

/// Sets how many steps the planner planned.
pub(crate) fn set_planned(db: &dyn Storage, task: i64, planned: usize) -> anyhow::Result<()> {
    db.set_planned_steps(task, planned)
}

/// Ends a task, and a step of it that still runs as it.
pub fn end(
    db: &dyn Storage,
    task: i64,
    state: Progress,
    verdict: Option<&Verdict>,
    error: Option<&str>,
) -> anyhow::Result<()> {
    let verdict = verdict.map(serde_json::to_string).transpose()?;
    db.end_coding_task(task, state, verdict.as_deref(), error)
}

/// Stops the tasks that were running when the server stopped.
pub fn stop_interrupted(db: &dyn Storage) -> anyhow::Result<()> {
    db.stop_running_tasks()
}

pub fn verdict_of(text: Option<String>) -> Option<Verdict> {
    text.and_then(|text| serde_json::from_str(&text).ok())
}

/// The lines of the user's tasks, the newest first: of the chat `chat_id`,
/// or of all chats, at most `most`.
pub fn list(
    db: &dyn Storage,
    user: i64,
    chat_id: Option<i64>,
    most: usize,
) -> anyhow::Result<Vec<TaskLine>> {
    db.coding_tasks(user, chat_id, most)
}

/// The folder of the user's task `id`, and how far it is.
pub fn task_row(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<(String, Progress)> {
    let found = db.coding_task_row(user, id)?;
    Ok(found.ok_or(NotFound("task"))?)
}

/// A file as it was before and after (`None`: not there).
type Ends = (Option<Vec<u8>>, Option<Vec<u8>>);

fn file_change(path: &str, before: Option<&[u8]>, after: Option<&[u8]>) -> FileChange {
    let (added, removed, diff) = crate::coding::snapshot::diff(before, after);
    FileChange {
        path: path.to_string(),
        added,
        removed,
        diff,
    }
}

/// The user's task `id`, with its steps and the files they changed; `ask` is
/// what waits for the user, which the runner holds.
pub fn get(db: &dyn Storage, user: i64, id: i64, ask: Option<ToolAsk>) -> anyhow::Result<Task> {
    let task = db.coding_task(user, id)?;
    let Some(KeptTask {
        task: found,
        steps: kept,
    }) = task
    else {
        Err(NotFound("task"))?
    };
    // Of each file, as it was before the first step that changed it and after the last.
    let mut whole: BTreeMap<String, Ends> = BTreeMap::new();
    let mut steps = Vec::new();
    for (changes, mut step) in kept {
        step.files = changes
            .iter()
            .map(|change| {
                file_change(
                    &change.path,
                    change.before.as_deref(),
                    change.after.as_deref(),
                )
            })
            .collect();
        if !step.undone {
            for change in changes {
                whole
                    .entry(change.path)
                    .and_modify(|(_, after)| after.clone_from(&change.after))
                    .or_insert((change.before, change.after));
            }
        }
        steps.push(step);
    }
    let files = whole
        .iter()
        .filter(|(_, (before, after))| before != after)
        .map(|(path, (before, after))| file_change(path, before.as_deref(), after.as_deref()))
        .collect();
    Ok(Task {
        id,
        chat_id: found.chat_id,
        chat_title: found.chat_title,
        message_id: found.message_id,
        goal: found.goal,
        folder: found.folder,
        crew: serde_json::from_str(&found.team)
            .context(Fail::said(Code::Internal, "the task's team cannot be read"))?,
        state: Progress::of(&found.state),
        planned: usize::try_from(found.planned).unwrap_or(0),
        verdict: verdict_of(found.verdict),
        error: found
            .error
            .and_then(|error| serde_json::from_str(&error).ok()),
        started_at: found.started_at,
        ended_at: found.ended_at,
        steps,
        files,
        ask,
    })
}

/// Puts the task's folder back to before the step `from` (before its first
/// step that changed files, where none is named): the files of that step and
/// of all after it that are not undone, the newest first. They count as
/// undone then. Not while the task runs. Blocks.
pub fn undo(db: &dyn Storage, user: i64, id: i64, from: Option<i64>) -> anyhow::Result<()> {
    let (folder, state) = task_row(db, user, id)?;
    ensure!(
        state != Progress::Running,
        Fail::said(Code::NotNow, "the task is still running; stop it first")
            .with("what", "task_running")
    );
    let steps = db.steps_to_undo(id, from)?;
    if let Some(from) = from {
        ensure!(
            steps.iter().any(|(step, _)| *step == from),
            NotFound("checkpoint")
        );
    }
    let folder = Path::new(&folder);
    for (step, changes) in &steps {
        for change in changes {
            crate::coding::snapshot::restore(folder, change)?;
        }
        db.step_undone(*step)?;
    }
    Ok(())
}

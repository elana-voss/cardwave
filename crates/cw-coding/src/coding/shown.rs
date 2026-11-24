//! What a task's step shows, as codes and fields the page words in its
//! language: who works (`Who`), what the step does or did (`StepWhat`), its
//! grey line (`StepDetail`), its checkpoint's name (`Checkpoint`) and its
//! output's lines (`StepLine`). cw-store keeps each as its JSON in its text column
//! of `coding_steps`, the output as a JSON list.

use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::tools::gave::Gave;

/// Who works a step.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(tag = "role", rename_all = "snake_case")]
#[ts(export)]
pub enum Who {
    #[default]
    Planner,
    /// Worker `number`, from 1.
    Worker {
        number: usize,
    },
    Auditor,
}

/// What a step does, or did once it ended.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(tag = "code", rename_all = "snake_case")]
#[ts(export)]
pub enum StepWhat {
    /// The planner plans the steps.
    #[default]
    Plan,
    /// The planner planned `steps` steps.
    Planned { steps: usize },
    /// A worker's step of the plan, in the planner's words.
    Work { step: String },
    /// A worker fixes what the auditor found.
    Fix,
    /// The auditor checks step `step` (from 1).
    CheckStep { step: usize },
    /// The auditor checks the steps and runs the tests.
    CheckAll,
    /// The auditor's verdict, with the tests' counts where tests ran.
    Verdict {
        passed: bool,
        tests_passed: Option<u32>,
        tests_total: Option<u32>,
    },
}

/// A tool a step calls, as its grey line tells it while it runs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum StepTool {
    ListFiles,
    ReadFile,
    WriteFile,
    RunCommand,
    InstallPackages,
    WebSearch,
    ReadWebPage,
}

/// A step's grey line.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(tag = "code", rename_all = "snake_case")]
#[ts(export)]
pub enum StepDetail {
    #[default]
    None,
    /// The planner's: opening it shows the plan.
    ShowPlan,
    /// What runs now: `tool` on `target` (a path, command, query or address; empty for the whole folder).
    Tool { tool: StepTool, target: String },
    /// What a worker's step changed: the lines added and removed and how many files.
    Changed {
        added: usize,
        removed: usize,
        files: usize,
    },
}

/// A step's checkpoint: the folder as it was before the step.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(tag = "code", rename_all = "snake_case")]
#[ts(export)]
pub enum Checkpoint {
    /// Before step `step` of the plan (from 1).
    BeforeStep { step: usize },
    /// Before the fix of what the auditor found.
    #[default]
    BeforeFix,
}

/// A line of a step's output, kept as its values for the page to word: the
/// model's own words, a tool's call with what it gave, or the plan.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[ts(export)]
pub enum StepLine {
    /// The model's words; `cut` where its reply reached the model's length limit.
    Words { text: String, cut: bool },
    /// A tool called on `target`, and what it gave, shortened for the output;
    /// `cut` where a command's output was cut.
    Called {
        tool: StepTool,
        target: String,
        gave: Gave,
        cut: bool,
    },
    /// The planner's steps, and the command of the tests (empty where none).
    Plan { steps: Vec<String>, tests: String },
}

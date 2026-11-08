//! The coding team's tasks over HTTP (`coding`): a task started in a chat
//! (this computer's account's alone, 403 for another), read, stopped, its
//! call that waits answered, and its folder put back to a checkpoint. The
//! newest five are the settings page's "Recent tasks".
//!
//! A task's roles take the models of the settings' team where it names them;
//! else the planner and the auditor the chat model, and the workers the
//! background model, or the chat model where there is none.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_chat::chats;
use cw_coding::coding::{self, Crew, Task, TaskLine, run};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_core::{Events, PageEvent};
use cw_library::settings::{self, Permissions, Team};
use cw_provider::{self as provider, Sampling};
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, User, owner_only};
use crate::AppState;

/// How many tasks the list of recent ones has.
const RECENT: usize = 5;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/chats/{id}/tasks", post(start))
        .route("/api/coding/tasks", get(recent))
        .route("/api/coding/tasks/{id}", get(show))
        .route("/api/coding/tasks/{id}/stop", post(stop))
        .route("/api/coding/tasks/{id}/answer", post(answer))
        .route("/api/coding/tasks/{id}/undo", post(undo))
}

/// A task to start.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct StartTask {
    pub goal: String,
    /// The folder on this computer the team works in.
    pub folder: String,
    /// The team; the settings' when left out.
    pub team: Option<Team>,
}

/// The user's answer to a task's call that waits.
#[derive(Deserialize, TS)]
#[ts(export)]
pub(crate) struct TaskAnswer {
    pub allow: bool,
}

/// Where to put a task's folder back to: before the step `step_id`, or
/// before its first checkpoint where it is left out ("Undo all").
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct Undo {
    pub(crate) step_id: Option<i64>,
}

async fn start(
    State(state): State<AppState>,
    User(user): User,
    Path(chat_id): Path<i64>,
    Json(new): Json<StartTask>,
) -> ApiResult<(StatusCode, Json<Task>)> {
    if user != state.local_user() {
        Err(owner_only("use its files"))?;
    }
    let goal = new.goal.trim().to_string();
    let folder = new.folder.trim().to_string();
    if goal.is_empty() {
        Err(Fail::new(Code::GoalMissing))?;
    }
    let data = state.data_dir.clone();
    // Held until the task is listed, so a restore neither swaps the data in between nor lets it begin later.
    let work = state.at_work(user)?;
    let (task, started) = state
        .run(move |db| {
            cw_library::settings::folder_checked(&folder, &data)?;
            let chat = provider::chat(db, user)?;
            // A background model at another provider is not the workers': the team is asked at the chat model's.
            let background = provider::background_beside(db, user, &chat)?;
            let settings = settings::get(db, user)?;
            // The team reads and writes the task's folder by Settings › Tools' Files.
            if !settings.tools.files {
                Err(Fail::new(Code::FilesToolOff))?;
            }
            let team = settings.coding;
            let chosen = new.team.unwrap_or(team.team);
            let (workers, audit) = team.shape(chosen);
            let crew = Crew {
                team: chosen,
                workers,
                audit,
                planner_model: team.planner_model.clone().unwrap_or(chat.model.clone()),
                worker_model: team
                    .worker_model
                    .clone()
                    .or(background)
                    .unwrap_or(chat.model.clone()),
                auditor_model: team.auditor_model.clone().unwrap_or(chat.model.clone()),
                permissions: Permissions::of(&settings.tools),
            };
            let id = coding::start(db, &chats::Side(db), user, chat_id, &goal, &folder, &crew)?;
            // The roles' questions take the context size of the chats, and none of their other values.
            let sampling = Sampling {
                context_size: chat.sampling.context_size,
                ..Sampling::default()
            };
            let provider = provider::Provider { sampling, ..chat };
            let started = run::Started {
                user,
                id,
                chat_id,
                goal,
                folder: folder.into(),
                crew,
                provider,
            };
            Ok((coding::get(db, user, id, None)?, started))
        })
        .await?;
    run::spawn(state.actions(), started);
    drop(work);
    state.push(
        user,
        &PageEvent::CodingTask {
            id: task.id,
            chat_id,
        },
    );
    Ok((StatusCode::CREATED, Json(task)))
}

async fn recent(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Vec<TaskLine>>> {
    state
        .run(move |db| coding::list(db, user, None, RECENT))
        .await
        .map(Json)
}

async fn show(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<Json<Task>> {
    let ask = run::asking(&state, user, id);
    state
        .run(move |db| coding::get(db, user, id, ask))
        .await
        .map(Json)
}

async fn stop(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
) -> ApiResult<StatusCode> {
    if !run::stop(&state, user, id) {
        // A task that has ended is stopped already.
        state.run(move |db| coding::task_row(db, user, id)).await?;
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn answer(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(answer): Json<TaskAnswer>,
) -> ApiResult<StatusCode> {
    if !run::answer(&state, user, id, answer.allow) {
        Err(NotFound("question"))?;
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn undo(
    State(state): State<AppState>,
    User(user): User,
    Path(id): Path<i64>,
    Json(undo): Json<Undo>,
) -> ApiResult<Json<Task>> {
    let task = state
        .run(move |db| {
            coding::undo(db, user, id, undo.step_id)?;
            coding::get(db, user, id, None)
        })
        .await?;
    state.push(
        user,
        &PageEvent::CodingTask {
            id,
            chat_id: task.chat_id,
        },
    );
    Ok(Json(task))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/coding.rs"));

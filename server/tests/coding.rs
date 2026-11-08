//! The coding team (`coding`): a task planned, built and audited in a chat,
//! its checkpoints undone, a failed verdict fixed once, a call that asks, a
//! stop, the ready-made teams, who may start one, the folder's snapshot, and
//! the sandbox's reach for the team's commands.
//!
//! `Team` is a stand-in for the model's server that answers each role (by
//! its system prompt's first words) with the next of the test's answers for
//! it, the last again once they are used up, and notes what each was sent;
//! an answer starting with `!` is a refusal (400) with the rest as its body.

mod common;

use std::collections::HashMap;
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::http::{StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::post;
use axum::{Json, Router};
use common::Folder;
use common::server::{Server, WAIT, device, start};
use cw_coding::coding::snapshot::{FILE_LIMIT, Snapshot};
use cw_coding::tools::{REFUSED, sandbox};
use serde_json::{Value, json};
use tokio::net::TcpListener;

const ROLES: [(&str, &str); 3] = [
    ("You are the planner", "planner"),
    ("You are a worker", "worker"),
    ("You are the auditor", "auditor"),
];

struct Team {
    url: String,
    asked: Arc<Mutex<Vec<(String, Value)>>>,
}

impl Team {
    async fn start(answers: Vec<(&'static str, Vec<String>)>) -> Self {
        let answers: HashMap<&str, Vec<String>> = answers.into_iter().collect();
        let asked = Arc::new(Mutex::new(Vec::<(String, Value)>::new()));
        let log = asked.clone();
        let complete = move |Json(body): Json<Value>| async move {
            let system = body["messages"][0]["content"].as_str().unwrap_or_default();
            let role = ROLES
                .iter()
                .find(|(start, _)| system.starts_with(start))
                .map(|(_, role)| *role)
                .unwrap_or("other");
            let mut log = log.lock().unwrap();
            let count = log.iter().filter(|(asked, _)| asked == role).count();
            log.push((role.to_string(), body));
            let own = &answers[role];
            let text = own[count.min(own.len() - 1)].clone();
            if let Some(refusal) = text.strip_prefix('!') {
                return (StatusCode::BAD_REQUEST, refusal.to_string()).into_response();
            }
            ([(header::CONTENT_TYPE, "text/event-stream")], text).into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().route("/v1/chat/completions", post(complete));
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }

    /// What `role` was sent, in order.
    fn asked(&self, role: &str) -> Vec<Value> {
        let asked = self.asked.lock().unwrap();
        asked
            .iter()
            .filter(|(asked, _)| asked == role)
            .map(|(_, body)| body.clone())
            .collect()
    }
}

/// A stream that calls `name` with `arguments`.
fn calls(name: &str, arguments: Value) -> String {
    let piece = json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "id": "call_1", "type": "function", "function": { "name": name, "arguments": arguments.to_string() } }] } }] });
    format!("data: {piece}\n\ndata: [DONE]\n\n")
}

/// Switches on Settings › Tools for `folder`, which the team goes by: Files,
/// asking before a write where `ask_writes`, and Commands, asking first,
/// where the sandbox runs them.
async fn tools_on(server: &Server, folder: &Folder, ask_writes: bool) {
    let tools = json!({ "folder": folder.path(), "files": true, "ask_writes": ask_writes,
        "commands": sandbox::AVAILABLE, "ask_commands": true });
    let (status, body) = server
        .patch("/api/settings", json!({ "tools": tools }))
        .await;
    assert_eq!(status, 200, "{body}");
}

/// A server with the team's models and a chat with Mira: the chat's address.
async fn chat_at(server: &Server, team: &Team) -> String {
    let provider = json!({ "base_url": team.url, "model": "big-model", "worker_model": "small-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    format!("/api/chats/{}", view["chat"]["id"])
}

/// Starts a task in the chat and answers its address.
async fn start_task(server: &Server, chat: &str, folder: &Folder, team: Option<&str>) -> String {
    let mut new = json!({ "goal": "Add b.txt and shout a.txt", "folder": folder.path() });
    if let Some(team) = team {
        new["team"] = json!(team);
    }
    let (status, task) = server.post(&format!("{chat}/tasks"), new).await;
    assert_eq!(status, 201, "{task}");
    assert_eq!(task["state"], "running");
    format!("/api/coding/tasks/{}", task["id"])
}

/// The task once `done` says it is far enough.
async fn task_when(server: &Server, task: &str, done: impl Fn(&Value) -> bool) -> Value {
    let mut waited = Duration::ZERO;
    loop {
        let (_, now) = server.get(task).await;
        if done(&now) {
            return now;
        }
        assert!(waited < WAIT, "{now:#}");
        tokio::time::sleep(Duration::from_millis(50)).await;
        waited += Duration::from_millis(50);
    }
}

async fn ended(server: &Server, task: &str) -> Value {
    task_when(server, task, |task| task["state"] != "running").await
}

/// A step's `who` or `what`, its code and fields as one line: "worker 1", "planned 2".
fn words(coded: &Value) -> String {
    let fields = coded.as_object().unwrap();
    let tag = ["role", "code"].iter().filter_map(|tag| fields.get(*tag));
    let rest = fields
        .iter()
        .filter(|(name, _)| !["role", "code"].contains(&name.as_str()))
        .map(|(_, value)| value);
    tag.chain(rest)
        .filter(|value| !value.is_null())
        .map(|value| value.as_str().map_or(value.to_string(), str::to_string))
        .collect::<Vec<_>>()
        .join(" ")
}

fn whos(task: &Value) -> Vec<String> {
    task["steps"]
        .as_array()
        .unwrap()
        .iter()
        .map(|step| format!("{} · {}", words(&step["who"]), words(&step["what"])))
        .collect()
}

fn read(folder: &Folder, name: &str) -> Option<String> {
    std::fs::read_to_string(folder.0.join(name)).ok()
}

fn report(summary: &str) -> String {
    calls("report", json!({ "summary": summary }))
}

#[tokio::test]
async fn a_task_is_planned_built_audited_and_undone_by_its_checkpoints() {
    let server = start().await;
    let folder = Folder::new("task");
    std::fs::write(folder.0.join("a.txt"), "one\n").unwrap();
    let team = Team::start(vec![
        (
            "planner",
            vec![
                calls("read_file", json!({ "path": "a.txt" })),
                calls("plan", json!({ "steps": ["Write b.txt", "Shout a.txt"], "test_command": "type a.txt" })),
            ],
        ),
        (
            "worker",
            vec![
                calls("write_file", json!({ "path": "b.txt", "content": "two\n" })),
                report("Wrote b.txt."),
                calls("write_file", json!({ "path": "a.txt", "content": "ONE\n" })),
                report("Shouted a.txt."),
            ],
        ),
        (
            "auditor",
            // A count sent as text is read all the same.
            vec![calls("verdict", json!({ "passed": true, "tests_passed": "1", "tests_total": 1, "failures": [], "notes": "" }))],
        ),
    ])
    .await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    let task = start_task(&server, &chat, &folder, None).await;
    let done = ended(&server, &task).await;

    assert_eq!(done["state"], "done", "{done:#}");
    assert_eq!(
        whos(&done),
        [
            "planner · planned 2",
            "worker 1 · work Write b.txt",
            "worker 2 · work Shout a.txt",
            "auditor · verdict true 1 1"
        ]
    );
    assert_eq!(done["crew"]["team"], "balanced");
    assert_eq!(done["verdict"]["tests_total"], 1);
    assert_eq!(
        done["steps"][1]["detail"],
        json!({ "code": "changed", "added": 1, "removed": 0, "files": 1 })
    );
    assert_eq!(
        done["steps"][2]["checkpoint"],
        json!({"code": "before_step", "step": 2})
    );
    assert_eq!(done["steps"][0]["checkpoint"], Value::Null);
    let files: Vec<(&str, u64, u64)> = done["files"]
        .as_array()
        .unwrap()
        .iter()
        .map(|file| {
            (
                file["path"].as_str().unwrap(),
                file["added"].as_u64().unwrap(),
                file["removed"].as_u64().unwrap(),
            )
        })
        .collect();
    assert_eq!(files, [("a.txt", 1, 1), ("b.txt", 1, 0)]);
    assert!(done["files"][0]["diff"].as_str().unwrap().contains("+ONE"));
    // The planner and the auditor ask the chat model, the workers the background model.
    assert_eq!(team.asked("planner")[0]["model"], "big-model");
    assert_eq!(team.asked("worker")[0]["model"], "small-model");
    // The planner read the file; the auditor was given the changes themselves.
    let planner = team.asked("planner");
    assert_eq!(
        planner[1]["messages"].as_array().unwrap().last().unwrap()["content"],
        "one\n"
    );
    let audited = team.asked("auditor")[0]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(
        audited.contains("=== a.txt") && audited.contains("+ONE") && audited.contains("+two"),
        "{audited}"
    );
    assert!(
        audited.contains("Worker 2 (Shout a.txt): Shouted a.txt."),
        "{audited}"
    );
    // The card stands in the chat; the recent tasks list it.
    let (_, view) = server.get(&chat).await;
    let card = view["messages"].as_array().unwrap().last().unwrap().clone();
    assert_eq!(card["task_id"], done["id"]);
    assert_eq!(server.get("/api/coding/tasks").await.1[0]["id"], done["id"]);

    // Back to before step 2, then before all.
    let step = done["steps"][2]["id"].clone();
    let (status, undone) = server
        .post(&format!("{task}/undo"), json!({ "step_id": step }))
        .await;
    assert_eq!(status, 200, "{undone}");
    assert_eq!(read(&folder, "a.txt").as_deref(), Some("one\n"));
    assert_eq!(read(&folder, "b.txt").as_deref(), Some("two\n"));
    assert_eq!(undone["steps"][2]["undone"], true);
    assert_eq!(undone["files"].as_array().unwrap().len(), 1);
    let (status, _) = server.post(&format!("{task}/undo"), json!({})).await;
    assert_eq!(status, 200);
    assert_eq!(read(&folder, "b.txt"), None);
    assert_eq!(server.get(&task).await.1["files"], json!([]));
}

#[tokio::test]
async fn a_step_that_changed_no_line_says_only_its_files() {
    let server = start().await;
    let folder = Folder::new("empty");
    let team = Team::start(vec![
        ("planner", vec![calls("plan", json!({ "steps": ["Make an empty file"], "test_command": "" }))]),
        ("worker", vec![calls("write_file", json!({ "path": "empty.txt", "content": "" })), report("Made it.")]),
        ("auditor", vec![calls("verdict", json!({ "passed": true, "tests_passed": 0, "tests_total": 0, "failures": [], "notes": "" }))]),
    ])
    .await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    let task = start_task(&server, &chat, &folder, None).await;
    let done = ended(&server, &task).await;
    assert_eq!(
        done["steps"][1]["detail"],
        json!({ "code": "changed", "added": 0, "removed": 0, "files": 1 }),
        "{done:#}"
    );
}

#[tokio::test]
async fn a_failed_verdict_is_fixed_once_and_checked_again() {
    let server = start().await;
    let folder = Folder::new("fix");
    let team = Team::start(vec![
        ("planner", vec![calls("plan", json!({ "steps": ["Write c.txt"], "test_command": "" }))]),
        (
            "worker",
            vec![
                calls("write_file", json!({ "path": "c.txt", "content": "wrong" })),
                report("Wrote c.txt."),
                calls("write_file", json!({ "path": "c.txt", "content": "right" })),
                // Words alone end a worker's step.
                "data: {\"choices\":[{\"delta\":{\"content\":\"Fixed it.\"}}]}\n\ndata: [DONE]\n\n".to_string(),
            ],
        ),
        (
            "auditor",
            vec![
                calls("verdict", json!({ "passed": false, "failures": [{ "name": "c.txt", "output": "says wrong" }], "notes": "c.txt must say right" })),
                calls("verdict", json!({ "passed": true, "notes": "" })),
            ],
        ),
        // The small question that turns thinking off.
        ("other", vec!["data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}

data: [DONE]

".to_string()]),
    ])
    .await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    // The chat model's thinking turned off, by the first form: the workers' model is another, and is sent none.
    let (status, all) = server
        .put("/api/kinds/chat/thinking", json!({ "on": false }))
        .await;
    assert_eq!(status, 200, "{all}");
    let task = start_task(&server, &chat, &folder, None).await;
    let done = ended(&server, &task).await;
    assert_eq!(team.asked("planner")[0]["reasoning_effort"], "none");
    assert_eq!(team.asked("worker")[0]["model"], "small-model");
    assert_eq!(team.asked("worker")[0].get("reasoning_effort"), None);
    assert_eq!(
        whos(&done),
        [
            "planner · planned 1",
            "worker 1 · work Write c.txt",
            "auditor · verdict false",
            "worker 1 · fix",
            "auditor · verdict true"
        ],
        "{done:#}"
    );
    assert_eq!(done["verdict"]["passed"], true);
    assert_eq!(
        done["steps"][3]["checkpoint"],
        json!({"code": "before_fix"})
    );
    let fixer = team.asked("worker")[2]["messages"][1]["content"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(
        fixer.contains("- c.txt\nsays wrong") && fixer.contains("c.txt must say right"),
        "{fixer}"
    );
    assert_eq!(read(&folder, "c.txt").as_deref(), Some("right"));
}

#[tokio::test]
async fn a_thorough_team_checks_each_step_and_keeps_a_step_left_failing() {
    let server = start().await;
    let folder = Folder::new("thorough");
    let words = "data: {\"choices\":[{\"delta\":{\"content\":\"Tried.\"}}]}\n\ndata: [DONE]\n\n";
    let failed = calls(
        "verdict",
        json!({ "passed": false, "notes": "e.txt is wrong" }),
    );
    let team = Team::start(vec![
        (
            "planner",
            vec![calls(
                "plan",
                json!({ "steps": ["Write e.txt", "Write f.txt"] }),
            )],
        ),
        (
            "worker",
            vec![
                calls("write_file", json!({ "path": "e.txt", "content": "bad" })),
                report("Wrote e.txt."),
                words.to_string(),
                calls("write_file", json!({ "path": "f.txt", "content": "good" })),
                report("Wrote f.txt."),
            ],
        ),
        (
            "auditor",
            vec![
                failed.clone(),
                failed,
                calls("verdict", json!({ "passed": true, "notes": "" })),
            ],
        ),
    ])
    .await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    // The background model moved to another provider: the workers ask the chat model, at the team's.
    let (_, added) = server
        .post(
            "/api/provider-list",
            json!({ "base_url": "https://elsewhere.example.test/v1" }),
        )
        .await;
    let pick = json!({ "provider_id": added["id"], "model": "far-model" });
    assert_eq!(server.put("/api/kinds/background", pick).await.0, 200);
    let task = start_task(&server, &chat, &folder, Some("thorough")).await;
    let done = ended(&server, &task).await;
    assert_eq!(team.asked("worker")[0]["model"], "big-model");
    assert_eq!(
        whos(&done),
        [
            "planner · planned 2",
            "worker 1 · work Write e.txt",
            "auditor · verdict false",
            "worker 1 · fix",
            "auditor · verdict false",
            "worker 2 · work Write f.txt",
            "auditor · verdict true"
        ],
        "{done:#}"
    );
    assert_eq!(done["verdict"]["passed"], false);
    assert_eq!(done["verdict"]["notes"], "e.txt is wrong");
}

#[tokio::test]
async fn a_call_that_asks_waits_for_the_user_and_a_stop_keeps_the_checkpoint() {
    let server = start().await;
    let folder = Folder::new("ask");
    let coding = server.get("/api/settings").await.1["coding"].clone();
    assert_eq!(coding["team"], "balanced");
    assert!(coding.get("permissions").is_none(), "{coding:#}");
    let write = |content: &str| calls("write_file", json!({ "path": "d.txt", "content": content }));
    let team = Team::start(vec![
        (
            "planner",
            vec![calls("plan", json!({ "steps": ["Write d.txt"] }))],
        ),
        (
            "worker",
            vec![
                write("no"),
                write("yes"),
                calls("run_command", json!({ "command": "dir" })),
            ],
        ),
        (
            "auditor",
            vec![calls("verdict", json!({ "passed": true, "notes": "" }))],
        ),
    ])
    .await;
    tools_on(&server, &folder, true).await;
    let chat = chat_at(&server, &team).await;
    let task = start_task(&server, &chat, &folder, Some("quick")).await;

    for allow in [false, true] {
        let asking = task_when(&server, &task, |task| !task["ask"].is_null()).await;
        if !allow {
            // One task at a time in a folder.
            let again = json!({ "goal": "Again", "folder": folder.path() });
            let (status, refused) = server.post(&format!("{chat}/tasks"), again).await;
            assert_eq!(status, 400, "{refused}");
        }
        assert_eq!(asking["ask"]["kind"], "write");
        assert_eq!(asking["ask"]["detail"], if allow { "yes" } else { "no" });
        let (status, _) = server
            .post(&format!("{task}/answer"), json!({ "allow": allow }))
            .await;
        assert_eq!(status, 204);
        task_when(&server, &task, |task| task["ask"] != asking["ask"]).await;
    }
    let refused = &team.asked("worker")[1]["messages"];
    assert_eq!(
        refused.as_array().unwrap().last().unwrap()["content"],
        REFUSED
    );
    // Never is not offered; Ask is.
    let offered: Vec<String> = team.asked("worker")[0]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| tool["function"]["name"].as_str().unwrap().to_string())
        .collect();
    assert!(!offered.contains(&"web_search".to_string()), "{offered:?}");
    assert!(offered.contains(&"write_file".to_string()));

    if sandbox::AVAILABLE {
        let asking = task_when(&server, &task, |task| !task["ask"].is_null()).await;
        assert_eq!(
            asking["ask"],
            json!({ "kind": "command", "what": "dir", "detail": "" })
        );
        assert_eq!(server.post(&format!("{task}/stop"), json!({})).await.0, 204);
        let stopped = ended(&server, &task).await;
        assert_eq!(stopped["state"], "stopped");
        assert_eq!(stopped["steps"][1]["state"], "stopped");
        assert_eq!(
            stopped["steps"][1]["checkpoint"],
            json!({"code": "before_step", "step": 1})
        );
        assert_eq!(server.post(&format!("{task}/undo"), json!({})).await.0, 200);
        assert_eq!(read(&folder, "d.txt"), None);
    }
    // The quick team has one worker and no auditor.
    let task = ended(&server, &task).await;
    assert_eq!(task["crew"]["workers"], 1);
    assert!(team.asked("auditor").is_empty());
}

#[tokio::test]
async fn a_provider_that_refuses_a_role_fails_the_task_with_its_refusal() {
    let server = start().await;
    let folder = Folder::new("refused");
    let team = Team::start(vec![("planner", vec!["!the key is wrong".into()])]).await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    let task = start_task(&server, &chat, &folder, None).await;
    let failed = ended(&server, &task).await;
    assert_eq!(failed["state"], "failed");
    let error = &failed["error"];
    assert_eq!(error["code"], "provider_refused", "{error}");
    assert_eq!(error["details"]["status"], 400, "{error}");
    assert!(
        error["details"]["reason"]
            .to_string()
            .contains("the key is wrong"),
        "{error}"
    );
}

#[tokio::test]
async fn a_task_is_this_computers_accounts_alone_in_a_folder_the_tools_may_use() {
    let server = start().await;
    let folder = Folder::new("whose");
    let team = Team::start(vec![(
        "planner",
        vec![calls("plan", json!({ "steps": [] }))],
    )])
    .await;
    tools_on(&server, &folder, false).await;
    let chat = chat_at(&server, &team).await;
    let new = |goal: &str, folder: String| json!({ "goal": goal, "folder": folder });
    let tasks = format!("{chat}/tasks");
    assert_eq!(server.post(&tasks, new(" ", folder.path())).await.0, 400);
    let data = server.dir.display().to_string();
    assert_eq!(server.post(&tasks, new("Go", data)).await.0, 400);
    // The team goes by Settings › Tools: without Files it has no way to the folder.
    let off = json!({ "tools": { "files": false, "commands": false } });
    assert_eq!(server.patch("/api/settings", off).await.0, 200);
    let (status, refused) = server.post(&tasks, new("Go", folder.path())).await;
    assert_eq!(status, 400);
    assert!(
        refused
            .to_string()
            .contains("switch on Files in Settings › Tools first"),
        "{refused}"
    );
    tools_on(&server, &folder, false).await;
    // A plan without steps fails the task.
    let (_, task) = server.post(&tasks, new("Go", folder.path())).await;
    let failed = ended(&server, &format!("/api/coding/tasks/{}", task["id"])).await;
    assert_eq!(failed["state"], "failed");
    assert_eq!(
        (
            &failed["error"]["code"],
            &failed["error"]["details"]["what"]
        ),
        (&json!("model_answer"), &json!("no_plan"))
    );

    let mut ada = device(&server, false).await;
    assert_eq!(ada.post(&tasks, new("Go", folder.path())).await.0, 403);
}

#[test]
fn a_snapshot_leaves_out_packages_builds_and_big_files() {
    let folder = Folder::new("snapshot");
    for (path, size) in [
        ("src/a.rs", 3),
        ("node_modules/x/index.js", 3),
        ("target/debug/b", 3),
        ("target/CACHEDIR.TAG", 3),
        ("venv/pyvenv.cfg", 3),
        ("venv/lib/c.py", 3),
        // A folder of that name without its marker is the project's own.
        ("src/target/d.rs", 3),
        ("big.bin", FILE_LIMIT as usize + 1),
    ] {
        let path = folder.0.join(path);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, vec![b'x'; size]).unwrap();
    }
    let before = Snapshot::read(&folder.0).unwrap();
    assert_eq!(
        before.0.keys().collect::<Vec<_>>(),
        ["src/a.rs", "src/target/d.rs"]
    );
    std::fs::write(folder.0.join("src/a.rs"), "y").unwrap();
    std::fs::write(folder.0.join("new.txt"), "z").unwrap();
    // A file another program holds locked is not read, and no change of it counted.
    #[cfg(windows)]
    let _locked = {
        use std::os::windows::fs::OpenOptionsExt;
        std::fs::OpenOptions::new()
            .read(true)
            .share_mode(0)
            .open(folder.0.join("src/target/d.rs"))
            .unwrap()
    };
    let after = Snapshot::read(&folder.0).unwrap();
    #[cfg(windows)]
    assert!(after.1.contains("src/target/d.rs"), "{:?}", after.1);
    let changes = before.changes(&after);
    let paths: Vec<&str> = changes.iter().map(|change| change.path.as_str()).collect();
    assert_eq!(paths, ["new.txt", "src/a.rs"]);
    assert_eq!(changes[0].before, None);
}

#[test]
fn a_teams_command_is_let_into_a_path_folder_only_where_it_holds_a_program() {
    let data = Folder::new("grant-data");
    let write = |file: std::path::PathBuf| {
        std::fs::create_dir_all(file.parent().unwrap()).unwrap();
        std::fs::write(file, "").unwrap();
    };
    let programs = Folder::new("grant-programs");
    write(programs.0.join("tool.exe"));
    let scripts = Folder::new("grant-scripts");
    write(scripts.0.join("tool.cmd"));
    let notes = Folder::new("grant-notes");
    write(notes.0.join("notes.txt"));
    write(notes.0.join("deeper/tool.exe"));
    write(data.0.join("tool.exe"));
    write(data.0.join("bin/tool.exe"));
    let holder = Folder::new("grant-holder");
    write(holder.0.join("tool.exe"));
    std::fs::create_dir_all(holder.0.join("data")).unwrap();
    assert!(sandbox::grantable(&programs.0, &data.0));
    assert!(sandbox::grantable(&scripts.0, &data.0));
    assert!(!sandbox::grantable(&notes.0, &data.0));
    assert!(!sandbox::grantable(&data.0, &data.0));
    assert!(!sandbox::grantable(&data.0.join("bin"), &data.0));
    assert!(!sandbox::grantable(&holder.0, &holder.0.join("data")));
    let root = programs.0.ancestors().last().unwrap();
    assert!(!sandbox::grantable(root, &data.0));
    if let Some(profile) = std::env::var_os("USERPROFILE") {
        assert!(!sandbox::grantable(std::path::Path::new(&profile), &data.0));
    }
}

#[cfg(windows)]
#[test]
fn a_teams_command_has_the_servers_programs_and_a_folder_of_its_own() {
    let folder = Folder::new("reach");
    let data = Folder::new("reach-data");
    let run = |reach| {
        let command = r#"echo %PATH%& echo [%APPDATA%]& echo kept>"%APPDATA%\kept.txt" && type "%APPDATA%\kept.txt""#;
        sandbox::run_with(
            &folder.0,
            command,
            Duration::from_secs(20),
            &AtomicBool::new(false),
            reach,
        )
        .unwrap()
    };
    let host = std::env::var("PATH").unwrap();
    let granted = |part: &&str| sandbox::grantable(std::path::Path::new(part), &data.0);
    let last = host.split(';').rfind(granted).unwrap().to_string();
    let reached = run(sandbox::Reach {
        network: false,
        programs: true,
        data: data.0.clone(),
    });
    assert!(reached.output.contains(&last), "{}", reached.output);
    assert!(reached.output.contains(r"\AC]"), "{}", reached.output);
    assert_eq!(reached.code, Some(0), "{}", reached.output);
    let bare = run(sandbox::Reach::default());
    assert!(!bare.output.contains(&last), "{}", bare.output);
    assert_ne!(bare.code, Some(0), "{}", bare.output);
}

#[cfg(windows)]
#[test]
fn a_teams_command_runs_node_and_npm_where_they_are_installed_and_reads_no_other_file() {
    let installed = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .any(|folder| folder.join("node.exe").is_file() && folder.join("npm.cmd").is_file());
    let folder = Folder::new("node");
    let other = Folder::new("node-other");
    let data = Folder::new("node-data");
    std::fs::write(other.0.join("secret.txt"), "kept").unwrap();
    let run = |command: &str| {
        let reach = sandbox::Reach {
            network: false,
            programs: true,
            data: data.0.clone(),
        };
        let time = Duration::from_secs(120);
        sandbox::run_with(&folder.0, command, time, &AtomicBool::new(false), reach).unwrap()
    };
    let secret = run(&format!(r#"type "{}\secret.txt""#, other.path()));
    assert!(!secret.output.contains("kept"), "{}", secret.output);
    if !installed {
        return;
    }
    let ran = run(r#"node -e "console.log(1)" && npm --version"#);
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    assert_eq!(ran.output.lines().next(), Some("1"), "{}", ran.output);
}

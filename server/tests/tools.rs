//! The tools the chat model calls (`tools.rs`): commands in the sandbox, a
//! folder's files, the web at a stand-in, a reply's rounds of calls, the
//! user's answer to a call that asks, and who may switch which on.
//!
//! `Model` (`common::model`) is a stand-in for a model's server.

mod common;

use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::time::Duration;

use common::Folder;
use common::api::{Api, says};
use common::model::{
    Model, PAUSE, call_pieces, chat_at, code_mode, names, next_event, stream, text_piece,
};
use common::server::{WAIT, device, start};
use cw_coding::tools::{REFUSED, files, sandbox, web::Web};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::timeout;

#[cfg(windows)]
#[test]
fn a_command_reaches_its_folder_and_no_other() {
    let inside = Folder::new("inside");
    let outside = Folder::new("outside");
    let secret = outside.0.join("secret.txt");
    std::fs::write(&secret, "the secret").unwrap();
    let time = Duration::from_secs(20);
    let run = |folder: &Folder, command: &str| {
        sandbox::run(&folder.0, command, time, &AtomicBool::new(false)).unwrap()
    };

    let ran = run(&inside, "echo made> made.txt && type made.txt");
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    assert_eq!(
        std::fs::read_to_string(inside.0.join("made.txt"))
            .unwrap()
            .trim(),
        "made"
    );

    let ran = run(&inside, &format!("type \"{}\"", secret.display()));
    assert!(!ran.output.contains("the secret"), "{}", ran.output);
    assert_ne!(ran.code, Some(0));

    let planted = outside.0.join("planted.txt");
    let ran = run(&inside, &format!("echo x> \"{}\"", planted.display()));
    assert!(!planted.exists(), "{}", ran.output);
    let ran = run(&inside, &format!("del \"{}\"", secret.display()));
    assert!(secret.exists(), "{}", ran.output);

    // A folder whose commands ran before is not reached from another.
    let made = inside.0.join("made.txt");
    let ran = run(&outside, &format!("type \"{}\"", made.display()));
    assert!(!ran.output.contains("made"), "{}", ran.output);
}

#[cfg(windows)]
#[test]
fn a_command_that_runs_too_long_is_ended() {
    let inside = Folder::new("long");
    // A loop of cmd.exe's own: PowerShell in the sandbox stopped at once on GitHub's runner ("Access to the
    // path … is denied"), so that the test saw it end by itself.
    let sleep = "for /l %i in (1,1,2147483647) do @rem";
    let began = std::time::Instant::now();
    let ran = sandbox::run(
        &inside.0,
        sleep,
        Duration::from_secs(2),
        &AtomicBool::new(false),
    )
    .unwrap();
    assert_eq!(ran.code, None, "{}", ran.output);
    assert!(began.elapsed() < Duration::from_secs(10));

    // And one whose reply is stopped, before its time.
    let stopped = Arc::new(AtomicBool::new(false));
    let stop = stopped.clone();
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_secs(1));
        stop.store(true, std::sync::atomic::Ordering::Relaxed);
    });
    let began = std::time::Instant::now();
    let ran = sandbox::run(&inside.0, sleep, Duration::from_secs(60), &stopped).unwrap();
    assert_eq!(ran.code, None, "{}", ran.output);
    assert!(began.elapsed() < Duration::from_secs(10));
}

#[test]
fn the_file_tools_reach_their_folder_and_no_other() {
    let inside = Folder::new("files");
    let outside = Folder::new("files-outside");
    std::fs::write(outside.0.join("secret.txt"), "the secret").unwrap();

    assert_eq!(
        files::write(&inside.0, "notes/today.txt", "hello").unwrap(),
        "Wrote 5 bytes to notes/today.txt."
    );
    assert_eq!(files::read(&inside.0, "notes/today.txt").unwrap(), "hello");
    assert_eq!(files::list(&inside.0, "").unwrap(), "notes/");
    assert_eq!(
        files::list(&inside.0, "notes").unwrap(),
        "today.txt (5 bytes)"
    );

    let away = "../cardwave-tools-".to_string()
        + &format!("{}-files-outside/secret.txt", std::process::id());
    let whole = outside.0.join("secret.txt").display().to_string();
    for path in [away.as_str(), whole.as_str()] {
        assert!(files::read(&inside.0, path).is_err(), "{path}");
        assert!(files::write(&inside.0, path, "x").is_err(), "{path}");
    }
    assert!(files::list(&inside.0, "..").is_err());

    // A junction inside the folder that leads out of it leads nowhere.
    #[cfg(windows)]
    {
        let made = std::process::Command::new("cmd")
            .args(["/c", "mklink", "/J"])
            .arg(inside.0.join("door"))
            .arg(&outside.0)
            .output()
            .unwrap();
        assert!(made.status.success());
        assert!(files::read(&inside.0, "door/secret.txt").is_err());
        assert!(files::write(&inside.0, "door/planted.txt", "x").is_err());
        assert!(!outside.0.join("planted.txt").exists());
        // Nor a link to a file that is not there yet, which Windows makes
        // only in its developer mode (or for an administrator).
        let later = outside.0.join("later.txt");
        if std::os::windows::fs::symlink_file(&later, inside.0.join("nowhere.txt")).is_ok() {
            assert!(files::write(&inside.0, "nowhere.txt", "x").is_err());
            assert!(!later.exists());
        }
    }
    assert_eq!(
        std::fs::read_to_string(outside.0.join("secret.txt")).unwrap(),
        "the secret"
    );
}

/// DuckDuckGo's page without scripts, as it answers a search, cut short.
const RESULTS: &str = r#"<html><head><style>td { color: red }</style></head><body><table>
<tr><td>1.&nbsp;</td><td>
  <a rel="nofollow" href="https://tokio.rs/" class='result-link'>Tokio - An asynchronous <b>Rust</b> runtime</a>
</td></tr>
<tr><td>&nbsp;&nbsp;&nbsp;</td><td class='result-snippet'>
  <b>Tokio</b> is a runtime for writing reliable asynchronous applications with <b>Rust</b>.
</td></tr>
<tr><td>2.&nbsp;</td><td>
  <a rel="nofollow" href="https://docs.rs/tokio/latest/tokio/" class='result-link'>tokio - Rust &amp; Docs.rs</a>
</td></tr>
<tr><td>&nbsp;&nbsp;&nbsp;</td><td class='result-snippet'>
  An event-driven, non-blocking I/O platform.
</td></tr>
<tr><td>3.&nbsp;</td><td>
  <a rel="nofollow" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1&amp;rut=abc" class='result-link'>Example</a>
</td></tr>
</table></body></html>"#;

#[tokio::test]
async fn the_web_is_searched_and_read() {
    let page = "<html><head><title>T</title><script>steal()</script></head><body><h1>Lamps</h1><p>Keep the light&#39;s wick <i>trimmed</i>.</p></body></html>";
    let web = Api::start_each(vec![
        says(200, "text/html", RESULTS),
        says(200, "text/html; charset=utf-8", page),
    ])
    .await;
    let tool = Web::new(Some(web.url.clone())).unwrap();

    let found = tool.search("rust tokio").await.unwrap();
    assert_eq!(
        found,
        "Tokio - An asynchronous Rust runtime\nhttps://tokio.rs/\nTokio is a runtime for writing reliable asynchronous applications with Rust.\n\n\
         tokio - Rust & Docs.rs\nhttps://docs.rs/tokio/latest/tokio/\nAn event-driven, non-blocking I/O platform.\n\n\
         Example\nhttps://example.com/a?b=1\n"
    );
    let text = tool.read("https://example.com/lamps?part=2").await.unwrap();
    assert_eq!(text, "Lamps\nKeep the light's wick trimmed.");

    let asked = web.asked();
    assert_eq!(
        (asked[0].method.as_str(), asked[0].path.as_str()),
        ("POST", "/v1/lite.duckduckgo.com/lite/")
    );
    assert_eq!(asked[0].body, "q=rust+tokio");
    assert_eq!(asked[1].path, "/v1/example.com/lamps?part=2");
}

#[tokio::test]
async fn the_web_tool_reads_nothing_on_this_computer() {
    let here = Api::start(says(200, "text/plain", "the app's own")).await;
    let port = here.url.trim_start_matches("http://127.0.0.1:");
    let tool = Web::new(None).unwrap();
    for address in [
        here.url.clone(),
        format!("http://localhost:{port}"),
        "http://[::1]/".to_string(),
        "http://192.168.1.1/".to_string(),
        "http://[64:ff9b::7f00:1]/".to_string(),
        "http://[2002:c0a8:101::1]/".to_string(),
        // 6to4 of an address on the internet, and IPv6 beyond what is given out for it (2000::/3).
        "http://[2002:808:808::1]/".to_string(),
        "http://[4000::1]/".to_string(),
    ] {
        let refused = tool.read(&address).await.unwrap_err().to_string();
        assert!(refused.contains("private network"), "{address}: {refused}");
    }
    assert!(here.asked().is_empty());
}

#[tokio::test]
async fn a_reply_calls_a_tool_and_answers_with_what_it_gave() {
    let server = start().await;
    let folder = Folder::new("reply");
    std::fs::write(folder.0.join("note.txt"), "Buy lamp oil.").unwrap();
    // Two calls, each in an event of its own and without its place, as some servers send them.
    let whole = |id: &str, name: &str, arguments: &str| json!({ "choices": [{ "delta": { "tool_calls": [{ "id": id, "type": "function", "function": { "name": name, "arguments": arguments } }] } }] });
    let model = Model::start(vec![
        (
            200,
            stream(&[
                whole("call_1", "read_file", r#"{"path":"note.txt"}"#),
                whole("call_2", "list_files", r#"{"path":""}"#),
            ]),
        ),
        (200, stream(&[text_piece("It says: buy lamp oil.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let tools = json!({ "tools": { "files": true, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let mut socket = server.listen().await;

    let (status, reply) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202, "{reply}");
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["type"], "reply_ended", "{ended}");
    assert_eq!(ended["message"]["content"], "It says: buy lamp oil.");

    let asked = model.asked();
    assert_eq!(asked.len(), 2);
    assert_eq!(
        names(&asked[0]["tools"]),
        ["list_files", "read_file", "write_file"]
    );
    let sent = asked[1]["messages"].as_array().unwrap();
    let [.., called, read, listed] = sent.as_slice() else {
        panic!("{sent:?}")
    };
    assert_eq!(
        called["tool_calls"][0]["function"]["arguments"],
        r#"{"path":"note.txt"}"#
    );
    assert_eq!(
        read,
        &json!({ "role": "tool", "tool_call_id": "call_1", "content": "Buy lamp oil." })
    );
    assert_eq!(
        listed,
        &json!({ "role": "tool", "tool_call_id": "call_2", "content": "note.txt (13 bytes)" })
    );
}

#[tokio::test]
async fn a_file_is_written_only_once_the_user_allows_it() {
    let server = start().await;
    let folder = Folder::new("ask");
    let write = call_pieces(
        "write_file",
        &json!({ "path": "plan.txt", "content": "Sail at dawn." }),
    );
    // Words before the call, in two pieces: the second comes before the first is pushed.
    let mut rest = vec![text_piece("write it.")];
    rest.extend(write.clone());
    let first = format!(
        "data: {}\n\n{PAUSE}{}",
        text_piece("Let me "),
        stream(&rest)
    );
    let model = Model::start(vec![
        (200, first),
        (200, stream(&[text_piece("Not written.")])),
        (200, stream(&write)),
        (200, stream(&[text_piece("Written.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let tools = json!({ "tools": { "files": true, "folder": folder.path() } });
    assert_eq!(
        server.patch("/api/settings", tools).await.1["tools"]["ask_writes"],
        true
    );
    let mut socket = server.listen().await;

    for allow in [false, true] {
        assert_eq!(
            server.post(&format!("{chat}/generate"), json!({})).await.0,
            202
        );
        let asks = next_event(&mut socket).await;
        let ask = json!({ "kind": "write", "what": "plan.txt", "detail": "Sail at dawn." });
        assert_eq!(
            (&asks["type"], &asks["ask"]),
            (&json!("tool_asks"), &ask),
            "{asks}"
        );
        // A page that opens the chat meanwhile is asked too, under all the words before.
        let (_, view) = server.get(&chat).await;
        assert_eq!(view["asking"], ask);
        if !allow {
            let words = view["messages"].as_array().unwrap().last().unwrap()["content"].clone();
            assert_eq!(words, "Let me write it.");
        }
        assert!(!folder.0.join("plan.txt").exists());

        let answered = server
            .post(&format!("{chat}/answer"), json!({ "allow": allow }))
            .await;
        assert_eq!(answered.0, 204);
        assert_eq!(next_event(&mut socket).await["ask"], Value::Null);
        let ended = next_event(&mut socket).await;
        assert_eq!(ended["type"], "reply_ended", "{ended}");
        assert_eq!(folder.0.join("plan.txt").exists(), allow);
    }
    let asked = model.asked();
    assert_eq!(
        asked[1]["messages"].as_array().unwrap().last().unwrap()["content"],
        REFUSED
    );
    assert_eq!(
        std::fs::read_to_string(folder.0.join("plan.txt")).unwrap(),
        "Sail at dawn."
    );
    assert_eq!(
        server
            .post(&format!("{chat}/answer"), json!({ "allow": true }))
            .await
            .0,
        404
    );
}

#[tokio::test]
async fn a_write_allowed_for_the_chat_is_not_asked_about_again_in_it() {
    let server = start().await;
    let folder = Folder::new("for-chat");
    let write = |content: &str| {
        call_pieces(
            "write_file",
            &json!({ "path": "plan.txt", "content": content }),
        )
    };
    let model = Model::start(vec![
        (200, stream(&write("Sail at dawn."))),
        (200, stream(&[text_piece("Written.")])),
        (200, stream(&write("Sail at noon."))),
        (200, stream(&[text_piece("Written again.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let tools = json!({ "tools": { "files": true, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(next_event(&mut socket).await["type"], "tool_asks");
    let answer = json!({ "allow": true, "for_chat": true });
    assert_eq!(server.post(&format!("{chat}/answer"), answer).await.0, 204);
    assert_eq!(next_event(&mut socket).await["ask"], Value::Null);
    assert_eq!(next_event(&mut socket).await["type"], "reply_ended");

    // The next write of this chat runs without a question.
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(next_event(&mut socket).await["type"], "reply_ended");
    assert_eq!(
        std::fs::read_to_string(folder.0.join("plan.txt")).unwrap(),
        "Sail at noon."
    );
}

#[tokio::test]
async fn the_dice_are_rolled_on_the_server_once_switched_on() {
    let server = start().await;
    let model = Model::start(vec![
        (200, stream(&[text_piece("No dice.")])),
        (
            200,
            stream(&call_pieces("dice", &json!({ "count": 2, "sides": 10 }))),
        ),
        (200, stream(&[text_piece("The dice roll.")])),
    ])
    .await;
    // No tool is switched on in the settings: the dice are off until switched on (the owner, 2026-10-23).
    let chat = chat_at(&server, &model).await;
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "No dice.", "{ended}");
    assert!(model.asked()[0].get("tools").is_none());

    let on = server
        .patch("/api/settings", json!({ "tools": { "dice": true } }))
        .await;
    assert_eq!(on.1["tools"]["dice"], true, "{on:?}");
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "The dice roll.", "{ended}");
    let asked = &model.asked()[1..];
    assert_eq!(names(&asked[0]["tools"]), ["dice"]);
    let rolled = asked[1]["messages"].as_array().unwrap().last().unwrap();
    assert_eq!(rolled["tool_call_id"], "call_1");
    // "2d10: 7 + 3 = 10": each die from 1 to 10, and their sum.
    let said = rolled["content"].as_str().unwrap();
    let (dice, total) = said
        .strip_prefix("2d10: ")
        .and_then(|rest| rest.split_once(" = "))
        .unwrap_or_else(|| panic!("{said}"));
    let dice: Vec<u32> = dice.split(" + ").map(|die| die.parse().unwrap()).collect();
    assert_eq!(dice.len(), 2, "{said}");
    assert!(dice.iter().all(|die| (1..=10).contains(die)), "{said}");
    assert_eq!(total.parse::<u32>().unwrap(), dice.iter().sum::<u32>());
}

#[tokio::test]
async fn a_model_that_takes_no_tools_is_asked_without_them() {
    let server = start().await;
    let model = Model::start(vec![
        (
            400,
            json!({ "error": { "message": "tools are not supported" } }).to_string(),
        ),
        (200, stream(&[text_piece("Hello.")])),
        (200, stream(&[text_piece("Hello again.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    code_mode(&server, &chat, true).await;
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "Hello.", "{ended}");
    // Code mode alone offers the model its own tools.
    let asked = model.asked();
    assert_eq!(names(&asked[0]["tools"]), ["make_tool"]);
    assert!(asked[1].get("tools").is_none());

    // The next reply asks it without tools at once.
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "Hello again.", "{ended}");
    let asked = model.asked();
    assert_eq!(asked.len(), 3);
    assert!(asked[2].get("tools").is_none());
}

#[tokio::test]
async fn a_picture_the_model_makes_comes_after_its_reply() {
    let images = Api::start(says(
        200,
        "application/json",
        &json!({ "data": [{ "b64_json": base64_picture() }] }).to_string(),
    ))
    .await;
    let server = start().await;
    let model = Model::start(vec![
        (
            200,
            stream(&call_pieces(
                "make_picture",
                &json!({ "description": "a lighthouse at night" }),
            )),
        ),
        (200, stream(&[text_piece("Here it is.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let own = json!({ "base_url": images.url, "api_key": "sk-img", "model": "gpt-image-1" });
    assert_eq!(server.set_images(own).await.0, 200);
    assert_eq!(
        server
            .patch("/api/settings", json!({ "tools": { "pictures": true } }))
            .await
            .0,
        200
    );
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    // The chat is to be read anew, as a picture came after the reply.
    assert_eq!(
        (&ended["type"], &ended["message"]),
        (&json!("reply_ended"), &Value::Null),
        "{ended}"
    );
    let (_, view) = server.get(&chat).await;
    let messages = view["messages"].as_array().unwrap();
    let [.., reply, picture] = messages.as_slice() else {
        panic!("{messages:?}")
    };
    assert_eq!(reply["content"], "Here it is.");
    assert_eq!(picture["picture"], true);
    assert_eq!(
        picture["content"],
        "*(sends a picture: a lighthouse at night)*"
    );
}

fn base64_picture() -> String {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.encode(common::picture())
}

#[tokio::test]
async fn files_need_a_folder_and_are_this_computers_accounts_alone() {
    let server = start().await;
    let folder = Folder::new("whose");
    let on = |tools: Value| json!({ "tools": tools });

    let (status, refused) = server
        .patch("/api/settings", on(json!({ "files": true })))
        .await;
    assert_eq!(status, 400, "{refused}");
    let gone = format!("{}-gone", folder.path());
    let (status, _) = server
        .patch("/api/settings", on(json!({ "folder": gone })))
        .await;
    assert_eq!(status, 400);
    // Not Cardwave's own data, a folder in it or that holds it, or a drive's root.
    let root = server.dir.ancestors().last().unwrap().to_path_buf();
    let inside = server.dir.join("inside");
    std::fs::create_dir_all(&inside).unwrap();
    for kept in [
        server.dir.clone(),
        server.dir.parent().unwrap().to_path_buf(),
        root,
        inside,
    ] {
        let folder = json!({ "folder": kept.display().to_string() });
        let (status, refused) = server.patch("/api/settings", on(folder)).await;
        assert_eq!(status, 400, "{kept:?}: {refused}");
    }
    let both =
        on(json!({ "files": true, "commands": true, "folder": format!("  {} ", folder.path()) }));
    let (status, settings) = server.patch("/api/settings", both).await;
    assert_eq!(status, 200, "{settings}");
    assert_eq!(settings["tools"]["folder"], folder.path());

    // Another account, switched to on this computer, has the web and pictures alone.
    let mut ada = device(&server, false).await;
    let mut as_ada = async |tools: Value| {
        ada.call(Method::PATCH, "/api/settings", Some(on(tools)))
            .await
            .0
    };
    assert_eq!(
        as_ada(json!({ "files": true, "folder": folder.path() })).await,
        403
    );
    assert_eq!(as_ada(json!({ "commands": false })).await, 403);
    let web = timeout(WAIT, as_ada(json!({ "web": true }))).await.unwrap();
    assert_eq!(web, 200);
}

/// A reply keeps the pages and files it read, each once, for its "Used in this reply".
#[tokio::test]
async fn a_reply_keeps_the_pages_and_files_it_read() {
    let page = "<html><head><title> Lamp  oil &amp; wicks </title></head><body>Oil.</body></html>";
    let web = Api::start_each(vec![says(200, "text/html", page)]).await;
    let server = common::server::start_asking(Some(web.url.clone())).await;
    let folder = Folder::new("reads");
    std::fs::write(folder.0.join("note.txt"), "Buy lamp oil.").unwrap();
    let whole = |id: &str, name: &str, arguments: &str| json!({ "choices": [{ "delta": { "tool_calls": [{ "id": id, "type": "function", "function": { "name": name, "arguments": arguments } }] } }] });
    let model = Model::start(vec![
        (
            200,
            stream(&[
                whole("call_1", "read_file", r#"{"path":"note.txt"}"#),
                whole(
                    "call_2",
                    "read_web_page",
                    r#"{"url":"https://example.com/oil"}"#,
                ),
                whole("call_3", "read_file", r#"{"path":"note.txt"}"#),
                whole(
                    "call_5",
                    "read_web_page",
                    r#"{"url":"HTTPS://Example.com/oil"}"#,
                ),
                whole("call_4", "read_file", r#"{"path":"missing.txt"}"#),
            ]),
        ),
        (200, stream(&[text_piece("Lamp oil it is.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let tools = json!({ "tools": { "files": true, "web": true, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let mut socket = server.listen().await;

    let (status, reply) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202, "{reply}");
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["type"], "reply_ended", "{ended}");
    // A file that could not be read is not among them, and a page however its address is spelled is there once.
    let read = json!([
        { "kind": "file", "path": "note.txt" },
        { "kind": "web", "title": "Lamp oil & wicks", "address": "https://example.com/oil" },
    ]);
    assert_eq!(ended["message"]["reads"], read);
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        view["messages"].as_array().unwrap().last().unwrap()["reads"],
        read
    );
}

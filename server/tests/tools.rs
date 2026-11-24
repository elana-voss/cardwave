//! The tools the chat model calls (`tools.rs`): commands in the sandbox (on
//! Linux in `sandbox_linux.rs`), a
//! folder's files, the web at a stand-in, a reply's rounds of calls, the
//! user's answer to a call that asks, who may switch which on. The chat
//! tools (the dice, names) are in `chat_tools.rs`.
//!
//! `Model` (`common::model`) is a stand-in for a model's server.

mod common;

#[cfg(windows)]
use std::sync::Arc;
#[cfg(windows)]
use std::sync::atomic::AtomicBool;
#[cfg(windows)]
use std::time::Duration;

use common::Folder;
use common::api::{Api, says};
use common::model::{
    Model, PAUSE, call_pieces, chat_at, code_mode, names, next_event, stream, text_piece,
};
use common::server::{Server, Socket, WAIT, device, start};
use cw_coding::tools::{REFUSED, files, web::Web};
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
        cw_sandbox::run(&folder.0, command, time, &AtomicBool::new(false)).unwrap()
    };

    let ran = run(&inside, "echo made> made.txt && type made.txt");
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    assert_eq!(
        std::fs::read_to_string(inside.0.join("made.txt"))
            .unwrap()
            .trim(),
        "made"
    );
    // `dir` reads the drive, which the sandbox refuses: the model is told how to list the folder.
    let ran = run(&inside, "dir /b");
    assert!(ran.drive_refused, "{}", ran.output);
    assert!(cw_sandbox::DRIVE_REFUSED.contains(cw_sandbox::LISTING));
    let ran = run(&inside, cw_sandbox::LISTING);
    assert_eq!(
        (ran.code, ran.output.trim()),
        (Some(0), "made.txt"),
        "{}",
        ran.output
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
    let ran = cw_sandbox::run(
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
    let ran = cw_sandbox::run(&inside.0, sleep, Duration::from_secs(60), &stopped).unwrap();
    assert_eq!(ran.code, None, "{}", ran.output);
    assert!(began.elapsed() < Duration::from_secs(10));
}

#[test]
fn the_file_tools_reach_their_folder_and_no_other() {
    let inside = Folder::new("files");
    let outside = Folder::new("files-outside");
    std::fs::write(outside.0.join("secret.txt"), "the secret").unwrap();

    assert_eq!(
        files::write(&inside.0, "notes/today.txt", "hello")
            .unwrap()
            .for_model(),
        "Wrote 5 bytes to notes/today.txt."
    );
    assert_eq!(
        files::read(&inside.0, "notes/today.txt")
            .unwrap()
            .for_model(),
        "hello"
    );
    assert_eq!(files::list(&inside.0, "").unwrap().for_model(), "notes/");
    assert_eq!(
        files::list(&inside.0, "notes").unwrap().for_model(),
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
    // The same on Linux: a link to a folder outside, and one to a file not there yet.
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(&outside.0, inside.0.join("door")).unwrap();
        assert!(files::read(&inside.0, "door/secret.txt").is_err());
        assert!(files::write(&inside.0, "door/planted.txt", "x").is_err());
        assert!(!outside.0.join("planted.txt").exists());
        let later = outside.0.join("later.txt");
        std::os::unix::fs::symlink(&later, inside.0.join("nowhere.txt")).unwrap();
        assert!(files::write(&inside.0, "nowhere.txt", "x").is_err());
        assert!(!later.exists());
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

    let found = tool.search("rust tokio").await.unwrap().for_model();
    assert_eq!(
        found,
        "Tokio - An asynchronous Rust runtime\nhttps://tokio.rs/\nTokio is a runtime for writing reliable asynchronous applications with Rust.\n\n\
         tokio - Rust & Docs.rs\nhttps://docs.rs/tokio/latest/tokio/\nAn event-driven, non-blocking I/O platform.\n\n\
         Example\nhttps://example.com/a?b=1\n"
    );
    let text = tool
        .read("https://example.com/lamps?part=2")
        .await
        .unwrap()
        .for_model();
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
async fn a_last_round_cut_off_before_its_first_word_leaves_the_words_before_whole() {
    let server = start().await;
    let folder = Folder::new("cut-after-call");
    std::fs::write(folder.0.join("note.txt"), "Buy lamp oil.").unwrap();
    // The words of the first round ended with its call; the round after is cut off before any.
    let words = "Here it is, the note you asked me to read. I will read the rest of it to you now";
    let mut first = vec![text_piece(words)];
    first.extend(call_pieces("read_file", &json!({ "path": "note.txt" })));
    let cut = json!({ "choices": [{ "delta": {}, "finish_reason": "length" }] });
    let model = Model::start(vec![(200, stream(&first)), (200, stream(&[cut]))]).await;
    let chat = chat_at(&server, &model).await;
    let tools = json!({ "tools": { "files": true, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let mut socket = server.listen().await;

    let (status, reply) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202, "{reply}");
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["type"], "reply_ended", "{ended}");
    assert_eq!(ended["message"]["content"], words);
}

#[tokio::test]
async fn a_call_whose_arguments_are_not_json_is_not_run_and_the_model_is_told() {
    let server = start().await;
    let folder = Folder::new("cut-arguments");
    // Cut short by the provider: a write the user would otherwise be asked about.
    let cut = json!({ "choices": [{ "delta": { "tool_calls": [{ "index": 0, "id": "call_1", "type": "function", "function": { "name": "write_file", "arguments": r#"{"path":"plan.txt","content":"Sail"# } }] } }] });
    let model = Model::start(vec![
        (200, stream(&[cut])),
        (200, stream(&[text_piece("Trying again.")])),
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
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["type"], "reply_ended", "{ended}");
    let asked = model.asked();
    let told = &asked[1]["messages"].as_array().unwrap().last().unwrap()["content"];
    assert!(told.as_str().unwrap().contains("not valid JSON"), "{told}");
    assert_eq!(std::fs::read_dir(&folder.0).unwrap().count(), 0);
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
    let both = on(
        json!({ "files": true, "commands": cfg!(windows), "folder": format!("  {} ", folder.path()) }),
    );
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

/// Lets a reply run to its end: each call that asks is answered by `answer`, `None` being Stop.
async fn reply_ended(
    server: &Server,
    chat: &str,
    socket: &mut Socket,
    answer: impl Fn(&Value) -> Option<bool>,
) -> Value {
    loop {
        let event = next_event(socket).await;
        match event["type"].as_str().unwrap() {
            "reply_ended" => return event,
            // The same event with no question says the question is gone.
            "tool_asks" if !event["ask"].is_null() => {
                let (place, body) = match answer(&event["ask"]) {
                    Some(allow) => ("answer", json!({ "allow": allow })),
                    None => ("stop", json!({})),
                };
                let sent = server.post(&format!("{chat}/{place}"), body).await;
                assert_eq!(sent.0, 204, "{}", sent.1);
            }
            _ => {}
        }
    }
}

/// A reply keeps its tool calls for "Used in this reply": each in the order it
/// ran, its outcome told, nothing of what it carried but a short "what".
#[tokio::test]
async fn a_reply_keeps_its_tool_calls() {
    let page = "<html><head><title> Lamp  oil &amp; wicks </title></head><body>Oil.</body></html>";
    let web = Api::start_each(vec![says(200, "text/html", page)]).await;
    let server = common::server::start_asking(Some(web.url.clone())).await;
    let folder = Folder::new("calls");
    std::fs::write(folder.0.join("note.txt"), "Buy lamp oil.").unwrap();
    let whole = |id: &str, name: &str, arguments: &str| json!({ "choices": [{ "delta": { "tool_calls": [{ "id": id, "type": "function", "function": { "name": name, "arguments": arguments } }] } }] });
    let dice = r#"{"count":2,"sides":6}"#;
    let long = "a".repeat(200);
    let make = json!({
        "name": "lamp_tool",
        "description": "Reads the note.",
        "parameters": { "type": "object" },
        "code": "export default () => readFile('note.txt') /* CODE BODY */",
    });
    let model = Model::start(vec![
        (
            200,
            stream(&[
                whole("call_1", "dice", dice),
                whole("call_2", "dice", dice),
                whole("call_3", "read_file", r#"{"path":"note.txt"}"#),
                whole("call_4", "read_file", r#"{"path":"missing.txt"}"#),
                whole(
                    "call_5",
                    "read_web_page",
                    r#"{"url":"https://www.example.com/oil"}"#,
                ),
                whole("call_6", "no_such_tool", r#"{"key":"HIDDEN VALUE"}"#),
                whole("call_7", "read_file", r#"{"path":"#),
                whole("call_8", "read_file", &json!({ "path": long }).to_string()),
                whole(
                    "call_9",
                    "write_file",
                    r#"{"path":"plan.txt","content":"FILE BODY"}"#,
                ),
                whole("call_10", "make_tool", &make.to_string()),
            ]),
        ),
        (200, stream(&[whole("call_11", "lamp_tool", "{}")])),
        (200, stream(&[text_piece("Lamp oil it is.")])),
        // Continued.
        (
            200,
            stream(&[whole("call_12", "dice", r#"{"count":1,"sides":20}"#)]),
        ),
        (200, stream(&[text_piece(" And wicks.")])),
        // Another version.
        (
            200,
            stream(&[whole("call_13", "read_file", r#"{"path":"note.txt"}"#)]),
        ),
        (200, stream(&[text_piece("Oil.")])),
        // Stopped at a call that waits for the user.
        (
            200,
            stream(&[
                text_piece("Writing."),
                whole("call_14", "write_file", r#"{"path":"b.txt","content":"x"}"#),
            ]),
        ),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    code_mode(&server, &chat, true).await;
    let tools =
        json!({ "tools": { "files": true, "web": true, "dice": true, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    let mut socket = server.listen().await;
    let generate = format!("{chat}/generate");

    assert_eq!(server.post(&generate, json!({})).await.0, 202);
    let refuse_writes = |ask: &Value| Some(ask["kind"] != "write");
    let ended = reply_ended(&server, &chat, &mut socket, refuse_writes).await;
    let calls = ended["message"]["calls"].clone();
    let line =
        |tool: &str, what: &str, end: &str| json!({ "tool": tool, "what": what, "end": end });
    // A roll's dice are its own: the first two lines are checked by their form.
    let rolls: Vec<&str> = (0..2)
        .map(|at| calls[at]["what"].as_str().unwrap_or(""))
        .collect();
    assert!(
        rolls.iter().all(|what| what.starts_with("2d6: ")),
        "{calls}"
    );
    assert_eq!(calls[0]["tool"], "dice", "{calls}");
    assert_eq!(calls[1]["end"], "done", "{calls}");
    let cut = format!("{}…", "a".repeat(80));
    assert_eq!(
        calls.as_array().unwrap()[2..],
        [
            line("read_file", "note.txt", "done"),
            line("read_file", "missing.txt", "failed"),
            line("read_web_page", "Lamp oil & wicks · example.com", "done"),
            line("no_such_tool", "", "failed"),
            line("read_file", "", "failed"),
            line("read_file", &cut, "failed"),
            line("write_file", "plan.txt", "not_allowed"),
            line("make_tool", "lamp_tool", "done"),
            // Only the outer call of a tool the model wrote.
            line("lamp_tool", "", "done"),
        ]
    );
    let kept = calls.to_string();
    for secret in ["FILE BODY", "CODE BODY", "HIDDEN VALUE", "Buy lamp oil"] {
        assert!(!kept.contains(secret), "{kept}");
    }
    let last = |view: &Value| view["messages"].as_array().unwrap().last().unwrap().clone();
    assert_eq!(last(&server.get(&chat).await.1)["calls"], calls);

    // Continuing adds to the list.
    let more = json!({ "continue": true });
    assert_eq!(server.post(&generate, more).await.0, 202);
    let ended = reply_ended(&server, &chat, &mut socket, |_| Some(true)).await;
    let longer = ended["message"]["calls"].as_array().unwrap();
    assert_eq!(longer.len(), calls.as_array().unwrap().len() + 1);
    assert_eq!(longer[..longer.len() - 1], calls.as_array().unwrap()[..]);
    assert!(
        longer.last().unwrap()["what"]
            .as_str()
            .unwrap()
            .starts_with("1d20: ")
    );
    assert_eq!(
        last(&server.get(&chat).await.1)["calls"],
        ended["message"]["calls"]
    );

    // Another version has its own.
    let again = json!({ "regenerate": true });
    assert_eq!(server.post(&generate, again.clone()).await.0, 202);
    let ended = reply_ended(&server, &chat, &mut socket, |_| Some(true)).await;
    assert_eq!(
        ended["message"]["calls"],
        json!([line("read_file", "note.txt", "done")])
    );

    // A call Stop cuts is listed as stopped.
    assert_eq!(server.post(&generate, again).await.0, 202);
    let ended = reply_ended(&server, &chat, &mut socket, |_| None).await;
    assert_eq!(
        ended["message"]["calls"],
        json!([line("write_file", "b.txt", "stopped")]),
        "{ended}"
    );
    assert_eq!(
        last(&server.get(&chat).await.1)["calls"],
        ended["message"]["calls"]
    );
}

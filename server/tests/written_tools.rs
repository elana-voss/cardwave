//! The tools the chat model writes itself (`tools/written.rs`, Code mode's
//! `make_tool`): checked and run in QuickJS with nothing of the host, kept per
//! account, asked about before they are kept, and calling the host's tools.
//!
//! `Model` (`common::model`) is a stand-in for a model's server.

mod common;

use std::sync::{Arc, Mutex};
use std::time::Duration;

use common::Folder;
use common::model::{
    Model, call_pieces, chat_at, code_mode, names, next_event, stream, text_piece,
};
use common::server::start;
use cw_coding::tools::{REFUSED, written};
use reqwest::Method;
use serde_json::{Value, json};

#[test]
fn a_written_tool_runs_in_quickjs_with_nothing_of_the_host() {
    let make = |name: &str, parameters: Value, code: &str| {
        let arguments = json!({ "name": name, "description": "Counts words.", "parameters": parameters, "code": code });
        written::check(&arguments.to_string(), |name| name == "dice_roll")
    };
    let object = json!({ "type": "object", "properties": { "text": { "type": "string" } } });
    let count = r#"export default function word_count({ text }) { return text.trim().split(/\s+/).filter(Boolean).length; }"#;
    let tool = make("word_count", object.clone(), count).unwrap();
    assert_eq!(
        (tool.name.as_str(), &tool.parameters),
        ("word_count", &object)
    );
    // The schema may come as text.
    assert!(make("word_count", json!(object.to_string()), count).is_ok());
    let required = json!({ "type": "object", "properties": { "text": { "type": ["string", "null"] } }, "required": ["text"] });
    assert!(make("word_count", required, count).is_ok());
    let nested = json!({ "type": "object", "properties": { "places": { "type": "array", "items": { "type": "object", "properties": { "city": { "type": "string" } }, "required": ["city"] } } } });
    assert!(make("word_count", nested, count).is_ok());
    // What the model is told of it is kept short.
    let long = json!({ "name": "long_one", "description": "x".repeat(301), "parameters": object, "code": count });
    let refused = written::check(&long.to_string(), |_| false).unwrap_err();
    assert!(format!("{refused}").contains("description"), "{refused}");
    let wide = json!({ "type": "object", "description": "x".repeat(4000) });
    assert!(format!("{:#}", make("word_count", wide, count).unwrap_err()).contains("schema"));
    for (name, parameters, code, says) in [
        ("Word", &object, count, "lowercase"),
        ("read_file", &object, count, "exists already"),
        ("dice_roll", &object, count, "exists already"),
        ("word_count", &json!({ "type": "string" }), count, "schema"),
        // One bad tool would make every reply go without tools.
        (
            "word_count",
            &json!({ "type": "object", "properties": "text" }),
            count,
            "\"properties\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "text": "string" } }),
            count,
            "\"text\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "text": { "type": "text" } } }),
            count,
            "\"text\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "words": { "type": "array" } } }),
            count,
            "\"items\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "text": { "type": "string" } }, "required": ["words"] }),
            count,
            "\"required\"",
        ),
        // A schema inside another is checked as the outer one is.
        (
            "word_count",
            &json!({ "type": "object", "properties": { "words": { "type": "array", "items": { "type": "word" } } } }),
            count,
            "\"words[]\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "rows": { "type": "array", "items": { "type": "array" } } } }),
            count,
            "\"rows[]\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "place": { "type": "object", "properties": { "city": { "type": "town" } } } } }),
            count,
            "\"place.city\"",
        ),
        (
            "word_count",
            &json!({ "type": "object", "properties": { "place": { "type": "object", "properties": { "city": { "type": "string" } }, "required": ["street"] } } }),
            count,
            "\"required\" of \"place\"",
        ),
        (
            "word_count",
            &object,
            "export const x = 1;",
            "not a function",
        ),
        (
            "word_count",
            &object,
            "export default function (",
            "SyntaxError",
        ),
        (
            "word_count",
            &object,
            "import os from 'os'; export default () => 1;",
            "os",
        ),
    ] {
        let refused = make(name, parameters.clone(), code).unwrap_err();
        assert!(
            format!("{refused:#}").contains(says),
            "{name} {code}: {refused:#}"
        );
    }

    let none: written::Host = Arc::new(|_, _| Err("there is no such tool".into()));
    let run =
        |code: &str, arguments: Value| written::run(code, &arguments.to_string(), none.clone());
    assert_eq!(
        run(count, json!({ "text": " one two  three " })).unwrap(),
        "3"
    );
    assert_eq!(
        run("export default ({ a }) => 'got ' + a", json!({ "a": 1 })).unwrap(),
        "got 1"
    );
    assert_eq!(
        run("export default async () => ({ sum: 2 })", json!({})).unwrap(),
        r#"{"sum":2}"#
    );
    let host = "export default () => [typeof require, typeof fetch, typeof std, typeof os, typeof setTimeout].join()";
    assert_eq!(
        run(host, json!({})).unwrap(),
        "undefined,undefined,undefined,undefined,undefined"
    );
    let thrown = run(
        "export default () => { throw new Error('no dice'); }",
        json!({}),
    )
    .unwrap_err();
    assert!(format!("{thrown}").contains("no dice"), "{thrown}");
    let began = std::time::Instant::now();
    let endless = run("export default () => { for (;;) {} }", json!({})).unwrap_err();
    assert!(
        format!("{endless}").contains("longer than 5 s"),
        "{endless}"
    );
    assert!(began.elapsed() < Duration::from_secs(8));
    let greedy =
        "export default () => { const all = []; for (;;) all.push(new Array(1e6).fill(1)); }";
    assert!(run(greedy, json!({})).is_err());
}

#[test]
fn an_account_keeps_a_name_once_and_fifty_tools_at_most() {
    let scratch = common::Scratch::new();
    let tool = |name: &str| written::NewTool {
        name: name.into(),
        description: "Counts.".into(),
        parameters: json!({ "type": "object" }),
        code: "export default () => 1".into(),
    };
    let (db, user) = (&scratch.db, scratch.user);
    written::add(db, user, None, &tool("word_count")).unwrap();
    // As when another reply made it meanwhile.
    let twice = written::add(db, user, None, &tool("word_count")).unwrap_err();
    assert!(format!("{twice}").contains("exists already"), "{twice}");
    for n in 1..written::MOST_TOOLS {
        written::add(db, user, None, &tool(&format!("tool_{n}"))).unwrap();
    }
    let more = written::add(db, user, None, &tool("one_more")).unwrap_err();
    assert!(format!("{more}").contains("delete one first"), "{more}");
}

#[tokio::test]
async fn a_tool_that_loads_too_long_holds_up_nothing_else() {
    let server = start().await;
    let model = Model::start(vec![
        (
            200,
            stream(&make_pieces(
                "slow_one",
                "for (;;) {}\nexport default () => 1",
            )),
        ),
        (200, stream(&[text_piece("It did not load.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    code_mode(&server, &chat, true).await;
    let mut socket = server.listen().await;

    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    tokio::time::sleep(Duration::from_millis(500)).await;
    let began = std::time::Instant::now();
    assert_eq!(server.get("/api/settings").await.0, 200);
    assert!(
        began.elapsed() < Duration::from_secs(2),
        "{:?}",
        began.elapsed()
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "It did not load.", "{ended}");
    let told = model.asked()[1]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()["content"]
        .clone();
    assert!(told.as_str().unwrap().contains("longer than 5 s"), "{told}");
}

/// A call of `make_tool` for `name`, whose code returns `code`'s value.
fn make_pieces(name: &str, code: &str) -> Vec<Value> {
    let tool = json!({
        "name": name,
        "description": "Counts the words of a text.",
        "parameters": { "type": "object", "properties": { "text": { "type": "string" } } },
        "code": code,
    });
    call_pieces("make_tool", &tool)
}

#[tokio::test]
async fn a_tool_the_model_writes_is_asked_about_kept_and_called() {
    let server = start().await;
    let count = "export default function word_count({ text }) { return text.split(' ').length; }";
    let model = Model::start(vec![
        (200, stream(&make_pieces("word_count", count))),
        (
            200,
            stream(&call_pieces(
                "word_count",
                &json!({ "text": "one two three" }),
            )),
        ),
        (200, stream(&[text_piece("Three words.")])),
        (
            200,
            stream(&make_pieces("dice_roll", "export default () => 4")),
        ),
        (200, stream(&[text_piece("Not made.")])),
        (200, stream(&[text_piece("Without Code mode.")])),
        (200, stream(&[text_piece("Plain.")])),
        (
            200,
            stream(&make_pieces(
                "shout",
                "export default ({ text }) => text.toUpperCase()",
            )),
        ),
        (200, stream(&[text_piece("Made.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    // Code mode is the chat's switch, here beside the web.
    let tools = json!({ "tools": { "web": true } });
    assert_eq!(
        server.patch("/api/settings", tools).await.1["tools"]["ask_new_tools"],
        true
    );
    code_mode(&server, &chat, true).await;
    let mut socket = server.listen().await;
    let (asking, answering) = (format!("{chat}/generate"), format!("{chat}/answer"));
    let generate = || server.post(&asking, json!({}));

    // Made once the user allows it, then called in the same reply.
    assert_eq!(generate().await.0, 202);
    let asks = next_event(&mut socket).await;
    assert_eq!(
        asks["ask"],
        json!({ "kind": "new_tool", "what": "word_count", "detail": format!("// Counts the words of a text.\n{count}") }),
        "{asks}"
    );
    let allow = |allow: bool| server.post(&answering, json!({ "allow": allow }));
    assert_eq!(allow(true).await.0, 204);
    assert_eq!(next_event(&mut socket).await["ask"], Value::Null);
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "Three words.", "{ended}");
    let asked = model.asked();
    assert_eq!(
        names(&asked[0]["tools"]),
        ["web_search", "read_web_page", "make_tool"]
    );
    assert_eq!(
        names(&asked[1]["tools"]),
        ["web_search", "read_web_page", "make_tool", "word_count"]
    );
    let last = |n: usize| {
        model.asked()[n]["messages"]
            .as_array()
            .unwrap()
            .last()
            .unwrap()["content"]
            .clone()
    };
    assert_eq!(last(2), "3");
    let (_, list) = server.get("/api/tools/written").await;
    let chat_id = chat.rsplit('/').next().unwrap().parse::<i64>().unwrap();
    assert_eq!(
        (
            &list[0]["name"],
            &list[0]["code"],
            &list[0]["on"],
            &list[0]["uses"],
            &list[0]["chat_id"]
        ),
        (
            &json!("word_count"),
            &json!(count),
            &json!(true),
            &json!(1),
            &json!(chat_id)
        ),
        "{list}"
    );
    assert_eq!(list[0]["chat_title"], json!("Mira (storm night)"));

    // Refused, it is not kept.
    assert_eq!(generate().await.0, 202);
    assert_eq!(next_event(&mut socket).await["ask"]["what"], "dice_roll");
    assert_eq!(allow(false).await.0, 204);
    next_event(&mut socket).await;
    assert_eq!(
        next_event(&mut socket).await["message"]["content"],
        "Not made."
    );
    assert_eq!(last(4), REFUSED);
    assert_eq!(
        server
            .get("/api/tools/written")
            .await
            .1
            .as_array()
            .unwrap()
            .len(),
        1
    );

    // Without Code mode the chat makes no tool, and the one kept is offered still.
    code_mode(&server, &chat, false).await;
    assert_eq!(generate().await.0, 202);
    assert_eq!(
        next_event(&mut socket).await["message"]["content"],
        "Without Code mode."
    );
    assert_eq!(
        names(&model.asked()[5]["tools"]),
        ["web_search", "read_web_page", "word_count"]
    );
    code_mode(&server, &chat, true).await;

    // Switched off, it is not offered; deleted, it is gone until Undo.
    let tool = format!("/api/tools/written/{}", list[0]["id"]);
    let (status, off) = server.patch(&tool, json!({ "on": false })).await;
    assert_eq!((status, &off["on"]), (200, &json!(false)));
    // Each change of a written tool is told to the pages.
    let told = json!({ "type": "written_tools" });
    assert_eq!(next_event(&mut socket).await, told);
    assert_eq!(generate().await.0, 202);
    assert_eq!(
        next_event(&mut socket).await["message"]["content"],
        "Plain."
    );
    assert_eq!(
        names(&model.asked()[6]["tools"]),
        ["web_search", "read_web_page", "make_tool"]
    );
    assert_eq!(server.call(Method::DELETE, &tool, None).await.0, 204);
    assert_eq!(next_event(&mut socket).await, told);
    assert_eq!(server.get("/api/tools/written").await.1, json!([]));
    let (status, back) = server.post(&format!("{tool}/restore"), json!({})).await;
    assert_eq!((status, &back["name"]), (200, &json!("word_count")));
    assert_eq!(next_event(&mut socket).await, told);

    // Without "Ask before a new tool runs" it is made at once.
    let tools = json!({ "tools": { "ask_new_tools": false } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    assert_eq!(generate().await.0, 202);
    assert_eq!(next_event(&mut socket).await["message"]["content"], "Made.");
    assert_eq!(
        last(8),
        "Made the tool shout. Call it as shout from now on, in this reply and in later chats."
    );
    let (_, list) = server.get("/api/tools/written").await;
    assert_eq!(list[0]["name"], "shout");
}

#[test]
fn a_written_tool_calls_the_hosts_tools_and_their_time_is_not_its_own() {
    let asked = Arc::new(Mutex::new(Vec::new()));
    let log = asked.clone();
    let host: written::Host = Arc::new(move |name, arguments| {
        log.lock()
            .unwrap()
            .push((name.to_string(), arguments.clone()));
        match name {
            "run_command" => Err(REFUSED.to_string()),
            // Longer than a script may run: the host's time is not the script's.
            "make_picture" => {
                std::thread::sleep(Duration::from_millis(5_200));
                Ok("made".into())
            }
            _ => Ok(format!("{name} done")),
        }
    });
    let code = r#"export default () => {
        const said = [listFiles(), readFile('a.txt'), writeFile('b.txt', 'B'), searchWeb('lamps'), readWebPage('https://example.com/'), makePicture('a lamp')];
        try { runCommand('dir'); } catch (error) { said.push('threw ' + error.message); }
        return said.join('|');
    }"#;
    let result = written::run(code, "{}", host).unwrap();
    assert_eq!(
        result,
        format!(
            "list_files done|read_file done|write_file done|web_search done|read_web_page done|made|threw {REFUSED}"
        )
    );
    let asked = asked.lock().unwrap().clone();
    let expected = [
        ("list_files", json!({ "path": "" })),
        ("read_file", json!({ "path": "a.txt" })),
        ("write_file", json!({ "path": "b.txt", "content": "B" })),
        ("web_search", json!({ "query": "lamps" })),
        ("read_web_page", json!({ "url": "https://example.com/" })),
        ("make_picture", json!({ "description": "a lamp" })),
        ("run_command", json!({ "command": "dir" })),
    ];
    let expected: Vec<(String, Value)> = expected
        .into_iter()
        .map(|(name, arguments)| (name.to_string(), arguments))
        .collect();
    assert_eq!(asked, expected);
}

#[tokio::test]
async fn a_written_tool_works_in_the_folder_as_the_model_would_and_asks_alike() {
    let server = start().await;
    let folder = Folder::new("written-host");
    std::fs::write(folder.0.join("note.txt"), "Buy lamp oil.").unwrap();
    let code = "export default () => { writeFile('copy.txt', readFile('note.txt').toUpperCase()); return listFiles(''); }";
    let copy = |id: &str| json!({ "choices": [{ "delta": { "tool_calls": [{ "id": id, "type": "function", "function": { "name": "copy_note", "arguments": "{}" } }] } }] });
    let model = Model::start(vec![
        (200, stream(&make_pieces("copy_note", code))),
        (200, stream(&[copy("call_2")])),
        (200, stream(&[text_piece("Copied.")])),
        (200, stream(&[copy("call_3")])),
        (200, stream(&[text_piece("Not copied.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let tools =
        json!({ "tools": { "files": true, "ask_new_tools": false, "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", tools).await.0, 200);
    code_mode(&server, &chat, true).await;
    let mut socket = server.listen().await;

    // Its write waits for Allow, as the model's own would.
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let asks = next_event(&mut socket).await;
    assert_eq!(
        asks["ask"],
        json!({ "kind": "write", "what": "copy.txt", "detail": "BUY LAMP OIL." }),
        "{asks}"
    );
    assert!(!folder.0.join("copy.txt").exists());
    assert_eq!(
        server
            .post(&format!("{chat}/answer"), json!({ "allow": true }))
            .await
            .0,
        204
    );
    next_event(&mut socket).await;
    assert_eq!(
        next_event(&mut socket).await["message"]["content"],
        "Copied."
    );
    assert_eq!(
        std::fs::read_to_string(folder.0.join("copy.txt")).unwrap(),
        "BUY LAMP OIL."
    );
    let given = model.asked()[2]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()["content"]
        .clone();
    assert!(
        given.as_str().unwrap().contains("copy.txt (13 bytes)"),
        "{given}"
    );

    // With Files off it reaches no file: the script is thrown why.
    let off = json!({ "tools": { "files": false } });
    assert_eq!(server.patch("/api/settings", off).await.0, 200);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(
        next_event(&mut socket).await["message"]["content"],
        "Not copied."
    );
    let given = model.asked()[4]["messages"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()["content"]
        .clone();
    assert!(
        given.as_str().unwrap().contains("there is no such tool"),
        "{given}"
    );
}

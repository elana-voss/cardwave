//! `ask` against the pretend model, and against a small server of fixed answers
//! where what was sent or the count of requests is the point.

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::{Arc, Mutex};

use serde_json::{Value, json};

use super::*;
use crate::{Sampling, client, pretend};

fn provider(base_url: &str, seen_thinking: bool) -> Provider {
    Provider {
        base_url: base_url.to_string(),
        api_key: String::new(),
        model: "plain-7b".to_string(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking,
    }
}

fn schema() -> Value {
    object([
        ("name", text()),
        ("kind", one_of(&["a", "b"])),
        (
            "items",
            list(object([("sure", yes_no()), ("count", whole())])),
        ),
    ])
}

const FITTING: &str = r#"{"name":"Ada","kind":"b","items":[{"sure":true,"count":2}]}"#;

fn question<'a>(user: &'a str, limit: u32) -> Question<'a> {
    Question {
        role: "rank kinds",
        system: "Rank the kinds.",
        user,
        schema: schema(),
        limit,
        temperature: None,
    }
}

/// The answer of a server that does not stream, ended as `finish` says.
fn said(content: &str, finish: &str) -> (u16, Value) {
    let choice = json!({ "message": { "content": content }, "finish_reason": finish });
    (200, json!({ "choices": [choice] }))
}

/// A server that answers each request with the next of `answers`, and what it was asked.
fn scripted(answers: Vec<(u16, Value)>) -> (String, Arc<Mutex<Vec<Value>>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = format!("http://{}/v1", listener.local_addr().unwrap());
    let asked = Arc::new(Mutex::new(Vec::new()));
    let kept = asked.clone();
    std::thread::spawn(move || {
        for (status, answer) in answers {
            let (mut socket, _) = listener.accept().unwrap();
            let (mut read, mut end) = (Vec::new(), None);
            let mut length = 0;
            while end.is_none_or(|end| read.len() < end + length) {
                let mut more = [0; 4096];
                let got = socket.read(&mut more).unwrap();
                read.extend_from_slice(&more[..got]);
                if end.is_none()
                    && let Some(at) = read.windows(4).position(|w| w == b"\r\n\r\n")
                {
                    end = Some(at + 4);
                    let head = String::from_utf8_lossy(&read[..at]).to_lowercase();
                    let field = head.split("content-length: ").nth(1).unwrap();
                    length = field.lines().next().unwrap().trim().parse().unwrap();
                }
            }
            let body = &read[end.unwrap()..];
            kept.lock()
                .unwrap()
                .push(serde_json::from_slice(body).unwrap());
            let answer = answer.to_string();
            let sent = format!(
                "HTTP/1.1 {status} X\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{answer}",
                answer.len()
            );
            socket.write_all(sent.as_bytes()).unwrap();
        }
    });
    (address, asked)
}

/// What `answers` come to, with what was asked.
async fn run(answers: Vec<(u16, Value)>, limit: u32) -> (anyhow::Result<Value>, Vec<Value>) {
    let (address, asked) = scripted(answers);
    let http = client().unwrap();
    let got = ask(&http, &provider(&address, false), &question("Hi.", limit)).await;
    let asked = asked.lock().unwrap().clone();
    (got, asked)
}

fn code(failure: &anyhow::Error) -> Code {
    failure.downcast_ref::<Fail>().unwrap().code
}

/// The system message of a request.
fn system(asked: &Value) -> &str {
    asked["messages"][0]["content"].as_str().unwrap()
}

#[tokio::test]
async fn a_question_may_name_its_own_temperature() {
    let (address, asked) = scripted(vec![said(FITTING, "stop")]);
    let http = client().unwrap();
    let cold = Question {
        temperature: Some(0.0),
        ..question("Hi.", LIMIT)
    };
    ask(&http, &provider(&address, false), &cold).await.unwrap();
    assert_eq!(asked.lock().unwrap()[0]["temperature"], 0.0);
}

#[tokio::test]
async fn a_call_asks_by_a_strict_schema_named_after_its_role() {
    let (got, asked) = run(vec![said(FITTING, "stop")], LIMIT).await;
    assert_eq!(got.unwrap()["name"], "Ada");
    let sent = &asked[0];
    let format = &sent["response_format"];
    assert_eq!(format["type"], "json_schema");
    assert_eq!(format["json_schema"]["name"], "rank_kinds");
    assert_eq!(format["json_schema"]["strict"], true);
    assert_eq!(format["json_schema"]["schema"], schema());
    assert_eq!(schema()["additionalProperties"], false);
    assert_eq!(schema()["required"], json!(["name", "kind", "items"]));
    assert_eq!(sent["temperature"], 0.8);
    assert_eq!(sent["max_tokens"], 4000);
    assert_eq!(system(sent), "Rank the kinds.");
    assert_eq!(sent["messages"][1]["content"], "Hi.");
}

#[tokio::test]
async fn answers_that_do_not_fit_are_asked_again_three_times_at_most() {
    let unfit = [
        "no json here",
        // A required key is missing.
        r#"{"name":"Ada","kind":"a"}"#,
        // Not one of the values; a key of the wrong type deep inside.
        r#"{"name":"Ada","kind":"c","items":[]}"#,
    ];
    let answers = unfit.iter().map(|text| said(text, "stop")).collect();
    let (got, asked) = run(answers, LIMIT).await;
    let failure = got.unwrap_err();
    assert_eq!(code(&failure), Code::ModelAnswer);
    assert_eq!(asked.len(), 3);
    // From the second try on, the fields are told too.
    assert!(!system(&asked[0]).contains(TOLD));
    assert!(system(&asked[1]).contains(TOLD));

    let deep = r#"{"name":"Ada","kind":"a","items":[{"sure":"yes","count":1}]}"#;
    let answers = vec![said(deep, "stop"), said(FITTING, "stop")];
    let (got, asked) = run(answers, LIMIT).await;
    assert_eq!(got.unwrap()["kind"], "b");
    assert_eq!(asked.len(), 2);
}

#[tokio::test]
async fn a_cut_off_answer_is_asked_again_with_four_times_the_limit_up_to_the_most() {
    let cut = said(r#"{"name":"Ad"#, "length");
    let answers = vec![cut.clone(), cut.clone(), said(FITTING, "stop")];
    let (got, asked) = run(answers, 10_000).await;
    assert!(got.is_ok());
    let limits: Vec<&Value> = asked.iter().map(|sent| &sent["max_tokens"]).collect();
    assert_eq!(limits, [&json!(10_000), &json!(32_000), &json!(32_000)]);
    // A cut-off is a try, and does not tell the fields.
    assert!(!system(&asked[1]).contains(TOLD));

    let (got, asked) = run(vec![cut.clone(), cut.clone(), cut], 100).await;
    assert_eq!(code(&got.unwrap_err()), Code::ModelAnswer);
    assert_eq!(asked.len(), 3);
}

#[tokio::test]
async fn the_pretend_models_cut_off_answer_comes_whole_at_a_higher_limit() {
    let http = client().unwrap();
    let user = format!("Hi. {}", pretend::CUT_OFF);
    let plain = provider(pretend::ADDRESS, false);
    let got = ask(&http, &plain, &question(&user, 4_000)).await.unwrap();
    assert_eq!(got["kind"], "a");
    assert_eq!(got["items"][0]["sure"], false);
    // Three tries do not reach it.
    let got = ask(&http, &plain, &question(&user, 500)).await;
    assert_eq!(code(&got.unwrap_err()), Code::ModelAnswer);
    // A model that thinks is sent no limit, so its answer is not cut off.
    let thinks = provider(pretend::ADDRESS, true);
    assert!(ask(&http, &thinks, &question(&user, 500)).await.is_ok());
}

#[tokio::test]
async fn a_refusal_fails_at_once_as_the_models() {
    let http = client().unwrap();
    let user = format!("Hi. {}", pretend::DECLINE);
    let plain = provider(pretend::ADDRESS, false);
    let failure = ask(&http, &plain, &question(&user, LIMIT))
        .await
        .unwrap_err();
    assert!(declined(&failure));
    assert_eq!(code(&failure), Code::ModelDeclined);

    let signals = [
        said("", "content_filter"),
        said("", "refusal"),
        (
            200,
            json!({ "choices": [{ "message": { "refusal": "No." } }] }),
        ),
        (
            200,
            json!({ "choices": [{ "message": {}, "native_finish_reason": "SAFETY" }] }),
        ),
        (
            400,
            json!({ "error": { "message": "no", "code": "content_policy_violation" } }),
        ),
        (
            200,
            json!({ "error": { "message": "no", "code": "refusal" } }),
        ),
        // OpenRouter's moderation: its code is a number, its reasons say what it is.
        (
            403,
            json!({ "error": { "code": 403, "message": "flagged", "metadata": { "reasons": ["x"] } } }),
        ),
    ];
    for signal in signals {
        let (got, asked) = run(vec![signal.clone()], LIMIT).await;
        assert!(declined(&got.unwrap_err()), "{signal:?}");
        assert_eq!(asked.len(), 1);
    }
}

#[tokio::test]
async fn a_provider_rejecting_the_format_is_told_the_fields_in_the_prompt() {
    let rejection = (
        400,
        json!({ "error": { "message": "response_format is not supported" } }),
    );
    // The rejection is no try: three answers are still read after it.
    let unfit = said("no json", "stop");
    let answers = vec![rejection, unfit.clone(), unfit, said(FITTING, "stop")];
    let (got, asked) = run(answers, LIMIT).await;
    assert!(got.is_ok());
    assert_eq!(asked.len(), 4);
    assert!(!asked[0]["response_format"].is_null());
    assert!(asked[1]["response_format"].is_null());
    assert!(system(&asked[1]).contains(TOLD));

    // The pretend model reads the fields as a model would.
    let http = client().unwrap();
    let user = format!("Hi. {}", pretend::NO_FORMAT);
    let plain = provider(pretend::ADDRESS, false);
    let got = ask(&http, &plain, &question(&user, LIMIT)).await.unwrap();
    assert_eq!(got["name"], "pretend");
}

#[tokio::test]
async fn any_other_failure_is_returned_at_once() {
    let down = (500, json!({ "error": { "message": "down" } }));
    let (got, asked) = run(vec![down], LIMIT).await;
    assert_eq!(code(&got.unwrap_err()), Code::ProviderRefused);
    assert_eq!(asked.len(), 1);
}

#[test]
fn a_role_makes_a_name_a_provider_takes() {
    assert_eq!(name_of("rank kinds/é"), "rank_kinds__");
    assert_eq!(name_of(&"x".repeat(70)).len(), 64);
}

//! The test of a model before it is set up: one small question, asked as a chat
//! asks. No test asks a provider: the API is a server of the test's own.

mod common;

use std::time::{Duration, Instant};

use axum::http::Method;
use common::api::{Api, JSON, Says, says};
use common::server::{Server, WAIT, start};
use cw_provider::{self as provider, Provider, Sampling, check};
use serde_json::{Value, json};
use tokio::time::timeout;

const STREAM: &str = "text/event-stream";
const DONE: &str = "data: [DONE]\n\n";

/// One piece of a streamed reply, as OpenAI's API sends it.
fn piece(text: &str) -> String {
    format!(
        "data: {}\n\n",
        json!({ "choices": [{ "delta": { "content": text } }] })
    )
}

/// An API whose model replies "OK", streamed.
async fn answering() -> Api {
    Api::start(says(200, STREAM, &(piece("OK") + DONE))).await
}

/// Asks the server to test the model `asked` names.
async fn test(server: &Server, asked: Value) -> (u16, Value) {
    timeout(WAIT, server.post("/api/provider/test", asked))
        .await
        .expect("the test did not end")
}

/// What the server says of a model whose API answers `says`.
async fn tested(says: Says) -> (u16, Value) {
    let api = Api::start(says).await;
    let server = start().await;
    test(&server, json!({ "base_url": api.url, "model": "tide-1" })).await
}

/// An answer's status and text, as a failure `why` of the check has them.
fn failed(why: &str) -> (u16, Value) {
    (400, json!(why))
}

/// An answer's status and text.
fn said((status, body): (u16, Value)) -> (u16, Value) {
    (status, body["error"].clone())
}

#[tokio::test]
async fn a_model_that_replies_passes_and_was_asked_as_a_chat_asks() {
    let api = answering().await;
    let server = start().await;
    // What was pasted is tidied as it is when it is stored.
    let asked = json!({ "base_url": format!(" {}/ ", api.url), "model": " tide-1 ", "api_key": " sk-typed\n" });
    assert_eq!(test(&server, asked).await, (204, Value::Null));

    // One question, at the place of the API a chat's prompt goes to, with the
    // key: a small one, to which the model's ID and nothing else is added, no
    // limit either, which not every model takes.
    let asked = api.asked();
    assert_eq!(asked.len(), 1, "{asked:?}");
    assert_eq!(
        (&asked[0].method, asked[0].path.as_str(), &asked[0].key),
        (
            &Method::POST,
            "/v1/chat/completions",
            &Some("Bearer sk-typed".into())
        )
    );
    assert_eq!(
        serde_json::from_str::<Value>(&asked[0].body).unwrap(),
        json!({
            "model": "tide-1",
            "messages": [{ "role": "user", "content": "Reply with the single word OK." }],
            "stream": true,
        })
    );
    // Nothing is set up by it.
    assert_eq!(server.get("/api/provider").await.1, Value::Null);

    // A server that does not stream answers with one document.
    let whole = json!({ "choices": [{ "message": { "role": "assistant", "content": "OK" } }] });
    assert_eq!(tested(says(200, JSON, &whole.to_string())).await.0, 204);
}

#[tokio::test]
async fn the_key_that_would_go_with_a_chat_goes_with_the_question_and_what_the_user_set_does_not() {
    let api = answering().await;
    let server = start().await;
    let stored = json!({
        "base_url": api.url,
        "model": "tide-1",
        "api_key": "sk-stored",
        "sampling": { "temperature": 0.7, "max_response_length": 300, "seed": 7 },
    });
    let (status, before) = server.put("/api/provider", stored).await;
    assert_eq!(status, 200, "{before}");

    // Without a key typed the stored one goes along, to the address it was stored with, however that is written.
    let at = |base_url: String, key: Option<&str>| {
        let mut asked = json!({ "base_url": base_url, "model": "reef-2" });
        if let Some(key) = key {
            asked["api_key"] = key.into();
        }
        asked
    };
    assert_eq!(
        test(&server, at(format!("{}/", api.url), None)).await.0,
        204
    );
    assert_eq!(api.last_key(), Some("Bearer sk-stored".into()));
    // The model asked is the form's, not the stored one, and the stored values for a reply stay at home.
    let sent: Value = serde_json::from_str(&api.asked()[0].body).unwrap();
    assert_eq!(sent["model"], "reef-2");
    assert_eq!(
        sent.as_object().unwrap().keys().collect::<Vec<_>>(),
        ["messages", "model", "stream"]
    );
    // A key typed goes in its place, and an empty one means none.
    assert_eq!(
        test(&server, at(api.url.clone(), Some("sk-typed"))).await.0,
        204
    );
    assert_eq!(api.last_key(), Some("Bearer sk-typed".into()));
    assert_eq!(test(&server, at(api.url.clone(), Some(""))).await.0, 204);
    assert_eq!(api.last_key(), None);

    // At another address the stored key is not sent.
    let other = answering().await;
    assert_eq!(test(&server, at(other.url.clone(), None)).await.0, 204);
    assert_eq!(other.last_key(), None);
    // The provider is as it was.
    assert_eq!(server.get("/api/provider").await.1, before);
}

#[tokio::test]
async fn the_first_words_of_a_reply_are_enough() {
    // A reply that begins and does not end, as a model's that writes on.
    let writing = Says {
        endless: true,
        ..says(200, STREAM, &piece("OK, here is a long story."))
    };
    let started = Instant::now();
    assert_eq!(tested(writing).await.0, 204);
    assert!(
        started.elapsed() < Duration::from_secs(5),
        "{:?}",
        started.elapsed()
    );
    // A piece without words is none yet: what comes after it counts.
    let late = Says {
        then: Some(piece("OK") + DONE),
        ..says(200, STREAM, &(piece("") + &piece("\n ")))
    };
    assert_eq!(tested(late).await.0, 204);
}

#[tokio::test]
async fn a_model_that_does_not_reply_fails_with_the_reason() {
    let refused = |message: &str| json!({ "error": { "message": message } }).to_string();
    let reported = format!("data: {}\n\n", refused("the model is overloaded"));
    for (says, why) in [
        (
            says(401, JSON, &refused("Incorrect API key provided")),
            "the model's server answered 401 Unauthorized: Incorrect API key provided",
        ),
        (
            says(404, JSON, &refused("The model `tide-1` does not exist")),
            "the model's server answered 404 Not Found: The model `tide-1` does not exist",
        ),
        // An address that is no API for chats: a website's page for what it does not have.
        (
            says(404, "text/html", "Not here."),
            "the model's server answered 404 Not Found: Not here.",
        ),
        (
            says(200, STREAM, &reported),
            "the model's server reported: the model is overloaded",
        ),
        // A reply without words is none, as in a chat.
        (says(200, STREAM, DONE), "the model sent no text"),
        (
            says(200, STREAM, &(piece(" \n") + DONE)),
            "the model sent no text",
        ),
        (
            says(200, JSON, r#"{"object":"list","data":[{"id":"tide-1"}]}"#),
            "the model sent no text",
        ),
        (
            says(200, "text/html", "<html><body>Welcome</body></html>"),
            "the model sent no text",
        ),
    ] {
        assert_eq!(said(tested(says).await), failed(why));
    }

    // Nothing listens there: the system's own reason, without the address, which the form shows.
    let server = start().await;
    let nowhere = json!({ "base_url": "http://127.0.0.1:1/v1", "model": "tide-1" });
    let (status, answer) = test(&server, nowhere).await;
    let why = answer["error"].as_str().unwrap();
    assert_eq!(status, 400);
    let reason = why
        .strip_prefix("the model's server cannot be reached: ")
        .unwrap_or_else(|| panic!("{why}"));
    assert!(
        !reason.is_empty() && !reason.contains("127.0.0.1") && !reason.contains("error sending"),
        "{why}"
    );

    // What is no address, no model or no key is refused, and nowhere is asked.
    let api = answering().await;
    for (change, why) in [
        (
            json!({ "base_url": "localhost:5001" }),
            "the address must be a plain web address such as https://api.openai.com/v1",
        ),
        (
            json!({ "base_url": format!("{}?key=1", api.url) }),
            "the address must be a plain web address such as https://api.openai.com/v1",
        ),
        (json!({ "model": "  " }), "the model must be named"),
        (
            json!({ "api_key": "sk two words" }),
            "the key holds characters a key cannot have",
        ),
    ] {
        let mut asked = json!({ "base_url": api.url, "model": "tide-1" });
        asked
            .as_object_mut()
            .unwrap()
            .extend(change.as_object().unwrap().clone());
        assert_eq!(said(test(&server, asked).await), failed(why));
    }
    assert_eq!(api.asked(), []);
}

#[tokio::test]
async fn a_model_has_a_while_for_its_first_word_and_no_longer() {
    let http = provider::client().unwrap();
    let brief = Duration::from_secs(2);
    // A server that takes the question and does not answer, and a reply that begins without a word and goes no further.
    let silent = Says {
        after: Duration::from_secs(120),
        ..says(200, STREAM, &(piece("OK") + DONE))
    };
    let wordless = Says {
        endless: true,
        ..says(200, STREAM, &piece(""))
    };
    for late in [silent, wordless] {
        let api = Api::start(late).await;
        let provider = Provider {
            base_url: api.url.clone(),
            api_key: String::new(),
            model: "tide-1".into(),
            sampling: Sampling::default(),
            name: String::new(),
            thinking_off: None,
            reply_limit: None,
            seen_thinking: false,
        };
        let started = Instant::now();
        let failed = check::model(&http, &provider, brief).await.unwrap_err();
        assert_eq!(format!("{failed:#}"), "the model did not answer in time");
        let took = started.elapsed();
        assert!(took >= brief && took < Duration::from_secs(8), "{took:?}");
    }
}

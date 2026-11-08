//! The models a provider lists, asked of its API with the user's key. No test
//! asks a provider: the API is a server of the test's own.
//!
//! A test of the wait or of the size calls `models::of` itself with `Limits` of
//! its own. An address where nothing listens is `http://127.0.0.1:1/v1`, which
//! Windows refuses after about 2 s.

mod common;

use std::time::{Duration, Instant};

use axum::http::Method;
use common::api::{Api, Asked, JSON, Says, says};
use common::server::{Server, WAIT, start};
use cw_provider as provider;
use cw_provider::models::{self, Limits, ListedModels};
use serde_json::{Value, json};
use tokio::time::timeout;

const HTML: &str = "text/html; charset=utf-8";
const MODELS: &str = r#"{"object":"list","data":[{"id":"tide-1"}]}"#;

/// An API that lists `MODELS`.
async fn listing() -> Api {
    Api::start(says(200, JSON, MODELS)).await
}

/// Asks the server for the models of the address in `asked`.
async fn list(server: &Server, asked: Value) -> (u16, Value) {
    timeout(WAIT, server.post("/api/provider/models", asked))
        .await
        .expect("the list did not come")
}

/// What the server answers when the API at the address answers `says`, asked
/// with `key` if there is one.
async fn answered(says: Says, key: Option<&str>) -> (u16, Value) {
    let api = Api::start(says).await;
    let server = start().await;
    let mut asked = json!({ "base_url": api.url });
    if let Some(key) = key {
        asked["api_key"] = key.into();
    }
    list(&server, asked).await
}

#[tokio::test]
async fn the_models_of_an_address_are_listed_each_once_in_the_order_of_their_names() {
    // A list as OpenAI's API gives it, with what is no model among them, a
    // model named twice, and a list of something else before it.
    let api = Api::start(says(
        200,
        JSON,
        r#"{"object":"list","meta":{"data":[{"id":"no-model"}]},"data":[
            {"id":"tide-2","object":"model","owned_by":{"id":"nobody"}},
            {"id":"Reef-1"},
            {"id":"tide-2"},
            {"id":"Tide-2"},
            {"id":""},
            {"id":"  "},
            {"id":7},
            {"object":"model"},
            "text", null, 3, ["tide-9"],
            {"id":"anchor/Tide-10"}
        ],"total":4}"#,
    ))
    .await;
    let server = start().await;
    // A slash at the address's end does not count, nor the space around it.
    let (status, listed) = list(&server, json!({ "base_url": format!(" {}/ ", api.url) })).await;
    assert_eq!(status, 200, "{listed}");
    let wanted =
        json!({ "models": ["anchor/Tide-10", "Reef-1", "Tide-2", "tide-2"], "more": false });
    assert_eq!(listed, wanted);
    // It was asked once, for its list, as JSON.
    let asked = Asked {
        method: Method::GET,
        path: "/v1/models".into(),
        key: None,
        accept: Some(JSON.into()),
        heard: api.asked()[0].heard.clone(),
        body: String::new(),
    };
    assert_eq!(api.asked(), [asked]);
    // Nothing is set up by it.
    assert_eq!(server.get("/api/provider").await.1, Value::Null);

    for (body, models) in [
        // A list by itself, as some APIs give it.
        (
            r#"[{"id":"tide-2"},{"id":"reef-1"}]"#,
            json!(["reef-1", "tide-2"]),
        ),
        // llama.cpp's, which has its models twice, under two names.
        (
            r#"{"models":[{"name":"kelp","model":"kelp"}],"object":"list","data":[{"id":"kelp"}]}"#,
            json!(["kelp"]),
        ),
        // A list without models is a list.
        (r#"{"object":"list","data":[]}"#, json!([])),
    ] {
        let (status, listed) = answered(says(200, JSON, body), None).await;
        assert_eq!(status, 200, "{body}");
        assert_eq!(listed, json!({ "models": models, "more": false }), "{body}");
    }
}

#[tokio::test]
async fn the_key_typed_goes_along_and_a_stored_key_only_to_the_address_it_was_stored_with() {
    let (mine, other) = (listing().await, listing().await);
    let server = start().await;
    let ask = async |api: &Api, key: Option<&str>| {
        let mut asked = json!({ "base_url": api.url });
        if let Some(key) = key {
            asked["api_key"] = key.into();
        }
        let (status, listed) = list(&server, asked).await;
        assert_eq!(status, 200, "{listed}");
        api.last_key()
    };
    let bearer = |key: &str| Some(format!("Bearer {key}"));

    // Without a provider set up: the key typed, as it would be stored, or none.
    assert_eq!(ask(&mine, None).await, None);
    assert_eq!(ask(&mine, Some(" sk-typed\n")).await, bearer("sk-typed"));
    // The key typed was not kept.
    assert_eq!(server.get("/api/provider").await.1, Value::Null);
    assert_eq!(ask(&mine, None).await, None);

    let stored = json!({ "base_url": mine.url, "model": "tide-1", "api_key": "sk-stored" });
    assert_eq!(server.put("/api/provider", stored).await.0, 200);
    // The stored key goes to the address it was stored with, however that is written.
    assert_eq!(ask(&mine, None).await, bearer("sk-stored"));
    let (_, listed) = list(&server, json!({ "base_url": format!("{}/", mine.url) })).await;
    assert_eq!(listed["models"], json!(["tide-1"]));
    assert_eq!(mine.last_key(), bearer("sk-stored"));
    // A key typed counts for more, and an empty one is none.
    assert_eq!(ask(&mine, Some("sk-new")).await, bearer("sk-new"));
    assert_eq!(ask(&mine, Some("")).await, None);
    // To another address goes the key typed for it, and never the stored one.
    assert_eq!(ask(&other, None).await, None);
    assert_eq!(ask(&other, Some("sk-other")).await, bearer("sk-other"));
    assert!(
        other
            .asked()
            .iter()
            .all(|asked| asked.key != bearer("sk-stored"))
    );

    // The provider is as it was set up, with its key.
    let (_, kept) = server.get("/api/provider").await;
    assert_eq!(kept["base_url"], mine.url);
    assert_eq!(kept["model"], "tide-1");
    assert_eq!(kept["has_key"], true);
    assert_eq!(ask(&mine, None).await, bearer("sk-stored"));
}

#[tokio::test]
async fn an_address_that_sends_on_to_another_host_is_followed_without_the_key() {
    // As a chat's question would be: the key is for the address in the form.
    let other = listing().await;
    let onward = Says {
        onward: Some(format!("{}/models", other.url)),
        ..says(307, JSON, "")
    };
    let mine = Api::start(onward).await;
    let server = start().await;
    let asked = json!({ "base_url": mine.url, "api_key": "sk-typed" });
    let (status, listed) = list(&server, asked).await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(listed["models"], json!(["tide-1"]));
    assert_eq!(mine.last_key(), Some("Bearer sk-typed".into()));
    assert_eq!(other.last_key(), None);
}

#[tokio::test]
async fn what_is_no_address_or_no_key_is_refused_and_nowhere_asked() {
    let api = listing().await;
    let server = start().await;
    let host = api.url.trim_start_matches("http://");
    for base_url in [
        String::new(),
        host.to_string(),
        format!("ftp://{host}"),
        format!("http://name:word@{host}"),
        format!("{}?key=sk-typed", api.url),
        format!("{}#models", api.url),
    ] {
        let (status, refused) = list(&server, json!({ "base_url": base_url })).await;
        assert_eq!(status, 400, "{base_url}");
        let said = refused["error"].as_str().unwrap();
        assert!(said.contains("a plain web address"), "{base_url}: {said}");
    }
    let asked = json!({ "base_url": api.url, "api_key": "sk typed" });
    let (status, refused) = list(&server, asked).await;
    assert_eq!(status, 400);
    assert_eq!(
        refused["error"],
        "the key holds characters a key cannot have"
    );
    assert_eq!(api.asked(), []);
}

#[tokio::test]
async fn an_address_that_gives_no_list_says_why() {
    let no_key = r#"{"error":{"message":"Missing API key"}}"#;
    let wrong_key = r#"{"error":{"message":"Incorrect API key provided"}}"#;
    let page = "<!doctype html><title>Not found</title>";
    for (status, kind, body, key, said) in [
        // The key is the reason, by whether one was sent.
        (
            401,
            JSON,
            wrong_key,
            Some("sk-typed"),
            "the model's server did not take the key (401 Unauthorized): Incorrect API key provided",
        ),
        (
            403,
            "text/plain",
            "Forbidden",
            Some("sk-typed"),
            "the model's server did not take the key (403 Forbidden): Forbidden",
        ),
        (
            401,
            JSON,
            no_key,
            None,
            "the model's server asks for a key (401 Unauthorized): Missing API key",
        ),
        (
            401,
            JSON,
            no_key,
            Some(""),
            "the model's server asks for a key (401 Unauthorized): Missing API key",
        ),
        (
            403,
            HTML,
            page,
            None,
            "the model's server asks for a key (403 Forbidden)",
        ),
        // An API may have no list: that is said as it is, without the server's page.
        (
            404,
            JSON,
            "",
            Some("sk-typed"),
            "the model's server has no list of models at this address (404 Not Found)",
        ),
        (
            404,
            HTML,
            page,
            None,
            "the model's server has no list of models at this address (404 Not Found)",
        ),
        (
            404,
            JSON,
            r#"{"message":"no such route"}"#,
            None,
            "the model's server has no list of models at this address (404 Not Found): no such route",
        ),
        // Anything else that went wrong, as the server tells it.
        (
            429,
            JSON,
            r#"{"error":"Slow down"}"#,
            Some("sk-typed"),
            "the model's server answered 429 Too Many Requests: Slow down",
        ),
        (
            500,
            JSON,
            "",
            None,
            "the model's server answered 500 Internal Server Error",
        ),
        // An answer that is no list of models: a page, other JSON, a list
        // under another name or further in, nothing.
        (
            200,
            HTML,
            page,
            None,
            "the address answers, but not with a list of models",
        ),
        (
            200,
            JSON,
            r#"{"status":"ok"}"#,
            None,
            "the address answers, but not with a list of models",
        ),
        (
            200,
            JSON,
            r#"{"models":[{"id":"tide-1"}]}"#,
            None,
            "the address answers, but not with a list of models",
        ),
        (
            200,
            JSON,
            r#"{"data":{"data":[{"id":"tide-1"}]}}"#,
            None,
            "the address answers, but not with a list of models",
        ),
        (
            200,
            JSON,
            "",
            None,
            "the address answers, but not with a list of models",
        ),
    ] {
        let (got, refused) = answered(says(status, kind, body), key).await;
        assert_eq!(got, 400, "{status} {body}");
        assert_eq!(refused["error"], said, "{status} {body}");
    }
}

#[tokio::test]
async fn an_address_where_nothing_listens_says_so() {
    // Port 1 of this machine: nothing listens there.
    let server = start().await;
    let (status, refused) = list(&server, json!({ "base_url": "http://127.0.0.1:1/v1" })).await;
    assert_eq!(status, 400);
    // Why, as the system says it, without the way the failure took through
    // the program.
    let said = refused["error"].as_str().unwrap();
    let why = said
        .strip_prefix("the model's server cannot be reached: ")
        .expect(said);
    assert!(why.contains("os error"), "{said}");
    assert!(!why.contains(": ") && !why.contains("127.0.0.1"), "{said}");
}

/// A list of `count` models, `tide-00000` and on.
fn long_list(count: usize) -> String {
    let models: Vec<String> = (0..count)
        .map(|n| format!(r#"{{"id":"tide-{n:05}","object":"model","owned_by":"nobody"}}"#))
        .collect();
    format!(r#"{{"object":"list","data":[{}]}}"#, models.join(","))
}

#[tokio::test]
async fn a_list_longer_than_is_read_gives_the_models_that_came_and_says_there_are_more() {
    let api = Api::start(says(200, JSON, &long_list(20_000))).await;
    let http = provider::client().unwrap();
    let short = Limits {
        bytes: 64 << 10,
        ..Limits::default()
    };
    let listed = models::of(&http, &api.url, "", short).await.unwrap();
    assert!(listed.more);
    // Of a million bytes about 64 KB were read: the models from the first on.
    let came = listed.models.len();
    assert!((1_000..10_000).contains(&came), "{came} models");
    let first: Vec<String> = (0..came).map(|n| format!("tide-{n:05}")).collect();
    assert_eq!(listed.models, first);

    // Within what is read by itself, the same list comes whole.
    let server = start().await;
    let (status, whole) = list(&server, json!({ "base_url": api.url })).await;
    assert_eq!(status, 200);
    assert_eq!(whole["models"].as_array().unwrap().len(), 20_000);
    assert_eq!(whole["more"], false);
}

#[tokio::test]
async fn a_list_that_breaks_off_gives_the_models_before_the_break() {
    let broken = r#"{"object":"list","data":[{"id":"tide-1"},{"id":"reef-1","object":"model"},{"id":"kelp-1","obj"#;
    let (status, listed) = answered(says(200, JSON, broken), None).await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(
        listed,
        json!({ "models": ["reef-1", "tide-1"], "more": true })
    );

    // One that breaks off before its first model is no list without models.
    for broken in [r#"{"object":"list","data":["#, r#"[{"id":"tide-1","obj"#] {
        let (status, refused) = answered(says(200, JSON, broken), None).await;
        assert_eq!(status, 400, "{broken}");
        assert_eq!(refused["error"], "the list of models did not come");
    }
}

#[tokio::test]
async fn a_list_is_waited_for_a_while_and_what_came_by_then_is_the_answer() {
    let http = provider::client().unwrap();
    let brief = Limits {
        wait: Duration::from_secs(2),
        ..Limits::default()
    };
    // The list begins and does not end, as one of megabytes on a slow line.
    let endless = Says {
        endless: true,
        ..says(
            200,
            JSON,
            r#"{"object":"list","data":[{"id":"tide-1"},{"id":"reef-1"},"#,
        )
    };
    let api = Api::start(endless).await;
    let started = Instant::now();
    let listed = models::of(&http, &api.url, "", brief).await.unwrap();
    let wanted = ListedModels {
        models: vec!["reef-1".into(), "tide-1".into()],
        more: true,
    };
    assert_eq!(listed, wanted);
    let took = started.elapsed();
    assert!(
        took >= Duration::from_secs(2) && took < Duration::from_secs(8),
        "{took:?}"
    );

    // A server that takes the question and does not answer, and one whose
    // answer begins and has not come as far as its list when the time is over.
    let silent = Says {
        after: Duration::from_secs(120),
        ..says(200, JSON, MODELS)
    };
    let stalled = Says {
        endless: true,
        ..says(200, JSON, r#"{"object":"list","pages":{"of":3},"#)
    };
    for late in [silent, stalled] {
        let api = Api::start(late).await;
        let started = Instant::now();
        let failed = models::of(&http, &api.url, "", brief).await.unwrap_err();
        assert_eq!(
            format!("{failed:#}"),
            "the model's server did not answer in time"
        );
        assert!(
            started.elapsed() < Duration::from_secs(8),
            "{:?}",
            started.elapsed()
        );
    }
}

#[tokio::test]
async fn the_list_and_the_picks_name_their_models_as_models_devs_list_does() {
    // The shipped list knows gpt-4o by its most common name; tide-1 it does not know.
    let api = Api::start(says(
        200,
        JSON,
        r#"{"data":[{"id":"gpt-4o"},{"id":"tide-1"}]}"#,
    ))
    .await;
    let server = start().await;
    let (status, listed) = list(&server, json!({ "base_url": api.url })).await;
    assert_eq!(status, 200, "{listed}");
    assert_eq!(listed["names"], json!({ "gpt-4o": "GPT-4o" }));
    let one = Api::start(says(200, JSON, r#"{"data":[{"id":"gpt-4o"}]}"#)).await;
    let (status, picks) = server
        .post("/api/provider/picks", json!({ "base_url": one.url }))
        .await;
    assert_eq!(status, 200, "{picks}");
    assert_eq!(picks["chat"], "gpt-4o");
    assert_eq!(picks["names"], json!({ "gpt-4o": "GPT-4o" }));
}

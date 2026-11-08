//! The list of providers kept with the app, and the search for the API of a
//! provider that is not on it. No test asks a provider: the places are a
//! server of the test's own.
//!
//! `Places` is that server, which the search asks in place of the providers'
//! hosts (`common::server::start_asking`); it answers by rules and notes what
//! it was asked. It is given by its IP address, as a name that leads to this
//! machine is not asked.

mod common;

use std::collections::HashSet;
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, Method, StatusCode, Uri, header};
use axum::response::IntoResponse;
use common::server::{Server, start, start_asking};
use cw_platform::http::{addresses, public};
use cw_provider::places::{PLACES, host_of, places};
use cw_provider::{self as provider, SetProvider, list};
use futures_util::{StreamExt, stream};
use reqwest::Url;
use serde_json::{Value, json};
use tokio::net::TcpListener;
use tokio::time::{sleep, timeout};

const JSON: &str = "application/json";
const HTML: &str = "text/html; charset=utf-8";
const MODELS: &str = r#"{"object":"list","data":[{"id":"tide-1"}]}"#;
const NO_KEY: &str = r#"{"error":{"message":"Missing API key"}}"#;
const NOT_FOUND: &str = r#"{"detail":"Not Found"}"#;

/// How the places answer what starts with `at` (a host and the start of a path).
#[derive(Clone)]
struct Rule {
    at: &'static str,
    status: u16,
    kind: &'static str,
    body: &'static str,
    /// Where the answer sends on, as a redirect does.
    onward: Option<&'static str>,
    /// How long the answer takes.
    after: Duration,
    /// Whether the answer never ends: after `body` nothing more comes.
    endless: bool,
}

fn says(at: &'static str, status: u16, kind: &'static str, body: &'static str) -> Rule {
    Rule {
        at,
        status,
        kind,
        body,
        onward: None,
        after: Duration::ZERO,
        endless: false,
    }
}

/// How long a test waits for a search: longer than the search waits for a place.
const WAIT: Duration = Duration::from_secs(20);

/// What the places were asked.
#[derive(Clone, Debug)]
struct Asked {
    method: Method,
    /// The host and the path: `api.tidewater.test/v1/models`.
    place: String,
    key: bool,
    /// Who asked, by its own word.
    by: String,
}

/// A stand-in for every host a search asks, started inside the test. The first
/// rule a place starts with answers it; without one it is a JSON 404, as an
/// API answers a place it does not have.
struct Places {
    url: String,
    asked: Arc<Mutex<Vec<Asked>>>,
}

impl Places {
    async fn start(rules: Vec<Rule>) -> Self {
        let asked = Arc::new(Mutex::new(Vec::new()));
        let log = asked.clone();
        let answer = move |method: Method, uri: Uri, headers: HeaderMap| async move {
            let place = uri.path().trim_start_matches('/').to_string();
            let key = headers.contains_key(header::AUTHORIZATION);
            let rule = rules
                .iter()
                .find(|rule| place.starts_with(rule.at))
                .cloned();
            let by = headers
                .get(header::USER_AGENT)
                .map(|by| by.to_str().unwrap());
            let by = by.unwrap_or_default().to_string();
            let asked = Asked {
                method,
                place,
                key,
                by,
            };
            log.lock().unwrap().push(asked);
            let rule = rule.unwrap_or(says("", 404, JSON, NOT_FOUND));
            sleep(rule.after).await;
            let mut head = HeaderMap::new();
            head.insert(header::CONTENT_TYPE, rule.kind.parse().unwrap());
            if let Some(onward) = rule.onward {
                head.insert(header::LOCATION, onward.parse().unwrap());
            }
            let body = stream::once(async move { Ok::<_, std::convert::Infallible>(rule.body) });
            let body = match rule.endless {
                true => Body::from_stream(body.chain(stream::pending())),
                false => Body::from_stream(body),
            };
            (StatusCode::from_u16(rule.status).unwrap(), head, body).into_response()
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let app = Router::new().fallback(answer);
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }

    fn asked(&self) -> Vec<Asked> {
        self.asked.lock().unwrap().clone()
    }

    /// A server that looks for a provider's API here.
    async fn server(&self) -> Server {
        start_asking(Some(self.url.clone())).await
    }
}

/// Asks the server for the API of the provider whose website is `website`.
async fn find(server: &Server, website: &str) -> (u16, Value) {
    let asked = json!({ "website": website });
    timeout(WAIT, server.post("/api/provider/find", asked))
        .await
        .expect("the search did not end")
}

/// What a search for `website` finds at places that follow `rules`.
async fn found(rules: Vec<Rule>, website: &str) -> Value {
    let places = Places::start(rules).await;
    let server = places.server().await;
    let (status, found) = find(&server, website).await;
    assert_eq!(status, 200, "{found}");
    found
}

#[test]
fn the_list_names_each_provider_once_at_an_address_the_form_takes() {
    let all = list::all();
    assert!(all.len() > 100, "{} providers", all.len());
    let names: Vec<String> = all.iter().map(|known| known.name.to_lowercase()).collect();
    let mut sorted = names.clone();
    sorted.sort();
    assert_eq!(
        names, sorted,
        "in the order of the names, whatever their case"
    );
    assert_eq!(names.iter().collect::<HashSet<_>>().len(), names.len());

    let scratch = common::Scratch::new();
    for known in all {
        let address = Url::parse(&known.base_url).unwrap();
        // The user's key goes where the list says: to a provider over https,
        // or to a server on the user's own machine.
        let own = address.scheme() == "http" && address.host_str() == Some("127.0.0.1");
        assert_eq!(known.local, own, "{}", known.name);
        assert!(own || address.scheme() == "https", "{}", known.name);
        // Saved, it is the address as the list has it.
        let new = SetProvider {
            base_url: known.base_url.clone(),
            model: "a-model".into(),
            api_key: None,
            sampling: None,
            name: None,
            worker_model: None,
            image_model: None,
        };
        let (kept, _) = provider::set(&scratch.db, scratch.user, new).unwrap();
        assert_eq!(kept.base_url, known.base_url, "{}", known.name);
    }

    let of = |name: &str| all.iter().find(|known| known.name == name).unwrap();
    assert_eq!(of("OpenAI").base_url, "https://api.openai.com/v1");
    assert_eq!(of("Featherless").base_url, "https://api.featherless.ai/v1");
    assert_eq!(of("KoboldCpp").base_url, "http://127.0.0.1:5001/v1");
    let local: Vec<&str> = all
        .iter()
        .filter(|known| known.local)
        .map(|known| known.name.as_str())
        .collect();
    assert_eq!(local, ["KoboldCpp", "LM Studio", "Ollama"]);
}

#[tokio::test]
async fn the_list_is_answered_with_names_addresses_and_how_keys_begin() {
    let server = start().await;
    let (status, listed) = server.get("/api/providers").await;
    assert_eq!(status, 200);
    let listed = listed.as_array().unwrap();
    assert_eq!(listed.len(), list::all().len());
    let kobold = json!({ "name": "KoboldCpp", "base_url": "http://127.0.0.1:5001/v1", "local": true, "keys": [] });
    assert!(listed.contains(&kobold), "{listed:?}");
    let openai = json!({
        "name": "OpenAI", "base_url": "https://api.openai.com/v1", "local": false,
        "keys": ["sk-proj-", "sk-svcacct-", "sk-"],
    });
    assert!(listed.contains(&openai));
}

/// By how a key begins first run says whose it is, so a beginning is one a
/// key can have, long enough to tell something, and of a service: a server on
/// the user's own machine gives no keys out.
#[test]
fn how_a_providers_keys_begin_is_told_for_services_alone() {
    let all = list::all();
    let with_keys: Vec<&str> = all
        .iter()
        .filter(|known| !known.keys.is_empty())
        .map(|known| known.name.as_str())
        .collect();
    assert_eq!(
        with_keys,
        [
            "Alibaba Cloud Model Studio",
            "Anthropic",
            "Baseten",
            "Chutes",
            "DeepSeek",
            "Electron Hub",
            "Google Gemini",
            "Groq",
            "Hugging Face",
            "NanoGPT",
            "Novita AI",
            "Nvidia NIM",
            "OpenAI",
            "OpenRouter",
            "Perplexity",
            "Pretend model",
            "xAI"
        ]
    );
    for known in all {
        assert!(!known.local || known.keys.is_empty(), "{}", known.name);
        for key in &known.keys {
            assert!(key.len() >= 3, "{}: {key}", known.name);
            assert!(key.chars().all(|c| c.is_ascii_graphic()), "{}", known.name);
        }
        let once: HashSet<_> = known.keys.iter().collect();
        assert_eq!(once.len(), known.keys.len(), "{}", known.name);
    }
    let of = |name: &str| &all.iter().find(|known| known.name == name).unwrap().keys;
    assert_eq!(of("OpenRouter"), &["sk-or-v1-"]);
    assert_eq!(of("Anthropic"), &["sk-ant-"]);
    // One beginning that several providers share: the user chooses between them.
    assert!(of("OpenAI").contains(&"sk-".to_string()));
    assert_eq!(of("DeepSeek"), &["sk-"]);
    // A NanoGPT key ("sk-nano-" and a UUID) is NanoGPT's, not OpenAI's or DeepSeek's.
    assert_eq!(of("NanoGPT"), &["sk-nano-"]);
}

#[tokio::test]
async fn a_listed_providers_website_gives_the_lists_address_and_asks_nowhere() {
    let places = Places::start(vec![says("", 200, JSON, MODELS)]).await;
    let server = places.server().await;
    for (website, name, base_url) in [
        ("openai.com", "OpenAI", "https://api.openai.com/v1"),
        // An address on the website, with "www." and in any case.
        (
            "https://WWW.Featherless.ai/models?sort=new",
            "Featherless",
            "https://api.featherless.ai/v1",
        ),
        // A host under the website's domain.
        ("platform.openai.com", "OpenAI", "https://api.openai.com/v1"),
        // The API is on another domain than the website: either names the provider.
        ("infermatic.ai", "Infermatic", "https://api.totalgpt.ai/v1"),
        ("totalgpt.ai", "Infermatic", "https://api.totalgpt.ai/v1"),
        // An entry without a website is found by its API's host.
        ("cortecs.ai", "Cortecs", "https://api.cortecs.ai/v1"),
    ] {
        let (status, found) = find(&server, website).await;
        assert_eq!(status, 200, "{website}");
        assert_eq!(
            found,
            json!({ "base_url": base_url, "name": name }),
            "{website}"
        );
    }
    assert!(places.asked().is_empty(), "{:?}", places.asked());

    // A name that only ends as a provider's website does is not that provider.
    let (_, found) = find(&server, "notopenai.com").await;
    assert_eq!(found, Value::Null);
    assert!(!places.asked().is_empty());
}

#[tokio::test]
async fn an_unlisted_providers_api_is_the_first_of_the_usual_places_that_answers() {
    // Two places answer as an API; the one earlier in the order answers later.
    let slow = Rule {
        after: Duration::from_millis(400),
        ..says("tidewater.test/api/v1/models", 200, JSON, MODELS)
    };
    let rules = vec![
        slow,
        says("llm.tidewater.test/v1/models", 200, JSON, MODELS),
    ];
    let stand_in = Places::start(rules).await;
    let server = stand_in.server().await;
    let (status, found) = find(&server, "tidewater.test").await;
    assert_eq!(status, 200);
    assert_eq!(
        found,
        json!({ "base_url": "https://tidewater.test/api/v1", "name": null })
    );

    // Every place was asked for its list of models, and the two that have one
    // for a place that cannot be: without a key, and nothing else of them.
    let asked = stand_in.asked();
    let mut of_models: Vec<&str> = asked
        .iter()
        .filter_map(|asked| asked.place.strip_suffix("/models"))
        .collect();
    of_models.sort();
    let mut all: Vec<String> = places("tidewater.test")
        .iter()
        .map(|base| base.trim_start_matches("https://").to_string())
        .collect();
    all.sort();
    assert_eq!(of_models, all);
    for asked in &asked {
        assert_eq!(asked.method, Method::GET, "{asked:?}");
        assert!(!asked.key, "{asked:?}");
        assert_eq!(asked.by, "Cardwave", "{asked:?}");
        let (host, path) = asked.place.split_once('/').unwrap();
        assert!(
            host == "tidewater.test" || host.ends_with(".tidewater.test"),
            "{asked:?}"
        );
        assert!(
            path.ends_with("models") || path.ends_with("cardwave-no-such-place"),
            "{asked:?}"
        );
    }
    // What was found is the user's to take: nothing is set up by the search.
    assert_eq!(server.get("/api/provider").await.1, Value::Null);
}

#[tokio::test]
async fn a_list_of_models_or_a_refusal_for_the_missing_key_is_an_api_and_a_page_is_not() {
    let at = "api.reed.test/v1/models";
    let base = json!({ "base_url": "https://api.reed.test/v1", "name": null });
    // Answers longer than the search reads: a list of 20,000 models, the same
    // under `data` behind other things, a text, and a list too far in to be seen.
    let models = r#"{"id":"tide-1","object":"model"},"#.repeat(20_000);
    let long = |text: String| -> &'static str { text.leak() };
    let long_list = long(format!("[{models}{{}}]"));
    let long_data = long(format!(
        r#"{{"object":"list","meta":{{"data":[1],"n":[2,{{}}]}},"data":[{models}{{}}]}}"#
    ));
    let long_text = long(format!(r#"{{"data":"{models:?}"}}"#));
    let far_in = long(format!(r#"{{"about":{models:?},"data":[{{}}]}}"#));
    for (status, kind, body, counts) in [
        (200, JSON, long_list, true),
        (200, JSON, long_data, true),
        (200, JSON, long_text, false),
        (200, JSON, far_in, false),
        (401, JSON, long_list, true),
        (200, HTML, long_list, false),
        (200, JSON, MODELS, true),
        (200, JSON, r#"[{"id":"tide-1"}]"#, true),
        // A list is one where it begins, also one that breaks off.
        (200, JSON, "{\"data\":[", true),
        (200, JSON, r#"{"data":{"data":[]}}"#, false),
        (200, JSON, r#"{"models":[{"id":"tide-1"}]}"#, false),
        (200, JSON, "", false),
        (401, JSON, NO_KEY, true),
        (403, "text/plain", "Forbidden", true),
        // A website answers every address with a page, found or not.
        (200, HTML, "<!doctype html><title>Reed</title>", false),
        (403, HTML, "<html>Forbidden</html>", false),
        (401, "text/plain", "  <html>Sign in</html>", false),
        // JSON that is no list of models, and other ways not to have one.
        (200, JSON, r#"{"status":"ok"}"#, false),
        (404, JSON, NOT_FOUND, false),
        (400, JSON, NO_KEY, false),
        (500, JSON, MODELS, false),
    ] {
        let found = found(vec![says(at, status, kind, body)], "reed.test").await;
        let wanted = if counts { base.clone() } else { Value::Null };
        let start: String = body.chars().take(60).collect();
        assert_eq!(found, wanted, "{status} {kind} {start}");
    }
}

#[tokio::test]
async fn a_list_of_models_is_known_by_its_start_and_not_waited_for() {
    // The list begins and does not end, as one of megabytes on a slow line.
    let endless = Rule {
        endless: true,
        ..says(
            "api.kelp.test/v1/models",
            200,
            JSON,
            r#"{"object":"list","data":[{"id":"tide-1"},"#,
        )
    };
    let places = Places::start(vec![endless]).await;
    let server = places.server().await;
    let started = Instant::now();
    let found = find(&server, "kelp.test").await.1;
    assert_eq!(found["base_url"], "https://api.kelp.test/v1");
    assert!(
        started.elapsed() < Duration::from_secs(5),
        "{:?}",
        started.elapsed()
    );
}

#[tokio::test]
async fn a_page_is_known_by_its_start_and_not_waited_for() {
    // A page that begins and does not end, told by its type and by its first letter.
    for (kind, body) in [(HTML, ""), ("text/plain", "  <!doctype html><title>Silt")] {
        let endless = Rule {
            endless: true,
            ..says("api.silt.test/v1/models", 200, kind, body)
        };
        let places = Places::start(vec![endless]).await;
        let server = places.server().await;
        let started = Instant::now();
        assert_eq!(find(&server, "silt.test").await.1, Value::Null, "{kind}");
        assert!(
            started.elapsed() < Duration::from_secs(5),
            "{kind}: {:?}",
            started.elapsed()
        );
    }
}

#[tokio::test]
async fn a_host_that_answers_every_place_alike_is_no_api() {
    // It refuses whatever is asked for the missing key, as a gateway before an API does.
    let refusing = says("api.marsh.test/", 401, JSON, NO_KEY);
    assert_eq!(found(vec![refusing], "marsh.test").await, Value::Null);
    // Or answers whatever is asked with the same list.
    let listing = says("api.marsh.test/", 200, JSON, MODELS);
    assert_eq!(found(vec![listing], "marsh.test").await, Value::Null);
    // A host that refuses the list alone has an API there.
    let api = says("api.marsh.test/v1/models", 401, JSON, NO_KEY);
    let found = found(vec![api], "marsh.test").await;
    assert_eq!(found["base_url"], "https://api.marsh.test/v1");
}

#[tokio::test]
async fn a_place_that_sends_on_elsewhere_is_not_followed() {
    let onward = Rule {
        onward: Some("/elsewhere.test/v1/models"),
        ..says("api.fen.test/v1/models", 302, JSON, "")
    };
    let rules = vec![onward, says("elsewhere.test/v1/models", 200, JSON, MODELS)];
    let places = Places::start(rules).await;
    let server = places.server().await;
    assert_eq!(find(&server, "fen.test").await.1, Value::Null);
    let elsewhere = |asked: &Asked| asked.place.starts_with("elsewhere.test");
    assert!(
        !places.asked().iter().any(elsewhere),
        "{:?}",
        places.asked()
    );
}

#[tokio::test]
async fn what_is_no_domain_is_refused_and_asked_nowhere() {
    let places = Places::start(vec![says("", 200, JSON, MODELS)]).await;
    let server = places.server().await;
    for website in [
        "",
        "Tidewater",
        "localhost",
        "http://localhost:5001/v1",
        "127.0.0.1",
        "https://10.0.0.7/v1",
        "http://[::1]:8080/",
        "2130706433",
        "ftp://tidewater.test",
        "tide water.test",
        "tide_water.test",
        "tidewater..test",
    ] {
        let (status, refused) = find(&server, website).await;
        assert_eq!(status, 400, "{website}");
        let said = refused["error"].as_str().unwrap();
        assert!(said.contains("such as example.com"), "{website}: {said}");
    }
    assert!(places.asked().is_empty(), "{:?}", places.asked());
}

#[tokio::test]
async fn a_place_that_does_not_answer_is_given_up_after_a_short_wait() {
    let silent = Rule {
        after: Duration::from_secs(120),
        ..says("", 200, JSON, MODELS)
    };
    let places = Places::start(vec![silent]).await;
    let server = places.server().await;
    let started = Instant::now();
    assert_eq!(find(&server, "stillwater.test").await.1, Value::Null);
    assert!(
        started.elapsed() < Duration::from_secs(14),
        "{:?}",
        started.elapsed()
    );
}

#[tokio::test]
async fn a_name_that_leads_to_this_machine_is_not_asked() {
    // The stand-in by its name: the search looks the name up, finds that it
    // leads here, and does not go there.
    let places = Places::start(vec![says(
        "api.tidewater.test/v1/models",
        200,
        JSON,
        MODELS,
    )])
    .await;
    let port = places.url.rsplit_once(':').unwrap().1;
    let by_name = start_asking(Some(format!("http://localhost:{port}"))).await;
    assert_eq!(find(&by_name, "tidewater.test").await.1, Value::Null);
    assert!(places.asked().is_empty(), "{:?}", places.asked());
    // By its address it is asked, and has the API.
    let found = find(&places.server().await, "tidewater.test").await.1;
    assert_eq!(found["base_url"], "https://api.tidewater.test/v1");
}

#[test]
fn a_website_is_read_as_its_domain() {
    for (typed, domain) in [
        ("tidewater.test", "tidewater.test"),
        ("  Tidewater.TEST ", "tidewater.test"),
        ("www.tidewater.test", "tidewater.test"),
        ("tidewater.test.", "tidewater.test"),
        (
            "https://www.tidewater.test/docs/api?lang=en#keys",
            "tidewater.test",
        ),
        ("http://docs.tidewater.test:8443/", "docs.tidewater.test"),
        ("tidewater.test/pricing", "tidewater.test"),
        ("gezeiten-küste.test", "xn--gezeiten-kste-5ob.test"),
    ] {
        assert_eq!(host_of(typed).as_deref(), Some(domain), "{typed}");
    }
    let long = format!("{}.test", ["tidewater"; 24].join("."));
    assert!(
        long.len() <= 253 && host_of(&long).is_none(),
        "too long with a host before it"
    );
}

#[test]
fn the_places_are_https_on_the_domain_and_under_it() {
    let tried = places("tidewater.test");
    assert_eq!(tried.len(), PLACES.len());
    assert_eq!(tried[0], "https://api.tidewater.test/v1");
    assert_eq!(tried[1], "https://tidewater.test/api/v1");
    for place in &tried {
        let address = Url::parse(place).unwrap();
        assert_eq!(address.scheme(), "https", "{place}");
        let host = address.host_str().unwrap();
        assert!(
            host == "tidewater.test" || host.ends_with(".tidewater.test"),
            "{place}"
        );
        assert_eq!(address.port(), None, "{place}");
    }
}

#[tokio::test]
async fn a_name_leads_the_search_to_public_addresses_only() {
    for (address, out) in [
        ("93.184.216.34", true),
        ("8.8.8.8", true),
        ("2606:4700:4700::1111", true),
        ("2a00:1450:4001:81b::200e", true),
        ("2001:200::1", true),
        ("127.0.0.1", false),
        ("127.8.9.1", false),
        ("0.0.0.0", false),
        ("10.1.2.3", false),
        ("172.16.0.1", false),
        ("172.31.255.254", false),
        ("192.168.1.1", false),
        ("169.254.169.254", false),
        ("100.64.0.1", false),
        ("192.0.0.8", false),
        ("198.18.0.1", false),
        ("192.0.2.1", false),
        ("224.0.0.1", false),
        ("255.255.255.255", false),
        ("::1", false),
        ("::", false),
        ("fe80::1", false),
        ("fd00::1", false),
        ("fc00::1", false),
        ("ff02::1", false),
        ("2001:db8::1", false),
        ("3fff::1", false),
        ("fec0::1", false),
        ("100::1", false),
        // An IPv4 address inside another kind of IPv6 address: 6to4, Teredo,
        // the old way of writing one, and NAT64 for a network of one's own.
        ("2002:a9fe:a9fe::1", false),
        ("2001:0:4136:e378:8000:63bf:3fff:fdd2", false),
        ("2001:1ff::1", false),
        ("::7f00:1", false),
        ("64:ff9b:1::a00:1", false),
        ("::ffff:127.0.0.1", false),
        ("::ffff:192.168.1.1", false),
        ("::ffff:8.8.8.8", true),
        ("64:ff9b::a00:1", false),
        ("64:ff9b::808:808", true),
    ] {
        assert_eq!(public(address.parse::<IpAddr>().unwrap()), out, "{address}");
    }
    // This machine's own name leads nowhere the search goes.
    assert!(addresses("localhost", public).await.unwrap().is_empty());
}

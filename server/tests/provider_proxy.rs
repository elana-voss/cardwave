//! The search for a provider's API goes round a proxy: a proxy would look the
//! names up itself, past the check of where they lead. The one test of this
//! file sets the proxy for its whole process, which is why it has a file, and
//! with it a process, of its own.
//!
//! A `reqwest` client of a test goes through that proxy too unless built with
//! `no_proxy()` (seen).

mod common;

use std::sync::{Arc, Mutex};

use axum::Router;
use axum::http::Uri;
use common::server::start_asking;
use serde_json::{Value, json};
use tokio::net::TcpListener;

/// A server that notes what it is asked and answers each time with `body`.
async fn listener(body: &'static str) -> (String, Arc<Mutex<Vec<String>>>) {
    let asked = Arc::new(Mutex::new(Vec::new()));
    let log = asked.clone();
    let answer = move |uri: Uri| async move {
        log.lock().unwrap().push(uri.to_string());
        let found = uri.path().ends_with("/v1/models");
        let status = if found { 200 } else { 404 };
        let json = [("content-type", "application/json")];
        (
            axum::http::StatusCode::from_u16(status).unwrap(),
            json,
            body,
        )
    };
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    tokio::spawn(async {
        axum::serve(listener, Router::new().fallback(answer))
            .await
            .unwrap()
    });
    (url, asked)
}

#[test]
fn the_search_asks_the_places_themselves_and_no_proxy() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let (proxy, through_proxy) = runtime.block_on(listener(r#"{"data":[]}"#));
    // Before anything of the test asks the environment: nothing else runs in
    // this process yet but the runtime's idle threads.
    unsafe {
        std::env::set_var("HTTP_PROXY", &proxy);
        std::env::set_var("http_proxy", &proxy);
        std::env::remove_var("NO_PROXY");
        std::env::remove_var("no_proxy");
    }
    runtime.block_on(async {
        let (places, asked) = listener(r#"{"data":[{"id":"tide-1"}]}"#).await;
        let server = start_asking(Some(places)).await;
        let website = json!({ "website": "tidewater.test" });
        // The test itself asks the server round the proxy too.
        let direct = reqwest::Client::builder().no_proxy().build().unwrap();
        let address = format!("http://{}/api/provider/find", server.addr);
        let answer = direct.post(address).json(&website).send().await.unwrap();
        assert_eq!(answer.status(), 200);
        let found: Value = answer.json().await.unwrap();
        assert_eq!(
            found["base_url"], "https://api.tidewater.test/v1",
            "{found}"
        );
        assert_ne!(*asked.lock().unwrap(), Vec::<String>::new());
        assert_eq!(*through_proxy.lock().unwrap(), Vec::<String>::new());
        assert_eq!(found["name"], Value::Null);
    });
}

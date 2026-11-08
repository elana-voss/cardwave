//! The models that fit this computer (`provider::fit`): Cardwave's list and
//! the folder's own GGUF files, whether each fits, a model of the list
//! downloaded into the folder from a file server of the test's own, its
//! download failing or cancelled, and the model removed.

mod common;

use std::time::Duration;

use axum::Router;
use axum::body::Body;
use axum::routing::get;
use common::server::{Server, WAIT, device, event, start_offering};
use cw_modelfiles::ModelFile;
use cw_provider::embedder::{Runner, Setup};
use cw_provider::fit::Offered;
use futures_util::stream;
use reqwest::Method;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::net::TcpListener;

/// What the file server sends as a model.
const MODEL: &[u8] = b"GGUF a model that fits";

/// A file server: `/model.gguf` is `MODEL`, `/slow.gguf` never ends.
async fn files() -> String {
    let slow = || async {
        let pieces = stream::unfold((), |()| async {
            tokio::time::sleep(Duration::from_millis(50)).await;
            Some((Ok::<_, std::io::Error>(vec![0u8; 16]), ()))
        });
        Body::from_stream(pieces)
    };
    let app = Router::new()
        .route("/model.gguf", get(|| async { MODEL }))
        .route("/slow.gguf", get(slow));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    url
}

fn sum(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

fn offered(name: &str, file_name: &str, url: String, size: u64, sha256: String) -> Offered {
    Offered {
        name: name.into(),
        file_name: file_name.into(),
        file: ModelFile { url, size, sha256 },
    }
}

/// A server offering a small model, one whose file is not what it says, one
/// that never ends and one too large; and its folder of models, chosen, with
/// a GGUF file of the user's own.
async fn started() -> (Server, std::path::PathBuf) {
    let at = files().await;
    let size = MODEL.len() as u64;
    let list = vec![
        offered(
            "Small",
            "small.gguf",
            format!("{at}/model.gguf"),
            size,
            sum(MODEL),
        ),
        offered(
            "Wrong",
            "wrong.gguf",
            format!("{at}/model.gguf"),
            size,
            sum(b"other"),
        ),
        offered(
            "Slow",
            "slow.gguf",
            format!("{at}/slow.gguf"),
            1 << 20,
            sum(b""),
        ),
        offered(
            "Huge",
            "huge.gguf",
            format!("{at}/model.gguf"),
            1 << 50,
            sum(MODEL),
        ),
    ];
    let search = Setup {
        model: ModelFile {
            url: String::new(),
            size: 0,
            sha256: String::new(),
        },
        runner: Runner::At("http://127.0.0.1:9".into()),
    };
    let server = start_offering(search, list).await;
    let folder = server.dir.join("my models");
    std::fs::create_dir_all(&folder).unwrap();
    std::fs::write(folder.join("Own-7B.gguf"), b"GGUF mine").unwrap();
    let (status, view) = server
        .put("/api/this-computer", json!({ "folder": folder }))
        .await;
    assert_eq!(status, 200, "{view}");
    (server, folder)
}

/// The model `file` of the box's list.
async fn model(server: &Server, file: &str) -> Value {
    let (status, view) = server.get("/api/this-computer/models").await;
    assert_eq!(status, 200, "{view}");
    let models = view["models"].as_array().unwrap();
    models
        .iter()
        .find(|one| one["file"] == file)
        .unwrap()
        .clone()
}

/// Waits, over the pushed `local_models`, until the model `file` is `state`.
async fn until(server: &Server, file: &str, state: &str) -> Value {
    let mut socket = server.listen().await;
    tokio::time::timeout(WAIT, async {
        loop {
            let now = model(server, file).await;
            if now["state"] == state {
                return now;
            }
            while event(&mut socket).await["type"] != "local_models" {}
        }
    })
    .await
    .unwrap()
}

#[tokio::test]
async fn the_list_says_which_models_fit_with_the_folders_own() {
    let server = {
        let at = files().await;
        let list = vec![offered("Small", "small.gguf", at, 1, sum(MODEL))];
        let search = Setup::bge_m3(std::path::PathBuf::new());
        start_offering(search, list).await
    };
    // Without a folder there is nothing to list.
    let (status, said) = server.get("/api/this-computer/models").await;
    assert_eq!(status, 400);
    assert!(said.to_string().contains("choose a folder"), "{said}");
    drop(server);

    let (server, _folder) = started().await;
    let (_, view) = server.get("/api/this-computer/models").await;
    assert!(view["memory"].as_u64().unwrap() > 0, "{view}");
    let shown: Vec<(&str, &str, bool, bool, &str)> = view["models"]
        .as_array()
        .unwrap()
        .iter()
        .map(|one| {
            let text = |key: &str| one[key].as_str().unwrap();
            let flag = |key: &str| one[key].as_bool().unwrap();
            (
                text("name"),
                text("file"),
                flag("fits"),
                flag("offered"),
                text("state"),
            )
        })
        .collect();
    assert_eq!(
        shown,
        [
            ("Small", "small.gguf", true, true, "absent"),
            ("Wrong", "wrong.gguf", true, true, "absent"),
            ("Slow", "slow.gguf", true, true, "absent"),
            ("Huge", "huge.gguf", false, true, "absent"),
            ("Own-7B.gguf", "Own-7B.gguf", true, false, "downloaded"),
        ]
    );
    assert_eq!(view["models"][4]["size"], 9);

    // The folder's own model is not removed, nor is a model of no list fetched.
    let path = "/api/this-computer/models/Own-7B.gguf";
    assert_eq!(server.call(Method::DELETE, path, None).await.0, 404);
    assert_eq!(server.post(path, json!({})).await.0, 404);
    // Nor is one too large for this computer.
    let (status, said) = server
        .post("/api/this-computer/models/huge.gguf", json!({}))
        .await;
    assert_eq!(status, 400);
    assert!(said.to_string().contains("too large"), "{said}");

    let mut ada = device(&server, false).await;
    let asked = ada.get("/api/this-computer/models").await;
    assert_eq!(asked.0, 403);
}

#[tokio::test]
async fn a_model_downloaded_is_one_of_the_folders_and_removed_again() {
    let (server, folder) = started().await;
    let (status, _) = server
        .post("/api/this-computer/models/small.gguf", json!({}))
        .await;
    assert_eq!(status, 200);
    let done = until(&server, "small.gguf", "downloaded").await;
    assert_eq!(done["failure"], Value::Null);
    assert_eq!(std::fs::read(folder.join("small.gguf")).unwrap(), MODEL);
    // There, it is not downloaded again.
    let again = "/api/this-computer/models/small.gguf";
    let (status, said) = server.post(again, json!({})).await;
    assert_eq!(status, 400);
    assert!(said.to_string().contains("in the folder already"), "{said}");

    // This computer offers it as a chat model, to be picked for a kind.
    let (_, list) = server.get("/api/provider-list").await;
    let id = &list["providers"][0]["id"];
    let (_, catalog) = server.get(&format!("/api/provider-list/{id}/models")).await;
    let ids: Vec<&str> = catalog["models"]
        .as_array()
        .unwrap()
        .iter()
        .map(|one| one["id"].as_str().unwrap())
        .collect();
    assert_eq!(ids, ["Own-7B.gguf", "small.gguf"]);
    let pick = json!({ "provider_id": id, "model": "small.gguf" });
    assert_eq!(server.put("/api/kinds/chat", pick).await.0, 200);

    let path = "/api/this-computer/models/small.gguf";
    let (status, view) = server.call(Method::DELETE, path, None).await;
    assert_eq!(status, 200, "{view}");
    assert!(!folder.join("small.gguf").exists());
    assert_eq!(model(&server, "small.gguf").await["state"], "absent");
}

#[tokio::test]
async fn a_download_that_fails_says_why_and_one_cancelled_leaves_nothing() {
    let (server, folder) = started().await;
    server
        .post("/api/this-computer/models/wrong.gguf", json!({}))
        .await;
    // Its state and why it failed change together.
    let failed = until(&server, "wrong.gguf", "absent").await;
    assert!(
        failed["failure"].to_string().contains("not the model"),
        "{failed}"
    );
    assert!(!folder.join("wrong.gguf").exists());

    server
        .post("/api/this-computer/models/slow.gguf", json!({}))
        .await;
    assert_eq!(model(&server, "slow.gguf").await["state"], "downloading");
    let path = "/api/this-computer/models/slow.gguf/download";
    assert_eq!(server.call(Method::DELETE, path, None).await.0, 200);
    let cancelled = until(&server, "slow.gguf", "absent").await;
    assert_eq!(cancelled["failure"], Value::Null);
    let left: Vec<_> = std::fs::read_dir(&folder)
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    assert_eq!(left, ["Own-7B.gguf"]);
}

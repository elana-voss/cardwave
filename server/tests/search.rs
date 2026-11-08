//! Search by description: the search model is downloaded when the user asks,
//! checked and kept; it reads every card in pieces; and the library finds a
//! card by its meaning beside its words. No test downloads or runs the real
//! model: `Embedder` is a stand-in that serves a small file as its download
//! and turns a text into a vector of its topics (the sea, space, the forest).
//!
//! `ready` downloads the stand-in's model and waits until it has read every
//! card; `found` is what the library's search lists, by title.

mod common;

use std::path::PathBuf;
use std::time::Duration;

use common::embedder::Embedder;
use common::server::{Server, WAIT, start_searching};
use cw_provider::embedder::{Runner, Setup};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

fn new_card(title: &str, name: &str, description: &str) -> Value {
    json!({
        "title": title, "tags": [name.to_lowercase()], "creator": "", "name": name,
        "greetings": ["Hello."], "description": description, "personality": "",
        "scenario": "", "example_dialogue": "", "creator_notes": "",
    })
}

async fn make(server: &Server, title: &str, name: &str, description: &str) -> i64 {
    let (status, made) = server
        .post("/api/cards/new", new_card(title, name, description))
        .await;
    assert_eq!(status, 201, "{made}");
    made["card_id"].as_i64().unwrap()
}

/// Waits until `done` says yes of the search model's state, and answers it.
async fn until(server: &Server, done: impl Fn(&Value) -> bool) -> Value {
    let end = Instant::now() + WAIT;
    loop {
        let (status, state) = server.get("/api/search").await;
        assert_eq!(status, 200, "{state}");
        if done(&state) {
            return state;
        }
        assert!(Instant::now() < end, "not yet: {state}");
        sleep(Duration::from_millis(20)).await;
    }
}

/// Downloads the model and waits until it has read every card.
async fn ready(server: &Server) -> Value {
    let (status, _) = server.post("/api/search/download", json!({})).await;
    assert_eq!(status, 200);
    until(server, |state| {
        state["state"] == "ready" && state["left"] == 0
    })
    .await
}

async fn found(server: &Server, query: &str) -> Vec<String> {
    let (status, list) = server.get(&format!("/api/cards?q={query}")).await;
    assert_eq!(status, 200, "{list}");
    let titles = list.as_array().unwrap().iter();
    titles
        .map(|card| card["title"].as_str().unwrap().to_string())
        .collect()
}

fn model_file(server: &Server) -> PathBuf {
    server.options().data_dir.join("models").join("bge-m3.gguf")
}

#[tokio::test]
async fn the_model_is_downloaded_when_asked_and_taken_only_as_it_should_be() {
    let stand_in = Embedder::start().await;
    let mut setup = stand_in.setup();
    let server = start_searching(setup.clone()).await;
    let (_, state) = server.get("/api/search").await;
    assert_eq!(
        state,
        json!({ "name": "bge-m3", "size": setup.model.size, "state": "absent", "done": 0, "failure": null, "left": 0 })
    );
    // A connection that drops is taken up again where it stopped.
    stand_in.drop_once();
    let state = ready(&server).await;
    assert_eq!(state["failure"], Value::Null);
    let ranges = stand_in.ranges();
    assert!(
        matches!(ranges[..], [None, Some(from)] if from > 0),
        "{ranges:?}"
    );
    assert_eq!(
        std::fs::metadata(model_file(&server)).unwrap().len(),
        setup.model.size
    );
    // Asked again, the model that is there is not downloaded anew.
    server.post("/api/search/download", json!({})).await;
    assert_eq!(
        until(&server, |state| state["state"] == "ready").await["done"],
        0
    );

    // A file that is not the model is not taken, and says why.
    setup.model.sha256 = "0".repeat(64);
    let other = start_searching(setup).await;
    other.post("/api/search/download", json!({})).await;
    let state = until(&other, |state| state["state"] != "downloading").await;
    assert_eq!(state["state"], "absent");
    assert_eq!(
        (
            &state["failure"]["code"],
            &state["failure"]["details"]["what"]
        ),
        (&json!("not_readable"), &json!("downloaded_model"))
    );
    let models = other.options().data_dir.join("models");
    assert_eq!(std::fs::read_dir(models).unwrap().count(), 0);
}

#[tokio::test]
async fn a_download_is_cancelled_and_the_model_removed() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    stand_in.hold();
    server.post("/api/search/download", json!({})).await;
    let state = until(&server, |state| state["done"].as_u64() > Some(0)).await;
    assert_eq!(state["state"], "downloading");
    let (status, state) = server
        .call(Method::DELETE, "/api/search/download", None)
        .await;
    assert_eq!(status, 200, "{state}");
    let state = until(&server, |state| state["state"] != "downloading").await;
    assert_eq!(
        (&state["state"], &state["failure"]),
        (&json!("absent"), &Value::Null)
    );
    let models = server.options().data_dir.join("models");
    assert_eq!(std::fs::read_dir(models).unwrap().count(), 0);

    let server = start_searching(stand_in_unheld().await.setup()).await;
    ready(&server).await;
    let (status, state) = server.call(Method::DELETE, "/api/search", None).await;
    assert_eq!((status, &state["state"]), (200, &json!("absent")));
    assert!(!model_file(&server).exists());
}

async fn stand_in_unheld() -> Embedder {
    Embedder::start().await
}

#[tokio::test]
async fn the_library_finds_cards_by_their_meaning_beside_their_words() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    make(
        &server,
        "North Light",
        "Mira",
        "She keeps the lighthouse through every storm.",
    )
    .await;
    make(
        &server,
        "Drift",
        "Nova",
        "A starship pilot far from any planet.",
    )
    .await;
    make(
        &server,
        "Ocean Café",
        "Ilse",
        "She serves coffee in a quiet town.",
    )
    .await;
    // Without the model a search goes by the words alone.
    assert_eq!(found(&server, "ocean").await, ["Ocean Café"]);

    ready(&server).await;
    // "ocean" is in no card but one's title, and near the lighthouse in meaning; the card found both ways first.
    assert_eq!(found(&server, "ocean").await, ["Ocean Café", "North Light"]);
    assert_eq!(found(&server, "orbit").await, ["Drift"]);
    // A card found by a part of a word alone ("ship") comes after the one nearest in meaning.
    make(&server, "Shipyard Hall", "Bea", "She sells bread.").await;
    until(&server, |state| state["left"] == 0).await;
    assert_eq!(
        found(&server, "a+ship").await,
        ["North Light", "Shipyard Hall", "Ocean Café"]
    );
    // A search with no meaning near any card finds by the words alone.
    assert_eq!(found(&server, "nova").await, ["Drift"]);
    assert_eq!(found(&server, "teapot").await, Vec::<String>::new());
    // The tags the list can be narrowed by are those of the cards found.
    let (_, tags) = server.get("/api/cards/tags?q=orbit").await;
    assert_eq!(
        tags,
        json!([{ "tag": "nova", "cards": 1, "chosen": false }])
    );

    // A card in the Trash is not found.
    let (_, list) = server.get("/api/cards?q=orbit").await;
    let id = list[0]["id"].as_i64().unwrap();
    let trashed = server
        .patch(&format!("/api/cards/{id}"), json!({ "trashed": true }))
        .await;
    assert_eq!(trashed.0, 200, "{}", trashed.1);
    assert_eq!(found(&server, "orbit").await, Vec::<String>::new());
}

#[tokio::test]
async fn a_card_is_read_whole_in_pieces_and_again_after_an_edit() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    let long = format!("{} END", "word ".repeat(1_100));
    let id = make(&server, "Long", "Wren", &long).await;
    ready(&server).await;
    let read = stand_in.read();
    // The description in pieces of at most 480 words, the last of which has its end.
    let pieces: Vec<&String> = read.iter().filter(|text| text.contains("word")).collect();
    assert_eq!(
        pieces.len(),
        4,
        "{:?}",
        read.iter().map(|t| t.len()).collect::<Vec<_>>()
    );
    assert!(
        pieces
            .iter()
            .all(|piece| piece.split_whitespace().count() <= 480)
    );
    assert!(pieces.last().unwrap().ends_with("END"));
    assert!(read.contains(&"Long, Wren".to_string()) && read.contains(&"wren".to_string()));

    // A search before the edit does not keep the card's vectors from before it.
    assert_eq!(found(&server, "woods").await, Vec::<String>::new());
    let (_, mut edit) = server.get(&format!("/api/cards/{id}/edit")).await;
    edit["characters"][0]["description"][0]["text"] = json!("Under the old trees of the forest.");
    let (status, saved) = server.put(&format!("/api/cards/{id}/edit"), edit).await;
    assert_eq!(status, 200, "{saved}");
    until(&server, |state| state["left"] == 0).await;
    assert_eq!(found(&server, "woods").await, ["Long"]);
}

#[tokio::test]
async fn a_model_that_does_not_run_says_why_and_the_search_goes_by_words() {
    let stand_in = Embedder::start().await;
    let setup = Setup {
        model: stand_in.file(),
        runner: Runner::LlamaServer(PathBuf::from("no-such-folder")),
    };
    let server = start_searching(setup).await;
    make(&server, "North Light", "Mira", "She keeps the lighthouse.").await;
    server.post("/api/search/download", json!({})).await;
    let state = until(&server, |state| state["failure"].is_object()).await;
    assert_eq!(
        (&state["state"], &state["left"]),
        (&json!("ready"), &json!(1))
    );
    let failure = &state["failure"];
    assert_eq!(
        failure["details"]["what"], "llama_server_start",
        "{failure}"
    );
    assert_eq!(found(&server, "north").await, ["North Light"]);
}

#[tokio::test]
async fn a_model_that_fails_is_not_started_again_by_each_page_that_asks() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    make(&server, "North Light", "Mira", "She keeps the lighthouse.").await;
    stand_in.down();
    server.post("/api/search/download", json!({})).await;
    let state = until(&server, |state| state["failure"].is_object()).await;
    assert_eq!(state["left"], 1);
    let asked = stand_in.asked();
    // Pages read the state on each event, and the library's list asks for the cards.
    for _ in 0..5 {
        server.get("/api/search").await;
        assert_eq!(found(&server, "north").await, ["North Light"]);
    }
    sleep(Duration::from_millis(200)).await;
    assert_eq!(stand_in.asked(), asked);
}

#[tokio::test]
async fn a_card_the_model_cannot_read_holds_back_none_after_it_nor_does_a_long_query() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    make(&server, "Bad", "Odd", "POISON in every line.").await;
    make(
        &server,
        "North Light",
        "Mira",
        "She keeps the lighthouse through every storm.",
    )
    .await;
    let state = ready(&server).await;
    assert_eq!(state["failure"], Value::Null);
    // A query longer than the model reads is cut as a card is, and found by meaning.
    let long = vec!["ocean"; 600].join("+");
    assert_eq!(found(&server, &long).await, ["North Light"]);
}

#[tokio::test]
async fn a_providers_search_model_reads_the_cards_without_a_download_and_its_vectors_are_its_own() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    make(
        &server,
        "North Light",
        "Mira",
        "She keeps the lighthouse through every storm.",
    )
    .await;
    make(
        &server,
        "Drift",
        "Nova",
        "A starship pilot far from any planet.",
    )
    .await;
    // A card the provider refuses is kept without vectors; those after it are read.
    make(&server, "Bad", "Poison", "POISON in every line.").await;
    // The stand-in answers in OpenAI's form at `/v1/embeddings`, as a provider does.
    let (status, added) = server
        .post(
            "/api/provider-list",
            json!({ "base_url": format!("{}/v1", stand_in.url) }),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    let at = json!({ "provider_id": added["id"], "model": "embed-1" });
    assert_eq!(server.put("/api/kinds/search", at).await.0, 200);
    until(&server, |state| {
        state["left"] == 0 && state["state"] == "absent"
    })
    .await;
    assert_eq!(found(&server, "ocean").await, ["North Light"]);
    assert!(!model_file(&server).exists());

    // The provider failing holds its model back; its address edited, it is asked again at once.
    stand_in.down();
    make(&server, "Orchard", "Ada", "She grows apples on a dry hill.").await;
    let state = until(&server, |state| state["failure"] != Value::Null).await;
    assert_eq!(state["left"], 1, "{state}");
    stand_in.up();
    let path = format!("/api/provider-list/{}", added["id"]);
    let edit = json!({ "base_url": format!("{}/v1", stand_in.url) });
    assert_eq!(server.patch(&path, edit).await.0, 200);
    until(&server, |state| {
        state["left"] == 0 && state["failure"] == Value::Null
    })
    .await;
    let read = stand_in.read().len();

    // Back to this computer's model, not downloaded: the provider's vectors are not used.
    assert_eq!(
        server
            .call(Method::DELETE, "/api/kinds/search", None)
            .await
            .0,
        200
    );
    assert_eq!(found(&server, "ocean").await, Vec::<String>::new());
    // Downloaded, it reads the cards anew.
    ready(&server).await;
    assert!(stand_in.read().len() > read);
    assert_eq!(found(&server, "ocean").await, ["North Light"]);
}

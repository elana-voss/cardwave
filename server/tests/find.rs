//! Search Cardwave (`GET /api/find`): characters, lorebooks and their entries, chats, personas and documents
//! found by their words, a match in a name before one in a text, whose line is the words in context, and by
//! their meaning after them where the search model reads (the stand-in of `common::embedder`, whose topics are
//! the sea, space and the forest). Memories are found as `memory.rs` tests.
//!
//! `find` answers the hits of a query as (kind, name, line) and `hits` them whole.

mod common;

use std::time::Duration;

use common::embedder::Embedder;
use common::server::{Server, WAIT, start, start_searching};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

async fn hits(server: &Server, query: &str, meaning: bool) -> Vec<Value> {
    let (status, hits) = server
        .get(&format!("/api/find?q={query}&meaning={meaning}"))
        .await;
    assert_eq!(status, 200, "{hits}");
    hits.as_array().unwrap().clone()
}

async fn find(server: &Server, query: &str) -> Vec<(String, String, String)> {
    let found = hits(server, query, false).await;
    found
        .iter()
        .map(|hit| {
            let text = |key: &str| hit[key].as_str().unwrap_or_default().to_string();
            (text("kind"), text("name"), text("line"))
        })
        .collect()
}

fn hit(kind: &str, name: &str, line: &str) -> (String, String, String) {
    (kind.into(), name.into(), line.into())
}

async fn new_card(server: &Server, title: &str, name: &str, description: &str) -> i64 {
    let card = json!({
        "title": title, "tags": [], "creator": "", "name": name, "greetings": ["Hello."],
        "description": description, "personality": "", "scenario": "", "example_dialogue": "", "creator_notes": "",
    });
    let (status, made) = server.post("/api/cards/new", card).await;
    assert_eq!(status, 201, "{made}");
    made["card_id"].as_i64().unwrap()
}

/// A lorebook of the library with one entry. Answers its ID and the entry's reference.
async fn lorebook(server: &Server, name: &str, entry: Value) -> (i64, String) {
    let (status, made) = server
        .post("/api/lorebooks/new", json!({ "name": name }))
        .await;
    assert_eq!(status, 201, "{made}");
    let id = made["id"].as_i64().unwrap();
    let (status, added) = server
        .post(&format!("/api/lorebooks/{id}/entries"), entry)
        .await;
    assert!(status == 200 || status == 201, "{added}");
    (id, added["reference"].as_str().unwrap().to_string())
}

#[tokio::test]
async fn a_character_is_found_by_its_names_and_tags_before_its_texts() {
    let server = start().await;
    let (_, mira) = server.upload("/api/cards", common::card_file()).await;
    let other = new_card(
        &server,
        "Harbor Tales",
        "Odo",
        "Odo once met Mira at the lighthouse, long ago in the bay.",
    )
    .await;

    let found = find(&server, "MIRA").await;
    assert_eq!(
        found,
        [
            hit(
                "character",
                "Mira of the North Light",
                "as Mira · sea · mystery"
            ),
            hit(
                "character",
                "Harbor Tales",
                "Odo once met Mira at the lighthouse, long ago in the bay. Hello."
            ),
        ]
    );
    // The scenario and a greeting are searched, the line cut at a word before the match.
    assert_eq!(
        find(&server, "causeway").await,
        [hit(
            "character",
            "Mira of the North Light",
            "…A storm has cut the causeway. {{user}} is stranded. \"You picked a night for it, {{user}}.\" Hold the lamp. Don't ask."
        )]
    );
    assert_eq!(
        find(&server, "picked night").await[0].1,
        "Mira of the North Light"
    );
    let first = &hits(&server, "sea", false).await[0];
    assert_eq!(
        (&first["id"], &first["picture"]),
        (&mira["card_id"], &mira["version_id"])
    );
    // Every word must be in it; a card in the Trash is not found.
    assert!(find(&server, "odo causeway").await.is_empty());
    let trashed = json!({ "trashed": true });
    let path = format!("/api/cards/{other}");
    assert_eq!(server.patch(&path, trashed).await.0, 200);
    assert_eq!(find(&server, "mira").await.len(), 1);
    assert!(find(&server, "").await.is_empty());
}

#[tokio::test]
async fn a_lorebook_is_found_by_its_name_and_an_entry_by_its_keywords_and_content() {
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let gulls = json!({ "name": "Gulls", "keywords": ["birds"], "content": "They steal the chips of anyone on the pier." });
    let (id, gull) = lorebook(&server, "Harbour Lore", gulls).await;

    assert_eq!(
        find(&server, "harbour").await,
        [hit("lorebook", "Harbour Lore", "1 entry")]
    );
    let found = hits(&server, "birds", false).await;
    assert_eq!(
        (&found[0]["id"], &found[0]["part"], &found[0]["book"]),
        (&json!(id), &json!(gull), &Value::Null)
    );
    assert_eq!(
        find(&server, "chips").await,
        [hit(
            "lorebook",
            "Harbour Lore",
            "Gulls · They steal the chips of anyone on the pier."
        )]
    );
    // A card's own lorebook: its entry names it, opened in the card.
    let found = hits(&server, "asta", false).await;
    assert_eq!(found.len(), 1, "{found:?}");
    assert_eq!(
        (&found[0]["id"], &found[0]["part"], &found[0]["book"]),
        (&card["card_id"], &json!("lore.wreck"), &json!(""))
    );
    assert_eq!(found[0]["line"], "wreck · The Asta sank here in 1911.");

    // An entry changed is found by its new words alone; a lorebook renamed by its new name.
    let path = format!("/api/lorebooks/{id}/entries/{gull}");
    assert_eq!(
        server
            .patch(&path, json!({ "content": "They nest on the roofs." }))
            .await
            .0,
        200
    );
    assert!(find(&server, "chips").await.is_empty());
    assert_eq!(find(&server, "roofs").await.len(), 1);
    assert_eq!(
        server
            .patch(
                &format!("/api/lorebooks/{id}"),
                json!({ "name": "Gull Lore" })
            )
            .await
            .0,
        200
    );
    assert_eq!(
        find(&server, "gull lore").await,
        [hit("lorebook", "Gull Lore", "1 entry")]
    );
    // In the Trash it is not found.
    let path = format!("/api/lorebooks/{id}");
    let (status, body) = server.patch(&path, json!({ "trashed": true })).await;
    assert_eq!(status, 200, "{body}");
    assert!(find(&server, "roofs").await.is_empty());
}

#[tokio::test]
async fn a_chat_is_found_by_its_title_and_characters_not_its_messages() {
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    let chat = view["chat"]["id"].clone();
    server
        .post(
            &format!("/api/chats/{chat}/messages"),
            json!({ "content": "Pineapple" }),
        )
        .await;

    let found = hits(&server, "mira", false).await;
    let chats: Vec<&Value> = found.iter().filter(|hit| hit["kind"] == "chat").collect();
    assert_eq!(chats.len(), 1, "{found:?}");
    assert_eq!(
        (&chats[0]["id"], &chats[0]["names"], &chats[0]["picture"]),
        (&chat, &json!(["Mira"]), &card["version_id"])
    );
    assert!(find(&server, "pineapple").await.is_empty());
    // The first eight words count, as for every other kind.
    let found = hits(
        &server,
        "mira mira mira mira mira mira mira mira pineapple",
        false,
    )
    .await;
    assert!(found.iter().any(|hit| hit["kind"] == "chat"), "{found:?}");
}

#[tokio::test]
async fn a_persona_and_a_document_are_found_by_their_names_and_texts() {
    let server = start().await;
    let made = json!({ "name": "Captain Rell", "description": "A smuggler with a wooden leg and a parrot." });
    let (status, persona) = server.post("/api/personas", made).await;
    assert_eq!(status, 201, "{persona}");
    assert_eq!(
        find(&server, "rell").await,
        [hit(
            "persona",
            "Captain Rell",
            "A smuggler with a wooden leg and a parrot."
        )]
    );
    assert_eq!(
        find(&server, "parrot").await,
        [hit(
            "persona",
            "Captain Rell",
            "…a wooden leg and a parrot."
        )]
    );
    let path = format!("/api/personas/{}", persona["id"]);
    assert_eq!(
        server
            .patch(&path, json!({ "description": "Retired." }))
            .await
            .0,
        200
    );
    assert!(find(&server, "parrot").await.is_empty());

    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let text = format!(
        "{}The stew wants fennel.",
        "Notes of the kitchen and its many pots. ".repeat(3)
    );
    let (status, added) = server
        .upload(
            &format!("/api/cards/{}/documents?name=Recipes.txt", card["card_id"]),
            text.into_bytes(),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    assert_eq!(
        find(&server, "recipes").await,
        [hit("document", "Recipes.txt", "28 words")]
    );
    assert_eq!(
        find(&server, "fennel").await,
        [hit(
            "document",
            "Recipes.txt",
            "…pots. The stew wants fennel."
        )]
    );
}

/// Waits until `query` finds by meaning what `done` says yes of, and answers it.
async fn until_found(server: &Server, query: &str, done: impl Fn(&[Value]) -> bool) -> Vec<Value> {
    let end = Instant::now() + WAIT;
    loop {
        let found = hits(server, query, true).await;
        if done(&found) {
            return found;
        }
        assert!(Instant::now() < end, "not found: {found:?}");
        sleep(Duration::from_millis(20)).await;
    }
}

#[tokio::test]
async fn what_has_no_words_of_the_query_is_found_by_its_meaning_after_what_has() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    let (status, _) = server.post("/api/search/download", json!({})).await;
    assert_eq!(status, 200);
    let keeper = json!({ "name": "Keeper", "keywords": ["lamp"], "content": "Watches the storm from the lighthouse." });
    let (id, entry) = lorebook(&server, "Coast", keeper).await;
    server
        .post(
            "/api/personas",
            json!({ "name": "Sailor", "description": "Sails the waves to the harbor." }),
        )
        .await;
    server
        .post(
            "/api/personas",
            json!({ "name": "Ocean", "description": "Named so." }),
        )
        .await;

    // The words first; by meaning the entry and the other persona after them.
    let found = until_found(&server, "ocean", |found| found.len() >= 3).await;
    let names: Vec<(&Value, &Value)> = found
        .iter()
        .map(|hit| (&hit["kind"], &hit["name"]))
        .collect();
    assert_eq!(
        names,
        [
            (&json!("lorebook"), &json!("Coast")),
            (&json!("persona"), &json!("Ocean")),
            (&json!("persona"), &json!("Sailor"))
        ]
    );
    assert_eq!(
        (&found[0]["line"], &found[0]["part"]),
        (&json!("Keeper"), &json!(entry))
    );
    assert_eq!(hits(&server, "ocean", false).await.len(), 1);

    // An entry changed is read again; one deleted goes.
    let path = format!("/api/lorebooks/{id}/entries/{entry}");
    assert_eq!(
        server
            .patch(
                &path,
                json!({ "content": "Walks among the trees and the moss." })
            )
            .await
            .0,
        200
    );
    until_found(&server, "forest", |found| {
        found.iter().any(|hit| hit["name"] == "Coast")
    })
    .await;
    until_found(&server, "ocean", |found| {
        found.iter().all(|hit| hit["kind"] != "lorebook")
    })
    .await;
    assert_eq!(server.call(Method::DELETE, &path, None).await.0, 200);
    assert!(hits(&server, "forest", true).await.is_empty());
}

#[tokio::test]
async fn a_document_in_the_trash_is_not_found_by_meaning_nor_hides_one_less_near() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    let (status, _) = server.post("/api/search/download", json!({})).await;
    assert_eq!(status, 200);
    let named = |found: &[Value], name: &str| {
        found
            .iter()
            .any(|hit| hit["kind"] == "document" && hit["name"] == name)
    };
    let add = |name: &'static str, text: String| {
        let server = &server;
        async move {
            let card = new_card(server, name, "Mira", "A keeper.").await;
            let path = format!("/api/cards/{card}/documents?name={name}");
            let (status, added) = server.upload(&path, text.into_bytes()).await;
            assert_eq!(status, 201, "{added}");
            card
        }
    };
    // Of the sea, among a hundred other words: near "ocean", not as near as a text of the sea alone.
    let far = (0..100)
        .map(|n| format!("w{n}"))
        .collect::<Vec<_>>()
        .join(" ");
    add("Far.txt", format!("The harbor. {far}")).await;
    until_found(&server, "ocean", |found| named(found, "Far.txt")).await;
    let near = add("Near.txt", "Ocean waves at the harbor.".into()).await;
    until_found(&server, "ocean", |found| {
        named(found, "Near.txt") && !named(found, "Far.txt")
    })
    .await;

    let path = format!("/api/cards/{near}");
    let trashed = json!({ "trashed": true });
    assert_eq!(server.patch(&path, trashed).await.0, 200);
    let found = until_found(&server, "ocean", |found| named(found, "Far.txt")).await;
    assert!(!named(&found, "Near.txt"), "{found:?}");
}

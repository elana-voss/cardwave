//! What the user did to a chat's memories holds: a character or persona
//! renamed, its memories follow the name; the user's own changes and
//! deletions of memories hold when a block is read again. The stand-in
//! provider is `common/memory.rs`'s `Fake`.

mod common;

use common::memory::{
    Fake, chat, fill, memories, memory_of, passes, remembered, reply, say, setup,
};
use common::server::{Server, start};
use cw_ccv4::png;
use reqwest::Method;
use serde_json::{Value, json};

/// The texts Knowledge › Memories lists.
async fn texts(server: &Server) -> Vec<Value> {
    memories(server)
        .await
        .iter()
        .map(|m| m["text"].clone())
        .collect()
}

#[tokio::test]
async fn a_character_renamed_in_its_card_keeps_what_it_knows() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds("PRESENT: Mira\nFACTS:\nmira | home | Mira lives in Saltmere | personal | Mira | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;

    let (_, view) = server.get(&chat).await;
    let card = view["characters"][0]["card_id"].clone();
    let path = format!("/api/cards/{card}/edit");
    let (_, mut form) = server.get(&path).await;
    form["characters"][0]["name"] = json!("Mirabel");
    let (status, saved) = server.put(&path, form).await;
    assert_eq!(status, 200, "{saved}");

    assert_eq!(texts(&server).await, [json!("Mirabel lives in Saltmere")]);
    assert_eq!(memories(&server).await[0]["known_to"], json!(["mirabel"]));
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    let note = memory_of(&prompt).unwrap_or_default();
    assert!(note.contains("Mirabel lives in Saltmere"), "{note}");
}

#[tokio::test]
async fn a_persona_renamed_is_renamed_in_its_memories() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let (status, persona) = server.post("/api/personas", json!({ "name": "Sam" })).await;
    assert_eq!(status, 201, "{persona}");
    let picked = json!({ "persona_id": persona["id"] });
    assert_eq!(server.put(&format!("{chat}/persona"), picked).await.0, 200);
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds("PRESENT: Mira, Sam\nFACTS:\nsam | dog | Sam has a dog called Pip | personal | Mira, Sam | current\nEVENTS:");
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    assert_eq!(texts(&server).await, [json!("Sam has a dog called Pip")]);

    let path = format!("/api/personas/{}", persona["id"]);
    let renamed = json!({ "name": "Samantha" });
    assert_eq!(server.patch(&path, renamed).await.0, 200);

    assert_eq!(
        texts(&server).await,
        [json!("Samantha has a dog called Pip")]
    );
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, json!({})).await;
    let note = memory_of(&prompt).unwrap_or_default();
    assert!(note.contains("Samantha has a dog called Pip"), "{note}");
}

/// The scarf event as Knowledge › Memories shows it.
const SCARF: &str = "Mira gave the user a scarf (cause: gift; result: Mira gives)";

#[tokio::test]
async fn what_the_user_changed_of_a_memory_holds_when_its_block_is_read_again() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    let read = |sister: &str| {
        format!(
            "PRESENT: Mira, Guest\nFACTS:\nuser | sister | {sister} | personal | Mira, Guest | current\nmira | lamp | Mira keeps a red lamp | personal | Mira, Guest | current\nEVENTS:\nMira gave the user a scarf | gift | Mira gives | Mira, Guest | personal"
        )
    };
    fake.finds(&read("The user's sister is called Ana"));
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let list = memories(&server).await;
    let id = |text: &str| {
        let found = list.iter().find(|m| m["text"] == text).expect(text);
        format!("/api/memories/{}", found["id"].as_str().unwrap())
    };
    let (sister, lamp, scarf) = (
        id("The user's sister is called Ana"),
        id("Mira keeps a red lamp"),
        id(SCARF),
    );
    let edited = json!({ "text": "The user's sister is called Beth" });
    assert_eq!(server.patch(&sister, edited).await.0, 200);
    assert_eq!(
        server
            .patch(&scarf, json!({ "known_to": ["Mira"] }))
            .await
            .0,
        200
    );
    assert_eq!(server.call(Method::DELETE, &lamp, None).await.0, 204);

    // A message of the block edited, the block is read again: the helper
    // words the sister anew and finds the lamp and the scarf as before.
    let (_, view) = server.get(&chat).await;
    let third = view["messages"][2]["id"].clone();
    let message = format!("/api/messages/{third}");
    let changed = json!({ "content": "Message three, changed." });
    assert_eq!(server.patch(&message, changed).await.0, 200);
    say(&server, &chat, "And now?").await;
    fake.finds(&read("The user has a sister called Ana"));
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    passes(&fake, 2).await;
    remembered(&mut socket).await;

    let list = memories(&server).await;
    let mut kept: Vec<String> = list.iter().map(|m| m["text"].to_string()).collect();
    kept.sort();
    let kept: Vec<Value> = kept
        .iter()
        .map(|t| serde_json::from_str(t).unwrap())
        .collect();
    assert_eq!(
        kept,
        [json!(SCARF), json!("The user's sister is called Beth")]
    );
    let scarf = list.iter().find(|m| m["text"] == SCARF).unwrap();
    assert_eq!(scarf["known_to"], json!(["mira"]));
}

/// Renames Mira of the chat's card to `name` in the card's editor.
async fn rename_mira(server: &Server, chat: &str, name: &str) {
    let (_, view) = server.get(chat).await;
    let path = format!("/api/cards/{}/edit", view["characters"][0]["card_id"]);
    let (_, mut form) = server.get(&path).await;
    form["characters"][0]["name"] = json!(name);
    let (status, saved) = server.put(&path, form).await;
    assert_eq!(status, 200, "{saved}");
}

const SALTMERE: &str = "PRESENT: Mira\nFACTS:\nmira | home | Mira lives in Saltmere | personal | Mira | current\nEVENTS:";

#[tokio::test]
async fn a_character_with_a_memory_of_two_chats_is_renamed_in_it_once() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    // The sample card with the assistant's mode, in which the character's one memory reads both chats.
    let mut card = common::container();
    let modes = "[meta-info]
modes = [\"Roleplay\", \"Assistant\"]
";
    card.toml[0].1 = card.toml[0].1.replacen(
        "[meta-info]
",
        modes,
        1,
    );
    let (_, card) = server.upload_whole(png::write(&card).unwrap()).await;
    let mut chats = Vec::new();
    for _ in 0..2 {
        let new =
            json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
        let (status, view) = server.post("/api/chats", new).await;
        assert_eq!(status, 201, "{view}");
        chats.push(format!("/api/chats/{}", view["chat"]["id"]));
    }
    let [first, second] = [&chats[0], &chats[1]];
    let mut socket = server.listen().await;
    for chat in [first, second] {
        let mode = json!({ "mode": "assistant" });
        assert_eq!(server.put(&format!("{chat}/mode"), mode).await.0, 200);
        fill(&server, chat, 19).await;
        fake.finds(SALTMERE);
        reply(&server, &fake, &mut socket, chat, json!({})).await;
        remembered(&mut socket).await;
    }

    rename_mira(&server, first, "Mira Vale").await;

    let texts = texts(&server).await;
    assert!(
        texts.contains(&json!("Mira Vale lives in Saltmere")),
        "{texts:?}"
    );
    assert!(
        !texts.iter().any(|t| t.to_string().contains("Vale Vale")),
        "{texts:?}"
    );
}

#[tokio::test]
async fn a_character_renamed_is_renamed_in_its_archived_chats_memories() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(SALTMERE);
    reply(&server, &fake, &mut socket, &chat, json!({})).await;
    remembered(&mut socket).await;
    let archived = json!({ "archived": true });
    assert_eq!(server.patch(&chat, archived).await.0, 200);

    rename_mira(&server, &chat, "Mirabel").await;

    assert_eq!(texts(&server).await, [json!("Mirabel lives in Saltmere")]);
    assert_eq!(memories(&server).await[0]["known_to"], json!(["mirabel"]));
}

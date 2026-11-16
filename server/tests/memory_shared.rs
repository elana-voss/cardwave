//! Which memory a chat's replies are given where it is not the chat's own
//! alone: a character's shared memory, which a chat moved to another persona
//! no longer changes, and a group chat, whose every speaker asks the memory
//! its pass writes. The stand-in provider is `common/memory.rs`'s `Fake`.

mod common;

use common::memory::{
    Fake, NOTHING, card_in_modes, chat_of, fill, memory_of, remembered, reply, say, setup,
};
use common::server::start;
use serde_json::json;

/// The helper's answer that finds the fact `fact` of Mira under `key`.
fn finding(key: &str, fact: &str) -> String {
    format!("PRESENT: Mira\nFACTS:\nmira | {key} | {fact} | personal | Mira | current\nEVENTS:")
}

#[tokio::test]
async fn a_chat_moved_to_another_persona_leaves_the_shared_memory_of_the_first_as_it_was() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    let card = card_in_modes(&server, &["Assistant"]).await;
    let x = chat_of(&server, &[(&card, "mira")]).await;
    let y = chat_of(&server, &[(&card, "mira")]).await;
    let mut socket = server.listen().await;
    // The shared memory reads X's first block, Y's, then X's second.
    for (chat, n, fact) in [
        (&x, 19, "Mira lives in Saltmere"),
        (&y, 19, "Mira keeps a cat"),
        (&x, 39, "Mira mends nets"),
    ] {
        fill(&server, chat, n).await;
        fake.finds(&finding(&fact.replace(' ', "-"), fact));
        reply(&server, &fake, &mut socket, chat, json!({})).await;
        remembered(&mut socket).await;
    }

    // Y goes to another persona, then a message of its first block changes there.
    let (_, bea) = server
        .post("/api/personas", json!({ "name": "Bea", "description": "" }))
        .await;
    let persona = json!({ "persona_id": bea["id"] });
    assert_eq!(server.put(&format!("{y}/persona"), persona).await.0, 200);
    let third = server.get(&y).await.1["messages"][2]["id"].clone();
    let changed = json!({ "content": "Message three, changed." });
    let (status, edited) = server
        .patch(&format!("/api/messages/{third}"), changed)
        .await;
    assert_eq!(status, 200, "{edited}");

    // X, still with no persona, is given all its memory held.
    fake.finds(NOTHING);
    say(&server, &x, "And now?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &x, json!({})).await;
    let note = memory_of(&prompt).unwrap_or_default();
    for fact in [
        "Mira lives in Saltmere",
        "Mira keeps a cat",
        "Mira mends nets",
    ] {
        assert!(note.contains(fact), "{fact}: {note}");
    }
}

#[tokio::test]
async fn in_a_group_chat_each_speaker_is_given_the_memory_the_chats_pass_writes() {
    let server = start().await;
    let fake = Fake::start().await;
    setup(&server, &fake).await;
    // The first card is in roleplay, so the chat's memory is its own; the
    // second has a personal mode alone.
    let roleplay = card_in_modes(&server, &["Roleplay"]).await;
    let assistant = card_in_modes(&server, &["Assistant"]).await;
    let chat = chat_of(&server, &[(&roleplay, "mira"), (&assistant, "mira")]).await;
    let second = server.get(&chat).await.1["characters"][1]["id"].clone();
    let by_second = json!({ "speaker_id": second });
    let mut socket = server.listen().await;
    fill(&server, &chat, 19).await;
    fake.finds(&finding("home", "Mira lives in Saltmere"));
    reply(&server, &fake, &mut socket, &chat, by_second.clone()).await;
    remembered(&mut socket).await;

    fake.finds(NOTHING);
    say(&server, &chat, "And now?").await;
    let (_, prompt) = reply(&server, &fake, &mut socket, &chat, by_second).await;
    let note = memory_of(&prompt).unwrap_or_default();
    assert!(note.contains("Mira lives in Saltmere"), "{note}");
}

//! A message deleted from the branch in view, with its versions and all that
//! follows it, and put back by the deletion's Undo. Over HTTP, on chats with
//! the sample card's Mira (and `bare`, for a chat of two), whose messages the
//! tests write themselves: a character's message is sent with the role
//! `assistant`, so no model is asked. `texts` reads the branch in view.

mod common;

use common::server::{Server, event, start};
use reqwest::Method;
use serde_json::{Value, json};

/// The sample card's first greeting, as a chat shows it.
const GREETING: &str = "\"You picked a night for it, User.\"";

/// The texts of the branch in view, oldest first.
fn texts(view: &Value) -> Vec<&str> {
    view["messages"]
        .as_array()
        .unwrap()
        .iter()
        .map(|message| message["content"].as_str().unwrap())
        .collect()
}

/// Starts a chat with the sample card's characters named. Returns its address and its view.
async fn chat_with(server: &Server, characters: &[&str]) -> (String, Value) {
    let (_, version) = server.add_card(common::card_file(), true).await;
    let cast: Vec<_> = characters.iter().map(|id| (version, *id)).collect();
    let view = server.chat_with(&cast, 0).await;
    (format!("/api/chats/{}", view["chat"]["id"]), view)
}

/// Sends a message into the chat; `role` "assistant" is a character's. Returns its ID.
async fn say(server: &Server, chat: &str, role: &str, content: &str) -> i64 {
    let (status, message) = server
        .post(
            &format!("{chat}/messages"),
            json!({ "content": content, "role": role }),
        )
        .await;
    assert_eq!(status, 201, "{message}");
    message["id"].as_i64().unwrap()
}

async fn delete(server: &Server, message: i64) -> (u16, Value) {
    server
        .call(Method::DELETE, &format!("/api/messages/{message}"), None)
        .await
}

async fn restore(server: &Server, message: i64) -> (u16, Value) {
    server
        .post(&format!("/api/messages/{message}/restore"), json!({}))
        .await
}

#[tokio::test]
async fn a_message_is_deleted_with_what_follows_it_and_put_back() {
    let server = start().await;
    let (chat, _) = chat_with(&server, &["mira"]).await;
    let asked = say(&server, &chat, "user", "Why tonight?").await;
    let answer = say(&server, &chat, "assistant", "The tide.").await;
    let more = say(&server, &chat, "user", "And then?").await;
    // A second version of the answer, and the first one in view again.
    let (_, other) = server
        .post(
            &format!("/api/messages/{answer}/swipes"),
            json!({ "content": "The moon." }),
        )
        .await;
    let other = other["id"].as_i64().unwrap();
    server
        .put(&format!("{chat}/head"), json!({ "message_id": more }))
        .await;

    // The answer goes in all its versions, with what follows it, and the chat goes on from the question.
    let (status, view) = delete(&server, answer).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(texts(&view), [GREETING, "Why tonight?"]);
    assert_eq!(view["chat"]["head_id"], asked);
    assert_eq!(server.get(&chat).await.1, view);
    // What is deleted is not there for anything else.
    assert_eq!(
        server
            .patch(&format!("/api/messages/{more}"), json!({ "content": "x" }))
            .await
            .0,
        404
    );
    assert_eq!(
        server
            .post(
                &format!("/api/messages/{other}/swipes"),
                json!({ "content": "x" })
            )
            .await
            .0,
        404
    );
    let (status, _) = server
        .put(&format!("{chat}/head"), json!({ "message_id": more }))
        .await;
    assert_eq!(status, 400);
    assert_eq!(delete(&server, answer).await.0, 404);

    // A new message after the question stands alone, then beside the answer put back.
    let instead = say(&server, &chat, "assistant", "No reason.").await;
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["messages"][2]["swipes"], json!([instead]));
    let (status, view) = restore(&server, answer).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(
        texts(&view),
        [GREETING, "Why tonight?", "The tide.", "And then?"]
    );
    assert_eq!(view["chat"]["head_id"], more);
    assert_eq!(
        view["messages"][2]["swipes"],
        json!([answer, other, instead])
    );
    // Put back once is put back: there is nothing more to put back.
    assert_eq!(restore(&server, answer).await.0, 404);
    assert_eq!(restore(&server, more).await.0, 404);
}

#[tokio::test]
async fn a_deletion_is_put_back_until_the_next_one_in_its_chat() {
    let server = start().await;
    let (chat, view) = chat_with(&server, &["mira"]).await;
    let greeting = view["messages"][0]["id"].as_i64().unwrap();
    let asked = say(&server, &chat, "user", "Why tonight?").await;
    let answer = say(&server, &chat, "assistant", "The tide.").await;

    assert_eq!(delete(&server, answer).await.0, 200);
    // The next deletion deletes the one before for good.
    let (status, view) = delete(&server, asked).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(texts(&view), [GREETING]);
    assert_eq!(restore(&server, answer).await.0, 404);
    let (_, view) = restore(&server, asked).await;
    assert_eq!(texts(&view), [GREETING, "Why tonight?"]);
    assert_eq!(view["chat"]["head_id"], asked);

    // The first message goes too, and the chat is empty until it is put back or one is sent.
    let (_, view) = delete(&server, greeting).await;
    assert_eq!(
        (texts(&view).len(), &view["chat"]["head_id"]),
        (0, &Value::Null)
    );
    let (_, view) = restore(&server, greeting).await;
    assert_eq!(texts(&view).len(), 2);

    // A message that is not in view, or not there at all, is not deleted.
    let (_, other) = server
        .post(
            &format!("/api/messages/{asked}/swipes"),
            json!({ "content": "Why now?" }),
        )
        .await;
    server
        .put(&format!("{chat}/head"), json!({ "message_id": asked }))
        .await;
    let (status, refused) = delete(&server, other["id"].as_i64().unwrap()).await;
    assert_eq!(status, 400, "{refused}");
    assert_eq!(delete(&server, 999).await.0, 404);

    // A chat in the Trash is only read.
    server.patch(&chat, json!({ "trashed": true })).await;
    assert_eq!(delete(&server, asked).await.0, 400);
    server.patch(&chat, json!({ "trashed": false })).await;

    // A restart deletes for good what was deleted.
    let (_, view) = delete(&server, asked).await;
    assert_eq!(texts(&view).len(), 1);
    let server = server.restart().await;
    assert_eq!(restore(&server, asked).await.0, 404);
}

#[tokio::test]
async fn one_version_of_a_reply_is_deleted_with_what_follows_it_and_put_back() {
    let server = start().await;
    let (chat, _) = chat_with(&server, &["mira"]).await;
    let asked = say(&server, &chat, "user", "Why tonight?").await;
    let answer = say(&server, &chat, "assistant", "The tide.").await;
    let more = say(&server, &chat, "user", "And then?").await;
    let (_, other) = server
        .post(
            &format!("/api/messages/{answer}/swipes"),
            json!({ "content": "The moon." }),
        )
        .await;
    let other = other["id"].as_i64().unwrap();
    server
        .put(&format!("{chat}/head"), json!({ "message_id": more }))
        .await;
    let only = |id: i64| format!("/api/messages/{id}/version");

    // The version after it is shown, where none is before it.
    let (status, view) = server.call(Method::DELETE, &only(answer), None).await;
    assert_eq!(status, 200, "{view}");
    assert_eq!(texts(&view), [GREETING, "Why tonight?", "The moon."]);
    assert_eq!(view["messages"][2]["swipes"], json!([other]));
    let (_, view) = restore(&server, answer).await;
    assert_eq!(view["chat"]["head_id"], more);
    assert_eq!(view["messages"][2]["swipes"], json!([answer, other]));

    // Else the one before it, with the branch last written in under it; a reply alone goes whole.
    server
        .put(&format!("{chat}/head"), json!({ "message_id": other }))
        .await;
    let (_, view) = server.call(Method::DELETE, &only(other), None).await;
    assert_eq!(
        texts(&view),
        [GREETING, "Why tonight?", "The tide.", "And then?"]
    );
    let (_, view) = server.call(Method::DELETE, &only(answer), None).await;
    assert_eq!(texts(&view), [GREETING, "Why tonight?"]);
    assert_eq!(view["chat"]["head_id"], asked);
}

#[tokio::test]
async fn deleted_messages_are_not_exported() {
    let server = start().await;
    let (chat, _) = chat_with(&server, &["mira"]).await;
    say(&server, &chat, "user", "Why tonight?").await;
    let answer = say(&server, &chat, "assistant", "The tide.").await;
    delete(&server, answer).await;
    say(&server, &chat, "assistant", "No reason.").await;
    let (_, file) = server.download(&format!("{chat}/export")).await;
    let file = String::from_utf8(file).unwrap();
    assert!(
        file.contains("No reason.") && !file.contains("The tide."),
        "{file}"
    );
}

#[tokio::test]
async fn a_character_whose_messages_are_all_deleted_can_leave() {
    let server = start().await;
    let (chat, view) = chat_with(&server, &["mira", "bare"]).await;
    let bare = view["characters"][1]["id"].as_i64().unwrap();
    say(&server, &chat, "user", "Who are you?").await;
    let (_, said) = server
        .post(
            &format!("{chat}/messages"),
            json!({ "content": "Nobody.", "role": "assistant", "speaker_id": bare }),
        )
        .await;
    let said = said["id"].as_i64().unwrap();
    assert_eq!(server.get(&chat).await.1["characters"][1]["written"], true);

    let (_, view) = delete(&server, said).await;
    assert_eq!(view["characters"][1]["written"], false);
    let (status, view) = server
        .call(
            Method::DELETE,
            &format!("/api/chat-characters/{bare}"),
            None,
        )
        .await;
    assert_eq!(status, 200, "{view}");
    // Its messages are gone for good with it, so nothing comes back under another's name.
    assert_eq!(restore(&server, said).await.0, 404);
}

#[tokio::test]
async fn every_other_page_is_told_of_a_message_deleted_or_put_back() {
    let server = start().await;
    let (chat, view) = chat_with(&server, &["mira"]).await;
    let asked = say(&server, &chat, "user", "Why tonight?").await;
    let (mut other, mut own) = (server.listen().await, server.listen_as("own").await);
    let told = json!({ "type": "messages", "chat_id": view["chat"]["id"] });

    // Deleted by the page "own", put back by another.
    let path = format!("/api/messages/{asked}");
    let deleted = server
        .call_as("own", Method::DELETE, &path, json!({}))
        .await;
    assert_eq!(deleted.0, 200, "{}", deleted.1);
    assert_eq!(event(&mut other).await, told);
    assert_eq!(restore(&server, asked).await.0, 200);
    assert_eq!(event(&mut other).await, told);

    // The page that deleted it hears only of the putting back, then of what comes next.
    assert_eq!(event(&mut own).await, told);
    assert_eq!(
        server
            .patch("/api/settings", json!({ "export_history": true }))
            .await
            .0,
        200
    );
    assert_eq!(event(&mut own).await, json!({ "type": "settings" }));
}

#[tokio::test]
async fn every_other_page_is_told_of_a_message_sent_and_a_chat_changed() {
    let server = start().await;
    let (_, version) = server.add_card(common::card_file(), true).await;
    let (mut other, mut own) = (server.listen().await, server.listen_as("own").await);
    let cast = json!({ "characters": [{ "version_id": version, "character": "mira" }] });
    let (status, view) = server
        .call_as("own", Method::POST, "/api/chats", cast)
        .await;
    assert_eq!(status, 201, "{view}");
    let id = view["chat"]["id"].clone();
    let chat = format!("/api/chats/{id}");
    let told = json!({ "type": "chat", "id": id });
    assert_eq!(event(&mut other).await, told);

    // A message sent, the chat renamed, starred, put in the Trash and deleted for good, each by "own".
    let said = json!({ "content": "Why tonight?", "role": "user" });
    let sent = server
        .call_as("own", Method::POST, &format!("{chat}/messages"), said)
        .await;
    assert_eq!(sent.0, 201, "{}", sent.1);
    assert_eq!(
        event(&mut other).await,
        json!({ "type": "messages", "chat_id": id })
    );
    let title = json!({ "title": "Storm" });
    let renamed = server
        .call_as("own", Method::PUT, &format!("{chat}/title"), title)
        .await;
    assert_eq!(renamed.0, 200, "{}", renamed.1);
    assert_eq!(event(&mut other).await, told);
    let starred = json!({ "favorite": true });
    assert_eq!(
        server.call_as("own", Method::PATCH, &chat, starred).await.0,
        200
    );
    assert_eq!(event(&mut other).await, told);
    let trashed = json!({ "trashed": true });
    assert_eq!(
        server.call_as("own", Method::PATCH, &chat, trashed).await.0,
        200
    );
    assert_eq!(event(&mut other).await, told);
    assert_eq!(event(&mut other).await, json!({ "type": "trash" }));
    let gone = server
        .call_as("own", Method::DELETE, &chat, json!({}))
        .await;
    assert_eq!(gone.0, 204, "{}", gone.1);
    assert_eq!(event(&mut other).await, told);
    assert_eq!(event(&mut other).await, json!({ "type": "trash" }));

    // The page that made them hears none of it, only what another page does next.
    assert_eq!(
        server
            .patch("/api/settings", json!({ "export_history": true }))
            .await
            .0,
        200
    );
    assert_eq!(event(&mut own).await, json!({ "type": "settings" }));
}

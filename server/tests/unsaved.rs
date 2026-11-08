//! Unsaved edits (`unsaved`): kept per field and user, replaced, and gone when an empty one is kept.

mod common;

use common::server::start;
use serde_json::{Value, json};

#[tokio::test]
async fn an_unsaved_text_is_kept_per_field_until_an_empty_one_is() {
    let server = start().await;
    assert_eq!(server.get("/api/unsaved/chat.1").await, (200, Value::Null));
    let (status, _) = server
        .put("/api/unsaved/chat.1", json!({ "text": "Half a" }))
        .await;
    assert_eq!(status, 204);
    server
        .put("/api/unsaved/chat.1", json!({ "text": "Half a thought" }))
        .await;
    server
        .put("/api/unsaved/message.4", json!({ "text": "Other" }))
        .await;
    assert_eq!(
        server.get("/api/unsaved/chat.1").await,
        (200, json!({ "text": "Half a thought" }))
    );
    server
        .put("/api/unsaved/chat.1", json!({ "text": "" }))
        .await;
    assert_eq!(server.get("/api/unsaved/chat.1").await, (200, Value::Null));
    assert_eq!(
        server.get("/api/unsaved/message.4").await,
        (200, json!({ "text": "Other" }))
    );
    let long = "x".repeat(201);
    let (status, _) = server
        .put(&format!("/api/unsaved/{long}"), json!({ "text": "a" }))
        .await;
    assert_eq!(status, 400);
    let (status, _) = server
        .put(
            "/api/unsaved/chat.1",
            json!({ "text": "x".repeat(400_001) }),
        )
        .await;
    assert_eq!(status, 400);
}

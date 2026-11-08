//! Backups restored (`api/backup.rs`) while other work is under way on the data, which would write into the
//! restored data by the old data's ids: the restore waits for it. The backups themselves: `password.rs`.

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::api::{Api, JSON, Says, says};
use common::server::{answer, start};
use serde_json::json;

/// A backup is not restored while a picture is being made: the picture's message would go into the
/// restored data by the old data's number of the chat. The image model takes seconds to answer.
#[tokio::test]
async fn a_backup_waits_for_a_picture_being_made() {
    let words = json!({ "choices": [{ "message": { "content": "lighthouse" } }] });
    let worker = Api::start(says(200, JSON, &words.to_string())).await;
    let picture = json!({ "data": [{ "b64_json": STANDARD.encode(common::picture()) }] });
    let slow = Says {
        after: std::time::Duration::from_secs(3),
        ..says(200, JSON, &picture.to_string())
    };
    let image = Api::start_each(vec![says(404, JSON, "{}"), slow]).await;
    let server = start().await;
    let provider = json!({ "base_url": worker.url, "model": "small-1", "api_key": "sk-chat" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let own =
        json!({ "model": "dall-e-3", "base_url": image.url, "api_key": "sk-image-0123456789" });
    assert_eq!(server.set_images(own).await.0, 200);
    let file = server
        .save_backup(Some("harbour"))
        .await
        .bytes()
        .await
        .unwrap();

    let asked = format!(
        "http://{}/api/chats/{}/picture",
        server.addr, view["chat"]["id"]
    );
    let making = tokio::spawn(async move {
        let sent = reqwest::Client::new().post(asked).json(&json!({})).send();
        sent.await.unwrap().status().as_u16()
    });
    tokio::time::sleep(std::time::Duration::from_millis(800)).await;
    let restoring = reqwest::Client::new()
        .post(format!("http://{}/api/backup", server.addr))
        .header("x-cardwave-password", "harbour")
        .body(file);
    let (status, said) = answer(restoring.send().await.unwrap()).await;
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
    assert_eq!(making.await.unwrap(), 201);
}

/// A backup is not restored while a card's picture is being made: the picture would go into the restored
/// data by the old data's number of the card. The image model takes seconds to answer.
#[tokio::test]
async fn a_backup_waits_for_a_cards_picture_being_made() {
    // A card keeps no picture of a single pixel, so this one is larger.
    let mut png = std::io::Cursor::new(Vec::new());
    image::RgbImage::from_pixel(20, 30, image::Rgb([200, 120, 40]))
        .write_to(&mut png, image::ImageFormat::Png)
        .unwrap();
    let picture = json!({ "data": [{ "b64_json": STANDARD.encode(png.into_inner()) }] });
    let slow = Says {
        after: std::time::Duration::from_secs(3),
        ..says(200, JSON, &picture.to_string())
    };
    let image = Api::start_each(vec![says(404, JSON, "{}"), slow]).await;
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let own =
        json!({ "model": "dall-e-3", "base_url": image.url, "api_key": "sk-image-0123456789" });
    assert_eq!(server.set_images(own).await.0, 200);
    let file = server
        .save_backup(Some("harbour"))
        .await
        .bytes()
        .await
        .unwrap();

    let asked = format!(
        "http://{}/api/cards/{}/pictures/made",
        server.addr, card["card_id"]
    );
    let making = tokio::spawn(async move {
        let sent = reqwest::Client::new()
            .post(asked)
            .json(&json!({ "words": "a lighthouse at night" }))
            .send();
        answer(sent.await.unwrap()).await
    });
    tokio::time::sleep(std::time::Duration::from_millis(800)).await;
    let restoring = reqwest::Client::new()
        .post(format!("http://{}/api/backup", server.addr))
        .header("x-cardwave-password", "harbour")
        .body(file);
    let (status, said) = answer(restoring.send().await.unwrap()).await;
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
    let (status, made) = making.await.unwrap();
    assert_eq!(status, 201, "{made}");
}

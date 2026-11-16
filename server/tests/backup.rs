//! Backups restored (`api/backup.rs`) while other work is under way on the data, which would write into the
//! restored data by the old data's ids: the restore waits for it. The backups themselves: `password.rs`.

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::api::{Api, JSON, held, says};
use common::model::{Model, SLOW_TITLE, next_event, stream, text_piece};
use common::server::{answer, start};
use serde_json::json;

/// A backup is not restored while a picture is being made: the picture's message would go into the
/// restored data by the old data's number of the chat. The image model answers once the test lets it.
#[tokio::test]
async fn a_backup_waits_for_a_picture_being_made() {
    let words = json!({ "choices": [{ "message": { "content": "lighthouse" } }] });
    let worker = Api::start(says(200, JSON, &words.to_string())).await;
    let picture = json!({ "data": [{ "b64_json": STANDARD.encode(common::picture()) }] });
    let held = held(says(200, JSON, &picture.to_string()));
    let image = Api::start_each(vec![says(404, JSON, "{}"), held]).await;
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
        let sent = common::server::client().post(asked).json(&json!({})).send();
        sent.await.unwrap().status().as_u16()
    });
    image.until_asked(2).await;
    let (status, said) = server.restore(file, Some("harbour")).await;
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
    image.release();
    assert_eq!(making.await.unwrap(), 201);
}

/// A backup is not restored while a card's picture is being made: the picture would go into the restored
/// data by the old data's number of the card. The image model answers once the test lets it.
#[tokio::test]
async fn a_backup_waits_for_a_cards_picture_being_made() {
    // A card keeps no picture of a single pixel, so this one is larger.
    let mut png = std::io::Cursor::new(Vec::new());
    image::RgbImage::from_pixel(20, 30, image::Rgb([200, 120, 40]))
        .write_to(&mut png, image::ImageFormat::Png)
        .unwrap();
    let picture = json!({ "data": [{ "b64_json": STANDARD.encode(png.into_inner()) }] });
    let held = held(says(200, JSON, &picture.to_string()));
    let image = Api::start_each(vec![says(404, JSON, "{}"), held]).await;
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
        let sent = common::server::client()
            .post(asked)
            .json(&json!({ "words": "a lighthouse at night" }))
            .send();
        answer(sent.await.unwrap()).await
    });
    image.until_asked(2).await;
    let (status, said) = server.restore(file, Some("harbour")).await;
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
    image.release();
    let (status, made) = making.await.unwrap();
    assert_eq!(status, 201, "{made}");
}

/// A backup is not restored while a folder of cards is imported: the cards still to come would go into the
/// restored data under the old data's number of the account. The test holds the database's write lock, so
/// the import's two files that are no cards each wait for it to be noted (the store's busy timeout of 5 s):
/// the restore is asked within the import's run of at least 10 s.
#[tokio::test]
async fn a_backup_waits_for_a_folder_of_cards_being_imported() {
    let server = start().await;
    let folder = common::Folder::new("restore-import");
    std::fs::write(folder.0.join("card.png"), common::card_file()).unwrap();
    for name in ["not-a-card-1.png", "not-a-card-2.png"] {
        std::fs::write(folder.0.join(name), b"no picture").unwrap();
    }
    let options = server.options();
    let db = cw_store::Db::open(
        &options.data_dir.join(cw_key::FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    let file = server
        .save_backup(Some("harbour"))
        .await
        .bytes()
        .await
        .unwrap();
    db.with(|c| c.execute_batch("begin immediate")).unwrap();
    let begun = json!({ "folder": folder.path() });
    assert_eq!(server.post("/api/card-folder/import", begun).await.0, 202);
    let (status, said) = server.restore(file, Some("harbour")).await;
    db.with(|c| c.execute_batch("rollback")).unwrap();
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
}

/// A backup is not restored while a chat is being titled: the title would go into the restored data's chat
/// of that number. The worker model takes seconds to answer.
#[tokio::test]
async fn a_backup_waits_for_a_chat_being_titled() {
    let model = Model::start(vec![(200, stream(&[text_piece("Hello.")]))]).await;
    let server = start().await;
    let provider = json!({ "base_url": model.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let file = server
        .save_backup(Some("harbour"))
        .await
        .bytes()
        .await
        .unwrap();
    let (_, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let mut socket = server.listen().await;
    let asked = json!({ "content": format!("Plan a trip. {SLOW_TITLE}") });
    assert_eq!(server.post(&format!("{chat}/messages"), asked).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    while next_event(&mut socket).await["type"] != "reply_ended" {}

    let (status, said) = server.restore(file, Some("harbour")).await;
    assert_eq!(
        (status, said["code"].as_str()),
        (400, Some("restore_busy")),
        "{said}"
    );
}

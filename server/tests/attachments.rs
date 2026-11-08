//! What the user attaches to a message (`attachments`, `api/attachments.rs`):
//! a picture, taken only where the chat model sees, and a document, kept for
//! the chat in Knowledge › Documents too; both wait for the message, go with it
//! when it is sent, a picture to the model with its message, a document whole
//! into the reply to its message. No test
//! asks a provider: `Api` stand-ins answer in turn, the first the question
//! whether the model sees.

mod common;

use common::api::{Api, JSON, Says, says};
use common::server::{Server, start};
use serde_json::{Value, json};

const REPLY: &str =
    "data: {\"choices\":[{\"delta\":{\"content\":\"A lamp.\"}}]}\n\ndata: [DONE]\n\n";

/// A model's answer to whether it sees: a word.
fn seen() -> Says {
    says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": "Grey." } }] }).to_string(),
    )
}

/// A chat with Mira at the stand-in `api`. Answers its address.
async fn chat_at(server: &Server, api: &Api) -> String {
    let provider = json!({ "base_url": api.url, "model": "test-model", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    format!("/api/chats/{}", view["chat"]["id"])
}

#[tokio::test]
async fn a_picture_goes_with_its_message_to_a_model_that_sees() {
    let server = start().await;
    let api = Api::start_each(vec![seen(), says(200, "text/event-stream", REPLY)]).await;
    let chat = chat_at(&server, &api).await;

    let (status, attached) = server
        .upload(
            &format!("{chat}/attachments?name=lamp.png"),
            common::picture(),
        )
        .await;
    assert_eq!(status, 201, "{attached}");
    assert_eq!(
        (&attached["name"], &attached["picture"]),
        (&json!("lamp.png"), &json!(true))
    );
    // The model was asked once, with a picture, whether it sees.
    assert!(api.asked()[0].body.contains("data:image/png;base64,"));
    let id = attached["id"].as_i64().unwrap();
    let (headers, picture) = server.download(&format!("/api/attachments/{id}")).await;
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!(picture, common::picture());

    // A message of the picture alone is sent; the picture is the message's, and no other can take it.
    let send = json!({ "content": "", "attachments": [id] });
    let (status, message) = server.post(&format!("{chat}/messages"), send.clone()).await;
    assert_eq!(status, 201, "{message}");
    assert_eq!(
        message["attachments"],
        json!([{ "id": id, "name": "lamp.png", "picture": true }])
    );
    let (status, said) = server.post(&format!("{chat}/messages"), send).await;
    assert_eq!(status, 404, "{said}");

    let (status, _) = server.post(&format!("{chat}/generate"), json!({})).await;
    assert_eq!(status, 202);
    let asked = until_asked(&api, 2).await;
    let body: Value = serde_json::from_str(&asked).unwrap();
    let messages = body["messages"].as_array().unwrap();
    let mine = messages
        .iter()
        .find(|message| message["content"].is_array())
        .expect("no message with a picture");
    assert_eq!(mine["role"], "user");
    // A message of the picture alone has no text part.
    assert_eq!(mine["content"].as_array().unwrap().len(), 1);
    assert_eq!(mine["content"][0]["type"], "image_url");
    assert!(
        mine["content"][0]["image_url"]["url"]
            .as_str()
            .unwrap()
            .starts_with("data:image/png;base64,")
    );
    let (_, view) = server.get(&chat).await;
    let sent = &view["messages"].as_array().unwrap()[1];
    assert_eq!(sent["attachments"][0]["id"], id);
}

/// The body of the `count`th asking of `api`, waited for.
async fn until_asked(api: &Api, count: usize) -> String {
    for _ in 0..250 {
        if let Some(asked) = api.asked().get(count - 1) {
            return asked.body.clone();
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    panic!("the model was not asked");
}

#[tokio::test]
async fn a_model_that_cannot_see_takes_no_picture_and_says_so() {
    let server = start().await;
    let refused = says(
        400,
        JSON,
        r#"{"error":{"message":"image input is not supported"}}"#,
    );
    let api = Api::start(refused).await;
    let chat = chat_at(&server, &api).await;
    let (status, said) = server
        .upload(
            &format!("{chat}/attachments?name=lamp.png"),
            common::picture(),
        )
        .await;
    assert_eq!(status, 400, "{said}");
    assert_eq!(
        said["error"],
        "test-model cannot see pictures, so it takes none"
    );
    // A refusal is not kept: it may pass, as a model still loading does.
    let path = format!("{chat}/attachments?name=lamp.png");
    assert_eq!(server.upload(&path, common::picture()).await.0, 400);
    assert_eq!(api.asked().len(), 2);
}

#[tokio::test]
async fn a_document_is_kept_for_the_chat_and_its_cross_takes_it_off_again() {
    let server = start().await;
    let api = Api::start(seen()).await;
    let chat = chat_at(&server, &api).await;
    let (status, attached) = server
        .upload(
            &format!("{chat}/attachments?name=notes.txt"),
            b"The lamp is lit at dusk.".to_vec(),
        )
        .await;
    assert_eq!(status, 201, "{attached}");
    assert_eq!(attached["picture"], false);
    // No model is asked for a document.
    assert!(api.asked().is_empty());
    let named = |list: &Value| {
        list.as_array()
            .unwrap()
            .iter()
            .map(|one| one["name"].clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(
        named(&server.get("/api/documents").await.1),
        [json!("notes.txt")]
    );

    let path = format!("/api/attachments/{}", attached["id"]);
    let (status, _) = server.call(reqwest::Method::DELETE, &path, None).await;
    assert_eq!(status, 204);
    // One no longer waiting is gone already, so a page that shows it can clear it.
    let (status, _) = server.call(reqwest::Method::DELETE, &path, None).await;
    assert_eq!(status, 204);
    assert!(named(&server.get("/api/documents").await.1).is_empty());
    let (status, said) = server
        .post(
            &format!("{chat}/messages"),
            json!({ "content": "Hi", "attachments": [attached["id"]] }),
        )
        .await;
    assert_eq!(status, 404, "{said}");
}

#[tokio::test]
async fn whether_a_model_sees_is_asked_once_for_all_its_pictures() {
    let server = start().await;
    let api = Api::start(seen()).await;
    let chat = chat_at(&server, &api).await;
    for name in ["lamp.png", "tide.png", "shore.png"] {
        let path = format!("{chat}/attachments?name={name}");
        let (status, attached) = server.upload(&path, common::picture()).await;
        assert_eq!(status, 201, "{attached}");
    }
    assert_eq!(api.asked().len(), 1);
}

#[tokio::test]
async fn a_document_attached_to_the_message_goes_whole_into_its_reply_without_a_search_model() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", REPLY)).await;
    let chat = chat_at(&server, &api).await;
    let (_, attached) = server
        .upload(
            &format!("{chat}/attachments?name=log.txt"),
            b"The keeper's cats were Pitch, Tar and Rope.".to_vec(),
        )
        .await;
    let send = json!({ "content": "What were the cats called?", "attachments": [attached["id"]] });
    assert_eq!(server.post(&format!("{chat}/messages"), send).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let asked = until_asked(&api, 1).await;
    assert!(
        asked.contains("From \\\"log.txt\\\":\\nThe keeper's cats were Pitch, Tar and Rope."),
        "{asked}"
    );
}

#[tokio::test]
async fn the_chat_lists_what_waits_so_a_page_opened_again_shows_it() {
    let server = start().await;
    let api = Api::start(seen()).await;
    let chat = chat_at(&server, &api).await;
    let mut ids = Vec::new();
    for name in ["cats.txt", "dogs.txt"] {
        let path = format!("{chat}/attachments?name={name}");
        let (status, attached) = server.upload(&path, b"Cats nap.".to_vec()).await;
        assert_eq!(status, 201, "{attached}");
        ids.push(attached["id"].clone());
    }
    let path = format!("/api/attachments/{}", ids[0]);
    assert_eq!(
        server.call(reqwest::Method::DELETE, &path, None).await.0,
        204
    );

    let (status, waiting) = server.get(&format!("{chat}/attachments")).await;
    assert_eq!(status, 200, "{waiting}");
    assert_eq!(
        waiting,
        json!([{ "id": ids[1], "name": "dogs.txt", "picture": false }])
    );
}

/// A photo `width` by `height` as a JPEG of fine detail, as a camera's is,
/// with the EXIF orientation `turned` (6: turned a quarter clockwise) where given.
fn photo(width: u32, height: u32, turned: Option<u8>) -> Vec<u8> {
    let picture = image::RgbImage::from_fn(width, height, |x, y| {
        let noise = (x.wrapping_mul(7919) ^ y.wrapping_mul(104_729)) % 61;
        image::Rgb([(x % 256) as u8, (y % 256) as u8, (noise * 4) as u8])
    });
    let mut file = Vec::new();
    let encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut file, 95);
    picture.write_with_encoder(encoder).unwrap();
    let Some(turned) = turned else { return file };
    // An APP1 segment of one IFD entry, Orientation (0x0112), right after SOI.
    let mut exif = b"Exif\0\0II*\0\x08\0\0\0\x01\0\x12\x01\x03\0\x01\0\0\0".to_vec();
    exif.extend_from_slice(&[turned, 0, 0, 0, 0, 0, 0, 0]);
    let length = (exif.len() + 2) as u16;
    let mut segment = vec![0xFF, 0xE1];
    segment.extend_from_slice(&length.to_be_bytes());
    segment.extend_from_slice(&exif);
    file.splice(2..2, segment);
    file
}

/// A picture attached, as it is kept for the chat: its kind and its size.
async fn attached(server: &Server, chat: &str, file: Vec<u8>) -> (String, Vec<u8>, (u32, u32)) {
    let path = format!("{chat}/attachments?name=photo.jpg");
    let (status, attached) = server.upload(&path, file).await;
    assert_eq!(status, 201, "{attached}");
    let address = format!("/api/attachments/{}", attached["id"]);
    let (headers, kept) = server.download(&address).await;
    let size = image::load_from_memory(&kept).unwrap();
    let kind = headers["content-type"].to_str().unwrap().to_owned();
    (kind, kept, (size.width(), size.height()))
}

#[tokio::test]
async fn a_large_photo_is_kept_smaller_once_so_each_turn_sends_less() {
    let server = start().await;
    let api = Api::start(seen()).await;
    let chat = chat_at(&server, &api).await;
    let whole = photo(2400, 1800, None);
    let (kind, kept, size) = attached(&server, &chat, whole.clone()).await;
    assert_eq!((kind.as_str(), size), ("image/jpeg", (1568, 1176)));
    assert!(
        kept.len() < whole.len(),
        "{} of {}",
        kept.len(),
        whole.len()
    );
}

#[tokio::test]
async fn a_photo_turned_by_its_camera_is_kept_upright() {
    let server = start().await;
    let api = Api::start(seen()).await;
    let chat = chat_at(&server, &api).await;
    let (_, _, size) = attached(&server, &chat, photo(2400, 1800, Some(6))).await;
    assert_eq!(size, (1176, 1568));
}

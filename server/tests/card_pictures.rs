//! A card's pictures: a file made the card's picture, every earlier one kept
//! and shown again, and a picture made by the image model of the words the
//! worker model wrote of the whole card. No test asks a provider: `Api`
//! stand-ins answer, the worker model's at the chat provider's address, and an
//! image model's is asked first whether it is a ComfyUI (`/system_stats`),
//! then whether an Automatic1111 (`/sdapi/v1/sd-models`).

mod common;

use std::io::Cursor;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::api::{Api, JSON, Says, says};
use common::server::{Server, start};
use image::codecs::webp::WebPEncoder;
use image::{ImageFormat, ImageReader, RgbImage};
use serde_json::{Value, json};

/// A picture of `width` by `height` in `format`, of one colour.
fn painted(width: u32, height: u32, format: ImageFormat) -> Vec<u8> {
    let picture = RgbImage::from_pixel(width, height, image::Rgb([200, 120, 40]));
    let mut file = Cursor::new(Vec::new());
    if format == ImageFormat::WebP {
        picture
            .write_with_encoder(WebPEncoder::new_lossless(&mut file))
            .unwrap();
    } else {
        picture.write_to(&mut file, format).unwrap();
    }
    file.into_inner()
}

/// Width and height of a PNG.
fn size_of(png: &[u8]) -> (u32, u32) {
    assert!(png.starts_with(b"\x89PNG"), "not a PNG");
    ImageReader::with_format(Cursor::new(png), ImageFormat::Png)
        .into_dimensions()
        .unwrap()
}

/// The sample card imported: its id, and the picture its newest version shows.
async fn card(server: &Server) -> Value {
    let (status, card) = server.upload("/api/cards", common::card_copy()).await;
    assert_eq!(status, 201, "{card}");
    card["card_id"].clone()
}

async fn shown(server: &Server, card: &Value) -> Vec<u8> {
    let (_, detail) = server.get(&format!("/api/cards/{card}")).await;
    let version = &detail["card"]["version_id"];
    server
        .download(&format!("/api/card-versions/{version}/image"))
        .await
        .1
}

/// Each listed picture's source and whether it is in use.
async fn listed(server: &Server, card: &Value) -> Vec<(String, bool)> {
    let (status, list) = server.get(&format!("/api/cards/{card}/pictures")).await;
    assert_eq!(status, 200, "{list}");
    list.as_array()
        .unwrap()
        .iter()
        .map(|one| {
            (
                one["source"].as_str().unwrap().to_string(),
                one["in_use"] == true,
            )
        })
        .collect()
}

#[tokio::test]
async fn a_picture_file_becomes_the_cards_and_every_earlier_one_is_kept() {
    let server = start().await;
    let card = card(&server).await;
    // The card's picture of one pixel is a card without art, which is not listed.
    assert!(listed(&server, &card).await.is_empty());
    let pictures = format!("/api/cards/{card}/pictures");

    let (status, jpeg) = server
        .upload(&pictures, painted(40, 60, ImageFormat::Jpeg))
        .await;
    assert_eq!(status, 200, "{jpeg}");
    // A JPEG is kept as a PNG, as a card file holds its picture.
    assert_eq!(size_of(&shown(&server, &card).await), (40, 60));
    assert_eq!(listed(&server, &card).await, [("file".into(), true)]);

    let (status, webp) = server
        .upload(&pictures, painted(30, 45, ImageFormat::WebP))
        .await;
    assert_eq!(status, 200, "{webp}");
    assert_eq!(size_of(&shown(&server, &card).await), (30, 45));
    // The one in use first, then the newest first.
    assert_eq!(
        listed(&server, &card).await,
        [("file".into(), true), ("file".into(), false)]
    );
    let (_, list) = server.get(&pictures).await;
    let jpeg_id = list[1]["id"].clone();
    assert_eq!(webp["before"], jpeg_id);
    let (headers, whole) = server.download(&format!("{pictures}/{jpeg_id}")).await;
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!(size_of(&whole), (40, 60));

    // An earlier picture is shown again; a text edited after keeps it.
    let (status, back) = server
        .put(
            &format!("/api/cards/{card}/picture"),
            json!({ "picture": jpeg_id }),
        )
        .await;
    assert_eq!(status, 200, "{back}");
    assert_eq!(back["before"], list[0]["id"]);
    let (status, _) = server
        .edit_card(&card, |form| {
            form["characters"][0]["scenario"][0]["text"] = json!("A new scenario.");
        })
        .await;
    assert_eq!(status, 200);
    assert_eq!(size_of(&shown(&server, &card).await), (40, 60));
    // Undo of the first change shows the picture of one pixel again, which stays unlisted.
    let (status, _) = server
        .put(
            &format!("/api/cards/{card}/picture"),
            json!({ "picture": jpeg["before"] }),
        )
        .await;
    assert_eq!(status, 200);
    assert_eq!(size_of(&shown(&server, &card).await), (1, 1));
    assert_eq!(
        listed(&server, &card).await,
        [("file".into(), false), ("file".into(), false)]
    );

    // Refused: what is no picture, a picture another card has, and a card in the Trash.
    let (status, said) = server.upload(&pictures, b"not a picture".to_vec()).await;
    assert_eq!(status, 400, "{said}");
    assert_eq!(
        (&said["code"], &said["details"]["what"]),
        (&json!("not_readable"), &json!("picture")),
        "{said}"
    );
    let other = self::card(&server).await;
    let (status, _) = server
        .put(
            &format!("/api/cards/{other}/picture"),
            json!({ "picture": jpeg_id }),
        )
        .await;
    assert_eq!(status, 404);
    assert_eq!(
        server
            .patch(&format!("/api/cards/{card}"), json!({ "trashed": true }))
            .await
            .0,
        200
    );
    let (status, said) = server
        .upload(&pictures, painted(20, 30, ImageFormat::Png))
        .await;
    assert_eq!(status, 400, "{said}");
    assert!(said["error"].as_str().unwrap().contains("Trash"), "{said}");
}

/// The worker model's whole answer.
fn worded(words: &str) -> Says {
    says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": words } }] }).to_string(),
    )
}

#[tokio::test]
async fn a_picture_is_made_of_what_the_worker_model_wrote_of_the_whole_card() {
    let worker = Api::start(worded("a keeper on a stormy cliff, oil painting")).await;
    let drawn =
        json!({ "data": [{ "b64_json": STANDARD.encode(painted(20, 30, ImageFormat::Png)) }] });
    let image = Api::start_each(vec![
        says(404, JSON, "{}"),
        says(200, JSON, &drawn.to_string()),
    ])
    .await;
    let server = start().await;
    let provider = json!({ "base_url": worker.url, "model": "small-1", "api_key": "sk-chat" });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let card = card(&server).await;
    let words = format!("/api/cards/{card}/pictures/words");
    // Without an image model nothing is asked.
    let (status, said) = server.post(&words, json!({})).await;
    assert_eq!(status, 400, "{said}");
    assert!(worker.asked().is_empty());
    let own =
        json!({ "model": "gpt-image-1", "base_url": image.url, "api_key": "sk-image-0123456789" });
    assert_eq!(server.set_images(own).await.0, 200);

    let (status, written) = server.post(&words, json!({})).await;
    assert_eq!(status, 200, "{written}");
    assert_eq!(written["words"], "a keeper on a stormy cliff, oil painting");
    // Named by its provider, as Settings names it: a server here has none, the page words it.
    assert_eq!(written["provider"], "");
    assert!(written.get("model").is_none() && written.get("host").is_none());
    // The worker model reads the whole card, and is told which model draws.
    let asked = &worker.asked()[0].body;
    assert!(asked.contains("You picked a night for it"), "{asked}");
    assert!(
        asked.contains("drawn by the image model \\\"gpt-image-1\\\""),
        "{asked}"
    );

    let made = format!("/api/cards/{card}/pictures/made");
    let (status, said) = server.post(&made, json!({ "words": "  " })).await;
    assert_eq!(status, 400, "{said}");
    let before = shown(&server, &card).await;
    let (status, picture) = server
        .post(&made, json!({ "words": written["words"] }))
        .await;
    assert_eq!(status, 201, "{picture}");
    assert_eq!(picture["source"], "made");
    assert_eq!(picture["in_use"], false);
    // Asked upright, of the words as they stand.
    let body: Value = serde_json::from_str(&image.asked()[2].body).unwrap();
    assert_eq!(body["size"], "1024x1536");
    assert_eq!(body["prompt"], "a keeper on a stormy cliff, oil painting");
    // It joins the card's pictures and is shown only when it is chosen.
    assert_eq!(listed(&server, &card).await, [("made".into(), false)]);
    assert_eq!(shown(&server, &card).await, before);
    let (status, _) = server
        .put(
            &format!("/api/cards/{card}/picture"),
            json!({ "picture": picture["id"] }),
        )
        .await;
    assert_eq!(status, 200);
    assert_eq!(size_of(&shown(&server, &card).await), (20, 30));
}

/// `jpeg` with an EXIF block that says it is to be turned a quarter clockwise, as a phone writes it.
fn turned(jpeg: &[u8]) -> Vec<u8> {
    let mut exif = b"Exif\0\0MM\0\x2a\0\0\0\x08\0\x01".to_vec();
    // Orientation (0x0112), a SHORT, 6; then no further IFD.
    exif.extend_from_slice(b"\x01\x12\0\x03\0\0\0\x01\0\x06\0\0\0\0\0\0");
    let mut file = jpeg[..2].to_vec();
    file.extend_from_slice(b"\xff\xe1");
    file.extend_from_slice(&u16::try_from(exif.len() + 2).unwrap().to_be_bytes());
    file.extend_from_slice(&exif);
    file.extend_from_slice(&jpeg[2..]);
    file
}

#[tokio::test]
async fn a_photo_is_kept_upright_and_a_picture_too_large_is_refused() {
    let server = start().await;
    let card = card(&server).await;
    let pictures = format!("/api/cards/{card}/pictures");
    let (status, said) = server
        .upload(&pictures, turned(&painted(40, 60, ImageFormat::Jpeg)))
        .await;
    assert_eq!(status, 200, "{said}");
    assert_eq!(size_of(&shown(&server, &card).await), (60, 40));

    // A PNG small on disk that says it is 60000 by 60000 pixels.
    let mut huge = painted(1, 1, ImageFormat::Png);
    huge[16..20].copy_from_slice(&60000u32.to_be_bytes());
    huge[20..24].copy_from_slice(&60000u32.to_be_bytes());
    let crc = crc32fast::hash(&huge[12..29]);
    huge[29..33].copy_from_slice(&crc.to_be_bytes());
    let (status, said) = server.upload(&pictures, huge).await;
    assert_eq!(status, 400, "{said}");
    assert!(
        said["error"].as_str().unwrap().contains("too large"),
        "{said}"
    );
}

#[tokio::test]
async fn a_card_longer_than_the_worker_model_reads_is_not_sent_for_its_picture() {
    let worker = Api::start(worded("never asked")).await;
    let server = start().await;
    let provider = json!({ "base_url": worker.url, "model": "small-1", "api_key": "sk-chat", "sampling": { "context_size": 600 } });
    assert_eq!(server.set_provider(provider).await.0, 200);
    let own =
        json!({ "model": "gpt-image-1", "base_url": worker.url, "api_key": "sk-image-0123456789" });
    assert_eq!(server.set_images(own).await.0, 200);
    let card = card(&server).await;
    let (status, said) = server
        .post(&format!("/api/cards/{card}/pictures/words"), json!({}))
        .await;
    assert_eq!(status, 400, "{said}");
    assert!(
        said["error"].as_str().unwrap().contains("longer than"),
        "{said}"
    );
    assert!(worker.asked().is_empty());
}

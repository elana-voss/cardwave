//! Expression packs: kept once from a zip or from pictures and shared by cards, one no card has going to the Trash,
//! a card's own from its V3 assets, and in a chat the picture of a reply's mood, told by the search model's
//! stand-in (`common::embedder`), whose vectors of a text and of the same words are one.

mod common;

use std::io::{Cursor, Write};

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::embedder::Embedder;
use common::server::{Server, WAIT, start, start_searching};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

/// A file that passes for a PNG, told from others by `mark`.
fn png(mark: &str) -> Vec<u8> {
    let mut file = b"\x89PNG\r\n\x1a\n".to_vec();
    file.extend_from_slice(mark.as_bytes());
    file
}

fn zip_of(files: &[(&str, Vec<u8>)]) -> Vec<u8> {
    let mut file = Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut file);
    for (name, data) in files {
        zip.start_file(*name, zip::write::SimpleFileOptions::default())
            .unwrap();
        zip.write_all(data).unwrap();
    }
    zip.finish().unwrap();
    file.into_inner()
}

fn files(files: &[(&str, Vec<u8>)]) -> Value {
    let files: Vec<Value> = files
        .iter()
        .map(|(name, data)| json!({ "name": name, "data": STANDARD.encode(data) }))
        .collect();
    json!(files)
}

async fn card(server: &Server) -> Value {
    let (status, card) = server.upload("/api/cards", common::card_copy()).await;
    assert_eq!(status, 201, "{card}");
    card["card_id"].clone()
}

/// Gives the card a pack of these files; answers the pack.
async fn pack_from(server: &Server, card: &Value, name: &str, given: &[(&str, Vec<u8>)]) -> Value {
    let new = json!({ "name": name, "files": files(given) });
    let (status, done) = server
        .post(&format!("/api/cards/{card}/expressions"), new)
        .await;
    assert_eq!(status, 200, "{done}");
    done["pack"].clone()
}

async fn trash_kinds(server: &Server) -> Vec<String> {
    let (_, trash) = server.get("/api/trash").await;
    trash["items"]
        .as_array()
        .unwrap()
        .iter()
        .map(|item| item["kind"].as_str().unwrap().to_string())
        .collect()
}

fn mira_pack() -> Vec<u8> {
    zip_of(&[
        ("mira/joy-2.png", png("joy two")),
        ("mira/joy.png", png("joy")),
        ("mira/Anger.png", png("anger")),
        ("mira/readme.txt", b"not a picture".to_vec()),
        ("__MACOSX/mira/._joy.png", png("mac")),
        ("mira/fear.png", b"no picture at all".to_vec()),
    ])
}

#[tokio::test]
async fn a_pack_from_a_zip_is_kept_once_and_shared_by_cards() {
    let server = start().await;
    let (first, second) = (card(&server).await, card(&server).await);
    let pack = pack_from(&server, &first, "Mira", &[("Mira.zip", mira_pack())]).await;
    assert_eq!(pack["name"], "Mira");
    assert_eq!(pack["moods"], json!(["anger", "joy"]));
    assert_eq!(pack["cards"], 1);
    let id = &pack["id"];
    assert_eq!(
        server
            .download(&format!("/api/expressions/{id}/joy"))
            .await
            .1,
        png("joy")
    );

    // The same pictures, given loose this time, are the pack kept.
    let again = pack_from(
        &server,
        &second,
        "Other",
        &[("joy.png", png("joy")), ("anger.png", png("anger"))],
    )
    .await;
    assert_eq!(&again["id"], id);
    assert_eq!(again["cards"], 2);
    let (_, all) = server.get("/api/expressions").await;
    assert_eq!(all.as_array().unwrap().len(), 1, "{all}");
    let (_, of_card) = server
        .get(&format!("/api/cards/{second}/expressions"))
        .await;
    assert_eq!(&of_card["id"], id);
}

#[tokio::test]
async fn files_that_name_no_mood_are_refused_and_nothing_is_kept() {
    let server = start().await;
    let card = card(&server).await;
    let new = json!({ "name": "x", "files": files(&[("pack.zip", zip_of(&[("smile.png", png("s"))])), ("joy.txt", b"text".to_vec())]) });
    let (status, error) = server
        .post(&format!("/api/cards/{card}/expressions"), new)
        .await;
    assert_eq!(status, 400, "{error}");
    assert!(
        error["error"].as_str().unwrap().contains("named by a mood"),
        "{error}"
    );
    assert_eq!(server.get("/api/expressions").await.1, json!([]));
}

#[tokio::test]
async fn a_zip_that_unpacks_past_the_limit_is_refused() {
    let server = start().await;
    let card = card(&server).await;
    let mut big = png("big");
    big.resize(18 << 20, 0);
    let names: Vec<String> = (1..=6).map(|at| format!("joy-{at}.png")).collect();
    let entries: Vec<(&str, Vec<u8>)> = names
        .iter()
        .map(|name| (name.as_str(), big.clone()))
        .collect();
    let new = json!({ "name": "x", "files": files(&[("big.zip", zip_of(&entries))]) });
    let (status, error) = server
        .post(&format!("/api/cards/{card}/expressions"), new)
        .await;
    assert_eq!(status, 400, "{error}");
    assert!(
        error["error"]
            .as_str()
            .unwrap()
            .contains("more than 100 MB"),
        "{error}"
    );
}

#[tokio::test]
async fn a_pack_no_card_has_goes_to_the_trash_and_comes_back_on_a_card() {
    let server = start().await;
    let (first, second) = (card(&server).await, card(&server).await);
    let pack = pack_from(&server, &first, "Mira", &[("Mira.zip", mira_pack())]).await;
    let id = pack["id"].clone();
    server
        .put(
            &format!("/api/cards/{second}/expressions"),
            json!({ "pack": id }),
        )
        .await;

    // Taken off one card, the other still has it.
    let (_, off) = server
        .put(
            &format!("/api/cards/{first}/expressions"),
            json!({ "pack": null }),
        )
        .await;
    assert_eq!((&off["pack"], &off["before"]), (&Value::Null, &id));
    assert!(trash_kinds(&server).await.is_empty());

    // Its last card deleted for good, it is in the Trash, and no longer offered.
    server
        .patch(&format!("/api/cards/{second}"), json!({ "trashed": true }))
        .await;
    assert!(
        trash_kinds(&server).await == ["card"],
        "a card in the Trash still has it"
    );
    assert_eq!(
        server
            .call(Method::DELETE, &format!("/api/cards/{second}"), None)
            .await
            .0,
        204
    );
    assert_eq!(trash_kinds(&server).await, ["expression_pack"]);
    assert_eq!(server.get("/api/expressions").await.1, json!([]));

    // Undo of taking it off: put on the card again, it is out of the Trash.
    let (_, back) = server
        .put(
            &format!("/api/cards/{first}/expressions"),
            json!({ "pack": id }),
        )
        .await;
    assert_eq!(back["pack"]["cards"], 1);
    assert!(trash_kinds(&server).await.is_empty());
}

#[tokio::test]
async fn a_pack_in_the_trash_is_restored_or_deleted_for_good() {
    let server = start().await;
    let card = card(&server).await;
    let id = pack_from(&server, &card, "Mira", &[("Mira.zip", mira_pack())]).await["id"].clone();
    let address = format!("/api/expressions/{id}");
    assert_eq!(
        server.call(Method::DELETE, &address, None).await.0,
        400,
        "a pack not in the Trash stays"
    );
    assert_eq!(
        server.patch(&address, json!({ "trashed": true })).await.0,
        400,
        "a card has it"
    );

    server
        .put(
            &format!("/api/cards/{card}/expressions"),
            json!({ "pack": null }),
        )
        .await;
    assert_eq!(
        server.patch(&address, json!({ "trashed": false })).await.0,
        204
    );
    assert_eq!(
        server.get("/api/expressions").await.1[0]["cards"],
        0,
        "restored, it is offered again"
    );
    assert_eq!(
        server.patch(&address, json!({ "trashed": true })).await.0,
        204
    );
    assert_eq!(server.call(Method::DELETE, &address, None).await.0, 204);
    assert!(trash_kinds(&server).await.is_empty());
    assert_eq!(server.get(&format!("{address}/joy")).await.0, 404);
}

#[tokio::test]
async fn a_v3_card_brings_its_emotion_assets_as_its_pack() {
    let server = start().await;
    let asset = |name: &str, mark: &str| json!({ "type": "emotion", "name": name, "ext": "png", "uri": format!("data:image/png;base64,{}", STANDARD.encode(png(mark))) });
    let v3 = json!({ "spec": "chara_card_v3", "spec_version": "3.0", "data": {
        "name": "Ryn", "first_mes": "Hello.",
        "assets": [asset("joy", "joy"), asset("neutral", "calm"), { "type": "icon", "name": "main", "uri": "ccdefault:" }],
    }});
    let (status, imported) = server.upload("/api/cards", common::card_png(&v3)).await;
    assert_eq!(status, 201, "{imported}");
    let (_, pack) = server
        .get(&format!("/api/cards/{}/expressions", imported["card_id"]))
        .await;
    assert_eq!(
        (&pack["name"], &pack["moods"]),
        (&json!("Ryn"), &json!(["joy", "neutral"])),
        "{pack}"
    );
    assert_eq!(
        server
            .download(&format!("/api/expressions/{}/neutral", pack["id"]))
            .await
            .1,
        png("calm")
    );
}

/// The greeting of a chat with Mira, whose card has a pack of joy and neutral; answers its address.
async fn greeting(server: &Server) -> String {
    let (_, card) = server.upload("/api/cards", common::card_copy()).await;
    pack_from(
        server,
        &card["card_id"],
        "Mira",
        &[("joy.png", png("joy")), ("neutral.png", png("calm"))],
    )
    .await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    format!("/api/messages/{}", view["messages"][0]["id"])
}

/// What the portrait shows once the message says `content`, the model given a few tries to start.
async fn shown(server: &Server, message: &str, content: &str) -> Value {
    assert_eq!(
        server.patch(message, json!({ "content": content })).await.0,
        200
    );
    let end = Instant::now() + WAIT;
    loop {
        let (status, shown) = server.get(&format!("{message}/expression")).await;
        assert_eq!(status, 200, "{shown}");
        if shown["mood"] != Value::Null || Instant::now() > end {
            return shown;
        }
        sleep(std::time::Duration::from_millis(50)).await;
    }
}

#[tokio::test]
async fn a_reply_shows_the_picture_of_its_mood_or_neutral_under_the_threshold() {
    let stand_in = Embedder::start().await;
    let server = start_searching(stand_in.setup()).await;
    assert_eq!(server.post("/api/search/download", json!({})).await.0, 200);
    let message = greeting(&server).await;

    let joy = shown(&server, &message, "great happiness, delight, and cheer").await;
    assert_eq!(joy["mood"], "joy", "{joy}");
    assert!(joy["url"].as_str().unwrap().ends_with("/joy"), "{joy}");
    // Near no mood: neutral; and fear, which the pack has no picture of, shows neutral's.
    let calm = shown(&server, &message, "the ship sails into the harbor").await;
    assert_eq!(calm["mood"], "neutral", "{calm}");
    assert!(
        calm["url"].as_str().unwrap().ends_with("/neutral"),
        "{calm}"
    );
    let fear = shown(
        &server,
        &message,
        "feeling afraid, anxious, or threatened by danger",
    )
    .await;
    assert_eq!(fear["mood"], "fear", "{fear}");
    assert!(
        fear["url"].as_str().unwrap().ends_with("/neutral"),
        "{fear}"
    );
}

#[tokio::test]
async fn without_the_search_model_the_plain_portrait_shows() {
    let server = start().await;
    let message = greeting(&server).await;
    let (status, shown) = server.get(&format!("{message}/expression")).await;
    assert_eq!(status, 200, "{shown}");
    assert_eq!(shown, json!({ "mood": null, "url": null }));
}

#[test]
fn the_nearest_mood_shows_and_none_under_the_threshold() {
    use cw_find::mood::{THRESHOLD, mood_of};
    use cw_library::expressions::{MOODS, mood_of_name, picture_for};
    let mut cosines = vec![0.1; MOODS.len()];
    cosines[17] = THRESHOLD;
    assert_eq!(mood_of(&cosines), "joy");
    cosines[17] = THRESHOLD - 0.01;
    assert_eq!(mood_of(&cosines), "neutral");
    assert_eq!(mood_of_name("pack/Surprise_2.webp"), Some("surprise"));
    assert_eq!(mood_of_name("smile.png"), None);
    let moods = vec!["joy".to_string()];
    assert_eq!(
        picture_for("anger", &moods),
        None,
        "no neutral: the plain portrait"
    );
}

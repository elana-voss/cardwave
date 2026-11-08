//! 3D figures: kept once from a file and shared by cards, one no card has going to the Trash, a mode's own figure
//! shown in that mode and the card's in the others, and the one the companion shows.

mod common;

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use common::picture;
use common::server::{Server, start};
use cw_ccv4::png;
use cw_ccv4::png::Container;
use reqwest::Method;
use serde_json::{Value, json};

/// A file that passes for a GLB, told from others by `mark`.
fn glb(mark: &str) -> Vec<u8> {
    let mut file = b"glTF\x02\0\0\0".to_vec();
    file.extend_from_slice(mark.as_bytes());
    file
}

fn still() -> String {
    STANDARD.encode(b"\x89PNG\r\n\x1a\nstill")
}

/// A card of two modes, Roleplay first.
const GWEN: &str = r#"spec = "ccv4:1.0.0"

[meta-info]
modes = ["Roleplay", "Assistant"]

[name.gwen]
text = "Gwen"

[greeting.hi]
text = "Hello."

[character.gwen]
name-char = "name.gwen"
greetings = ["greeting.hi"]
prompt = ["name.gwen", "CHAT-HISTORY"]
"#;

async fn card(server: &Server) -> Value {
    let (status, card) = server.upload("/api/cards", common::card_copy()).await;
    assert_eq!(status, 201, "{card}");
    card["card_id"].clone()
}

/// Gwen's card: its id and version.
async fn gwen(server: &Server) -> (Value, Value) {
    let file = png::write(&Container {
        image: picture(),
        toml: vec![("card/0001_card.toml".to_string(), GWEN.to_string())],
        assets: Vec::new(),
    })
    .unwrap();
    let (status, card) = server.upload("/api/cards", file).await;
    assert_eq!(status, 201, "{card}");
    (card["card_id"].clone(), card["version_id"].clone())
}

/// Gives the card, or its mode, a figure from this file; answers the answer.
async fn from_file(
    server: &Server,
    card: &Value,
    name: &str,
    data: &[u8],
    mode: Option<&str>,
) -> (u16, Value) {
    let new =
        json!({ "file_name": name, "data": STANDARD.encode(data), "still": still(), "mode": mode });
    server
        .post(&format!("/api/cards/{card}/figures"), new)
        .await
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

#[tokio::test]
async fn a_figure_from_a_file_is_kept_once_and_shared_by_cards() {
    let server = start().await;
    let (first, second) = (card(&server).await, card(&server).await);
    let (status, done) = from_file(&server, &first, "Mira.vrm", &glb("mira"), None).await;
    assert_eq!(status, 200, "{done}");
    let figure = &done["figures"]["figure"];
    assert_eq!(
        (&figure["name"], &figure["kind"], &figure["cards"]),
        (&json!("Mira"), &json!("vrm"), &json!(1))
    );
    assert_eq!(done["before"], Value::Null);
    let id = figure["id"].clone();
    assert_eq!(
        server.download(&format!("/api/figures/{id}/file")).await.1,
        glb("mira")
    );
    assert_eq!(
        server.download(&format!("/api/figures/{id}/still")).await.1,
        b"\x89PNG\r\n\x1a\nstill"
    );

    // The same file again, under another name, is the figure kept.
    let (_, again) = from_file(&server, &second, "copy.vrm", &glb("mira"), None).await;
    assert_eq!(again["figures"]["figure"]["id"], id);
    assert_eq!(again["figures"]["figure"]["cards"], 2);
    let (_, all) = server.get("/api/figures").await;
    assert_eq!(all.as_array().unwrap().len(), 1, "{all}");
}

#[tokio::test]
async fn a_file_of_another_kind_is_refused_and_nothing_is_kept() {
    let server = start().await;
    let card = card(&server).await;
    for (name, data, says) in [
        ("figure.obj", glb("x"), "VRM, GLB or FBX"),
        ("figure.glb", b"not a figure".to_vec(), "not a GLB file"),
        ("figure.fbx", glb("x"), "not a FBX file"),
    ] {
        let (status, error) = from_file(&server, &card, name, &data, None).await;
        assert_eq!(status, 400, "{error}");
        assert!(error["error"].as_str().unwrap().contains(says), "{error}");
    }
    let (status, error) = server
        .post(
            &format!("/api/cards/{card}/figures"),
            json!({ "file_name": "a.glb", "data": STANDARD.encode(glb("a")), "still": STANDARD.encode("text"), "mode": null }),
        )
        .await;
    assert_eq!(status, 400, "{error}");
    assert_eq!(server.get("/api/figures").await.1, json!([]));
}

#[tokio::test]
async fn a_figure_no_card_has_goes_to_the_trash_and_comes_back_on_a_card() {
    let server = start().await;
    let (first, second) = (card(&server).await, card(&server).await);
    let (_, done) = from_file(&server, &first, "Mira.glb", &glb("mira"), None).await;
    let id = done["figures"]["figure"]["id"].clone();
    server
        .put(
            &format!("/api/cards/{second}/figures"),
            json!({ "figure": id, "mode": null }),
        )
        .await;

    let (_, off) = server
        .put(
            &format!("/api/cards/{first}/figures"),
            json!({ "figure": null, "mode": null }),
        )
        .await;
    assert_eq!(
        (&off["figures"]["figure"], &off["before"]),
        (&Value::Null, &id)
    );
    assert!(trash_kinds(&server).await.is_empty());

    // Its last card deleted for good, it is in the Trash and no longer offered.
    server
        .patch(&format!("/api/cards/{second}"), json!({ "trashed": true }))
        .await;
    assert_eq!(
        trash_kinds(&server).await,
        ["card"],
        "a card in the Trash still has it"
    );
    assert_eq!(
        server
            .call(Method::DELETE, &format!("/api/cards/{second}"), None)
            .await
            .0,
        204
    );
    assert_eq!(trash_kinds(&server).await, ["figure"]);
    assert_eq!(server.get("/api/figures").await.1, json!([]));

    // Put on a card again, it is out of the Trash.
    let (_, back) = server
        .put(
            &format!("/api/cards/{first}/figures"),
            json!({ "figure": id, "mode": null }),
        )
        .await;
    assert_eq!(back["figures"]["figure"]["id"], id);
    assert!(trash_kinds(&server).await.is_empty());

    // Taken off again and deleted for good from the Trash, its file goes.
    server
        .put(
            &format!("/api/cards/{first}/figures"),
            json!({ "figure": null, "mode": null }),
        )
        .await;
    let (status, refused) = server
        .patch(&format!("/api/figures/{id}"), json!({ "trashed": false }))
        .await;
    assert_eq!(status, 204, "{refused}");
    assert_eq!(
        server
            .patch(&format!("/api/figures/{id}"), json!({ "trashed": true }))
            .await
            .0,
        204
    );
    assert_eq!(
        server
            .call(Method::DELETE, &format!("/api/figures/{id}"), None)
            .await
            .0,
        204
    );
    assert_eq!(server.get(&format!("/api/figures/{id}/file")).await.0, 404);
    assert!(trash_kinds(&server).await.is_empty());
}

#[tokio::test]
async fn a_mode_shows_its_own_figure_and_the_others_the_cards_in_the_companion() {
    let server = start().await;
    let (gwen, version) = gwen(&server).await;
    // No companion: none.
    assert_eq!(server.get("/api/companion/figure").await.1, Value::Null);
    let (_, card_own) = from_file(&server, &gwen, "Gwen.vrm", &glb("gwen"), None).await;
    let (status, done) = from_file(
        &server,
        &gwen,
        "Office.fbx",
        b"Kaydara FBX Binary  \0office",
        Some("assistant"),
    )
    .await;
    assert_eq!(status, 200, "{done}");
    let card_figure = card_own["figures"]["figure"]["id"].clone();
    let office = done["figures"]["modes"][0]["figure"]["id"].clone();
    assert_eq!(
        done["figures"]["modes"][0]["mode"], "Assistant",
        "the mode as the card names it"
    );
    assert_eq!(done["figures"]["figure"]["id"], card_figure);
    let (status, error) = from_file(&server, &gwen, "x.glb", &glb("x"), Some("Pirate")).await;
    assert_eq!(status, 400, "{error}");

    // The companion is Gwen; without a chat it is in her first mode, Roleplay, which has the card's figure.
    let companion = json!({ "card_id": gwen, "starts": false, "hidden_until": null });
    assert_eq!(
        server
            .patch("/api/settings", json!({ "companion": companion }))
            .await
            .0,
        200
    );
    assert_eq!(
        server.get("/api/companion/figure").await.1["id"],
        card_figure
    );

    // Her newest chat set to Assistant: the mode's own.
    let new = json!({ "characters": [{ "version_id": version, "character": "gwen" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = &view["chat"]["id"];
    assert_eq!(
        server
            .put(
                &format!("/api/chats/{chat}/mode"),
                json!({ "mode": "Assistant" })
            )
            .await
            .0,
        200
    );
    assert_eq!(server.get("/api/companion/figure").await.1["id"], office);

    // The mode's taken off: the card's again, and the mode's figure is in the Trash.
    let (_, off) = server
        .put(
            &format!("/api/cards/{gwen}/figures"),
            json!({ "figure": null, "mode": "ASSISTANT" }),
        )
        .await;
    assert_eq!(
        (&off["figures"]["modes"], &off["before"]),
        (&json!([]), &office)
    );
    assert_eq!(
        server.get("/api/companion/figure").await.1["id"],
        card_figure
    );
    assert_eq!(trash_kinds(&server).await, ["figure"]);
}

#[tokio::test]
async fn a_figure_of_a_mode_the_card_lost_comes_off_and_a_figure_s_number_is_never_given_again() {
    let server = start().await;
    let (gwen, _) = gwen(&server).await;
    let (_, done) = from_file(
        &server,
        &gwen,
        "Office.glb",
        &glb("office"),
        Some("Assistant"),
    )
    .await;
    let office = done["figures"]["modes"][0]["figure"]["id"].clone();
    // The card loses the mode Assistant.
    let (_, mut edit) = server.get(&format!("/api/cards/{gwen}/edit")).await;
    edit["modes"] = json!(["Roleplay"]);
    let (status, saved) = server.put(&format!("/api/cards/{gwen}/edit"), edit).await;
    assert_eq!(status, 200, "{saved}");
    let (status, off) = server
        .put(
            &format!("/api/cards/{gwen}/figures"),
            json!({ "figure": null, "mode": "Assistant" }),
        )
        .await;
    assert_eq!(status, 200, "{off}");
    assert_eq!(
        (&off["figures"]["modes"], &off["before"]),
        (&json!([]), &office)
    );

    // Deleted for good, the newest figure's number is not the next one's.
    let (status, _) = server
        .call(Method::DELETE, &format!("/api/figures/{office}"), None)
        .await;
    assert_eq!(status, 204);
    let (_, next) = from_file(&server, &gwen, "Next.glb", &glb("next"), None).await;
    assert_ne!(next["figures"]["figure"]["id"], office);
}

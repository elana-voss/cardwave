//! The account's own voices and its characters' (`api/voices.rs`,
//! `voice::own`): a voice is made of a recording, brought to the shipped ones'
//! form, renamed and deleted, and reads as any voice; a card's character
//! reads in its voice, else the account's. The stand-in voice of
//! `voice::Setup::stand_in` speaks, never Pocket TTS.

mod common;

use common::embedder::Embedder;
use common::server::{Server, start_voicing};
use cw_voice::{self as voice, Setup};
use reqwest::Method;
use serde_json::{Value, json};

/// A WAV file of `seconds` of a tone, 16-bit stereo at 48,000 a second.
fn recording(seconds: f32) -> Vec<u8> {
    let count = (seconds * 48_000.0) as usize;
    let sound: Vec<f32> = (0..count)
        .map(|n| (n as f32 * 300.0 * std::f32::consts::TAU / 48_000.0).sin() * 0.3)
        .collect();
    let data: Vec<u8> = sound
        .iter()
        .flat_map(|s| {
            let sample = ((s * 32767.0) as i16).to_le_bytes();
            [sample, sample].concat()
        })
        .collect();
    let mut file = b"RIFF".to_vec();
    file.extend_from_slice(&(36 + data.len() as u32).to_le_bytes());
    file.extend_from_slice(b"WAVEfmt ");
    file.extend_from_slice(&16u32.to_le_bytes());
    file.extend_from_slice(&1u16.to_le_bytes());
    file.extend_from_slice(&2u16.to_le_bytes());
    file.extend_from_slice(&48_000u32.to_le_bytes());
    file.extend_from_slice(&(48_000u32 * 4).to_le_bytes());
    file.extend_from_slice(&4u16.to_le_bytes());
    file.extend_from_slice(&16u16.to_le_bytes());
    file.extend_from_slice(b"data");
    file.extend_from_slice(&(data.len() as u32).to_le_bytes());
    file.extend_from_slice(&data);
    file
}

async fn voicing() -> (Embedder, Server) {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    server.post("/api/voice/download", json!({})).await;
    loop {
        let (_, state) = server.get("/api/voice").await;
        if state["state"] == "ready" {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    (stand_in, server)
}

async fn speak(server: &Server, body: Value) -> u16 {
    reqwest::Client::new()
        .post(format!("http://{}/api/voice/speak", server.addr))
        .json(&body)
        .send()
        .await
        .unwrap()
        .status()
        .as_u16()
}

/// The account's own voices in the voice's state.
async fn own(server: &Server) -> Vec<Value> {
    let (_, state) = server.get("/api/voice").await;
    state["voices"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|voice| voice["own"] == true)
        .cloned()
        .collect()
}

#[test]
fn a_recording_is_made_one_channel_at_the_models_rate_and_at_most_thirty_seconds() {
    let made = voice::prepare(&recording(40.0)).unwrap();
    let (rate, sound) = voice::read_wav(&made).unwrap();
    assert_eq!((rate, sound.len()), (24_000, 30 * 24_000));
    let made = voice::prepare(&recording(4.0)).unwrap();
    assert_eq!(voice::read_wav(&made).unwrap().1.len(), 4 * 24_000);
    let short = voice::prepare(&recording(2.0)).unwrap_err().to_string();
    assert!(short.contains("too short"), "{short}");
}

#[tokio::test]
async fn a_voice_is_made_from_a_recording_renamed_and_deleted() {
    let (_stand_in, server) = voicing().await;
    let (status, made) = server
        .upload("/api/voice/own?name=%20My%20voice%20", recording(4.0))
        .await;
    assert_eq!(status, 200, "{made}");
    assert_eq!(made["name"], "My voice");
    assert_eq!(made["own"], true);
    let id = made["id"].as_str().unwrap().to_string();
    assert!(id.starts_with("own-"), "{id}");
    assert_eq!(own(&server).await, vec![made.clone()]);
    // It reads, chosen for a text or as the account's voice.
    assert_eq!(
        speak(&server, json!({ "text": "one", "voice": id })).await,
        200
    );
    let (status, _) = server.patch("/api/settings", json!({ "voice": id })).await;
    assert_eq!(status, 200);

    // Refused: no name, a recording too short, one that is no WAV.
    let (status, _) = server.upload("/api/voice/own?name=", recording(4.0)).await;
    assert_eq!(status, 400);
    let (status, why) = server
        .upload("/api/voice/own?name=Short", recording(1.0))
        .await;
    assert_eq!(status, 400, "{why}");
    let (status, _) = server
        .upload("/api/voice/own?name=Noise", b"not a wav".to_vec())
        .await;
    assert_eq!(status, 400);

    let (status, _) = server
        .patch(
            &format!("/api/voice/own/{id}"),
            json!({ "name": "Evening" }),
        )
        .await;
    assert_eq!(status, 200);
    assert_eq!(own(&server).await[0]["name"], "Evening");
    let (status, _) = server
        .patch("/api/voice/own/alba", json!({ "name": "Mine" }))
        .await;
    assert_eq!(status, 404);

    let (status, _) = server
        .call(Method::DELETE, &format!("/api/voice/own/{id}"), None)
        .await;
    assert_eq!(status, 200);
    assert!(own(&server).await.is_empty());
    // The account's voice gone, a text is read in the first.
    assert_eq!(speak(&server, json!({ "text": "one" })).await, 200);
    assert_eq!(
        speak(&server, json!({ "text": "one", "voice": id })).await,
        400
    );
}

/// A new card of `name`, its number.
async fn card(server: &Server, name: &str, title: &str) -> i64 {
    let card = json!({ "title": title, "tags": [], "creator": "", "name": name, "greetings": ["Hello."], "description": "", "personality": "", "scenario": "", "example_dialogue": "", "creator_notes": "" });
    let (status, made) = server.post("/api/cards/new", card).await;
    assert_eq!(status, 201, "{made}");
    made["card_id"].as_i64().unwrap()
}

#[tokio::test]
async fn a_characters_voice_reads_its_messages_until_it_is_taken_away() {
    let (_stand_in, server) = voicing().await;
    let mira = card(&server, "Mira", "North Light").await;
    let (_, list) = server.get("/api/voice/characters").await;
    assert_eq!(list, json!([]));
    let (status, list) = server
        .put(
            &format!("/api/voice/characters/{mira}"),
            json!({ "voice": "marius" }),
        )
        .await;
    assert_eq!(status, 200, "{list}");
    assert_eq!(
        list,
        json!([{ "card_id": mira, "name": "Mira", "title": "North Light", "voice": "marius" }])
    );
    assert_eq!(
        speak(&server, json!({ "text": "one", "card": mira })).await,
        200
    );
    let (status, _) = server
        .put(
            &format!("/api/voice/characters/{mira}"),
            json!({ "voice": "nobody" }),
        )
        .await;
    assert_eq!(status, 400);
    let (status, _) = server
        .put("/api/voice/characters/9999", json!({ "voice": "marius" }))
        .await;
    assert_eq!(status, 404);

    // A voice made and given to the card, then deleted: the card has none.
    let (_, made) = server
        .upload("/api/voice/own?name=Mine", recording(4.0))
        .await;
    let id = made["id"].as_str().unwrap().to_string();
    server
        .put(
            &format!("/api/voice/characters/{mira}"),
            json!({ "voice": id }),
        )
        .await;
    let (_, list) = server.get("/api/voice/characters").await;
    assert_eq!(list[0]["voice"], id.as_str());
    server
        .call(Method::DELETE, &format!("/api/voice/own/{id}"), None)
        .await;
    let (_, list) = server.get("/api/voice/characters").await;
    assert_eq!(list, json!([]));

    server
        .put(
            &format!("/api/voice/characters/{mira}"),
            json!({ "voice": "marius" }),
        )
        .await;
    let (status, list) = server
        .call(
            Method::DELETE,
            &format!("/api/voice/characters/{mira}"),
            None,
        )
        .await;
    assert_eq!((status, list), (200, json!([])));
}

#[test]
fn a_text_reads_in_the_voice_asked_else_the_cards_else_the_accounts_else_the_first() {
    use cw_voice::own::{Storage as _, voice_of};
    let scratch = common::Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file())
        .unwrap()
        .card_id;
    let id = |asked: Option<&str>, card: Option<i64>, account: Option<&str>| {
        voice_of(db, me, asked, card, account)
            .unwrap()
            .id()
            .to_string()
    };
    assert_eq!(id(None, Some(card), None), "alba");
    assert_eq!(id(None, Some(card), Some("vera")), "vera");
    assert!(db.set_character_voice(me, card, Some("marius")).unwrap());
    assert_eq!(id(None, Some(card), Some("vera")), "marius");
    assert_eq!(id(Some("anna"), Some(card), Some("vera")), "anna");
    assert_eq!(id(None, None, Some("vera")), "vera");
    // A voice that is gone counts as none.
    assert!(db.set_character_voice(me, card, Some("own-77")).unwrap());
    assert_eq!(id(None, Some(card), Some("vera")), "vera");
    assert_eq!(id(None, Some(card), Some("own-78")), "alba");
    assert!(voice_of(db, me, Some("own-77"), None, None).is_err());
}

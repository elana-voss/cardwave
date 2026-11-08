//! Dictation (`api/dictation.rs`, `dictation.rs`): its model is downloaded
//! when this computer's account asks and removed again; a WAV sent is heard
//! as the model's words; what is not the page's WAV, or comes before the
//! model is there or while it is removed, is refused. No test downloads or
//! runs Whisper: `Embedder` serves a small file as its file, and the
//! stand-in (`Ears::StandIn`) hears the words it is given.

mod common;

use std::sync::Arc;
use std::time::Duration;

use common::embedder::Embedder;
use common::server::{Server, WAIT, start_dictating};
use cw_dictation::{self as dictation, Setup};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

/// A WAV file of a tenth of a second of silence, 16-bit at 16,000 a second.
fn wav() -> Vec<u8> {
    wav_of(&[0; 1_600], 1, 16_000)
}

/// A WAV file of `samples` in `channels` at `rate` a second, 16-bit.
fn wav_of(samples: &[i16], channels: u16, rate: u32) -> Vec<u8> {
    let data: Vec<u8> = samples
        .iter()
        .flat_map(|sample| sample.to_le_bytes())
        .collect();
    let mut file = b"RIFF".to_vec();
    file.extend((36 + data.len() as u32).to_le_bytes());
    file.extend(b"WAVEfmt ");
    file.extend(16u32.to_le_bytes());
    file.extend(1u16.to_le_bytes());
    file.extend(channels.to_le_bytes());
    file.extend(rate.to_le_bytes());
    file.extend((rate * 2 * u32::from(channels)).to_le_bytes());
    file.extend((2 * channels).to_le_bytes());
    file.extend(16u16.to_le_bytes());
    file.extend(b"data");
    file.extend((data.len() as u32).to_le_bytes());
    file.extend(data);
    file
}

async fn until(server: &Server, wanted: &str) -> Value {
    let end = Instant::now() + WAIT;
    loop {
        let (status, state) = server.get("/api/dictation").await;
        assert_eq!(status, 200, "{state}");
        if state["state"] == wanted {
            return state;
        }
        assert!(Instant::now() < end, "not yet: {state}");
        sleep(Duration::from_millis(20)).await;
    }
}

async fn dictating(says: &str) -> (Server, Embedder) {
    dictating_slowly(says, Duration::ZERO).await
}

async fn dictating_slowly(says: &str, slow: Duration) -> (Server, Embedder) {
    let files = Embedder::start().await;
    let setup = Setup::stand_in(files.file(), says, slow);
    (start_dictating(setup).await, files)
}

#[tokio::test]
async fn the_model_is_downloaded_when_asked_and_removed_again() {
    let (server, files) = dictating("").await;
    let state = until(&server, "absent").await;
    assert_eq!(state["name"], dictation::MODEL);
    assert_eq!(state["size"], files.file().size);
    let (status, _) = server.post("/api/dictation/download", json!({})).await;
    assert_eq!(status, 200);
    until(&server, "ready").await;
    let folder = dictation::folder(&server.dir);
    assert_eq!(std::fs::read_dir(&folder).unwrap().count(), 1);
    let (status, state) = server.call(Method::DELETE, "/api/dictation", None).await;
    assert_eq!((status, state["state"].as_str()), (200, Some("absent")));
    assert_eq!(std::fs::read_dir(&folder).unwrap().count(), 0);
}

#[tokio::test]
async fn a_recording_is_heard_as_the_model_says_its_words() {
    let (server, _files) = dictating("Hello there.").await;
    let (status, refused) = server.upload("/api/dictation/hear", wav()).await;
    assert_eq!(status, 400, "not set up yet: {refused}");
    server.post("/api/dictation/download", json!({})).await;
    until(&server, "ready").await;
    let (status, heard) = server.upload("/api/dictation/hear", wav()).await;
    assert_eq!((status, &heard), (200, &json!({ "text": "Hello there." })));
    for refused in [
        b"not a wav".to_vec(),
        wav_of(&[0; 3_200], 2, 16_000),
        wav_of(&[0; 1_600], 1, 48_000),
    ] {
        let (status, _) = server.upload("/api/dictation/hear", refused).await;
        assert_eq!(status, 400);
    }
}

#[tokio::test]
async fn a_recording_sent_while_the_model_is_removed_is_refused() {
    let (server, _files) = dictating_slowly("Hi.", Duration::from_millis(600)).await;
    server.post("/api/dictation/download", json!({})).await;
    until(&server, "ready").await;
    let server = Arc::new(server);
    let hearing =
        |server: Arc<Server>| async move { server.upload("/api/dictation/hear", wav()).await };
    // The first is heard while Remove waits for it, the second comes after Remove.
    let first = tokio::spawn(hearing(server.clone()));
    sleep(Duration::from_millis(200)).await;
    let removing = {
        let server = server.clone();
        tokio::spawn(async move { server.call(Method::DELETE, "/api/dictation", None).await })
    };
    sleep(Duration::from_millis(100)).await;
    let second = tokio::spawn(hearing(server.clone()));
    assert_eq!(first.await.unwrap().0, 200);
    assert_eq!(removing.await.unwrap().0, 200);
    let (status, refused) = second.await.unwrap();
    assert_eq!(status, 400, "{refused}");
}

#[tokio::test]
async fn a_hearing_the_page_gave_up_keeps_the_model_for_the_next() {
    let (server, _files) = dictating_slowly("Hi.", Duration::from_millis(800)).await;
    server.post("/api/dictation/download", json!({})).await;
    until(&server, "ready").await;
    let server = Arc::new(server);
    let start = Instant::now();
    let given_up = {
        let server = server.clone();
        tokio::spawn(async move { server.upload("/api/dictation/hear", wav()).await })
    };
    sleep(Duration::from_millis(200)).await;
    given_up.abort();
    let (status, _) = server.upload("/api/dictation/hear", wav()).await;
    assert_eq!(status, 200);
    // Heard after the first ended (800 ms), not by a second model beside it.
    assert!(
        start.elapsed() >= Duration::from_millis(1_500),
        "{:?}",
        start.elapsed()
    );
}

#[test]
fn the_page_s_wav_is_read_as_its_sound() {
    let mut file = wav_of(&[0, 16_384, -32_768], 1, 16_000);
    // A chunk before the sound, of odd size and so padded, is passed over.
    let data = file.split_off(36);
    file.extend(b"LIST");
    file.extend(3u32.to_le_bytes());
    file.extend(b"abc\0");
    file.extend(data);
    assert_eq!(dictation::samples(&file).unwrap(), vec![0.0, 0.5, -1.0]);
}

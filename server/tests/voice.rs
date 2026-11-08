//! Voice (`api/voice.rs`, `voice.rs`): what it needs is downloaded when this
//! computer's account asks, a file taken out of a zip where it is one; a text
//! is read aloud as 16-bit samples, in the voice asked for or the account's,
//! the answer broken off where the model fails after its first sound;
//! a voice's recording is read and brought to the model's rate. A language
//! is downloaded, cancelled and removed on its own, and a text is read in the
//! language the AI writes in where it is there; the speed stretches the
//! sound. No test
//! downloads or runs Pocket TTS: `Embedder` serves a small file as the
//! download, and `voice::Setup::stand_in` speaks a tone of a tenth of a
//! second a word.

mod common;

use std::io::Write;
use std::time::Duration;

use axum::Router;
use axum::routing::get;
use common::embedder::Embedder;
use common::server::{Server, WAIT, event, start_voicing};
use cw_modelfiles::ModelFile;
use cw_voice::{self as voice, Part, Setup, Speaker};
use reqwest::Method;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::time::{Instant, sleep};

/// Waits until `done` says yes of the voice's state, and answers it.
async fn until(server: &Server, done: impl Fn(&Value) -> bool) -> Value {
    let end = Instant::now() + WAIT;
    loop {
        let (status, state) = server.get("/api/voice").await;
        assert_eq!(status, 200, "{state}");
        if done(&state) {
            return state;
        }
        assert!(Instant::now() < end, "not yet: {state}");
        sleep(Duration::from_millis(20)).await;
    }
}

async fn ready(server: &Server) {
    let (status, _) = server.post("/api/voice/download", json!({})).await;
    assert_eq!(status, 200);
    until(server, |state| state["state"] == "ready").await;
}

/// What a reading of `body` answers: its status, and its bytes.
async fn speak(server: &Server, body: Value) -> (u16, Vec<u8>) {
    let answer = reqwest::Client::new()
        .post(format!("http://{}/api/voice/speak", server.addr))
        .json(&body)
        .send()
        .await
        .unwrap();
    (
        answer.status().as_u16(),
        answer.bytes().await.unwrap().to_vec(),
    )
}

#[tokio::test]
async fn the_voice_is_downloaded_when_asked_and_a_download_cancelled_leaves_nothing() {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    let (status, state) = server.get("/api/voice").await;
    assert_eq!(status, 200);
    assert_eq!(state["state"], "absent");
    assert_eq!(state["size"], stand_in.file().size);
    assert_eq!(state["rate"], 24_000);
    // The voices of CC0 and CC BY sets, the first used until another is chosen.
    let voices = state["voices"].as_array().unwrap();
    assert_eq!(voices.len(), 29);
    assert_eq!(
        voices[0],
        json!({ "id": "alba", "name": "Alba", "language": "en", "set": "Alba MacKenna", "license": "CC BY 4.0", "credit": "Voice-acted by Alba MacKenna", "own": false })
    );
    assert!(
        voices
            .iter()
            .all(|voice| ["CC0", "CC BY 4.0"].contains(&voice["license"].as_str().unwrap()))
    );
    // CC BY asks for the attribution the page "About Cardwave" gives; CC0 for none.
    let anna = voices.iter().find(|voice| voice["id"] == "anna").unwrap();
    assert!(
        anna["credit"]
            .as_str()
            .unwrap()
            .starts_with("Speaker p228 of the CSTR VCTK Corpus"),
        "{anna}"
    );
    // The native speakers' voices, each with its language, after the English ones.
    let lena = voices.iter().find(|voice| voice["id"] == "lena").unwrap();
    assert_eq!(lena["language"], "de", "{lena}");
    assert!(
        lena["credit"]
            .as_str()
            .unwrap()
            .starts_with("Speaker 3277 of CML-TTS"),
        "{lena}"
    );
    let languages: Vec<&str> = voices[19..]
        .iter()
        .map(|voice| voice["language"].as_str().unwrap())
        .collect();
    for language in ["de", "it", "pt", "es", "fr"] {
        assert_eq!(languages.iter().filter(|&&of| of == language).count(), 2);
    }
    for voice in voices {
        let by = voice["license"] == "CC BY 4.0";
        assert_eq!(voice["credit"] != "", by, "{voice}");
    }

    // Held at its start, the download is cancelled and leaves no file behind.
    stand_in.hold();
    let mut socket = server.listen().await;
    let (_, state) = server.post("/api/voice/download", json!({})).await;
    assert_eq!(state["state"], "downloading");
    assert_eq!(event(&mut socket).await["type"], "voice");
    let (_, _) = server
        .call(Method::DELETE, "/api/voice/download", None)
        .await;
    until(&server, |state| state["state"] == "absent").await;
    let folder = voice::folder(&server.options().data_dir);
    let left: Vec<_> = std::fs::read_dir(&folder)
        .map(|files| files.flatten().map(|file| file.file_name()).collect())
        .unwrap_or_default();
    assert!(left.is_empty(), "{left:?}");
}

#[tokio::test]
async fn a_text_is_read_aloud_once_the_voice_is_there_in_the_voice_asked_for() {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    let (status, refused) = speak(&server, json!({ "text": "Hello there." })).await;
    assert_eq!(status, 400, "{}", String::from_utf8_lossy(&refused));
    ready(&server).await;

    // A tenth of a second a word, at 24,000 samples a second, 2 bytes each.
    let (status, sound) = speak(&server, json!({ "text": "one two three" })).await;
    assert_eq!(status, 200);
    assert_eq!(sound.len(), 3 * 2_400 * 2);
    let (status, _) = speak(&server, json!({ "text": "one", "voice": "marius" })).await;
    assert_eq!(status, 200);
    let (status, _) = speak(&server, json!({ "text": "one", "voice": "lena" })).await;
    assert_eq!(status, 200);
    let (status, _) = speak(&server, json!({ "text": "one", "voice": "cosette" })).await;
    assert_eq!(status, 400);
    let (status, _) = speak(&server, json!({ "text": "  " })).await;
    assert_eq!(status, 400);
    // A failure after the first sound breaks the answer off; one before it is the answer.
    let answer = reqwest::Client::new()
        .post(format!("http://{}/api/voice/speak", server.addr))
        .json(&json!({ "text": "one FAIL" }))
        .send()
        .await;
    let whole = match answer {
        Ok(answer) => answer.status() == 200 && answer.bytes().await.is_ok(),
        Err(_) => false,
    };
    assert!(!whole);
    let (status, why) = speak(&server, json!({ "text": "FAIL" })).await;
    assert_eq!(status, 400);
    let why: serde_json::Value = serde_json::from_slice(&why).unwrap();
    assert_eq!(why["code"], "voice_failed", "{why}");

    // The account's voice is one of the voices.
    let (status, settings) = server
        .patch("/api/settings", json!({ "voice": "marius" }))
        .await;
    assert_eq!(status, 200);
    assert_eq!(settings["voice"], "marius");
    let (status, _) = server
        .patch("/api/settings", json!({ "voice": "cosette" }))
        .await;
    assert_eq!(status, 400);
}

#[tokio::test]
async fn a_file_that_comes_in_a_zip_is_taken_out_of_it() {
    let mut zip = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    zip.start_file("lib/runtime.dll", zip::write::SimpleFileOptions::default())
        .unwrap();
    zip.write_all(b"the runtime").unwrap();
    let zip = zip.finish().unwrap().into_inner();
    let sum: String = Sha256::digest(&zip)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect();
    let size = zip.len() as u64;
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/package.whl", listener.local_addr().unwrap());
    let app = Router::new().route("/package.whl", get(move || async move { zip.clone() }));
    tokio::spawn(async move { axum::serve(listener, app).await });

    let server = start_voicing(Setup {
        parts: vec![Part {
            file: ModelFile {
                url,
                size,
                sha256: sum,
            },
            path: "runtime.dll".into(),
            unpack: Some("lib/runtime.dll".into()),
        }],
        languages: Vec::new(),
        speaker: Speaker::Tone,
    })
    .await;
    ready(&server).await;
    let folder = voice::folder(&server.options().data_dir);
    assert_eq!(
        std::fs::read(folder.join("runtime.dll")).unwrap(),
        b"the runtime"
    );
    assert_eq!(std::fs::read_dir(&folder).unwrap().count(), 1);
}

/// A WAV file of 16-bit PCM of `channels` channels.
fn wav(rate: u32, channels: u16, samples: &[i16]) -> Vec<u8> {
    let data: Vec<u8> = samples.iter().flat_map(|s| s.to_le_bytes()).collect();
    let mut file = b"RIFF".to_vec();
    file.extend_from_slice(&(36 + data.len() as u32).to_le_bytes());
    file.extend_from_slice(b"WAVEfmt ");
    file.extend_from_slice(&16u32.to_le_bytes());
    file.extend_from_slice(&1u16.to_le_bytes());
    file.extend_from_slice(&channels.to_le_bytes());
    file.extend_from_slice(&rate.to_le_bytes());
    file.extend_from_slice(&(rate * 2 * u32::from(channels)).to_le_bytes());
    file.extend_from_slice(&(2 * channels).to_le_bytes());
    file.extend_from_slice(&16u16.to_le_bytes());
    // A chunk the reader passes over, of an odd length.
    file.extend_from_slice(b"LIST");
    file.extend_from_slice(&3u32.to_le_bytes());
    file.extend_from_slice(&[0, 0, 0, 0]);
    file.extend_from_slice(b"data");
    file.extend_from_slice(&(data.len() as u32).to_le_bytes());
    file.extend_from_slice(&data);
    file
}

#[test]
fn each_native_speakers_recording_comes_with_the_app_and_is_long_enough() {
    let setup = Setup::pocket();
    let nowhere = std::path::Path::new("nowhere");
    for native in voice::NATIVE {
        let wav = setup.recording(nowhere, native).unwrap();
        let (rate, sound) = voice::read_wav(&wav).unwrap();
        let seconds = sound.len() as u32 / rate;
        assert!(
            (voice::SHORTEST..=voice::LONGEST).contains(&seconds),
            "{}: {seconds} s",
            native.id
        );
    }
}

#[test]
fn a_recording_is_read_with_its_channels_made_one() {
    let (rate, samples) = voice::read_wav(&wav(32_000, 2, &[16_384, 0, -16_384, -16_384])).unwrap();
    assert_eq!(rate, 32_000);
    assert_eq!(samples, vec![0.25, -0.5]);
    assert!(voice::read_wav(b"not a wav file").is_err());
}

#[test]
fn a_recording_is_brought_to_the_models_rate_and_keeps_its_pitch() {
    // A second of 1 kHz at 48,000 a second: 24,000 samples after, with 2,000 crossings of zero a second.
    let tone: Vec<f32> = (0..48_000)
        .map(|n| (n as f32 * 1_000.0 * std::f32::consts::TAU / 48_000.0).sin())
        .collect();
    let made = voice::resample(&tone, 48_000, 24_000);
    assert_eq!(made.len(), 24_000);
    let crossings = made[100..23_900]
        .windows(2)
        .filter(|pair| (pair[0] < 0.0) != (pair[1] < 0.0))
        .count();
    assert!((1_978..=1_988).contains(&crossings), "{crossings}");
    let loudest = made[100..23_900].iter().fold(0.0f32, |a, b| a.max(b.abs()));
    assert!((0.95..1.05).contains(&loudest), "{loudest}");
    // Above the new rate's half, a tone is gone.
    let high: Vec<f32> = (0..44_100)
        .map(|n| (n as f32 * 15_000.0 * std::f32::consts::TAU / 44_100.0).sin())
        .collect();
    let made = voice::resample(&high, 44_100, 24_000);
    let loudest = made[100..23_900].iter().fold(0.0f32, |a, b| a.max(b.abs()));
    assert!(loudest < 0.05, "{loudest}");
}

/// The language `id` of the voice's state.
fn language<'a>(state: &'a Value, id: &str) -> &'a Value {
    state["languages"]
        .as_array()
        .unwrap()
        .iter()
        .find(|language| language["id"] == id)
        .unwrap()
}

/// What a reading of `text` answers: its status, its language, and how many samples.
async fn read(server: &Server, text: &str) -> (u16, String, usize) {
    let answer = reqwest::Client::new()
        .post(format!("http://{}/api/voice/speak", server.addr))
        .json(&json!({ "text": text }))
        .send()
        .await
        .unwrap();
    let language = answer.headers()["content-language"]
        .to_str()
        .unwrap()
        .to_string();
    let status = answer.status().as_u16();
    (status, language, answer.bytes().await.unwrap().len() / 2)
}

#[tokio::test]
async fn a_language_is_downloaded_when_picked_and_a_text_read_in_it_until_it_is_removed() {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    ready(&server).await;
    let (_, state) = server.get("/api/voice").await;
    let names: Vec<&str> = state["languages"]
        .as_array()
        .unwrap()
        .iter()
        .map(|language| language["name"].as_str().unwrap())
        .collect();
    assert_eq!(
        names,
        ["German", "Italian", "Portuguese", "Spanish", "French"]
    );
    assert_eq!(language(&state, "german")["state"], "absent");
    assert_eq!(state["reads_in"], "English");
    let (status, _) = server
        .patch("/api/settings", json!({ "language": "de" }))
        .await;
    assert_eq!(status, 200);
    // Not there yet: read in English.
    assert_eq!(read(&server, "eins zwei").await.1, "en");

    // Held at its start, its download is cancelled and leaves nothing.
    stand_in.hold();
    let (status, state) = server.post("/api/voice/languages/german", json!({})).await;
    assert_eq!(status, 200);
    assert_eq!(language(&state, "german")["state"], "downloading");
    let (status, _) = server
        .call(Method::DELETE, "/api/voice/languages/german", None)
        .await;
    assert_eq!(status, 200);
    until(&server, |state| {
        language(state, "german")["state"] == "absent"
    })
    .await;
    stand_in.release();
    let folder = voice::folder(&server.options().data_dir);
    assert!(!folder.join("german").join("stand-in").exists());

    server.post("/api/voice/languages/german", json!({})).await;
    let state = until(&server, |state| {
        language(state, "german")["state"] == "ready"
    })
    .await;
    assert_eq!(state["reads_in"], "German");
    let (status, tongue, count) = read(&server, "eins zwei").await;
    assert_eq!((status, tongue.as_str(), count), (200, "de", 2 * 2_400));
    // Italian is not what the AI writes in.
    assert_eq!(language(&state, "italian")["state"], "absent");

    // Removed, its files go and the text is read in English again.
    let (status, state) = server
        .call(Method::DELETE, "/api/voice/languages/german", None)
        .await;
    assert_eq!(status, 200);
    assert_eq!(language(&state, "german")["state"], "absent");
    assert!(!folder.join("german").exists());
    assert_eq!(read(&server, "eins zwei").await.1, "en");
    let (status, _) = server.post("/api/voice/languages/klingon", json!({})).await;
    assert_eq!(status, 404);
}

#[tokio::test]
async fn the_speed_makes_a_reading_shorter_or_longer() {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    ready(&server).await;
    let words = "one two three four five six seven eight nine ten";
    assert_eq!(read(&server, words).await.2, 10 * 2_400);
    for (speed, most) in [(200, 0.55), (50, 2.1)] {
        let (status, settings) = server
            .patch("/api/settings", json!({ "voice_speed": speed }))
            .await;
        assert_eq!(
            (status, settings["voice_speed"].as_u64()),
            (200, Some(speed))
        );
        let (_, _, count) = read(&server, words).await;
        let ratio = count as f64 / 24_000.0;
        assert!(ratio < most && ratio > most - 0.15, "{speed}: {ratio}");
    }
    for wrong in [49, 201] {
        let (status, _) = server
            .patch("/api/settings", json!({ "voice_speed": wrong }))
            .await;
        assert_eq!(status, 400);
    }
}

/// A server at `api` that serves Voice as `model`, with the stand-in voice.
async fn voicing_at(api: &common::api::Api, model: &str) -> Server {
    let stand_in = Embedder::start().await;
    let server = start_voicing(Setup::stand_in(stand_in.file())).await;
    let (status, added) = server
        .post(
            "/api/provider-list",
            json!({ "base_url": api.url, "api_key": "sk-v-1234" }),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    let at = json!({ "provider_id": added["id"], "model": model });
    assert_eq!(server.put("/api/kinds/voice", at).await.0, 200);
    server
}

/// What `api` was sent to read aloud, the oldest first.
fn spoken(api: &common::api::Api) -> Vec<Value> {
    api.asked()
        .iter()
        .filter(|asked| asked.path == "/v1/audio/speech")
        .map(|asked| serde_json::from_str(&asked.body).unwrap())
        .collect()
}

#[tokio::test]
async fn a_voice_at_a_provider_reads_without_a_download_in_whole_samples_in_the_voice_picked() {
    // Three bytes, then one: the page is handed whole samples.
    let sound = common::api::Says {
        then: Some("d".into()),
        ..common::api::says(200, "application/octet-stream", "abc")
    };
    let voices = common::api::says(
        200,
        common::api::JSON,
        r#"{"voices":["af_bella","am_adam"]}"#,
    );
    let api =
        common::api::Api::start_routed(vec![("/audio/speech", sound), ("/audio/voices", voices)])
            .await;
    let server = voicing_at(&api, "kokoro").await;
    let (_, state) = server.get("/api/voice").await;
    assert_eq!(
        (&state["state"], &state["at_provider"]),
        (&json!("absent"), &json!(true))
    );
    let ids: Vec<&Value> = state["voices"]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| &v["id"])
        .collect();
    assert_eq!(ids, [&json!("at:af_bella"), &json!("at:am_adam")]);
    server
        .patch("/api/settings", json!({ "voice_speed": 150 }))
        .await;

    // Nothing picked: the first listed.
    let (status, sound) = speak(&server, json!({ "text": "Hello there." })).await;
    assert_eq!((status, sound), (200, b"abcd".to_vec()));
    let speech = api
        .asked()
        .into_iter()
        .find(|asked| asked.path == "/v1/audio/speech")
        .unwrap();
    assert_eq!(speech.key.as_deref(), Some("Bearer sk-v-1234"));
    assert_eq!(
        spoken(&api)[0],
        json!({ "model": "kokoro", "input": "Hello there.", "voice": "af_bella", "response_format": "pcm", "speed": 1.5 })
    );

    // The voice picked is kept and sent; one the provider does not list is refused.
    assert_eq!(
        server
            .patch("/api/settings", json!({ "voice": "at:am_adam" }))
            .await
            .0,
        200
    );
    assert_eq!(
        server
            .patch("/api/settings", json!({ "voice": "at:nobody" }))
            .await
            .0,
        400
    );
    speak(&server, json!({ "text": "Hello." })).await;
    assert_eq!(spoken(&api)[1]["voice"], "am_adam");
    speak(&server, json!({ "text": "Hello.", "voice": "at:af_bella" })).await;
    assert_eq!(spoken(&api)[2]["voice"], "af_bella");

    // A text longer than one request takes is asked in two, its sound one.
    let long = "word ".repeat(900);
    let (status, sound) = speak(&server, json!({ "text": long })).await;
    assert_eq!((status, sound), (200, b"abcdabcd".to_vec()));
    assert_eq!(spoken(&api).len(), 5);

    // Back to this computer's voice, which is not downloaded.
    assert_eq!(
        server
            .call(Method::DELETE, "/api/kinds/voice", None)
            .await
            .0,
        200
    );
    assert_eq!(speak(&server, json!({ "text": "Hello." })).await.0, 400);
}

#[tokio::test]
async fn a_provider_that_lists_no_voices_is_asked_without_one() {
    let sound = common::api::says(200, "application/octet-stream", "ab");
    let api = common::api::Api::start_routed(vec![("/audio/speech", sound)]).await;
    let server = voicing_at(&api, "some-tts").await;
    assert_eq!(server.get("/api/voice").await.1["voices"], json!([]));
    // About still lists the shipped voices, with their licences.
    let (status, shipped) = server.get("/api/voice/shipped").await;
    assert_eq!(status, 200);
    assert!(shipped.as_array().is_some_and(|all| {
        !all.is_empty()
            && all
                .iter()
                .all(|voice| voice["license"].as_str().is_some_and(|l| !l.is_empty()))
    }));
    assert_eq!(speak(&server, json!({ "text": "Hello." })).await.0, 200);
    assert!(spoken(&api)[0].get("voice").is_none());
}

#[tokio::test]
async fn a_provider_whose_voices_fail_to_come_says_why_and_reads_nothing() {
    let sound = common::api::says(200, "application/octet-stream", "ab");
    let broken = common::api::says(503, common::api::JSON, "{}");
    let api =
        common::api::Api::start_routed(vec![("/audio/speech", sound), ("/audio/voices", broken)])
            .await;
    let server = voicing_at(&api, "kokoro").await;
    let (_, state) = server.get("/api/voice").await;
    assert_eq!(
        state["failure"]["details"]["status"], "503 Service Unavailable",
        "{state}"
    );
    assert_eq!(speak(&server, json!({ "text": "Hello." })).await.0, 400);
    assert!(spoken(&api).is_empty());
}

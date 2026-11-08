//! A stand-in for the search model, started inside a test: it serves a small
//! file as the model's download and answers as `llama-server` does.
//!
//! A text's tokens are its words. Its vector counts its words of each of a
//! few topics (`TOPICS`: the sea, space, the forest), and every other word a
//! twentieth in a dimension of its letters (one of `OTHERS`), so that "ocean"
//! is near a text about a lighthouse and a storm that never says it, and a
//! word is near itself alone. `read` is every text it was
//! given to turn into a vector, in order. `hold` keeps the download from
//! ending, for a test that cancels it, and `drop_once` drops its connection
//! once; it serves a `Range`, and `ranges` says where each download began. As `llama-server` it refuses a text of
//! more than 480 tokens, and a text with "POISON" in it; `down` has it answer
//! nothing but 503, `stall` never answer for a vector, and `asked` counts
//! what it was asked but the download.

use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::Json;
use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, StatusCode, Uri, header};
use axum::response::IntoResponse;
use axum::routing::get;
use cw_modelfiles::ModelFile;
use cw_provider::embedder::{Runner, Setup};
use futures_util::stream;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::net::TcpListener;

const TOPICS: [&[&str]; 3] = [
    &[
        "sea",
        "ocean",
        "lighthouse",
        "storm",
        "ship",
        "harbor",
        "waves",
        "tide",
        "keeper",
    ],
    &[
        "space", "star", "stars", "starship", "planet", "orbit", "galaxy", "pilot",
    ],
    &["forest", "tree", "trees", "woods", "elf", "moss", "deer"],
];

/// The dimensions the words of no topic are spread over.
const OTHERS: usize = 1024;

/// The bytes the stand-in serves as the model's file, in pieces.
const PIECE: usize = 16 * 1024;
const PIECES: usize = 20;

pub struct Embedder {
    pub url: String,
    read: Arc<Mutex<Vec<String>>>,
    hold: Arc<AtomicBool>,
    down: Arc<AtomicBool>,
    stalled: Arc<AtomicBool>,
    asked: Arc<AtomicUsize>,
    dropping: Arc<AtomicBool>,
    ranges: Arc<Mutex<Vec<Option<usize>>>>,
}

impl Embedder {
    pub async fn start() -> Self {
        let read = Arc::new(Mutex::new(Vec::new()));
        let hold = Arc::new(AtomicBool::new(false));
        let log = read.clone();
        let held = hold.clone();
        let (down, asked) = (
            Arc::new(AtomicBool::new(false)),
            Arc::new(AtomicUsize::new(0)),
        );
        let (down_, asked_) = (down.clone(), asked.clone());
        let stalled = Arc::new(AtomicBool::new(false));
        let stalled_ = stalled.clone();
        let (dropping, ranges) = (
            Arc::new(AtomicBool::new(false)),
            Arc::new(Mutex::new(Vec::new())),
        );
        let (dropping_, ranges_) = (dropping.clone(), ranges.clone());
        let app = Router::new()
            .route(
                "/model.gguf",
                get(move |headers: HeaderMap| {
                    let held = held.load(Ordering::Relaxed);
                    // A connection dropped once, after three pieces, where the test asked for it.
                    let drop = dropping.swap(false, Ordering::Relaxed);
                    let whole: Vec<u8> = (0..PIECES).flat_map(piece).collect();
                    let size = whole.len();
                    let from = headers
                        .get(header::RANGE)
                        .and_then(|range| range.to_str().ok()?.strip_prefix("bytes=")?.strip_suffix('-')?.parse::<usize>().ok());
                    ranges.lock().unwrap().push(from);
                    let rest = whole[from.unwrap_or(0)..].to_vec();
                    let length = rest.len();
                    let pieces = stream::unfold(0, move |n| {
                        let rest = rest.clone();
                        async move {
                            let at = n * PIECE;
                            if at >= rest.len() {
                                return None;
                            }
                            if held && n == 2 {
                                std::future::pending::<()>().await;
                            }
                            if drop && n == 3 {
                                return Some((Err(std::io::Error::other("dropped")), usize::MAX / PIECE));
                            }
                            tokio::time::sleep(Duration::from_millis(5)).await;
                            Some((Ok(rest[at..(at + PIECE).min(rest.len())].to_vec()), n + 1))
                        }
                    });
                    async move {
                        let mut head = HeaderMap::new();
                        head.insert(header::CONTENT_LENGTH, length.into());
                        let status = match from {
                            Some(from) => {
                                let range = format!("bytes {from}-{}/{size}", size - 1);
                                head.insert(header::CONTENT_RANGE, range.parse().unwrap());
                                StatusCode::PARTIAL_CONTENT
                            }
                            None => StatusCode::OK,
                        };
                        (status, head, Body::from_stream(pieces))
                    }
                }),
            )
            .fallback(move |uri: Uri, body: String| {
                let (log, down, asked) = (log.clone(), down_.clone(), asked_.clone());
                let stalled = stalled_.clone();
                async move {
                    asked.fetch_add(1, Ordering::Relaxed);
                    if down.load(Ordering::Relaxed) {
                        return (StatusCode::SERVICE_UNAVAILABLE, Json(json!({}))).into_response();
                    }
                    let body: Value = serde_json::from_str(&body).unwrap_or_default();
                    match uri.path() {
                        "/tokenize" => {
                            let words = body["content"].as_str().unwrap_or_default().split_whitespace().count();
                            Json(json!({ "tokens": vec![1; words] })).into_response()
                        }
                        "/v1/embeddings" => {
                            if stalled.load(Ordering::Relaxed) {
                                std::future::pending::<()>().await;
                            }
                            let texts: Vec<String> = body["input"]
                                .as_array()
                                .unwrap()
                                .iter()
                                .map(|text| text.as_str().unwrap().to_string())
                                .collect();
                            let refused = |text: &String| text.split_whitespace().count() > 480 || text.contains("POISON");
                            if texts.iter().any(refused) {
                                return (StatusCode::BAD_REQUEST, Json(json!({ "error": "input is too large" }))).into_response();
                            }
                            log.lock().unwrap().extend(texts.iter().cloned());
                            let data: Vec<Value> = texts
                                .iter()
                                .enumerate()
                                .map(|(index, text)| json!({ "index": index, "embedding": vector(text) }))
                                .collect();
                            Json(json!({ "data": data })).into_response()
                        }
                        _ => Json(json!({ "status": "ok" })).into_response(),
                    }
                }
            });
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self {
            url,
            read,
            hold,
            down,
            stalled,
            asked,
            dropping: dropping_,
            ranges: ranges_,
        }
    }

    /// Has the stand-in never answer when it is asked for vectors, as a model that hangs.
    pub fn stall(&self) {
        self.stalled.store(true, Ordering::Relaxed);
    }

    /// Has the stand-in answer 503 to all but the download, as a model that is gone.
    pub fn down(&self) {
        self.down.store(true, Ordering::Relaxed);
    }

    /// Has the stand-in answer again after `down`.
    #[allow(dead_code)]
    pub fn up(&self) {
        self.down.store(false, Ordering::Relaxed);
    }

    /// Drops the next download's connection after three pieces.
    pub fn drop_once(&self) {
        self.dropping.store(true, Ordering::Relaxed);
    }

    /// Where each download asked to begin (`Range`), none for the start.
    pub fn ranges(&self) -> Vec<Option<usize>> {
        self.ranges.lock().unwrap().clone()
    }

    /// How many times it was asked anything but the download.
    pub fn asked(&self) -> usize {
        self.asked.load(Ordering::Relaxed)
    }

    /// The search model as this stand-in serves and runs it.
    pub fn setup(&self) -> Setup {
        Setup {
            model: self.file(),
            runner: Runner::At(self.url.clone()),
        }
    }

    /// The model's file as the stand-in serves it.
    pub fn file(&self) -> ModelFile {
        let whole: Vec<u8> = (0..PIECES).flat_map(piece).collect();
        ModelFile {
            url: format!("{}/model.gguf", self.url),
            size: whole.len() as u64,
            sha256: Sha256::digest(&whole)
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect(),
        }
    }

    pub fn read(&self) -> Vec<String> {
        self.read.lock().unwrap().clone()
    }

    /// Keeps each download that begins from now on from ending.
    pub fn hold(&self) {
        self.hold.store(true, Ordering::Relaxed);
    }

    /// Lets the downloads that begin from now on end again.
    #[allow(dead_code)]
    pub fn release(&self) {
        self.hold.store(false, Ordering::Relaxed);
    }
}

fn piece(n: usize) -> Vec<u8> {
    vec![n as u8; PIECE]
}

fn vector(text: &str) -> Vec<f32> {
    let mut vector = vec![0.0; TOPICS.len() + OTHERS];
    for word in text
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
    {
        let word = word.to_lowercase();
        match TOPICS
            .iter()
            .position(|topic| topic.contains(&word.as_str()))
        {
            Some(topic) => vector[topic] += 1.0,
            None => {
                let letters = word.bytes().fold(7usize, |hash, byte| {
                    hash.wrapping_mul(31).wrapping_add(byte.into())
                });
                vector[TOPICS.len() + letters % OTHERS] += 0.05;
            }
        }
    }
    vector
}

//! The search model, bge-m3: a text to 1,024 numbers, near for texts about the
//! same thing. Its file comes by cw-modelfiles; llama.cpp's `llama-server` runs
//! it (`Running::start`) on a free local port, the graphics card first (Vulkan),
//! else the processor.
//! The process ends with the server (on Windows a job object); its log is
//! `llama-server.log` in the data folder, made anew at each start.
//! `Running` counts a text's tokens (`tokens`), cuts it into pieces of at most
//! `CHUNK_TOKENS` by halving (`chunks`), and embeds to unit vectors (`embed`).
//! An account whose search is at a provider reads by its model (`at.rs`);
//! `Reader` is either, its `stamp` names the model each vector is kept with, so
//! vectors of two models are never compared. Tests: `Runner::At` a stand-in.

mod at;

pub use at::At;
pub(crate) use at::TextRefused;

use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Fail};
use cw_modelfiles::ModelFile;
use cw_platform::http::Client;

use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

/// The model's name, as the app shows it and stamps every vector with.
pub const MODEL: &str = "bge-m3";
/// The most tokens of a text the model is given at once: its context of 512
/// less room for its own marks, as Cardwave cuts.
pub(crate) const CHUNK_TOKENS: usize = 480;
/// How long the model may take to be ready after its start.
const START_LIMIT: Duration = Duration::from_secs(120);

/// Where the search model comes from and what runs it.
#[derive(Clone, Debug)]
pub struct Setup {
    pub model: ModelFile,
    pub runner: Runner,
}

#[derive(Clone, Debug)]
pub enum Runner {
    /// The folder of llama.cpp's `llama-server`, which runs the model's file.
    LlamaServer(PathBuf),
    /// A server already running at this address that answers as
    /// `llama-server` does; the tests' stand-in.
    At(String),
}

impl Setup {
    /// bge-m3 as the embedder spike measured it (the GGUF of `gpustack`, Q8_0),
    /// run by the `llama-server` in `llama_dir`.
    pub fn bge_m3(llama_dir: PathBuf) -> Self {
        Self {
            model: ModelFile {
                url: "https://huggingface.co/gpustack/bge-m3-GGUF/resolve/main/bge-m3-Q8_0.gguf"
                    .into(),
                size: 634_553_760,
                sha256: "950f4a8e5e19477a6d3c26d2f162233c20002c601f75e4b002e3239997821167".into(),
            },
            runner: Runner::LlamaServer(llama_dir),
        }
    }
}

/// Where the model's file is kept in the data folder.
pub fn model_path(data_dir: &Path) -> PathBuf {
    data_dir.join("models").join(format!("{MODEL}.gguf"))
}

/// The model, running and ready.
pub struct Running {
    /// Its address, up to the path.
    url: String,
    /// Its process, until it is stopped; none for a stand-in.
    process: std::sync::Mutex<Option<Process>>,
}

/// What the search model is started with beside its file: it makes vectors,
/// a text of up to 512 tokens at a time.
const EMBEDDING: &[&str] = &[
    "--embedding",
    "--pooling",
    "cls",
    "--ctx-size",
    "512",
    "--batch-size",
    "512",
    "--ubatch-size",
    "512",
    "--cache-ram",
    "0",
];

impl Running {
    /// Starts the model's file `model` as `setup` says, and waits until it is ready.
    pub async fn start(
        http: &Client,
        setup: &Setup,
        model: &Path,
        log: &Path,
    ) -> anyhow::Result<Self> {
        Self::launch(http, &setup.runner, model, log, EMBEDDING).await
    }

    /// Starts `llama-server` with the model's file `model` and `args` as
    /// `runner` says, on the graphics card, else on the processor alone, and
    /// waits until it is ready; a stand-in is only named. Local models run so
    /// too (`local`).
    pub(crate) async fn launch(
        http: &Client,
        runner: &Runner,
        model: &Path,
        log: &Path,
        args: &[&str],
    ) -> anyhow::Result<Self> {
        let folder = match runner {
            Runner::At(url) => {
                return Ok(Self {
                    url: url.trim_end_matches('/').to_string(),
                    process: std::sync::Mutex::default(),
                });
            }
            Runner::LlamaServer(folder) => folder,
        };
        match Self::run(http, folder, model, log, args, false).await {
            Ok(running) => Ok(running),
            Err(failure) => {
                tracing::warn!(
                    "{} did not start on the graphics card: {failure:#}",
                    model.display()
                );
                Self::run(http, folder, model, log, args, true).await
            }
        }
    }

    /// Its address, up to the path.
    pub fn url(&self) -> &str {
        &self.url
    }

    /// Starts `llama-server` from `folder` on a free port, on the processor
    /// alone where `cpu` says so.
    async fn run(
        http: &Client,
        folder: &Path,
        model: &Path,
        log: &Path,
        args: &[&str],
        cpu: bool,
    ) -> anyhow::Result<Self> {
        let port = std::net::TcpListener::bind("127.0.0.1:0")?
            .local_addr()?
            .port();
        let mut command = tokio::process::Command::new(folder.join("llama-server"));
        command
            .arg("--model")
            .arg(model)
            .args(args)
            .args(["--parallel", "1", "--host", "127.0.0.1"])
            .args(["--port", &port.to_string()])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(std::fs::File::create(log)?)
            .kill_on_drop(true);
        if cpu {
            command.args(["--device", "none"]);
        }
        #[cfg(windows)]
        command.creation_flags(cw_platform::sys::NO_WINDOW);
        let mut child = command.spawn().with_context(|| {
            Fail::said(
                Code::NotPossible,
                format!("llama-server cannot be started from {}", folder.display()),
            )
            .with("what", "llama_server_start")
            .with("folder", (folder.display()).to_string())
        })?;
        #[cfg(windows)]
        let job = cw_platform::sys::Job::holding(&child)
            .context(Fail::said(Code::Internal, "llama-server's job object"))?;
        let url = format!("http://127.0.0.1:{port}");
        let started = Instant::now();
        loop {
            if let Some(status) = child.try_wait()? {
                bail!(
                    Fail::said(
                        Code::NotPossible,
                        format!("llama-server ended at its start ({status}); see its log")
                    )
                    .with("what", "llama_server_start")
                    .with("status", status.to_string())
                );
            }
            let health = http.get(format!("{url}/health")).send().await;
            if health.is_ok_and(|answer| answer.status().is_success()) {
                break;
            }
            ensure!(
                started.elapsed() < START_LIMIT,
                Fail::said(Code::TimedOut, "llama-server was not ready in time")
                    .with("whose", "llama_server")
            );
            sleep(Duration::from_millis(100)).await;
        }
        Ok(Self {
            url,
            process: std::sync::Mutex::new(Some(Process {
                child,
                #[cfg(windows)]
                _job: job,
            })),
        })
    }

    /// How many tokens `text` is to the model.
    pub async fn tokens(&self, http: &Client, text: &str) -> anyhow::Result<usize> {
        let answer: Value = self
            .ask(http, "/tokenize", json!({ "content": text }))
            .await?;
        let tokens = answer["tokens"].as_array().context(
            Fail::said(
                Code::ModelAnswer,
                "the search model's tokens cannot be read",
            )
            .with("what", "search_tokens"),
        )?;
        Ok(tokens.len())
    }

    /// `text` in pieces of at most `CHUNK_TOKENS` tokens, in their order: one
    /// that is longer is halved, by its characters, until each fits. None of
    /// a text that is only space.
    pub async fn chunks(&self, http: &Client, text: &str) -> anyhow::Result<Vec<String>> {
        // Bytes no more than half the tokens allowed are no more tokens than allowed.
        cut(text, |piece: String| async move {
            Ok(piece.len() <= CHUNK_TOKENS / 2 || self.tokens(http, &piece).await? <= CHUNK_TOKENS)
        })
        .await
    }

    /// The vectors of `texts`, in their order, each of length one.
    pub async fn embed(&self, http: &Client, texts: &[String]) -> anyhow::Result<Vec<Vec<f32>>> {
        if texts.is_empty() {
            return Ok(Vec::new());
        }
        let answer = self
            .ask(
                http,
                "/v1/embeddings",
                json!({ "model": MODEL, "input": texts }),
            )
            .await?;
        vectors_in(&answer, texts.len())
    }

    /// Whether the model still answers.
    pub async fn alive(&self, http: &Client) -> bool {
        let health = http.get(format!("{}/health", self.url)).send().await;
        health.is_ok_and(|answer| answer.status().is_success())
    }

    /// Ends the model's process and waits until it is gone, so that its file
    /// can be deleted; also while others still hold this.
    pub async fn stop(&self) {
        let process = cw_core::lock(&self.process).take();
        if let Some(mut process) = process {
            // It fails only where the process has ended already.
            let _ = process.child.kill().await;
        }
    }

    async fn ask(&self, http: &Client, path: &str, body: Value) -> anyhow::Result<Value> {
        let answer = http
            .post(format!("{}{path}", self.url))
            .json(&body)
            .send()
            .await
            .context(
                Fail::said(Code::Unreachable, "the search model does not answer")
                    .with("whose", "search_model"),
            )?;
        let status = answer.status();
        ensure!(
            status.is_success(),
            Fail::said(
                Code::Answered,
                format!(
                    "the search model answered {status}: {}",
                    answer.text().await.unwrap_or_default()
                )
            )
            .with("whose", "search_model")
            .with("status", status.to_string())
        );
        Ok(answer.json().await?)
    }
}

/// The vectors of an answer in OpenAI's form to `count` texts, in their
/// order, each of length one.
fn vectors_in(answer: &Value, count: usize) -> anyhow::Result<Vec<Vec<f32>>> {
    let data = answer["data"].as_array().context(
        Fail::said(
            Code::ModelAnswer,
            "the search model's answer cannot be read",
        )
        .with("what", "search_model"),
    )?;
    ensure!(
        data.len() == count,
        Fail::said(
            Code::ModelAnswer,
            "the search model's answer cannot be read"
        )
        .with("what", "search_model")
    );
    let mut vectors = vec![Vec::new(); count];
    for item in data {
        let at = item["index"].as_u64().context(
            Fail::said(
                Code::ModelAnswer,
                "the search model's answer cannot be read",
            )
            .with("what", "search_model"),
        )? as usize;
        let numbers = item["embedding"].as_array().context(
            Fail::said(
                Code::ModelAnswer,
                "the search model's answer cannot be read",
            )
            .with("what", "search_model"),
        )?;
        let vector: Vec<f32> = numbers
            .iter()
            .map(|n| n.as_f64().unwrap_or(0.0) as f32)
            .collect();
        let length = vector.iter().map(|x| x * x).sum::<f32>().sqrt();
        ensure!(
            at < count && length > 0.0,
            Fail::said(
                Code::ModelAnswer,
                "the search model's answer cannot be read"
            )
            .with("what", "search_model")
        );
        vectors[at] = vector.iter().map(|x| x / length).collect();
    }
    let size = vectors[0].len();
    ensure!(
        vectors.iter().all(|vector| vector.len() == size),
        Fail::said(
            Code::ModelAnswer,
            "the search model's answer cannot be read"
        )
        .with("what", "search_model")
    );
    Ok(vectors)
}

/// `text` in pieces, in their order, each halved at its middle character
/// until `fits` holds of it or it is one character; none of a text that is
/// only space. Both readers cut so, each by its own measure.
/// (`fits` takes the piece owned: a closure borrowing it would keep the
/// server's tasks from being sent between threads.)
async fn cut<F>(text: &str, mut fits: impl FnMut(String) -> F) -> anyhow::Result<Vec<String>>
where
    F: Future<Output = anyhow::Result<bool>>,
{
    let mut pieces = Vec::new();
    let mut left = vec![text.trim().to_string()];
    while let Some(piece) = left.pop() {
        if piece.trim().is_empty() {
            continue;
        }
        if piece.chars().count() <= 1 || fits(piece.clone()).await? {
            pieces.push(piece);
            continue;
        }
        let (first, second) = halves(&piece);
        left.push(second);
        left.push(first);
    }
    Ok(pieces)
}

/// `piece` cut in two at its middle character.
fn halves(piece: &str) -> (String, String) {
    let half = piece
        .char_indices()
        .nth(piece.chars().count() / 2)
        .map_or(piece.len(), |(at, _)| at);
    let (first, second) = piece.split_at(half);
    (first.to_string(), second.to_string())
}

/// What turns an account's texts into vectors: this computer's model, or a provider's.
#[derive(Clone)]
pub enum Reader {
    Local(Arc<Running>),
    At(Arc<At>),
}

impl Reader {
    /// The name its vectors are kept with.
    pub fn stamp(&self) -> String {
        match self {
            Reader::Local(_) => MODEL.to_string(),
            Reader::At(at) => at.stamp(),
        }
    }

    /// `text` in pieces the model takes, in their order.
    pub async fn chunks(&self, http: &Client, text: &str) -> anyhow::Result<Vec<String>> {
        match self {
            Reader::Local(running) => running.chunks(http, text).await,
            Reader::At(at) => Ok(at.chunks(text)),
        }
    }

    /// The vectors of `texts`, in their order, each of length one.
    pub async fn embed(&self, http: &Client, texts: &[String]) -> anyhow::Result<Vec<Vec<f32>>> {
        match self {
            Reader::Local(running) => running.embed(http, texts).await,
            Reader::At(at) => at.embed(http, texts).await,
        }
    }

    /// Whether `failure` was the text's, the model answering: this
    /// computer's where it still answers, a provider's where it refused the text.
    pub async fn answers(&self, http: &Client, failure: &anyhow::Error) -> bool {
        match self {
            Reader::Local(running) => running.alive(http).await,
            Reader::At(_) => failure.is::<TextRefused>(),
        }
    }
}

/// The vector as stored: its numbers as 4 bytes each, little-endian.
pub fn to_bytes(vector: &[f32]) -> Vec<u8> {
    vector.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// The cosine of a vector of length one and one stored by [`to_bytes`].
pub fn cosine(vector: &[f32], stored: &[u8]) -> f32 {
    vector
        .iter()
        .zip(stored.as_chunks::<4>().0)
        .map(|(x, b)| x * f32::from_le_bytes(*b))
        .sum()
}

/// What keeps `llama-server` tied to the server: the process, which is killed
/// when this is dropped, and on Windows the job that kills it when the
/// server's process ends.
struct Process {
    child: tokio::process::Child,
    #[cfg(windows)]
    _job: cw_platform::sys::Job,
}

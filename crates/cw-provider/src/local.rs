//! The provider "This computer": the GGUF files of a folder the user chose, each
//! a chat model by its file's name, run with llama.cpp's `llama-server` as the
//! search model is (`Running::launch`): one model loaded at a time, on the
//! graphics card or else the processor, let go after `IDLE` without use.
//!
//! Its address ([`address_of`]) is the never-resolving host `HOST` with the
//! folder as the path's first segment. `send` hands such a request to
//! [`answer`]: `GET …/models` lists the folder ([`models`]), a chat goes to its
//! model's `llama-server`, loaded first. A typed address may not be this one.
//!
//! Traps: what runs the models is the process's ([`set_up`] by each app opened,
//! the last kept), as `send` knows no app. A model is let go or another loaded
//! only once no answer of it is read: each answer's body holds a [`Use`] until
//! dropped; [`let_go_of`] lets a model go before its file is removed.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex as StdMutex, OnceLock, Weak};
use std::time::Duration;

use anyhow::{Context, ensure};
use cw_core::lock;
use cw_core::{Code, Fail};
use cw_platform::http::{Body, Client, Method, Request, Response, ResponseBuilder, Url};
use futures_util::StreamExt;
use percent_encoding::{NON_ALPHANUMERIC, percent_decode_str, utf8_percent_encode};
use serde_json::{Value, json};
use tokio::sync::Mutex;
use tokio::time::{Instant, sleep};

use crate::embedder::{Runner, Running};
use crate::pretend::whole;

/// The host of its address.
const HOST: &str = "this-computer.cardwave.invalid";
/// Its name on the page.
pub const NAME: &str = "This computer";
/// How long a model stays loaded after its last answer was read.
pub const IDLE: Duration = Duration::from_secs(300);
/// How often a loaded model is looked at to be let go.
const LOOK_EVERY: Duration = Duration::from_secs(15);
/// What `llama-server` is started with beside the model's file; it fits the
/// context and the layers on the graphics card to its memory by itself.
const CHAT: &[&str] = &["--no-webui"];

/// What runs the models, and the log it writes.
#[derive(Clone, Debug)]
pub struct Setup {
    pub runner: Runner,
    pub log: PathBuf,
}

static SETUP: StdMutex<Option<Setup>> = StdMutex::new(None);
static LOADED: Mutex<Option<Loaded>> = Mutex::const_new(None);

/// The memory of the largest graphics card `llama-server` runs on, in bytes, as
/// its `--list-devices` tells, asked once ([`largest_card`]); none without a
/// card, before [`set_up`] or with a stand-in. Its whole memory, not what is
/// free, which a model loaded at the time would lower for the session.
pub(crate) fn graphics_memory() -> Option<u64> {
    static TOLD: OnceLock<Option<u64>> = OnceLock::new();
    let Runner::LlamaServer(folder) = lock(&SETUP).as_ref()?.runner.clone() else {
        return None;
    };
    *TOLD.get_or_init(|| {
        let mut command = std::process::Command::new(folder.join("llama-server"));
        command
            .arg("--list-devices")
            .stdin(std::process::Stdio::null());
        #[cfg(windows)]
        std::os::windows::process::CommandExt::creation_flags(
            &mut command,
            cw_platform::sys::NO_WINDOW,
        );
        let output = command.output().ok()?;
        let told = [output.stdout, output.stderr].concat();
        largest_card(&String::from_utf8_lossy(&told))
    })
}

/// The largest memory of the devices `llama-server --list-devices` lists
/// (`  Vulkan1: NVIDIA … (8188 MiB, 7420 MiB free)`), in bytes, a built-in
/// card's none: its memory is the computer's own, counted as such.
fn largest_card(listed: &str) -> Option<u64> {
    listed
        .lines()
        .filter_map(|line| {
            let (name, sizes) = line.trim_end().rsplit_once(" (")?;
            let (total, _) = sizes.split_once(" MiB, ")?;
            (!built_in(name)).then_some(total.parse::<u64>().ok()?)
        })
        .max()
        .map(|mib| mib << 20)
}

/// Whether a device's name is a card built into the processor: AMD's
/// "Radeon(TM) 780M Graphics", Intel's "UHD", "Iris Xe" and "Arc(TM) Graphics"
/// end in "Graphics"; a separate one does not, but Intel's "Arc(TM) A770 Graphics".
fn built_in(name: &str) -> bool {
    let separate_arc = name.split_once("Arc(TM) ").is_some_and(|(_, model)| {
        let mut chars = model.chars();
        chars.next().is_some_and(|c| c.is_ascii_uppercase())
            && chars.next().is_some_and(|c| c.is_ascii_digit())
    });
    name.ends_with(" Graphics") && !separate_arc
}

/// Has the models run as `setup` says from now on.
pub fn set_up(setup: Setup) {
    *lock(&SETUP) = Some(setup);
}

/// The model loaded, and who is reading its answers.
struct Loaded {
    file: PathBuf,
    running: Running,
    users: Arc<Users>,
}

/// How many answers of the model loaded are being read, and when the last
/// began or ended.
struct Users {
    reading: AtomicUsize,
    last: StdMutex<Instant>,
}

/// One answer of the model being read: it keeps the model loaded.
pub(crate) struct Use(Arc<Users>);

impl Use {
    fn of(users: &Arc<Users>) -> Self {
        users.reading.fetch_add(1, Ordering::SeqCst);
        *lock(&users.last) = Instant::now();
        Self(users.clone())
    }
}

impl Drop for Use {
    fn drop(&mut self) {
        *lock(&self.0.last) = Instant::now();
        self.0.reading.fetch_sub(1, Ordering::SeqCst);
    }
}

/// The address of the models of `folder`.
pub fn address_of(folder: &Path) -> anyhow::Result<String> {
    let folder = folder.to_str().context(
        Fail::said(Code::NotReadable, "the folder's name cannot be read")
            .with("what", "folder_read"),
    )?;
    let segment = utf8_percent_encode(folder, NON_ALPHANUMERIC);
    Ok(format!("https://{HOST}/{segment}/v1"))
}

/// The folder of a URL of This computer's, or none for any other URL.
fn folder_of(url: &Url) -> Option<PathBuf> {
    if url.host_str() != Some(HOST) {
        return None;
    }
    let segment = url.path_segments()?.next()?;
    let folder = percent_decode_str(segment).decode_utf8().ok()?;
    Some(PathBuf::from(folder.as_ref()))
}

/// The folder of This computer's address `base_url`, or none for another address.
pub(crate) fn folder_at(base_url: &str) -> Option<PathBuf> {
    folder_of(&Url::parse(base_url).ok()?)
}

/// Whether `base_url` is This computer's.
pub fn at(base_url: &str) -> bool {
    Url::parse(base_url).is_ok_and(|url| url.host_str() == Some(HOST))
}

/// Whether `request` is for This computer.
pub fn asked(request: &Request) -> bool {
    request.url().host_str() == Some(HOST)
}

/// The models of `folder`, by their files' names, in order: every GGUF file
/// but a vision model's projector and the later parts of a split model.
pub fn models(folder: &Path) -> anyhow::Result<Vec<String>> {
    let read = std::fs::read_dir(folder).with_context(|| {
        Fail::said(
            Code::NotReadable,
            format!("the folder {} cannot be read", folder.display()),
        )
        .with("what", "folder_read")
        .with("folder", (folder.display()).to_string())
    })?;
    let mut models: Vec<String> = read
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let name = entry.file_name().into_string().ok()?;
            let lower = name.to_lowercase();
            // A link to a model's file counts as the file.
            let model = lower.ends_with(".gguf")
                && !lower.contains("mmproj")
                && later_part(&lower).is_none_or(|part| part == 1)
                && std::fs::metadata(entry.path()).ok()?.is_file();
            model.then_some(name)
        })
        .collect();
    models.sort_by_key(|name| name.to_lowercase());
    Ok(models)
}

/// The part of a split model's file (`…-00002-of-00003.gguf`), where it is one.
fn later_part(name: &str) -> Option<u32> {
    split_name(name).map(|(_, part, _)| part)
}

/// A split model's file's name (`Big-00002-of-00003.gguf`, in any case) as
/// its stem in lower case, its part and its count of parts, where it is one.
pub(crate) fn split_name(name: &str) -> Option<(String, u32, u32)> {
    let lower = name.to_lowercase();
    let (rest, count) = lower.strip_suffix(".gguf")?.rsplit_once("-of-")?;
    let (stem, part) = rest.rsplit_once('-')?;
    let digits = |text: &str| text.len() == 5 && text.bytes().all(|b| b.is_ascii_digit());
    (digits(part) && digits(count)).then_some(())?;
    Some((stem.into(), part.parse().ok()?, count.parse().ok()?))
}

/// This computer's answer to `request`, as an OpenAI-compatible API answers.
pub async fn answer(http: &Client, mut request: Request) -> cw_platform::http::Result<Response> {
    let Some(folder) = folder_of(request.url()) else {
        return Ok(refused(404, "not found".into()));
    };
    let path = request.url().path().to_string();
    if request.method() == Method::GET && path.ends_with("/models") {
        return Ok(match models(&folder) {
            Ok(ids) => {
                let data: Vec<Value> = ids
                    .iter()
                    .map(|id| json!({ "id": id, "object": "model" }))
                    .collect();
                whole(200, json!({ "object": "list", "data": data }))
            }
            Err(error) => failed(404, &error),
        });
    }
    if request.method() != Method::POST || !path.ends_with("/chat/completions") {
        return Ok(refused(404, "not found".into()));
    }
    let asked = request
        .body()
        .and_then(Body::as_bytes)
        .and_then(|body| serde_json::from_slice::<Value>(body).ok());
    let id = asked
        .as_ref()
        .and_then(|asked| asked["model"].as_str())
        .unwrap_or_default();
    let file = match model_file(&folder, id) {
        Ok(file) => file,
        Err(error) => return Ok(failed(404, &error)),
    };
    let (url, authorization, using) = match load(http, &file).await {
        Ok(loaded) => loaded,
        Err(error) => return Ok(failed(503, &error)),
    };
    // The address was made by `launch`, a plain one with a port.
    let url = Url::parse(&format!("{url}/v1/chat/completions")).expect("a URL");
    *request.url_mut() = url;
    let authorization = authorization.parse().expect("a header value of hex");
    let name = cw_platform::http::header::AUTHORIZATION;
    request.headers_mut().insert(name, authorization);
    let response = http.execute(request).await?;
    Ok(held(response, using))
}

/// The file of the model `id` in `folder`, where it is one of its models.
fn model_file(folder: &Path, id: &str) -> anyhow::Result<PathBuf> {
    ensure!(
        models(folder)?.iter().any(|model| model == id),
        Fail::said(
            Code::NotPossible,
            format!("there is no model “{id}” in {}", folder.display())
        )
        .with("what", "no_local_model")
        .with("id", id.to_string())
        .with("folder", (folder.display()).to_string())
    );
    Ok(folder.join(id))
}

/// The address of `llama-server` with the model's `file` loaded, loading it
/// in place of another first, its `Authorization` header and a use of it.
async fn load(http: &Client, file: &Path) -> anyhow::Result<(String, String, Use)> {
    let mut loaded = LOADED.lock().await;
    if let Some(now) = loaded.as_ref().filter(|now| now.file == file) {
        // One that ended (out of memory, ended by hand) is started anew.
        if now.running.alive(http).await {
            let running = &now.running;
            let using = Use::of(&now.users);
            return Ok((running.url().into(), running.authorization(), using));
        }
    }
    // Another model's answers are read to their end first; given up on
    // meanwhile, the request leaves it loaded.
    while loaded.as_ref().is_some_and(|before| {
        before.file != file && before.users.reading.load(Ordering::SeqCst) > 0
    }) {
        sleep(Duration::from_millis(100)).await;
    }
    if let Some(before) = loaded.take() {
        before.running.stop().await;
    }
    let setup = lock(&SETUP).clone().context(
        Fail::said(Code::NotPossible, "local models are not set up")
            .with("what", "no_local_models"),
    )?;
    let running = Running::launch(http, &setup.runner, file, &setup.log, CHAT).await?;
    let users = Arc::new(Users {
        reading: AtomicUsize::new(0),
        last: StdMutex::new(Instant::now()),
    });
    tokio::spawn(let_go_when_idle(Arc::downgrade(&users)));
    let using = Use::of(&users);
    let url = running.url().to_string();
    let authorization = running.authorization();
    *loaded = Some(Loaded {
        file: file.to_path_buf(),
        running,
        users,
    });
    Ok((url, authorization, using))
}

/// Lets the model of `users` go once it was not used for `IDLE`; ends when
/// it is gone.
async fn let_go_when_idle(users: Weak<Users>) {
    while users.strong_count() > 0 {
        sleep(LOOK_EVERY).await;
        let mut loaded = LOADED.lock().await;
        let ours = loaded
            .as_ref()
            .is_some_and(|now| std::ptr::eq(Arc::as_ptr(&now.users), users.as_ptr()));
        if ours {
            let_go(&mut loaded, IDLE).await;
        }
    }
}

/// Lets the model loaded go where no answer of it is being read and the last
/// ended `idle` ago or more.
async fn let_go(loaded: &mut Option<Loaded>, idle: Duration) {
    let idle = loaded.as_ref().is_some_and(|now| {
        now.users.reading.load(Ordering::SeqCst) == 0 && lock(&now.users.last).elapsed() >= idle
    });
    if idle && let Some(before) = loaded.take() {
        before.running.stop().await;
    }
}

/// Lets the model of `file` go where it is loaded, so that its file can be
/// removed (`fit`); refused while an answer of it is being read.
pub(crate) async fn let_go_of(file: &Path) -> anyhow::Result<()> {
    let mut loaded = LOADED.lock().await;
    if let Some(now) = loaded.as_ref().filter(|now| now.file == file) {
        ensure!(
            now.users.reading.load(Ordering::SeqCst) == 0,
            Fail::said(
                Code::NotNow,
                "the model is replying; remove it once the reply has ended"
            )
            .with("what", "model_replying")
        );
        if let Some(before) = loaded.take() {
            before.running.stop().await;
        }
    }
    Ok(())
}

/// Lets the model loaded go as when `idle` passed without use (for the tests),
/// and says which model is loaded then.
pub async fn idle_for(idle: Duration) -> Option<PathBuf> {
    let mut loaded = LOADED.lock().await;
    let_go(&mut loaded, idle).await;
    loaded.as_ref().map(|now| now.file.clone())
}

/// `response`, whose body holds `using` until it is read or dropped.
fn held(response: Response, using: Use) -> Response {
    let mut answer = ResponseBuilder::new().status(response.status());
    for (name, value) in response.headers() {
        answer = answer.header(name, value);
    }
    let body = response.bytes_stream().map(move |piece| {
        let _held = &using;
        piece
    });
    // The status and headers are those of an answer.
    Response::from(answer.body(Body::wrap_stream(body)).expect("an answer"))
}

/// An error answer saying `message`.
/// The key of a refusal's body under which [`failed`] puts the failure's
/// `ErrorBody`, which `provider::succeeded` raises again with its code.
pub(crate) const OWN: &str = "cardwave";

/// A refusal for a failure of this provider's own, its code kept.
fn failed(status: u16, error: &anyhow::Error) -> Response {
    let message = format!("{error:#}");
    whole(
        status,
        json!({ "error": { "message": message }, OWN: cw_core::told(error, Code::Internal) }),
    )
}

fn refused(status: u16, message: String) -> Response {
    whole(status, json!({ "error": { "message": message } }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_largest_cards_memory_is_read_from_the_device_list_without_a_built_in_one() {
        let listed = "Available devices:
  Vulkan0: AMD Radeon(TM) 780M Graphics (16444 MiB, 15622 MiB free)
  Vulkan1: NVIDIA GeForce RTX 4060 Laptop GPU (8188 MiB, 7420 MiB free)
";
        assert_eq!(
            largest_card(listed),
            Some(8188 << 20),
            "its whole memory, the built-in's none"
        );
        let intel = "  Vulkan0: Intel(R) Iris(R) Xe Graphics (8000 MiB, 7000 MiB free)
  Vulkan1: Intel(R) Arc(TM) A770 Graphics (16032 MiB, 15000 MiB free)
";
        assert_eq!(largest_card(intel), Some(16032 << 20));
        assert_eq!(
            largest_card(
                "Available devices:
"
            ),
            None
        );
    }

    #[test]
    fn its_address_carries_the_folder() {
        let folder = Path::new(r"C:\Users\Ann Lee\Models/ü");
        let address = address_of(folder).unwrap();
        assert!(at(&address));
        assert_eq!(folder_at(&format!("{address}/models")).unwrap(), folder);
        assert!(!at("https://api.openai.com/v1"));
    }

    #[test]
    fn a_split_model_is_listed_by_its_first_part() {
        assert_eq!(later_part("big-00001-of-00003.gguf"), Some(1));
        assert_eq!(later_part("big-00002-of-00003.gguf"), Some(2));
        assert_eq!(later_part("qwen3-8b-q4_k_m.gguf"), None);
        assert_eq!(
            split_name("Big-00002-OF-00003.GGUF"),
            Some(("big".into(), 2, 3))
        );
        assert_eq!(split_name("big-2-of-3.gguf"), None);
    }
}

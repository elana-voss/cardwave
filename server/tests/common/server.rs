//! A running server for the tests that go over HTTP.
//!
//! `start()` is a server of its own per test, with `get`, `post`, `patch`,
//! `put`, `call`, `upload`, `add_card` and `chat_with` (a card imported, a
//! chat started), and `set_provider`/`set_images` as first run stores them; `listen` opens the event socket, `listen_as` as a page that calls
//! itself by a mark (`call_as`). Variants: `start_asking` (the provider search
//! asks the test's server, `https://host/path` as `/host/path`, and fetches
//! models.dev's list there), `start_searching`/`start_voicing` (the search
//! model or voice is a stand-in), `start_offering` (This computer offers the
//! test's models to download, else none), `start_storing` (the key in the credential
//! store under the test's own service). The home network listens on loopback.
//! A test may open the database a second time (`Db::open` on
//! `server.options()`) to plant what the API cannot. `Device` is a browser
//! that keeps its cookie, at the home network's address (`phone`) or the
//! server's; `device` signs one in to a new account. `until` polls a probe
//! until it holds, failing after `WAIT`.

use std::future::Future;
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use cardwave_server::{Network, Options, bind_local, router, serve};
use cw_core::ErrorBody;
use cw_dictation as dictation;
use cw_key::{DbKey, Place};
use cw_library::faces::Opener;
use cw_provider::embedder::Setup;
use cw_provider::fit::Offered;
use cw_voice as voice;
use futures_util::StreamExt;
use reqwest::Method;
use serde_json::{Value, json};
use tokio::net::TcpStream;
use tokio::sync::oneshot;
use tokio::time::{Instant, sleep, timeout};
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::{MaybeTlsStream, WebSocketStream};

/// How long a test waits for something that should come at once.
pub const WAIT: Duration = Duration::from_secs(10);

/// Asks `probe` every 20 ms until it answers `Ok`, which it returns; past `WAIT`
/// the test fails with its last `Err`, which says what it found.
pub async fn until<T, F, Fut>(mut probe: F) -> T
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, String>>,
{
    let end = Instant::now() + WAIT;
    loop {
        match probe().await {
            Ok(done) => return done,
            Err(found) => assert!(Instant::now() < end, "{found}"),
        }
        sleep(Duration::from_millis(20)).await;
    }
}

static NEXT: AtomicUsize = AtomicUsize::new(0);

/// A running server on a free port; on drop it is stopped and its scratch data
/// folder removed.
pub struct Server {
    pub addr: String,
    /// What looks for faces: by default nothing, the model staying shut.
    faces: Option<Opener>,
    /// The data folder.
    pub dir: PathBuf,
    /// Where the database's key is kept: given, but by `start_storing`.
    place: Place,
    /// Where the server looks for a provider's API, in place of the provider's hosts.
    places: Option<String>,
    /// Where the search model comes from and what runs it: by default bge-m3
    /// from no folder, which a test never downloads.
    search: Option<Setup>,
    /// What the voice downloads and what speaks: by default Pocket TTS, which a
    /// test never downloads.
    voice: Option<voice::Setup>,
    /// What dictation downloads and what hears: by default Whisper, which a
    /// test never downloads.
    dictation: Option<dictation::Setup>,
    /// The models This computer offers to download: by default none.
    offered: Vec<Offered>,
    stop: Option<oneshot::Sender<()>>,
    thread: Option<std::thread::JoinHandle<()>>,
}

impl Drop for Server {
    fn drop(&mut self) {
        // The folder can only go once the server has closed the database.
        self.halt();
        if self.dir.as_os_str().is_empty() {
            return;
        }
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

/// Starts a server on a free port with its own scratch data folder.
pub async fn start() -> Server {
    start_asking(None).await
}

/// [`start`], with the server looking for a provider's API at `places`, a
/// server of the test's own, in place of the provider's hosts.
pub async fn start_asking(places: Option<String>) -> Server {
    start_with(places, None).await
}

/// [`start`], with the search model coming from and run as `search` says:
/// a stand-in of the test's own (`common::embedder`).
pub async fn start_searching(search: Setup) -> Server {
    start_with(None, Some(search)).await
}

/// [`start`], with the voice downloading and speaking as `voice` says.
pub async fn start_voicing(voice: voice::Setup) -> Server {
    let key = Place::Given(DbKey::generate().unwrap());
    run_with(scratch(), key, None, None, Some(voice), Vec::new(), None).await
}

/// [`start`], with `faces` looking for the faces on the pictures.
pub async fn start_looking(faces: Opener) -> Server {
    let key = Place::Given(DbKey::generate().unwrap());
    let mut server = built(scratch(), key, None, None, None, Vec::new(), None);
    server.faces = Some(faces);
    listening(server).await
}

/// [`start`], with dictation downloading and hearing as `dictation` says.
pub async fn start_dictating(dictation: dictation::Setup) -> Server {
    let key = Place::Given(DbKey::generate().unwrap());
    run_with(
        scratch(),
        key,
        None,
        None,
        None,
        Vec::new(),
        Some(dictation),
    )
    .await
}

/// [`start_searching`], with This computer offering `offered` to download.
pub async fn start_offering(search: Setup, offered: Vec<Offered>) -> Server {
    let key = Place::Given(DbKey::generate().unwrap());
    run_with(scratch(), key, None, Some(search), None, offered, None).await
}

/// [`start`], with the database's key kept in the credential store under
/// `service`, which is the test's own.
pub async fn start_storing(service: &str) -> Server {
    run(scratch(), Place::Store(service.into()), None, None).await
}

async fn start_with(places: Option<String>, search: Option<Setup>) -> Server {
    let key = Place::Given(DbKey::generate().unwrap());
    run(scratch(), key, places, search).await
}

/// A new, empty data folder of the test's own. Windows hands a process id out
/// again, and a folder an earlier run left behind holds a database of another
/// key, so a name taken is skipped.
fn scratch() -> PathBuf {
    loop {
        let n = NEXT.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join(format!("cardwave-test-{}-{n}", std::process::id()));
        match std::fs::create_dir(&dir) {
            Ok(()) => return dir,
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => panic!("cannot make {}: {e}", dir.display()),
        }
    }
}

/// Runs a server on the data folder `dir`, on its own thread so that dropping
/// it can wait for the shutdown.
async fn run(dir: PathBuf, place: Place, places: Option<String>, search: Option<Setup>) -> Server {
    run_with(dir, place, places, search, None, Vec::new(), None).await
}

async fn run_with(
    dir: PathBuf,
    place: Place,
    places: Option<String>,
    search: Option<Setup>,
    voice: Option<voice::Setup>,
    offered: Vec<Offered>,
    dictation: Option<dictation::Setup>,
) -> Server {
    listening(built(dir, place, places, search, voice, offered, dictation)).await
}

fn built(
    dir: PathBuf,
    place: Place,
    places: Option<String>,
    search: Option<Setup>,
    voice: Option<voice::Setup>,
    offered: Vec<Offered>,
    dictation: Option<dictation::Setup>,
) -> Server {
    Server {
        faces: None,
        addr: String::new(),
        dir,
        place,
        places,
        search,
        voice,
        dictation,
        offered,
        stop: None,
        thread: None,
    }
}

async fn listening(mut server: Server) -> Server {
    let app = router(server.options()).unwrap();
    let listener = bind_local(0..=0).await.unwrap().into_std().unwrap();
    server.addr = listener.local_addr().unwrap().to_string();
    let (stop, stopped) = oneshot::channel::<()>();
    server.stop = Some(stop);
    server.thread = Some(std::thread::spawn(move || {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let listener = tokio::net::TcpListener::from_std(listener).unwrap();
            let _ = serve(listener, app, async {
                let _ = stopped.await;
            })
            .await;
        });
    }));
    server
}

/// The event socket, as a page holds it.
pub type Socket = WebSocketStream<MaybeTlsStream<TcpStream>>;

/// The next event the server pushes.
pub async fn event(socket: &mut Socket) -> Value {
    let message = timeout(WAIT, socket.next())
        .await
        .expect("no event came")
        .unwrap()
        .unwrap();
    serde_json::from_str(message.to_text().unwrap()).unwrap()
}

impl Server {
    /// What a server on this one's data folder is started with.
    pub fn options(&self) -> Options {
        Options {
            data_dir: self.dir.clone(),
            web_dir: None,
            key: self.place.clone(),
            provider_places: self.places.clone(),
            faces: self.faces.clone(),
            models_dev: self
                .places
                .as_ref()
                .map(|places| format!("{places}/models.dev/api.json")),
            search: self
                .search
                .clone()
                .unwrap_or_else(|| Setup::bge_m3(PathBuf::new())),
            voice: self.voice.clone().unwrap_or_else(voice::Setup::pocket),
            dictation: self
                .dictation
                .clone()
                .unwrap_or_else(dictation::Setup::turbo),
            local_models: self.offered.clone(),
            network: Network::loopback(),
            watch_every: std::time::Duration::from_millis(50),
            documents: Some(self.dir.join("Documents")),
            account_name: "local".into(),
        }
    }

    /// Stops the server and starts it again on the same data folder, as when
    /// the app is closed and opened. Sockets to it have to be closed first.
    pub async fn restart(mut self) -> Server {
        self.halt();
        // What still holds the old server (a task ending under a full run's
        // load) holds its lock: the new one would not tidy as the first.
        let lock = std::fs::File::options()
            .write(true)
            .create(true)
            .truncate(false)
            .open(self.dir.join("server.lock"))
            .unwrap();
        for _ in 0..100 {
            if lock.try_lock().is_ok() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
        drop(lock);
        let places = self.places.take();
        let search = self.search.take();
        let voice = self.voice.take();
        let offered = std::mem::take(&mut self.offered);
        let dictation = self.dictation.take();
        run_with(
            std::mem::take(&mut self.dir),
            self.place.clone(),
            places,
            search,
            voice,
            offered,
            dictation,
        )
        .await
    }

    fn halt(&mut self) {
        drop(self.stop.take());
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }

    /// Opens the event socket, as a page does.
    pub async fn listen(&self) -> Socket {
        self.listen_at("/ws").await
    }

    /// Opens the event socket as the page `page` does, which is not told of its own changes.
    pub async fn listen_as(&self, page: &str) -> Socket {
        self.listen_at(&format!("/ws?page={page}")).await
    }

    async fn listen_at(&self, path: &str) -> Socket {
        let (mut socket, _) = tokio_tungstenite::connect_async(format!("ws://{}{path}", self.addr))
            .await
            .unwrap();
        assert_eq!(event(&mut socket).await["type"], "hello");
        socket
    }

    /// Sends a request as the page `page` does, which calls itself so in a header.
    pub async fn call_as(
        &self,
        page: &str,
        method: Method,
        path: &str,
        body: Value,
    ) -> (u16, Value) {
        let request = reqwest::Client::new()
            .request(method, format!("http://{}{path}", self.addr))
            .header("x-cardwave-page", page)
            .json(&body);
        answer(request.send().await.unwrap()).await
    }

    /// Sends a request and returns the answer's status and JSON body (`Null` when it has none).
    pub async fn call(&self, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
        let mut request =
            reqwest::Client::new().request(method, format!("http://{}{path}", self.addr));
        if let Some(body) = body {
            request = request.json(&body);
        }
        answer(request.send().await.unwrap()).await
    }

    pub async fn get(&self, path: &str) -> (u16, Value) {
        self.call(Method::GET, path, None).await
    }

    pub async fn post(&self, path: &str, body: Value) -> (u16, Value) {
        self.call(Method::POST, path, Some(body)).await
    }

    pub async fn patch(&self, path: &str, body: Value) -> (u16, Value) {
        self.call(Method::PATCH, path, Some(body)).await
    }

    pub async fn put(&self, path: &str, body: Value) -> (u16, Value) {
        self.call(Method::PUT, path, Some(body)).await
    }

    /// Stores the chat model as first run's "Confirm" does (`PUT /api/provider`).
    pub async fn set_provider(&self, provider: Value) -> (u16, Value) {
        self.put("/api/provider", provider).await
    }

    /// Picks the image model `{ model, base_url?, api_key? }`: at the
    /// provider of its address, added where there is none, else at the chat
    /// model's. Answers the first refusal, else `GET /api/images`.
    pub async fn set_images(&self, own: Value) -> (u16, Value) {
        let at = match own.get("base_url") {
            Some(base_url) => {
                let mut entry = json!({ "base_url": base_url });
                if let Some(key) = own.get("api_key") {
                    entry["api_key"] = key.clone();
                }
                let (status, entry) = self.post("/api/provider-list", entry).await;
                if status >= 300 {
                    return (status, entry);
                }
                entry["id"].clone()
            }
            None => {
                let (_, list) = self.get("/api/provider-list").await;
                let kinds = list["kinds"].as_array().cloned().unwrap_or_default();
                let chat = kinds.iter().find(|kind| kind["kind"] == "chat");
                chat.map(|chat| chat["provider_id"].clone())
                    .unwrap_or_default()
            }
        };
        let pick = json!({ "provider_id": at, "model": own["model"] });
        let (status, why) = self.put("/api/kinds/images", pick).await;
        if status >= 300 {
            return (status, why);
        }
        self.get("/api/images").await
    }

    /// Edits the card `id` as its editor would: `change` is made in what the
    /// editor shows, which is saved. Answers with what the save answers.
    pub async fn edit_card(&self, id: &Value, change: impl FnOnce(&mut Value)) -> (u16, Value) {
        let path = format!("/api/cards/{id}/edit");
        let (_, mut form) = self.get(&path).await;
        change(&mut form);
        self.put(&path, form).await
    }

    /// Uploads a file as the request body.
    pub async fn upload(&self, path: &str, file: Vec<u8>) -> (u16, Value) {
        answer(
            reqwest::Client::new()
                .post(format!("http://{}{path}", self.addr))
                .body(file)
                .send()
                .await
                .unwrap(),
        )
        .await
    }

    /// Imports the card `file`, with all its characters where `whole`
    /// (`upload_whole`): its card's and its version's IDs.
    pub async fn add_card(&self, file: Vec<u8>, whole: bool) -> (i64, i64) {
        let (status, imported) = match whole {
            true => self.upload_whole(file).await,
            false => self.upload("/api/cards", file).await,
        };
        assert_eq!(status, 201, "{imported}");
        let id = |name: &str| imported[name].as_i64().unwrap();
        (id("card_id"), id("version_id"))
    }

    /// Starts a chat with `characters`, each (card version, ID in the card),
    /// at the greeting `greeting`: its view.
    pub async fn chat_with(&self, characters: &[(i64, &str)], greeting: usize) -> Value {
        let characters: Vec<Value> = characters
            .iter()
            .map(|(version, character)| json!({ "version_id": version, "character": character }))
            .collect();
        let new = json!({ "characters": characters, "greeting": greeting });
        let (status, view) = self.post("/api/chats", new).await;
        assert_eq!(status, 201, "{view}");
        view
    }

    /// Uploads the card `file` with all its characters (`super::import_whole`).
    pub async fn upload_whole(&self, file: Vec<u8>) -> (u16, Value) {
        let (status, imported) = self.upload("/api/cards", file.clone()).await;
        if status == 201 {
            let options = self.options();
            let db = cw_store::Db::open(
                &options.data_dir.join(cw_key::FILE_NAME),
                options.key.given().unwrap(),
            )
            .unwrap();
            super::plant_whole(&db, imported["version_id"].as_i64().unwrap(), &file);
        }
        (status, imported)
    }

    /// The answer to "Back up", sent with `password` where it is given, as the page's form sends it.
    pub async fn save_backup(&self, password: Option<&str>) -> reqwest::Response {
        let form: Vec<_> = password.map(|p| ("password", p)).into_iter().collect();
        reqwest::Client::new()
            .post(format!("http://{}/api/backup/save", self.addr))
            .form(&form)
            .send()
            .await
            .unwrap()
    }

    pub async fn download(&self, path: &str) -> (reqwest::header::HeaderMap, Vec<u8>) {
        let response = reqwest::get(format!("http://{}{path}", self.addr))
            .await
            .unwrap();
        assert_eq!(response.status(), 200, "{path}");
        (
            response.headers().clone(),
            response.bytes().await.unwrap().to_vec(),
        )
    }
}

/// A browser: where it is, and the session its cookie holds.
pub struct Device {
    pub base: String,
    pub cookie: Option<String>,
}

impl Device {
    pub fn at(base: &str) -> Self {
        Self {
            base: base.trim_end_matches('/').to_string(),
            cookie: None,
        }
    }

    pub async fn call(&mut self, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
        let mut request = reqwest::Client::new().request(method, format!("{}{path}", self.base));
        if let Some(cookie) = &self.cookie {
            request = request.header("cookie", cookie);
        }
        if let Some(body) = body {
            request = request.json(&body);
        }
        let response = request.send().await.unwrap();
        if let Some(set) = response.headers().get("set-cookie") {
            let pair = set.to_str().unwrap().split(';').next().unwrap().to_string();
            self.cookie = Some(pair).filter(|pair| !pair.ends_with('='));
        }
        let status = response.status().as_u16();
        if status == 401 && response.headers().contains_key("x-cardwave-sign-in") {
            return (status, json!("sign in"));
        }
        (status, response.json().await.unwrap_or(Value::Null))
    }

    pub async fn get(&mut self, path: &str) -> (u16, Value) {
        self.call(Method::GET, path, None).await
    }

    pub async fn post(&mut self, path: &str, body: Value) -> (u16, Value) {
        self.call(Method::POST, path, Some(body)).await
    }

    /// Signs in to `account` with `password`: the answer's status.
    pub async fn sign_in(&mut self, account: i64, password: Option<&str>) -> u16 {
        let with = json!({ "account": account, "password": password });
        self.post("/api/sign-in", with).await.0
    }

    /// The names of the personas of the account it is signed in to.
    pub async fn personas(&mut self) -> Vec<String> {
        let (status, list) = self.get("/api/personas").await;
        assert_eq!(status, 200, "{list}");
        let names = list.as_array().unwrap().iter();
        names.map(|p| p["name"].as_str().unwrap().into()).collect()
    }

    /// Opens the event socket, with the cookie.
    pub async fn listen(&self) -> Result<Socket, String> {
        let address = format!("{}/ws", self.base.replacen("http", "ws", 1));
        let mut request = address.into_client_request().unwrap();
        if let Some(cookie) = &self.cookie {
            request
                .headers_mut()
                .insert("cookie", cookie.parse().unwrap());
        }
        match tokio_tungstenite::connect_async(request).await {
            Ok((mut socket, _)) => {
                assert_eq!(event(&mut socket).await["type"], "hello");
                Ok(socket)
            }
            Err(failure) => Err(failure.to_string()),
        }
    }
}

/// Lets other devices reach `server`, and a device there.
pub async fn phone(server: &Server) -> Device {
    let (status, network) = server.put("/api/network", json!({ "on": true })).await;
    assert_eq!(status, 200, "{network}");
    assert_eq!(network["on"], true);
    Device::at(network["address"].as_str().unwrap())
}

/// A browser at `server`'s own address, or with `network` at the home
/// network's, signed in to a new account "Ada" with the password "lantern".
pub async fn device(server: &Server, network: bool) -> Device {
    let mut device = match network {
        true => phone(server).await,
        false => Device::at(&format!("http://{}", server.addr)),
    };
    let account = json!({ "name": "Ada", "password": "lantern" });
    let (status, added) = server.post("/api/accounts", account).await;
    assert_eq!(status, 201, "{added}");
    let ada = added["id"].as_i64().unwrap();
    assert_eq!(device.sign_in(ada, Some("lantern")).await, 204);
    device
}

/// The answer's status and JSON body (`Null` when it has none). Every error
/// answer is an `ErrorBody`: a code from the one list, a text and details.
pub async fn answer(response: reqwest::Response) -> (u16, Value) {
    let status = response.status().as_u16();
    let body = response.json().await.unwrap_or(Value::Null);
    if status >= 400 {
        let said = serde_json::from_value::<ErrorBody>(body.clone());
        let said = said.unwrap_or_else(|e| panic!("{status} {body}: no error body ({e})"));
        assert!(!said.error.is_empty(), "{status} without an error text");
    }
    (status, body)
}

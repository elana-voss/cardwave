//! The password over the database key, and backups (`password.rs`, `backup.rs`):
//! a server whose password is on starts locked, and a backup, always sealed by
//! a password, is read back by another server, which keeps its own key.

mod common;

use common::server::{Server, answer, event, start};
use cw_key::FILE_NAME;
use cw_store::Db;
use futures_util::StreamExt;
use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use serde_json::{Value, json};
use tokio_tungstenite::tungstenite::Message;

/// Makes a persona called `name`, which is data the test can find again.
async fn persona(server: &Server, name: &str) {
    let made = server
        .post("/api/personas", json!({ "name": name, "description": "" }))
        .await;
    assert_eq!(made.0, 201, "{}", made.1);
}

/// The names of the server's personas.
async fn personas(server: &Server) -> Vec<String> {
    let (status, list) = server.get("/api/personas").await;
    assert_eq!(status, 200, "{list}");
    list.as_array()
        .unwrap()
        .iter()
        .map(|p| p["name"].as_str().unwrap().to_string())
        .collect()
}

async fn set_password(server: &Server, change: Value) -> (u16, Value) {
    server.put("/api/password", change).await
}

async fn unlock(server: &Server, password: &str) -> u16 {
    server
        .post("/api/unlock", json!({ "password": password }))
        .await
        .0
}

#[tokio::test]
async fn a_password_switched_on_is_asked_for_at_the_next_start() {
    let server = start().await;
    persona(&server, "Wanderer").await;
    assert_eq!(
        server.get("/api/lock").await,
        (
            200,
            json!({ "locked": false, "password": false, "name": null })
        )
    );
    let on = set_password(&server, json!({ "password": "harbour lights" })).await;
    assert_eq!(
        on,
        (
            200,
            json!({ "locked": false, "password": true, "name": null })
        )
    );
    // The name the start screen shows follows a rename.
    server.put("/api/account", json!({ "name": "Rowan" })).await;

    let server = server.restart().await;
    // Locked: the start screen has the account's name, and nothing else is answered.
    assert_eq!(
        server.get("/api/lock").await,
        (
            200,
            json!({ "locked": true, "password": true, "name": "Rowan" })
        )
    );
    let (status, refused) = server.get("/api/personas").await;
    assert_eq!(status, 423, "{refused}");
    assert_eq!(unlock(&server, "harbour light").await, 401);
    assert_eq!(server.get("/api/personas").await.0, 423);

    assert_eq!(unlock(&server, "harbour lights").await, 204);
    assert_eq!(personas(&server).await, ["Wanderer"]);
    assert_eq!(server.get("/api/lock").await.1["locked"], false);
    // A second try finds it open.
    assert_eq!(unlock(&server, "anything").await, 204);
}

#[tokio::test]
async fn lock_has_the_app_wait_for_the_password_and_ends_every_socket() {
    let server = start().await;
    // Without a password there is nothing to lock with.
    assert_eq!(server.post("/api/password/lock", json!({})).await.0, 400);
    set_password(&server, json!({ "password": "harbour lights" })).await;
    persona(&server, "Wanderer").await;
    let mut socket = server.listen().await;

    assert_eq!(server.post("/api/password/lock", json!({})).await.0, 204);
    let ended = tokio::time::timeout(common::server::WAIT, socket.next())
        .await
        .expect("the socket stays open");
    assert!(!matches!(ended, Some(Ok(Message::Text(_)))), "{ended:?}");
    assert_eq!(server.get("/api/lock").await.1["locked"], true);
    assert_eq!(server.get("/api/personas").await.0, 423);
    assert_eq!(unlock(&server, "harbour light").await, 401);
    assert_eq!(server.get("/api/personas").await.0, 423);

    assert_eq!(unlock(&server, "harbour lights").await, 204);
    assert_eq!(personas(&server).await, ["Wanderer"]);
    assert_eq!(server.get("/api/lock").await.1["locked"], false);
}

#[tokio::test]
async fn a_password_is_changed_and_switched_off_with_the_current_one() {
    let server = start().await;
    assert_eq!(
        set_password(&server, json!({ "password": "" })).await.0,
        400
    );
    // None is on: there is none to switch off.
    assert_eq!(
        set_password(&server, json!({})).await.1["code"],
        "no_password_on"
    );
    set_password(&server, json!({ "password": "first" })).await;

    // Without the current password, or with a wrong one, nothing changes.
    assert_eq!(
        set_password(&server, json!({ "password": "second" }))
            .await
            .0,
        401
    );
    assert_eq!(
        set_password(&server, json!({ "current": "frist", "password": "second" }))
            .await
            .0,
        401
    );
    let changed = set_password(&server, json!({ "current": "first", "password": "second" })).await;
    assert_eq!(changed.1["password"], true);

    let server = server.restart().await;
    assert_eq!(unlock(&server, "first").await, 401);
    assert_eq!(unlock(&server, "second").await, 204);

    assert_eq!(
        set_password(&server, json!({ "current": "first" })).await.0,
        401
    );
    let off = set_password(&server, json!({ "current": "second" })).await;
    assert_eq!(off.1["password"], false);
    let server = server.restart().await;
    assert_eq!(server.get("/api/lock").await.1["locked"], false);
    assert_eq!(server.get("/api/personas").await.0, 200);
}

/// The backup `server` makes, sealed by `password` where none is on.
async fn backup(server: &Server, password: Option<&str>) -> Vec<u8> {
    let response = server.save_backup(password).await;
    assert_eq!(response.status(), 200);
    let named = response.headers()["content-disposition"].to_str().unwrap();
    assert!(named.contains("cardwave-backup-"), "{named}");
    let file = response.bytes().await.unwrap().to_vec();
    assert!(file.starts_with(b"Cardwave backup 1\n"));
    file
}

/// Restores `file` on `server`, with `password` where it is given, as the page
/// sends it: percent-encoded, as a header holds ASCII alone.
async fn restore(server: &Server, file: Vec<u8>, password: Option<&str>) -> (u16, Value) {
    let mut request = reqwest::Client::new()
        .post(format!("http://{}/api/backup", server.addr))
        .body(file);
    if let Some(password) = password {
        let sent = utf8_percent_encode(password, NON_ALPHANUMERIC).to_string();
        request = request.header("x-cardwave-password", sent);
    }
    answer(request.send().await.unwrap()).await
}

#[tokio::test]
async fn a_backup_is_read_back_by_another_server_which_keeps_its_own_key() {
    let first = start().await;
    persona(&first, "Wanderer").await;
    first.put("/api/account", json!({ "name": "Rowan" })).await;
    let file = backup(&first, Some("harbour lights")).await;

    // Another computer, with data of its own, which the backup takes the place of.
    let second = start().await;
    persona(&second, "Stranger").await;
    let mut socket = second.listen().await;
    assert_eq!(restore(&second, b"not one".to_vec(), None).await.0, 400);
    assert_eq!(restore(&second, file, Some("harbour lights")).await.0, 204);
    assert_eq!(event(&mut socket).await, json!({ "type": "restored" }));
    drop(socket);
    assert_eq!(personas(&second).await, ["Wanderer"]);
    assert_eq!(second.get("/api/account").await.1["name"], "Rowan");

    // Its own key opens it at the next start.
    let second = second.restart().await;
    assert_eq!(personas(&second).await, ["Wanderer"]);
}

#[tokio::test]
async fn a_backup_where_no_password_is_on_is_sealed_by_the_one_given_and_refused_without() {
    let first = start().await;
    persona(&first, "Wanderer").await;
    let (status, refused) = answer(first.save_backup(None).await).await;
    assert_eq!(
        (status, refused["error"].as_str()),
        (400, Some("A backup needs a password."))
    );
    assert_eq!(answer(first.save_backup(Some("")).await).await.0, 400);
    let file = backup(&first, Some("Hafenlichter, 港の灯")).await;
    // The app itself still opens without one.
    assert!(!server_locked(&first.restart().await).await);

    let second = start().await;
    assert_eq!(restore(&second, file.clone(), None).await.0, 401);
    assert_eq!(restore(&second, file.clone(), Some("Hafen")).await.0, 401);
    assert_eq!(
        restore(&second, file, Some("Hafenlichter, 港の灯")).await.0,
        204
    );
    assert_eq!(personas(&second).await, ["Wanderer"]);
}

#[tokio::test]
async fn a_backup_made_before_every_one_had_a_password_is_restored_still() {
    let first = start().await;
    persona(&first, "Wanderer").await;
    let file = backup(&first, Some("harbour lights")).await;
    // Its key as such a backup held it: as it is.
    let head = file.iter().skip(18).position(|&b| b == b'\n').unwrap() + 19;
    let key = first.options().key.given().unwrap().to_hex();
    let mut old = format!("Cardwave backup 1\n{{\"key\":\"{key}\"}}\n").into_bytes();
    old.extend_from_slice(&file[head..]);

    let second = start().await;
    assert_eq!(restore(&second, old, None).await.0, 204);
    assert_eq!(personas(&second).await, ["Wanderer"]);
}

#[tokio::test]
async fn a_backup_made_with_a_password_is_read_back_with_it_alone() {
    let first = start().await;
    persona(&first, "Wanderer").await;
    set_password(&first, json!({ "password": "Hafenlichter, 港の灯" })).await;
    // The password that is on seals it, not one sent.
    let file = backup(&first, Some("other")).await;

    let second = start().await;
    let (status, needs) = restore(&second, file.clone(), None).await;
    assert_eq!(
        (status, needs["error"].as_str()),
        (401, Some("This backup needs its password."))
    );
    assert_eq!(
        restore(&second, file.clone(), Some("Hafenlichter")).await.0,
        401
    );
    assert_eq!(
        restore(&second, file, Some("Hafenlichter, 港の灯")).await.0,
        204
    );
    assert_eq!(personas(&second).await, ["Wanderer"]);
    // The password was the first server's: the second opens without one, as before.
    let second = second.restart().await;
    assert!(!server_locked(&second).await);
    assert_eq!(personas(&second).await, ["Wanderer"]);
}

async fn server_locked(server: &Server) -> bool {
    server.get("/api/lock").await.1["locked"].as_bool().unwrap()
}

/// The database of `server`, opened beside it, to plant what the API cannot.
fn database(server: &Server) -> Db {
    let options = server.options();
    Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap()
}

#[tokio::test]
async fn a_backup_restored_is_tidied_as_at_a_start() {
    let first = start().await;
    let (status, imported) = first.upload("/api/cards", common::card_file()).await;
    assert_eq!(status, 201, "{imported}");
    // A card waiting to be described when the backup was made: nothing describes it on the other computer.
    database(&first)
        .with(|c| {
            c.execute(
                "insert into card_descriptions (card_id, state, updated_at) values (?1, 'queued', 0)",
                [imported["card_id"].as_i64().unwrap()],
            )
        })
        .unwrap();
    let file = backup(&first, Some("harbour lights")).await;

    let second = start().await;
    assert_eq!(restore(&second, file, Some("harbour lights")).await.0, 204);
    let queued: i64 = database(&second)
        .with(|c| {
            c.query_row(
                "select count(*) from card_descriptions where state = 'queued'",
                [],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(queued, 0);
}

#[tokio::test]
async fn a_backup_whose_password_would_cost_too_much_to_try_is_refused() {
    let first = start().await;
    set_password(&first, json!({ "password": "harbour lights" })).await;
    let file = backup(&first, None).await;
    // Its header asks argon2id for 4 TiB of memory.
    let text = String::from_utf8_lossy(&file[..200]).into_owned();
    let asked = text.replace("\"memory\":19456", "\"memory\":4000000000");
    assert_ne!(asked, text);
    let mut crafted = asked.into_bytes();
    crafted.extend_from_slice(&file[200..]);

    let second = start().await;
    let (status, refused) = restore(&second, crafted, Some("harbour lights")).await;
    assert_eq!(status, 400, "{refused}");
}

#[tokio::test]
async fn what_a_backup_left_in_the_data_folder_is_gone_at_the_next_start() {
    let server = start().await;
    let dir = server.options().data_dir;
    for left in [
        "backup-00ff.db",
        "restore.upload-00ff",
        "restore.db",
        "restore.db-wal",
    ] {
        std::fs::write(dir.join(left), b"Cardwave backup 1\n").unwrap();
    }
    let server = server.restart().await;
    let dir = server.options().data_dir;
    for left in [
        "backup-00ff.db",
        "restore.upload-00ff",
        "restore.db",
        "restore.db-wal",
    ] {
        assert!(!dir.join(left).exists(), "{left}");
    }
}

/// The credential store's entry of `server`'s data folder under `service`,
/// which is taken out of the store when it is dropped.
#[cfg(any(windows, target_os = "macos"))]
struct Stored(keyring::Entry);

#[cfg(any(windows, target_os = "macos"))]
impl Stored {
    fn of(service: &str, server: &Server) -> Self {
        let dir = server.options().data_dir.canonicalize().unwrap();
        Self(keyring::Entry::new(service, &dir.to_string_lossy()).unwrap())
    }

    /// The key the entry holds, if it holds one.
    fn key(&self) -> Option<String> {
        match self.0.get_password() {
            Ok(hex) => Some(hex),
            Err(keyring::Error::NoEntry) => None,
            Err(failure) => panic!("{failure}"),
        }
    }
}

#[cfg(any(windows, target_os = "macos"))]
impl Drop for Stored {
    fn drop(&mut self) {
        let _ = self.0.delete_credential();
    }
}

#[cfg(any(windows, target_os = "macos"))]
#[tokio::test]
async fn the_key_leaves_the_credential_store_while_a_password_is_on() {
    // A service of the test's own: the installed app keeps its keys under "cardwave".
    let service = format!("cardwave-test-{}", std::process::id());
    let server = common::server::start_storing(&service).await;
    let store = Stored::of(&service, &server);
    persona(&server, "Wanderer").await;
    let key = store.key().expect("the store holds the key");
    let on = set_password(&server, json!({ "password": "harbour lights" })).await;
    assert_eq!(on.0, 200, "{}", on.1);
    assert_eq!(store.key(), None);

    // Where the app stopped before the key was out of the store, the key left there goes at the unlock.
    let server = server.restart().await;
    store.0.set_password(&key).unwrap();
    assert_eq!(unlock(&server, "harbour lights").await, 204);
    assert_eq!(store.key(), None);

    let off = set_password(&server, json!({ "current": "harbour lights" })).await;
    assert_eq!(off.0, 200, "{}", off.1);
    assert_eq!(store.key().as_deref(), Some(key.as_str()));
    // Without a password the app opens by the key in the store.
    let server = server.restart().await;
    assert_eq!(personas(&server).await, ["Wanderer"]);
}

//! Accounts (`api/accounts.rs`): other devices reach the server once its owner
//! lets them, and every address, the socket and the pictures ask them to sign
//! in; each account holds its own; wrong passwords are held back; on this
//! computer an account is switched to and back.
//!
//! `Device` (`common::server`) is a browser of its own, at the address of the
//! home network's listener or at the server's own.

mod common;

use common::server::{Device, Server, WAIT, event, phone, start};
use reqwest::Method;
use serde_json::{Value, json};
use tokio_tungstenite::tungstenite::Message;

/// Adds the account `name` with `password`: its number.
async fn add(server: &Server, name: &str, password: &str) -> i64 {
    let account = json!({ "name": name, "password": password });
    let (status, added) = server.post("/api/accounts", account).await;
    assert_eq!(status, 201, "{added}");
    added["id"].as_i64().unwrap()
}

async fn persona(device: &mut Device, name: &str) {
    let made = json!({ "name": name, "description": "" });
    assert_eq!(device.post("/api/personas", made).await.0, 201);
}

#[tokio::test]
async fn another_device_signs_in_to_an_account_which_holds_its_own() {
    let server = start().await;
    let mut here = Device::at(&format!("http://{}", server.addr));
    persona(&mut here, "Wanderer").await;
    let mut phone = phone(&server).await;
    // Every address, the socket and a picture ask for a session; the page itself and the status do not.
    assert_eq!(phone.get("/api/personas").await, (401, json!("sign in")));
    assert_eq!(
        phone.get("/api/card-versions/1/image").await,
        (401, json!("sign in"))
    );
    assert!(phone.listen().await.unwrap_err().contains("401"));
    assert_eq!(phone.get("/api/status").await.0, 200);
    // This computer's account has no password, so no account can sign in from there.
    let (_, signing) = phone.get("/api/sign-in").await;
    assert_eq!(
        signing,
        json!({ "needed": true, "remote": true, "accounts": [] })
    );

    let ada = add(&server, "Ada", "tide pool").await;
    let (_, signing) = phone.get("/api/sign-in").await;
    let line =
        json!({ "id": ada, "name": "Ada", "local": false, "current": false, "password": true });
    assert_eq!(signing["accounts"], json!([line]));
    assert_eq!(phone.sign_in(ada, Some("tide")).await, 401);
    assert_eq!(phone.sign_in(ada, None).await, 401);
    assert_eq!(phone.sign_in(ada, Some("tide pool")).await, 204);
    assert_eq!(phone.get("/api/sign-in").await.1["needed"], false);
    assert_eq!(phone.get("/api/account").await.1["name"], "Ada");
    assert!(phone.listen().await.is_ok());
    // Each account holds its own.
    assert_eq!(phone.personas().await, Vec::<String>::new());
    persona(&mut phone, "Sailor").await;
    assert_eq!(phone.personas().await, ["Sailor"]);
    assert_eq!(here.personas().await, ["Wanderer"]);
    // What serves every account is this computer's account's to change.
    let another = json!({ "name": "Bo", "password": "x" });
    assert_eq!(phone.post("/api/accounts", another).await.0, 403);
    assert_eq!(phone.post("/api/backup/save", json!({})).await.0, 403);
    assert_eq!(phone.get("/api/network").await.0, 403);
    assert_eq!(phone.post("/api/search/download", json!({})).await.0, 403);
    let folder = json!({ "folder": "C:/" });
    assert_eq!(phone.post("/api/card-folder/import", folder).await.0, 403);
    let cards = json!({ "card_folder": { "watch": false } });
    let changed = phone
        .call(Method::PATCH, "/api/settings", Some(cards))
        .await;
    assert_eq!(changed.0, 403);

    // Deleted, the account is gone with what it held, and its session with it.
    let (status, _) = server
        .call(Method::DELETE, &format!("/api/accounts/{ada}"), None)
        .await;
    assert_eq!(status, 204);
    assert_eq!(phone.get("/api/personas").await, (401, json!("sign in")));
    let (_, accounts) = server.get("/api/accounts").await;
    assert_eq!(accounts.as_array().unwrap().len(), 1);
    // This computer's account is not deleted.
    let (_, me) = server.get("/api/accounts").await;
    let me = me[0]["id"].as_i64().unwrap();
    let (status, _) = server
        .call(Method::DELETE, &format!("/api/accounts/{me}"), None)
        .await;
    assert_eq!(status, 404);
}

#[tokio::test]
async fn wrong_passwords_from_one_place_are_held_back() {
    let server = start().await;
    let ada = add(&server, "Ada", "tide pool").await;
    let bo = add(&server, "Bo", "harbour").await;
    let mut phone = phone(&server).await;
    // Tries sent at once are held back as tries one after the other are: five are checked.
    let base = phone.base.clone();
    let tries = (0..12).map(|_| {
        let base = base.clone();
        async move {
            let mut device = Device::at(&base);
            device.sign_in(ada, Some("guess")).await
        }
    });
    let mut answered = futures_util::future::join_all(tries).await;
    answered.sort();
    assert_eq!(answered, [[401; 5].as_slice(), &[429; 7]].concat());
    // The right one waits too, for a while.
    let (status, why) = phone
        .post(
            "/api/sign-in",
            json!({ "account": ada, "password": "tide pool" }),
        )
        .await;
    assert_eq!(status, 429, "{why}");
    assert!(
        why["error"]
            .as_str()
            .unwrap()
            .starts_with("Too many wrong passwords.")
    );
    // Another account is not held back by them.
    assert_eq!(phone.sign_in(bo, Some("harbour")).await, 204);
}

#[tokio::test]
async fn this_computers_account_signs_in_elsewhere_by_the_password_of_the_app() {
    let server = start().await;
    let (_, accounts) = server.get("/api/accounts").await;
    let me = accounts[0]["id"].as_i64().unwrap();
    let mut phone = phone(&server).await;
    // Without a password it signs in on this computer alone.
    assert_eq!(phone.sign_in(me, None).await, 400);
    let on = server
        .put("/api/password", json!({ "password": "harbour lights" }))
        .await;
    assert_eq!(on.0, 200, "{}", on.1);
    assert_eq!(
        phone.get("/api/sign-in").await.1["accounts"][0]["password"],
        true
    );
    assert_eq!(phone.sign_in(me, Some("harbour lights")).await, 204);
    assert_eq!(phone.get("/api/account").await.1["local"], true);
    // The password changed on this computer signs the other device out.
    let change = json!({ "current": "harbour lights", "password": "lantern" });
    assert_eq!(server.put("/api/password", change).await.0, 200);
    assert_eq!(phone.get("/api/account").await, (401, json!("sign in")));
}

#[tokio::test]
async fn a_password_reset_signs_the_account_out_and_an_account_changes_its_own() {
    let server = start().await;
    let ada = add(&server, "Ada", "tide pool").await;
    let mut phone = phone(&server).await;
    assert_eq!(phone.sign_in(ada, Some("tide pool")).await, 204);
    let mut socket = phone.listen().await.unwrap();
    let reset = json!({ "password": "new moon" });
    let path = format!("/api/accounts/{ada}/password");
    assert_eq!(server.put(&path, reset).await.0, 204);
    assert_eq!(phone.get("/api/account").await, (401, json!("sign in")));
    // Its socket hears nothing more of the account: it ends at the account's next event.
    assert_eq!(phone.sign_in(ada, Some("new moon")).await, 204);
    let renamed = json!({ "name": "Ada Vale" });
    assert_eq!(
        phone
            .call(Method::PUT, "/api/account", Some(renamed))
            .await
            .0,
        200
    );
    let ended = tokio::time::timeout(WAIT, futures_util::StreamExt::next(&mut socket)).await;
    assert!(
        matches!(ended, Ok(None | Some(Err(_)) | Some(Ok(Message::Close(_))))),
        "{ended:?}"
    );

    let own = json!({ "current": "new moon", "password": "low tide" });
    assert_eq!(
        phone.call(Method::PUT, "/api/password", Some(own)).await.0,
        200
    );
    // It keeps a password: one cannot be switched off.
    let off = json!({ "current": "low tide" });
    let (status, body) = phone.call(Method::PUT, "/api/password", Some(off)).await;
    assert_eq!((status, &body["code"]), (400, &json!("password_kept")));
    let wrong = json!({ "current": "new moon", "password": "x" });
    assert_eq!(
        phone
            .call(Method::PUT, "/api/password", Some(wrong))
            .await
            .0,
        401
    );
    assert_eq!(phone.get("/api/account").await.1["name"], "Ada Vale");
}

#[tokio::test]
async fn on_this_computer_an_account_is_switched_to_and_back() {
    let server = start().await;
    let mut here = Device::at(&format!("http://{}", server.addr));
    persona(&mut here, "Wanderer").await;
    let ada = add(&server, "Ada", "tide pool").await;
    let (_, accounts) = here.get("/api/accounts").await;
    let me = accounts[0]["id"].as_i64().unwrap();
    // This computer's account asks for no password here, while none is on.
    let lines: Vec<(bool, bool)> = accounts
        .as_array()
        .unwrap()
        .iter()
        .map(|a| {
            (
                a["current"].as_bool().unwrap(),
                a["password"].as_bool().unwrap(),
            )
        })
        .collect();
    assert_eq!(lines, [(true, false), (false, true)]);
    assert_eq!(here.sign_in(ada, Some("tide pool")).await, 204);
    assert_eq!(here.personas().await, Vec::<String>::new());
    assert_eq!(here.sign_in(me, None).await, 204);
    assert_eq!(here.personas().await, ["Wanderer"]);
    // Signed out, a page here is this computer's account's again.
    assert_eq!(here.sign_in(ada, Some("tide pool")).await, 204);
    let cookie = here.cookie.clone().unwrap();
    let (name, _) = cookie.split_once('=').unwrap();
    assert_eq!(here.post("/api/sign-out", json!({})).await.0, 204);
    assert_eq!(here.cookie, None);
    assert_eq!(here.personas().await, ["Wanderer"]);
    // Another server's cookie, which the browser sends to every port of the host, is none of this one's.
    here.cookie = Some("cardwave_0123456789abcdef=00".into());
    assert_eq!(here.personas().await, ["Wanderer"]);
    // A session of this server that ended is not this computer's account's: the page is to sign in.
    here.cookie = Some(format!("{name}=00"));
    assert_eq!(here.get("/api/personas").await, (401, json!("sign in")));
    assert_eq!(here.get("/api/sign-in").await.1["needed"], true);
}

#[tokio::test]
async fn only_this_computers_account_locks_cardwave() {
    let server = start().await;
    let ada = add(&server, "Ada", "tide pool").await;
    let on = json!({ "password": "harbour lights" });
    assert_eq!(server.put("/api/password", on).await.0, 200);
    let mut here = Device::at(&format!("http://{}", server.addr));
    assert_eq!(here.sign_in(ada, Some("tide pool")).await, 204);
    assert_eq!(here.post("/api/password/lock", json!({})).await.0, 403);
    assert_eq!(server.get("/api/lock").await.1["locked"], false);
}

#[tokio::test]
async fn a_restored_backup_signs_every_page_out() {
    let server = start().await;
    let ada = add(&server, "Ada", "tide pool").await;
    let mut phone = phone(&server).await;
    assert_eq!(phone.sign_in(ada, Some("tide pool")).await, 204);
    let mut socket = phone.listen().await.unwrap();
    let file = server.save_backup(Some("x")).await.bytes().await.unwrap();
    let restored = reqwest::Client::new()
        .post(format!("http://{}/api/backup", server.addr))
        .header("x-cardwave-password", "x")
        .body(file)
        .send()
        .await
        .unwrap();
    assert_eq!(restored.status(), 204);
    // The page hears it, though its session ended, and starts anew.
    assert_eq!(event(&mut socket).await["type"], "restored");
    assert_eq!(phone.get("/api/account").await, (401, json!("sign in")));
    // The backup said the home network reaches the server, so it still does.
    assert_eq!(phone.sign_in(ada, Some("tide pool")).await, 204);
}

#[tokio::test]
async fn the_home_network_reaches_the_server_until_it_is_switched_off() {
    let server = start().await;
    let ada = add(&server, "Ada", "tide pool").await;
    let mut phone = phone(&server).await;
    assert_eq!(phone.sign_in(ada, Some("tide pool")).await, 204);
    let mut socket = phone.listen().await.unwrap();
    // A server started again listens again, at an address of its own.
    let server = server.restart().await;
    let (_, network) = server.get("/api/network").await;
    assert_eq!(network["on"], true);
    let mut phone = Device {
        base: network["address"]
            .as_str()
            .unwrap()
            .trim_end_matches('/')
            .into(),
        cookie: phone.cookie,
    };
    assert_eq!(phone.get("/api/account").await.1["name"], "Ada");
    drop(socket);
    socket = phone.listen().await.unwrap();

    let (status, off) = server.put("/api/network", json!({ "on": false })).await;
    assert_eq!(
        (status, off),
        (200, json!({ "on": false, "address": null }))
    );
    // The socket of the other device ends, and nothing answers there.
    let ended = tokio::time::timeout(WAIT, futures_util::StreamExt::next(&mut socket)).await;
    assert!(
        matches!(ended, Ok(None | Some(Err(_)) | Some(Ok(Message::Close(_))))),
        "{ended:?}"
    );
    let refused = reqwest::get(format!("{}/api/status", phone.base)).await;
    assert!(refused.is_err());
}

#[tokio::test]
async fn an_account_has_a_picture_of_its_own() {
    let server = start().await;
    let mut socket = server.listen().await;
    let sent = reqwest::Client::new()
        .put(format!("http://{}/api/account/picture", server.addr))
        .body(common::picture())
        .send()
        .await
        .unwrap();
    assert_eq!(sent.status(), 200);
    let account: Value = sent.json().await.unwrap();
    let address = account["picture"].as_str().unwrap();
    assert!(address.starts_with("/api/account/picture?at="), "{address}");
    assert_eq!(event(&mut socket).await["picture"], address);
    let (headers, picture) = server.download(address).await;
    assert_eq!(headers["content-type"], "image/png");
    let made = image::load_from_memory(&picture).unwrap();
    assert_eq!((made.width(), made.height()), (128, 128));
    // A file that is no picture is refused.
    let refused = reqwest::Client::new()
        .put(format!("http://{}/api/account/picture", server.addr))
        .body("no picture")
        .send()
        .await
        .unwrap();
    assert_eq!(refused.status(), 400);
    // Nor is one wider than the decoder is let read.
    let mut wide = std::io::Cursor::new(Vec::new());
    image::RgbaImage::new(5000, 1)
        .write_to(&mut wide, image::ImageFormat::Png)
        .unwrap();
    let refused = reqwest::Client::new()
        .put(format!("http://{}/api/account/picture", server.addr))
        .body(wide.into_inner())
        .send()
        .await
        .unwrap();
    assert_eq!(refused.status(), 400);

    let (status, removed) = server
        .call(Method::DELETE, "/api/account/picture", None)
        .await;
    assert_eq!((status, &removed["picture"]), (200, &Value::Null));
    assert_eq!(server.get("/api/account/picture").await.0, 404);
}

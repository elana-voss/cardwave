mod common;

use common::server::{answer, event, start};
use cw_accounts::users;
use cw_ccv4::png;
use cw_key::FILE_NAME;
use cw_store::Db;
use reqwest::Method;
use serde_json::{Value, json};
use tokio_tungstenite::tungstenite::client::IntoClientRequest;

#[tokio::test]
async fn status_reports_app_and_version() {
    let server = start().await;
    let addr = &server.addr;
    let body: serde_json::Value = reqwest::get(format!("http://{addr}/api/status"))
        .await
        .unwrap()
        .json()
        .await
        .unwrap();
    assert_eq!(body["app"], "cardwave");
    assert_eq!(body["version"], env!("CARGO_PKG_VERSION"));
    // When the server was built, which the page "About Cardwave" says beside the version.
    let built = body["built"].as_i64().unwrap();
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    assert!(
        built > now - 400 * 24 * 3600 * 1000 && built <= now,
        "{built}"
    );
    // Whether Settings › Data shows "Move imported files to the Recycle Bin": Windows' alone.
    assert_eq!(body["recycle_bin"], cfg!(windows));
}

#[tokio::test]
async fn the_account_tells_what_its_user_is_called() {
    let server = start().await;
    // The one user a server has until it has a login.
    assert_eq!(
        server.get("/api/account").await,
        (
            200,
            json!({ "name": "local", "local": true, "picture": null })
        )
    );
}

#[tokio::test]
async fn the_account_is_renamed_and_stays_the_same_user() {
    let server = start().await;
    // What the user has is the account's, whatever it is called.
    let (status, persona) = server
        .post(
            "/api/personas",
            json!({ "name": "Wanderer", "description": "" }),
        )
        .await;
    assert_eq!(status, 201, "{persona}");
    let mut socket = server.listen().await;

    // A name is kept without the space around it, and the user's pages are told.
    let (status, renamed) = server
        .put("/api/account", json!({ "name": "  Rowan Vale\n" }))
        .await;
    assert_eq!(
        (status, &renamed),
        (
            200,
            &json!({ "name": "Rowan Vale", "local": true, "picture": null })
        )
    );
    assert_eq!(
        event(&mut socket).await,
        json!({ "type": "account", "name": "Rowan Vale", "local": true, "picture": null })
    );
    assert_eq!(server.get("/api/account").await.1, renamed);

    // A name that is none, too long, or of more than one line is refused, and the name stays.
    for wrong in [
        json!(""),
        json!("   "),
        json!("n".repeat(41)),
        json!("Rowan\nVale"),
    ] {
        let (status, why) = server.put("/api/account", json!({ "name": wrong })).await;
        assert_eq!(status, 400, "{why}");
    }
    assert_eq!(server.get("/api/account").await.1, renamed);
    // Forty characters are a name, counted as signs and not as bytes.
    let longest = "é".repeat(40);
    let (status, long) = server.put("/api/account", json!({ "name": longest })).await;
    assert_eq!((status, &long["name"]), (200, &json!(longest)));

    // A server that starts again on the same data finds this computer's account by its
    // mark, not by the name it had: it is the same user, with what it had.
    drop(socket);
    let server = server.restart().await;
    assert_eq!(
        server.get("/api/account").await.1,
        json!({ "name": longest, "local": true, "picture": null })
    );
    let (_, personas) = server.get("/api/personas").await;
    assert_eq!(personas[0]["name"], "Wanderer");
    assert_eq!(personas.as_array().unwrap().len(), 1);
    // Called `local` again, it is still the one account.
    let (status, back) = server.put("/api/account", json!({ "name": "local" })).await;
    assert_eq!((status, &back["name"]), (200, &json!("local")));
}

#[tokio::test]
async fn an_account_is_not_called_as_another_one_is() {
    let server = start().await;
    let db = Db::open(
        &server.options().data_dir.join(FILE_NAME),
        server.options().key.given().unwrap(),
    )
    .unwrap();
    users::create(&db, "Sam").unwrap();
    // Upper and lower case aside.
    let (status, why) = server.put("/api/account", json!({ "name": "sAM" })).await;
    assert_eq!(
        (status, why),
        (
            400,
            json!({ "code": "taken", "error": "another account is called “sAM”", "details": { "what": "account_name", "name": "sAM" } })
        )
    );
    assert_eq!(server.get("/api/account").await.1["name"], "local");
    // Its own name again is no other's.
    let (status, _) = server.put("/api/account", json!({ "name": "local" })).await;
    assert_eq!(status, 200);
}

#[tokio::test]
async fn socket_says_hello() {
    start().await.listen().await;
}

#[tokio::test]
async fn socket_refuses_foreign_origin() {
    let server = start().await;
    let addr = &server.addr;
    let mut req = format!("ws://{addr}/ws").into_client_request().unwrap();
    req.headers_mut()
        .insert("origin", "http://evil.example".parse().unwrap());
    assert!(tokio_tungstenite::connect_async(req).await.is_err());
}

#[tokio::test]
async fn unknown_api_path_is_404() {
    let server = start().await;
    let res = reqwest::get(format!("http://{}/api/nope", server.addr))
        .await
        .unwrap();
    assert_eq!(res.status(), 404);
}

#[tokio::test]
async fn http_refuses_foreign_origin_but_allows_same_or_none() {
    let server = start().await;
    let url = format!("http://{}/api/status", server.addr);
    let client = reqwest::Client::new();
    let get = |origin: Option<String>| {
        let mut req = client.get(&url);
        if let Some(o) = origin {
            req = req.header("origin", o);
        }
        async move { req.send().await.unwrap().status() }
    };
    assert_eq!(get(Some("http://evil.example".into())).await, 403);
    assert_eq!(get(Some(format!("http://{}", server.addr))).await, 200);
    assert_eq!(get(None).await, 200);
}

#[tokio::test]
async fn only_a_numeric_address_or_localhost_is_answered() {
    let server = start().await;
    let url = format!("http://{}/api/status", server.addr);
    let client = reqwest::Client::new();
    let port = server.addr.rsplit(':').next().unwrap();
    let to = |host: String| {
        let req = client
            .get(&url)
            .header("host", host.clone())
            .header("origin", format!("http://{host}"));
        async move { req.send().await.unwrap().status() }
    };
    // A page of another site whose name was made to lead to this computer.
    assert_eq!(to(format!("cards.example:{port}")).await, 403);
    for host in [
        format!("localhost:{port}"),
        format!("[::1]:{port}"),
        format!("192.168.1.20:{port}"),
        server.addr.clone(),
    ] {
        assert_eq!(to(host.clone()).await, 200, "{host}");
    }
}

fn contents(view: &Value) -> Vec<&str> {
    view["messages"]
        .as_array()
        .unwrap()
        .iter()
        .map(|m| m["content"].as_str().unwrap())
        .collect()
}

#[tokio::test]
async fn a_card_is_uploaded_listed_and_served() {
    let server = start().await;
    let (status, imported) = server.upload("/api/cards", common::card_file()).await;
    assert_eq!(status, 201);
    assert_eq!(
        (&imported["title"], &imported["version"]),
        (&json!("Mira of the North Light"), &json!(1))
    );
    let (id, version) = (
        imported["card_id"].as_i64().unwrap(),
        imported["version_id"].as_i64().unwrap(),
    );

    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list.as_array().unwrap().len(), 1);
    assert_eq!(list[0]["id"], id);

    let (status, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(status, 200);
    assert_eq!(detail["card"]["version_id"], version);
    assert_eq!(detail["tags"], json!(["sea", "mystery"]));
    let mira = &detail["characters"][0];
    assert_eq!(
        (&mira["id"], &mira["name"], &mira["label"]),
        (&json!("mira"), &json!("Mira"), &json!("Mira (storm night)"))
    );
    assert_eq!(
        mira["avatar_url"],
        format!("/api/card-versions/{version}/assets/card/images/mira.png")
    );
    // A card holds one character: of the file's two the first is kept, and the import says so.
    assert_eq!(detail["characters"].as_array().unwrap().len(), 1);
    assert!(
        imported["warnings"]
            .as_array()
            .unwrap()
            .contains(&json!({ "code": "first_character_kept", "name": "Mira" })),
        "{imported}"
    );

    // Files out of a card are served so that a browser neither guesses nor runs them.
    let (headers, avatar) = server.download(mira["avatar_url"].as_str().unwrap()).await;
    assert_eq!(avatar, common::AVATAR);
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!(headers["x-content-type-options"], "nosniff");
    assert_eq!(
        headers["content-security-policy"],
        "default-src 'none'; sandbox"
    );
    assert_eq!(headers["cross-origin-resource-policy"], "same-origin");
    // A card version never changes, so its files are kept by the browser; a list is not.
    assert_eq!(
        headers["cache-control"],
        "private, max-age=31536000, immutable"
    );
    let list = reqwest::get(format!("http://{}/api/cards", server.addr))
        .await
        .unwrap();
    assert_eq!(list.headers()["cache-control"], "no-cache");
    // A character without an avatar of its own shows the card's picture.
    let (_, plain) = server
        .upload(
            "/api/cards",
            common::card_png(&json!({"data": {"name": "Bare"}})),
        )
        .await;
    let (_, bare) = server
        .get(&format!("/api/cards/{}", plain["card_id"]))
        .await;
    let url = format!("/api/card-versions/{}/image", plain["version_id"]);
    assert_eq!(bare["characters"][0]["avatar_url"], url);
    let (headers, _) = server.download(&url).await;
    assert_eq!(headers["content-type"], "image/png");

    // The card is "edited" from its first edit on.
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["edited_at"], Value::Null);
    let (status, second) = server
        .edit_card(&json!(id), |form| {
            form["characters"][0]["personality"][0]["text"] = json!("Warm.")
        })
        .await;
    assert_eq!((status, &second["number"]), (200, &json!(2)));
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["card"]["version_id"], second["id"]);
    assert!(
        detail["edited_at"].as_i64().unwrap() >= detail["card"]["created_at"].as_i64().unwrap()
    );

    let (status, card) = server
        .patch(
            &format!("/api/cards/{id}"),
            json!({ "favorite": true, "trashed": true }),
        )
        .await;
    assert_eq!(status, 200);
    assert_eq!(
        (&card["favorite"], &card["archived"], &card["trashed"]),
        (&json!(true), &json!(false), &json!(true))
    );
}

#[tokio::test]
async fn a_large_card_with_an_oddly_named_avatar_is_served() {
    let server = start().await;
    let name = "card/images/mira & co #1 (ö).png";
    let mut container = common::container();
    // Larger than the 2 MB a request body may have by default.
    container.assets = vec![(name.to_string(), vec![7; 3 * 1024 * 1024])];
    container.toml[1].1 = container.toml[1].1.replace("card/images/mira.png", name);
    let (status, imported) = server
        .upload("/api/cards", png::write(&container).unwrap())
        .await;
    assert_eq!(status, 201, "{imported}");

    let (_, detail) = server
        .get(&format!("/api/cards/{}", imported["card_id"]))
        .await;
    let url = detail["characters"][0]["avatar_url"].as_str().unwrap();
    assert!(
        url.ends_with("/assets/card/images/mira%20%26%20co%20%231%20%28%C3%B6%29.png"),
        "{url}"
    );
    let (_, avatar) = server.download(url).await;
    assert_eq!(avatar.len(), 3 * 1024 * 1024);
}

#[tokio::test]
async fn bad_uploads_and_missing_items_are_told_apart() {
    let server = start().await;
    let (status, body) = server.upload("/api/cards", common::picture()).await;
    assert_eq!(
        (status, &body["error"]),
        (400, &json!("this PNG holds no character card"))
    );
    let (status, body) = server.upload("/api/cards", b"hello".to_vec()).await;
    assert_eq!((status, &body["error"]), (400, &json!("not a PNG file")));
    assert_eq!(server.get("/api/cards").await.1, json!([]));

    let missing =
        json!({ "code": "not_found", "error": "no such card", "details": { "what": "card" } });
    assert_eq!(server.get("/api/cards/99").await, (404, missing.clone()));
    assert_eq!(
        server.patch("/api/cards/99", json!({})).await,
        (404, missing)
    );
    for path in [
        "/api/card-versions/99/image",
        "/api/card-versions/99/assets/card/x.png",
        "/api/chats/99",
    ] {
        assert_eq!(server.get(path).await.0, 404, "{path}");
    }
    let text = json!({ "content": "Hello?" });
    assert_eq!(
        server
            .patch("/api/chats/99", json!({ "favorite": true }))
            .await
            .0,
        404
    );
    assert_eq!(
        server
            .put("/api/chats/99/persona", json!({ "persona_id": 1 }))
            .await
            .0,
        404
    );
    assert_eq!(
        server
            .call(Method::DELETE, "/api/chats/99/persona", None)
            .await
            .0,
        404
    );
    assert_eq!(
        server
            .put("/api/chats/99/head", json!({ "message_id": 1 }))
            .await
            .0,
        404
    );
    assert_eq!(
        server
            .put(
                "/api/chats/99/head",
                json!({ "message_id": 1, "follow": true })
            )
            .await
            .0,
        404
    );
    assert_eq!(
        server.post("/api/chats/99/messages", text.clone()).await.0,
        404
    );
    assert_eq!(server.patch("/api/messages/99", text.clone()).await.0, 404);
    assert_eq!(server.post("/api/messages/99/swipes", text).await.0, 404);

    let nobody = json!({ "characters": [{ "version_id": 99, "character": "mira" }] });
    assert_eq!(server.post("/api/chats", nobody).await.0, 404);
    assert_eq!(
        server
            .post("/api/personas", json!({ "name": "  " }))
            .await
            .0,
        400
    );

    // Requests the handlers never see are answered in the same form.
    assert_eq!(
        server
            .post("/api/personas", json!({ "nam": "Ines" }))
            .await
            .0,
        422
    );
    assert_eq!(server.get("/api/cards/first").await.0, 400);
    assert_eq!(server.get("/api/nope").await.0, 404);
    assert_eq!(server.call(Method::DELETE, "/api/cards", None).await.0, 405);
}

#[tokio::test]
async fn another_sites_page_cannot_load_from_the_api() {
    let server = start().await;
    let from = |site: &'static str| {
        let request = reqwest::Client::new().get(format!("http://{}/api/cards", server.addr));
        async move {
            answer(request.header("sec-fetch-site", site).send().await.unwrap())
                .await
                .0
        }
    };
    assert_eq!(from("cross-site").await, 403);
    // Another port of this machine is the same site, but not this server.
    assert_eq!(from("same-site").await, 403);
    assert_eq!(from("same-origin").await, 200);
    // Typed into the address bar.
    assert_eq!(from("none").await, 200);
}

#[tokio::test]
async fn a_chat_is_started_written_swiped_and_branched() {
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let (status, persona) = server
        .post(
            "/api/personas",
            json!({ "name": "Ines", "description": "A surveyor." }),
        )
        .await;
    assert_eq!((status, &persona["name"]), (201, &json!("Ines")));
    assert_eq!(server.get("/api/personas").await.1, json!([persona]));

    let new = json!({
        "characters": [{ "version_id": card["version_id"], "character": "mira" }],
        "persona_id": persona["id"],
    });
    let (status, view) = server.post("/api/chats", new).await;
    assert_eq!(status, 201, "{view}");
    let chat = view["chat"]["id"].as_i64().unwrap();
    assert_eq!(view["chat"]["title"], "Mira (storm night)");
    let mira = &view["characters"][0];
    assert_eq!(
        (&mira["name"], &mira["card_id"], &mira["version_id"]),
        (&json!("Mira"), &card["card_id"], &card["version_id"])
    );
    assert!(
        mira["avatar_url"]
            .as_str()
            .unwrap()
            .ends_with("/assets/card/images/mira.png")
    );
    // The greeting is what the user reads: its macros are resolved, the other greeting is a swipe.
    assert_eq!(contents(&view), ["\"You picked a night for it, Ines.\""]);
    let greeting = &view["messages"][0];
    assert_eq!(
        (&greeting["role"], &greeting["speaker_id"]),
        (&json!("assistant"), &mira["id"])
    );
    let greetings = greeting["swipes"].as_array().unwrap();
    assert_eq!((greetings.len(), &greetings[0]), (2, &greeting["id"]));

    let messages = format!("/api/chats/{chat}/messages");
    let (status, asked) = server
        .post(&messages, json!({ "content": "Why tonight?" }))
        .await;
    assert_eq!(status, 201);
    assert_eq!(
        (&asked["role"], &asked["parent_id"], &asked["speaker_id"]),
        (&json!("user"), &greeting["id"], &Value::Null)
    );
    assert_eq!(asked["swipes"], json!([asked["id"]]));
    let line = json!({ "content": "The causeway.", "role": "assistant", "speaker_id": mira["id"] });
    let (status, reply) = server.post(&messages, line).await;
    assert_eq!((status, &reply["speaker_id"]), (201, &mira["id"]));
    let stranger = json!({ "content": "Boo.", "role": "assistant", "speaker_id": 99 });
    assert_eq!(server.post(&messages, stranger).await.0, 400);
    // Only a character's message has a speaker.
    assert_eq!(
        server
            .post(
                &messages,
                json!({ "content": "Boo.", "speaker_id": mira["id"] })
            )
            .await
            .0,
        400
    );

    let (status, swipe) = server
        .post(
            &format!("/api/messages/{}/swipes", reply["id"]),
            json!({ "content": "Ask the tide." }),
        )
        .await;
    assert_eq!(status, 201);
    assert_eq!(swipe["swipes"], json!([reply["id"], swipe["id"]]));
    let (status, edited) = server
        .patch(
            &format!("/api/messages/{}", asked["id"]),
            json!({ "content": "Why now?" }),
        )
        .await;
    assert_eq!(
        (status, &edited["content"], &edited["id"]),
        (200, &json!("Why now?"), &asked["id"])
    );

    let (_, view) = server.get(&format!("/api/chats/{chat}")).await;
    assert_eq!(contents(&view)[1..], ["Why now?", "Ask the tide."]);
    assert_eq!(view["chat"]["head_id"], swipe["id"]);
    assert_eq!(
        view["messages"][2]["swipes"],
        json!([reply["id"], swipe["id"]])
    );

    // Back on the first reply the chat goes on; a character's line names the first character by itself.
    let head = format!("/api/chats/{chat}/head");
    let (status, view) = server
        .put(&head, json!({ "message_id": reply["id"] }))
        .await;
    assert_eq!((status, &view["chat"]["head_id"]), (200, &reply["id"]));
    let (_, more) = server
        .post(
            &messages,
            json!({ "content": "It floods at nine.", "role": "assistant" }),
        )
        .await;
    assert_eq!(
        (&more["parent_id"], &more["speaker_id"]),
        (&reply["id"], &mira["id"])
    );

    // The other greeting is a branch of its own. Coming back shows the first one as it was
    // last left: down the older reply, which is where the newest message is.
    let (_, view) = server
        .put(&head, json!({ "message_id": greetings[1] }))
        .await;
    assert_eq!(contents(&view), ["Hold the lamp. Don't ask."]);
    let (_, view) = server
        .put(&head, json!({ "message_id": greetings[0], "follow": true }))
        .await;
    assert_eq!(
        contents(&view)[1..],
        ["Why now?", "The causeway.", "It floods at nine."]
    );
    // Without following, the view ends at the message.
    let (_, view) = server
        .put(&head, json!({ "message_id": asked["id"] }))
        .await;
    assert_eq!(contents(&view).len(), 2);
    assert_eq!(
        server.put(&head, json!({ "message_id": 9999 })).await.0,
        400
    );

    let (_, list) = server.get("/api/chats").await;
    assert_eq!(
        (list.as_array().unwrap().len(), &list[0]["id"]),
        (1, &json!(chat))
    );
    let (_, changed) = server
        .patch(&format!("/api/chats/{chat}"), json!({ "archived": true }))
        .await;
    assert_eq!(
        (&changed["archived"], &changed["persona_id"]),
        (&json!(true), &persona["id"])
    );
    let (status, changed) = server
        .call(Method::DELETE, &format!("/api/chats/{chat}/persona"), None)
        .await;
    assert_eq!((status, &changed["persona_id"]), (200, &Value::Null));
    let (_, changed) = server
        .put(
            &format!("/api/chats/{chat}/persona"),
            json!({ "persona_id": persona["id"] }),
        )
        .await;
    assert_eq!(changed["persona_id"], persona["id"]);

    // An edit of the card moves the chat to it.
    let (_, second) = server
        .edit_card(&card["card_id"], |form| {
            form["characters"][0]["personality"][0]["text"] = json!("Warm.")
        })
        .await;
    let (_, view) = server.get(&format!("/api/chats/{chat}")).await;
    assert_eq!(view["characters"][0]["version_id"], second["id"]);
}

#[tokio::test]
async fn a_page_is_not_told_of_its_own_change_and_every_other_page_is() {
    let server = start().await;
    let (mut one, mut two, mut none) = (
        server.listen_as("one").await,
        server.listen_as("two").await,
        server.listen().await,
    );
    let kobold = json!({ "base_url": "http://127.0.0.1:5001/v1", "model": "kobold-1" });
    let changed = server
        .call_as("one", Method::PUT, "/api/provider", kobold.clone())
        .await;
    assert_eq!(changed.0, 200, "{}", changed.1);
    let preset = json!({ "name": "Kobold", "holds": kobold });
    assert_eq!(server.post("/api/presets", preset).await.0, 201);

    // The page that stored the provider hears only of the preset, made by no page; the others of both.
    let (provider, presets) = (json!({ "type": "provider" }), json!({ "type": "presets" }));
    assert_eq!(event(&mut one).await, presets);
    for socket in [&mut two, &mut none] {
        assert_eq!(event(socket).await, provider);
        assert_eq!(event(socket).await, presets);
    }

    // A mark longer than 64 bytes is no page's, so that page is told as every other.
    let long = "p".repeat(65);
    let mut unmarked = server.listen_as(&long).await;
    let renamed = json!({ "name": "Kobold 2" });
    let path = "/api/presets/1";
    assert_eq!(
        server.call_as(&long, Method::PATCH, path, renamed).await.0,
        200
    );
    assert_eq!(event(&mut unmarked).await, presets);
    let renamed = json!({ "name": "Kobold 3" });
    assert_eq!(
        server
            .call_as(&"p".repeat(64), Method::PATCH, path, renamed)
            .await
            .0,
        200
    );
    let mut marked = server.listen_as(&"p".repeat(64)).await;
    let renamed = json!({ "name": "Kobold 4" });
    assert_eq!(
        server
            .call_as(&"p".repeat(64), Method::PATCH, path, renamed)
            .await
            .0,
        200
    );
    assert_eq!(
        server.patch(path, json!({ "name": "Kobold 5" })).await.0,
        200
    );
    // Of the two changes the page of 64 bytes made after it listened, it hears none; the one of no page it hears.
    assert_eq!(event(&mut marked).await, presets);
    assert_eq!(event(&mut unmarked).await, presets);
    assert_eq!(event(&mut unmarked).await, presets);
    assert_eq!(event(&mut unmarked).await, presets);

    // An empty mark is none either.
    let mut empty = server.listen_as("").await;
    let renamed = json!({ "name": "Kobold 6" });
    assert_eq!(
        server.call_as("", Method::PATCH, path, renamed).await.0,
        200
    );
    assert_eq!(event(&mut empty).await, presets);
}

#[tokio::test]
async fn every_other_page_is_told_of_a_change_of_the_settings() {
    let server = start().await;
    let (mut one, mut two) = (server.listen_as("one").await, server.listen_as("two").await);
    let told = json!({ "type": "settings" });
    let refused = json!({ "voice": "nobody" });
    assert_eq!(
        server
            .call_as("one", Method::PATCH, "/api/settings", refused)
            .await
            .0,
        400
    );
    let history = json!({ "export_history": true });
    assert_eq!(
        server
            .call_as("one", Method::PATCH, "/api/settings", history)
            .await
            .0,
        200
    );
    assert_eq!(event(&mut two).await, told);
    // The page that changed them hears of the next change, made by another.
    let plain = json!({ "plain_prompt": "Be brief." });
    assert_eq!(
        server
            .call_as("two", Method::PATCH, "/api/settings", plain)
            .await
            .0,
        200
    );
    assert_eq!(event(&mut one).await, told);
}

#[tokio::test]
async fn the_users_own_css_is_kept_as_typed_and_emptied_again() {
    let server = start().await;
    assert_eq!(server.get("/api/settings").await.1["own_css"], "");
    let css = ":root { --accent: #2e7d32; }\n\n.bubble { border-radius: 6px; }\n";
    let (status, kept) = server
        .patch("/api/settings", json!({ "own_css": css }))
        .await;
    assert_eq!((status, &kept["own_css"]), (200, &json!(css)));
    assert_eq!(server.get("/api/settings").await.1["own_css"], css);
    // Emptied, the app has its own look again.
    let (_, kept) = server
        .patch("/api/settings", json!({ "own_css": "" }))
        .await;
    assert_eq!(kept["own_css"], "");
}

#[tokio::test]
async fn an_imported_cards_file_name_is_kept_for_its_texts_imported_draft() {
    let server = start().await;
    let (_, named) = server
        .upload(
            "/api/cards?name=Mira%20of%20the%20North.png",
            common::card_file(),
        )
        .await;
    let id = named["card_id"].as_i64().unwrap();
    let (_, form) = server.get(&format!("/api/cards/{id}/edit")).await;
    let reference = form["characters"][0]["description"][0]["reference"]
        .as_str()
        .unwrap()
        .to_string();
    let (status, drafts) = server
        .get(&format!("/api/cards/{id}/drafts?reference={reference}"))
        .await;
    assert_eq!(status, 200);
    assert_eq!(drafts["file"], json!("Mira of the North.png"));
    assert_eq!(drafts["drafts"][0]["made"], json!("imported"));
    // One sent without a name has none (an exact copy is refused, so on another server).
    let server = start().await;
    let (_, unnamed) = server.upload("/api/cards", common::card_file()).await;
    let unnamed = unnamed["card_id"].as_i64().unwrap();
    let (_, drafts) = server
        .get(&format!(
            "/api/cards/{unnamed}/drafts?reference={reference}"
        ))
        .await;
    assert_eq!(drafts["drafts"][0]["made"], json!("imported"));
    assert!(drafts.get("file").is_none());
}

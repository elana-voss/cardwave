//! A reply written by the provider: how the provider is kept, a reply streamed,
//! stopped, swiped, failed or cut off by a restart, and what is not deleted
//! while one is written. The rest of a reply's prompt is `generate_lore.rs`;
//! the stand-in model server is `common::streamed`.

mod common;

use std::time::Duration;

use common::server::{WAIT, event, start};
use common::streamed::*;
use serde_json::{Value, json};
use tokio::time::{sleep, timeout};

#[tokio::test]
async fn the_provider_is_kept_without_showing_its_key() {
    let server = start().await;
    assert_eq!(server.get("/api/provider").await, (200, Value::Null));

    let set = |change: Value| {
        let mut provider = json!({ "base_url": "https://api.example.com/v1", "model": "gpt-test" });
        provider
            .as_object_mut()
            .unwrap()
            .extend(change.as_object().unwrap().clone());
        server.put("/api/provider", provider)
    };
    for wrong in [
        json!({ "base_url": "localhost:5001" }),
        json!({ "base_url": "ftp://example.com/v1" }),
        json!({ "base_url": "https://me:secret@example.com/v1" }),
        json!({ "base_url": "https://example.com/v1?version=2" }),
        json!({ "model": "  " }),
        json!({ "api_key": "sk two words" }),
        json!({ "sampling": { "temperature": 2.5 } }),
        json!({ "sampling": { "context_size": 100 } }),
    ] {
        assert_eq!(set(wrong.clone()).await.0, 400, "{wrong}");
    }
    assert_eq!(server.get("/api/provider").await.1, Value::Null);

    // A pasted key and address are tidied; the key is stored but never sent back.
    let pasted = json!({ "base_url": " https://api.example.com/v1/ ", "api_key": " sk-secret\n", "sampling": { "top_p": 0.9 } });
    let (status, provider) = set(pasted).await;
    assert_eq!(status, 200, "{provider}");
    let shown = json!({
        "base_url": "https://api.example.com/v1",
        "model": "gpt-test",
        "has_key": true,
        "key_end": null,
        "sampling": {
            "context_size": null, "temperature": null, "top_p": 0.9,
            "frequency_penalty": null, "presence_penalty": null, "seed": null,
        },
        "name": null,
        "worker_model": null,
    });
    assert_eq!(provider, shown);
    assert_eq!(server.get("/api/provider").await.1, shown);

    // Without a new key the stored one stays, but only for the same address;
    // values for a reply left out are the account's.
    let (_, provider) = set(json!({ "model": "gpt-other" })).await;
    assert_eq!(
        (
            &provider["has_key"],
            &provider["model"],
            &provider["sampling"]["top_p"]
        ),
        (&json!(true), &json!("gpt-other"), &json!(0.9))
    );
    assert_eq!(
        set(json!({ "base_url": "https://elsewhere.example.com/v1" }))
            .await
            .1["has_key"],
        false
    );
    assert_eq!(set(json!({ "api_key": "sk-new" })).await.1["has_key"], true);
    assert_eq!(set(json!({ "api_key": "" })).await.1["has_key"], false);
}

#[tokio::test]
async fn a_providers_own_name_is_kept_as_long_as_its_address() {
    let server = start().await;
    let set = |change: Value| {
        let mut provider = json!({ "base_url": "https://api.example.com/v1", "model": "gpt-test" });
        provider
            .as_object_mut()
            .unwrap()
            .extend(change.as_object().unwrap().clone());
        server.put("/api/provider", provider)
    };
    // Without one a provider has no name of the user's.
    assert_eq!(set(json!({})).await.1["name"], Value::Null);
    // A name is kept without the space around it, and told when the provider is read.
    let (status, named) = set(json!({ "name": "  My rig\n" })).await;
    assert_eq!((status, &named["name"]), (200, &json!("My rig")));
    assert_eq!(server.get("/api/provider").await.1["name"], "My rig");
    // Left out, it stays while the address does, whatever else is set.
    let (_, kept) = set(json!({ "model": "gpt-other", "api_key": "sk-new" })).await;
    assert_eq!(kept["name"], "My rig");
    // Another address is another provider: the name was not given for it.
    let elsewhere = json!({ "base_url": "https://elsewhere.example.com/v1" });
    assert_eq!(set(elsewhere).await.1["name"], Value::Null);
    assert_eq!(server.get("/api/provider").await.1["name"], Value::Null);
    // A name given with another address is that address's, and an empty one takes it off.
    let moved = json!({ "base_url": "https://third.example.com/v1", "name": "Third" });
    assert_eq!(set(moved).await.1["name"], "Third");
    let cleared = json!({ "base_url": "https://third.example.com/v1", "name": " " });
    assert_eq!(set(cleared).await.1["name"], Value::Null);

    // At most sixty characters, none of them a line end or the like.
    let longest = "n".repeat(60);
    assert_eq!(set(json!({ "name": longest })).await.1["name"], longest);
    for wrong in [json!("n".repeat(61)), json!("two\nlines")] {
        let (status, why) = set(json!({ "name": wrong })).await;
        assert_eq!(status, 400, "{why}");
    }
    assert_eq!(server.get("/api/provider").await.1["name"], longest);
}

#[tokio::test]
async fn the_end_of_a_long_key_is_told_and_nothing_of_a_short_one() {
    let server = start().await;
    let set = |key: Option<String>| {
        let mut provider = json!({ "base_url": "https://api.example.com/v1", "model": "gpt-test" });
        if let Some(key) = key {
            provider["api_key"] = key.into();
        }
        server.put("/api/provider", provider)
    };
    // The last four characters of a key of sixteen or more, by which the user knows it.
    for (key, end) in [
        (
            "sk-proj-0123456789abcdefghijklmnopqrstuvwxyz-4f2a",
            json!("4f2a"),
        ),
        ("k23456789012wxyz", json!("wxyz")),
        // Of a shorter one they would be too much of it.
        ("k2345678901wxyz", Value::Null),
        ("4f2a", Value::Null),
        ("", Value::Null),
    ] {
        let (status, provider) = set(Some(key.to_string())).await;
        assert_eq!(status, 200, "{provider}");
        assert_eq!(
            (&provider["key_end"], &provider["has_key"]),
            (&end, &json!(!key.is_empty())),
            "{key}"
        );
        // It is told again when the provider is read, and the key itself never.
        let (_, read) = server.get("/api/provider").await;
        assert_eq!(read, provider);
        assert!(key.len() < 16 || !read.to_string().contains(key), "{read}");
    }
    // A key that stays is told as before; one that goes with its address is not.
    let long = "k23456789012wxyz".to_string();
    set(Some(long)).await;
    assert_eq!(set(None).await.1["key_end"], "wxyz");
    let elsewhere = json!({ "base_url": "https://elsewhere.example.com/v1", "model": "gpt-test" });
    let (_, moved) = server.put("/api/provider", elsewhere).await;
    assert_eq!(
        (&moved["key_end"], &moved["has_key"]),
        (&Value::Null, &json!(false))
    );
}

#[tokio::test]
async fn a_reply_is_streamed_into_the_chat() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;

    let (status, message) = generate(&server, &chat, json!({})).await;
    assert_eq!(status, 202, "{message}");
    assert_eq!(
        (&message["role"], &message["content"], &message["complete"]),
        (&json!("assistant"), &json!(""), &json!(false))
    );

    // The provider gets the key, the model, what the user chose to send along,
    // the chat's reply length for a model that does not think, and nothing
    // else, and the prompt built from the card and the chat.
    let asked = provider.next().await;
    assert_eq!(asked.key.as_deref(), Some("Bearer sk-test"));
    let body = &asked.body;
    assert_eq!(
        (&body["model"], &body["stream"], &body["temperature"]),
        (&json!("test-model"), &json!(true), &json!(0.7))
    );
    assert_eq!(body["max_tokens"], 350);
    assert!(
        ["top_p", "seed"]
            .iter()
            .all(|name| body.get(name).is_none())
    );
    let prompt = &body["messages"];
    assert_eq!(prompt[0]["role"], "system");
    assert!(has(prompt, "Keeper of the north light"));
    assert!(
        prompt
            .as_array()
            .unwrap()
            .contains(&json!({ "role": "user", "content": "Why tonight?" }))
    );
    assert!(
        prompt
            .as_array()
            .unwrap()
            .iter()
            .all(|message| message["content"] != "")
    );

    // The first words, after a line that carries no text and a keep-alive.
    let mut first =
        b"data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n\n: keep-alive\n\n".to_vec();
    first.extend(says("The \u{1F30A} cause"));
    asked.answer.send(first).unwrap();
    let piece = event(&mut socket).await;
    assert_eq!(
        (
            &piece["type"],
            &piece["message_id"],
            &piece["start"],
            &piece["text"]
        ),
        (
            &json!("reply_text"),
            &message["id"],
            &json!(0),
            &json!("The \u{1F30A} cause")
        )
    );
    // A page that opens the chat now reads the reply as far as it is.
    let (_, view) = server.get(&chat).await;
    let newest = view["messages"].as_array().unwrap().last().unwrap();
    assert_eq!(
        (&newest["content"], &newest["complete"]),
        (&json!("The \u{1F30A} cause"), &json!(false))
    );
    // Meanwhile the chat takes nothing else.
    assert_eq!(generate(&server, &chat, json!({})).await.0, 409);
    assert_eq!(
        server
            .post(&format!("{chat}/messages"), json!({ "content": "Wait." }))
            .await
            .0,
        409
    );
    assert_eq!(
        server
            .put(
                &format!("{chat}/head"),
                json!({ "message_id": message["parent_id"] })
            )
            .await
            .0,
        409
    );
    let (written, answered) = (
        format!("/api/messages/{}", message["id"]),
        format!("/api/messages/{}", message["parent_id"]),
    );
    assert_eq!(
        server
            .patch(&written, json!({ "content": "Mine." }))
            .await
            .0,
        409
    );
    assert_eq!(
        server
            .post(
                &format!("{answered}/swipes"),
                json!({ "content": "Why now?" })
            )
            .await
            .0,
        409
    );

    // The rest arrives cut in the middle of a line and of a character, with
    // Windows line ends. The provider says it is done but does not hang up.
    let rest = "data: {\"choices\":[{\"delta\":{\"content\":\"way \u{2014} it fl\u{F6}ods at nine.\"}}]}\r\n\r\n".as_bytes();
    let cut = rest.iter().position(|&byte| byte == 0xE2).unwrap() + 1;
    sleep(Duration::from_millis(150)).await;
    asked.answer.send(rest[..cut].to_vec()).unwrap();
    sleep(Duration::from_millis(50)).await;
    asked.answer.send([&rest[cut..], DONE].concat()).unwrap();
    let whole = "The \u{1F30A} causeway \u{2014} it fl\u{F6}ods at nine.";
    let (text, ended) = follow(&mut socket, "The \u{1F30A} cause").await;
    assert_eq!(text, whole);
    assert_eq!(
        (&ended["chat_id"], &ended["message_id"], &ended["error"]),
        (&view["chat"]["id"], &message["id"], &Value::Null)
    );
    let reply = &ended["message"];
    assert_eq!(
        (&reply["content"], &reply["complete"], &reply["swipes"]),
        (&json!(whole), &json!(true), &json!([message["id"]]))
    );

    let (_, view) = server.get(&chat).await;
    assert_eq!(view["chat"]["head_id"], message["id"]);
    assert_eq!(view["messages"].as_array().unwrap().last().unwrap(), reply);
    assert_eq!(
        server
            .post(
                &format!("{chat}/messages"),
                json!({ "content": "At nine?" })
            )
            .await
            .0,
        201
    );
}

#[tokio::test]
async fn a_reply_can_be_stopped() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let stop = format!("{chat}/stop");
    // Nothing to stop is fine.
    assert_eq!(server.post(&stop, json!({})).await.0, 204);

    // Stopped in the middle, the reply keeps what it has.
    let (_, message) = generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    asked.answer.send(says("Because the")).unwrap();
    assert_eq!(event(&mut socket).await["text"], "Because the");
    // Also what has arrived since the pages were last told.
    asked.answer.send(says(" tide")).unwrap();
    sleep(Duration::from_millis(40)).await;
    assert_eq!(server.post(&stop, json!({})).await.0, 204);
    let (_, ended) = follow(&mut socket, "Because the").await;
    assert_eq!(
        (
            &ended["message"]["id"],
            &ended["message"]["content"],
            &ended["message"]["complete"],
            &ended["error"]
        ),
        (
            &message["id"],
            &json!("Because the tide"),
            &json!(true),
            &Value::Null
        )
    );
    // The server has hung up on the provider, which is what stops the model.
    let hung_up = async {
        while asked.answer.send(b": still there?\n\n".to_vec()).is_ok() {
            sleep(Duration::from_millis(20)).await;
        }
    };
    timeout(WAIT, hung_up)
        .await
        .expect("the provider is still being read");

    // Stopped before the first word, it leaves nothing behind.
    let (status, empty) = generate(&server, &chat, json!({})).await;
    assert_eq!(status, 202, "{empty}");
    let _asked = provider.next().await;
    assert_eq!(server.post(&stop, json!({})).await.0, 204);
    let (_, ended) = follow(&mut socket, "").await;
    assert_eq!(
        (&ended["message_id"], &ended["message"], &ended["error"]),
        (&empty["id"], &Value::Null, &Value::Null)
    );
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["chat"]["head_id"], message["id"]);
    assert_eq!(view["messages"].as_array().unwrap().len(), 3);
    assert_eq!(server.post("/api/chats/999/stop", json!({})).await.0, 404);
}

#[tokio::test]
async fn a_reply_is_written_again_as_a_swipe() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;

    generate(&server, &chat, json!({})).await;
    provider
        .next()
        .await
        .answer
        .send([&says("First.")[..], DONE].concat())
        .unwrap();
    let first = follow(&mut socket, "").await.1["message"].clone();
    assert_eq!(first["content"], "First.");

    // The second version stands beside the first and answers the same chat:
    // the prompt ends before the first one.
    let (status, second) = generate(&server, &chat, json!({ "regenerate": true })).await;
    assert_eq!(status, 202, "{second}");
    assert_eq!(
        (
            &second["swipes"],
            &second["parent_id"],
            &second["speaker_id"]
        ),
        (
            &json!([first["id"], second["id"]]),
            &first["parent_id"],
            &first["speaker_id"]
        )
    );
    let asked = provider.next().await;
    let prompt = &asked.body["messages"];
    assert!(has(prompt, "Why tonight?") && !has(prompt, "First."));
    asked
        .answer
        .send([&says("Second.")[..], DONE].concat())
        .unwrap();
    assert_eq!(
        follow(&mut socket, "").await.1["message"]["content"],
        "Second."
    );
    let (_, view) = server.get(&chat).await;
    let messages = view["messages"].as_array().unwrap();
    assert_eq!(
        (
            messages.len(),
            &messages[2]["content"],
            &view["chat"]["head_id"]
        ),
        (3, &json!("Second."), &second["id"])
    );

    // A version stopped before its first word is gone, and the one before it is in view again.
    let (_, empty) = generate(&server, &chat, json!({ "regenerate": true })).await;
    assert_eq!(
        empty["swipes"],
        json!([first["id"], second["id"], empty["id"]])
    );
    let _asked = provider.next().await;
    server.post(&format!("{chat}/stop"), json!({})).await;
    assert_eq!(follow(&mut socket, "").await.1["message"], Value::Null);
    let (_, view) = server.get(&chat).await;
    let newest = view["messages"].as_array().unwrap().last().unwrap();
    assert_eq!(
        (&view["chat"]["head_id"], &newest["swipes"]),
        (&second["id"], &json!([first["id"], second["id"]]))
    );

    // What cannot be written leaves the chat as it was, and free.
    let asked_id = &first["parent_id"];
    server
        .put(&format!("{chat}/head"), json!({ "message_id": asked_id }))
        .await;
    assert_eq!(
        generate(&server, &chat, json!({ "regenerate": true }))
            .await
            .0,
        400
    );
    assert_eq!(
        generate(&server, &chat, json!({ "speaker_id": 999 }))
            .await
            .0,
        400
    );
    assert_eq!(generate(&server, "/api/chats/999", json!({})).await.0, 404);
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        (
            view["messages"].as_array().unwrap().len(),
            &view["chat"]["head_id"]
        ),
        (2, asked_id)
    );
    // From the user's message a plain reply starts a third version.
    let (status, third) = generate(&server, &chat, json!({})).await;
    assert_eq!(
        (status, &third["swipes"]),
        (202, &json!([first["id"], second["id"], third["id"]]))
    );
}

#[tokio::test]
async fn a_chat_model_the_provider_no_longer_offers_is_marked_until_a_reply_comes_or_it_is_picked_anew()
 {
    let server = start().await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let gone = || async { server.get("/api/provider-list").await.1["kinds"][0]["gone"].clone() };
    assert_eq!(gone().await, json!(false));

    let no = json!({ "error": { "message": "The model `test-model` does not exist" } });
    *provider.refusal.lock().unwrap() = Some((404, no.to_string()));
    generate(&server, &chat, json!({})).await;
    follow(&mut socket, "").await;
    assert_eq!(gone().await, json!(true));
    // Picked anew, it is tried again.
    use_provider(&server, &provider.url).await;
    assert_eq!(gone().await, json!(false));

    generate(&server, &chat, json!({})).await;
    follow(&mut socket, "").await;
    assert_eq!(gone().await, json!(true));
    // A reply that comes says it is offered after all.
    *provider.refusal.lock().unwrap() = None;
    generate(&server, &chat, json!({})).await;
    provider
        .next()
        .await
        .answer
        .send([&says("Hi")[..], DONE].concat())
        .unwrap();
    assert_eq!(follow(&mut socket, "").await.1["message"]["content"], "Hi");
    assert_eq!(gone().await, json!(false));
}

#[tokio::test]
async fn a_failed_reply_says_why() {
    let server = start().await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let (status, refused) = generate(&server, &chat, json!({})).await;
    // Told apart from other failures by its status, as the page leads to the setup from it.
    assert_eq!(
        (status, refused),
        (
            424,
            json!({ "code": "no_provider", "error": "no model provider is set up yet", "details": {} })
        )
    );

    // The provider refuses: the reason reaches the page and the chat is as before.
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let no = json!({ "error": { "message": "Incorrect API key provided", "type": "invalid_request_error" } });
    *provider.refusal.lock().unwrap() = Some((401, no.to_string()));
    let (status, message) = generate(&server, &chat, json!({})).await;
    assert_eq!(status, 202);
    let (_, ended) = follow(&mut socket, "").await;
    // The provider's own words are a detail of its code, which the UI words.
    let error = &ended["error"];
    assert_eq!(
        (&error["code"], &error["details"]["status"]),
        (&json!("provider_refused"), &json!(401)),
        "{error}"
    );
    assert!(
        error["details"]["reason"]
            .as_str()
            .unwrap()
            .contains("Incorrect API key provided"),
        "{error}"
    );
    assert_eq!(
        (&ended["message_id"], &ended["message"]),
        (&message["id"], &Value::Null)
    );
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        (
            view["messages"].as_array().unwrap().len(),
            &view["chat"]["head_id"]
        ),
        (2, &message["parent_id"])
    );

    // So does a server that answers 200 with what went wrong, not with a stream.
    *provider.refusal.lock().unwrap() =
        Some((200, json!({ "error": "The quota is used up" }).to_string()));
    generate(&server, &chat, json!({})).await;
    let (_, ended) = follow(&mut socket, "").await;
    let reported = json!({ "what": "server_reported", "reason": "The quota is used up" });
    assert_eq!(
        (&ended["error"]["code"], &ended["error"]["details"]),
        (&json!("model_answer"), &reported)
    );
    assert_eq!(ended["message"], Value::Null);
    // A reply that ends by itself without a word has failed; it was not stopped.
    *provider.refusal.lock().unwrap() = None;
    generate(&server, &chat, json!({})).await;
    provider.next().await.answer.send(DONE.to_vec()).unwrap();
    let (_, ended) = follow(&mut socket, "").await;
    assert!(
        ended["error"]["error"]
            .as_str()
            .unwrap()
            .contains("no text"),
        "{}",
        ended["error"]
    );
    assert_eq!(ended["message"], Value::Null);

    // It fails in the middle: what was written stays, to the last word.
    generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    asked.answer.send(says("The tide")).unwrap();
    assert_eq!(event(&mut socket).await["text"], "The tide");
    let failure = b"data: {\"error\":{\"message\":\"The model is overloaded\"}}\n\n";
    asked
        .answer
        .send([&says(" turns")[..], failure].concat())
        .unwrap();
    let (_, ended) = follow(&mut socket, "The tide").await;
    assert!(
        ended["error"]["error"]
            .as_str()
            .unwrap()
            .contains("The model is overloaded")
    );
    assert_eq!(
        (&ended["message"]["content"], &ended["message"]["complete"]),
        (&json!("The tide turns"), &json!(true))
    );

    // The connection breaks after some words, the server never saying it is done: the words stay, and the reply says it broke off.
    generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    asked.answer.send(says("The tide")).unwrap();
    assert_eq!(event(&mut socket).await["text"], "The tide");
    drop(asked);
    let (_, ended) = follow(&mut socket, "The tide").await;
    assert_eq!(
        (
            &ended["error"]["details"]["what"],
            &ended["message"]["content"]
        ),
        (&json!("reply_broke_off"), &json!("The tide"))
    );

    // A server that does not stream sends the reply whole.
    let whole =
        json!({ "choices": [{ "message": { "role": "assistant", "content": "All at once." } }] });
    *provider.refusal.lock().unwrap() = Some((200, whole.to_string()));
    generate(&server, &chat, json!({})).await;
    let (_, ended) = follow(&mut socket, "").await;
    assert_eq!(
        (&ended["message"]["content"], &ended["error"]),
        (&json!("All at once."), &Value::Null)
    );

    // Nobody answers at the address.
    use_provider(&server, "http://127.0.0.1:1/v1").await;
    generate(&server, &chat, json!({})).await;
    let (_, ended) = follow(&mut socket, "").await;
    assert!(
        ended["error"]["error"]
            .as_str()
            .unwrap()
            .contains("cannot be reached"),
        "{}",
        ended["error"]
    );
    assert_eq!(ended["message"], Value::Null);
}

#[tokio::test]
async fn a_reply_cut_off_by_a_restart_is_ended() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let (_, message) = generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    asked.answer.send(says("The cause")).unwrap();
    assert_eq!(event(&mut socket).await["text"], "The cause");
    let newest = |view: Value| view["messages"].as_array().unwrap().last().unwrap().clone();

    // A second server started on the same data folder leaves the reply alone.
    drop(cardwave_server::router(server.options()).unwrap());
    assert_eq!(newest(server.get(&chat).await.1)["complete"], false);

    // The server stops in the middle of the reply. Started again, it ends the
    // reply as far as it got, and the chat goes on.
    drop(socket);
    let server = server.restart().await;
    let cut = newest(server.get(&chat).await.1);
    assert_eq!(
        (&cut["id"], &cut["content"], &cut["complete"]),
        (&message["id"], &json!("The cause"), &json!(true))
    );
    assert_eq!(
        server
            .post(&format!("{chat}/messages"), json!({ "content": "Go on." }))
            .await
            .0,
        201
    );
}

#[tokio::test]
async fn nothing_is_deleted_for_good_while_a_reply_is_written_in_it() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let (_, view) = server.get(&chat).await;
    let card = format!("/api/cards/{}", view["characters"][0]["card_id"]);
    let delete = async |path: &str| server.call(reqwest::Method::DELETE, path, None).await.0;

    let mut socket = server.listen().await;
    generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    asked.answer.send(says("Because")).unwrap();
    assert_eq!(event(&mut socket).await["text"], "Because");
    // Neither the chat by itself, nor with its card, nor with all of the Trash.
    assert_eq!(server.patch(&chat, json!({ "trashed": true })).await.0, 200);
    assert_eq!(delete(&chat).await, 409);
    assert_eq!(server.patch(&card, json!({ "trashed": true })).await.0, 200);
    assert_eq!(delete(&card).await, 409);
    assert_eq!(delete("/api/trash").await, 204);
    assert_eq!(server.get(&card).await.0, 200);
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["messages"].as_array().unwrap().len(), 3);

    // Once the reply has ended, it all goes.
    assert_eq!(server.post(&format!("{chat}/stop"), json!({})).await.0, 204);
    follow(&mut socket, "Because").await;
    assert_eq!(delete(&card).await, 204);
    assert_eq!(server.get(&chat).await.0, 404);
}

#[tokio::test]
async fn a_reply_keeps_whom_it_was_asked_of_and_how_long_it_took() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;

    // "Reply statistics": the model and the provider in words (its host, as it has no name),
    // the time to the first word and in all.
    let (_, message) = generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    sleep(Duration::from_millis(200)).await;
    asked.answer.send(says("At")).unwrap();
    sleep(Duration::from_millis(150)).await;
    asked
        .answer
        .send([says(" nine."), DONE.to_vec()].concat())
        .unwrap();
    let (_, ended) = follow(&mut socket, "").await;
    let reply = &ended["message"];
    assert_eq!(reply["id"], message["id"]);
    // A server on this computer the user did not name has no name: the page words it.
    assert_eq!(
        (&reply["model"], &reply["provider"]),
        (&json!("test-model"), &json!(""))
    );
    let (first, all) = (
        reply["times"]["to_first_word_ms"].as_u64().unwrap(),
        reply["times"]["in_all_ms"].as_u64().unwrap(),
    );
    assert!(first >= 200 && all >= first + 150, "{first} {all}");
    let (_, view) = server.get(&chat).await;
    assert_eq!(
        view["messages"].as_array().unwrap().last().unwrap()["times"],
        reply["times"]
    );
}

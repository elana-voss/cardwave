//! A reply's prompt and what it tells of it: the context each part took, the
//! lorebook entries it was given, a reply continued, the user's message written
//! and bettered by the model, and the time told to a character writing first.
//! The stand-in model server is `common::streamed`.

mod common;

use common::server::start;
use common::streamed::*;
use serde_json::{Value, json};

#[tokio::test]
async fn a_reply_says_how_much_of_the_context_its_prompt_took_part_by_part_and_each_message_its_tokens()
 {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let (_, view) = server.get(&chat).await;
    // A message no model wrote has no context of its own, and its tokens all the same.
    assert_eq!(view["messages"][1]["context"], Value::Null);
    assert!(view["messages"][1]["tokens"].as_u64().unwrap() > 0);
    written(&server, &mut provider, &mut socket, &chat, json!({})).await;
    let (_, view) = server.get(&chat).await;
    let context = &view["messages"][2]["context"];
    let (used, size) = (
        context["used"].as_u64().unwrap(),
        context["size"].as_u64().unwrap(),
    );
    assert!(used > 0 && used < size, "{context}");
    // "Sent to the AI": its parts add up to what the prompt took; the card and the chat are in it.
    let sent = &view["messages"][2]["sent"];
    let part = |name: &str| sent[name].as_u64().unwrap();
    let parts = ["card", "persona", "memory", "lorebook", "history"];
    assert_eq!(
        parts.iter().map(|name| part(name)).sum::<u64>(),
        used,
        "{sent}"
    );
    assert!(part("card") > 0 && part("history") > 0, "{sent}");
    assert_eq!(view["messages"][1]["sent"], Value::Null);
}

#[tokio::test]
async fn a_reply_says_which_lorebook_entries_it_was_given_and_a_chat_can_leave_them_out() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let (_, view) = server.get(&chat).await;
    let card = view["characters"][0]["card_id"].as_i64().unwrap();
    let coast = |on: bool, removed: Value| json!([{ "card_id": card, "reference": "lorebook.coast", "name": "coast", "on": on, "entries": ["lore.wreck", "lore.lamp", "lore.off"], "removed": removed, "trashed": false, "taken": false, "everywhere": false, "persona": false }]);
    let lamp = json!({ "card_id": card, "reference": "lore.lamp", "name": "lamp" });
    assert_eq!(view["lorebooks"], coast(true, json!([])));
    // A greeting and the user's message were given nothing.
    assert_eq!(
        (&view["messages"][0]["lore"], &view["messages"][1]["lore"]),
        (&json!([]), &json!([]))
    );

    // Asked for a reply, the answer says at once what the prompt holds; so do the reply's end and the chat.
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, json!({})).await;
    assert_eq!(lore, json!([lamp]));
    assert!(has(&prompt, "The lamp must never go out."));
    assert_eq!(
        server.get(&chat).await.1["messages"][2]["lore"],
        json!([lamp])
    );

    // The entry left out: the next reply is written without it, and the first one's record stays.
    let set = |reference: &'static str, on: bool| {
        let (server, chat) = (&server, &chat);
        async move {
            server
                .put(
                    &format!("{chat}/lore"),
                    json!({ "card_id": card, "reference": reference, "on": on }),
                )
                .await
        }
    };
    assert_eq!(
        set("lore.lamp", false).await,
        (200, coast(true, json!([lamp])))
    );
    let again = || json!({ "regenerate": true });
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, again()).await;
    assert_eq!(lore, json!([]));
    assert!(!has(&prompt, "The lamp must never go out."));
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["lorebooks"], coast(true, json!([lamp])));
    let first = view["messages"][2]["swipes"][0].as_i64().unwrap();
    let (_, view) = server
        .put(&format!("{chat}/head"), json!({ "message_id": first }))
        .await;
    assert_eq!(view["messages"][2]["lore"], json!([lamp]));

    // Taken back in, with the whole lorebook switched off: still nothing of it.
    assert_eq!(set("lore.lamp", true).await, (200, coast(true, json!([]))));
    assert_eq!(
        set("lorebook.coast", false).await,
        (200, coast(false, json!([])))
    );
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, again()).await;
    assert_eq!(lore, json!([]));
    assert!(!has(&prompt, "The lamp must never go out."));
    // Switched on again, it is back.
    assert_eq!(set("lorebook.coast", true).await.0, 200);
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, again()).await;
    assert_eq!(lore, json!([lamp]));
    assert!(has(&prompt, "The lamp must never go out."));

    // What the chat does not have is refused, and so is a chat that is not there.
    assert_eq!(set("lore.nothing", false).await.0, 400);
    let other = json!({ "card_id": card, "reference": "lorebook.coast", "on": false });
    assert_eq!(server.put("/api/chats/999/lore", other).await.0, 404);
}

#[tokio::test]
async fn a_chat_takes_a_lorebook_of_the_library_along_and_its_replies_say_what_it_gave_them() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let file = json!({ "name": "Harbour", "entries": [
        { "keys": ["tonight"], "comment": "Pier", "content": "The pier is rotten.", "insertion_order": 200 },
        { "keys": [], "comment": "Bell", "content": "The bell rings in fog.", "constant": true, "insertion_order": 150 },
    ]});
    let (_, imported) = server
        .upload("/api/lorebooks", file.to_string().into_bytes())
        .await;
    let harbour = imported["lorebook"]["id"].as_i64().unwrap();
    let card = server.get(&chat).await.1["characters"][0]["card_id"]
        .as_i64()
        .unwrap();
    let lamp = json!({ "card_id": card, "reference": "lore.lamp", "name": "lamp" });
    let bell = json!({ "lorebook_id": harbour, "reference": "lore.harbour-bell", "name": "Bell" });
    let pier = json!({ "lorebook_id": harbour, "reference": "lore.harbour-pier", "name": "Pier" });
    let book = |removed: Value| json!({ "lorebook_id": harbour, "reference": "lorebook.harbour", "name": "Harbour", "on": true, "entries": ["lore.harbour-pier", "lore.harbour-bell"], "removed": removed, "trashed": false, "taken": true, "everywhere": false, "persona": false });
    let delete = async |path: &str| server.call(reqwest::Method::DELETE, path, None).await;

    // Taken along, it stands after the characters' own.
    let take = format!("{chat}/lorebooks");
    let (status, listed) = server.post(&take, json!({ "lorebook_id": harbour })).await;
    assert_eq!(
        (status, listed.as_array().unwrap().len(), &listed[1]),
        (200, 2, &book(json!([])))
    );
    assert_eq!(server.get(&chat).await.1["lorebooks"], listed);

    // A reply is given its entries among the card's, each noted with where it is from.
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, json!({})).await;
    assert_eq!(lore, json!([lamp, bell, pier]));
    assert!(has(&prompt, "The bell rings in fog.") && has(&prompt, "The pier is rotten."));

    // An entry is left out of the chat by the lorebook it is from.
    let lore_path = format!("{chat}/lore");
    let out = json!({ "lorebook_id": harbour, "reference": "lore.harbour-bell", "on": false });
    let (status, listed) = server.put(&lore_path, out).await;
    assert_eq!((status, &listed[1]), (200, &book(json!([bell]))));
    let again = || json!({ "regenerate": true });
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, again()).await;
    assert_eq!(lore, json!([lamp, pier]));
    assert!(!has(&prompt, "The bell rings in fog.") && has(&prompt, "The pier is rotten."));
    // A change has to say where the lore is from.
    assert_eq!(
        server
            .put(
                &lore_path,
                json!({ "reference": "lore.harbour-bell", "on": true })
            )
            .await
            .0,
        422
    );

    // Let go, the next reply has nothing of it, and the earlier ones keep what they noted.
    let (status, listed) = delete(&format!("{take}/{harbour}")).await;
    assert_eq!(
        (status, listed.as_array().unwrap().len(), &listed[0]["name"]),
        (200, 1, &json!("coast"))
    );
    let (lore, prompt) = written(&server, &mut provider, &mut socket, &chat, again()).await;
    assert_eq!(lore, json!([lamp]));
    assert!(!has(&prompt, "The pier is rotten."));
    let (_, view) = server.get(&chat).await;
    let first = view["messages"][2]["swipes"][0].as_i64().unwrap();
    let (_, view) = server
        .put(&format!("{chat}/head"), json!({ "message_id": first }))
        .await;
    assert_eq!(view["messages"][2]["lore"], json!([lamp, bell, pier]));

    // What is not there is neither taken nor let go, and one in the Trash is not taken.
    assert_eq!(delete(&format!("{take}/{harbour}")).await.0, 400);
    assert_eq!(
        server.post(&take, json!({ "lorebook_id": 999 })).await.0,
        404
    );
    assert_eq!(
        server
            .post(
                "/api/chats/999/lorebooks",
                json!({ "lorebook_id": harbour })
            )
            .await
            .0,
        404
    );
    assert_eq!(
        delete(&format!("/api/chats/999/lorebooks/{harbour}"))
            .await
            .0,
        404
    );
    server
        .patch(
            &format!("/api/lorebooks/{harbour}"),
            json!({ "trashed": true }),
        )
        .await;
    let (status, error) = server.post(&take, json!({ "lorebook_id": harbour })).await;
    assert_eq!(
        (status, error["error"].as_str().unwrap()),
        (
            400,
            "the lorebook “Harbour” is in the Trash; restore it to use it"
        )
    );
}

#[tokio::test]
async fn a_reply_is_continued_in_its_own_message() {
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
        .send([&says("The tide.")[..], DONE].concat())
        .unwrap();
    let first = follow(&mut socket, "").await.1["message"].clone();

    // The model is given the reply as it stands and asked to go on; its words
    // follow the reply's in a paragraph of their own, without the space it began with.
    let (status, going) = generate(&server, &chat, json!({ "continue": true })).await;
    assert_eq!(status, 202, "{going}");
    assert_eq!(
        (&going["id"], &going["content"], &going["complete"]),
        (&first["id"], &json!("The tide."), &json!(false))
    );
    let asked = provider.next().await;
    let prompt = &asked.body["messages"];
    assert!(has(prompt, "The tide."));
    assert!(
        prompt
            .as_array()
            .unwrap()
            .contains(&json!({ "role": "user", "content": "[Continue your last message without repeating its original content.]" }))
    );
    asked
        .answer
        .send([&says(" It turns at")[..], &says(" midnight.")[..], DONE].concat())
        .unwrap();
    // The end tells the reply as it is, which may be more than was pushed.
    let ended = follow(&mut socket, "The tide.").await.1;
    let text = "The tide.\n\nIt turns at midnight.";
    assert_eq!(
        (&ended["message"]["content"], &ended["message"]["complete"]),
        (&json!(text), &json!(true))
    );
    let (_, view) = server.get(&chat).await;
    let messages = view["messages"].as_array().unwrap();
    assert_eq!(
        (
            messages.len(),
            &messages[2]["content"],
            &messages[2]["swipes"]
        ),
        (3, &json!(text), &json!([first["id"]]))
    );

    // Cut off inside a sentence, a reply goes on in it.
    let id = first["id"].as_i64().unwrap();
    server
        .patch(
            &format!("/api/messages/{id}"),
            json!({ "content": "She walked to the" }),
        )
        .await;
    generate(&server, &chat, json!({ "continue": true })).await;
    provider
        .next()
        .await
        .answer
        .send([&says("door.")[..], DONE].concat())
        .unwrap();
    assert_eq!(
        follow(&mut socket, "She walked to the").await.1["message"]["content"],
        "She walked to the door."
    );

    // Stopped before its first word, or failing, the reply keeps what it had.
    generate(&server, &chat, json!({ "continue": true })).await;
    let _asked = provider.next().await;
    server.post(&format!("{chat}/stop"), json!({})).await;
    let ended = follow(&mut socket, "She walked to the door.").await.1;
    assert_eq!(
        (&ended["message"]["content"], &ended["error"]),
        (&json!("She walked to the door."), &Value::Null)
    );
    generate(&server, &chat, json!({ "continue": true })).await;
    provider.next().await.answer.send(DONE.to_vec()).unwrap();
    let ended = follow(&mut socket, "She walked to the door.").await.1;
    assert_eq!(ended["message"]["content"], "She walked to the door.");
    assert_eq!(ended["error"]["code"], "no_text");

    // After a blank the words follow as they come; a reply without words has nothing to go on from.
    server
        .patch(
            &format!("/api/messages/{id}"),
            json!({ "content": "She waited.\n" }),
        )
        .await;
    generate(&server, &chat, json!({ "continue": true })).await;
    provider
        .next()
        .await
        .answer
        .send([&says("Then she left.")[..], DONE].concat())
        .unwrap();
    assert_eq!(
        follow(&mut socket, "She waited.\n").await.1["message"]["content"],
        "She waited.\nThen she left."
    );
    server
        .patch(&format!("/api/messages/{id}"), json!({ "content": " " }))
        .await;
    let (status, refused) = generate(&server, &chat, json!({ "continue": true })).await;
    assert_eq!(
        (status, &refused["error"]),
        (400, &json!("the reply has no text to continue"))
    );

    // Only a character's reply is continued, and not as it is written again.
    assert_eq!(
        generate(
            &server,
            &chat,
            json!({ "continue": true, "regenerate": true })
        )
        .await
        .0,
        400
    );
    server
        .put(
            &format!("{chat}/head"),
            json!({ "message_id": first["parent_id"] }),
        )
        .await;
    let (status, refused) = generate(&server, &chat, json!({ "continue": true })).await;
    assert_eq!(
        (status, &refused["error"]),
        (400, &json!("only a character's reply can be continued"))
    );
    assert_eq!(
        generate(&server, "/api/chats/999", json!({ "continue": true }))
            .await
            .0,
        404
    );
}

#[tokio::test]
async fn the_model_writes_the_users_message_and_betters_it() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let draft = format!("{chat}/draft");

    // Written for the user: the chat's prompt, and what to write as long as the
    // user's own messages are; the user's name before it is taken off.
    let (answer, ()) = tokio::join!(server.post(&draft, json!({})), async {
        let asked = provider.next().await;
        let prompt = &asked.body["messages"];
        assert!(has(prompt, "Keeper of the north light") && has(prompt, "Why tonight?"));
        let ask = json!({ "role": "user", "content": "[Write your next reply from the point of view of Guest, using the user persona and the chat history so far as a guideline for the writing style of Guest. Don't write as Mira or system. Don't describe actions of Mira. Limit your response to approximately 1 sentence.]" });
        assert!(prompt.as_array().unwrap().contains(&ask), "{prompt}");
        asked
            .answer
            .send(
                [
                    &says("Guest: I came")[..],
                    &says(" for the tide.")[..],
                    DONE,
                ]
                .concat(),
            )
            .unwrap();
    });
    assert_eq!(answer, (200, json!({ "content": "I came for the tide." })));

    // Bettered: the chat's last messages and the text, and what the model says
    // around its answer is taken off.
    let (answer, ()) = tokio::join!(
        server.post(&draft, json!({ "improve": " i want see lamp " })),
        async {
            let asked = provider.next().await;
            let prompt = &asked.body["messages"];
            assert_eq!(prompt[0]["role"], "system");
            assert!(
                prompt[0]["content"]
                    .as_str()
                    .unwrap()
                    .contains("input improver")
            );
            // The chat's messages, the characters' too.
            assert!(has(prompt, "Why tonight?") && has(prompt, "You picked a night for it"));
            let ask = last(prompt);
            assert!(
                ask.contains("easier for Mira to respond")
                    && ask.ends_with("# Current message from Guest:\ni want see lamp]"),
                "{ask}"
            );
            asked
                .answer
                .send(
                    [
                        &says("\"Improved message: I want to see the lamp.\"")[..],
                        DONE,
                    ]
                    .concat(),
                )
                .unwrap();
        }
    );
    assert_eq!(
        answer,
        (200, json!({ "content": "I want to see the lamp." }))
    );

    // Quotes that are the user's own, and words that only begin like what a model says before its answer, stay.
    for (mine, answer) in [
        ("\"Come here,\" I whisper.", "\"Come here,\" I whisper."),
        ("\"I'm here.\"", "\"I am here.\""),
        ("better security", "Improved security is all I ask."),
        (
            "come here i whisper now",
            "\"Come here,\" I whisper, \"now.\"",
        ),
    ] {
        let (got, ()) = tokio::join!(server.post(&draft, json!({ "improve": mine })), async {
            provider
                .next()
                .await
                .answer
                .send([&says(answer)[..], DONE].concat())
                .unwrap();
        });
        assert_eq!(got, (200, json!({ "content": answer })));
    }

    // The chat is as it was, and nothing is asked of a model for nothing.
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["messages"].as_array().unwrap().len(), 2);
    assert_eq!(server.post(&draft, json!({ "improve": "  " })).await.0, 400);
    assert_eq!(server.post("/api/chats/999/draft", json!({})).await.0, 404);
    let (answer, ()) = tokio::join!(server.post(&draft, json!({})), async {
        provider.next().await.answer.send(DONE.to_vec()).unwrap();
    });
    assert_eq!(
        answer,
        (
            400,
            json!({ "code": "no_text", "error": "the model sent no text", "details": {} })
        )
    );
}

/// A character writing first, the newest message its own greeting, is told the
/// time after the chat's log; a reply to the user's message just sent is not.
#[tokio::test]
async fn a_character_writing_first_is_told_the_time() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let new = json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
    let (_, view) = server.post("/api/chats", new).await;
    let first = format!("/api/chats/{}", view["chat"]["id"]);
    assert_eq!(generate(&server, &first, json!({})).await.0, 202);
    let prompt = provider.next().await.body["messages"].clone();
    // After the log, before the card's post-history instructions.
    let note = &prompt.as_array().unwrap().iter().rev().nth(1).unwrap();
    assert_eq!(note["role"], "system");
    let said = note["content"].as_str().unwrap();
    assert!(
        said.starts_with("[It is ")
            && said.ends_with("The last message was written less than a minute ago.]"),
        "{said}"
    );
    server.post(&format!("{first}/stop"), json!({})).await;

    let (_, view) = server
        .post(
            "/api/chats",
            json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] }),
        )
        .await;
    let answered = format!("/api/chats/{}", view["chat"]["id"]);
    server
        .post(
            &format!("{answered}/messages"),
            json!({ "content": "Why tonight?" }),
        )
        .await;
    assert_eq!(generate(&server, &answered, json!({})).await.0, 202);
    let prompt = provider.next().await.body["messages"].clone();
    assert!(!has(&prompt, "[It is "));
}

#[tokio::test]
async fn the_words_in_the_field_steer_write_for_me_and_a_continued_reply() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let draft = format!("{chat}/draft");

    // Write for me is told the direction inside its instruction; it is sent as no message.
    let (answer, ()) = tokio::join!(
        server.post(&draft, json!({ "direction": "  she asks about the lamp " })),
        async {
            let asked = provider.next().await;
            let prompt = &asked.body["messages"];
            assert!(
                has(
                    prompt,
                    "Limit your response to approximately 1 sentence. Follow this direction from Guest: she asks about the lamp]"
                ) && !has(prompt, "  she asks"),
                "{prompt}"
            );
            asked
                .answer
                .send([&says("Is the lamp lit?")[..], DONE].concat())
                .unwrap();
        }
    );
    assert_eq!(answer, (200, json!({ "content": "Is the lamp lit?" })));
    // An improvement has the field's words as its message, so no direction besides.
    let both = json!({ "improve": "hello", "direction": "kinder" });
    assert_eq!(server.post(&draft, both).await.0, 400);

    // A continued reply is told it too; a direction without continuing is refused.
    let mut socket = server.listen().await;
    generate(&server, &chat, json!({})).await;
    provider
        .next()
        .await
        .answer
        .send([&says("The tide.")[..], DONE].concat())
        .unwrap();
    follow(&mut socket, "").await;
    let (status, _) = generate(&server, &chat, json!({ "direction": "darker" })).await;
    assert_eq!(status, 400);
    let (status, going) = generate(
        &server,
        &chat,
        json!({ "continue": true, "direction": "it grows darker" }),
    )
    .await;
    assert_eq!(status, 202, "{going}");
    let asked = provider.next().await;
    assert!(has(
        &asked.body["messages"],
        "[Continue your last message without repeating its original content. Follow this direction from Guest: it grows darker]"
    ));
    asked
        .answer
        .send([&says(" Night came.")[..], DONE].concat())
        .unwrap();
    follow(&mut socket, "The tide.").await;
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["messages"].as_array().unwrap().len(), 3);
}

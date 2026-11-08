//! A chat without a character: the AI itself, with no persona, whose replies
//! carry no speaker and whose prompt is the chat alone, and which names itself
//! after the first reply (the pretend model answers both); one with a
//! character names itself after its second exchange, once, unless renamed.

mod common;

use common::Scratch;
use common::server::{WAIT, event, start};
use cw_chat::chats::{self, NewChat, NewMessage};
use cw_library::settings::{self, ChangeSettings};
use cw_prompt::Role;
use cw_prompt::Variables;
use cw_prompt::builder::{self, PromptRequest};
use cw_provider::pretend;
use serde_json::json;
use tokio::time::timeout;

#[tokio::test]
async fn a_chat_without_a_character_is_the_ai_and_names_itself() {
    let server = start().await;
    let provider = json!({ "base_url": pretend::ADDRESS, "model": "pretend-chat", "api_key": "sk-cardwave-fake-0000" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    // A default persona is not taken.
    let persona = json!({ "name": "Ada", "description": "" });
    let (_, made) = server.post("/api/personas", persona).await;
    let default = json!({ "is_default": true });
    assert_eq!(
        server
            .patch(&format!("/api/personas/{}", made["id"]), default)
            .await
            .0,
        200
    );

    let (status, view) = server.post("/api/chats", json!({ "characters": [] })).await;
    assert_eq!(status, 201, "{view}");
    assert_eq!(
        view["chat"]["title"], "",
        "a chat not yet named has no title; the page words it"
    );
    assert_eq!(view["persona"], json!(null));
    assert_eq!(view["messages"], json!([]));
    assert_eq!(view["model"], "pretend-chat");
    let chat = format!("/api/chats/{}", view["chat"]["id"]);

    let mut socket = server.listen().await;
    let asked = json!({ "content": "Plan a trip to Lisbon." });
    assert_eq!(server.post(&format!("{chat}/messages"), asked).await.0, 201);
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let mut titled = None;
    let mut ended = None;
    while titled.is_none() || ended.is_none() {
        let event = timeout(WAIT, event(&mut socket)).await.expect("an event");
        match event["type"].as_str().unwrap() {
            "reply_ended" => ended = Some(event),
            "chat_title" => titled = Some(event),
            _ => {}
        }
    }
    let ended = ended.unwrap();
    assert_eq!(ended["error"], json!(null), "{ended}");
    assert_eq!(ended["message"]["speaker_id"], json!(null));
    assert_eq!(ended["message"]["content"], pretend::REPLY);
    assert_eq!(ended["message"]["model"], "pretend-chat");
    assert_eq!(titled.unwrap()["title"], "A talk with the pretend model");
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["chat"]["title"], "A talk with the pretend model");

    // A reply keeps the model that wrote it when another is set up.
    let other = json!({ "base_url": pretend::ADDRESS, "model": "pretend-chat-mini", "api_key": "sk-cardwave-fake-0000" });
    assert_eq!(server.put("/api/provider", other).await.0, 200);
    let (_, view) = server.get(&chat).await;
    assert_eq!(view["model"], "pretend-chat-mini");
    assert_eq!(view["messages"][1]["model"], "pretend-chat");
    // Its file calls the AI "AI", whatever the chat's title.
    let (_, file) = server.download(&format!("{chat}/export")).await;
    let file = String::from_utf8(file).unwrap();
    assert!(file.contains(r#""name":"AI""#), "{file}");

    // It takes no character.
    let (_, card) = server.upload("/api/cards", common::card_file()).await;
    let add = json!({ "card_id": card["card_id"], "character": "mira" });
    assert_eq!(server.post(&format!("{chat}/characters"), add).await.0, 400);
}

#[test]
fn its_prompt_is_the_chat_alone_and_it_is_named_once() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let new = NewChat {
        characters: &[],
        persona_id: None,
        greeting: 0,
    };
    let chat_id = chats::create(db, me, &new).unwrap();
    // Not before a reply to the user.
    assert_eq!(chats::title::unnamed(db, me, chat_id).unwrap(), None);
    let user = NewMessage {
        role: Role::User,
        speaker_id: None,
        content: "Hello.",
        complete: true,
    };
    chats::append(db, me, chat_id, &user).unwrap();
    let reply = NewMessage {
        role: Role::Assistant,
        speaker_id: None,
        content: "Hi.",
        complete: true,
    };
    chats::append(db, me, chat_id, &reply).unwrap();

    let inputs = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    assert_eq!(inputs.card_id, None);
    assert_eq!(inputs.character.name, "");
    // It is told the one text of Settings, its date and time filled in when the prompt is built.
    assert_eq!(inputs.character.system_prompt, settings::PLAIN_PROMPT);
    let mut state = inputs.state.clone();
    let request = PromptRequest::new(&inputs.character, 8000);
    let built = builder::build(&request, &mut state, &mut Variables::new()).messages;
    let year = chrono::Local::now().format("%Y").to_string();
    assert!(
        built[0]
            .content
            .contains("You are a helpful, honest assistant. It is now")
    );
    assert!(built[0].content.contains(&year), "{}", built[0].content);
    let change = ChangeSettings {
        plain_prompt: Some("You are terse.".to_string()),
        ..Default::default()
    };
    settings::change(db, me, &change).unwrap();
    let inputs_now = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    assert_eq!(inputs_now.character.system_prompt, "You are terse.");
    assert_eq!(inputs.state.persona_name, "");
    assert_eq!(inputs.state.messages.len(), 2);

    let said = chats::title::unnamed(db, me, chat_id).unwrap();
    assert_eq!(
        said,
        Some(vec!["User: Hello.".to_string(), "AI: Hi.".to_string()])
    );

    // Of many messages before the first reply, the newest up to it.
    let other = chats::create(db, me, &new).unwrap();
    for n in 1..=5 {
        let asked = format!("Part {n}.");
        let user = NewMessage {
            content: &asked,
            ..user
        };
        chats::append(db, me, other, &user).unwrap();
    }
    chats::append(db, me, other, &reply).unwrap();
    let said = chats::title::unnamed(db, me, other).unwrap().unwrap();
    assert_eq!(
        said,
        [
            "User: Part 1.",
            "User: Part 2.",
            "User: Part 3.",
            "User: Part 4.",
            "User: Part 5.",
            "AI: Hi."
        ]
    );
    assert!(chats::title::keep(db, me, chat_id, "Greetings").unwrap());
    assert!(!chats::title::keep(db, me, chat_id, "Another").unwrap());
    assert_eq!(chats::title::unnamed(db, me, chat_id).unwrap(), None);
    assert_eq!(
        chats::get(db, me, chat_id).unwrap().unwrap().title,
        "Greetings"
    );
}

#[test]
fn a_chat_with_a_character_is_named_after_its_second_exchange_once() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = common::lore::chat(&scratch, "mira");
    let said = |content: &'static str, role: Role| NewMessage {
        role,
        speaker_id: None,
        content,
        complete: true,
    };
    // Called by its character meanwhile.
    let called = chats::get(db, me, chat_id).unwrap().unwrap().title;
    assert!(!called.is_empty());
    chats::append(db, me, chat_id, &said("We sail at dawn.", Role::User)).unwrap();
    chats::append(db, me, chat_id, &said("Aye.", Role::Assistant)).unwrap();
    // Not after one exchange: the greeting tells too little apart.
    assert_eq!(chats::title::unnamed(db, me, chat_id).unwrap(), None);
    chats::append(db, me, chat_id, &said("Where to?", Role::User)).unwrap();
    chats::append(db, me, chat_id, &said("The reef.", Role::Assistant)).unwrap();
    let asked = chats::title::unnamed(db, me, chat_id).unwrap().unwrap();
    assert_eq!(
        asked[asked.len() - 4..],
        [
            "User: We sail at dawn.",
            "Character: Aye.",
            "User: Where to?",
            "Character: The reef."
        ]
    );
    assert!(asked[0].starts_with("Character: "), "{asked:?}");
    assert!(chats::title::keep(db, me, chat_id, "Sailing to the reef").unwrap());
    // Named once: never again by itself.
    assert_eq!(chats::title::unnamed(db, me, chat_id).unwrap(), None);
    assert!(!chats::title::keep(db, me, chat_id, "Another").unwrap());

    // A chat the user renamed first is not named by the model.
    let other = common::lore::chat(&scratch, "mira");
    chats::rename(db, me, other, "My voyage").unwrap();
    chats::append(db, me, other, &said("Hi.", Role::User)).unwrap();
    chats::append(db, me, other, &said("Hello.", Role::Assistant)).unwrap();
    chats::append(db, me, other, &said("Go.", Role::User)).unwrap();
    chats::append(db, me, other, &said("Going.", Role::Assistant)).unwrap();
    assert_eq!(chats::title::unnamed(db, me, other).unwrap(), None);
    assert_eq!(
        chats::get(db, me, other).unwrap().unwrap().title,
        "My voyage"
    );
}

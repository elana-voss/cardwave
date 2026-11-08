//! The pretend model: a provider built into the server, which a key beginning
//! `sk-cardwave-fake-` connects. Nothing here leaves the test.

use std::time::Instant;

use cw_chat::assistant::{self, ToPick};
use cw_chat::chats;
use cw_chat::companion::{self, CompanionPlan};
use cw_chat::images;
use cw_chat::memory::{self, Block, Helper, Mode, Said};
use cw_library::describe::{self, Outcome};
use cw_prompt::{PromptMessage, Role};
use cw_provider::images::Whom;
use cw_provider::models::{self, Limits};
use cw_provider::{self as provider, Provider, Sampling, facts, list, pretend};
use futures_util::future::BoxFuture;
use serde_json::json;

const KEY: &str = "sk-cardwave-fake-0000";

/// The pretend model as the memory's helper.
struct Asks<'a>(&'a provider::Http, &'a Provider);

impl Helper for Asks<'_> {
    fn ask<'a>(&'a self, prompt: &'a str) -> BoxFuture<'a, anyhow::Result<String>> {
        Box::pin(async move {
            let asked = [PromptMessage::new(Role::User, prompt)];
            let mut reply = provider::ask(self.0, self.1, &asked).await?;
            let mut text = String::new();
            while let Some(piece) = reply.next().await? {
                text.push_str(&piece);
            }
            Ok(text)
        })
    }
}

fn pretend(model: &str) -> Provider {
    Provider {
        base_url: pretend::ADDRESS.into(),
        api_key: KEY.into(),
        model: model.into(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    }
}

#[test]
fn its_key_is_taken_for_the_pretend_models() {
    let listed = list::at(pretend::ADDRESS).expect("the pretend model is on the list");
    assert_eq!(listed.keys, ["sk-cardwave-fake-"]);
    assert!(!listed.local);
}

#[tokio::test]
async fn it_lists_chat_models_and_image_models() {
    let http = provider::client()
        .unwrap()
        .answering(&cardwave_server::pretend::FIXED);
    let listed = models::of(&http, pretend::ADDRESS, KEY, Limits::default())
        .await
        .unwrap();
    let pictures = provider::images::listed(&http, pretend::ADDRESS, KEY)
        .await
        .unwrap();
    let chats: Vec<_> = listed
        .models
        .iter()
        .filter(|id| !facts::by_name(id).image)
        .collect();
    assert!(chats.len() >= 2, "{listed:?}");
    assert!(pictures.models.len() >= 2, "{pictures:?}");
    assert!(pictures.models.iter().all(|id| listed.models.contains(id)));
}

#[tokio::test]
async fn it_answers_a_chat_with_its_reply_streamed() {
    let http = provider::client()
        .unwrap()
        .answering(&cardwave_server::pretend::FIXED);
    let prompt = [PromptMessage::new(Role::User, "Hello there.")];
    let started = Instant::now();
    let mut reply = provider::ask(&http, &pretend("pretend-chat"), &prompt)
        .await
        .unwrap();
    let mut pieces = Vec::new();
    while let Some(piece) = reply.next().await.unwrap() {
        pieces.push((piece, started.elapsed()));
    }
    let text: String = pieces.iter().map(|(piece, _)| piece.as_str()).collect();
    assert_eq!(text, pretend::REPLY);
    // Streamed: the pieces come one after the other, not all at once.
    assert!(pieces.len() > 3);
    assert!(pieces.last().unwrap().1 > pieces[0].1);
}

#[tokio::test]
async fn the_worker_models_questions_get_answers_their_readers_take() {
    let http = provider::client()
        .unwrap()
        .answering(&cardwave_server::pretend::FIXED);
    let worker = pretend("pretend-chat-mini");
    let card = json!({ "title": "Mira", "characters": [{ "name": "Mira" }] });
    match describe::ask(&http, &worker, &card.to_string())
        .await
        .unwrap()
    {
        Outcome::Described { logline, .. } => assert!(!logline.is_empty()),
        Outcome::Refused(why) => panic!("refused: {why}"),
    }
    let to_pick = ToPick {
        modes: vec!["Roleplay".into(), "Assistant".into()],
        current: "Roleplay".into(),
        newest: vec!["User: Hello.".into()],
    };
    assert_eq!(
        assistant::pick(&http, &worker, &to_pick).await.unwrap(),
        None
    );
    for mode in [Mode::Roleplay, Mode::Assistant] {
        let block = Block {
            messages: vec![Said {
                n: 1,
                speaker: "User".into(),
                text: "Hello.".into(),
                day: None,
            }],
            user: "User".into(),
            cast: vec!["Mira".into()],
            mode,
            absent: Vec::new(),
            chat_id: Some(1),
        };
        let added = memory::system()
            .add("", &block, &Asks(&http, &worker))
            .await
            .unwrap();
        assert!(added.saved.is_empty());
        assert!(memory::system().entries(&added.state).unwrap().is_empty());
    }
    let said = ["User: Hello.".to_string(), "AI: Hi.".to_string()];
    let title = chats::title::ask(&http, &worker, &said).await.unwrap();
    assert_eq!(title.as_deref(), Some("A talk with the pretend model"));
    let plan = CompanionPlan {
        chat_id: Some(1),
        width: 1920.0,
        height: 1080.0,
        x: 0.0,
        y: 0.0,
        state: String::new(),
        occasion: companion::Occasion::Reply,
        handled: Vec::new(),
        alone_s: 0,
    };
    let moves = companion::plan(&http, &worker, "Hello.".into(), &plan).await;
    assert!(moves.unwrap().is_empty());
    // The words for a picture: plain words, not the chat's reply.
    let asked = [PromptMessage::new(
        Role::User,
        format!("Character description:\nTall.\n\n{}", images::SCENE),
    )];
    let mut reply = provider::ask(&http, &worker, &asked).await.unwrap();
    let mut words = String::new();
    while let Some(piece) = reply.next().await.unwrap() {
        words.push_str(&piece);
    }
    let words = images::words_of(&words).unwrap();
    assert_eq!(words, cardwave_server::pretend::PICTURE_WORDS);
}

#[tokio::test]
async fn a_chat_that_quotes_a_worker_prompt_gets_the_reply() {
    let http = provider::client()
        .unwrap()
        .answering(&cardwave_server::pretend::FIXED);
    let prompt = [
        PromptMessage::new(Role::System, "You are Mira, keeper of the lighthouse."),
        PromptMessage::new(Role::User, memory::hybrid::OPENING),
    ];
    let mut reply = provider::ask(&http, &pretend("pretend-chat"), &prompt)
        .await
        .unwrap();
    let mut text = String::new();
    while let Some(piece) = reply.next().await.unwrap() {
        text.push_str(&piece);
    }
    assert_eq!(text, pretend::REPLY);
}

#[tokio::test]
async fn it_makes_a_picture() {
    let http = provider::client()
        .unwrap()
        .answering(&cardwave_server::pretend::FIXED);
    let whom = Whom {
        provider: String::new(),
        base_url: pretend::ADDRESS.into(),
        api_key: KEY.into(),
        model: "pretend-image".into(),
        workflow: None,
    };
    let picture = images::make(&http, &whom, "a lighthouse").await.unwrap();
    assert_eq!(picture.mime, "image/png");
}

//! Cardwave's name on the calls to a provider, on a stand-in for its API, by every
//! way a call is sent: chat, the models list, voice, pictures. The stand-in for a
//! provider of `app_name.toml` is set for the whole process
//! (`cw_provider::app_name::stand_in`), which is why this file is a process of its own.

mod common;

use common::api::{Api, Asked, JSON, says};
use cw_chat::images::make_with;
use cw_provider::images::{ImageApi, Whom, listed};
use cw_provider::models::{Limits, described};
use cw_provider::{Provider, Sampling, ask, client};
use cw_voice::at::{read, voices};

/// What a call sends whoever it asks.
const PLAIN: [&str; 5] = [
    "accept",
    "authorization",
    "content-length",
    "content-type",
    "host",
];

/// Asks the API at `api` by every way a call is sent. Only what it was asked counts,
/// so what it answers (404 for most) is not looked at.
async fn every_way(api: &Api) {
    let http = client().unwrap();
    let provider = Provider {
        base_url: api.url.clone(),
        api_key: "a-key".to_string(),
        model: "a-model".to_string(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    };
    let whom = Whom {
        base_url: api.url.clone(),
        api_key: "a-key".to_string(),
        model: "a-model".to_string(),
        provider: String::new(),
        workflow: None,
    };
    let models = format!("{}/models", api.url);
    let no_prompt: [cw_prompt::PromptMessage; 0] = [];
    let _ = ask(&http, &provider, &no_prompt).await;
    let _ = described(&http, &models, "a-key", Limits::default()).await;
    let _ = voices(&http, &provider).await;
    let _ = read(&http, &provider, "Words.", 1.0, None).await;
    let _ = listed(&http, &api.url, "a-key").await;
    let _ = make_with(&http, ImageApi::OpenAi, &whom, "a picture").await;
    let _ = make_with(&http, ImageApi::Automatic1111, &whom, "a picture").await;
    let asked: Vec<String> = api.asked().into_iter().map(|asked| asked.path).collect();
    for path in [
        "/v1/chat/completions",
        "/v1/models",
        "/v1/audio/voices",
        "/v1/audio/speech",
        "/v1/system_stats",
        "/v1/models/checkpoints",
        "/v1/images/generations",
        "/v1/sdapi/v1/txt2img",
    ] {
        assert!(asked.iter().any(|one| one == path), "{path} in {asked:?}");
    }
}

/// A provider's API that passes for a ComfyUI, so that the calls only one is asked are made too.
async fn provider_api() -> Api {
    let comfyui = says(200, JSON, r#"{ "system": {}, "devices": [] }"#);
    Api::start_routed(vec![("/system_stats", comfyui)]).await
}

/// Of each call, the headers beyond what a call sends whoever it asks.
fn beyond_plain(api: &Api) -> Vec<Vec<(String, String)>> {
    let beyond = |asked: Asked| {
        let heard = asked.heard.into_iter();
        heard
            .filter(|(name, _)| !PLAIN.contains(&name.as_str()))
            .collect()
    };
    api.asked().into_iter().map(beyond).collect()
}

#[tokio::test]
async fn a_listed_providers_calls_carry_its_headers_and_nothing_else() {
    let api = provider_api().await;
    cw_provider::app_name::stand_in("OpenRouter", &api.url);
    every_way(&api).await;
    let own = [
        ("http-referer", "https://cardwave.cc"),
        ("x-openrouter-categories", "roleplay"),
        ("x-openrouter-title", "Cardwave"),
    ]
    .map(|(name, value)| (name.to_string(), value.to_string()));
    for mut sent in beyond_plain(&api) {
        sent.sort();
        assert_eq!(sent, own);
    }
}

#[tokio::test]
async fn another_address_is_sent_none_of_them() {
    let api = provider_api().await;
    every_way(&api).await;
    for sent in beyond_plain(&api) {
        assert_eq!(sent, Vec::new());
    }
}

#[tokio::test]
async fn no_call_carries_a_version_number() {
    let api = provider_api().await;
    every_way(&api).await;
    for asked in api.asked() {
        for (name, value) in asked.heard {
            let counted = ["host", "content-length"].contains(&name.as_str());
            let numbered = value.contains(|c: char| c.is_ascii_digit());
            assert!(counted || !numbered, "{name}: {value}");
        }
    }
}

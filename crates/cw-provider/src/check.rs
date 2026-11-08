//! Whether a model answers: one small question, asked the way a chat asks, at
//! the address, with the key and of the model the user is about to set up. So
//! what would fail a chat fails here first, before anything is stored. A list
//! of models that comes proves neither the key nor that the address is an API
//! for chats, as some providers list their models to anyone; a reply does.
//!
//! The question costs what a few tokens cost at a provider that is paid for,
//! so it is asked when the user asks for it, and never by itself.
//!
//! `whom` is the provider a form's values would be, and `model` asks it the
//! `QUESTION` through `provider::ask` and waits for the first words, at most
//! `WAIT`. Over HTTP it is `POST /api/provider/test`, which stores nothing and
//! answers 204 or why not. `sees` asks it with a picture, when one is attached
//! in a chat (`attachments`), and `thinking_off` with each form of turning its
//! thinking off, when the user switches it off (`kinds`). `key` asks, at no
//! cost, whether the provider takes a key it is added or changed with.

use std::time::Duration;

use anyhow::{anyhow, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use serde::Deserialize;
use tokio::time::timeout;
use ts_rs::TS;

use crate::Http;
use crate::Storage;
use crate::kinds::NoThinking;
use crate::{Provider, Sampling};

/// What the model is asked. The answer is a word, so the test is small without
/// a limit on the reply's tokens, which not every model takes under the same
/// name: a model that refuses the limit would fail the test and answer a chat.
const QUESTION: &str = "Reply with the single word OK.";

/// How long the model has for its first word. A model on the user's own
/// machine may have to be loaded before it answers.
pub const WAIT: Duration = Duration::from_secs(60);

/// The model a form asks to be tested.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct TestModel {
    /// The address that stands in the form.
    pub base_url: String,
    /// The model's ID as the provider names it.
    pub model: String,
    /// The key as typed. Left out, the stored key goes along if `base_url` is
    /// the address it was stored with, and none otherwise. Empty, none does.
    pub api_key: Option<String>,
}

/// The provider `asked` would be if it were stored: its address and model as
/// they would be kept, with the key that goes there. Nothing is sent along
/// with the question, so that a value the user set does not decide the test.
pub fn whom(db: &dyn Storage, user: i64, asked: TestModel) -> anyhow::Result<Provider> {
    let (base_url, api_key) = crate::whom(db, user, &asked.base_url, asked.api_key)?;
    Ok(Provider {
        base_url,
        api_key,
        model: crate::model(&asked.model)?,
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    })
}

/// Asks the provider's model the question and waits for the first of its
/// reply, at most `wait`. The rest of the reply is not read: hanging up stops
/// a model that is still writing.
pub async fn model(http: &Http, provider: &Provider, wait: Duration) -> anyhow::Result<()> {
    let prompt = [PromptMessage::new(Role::User, QUESTION)];
    let replied = async {
        let mut reply = crate::ask(http, provider, &prompt).await?;
        while let Some(piece) = reply.next().await? {
            if !piece.trim().is_empty() {
                return Ok(());
            }
        }
        // As for a chat, where a reply without text is a failure.
        bail!(Fail::said(Code::ModelAnswer, "the model sent no text").with("what", "no_text"))
    };
    match timeout(wait, replied).await {
        Ok(replied) => replied.map_err(brief),
        Err(_) => bail!(
            Fail::said(Code::TimedOut, "the model did not answer in time").with("whose", "model")
        ),
    }
}

/// Whether the provider's model sees pictures: the question asked with a
/// small grey picture, which a model that cannot see is refused (400, 404,
/// 415 or 422; the models' facts are not known). The reply is not read: that
/// the request is taken is the answer. Another failure is the error.
pub async fn sees(http: &Http, provider: &Provider) -> anyhow::Result<bool> {
    let mut grey = Vec::new();
    image::RgbImage::from_pixel(8, 8, image::Rgb([128, 128, 128])).write_to(
        &mut std::io::Cursor::new(&mut grey),
        image::ImageFormat::Png,
    )?;
    let picture = format!("data:image/png;base64,{}", STANDARD.encode(&grey));
    let prompt = [PromptMessage {
        pictures: vec![picture],
        ..PromptMessage::new(Role::User, QUESTION)
    }];
    let asked = match timeout(WAIT, crate::ask(http, provider, &prompt)).await {
        Ok(asked) => asked,
        Err(_) => bail!(
            Fail::said(Code::TimedOut, "the model did not answer in time").with("whose", "model")
        ),
    };
    match asked {
        Ok(_) => Ok(true),
        Err(failure) => match crate::refusal_of(&failure) {
            Some((status, _)) if [400, 404, 415, 422].contains(&status) => Ok(false),
            _ => Err(brief(failure)),
        },
    }
}

/// The first form of turning thinking off that the provider takes for its
/// model: the question asked with each in turn, a refusal (400, 404, 415 or
/// 422) leading to the next; none where it takes none. As with `sees`, the
/// reply is not read. Another failure is the error.
pub async fn thinking_off(http: &Http, provider: &Provider) -> anyhow::Result<Option<NoThinking>> {
    let prompt = [PromptMessage::new(Role::User, QUESTION)];
    for form in NoThinking::ALL {
        let asked = Provider {
            thinking_off: Some(form),
            ..provider.clone()
        };
        let answer = match timeout(WAIT, crate::ask(http, &asked, &prompt)).await {
            Ok(answer) => answer,
            Err(_) => bail!(
                Fail::said(Code::TimedOut, "the model did not answer in time")
                    .with("whose", "model")
            ),
        };
        match answer {
            Ok(_) => return Ok(Some(form)),
            Err(failure) => match crate::refusal_of(&failure) {
                Some((status, _)) if [400, 404, 415, 422].contains(&status) => continue,
                _ => return Err(brief(failure)),
            },
        }
    }
    Ok(None)
}

/// Why the question failed, as a form shows it. Of what went wrong on the way
/// to the server that is what was being done and the system's own reason,
/// without the address in between, which the form shows already.
fn brief(failure: anyhow::Error) -> anyhow::Error {
    match failure.downcast_ref::<cw_platform::http::Error>() {
        Some(_) => anyhow!(
            Fail::said(
                Code::Unreachable,
                format!("{failure}: {}", failure.root_cause())
            )
            .with("whose", "model_server")
        ),
        None => failure,
    }
}

/// How long the provider has to say whether it takes a key.
const KEY_WAIT: Duration = Duration::from_secs(15);

/// Whether the provider refuses `key`, asked by one request that costs nothing: the list of models, which most
/// providers give only with a valid key, or, where a provider lists its models to anyone, its own place for
/// the key or the account ([`OWN_PLACES`]). Without a key, or where the answer does not tell (none came,
/// another status), the key is taken: the chat says what is wrong then.
pub async fn key(http: &Http, base_url: &str, key: &str) -> anyhow::Result<()> {
    if key.is_empty() {
        return Ok(());
    }
    let (url, post) = key_place(base_url);
    let ask = if post { http.post(url) } else { http.get(url) };
    let Ok(answer) = crate::send(crate::keyed(ask, key).timeout(KEY_WAIT)).await else {
        return Ok(());
    };
    let status = answer.status().as_u16();
    // Some (xAI, Gemini) refuse a key with 400; its words tell it from another 400.
    let words = match status {
        400 => answer.text().await.unwrap_or_default(),
        _ => String::new(),
    };
    taken(status, &words)
}

/// Where a provider whose list of models comes to anyone tells whether it takes a key, by the host of its
/// API, each from the provider's docs and seen to answer a made-up key with 401 or 403 (2026-11-08), and
/// whether it is asked by POST. NanoGPT's is its balance (POST): its subscription's usage refuses a working
/// key that is not a UUID ("Malformed API key"), the balance took a working key and refused made-up ones.
const OWN_PLACES: &[(&str, &str, bool)] = &[
    ("openrouter.ai", "https://openrouter.ai/api/v1/key", false),
    (
        "nano-gpt.com",
        "https://nano-gpt.com/api/check-balance",
        true,
    ),
    (
        "router.huggingface.co",
        "https://huggingface.co/api/whoami-v2",
        false,
    ),
    (
        "api.venice.ai",
        "https://api.venice.ai/api/v1/api_keys/rate_limits",
        false,
    ),
    (
        "api.poe.com",
        "https://api.poe.com/usage/current_balance",
        false,
    ),
    ("api.novita.ai", "https://api.novita.ai/v3/user", false),
];

/// Where the provider at `base_url` tells whether it takes a key, and whether by POST: its own place, else
/// its list of models.
fn key_place(base_url: &str) -> (String, bool) {
    let base = base_url.trim_end_matches('/');
    let host = cw_platform::http::Url::parse(base)
        .ok()
        .and_then(|url| url.host_str().map(str::to_string));
    OWN_PLACES
        .iter()
        .find(|(at, _, _)| host.as_deref() == Some(*at))
        .map_or_else(
            || (format!("{base}/models"), false),
            |(_, place, post)| ((*place).to_string(), *post),
        )
}

/// The key check's answer: 401 or 403 refuse the key, and a 400 that speaks of the key.
fn taken(status: u16, words: &str) -> anyhow::Result<()> {
    let of_the_key = status == 400 && words.to_lowercase().contains("key");
    if matches!(status, 401 | 403) || of_the_key {
        bail!(Fail::said(Code::NotPossible, "the key was refused").with("what", "key_refused"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_key_is_asked_at_the_models_or_the_providers_own_place_and_refused_only_so() {
        assert_eq!(
            key_place("https://openrouter.ai/api/v1/"),
            ("https://openrouter.ai/api/v1/key".to_string(), false)
        );
        assert_eq!(
            key_place("https://api.x.ai/v1"),
            ("https://api.x.ai/v1/models".to_string(), false)
        );
        // NanoGPT's usage refuses a working key that is not a UUID; its balance takes every key.
        assert_eq!(
            key_place("https://nano-gpt.com/api/v1"),
            ("https://nano-gpt.com/api/check-balance".to_string(), true)
        );
        assert_eq!(
            key_place("https://router.huggingface.co/v1"),
            ("https://huggingface.co/api/whoami-v2".to_string(), false)
        );
        for (status, words) in [(401, ""), (403, ""), (400, "Incorrect API key provided")] {
            let refused = taken(status, words).expect_err("refused");
            let fail = refused.downcast_ref::<Fail>().expect("a Fail");
            assert_eq!(
                fail.details.get("what").map(ToString::to_string).as_deref(),
                Some("key_refused")
            );
        }
        for (status, words) in [
            (200, ""),
            (400, "bad request"),
            (404, ""),
            (429, ""),
            (500, ""),
        ] {
            assert!(taken(status, words).is_ok());
        }
    }
}

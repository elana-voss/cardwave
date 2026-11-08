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
//! thinking off, when the user switches it off (`kinds`).

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

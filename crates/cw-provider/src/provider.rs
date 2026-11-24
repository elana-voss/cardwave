//! The provider a prompt is sent to ([`Provider`]): its server, key, model,
//! the values sent along ([`Sampling`]) and what is known of its model.
//! Built by [`Provider::new`]; a model at another entry by
//! [`Provider::other_model`], which keeps nothing known of the model (its
//! thinking, `steps`). A field added to it gets its default in `new` alone.

use anyhow::{bail, ensure};
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use ts_rs::TS;

use crate::steps::{self, Listed, Thinking};

/// How much of a stored key is told, for the user to know the key by: its
/// last characters, and only of a key so long that they give little of it away.
/// First run shows as much of a key that is typed and not stored yet, by the
/// same two numbers in `web/src/views/setup.ts`.
const KEY_END: usize = 4;
const KEY_END_FROM: usize = 16;

/// What goes along with a prompt. A value left unset is not sent, so the
/// provider's own default applies. These are the parameters the Flutter app
/// sends to an OpenAI-compatible server, with its ranges.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize, TS)]
#[ts(export, optional_fields = nullable)]
pub struct Sampling {
    /// The most tokens sent to any model: the prompt is fitted into the
    /// smaller of it and the model's window, into it alone where the window is
    /// unknown (`Provider::context`).
    pub context_size: Option<usize>,
    pub temperature: Option<f64>,
    pub top_p: Option<f64>,
    pub frequency_penalty: Option<f64>,
    pub presence_penalty: Option<f64>,
    pub seed: Option<i64>,
}

impl Sampling {
    /// What is sent along with a prompt, under the names of OpenAI's API.
    pub(crate) fn sent(&self) -> impl Iterator<Item = (&'static str, Value)> {
        let chosen = [
            ("temperature", self.temperature.map(Value::from)),
            ("top_p", self.top_p.map(Value::from)),
            ("frequency_penalty", self.frequency_penalty.map(Value::from)),
            ("presence_penalty", self.presence_penalty.map(Value::from)),
            ("seed", self.seed.map(Value::from)),
        ];
        chosen
            .into_iter()
            .filter_map(|(name, value)| Some((name, value?)))
    }

    pub(crate) fn check(&self) -> anyhow::Result<()> {
        let within = |name: &str, value: Option<f64>, min: f64, max: f64| {
            ensure!(
                value.is_none_or(|value| (min..=max).contains(&value)),
                Fail::said(
                    Code::OutOfRange,
                    format!("{name} must be from {min} to {max}")
                )
                .with("what", "provider_setting")
                .with("name", name.to_string())
                .with("min", min.to_string())
                .with("max", max.to_string())
            );
            Ok(())
        };
        within("temperature", self.temperature, 0.0, 2.0)?;
        within("top_p", self.top_p, 0.0, 1.0)?;
        within("frequency_penalty", self.frequency_penalty, -2.0, 2.0)?;
        within("presence_penalty", self.presence_penalty, -2.0, 2.0)?;
        ensure!(
            self.context_size.is_none_or(|size| size >= 512),
            Fail::said(
                Code::OutOfRange,
                "the context size must be at least 512 tokens"
            )
            .with("what", "context_size")
        );
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Provider {
    /// Address of the API up to its version part, without a slash at the end:
    /// `https://api.openai.com/v1`.
    pub base_url: String,
    /// Empty for a server that asks for none.
    pub api_key: String,
    pub model: String,
    pub sampling: Sampling,
    /// What the user calls it, for one whose address is not on the list;
    /// empty for none.
    pub name: String,
    /// How its model's thinking stands, as the user set it (`steps`).
    pub thinking: Thinking,
    /// What its provider's list says of its model's thinking.
    pub listed: Listed,
    /// The most tokens of each answer (`limited`); none leaves it to the
    /// provider.
    pub reply_limit: Option<u32>,
    /// Whether an answer of its model carried thinking (`kinds::saw_thinking`).
    pub seen_thinking: bool,
    /// Its model's context window, where known: none until [`window::settled`].
    pub window: Option<usize>,
}

impl Provider {
    /// `model` at `base_url` with `api_key` (empty: none), unnamed, with the
    /// provider's own defaults and nothing known of the model.
    pub fn new(
        base_url: impl Into<String>,
        api_key: impl Into<String>,
        model: impl Into<String>,
    ) -> Provider {
        Provider {
            base_url: base_url.into(),
            api_key: api_key.into(),
            model: model.into(),
            sampling: Sampling::default(),
            name: String::new(),
            thinking: Thinking::On,
            listed: Listed::default(),
            reply_limit: None,
            seen_thinking: false,
            window: None,
        }
    }

    /// `model` at another entry (`base_url`, `api_key`, `name`), with this
    /// provider's values for a reply and nothing known of the model.
    pub fn other_model(
        &self,
        base_url: String,
        api_key: String,
        name: String,
        model: String,
    ) -> Provider {
        Provider {
            sampling: self.sampling.clone(),
            reply_limit: self.reply_limit,
            name,
            ..Provider::new(base_url, api_key, model)
        }
    }

    /// The most tokens its prompt and reply may take: its model's window,
    /// capped by the user's Context size, which stands in where the window is
    /// unknown. Fails where neither is, naming the model.
    pub fn context(&self) -> anyhow::Result<usize> {
        match (self.window, self.sampling.context_size) {
            (Some(window), Some(size)) => Ok(window.min(size)),
            (Some(size), None) | (None, Some(size)) => Ok(size),
            (None, None) => bail!(
                Fail::said(
                    Code::Needed,
                    format!("the context window of “{}” is not known", self.model)
                )
                .with("what", "context_size")
                .with("model", self.model.clone())
            ),
        }
    }

    /// The provider with `length` (a chat's Reply length) as the most tokens
    /// of each of its answers, where its model does not think (`thinks`). A
    /// model that thinks is given none, as its thinking would count against it.
    pub fn limited(self, length: u32) -> Provider {
        Provider {
            reply_limit: (!self.thinks()).then_some(length),
            ..self
        }
    }

    /// Whether its model thinks: its thinking not turned off, and seen
    /// thinking, else so listed by its provider, else known to by its name
    /// (`facts::guessed`). The chat's side panel tells it too.
    pub fn thinks(&self) -> bool {
        !self.thinking.off() && steps::model_thinks(self)
    }

    /// The end of the key, by which the user knows which key it is. A short
    /// key has none to tell, and neither has a provider without a key.
    pub fn key_end(&self) -> Option<String> {
        key_end(&self.api_key)
    }
}

/// The end of `key` that is told, for the image model's key too.
pub fn key_end(key: &str) -> Option<String> {
    let length = key.chars().count();
    (length >= KEY_END_FROM).then(|| key.chars().skip(length - KEY_END).collect())
}

#[cfg(test)]
mod tests {
    use super::{Provider, Sampling};
    use crate::steps::{NoThinking, Step, Thinking};

    fn of(model: &str, thinking: Thinking) -> Provider {
        Provider {
            thinking,
            ..Provider::new("http://localhost:8080/v1", "", model)
        }
    }

    #[test]
    fn a_reply_is_limited_where_the_model_does_not_think() {
        assert_eq!(
            of("my-rig-7b", Thinking::On).limited(350).reply_limit,
            Some(350)
        );
        // Its name says nothing, but an answer of it carried thinking.
        let seen = Provider {
            seen_thinking: true,
            ..of("my-rig-7b", Thinking::On)
        };
        assert_eq!(seen.limited(350).reply_limit, None);
        // models.dev says gpt-5 thinks, unless its thinking was turned off.
        assert_eq!(of("gpt-5", Thinking::On).limited(350).reply_limit, None);
        let off = Thinking::OffBy(NoThinking::ReasoningEffort);
        assert_eq!(of("gpt-5", off).limited(350).reply_limit, Some(350));
        let off = Thinking::Step(Step::Off);
        assert_eq!(of("gpt-5", off).limited(350).reply_limit, Some(350));
        let deep = Thinking::Step(Step::Deep);
        assert_eq!(of("gpt-5", deep).limited(350).reply_limit, None);
    }

    /// What is known of the chat model, and what was seen of it.
    fn known() -> Provider {
        Provider {
            sampling: Sampling {
                temperature: Some(0.7),
                ..Sampling::default()
            },
            name: "My rig".into(),
            thinking: Thinking::Step(Step::Light),
            reply_limit: Some(350),
            seen_thinking: true,
            window: Some(32_768),
            ..Provider::new("http://rig:8080/v1", "sk-rig", "big-1")
        }
    }

    #[test]
    fn another_model_keeps_the_values_but_not_what_was_known_of_the_model() {
        let chat = known();
        // At another entry nothing of the model is kept, even by its name.
        let elsewhere = chat.other_model(
            "http://far/v1".into(),
            "sk-far".into(),
            "Far".into(),
            "big-1".into(),
        );
        assert_eq!(
            (
                elsewhere.thinking,
                elsewhere.seen_thinking,
                elsewhere.window
            ),
            (Thinking::On, false, None)
        );
        assert_eq!(
            (elsewhere.base_url.as_str(), elsewhere.name.as_str()),
            ("http://far/v1", "Far")
        );
        assert_eq!(
            (&elsewhere.sampling, elsewhere.reply_limit),
            (&chat.sampling, Some(350))
        );
    }
}

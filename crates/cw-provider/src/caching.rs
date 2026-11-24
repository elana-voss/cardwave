//! Prompt caching for Claude models: Anthropic caches a prompt's start only
//! where the request marks it (`cache_control`), which OpenRouter and NanoGPT
//! pass on (`own.toml`'s `own_api`); OpenAI, DeepSeek and Gemini cache by
//! themselves, and Anthropic's own OpenAI form takes no mark. [`marks`] tells
//! whether a request is marked, [`mark`] puts the marks on its messages where
//! the prompt's builder says its steady start ends (`BuiltPrompt::cache_at`).
//! A cache lasts 5 minutes from its last use (the owner's choice over 1 hour).
//! Trap: NanoGPT bills a marked request outside a subscription, so a NanoGPT
//! key is marked only once its usage says no subscription is active; that
//! answer is kept a while per key ([`Subscriptions`]), not asked at each reply.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use serde_json::{Value, json};

use crate::list::{self, OwnApi};
use crate::{Http, Provider, subscription};

/// How long a key's subscription, as read, is believed.
const BELIEVED: Duration = Duration::from_secs(60 * 60);
/// How long a read that failed is believed: a dead endpoint costs no wait at
/// each reply, and a key is not left unmarked long.
const UNREAD: Duration = Duration::from_secs(60);

/// Whether the request of `provider` carries cache marks: to a Claude model
/// through OpenRouter, or through NanoGPT for a key without an active
/// subscription; never where that could not be read.
pub async fn marks(http: &Http, provider: &Provider) -> bool {
    if !is_claude(&provider.model) {
        return false;
    }
    match list::own_api(&provider.base_url) {
        Some(OwnApi::OpenRouter) => true,
        Some(OwnApi::NanoGpt) => {
            let subscribed = http.subscriptions.active(http, provider).await;
            subscribed == Some(false)
        }
        None => false,
    }
}

/// Whether a model is Anthropic's Claude by its id, as the routes name it
/// (`anthropic/claude-sonnet-4.5`, `claude-opus-4-1-20250805:thinking`).
fn is_claude(model: &str) -> bool {
    model.to_lowercase().contains("claude")
}

/// Marks the message at each of `at` in `messages` (a request's, as JSON):
/// its content becomes a list of parts, as a message with pictures has, and
/// its last text part carries the mark. A message without text stays as it
/// is: Anthropic refuses an empty text part.
pub(crate) fn mark(messages: &mut Value, at: &[usize]) {
    for &index in at {
        let Some(message) = messages.get_mut(index) else {
            continue;
        };
        let content = &mut message["content"];
        if let Some(text) = content.as_str().filter(|text| !text.is_empty()) {
            *content = json!([{ "type": "text", "text": text }]);
        }
        let text_part = content.as_array_mut().and_then(|parts| {
            parts
                .iter_mut()
                .rev()
                .find(|part| part["type"] == "text" && part["text"].as_str() != Some(""))
        });
        if let Some(part) = text_part {
            part["cache_control"] = json!({ "type": "ephemeral" });
        }
    }
}

/// How long a key's subscription read as `active` is believed.
fn believed(active: Option<bool>) -> Duration {
    match active {
        Some(_) => BELIEVED,
        None => UNREAD,
    }
}

/// Each key's subscription as read (`subscription::active`), with when.
type Read = HashMap<String, (Instant, Option<bool>)>;

/// The NanoGPT subscriptions read, by key, shared by every clone of the client.
#[derive(Clone, Default)]
pub(crate) struct Subscriptions(Arc<Mutex<Read>>);

impl Subscriptions {
    /// Whether `provider`'s key has an active subscription, as last read
    /// within [`believed`]; read anew past it.
    async fn active(&self, http: &Http, provider: &Provider) -> Option<bool> {
        let key = &provider.api_key;
        if let Some((read, active)) = self.lock().get(key)
            && read.elapsed() < believed(*active)
        {
            return *active;
        }
        let active = subscription::active(http, &provider.base_url, key).await;
        self.lock().insert(key.clone(), (Instant::now(), active));
        active
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Read> {
        // A thread that panicked holding it left a whole map: each entry is written at once.
        self.0
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_claude_model_is_told_by_its_id_in_each_route_s_form() {
        for model in [
            "anthropic/claude-sonnet-4.5",
            "anthropic/claude-3.7-sonnet:thinking",
            "claude-opus-4-1-20250805",
            "claude-sonnet-latest",
        ] {
            assert!(is_claude(model), "{model}");
        }
        assert!(!is_claude("openai/gpt-5"));
        assert!(!is_claude("deepseek/deepseek-chat"));
    }

    #[test]
    fn a_marked_message_s_last_text_part_carries_the_mark() {
        let mut messages = json!([
            { "role": "system", "content": "Be kind." },
            { "role": "user", "content": [
                { "type": "text", "text": "Look." },
                { "type": "image_url", "image_url": { "url": "data:image/png;base64,AA==" } }
            ] },
            { "role": "assistant", "content": "", "tool_calls": [] },
            { "role": "user", "content": "Bye" }
        ]);
        mark(&mut messages, &[0, 1, 2, 9]);
        let ephemeral = json!({ "type": "ephemeral" });
        assert_eq!(
            messages[0]["content"],
            json!([{ "type": "text", "text": "Be kind.", "cache_control": ephemeral }])
        );
        assert_eq!(messages[1]["content"][0]["cache_control"], ephemeral);
        assert!(messages[1]["content"][1]["cache_control"].is_null());
        // No text: unmarked, as it was; an index past the end is no message.
        assert_eq!(messages[2]["content"], "");
        assert_eq!(messages[3]["content"], "Bye");
    }

    /// A key's subscription as read is believed an hour; a read that failed
    /// only a minute, so the next reply asks again.
    #[test]
    fn a_failed_read_is_believed_only_a_minute() {
        assert_eq!(believed(Some(false)), Duration::from_secs(60 * 60));
        assert_eq!(believed(Some(true)), Duration::from_secs(60 * 60));
        assert_eq!(believed(None), Duration::from_secs(60));
    }
}

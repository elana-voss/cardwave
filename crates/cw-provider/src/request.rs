//! The body of a request for a reply ([`body`]): a pure function of the
//! provider, the prompt and what else is asked ([`Request`]), so a test builds
//! it for any address; it carries the model's step of thinking (`steps::sent`). A request given cache marks (which its caller gives
//! only where `caching::marks` says the provider takes them) carries them
//! where the prompt's steady start ends, and through NanoGPT asks for the
//! tokens used on a stream, which it sends only when asked; a request without
//! is the same, byte for byte, as before marks were.

use serde_json::{Value, json};

use crate::list::{self, OwnApi};
use crate::{Provider, caching, host, steps};

/// What a request asks besides the provider and the prompt.
#[derive(Clone, Copy, Default)]
pub struct Request<'a> {
    /// The tools the model may call.
    pub tools: &'a [Value],
    /// The tools are listed and not to be called (`tool_choice: "none"`): a
    /// marked request's last round, whose cached start holds the tools.
    pub tools_off: bool,
    /// The `response_format` to answer in, where there is one.
    pub shape: Option<&'a Value>,
    /// The messages marked as ending the prompt's steady start
    /// (`BuiltPrompt::cache_at`); none where the provider takes no marks
    /// (`caching::marks`), which its caller asks once per reply.
    pub marks: &'a [usize],
}

/// The JSON body sent for `prompt` (its messages as JSON), streamed.
pub(crate) fn body(provider: &Provider, mut prompt: Value, request: &Request) -> Value {
    let marked = !request.marks.is_empty();
    caching::mark(&mut prompt, request.marks);
    let mut body = json!({ "model": provider.model, "messages": prompt, "stream": true });
    if !request.tools.is_empty() {
        body["tools"] = json!(request.tools);
        if request.tools_off {
            body["tool_choice"] = json!("none");
        }
    }
    if let Some(shape) = request.shape {
        body["response_format"] = shape.clone();
    }
    for (name, value) in provider.sampling.sent() {
        body[name] = value;
    }
    for (name, value) in steps::sent(provider) {
        body[name] = value;
    }
    if let Some(limit) = provider.reply_limit {
        body[limit_field(&provider.base_url)] = limit.into();
    }
    if marked && list::own_api(&provider.base_url) == Some(OwnApi::NanoGpt) {
        body["stream_options"] = json!({ "include_usage": true });
    }
    body
}

/// The field a reply's limit is sent in: OpenAI's own API and Azure's take
/// only `max_completion_tokens` for their newer models, every other `max_tokens`.
fn limit_field(base_url: &str) -> &'static str {
    match host(base_url).map(|(host, _)| host) {
        Some(host) if host == "api.openai.com" || host.ends_with(".openai.azure.com") => {
            "max_completion_tokens"
        }
        _ => "max_tokens",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn provider(base_url: &str, model: &str) -> Provider {
        Provider::new(base_url, "", model)
    }

    fn prompt() -> Value {
        json!([
            { "role": "system", "content": "Be kind." },
            { "role": "user", "content": "Hi" },
            { "role": "assistant", "content": "Hello" },
            { "role": "user", "content": "Bye" }
        ])
    }

    const MARKS: Request = Request {
        tools: &[],
        tools_off: false,
        shape: None,
        marks: &[0, 2],
    };

    #[test]
    fn a_marked_request_carries_the_mark_where_the_steady_start_ends() {
        let ephemeral = json!({ "type": "ephemeral" });
        for base_url in [
            "https://openrouter.ai/api/v1",
            "https://nano-gpt.com/api/v1",
        ] {
            let claude = provider(base_url, "anthropic/claude-sonnet-4.5");
            let body = body(&claude, prompt(), &MARKS);
            let messages = &body["messages"];
            assert_eq!(
                messages[0]["content"][0]["cache_control"], ephemeral,
                "{base_url}"
            );
            assert_eq!(messages[2]["content"][0]["text"], "Hello");
            assert_eq!(messages[2]["content"][0]["cache_control"], ephemeral);
            assert_eq!(messages[1]["content"], "Hi");
            assert_eq!(messages[3]["content"], "Bye");
        }
        let nano = provider("https://nano-gpt.com/api/v1", "claude-sonnet-4-5-20250929");
        let usage = &body(&nano, prompt(), &MARKS)["stream_options"];
        assert_eq!(usage, &json!({ "include_usage": true }));
        let router = provider(
            "https://openrouter.ai/api/v1",
            "anthropic/claude-sonnet-4.5",
        );
        assert!(body(&router, prompt(), &MARKS)["stream_options"].is_null());
    }

    #[test]
    fn an_unmarked_request_is_the_same_byte_for_byte() {
        let tools = [json!({ "type": "function", "function": { "name": "roll" } })];
        let unmarked = Request {
            tools: &tools,
            ..Request::default()
        };
        // A NanoGPT subscriber's request, and any other provider's, carry no marks
        // (a model that does not think, which would carry its step of thinking).
        for (base_url, model) in [
            ("https://nano-gpt.com/api/v1", "claude-sonnet-4-5-20250929"),
            ("https://api.openai.com/v1", "gpt-4o"),
        ] {
            let provider = provider(base_url, model);
            let sent = serde_json::to_vec(&body(&provider, prompt(), &unmarked)).unwrap();
            let before =
                json!({ "model": model, "messages": prompt(), "stream": true, "tools": tools });
            assert_eq!(sent, serde_json::to_vec(&before).unwrap(), "{base_url}");
        }
    }

    #[test]
    fn a_last_round_keeps_its_tools_not_to_be_called() {
        let tools = [json!({ "type": "function", "function": { "name": "roll" } })];
        let last = Request {
            tools: &tools,
            tools_off: true,
            ..MARKS
        };
        let claude = provider(
            "https://openrouter.ai/api/v1",
            "anthropic/claude-sonnet-4.5",
        );
        let body = body(&claude, prompt(), &last);
        assert_eq!(body["tools"], json!(tools));
        assert_eq!(body["tool_choice"], "none");
    }

    #[test]
    fn a_request_carries_its_models_step_of_thinking() {
        let mut deep = provider("https://api.deepseek.com/v1", "deepseek-chat");
        deep.listed.thinks = Some(true);
        deep.thinking = steps::Thinking::Step(steps::Step::Deep);
        let body = body(&deep, prompt(), &Request::default());
        assert_eq!(body["reasoning_effort"], "max");
    }

    #[test]
    fn openai_is_sent_its_own_field_for_the_limit() {
        assert_eq!(
            limit_field("https://api.openai.com/v1"),
            "max_completion_tokens"
        );
        let azure = "https://mine.openai.azure.com/openai/v1";
        assert_eq!(limit_field(azure), "max_completion_tokens");
        assert_eq!(limit_field("https://openrouter.ai/api/v1"), "max_tokens");
    }
}

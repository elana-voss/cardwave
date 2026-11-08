//! A reply on its way from the model, read piece by piece: its words, its
//! thinking, the tools it calls and how it ended ([`Ending`]), whether streamed
//! or sent as one document.

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Fail};
use cw_platform::http::Response;
use serde_json::{Value, json};

use crate::{REPLY_LIMIT, error_code, reason, thinking};

/// A reply on its way from the model.
pub struct Reply {
    response: Response,
    /// Whether the reply comes as a stream of events (server-sent events), not
    /// as one JSON document.
    streamed: bool,
    /// What has arrived and is not read yet: of a stream, the line the server
    /// is still sending.
    unread: Vec<u8>,
    /// Bytes of text handed out so far.
    length: usize,
    done: bool,
    /// What went wrong after text that had yet to be handed out.
    failed: Option<anyhow::Error>,
    /// The tools the model calls, as far as they have come.
    calls: Vec<Call>,
    /// Tells a `<think>` part of the text apart from the reply.
    splitter: thinking::Splitter,
    ending: Ending,
}

/// How a reply ended, by what its provider said of it, as far as it has come.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Ending {
    /// It stopped at the limit on its length.
    pub cut_off: bool,
    /// The model declined to answer, in these words where it gave any.
    pub declined: Option<String>,
}

impl Ending {
    /// Reads what one choice says: a `refusal` (OpenAI's) and a finish reason,
    /// the route's own and, through OpenRouter, the model's (Anthropic's
    /// `refusal`, Gemini's safety blocks).
    fn read(&mut self, choice: &Value) {
        for part in [&choice["delta"], &choice["message"]] {
            if let Some(words) = part["refusal"].as_str().filter(|words| !words.is_empty()) {
                self.declined.get_or_insert_default().push_str(words);
            }
        }
        for reason in [&choice["finish_reason"], &choice["native_finish_reason"]] {
            let reason = reason.as_str().unwrap_or_default().to_lowercase();
            match reason.as_str() {
                "length" | "max_tokens" => self.cut_off = true,
                "content_filter" | "refusal" | "safety" | "prohibited_content" | "blocklist"
                | "spii" => {
                    self.declined.get_or_insert_default();
                }
                _ => {}
            }
        }
    }
}

/// What has come of a reply: words of the reply, the model's thinking, or both.
#[derive(Debug, Default)]
pub struct Piece {
    pub words: String,
    pub thinking: String,
}

impl Reply {
    /// The reply `response` brings; `streamed` as its server said.
    pub(crate) fn of(response: Response, streamed: bool) -> Self {
        Self {
            response,
            streamed,
            unread: Vec::new(),
            length: 0,
            done: false,
            failed: None,
            calls: Vec::new(),
            splitter: thinking::Splitter::default(),
            ending: Ending::default(),
        }
    }

    /// How the reply ended, once it is complete.
    pub fn ending(&self) -> &Ending {
        &self.ending
    }

    /// The tools the model called, once the reply is complete. A call some
    /// servers send without an ID is given one.
    pub fn calls(&mut self) -> Vec<Call> {
        let mut calls = std::mem::take(&mut self.calls);
        calls.retain(|call| !call.name.is_empty());
        for (at, call) in calls.iter_mut().enumerate() {
            if call.id.is_empty() {
                call.id = format!("call_{at}");
            }
        }
        calls
    }

    /// The next piece of the reply's words, or `None` when the reply is
    /// complete; the model's thinking is passed over.
    pub async fn next(&mut self) -> anyhow::Result<Option<String>> {
        loop {
            match self.next_piece().await? {
                Some(piece) if piece.words.is_empty() => {}
                piece => return Ok(piece.map(|piece| piece.words)),
            }
        }
    }

    /// The next piece of the reply, words or thinking, or `None` when the reply
    /// is complete. Giving up the wait loses nothing; dropping the reply hangs
    /// up on the server, which stops a model that is still writing.
    pub async fn next_piece(&mut self) -> anyhow::Result<Option<Piece>> {
        if let Some(failure) = self.failed.take() {
            return Err(failure);
        }
        loop {
            let (mut text, mut piece) = (String::new(), Piece::default());
            let read = self.read_arrived(&mut text, &mut piece.thinking);
            // What comes after `[DONE]` is no part of the reply.
            let end = self.done;
            self.splitter
                .take(&text, end, &mut piece.thinking, &mut piece.words);
            if let Err(failure) = read {
                if piece.words.is_empty() && piece.thinking.is_empty() {
                    return Err(failure);
                }
                self.failed = Some(failure);
            }
            if !piece.words.is_empty() || !piece.thinking.is_empty() {
                self.length += piece.words.len() + piece.thinking.len();
                ensure!(
                    self.length <= REPLY_LIMIT,
                    Fail::said(
                        Code::TooBig,
                        format!("the reply was cut off at {} MB", REPLY_LIMIT >> 20)
                    )
                    .with("what", "reply")
                );
                return Ok(Some(piece));
            }
            if end {
                return Ok(None);
            }
            match self.response.chunk().await.context(
                Fail::said(Code::ModelAnswer, "the reply broke off")
                    .with("what", "reply_broke_off"),
            )? {
                Some(more) => {
                    ensure!(
                        self.unread.len() + more.len() <= REPLY_LIMIT,
                        Fail::said(Code::ModelAnswer, "the model's server sent no chat reply")
                            .with("what", "no_chat_reply")
                    );
                    self.unread.extend_from_slice(&more);
                }
                // The server hung up, perhaps without saying it was done. Its
                // last line may lack a line end.
                None => {
                    self.unread.push(b'\n');
                    self.done = true;
                }
            }
        }
    }

    /// Takes the text and the thinking out of what has arrived.
    fn read_arrived(&mut self, text: &mut String, thinking: &mut String) -> anyhow::Result<()> {
        if !self.streamed {
            // The one document is whole when the server has hung up.
            if self.done && !self.unread.is_empty() {
                let answer = serde_json::from_slice(&std::mem::take(&mut self.unread));
                read_event(
                    &answer.context(
                        Fail::said(Code::ModelAnswer, "the model's server sent no chat reply")
                            .with("what", "no_chat_reply"),
                    )?,
                    (text, thinking),
                    &mut self.calls,
                    &mut self.ending,
                )?;
            }
            return Ok(());
        }
        // Lines are cut at the byte level, so a character that arrives in two
        // parts is whole again before it is read as text.
        while let Some(end) = self.unread.iter().position(|&byte| byte == b'\n') {
            let line: Vec<u8> = self.unread.drain(..=end).collect();
            // Only `data:` lines carry anything; the rest are comments and keep-alives.
            let line = String::from_utf8_lossy(&line);
            let Some(data) = line.trim().strip_prefix("data:").map(str::trim_start) else {
                continue;
            };
            if data == "[DONE]" {
                self.done = true;
            } else if let Ok(event) = serde_json::from_str(data) {
                read_event(
                    &event,
                    (&mut *text, &mut *thinking),
                    &mut self.calls,
                    &mut self.ending,
                )?;
            }
        }
        Ok(())
    }
}

/// Takes the text and the thinking out of one answer of the API: a piece of a
/// streamed reply, or a reply that came whole; and the tools it calls, which a
/// stream sends in pieces, by their place in the list, the first piece of each
/// with its ID. Thinking comes as `reasoning_content` (DeepSeek, llama.cpp,
/// vLLM) or `reasoning` (OpenRouter, Ollama). How it ends goes into `ending`.
fn read_event(
    event: &Value,
    (text, thinking): (&mut String, &mut String),
    calls: &mut Vec<Call>,
    ending: &mut Ending,
) -> anyhow::Result<()> {
    if !event["error"].is_null() {
        let reason = reason(event);
        let reported = Fail::said(
            Code::ModelAnswer,
            format!("the model's server reported: {reason}"),
        )
        .with("what", "server_reported")
        .with("reason", reason);
        bail!(match error_code(event) {
            Some(code) => reported.with("code", code),
            None => reported,
        });
    }
    let choice = &event["choices"][0];
    ending.read(choice);
    if let Some(piece) = choice["delta"]["content"]
        .as_str()
        .or(choice["message"]["content"].as_str())
    {
        text.push_str(piece);
    }
    for part in [&choice["delta"], &choice["message"]] {
        if let Some(thought) = part["reasoning_content"]
            .as_str()
            .or(part["reasoning"].as_str())
        {
            thinking.push_str(thought);
        }
    }
    let called = choice["delta"]["tool_calls"]
        .as_array()
        .or(choice["message"]["tool_calls"].as_array());
    for piece in called.into_iter().flatten() {
        // Without its place, a piece with an ID of its own begins a call, and
        // any other goes on with the last.
        let id = piece["id"].as_str().filter(|id| !id.is_empty());
        let place = match piece["index"].as_u64() {
            Some(index) => index as usize,
            None if id.is_some_and(|id| calls.last().is_none_or(|last| last.id != id)) => {
                calls.len()
            }
            None => calls.len().saturating_sub(1),
        };
        ensure!(
            place < 64,
            Fail::said(Code::ModelAnswer, "the model called too many tools")
                .with("what", "too_many_tools")
        );
        if calls.len() <= place {
            calls.resize_with(place + 1, Call::default);
        }
        let call = &mut calls[place];
        if let Some(id) = id {
            call.id = id.to_string();
        }
        let function = &piece["function"];
        if let Some(name) = function["name"].as_str().filter(|name| !name.is_empty()) {
            call.name = name.to_string();
        }
        if let Some(arguments) = function["arguments"].as_str() {
            call.arguments.push_str(arguments);
        }
    }
    Ok(())
}

/// A call of a tool, as the model sent it.
#[derive(Clone, Debug, Default)]
pub struct Call {
    pub id: String,
    pub name: String,
    /// Its arguments, a JSON object as text.
    pub arguments: String,
}

impl Call {
    /// The call as the model's message names it in the prompt.
    pub fn sent(&self) -> Value {
        json!({
            "id": self.id,
            "type": "function",
            "function": { "name": self.name, "arguments": self.arguments },
        })
    }

    pub fn argument(&self, name: &str) -> String {
        let arguments: Value = serde_json::from_str(&self.arguments).unwrap_or_default();
        arguments[name].as_str().unwrap_or_default().to_string()
    }
}

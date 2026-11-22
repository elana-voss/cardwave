//! The rounds of a reply: the model asked (`ask_round`), its words taken in
//! `stream`, the tools it calls run (`run_calls`, a written tool's script in
//! `run_script`, a call the user allows first in `ask_user`), up to `ROUNDS`.
//! The tools' note stands in the prompt where `assemble` put it until a round
//! offers no tools: told of tools it may not call, a model writes the call as
//! words. A server that refuses tools is asked again without, and the model
//! kept in `AppState::toolless` once that answer came.

use std::pin::Pin;

use anyhow::ensure;
use cw_chat::chats;
use cw_coding::tools::used::CallEnd;
use cw_coding::tools::{Done, REFUSED, ToolAsk, Toolbox, WrittenRun, chat};
use cw_core::{Code, Fail};
use cw_prompt::PromptMessage;
use cw_provider::Call;
use cw_provider::images::Picture;
use cw_provider::{self as provider, Provider};
use serde_json::{Value, json};
use tokio::sync::futures::Notified;
use tokio::sync::oneshot;

use super::super::ReplyEvent;
use super::stream::{Pushed, take_words};
use super::{Asking, Job, Writer};

/// The most rounds of tool calls a reply makes; the round after them is
/// offered no tools.
const ROUNDS: usize = 8;

/// Reads the model's reply to `messages` into `content`, after what it holds,
/// saving and pushing it as it grows, until it is complete or stopped; the
/// tools it calls are run between, and the pictures they make put in `made`.
/// Each round's words begin at their first, joined to the text before by
/// `stream::joint`. After an error `content` holds the reply as far as it got.
/// `pushed` tells after whether the model thought.
pub(super) async fn read_reply(
    writer: &Writer,
    job: &Job,
    messages: Vec<PromptMessage>,
    (pushed, content, made): (&mut Pushed, &mut String, &mut Vec<(String, Picture)>),
) -> anyhow::Result<()> {
    let message_id = job.message_id;
    let stopped = writer.stop.notified();
    tokio::pin!(stopped);
    let mut messages: Vec<Value> = messages.iter().map(|message| json!(message)).collect();
    let mut note = job.tools_at;
    // Refused now, the model is kept toolless once it answered without.
    let (mut refused, mut learned) = (job.toolless, false);
    let base = content.len();
    let unlimited = Provider {
        reply_limit: None,
        ..job.provider.clone()
    };
    for round in 0..=ROUNDS {
        let (mut reply, offered) = loop {
            let offered = match &job.toolbox {
                Some(toolbox) if round < ROUNDS && !refused => toolbox.definitions(),
                _ => Vec::new(),
            };
            // What follows the note was only ever added after, so its place holds until then.
            if offered.is_empty()
                && let Some(at) = note.take()
            {
                messages.remove(at);
            }
            let providers = (&job.provider, &unlimited);
            match ask_round(writer, providers, &messages, &offered, stopped.as_mut()).await? {
                Asked::Stopped => return Ok(()),
                Asked::Refused => (refused, learned) = (true, true),
                Asked::Reply(reply) => break (*reply, offered),
            }
        };
        if std::mem::take(&mut learned) {
            let whose = (job.provider.base_url.clone(), job.provider.model.clone());
            writer.state.toolless().insert(whose);
        }
        let begun = content.len();
        let words = (message_id, &mut *pushed, &mut *content);
        let from = (&mut reply, &job.others[..]);
        if !take_words(writer, words, from, stopped.as_mut()).await? {
            return Ok(());
        }
        let calls = reply.calls();
        // Read, it lets go of its model, which a tool may need to swap (`provider::local`).
        drop(reply);
        let toolbox = match &job.toolbox {
            Some(toolbox) if !calls.is_empty() && !offered.is_empty() => toolbox,
            // Not to be taken for a reply that was stopped before its first word.
            _ => {
                ensure!(
                    content.len() > base || !made.is_empty(),
                    Fail::new(Code::NoText)
                );
                return Ok(());
            }
        };
        // The pages have all the words before a call waits or runs.
        if pushed.saved < content.len() {
            pushed.flush(writer, message_id, content).await?;
        }
        let sent: Vec<Value> = calls.iter().map(|call| call.sent()).collect();
        messages
            .push(json!({ "role": "assistant", "content": &content[begun..], "tool_calls": sent }));
        let ran = (&mut messages, &mut *made);
        if !run_calls(writer, (message_id, toolbox), &calls, stopped.as_mut(), ran).await? {
            return Ok(());
        }
    }
    unreachable!("the last round is offered no tools")
}

/// How a round's request went.
enum Asked {
    /// Boxed: a reply is much larger than the other two.
    Reply(Box<provider::Reply>),
    /// The reply was stopped first.
    Stopped,
    /// The server refused the tools offered: the round is asked again without.
    Refused,
}

/// Asks the model for a round of the reply, offered the tools in `offered`,
/// of `provider`, or of `unlimited` where a call's arguments, a file's whole
/// text among them, are not to be cut short.
async fn ask_round(
    writer: &Writer,
    (provider, unlimited): (&Provider, &Provider),
    messages: &[Value],
    offered: &[Value],
    stopped: Pin<&mut Notified<'_>>,
) -> anyhow::Result<Asked> {
    let limited = match chat::cuts(offered) {
        true => unlimited,
        false => provider,
    };
    let asked = tokio::select! {
        biased;
        _ = stopped => return Ok(Asked::Stopped),
        reply = provider::ask_with(&writer.state.http, limited, messages, offered) => reply,
    };
    match asked {
        Err(failure) if !offered.is_empty() && refuses_tools(&failure) => Ok(Asked::Refused),
        asked => Ok(Asked::Reply(Box::new(asked?))),
    }
}

/// Runs a round's tool calls in turn, each answer put after them in `prompt`
/// and the pictures they make in `made`: false when the reply is stopped first.
async fn run_calls(
    writer: &Writer,
    (message_id, toolbox): (i64, &Toolbox),
    calls: &[Call],
    mut stopped: Pin<&mut Notified<'_>>,
    (prompt, made): (&mut Vec<Value>, &mut Vec<(String, Picture)>),
) -> anyhow::Result<bool> {
    for call in calls {
        let ran = match toolbox.start_written(&writer.state.actions(), call) {
            Some(running) => {
                let script = (message_id, toolbox, running);
                run_script(writer, script, stopped.as_mut(), made).await
            }
            None => called(writer, (message_id, toolbox, call), stopped.as_mut()).await,
        };
        // Only here: what a written tool calls inside it is not listed.
        let (end, shown) = match &ran {
            Ok(Some(done)) => (done.end, done.shown.clone()),
            Ok(None) => (CallEnd::Stopped, None),
            Err(_) => (CallEnd::Failed, None),
        };
        toolbox.keep_call(call, end, shown);
        let Some(done) = ran? else {
            return Ok(false);
        };
        made.extend(done.picture);
        let text = done.text;
        prompt.push(json!({ "role": "tool", "tool_call_id": call.id, "content": text }));
    }
    Ok(true)
}

/// Runs a tool the model wrote (`running`), answering its script's calls of
/// the host's tools until it ends; the pictures they make go into `made`.
/// `None` when the reply is stopped first.
async fn run_script(
    writer: &Writer,
    (message_id, toolbox, mut running): (i64, &Toolbox, WrittenRun),
    mut stopped: Pin<&mut Notified<'_>>,
    made: &mut Vec<(String, Picture)>,
) -> anyhow::Result<Option<Done>> {
    let mut open = true;
    let ended = loop {
        let next = tokio::select! {
            biased;
            _ = &mut stopped => return Ok(None),
            request = running.calls.recv(), if open => Ok(request),
            ended = &mut running.done => Err(ended),
        };
        match next {
            Ok(Some(request)) => {
                let reading = (message_id, toolbox, &request.call);
                let Some(mut done) = called(writer, reading, stopped.as_mut()).await? else {
                    return Ok(None);
                };
                made.extend(done.picture.take());
                // Its receiver gone, nobody waits for the answer.
                let _ = request.answer.send(done.result());
            }
            Ok(None) => open = false,
            Err(ended) => break ended,
        }
    };
    let ran = ended.map_err(anyhow::Error::from).and_then(|ran| ran);
    Ok(Some(Done {
        end: match ran {
            Ok(_) => CallEnd::Done,
            Err(_) => CallEnd::Failed,
        },
        text: ran.unwrap_or_else(|failure| format!("Failed: {failure:#}")),
        picture: None,
        shown: None,
    }))
}

/// Runs a tool's call (of the reply's message, in its toolbox), asking the
/// user first where the settings say so and the chat does not allow it
/// already (the owner, 2026-10-15): `None` when the reply is stopped first.
async fn called(
    writer: &Writer,
    (message_id, toolbox, call): (i64, &Toolbox, &Call),
    mut stopped: Pin<&mut Notified<'_>>,
) -> anyhow::Result<Option<Done>> {
    let (state, user, chat_id) = (&writer.state, writer.user, writer.chat_id);
    if let Some(ask) = toolbox.asks(call).await
        && !state
            .work(move |db| chats::tool_allowed(db, user, chat_id, ask.kind))
            .await?
    {
        match ask_user(writer, message_id, ask, stopped.as_mut()).await {
            Some(true) => {}
            Some(false) => {
                return Ok(Some(Done {
                    text: REFUSED.to_string(),
                    picture: None,
                    end: CallEnd::NotAllowed,
                    shown: None,
                }));
            }
            None => return Ok(None),
        }
    }
    let app = state.actions();
    Ok(tokio::select! {
        biased;
        _ = stopped => None,
        done = toolbox.run(&app, call) => Some(done),
    })
}

/// Whether the model's server refused a request for the tools it was offered:
/// it answered that the request was wrong, or that it has no such model.
fn refuses_tools(failure: &anyhow::Error) -> bool {
    provider::refusal_of(failure).is_some_and(|(status, _)| matches!(status, 400 | 404 | 422))
}

/// Asks the user whether a tool's call may run, and waits for the answer:
/// `None` when the reply is stopped first.
async fn ask_user(
    writer: &Writer,
    message_id: i64,
    ask: ToolAsk,
    stopped: Pin<&mut Notified<'_>>,
) -> Option<bool> {
    let (state, user, chat_id) = (&writer.state, writer.user, writer.chat_id);
    let (answer, answered) = oneshot::channel();
    let asking = Asking {
        ask: ask.clone(),
        answer,
    };
    state.asks().insert((user, chat_id), asking);
    let told = |ask| ReplyEvent::ToolAsks {
        chat_id,
        message_id,
        ask,
    };
    state.push_reply(user, told(Some(ask)));
    let allowed = tokio::select! {
        biased;
        _ = stopped => None,
        answer = answered => Some(answer.unwrap_or(false)),
    };
    state.asks().remove(&(user, chat_id));
    state.push_reply(user, told(None));
    allowed
}

//! The rounds of a reply: the model asked (`ask_round`), its words taken in
//! `stream`, the tools it calls run (`run_calls`, a written tool's script in
//! `run_script`, a call the user allows first in `ask_user`), up to `ROUNDS`.
//! The tools' note stands in the prompt where `assemble` put it until a round
//! offers no tools: told of tools it may not call, a model writes the call as
//! words. A request with cache marks (`provider::caching`) keeps listing the
//! tools in its last round, not to be called, as they are part of the cached
//! start; the note, after the marks, goes all the same. A server that refuses tools is asked again without, and the model
//! kept in `AppState::toolless` once that answer came. How the writing ended
//! (`ReplyEnd`: stopped, or as the provider said of the last round with words) goes to
//! `writer::finish`, which trims a cut-off end by it. A cut is the chat's Reply
//! length reached where the round was asked with it, else the model's own limit
//! (`AtModelLimit`), which the chat tells.

use std::pin::Pin;

use anyhow::ensure;
use cw_chat::chats;
use cw_chat::chats::ReplyEnd;
use cw_coding::tools::used::CallEnd;
use cw_coding::tools::{Done, REFUSED, ToolAsk, Toolbox, WrittenRun, chat};
use cw_core::{Code, Fail};
use cw_prompt::PromptMessage;
use cw_provider::images::Picture;
use cw_provider::{self as provider, Provider};
use cw_provider::{Call, Finish};
use serde_json::{Value, json};
use tokio::sync::futures::Notified;
use tokio::sync::oneshot;

use super::super::ReplyEvent;
use super::stream::{Pushed, Taken, take_words};
use super::{Asking, Job, Writer};

/// The most rounds of tool calls a reply makes; the round after them is
/// offered no tools to call ([`Offers`]).
const ROUNDS: usize = 8;

/// The tools a reply's rounds offer: to call before the last round; in the
/// last round of a marked request listed and not to be called, as the cached
/// start holds them, else none; none from the server's refusal on, which is
/// learned of the model only where it refused tools to call.
#[derive(Default)]
struct Offers {
    marked: bool,
    refused: bool,
    learned: bool,
}

impl Offers {
    /// Whether round `round` offers the tools, and then whether they are off.
    fn at(&self, round: usize) -> Option<bool> {
        let offered = !self.refused && (round < ROUNDS || self.marked);
        offered.then_some(round == ROUNDS)
    }

    /// The server refused the tools of a round, offered `off` or to be called.
    fn refused_with(&mut self, off: bool) {
        self.refused = true;
        self.learned = !off;
    }

    /// Whether a refusal was learned since last asked.
    fn learned(&mut self) -> bool {
        std::mem::take(&mut self.learned)
    }
}

/// Reads the model's reply to `messages` into `content`, after what it holds,
/// saving and pushing it as it grows, until it is complete or stopped; the
/// tools it calls are run between, and the pictures they make put in `made`.
/// Each round's words begin at their first, joined to the text before by
/// `stream::joint`. After an error `content` holds the reply as far as it got.
/// `pushed` tells after whether the model thought. Returns how the reply's
/// writing ended: stopped, or finished as the provider said of the last round
/// that wrote words, those a call follows ended on their own (a round cut off
/// before its first word leaves them whole).
pub(super) async fn read_reply(
    writer: &Writer,
    job: &Job,
    messages: Vec<PromptMessage>,
    (pushed, content, made): (&mut Pushed, &mut String, &mut Vec<(String, Picture)>),
) -> anyhow::Result<ReplyEnd> {
    let message_id = job.message_id;
    let stopped = writer.stop.notified();
    tokio::pin!(stopped);
    let mut messages: Vec<Value> = messages.iter().map(|message| json!(message)).collect();
    let mut note = job.tools_at;
    // One answer for every round: whether this request carries cache marks.
    let marks: &[usize] = match job.cache_at.is_empty() {
        false if provider::caching::marks(&writer.state.http, &job.provider).await => &job.cache_at,
        _ => &[],
    };
    // Refused now, the model is kept toolless once it answered without.
    let mut offers = Offers {
        marked: !marks.is_empty(),
        refused: job.toolless,
        learned: false,
    };
    let base = content.len();
    // How the last round that wrote words ended, which tells how the words end.
    let mut words_ended: Option<ReplyEnd> = None;
    let unlimited = Provider {
        reply_limit: None,
        ..job.provider.clone()
    };
    for round in 0..=ROUNDS {
        let ((mut reply, unlimited), offered) = loop {
            let (offered, tools_off) = match (&job.toolbox, offers.at(round)) {
                (Some(toolbox), Some(off)) => (toolbox.definitions(), off),
                _ => (Vec::new(), false),
            };
            // What follows the note was only ever added after, so its place holds until then.
            if (offered.is_empty() || tools_off)
                && let Some(at) = note.take()
            {
                messages.remove(at);
            }
            let providers = (&job.provider, &unlimited);
            let request = provider::Request {
                tools: &offered,
                tools_off,
                shape: None,
                marks,
            };
            match ask_round(writer, providers, &messages, request, stopped.as_mut()).await? {
                Asked::Stopped => return Ok(ReplyEnd::Stopped),
                Asked::Refused => offers.refused_with(tools_off),
                Asked::Reply { reply, unlimited } => {
                    let callable = if tools_off { Vec::new() } else { offered };
                    break ((*reply, unlimited), callable);
                }
            }
        };
        if offers.learned() {
            let whose = (job.provider.base_url.clone(), job.provider.model.clone());
            writer.state.toolless().insert(whose);
        }
        let begun = content.len();
        let words = (message_id, &mut *pushed, &mut *content);
        let from = (&mut reply, &job.others[..]);
        match take_words(writer, words, from, stopped.as_mut()).await? {
            Taken::Ended => {}
            Taken::Stopped => return Ok(ReplyEnd::Stopped),
            // Cut by Cardwave where another character's turn begins, it ended there.
            Taken::Drifted => return Ok(ReplyEnd::Finished(Finish::OnItsOwn)),
        }
        // A cut in a round asked without the chat's Reply length is the model's own limit.
        let end = match reply.ending().finish {
            Finish::CutOff if unlimited => ReplyEnd::AtModelLimit,
            finish => ReplyEnd::Finished(finish),
        };
        let calls = reply.calls();
        // Words that a call follows ended there, whatever the provider said of the round.
        if content.len() > begun {
            words_ended = Some(match calls.is_empty() {
                true => end,
                false => ReplyEnd::Finished(Finish::OnItsOwn),
            });
        }
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
                // The model's own limit in the last round cut the reply, wherever its words ended.
                return Ok(match end {
                    ReplyEnd::AtModelLimit => end,
                    _ => words_ended.unwrap_or(end),
                });
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
            return Ok(ReplyEnd::Stopped);
        }
    }
    unreachable!("the last round is offered no tools")
}

/// How a round's request went.
enum Asked {
    /// Boxed: a reply is much larger than the other two.
    Reply {
        reply: Box<provider::Reply>,
        /// Whether it was asked without a limit of its length.
        unlimited: bool,
    },
    /// The reply was stopped first.
    Stopped,
    /// The server refused the tools offered: the round is asked again without.
    Refused,
}

/// Asks the model for a round of the reply, offered the tools of `request`,
/// of `provider`, or of `unlimited` where a call's arguments, a file's whole
/// text among them, are not to be cut short.
async fn ask_round(
    writer: &Writer,
    (provider, unlimited): (&Provider, &Provider),
    messages: &[Value],
    request: provider::Request<'_>,
    stopped: Pin<&mut Notified<'_>>,
) -> anyhow::Result<Asked> {
    let limited = match !request.tools_off && chat::cuts(request.tools) {
        true => unlimited,
        false => provider,
    };
    let asked = tokio::select! {
        biased;
        _ = stopped => return Ok(Asked::Stopped),
        reply = provider::ask_request(&writer.state.http, limited, messages, request) => reply,
    };
    match asked {
        Err(failure) if !request.tools.is_empty() && refuses_tools(&failure) => Ok(Asked::Refused),
        asked => Ok(Asked::Reply {
            reply: Box::new(asked?),
            unlimited: limited.reply_limit.is_none(),
        }),
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

#[cfg(test)]
mod tests {
    use super::{Offers, ROUNDS};

    /// A marked request's last round keeps its tools, off; an unmarked one's
    /// has none; a refusal of tools that were off is not learned of the model.
    #[test]
    fn a_marked_last_round_keeps_its_tools_off() {
        let unmarked = Offers::default();
        assert_eq!(unmarked.at(0), Some(false));
        assert_eq!(unmarked.at(ROUNDS), None);
        let mut marked = Offers {
            marked: true,
            ..Offers::default()
        };
        assert_eq!(marked.at(ROUNDS - 1), Some(false));
        assert_eq!(marked.at(ROUNDS), Some(true));
        marked.refused_with(true);
        assert_eq!(marked.at(ROUNDS), None);
        assert!(!marked.learned());
        let mut early = Offers::default();
        early.refused_with(false);
        assert_eq!(early.at(0), None);
        assert!(early.learned());
        assert!(!early.learned());
    }
}

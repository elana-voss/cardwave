//! The prompts of a chat's replies, from the chat as stored: the one a reply
//! answers (`prompt_for`, which keeps the chat's state and the lore it used),
//! the one that continues the newest reply (`continue_prompt`), and a draft's,
//! the user's next message written or bettered (`draft_prompt`, its answer
//! `cleaned`); `api::generate` asks the model and streams. Continuing and
//! writing for the user may be steered by the message field's words, told
//! inside the instruction (`steered`). A reply where the character writes
//! first, or answers after a pause, is told the date, the time and how long
//! since the last message (`time_note`), after the log, where it leaves the
//! cached beginning of the prompt as it was.

use anyhow::ensure;
use chrono::{DateTime, FixedOffset, Local};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_prompt::builder::{self, PromptRequest};
use cw_prompt::{ChatMessage, PromptMessage, Role, Variables};
use cw_provider::{self as provider, NOT_SET_UP, Provider, Sampling};

use crate::chats::{self, Chat, Message};

/// What has the model go on with its reply, after the chat's log.
const CONTINUE: &str = "[Continue your last message without repeating its original content.]";

/// The instruction `[…]` with the user's `direction`, where one is given with
/// words, told at its end: the words in the message field that steer one reply
/// and are sent as no message (the owner, 2026-10-22).
fn steered(instruction: &str, direction: Option<&str>) -> String {
    match direction.map(str::trim).filter(|words| !words.is_empty()) {
        Some(words) => {
            let open = instruction.strip_suffix(']').unwrap_or(instruction);
            format!("{open} Follow this direction from {{{{user}}}}: {words}]")
        }
        None => instruction.to_string(),
    }
}

/// What has the model write the user's next message, after the chat's log;
/// `length_hint` and the closing bracket follow it.
const WRITE_FOR_ME: &str = "[Write your next reply from the point of view of {{user}}, using the user persona and the chat history so far as a guideline for the writing style of {{user}}. Don't write as {{char}} or system. Don't describe actions of {{char}}.";

/// How many of the chat's newest messages an improvement is given.
const IMPROVE_TURNS: usize = 5;

/// What an improvement begins with, before the chat's messages.
const IMPROVE_SYSTEM: &str = "[You are an expert roleplay input improver, tasked with enriching user input to offer an AI a more substantial message to reply to.]";

/// What an improvement ends with, after the chat's messages.
const IMPROVE: &str = "[You are an expert roleplay input improver. Your task is to improve ONLY the MOST RECENT MESSAGE from %USER_NAME% so it becomes easier for %CHAR_NAME% to respond to naturally, emotionally, and coherently.

Your job is NOT to continue the roleplay.
Your job is NOT to answer as %CHAR_NAME%.
Your job is ONLY to analyze and, if needed, improve the latest message from %USER_NAME%.

Rewrite ONLY the current message from %USER_NAME% into a natural first-person reply that adheres to these strict proportional rules:
- Match the length and structural scale of the original input.
- If the input is a single spoken phrase, return a single improved phrase.
- If the input lacks actions or narration, do not invent them.
- Do not expand a brief response into a multi-paragraph narrative.
- Perfectly continue the exact context and flow.
- Keep the original intent, personality, and voice of %USER_NAME% exactly.
- Enhance grammar, tone, and vocabulary without taking unwanted creative liberties.

Output ONLY the improved message. Nothing else.

# Current message from %USER_NAME%:
%CURRENT_USER_MESSAGE%]";

/// What a reply's prompt is given beside the chat: what it is reminded of,
/// the pieces of documents (as the builder's `data_context`), and the chat's
/// reply length, which the context keeps room for.
#[derive(Clone, Copy)]
pub struct Given<'a> {
    pub memory: Option<&'a str>,
    pub documents: Option<&'a str>,
    pub length: u32,
}

/// Builds the prompt that has the newest reply continued: the chat down to
/// it, as it stands in `inputs`, and [`CONTINUE`], `steered` by `direction`.
/// What the build changes is not kept, as the reply's own build kept it.
pub fn continue_prompt(
    inputs: &mut chats::PromptInputs,
    sampling: &Sampling,
    given: Given,
    direction: Option<&str>,
) -> Vec<PromptMessage> {
    let instruction = steered(CONTINUE, direction);
    // A reply being written stays out of a prompt; this one is what is continued.
    if let Some(last) = inputs.state.messages.last_mut() {
        last.complete = true;
    }
    let request = PromptRequest {
        max_response_length: Some(given.length as usize),
        injected_message: Some((Role::User, &instruction)),
        memory_context: given.memory,
        data_context: given.documents,
        ..PromptRequest::new(&inputs.character, sampling.context())
    };
    builder::build(&request, &mut inputs.state, &mut Variables::new()).messages
}

/// How long a pause is: a user's message written this long after the one
/// before it has the reply told the time (`time_note`).
const PAUSE_MS: i64 = 60 * 60 * 1000;

/// What a reply is told of the time after the chat's log, as of `now`: where
/// the character writes first (the newest message is not the user's, or there
/// is none), the date, the time and how long since the newest message; where
/// the user's message came [`PAUSE_MS`] or more after the one before it, the
/// same of the one before it. Else nothing. `times` are the messages' own.
pub fn time_note(
    messages: &[ChatMessage],
    times: &[i64],
    now: DateTime<FixedOffset>,
) -> Option<String> {
    let it_is = format!("It is {}.", now.format("%A, %-d %B %Y, %H:%M"));
    let ago = |at: i64| long(now.timestamp_millis() - at);
    let newest = messages.len().checked_sub(1);
    let said = match newest {
        None => "There is no message yet.".to_string(),
        Some(at) if messages[at].role != Role::User => {
            format!("The last message was written {}.", ago(*times.get(at)?))
        }
        Some(at) => {
            let (before, user) = (*times.get(at.checked_sub(1)?)?, *times.get(at)?);
            if user - before < PAUSE_MS {
                return None;
            }
            format!(
                "Before {{{{user}}}}'s message, the last one was written {}.",
                ago(before)
            )
        }
    };
    Some(format!("[{it_is} {said}]"))
}

/// A stretch of time as the note says it: "less than a minute ago", "5 minutes ago", "3 hours ago", "2 days ago".
fn long(ms: i64) -> String {
    let minutes = ms.max(0) / 60_000;
    let (n, unit) = match minutes {
        0 => return "less than a minute ago".to_string(),
        1..60 => (minutes, "minute"),
        60..2880 => (minutes / 60, "hour"),
        _ => (minutes / 1440, "day"),
    };
    format!("{n} {unit}{} ago", if n == 1 { "" } else { "s" })
}

/// Builds the prompt that `reply` answers, of `inputs`: the chat down to the
/// message before it, with what the reply is reminded of, and the time where
/// `time_note` tells it.
pub fn prompt_for(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    sampling: &Sampling,
    reply: &Message,
    mut inputs: chats::PromptInputs,
    given: Given,
) -> anyhow::Result<Vec<PromptMessage>> {
    let note = time_note(
        &inputs.state.messages,
        &inputs.times,
        Local::now().fixed_offset(),
    );
    let request = PromptRequest {
        max_response_length: Some(given.length as usize),
        injected_message: note.as_deref().map(|note| (Role::System, note)),
        memory_context: given.memory,
        data_context: given.documents,
        ..PromptRequest::new(&inputs.character, sampling.context())
    };
    // Variables shared by all of a user's chats are not stored yet.
    let built = builder::build(&request, &mut inputs.state, &mut Variables::new());
    chats::save_prompt_state(db, user, chat.id, &inputs.state)?;
    let context = chats::ContextUse {
        used: built
            .breakdown
            .segments
            .iter()
            .map(|segment| segment.tokens)
            .sum(),
        size: built.breakdown.context_size,
    };
    let sent = sent(&built.breakdown.segments);
    chats::save_used(db, user, reply.id, &inputs, &built.lore, (context, sent))?;
    Ok(built.messages)
}

/// The tokens of a prompt's `segments`, part by part, as "Sent to the AI" names them.
pub fn sent(segments: &[builder::Segment]) -> chats::Sent {
    use builder::SegmentKind as Kind;
    let mut sent = chats::Sent::default();
    for segment in segments {
        let part = match segment.kind {
            Kind::UserPersona => &mut sent.persona,
            Kind::Memory => &mut sent.memory,
            Kind::WorldInfo => &mut sent.lorebook,
            Kind::History | Kind::CurrentMessage | Kind::Injected => &mut sent.history,
            _ => &mut sent.card,
        };
        *part += segment.tokens;
    }
    sent
}

/// The provider and the prompt of a draft (`POST /api/chats/{id}/draft`), and
/// the name the user goes by in the chat. Writing for the user may be
/// `steered` by `direction`; an improvement takes none.
pub fn draft_prompt(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    improve: Option<&str>,
    direction: Option<&str>,
) -> anyhow::Result<(Provider, Vec<PromptMessage>, String)> {
    ensure!(
        improve.is_none() || direction.is_none(),
        Fail::said(
            Code::NotPossible,
            "an improvement takes no direction: the field's words are what it betters"
        )
        .with("what", "improve_direction")
    );
    let chat = chats::get(db, user, chat_id)?.ok_or(NotFound("chat"))?;
    let provider = provider::get(db, user)?.ok_or(NOT_SET_UP)?;
    // The character picked to reply, else the one the chat began with.
    let mut inputs = chats::prompt_inputs_after(db, user, &chat, chat.replier_id, chat.head_id)?;
    let prompt = match improve {
        Some(text) => {
            let text = text.trim();
            ensure!(
                !text.is_empty(),
                Fail::said(Code::Needed, "there is no message to improve")
                    .with("what", "message_to_improve")
            );
            improve_prompt(&inputs, text)
        }
        None => {
            let instruction = steered(
                &format!("{WRITE_FOR_ME}{}]", length_hint(&inputs.state.messages)),
                direction,
            );
            let request = PromptRequest {
                max_response_length: Some(chat.reply_length as usize),
                injected_message: Some((Role::User, &instruction)),
                is_impersonating: true,
                ..PromptRequest::new(&inputs.character, provider.sampling.context())
            };
            builder::build(&request, &mut inputs.state, &mut Variables::new()).messages
        }
    };
    Ok((provider, prompt, inputs.state.persona_name))
}

/// How long the user's message is to be, by the user's last five messages, as
/// Cardwave says it: in paragraphs where one of them has several, else in
/// sentences, on average; one paragraph where there are none.
pub fn length_hint(messages: &[ChatMessage]) -> String {
    let mut own: Vec<&str> = messages
        .iter()
        .rev()
        .filter(|m| m.role == Role::User && m.complete && !m.content.trim().is_empty())
        .take(5)
        .map(|m| m.content.trim())
        .collect();
    own.reverse();
    if own.is_empty() {
        return " Limit your response to approximately 1 paragraph.".to_string();
    }
    let paragraphs: Vec<usize> = own
        .iter()
        .map(|text| text.lines().filter(|line| !line.trim().is_empty()).count())
        .collect();
    let sentences: usize = own
        .iter()
        .map(|text| {
            text.split(['.', '!', '?'])
                .filter(|part| !part.trim().is_empty())
                .count()
                .max(1)
        })
        .sum();
    let (total, one, many) = if paragraphs.iter().any(|&n| n > 1) {
        (paragraphs.iter().sum(), "paragraph", "paragraphs")
    } else {
        (sentences, "sentence", "sentences")
    };
    let average = (total as f64 / own.len() as f64).round() as usize;
    let unit = if average == 1 { one } else { many };
    format!(" Limit your response to approximately {average} {unit}.")
}

/// The prompt that betters `text`: [`IMPROVE_SYSTEM`], the chat's last
/// [`IMPROVE_TURNS`] messages with text, and [`IMPROVE`] with the names and the text.
fn improve_prompt(inputs: &chats::PromptInputs, text: &str) -> Vec<PromptMessage> {
    let said: Vec<&ChatMessage> = inputs
        .state
        .messages
        .iter()
        .filter(|m| m.complete && !m.content.trim().is_empty())
        .collect();
    let recent = &said[said.len().saturating_sub(IMPROVE_TURNS)..];
    let ask = IMPROVE
        .replace("%USER_NAME%", &inputs.state.persona_name)
        .replace("%CHAR_NAME%", inputs.character.display_name())
        // Last, so that the user's own words are taken as they are.
        .replace("%CURRENT_USER_MESSAGE%", text);
    std::iter::once(PromptMessage::new(Role::System, IMPROVE_SYSTEM))
        .chain(
            recent
                .iter()
                .map(|m| PromptMessage::new(m.role, m.content.clone())),
        )
        .chain(std::iter::once(PromptMessage::new(Role::User, ask)))
        .collect()
}

/// The text a model wrote for the user without what it put around it: of an
/// improvement of `improved`, an "Improved message:" before it and quotes
/// around it that have none inside, where the user's text was not quoted so;
/// and the user's name before a colon, as the chat's log names a speaker.
pub fn cleaned<'a>(text: &'a str, user_name: &str, improved: Option<&str>) -> String {
    let mut text = text.trim();
    if let Some(improved) = improved {
        let said = |text: &'a str| {
            [
                "here is the improved message",
                "improved message",
                "improved",
            ]
            .iter()
            .find_map(|said| {
                let head = text.get(..said.len())?;
                head.eq_ignore_ascii_case(said)
                    .then(|| text[said.len()..].strip_prefix(':'))
                    .flatten()
            })
            .map_or(text, str::trim_start)
        };
        let quoted = improved.trim_start().starts_with('"');
        text = said(text);
        if let Some(inner) = text.strip_prefix('"').and_then(|t| t.strip_suffix('"'))
            && !quoted
            && !inner.contains('"')
        {
            text = said(inner.trim());
        }
    }
    if let Some(rest) = text
        .strip_prefix(user_name)
        .and_then(|rest| rest.strip_prefix(':'))
    {
        text = rest.trim_start();
    }
    text.to_string()
}

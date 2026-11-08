//! What goes to the worker model of a card: the card as its prompts are given it (`card_text`, `card_json`), on
//! one spaced line (`sent`, the reason in `describe.rs`'s head), whether it fits the model's context (`fits`), and
//! an answer asked once more when it cannot be read (`asked_and_read`).

use anyhow::ensure;
use cw_ccv4::{Document, mapping};
use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, tokens};
use cw_provider::{Http, Provider, answer};
use serde::Serialize;
use serde_json::{Value, json};

/// The tokens kept free for the classifier's answer in the worker model's context.
const ANSWER_ROOM: usize = 1_000;

/// serde_json's compact form with a space after each `,` and `:`.
struct Spaced;

impl serde_json::ser::Formatter for Spaced {
    fn begin_array_value<W: ?Sized + std::io::Write>(
        &mut self,
        writer: &mut W,
        first: bool,
    ) -> std::io::Result<()> {
        writer.write_all(if first { b"" } else { b", " })
    }

    fn begin_object_key<W: ?Sized + std::io::Write>(
        &mut self,
        writer: &mut W,
        first: bool,
    ) -> std::io::Result<()> {
        writer.write_all(if first { b"" } else { b", " })
    }

    fn begin_object_value<W: ?Sized + std::io::Write>(
        &mut self,
        writer: &mut W,
    ) -> std::io::Result<()> {
        writer.write_all(b": ")
    }
}

/// JSON as a model is given it: on one spaced line, for the head's reason.
pub(crate) fn sent(value: &impl Serialize) -> anyhow::Result<String> {
    let mut out = Vec::new();
    value.serialize(&mut serde_json::Serializer::with_formatter(
        &mut out, Spaced,
    ))?;
    Ok(String::from_utf8(out)?)
}

/// A card as a prompt is given it, in this order: a `Value` would sort its keys.
#[derive(Serialize)]
struct Told {
    title: String,
    tags: Vec<String>,
    characters: Vec<ToldCharacter>,
}

#[derive(Serialize)]
struct ToldCharacter {
    name: String,
    description: String,
    personality: String,
    scenario: String,
    first_mes: String,
    alternate_greetings: Vec<String>,
    mes_example: String,
}

/// A card's title, tags and characters in SillyTavern's field names, the texts as written.
fn told(document: &Document) -> Told {
    let cut = |text: &str| -> String { text.trim().to_string() };
    let characters = document
        .characters()
        .into_iter()
        .map(|id| {
            let texts = mapping::character(document, id).unwrap_or_default();
            let mut greetings = document.greetings(id, false).into_iter().map(|g| cut(&g));
            let first = greetings.next().unwrap_or_default();
            ToldCharacter {
                name: document.character_name(id),
                description: cut(&texts.description),
                personality: cut(&texts.personality),
                scenario: cut(&texts.scenario),
                first_mes: first,
                alternate_greetings: greetings.collect(),
                mes_example: cut(&texts.mes_example),
            }
        })
        .collect();
    Told {
        title: document.title(),
        tags: document.tags(),
        characters,
    }
}

/// The card as the prompts for its description and its needs are given it.
pub fn card_text(document: &Document) -> anyhow::Result<String> {
    sent(&told(document))
}

/// The card as data, for the prompt of a picture of it.
pub fn card_json(document: &Document) -> Value {
    json!(told(document))
}

/// The model's answer as `read` reads it. One that cannot be read is asked once more, one more call, and a
/// second stays the failure; what the provider itself answered with an error, or a refusal, is not asked again.
pub(crate) async fn asked_and_read<T>(
    http: &Http,
    provider: &Provider,
    messages: &[PromptMessage],
    read: impl Fn(&str) -> anyhow::Result<T>,
) -> anyhow::Result<T> {
    match read(&answer(http, provider, messages).await?) {
        Ok(read) => Ok(read),
        // The first failure is dropped: the second answer's is the one told.
        Err(_) => read(&answer(http, provider, messages).await?),
    }
}

/// Refuses a card that the worker model cannot read whole beside the
/// classifier's prompt and the room for its answer: classified from its start
/// alone, a card could pass that a later greeting has refused.
/// Refuses a card that, told with `prompt`, is longer than the worker model reads.
pub fn fits(provider: &Provider, prompt: &str, card: &str) -> anyhow::Result<()> {
    let needed = tokens::estimate(prompt) + tokens::estimate(card) + ANSWER_ROOM;
    let context = provider.sampling.context();
    ensure!(needed <= context, Fail::said(Code::TooBig, format!("the card is longer than the worker model reads (about {needed} tokens of {context})")).with("what", "card_for_worker").with("needed", needed.to_string()).with("context", context.to_string()));
    Ok(())
}

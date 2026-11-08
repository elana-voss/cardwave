//! First run's picks: from the key, a model of each kind (chat, background,
//! images) of those the provider lists, so that step 2 opens filled in.
//!
//! Rules first ([`candidates`]): the provider's models (`catalog`, its kinds
//! as Settings › Providers has them) matched by name against models.dev's
//! whole list (`models_dev`), at most [`CANDIDATES`] per kind: chat models
//! that are no cheap one, not dear and not short of context, the newest first;
//! background models that are cheap by name or price, the newest first; image
//! models, the newest first; those models.dev does not know after those it
//! does. Then the rules' first chat model makes the final picks in one request
//! ([`ask`]); an answer that names no candidate leaves the rules' own: their
//! first chat and image model, and as background the cheap model of the chat
//! model's maker ([`cheap_worker`]), else none (the chat model does that work).
//! Where the provider offers a family `suggested` names, its newest model leads
//! the background candidates and is the background pick whatever the answer
//! ([`worker`]). Nothing is tested or stored here. Over HTTP it is `POST /api/provider/picks`.

use std::cmp::Reverse;
use std::time::Duration;

use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use serde::Serialize;
use serde_json::Value;
use tokio::time::timeout;
use ts_rs::TS;

use crate::Http;
use crate::catalog::{self, OfferedModel};
use crate::facts::{self, has_word};
use crate::models_dev::{Index, Known};
use crate::{Provider, Sampling, suggested};

/// The most candidates of a kind.
pub(crate) const CANDIDATES: usize = 15;

/// How long the final picks may take: a model that thinks first takes a while.
const ASK_LIMIT: Duration = Duration::from_secs(120);

/// Words in a model's ID that mark a cheap, quick model of its maker.
const CHEAP: [&str; 7] = ["mini", "flash", "lite", "haiku", "small", "fast", "air"];
/// [`CHEAP`] and "nano": a chat model by none of them can have a cheap one beside it.
const CHEAP_OR_NANO: [&str; 8] = [
    "mini", "flash", "lite", "haiku", "small", "fast", "air", "nano",
];
/// Dollars per million tokens written above which a model is no chat model's candidate.
const DEAR: f64 = 30.0;
/// Dollars per million tokens written up to which a model is a cheap one.
const CHEAP_PRICE: f64 = 4.0;
/// Tokens a chat model reads at least.
const SHORT: u64 = 16_000;

/// The models first run opens with, and what the provider's list came to.
#[derive(Debug, Default, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct Picks {
    pub chat: Option<String>,
    /// None: the chat model does that work.
    pub background: Option<String>,
    pub images: Option<String>,
    /// How many models the provider listed.
    pub listed: usize,
    /// Why no list came, where none did.
    pub failed: Option<cw_core::ErrorBody>,
}

/// The candidates of each kind, the rules' first first.
#[derive(Debug, Default, PartialEq)]
pub struct Candidates {
    pub chat: Vec<String>,
    pub background: Vec<String>,
    pub images: Vec<String>,
}

impl Candidates {
    /// `id` first among the background candidates, once, at most [`CANDIDATES`] of them.
    fn lead(&mut self, id: &str) {
        self.background.retain(|other| other != id);
        self.background.insert(0, id.to_string());
        self.background.truncate(CANDIDATES);
    }
}

/// The maker of a model: the part of its ID before its last `/`, or its first word.
fn maker(id: &str) -> String {
    match id.rsplit_once('/') {
        Some((maker, _)) => maker.to_lowercase(),
        None => facts::words(id).into_iter().next().unwrap_or_default(),
    }
}

fn cheap(id: &str, marks: &[&str]) -> bool {
    has_word(id, marks) && !facts::no_chat_by_name(id)
}

/// The cheap model of the chat model's maker among `models`, the last such ID
/// in the order of the letters, numbers counted as numbers, which is mostly
/// the newest; none where the chat model is a cheap or a "nano" one itself.
pub(crate) fn cheap_worker(models: &[String], chat: &str) -> Option<String> {
    if cheap(chat, &CHEAP_OR_NANO) {
        return None;
    }
    models
        .iter()
        .filter(|id| maker(id) == maker(chat) && cheap(id, &CHEAP))
        .max_by(|a, b| numeric_order(a, b))
        .cloned()
}

/// The order of the letters, case aside, with a run of digits counted as a number.
fn numeric_order(a: &str, b: &str) -> std::cmp::Ordering {
    fn parts(id: &str) -> Vec<(u64, String)> {
        let mut parts = Vec::new();
        let lower = id.to_lowercase();
        let mut rest = lower.as_str();
        while !rest.is_empty() {
            let digits = rest
                .find(|c: char| !c.is_ascii_digit())
                .unwrap_or(rest.len());
            if digits > 0 {
                parts.push((rest[..digits].parse().unwrap_or(u64::MAX), String::new()));
                rest = &rest[digits..];
            } else {
                let letters = rest
                    .find(|c: char| c.is_ascii_digit())
                    .unwrap_or(rest.len());
                parts.push((0, rest[..letters].to_string()));
                rest = &rest[letters..];
            }
        }
        parts
    }
    parts(a).cmp(&parts(b))
}

/// The newest first, those models.dev does not know last, then by `then`.
fn ranked<'a>(
    models: impl Iterator<Item = &'a str>,
    index: &Index,
    then: impl Fn(Option<&Known>) -> i64,
) -> Vec<String> {
    let mut ranked: Vec<(bool, Reverse<String>, i64, &str)> = models
        .map(|id| {
            let known = index.get(id);
            let released = known
                .and_then(|known| known.released.clone())
                .unwrap_or_default();
            (known.is_none(), Reverse(released), then(known), id)
        })
        .collect();
    ranked.sort();
    ranked
        .into_iter()
        .take(CANDIDATES)
        .map(|(.., id)| id.to_string())
        .collect()
}

/// A price as a number to sort by, in hundredths of a cent.
fn price(known: Option<&Known>) -> i64 {
    known
        .and_then(|known| known.output)
        .map_or(0, |price| (price * 10_000.0) as i64)
}

/// The rules' candidates of each kind among the provider's `models`.
pub fn candidates(models: &[OfferedModel], index: &Index) -> Candidates {
    let texts: Vec<&str> = models
        .iter()
        .filter(|m| m.text)
        .map(|m| m.id.as_str())
        .collect();
    let chatty: Vec<&str> = texts
        .iter()
        .copied()
        .filter(|id| !facts::no_chat_by_name(id))
        .collect();
    let fit = |id: &&str| {
        let known = index.get(id);
        !has_word(id, &CHEAP_OR_NANO)
            && known
                .and_then(|known| known.output)
                .is_none_or(|price| price <= DEAR)
            && known
                .and_then(|known| known.context)
                .is_none_or(|context| context >= SHORT)
    };
    let mut chat: Vec<&str> = chatty.iter().copied().filter(fit).collect();
    // A list of cheap models alone still has a chat model.
    if chat.is_empty() {
        chat = if chatty.is_empty() {
            texts.clone()
        } else {
            chatty.clone()
        };
    }
    let is_cheap = |id: &&str| {
        let price = index.get(id).and_then(|known| known.output);
        price.map_or(has_word(id, &CHEAP), |price| price <= CHEAP_PRICE)
    };
    Candidates {
        // The dearer first among those of a day: mostly the stronger.
        chat: ranked(chat.into_iter(), index, |known| -price(known)),
        background: ranked(chatty.iter().copied().filter(is_cheap), index, price),
        images: ranked(
            models.iter().filter(|m| m.image).map(|m| m.id.as_str()),
            index,
            |_| 0,
        ),
    }
}

/// A candidate's line in the request: its ID and what models.dev says of it.
fn line(id: &str, index: &Index) -> String {
    let Some(known) = index.get(id) else {
        return format!("- {id}");
    };
    let mut said = Vec::new();
    if let Some(released) = &known.released {
        said.push(format!("released {released}"));
    }
    if let (Some(input), Some(output)) = (known.input, known.output) {
        said.push(format!("${input} in, ${output} out per million tokens"));
    }
    if let Some(context) = known.context {
        said.push(format!("reads {context} tokens"));
    }
    match said.is_empty() {
        true => format!("- {id}"),
        false => format!("- {id} ({})", said.join(", ")),
    }
}

const ASKED: &str = "You pick the models for Cardwave, an app for chatting and roleplay with characters. From each list below, pick one model by its ID, copied exactly:\n\
\"chat\": the best model for writing a character's replies in roleplay and conversation;\n\
\"background\": a cheap, quick model for summaries, tags and memories, best of the chat model's maker;\n\
\"images\": the best model for pictures of characters and scenes.\n\
Answer with this JSON alone: {\"chat\": \"…\", \"background\": \"…\", \"images\": \"…\"}, null where a list is empty.";

/// The request for the final picks among `candidates`.
fn prompt(candidates: &Candidates, index: &Index) -> Vec<PromptMessage> {
    let list = |name: &str, ids: &[String]| {
        let lines: Vec<String> = ids.iter().map(|id| line(id, index)).collect();
        format!(
            "{name}:\n{}",
            if lines.is_empty() {
                "(empty)".into()
            } else {
                lines.join("\n")
            }
        )
    };
    let lists = [
        list("chat", &candidates.chat),
        list("background", &candidates.background),
        list("images", &candidates.images),
    ];
    vec![
        PromptMessage::new(Role::System, ASKED.to_string()),
        PromptMessage::new(Role::User, lists.join("\n\n")),
    ]
}

/// What an answer picked of each kind, where it is one of the candidates.
fn chosen(answer: &Value, candidates: &Candidates) -> [Option<String>; 3] {
    let of = |key: &str, ids: &[String]| {
        let named = answer.get(key)?.as_str()?.trim();
        ids.iter().find(|id| id.as_str() == named).cloned()
    };
    [
        of("chat", &candidates.chat),
        of("background", &candidates.background),
        of("images", &candidates.images),
    ]
}

/// Has `model` at the provider pick among the candidates; what it named of them.
async fn ask(
    http: &Http,
    base_url: &str,
    key: &str,
    model: &str,
    candidates: &Candidates,
    index: &Index,
) -> anyhow::Result<[Option<String>; 3]> {
    let provider = Provider {
        base_url: base_url.to_string(),
        api_key: key.to_string(),
        model: model.to_string(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    };
    let prompt = prompt(candidates, index);
    let asked = crate::answer(http, &provider, &prompt);
    let answer = match timeout(ASK_LIMIT, asked).await {
        Ok(answer) => answer?,
        Err(_) => {
            anyhow::bail!(Fail::said(Code::TimedOut, "no answer in time").with("whose", "model"))
        }
    };
    Ok(chosen(&crate::object(&answer)?, candidates))
}

/// The picks for the provider at `base_url`, asked with `key`.
pub async fn pick(http: &Http, index: &Index, base_url: &str, key: &str) -> Picks {
    let catalog = catalog::of(http, base_url, key).await;
    let mut candidates = candidates(&catalog.models, index);
    let mut picks = Picks {
        chat: candidates.chat.first().cloned(),
        images: candidates.images.first().cloned(),
        listed: catalog.models.len(),
        failed: catalog.failed,
        background: None,
    };
    let texts: Vec<String> = catalog
        .models
        .iter()
        .filter(|m| m.text)
        .map(|m| m.id.clone())
        .collect();
    let suggested = suggested::of(base_url, &texts, index);
    if let Some(id) = &suggested {
        candidates.lead(id);
    }
    let several = [&candidates.chat, &candidates.background, &candidates.images]
        .iter()
        .any(|ids| ids.len() > 1);
    let mut background = None;
    if let (Some(model), true) = (&picks.chat, several) {
        match ask(http, base_url, key, model, &candidates, index).await {
            Ok([chat, worker, images]) => {
                picks.chat = chat.or(picks.chat);
                picks.images = images.or(picks.images);
                background = worker;
            }
            Err(failure) => {
                tracing::warn!("the models were picked by the rules alone: {failure:#}")
            }
        }
    }
    if let Some(chat) = &picks.chat {
        picks.background = worker(suggested, background, &texts, chat);
    }
    picks
}

/// The background pick: the suggestion, else the picking model's choice, else
/// the cheap model of the chat model's maker; none where that is the chat model.
fn worker(
    suggested: Option<String>,
    chosen: Option<String>,
    texts: &[String],
    chat: &str,
) -> Option<String> {
    suggested
        .or(chosen)
        .or_else(|| cheap_worker(texts, chat))
        .filter(|worker| worker != chat)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ids(list: &[&str]) -> Vec<String> {
        list.iter().map(|id| id.to_string()).collect()
    }

    #[test]
    fn the_cheap_model_of_the_chat_models_maker_is_its_worker() {
        let routed = ids(&[
            "anthropic/claude-sonnet-4.5",
            "anthropic/claude-haiku-4.5",
            "openai/gpt-5-mini",
        ]);
        assert_eq!(
            cheap_worker(&routed, "anthropic/claude-sonnet-4.5").as_deref(),
            Some("anthropic/claude-haiku-4.5")
        );
        let openai = ids(&[
            "gpt-5",
            "gpt-5-mini",
            "gpt-5-nano",
            "gpt-4o-mini-tts",
            "o3",
            "o3-mini",
        ]);
        assert_eq!(
            cheap_worker(&openai, "gpt-5").as_deref(),
            Some("gpt-5-mini")
        );
        assert_eq!(cheap_worker(&openai, "o3").as_deref(), Some("o3-mini"));
        // Numbers counted as numbers: 10 after 9.
        let reef = ids(&["reef-10", "reef-9-mini", "reef-10-mini"]);
        assert_eq!(
            cheap_worker(&reef, "reef-10").as_deref(),
            Some("reef-10-mini")
        );
        // A model for sound, pictures, search, code or embeddings is no worker.
        let grok = ids(&["x-ai/grok-4", "x-ai/grok-code-fast-1", "x-ai/grok-4-fast"]);
        assert_eq!(
            cheap_worker(&grok, "x-ai/grok-4").as_deref(),
            Some("x-ai/grok-4-fast")
        );
        let gemini = ids(&[
            "google/gemini-2.5-pro",
            "google/gemini-2.5-flash-image",
            "google/gemini-2.5-flash",
        ]);
        assert_eq!(
            cheap_worker(&gemini, "google/gemini-2.5-pro").as_deref(),
            Some("google/gemini-2.5-flash")
        );
        assert_eq!(cheap_worker(&routed, "sao10k/l3.3-euryale-70b"), None);
        assert_eq!(
            cheap_worker(
                &ids(&["deepseek-chat", "deepseek-reasoner"]),
                "deepseek-chat"
            ),
            None
        );
        // A cheap or nano chat model does the work itself; none of its maker, none.
        assert_eq!(cheap_worker(&openai, "gpt-5-nano"), None);
        assert_eq!(cheap_worker(&openai, "gpt-4o-mini"), None);
        assert_eq!(cheap_worker(&ids(&["tide-1"]), "tide-1"), None);
    }

    fn offered(id: &str, text: bool, image: bool) -> OfferedModel {
        OfferedModel {
            id: id.into(),
            text,
            image,
            search: false,
            voice: false,
            thinks: false,
        }
    }

    const LIST: &str = r#"{ "p": { "models": {
        "big-2": { "id": "big-2", "release_date": "2025-06-01", "cost": { "input": 3, "output": 15 }, "limit": { "context": 200000 } },
        "big-3": { "id": "big-3", "release_date": "2025-09-01", "cost": { "input": 3, "output": 15 }, "limit": { "context": 200000 } },
        "pro-max": { "id": "pro-max", "release_date": "2025-10-01", "cost": { "input": 15, "output": 75 } },
        "tiny-ctx": { "id": "tiny-ctx", "release_date": "2025-10-01", "limit": { "context": 8000 } },
        "cheapo": { "id": "cheapo", "release_date": "2025-07-01", "cost": { "input": 0.1, "output": 0.4 } },
        "paint-2": { "id": "paint-2", "release_date": "2025-05-01" } } } }"#;

    #[test]
    fn the_rules_take_the_newest_fitting_models_of_each_kind() {
        let index = Index::read(LIST.as_bytes()).unwrap();
        let models = [
            offered("big-2", true, false),
            offered("big-3", true, false),
            offered("pro-max", true, false),
            offered("tiny-ctx", true, false),
            offered("cheapo", true, false),
            offered("big-3-mini", true, false),
            offered("unknown-1", true, false),
            offered("text-embed-1", true, false),
            offered("paint-1", false, true),
            offered("paint-2", false, true),
        ];
        let found = candidates(&models, &index);
        // Not dear, not short, no cheap one, no embedder; models.dev's newest first, the unknown last.
        assert_eq!(found.chat, ids(&["big-3", "cheapo", "big-2", "unknown-1"]));
        // Cheap by price or by name.
        assert_eq!(found.background, ids(&["cheapo", "big-3-mini"]));
        assert_eq!(found.images, ids(&["paint-2", "paint-1"]));
        // At most fifteen of a kind.
        let many: Vec<OfferedModel> = (0..20)
            .map(|n| offered(&format!("m-{n}"), true, false))
            .collect();
        assert_eq!(candidates(&many, &index).chat.len(), CANDIDATES);
    }

    #[test]
    fn a_suggestion_leads_the_background_candidates_and_is_the_background_pick() {
        let mut found = Candidates {
            background: ids(&["cheapo", "mistral-small-4", "big-3-mini"]),
            ..Candidates::default()
        };
        found.lead("mistral-small-4");
        assert_eq!(
            found.background,
            ids(&["mistral-small-4", "cheapo", "big-3-mini"])
        );
        let texts = ids(&["big-3", "big-3-mini", "mistral-small-4"]);
        let suggested = Some("mistral-small-4".to_string());
        let chosen = Some("big-3-mini".to_string());
        assert_eq!(
            worker(suggested.clone(), chosen.clone(), &texts, "big-3").as_deref(),
            Some("mistral-small-4")
        );
        // None suggested: the picking model's choice, else the cheap model of the chat model's maker.
        assert_eq!(
            worker(None, chosen, &texts, "big-3").as_deref(),
            Some("big-3-mini")
        );
        assert_eq!(
            worker(None, None, &texts, "big-3").as_deref(),
            Some("big-3-mini")
        );
        // The chat model itself is no background pick: it does that work.
        assert_eq!(worker(suggested, None, &texts, "mistral-small-4"), None);
    }

    #[test]
    fn an_answer_counts_where_it_names_a_candidate() {
        let candidates = Candidates {
            chat: ids(&["a", "b"]),
            background: ids(&["c"]),
            images: vec![],
        };
        let answer = serde_json::json!({ "chat": "b", "background": "zzz", "images": "a" });
        assert_eq!(chosen(&answer, &candidates), [Some("b".into()), None, None]);
    }
}

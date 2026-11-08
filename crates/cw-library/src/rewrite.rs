//! A card's text changed by one of its AI tools (Improve the prose, Fix grammar
//! and spelling, Make it shorter, Make it longer, Translate…, Ask for a
//! change…), by the background model (`provider::for_work`). [`ask`] answers the
//! new text alone; nothing is stored, as the page keeps it or not, a kept one as
//! a draft named after the tool. A card's text is asked of with its name,
//! description, personality and scenario as context ([`CardContext`]).
//!
//! [`translate_lore`] translates a card's own lorebook for "Translate…": each
//! entry's words and keywords, a few entries at a time. [`lore`] is a lorebook
//! editor's AI tools for the whole lorebook (Write missing keywords, Fix grammar
//! in every entry, Translate the lorebook…), entry by entry, nothing stored.
//!
//! Trap: a model may put the text in a code fence or the `<text>` tags it was
//! given in; [`cleaned`] takes them off.

use anyhow::{bail, ensure};
use cw_ccv4::drafts::AiTool;
use cw_ccv4::languages::LoreText;
use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::Provider;
use futures_util::{StreamExt, TryStreamExt, stream};
use serde::Deserialize;
use ts_rs::TS;

/// A text to change.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct Rewrite {
    pub text: String,
    pub tool: AiTool,
    /// The text's name on the card's page ("Description").
    pub what: String,
    /// What the user typed: the language for Translate, the change for Ask.
    pub given: Option<String>,
    /// The card the text belongs to, for context.
    pub card: Option<CardContext>,
}

/// What of a card a text's AI tool is given as context; an empty text is left out.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct CardContext {
    pub name: String,
    pub description: String,
    pub personality: String,
    pub scenario: String,
}

impl CardContext {
    /// The card's texts with words, each in its tag; none where none has words.
    fn told(&self) -> Option<String> {
        let parts: Vec<String> = [
            ("name", &self.name),
            ("description", &self.description),
            ("personality", &self.personality),
            ("scenario", &self.scenario),
        ]
        .iter()
        .filter(|(_, text)| !text.trim().is_empty())
        .map(|(tag, text)| format!("<{tag}>{}</{tag}>", text.trim()))
        .collect();
        (!parts.is_empty()).then(|| parts.join("\n"))
    }
}

/// What every tool is told around its own instruction.
const FRAME: &str = "You rewrite one text of a character card for roleplay: the card's {what}.";
const KEEP: &str = "Keep its macros, such as {{char}} and {{user}}, exactly as written, and its Markdown marks: **bold**, *narration*, lists and the empty lines between paragraphs. Answer with the new text alone: no title, no quotes around it, no word on what you changed.";

/// The tool's instruction, with what the user typed.
fn instruction(tool: AiTool, given: &str) -> anyhow::Result<String> {
    let needs = |what: &str| {
        ensure!(
            !given.is_empty(),
            Fail::said(Code::Needed, format!("{what} is missing")).with("what", "rewrite_given")
        );
        Ok(())
    };
    Ok(match tool {
        AiTool::Improve => "Improve the prose: make it read better, clearer and more vivid, keeping its meaning, its facts, its point of view and about its length.".to_string(),
        AiTool::Fix => "Fix its grammar and spelling only; change nothing else.".to_string(),
        AiTool::Shorter => "Make it shorter, about two thirds of its length, keeping what matters most.".to_string(),
        AiTool::Longer => "Make it longer, about half as long again, with detail that fits what it says.".to_string(),
        AiTool::Translate => {
            needs("the language")?;
            format!("Translate it into {given}.")
        }
        AiTool::Ask => {
            needs("the change")?;
            format!("Change it as the user asks, and nothing else: {given}")
        }
    })
}

/// The prompt for `rewrite`.
pub fn prompt(rewrite: &Rewrite) -> anyhow::Result<Vec<PromptMessage>> {
    let text = rewrite.text.trim();
    ensure!(
        !text.is_empty(),
        Fail::said(Code::Needed, "there is no text to change").with("what", "text_to_change")
    );
    let given = rewrite.given.as_deref().unwrap_or_default().trim();
    let mut system = format!(
        "{} {} {KEEP}",
        FRAME.replace("{what}", rewrite.what.trim()),
        instruction(rewrite.tool, given)?
    );
    if let Some(card) = rewrite.card.as_ref().and_then(CardContext::told) {
        system.push_str(&format!(
            "\n\nThe card the text belongs to, for context only; change nothing of it but the text:\n<card>\n{card}\n</card>"
        ));
    }
    Ok(vec![
        PromptMessage::new(Role::System, system),
        PromptMessage::new(Role::User, format!("<text>\n{text}\n</text>")),
    ])
}

/// Has the background model change the text; answers the new text.
pub async fn ask(http: &Http, provider: &Provider, rewrite: &Rewrite) -> anyhow::Result<String> {
    let prompt = prompt(rewrite)?;
    let text = cleaned(
        &cw_provider::answer(http, provider, &prompt).await?,
        &rewrite.text,
    );
    if text.is_empty() {
        bail!(
            Fail::said(Code::ModelAnswer, "the background model sent no text")
                .with("what", "background_text")
        );
    }
    Ok(text)
}

/// How many lorebook entries are translated at once.
const AT_ONCE: usize = 4;

/// Translates `text`, the card's `what`, into `language` (its English name).
async fn translated(
    http: &Http,
    provider: &Provider,
    text: &str,
    what: &str,
    language: &str,
) -> anyhow::Result<String> {
    let asked = Rewrite {
        text: text.to_string(),
        tool: AiTool::Translate,
        what: what.to_string(),
        given: Some(language.to_string()),
        card: None,
    };
    ask(http, provider, &asked).await
}

/// Keywords translated into `language`, as one list parted by commas; none stay none.
async fn translated_keywords(
    http: &Http,
    provider: &Provider,
    keywords: &[String],
    language: &str,
) -> anyhow::Result<Vec<String>> {
    if keywords.is_empty() {
        return Ok(Vec::new());
    }
    let what = "lorebook entry's keywords, parted by commas";
    let words = translated(http, provider, &keywords.join(", "), what, language).await?;
    Ok(keywords_in(&words, keywords.len()).unwrap_or_else(|| keywords.to_vec()))
}

/// The keywords of `answer`, parted by any comma a language writes; none
/// where they are not `count`, as the model then wrote something else.
fn keywords_in(answer: &str, count: usize) -> Option<Vec<String>> {
    let words: Vec<String> = answer
        .split([',', '\u{FF0C}', '\u{3001}', '\u{060C}'])
        .map(str::trim)
        .filter(|word| !word.is_empty())
        .map(str::to_string)
        .collect();
    (words.len() == count).then_some(words)
}

/// The entries `entries` translated into `language` (its English name), in their order.
pub async fn translate_lore(
    http: &Http,
    provider: &Provider,
    entries: Vec<LoreText>,
    language: &str,
) -> anyhow::Result<Vec<LoreText>> {
    let one = |entry: LoreText| async move {
        Ok::<_, anyhow::Error>(LoreText {
            text: translated(http, provider, &entry.text, "lorebook entry", language).await?,
            keywords: translated_keywords(http, provider, &entry.keywords, language).await?,
            secondary_keywords: translated_keywords(
                http,
                provider,
                &entry.secondary_keywords,
                language,
            )
            .await?,
            reference: entry.reference,
        })
    };
    stream::iter(entries)
        .map(one)
        .buffered(AT_ONCE)
        .try_collect()
        .await
}

/// An AI tool of a whole lorebook, done to each entry it is given.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum LoreTool {
    /// Keywords for an entry that has none.
    Keywords,
    /// Its words' grammar and spelling.
    Fix,
    /// Its words and keywords, into the language in `given`.
    Translate,
}

/// Entries of a lorebook to change by one tool.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct LoreRewrite {
    pub tool: LoreTool,
    /// The language for Translate.
    pub given: Option<String>,
    pub entries: Vec<LoreText>,
}

/// What the background model is told to write an entry's keywords.
const KEYWORDS: &str = "You write the keywords of one entry of a lorebook for roleplay: words or short names that, when one of them appears in the chat, show that the entry is wanted. Write three to six, in the entry's language, each as it would stand in a chat. Answer with the keywords alone, parted by commas: no title, no quotes, no other word.";

/// The keywords the background model writes for an entry of `text`.
async fn keywords_for(http: &Http, provider: &Provider, text: &str) -> anyhow::Result<Vec<String>> {
    let prompt = vec![
        PromptMessage::new(Role::System, KEYWORDS.to_string()),
        PromptMessage::new(Role::User, format!("<entry>\n{}\n</entry>", text.trim())),
    ];
    let answer = cleaned(&cw_provider::answer(http, provider, &prompt).await?, "");
    let mut keywords: Vec<String> = Vec::new();
    for word in answer.split([',', '\n', '\u{FF0C}', '\u{3001}', '\u{060C}']) {
        let word = word.trim().trim_matches(['"', '\'', '.', '*', '-']).trim();
        if !word.is_empty() && !keywords.iter().any(|kept| kept == word) {
            keywords.push(word.to_string());
        }
    }
    ensure!(
        !keywords.is_empty(),
        Fail::said(Code::ModelAnswer, "the background model wrote no keywords")
            .with("what", "keywords")
    );
    Ok(keywords.into_iter().take(8).collect())
}

/// The entries `asked` gives, each as `asked.tool` changes it, in their order.
pub async fn lore(
    http: &Http,
    provider: &Provider,
    asked: LoreRewrite,
) -> anyhow::Result<Vec<LoreText>> {
    let LoreRewrite {
        tool,
        given,
        entries,
    } = asked;
    let given = given.unwrap_or_default();
    if let LoreTool::Translate = tool {
        ensure!(
            !given.trim().is_empty(),
            Fail::said(Code::Needed, "the language is missing").with("what", "language")
        );
        return translate_lore(http, provider, entries, given.trim()).await;
    }
    let one = |entry: LoreText| async move {
        let mut entry = entry;
        // Words to work on; and keywords are written only where there are none.
        let keyworded = matches!(tool, LoreTool::Keywords) && !entry.keywords.is_empty();
        if entry.text.trim().is_empty() || keyworded {
            return Ok::<_, anyhow::Error>(entry);
        }
        match tool {
            LoreTool::Keywords => {
                entry.keywords = keywords_for(http, provider, &entry.text).await?
            }
            _ => {
                let asked = Rewrite {
                    text: entry.text.clone(),
                    tool: AiTool::Fix,
                    what: "lorebook entry".to_string(),
                    given: None,
                    card: None,
                };
                entry.text = ask(http, provider, &asked).await?;
            }
        }
        Ok(entry)
    };
    stream::iter(entries)
        .map(one)
        .buffered(AT_ONCE)
        .try_collect()
        .await
}

/// The answer without a code fence or `<text>` tags around it, unless the
/// text it changed was in them too.
fn cleaned(answer: &str, asked: &str) -> String {
    let mut text = answer.trim();
    let asked = asked.trim();
    if asked.starts_with("```") {
        return text.to_string();
    }
    if let Some(inner) = text.strip_prefix("```").and_then(|t| t.strip_suffix("```")) {
        // The fence's first line may name a language.
        text = inner
            .split_once('\n')
            .map_or(inner, |(_, rest)| rest)
            .trim();
    }
    if let Some(inner) = text
        .strip_prefix("<text>")
        .and_then(|t| t.strip_suffix("</text>"))
    {
        text = inner.trim();
    }
    text.to_string()
}

#[cfg(test)]
mod tests {
    use crate::rewrite::keywords_in;

    #[test]
    fn keywords_are_parted_by_any_comma_and_kept_only_as_many_as_asked() {
        assert_eq!(
            keywords_in("Wrack, Schiff", 2).unwrap(),
            ["Wrack", "Schiff"]
        );
        assert_eq!(
            keywords_in("\u{6C89}\u{8239}\u{FF0C}\u{8239}", 2)
                .unwrap()
                .len(),
            2
        );
        assert_eq!(keywords_in("Here are the keywords: Wrack, Schiff", 1), None);
    }
}

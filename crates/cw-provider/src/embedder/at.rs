//! A provider's search model (the kind Search of Settings › Providers): texts
//! turned into vectors by `POST <base>/embeddings` in OpenAI's form, with the
//! account's key for that address. A text goes in pieces of at most
//! `CHUNK_CHARS` characters, halved as this computer's model halves by tokens
//! (no provider tells its tokens). Its vectors are kept with `stamp`, the model,
//! its address and the account's entry of it, so that another model's are
//! read anew and no account's key reads another's texts. A text it refuses
//! (`TextRefused`, 400, 413 or 422) is that text's fault, not the model's.

use crate::{self as provider, Provider};
use anyhow::bail;
use cw_platform::http::Client;
use serde_json::json;

use futures_util::FutureExt;

use crate::embedder::{CHUNK_TOKENS, cut, vectors_in};

/// The most characters of a piece: about `CHUNK_TOKENS` at four characters
/// a token (Claude's estimate for English), well under the 8,191 tokens of
/// OpenAI's search models.
const CHUNK_CHARS: usize = CHUNK_TOKENS * 4;

/// A provider's search model: the account's entry of the provider, its
/// address, key and model.
#[derive(Clone, Debug)]
pub struct At {
    pub entry: i64,
    pub base_url: String,
    /// Empty for none.
    pub api_key: String,
    pub model: String,
}

/// A text the provider refused, not the model failing: kept without vectors.
#[derive(Debug)]
pub(crate) struct TextRefused(pub String);

impl std::fmt::Display for TextRefused {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for TextRefused {}

impl At {
    /// The search model of the account's `entry`, as `provider` asks it.
    pub fn of(entry: i64, provider: Provider) -> Self {
        Self {
            entry,
            base_url: provider.base_url,
            api_key: provider.api_key,
            model: provider.model,
        }
    }

    /// The name its vectors are kept with; `search::stamp_sql` writes the same.
    pub fn stamp(&self) -> String {
        format!("{} at {} #{}", self.model, self.base_url, self.entry)
    }

    /// `text` in pieces of at most `CHUNK_CHARS` characters, in their order;
    /// none of a text that is only space.
    pub fn chunks(&self, text: &str) -> Vec<String> {
        // Its measure never waits nor fails, so the cut is ready at once.
        let fits = |piece: String| async move { Ok(piece.chars().count() <= CHUNK_CHARS) };
        match cut(text, fits).now_or_never() {
            Some(Ok(pieces)) => pieces,
            _ => unreachable!("a cut by characters neither waits nor fails"),
        }
    }

    /// The vectors of `texts`, in their order, each of length one.
    pub async fn embed(&self, http: &Client, texts: &[String]) -> anyhow::Result<Vec<Vec<f32>>> {
        if texts.is_empty() {
            return Ok(Vec::new());
        }
        let request = http
            .post(format!("{}/embeddings", self.base_url))
            .json(&json!({ "model": self.model, "input": texts }));
        let whose = "the provider's search model";
        let answer = match provider::answered(request, &self.api_key, whose).await {
            Ok(answer) => answer,
            Err(failure) => match provider::refusal_of(&failure) {
                Some((400 | 413 | 422, refused)) => {
                    bail!(TextRefused(refused.to_string()))
                }
                _ => return Err(failure),
            },
        };
        vectors_in(&answer.json().await?, texts.len())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_long_text_is_halved_until_each_piece_fits() {
        let at = At {
            entry: 1,
            base_url: "http://x".into(),
            api_key: String::new(),
            model: "m".into(),
        };
        let text = "a".repeat(CHUNK_CHARS * 3);
        let pieces = at.chunks(&text);
        assert_eq!(pieces.len(), 4);
        assert!(pieces.iter().all(|piece| piece.len() <= CHUNK_CHARS));
        assert_eq!(pieces.concat(), text);
        assert!(at.chunks("  ").is_empty());
    }
}

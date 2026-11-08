//! A provider's voice (the kind Voice): a text read aloud by `POST
//! <base>/audio/speech` in OpenAI's form, with the account's key for that
//! address, its sound asked as `pcm` (16-bit mono at 24 kHz, as `RATE`), so the
//! page plays both alike. A text longer than `INPUT_CHARS` is asked in parts;
//! `read` hands the sound on in whole samples.
//!
//! Its voices (`voices`), listed while Voice is at a provider, are `at:<name>`
//! (`PREFIX`), kept where this computer's are. Found 2026-10-22: models.dev names
//! none; OpenAI and Groq list none by API (their documentation names 13 for
//! gpt-4o-mini-tts, 9 for tts-1; Orpheus's six English, four Arabic);
//! Kokoro-FastAPI answers `GET <base>/audio/voices` (`{"voices": [...]}`),
//! Together `GET <base>/voices` (`{"data": [{"model", "voices"}]}`). Any other
//! is asked both ways; one listing none is asked without a voice. The voice sent
//! (`pick`) is the first asked that it lists, else its first.

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use cw_platform::http::{Client, Response};
use cw_provider::{self as provider, Provider};
use futures_util::{Stream, StreamExt};
use serde_json::json;

/// What a provider's voice's id starts with among the account's voices.
pub const PREFIX: &str = "at:";

/// OpenAI's voices for gpt-4o-mini-tts, the first nine also tts-1's and tts-1-hd's.
const OPENAI: [&str; 13] = [
    "alloy", "ash", "coral", "echo", "fable", "onyx", "nova", "sage", "shimmer", "ballad", "verse",
    "marin", "cedar",
];

/// The voices a provider's documentation names for `model` at `base_url`,
/// where its API lists none.
fn documented(base_url: &str, model: &str) -> Option<Vec<String>> {
    let host = base_url.split("://").nth(1)?.split('/').next()?;
    let names: &[&str] = match host {
        "api.openai.com" if model.starts_with("tts-1") => &OPENAI[..9],
        "api.openai.com" => &OPENAI,
        "api.groq.com" if model.contains("orpheus-arabic") => {
            &["fahad", "sultan", "lulwa", "noura"]
        }
        "api.groq.com" if model.contains("orpheus") => {
            &["autumn", "diana", "hannah", "austin", "daniel", "troy"]
        }
        _ => return None,
    };
    Some(names.iter().map(|name| name.to_string()).collect())
}

/// The voices named in a server's answer: `{"voices": [...]}`, or the entry of
/// `model` in `{"data": [{"model", "voices"}]}`; a voice is its name, or an
/// object's `name`, `id` or `voice_id`.
fn named(answer: &serde_json::Value, model: &str) -> Vec<String> {
    let voices = answer.get("voices").or_else(|| {
        answer
            .get("data")?
            .as_array()?
            .iter()
            .find(|entry| entry.get("model").and_then(|m| m.as_str()) == Some(model))?
            .get("voices")
    });
    let Some(voices) = voices.and_then(|voices| voices.as_array()) else {
        return Vec::new();
    };
    voices
        .iter()
        .filter_map(|voice| {
            voice.as_str().or_else(|| {
                ["name", "id", "voice_id"]
                    .iter()
                    .find_map(|key| voice.get(key)?.as_str())
            })
        })
        .map(str::to_string)
        .collect()
}

/// The voices `provider` reads in, as its documentation names them or its
/// server lists them; none where neither does. Why not, where its server
/// cannot be reached or fails (5xx), so that a voice picked is not passed over.
pub async fn voices(http: &Client, provider: &Provider) -> anyhow::Result<Vec<String>> {
    if let Some(known) = documented(&provider.base_url, &provider.model) {
        return Ok(known);
    }
    for path in ["audio/voices", "voices"] {
        let request = http.get(format!("{}/{path}", provider.base_url));
        let answer = provider::send(provider::keyed(request, &provider.api_key))
            .await
            .context(
                Fail::said(Code::Unreachable, "the provider's voices cannot be reached")
                    .with("whose", "provider_voices"),
            )?;
        let status = answer.status();
        if status.is_server_error() {
            bail!(
                Fail::said(
                    Code::Answered,
                    format!("the provider's voices answered {status}")
                )
                .with("whose", "provider_voices")
                .with("status", status.to_string())
            );
        }
        // Any other answer that is no list of voices says this way lists none.
        if !status.is_success() {
            continue;
        }
        let Ok(body) = answer.json::<serde_json::Value>().await else {
            continue;
        };
        let found = named(&body, &provider.model);
        if !found.is_empty() {
            return Ok(found);
        }
    }
    Ok(Vec::new())
}

/// The voice to send of those `listed`: the first of `asked` (ids: `PREFIX`
/// and the name) that is listed, else the first listed; none where none is.
pub fn pick<'a>(listed: &'a [String], asked: &[Option<&str>]) -> Option<&'a str> {
    asked
        .iter()
        .flatten()
        .filter_map(|id| id.strip_prefix(PREFIX))
        .find_map(|name| listed.iter().find(|voice| *voice == name))
        .or(listed.first())
        .map(String::as_str)
}

/// The most characters asked at once: OpenAI's speech takes 4,096.
const INPUT_CHARS: usize = 4000;

/// `text` in parts of at most `INPUT_CHARS` characters, cut after a space
/// where one is, in their order.
fn parts(text: &str) -> Vec<String> {
    let mut parts = Vec::new();
    let (mut part, mut length) = (String::new(), 0);
    for word in text.trim().split_inclusive(char::is_whitespace) {
        for piece in word.chars().collect::<Vec<_>>().chunks(INPUT_CHARS) {
            if length + piece.len() > INPUT_CHARS {
                parts.push(std::mem::take(&mut part));
                length = 0;
            }
            part.extend(piece);
            length += piece.len();
        }
    }
    if !part.trim().is_empty() {
        parts.push(part);
    }
    parts
}

/// The sound of `provider` reading `text` aloud at `speed` (1 the usual), in
/// whole samples as it comes, in `voice` (none: the server's own); why it
/// refused where it refused the first part. A later part refused ends the sound there.
pub async fn read(
    http: &Client,
    provider: &Provider,
    text: &str,
    speed: f64,
    voice: Option<String>,
) -> anyhow::Result<impl Stream<Item = std::io::Result<Vec<u8>>> + use<>> {
    let mut parts = parts(text).into_iter();
    let first = parts.next().context(
        Fail::said(Code::Needed, "there is nothing to read").with("what", "text_to_read"),
    )?;
    let answer = speech(http, provider, &first, speed, voice.as_deref()).await?;
    let (http, provider) = (http.clone(), provider.clone());
    let rest = futures_util::stream::iter(parts)
        .then(move |part| {
            let (http, provider, voice) = (http.clone(), provider.clone(), voice.clone());
            async move { speech(&http, &provider, &part, speed, voice.as_deref()).await }
        })
        .map(|answer| answer.map_err(std::io::Error::other));
    let answers = futures_util::stream::once(async { Ok(answer) }).chain(rest);
    Ok(answers
        .map(|answer| match answer {
            Ok(answer) => samples(answer).left_stream(),
            Err(failure) => futures_util::stream::once(async { Err(failure) }).right_stream(),
        })
        .flatten()
        .scan(false, |ended, piece| {
            // After a failure nothing more is read.
            let next = (!*ended).then_some(piece);
            if matches!(next, Some(Err(_))) {
                *ended = true;
            }
            async move { next }
        }))
}

/// Asks `provider` to read `text` aloud at `speed` (1 the usual) in `voice`;
/// its answer once the provider has begun it, else why it refused.
async fn speech(
    http: &Client,
    provider: &Provider,
    text: &str,
    speed: f64,
    voice: Option<&str>,
) -> anyhow::Result<Response> {
    let mut asked = json!({
        "model": provider.model,
        "input": text,
        "response_format": "pcm",
        "speed": speed,
    });
    if let Some(voice) = voice {
        asked["voice"] = voice.into();
    }
    let request = http
        .post(format!("{}/audio/speech", provider.base_url))
        .json(&asked);
    provider::answered(request, &provider.api_key, "the provider's voice").await
}

/// The sound of `answer` as it comes, each piece whole samples: a byte left
/// over goes with the next piece.
fn samples(answer: Response) -> impl Stream<Item = std::io::Result<Vec<u8>>> {
    futures_util::stream::unfold(Some((answer, Vec::new())), |state| async move {
        let (mut answer, mut left) = state?;
        loop {
            match answer.chunk().await {
                Ok(Some(piece)) => {
                    left.extend_from_slice(&piece);
                    let whole = left.len() / 2 * 2;
                    if whole == 0 {
                        continue;
                    }
                    let rest = left.split_off(whole);
                    return Some((Ok(left), Some((answer, rest))));
                }
                Ok(None) => return None,
                Err(failure) => return Some((Err(std::io::Error::other(failure)), None)),
            }
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_long_text_is_asked_in_parts_cut_at_spaces() {
        let text = "word ".repeat(1700);
        let parts = parts(&text);
        assert_eq!(parts.len(), 3);
        assert!(
            parts
                .iter()
                .all(|part| part.chars().count() <= INPUT_CHARS && part.starts_with("word"))
        );
        assert_eq!(parts.concat(), text.trim());
        assert_eq!(crate::at::parts(&"x".repeat(INPUT_CHARS + 1)).len(), 2);
    }

    #[test]
    fn the_voices_are_read_from_each_known_form_of_answer() {
        let kokoro = json!({ "voices": ["af_bella", "am_adam"] });
        assert_eq!(named(&kokoro, "kokoro"), ["af_bella", "am_adam"]);
        let together = json!({ "data": [
            { "model": "other", "voices": [{ "name": "x" }] },
            { "model": "orpheus", "voices": [{ "name": "tara" }, { "id": "leo" }] },
        ] });
        assert_eq!(named(&together, "orpheus"), ["tara", "leo"]);
        assert!(named(&json!({ "error": "no" }), "orpheus").is_empty());
        let openai = |model| {
            documented("https://api.openai.com/v1", model)
                .unwrap()
                .len()
        };
        assert_eq!((openai("tts-1"), openai("gpt-4o-mini-tts")), (9, 13));
        let groq = documented(
            "https://api.groq.com/openai/v1",
            "canopylabs/orpheus-v1-english",
        );
        assert_eq!(groq.unwrap()[0], "autumn");
        assert!(documented("http://localhost:8880/v1", "kokoro").is_none());
        assert!(documented("https://api.groq.com/openai/v1", "playai-tts").is_none());
    }

    #[test]
    fn the_voice_sent_is_the_first_asked_that_is_listed_else_the_first_listed() {
        let listed = ["nova".to_string(), "echo".to_string()];
        let asked = [None, Some("marius"), Some("at:echo")];
        assert_eq!(pick(&listed, &asked), Some("echo"));
        assert_eq!(
            pick(&listed, &[Some("at:gone"), Some("alba")]),
            Some("nova")
        );
        assert_eq!(pick(&[], &[Some("at:echo")]), None);
    }
}

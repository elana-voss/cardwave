//! Pictures made by a model. The image model is the images kind of
//! `provider::kinds`, at any provider of the account (`get` as the settings
//! show it). Which API an address speaks, and its image models, are asked by
//! `provider::images` (`api_of`, `listed`).
//!
//! A picture in a chat (`asked_of`, `make`, `keep`): the worker model writes
//! its words from the character and the newest messages, or the user's (the
//! Flutter app's `scene.txt`, `words.txt`); it is kept with a message whose
//! text tells the chat model what was sent (`SENT`); "Make again" makes a new
//! version (`keep_again`). ComfyUI gets its default workflow with the chosen
//! checkpoint, 1024 by 1024, or the user's saved one (`comfy`). A card's
//! picture (`asked_of_card`, `make_shaped`) is asked upright (`Shape`) where
//! the model takes that size.

pub mod comfy;
pub mod graph;
mod sdapi;

use anyhow::{Context, bail, ensure};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_platform::http::Client;
use cw_prompt::{PromptMessage, Role};
use cw_provider::images::{ImageApi, api_of};
use cw_provider::images::{Picture, Whom};
use cw_provider::kinds::{self, Kind};
use cw_provider::models::ListModels;
use cw_provider::{self as provider, keyed};
use serde::Serialize;
use serde_json::{Value, json};
use ts_rs::TS;

use crate::chats::{self, NewMessage, PromptInputs};

/// What the worker model is asked for the words of a picture: of what the
/// user typed, or of the newest messages.
pub const WORDS: &str = include_str!("images/words.txt");
pub const SCENE: &str = include_str!("images/scene.txt");
/// What the worker model is asked for the words of a card's picture, of the whole card.
pub const CARD: &str = include_str!("images/card.txt");

/// The most bytes of a picture's answer read: a picture as base64 in JSON.
const PICTURE_LIMIT: usize = 64 << 20;
/// How many of the newest messages the words for a picture of the scene are written from.
const HISTORY: usize = 6;
/// The most characters of the words a picture is made from.
const WORDS_LIMIT: usize = 1000;
/// What the message of a picture says, with the words it was made from.
const SENT: &str = "*(sends a picture: {})*";

/// The image model as the account's settings show it.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct ImageModelView {
    pub model: String,
    /// Its own address; none where it is at the chat provider's.
    pub base_url: Option<String>,
    /// Whether a key of its own is kept.
    pub has_key: bool,
    /// The end of that key, as the chat provider's is told.
    pub key_end: Option<String>,
}

/// What the pictures need of the database, which `cw_store::images` gives.
pub trait Storage {
    /// Keeps a picture with the message that shows it.
    fn keep_picture(&self, message_id: i64, data: &[u8], prompt: &str) -> anyhow::Result<()>;
    /// The picture of a message of the user's.
    fn picture(&self, user: i64, message_id: i64) -> anyhow::Result<Option<Vec<u8>>>;
}

/// The address and key a form's list of image models is asked with: the key
/// typed, else the image model's where it is at that address, else the one
/// kept for it (`provider::whom`). A kept key goes only to its own address.
pub fn whom_listed(
    db: &dyn crate::chats::Storage,
    user: i64,
    asked: ListModels,
) -> anyhow::Result<(String, String)> {
    let base_url = provider::address(&asked.base_url)?;
    let key = match provider::key(asked.api_key)? {
        Some(key) => key,
        None => match kinds::provider_of(db, user, Kind::Images)?
            .filter(|kept| kept.base_url == base_url)
        {
            Some(kept) => kept.api_key,
            None => provider::whom(db, user, &base_url, None)?.1,
        },
    };
    Ok((base_url, key))
}

/// The account's image model, if one is set up: the images kind, whose
/// address is told where it is another provider's than the chat's.
pub fn get(db: &dyn crate::chats::Storage, user: i64) -> anyhow::Result<Option<ImageModelView>> {
    let Some(picked) = kinds::picked(db, user, Kind::Images)? else {
        return Ok(None);
    };
    let chat = kinds::picked(db, user, Kind::Chat)?.map(|chat| chat.entry);
    let own = (chat != Some(picked.entry))
        .then(|| kinds::entry(db, user, picked.entry))
        .transpose()?;
    Ok(Some(ImageModelView {
        model: picked.model,
        has_key: own.as_ref().is_some_and(|own| !own.api_key.is_empty()),
        key_end: own.as_ref().and_then(|own| provider::key_end(&own.api_key)),
        base_url: own.map(|own| own.base_url),
    }))
}

/// Whom the account's pictures are asked of.
pub fn whom(db: &dyn crate::chats::Storage, user: i64) -> anyhow::Result<Whom> {
    let picked = kinds::picked(db, user, Kind::Images)?.context(
        Fail::said(
            Code::NotPossible,
            "no image model is set up yet: set one up in Settings › Models › Images",
        )
        .with("what", "no_image_model"),
    )?;
    let entry = kinds::entry(db, user, picked.entry)?;
    Ok(Whom {
        provider: kinds::whose(&entry.name, &entry.base_url),
        base_url: entry.base_url,
        api_key: entry.api_key,
        model: picked.model,
        workflow: entry.workflow,
    })
}

/// What the worker model is asked for the words a picture is made from: of
/// `words` the user typed, or, where there are none, of the newest messages.
pub fn asked_of(inputs: &PromptInputs, words: Option<&str>) -> Vec<PromptMessage> {
    let char_name = inputs.character.display_name();
    let user_name = inputs.state.persona_name.as_str();
    let named = |text: &str| {
        text.replace("{{char}}", char_name)
            .replace("{{user}}", user_name)
    };
    let mut asked = String::new();
    if !inputs.character.description.trim().is_empty() {
        asked.push_str(&format!(
            "Character description:\n{}\n\n",
            named(&inputs.character.description)
        ));
    }
    let template = match words.map(str::trim).filter(|words| !words.is_empty()) {
        Some(words) => WORDS.replace("{{subject}}", words),
        None => {
            let newest: Vec<_> = inputs
                .state
                .messages
                .iter()
                .filter(|message| message.complete && !message.content.trim().is_empty())
                .collect();
            let newest = &newest[newest.len().saturating_sub(HISTORY)..];
            if !newest.is_empty() {
                asked.push_str("Recent chat history:\n");
                for message in newest {
                    let who = match message.role {
                        Role::User => user_name,
                        _ => char_name,
                    };
                    asked.push_str(&format!("{who}: {}\n", message.content));
                }
                asked.push('\n');
            }
            SCENE.to_string()
        }
    };
    asked.push_str(&named(&template));
    vec![PromptMessage::new(Role::User, asked)]
}

/// What the worker model is asked for the words of a card's picture
/// ("Make a picture"): the whole `card` (`describe::card_json`), and which
/// image model draws it, `model`, so that it writes them as that one reads
/// them best.
pub fn asked_of_card(card: &Value, character: &str, model: &str) -> Vec<PromptMessage> {
    let asked = CARD
        .replace("{{char}}", character)
        .replace("{{model}}", model);
    vec![
        PromptMessage::new(Role::System, asked),
        PromptMessage::new(
            Role::User,
            format!(
                "<card>
{card}
</card>"
            ),
        ),
    ]
}

/// The words for the image model of the worker model's answer: without a
/// reasoning model's `<think>` part, the space and quotes around them, and
/// at most `WORDS_LIMIT` characters.
pub fn words_of(answer: &str) -> anyhow::Result<String> {
    let answer = answer
        .rsplit_once("</think>")
        .map_or(answer, |(_, after)| after);
    let answer: String = answer.trim().chars().take(WORDS_LIMIT).collect();
    let words = answer
        .trim()
        .trim_matches(['"', '\'', '`'])
        .trim()
        .to_string();
    ensure!(
        !words.is_empty(),
        Fail::said(
            Code::ModelAnswer,
            "the worker model wrote no words for the picture"
        )
        .with("what", "picture_words")
    );
    Ok(words)
}

/// The shape a picture is asked in.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Shape {
    /// As the model makes it by itself, mostly square: a chat's.
    Own,
    /// Two wide and three high, or near it, where the model is known to take
    /// such a size: a card's.
    Upright,
}

/// The size asked of OpenAI's image API for `shape`, where the model is known
/// to take one: GPT Image 1024 by 1536, DALL-E 3 1024 by 1792. Others are
/// asked for none, as a size they do not know is refused.
fn openai_size(model: &str, shape: Shape) -> Option<&'static str> {
    let model = model.to_ascii_lowercase();
    match shape {
        Shape::Own => None,
        Shape::Upright if model.contains("gpt-image") => Some("1024x1536"),
        Shape::Upright if model.contains("dall-e-3") => Some("1024x1792"),
        Shape::Upright => None,
    }
}

/// Has the image model make a picture of `prompt`.
pub async fn make(http: &Client, whom: &Whom, prompt: &str) -> anyhow::Result<Picture> {
    make_shaped(http, whom, prompt, Shape::Own).await
}

/// [`make`] in the shape `shape`.
pub async fn make_shaped(
    http: &Client,
    whom: &Whom,
    prompt: &str,
    shape: Shape,
) -> anyhow::Result<Picture> {
    let api = api_of(http, &whom.base_url, &whom.api_key).await;
    made(http, api, whom, prompt, shape).await
}

/// [`make`] at an address that speaks `api`.
pub async fn make_with(
    http: &Client,
    api: ImageApi,
    whom: &Whom,
    prompt: &str,
) -> anyhow::Result<Picture> {
    made(http, api, whom, prompt, Shape::Own).await
}

/// [`make_shaped`] at an address that speaks `api`.
async fn made(
    http: &Client,
    api: ImageApi,
    whom: &Whom,
    prompt: &str,
    shape: Shape,
) -> anyhow::Result<Picture> {
    let data = match api {
        ImageApi::ComfyUi => crate::images::comfy::make(http, whom, prompt, shape).await?,
        ImageApi::Automatic1111 => crate::images::sdapi::make(http, whom, prompt, shape).await?,
        api => {
            let (path, body) = match api {
                ImageApi::OpenRouter => {
                    ("images", json!({ "model": whom.model, "prompt": prompt }))
                }
                _ => {
                    let mut body = json!({ "model": whom.model, "prompt": prompt, "n": 1 });
                    if let Some(size) = openai_size(&whom.model, shape) {
                        body["size"] = json!(size);
                    }
                    ("images/generations", body)
                }
            };
            let request = keyed(
                http.post(format!("{}/{path}", whom.base_url)),
                &whom.api_key,
            )
            .json(&body);
            let said = read(
                provider::send(request).await.context(
                    Fail::said(Code::Unreachable, "the image model cannot be reached")
                        .with("whose", "image_model"),
                )?,
            )
            .await?;
            let said: Value = serde_json::from_slice(&said).context(
                Fail::said(Code::NotReadable, "the image model's answer cannot be read")
                    .with("what", "image_model_answer"),
            )?;
            let first = &said["data"][0];
            if let Some(b64) = first["b64_json"].as_str() {
                STANDARD.decode(b64).context(
                    Fail::said(
                        Code::NotReadable,
                        "the image model's picture cannot be read",
                    )
                    .with("what", "image_model_picture"),
                )?
            } else if let Some(url) = first["url"].as_str() {
                // DALL-E 3 answers with an address the picture is at for an hour:
                // fetched only where it is a web site's, and not sent on from
                // there, so that an answer cannot have this computer ask
                // its own network.
                ensure!(
                    url.starts_with("https://"),
                    Fail::said(
                        Code::ModelAnswer,
                        "the image model's picture is at an address that is not fetched"
                    )
                    .with("what", "picture_address")
                );
                read(
                    fetched(url).await.context(
                        Fail::said(Code::Unreachable, "the picture cannot be fetched")
                            .with("whose", "picture_address"),
                    )?,
                )
                .await?
            } else {
                bail!(
                    Fail::said(
                        Code::ModelAnswer,
                        "the image model answered without a picture"
                    )
                    .with("what", "no_picture")
                );
            }
        }
    };
    let mime = mime_of(&data).context(
        Fail::said(Code::ModelAnswer, "the image model's answer is no picture")
            .with("what", "no_picture"),
    )?;
    Ok(Picture { data, mime })
}

/// The answer of the address a picture is at, not followed anywhere from there.
/// A bare name is sent, as some of these refuse a call without one (Together's, 403).
async fn fetched(url: &str) -> anyhow::Result<cw_platform::http::Response> {
    let once = cw_platform::http::client(cw_platform::http::Make {
        redirects: cw_platform::http::Redirects::None,
        agent: Some(provider::app_name::NAME),
        ..Default::default()
    })?;
    Ok(once.get(url).send().await?)
}

/// The type of a picture a browser shows, by its first bytes.
fn mime_of(data: &[u8]) -> Option<&'static str> {
    match image::guess_format(data).ok()? {
        image::ImageFormat::Png => Some("image/png"),
        image::ImageFormat::Jpeg => Some("image/jpeg"),
        image::ImageFormat::WebP => Some("image/webp"),
        image::ImageFormat::Gif => Some("image/gif"),
        _ => None,
    }
}

/// The body of a successful answer, or why it failed.
async fn read(answer: cw_platform::http::Response) -> anyhow::Result<Vec<u8>> {
    let mut answer = provider::succeeded(answer, "the image model").await?;
    Ok(provider::body(&mut answer, PICTURE_LIMIT).await)
}

/// Keeps `picture` as a message of `speaker` (the chat's first character
/// where none is named) at the end of the chat, and answers its ID.
pub fn keep(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    speaker_id: Option<i64>,
    prompt: &str,
    picture: &Picture,
) -> anyhow::Result<i64> {
    let content = SENT.replace("{}", prompt);
    let new = NewMessage {
        role: Role::Assistant,
        speaker_id,
        content: &content,
        complete: true,
    };
    let id = chats::append(db, user, chat_id, &new)?;
    db.keep_picture(id, &picture.data, prompt)?;
    Ok(id)
}

/// Keeps `picture`, made anew of `prompt` ("Make again"), as another version
/// of the picture message `message_id`, which the chat shows from then on;
/// answers its ID. Not in a chat in the Trash or while a reply is written.
pub fn keep_again(
    db: &dyn crate::chats::Storage,
    user: i64,
    message_id: i64,
    prompt: &str,
    picture: &Picture,
) -> anyhow::Result<i64> {
    let content = SENT.replace("{}", prompt);
    let id = chats::add_swipe(db, user, message_id, &content, true)?;
    db.keep_picture(id, &picture.data, prompt)?;
    Ok(id)
}

/// The picture of a message of the user's, with its type.
pub fn picture(db: &dyn Storage, user: i64, message_id: i64) -> anyhow::Result<Picture> {
    let data = db.picture(user, message_id)?;
    let data = data.ok_or(NotFound("picture"))?;
    // Only a picture is kept.
    let mime = mime_of(&data).unwrap_or("image/png");
    Ok(Picture { data, mime })
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};
    use std::net::TcpListener;

    use super::*;

    #[tokio::test]
    async fn the_address_of_a_picture_is_asked_with_the_bare_name() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let heard = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut asked = [0; 4096];
            let read = stream.read(&mut asked).unwrap();
            let answer = b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
            stream.write_all(answer).unwrap();
            String::from_utf8_lossy(&asked[..read]).to_lowercase()
        });
        fetched(&format!("http://{address}/a.png")).await.unwrap();
        let heard = heard.join().unwrap();
        assert!(heard.contains("\r\nuser-agent: cardwave\r\n"), "{heard}");
    }
}

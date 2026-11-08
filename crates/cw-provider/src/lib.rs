//! cw-provider: asking a model at a server that speaks OpenAI's chat-completions
//! API. [`ask`]/[`ask_with`] stream a reply, thinking told apart ([`thinking`]);
//! [`answer`] waits for a whole one, [`object`] reads its JSON, [`Call`] is a
//! tool call, [`form`] asks for an answer of fixed fields, [`reply`] reads a
//! reply. Every request goes through [`send`], with the client [`Http`],
//! which carries the server's pretend answers (`pretend`) and hands This
//! computer's address to [`local`]; [`answered`] sends with the key ([`keyed`]).
//! Modules: [`app_name`] Cardwave's name on a call, set in [`send`], [`list`] known providers, [`places`] an unknown one's API, [`models`]
//! a provider's list, [`check`] a small question, [`presets`], [`kinds`] the
//! account's providers, [`facts`]/[`catalog`] what kind a model is, [`images`]
//! what an image service offers, [`embedder`] the search model.
//! Storage: the crate's [`Storage`] (kinds' and presets'), taken as `&dyn`.
//! Traps: a stored key goes only to the address it was stored with (`whom`);
//! "the stored provider" is the chat kind's with the account's reply values
//! (`get`); a reply's length caps an answer only where the model does not think.

pub mod app_name;
pub mod catalog;
pub mod check;
pub mod facts;
pub mod fit;
pub mod form;
pub mod images;
pub mod kinds;
pub mod list;
pub mod local;
pub mod models;
pub mod models_dev;
pub mod picks;
pub mod places;
pub mod presets;
pub mod pretend;
pub mod reply;
pub(crate) mod subscription;
pub(crate) mod suggested;
pub mod thinking;

use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Detail, ErrorBody, Fail};
use cw_platform::http::header::CONTENT_TYPE;
use cw_platform::http::{Client, RequestBuilder, Response, Url};
use cw_prompt::PromptMessage;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tokio::time::timeout;
use ts_rs::TS;

use kinds::{Kind, NoThinking};
pub use reply::{Call, Piece, Reply};

/// How long one of the two answers may take, whole.
const ANSWER_LIMIT: Duration = Duration::from_secs(300);

/// Context window assumed when the user has set none, as in the Flutter app.
const DEFAULT_CONTEXT_SIZE: usize = 128_000;

/// A reply longer than this is cut off, and so is a single line of the stream:
/// neither is a chat reply any more.
pub(crate) const REPLY_LIMIT: usize = 1 << 20;
/// How much of an error answer is read to find out what went wrong.
const ERROR_BODY_LIMIT: usize = 16 * 1024;
const CONNECT_TIMEOUT: Duration = Duration::from_secs(15);
/// How long the server may stay silent. A local model can take minutes to read
/// a long prompt before its first word.
pub const SILENCE_LIMIT: Duration = Duration::from_secs(300);

/// How much of a stored key is told, for the user to know the key by: its
/// last characters, and only of a key so long that they give little of it away.
/// First run shows as much of a key that is typed and not stored yet, by the
/// same two numbers in `web/src/views/setup.ts`.
const KEY_END: usize = 4;
const KEY_END_FROM: usize = 16;

/// The most characters a name the user gives may have: a provider's, and a
/// preset's.
pub const NAME_LIMIT: usize = 60;

/// The user has no provider yet, so there is no model to ask (424).
pub const NOT_SET_UP: Fail = Fail::new(Code::NoProvider);

/// A provider refused a request, with its status and what it said; `whose`
/// names what was asked ("the model's server"), logged. Its `error` names the status
/// with its reason ("429 Too Many Requests"); its details name `whose` and
/// the `refusal` by the UI's words, which tell the user what to do: by the
/// status, and for a model gone or a message too long by the provider's words.
pub fn refused(whose: &'static str, status: u16, reason: String) -> Fail {
    let named = cw_platform::http::StatusCode::from_u16(status)
        .map_or(status.to_string(), |s| s.to_string());
    let words = reason.to_lowercase();
    let says = |any: &[&str]| any.iter().any(|said| words.contains(said));
    let refusal = match status {
        401 | 403 => "key",
        402 => "paid",
        429 => "busy",
        502..=504 => "down",
        500..=599 => "fault",
        400 | 404 | 413 | 422
            if says(&[
                "context length",
                "context_length",
                "context window",
                "too long",
            ]) =>
        {
            "too_long"
        }
        400 | 404
            if says(&["model_not_found", "no such model", "model not found"])
                || (words.contains("model") && says(&["does not exist", "not found"])) =>
        {
            "no_model"
        }
        _ => "other",
    };
    // Logged, as the user is told only the UI's words for it.
    let said = format!("{whose} answered {named}: {reason}");
    tracing::warn!("{said}");
    Fail::said(Code::ProviderRefused, said)
        .with("whose", ui_name(whose))
        .with("refusal", refusal)
        .with("status", status)
        .with("reason", reason)
}

/// `whose` (a failure's English words for what was asked) as the UI's words name it.
fn ui_name(whose: &str) -> &'static str {
    match whose {
        "the provider's voice" => "provider_voice",
        "the provider's search model" => "provider_search_model",
        "the image model" => "image_model",
        _ => "model_server",
    }
}

/// The status a provider refused with, and its refusal, where `failure` is one ([`refused`]).
pub fn refusal_of(failure: &anyhow::Error) -> Option<(u16, Fail)> {
    let status = |fail: &Fail| match (fail.code, fail.details.get("status")) {
        (Code::ProviderRefused, Some(Detail::Number(status))) => u16::try_from(*status).ok(),
        _ => None,
    };
    let outer = failure.downcast_ref::<Fail>().into_iter();
    let chained = failure.chain().filter_map(|e| e.downcast_ref::<Fail>());
    outer
        .chain(chained)
        .find_map(|fail| Some((status(fail)?, fail.clone())))
}

/// Whether `failure` is the provider saying it no longer offers the model ([`refused`]'s "no_model").
pub fn no_longer_offered(failure: &anyhow::Error) -> bool {
    refusal_of(failure).is_some_and(|(_, fail)| {
        matches!(fail.details.get("refusal"), Some(Detail::Text(said)) if said == "no_model")
    })
}

/// What goes along with a prompt. A value left unset is not sent, so the
/// provider's own default applies. These are the parameters the Flutter app
/// sends to an OpenAI-compatible server, with its ranges.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize, TS)]
#[ts(export, optional_fields = nullable)]
pub struct Sampling {
    /// The model's context window in tokens, which the prompt is fitted into;
    /// 128000 when unset.
    pub context_size: Option<usize>,
    pub temperature: Option<f64>,
    pub top_p: Option<f64>,
    pub frequency_penalty: Option<f64>,
    pub presence_penalty: Option<f64>,
    pub seed: Option<i64>,
}

impl Sampling {
    /// The context window the prompt is fitted into.
    pub fn context(&self) -> usize {
        self.context_size.unwrap_or(DEFAULT_CONTEXT_SIZE)
    }

    /// What is sent along with a prompt, under the names of OpenAI's API.
    fn sent(&self) -> impl Iterator<Item = (&'static str, Value)> {
        let chosen = [
            ("temperature", self.temperature.map(Value::from)),
            ("top_p", self.top_p.map(Value::from)),
            ("frequency_penalty", self.frequency_penalty.map(Value::from)),
            ("presence_penalty", self.presence_penalty.map(Value::from)),
            ("seed", self.seed.map(Value::from)),
        ];
        chosen
            .into_iter()
            .filter_map(|(name, value)| Some((name, value?)))
    }

    pub(crate) fn check(&self) -> anyhow::Result<()> {
        let within = |name: &str, value: Option<f64>, min: f64, max: f64| {
            ensure!(
                value.is_none_or(|value| (min..=max).contains(&value)),
                Fail::said(
                    Code::OutOfRange,
                    format!("{name} must be from {min} to {max}")
                )
                .with("what", "provider_setting")
                .with("name", name.to_string())
                .with("min", min.to_string())
                .with("max", max.to_string())
            );
            Ok(())
        };
        within("temperature", self.temperature, 0.0, 2.0)?;
        within("top_p", self.top_p, 0.0, 1.0)?;
        within("frequency_penalty", self.frequency_penalty, -2.0, 2.0)?;
        within("presence_penalty", self.presence_penalty, -2.0, 2.0)?;
        ensure!(
            self.context() >= 512,
            Fail::said(
                Code::OutOfRange,
                "the context size must be at least 512 tokens"
            )
            .with("what", "context_size")
        );
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Provider {
    /// Address of the API up to its version part, without a slash at the end:
    /// `https://api.openai.com/v1`.
    pub base_url: String,
    /// Empty for a server that asks for none.
    pub api_key: String,
    pub model: String,
    pub sampling: Sampling,
    /// What the user calls it, for one whose address is not on the list;
    /// empty for none.
    pub name: String,
    /// How its thinking is turned off, where the user did.
    pub thinking_off: Option<NoThinking>,
    /// The most tokens of each answer (`limited`); none leaves it to the
    /// provider.
    pub reply_limit: Option<u32>,
    /// Whether an answer of its model carried thinking (`kinds::saw_thinking`).
    pub seen_thinking: bool,
}

impl Provider {
    /// The provider with `length` (a chat's Reply length) as the most tokens
    /// of each of its answers, where its model does not think (`thinks`). A
    /// model that thinks is given none, as its thinking would count against it.
    pub fn limited(self, length: u32) -> Provider {
        Provider {
            reply_limit: (!self.thinks()).then_some(length),
            ..self
        }
    }

    /// Whether its model thinks: its thinking not turned off, and known to
    /// think (`facts::guessed`) or seen thinking. The chat's side panel tells it too.
    pub fn thinks(&self) -> bool {
        self.thinking_off.is_none() && (self.seen_thinking || facts::guessed(&self.model).thinks)
    }

    /// The end of the key, by which the user knows which key it is. A short
    /// key has none to tell, and neither has a provider without a key.
    pub fn key_end(&self) -> Option<String> {
        key_end(&self.api_key)
    }
}

/// The end of `key` that is told, for the image model's key too.
pub fn key_end(key: &str) -> Option<String> {
    let length = key.chars().count();
    (length >= KEY_END_FROM).then(|| key.chars().skip(length - KEY_END).collect())
}

/// What the provider needs of the database, which `cw_store::provider` gives:
/// also what the kinds and the presets need.
pub trait Storage: kinds::Storage + presets::Storage {
    /// Stores first run's models at once, all or nothing: at the chat's own
    /// entry where the address stays (a key typed changes it there, and its
    /// presets with it), else at the entry of that address with the key typed
    /// or the first kept there, added where there is none; the name where it
    /// is another than the entry's (at another than the chat's, only one
    /// typed), the values where given, then the chat model, the background
    /// model where given (empty: none) and the image model where given.
    fn set_provider(&self, user: i64, new: &Stored) -> anyhow::Result<()>;
    /// Lets go of the providers that presets took the place of: `user`'s, or everyone's.
    fn forget_replaced_providers(&self, user: Option<i64>) -> anyhow::Result<()>;
}

/// The stored provider: the chat kind's, with the account's values.
pub fn get(db: &dyn kinds::Storage, user: i64) -> anyhow::Result<Option<Provider>> {
    kinds::provider_of(db, user, Kind::Chat)
}

/// Why there is no model to ask: no provider at all, or (`what` chat_model)
/// providers but no chat model picked, as after adding one in Settings at first run.
pub fn not_set_up(db: &dyn kinds::Storage, user: i64) -> anyhow::Result<Fail> {
    Ok(if db.entries(user)?.is_empty() {
        NOT_SET_UP
    } else {
        NOT_SET_UP.with("what", "chat_model")
    })
}

/// The chat model's provider, else the failure telling why there is none.
pub fn chat(db: &dyn kinds::Storage, user: i64) -> anyhow::Result<Provider> {
    match get(db, user)? {
        Some(chat) => Ok(chat),
        None => Err(not_set_up(db, user)?.into()),
    }
}

/// The provider the app's own work is asked of ([`for_work`]), else the
/// failure telling why there is none.
pub fn worker(db: &dyn Storage, user: i64) -> anyhow::Result<Provider> {
    match for_work(db, user)? {
        Some(work) => Ok(work),
        None => Err(not_set_up(db, user)?.into()),
    }
}

/// A provider as the user sets it.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct SetProvider {
    /// Address of an OpenAI-compatible API up to its version part, such as
    /// `https://api.openai.com/v1`.
    pub base_url: String,
    pub model: String,
    /// Left out, the stored key stays as long as the address does, and at
    /// another address the key kept there is taken: a key is never sent to
    /// another server than the one it was given for. Empty, none.
    pub api_key: Option<String>,
    /// Left out, the account's values stay.
    pub sampling: Option<Sampling>,
    /// What the user calls the provider. Left out, the entry's name stays;
    /// empty removes it at the chat's own entry and keeps it at another.
    pub name: Option<String>,
    /// The background model, of the same address. Left out, the one picked
    /// stays; empty removes it, so the chat model does the work.
    pub worker_model: Option<String>,
    /// The image model, of the same address. Left out, the one picked stays.
    pub image_model: Option<String>,
}

/// What first run stores, tidied and checked (`set`); the key and the name
/// as typed, or left out.
pub struct Stored {
    pub base_url: String,
    pub model: String,
    pub api_key: Option<String>,
    pub sampling: Option<Sampling>,
    pub name: Option<String>,
    /// Empty for none.
    pub worker: Option<String>,
    pub image: Option<String>,
}

/// Stores first run's models at once ([`Storage::set_provider`]). Returns the
/// provider as stored, with its worker model.
pub fn set(
    db: &dyn Storage,
    user: i64,
    new: SetProvider,
) -> anyhow::Result<(Provider, Option<String>)> {
    if let Some(sampling) = &new.sampling {
        sampling.check()?;
    }
    let tidied = Stored {
        base_url: address_at(db, user, &new.base_url)?,
        model: model(&new.model)?,
        api_key: key(new.api_key)?,
        sampling: new.sampling,
        name: called(new.name)?,
        worker: new.worker_model.map(|id| id.trim().to_string()),
        image: new.image_model.as_deref().map(model).transpose()?,
    };
    db.set_provider(user, &tidied)?;
    stored(db, user)?.context(Fail::said(Code::Internal, "the provider was not stored"))
}

/// The stored provider of `user` with its background model, if one is picked.
pub fn stored(db: &dyn Storage, user: i64) -> anyhow::Result<Option<(Provider, Option<String>)>> {
    let Some(chat) = get(db, user)? else {
        return Ok(None);
    };
    let worker = kinds::picked(db, user, Kind::Background)?.map(|picked| picked.model);
    Ok(Some((chat, worker)))
}

/// The background model where it is at the chat model's provider (its address
/// and key), as the coding team asks all its roles there.
pub fn background_beside(
    db: &dyn Storage,
    user: i64,
    chat: &Provider,
) -> anyhow::Result<Option<String>> {
    Ok(kinds::provider_of(db, user, Kind::Background)?
        .filter(|work| work.base_url == chat.base_url && work.api_key == chat.api_key)
        .map(|work| work.model))
}

/// The provider the app's own work is asked of: the stored one with its
/// worker model, or its chat model where none is set. Of the values for a
/// reply only the context size goes along: the rest are set for the chats.
pub fn for_work(db: &dyn Storage, user: i64) -> anyhow::Result<Option<Provider>> {
    match kinds::provider_of(db, user, Kind::Background)? {
        Some(background) => Ok(Some(as_work(background))),
        None => chat_for_work(db, user),
    }
}

/// The chat model asked for the app's own work, sent of the values for a
/// reply only the context size, as [`for_work`] does.
pub fn chat_for_work(db: &dyn Storage, user: i64) -> anyhow::Result<Option<Provider>> {
    Ok(get(db, user)?.map(as_work))
}

/// `work` with only its context size of the values for a reply.
fn as_work(work: Provider) -> Provider {
    let sampling = Sampling {
        context_size: work.sampling.context_size,
        ..Sampling::default()
    };
    Provider { sampling, ..work }
}

/// A name the user gives as it is kept: `typed` without the space around it.
/// `whose` begins the refusal of one that is too long ("a provider's").
pub fn name_of(typed: &str, whose: &str) -> anyhow::Result<String> {
    let name = typed.trim();
    ensure!(
        name.chars().count() <= NAME_LIMIT,
        Fail::said(
            Code::TooLong,
            format!("{whose} name has at most {NAME_LIMIT} characters")
        )
        .with("what", "provider_name")
        .with("name_limit", NAME_LIMIT)
    );
    ensure!(
        !name.chars().any(char::is_control),
        Fail::said(
            Code::NotReadable,
            "the name holds characters a name cannot have"
        )
        .with("what", "name_characters")
    );
    Ok(name.to_string())
}

/// A provider's name as it is kept, where one is given.
fn called(typed: Option<String>) -> anyhow::Result<Option<String>> {
    typed
        .map(|typed| name_of(&typed, "a provider's"))
        .transpose()
}

/// The address of an API as it is kept and asked: `typed` without the space
/// around it and the slash at its end.
pub fn address(typed: &str) -> anyhow::Result<String> {
    let base_url = typed.trim().trim_end_matches('/').to_string();
    // The path of the API is added to the address as it is, and the address is
    // shown again, so it holds neither a query nor a name and password.
    let plain = Url::parse(&base_url).is_ok_and(|url| {
        let web = matches!(url.scheme(), "http" | "https") && url.has_host();
        web && url.username().is_empty()
            && url.password().is_none()
            && url.query().is_none()
            && url.fragment().is_none()
    });
    ensure!(
        plain,
        Fail::said(
            Code::NotReadable,
            "the address must be a plain web address such as https://api.openai.com/v1"
        )
        .with("what", "provider_address")
    );
    ensure!(
        !local::at(&base_url),
        Fail::said(
            Code::NotPossible,
            "This computer's models are found by their folder, in Settings › Providers"
        )
        .with("what", "local_address")
    );
    Ok(base_url)
}

/// [`address`], or This computer's where the account has it, its folder set
/// (Settings › Providers, first run's "Use a server on this computer"): first
/// run lists, tests, picks and stores its models as any provider's.
pub(crate) fn address_at(
    db: &dyn kinds::Storage,
    user: i64,
    typed: &str,
) -> anyhow::Result<String> {
    let base_url = typed.trim().trim_end_matches('/');
    let entries = || kinds::Storage::entries(db, user);
    if local::at(base_url) && entries()?.iter().any(|entry| entry.base_url == base_url) {
        return Ok(base_url.to_string());
    }
    address(typed)
}

/// A key as it is kept and sent: `typed` without the space around it.
pub fn key(typed: Option<String>) -> anyhow::Result<Option<String>> {
    // A pasted key often comes with spaces or a line end around it.
    let key = typed.map(|key| key.trim().to_string());
    ensure!(
        key.iter()
            .flat_map(|key| key.chars())
            .all(|c| c.is_ascii_graphic()),
        Fail::said(
            Code::NotReadable,
            "the key holds characters a key cannot have"
        )
        .with("what", "key_characters")
    );
    Ok(key)
}

/// A model's ID as it is kept and sent: `typed` without the space around it.
pub(crate) fn model(typed: &str) -> anyhow::Result<String> {
    let model = typed.trim().to_string();
    ensure!(
        !model.is_empty(),
        Fail::said(Code::Needed, "the model must be named").with("what", "model_name")
    );
    Ok(model)
}

/// Whom a form asks before anything is stored: the address in it as it would
/// be stored, and the key that goes there, empty for none. That is the key
/// `typed`; left out, the stored key if the address is the one it was stored
/// with, and none otherwise.
pub fn whom(
    db: &dyn kinds::Storage,
    user: i64,
    base_url: &str,
    typed: Option<String>,
) -> anyhow::Result<(String, String)> {
    let base_url = address_at(db, user, base_url)?;
    let key = match key(typed)? {
        Some(typed) => typed,
        // A stored key goes only to the address it was stored with: the chat
        // model's provider's, else the first of the account's there.
        None => match get(db, user)?.filter(|stored| stored.base_url == base_url) {
            Some(stored) => stored.api_key,
            None => kinds::Storage::entries(db, user)?
                .into_iter()
                .find(|entry| entry.base_url == base_url)
                .map(|entry| entry.api_key)
                .unwrap_or_default(),
        },
    };
    Ok((base_url, key))
}

/// What the pretend model answers the worker model's questions: each
/// question's prompt and its answer, which the server hands in ([`Http`]).
pub(crate) type Fixed = &'static [(&'static str, &'static str)];

/// The client the chat models are asked with: the HTTP client, which it is
/// for any other call, and what the pretend model answers the worker model's
/// questions ([`Fixed`]), handed in where the server starts.
#[derive(Clone)]
pub struct Http {
    client: Client,
    fixed: Fixed,
}

impl Http {
    /// The client with what the pretend model answers the worker model's
    /// questions, which it otherwise answers with its chat's reply.
    pub fn answering(self, fixed: Fixed) -> Self {
        Self { fixed, ..self }
    }

    /// This client, but for calls that may stay silent for `silence`; reqwest has no
    /// silence per request. Answers as this one does.
    pub fn with_silence(&self, silence: Duration) -> cw_platform::http::Result<Self> {
        let client = silent_for(silence)?;
        let fixed = self.fixed;
        Ok(Self { client, fixed })
    }
}

impl std::ops::Deref for Http {
    type Target = Client;

    fn deref(&self) -> &Client {
        &self.client
    }
}

/// The client all calls to providers share; the pretend model answers the
/// worker model's questions only as [`Http::answering`] says.
pub fn client() -> cw_platform::http::Result<Http> {
    let client = silent_for(SILENCE_LIMIT)?;
    Ok(Http { client, fixed: &[] })
}

fn silent_for(silence: Duration) -> cw_platform::http::Result<Client> {
    cw_platform::http::client(cw_platform::http::Make {
        connect: Some(CONNECT_TIMEOUT),
        silence: Some(silence),
        ..Default::default()
    })
}

/// `request` with the key, where there is one.
pub fn keyed(request: RequestBuilder, key: &str) -> RequestBuilder {
    if key.is_empty() {
        request
    } else {
        request.bearer_auth(key)
    }
}

/// Sends `request` to a provider with `key` where there is one (`send`): its
/// answer where it succeeded, else [`refused`] with what it said. `whose`
/// names what is asked in the error ("the provider's voice").
pub async fn answered(
    request: RequestBuilder,
    key: &str,
    whose: &'static str,
) -> anyhow::Result<Response> {
    answered_with(request, key, whose, &[]).await
}

/// [`answered`], the pretend model answering the worker model's questions as
/// `fixed` says.
async fn answered_with(
    request: RequestBuilder,
    key: &str,
    whose: &'static str,
    fixed: Fixed,
) -> anyhow::Result<Response> {
    let answer = send_with(keyed(request, key), fixed)
        .await
        .with_context(|| {
            Fail::said(Code::Unreachable, format!("{whose} cannot be reached"))
                .with("whose", ui_name(whose))
        })?;
    succeeded(answer, whose).await
}

/// `answer` where it succeeded, else [`refused`] with what it said.
pub async fn succeeded(mut answer: Response, whose: &'static str) -> anyhow::Result<Response> {
    let status = answer.status();
    if !status.is_success() {
        let said = body(&mut answer, ERROR_BODY_LIMIT).await;
        let said = String::from_utf8_lossy(&said);
        let answer = serde_json::from_str::<Value>(&said).ok();
        let code = answer.as_ref().and_then(error_code).map(str::to_string);
        // "This computer" (`local`) answers its own failure with its body.
        if let Some(own) = answer
            .as_ref()
            .and_then(|answer| ErrorBody::deserialize(&answer[local::OWN]).ok())
        {
            bail!(Fail::from(own));
        }
        let reason = answer.map_or_else(|| brief(&said), |answer| reason(&answer));
        let refusal = refused(whose, status.as_u16(), reason);
        bail!(match code {
            Some(code) => refusal.with("code", code),
            None => refusal,
        });
    }
    Ok(answer)
}

/// Sends a request to a provider: to [`pretend`] or [`local`] where it is
/// for its address, else over the network.
pub async fn send(request: RequestBuilder) -> cw_platform::http::Result<Response> {
    send_with(request, &[]).await
}

/// [`send`], the pretend model answering the worker model's questions as
/// `fixed` says.
async fn send_with(request: RequestBuilder, fixed: Fixed) -> cw_platform::http::Result<Response> {
    let (http, request) = request.build_split();
    let mut request = request?;
    app_name::on(&mut request);
    if pretend::asked(&request) {
        return Ok(pretend::answer(&request, fixed));
    }
    if local::asked(&request) {
        return local::answer(&http, request).await;
    }
    http.execute(request).await
}

/// Sends `prompt` to the provider's model. The answer is read piece by piece
/// with [`Reply::next`].
pub async fn ask(
    http: &Http,
    provider: &Provider,
    prompt: &[PromptMessage],
) -> anyhow::Result<Reply> {
    ask_with(http, provider, prompt, &[]).await
}

/// [`ask`], with a prompt of any messages (a tool's among them) and the
/// `tools` the model may call, whose calls [`Reply::calls`] has once the
/// reply is read. A refusal is [`refused`].
pub async fn ask_with(
    http: &Http,
    provider: &Provider,
    prompt: &(impl Serialize + ?Sized),
    tools: &[Value],
) -> anyhow::Result<Reply> {
    ask_shaped(http, provider, prompt, tools, None).await
}

/// [`ask_with`], with the `response_format` to answer in, where there is one.
pub(crate) async fn ask_shaped(
    http: &Http,
    provider: &Provider,
    prompt: &(impl Serialize + ?Sized),
    tools: &[Value],
    shape: Option<&Value>,
) -> anyhow::Result<Reply> {
    let mut body = json!({ "model": provider.model, "messages": prompt, "stream": true });
    if !tools.is_empty() {
        body["tools"] = json!(tools);
    }
    if let Some(shape) = shape {
        body["response_format"] = shape.clone();
    }
    for (name, value) in provider.sampling.sent() {
        body[name] = value;
    }
    if let Some((name, value)) = provider.thinking_off.map(NoThinking::sent) {
        body[name] = value;
    }
    if let Some(limit) = provider.reply_limit {
        body[limit_field(&provider.base_url)] = limit.into();
    }
    let request = http
        .post(format!("{}/chat/completions", provider.base_url))
        .json(&body);
    let response =
        answered_with(request, &provider.api_key, "the model's server", http.fixed).await?;
    // A server that does not stream answers with one JSON document.
    let streamed = response
        .headers()
        .get(CONTENT_TYPE)
        .is_none_or(|kind| !kind.as_bytes().starts_with(b"application/json"));
    Ok(Reply::of(response, streamed))
}

/// The field a reply's limit is sent in: OpenAI's own API and Azure's take
/// only `max_completion_tokens` for their newer models, every other `max_tokens`.
fn limit_field(base_url: &str) -> &'static str {
    let url = Url::parse(base_url);
    match url.as_ref().ok().and_then(Url::host_str) {
        Some(host) if host == "api.openai.com" || host.ends_with(".openai.azure.com") => {
            "max_completion_tokens"
        }
        _ => "max_tokens",
    }
}

/// What the answer to a request that failed says went wrong, as far as it is
/// read.
pub(crate) async fn refusal(response: &mut Response) -> String {
    let said = body(response, ERROR_BODY_LIMIT).await;
    let said = String::from_utf8_lossy(&said);
    match serde_json::from_str(&said) {
        Ok(answer) => reason(&answer),
        Err(_) => brief(&said),
    }
}

/// What an answer says, as far as it has come when it ends, breaks off or is
/// `limit` bytes long.
pub async fn body(response: &mut Response, limit: usize) -> Vec<u8> {
    let mut said = Vec::new();
    while said.len() < limit
        && let Ok(Some(more)) = response.chunk().await
    {
        said.extend_from_slice(&more);
    }
    said
}

/// What an error answer says went wrong. Providers agree on `error.message`
/// only roughly.
pub(crate) fn reason(answer: &Value) -> String {
    let error = &answer["error"];
    match error["message"]
        .as_str()
        .or(error.as_str())
        .or(answer["message"].as_str())
    {
        Some(message) => brief(message),
        None => brief(&answer.to_string()),
    }
}

/// The kind of failure an error answer names, as a provider's word (`error.code`,
/// else `error.type`), where it names one. OpenRouter's moderation has a number
/// as its code and tells its `reasons`: that is a content filter.
pub(crate) fn error_code(answer: &Value) -> Option<&str> {
    let error = &answer["error"];
    let moderated = error["metadata"]["reasons"]
        .is_array()
        .then_some("content_filter");
    error["code"]
        .as_str()
        .or(error["type"].as_str())
        .or(moderated)
}

fn brief(text: &str) -> String {
    text.trim().chars().take(500).collect()
}

/// The model's whole answer to `prompt`.
pub async fn answer(
    http: &Http,
    provider: &Provider,
    prompt: &[PromptMessage],
) -> anyhow::Result<String> {
    let whole = async {
        let mut reply = ask(http, provider, prompt).await?;
        let mut text = String::new();
        while let Some(piece) = reply.next().await? {
            text.push_str(&piece);
        }
        anyhow::Ok(text)
    };
    match timeout(ANSWER_LIMIT, whole).await {
        Ok(text) => text,
        Err(_) => bail!(
            Fail::said(Code::TimedOut, "the model did not answer in time").with("whose", "model")
        ),
    }
}

/// The JSON object in a model's answer: from its first `{` to its last `}`,
/// so a code fence or a word around it does not matter.
pub fn object(text: &str) -> anyhow::Result<Value> {
    let start = text.find('{').context(
        Fail::said(Code::ModelAnswer, "no JSON object in the answer").with("what", "json"),
    )?;
    let end = text.rfind('}').context(
        Fail::said(Code::ModelAnswer, "no JSON object in the answer").with("what", "json"),
    )?;
    ensure!(
        start < end,
        Fail::said(Code::ModelAnswer, "no JSON object in the answer").with("what", "json")
    );
    Ok(serde_json::from_str(&text[start..=end])?)
}

#[cfg(test)]
mod tests {
    use crate::{NoThinking, Provider, Sampling, limit_field};

    #[tokio::test]
    async fn a_client_with_its_own_silence_gives_up_after_it() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let silence = std::time::Duration::from_millis(100);
        let http = crate::client().unwrap().with_silence(silence).unwrap();

        let got = http.get(format!("http://{address}/")).send().await;

        assert!(got.unwrap_err().is_timeout());
        drop(listener);
    }

    fn of(model: &str, thinking_off: Option<NoThinking>) -> Provider {
        Provider {
            base_url: "http://localhost:8080/v1".into(),
            api_key: String::new(),
            model: model.into(),
            sampling: Sampling::default(),
            name: String::new(),
            thinking_off,
            reply_limit: None,
            seen_thinking: false,
        }
    }

    #[test]
    fn a_reply_is_limited_where_the_model_does_not_think() {
        assert_eq!(of("my-rig-7b", None).limited(350).reply_limit, Some(350));
        // Its name says nothing, but an answer of it carried thinking.
        let seen = Provider {
            seen_thinking: true,
            ..of("my-rig-7b", None)
        };
        assert_eq!(seen.limited(350).reply_limit, None);
        // models.dev says gpt-5 thinks, unless its thinking was turned off.
        assert_eq!(of("gpt-5", None).limited(350).reply_limit, None);
        let off = Some(NoThinking::ReasoningEffort);
        assert_eq!(of("gpt-5", off).limited(350).reply_limit, Some(350));
    }

    #[test]
    fn a_refusal_names_what_was_asked_and_why_by_the_ui_s_words() {
        use cw_core::{Detail, Fail};
        let detail = |fail: &Fail, name: &str| fail.details.get(name).cloned();
        let text = |text: &str| Some(Detail::Text(text.into()));
        for (status, why) in [
            (401, "key"),
            (403, "key"),
            (402, "paid"),
            (429, "busy"),
            (503, "down"),
            (500, "fault"),
            (404, "other"),
        ] {
            let fail = crate::refused("the model's server", status, "no".into());
            assert_eq!(detail(&fail, "refusal"), text(why), "{status}");
            assert_eq!(detail(&fail, "whose"), text("model_server"));
        }
        // A model gone and a message too long are told by the provider's words.
        for (status, said, why) in [
            (404, "The model `fake-1` does not exist", "no_model"),
            (400, "model_not_found: no such model", "no_model"),
            (
                400,
                "This model's maximum context length is 8192 tokens.",
                "too_long",
            ),
            (
                413,
                "prompt is too long: 210000 tokens > 200000 maximum",
                "too_long",
            ),
        ] {
            let fail = crate::refused("the model's server", status, said.into());
            assert_eq!(detail(&fail, "refusal"), text(why), "{said}");
            assert_eq!(detail(&fail, "whose"), text("model_server"));
        }
        let voice = crate::refused("the provider's voice", 401, "no".into());
        assert_eq!(detail(&voice, "whose"), text("provider_voice"));
        assert_eq!(
            voice.to_string(),
            "the provider's voice answered 401 Unauthorized: no"
        );
    }

    #[test]
    fn openai_is_sent_its_own_field_for_the_limit() {
        assert_eq!(
            limit_field("https://api.openai.com/v1"),
            "max_completion_tokens"
        );
        let azure = "https://mine.openai.azure.com/openai/v1";
        assert_eq!(limit_field(azure), "max_completion_tokens");
        assert_eq!(limit_field("https://openrouter.ai/api/v1"), "max_tokens");
    }
}
pub mod embedder;

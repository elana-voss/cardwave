//! The models a provider has, asked of its API (`GET <base>/models`), so that a
//! model's ID need not be typed; the answer also says, before anything is saved,
//! whether the address lists models and takes the key.
//!
//! It asks where a chat would go (the user's address, a local server too) through
//! the chats' client, with the key a chat would send: the one typed, or the
//! stored one at the address it was stored with. It stores nothing. A list may be
//! megabytes and slow, so it is read for a while and up to a size (`Limits`).
//!
//! `of` asks within `Limits`; `described` asks any address and keeps what it says
//! of each model (`Said`: OpenRouter's output kinds and parameters, NanoGPT's
//! capabilities), which `catalog` reads; `read` reads a list that may break off
//! anywhere, for `places` too. Over HTTP it is `POST /api/provider/models`.

use std::fmt;
use std::time::{Duration, Instant};

use anyhow::{bail, ensure};
use cw_core::{Code, Fail};
use cw_platform::http::Client;
use cw_platform::http::header::ACCEPT;
use serde::de::{DeserializeSeed, Deserializer, IgnoredAny, MapAccess, SeqAccess, Visitor};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use ts_rs::TS;

/// How long a list may take to come, and how much of it is read: enough for
/// the largest list seen to come whole, Featherless's, 7 MB in 23 to 30 s.
const WAIT: Duration = Duration::from_secs(45);
const LIMIT: usize = 16 << 20;

/// Whose models the form asks for.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ListModels {
    /// The address that stands in the form.
    pub base_url: String,
    /// The key as typed. Left out, the stored key goes along if `base_url` is
    /// the address it was stored with, and none otherwise. Empty, none does.
    pub api_key: Option<String>,
}

/// The models a provider lists.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct ListedModels {
    /// Their IDs, each once, in the order of the letters whatever their case.
    pub models: Vec<String>,
    /// Whether the provider has more than these: its list did not come whole.
    pub more: bool,
}

/// How long the list of models is waited for, and how many bytes of it are read.
#[derive(Clone, Copy)]
pub struct Limits {
    pub wait: Duration,
    pub bytes: usize,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            wait: WAIT,
            bytes: LIMIT,
        }
    }
}

/// What a list says of a model beside its ID, where it says it.
#[derive(Debug, Default, Clone, PartialEq)]
pub struct Said {
    /// What it makes (`architecture.output_modalities`: "text", "image").
    pub output: Option<Vec<String>>,
    /// Whether it thinks first: OpenRouter's `supported_parameters` holding
    /// "reasoning", NanoGPT's `capabilities.reasoning`.
    pub thinks: Option<bool>,
}

/// A list's models with what it says of each, in the order of `ListedModels`.
pub struct Described {
    pub models: Vec<(String, Said)>,
    pub more: bool,
}

/// The models the API at `base_url` lists when asked with `key`.
pub async fn of(
    http: &Client,
    base_url: &str,
    key: &str,
    limits: Limits,
) -> anyhow::Result<ListedModels> {
    let described = described(http, &format!("{base_url}/models"), key, limits).await?;
    Ok(ListedModels {
        models: described.models.into_iter().map(|(id, _)| id).collect(),
        more: described.more,
    })
}

/// The models the list at `url` has when asked with `key`, with what it says of each.
pub async fn described(
    http: &Client,
    url: &str,
    key: &str,
    limits: Limits,
) -> anyhow::Result<Described> {
    let started = Instant::now();
    let request = http
        .get(url)
        .header(ACCEPT, "application/json")
        .timeout(limits.wait);
    let mut response = match crate::send(crate::keyed(request, key)).await {
        Ok(response) => response,
        Err(late) if late.is_timeout() => bail!(
            Fail::said(Code::TimedOut, "the model's server did not answer in time")
                .with("whose", "model_server")
        ),
        // Of what went wrong on the way, the last thing says it as the form
        // can show it: the name is not known, nothing listens there.
        Err(failure) => bail!(
            Fail::said(
                Code::Unreachable,
                format!(
                    "the model's server cannot be reached: {}",
                    anyhow::Error::from(failure).root_cause()
                )
            )
            .with("whose", "model_server")
        ),
    };
    let status = response.status();
    if !status.is_success() {
        let reason = crate::refusal(&mut response).await;
        // A web server's page for the error says nothing a user can read.
        let reason = if reason.is_empty() || reason.starts_with('<') {
            String::new()
        } else {
            format!(": {reason}")
        };
        let said = match (status.as_u16(), key.is_empty()) {
            (401 | 403, false) => "did not take the key",
            (401 | 403, true) => "asks for a key",
            // An API may have none (Gemini's has not), so this is no wrong address by itself.
            (404, _) => "has no list of models at this address",
            _ => bail!(
                Fail::said(
                    Code::Answered,
                    format!("the model's server answered {status}{reason}")
                )
                .with("whose", "model_server")
                .with("status", status.to_string())
                .with("reason", reason.to_string())
            ),
        };
        bail!(
            Fail::said(
                Code::Answered,
                format!("the model's server {said} ({status}){reason}")
            )
            .with("whose", "model_server")
            .with("said", said.to_string())
            .with("status", status.to_string())
            .with("reason", reason.to_string())
        );
    }
    // Read until the list is whole, too long, or its time is over.
    let read = read(&crate::body(&mut response, limits.bytes).await);
    // An answer that has not come as far as its list when the time is over.
    ensure!(
        read.list || started.elapsed() < limits.wait,
        Fail::said(Code::TimedOut, "the model's server did not answer in time")
            .with("whose", "model_server")
    );
    ensure!(
        read.list,
        Fail::said(
            Code::NotReadable,
            "the address answers, but not with a list of models"
        )
        .with("what", "models_list_answer")
    );
    let mut models = read.ids;
    models.retain(|(id, _)| !id.trim().is_empty());
    models.sort_by_cached_key(|(id, _)| (id.to_lowercase(), id.clone()));
    models.dedup_by(|(one, _), (other, _)| one == other);
    // A list that broke off before its first model says nothing of what the
    // provider has, least of all that it has none.
    ensure!(
        read.whole || !models.is_empty(),
        Fail::said(Code::NotReadable, "the list of models did not come")
            .with("what", "models_list_missing")
    );
    Ok(Described {
        models,
        more: !read.whole,
    })
}

impl Said {
    fn of(
        architecture: Option<Value>,
        parameters: Option<Value>,
        capabilities: Option<Value>,
    ) -> Self {
        let output = architecture.and_then(|architecture| {
            let kinds = architecture.get("output_modalities")?.as_array()?;
            Some(
                kinds
                    .iter()
                    .filter_map(|kind| Some(kind.as_str()?.to_string()))
                    .collect(),
            )
        });
        let listed = parameters.and_then(|parameters| {
            let names = parameters.as_array()?;
            Some(names.iter().any(|name| name.as_str() == Some("reasoning")))
        });
        let capable =
            capabilities.and_then(|capabilities| capabilities.get("reasoning")?.as_bool());
        Self {
            output,
            thinks: capable.or(listed),
        }
    }
}

/// What was read of an answer that is to be a list of models.
pub(super) struct Read {
    /// The IDs of its models, as they came, with what it says of each.
    pub ids: Vec<(String, Said)>,
    /// Whether it is a list of models: JSON that begins as a list, or with one
    /// under `data`.
    pub list: bool,
    /// Whether it was read to its end, and not only to where it breaks off.
    pub whole: bool,
}

/// Reads `said` as a list of models: a list, or an object with a list under
/// `data`, of objects that each have their model's `id`. `said` may break off
/// anywhere: the models before that place are read.
pub(super) fn read(said: &[u8]) -> Read {
    /// One thing of the list. What is no model with an ID is passed over;
    /// what it says beside is read loosely, as lists differ.
    #[derive(Deserialize)]
    #[serde(untagged)]
    enum Entry {
        Model {
            id: String,
            architecture: Option<Value>,
            supported_parameters: Option<Value>,
            capabilities: Option<Value>,
        },
        Other(IgnoredAny),
    }

    struct Reader<'a> {
        read: &'a mut Read,
        /// Whether this is the whole answer, not what stands under `data`.
        top: bool,
    }

    impl<'de> DeserializeSeed<'de> for Reader<'_> {
        type Value = ();

        fn deserialize<D: Deserializer<'de>>(self, from: D) -> Result<(), D::Error> {
            from.deserialize_any(self)
        }
    }

    impl<'de> Visitor<'de> for Reader<'_> {
        type Value = ();

        fn expecting(&self, text: &mut fmt::Formatter) -> fmt::Result {
            text.write_str("a list of models")
        }

        fn visit_seq<A: SeqAccess<'de>>(self, mut list: A) -> Result<(), A::Error> {
            self.read.list = true;
            while let Some(entry) = list.next_element()? {
                if let Entry::Model {
                    id,
                    architecture,
                    supported_parameters,
                    capabilities,
                } = entry
                {
                    let said = Said::of(architecture, supported_parameters, capabilities);
                    self.read.ids.push((id, said));
                }
            }
            Ok(())
        }

        fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<(), A::Error> {
            while self.top
                && let Some(key) = map.next_key::<String>()?
            {
                if key == "data" {
                    let read = &mut *self.read;
                    map.next_value_seed(Reader { read, top: false })?;
                } else {
                    map.next_value::<IgnoredAny>()?;
                }
            }
            Ok(())
        }
    }

    // The reading ends with an error where the answer breaks off, or is not
    // what a list of models is: what was found until then stays.
    let mut read = Read {
        ids: Vec::new(),
        list: false,
        whole: false,
    };
    let mut json = serde_json::Deserializer::from_slice(said);
    let top = Reader {
        read: &mut read,
        top: true,
    };
    let whole = top.deserialize(&mut json).is_ok();
    Read { whole, ..read }
}

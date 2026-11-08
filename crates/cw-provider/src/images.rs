//! What an image service offers, asked of its address: which API it speaks
//! (`api_of`: OpenRouter's and NanoGPT's by their host, ComfyUI's by its
//! `/system_stats`, Automatic1111's and Forge's by their list of checkpoints,
//! else OpenAI's image API), its image models (`listed`, `listed_at`) and
//! ComfyUI's saved workflows (`workflows`), and who is asked for a picture (`Whom`) and what comes back
//! (`Picture`). Making a picture is the server's
//! `images`.

use std::time::Duration;

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};
use cw_platform::http::{Client, Url};
use serde::Deserialize;
use serde_json::Value;

use crate::kinds::Workflow;
use crate::models::{self, Limits, ListedModels};
use crate::{facts, keyed, send};

/// Where a picture is asked for, and of which model.
#[derive(Clone, Debug)]
pub struct Whom {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    /// The provider's name as Settings shows it (`kinds::whose`).
    pub provider: String,
    /// A ComfyUI's saved workflow its pictures are made by; none for its default one.
    pub workflow: Option<Workflow>,
}

/// A picture as a model made it.
#[derive(Debug)]
pub struct Picture {
    pub data: Vec<u8>,
    pub mime: &'static str,
}

/// How long an address is given to say it is a ComfyUI, or to show its
/// list of checkpoints.
const PROBE_LIMIT: Duration = Duration::from_secs(5);

/// How long ComfyUI is given for a list or a saved workflow: its list of nodes is megabytes.
pub const LIST_LIMIT: Duration = Duration::from_secs(30);

/// The API an image model's address speaks.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ImageApi {
    /// `POST /images/generations`.
    OpenAi,
    /// `POST /images`, and its image models at `/images/models`.
    OpenRouter,
    /// A workflow to `POST /prompt`, its checkpoints at `/models/checkpoints`.
    ComfyUi,
    /// Automatic1111's and Forge's `POST /sdapi/v1/txt2img`.
    Automatic1111,
}

/// Whether the address is NanoGPT's by its host, which lists its image models apart.
pub(crate) fn is_nanogpt(base_url: &str) -> bool {
    Url::parse(base_url).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|host| host == "nano-gpt.com" || host.ends_with(".nano-gpt.com"))
    })
}

/// Whether the address is OpenRouter's by its host.
pub fn is_openrouter(base_url: &str) -> bool {
    Url::parse(base_url).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|host| host == "openrouter.ai" || host.ends_with(".openrouter.ai"))
    })
}

/// Which API the address speaks, asked with `key`: a ComfyUI, an
/// Automatic1111 or a Forge behind a server that asks for one.
pub async fn api_of(http: &Client, base_url: &str, key: &str) -> ImageApi {
    if is_openrouter(base_url) {
        return ImageApi::OpenRouter;
    }
    let stats =
        send(keyed(http.get(format!("{base_url}/system_stats")), key).timeout(PROBE_LIMIT)).await;
    let comfy = match stats {
        Ok(answer) if answer.status().is_success() => answer
            .json::<Value>()
            .await
            .is_ok_and(|said| said.get("system").is_some() && said.get("devices").is_some()),
        _ => false,
    };
    if comfy {
        ImageApi::ComfyUi
    } else if is_one(http, base_url, key).await {
        ImageApi::Automatic1111
    } else {
        ImageApi::OpenAi
    }
}

/// The image models the address has, asked with `key`.
pub async fn listed(http: &Client, base_url: &str, key: &str) -> anyhow::Result<ListedModels> {
    listed_at(http, api_of(http, base_url, key).await, base_url, key).await
}

/// The image models of the address that speaks `api`: ComfyUI's,
/// Automatic1111's and Forge's checkpoints, OpenRouter's image models, NanoGPT's list of them, and else the models
/// that models.dev or their names say make pictures.
pub(crate) async fn listed_at(
    http: &Client,
    api: ImageApi,
    base_url: &str,
    key: &str,
) -> anyhow::Result<ListedModels> {
    match api {
        ImageApi::ComfyUi => {
            let answer = send(
                keyed(http.get(format!("{base_url}/models/checkpoints")), key).timeout(PROBE_LIMIT),
            )
            .await
            .context(
                Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
            )?;
            ensure!(
                answer.status().is_success(),
                Fail::said(
                    Code::Answered,
                    format!("ComfyUI answered {}", answer.status())
                )
                .with("whose", "comfyui")
                .with("status", (answer.status()).to_string())
            );
            let mut models: Vec<String> = answer.json().await.context(
                Fail::said(
                    Code::NotReadable,
                    "ComfyUI's list of checkpoints cannot be read",
                )
                .with("what", "comfyui_answer"),
            )?;
            models.sort_by_cached_key(|id| id.to_lowercase());
            Ok(ListedModels {
                models,
                more: false,
            })
        }
        ImageApi::Automatic1111 => Ok(ListedModels {
            models: checkpoints(http, base_url, key).await?,
            more: false,
        }),
        ImageApi::OpenRouter => {
            models::of(http, &format!("{base_url}/images"), key, Limits::default()).await
        }
        ImageApi::OpenAi if is_nanogpt(base_url) => {
            let listed = models::described(
                http,
                &format!("{base_url}/image-models"),
                key,
                Limits::default(),
            )
            .await?;
            Ok(ListedModels {
                models: listed.models.into_iter().map(|(id, _)| id).collect(),
                more: listed.more,
            })
        }
        ImageApi::OpenAi => {
            let mut listed = models::of(http, base_url, key, Limits::default()).await?;
            listed.models.retain(|id| facts::makes_pictures(id));
            Ok(listed)
        }
    }
}

#[derive(Deserialize)]
struct Checkpoint {
    model_name: String,
}

/// The checkpoints of the Automatic1111 or Forge at `base`, asked with
/// `key`, in the order of their names whatever their case.
pub(crate) async fn checkpoints(
    http: &Client,
    base: &str,
    key: &str,
) -> anyhow::Result<Vec<String>> {
    let answer =
        send(keyed(http.get(format!("{base}/sdapi/v1/sd-models")), key).timeout(PROBE_LIMIT))
            .await
            .context(
                Fail::said(Code::Unreachable, "the picture server cannot be reached")
                    .with("whose", "picture_server"),
            )?;
    let status = answer.status();
    ensure!(
        status.is_success(),
        Fail::said(
            Code::Answered,
            format!("the picture server answered {status}")
        )
        .with("whose", "picture_server")
        .with("status", status.to_string())
    );
    let listed: Vec<Checkpoint> = answer.json().await.context(
        Fail::said(
            Code::NotReadable,
            "the picture server's list of models cannot be read",
        )
        .with("what", "picture_server_answer"),
    )?;
    let mut models: Vec<String> = listed.into_iter().map(|one| one.model_name).collect();
    models.sort_by_cached_key(|id| (id.to_lowercase(), id.clone()));
    models.dedup();
    Ok(models)
}

/// Whether the address is an Automatic1111 or a Forge: its list of models comes.
pub(crate) async fn is_one(http: &Client, base: &str, key: &str) -> bool {
    checkpoints(http, base, key).await.is_ok()
}

/// The address `base` with the path segments `segments`, each encoded whole.
pub fn at(base: &str, segments: &[&str]) -> anyhow::Result<Url> {
    let mut url = Url::parse(base).context(
        Fail::said(Code::NotReadable, "ComfyUI's address cannot be read")
            .with("what", "comfyui_address"),
    )?;
    url.path_segments_mut()
        .map_err(|()| {
            anyhow::anyhow!(
                Fail::said(Code::NotReadable, "ComfyUI's address cannot be read")
                    .with("what", "comfyui_address")
            )
        })?
        .pop_if_empty()
        .extend(segments);
    Ok(url)
}

/// The names of the workflows saved in the ComfyUI, in its folder and the
/// folders in it, in the order of their names whatever their case.
pub(crate) async fn workflows(http: &Client, base: &str, key: &str) -> anyhow::Result<Vec<String>> {
    let mut url = at(base, &["userdata"])?;
    url.query_pairs_mut()
        .append_pair("dir", "workflows")
        .append_pair("recurse", "true");
    let answer = send(keyed(http.get(url), key).timeout(LIST_LIMIT))
        .await
        .context(
            Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
        )?;
    // A ComfyUI where none was saved yet has no folder of them.
    if answer.status() == cw_platform::http::StatusCode::NOT_FOUND {
        return Ok(Vec::new());
    }
    let status = answer.status();
    ensure!(
        status.is_success(),
        Fail::said(Code::Answered, format!("ComfyUI answered {status}"))
            .with("whose", "comfyui")
            .with("status", status.to_string())
    );
    let names: Vec<String> = answer.json().await.context(
        Fail::said(
            Code::NotReadable,
            "ComfyUI's list of workflows cannot be read",
        )
        .with("what", "comfyui_answer"),
    )?;
    let mut names: Vec<String> = names
        .into_iter()
        .filter(|name| name.to_lowercase().ends_with(".json"))
        .collect();
    names.sort_by_cached_key(|name| name.to_lowercase());
    Ok(names)
}

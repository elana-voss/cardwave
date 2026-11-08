//! What models.dev's whole list (https://models.dev/api.json) says of a model:
//! release, price, context, tools, what it makes and whether it thinks
//! ([`Known`]), by which first run picks models (`picks`) and kinds are told
//! (`facts`).
//!
//! The list ships gzipped (`crates/cw-provider/providers/models.dev.json.gz`,
//! written by `tools/models.py`) and is fetched anew at most once a day ([`DAY`])
//! from `source` into the data folder ([`FILE`]), read in the shipped one's place
//! while it is of the day; a failed fetch leaves what was there for a day.
//! Without `source` (the server tests) nothing is fetched.
//!
//! A model is found by its name ([`Index::get`]): lower-case, after its last `/`,
//! no `:` tag, `.` and `_` as `-`, else without a date or `-latest`. An ID several
//! providers list is one entry: the middle of their dates and prices, the most it
//! reads, and a kind or thinking at least half of them say.

use std::collections::HashMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime};

use anyhow::Context;
use cw_core::{Code, Fail};
use cw_platform::http::Client;
use serde::Deserialize;
use tokio::sync::Mutex;

/// The list as shipped with this version.
const SHIPPED: &[u8] = include_bytes!("../providers/models.dev.json.gz");

/// Where models.dev's list is.
pub const SOURCE: &str = "https://models.dev/api.json";

/// The copy fetched last, in the data folder.
pub const FILE: &str = "models.dev.json";

/// How long a list fetched, or a fetch that failed, stands.
pub const DAY: Duration = Duration::from_secs(24 * 60 * 60);

/// How long a fetch may take, and how much of an answer is read.
const FETCH_LIMIT: Duration = Duration::from_secs(20);
const SIZE_LIMIT: usize = 64 << 20;

/// What models.dev says of a model.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Known {
    /// When it came out, `2025-08-07` (or `2025-08`), compared as text.
    pub(crate) released: Option<String>,
    /// Dollars per million tokens read and written.
    pub input: Option<f64>,
    pub output: Option<f64>,
    /// The most tokens it reads.
    pub context: Option<u64>,
    /// Whether it calls tools.
    pub tools: bool,
    /// Whether it writes text, makes pictures, thinks before it replies.
    pub text: bool,
    pub image: bool,
    pub thinks: bool,
    /// The name people read: the one most of its listings give, the shortest on a tie.
    pub name: Option<String>,
}

/// models.dev's list, by name.
#[derive(Debug, Default)]
pub struct Index(HashMap<String, Known>);

/// The list in the server's state: read once, fetched anew at most once a day.
pub struct ModelsDev {
    source: Option<String>,
    file: PathBuf,
    held: Mutex<Option<(Instant, Arc<Index>)>>,
}

impl ModelsDev {
    pub fn new(source: Option<String>, data_dir: &Path) -> Self {
        Self {
            source,
            file: data_dir.join(FILE),
            held: Mutex::default(),
        }
    }

    /// The list: the one read within the day, else the data folder's copy if
    /// it is of the day and reads, else one fetched now, else the copy or the
    /// shipped one. The lock is held over the fetch, so that one fetches.
    pub async fn index(&self, http: &Client) -> Arc<Index> {
        let mut held = self.held.lock().await;
        if let Some((read, index)) = held.as_ref()
            && read.elapsed() < DAY
        {
            return index.clone();
        }
        let fresh = std::fs::metadata(&self.file)
            .and_then(|meta| meta.modified())
            .is_ok_and(|at| SystemTime::now().duration_since(at).unwrap_or_default() < DAY);
        let today = if fresh { self.kept() } else { None };
        let index = match today {
            Some(index) => index,
            None => match self.fetched(http).await {
                Some(index) => index,
                None => self.kept().unwrap_or_else(shipped),
            },
        };
        let index = Arc::new(index);
        *held = Some((Instant::now(), index.clone()));
        index
    }

    /// The list fetched now and kept in the data folder (written beside it
    /// first, so that a copy cut short is never read), where there is a source.
    async fn fetched(&self, http: &Client) -> Option<Index> {
        let bytes = match fetch(http, self.source.as_deref()?).await {
            Ok(bytes) => bytes,
            Err(failure) => {
                tracing::warn!("models.dev's list was not fetched: {failure:#}");
                return None;
            }
        };
        let part = self.file.with_extension("json.part");
        let kept = async {
            tokio::fs::write(&part, &bytes).await?;
            tokio::fs::rename(&part, &self.file).await
        };
        if let Err(failure) = kept.await {
            tracing::warn!("models.dev's list cannot be kept: {failure}");
        }
        Index::read(&bytes).ok()
    }

    /// The data folder's copy, where there is one that reads.
    fn kept(&self) -> Option<Index> {
        let bytes = std::fs::read(&self.file).ok()?;
        Index::read(&bytes)
            .inspect_err(|failure| {
                tracing::warn!("models.dev's kept list does not read: {failure}")
            })
            .ok()
    }
}

/// The list shipped with this version.
pub fn shipped() -> Index {
    let mut bytes = Vec::new();
    flate2::read::GzDecoder::new(SHIPPED)
        .read_to_end(&mut bytes)
        .and_then(|_| Index::read(&bytes).map_err(std::io::Error::other))
        // Built into the server and read by the tests, so it reads.
        .expect("the shipped models.dev list reads")
}

/// The list at `source`, as long as it reads.
async fn fetch(http: &Client, source: &str) -> anyhow::Result<Vec<u8>> {
    let mut answer = http
        .get(source)
        .timeout(FETCH_LIMIT)
        .send()
        .await?
        .error_for_status()?;
    let mut bytes = Vec::new();
    while let Some(chunk) = answer.chunk().await? {
        bytes.extend_from_slice(&chunk);
        anyhow::ensure!(
            bytes.len() <= SIZE_LIMIT,
            Fail::said(Code::TooBig, "the list is too long").with("what", "models_dev_list")
        );
    }
    Index::read(&bytes)?;
    Ok(bytes)
}

#[derive(Deserialize)]
struct ProviderJson {
    #[serde(default)]
    models: HashMap<String, ModelJson>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ModelJson {
    id: Option<String>,
    name: Option<String>,
    release_date: Option<String>,
    tool_call: bool,
    reasoning: bool,
    cost: Option<CostJson>,
    limit: Option<LimitJson>,
    modalities: Option<ModalitiesJson>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ModalitiesJson {
    output: Vec<String>,
}

impl ModelJson {
    /// Whether its output kinds have `kind`.
    fn outputs(&self, kind: &str) -> bool {
        self.modalities
            .as_ref()
            .is_some_and(|said| said.output.iter().any(|output| output == kind))
    }
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct CostJson {
    input: Option<f64>,
    output: Option<f64>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct LimitJson {
    context: Option<u64>,
}

/// The middle of `prices`, of those above nothing: a provider's free copy says
/// nothing of what the model costs.
fn middle(mut prices: Vec<f64>) -> Option<f64> {
    prices.retain(|price| *price > 0.0);
    prices.sort_by(f64::total_cmp);
    prices.get(prices.len() / 2).copied()
}

/// The middle of `dates`: one provider's slip does not move it.
fn middle_date(mut dates: Vec<String>) -> Option<String> {
    dates.sort();
    dates.get(dates.len() / 2).cloned()
}

/// Whether at least half of `models` say so.
fn half(models: &[&ModelJson], says: impl Fn(&ModelJson) -> bool) -> bool {
    2 * models.iter().filter(|m| says(m)).count() >= models.len()
}

/// Of the listings of one name, those whose kinds and thinking count: those
/// without a `:` tag where there are any, as `x:thinking` is another model.
fn voters(listed: &[(bool, ModelJson)]) -> Vec<&ModelJson> {
    let plain = listed.iter().any(|(tagged, _)| !tagged);
    let counts = |tagged: &bool| !plain || !tagged;
    listed
        .iter()
        .filter(|(tagged, _)| counts(tagged))
        .map(|(_, m)| m)
        .collect()
}

/// The name most of `models` give, the shortest of those on a tie.
fn most_named(models: &[&ModelJson]) -> Option<String> {
    let mut counts: HashMap<&str, usize> = HashMap::new();
    for name in models.iter().filter_map(|m| m.name.as_deref()) {
        *counts.entry(name.trim()).or_default() += 1;
    }
    counts
        .into_iter()
        .filter(|(name, _)| !name.is_empty())
        .max_by(|a, b| {
            a.1.cmp(&b.1)
                .then(b.0.len().cmp(&a.0.len()))
                .then(b.0.cmp(a.0))
        })
        .map(|(name, _)| name.to_string())
}

/// A model's name as the list is looked up by.
fn name_of(id: &str) -> String {
    let lower = id.trim().to_lowercase();
    let tail = lower.rsplit('/').next().unwrap_or_default();
    let tail = tail.split(':').next().unwrap_or_default();
    tail.replace(['.', '_', ' '], "-")
}

/// `name` without a date or `-latest` at its end: `-20250514`, `-2025-05-14`, `-0528`.
fn undated(name: &str) -> &str {
    if let Some(rest) = name.strip_suffix("-latest") {
        return rest;
    }
    let digits = |part: &str, n: usize| part.len() == n && part.bytes().all(|b| b.is_ascii_digit());
    let parts: Vec<&str> = name.rsplitn(4, '-').collect();
    if parts.len() == 4 && digits(parts[0], 2) && digits(parts[1], 2) && digits(parts[2], 4) {
        return parts[3];
    }
    match name.rsplit_once('-') {
        Some((rest, end)) if !rest.is_empty() && (digits(end, 8) || digits(end, 4)) => rest,
        _ => name,
    }
}

impl Index {
    /// The list from models.dev's JSON.
    pub fn read(bytes: &[u8]) -> anyhow::Result<Self> {
        let providers: HashMap<String, ProviderJson> = serde_json::from_slice(bytes).context(
            Fail::said(Code::NotReadable, "models.dev's list").with("what", "models_dev_list"),
        )?;
        let mut all: HashMap<String, Vec<(bool, ModelJson)>> = HashMap::new();
        for (key, model) in providers.into_values().flat_map(|provider| provider.models) {
            let id = model.id.clone().unwrap_or(key);
            let tagged = id.contains(':');
            all.entry(name_of(&id)).or_default().push((tagged, model));
        }
        let index = all
            .into_iter()
            .map(|(name, listed)| {
                let voting = voters(&listed);
                let models: Vec<&ModelJson> = listed.iter().map(|(_, m)| m).collect();
                let known = Known {
                    released: middle_date(
                        models
                            .iter()
                            .filter_map(|m| m.release_date.clone())
                            .collect(),
                    ),
                    input: middle(
                        models
                            .iter()
                            .filter_map(|m| m.cost.as_ref()?.input)
                            .collect(),
                    ),
                    output: middle(
                        models
                            .iter()
                            .filter_map(|m| m.cost.as_ref()?.output)
                            .collect(),
                    ),
                    context: models
                        .iter()
                        .filter_map(|m| m.limit.as_ref()?.context)
                        .max(),
                    tools: models.iter().any(|m| m.tool_call),
                    text: half(&voting, |m| m.outputs("text")),
                    image: half(&voting, |m| m.outputs("image")),
                    thinks: half(&voting, |m| m.reasoning),
                    name: most_named(&voting),
                };
                (name, known)
            })
            .collect();
        Ok(Self(index))
    }

    /// What the list says of the model `id` of a provider's list, by its name.
    pub fn get(&self, id: &str) -> Option<&Known> {
        let name = name_of(id);
        self.0.get(&name).or_else(|| self.0.get(undated(&name)))
    }

    /// The readable name of the model `id`: only of the same name, as a dated
    /// model keeps its own.
    pub fn name(&self, id: &str) -> Option<&str> {
        self.0.get(&name_of(id))?.name.as_deref()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LIST: &str = r#"{
        "openai": { "models": {
            "gpt-5": { "id": "gpt-5", "release_date": "2025-08-07", "tool_call": true, "reasoning": true,
                       "modalities": { "output": ["text"] },
                       "cost": { "input": 1.25, "output": 10 }, "limit": { "context": 400000 } } } },
        "azure": { "models": {
            "gpt-5": { "id": "gpt-5", "reasoning": true, "modalities": { "output": ["text"] } } } },
        "router": { "models": {
            "openai/gpt-5": { "id": "openai/gpt-5", "release_date": "2025-08-08", "reasoning": true,
                              "modalities": { "output": ["text", "image"] },
                              "cost": { "input": 1.5, "output": 12 }, "limit": { "context": 272000 } },
            "openai/gpt-5:free": { "id": "openai/gpt-5:free", "cost": { "input": 0, "output": 0 } },
            "anthropic/claude-3.7-sonnet": { "id": "anthropic/claude-3.7-sonnet", "modalities": { "output": ["text"] } },
            "anthropic/claude-3.7-sonnet:thinking": { "id": "anthropic/claude-3.7-sonnet:thinking", "reasoning": true },
            "claude-sonnet-4.5": { "id": "anthropic/claude-sonnet-4.5", "cost": { "output": 15 } } } }
    }"#;

    #[test]
    fn a_model_is_one_entry_by_its_name_whoever_lists_it() {
        let index = Index::read(LIST.as_bytes()).unwrap();
        let gpt = index.get("gpt-5").unwrap();
        // The middle date and price above nothing, the most it reads, tools where any says so.
        assert_eq!(gpt.released.as_deref(), Some("2025-08-08"));
        assert_eq!((gpt.input, gpt.output), (Some(1.5), Some(12.0)));
        assert_eq!((gpt.context, gpt.tools), (Some(400000), true));
        // A kind or thinking where at least half of them say so: one slip does not count, nor one
        // with a tag, which is another model where the name is listed without one.
        assert_eq!((gpt.text, gpt.image, gpt.thinks), (true, false, true));
        let claude = index.get("claude-3.7-sonnet").unwrap();
        assert_eq!((claude.text, claude.thinks), (true, false));
        // By the part after its last slash, without a tag, a date or `-latest`, `.` as `-`.
        for id in [
            "openai/GPT-5",
            "gpt-5:beta",
            "gpt-5-2025-08-07",
            "gpt-5-20250807",
            "gpt-5-latest",
        ] {
            assert_eq!(index.get(id), Some(gpt), "{id}");
        }
        assert!(index.get("claude-sonnet-4-5").is_some());
        assert!(index.get("anthropic/claude-sonnet-4.5").is_some());
        assert!(index.get("gpt-5-mini").is_none());
        assert_eq!(undated("qwen-3"), "qwen-3");
    }

    #[test]
    fn the_shipped_list_reads() {
        assert!(shipped().get("gpt-5").is_some());
    }
}

//! A ComfyUI's pictures: a workflow queued (`POST /prompt`), its history
//! asked until it is done, and the first picture it saved fetched (`make`).
//! The workflow is ComfyUI's default one with the checkpoint picked
//! (`workflow`), or a workflow the user saved in ComfyUI and picked on
//! Settings › Providers (`kinds::Workflow`): read anew for each picture
//! (`GET /userdata/workflows%2F<name>`, the slash in the name's one segment),
//! turned into the form `/prompt` takes by `graph` with the nodes ComfyUI
//! has (`GET /object_info`), the picture's words put into the input the
//! background model found when it was picked (`pick`, `PLACE`), and a new
//! seed into each that ComfyUI's page would change after each run. Its sizes
//! and models are the workflow's own: the shape a card's picture asks for
//! goes to the default workflow alone.

use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Fail};
use cw_platform::http::{Client, Url};
use cw_prompt::{PromptMessage, Role};
use cw_provider::Http;
use cw_provider::images::{LIST_LIMIT, at};
use cw_provider::kinds::Workflow;
use cw_provider::{Provider, send};
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

use crate::images::graph::{self, Place};
use crate::images::{Shape, Whom, keyed, read};

/// What the background model is asked: which text field of a workflow takes a picture's words.
pub const PLACE: &str = include_str!("place.txt");

/// How long ComfyUI may take for a picture: on a slow machine minutes.
const LIMIT: Duration = Duration::from_secs(600);
/// How often ComfyUI is asked whether the picture is done.
const EVERY: Duration = Duration::from_millis(500);
/// The most characters of a field's text the background model is shown.
const SHOWN: usize = 300;

/// ComfyUI's default workflow, with the checkpoint `model` and the words `prompt`.
pub fn workflow(model: &str, prompt: &str, seed: u64, shape: Shape) -> Value {
    // Upright, a size of SDXL's own at about a million pixels, 2:3 to a pixel.
    let (width, height) = match shape {
        Shape::Own => (1024, 1024),
        Shape::Upright => (832, 1248),
    };
    json!({
        "3": { "class_type": "KSampler", "inputs": {
            "seed": seed, "steps": 20, "cfg": 8, "sampler_name": "euler", "scheduler": "normal",
            "denoise": 1, "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0],
            "latent_image": ["5", 0] } },
        "4": { "class_type": "CheckpointLoaderSimple", "inputs": { "ckpt_name": model } },
        "5": { "class_type": "EmptyLatentImage", "inputs": { "width": width, "height": height, "batch_size": 1 } },
        "6": { "class_type": "CLIPTextEncode", "inputs": { "text": prompt, "clip": ["4", 1] } },
        "7": { "class_type": "CLIPTextEncode", "inputs": { "text": "text, watermark", "clip": ["4", 1] } },
        "8": { "class_type": "VAEDecode", "inputs": { "samples": ["3", 0], "vae": ["4", 2] } },
        "9": { "class_type": "SaveImage", "inputs": { "filename_prefix": "Cardwave", "images": ["8", 0] } }
    })
}

/// The JSON of ComfyUI's answer to `GET url`.
async fn got(http: &Client, key: &str, url: Url) -> anyhow::Result<Value> {
    let answer = send(keyed(http.get(url), key).timeout(LIST_LIMIT))
        .await
        .context(
            Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
        )?;
    let status = answer.status();
    ensure!(
        status.is_success(),
        Fail::said(Code::Answered, format!("ComfyUI answered {status}"))
            .with("whose", "comfyui")
            .with("status", status.to_string())
    );
    answer.json().await.context(
        Fail::said(Code::NotReadable, "ComfyUI's answer cannot be read")
            .with("what", "comfyui_answer"),
    )
}

/// The saved workflow `name` in the form `POST /prompt` takes, and the nodes
/// ComfyUI has (`/object_info`).
async fn saved(
    http: &Client,
    base: &str,
    key: &str,
    name: &str,
) -> anyhow::Result<(graph::Prompt, Value)> {
    let file = format!("workflows/{name}");
    let saved = got(http, key, at(base, &["userdata", &file])?)
        .await
        .with_context(|| {
            Fail::said(
                Code::NotReadable,
                format!("the workflow “{name}” cannot be read"),
            )
            .with("what", "workflow")
            .with("name", name.to_string())
        })?;
    let info = got(http, key, at(base, &["object_info"])?).await?;
    let prompt = graph::prompt_of(&saved, &info).with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("the workflow “{name}” cannot be used"),
        )
        .with("what", "workflow_use")
        .with("name", name.to_string())
    })?;
    Ok((prompt, info))
}

/// What the background model is asked of `places`, a workflow's text fields.
pub fn asked_of(places: &[Place]) -> Vec<PromptMessage> {
    let fields: Vec<String> = places
        .iter()
        .enumerate()
        .map(|(index, place)| {
            let text: String = place.text.chars().take(SHOWN).collect();
            format!(
                "{}. {} “{}”, {}: {}",
                index + 1,
                place.class,
                place.title,
                place.input,
                serde_json::to_string(&text).unwrap_or_default()
            )
        })
        .collect();
    vec![PromptMessage::new(
        Role::User,
        PLACE.replace("{{fields}}", &fields.join("\n")),
    )]
}

/// The place the background model's `answer` names among `places`.
pub(crate) fn place_of<'p>(answer: &str, places: &'p [Place]) -> anyhow::Result<&'p Place> {
    #[derive(Deserialize)]
    struct Said {
        place: usize,
    }
    let answer = answer
        .rsplit_once("</think>")
        .map_or(answer, |(_, after)| after);
    let said: Said = serde_json::from_value(cw_provider::object(answer)?).context(
        Fail::said(
            Code::ModelAnswer,
            "the background model's answer cannot be read",
        )
        .with("what", "background_answer"),
    )?;
    match said.place.checked_sub(1).and_then(|at| places.get(at)) {
        Some(place) => Ok(place),
        None => bail!(
            Fail::said(
                Code::ModelAnswer,
                "the background model found no field for the picture's words"
            )
            .with("what", "picture_field")
        ),
    }
}

/// Why ComfyUI did not take a workflow, from its answer to `POST /prompt`:
/// its message and details, and those of the first node it found wrong (a
/// model the workflow names that it does not have, say).
fn refused(answer: &Value) -> String {
    let words = |error: &Value| {
        let said = error["message"]
            .as_str()
            .unwrap_or("the workflow was not taken");
        match error["details"]
            .as_str()
            .filter(|details| !details.is_empty())
        {
            Some(details) => format!("{said}: {details}"),
            None => said.to_string(),
        }
    };
    let node = answer["node_errors"].as_object().and_then(|nodes| {
        let (id, node) = nodes.iter().next()?;
        let class = node["class_type"].as_str().unwrap_or(id);
        Some(format!(
            "; node {id} {class}: {}",
            words(&node["errors"][0])
        ))
    });
    format!("{}{}", words(&answer["error"]), node.unwrap_or_default())
}

/// The saved workflow `name` of the ComfyUI at `base`, with where its
/// pictures' words go, as `worker` (the background model) finds it.
pub async fn pick(
    http: &Http,
    worker: &Provider,
    base: &str,
    key: &str,
    name: &str,
) -> anyhow::Result<Workflow> {
    let (prompt, info) = saved(http, base, key, name).await?;
    let places = graph::places(&prompt, &info);
    ensure!(
        !places.is_empty(),
        Fail::said(
            Code::NotPossible,
            format!("the workflow “{name}” has no text field for the picture's words")
        )
        .with("what", "workflow_no_text")
        .with("name", name.to_string())
    );
    let answer = cw_provider::answer(http, worker, &asked_of(&places)).await?;
    let place = place_of(&answer, &places).with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("the workflow “{name}” cannot be used"),
        )
        .with("what", "workflow_use")
        .with("name", name.to_string())
    })?;
    Ok(Workflow {
        name: name.to_string(),
        node: place.node.clone(),
        input: place.input.clone(),
    })
}

/// The prompt for a picture of `words` by the saved `workflow`.
async fn by_saved(
    http: &Client,
    whom: &Whom,
    workflow: &Workflow,
    words: &str,
) -> anyhow::Result<Value> {
    let name = &workflow.name;
    let (saved, _) = saved(http, &whom.base_url, &whom.api_key, name).await?;
    let mut prompt = Value::Object(saved.nodes);
    let fits = prompt
        .get(&workflow.node)
        .is_some_and(|node| node["inputs"][&workflow.input].is_string());
    ensure!(fits, Fail::said(Code::Changed, format!("the workflow “{name}” was changed in ComfyUI: pick it again in Settings › Providers")).with("what", "workflow").with("name", name.to_string()));
    prompt[&workflow.node]["inputs"][&workflow.input] = words.into();
    reseed(&mut prompt, &saved.seeds);
    Ok(prompt)
}

/// A new number in each of `seeds` that still holds one of its own: a seed
/// fed by another node (a link, `[node, slot]`) or left out stays so.
fn reseed(prompt: &mut Value, seeds: &[(String, String, u64)]) {
    for (node, input, most) in seeds {
        let Some(seed) = prompt[node]["inputs"].get_mut(input) else {
            continue;
        };
        if seed.is_number() {
            // Within what JavaScript counts exactly, as ComfyUI's page makes them.
            *seed = rand::random_range(0..=(*most).min((1 << 53) - 1)).into();
        }
    }
}

/// A picture of `words` made by the ComfyUI of `whom`.
pub async fn make(
    http: &Client,
    whom: &Whom,
    words: &str,
    shape: Shape,
) -> anyhow::Result<Vec<u8>> {
    let base = &whom.base_url;
    let key = &whom.api_key;
    let prompt = match &whom.workflow {
        Some(saved) => by_saved(http, whom, saved, words).await?,
        None => workflow(&whom.model, words, rand::random::<u32>().into(), shape),
    };
    let queued =
        send(keyed(http.post(format!("{base}/prompt")), key).json(&json!({ "prompt": prompt })))
            .await
            .context(
                Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
            )?;
    let status = queued.status();
    let queued: Value = queued.json().await.context(
        Fail::said(Code::NotReadable, "ComfyUI's answer cannot be read")
            .with("what", "comfyui_answer"),
    )?;
    ensure!(
        status.is_success(),
        Fail::said(
            Code::Answered,
            format!("ComfyUI answered {status}: {}", refused(&queued))
        )
        .with("whose", "comfyui")
        .with("status", status.to_string())
    );
    let id = queued["prompt_id"]
        .as_str()
        .context(
            Fail::said(Code::NotPossible, "ComfyUI did not queue the picture")
                .with("what", "comfyui_queue"),
        )?
        .to_string();
    let end = Instant::now() + LIMIT;
    let done = loop {
        let history: Value = send(keyed(http.get(format!("{base}/history/{id}")), key))
            .await
            .context(
                Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
            )?
            .json()
            .await
            .context(
                Fail::said(Code::NotReadable, "ComfyUI's history cannot be read")
                    .with("what", "comfyui_answer"),
            )?;
        let entry = &history[&id];
        if entry["status"]["status_str"] == "error" {
            let said = entry["status"]["messages"]
                .as_array()
                .into_iter()
                .flatten()
                .find(|message| message[0] == "execution_error")
                .and_then(|message| message[1]["exception_message"].as_str())
                .unwrap_or("the workflow failed");
            bail!(
                Fail::said(Code::NotPossible, format!("ComfyUI: {}", said.trim()))
                    .with("what", "comfyui_said")
                    .with("said", (said.trim()).to_string())
            );
        }
        if entry["status"]["completed"] == true
            || entry["outputs"].as_object().is_some_and(|o| !o.is_empty())
        {
            break entry.clone();
        }
        ensure!(
            Instant::now() < end,
            Fail::said(Code::TimedOut, "ComfyUI did not make the picture in time")
                .with("whose", "comfyui")
        );
        sleep(EVERY).await;
    };
    // A picture saved before one only shown (a preview's).
    let pictures: Vec<&Value> = done["outputs"]
        .as_object()
        .into_iter()
        .flat_map(|outputs| outputs.values())
        .flat_map(|output| output["images"].as_array().into_iter().flatten())
        .collect();
    let saved = pictures
        .iter()
        .find(|picture| picture["type"] == "output")
        .or_else(|| pictures.first())
        .context(
            Fail::said(Code::NotPossible, "ComfyUI made no picture")
                .with("what", "comfyui_no_picture"),
        )?;
    let mut view = Url::parse(&format!("{base}/view"))?;
    view.query_pairs_mut()
        .append_pair("filename", saved["filename"].as_str().unwrap_or_default())
        .append_pair("subfolder", saved["subfolder"].as_str().unwrap_or_default())
        .append_pair("type", saved["type"].as_str().unwrap_or("output"));
    read(send(keyed(http.get(view), key)).await.context(
        Fail::said(Code::Unreachable, "ComfyUI cannot be reached").with("whose", "comfyui"),
    )?)
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_workflow_comfyui_did_not_take_says_the_node_it_found_wrong() {
        let answer = json!({
            "error": { "type": "prompt_outputs_failed_validation", "message": "Prompt outputs failed validation", "details": "" },
            "node_errors": { "2": {
                "errors": [{ "message": "Value not in list", "details": "clip_name: 'a.gguf' not in ['b.gguf']" }],
                "class_type": "CLIPLoaderGGUF"
            } }
        });
        assert_eq!(
            refused(&answer),
            "Prompt outputs failed validation; node 2 CLIPLoaderGGUF: Value not in list: clip_name: 'a.gguf' not in ['b.gguf']"
        );
        assert_eq!(refused(&json!({})), "the workflow was not taken");
    }

    #[test]
    fn only_a_seed_of_its_own_is_made_anew() {
        let mut prompt = json!({
            "3": { "inputs": { "seed": 42 } },
            "4": { "inputs": { "seed": ["9", 0] } },
            "5": { "inputs": {} }
        });
        let seeds: Vec<_> = ["3", "4", "5"]
            .into_iter()
            .map(|id| (id.to_string(), "seed".to_string(), 7))
            .collect();
        reseed(&mut prompt, &seeds);
        assert!(prompt["3"]["inputs"]["seed"].as_u64().unwrap() <= 7);
        assert_eq!(prompt["4"]["inputs"]["seed"], json!(["9", 0]));
        assert_eq!(prompt["5"]["inputs"], json!({}));
    }
}

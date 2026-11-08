//! A workflow saved in ComfyUI turned into the form `POST /prompt` takes, as
//! ComfyUI's own page does it (its `graphToPrompt`): a saved workflow is the
//! editor's (nodes, each with its widgets' values in a row, and links), the
//! prompt a map of node IDs to their class and inputs. A node's widgets are
//! named by the node's inputs as `GET /object_info` lists them
//! (`input_order`), each INT or COMBO with "control after generate" and each
//! upload button taking one value more.
//!
//! Traps: a subgraph's nodes are its instance's ID, ":" and their own; a link
//! from a bypassed node goes on through its input of the same type, one from
//! a muted node goes nowhere; a Reroute is followed, a PrimitiveNode's value
//! already stands in its targets' widgets; a node the ComfyUI does not know is
//! one of its page's alone and left out, but a link from one is refused; a
//! value that is a list is sent as `{"__value__": [...]}`. The fields for the
//! words (`places`) go by node number, not the map's order of text. What it does with
//! the owner's saved workflows was compared with ComfyUI's page (work log).

use std::collections::HashMap;

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use serde_json::{Map, Value, json};

/// The ID a subgraph's links give its inputs and outputs.
const INPUT_NODE: i64 = -10;
/// A node's mode: muted, never run.
const NEVER: i64 = 2;
/// A node's mode: bypassed, its inputs handed on.
const BYPASS: i64 = 4;
/// The values of a widget "control after generate" may hold.
const CONTROLS: &[&str] = &["fixed", "increment", "decrement", "randomize"];
/// The options of a COMBO that give it an upload button, a widget of its own.
const UPLOADS: &[&str] = &[
    "image_upload",
    "video_upload",
    "audio_upload",
    "animated_image_upload",
    "mesh_upload",
    "file_upload",
];
/// The nodes whose file name the page fills in (`named_file`).
const SAVES: &[&str] = &[
    "SaveImage",
    "SaveImageAdvanced",
    "SaveSVGNode",
    "SaveVideo",
    "SaveAnimatedWEBP",
    "SaveWEBM",
    "SaveAudio",
    "SaveAudioMP3",
    "SaveAudioOpus",
    "SaveAudioAdvanced",
    "SaveGLB",
    "Save3DAdvanced",
    "SaveGaussianSplat",
    "SavePointCloud",
    "SaveAnimatedPNG",
    "CLIPSave",
    "VAESave",
    "ModelSave",
    "LoraSave",
    "SaveLatent",
];
/// The types of input ComfyUI's page makes a widget of.
const WIDGETS: &[&str] = &["INT", "FLOAT", "STRING", "BOOLEAN", "COMBO"];

/// A workflow in the form `POST /prompt` takes.
#[derive(Debug, Default)]
pub struct Prompt {
    /// Node ID to `{"class_type", "inputs", "_meta": {"title"}}`.
    pub nodes: Map<String, Value>,
    /// The inputs a new seed goes into for each picture: those whose "control
    /// after generate" says anything but "fixed", as node ID, input name and
    /// the largest value it takes.
    pub seeds: Vec<(String, String, u64)>,
}

/// A text input of a workflow, where a prompt may go.
#[derive(Debug, PartialEq)]
pub struct Place {
    pub node: String,
    pub input: String,
    pub(crate) class: String,
    pub title: String,
    pub text: String,
}

struct Link {
    origin: i64,
    slot: usize,
    kind: String,
}

/// A graph of the workflow: its top or a subgraph's definition.
struct Graph<'a> {
    nodes: Vec<&'a Value>,
    links: HashMap<i64, Link>,
    /// A subgraph's definition, with its inputs and outputs.
    own: Option<&'a Value>,
}

/// Where an input's value comes from.
enum Source {
    /// A node's output: its ID and slot.
    Output(String, u64),
    /// The input's own widget.
    Own,
    /// Nothing: the input is left out.
    Nothing,
}

/// One level of subgraphs on the way to a node: the graph, and the node of
/// the level above whose subgraph it is.
#[derive(Clone, Copy)]
struct Frame<'g, 'a> {
    graph: &'g Graph<'a>,
    instance: Option<&'a Value>,
}

struct Walk<'g, 'a> {
    info: &'a Value,
    subgraphs: &'g HashMap<&'a str, Graph<'a>>,
    prompt: Prompt,
    /// Each node sent: its name for search and replace, its title and inputs.
    named: Vec<(String, String, Map<String, Value>)>,
}

fn number(value: &Value) -> Option<i64> {
    value.as_i64().or_else(|| value.as_str()?.parse().ok())
}

fn graph(saved: &Value) -> anyhow::Result<Graph<'_>> {
    let nodes = saved["nodes"].as_array().context(
        Fail::said(Code::NotReadable, "the workflow has no nodes").with("what", "workflow_broken"),
    )?;
    let mut links = HashMap::new();
    for link in saved["links"].as_array().into_iter().flatten() {
        // The top's links are rows, a subgraph's objects.
        let (id, origin, slot, kind) = match link {
            Value::Array(row) => {
                let at = |i: usize| row.get(i).unwrap_or(&Value::Null);
                (at(0), at(1), at(2), at(5))
            }
            _ => (
                &link["id"],
                &link["origin_id"],
                &link["origin_slot"],
                &link["type"],
            ),
        };
        let (Some(id), Some(origin), Some(slot)) = (number(id), number(origin), slot.as_u64())
        else {
            bail!(
                Fail::said(
                    Code::NotReadable,
                    "the workflow has a link that cannot be read"
                )
                .with("what", "workflow_broken")
            );
        };
        let kind = kind.as_str().unwrap_or_default().to_string();
        links.insert(
            id,
            Link {
                origin,
                slot: slot as usize,
                kind,
            },
        );
    }
    Ok(Graph {
        nodes: nodes.iter().collect(),
        links,
        own: None,
    })
}

/// `saved`, a workflow as ComfyUI keeps it, in the form `POST /prompt` takes,
/// its nodes as `info` (`GET /object_info`) has them.
pub fn prompt_of(saved: &Value, info: &Value) -> anyhow::Result<Prompt> {
    if saved.get("nodes").is_none()
        && saved
            .as_object()
            .is_some_and(|all| all.values().all(|node| node.get("class_type").is_some()))
    {
        bail!(
            Fail::said(
                Code::NotReadable,
                "the workflow is saved in the form for the API: save it in ComfyUI as a workflow"
            )
            .with("what", "workflow_api_form")
        );
    }
    let top = graph(saved)?;
    let mut subgraphs = HashMap::new();
    for own in saved["definitions"]["subgraphs"]
        .as_array()
        .into_iter()
        .flatten()
    {
        let id = own["id"].as_str().context(
            Fail::said(Code::NotReadable, "a subgraph has no ID").with("what", "workflow_broken"),
        )?;
        let mut inner = graph(own)?;
        inner.own = Some(own);
        subgraphs.insert(id, inner);
    }
    let mut walk = Walk {
        info,
        subgraphs: &subgraphs,
        prompt: Prompt::default(),
        named: Vec::new(),
    };
    walk.nodes(&[Frame {
        graph: &top,
        instance: None,
    }])?;
    let mut prompt = walk.prompt;
    for node in prompt.nodes.values_mut() {
        let saving = node["class_type"]
            .as_str()
            .is_some_and(|class| SAVES.contains(&class));
        if let Some(prefix) = node["inputs"]["filename_prefix"]
            .as_str()
            .filter(|_| saving)
        {
            node["inputs"]["filename_prefix"] = named_file(prefix, &walk.named).into();
        }
    }
    // A link to a node that is not sent goes too.
    let ids: Vec<String> = prompt.nodes.keys().cloned().collect();
    for node in prompt.nodes.values_mut() {
        if let Some(inputs) = node["inputs"].as_object_mut() {
            inputs.retain(|_, value| match value.as_array() {
                Some(link) if link.len() == 2 && link[0].is_string() => {
                    ids.iter().any(|id| Some(id.as_str()) == link[0].as_str())
                }
                _ => true,
            });
        }
    }
    if prompt.nodes.is_empty() {
        bail!(
            Fail::said(
                Code::NotReadable,
                "the workflow has no node this ComfyUI can run"
            )
            .with("what", "workflow_no_node")
        );
    }
    Ok(prompt)
}

/// The ID a node has in the prompt: its subgraphs' instances' and its own, joined by ":".
fn id_of(scope: &[Frame], node: &Value) -> String {
    let mut id: Vec<String> = scope
        .iter()
        .filter_map(|frame| frame.instance.map(|instance| shown(&instance["id"])))
        .collect();
    id.push(shown(&node["id"]));
    id.join(":")
}

/// A node's ID as text.
fn shown(id: &Value) -> String {
    match id {
        Value::String(id) => id.clone(),
        id => id.to_string(),
    }
}

/// An input's spec in `info` and its type, where the node's class has it.
fn spec<'a>(class: &'a Value, name: &str) -> Option<&'a Value> {
    let input = &class["input"];
    input["required"]
        .get(name)
        .or_else(|| input["optional"].get(name))
}

/// Whether ComfyUI's page makes a widget of an input of `spec`.
fn is_widget(spec: &Value) -> bool {
    let options = &spec[1];
    if options["forceInput"] == true {
        return false;
    }
    match &spec[0] {
        Value::Array(_) => true,
        Value::String(kind) => WIDGETS.contains(&kind.as_str()),
        _ => false,
    }
}

impl<'g, 'a> Walk<'g, 'a> {
    /// The nodes of the graph at the end of `scope`, and of its subgraphs.
    fn nodes(&mut self, scope: &[Frame<'g, 'a>]) -> anyhow::Result<()> {
        let here = scope.last().expect("a scope has a graph").graph;
        for &node in &here.nodes {
            let mode = node["mode"].as_i64().unwrap_or(0);
            if mode == NEVER || mode == BYPASS {
                continue;
            }
            let kind = node["type"].as_str().unwrap_or_default();
            if let Some(inner) = self.subgraphs.get(kind) {
                let mut deeper = scope.to_vec();
                deeper.push(Frame {
                    graph: inner,
                    instance: Some(node),
                });
                self.nodes(&deeper)?;
                continue;
            }
            // A node of the page alone (a note, a reroute, a primitive, an
            // extension's own) is not sent.
            let Some(class) = self.info.get(kind) else {
                continue;
            };
            self.node(scope, node, kind, class)?;
        }
        Ok(())
    }

    /// A node as the prompt has it.
    fn node(
        &mut self,
        scope: &[Frame<'g, 'a>],
        node: &'a Value,
        kind: &str,
        class: &Value,
    ) -> anyhow::Result<()> {
        let id = id_of(scope, node);
        let mut inputs = Map::new();
        let mut controls = Vec::new();
        widgets(node, class, &mut inputs, &mut controls)?;
        for (name, control, most) in controls {
            if control != "fixed" {
                self.prompt.seeds.push((id.clone(), name, most));
            }
        }
        for input in node["inputs"].as_array().into_iter().flatten() {
            let Some(link) = number(&input["link"]) else {
                continue;
            };
            let name = input["name"].as_str().unwrap_or_default().to_string();
            match self.source_of_link(scope, link)? {
                Source::Output(from, slot) => {
                    inputs.insert(name, json!([from, slot]));
                }
                // The widget's value stands.
                Source::Own | Source::Nothing => {}
            }
        }
        let title = node["title"]
            .as_str()
            .or_else(|| class["display_name"].as_str())
            .unwrap_or(kind);
        let named = node["properties"]["Node name for S&R"]
            .as_str()
            .unwrap_or(kind);
        self.named
            .push((named.to_string(), title.to_string(), inputs.clone()));
        self.prompt.nodes.insert(
            id,
            json!({ "inputs": inputs, "class_type": kind, "_meta": { "title": title } }),
        );
        Ok(())
    }

    /// Where the link `id` of the graph at the end of `scope` comes from.
    fn source_of_link(&self, scope: &[Frame<'g, 'a>], id: i64) -> anyhow::Result<Source> {
        let here = scope.last().expect("a scope has a graph").graph;
        let link = here.links.get(&id).with_context(|| {
            Fail::said(
                Code::NotReadable,
                format!("the workflow's link {id} is missing"),
            )
            .with("what", "workflow_broken")
            .with("id", id.to_string())
        })?;
        self.source_of_output(scope, link.origin, link.slot, &link.kind)
    }

    /// Where the output `slot` of the node `origin` of the graph at the end of
    /// `scope` comes from, as it carries `kind`.
    fn source_of_output(
        &self,
        scope: &[Frame<'g, 'a>],
        origin: i64,
        slot: usize,
        kind: &str,
    ) -> anyhow::Result<Source> {
        let frame = *scope.last().expect("a scope has a graph");
        if origin == INPUT_NODE {
            // The subgraph's input: its instance's input of that name, outside.
            let (Some(instance), Some(own)) = (frame.instance, frame.graph.own) else {
                bail!(
                    Fail::said(
                        Code::NotReadable,
                        "the workflow links to a subgraph's input outside one"
                    )
                    .with("what", "workflow_broken")
                );
            };
            let name = &own["inputs"][slot]["name"];
            let outer = instance["inputs"]
                .as_array()
                .into_iter()
                .flatten()
                .find(|input| &input["name"] == name);
            return match outer.and_then(|input| number(&input["link"])) {
                Some(link) => {
                    let outside = &scope[..scope.len() - 1];
                    match self.source_of_link(outside, link)? {
                        Source::Nothing => Ok(Source::Own),
                        found => Ok(found),
                    }
                }
                None => Ok(Source::Own),
            };
        }
        let node = frame
            .graph
            .nodes
            .iter()
            .find(|node| number(&node["id"]) == Some(origin))
            .with_context(|| {
                Fail::said(
                    Code::NotReadable,
                    format!("the workflow links to a node {origin} it lacks"),
                )
                .with("what", "workflow_broken")
                .with("origin", origin.to_string())
            })?;
        let mode = node["mode"].as_i64().unwrap_or(0);
        let class = node["type"].as_str().unwrap_or_default();
        let inputs = node["inputs"].as_array().map(Vec::as_slice).unwrap_or(&[]);
        if mode == NEVER {
            return Ok(Source::Nothing);
        }
        if class == "Reroute" {
            return match inputs.first().and_then(|input| number(&input["link"])) {
                Some(link) => self.source_of_link(scope, link),
                None => Ok(Source::Nothing),
            };
        }
        if class == "PrimitiveNode" {
            return Ok(Source::Own);
        }
        if mode == BYPASS {
            let fits = |input: &&Value| input["type"].as_str() == Some(kind);
            let through = inputs
                .get(slot)
                .filter(fits)
                .or_else(|| inputs.iter().find(fits))
                .and_then(|input| number(&input["link"]));
            return match through {
                Some(link) => self.source_of_link(scope, link),
                None => Ok(Source::Nothing),
            };
        }
        if let Some(inner) = self.subgraphs.get(class) {
            let own = inner.own.expect("a subgraph has its definition");
            let link = own["outputs"][slot]["linkIds"][0].as_i64();
            let Some(link) = link else {
                return Ok(Source::Nothing);
            };
            let mut deeper = scope.to_vec();
            deeper.push(Frame {
                graph: inner,
                instance: Some(node),
            });
            return self.source_of_link(&deeper, link);
        }
        if self.info.get(class).is_none() {
            bail!(
                Fail::said(
                    Code::NotReadable,
                    format!("the workflow's node “{class}” is not one this ComfyUI has")
                )
                .with("what", "workflow_node")
                .with("class", class.to_string())
            );
        }
        Ok(Source::Output(id_of(scope, node), slot as u64))
    }
}

/// The values of `node`'s widgets by their inputs' names, into `inputs`; the
/// names, values and largest values of its "control after generate" widgets
/// into `controls`. A widget the saved workflow has no value for has its default, as the page
/// gives it; values left over are of widgets the page shows alone (a
/// preview's text). A value of another type than its widget's means widgets
/// an extension added in between: refused.
fn widgets(
    node: &Value,
    class: &Value,
    inputs: &mut Map<String, Value>,
    controls: &mut Vec<(String, String, u64)>,
) -> anyhow::Result<()> {
    let sent = |value: &Value| match value {
        Value::Array(_) => json!({ "__value__": value }),
        _ => value.clone(),
    };
    // The page marks each input that has a widget; an extension's widget type is known by that alone.
    let marked: Vec<&str> = node["inputs"]
        .as_array()
        .into_iter()
        .flatten()
        .filter(|input| input.get("widget").is_some())
        .filter_map(|input| input["name"].as_str())
        .collect();
    let kind = node["type"].as_str().unwrap_or_default();
    let mut names = Vec::new();
    for group in ["required", "optional"] {
        for name in class["input_order"][group].as_array().into_iter().flatten() {
            let Some(name) = name.as_str() else { continue };
            let Some(spec) = spec(class, name) else {
                continue;
            };
            if !is_widget(spec) && !marked.contains(&name) {
                continue;
            }
            if spec[0] == "COMFY_DYNAMICCOMBO_V3" {
                bail!(
                    Fail::said(
                        Code::NotReadable,
                        format!(
                            "the workflow's node “{kind}” has a kind of field Cardwave cannot read"
                        )
                    )
                    .with("what", "workflow_fields")
                    .with("kind", kind.to_string())
                );
            }
            names.push((name, spec));
        }
    }
    let mut values = match &node["widgets_values"] {
        // An extension's node may keep them by name.
        Value::Object(named) => {
            for (name, spec) in names {
                if let Some(value) = named.get(name).or_else(|| default(spec)) {
                    inputs.insert(name.to_string(), sent(value));
                }
            }
            return Ok(());
        }
        Value::Array(values) => values.iter().peekable(),
        _ => [].iter().peekable(),
    };
    for (name, spec) in names {
        let Some(value) = values.next().or_else(|| default(spec)) else {
            continue;
        };
        if !fits(spec, value) {
            bail!(
                Fail::said(
                    Code::NotReadable,
                    format!("the workflow's node “{kind}” has fields Cardwave cannot read")
                )
                .with("what", "workflow_fields")
                .with("kind", kind.to_string())
            );
        }
        inputs.insert(name.to_string(), sent(value));
        let options = &spec[1];
        let controlled = !matches!(
            options["control_after_generate"],
            Value::Null | Value::Bool(false)
        ) || (spec[0] == "INT" && (name == "seed" || name == "noise_seed"));
        let control = |next: &&Value| next.as_str().is_some_and(|said| CONTROLS.contains(&said));
        if controlled && let Some(control) = values.next_if(control) {
            let control = control.as_str().unwrap_or_default().to_string();
            let most = options["max"].as_u64().unwrap_or(u64::MAX);
            controls.push((name.to_string(), control, most));
        }
        if UPLOADS.iter().any(|upload| options[upload] == true) {
            values.next();
        }
    }
    Ok(())
}

/// Whether `value` is of the type of a widget of `spec`.
fn fits(spec: &Value, value: &Value) -> bool {
    match spec[0].as_str() {
        Some("INT" | "FLOAT") => value.is_number(),
        Some("BOOLEAN") => value.is_boolean(),
        Some("STRING") => value.is_string(),
        Some("COMBO") | None => value.is_string() || value.is_number() || value.is_null(),
        Some(_) => true,
    }
}

/// The value a widget of `spec` begins with: its default, else a list's first.
fn default(spec: &Value) -> Option<&Value> {
    spec[1]
        .get("default")
        .or_else(|| spec[0].as_array().and_then(|list| list.first()))
        .or_else(|| spec[1]["options"].as_array().and_then(|list| list.first()))
}

/// `prefix`, a saving node's file name, as the page sends it: each
/// `%date:[format]%` the date, each `%[node].[widget]%` that widget's value
/// (the node by its name for search and replace, else its title).
fn named_file(prefix: &str, nodes: &[(String, String, Map<String, Value>)]) -> String {
    let mut out = String::new();
    let mut rest = prefix;
    while let Some(start) = rest.find('%') {
        let Some(len) = rest[start + 1..].find('%') else {
            break;
        };
        let pattern = &rest[start + 1..start + 1 + len];
        out.push_str(&rest[..start]);
        let parts: Vec<&str> = pattern.split('.').collect();
        let replaced = match parts.as_slice() {
            [one] => one
                .strip_prefix("date:")
                .map(|format| dated(format, &chrono::Local::now().naive_local())),
            [node, widget] => nodes
                .iter()
                .find(|(named, _, _)| named == node)
                .or_else(|| nodes.iter().find(|(_, title, _)| title == node))
                .and_then(|(_, _, inputs)| inputs.get(*widget))
                .map(|value| {
                    let text = match value {
                        Value::String(text) => text.clone(),
                        Value::Null => String::new(),
                        value => value.to_string(),
                    };
                    text.chars()
                        .map(|c| match c {
                            '/' | '?' | '<' | '>' | '\\' | ':' | '*' | '|' | '"' => '_',
                            c if c.is_control() => '_',
                            c => c,
                        })
                        .collect()
                }),
            _ => None,
        };
        match replaced {
            Some(replaced) => {
                out.push_str(&replaced);
                rest = &rest[start + len + 2..];
            }
            // Left as it is, its closing sign the next one's opening.
            None => {
                out.push('%');
                out.push_str(pattern);
                rest = &rest[start + len + 1..];
            }
        }
    }
    out.push_str(rest);
    out
}

/// `format` with the date's parts as the page writes them: `yyyy`, `yy`, and
/// `M`, `d`, `h`, `m`, `s` once or twice (twice with a leading zero).
fn dated(format: &str, at: &chrono::NaiveDateTime) -> String {
    use chrono::{Datelike, Timelike};
    let mut out = String::new();
    let chars: Vec<char> = format.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        let run = chars[i..].iter().take_while(|&&next| next == c).count();
        let (taken, text) = match c {
            'y' if run >= 4 => (4, at.year().to_string()),
            'y' if run >= 2 => (2, format!("{:02}", at.year() % 100)),
            'M' | 'd' | 'h' | 'm' | 's' => {
                let n = match c {
                    'M' => at.month(),
                    'd' => at.day(),
                    'h' => at.hour(),
                    'm' => at.minute(),
                    _ => at.second(),
                };
                let taken = run.min(2);
                (taken, format!("{n:0taken$}"))
            }
            c => (1, c.to_string()),
        };
        out.push_str(&text);
        i += taken;
    }
    out
}

/// The text inputs of `prompt` a picture's words may go into, in the order of
/// their nodes' numbers (a subgraph's inner node after its own): each STRING
/// input that holds text of its own.
pub fn places(prompt: &Prompt, info: &Value) -> Vec<Place> {
    let mut found = Vec::new();
    for (id, node) in &prompt.nodes {
        let class = node["class_type"].as_str().unwrap_or_default();
        for (input, value) in node["inputs"].as_object().into_iter().flatten() {
            let Some(text) = value.as_str() else {
                continue;
            };
            if spec(&info[class], input).is_some_and(|spec| spec[0] == "STRING") {
                found.push(Place {
                    node: id.clone(),
                    input: input.clone(),
                    class: class.to_string(),
                    title: node["_meta"]["title"].as_str().unwrap_or(class).to_string(),
                    text: text.to_string(),
                });
            }
        }
    }
    // The map has its IDs in the order of text, "13" before "4".
    let number = |id: &str| -> Vec<u64> {
        id.split(':')
            .map(|part| part.parse().unwrap_or(u64::MAX))
            .collect()
    };
    found.sort_by_cached_key(|place| number(&place.node));
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_file_names_date_and_widgets_are_written_as_comfyuis_page_does() {
        let at = chrono::NaiveDate::from_ymd_opt(2026, 3, 4)
            .and_then(|day| day.and_hms_opt(5, 6, 7))
            .unwrap();
        assert_eq!(dated("yyyy-MM-dd hh.mm.ss", &at), "2026-03-04 05.06.07");
        assert_eq!(dated("yy/M/d h:m:s", &at), "26/3/4 5:6:7");
        let inputs = serde_json::json!({ "text": "a/b: c", "seed": 7 });
        let nodes = [(
            "CLIPTextEncode".to_string(),
            "Positive".to_string(),
            inputs.as_object().unwrap().clone(),
        )];
        assert_eq!(
            named_file(
                "x-%Positive.text%-%CLIPTextEncode.seed%-%gone.text%",
                &nodes
            ),
            "x-a_b_ c-7-%gone.text%"
        );
    }

    #[test]
    fn a_short_link_is_refused_not_a_panic() {
        let saved = serde_json::json!({ "nodes": [], "links": [[1, 2]] });
        let error = graph(&saved).err().unwrap();
        assert!(error.to_string().contains("link"), "{error}");
    }

    #[test]
    fn the_fields_for_the_words_go_by_their_nodes_numbers() {
        let info: Value = serde_json::from_str(include_str!(
            "../../../../server/tests/comfy/object_info.json"
        ))
        .unwrap();
        let node = |text: &str| serde_json::json!({ "class_type": "CLIPTextEncode", "inputs": { "text": text }, "_meta": { "title": text } });
        let mut nodes = Map::new();
        for id in ["13", "4", "5:2", "5:10"] {
            nodes.insert(id.to_string(), node(id));
        }
        let prompt = Prompt {
            nodes,
            seeds: Vec::new(),
        };
        let order: Vec<_> = places(&prompt, &info)
            .into_iter()
            .map(|place| place.node)
            .collect();
        assert_eq!(order, ["4", "5:2", "5:10", "13"]);
    }
}

//! Asking a model for an answer of fixed fields: [`ask`] sends a [`Question`]
//! with a strict JSON schema, built of [`object`], [`list`], [`text`], [`yes_no`],
//! [`whole`] and [`one_of`], and gives back the JSON that fits it. Temperature and
//! limit are the call's own, the user's settings stay as they are.
//!
//! Tries ([`TRIES`]): an answer that cannot be read or lacks a required key is
//! asked again with the fields told in the system message; one cut off where a
//! limit was sent is asked again with four times the limit, up to [`MOST`]. A
//! model that thinks is sent no limit (`Provider::limited`).
//! A provider's refusal signal fails at once as `Code::ModelDeclined` ([`declined`]).
//! A provider that rejects `response_format` (400, 422) is asked once more
//! without it, which is no try; every other failure is returned at once.
//! Trap: no limit on a try's time but the silence limit of `client`: a long
//! answer of a slow model takes longer than `answer`'s limit.

use anyhow::bail;
use cw_core::{Code, Detail, Fail};
use serde_json::{Map, Value, json};

use crate::reply::Ending;
use crate::{Http, Provider, ask_shaped, refusal_of};

/// The limit of a call that names no other.
pub const LIMIT: u32 = 4_000;
/// The most tokens a cut-off answer is asked again with.
pub const MOST: u32 = 32_000;
/// How many answers a call reads before it fails.
pub const TRIES: usize = 3;
const TEMPERATURE: f64 = 0.8;
/// What goes before the schema where the system message tells the fields.
pub(crate) const TOLD: &str =
    "Answer with one JSON object and nothing else, in this JSON Schema:\n";
/// Providers' words for a refusal in an error's code.
const REFUSING: [&str; 4] = [
    "content_filter",
    "content_policy_violation",
    "refusal",
    "safety",
];

/// One call: its two messages, the schema of its answer and its limit in tokens.
pub struct Question<'a> {
    /// What the call does; the schema's name is made of it.
    pub role: &'a str,
    pub system: &'a str,
    pub user: &'a str,
    pub schema: Value,
    pub limit: u32,
    /// `None`: [`TEMPERATURE`].
    pub temperature: Option<f64>,
}

/// An object whose keys are all required, with no others.
pub fn object<const N: usize>(fields: [(&str, Value); N]) -> Value {
    let required: Vec<&str> = fields.iter().map(|(key, _)| *key).collect();
    let required = json!(required);
    let properties: Map<String, Value> = fields
        .into_iter()
        .map(|(key, kind)| (key.to_string(), kind))
        .collect();
    json!({
        "type": "object",
        "properties": properties,
        "required": required,
        "additionalProperties": false,
    })
}

/// A list of `item`.
pub fn list(item: Value) -> Value {
    json!({ "type": "array", "items": item })
}

pub fn text() -> Value {
    json!({ "type": "string" })
}

pub fn yes_no() -> Value {
    json!({ "type": "boolean" })
}

/// A whole number.
pub fn whole() -> Value {
    json!({ "type": "integer" })
}

/// A text limited to `values`.
pub fn one_of(values: &[&str]) -> Value {
    json!({ "type": "string", "enum": values })
}

/// The model's answer to `question`, which fits its schema. Fails with
/// `Code::ModelDeclined` on a refusal ([`declined`]), with `Code::ModelAnswer`
/// (`no_fitting_answer`) after [`TRIES`] answers that do not fit, and with what
/// went wrong on any other failure.
pub async fn ask(
    http: &Http,
    provider: &Provider,
    question: &Question<'_>,
) -> anyhow::Result<Value> {
    let mut asked = provider.clone().limited(question.limit);
    asked.sampling.temperature = Some(question.temperature.unwrap_or(TEMPERATURE));
    let shape = json!({
        "type": "json_schema",
        "json_schema": {
            "name": name_of(question.role),
            "strict": true,
            "schema": question.schema,
        },
    });
    let (mut format, mut tell, mut tries) = (true, false, 0);
    while tries < TRIES {
        let prompt = messages(question, tell || !format);
        let shape = format.then_some(&shape);
        let (words, ending) = match read(http, &asked, &prompt, shape).await {
            Ok(read) => read,
            Err(failure) if refused_as_declining(&failure) => {
                bail!(declining(&asked, &failure.to_string()))
            }
            Err(failure) if format && matches!(refusal_of(&failure), Some((400 | 422, _))) => {
                format = false;
                continue;
            }
            Err(failure) => return Err(failure),
        };
        if let Some(reason) = &ending.declined {
            bail!(declining(&asked, reason));
        }
        if let Ok(answer) = crate::object(&words)
            && fits(&answer, &question.schema)
        {
            return Ok(answer);
        }
        tries += 1;
        match (ending.cut_off, asked.reply_limit) {
            (true, Some(limit)) => {
                asked.reply_limit = Some(limit.saturating_mul(4).min(MOST).max(limit));
            }
            _ => tell = true,
        }
    }
    bail!(
        Fail::said(
            Code::ModelAnswer,
            format!("no answer of the asked fields in {TRIES} tries"),
        )
        .with("what", "no_fitting_answer")
    )
}

/// The call's two messages; `tell` adds the fields to the system message.
fn messages(question: &Question<'_>, tell: bool) -> Value {
    let system = match tell {
        true => format!(
            "{}

{TOLD}{}",
            question.system, question.schema
        ),
        false => question.system.to_string(),
    };
    json!([
        { "role": "system", "content": system },
        { "role": "user", "content": question.user },
    ])
}

/// One whole answer and how it ended.
async fn read(
    http: &Http,
    provider: &Provider,
    prompt: &Value,
    shape: Option<&Value>,
) -> anyhow::Result<(String, Ending)> {
    let mut reply = ask_shaped(http, provider, prompt, &[], shape).await?;
    let mut words = String::new();
    while let Some(piece) = reply.next().await? {
        words.push_str(&piece);
    }
    Ok((words, reply.ending().clone()))
}

fn declining(provider: &Provider, reason: &str) -> Fail {
    Fail::new(Code::ModelDeclined)
        .with("model", provider.model.as_str())
        .with("reason", reason)
}

/// The `Fail`s of `failure`: a given one is found by anyhow's own downcast only.
fn fails(failure: &anyhow::Error) -> impl Iterator<Item = &Fail> {
    let outer = failure.downcast_ref::<Fail>().into_iter();
    outer.chain(failure.chain().filter_map(|e| e.downcast_ref::<Fail>()))
}

/// Whether an error answer's code is a provider's word for a refusal.
fn refused_as_declining(failure: &anyhow::Error) -> bool {
    fails(failure).any(|fail| {
        matches!(fail.details.get("code"),
            Some(Detail::Text(code)) if REFUSING.contains(&code.as_str()))
    })
}

/// A schema's name as the providers allow it.
fn name_of(role: &str) -> String {
    role.chars()
        .take(64)
        .map(
            |c| match c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                true => c,
                false => '_',
            },
        )
        .collect()
}

/// Whether `value` holds every key `schema` requires, of the kind it names;
/// other keys are not refused.
fn fits(value: &Value, schema: &Value) -> bool {
    match schema["type"].as_str() {
        Some("object") => {
            let required = schema["required"].as_array().into_iter().flatten();
            value.is_object()
                && required.filter_map(Value::as_str).all(|key| {
                    value
                        .get(key)
                        .is_some_and(|field| fits(field, &schema["properties"][key]))
                })
        }
        Some("array") => value
            .as_array()
            .is_some_and(|items| items.iter().all(|item| fits(item, &schema["items"]))),
        Some("string") => {
            value.is_string()
                && schema["enum"]
                    .as_array()
                    .is_none_or(|values| values.contains(value))
        }
        Some("boolean") => value.is_boolean(),
        Some("integer") => value.is_i64() || value.is_u64(),
        _ => true,
    }
}

/// Whether `failure` is a model's refusal.
pub fn declined(failure: &anyhow::Error) -> bool {
    fails(failure).any(|fail| fail.code == Code::ModelDeclined)
}

/// Whether `failure` is a model's answer that could not be used.
pub fn unanswered(failure: &anyhow::Error) -> bool {
    fails(failure).any(|fail| fail.code == Code::ModelAnswer)
}

#[cfg(test)]
mod tests;

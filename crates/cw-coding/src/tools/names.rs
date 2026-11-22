//! Names for new characters (`suggest_npc_name`), ported from the owner's
//! SillyTavern extension NPC Name Suggester (0.3.0 and its upgrade 5ff9fb2, a
//! name kept back until revealed): the chat's model asks for
//! a new character's name with up to twelve optional filters (the database's
//! `TAGS`, each with what the model is told of it) and is given one
//! of a tagged database (`database`), picked by the extension's rules
//! (`picker`) and told as its JSON (`answer`). A chat tool (`chat::ChatTool`,
//! `TOOL`) while Tools for the AI › Names for new characters is on; while it
//! is, the model is told of it before the latest message (`advertisement.txt`,
//! `note`). The names a chat used are kept with it (`Storage`), so a name
//! comes back only once every name fitting the request is used.

mod answer;
mod database;
mod picker;

use anyhow::Context;
use serde_json::{Map, Value, json};

use crate::tools::chat::{ChatTool, Ran, Turn};
use database::{TAGS, Tag};
use picker::{Filters, Used};

/// The tool's name.
pub const NAME: &str = "suggest_npc_name";

/// What the model is told of the tool before the latest message; `%CULTURES%`
/// becomes the cultures the database holds.
const ADVERTISEMENT: &str = include_str!("names/advertisement.txt");

/// The tool as a chat tool.
pub const TOOL: ChatTool = ChatTool {
    name: NAME,
    on: |tools| tools.names,
    definition,
    note: Some(note),
    asked,
    run,
    short: false,
};

/// What the chats store of the tool: the names each used, as "culture/name".
pub trait Storage {
    /// The first names and the surnames the chat `chat_id` used.
    fn used_names(&self, chat_id: i64) -> anyhow::Result<(Vec<String>, Vec<String>)>;
    /// Keeps `first` and `last` as the chat's used names, in place of those before.
    fn keep_used_names(
        &self,
        chat_id: i64,
        first: &[String],
        last: &[String],
    ) -> anyhow::Result<()>;
}

/// The tool as the model is told of it: every filter optional, each an enum
/// of the values the database holds.
fn definition() -> Value {
    let names = database::names();
    let properties: Map<String, Value> = TAGS
        .iter()
        .map(
            |&Tag {
                 name: field,
                 description,
                 ..
             }| {
                let values = names.values_of(field);
                let schema = match field {
                    "themes" => json!({
                        "type": "array",
                        "items": { "type": "string", "enum": values },
                        "description": description,
                    }),
                    _ => json!({ "type": "string", "enum": values, "description": description }),
                };
                (field.to_string(), schema)
            },
        )
        .collect();
    json!({
        "type": "function",
        "function": {
            "name": NAME,
            "description": format!("Settle a new character's name: call {NAME}, with filters that fit the character as already established, at the latest before the reply in which their name first appears. An earlier call is fine if you keep the name back: it is the narrator's until the user's character hears or reads it (someone says it, it is written somewhere visible); until then, describe them. Returns a curated first name, with a last name where the culture has surnames, and classification tags (era, role, intelligence, allure, etc). Do NOT invent names yourself. Pass race: human for every person; race: mythical only for a god, spirit or monster; race: elf, race: dwarf or race: dragon for those; a mythology filter goes with race: mythical, never human. Pass commonness only when the story calls for it; otherwise leave it out."),
            "parameters": { "type": "object", "properties": properties },
        },
    })
}

/// What the model is told before the latest message.
fn note() -> String {
    let cultures = database::names().values_of("language_ethnicity");
    ADVERTISEMENT
        .trim_end()
        .replace("%CULTURES%", &cultures.join(", "))
}

/// The filters a call asked for, as "Used in this reply" shows them: "female, japanese".
fn asked(arguments: &str) -> String {
    let filters = filters(arguments).unwrap_or_default();
    TAGS.iter()
        .filter_map(|tag| filters.get(tag.name))
        .flatten()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .join(", ")
}

/// Picks a name for the call, keeping it among the chat's used names.
fn run(turn: Turn<'_>) -> Ran {
    let filters = filters(turn.arguments)?;
    let mut used = match turn.chat_id {
        Some(chat_id) => {
            let (first, last) = turn.store.used_names(chat_id)?;
            Used {
                first: first.into_iter().collect(),
                last: last.into_iter().collect(),
            }
        }
        None => Used::default(),
    };
    let picked = picker::pick(database::names(), &filters, &mut used, &mut |max| {
        rand::random_range(0..max)
    })?;
    if let Some(chat_id) = turn.chat_id {
        let sorted = |names: &std::collections::HashSet<String>| {
            let mut all: Vec<String> = names.iter().cloned().collect();
            all.sort_unstable();
            all
        };
        turn.store
            .keep_used_names(chat_id, &sorted(&used.first), &sorted(&used.last))?;
    }
    // "Used in this reply" shows the filters (`asked`), never the name the
    // model keeps back until the user's character learns it.
    Ok((answer::of(&picked), None))
}

/// The filters of `arguments`: each of `TAGS` given as a value or a list;
/// an empty value or list, or one not text, is no filter, nor is any other field.
fn filters(arguments: &str) -> anyhow::Result<Filters> {
    let arguments: Value = match arguments.trim() {
        "" => json!({}),
        text => serde_json::from_str(text).context("the arguments are no JSON")?,
    };
    let given = arguments
        .as_object()
        .context("the arguments are no JSON object")?;
    Ok(TAGS
        .iter()
        .filter_map(|&Tag { name: field, .. }| {
            let wanted: Vec<String> = match given.get(field)? {
                Value::Array(values) => values.iter().filter_map(text).collect(),
                value => text(value).into_iter().collect(),
            };
            (!wanted.is_empty()).then_some((field, wanted))
        })
        .collect())
}

/// `value` where it is text that is not empty.
fn text(value: &Value) -> Option<String> {
    value
        .as_str()
        .filter(|text| !text.is_empty())
        .map(str::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_model_is_told_every_filter_and_every_culture() {
        let told = definition();
        let properties = told["function"]["parameters"]["properties"]
            .as_object()
            .unwrap();
        assert_eq!(properties.len(), 12);
        assert!(told["function"]["parameters"].get("required").is_none());
        let cultures = properties["language_ethnicity"]["enum"].as_array().unwrap();
        assert!(cultures.iter().any(|culture| culture == "japanese"));
        assert!(note().contains("japanese") && !note().contains("%CULTURES%"));
    }

    /// The extension's R13 (5ff9fb2): the answer keeps the name the
    /// narrator's until the user's character hears or reads it.
    #[test]
    fn the_answer_keeps_the_name_back_until_it_is_revealed() {
        let mut used = picker::Used::default();
        let filters = Filters::from([("language_ethnicity", vec!["japanese".to_string()])]);
        let picked = picker::pick(database::names(), &filters, &mut used, &mut |_| 0).unwrap();
        let answer: Value = serde_json::from_str(&answer::of(&picked)).unwrap();
        assert_eq!(answer["reveal"], answer::REVEAL);
        assert!(answer::REVEAL.contains("only once the user's character hears or reads it"));
        assert!(note().contains("`reveal`"));
    }

    /// The extension's R13 (5ff9fb2): a name may be settled early and kept
    /// back until it is revealed.
    #[test]
    fn a_name_may_be_settled_early_and_kept_back() {
        let told = definition();
        let description = told["function"]["description"].as_str().unwrap();
        for text in [note().as_str(), description] {
            assert!(text.starts_with("Settle a new character's name: call suggest_npc_name"));
            assert!(text.contains("An earlier call is fine if you keep the name back"));
        }
        assert!(description.contains("the user's character hears or reads it"));
        assert!(!note().contains("into your narration naturally"));
    }

    #[test]
    fn filters_are_read_as_values_or_lists_and_empty_ones_are_none() {
        let read =
            filters(r#"{"themes":"regal","gender":null,"age":[],"era":["", "modern"],"x":"y"}"#)
                .unwrap();
        assert_eq!(read.len(), 2);
        assert_eq!(read["themes"], ["regal"]);
        assert_eq!(read["era"], ["modern"]);
        assert!(filters("").unwrap().is_empty());
        assert!(filters("[1]").is_err());
        assert_eq!(
            asked(r#"{"language_ethnicity":"japanese","gender":"female"}"#),
            "female, japanese"
        );
    }
}

//! A chat's own tools (`ALL`): those a chat reply is offered by a switch of
//! Tools for the AI and that run on the server at once, without asking the
//! user: the dice (`dice`) and names for new characters (`names`). Each tool's
//! module fills one `ChatTool`; the offer, the run, "Used in this reply", the
//! names a written tool cannot take, the Reply length (`cuts`) and the MCP
//! server's list (which leaves them out) read them here, so a new chat tool
//! is its module and a line in `ALL`.

use cw_library::settings::Tools;
use serde_json::Value;

/// What a chat tool's call runs with.
pub struct Turn<'a> {
    /// The call's arguments as the model wrote them.
    pub arguments: &'a str,
    pub store: &'a dyn crate::ports::Storage,
    /// The chat the reply is in, where it is in one.
    pub chat_id: Option<i64>,
}

/// What a call came to: the text the model reads and, where its result tells
/// more than what was asked, what "Used in this reply" shows.
pub type Ran = anyhow::Result<(String, Option<String>)>;

/// A chat tool.
pub struct ChatTool {
    /// The name the model calls it by.
    pub name: &'static str,
    /// Whether the settings switch it on.
    pub on: fn(&Tools) -> bool,
    /// The tool as the model is told of it.
    pub definition: fn() -> Value,
    /// What the model is told of it before the latest message while it is on, where anything.
    pub note: Option<fn() -> String>,
    /// What a call's arguments asked, as "Used in this reply" shows it.
    pub asked: fn(&str) -> String,
    /// Runs a call; it may block.
    pub run: fn(Turn<'_>) -> Ran,
    /// Whether its call's arguments are a few short words, which the Reply
    /// length cannot cut (the dice's; not the names tool's twelve filters).
    pub short: bool,
}

/// Every chat tool.
pub const ALL: [&ChatTool; 2] = [&crate::tools::dice::TOOL, &crate::tools::names::TOOL];

/// The chat tool called `name`.
pub fn named(name: &str) -> Option<&'static ChatTool> {
    ALL.into_iter().find(|tool| tool.name == name)
}

/// Whether a request offered `definitions` is sent no Reply length: where any
/// tool is offered whose call's arguments a limit could cut, all but a chat
/// tool's that are `short`.
pub fn cuts(definitions: &[Value]) -> bool {
    definitions.iter().any(|definition| {
        let name = definition["function"]["name"].as_str().unwrap_or_default();
        !named(name).is_some_and(|tool| tool.short)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_short_arguments_keep_the_reply_length() {
        let other = crate::tools::tool("web_search", "", serde_json::json!({}));
        let dice = (crate::tools::dice::TOOL.definition)();
        let names = (crate::tools::names::TOOL.definition)();
        assert!(!cuts(std::slice::from_ref(&dice)));
        assert!(!cuts(&[]));
        assert!(cuts(&[dice.clone(), names]));
        assert!(cuts(&[dice, other]));
    }
}

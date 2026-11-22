//! What a reply keeps of each tool call it made, for the side panel's "Used in
//! this reply": the tool, how the call ended and one short "what" (the owner,
//! 2026-11-18). Arguments can be a whole file, a written tool's code or the
//! values sent to Cardwave's functions, and results are long, so `what` is only
//! ever the one field `asked` names, cut at `MOST` characters; of results only
//! a chat tool's (the dice, a new character's name) and a page's title
//! (`Done::shown`). An address loses the name,
//! password, query and fragment it may carry.

use cw_platform::http::Url;
use cw_provider::Call;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::tools::builtin;

/// The most characters of a line's tool name and of its `what`.
pub(crate) const MOST: usize = 80;

/// How a tool call ended.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum CallEnd {
    Done,
    /// The user refused it.
    NotAllowed,
    Failed,
    /// The reply was stopped while it ran or waited.
    Stopped,
}

/// A tool call of a reply, as "Used in this reply" lists it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct UsedCall {
    pub tool: String,
    /// What it was about; empty where nothing can be said (a written tool's call).
    pub what: String,
    pub end: CallEnd,
}

/// The line of `call`, which ended as `end`; `shown` is what its result lets
/// say instead of what was asked.
pub fn of(call: &Call, end: CallEnd, shown: Option<String>) -> UsedCall {
    UsedCall {
        tool: short(&call.name),
        what: short(&shown.unwrap_or_else(|| asked(call))),
        end,
    }
}

/// A page read as "[title] · [site]", its address where it has no title.
pub(crate) fn page_line(title: &str, address: &str) -> String {
    let parsed = Url::parse(address.trim()).ok();
    let site = parsed
        .as_ref()
        .and_then(Url::host_str)
        .map(|host| host.strip_prefix("www.").unwrap_or(host));
    match site {
        Some(site) if !title.trim().is_empty() => format!("{} · {site}", title.trim()),
        _ => bare_address(address),
    }
}

/// The one field of `call`'s arguments that says what it was about.
fn asked(call: &Call) -> String {
    if let Some(tool) = crate::tools::chat::named(&call.name) {
        return (tool.asked)(&call.arguments);
    }
    match call.name.as_str() {
        builtin::WEB_SEARCH => call.argument("query"),
        builtin::READ_WEB_PAGE => bare_address(&call.argument("url")),
        builtin::LIST_FILES | builtin::READ_FILE | builtin::WRITE_FILE => call.argument("path"),
        builtin::RUN_COMMAND => call.argument("command"),
        builtin::MAKE_PICTURE => call.argument("description"),
        crate::tools::written::MAKE => call.argument("name"),
        crate::tools::app::CALL | crate::tools::app::HELP => call.argument("tool"),
        // The goal stands in the offer the chat shows under the reply.
        builtin::START_CODING => String::new(),
        // Any other name is a written tool's, whose arguments are its own and
        // can be anything the user keeps: nothing of them is kept.
        _ => String::new(),
    }
}

/// `address` without what can be secret in it: a name, a password, and all
/// after `?` or `#`, where a key can stand. A web address is written as the
/// browser writes it; anything else, which the model may have sent and no
/// page was read from, is cut as text.
fn bare_address(address: &str) -> String {
    let address = address.trim();
    if let Ok(mut parsed) = Url::parse(address)
        && matches!(parsed.scheme(), "http" | "https")
    {
        // Neither refuses on an http(s) address, which always has a host.
        let _ = parsed.set_username("");
        let _ = parsed.set_password(None);
        parsed.set_query(None);
        parsed.set_fragment(None);
        return parsed.into();
    }
    let bare = address.split(['?', '#']).next().unwrap_or_default();
    let start = bare.find("//").map_or(0, |at| at + 2);
    let end = bare[start..].find('/').map_or(bare.len(), |at| start + at);
    match bare[start..end].rfind('@') {
        Some(at) => format!("{}{}", &bare[..start], &bare[start + at + 1..]),
        None => bare.to_string(),
    }
}

/// `text` on one line, cut at [`MOST`] characters with "…" where it goes on.
fn short(text: &str) -> String {
    let line = text.split_whitespace().collect::<Vec<_>>().join(" ");
    match line.char_indices().nth(MOST) {
        Some((at, _)) => format!("{}…", &line[..at]),
        None => line,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn what(name: &str, arguments: serde_json::Value) -> String {
        let call = Call {
            id: String::new(),
            name: name.into(),
            arguments: arguments.to_string(),
        };
        of(&call, CallEnd::Done, None).what
    }

    #[test]
    fn each_tool_says_its_one_field_and_nothing_else() {
        let cases = [
            ("web_search", json!({ "query": "lamp oil" }), "lamp oil"),
            ("list_files", json!({ "path": "notes" }), "notes"),
            ("run_command", json!({ "command": "ls  -l\n" }), "ls -l"),
            ("make_picture", json!({ "description": "a boat" }), "a boat"),
            (
                "cardwave",
                json!({ "tool": "make_card", "arguments": { "name": "SECRET" } }),
                "make_card",
            ),
            ("cardwave_help", json!({ "tool": "make_card" }), "make_card"),
            (
                "make_tool",
                json!({ "name": "lamp", "code": "SECRET" }),
                "lamp",
            ),
            (
                "write_file",
                json!({ "path": "a.txt", "content": "SECRET" }),
                "a.txt",
            ),
            ("dice", json!({ "count": "2", "sides": 6.0 }), "2d6"),
            ("start_coding_task", json!({ "goal": "SECRET" }), ""),
            ("lamp_tool", json!({ "key": "SECRET" }), ""),
        ];
        for (tool, arguments, said) in cases {
            assert_eq!(what(tool, arguments), said, "{tool}");
        }
    }

    #[test]
    fn an_address_is_kept_without_what_can_be_secret() {
        let cases = [
            (
                " https://ann:pw@example.com/oil ",
                "https://example.com/oil",
            ),
            (
                "https://example.com/oil?key=SECRET#top",
                "https://example.com/oil",
            ),
            ("ann:pw@example.com/oil?key=SECRET", "example.com/oil"),
            ("//ann:pw@example.com/oil", "//example.com/oil"),
            ("ftp://ann:pw@example.com/oil", "ftp://example.com/oil"),
            ("not one", "not one"),
        ];
        for (url, said) in cases {
            assert_eq!(what("read_web_page", json!({ "url": url })), said, "{url}");
        }
    }

    #[test]
    fn a_page_is_its_title_and_site_or_else_its_address() {
        let address = "https://www.example.com/oil";
        assert_eq!(page_line("Oil", address), "Oil · example.com");
        assert_eq!(page_line(" ", address), address);
    }

    #[test]
    fn a_long_what_is_cut_on_a_character() {
        let said = what("web_search", json!({ "query": "é".repeat(MOST + 1) }));
        assert_eq!(said, format!("{}…", "é".repeat(MOST)));
    }
}

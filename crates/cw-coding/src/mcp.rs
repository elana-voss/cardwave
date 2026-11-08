//! What the MCP server (`api::mcp`) keeps, all in `meta`: Account › Server's
//! "Other programs" switch (`mcp`), the account served (`mcp_account`), and the
//! programs by the name each gives itself (`mcp_programs`). A program removed
//! is refused until the switch is switched on anew, which forgets them all.

use serde::{Deserialize, Serialize};
use ts_rs::TS;

use cw_core::NotFound;

/// What Account › Server's group "Other programs" shows.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct McpSettings {
    /// Whether other programs are served.
    pub on: bool,
    /// The account whose cards, chats and tools they see.
    pub account: i64,
    /// The programs that connected since it was switched on, the first first.
    pub programs: Vec<String>,
}

/// A change of the group; what is left out stays as it is.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeMcp {
    pub on: Option<bool>,
    pub account: Option<i64>,
    /// A program to refuse from now on, until the switch is switched on anew.
    pub remove: Option<String>,
}

/// What the MCP server needs of the database, which `cw_store::mcp` gives.
pub trait Storage {
    /// The group as it is: the account served is this computer's (`local`)
    /// where none was chosen or the one chosen was deleted.
    fn mcp_settings(&self, local: i64) -> anyhow::Result<McpSettings>;
    fn is_account(&self, id: i64) -> anyhow::Result<bool>;
    /// Applies `change`, its account known to exist, and answers the group as it then is.
    fn change_mcp(&self, local: i64, change: ChangeMcp) -> anyhow::Result<McpSettings>;
    /// As [`admit`].
    fn admit_program(&self, local: i64, name: Option<&str>) -> anyhow::Result<Result<i64, String>>;
}

/// The group as it is.
pub fn settings(db: &dyn Storage, local: i64) -> anyhow::Result<McpSettings> {
    db.mcp_settings(local)
}

/// Applies `change` and answers the group as it then is; an account that does
/// not exist is `NotFound`.
pub fn change(db: &dyn Storage, local: i64, change: ChangeMcp) -> anyhow::Result<McpSettings> {
    if let Some(account) = change.account {
        anyhow::ensure!(db.is_account(account)?, NotFound("account"));
    }
    db.change_mcp(local, change)
}

/// The account a request of the program `name` is served as, noting the
/// program where it is new; or why it is refused.
pub fn admit(
    db: &dyn Storage,
    local: i64,
    name: Option<&str>,
) -> anyhow::Result<Result<i64, String>> {
    db.admit_program(local, name)
}

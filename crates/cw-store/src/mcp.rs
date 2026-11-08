//! What the MCP server keeps (`mcp::Storage`), all in `meta`: the switch
//! (`mcp`), the account served (`mcp_account`), the programs (`mcp_programs`).

use cw_coding::mcp::{ChangeMcp, McpSettings, Storage};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};

use crate::{Db, meta, set_meta};

/// The programs as `meta` keeps them.
#[derive(Default, Serialize, Deserialize)]
struct Programs {
    connected: Vec<String>,
    removed: Vec<String>,
}

fn programs(conn: &Connection) -> rusqlite::Result<Programs> {
    let kept = meta(conn, "mcp_programs")?;
    Ok(kept
        .and_then(|kept| serde_json::from_str(&kept).ok())
        .unwrap_or_default())
}

fn keep(conn: &Connection, programs: &Programs) -> rusqlite::Result<()> {
    let text = serde_json::to_string(programs).unwrap_or_default();
    set_meta(conn, "mcp_programs", &text)
}

fn account_is(conn: &Connection, id: i64) -> rusqlite::Result<bool> {
    conn.query_row(
        "select exists (select 1 from users where id = ?1)",
        [id],
        |r| r.get(0),
    )
}

/// The group as it is: the account served is this computer's (`local`) where
/// none was chosen or the one chosen was deleted.
fn served(conn: &Connection, local: i64) -> rusqlite::Result<McpSettings> {
    let chosen = meta(conn, "mcp_account")?.and_then(|id| id.parse().ok());
    let account = match chosen {
        Some(id) if account_is(conn, id)? => id,
        _ => local,
    };
    Ok(McpSettings {
        on: meta(conn, "mcp")?.as_deref() == Some("on"),
        account,
        programs: programs(conn)?.connected,
    })
}

impl Storage for Db {
    fn mcp_settings(&self, local: i64) -> anyhow::Result<McpSettings> {
        Ok(self.with(|conn| served(conn, local))?)
    }

    fn is_account(&self, id: i64) -> anyhow::Result<bool> {
        Ok(self.with(|conn| account_is(conn, id))?)
    }

    fn change_mcp(&self, local: i64, change: ChangeMcp) -> anyhow::Result<McpSettings> {
        Ok(self.with(|conn| {
            let was = served(conn, local)?;
            if let Some(on) = change.on {
                // Switched on anew, it begins with no program.
                if on && !was.on {
                    keep(conn, &Programs::default())?;
                }
                set_meta(conn, "mcp", if on { "on" } else { "off" })?;
            }
            if let Some(account) = change.account {
                set_meta(conn, "mcp_account", &account.to_string())?;
            }
            if let Some(name) = change.remove {
                let mut programs = programs(conn)?;
                programs.connected.retain(|one| *one != name);
                if !programs.removed.contains(&name) {
                    programs.removed.push(name);
                }
                keep(conn, &programs)?;
            }
            served(conn, local)
        })?)
    }

    fn admit_program(&self, local: i64, name: Option<&str>) -> anyhow::Result<Result<i64, String>> {
        Ok(self.with(|conn| {
            let settings = served(conn, local)?;
            if !settings.on {
                let off = "Cardwave serves no other programs until \"Let AI apps on this computer use Cardwave\" is switched on in its Account › Sharing.";
                return Ok(Err(off.into()));
            }
            if let Some(name) = name {
                let mut programs = programs(conn)?;
                if programs.removed.iter().any(|one| one == name) {
                    return Ok(Err(format!(
                        "\"{name}\" was removed in Cardwave's Account › Sharing. Switching \"Let AI apps on this computer use Cardwave\" off and on lets it in again."
                    )));
                }
                if !programs.connected.iter().any(|one| one == name) {
                    programs.connected.push(name.to_string());
                    keep(conn, &programs)?;
                }
            }
            Ok(Ok(settings.account))
        })?)
    }
}

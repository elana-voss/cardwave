//! The providers, the kinds of model and the model presets as SQLite keeps
//! them (`provider::Storage`, `provider::kinds::Storage`,
//! `provider::presets::Storage`): `provider_entries`, a row per provider of an
//! account, with a ComfyUI's workflow picked (`workflow*`, empty for none); `model_kinds`, a row per kind with its provider, model, how its
//! thinking stands and whether it was seen thinking; the account's values for a reply as JSON in
//! `users.sampling`; and `presets`, a row per preset or, with `replaced`, per
//! chat model a preset took the place of. `chat` reads the chat kind as the
//! provider the chats ask.

use cw_core::now_ms;
use cw_provider::kinds::{self, Entry, Kind, Picked, Thinking, Workflow};
use cw_provider::presets::{self, Named, Used};
use cw_provider::{Provider, Sampling, Storage, Stored};
use rusqlite::types::Type;
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::Db;

/// Reads JSON of the values for a reply from column `at` of `row`.
fn sampling_at(row: &Row<'_>, at: usize) -> rusqlite::Result<Sampling> {
    let values: String = row.get(at)?;
    serde_json::from_str(&values)
        .map_err(|error| rusqlite::Error::FromSqlConversionFailure(at, Type::Text, Box::new(error)))
}

/// Reads one from five columns of `row`, the first of them `at`: the
/// address, the key, the model, the values for a reply and the name.
fn read(row: &Row<'_>, at: usize) -> rusqlite::Result<Provider> {
    Ok(Provider {
        base_url: row.get(at)?,
        api_key: row.get(at + 1)?,
        model: row.get(at + 2)?,
        sampling: sampling_at(row, at + 3)?,
        name: row.get(at + 4)?,
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    })
}

/// The values for a reply as a table keeps them: JSON.
fn values(sampling: &Sampling) -> rusqlite::Result<String> {
    serde_json::to_string(sampling)
        .map_err(|error| rusqlite::Error::ToSqlConversionFailure(Box::new(error)))
}

/// The chat kind of `user` as the provider the chats ask, with its entry.
fn chat(conn: &Connection, user: i64) -> rusqlite::Result<Option<(Provider, i64)>> {
    conn.query_row(
        "select e.base_url, e.api_key, k.model, u.sampling, e.name, k.thinking, e.id, k.seen_thinking
         from model_kinds k join provider_entries e on e.id = k.entry_id join users u on u.id = k.user_id
         where k.user_id = ?1 and k.kind = 'chat'",
        [user],
        |row| {
            let thinking: String = row.get(5)?;
            let provider = Provider {
                thinking_off: match Thinking::read(&thinking) {
                    Thinking::Off(form) => Some(form),
                    _ => None,
                },
                seen_thinking: row.get(7)?,
                ..read(row, 0)?
            };
            Ok((provider, row.get(6)?))
        },
    )
    .optional()
}

/// The entry at `base_url` with `key`, added where `user` has none: its ID.
fn entry_for(
    conn: &Connection,
    user: i64,
    base_url: &str,
    key: &str,
    name: &str,
) -> rusqlite::Result<i64> {
    let found: Option<i64> = conn
        .query_row(
            "select min(id) from provider_entries where user_id = ?1 and base_url = ?2 and api_key = ?3",
            params![user, base_url, key],
            |r| r.get(0),
        )?;
    match found {
        Some(id) => Ok(id),
        None => conn.query_row(
            "insert into provider_entries (user_id, name, base_url, api_key, created_at)
             values (?1, ?2, ?3, ?4, ?5) returning id",
            params![user, name, base_url, key, now_ms()],
            |r| r.get(0),
        ),
    }
}

/// Puts `kind` at the entry with the model, its thinking on; the background
/// kind at the chat model's is none. Whether the entry is the user's.
fn pick(
    conn: &Connection,
    user: i64,
    kind: Kind,
    entry: i64,
    model: &str,
) -> rusqlite::Result<bool> {
    let owned: bool = conn.query_row(
        "select exists (select 1 from provider_entries where id = ?1 and user_id = ?2)",
        [entry, user],
        |r| r.get(0),
    )?;
    if !owned {
        return Ok(false);
    }
    let same_as_chat = kind == Kind::Background
        && chat(conn, user)?.is_some_and(|(chat, at)| at == entry && chat.model == model);
    if same_as_chat {
        conn.execute(
            "delete from model_kinds where user_id = ?1 and kind = 'background'",
            [user],
        )?;
        return Ok(true);
    }
    conn.execute(
        "insert into model_kinds (user_id, kind, entry_id, model, thinking) values (?1, ?2, ?3, ?4, '')
         on conflict (user_id, kind) do update set entry_id = excluded.entry_id, model = excluded.model,
            thinking = case when model_kinds.entry_id = excluded.entry_id and model_kinds.model = excluded.model
                then model_kinds.thinking else '' end,
            seen_thinking = model_kinds.seen_thinking and model_kinds.entry_id = excluded.entry_id
                and model_kinds.model = excluded.model",
        params![user, kind.as_str(), entry, model],
    )?;
    Ok(true)
}

fn set_sampling(conn: &Connection, user: i64, sampling: &Sampling) -> rusqlite::Result<()> {
    conn.execute(
        "update users set sampling = ?2 where id = ?1",
        params![user, values(sampling)?],
    )?;
    Ok(())
}

/// Stores `provider` as the chat kind of `user`, at the entry of its address:
/// `at`, the chat's own entry, where the address stays (its key and name are
/// changed), else one with that key, else a new one. Lets go of the chat
/// model a preset took the place of. Answers the entry.
fn write(conn: &Connection, user: i64, provider: &Provider) -> rusqlite::Result<()> {
    let entry = entry_for(
        conn,
        user,
        &provider.base_url,
        &provider.api_key,
        &provider.name,
    )?;
    pick(conn, user, Kind::Chat, entry, &provider.model)?;
    set_sampling(conn, user, &provider.sampling)?;
    forget_replaced(conn, Some(user))
}

/// The key of the account's first entry at `base_url`, else none.
fn kept_key(conn: &Connection, user: i64, base_url: &str) -> rusqlite::Result<String> {
    let first = conn
        .query_row(
            "select api_key from provider_entries where user_id = ?1 and base_url = ?2 order by id limit 1",
            params![user, base_url],
            |r| r.get(0),
        )
        .optional()?;
    Ok(first.unwrap_or_default())
}

/// Gives the entry `id` another name, address or key; the presets of its old
/// address and key go with it, as a preset holds its address and key.
fn move_entry(
    conn: &Connection,
    user: i64,
    id: i64,
    name: &str,
    base_url: &str,
    api_key: &str,
) -> rusqlite::Result<bool> {
    let before: Option<(String, String)> = conn
        .query_row(
            "select base_url, api_key from provider_entries where id = ?1 and user_id = ?2",
            [id, user],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    let Some((old_url, old_key)) = before else {
        return Ok(false);
    };
    conn.execute(
        "update provider_entries set name = ?3, base_url = ?4, api_key = ?5 where id = ?1 and user_id = ?2",
        params![id, user, name, base_url, api_key],
    )?;
    conn.execute(
        "update presets set base_url = ?4, api_key = ?5, provider_name = ?6
         where user_id = ?1 and base_url = ?2 and api_key = ?3",
        params![user, old_url, old_key, base_url, api_key, name],
    )?;
    Ok(true)
}

/// What the row `id` holds, a preset or the chat model one took the place of,
/// if it is the user's.
fn holds_of(conn: &Connection, user: i64, id: i64) -> rusqlite::Result<Option<Provider>> {
    conn.query_row(
        "select base_url, api_key, model, sampling, provider_name
         from presets where id = ?1 and user_id = ?2",
        [id, user],
        |r| read(r, 0),
    )
    .optional()
}

/// Adds a row that holds `holds`: a preset called `name`, or, with `replaced`,
/// the chat model a preset took the place of, which has no name, as no preset
/// has. Answers its number, and `None` for a preset whose name another of the
/// user's has, which adds no row.
fn insert(
    conn: &Connection,
    user: i64,
    name: &str,
    holds: &Provider,
    replaced: bool,
) -> rusqlite::Result<Option<i64>> {
    conn.query_row(
        "insert into presets (user_id, name, base_url, api_key, model, sampling, provider_name, replaced, created_at)
         select ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9
         where not exists (select 1 from presets where user_id = ?1 and name = ?2 and replaced = 0)
         returning id",
        params![
            user,
            name,
            holds.base_url,
            holds.api_key,
            holds.model,
            values(&holds.sampling)?,
            holds.name,
            replaced,
            now_ms(),
        ],
        |r| r.get(0),
    )
    .optional()
}

/// Lets go of the chat models that presets took the place of: `user`'s, or
/// everyone's. With them goes what they alone held, a key among it.
fn forget_replaced(conn: &Connection, user: Option<i64>) -> rusqlite::Result<()> {
    conn.execute(
        "delete from presets where replaced = 1 and (?1 is null or user_id = ?1)",
        [user],
    )?;
    Ok(())
}

impl Storage for Db {
    fn set_provider(&self, user: i64, new: &Stored) -> anyhow::Result<()> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let own = chat(&tx, user)?
                .filter(|(chat, _)| chat.base_url == new.base_url)
                .map(|(_, entry)| entry);
            let entry = match own {
                Some(entry) => entry,
                None => {
                    let key = match &new.api_key {
                        Some(key) => key.clone(),
                        None => kept_key(&tx, user, &new.base_url)?,
                    };
                    let name = new.name.as_deref().unwrap_or_default();
                    entry_for(&tx, user, &new.base_url, &key, name)?
                }
            };
            let (name, key): (String, String) = tx.query_row(
                "select name, api_key from provider_entries where id = ?1",
                [entry],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )?;
            let typed = new.api_key.as_ref().filter(|_| own.is_some());
            let renamed = new
                .name
                .as_ref()
                .filter(|typed| **typed != name && (own.is_some() || !typed.is_empty()));
            if typed.is_some() || renamed.is_some() {
                let name = renamed.unwrap_or(&name);
                move_entry(&tx, user, entry, name, &new.base_url, typed.unwrap_or(&key))?;
            }
            if let Some(sampling) = &new.sampling {
                set_sampling(&tx, user, sampling)?;
            }
            pick(&tx, user, Kind::Chat, entry, &new.model)?;
            match new.worker.as_deref() {
                Some("") => {
                    tx.execute(
                        "delete from model_kinds where user_id = ?1 and kind = 'background'",
                        [user],
                    )?;
                }
                Some(worker) => {
                    pick(&tx, user, Kind::Background, entry, worker)?;
                }
                None => {}
            }
            if let Some(image) = &new.image {
                pick(&tx, user, Kind::Images, entry, image)?;
            }
            forget_replaced(&tx, Some(user))?;
            tx.commit()
        })?)
    }

    fn forget_replaced_providers(&self, user: Option<i64>) -> anyhow::Result<()> {
        Ok(self.with(|conn| forget_replaced(conn, user))?)
    }
}

impl kinds::Storage for Db {
    fn chat_provider(&self, user: i64) -> anyhow::Result<Option<Provider>> {
        Ok(self.with(|conn| chat(conn, user))?.map(|(chat, _)| chat))
    }

    fn entries(&self, user: i64) -> anyhow::Result<Vec<Entry>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select id, name, base_url, api_key, workflow, workflow_node, workflow_input
                 from provider_entries where user_id = ?1 order by id",
            )?
            .query_map([user], |r| {
                let workflow: String = r.get(4)?;
                Ok(Entry {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    base_url: r.get(2)?,
                    api_key: r.get(3)?,
                    workflow: match workflow.is_empty() {
                        true => None,
                        false => Some(Workflow {
                            name: workflow,
                            node: r.get(5)?,
                            input: r.get(6)?,
                        }),
                    },
                })
            })?
            .collect()
        })?)
    }

    fn picked(&self, user: i64) -> anyhow::Result<Vec<Picked>> {
        Ok(self.with(|conn| {
            conn.prepare(
                "select kind, entry_id, model, thinking, seen_thinking from model_kinds where user_id = ?1
                 order by case kind when 'chat' then 0 when 'background' then 1 when 'images' then 2
                    when 'search' then 3 else 4 end",
            )?
            .query_map([user], |r| {
                let kind: String = r.get(0)?;
                let thinking: String = r.get(3)?;
                Ok(Picked {
                    // The table's check holds every kind to those `Kind` has.
                    kind: Kind::of(&kind).unwrap_or(Kind::Chat),
                    entry: r.get(1)?,
                    model: r.get(2)?,
                    thinking: Thinking::read(&thinking),
                    seen_thinking: r.get(4)?,
                })
            })?
            .collect()
        })?)
    }

    fn entry_for(&self, user: i64, base_url: &str, key: &str, name: &str) -> anyhow::Result<i64> {
        Ok(self.with(|conn| entry_for(conn, user, base_url, key, name))?)
    }

    fn change_entry(&self, user: i64, entry: &Entry) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let (name, url, key) = (&entry.name, &entry.base_url, &entry.api_key);
            let changed = move_entry(&tx, user, entry.id, name, url, key)?;
            tx.commit()?;
            Ok(changed)
        })?)
    }

    fn set_workflow(
        &self,
        user: i64,
        id: i64,
        workflow: Option<&Workflow>,
    ) -> anyhow::Result<bool> {
        let (name, node, input) = workflow
            .map(|w| (w.name.as_str(), w.node.as_str(), w.input.as_str()))
            .unwrap_or_default();
        let changed = self.with(|conn| {
            conn.execute(
                "update provider_entries set workflow = ?3, workflow_node = ?4, workflow_input = ?5
                 where id = ?1 and user_id = ?2",
                params![id, user, name, node, input],
            )
        })?;
        Ok(changed == 1)
    }

    fn remove_entry(&self, user: i64, id: i64) -> anyhow::Result<bool> {
        let gone = self.with(|conn| {
            conn.execute(
                "delete from provider_entries where id = ?1 and user_id = ?2",
                [id, user],
            )
        })?;
        Ok(gone == 1)
    }

    fn pick(&self, user: i64, kind: Kind, entry: i64, model: &str) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let picked = pick(&tx, user, kind, entry, model)?;
            // The chat model stored otherwise than by a preset leaves no way back.
            if picked && kind == Kind::Chat {
                forget_replaced(&tx, Some(user))?;
            }
            tx.commit()?;
            Ok(picked)
        })?)
    }

    fn unpick(&self, user: i64, kind: Kind) -> anyhow::Result<bool> {
        let gone = self.with(|conn| {
            conn.execute(
                "delete from model_kinds where user_id = ?1 and kind = ?2",
                params![user, kind.as_str()],
            )
        })?;
        Ok(gone == 1)
    }

    fn set_thinking(
        &self,
        user: i64,
        kind: Kind,
        model: &str,
        thinking: Thinking,
    ) -> anyhow::Result<bool> {
        let changed = self.with(|conn| {
            conn.execute(
                "update model_kinds set thinking = ?4 where user_id = ?1 and kind = ?2 and model = ?3",
                params![user, kind.as_str(), model, thinking.kept()],
            )
        })?;
        Ok(changed == 1)
    }

    fn saw_thinking(&self, user: i64, kind: Kind, model: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update model_kinds set seen_thinking = 1 where user_id = ?1 and kind = ?2 and model = ?3",
                params![user, kind.as_str(), model],
            )
        })?;
        Ok(())
    }

    fn sampling(&self, user: i64) -> anyhow::Result<Sampling> {
        Ok(self
            .with(|conn| {
                conn.query_row("select sampling from users where id = ?1", [user], |r| {
                    sampling_at(r, 0)
                })
                .optional()
            })?
            .unwrap_or_default())
    }

    fn set_sampling(&self, user: i64, sampling: &Sampling) -> anyhow::Result<()> {
        Ok(self.with(|conn| set_sampling(conn, user, sampling))?)
    }
}

impl presets::Storage for Db {
    fn model_presets(&self, user: i64) -> anyhow::Result<presets::KeptModelPresets> {
        Ok(self.with(|conn| {
            let stored = chat(conn, user)?.map(|(provider, _)| provider);
            let rows: Vec<(i64, String, Provider)> = conn
                .prepare(
                    "select id, name, base_url, api_key, model, sampling, provider_name
                     from presets where user_id = ?1 and replaced = 0",
                )?
                .query_map([user], |r| Ok((r.get(0)?, r.get(1)?, read(r, 2)?)))?
                .collect::<rusqlite::Result<_>>()?;
            Ok(presets::KeptModelPresets {
                stored,
                presets: rows,
            })
        })?)
    }

    fn preset_holds(&self, user: i64, id: i64) -> anyhow::Result<Option<Provider>> {
        Ok(self.with(|conn| holds_of(conn, user, id))?)
    }

    fn add_preset(&self, user: i64, name: &str, holds: &Provider) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| insert(conn, user, name, holds, false))?)
    }

    fn change_preset(
        &self,
        user: i64,
        id: i64,
        name: Option<&str>,
        holds: Option<&Provider>,
    ) -> anyhow::Result<usize> {
        let values = holds.map(|holds| values(&holds.sampling)).transpose()?;
        // A name that another preset has changes no row.
        let changed = self.with(|conn| {
            conn.execute(
                "update presets set
                    name = coalesce(?3, name), base_url = coalesce(?4, base_url),
                    api_key = coalesce(?5, api_key), model = coalesce(?6, model),
                    sampling = coalesce(?7, sampling), provider_name = coalesce(?8, provider_name)
                 where id = ?1 and user_id = ?2 and replaced = 0 and not exists (
                    select 1 from presets where user_id = ?2 and name = ?3 and id <> ?1 and replaced = 0)",
                params![
                    id,
                    user,
                    name,
                    holds.map(|holds| &holds.base_url),
                    holds.map(|holds| &holds.api_key),
                    holds.map(|holds| &holds.model),
                    values,
                    holds.map(|holds| &holds.name),
                ],
            )
        })?;
        Ok(changed)
    }

    fn copy_preset(&self, user: i64, id: i64, named: &Named) -> anyhow::Result<Option<i64>> {
        Ok(self.with(|conn| {
            let presets: Vec<(i64, String)> = conn
                .prepare("select id, name from presets where user_id = ?1 and replaced = 0")?
                .query_map([user], |r| Ok((r.get(0)?, r.get(1)?)))?
                .collect::<rusqlite::Result<_>>()?;
            let Some(copy) = named(&presets) else {
                return Ok(None);
            };
            conn.query_row(
                "insert into presets (user_id, name, base_url, api_key, model, sampling, provider_name, created_at)
                 select user_id, ?2, base_url, api_key, model, sampling, provider_name, ?3
                 from presets where id = ?1
                 returning id",
                params![id, copy, now_ms()],
                |r| r.get(0),
            )
            .map(Some)
        })?)
    }

    fn delete_preset(&self, user: i64, id: i64) -> anyhow::Result<bool> {
        let gone = self.with(|conn| {
            conn.execute(
                "delete from presets where id = ?1 and user_id = ?2 and replaced = 0",
                [id, user],
            )
        })?;
        Ok(gone == 1)
    }

    fn put_preset_in_use(&self, user: i64, id: i64) -> anyhow::Result<Option<Used>> {
        Ok(self.with(|conn| {
            let tx = conn.transaction()?;
            let Some(provider) = holds_of(&tx, user, id)? else {
                return Ok(None);
            };
            let before = chat(&tx, user)?.map(|(before, _)| before);
            // The store lets the row kept until now go, which may be the one put in
            // use; the chat model stored until now is kept after it, so it is the one.
            // The preset's provider is the entry of its address and key, which no
            // other kind at the chat's entry has changed under it.
            write(&tx, user, &provider)?;
            let before = match before {
                Some(before) => insert(&tx, user, "", &before, true)?,
                None => None,
            };
            let provider = chat(&tx, user)?
                .map(|(provider, _)| provider)
                .unwrap_or(provider);
            tx.commit()?;
            Ok(Some(Used { provider, before }))
        })?)
    }
}

//! A chat's messages as SQLite keeps them (`chats::messages::Storage`): a
//! tree by `parent_id`, the chat's `head_id` the newest in view, a deleted one
//! hidden by `deleted_from` until it is purged.

use anyhow::{anyhow, ensure};
use cw_chat::chats::export::WrittenOut;
use cw_chat::chats::messages::Storage;
use cw_chat::chats::{
    BUSY, Chat, ContextUse, IN_TRASH, Message, MessageView, NOT_IN_CHAT, NewMessage,
};
use cw_coding::tools::Read;
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};
use cw_prompt::Role;
use rusqlite::{Connection, OptionalExtension, Row, params};

use crate::Db;
use crate::chats::{chat_of, writing};

fn role_name(role: Role) -> &'static str {
    match role {
        Role::System => "system",
        Role::User => "user",
        Role::Assistant => "assistant",
    }
}

pub(super) fn message(row: &Row<'_>) -> rusqlite::Result<Message> {
    let role = match row.get::<_, String>(2)?.as_str() {
        "user" => Role::User,
        "assistant" => Role::Assistant,
        _ => Role::System,
    };
    Ok(Message {
        id: row.get(0)?,
        parent_id: row.get(1)?,
        role,
        speaker_id: row.get(3)?,
        content: row.get(4)?,
        complete: row.get(5)?,
        token_count: row
            .get::<_, Option<i64>>(6)?
            .and_then(|n| usize::try_from(n).ok()),
        created_at: row.get(7)?,
    })
}

fn message_view(row: &Row<'_>) -> rusqlite::Result<MessageView> {
    let swipes: String = row.get(8)?;
    let lore: Option<String> = row.get(9)?;
    // What cannot be read is shown as none: the chat opens all the same.
    let lore = lore.and_then(|lore| {
        serde_json::from_str(&lore)
            .inspect_err(|error| {
                tracing::warn!("a reply's lorebook entries cannot be read: {error}")
            })
            .ok()
    });
    let memories: String = row.get(10)?;
    let message = message(row)?;
    let used: Option<i64> = row.get(12)?;
    let size: Option<i64> = row.get(13)?;
    let context = used.zip(size).map(|(used, size)| ContextUse {
        used: usize::try_from(used).unwrap_or(0),
        size: usize::try_from(size).unwrap_or(0),
    });
    Ok(MessageView {
        tokens: message
            .token_count
            .unwrap_or_else(|| cw_prompt::tokens::estimate(&message.content)),
        context,
        message,
        swipes: swipes.split(',').filter_map(|id| id.parse().ok()).collect(),
        lore: lore.unwrap_or_default(),
        memories: serde_json::from_str(&memories).unwrap_or_default(),
        picture: row.get(11)?,
        task_id: row.get(14)?,
        model: row.get(15)?,
        sent: json_column(row, 16, "parts' tokens")?,
        reads: json_column(row, 17, "pages and files read")?.unwrap_or_default(),
        attachments: json_column(row, 18, "attachments")?.unwrap_or_default(),
        provider: row.get(19)?,
        times: json_column(row, 20, "times")?,
        broke_off: row.get(21)?,
    })
}

/// The JSON in column `at`, where there is any. What cannot be read is
/// taken as none, so that the chat opens all the same.
fn json_column<T: serde::de::DeserializeOwned>(
    row: &Row<'_>,
    at: usize,
    what: &str,
) -> rusqlite::Result<Option<T>> {
    let text: Option<String> = row.get(at)?;
    Ok(text.and_then(|text| {
        serde_json::from_str(&text)
            .inspect_err(|error| tracing::warn!("a reply's {what} cannot be read: {error}"))
            .ok()
    }))
}

/// Adds a message below `parent` and makes it the chat's head. `state` is a
/// [`Snapshot`] the message starts with.
pub(super) fn insert_message(
    conn: &Connection,
    chat_id: i64,
    parent: Option<i64>,
    new: &NewMessage<'_>,
    state: Option<&str>,
) -> rusqlite::Result<i64> {
    let now = now_ms();
    conn.execute(
        "insert into messages (chat_id, parent_id, role, speaker_id, content, complete, state, created_at)
         values (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![chat_id, parent, role_name(new.role), new.speaker_id, new.content, new.complete, state, now],
    )?;
    let id = conn.last_insert_rowid();
    conn.execute(
        "update chats set head_id = ?2, updated_at = ?3 where id = ?1",
        params![chat_id, id, now],
    )?;
    Ok(id)
}

/// Deletes for good what a chat's deletion kept hidden. Nothing that is there
/// hangs below it, as a deletion takes all that follows a message.
pub(super) fn purge(tx: &Connection, chat_id: i64) -> rusqlite::Result<()> {
    tx.execute(
        "delete from messages where chat_id = ?1 and deleted_from is not null",
        [chat_id],
    )?;
    Ok(())
}

/// Removes a reply that ended without text. Nothing hangs below it: its chat
/// took no other message while it was being generated. If the chat's head was
/// on it, the head moves to `head`.
fn remove_empty(tx: &Connection, message_id: i64, head: Option<i64>) -> rusqlite::Result<()> {
    let chat_id: i64 = tx.query_row(
        "delete from messages where id = ?1 returning chat_id",
        [message_id],
        |r| r.get(0),
    )?;
    // Removing the message the head pointed at has left the chat without one.
    tx.execute(
        "update chats set head_id = ?2 where id = ?1 and head_id is null",
        params![chat_id, head],
    )?;
    Ok(())
}

/// Ends the incomplete messages of one chat or of all. Returns their ids,
/// each with whether the message is still there. Those of all say they broke off.
fn end_unwritten(
    conn: &mut Connection,
    chat_id: Option<i64>,
) -> rusqlite::Result<Vec<(i64, bool)>> {
    let tx = conn.transaction()?;
    let unwritten: Vec<(i64, String, Option<i64>)> = tx
        .prepare(
            "select m.id, m.content, coalesce(
                (select max(s.id) from messages s
                 where s.chat_id = m.chat_id and s.parent_id is m.parent_id and s.id <> m.id
                   and s.deleted_from is null),
                m.parent_id)
             from messages m where m.complete = 0 and (?1 is null or m.chat_id = ?1)",
        )?
        .query_map([chat_id], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
        .collect::<rusqlite::Result<_>>()?;
    let mut ended = Vec::new();
    for (message_id, content, head) in unwritten {
        let kept = !content.trim().is_empty();
        if kept {
            // Only a start's end of every chat is a cut-off; one chat's is the user's Stop.
            tx.execute(
                "update messages set complete = 1, broke_off = ?2 where id = ?1",
                params![message_id, chat_id.is_none()],
            )?;
        } else {
            remove_empty(&tx, message_id, head)?;
        }
        ended.push((message_id, kept));
    }
    tx.commit()?;
    Ok(ended)
}

pub(super) const MESSAGE_COLUMNS: &str =
    "m.id, m.parent_id, m.role, m.speaker_id, m.content, m.complete, m.token_count, m.created_at";

/// Columns after [`MESSAGE_COLUMNS`]: the ids of the message and its swipes,
/// oldest first, the lorebook entries its prompt held, and the texts the
/// memory saved from the blocks its end had read (`memory`), whether it is a
/// picture (`images`), the context its prompt took, the coding task whose
/// card it is (`coding`), the model it was asked of, its prompt's parts'
/// tokens, the pages and files it read, its attachments (JSON), whom its
/// model was asked of, how long it took and whether the app's close broke it off.
const VIEW_COLUMNS: &str = "(select group_concat(s.id order by s.id) from messages s
     where s.chat_id = m.chat_id and s.parent_id is m.parent_id and s.deleted_from is null), m.lore,
     (select json_group_array(x.value) from (select j.value from memory_blocks b, json_each(b.saved) j
      where b.message_id = m.id order by b.id, j.key) x),
     exists (select 1 from pictures p where p.message_id = m.id), m.context_used, m.context_size,
     (select t.id from coding_tasks t where t.message_id = m.id), m.model, m.sent, m.reads,
     (select json_group_array(json_object('id', a.id, 'name', a.name, 'picture', json(a.picture)))
      from (select id, name, case when picture is null then 'false' else 'true' end picture
            from attachments where message_id = m.id order by id) a), m.provider, m.times, m.broke_off";

/// The messages from `?1` up to the first one of its chat, with their distance.
pub(super) const ANCESTORS: &str = "with recursive path (id, distance) as (
        select ?1, 0
        union all
        select m.parent_id, path.distance + 1 from messages m join path on m.id = path.id
        where m.parent_id is not null
     )";

/// The newest message not deleted in `message_id`'s subtree, itself included.
fn newest_below(conn: &Connection, message_id: i64) -> rusqlite::Result<i64> {
    conn.query_row(
        "with recursive below (id) as (
            select ?1
            union all
            select m.id from messages m join below on m.parent_id = below.id
            where m.deleted_from is null
         )
         select max(id) from below",
        [message_id],
        |r| r.get(0),
    )
}

/// The version of `message_id` shown in its place when it alone is deleted:
/// the one before it, else the one after it; none where it has no other.
fn other_version(
    conn: &Connection,
    chat_id: i64,
    parent: Option<i64>,
    message_id: i64,
) -> rusqlite::Result<Option<i64>> {
    conn.query_row(
        "select coalesce(
            (select max(id) from messages where chat_id = ?1 and parent_id is ?2
             and deleted_from is null and id < ?3),
            (select min(id) from messages where chat_id = ?1 and parent_id is ?2
             and deleted_from is null and id > ?3))",
        params![chat_id, parent, message_id],
        |r| r.get(0),
    )
}

impl Storage for Db {
    fn newest_below(&self, message_id: i64) -> anyhow::Result<i64> {
        Ok(self.with(|conn| newest_below(conn, message_id))?)
    }

    fn end_unwritten(&self, chat_id: Option<i64>) -> anyhow::Result<Vec<(i64, bool)>> {
        Ok(self.with(|conn| end_unwritten(conn, chat_id))?)
    }

    fn keep_used(
        &self,
        user: i64,
        message_id: i64,
        lore: Option<&str>,
        context: ContextUse,
        sent: &str,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update messages set lore = ?2, context_used = ?4, context_size = ?5, sent = ?6
                 where id = ?1 and chat_id in (select id from chats where user_id = ?3)",
                params![
                    message_id,
                    lore,
                    user,
                    context.used as i64,
                    context.size as i64,
                    sent
                ],
            )
        })?;
        Ok(())
    }

    fn keep_reads(&self, user: i64, message_id: i64, reads: &[Read]) -> anyhow::Result<()> {
        // One connection, taken for the whole call: nothing comes between the read and the write.
        self.with(|tx| {
            let mine = "where id = ?1 and chat_id in (select id from chats where user_id = ?2)";
            let before: Option<Option<String>> = tx
                .query_row(
                    &format!("select reads from messages {mine}"),
                    params![message_id, user],
                    |r| r.get(0),
                )
                .optional()?;
            let Some(before) = before else {
                return Ok(());
            };
            // Those read before the reply was continued, where they can be read, come first.
            let mut all: Vec<Read> = before
                .and_then(|text| {
                    serde_json::from_str(&text)
                        .inspect_err(|error| {
                            tracing::warn!("a reply's pages and files read cannot be read: {error}")
                        })
                        .ok()
                })
                .unwrap_or_default();
            all.extend(
                reads
                    .iter()
                    .filter(|read| !all.contains(read))
                    .cloned()
                    .collect::<Vec<_>>(),
            );
            let all = serde_json::to_string(&all)
                .map_err(|error| rusqlite::Error::ToSqlConversionFailure(Box::new(error)))?;
            tx.execute(
                &format!("update messages set reads = ?3 {mine}"),
                params![message_id, user, all],
            )?;
            Ok(())
        })?;
        Ok(())
    }

    fn append_message(&self, user: i64, chat_id: i64, new: &NewMessage<'_>) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(Option<i64>, bool)> = tx
                .query_row(
                    "select head_id, trashed_at is not null from chats where id = ?1 and user_id = ?2",
                    [chat_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .optional()?;
            let Some((head, trashed)) = found else {
                return Ok(Err(NotFound("chat").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(Fail::said(Code::InTrash, IN_TRASH).with("what", "chat"))));
            }
            if writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            let speaker_id = match (new.role, new.speaker_id) {
                (Role::Assistant, Some(speaker)) => {
                    let in_chat: bool = tx.query_row(
                        "select exists (select 1 from chat_characters where id = ?1 and chat_id = ?2)",
                        [speaker, chat_id],
                        |r| r.get(0),
                    )?;
                    if !in_chat {
                        return Ok(Err(anyhow!(Fail::said(Code::NotPossible, NOT_IN_CHAT).with("what", "speaker_not_in_chat"))));
                    }
                    Some(speaker)
                }
                (Role::Assistant, None) => tx
                    .query_row(
                        "select id from chat_characters where chat_id = ?1 order by id limit 1",
                        [chat_id],
                        |r| r.get(0),
                    )
                    .optional()?,
                (_, Some(_)) => return Ok(Err(anyhow!(Fail::said(Code::NotPossible, "only a character's message has a speaker").with("what", "speaker_only_character")))),
                (_, None) => None,
            };
            let id = insert_message(&tx, chat_id, head, &NewMessage { speaker_id, ..*new }, None)?;
            tx.commit()?;
            Ok(Ok(id))
        })?
    }

    fn add_swipe(
        &self,
        user: i64,
        message_id: i64,
        content: &str,
        complete: bool,
    ) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let original = tx
                .query_row(
                    &format!(
                        "select {MESSAGE_COLUMNS}, m.chat_id, c.trashed_at is not null
                         from messages m join chats c on c.id = m.chat_id
                         where m.id = ?1 and c.user_id = ?2 and m.deleted_from is null"
                    ),
                    [message_id, user],
                    |r| Ok((message(r)?, r.get::<_, i64>(8)?, r.get::<_, bool>(9)?)),
                )
                .optional()?;
            let Some((original, chat_id, trashed)) = original else {
                return Ok(Err(NotFound("message").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(
                    Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
                )));
            }
            if writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            let swipe = NewMessage {
                role: original.role,
                speaker_id: original.speaker_id,
                content,
                complete,
            };
            let id = insert_message(&tx, chat_id, original.parent_id, &swipe, None)?;
            tx.commit()?;
            Ok(Ok(id))
        })?
    }

    fn move_head(&self, user: i64, chat_id: i64, message_id: i64) -> anyhow::Result<bool> {
        let changed = self.with(|conn| {
            conn.execute(
                "update chats set head_id = ?2 where id = ?1 and user_id = ?3 and trashed_at is null
                 and exists (select 1 from messages where id = ?2 and chat_id = ?1 and deleted_from is null)
                 and not exists (select 1 from messages where chat_id = ?1 and complete = 0)",
                params![chat_id, message_id, user],
            )
        })?;
        Ok(changed == 1)
    }

    fn delete_message(&self, user: i64, message_id: i64, versions: bool) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(i64, Option<i64>, Option<i64>, bool)> = tx
                .query_row(
                    "select m.chat_id, m.parent_id, c.head_id, c.trashed_at is not null
                     from messages m join chats c on c.id = m.chat_id
                     where m.id = ?1 and c.user_id = ?2 and m.deleted_from is null",
                    [message_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
                )
                .optional()?;
            let Some((chat_id, parent, head, trashed)) = found else {
                return Ok(Err(NotFound("message").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(
                    Fail::said(Code::InTrash, IN_TRASH).with("what", "chat")
                )));
            }
            if writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            let in_view: bool = tx.query_row(
                &format!("{ANCESTORS} select exists (select 1 from path where id = ?2)"),
                params![head, message_id],
                |r| r.get(0),
            )?;
            if !in_view {
                return Ok(Err(anyhow!(
                    Fail::said(Code::NotPossible, "the message is not in view")
                        .with("what", "message_not_in_view")
                )));
            }
            purge(&tx, chat_id)?;
            let shown = match versions {
                true => None,
                false => other_version(&tx, chat_id, parent, message_id)?,
            };
            // The deletion's top: the message alone where another version is
            // shown in its place, else all its versions.
            let top = match shown {
                Some(_) => "select ?3",
                None => "select id from messages where chat_id = ?1 and parent_id is ?2",
            };
            tx.execute(
                &format!(
                    "with recursive below (id) as (
                        {top}
                        union all
                        select m.id from messages m join below on m.parent_id = below.id
                     )
                     update messages set deleted_from = ?4 where id in (select id from below)"
                ),
                params![chat_id, parent, message_id, head],
            )?;
            let head = match shown {
                Some(version) => Some(newest_below(&tx, version)?),
                None => parent,
            };
            tx.execute(
                "update chats set head_id = ?2 where id = ?1",
                params![chat_id, head],
            )?;
            tx.commit()?;
            Ok(Ok(chat_id))
        })?
    }

    fn restore_messages(&self, user: i64, message_id: i64) -> anyhow::Result<i64> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(i64, i64, bool)> = tx
                .query_row(
                    "select m.chat_id, m.deleted_from, c.trashed_at is not null
                     from messages m join chats c on c.id = m.chat_id
                     where m.id = ?1 and c.user_id = ?2 and m.deleted_from is not null",
                    [message_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )
                .optional()?;
            let Some((chat_id, head, trashed)) = found else {
                return Ok(Err(NotFound("deleted message").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(Fail::said(Code::InTrash, IN_TRASH).with("what", "chat"))));
            }
            if writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            tx.execute(
                "update messages set deleted_from = null where chat_id = ?1 and deleted_from is not null",
                [chat_id],
            )?;
            tx.execute(
                "update chats set head_id = ?2 where id = ?1",
                params![chat_id, head],
            )?;
            tx.commit()?;
            Ok(Ok(chat_id))
        })?
    }

    fn purge_deleted_messages(&self) -> anyhow::Result<()> {
        self.with(|conn| conn.execute("delete from messages where deleted_from is not null", []))?;
        Ok(())
    }

    fn reopen(&self, user: i64, chat_id: i64) -> anyhow::Result<Message> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            let found: Option<(Option<i64>, bool)> = tx
                .query_row(
                    "select head_id, trashed_at is not null from chats where id = ?1 and user_id = ?2",
                    [chat_id, user],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .optional()?;
            let Some((head, trashed)) = found else {
                return Ok(Err(NotFound("chat").into()));
            };
            if trashed {
                return Ok(Err(anyhow!(Fail::said(Code::InTrash, IN_TRASH).with("what", "chat"))));
            }
            if writing(&tx, chat_id)? {
                return Ok(Err(BUSY.into()));
            }
            let newest = tx
                .query_row(
                    &format!("select {MESSAGE_COLUMNS} from messages m where m.id = ?1"),
                    [head],
                    message,
                )
                .optional()?;
            let Some(newest) = newest.filter(|m| m.role == Role::Assistant) else {
                return Ok(Err(anyhow!(Fail::said(Code::NotPossible, "only a character's reply can be continued").with("what", "continue_only_reply"))));
            };
            if newest.content.trim().is_empty() {
                return Ok(Err(anyhow!(Fail::said(Code::NotPossible, "the reply has no text to continue").with("what", "continue_no_text"))));
            }
            tx.execute(
                "update messages set complete = 0, broke_off = 0 where id = ?1",
                [newest.id],
            )?;
            tx.commit()?;
            Ok(Ok(newest))
        })?
    }

    fn rewrite_message(&self, user: i64, message_id: i64, content: &str) -> anyhow::Result<bool> {
        let changed = self.with(|conn| {
            conn.execute(
                "update messages set content = ?2, token_count = null
                 where id = ?1 and complete = 1 and deleted_from is null
                   and chat_id in (select id from chats where user_id = ?3 and trashed_at is null)",
                params![message_id, content, user],
            )
        })?;
        Ok(changed == 1)
    }

    fn message_in_trash(&self, message_id: i64) -> anyhow::Result<bool> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select c.trashed_at is not null from messages m join chats c on c.id = m.chat_id where m.id = ?1",
                [message_id],
                |r| r.get(0),
            )
        })?)
    }

    fn write_reply(&self, user: i64, message_id: i64, more: &str) -> anyhow::Result<()> {
        let changed = self.with(|conn| {
            conn.execute(
                "update messages set content = content || ?2
                 where id = ?1 and complete = 0 and chat_id in (select id from chats where user_id = ?3)",
                params![message_id, more, user],
            )
        })?;
        ensure!(changed == 1, NotFound("message"));
        Ok(())
    }

    fn end_reply(
        &self,
        user: i64,
        message_id: i64,
        content: &str,
        head_before: Option<i64>,
    ) -> anyhow::Result<Option<bool>> {
        let ended = self.with(|conn| {
            let tx = conn.transaction()?;
            let changed = tx.execute(
                "update messages set content = ?2, complete = 1, token_count = null
                 where id = ?1 and complete = 0 and chat_id in (select id from chats where user_id = ?3)",
                params![message_id, content, user],
            )?;
            let removed = changed == 1 && content.trim().is_empty();
            if removed {
                remove_empty(&tx, message_id, head_before)?;
            }
            tx.commit()?;
            Ok((changed, removed))
        })?;
        Ok((ended.0 == 1).then_some(ended.1))
    }

    fn path_to(&self, chat_id: i64, last: Option<i64>) -> anyhow::Result<Vec<Message>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "{ANCESTORS} select {MESSAGE_COLUMNS} from path join messages m on m.id = path.id
                 where m.chat_id = ?2 order by path.distance desc"
            ))?;
            query.query_map(params![last, chat_id], message)?.collect()
        })?)
    }

    fn branch(&self, user: i64, chat_id: i64) -> anyhow::Result<(Chat, Vec<MessageView>)> {
        let found = self.with(|conn| {
            let Some(chat) = chat_of(conn, user, chat_id)? else { return Ok(None) };
            let mut query = conn.prepare(&format!(
                "{ANCESTORS} select {MESSAGE_COLUMNS}, {VIEW_COLUMNS} from path join messages m on m.id = path.id
                 order by path.distance desc"
            ))?;
            let messages = query.query_map([chat.head_id], message_view)?.collect::<rusqlite::Result<_>>()?;
            Ok(Some((chat, messages)))
        })?;
        Ok(found.ok_or(NotFound("chat"))?)
    }

    fn view_message(&self, user: i64, message_id: i64) -> anyhow::Result<MessageView> {
        let found = self.with(|conn| {
            conn.query_row(
                &format!(
                    "select {MESSAGE_COLUMNS}, {VIEW_COLUMNS} from messages m join chats c on c.id = m.chat_id
                     where m.id = ?1 and c.user_id = ?2 and m.deleted_from is null"
                ),
                [message_id, user],
                message_view,
            )
            .optional()
        })?;
        Ok(found.ok_or(NotFound("message"))?)
    }

    fn swipes(&self, user: i64, message_id: i64) -> anyhow::Result<Vec<Message>> {
        Ok(self.with(|conn| {
            let mut query = conn.prepare(&format!(
                "select {MESSAGE_COLUMNS} from messages m
                 join messages o on o.id = ?1
                 join chats c on c.id = o.chat_id
                 where c.user_id = ?2 and m.chat_id = o.chat_id and m.parent_id is o.parent_id
                   and m.deleted_from is null order by m.id"
            ))?;
            query.query_map([message_id, user], message)?.collect()
        })?)
    }

    fn set_model(
        &self,
        user: i64,
        message_id: i64,
        model: &str,
        provider: &str,
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update messages set model = ?3, provider = ?4
                 where id = ?1 and chat_id in (select id from chats where user_id = ?2)",
                params![message_id, user, model, provider],
            )
        })?;
        Ok(())
    }

    fn keep_times(&self, user: i64, message_id: i64, times: &str) -> anyhow::Result<()> {
        self.with(|conn| {
            conn.execute(
                "update messages set times = ?3
                 where id = ?1 and chat_id in (select id from chats where user_id = ?2)",
                params![message_id, user, times],
            )
        })?;
        Ok(())
    }
}

impl cw_chat::chats::export::Storage for Db {
    fn chat_written_out(&self, user: i64, chat_id: i64) -> anyhow::Result<Option<WrittenOut>> {
        Ok(self.with(|conn| {
            let Some(chat) = chat_of(conn, user, chat_id)? else { return Ok(None) };
            let characters = crate::chat_characters::cast_of(conn, chat_id)?;
            let mut query = conn.prepare(&format!(
                "{ANCESTORS} select {MESSAGE_COLUMNS}, m.id = shown.id from path
                 join messages shown on shown.id = path.id
                 join messages m on m.chat_id = shown.chat_id and m.parent_id is shown.parent_id
                 where shown.chat_id = ?2
                   and m.complete and m.deleted_from is null and m.role = shown.role and m.speaker_id is shown.speaker_id
                 order by path.distance desc, m.id"
            ))?;
            let messages = query
                .query_map(params![chat.head_id, chat_id], |r| Ok((message(r)?, r.get(8)?)))?
                .collect::<rusqlite::Result<_>>()?;
            Ok(Some((chat, characters, messages)))
        })?)
    }
}

impl cw_chat::chats::inputs::Storage for Db {
    fn state_above(&self, head: i64) -> anyhow::Result<Option<String>> {
        Ok(self.with(|conn| {
            conn.query_row(
                &format!(
                    "{ANCESTORS} select m.state from path join messages m on m.id = path.id
                     where path.distance > 0 and m.state is not null order by path.distance limit 1"
                ),
                [head],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn message_state(
        &self,
        chat_id: i64,
        message_id: Option<i64>,
    ) -> anyhow::Result<Option<Option<String>>> {
        Ok(self.with(|conn| {
            conn.query_row(
                "select state from messages where id = ?1 and chat_id = ?2",
                params![message_id, chat_id],
                |r| r.get(0),
            )
            .optional()
        })?)
    }

    fn keep_prompt_state(
        &self,
        chat_id: i64,
        newest: Option<i64>,
        state: &str,
        counted: &[(i64, i64)],
    ) -> anyhow::Result<()> {
        self.with(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "update messages set state = ?2 where id = ?1 and chat_id = ?3",
                params![newest, state, chat_id],
            )?;
            let mut update = tx.prepare(
                "update messages set token_count = ?2 where id = ?1 and chat_id = ?3 and token_count is null",
            )?;
            for (id, tokens) in counted {
                update.execute(params![id, tokens, chat_id])?;
            }
            drop(update);
            tx.commit()
        })?;
        Ok(())
    }
}

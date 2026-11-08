//! The schema steps run on rows from before them.

use super::*;
use crate::register_vec;
use rusqlite::params;

/// Before schema step 6 a card went to the Trash without its chats. The
/// step sends them after it, so that deleting the card for good takes no
/// chat the user still sees among the others.
#[test]
fn the_chats_of_cards_already_in_the_trash_follow_them() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    for step in &MIGRATIONS[..5] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", 5).unwrap();
    conn.execute_batch(
        "insert into users (id, name, created_at) values (1, 'erin', 0);
         insert into blobs (id, hash, data) values (1, x'00', x'00');
         insert into cards (id, user_id, title, trashed_at, created_at, updated_at) values
            (1, 1, 'Gone', 500, 0, 0), (2, 1, 'Here', null, 0, 0), (3, 1, 'Gone later', 700, 0, 0);
         insert into card_versions (id, card_id, number, image_id, created_at) values
            (1, 1, 1, 1, 0), (2, 2, 1, 1, 0), (3, 3, 1, 1, 0);
         insert into chats (id, user_id, title, trashed_at, created_at, updated_at) values
            (1, 1, 'with the one gone', null, 0, 0), (2, 1, 'with the one here', null, 0, 0),
            (3, 1, 'deleted by itself', 900, 0, 0), (4, 1, 'with both gone', null, 0, 0),
            (5, 1, 'with one gone and one here', null, 0, 0);
         insert into chat_characters (chat_id, position, version_id, character) values
            (1, 0, 1, 'a'), (2, 0, 2, 'a'), (3, 0, 1, 'a'), (4, 0, 3, 'a'), (4, 1, 1, 'a'),
            (5, 0, 2, 'a'), (5, 1, 3, 'a');",
    )
    .unwrap();

    migrate(&mut conn).unwrap();
    let chats: Vec<(i64, Option<i64>, Option<i64>)> = conn
        .prepare("select id, trashed_at, trashed_with from chats order by id")
        .unwrap()
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    // In the Trash since its card is, and back with it; one deleted by itself stays so.
    let expected = [
        (1, Some(500), Some(1)),
        (2, None, None),
        (3, Some(900), None),
        (4, Some(500), Some(1)),
        (5, Some(700), Some(3)),
    ];
    assert_eq!(chats, expected);
}

/// Schema step 10 makes `chat_lorebook_off` anew. What chats had left out
/// stays, and from then on a chat leaves things out of a lorebook it did
/// not take along itself: one it has through its card.
#[test]
fn what_chats_left_out_of_their_lorebooks_stays_when_the_table_is_made_anew() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", true).unwrap();
    for step in &MIGRATIONS[..9] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", 9).unwrap();
    conn.execute_batch(
        "insert into users (id, name, created_at) values (1, 'erin', 0);
         insert into chats (id, user_id, title, created_at, updated_at) values (1, 1, 'chat', 0, 0);
         insert into lorebooks (id, user_id, name, toml, entries, entry_names, created_at) values
            (1, 1, 'Taken', '', 1, '[]', 0), (2, 1, 'Not taken', '', 1, '[]', 0);
         insert into chat_lorebooks (chat_id, lorebook_id, added_at) values (1, 1, 0);
         insert into chat_lorebook_off (chat_id, lorebook_id, reference) values (1, 1, 'lore.pier');",
    )
    .unwrap();
    let left_out = |conn: &Connection| -> Vec<(i64, String)> {
        conn.prepare("select lorebook_id, reference from chat_lorebook_off order by lorebook_id")
            .unwrap()
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))
            .unwrap()
            .collect::<rusqlite::Result<_>>()
            .unwrap()
    };
    let other = "insert into chat_lorebook_off (chat_id, lorebook_id, reference) values (1, 2, 'lore.bell')";
    assert!(conn.execute(other, []).is_err());

    migrate(&mut conn).unwrap();
    assert_eq!(left_out(&conn), [(1, "lore.pier".to_string())]);
    conn.execute(other, []).unwrap();
    // The rows go with their lorebook and with their chat.
    conn.execute("delete from lorebooks where id = 2", [])
        .unwrap();
    assert_eq!(left_out(&conn), [(1, "lore.pier".to_string())]);
    conn.execute("delete from chats where id = 1", []).unwrap();
    assert_eq!(left_out(&conn), []);
}

/// Schema step 13 gives a chat its turn order. A chat from before it has
/// the natural one and nobody picked by hand, no other order is one, and
/// the one picked is forgotten with its character.
#[test]
fn a_chat_from_before_the_turn_order_has_the_natural_one() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", true).unwrap();
    for step in &MIGRATIONS[..12] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", 12).unwrap();
    assert!(conn.prepare("select turn_order from chats").is_err());
    conn.execute_batch(
        "insert into users (id, name, created_at) values (1, 'erin', 0);
         insert into blobs (id, hash, data) values (1, x'00', x'00');
         insert into cards (id, user_id, title, created_at, updated_at) values (1, 1, 'Card', 0, 0);
         insert into card_versions (id, card_id, number, image_id, created_at) values (1, 1, 1, 1, 0);
         insert into chats (id, user_id, title, created_at, updated_at) values (1, 1, 'chat', 0, 0);
         insert into chat_characters (id, chat_id, position, version_id, character) values
            (7, 1, 0, 1, 'a'), (8, 1, 1, 1, 'b');",
    )
    .unwrap();

    migrate(&mut conn).unwrap();
    let turn = |conn: &Connection| -> (String, Option<i64>) {
        conn.query_row("select turn_order, replier_id from chats", [], |r| {
            Ok((r.get(0)?, r.get(1)?))
        })
        .unwrap()
    };
    assert_eq!(turn(&conn), ("natural".to_string(), None));
    let set = "update chats set turn_order = ?1, replier_id = ?2";
    assert!(conn.execute(set, params!["sideways", 8]).is_err());
    assert!(conn.execute(set, params!["list", 9]).is_err());
    conn.execute(set, params!["list", 8]).unwrap();
    conn.execute("delete from chat_characters where id = 8", [])
        .unwrap();
    assert_eq!(turn(&conn), ("list".to_string(), None));
    // Who is picked in which chat is found by index when a character goes.
    let plan: String = conn
        .query_row(
            "explain query plan select 1 from chats where replier_id = 8",
            [],
            |r| r.get(3),
        )
        .unwrap();
    assert!(plan.contains("chats_by_replier"), "{plan}");
}

/// Schema step 14 has a chat's character muted or not. One from before
/// it is not muted, a new one neither, and nothing else is said of it.
#[test]
fn a_chat_character_from_before_muting_is_not_muted() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", true).unwrap();
    for step in &MIGRATIONS[..13] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", 13).unwrap();
    assert!(conn.prepare("select muted from chat_characters").is_err());
    conn.execute_batch(
        "insert into users (id, name, created_at) values (1, 'erin', 0);
         insert into blobs (id, hash, data) values (1, x'00', x'00');
         insert into cards (id, user_id, title, created_at, updated_at) values (1, 1, 'Card', 0, 0);
         insert into card_versions (id, card_id, number, image_id, created_at) values (1, 1, 1, 1, 0);
         insert into chats (id, user_id, title, created_at, updated_at) values (1, 1, 'chat', 0, 0);
         insert into chat_characters (id, chat_id, position, version_id, character) values (7, 1, 0, 1, 'a');",
    )
    .unwrap();

    migrate(&mut conn).unwrap();
    conn.execute(
        "insert into chat_characters (id, chat_id, position, version_id, character) values (8, 1, 1, 1, 'b')",
        [],
    )
    .unwrap();
    let muted = |conn: &Connection| -> Vec<bool> {
        conn.prepare("select muted from chat_characters order by id")
            .unwrap()
            .query_map([], |r| r.get(0))
            .unwrap()
            .collect::<rusqlite::Result<_>>()
            .unwrap()
    };
    assert_eq!(muted(&conn), [false, false]);
    let set = "update chat_characters set muted = ?1 where id = 8";
    assert!(conn.execute(set, [2]).is_err());
    assert!(conn.execute(set, [Option::<i64>::None]).is_err());
    conn.execute(set, [1]).unwrap();
    assert_eq!(muted(&conn), [false, true]);
}

/// Schema step 15 marks this computer's account, which was known by its
/// name, `local`: a database from before it has that user marked and no
/// other, and at most one user is marked. Step 16 gives a provider a name
/// of the user's, and one from before it has none.
#[test]
fn the_user_called_local_is_marked_as_this_computers_account() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", true).unwrap();
    for step in &MIGRATIONS[..14] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", 14).unwrap();
    conn.execute_batch(
        "insert into users (id, name, created_at) values (1, 'sam', 0), (2, 'local', 0);
         insert into providers (user_id, base_url, api_key, model, sampling, updated_at)
            values (2, 'https://api.example.com/v1', '', 'tide-1', '{}', 0);",
    )
    .unwrap();
    migrate(&mut conn).unwrap();
    let marked = |conn: &Connection| -> Vec<(String, bool)> {
        conn.prepare("select name, local from users order by id")
            .unwrap()
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))
            .unwrap()
            .collect::<rusqlite::Result<_>>()
            .unwrap()
    };
    let users = [("sam".to_string(), false), ("local".to_string(), true)];
    assert_eq!(marked(&conn), users);
    // A second one cannot be marked, and the mark is yes or no.
    let mark = "update users set local = ?1 where id = 1";
    assert!(conn.execute(mark, [1]).is_err());
    assert!(conn.execute(mark, [2]).is_err());
    assert_eq!(marked(&conn), users);
    // Renamed, the marked one is still the one.
    conn.execute("update users set name = 'Rowan' where id = 2", [])
        .unwrap();
    assert_eq!(marked(&conn)[1], ("Rowan".to_string(), true));

    let name: String = conn
        .query_row(
            "select name from provider_entries where user_id = 2",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(name, "");
}

/// The last step gives a chat its reply length and Code mode: a chat from
/// before has the response length and the Code mode its account had, or
/// 350 tokens where the account set no length.
#[test]
fn a_chat_keeps_the_code_mode_and_length_its_account_had() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    // The step that gave chats their code mode, and the steps after it, run on the rows below.
    let before = MIGRATIONS
        .iter()
        .position(|step| step.contains("add column code_mode"))
        .unwrap();
    for step in &MIGRATIONS[..before] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", before as u32)
        .unwrap();
    conn.execute_batch(
        r#"insert into users (id, name, created_at, settings) values
            (1, 'erin', 0, '{"tools": {"code": true}}'), (2, 'odo', 0, '{"tools": {"code": false}}'), (3, 'mira', 0, '{}');
         insert into providers (user_id, base_url, api_key, model, sampling, updated_at) values
            (1, 'http://a', '', 'm', '{"max_response_length": 900}', 0), (2, 'http://b', '', 'm', '{"max_response_length": null}', 0);
         insert into chats (id, user_id, title, created_at, updated_at) values (1, 1, 'a', 0, 0), (2, 2, 'b', 0, 0), (3, 3, 'c', 0, 0);"#,
    )
    .unwrap();
    migrate(&mut conn).unwrap();
    let chats: Vec<(i64, bool)> = conn
        .prepare("select reply_length, code_mode from chats order by id")
        .unwrap()
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    assert_eq!(chats, [(900, true), (350, false), (350, false)]);
}

/// Which chats have which lorebook is asked of `cw_store::lorebooks::HAD`, by the
/// Trash's list for every chat and lorebook there is. It is searched by
/// index for the two asked for, and never read as a whole each time.

#[test]
fn the_lorebooks_chats_have_are_searched_by_index() {
    register_vec();
    let conn = Connection::open_in_memory().unwrap();
    for step in MIGRATIONS {
        conn.execute_batch(step).unwrap();
    }
    let asked = format!(
        "explain query plan select 1 from chats x, lorebooks y
         where exists (select 1 from {} h where h.chat_id = x.id and h.lorebook_id = y.id)",
        crate::lorebooks::HAD
    );
    let plan: Vec<String> = conn
        .prepare(&asked)
        .unwrap()
        .query_map([], |r| r.get(3))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    let whole = |step: &&String| {
        step.starts_with("SCAN") && !step.starts_with("SCAN x") && !step.starts_with("SCAN y")
    };
    assert_eq!(plan.iter().filter(whole).count(), 0, "{plan:#?}");
    for half in [
        "SEARCH a ",
        "SEARCH chat_lorebooks ",
        "SEARCH l ",
        "SEARCH g ",
    ] {
        assert!(
            plan.iter().any(|step| step.starts_with(half)),
            "{half}: {plan:#?}"
        );
    }
}

/// The last step makes the account's providers a list: the stored provider,
/// the image model's own address and each preset's provider become its
/// entries, once each; the chat, background and image models kinds at them;
/// the stored values for a reply the account's. What a preset kept for an
/// Undo goes.
#[test]
fn the_stored_provider_the_image_model_and_the_presets_become_the_list() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", true).unwrap();
    let before = MIGRATIONS
        .iter()
        .position(|step| step.contains("create table provider_entries"))
        .unwrap();
    for step in &MIGRATIONS[..before] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", before as u32)
        .unwrap();
    conn.execute_batch(
        r#"insert into users (id, name, created_at) values (1, 'erin', 0), (2, 'odo', 0), (3, 'mira', 0);
         insert into providers (user_id, name, base_url, api_key, model, sampling, worker_model, updated_at) values
            (1, 'Rig', 'http://rig', 'k1', 'tide-1', '{"temperature": 0.7}', 'small-1', 5),
            (2, '', 'http://odo', '', 'tide-2', '{}', '', 6);
         insert into image_models (user_id, base_url, api_key, model, updated_at) values
            (1, 'http://pics', 'k2', 'paint-1', 7), (2, null, '', 'paint-2', 8), (3, null, '', 'paint-3', 9);
         insert into presets (user_id, name, base_url, api_key, model, sampling, provider_name, replaced, created_at) values
            (1, 'Same', 'http://rig', 'k1', 'tide-9', '{}', 'Rig', 0, 1),
            (1, 'Pics', 'http://pics', 'k2', 'tide-8', '{}', '', 0, 2),
            (1, 'New', 'http://new', 'k3', 'tide-7', '{}', 'New one', 0, 3),
            (1, 'New two', 'http://new', 'k3', 'tide-6', '{}', 'New one', 0, 4),
            (1, '', 'http://old', '', 'tide-5', '{}', '', 1, 5);"#,
    )
    .unwrap();
    migrate(&mut conn).unwrap();

    let entries: Vec<(i64, i64, String, String, String)> = conn
        .prepare("select id, user_id, name, base_url, api_key from provider_entries order by id")
        .unwrap()
        .query_map([], |r| {
            Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?))
        })
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    let entry = |id: i64, user: i64, name: &str, url: &str, key: &str| {
        (id, user, name.to_string(), url.to_string(), key.to_string())
    };
    assert_eq!(
        entries,
        [
            entry(1, 1, "Rig", "http://rig", "k1"),
            entry(2, 2, "", "http://odo", ""),
            entry(3, 1, "", "http://pics", "k2"),
            entry(4, 1, "New one", "http://new", "k3"),
        ]
    );
    let kinds: Vec<(i64, String, i64, String)> = conn
        .prepare("select user_id, kind, entry_id, model from model_kinds order by user_id, kind")
        .unwrap()
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    let kind = |user: i64, kind: &str, entry: i64, model: &str| {
        (user, kind.to_string(), entry, model.to_string())
    };
    // Mira's image model was at a chat provider she has none of: it goes.
    assert_eq!(
        kinds,
        [
            kind(1, "background", 1, "small-1"),
            kind(1, "chat", 1, "tide-1"),
            kind(1, "images", 3, "paint-1"),
            kind(2, "chat", 2, "tide-2"),
            kind(2, "images", 2, "paint-2"),
        ]
    );
    let sampling: Vec<String> = conn
        .prepare("select sampling from users order by id")
        .unwrap()
        .query_map([], |r| r.get(0))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    assert_eq!(sampling, [r#"{"temperature": 0.7}"#, "{}", "{}"]);
    let presets: i64 = conn
        .query_row("select count(*) from presets", [], |r| r.get(0))
        .unwrap();
    assert_eq!(presets, 4);
}

/// By need orders by each need's rank, which answers from before it lack: they are dropped and asked anew. A
/// refusal holds no needs, and one by the describer would not be queued again, so it stays.
#[test]
fn the_needs_answered_before_ranks_are_dropped_and_refusals_stay() {
    register_vec();
    let mut conn = Connection::open_in_memory().unwrap();
    let after = 1 + MIGRATIONS
        .iter()
        .position(|step| step.contains("create table card_needs"))
        .unwrap();
    for step in &MIGRATIONS[..after] {
        conn.execute_batch(step).unwrap();
    }
    conn.pragma_update(None, "user_version", after as u32)
        .unwrap();
    conn.execute_batch(
        "insert into users (id, name, created_at, settings) values (1, 'erin', 0, '{}');
         insert into cards (id, user_id, title, created_at, updated_at) values
            (1, 1, 'a', 0, 0), (2, 1, 'b', 0, 0), (3, 1, 'c', 0, 0), (4, 1, 'd', 0, 0);
         insert into card_needs (card_id, state, levels, updated_at) values
            (1, 'asked', '[]', 0), (2, 'failed', '[]', 0), (3, 'queued', '[]', 0), (4, 'refused', '[]', 0);",
    )
    .unwrap();
    migrate(&mut conn).unwrap();
    let left: Vec<String> = conn
        .prepare("select state from card_needs order by card_id")
        .unwrap()
        .query_map([], |r| r.get(0))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    assert_eq!(left, ["refused"]);
}

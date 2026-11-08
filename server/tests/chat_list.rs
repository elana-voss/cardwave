//! What the list of chats shows: a chat's line, the search, All / Favorites /
//! Archived, the three orders, and what a chat's characters are called there.
//!
//! `card` is the sample card under another title, label (what a chat with it is
//! called) and name, and `plant` runs a change on a running server's database,
//! as the chats' times.

mod common;

use common::Scratch;
use common::server::{Server, start};
use cw_accounts::users;
use cw_ccv4::png::{self, Container};
use cw_chat::chats::{self, ChatSort, Find, NewChat};
use cw_key::FILE_NAME;
use cw_library::cards::Show;
use cw_store::Db;
use serde_json::{Value, json};

/// The sample card under another title, with its first character under
/// another label, which is what a chat with it is called, and another name.
fn card(title: &str, label: &str, name: &str) -> Vec<u8> {
    let mut container: Container = common::container();
    container.toml[0].1 = container.toml[0]
        .1
        .replace(
            "title = \"Mira of the North Light\"",
            &format!("title = {}", json!(title)),
        )
        .replace(
            "[name.mira]\ntext = \"Mira\"",
            &format!("[name.mira]\ntext = {}", json!(name)),
        );
    container.toml[1].1 = container.toml[1].1.replace(
        "name-card = \"Mira (storm night)\"",
        &format!("name-card = {}", json!(label)),
    );
    let written = format!("{}{}", container.toml[0].1, container.toml[1].1);
    for part in [title, label, name] {
        assert!(written.contains(&json!(part).to_string()), "{part}");
    }
    png::write(&container).unwrap()
}

/// Uploads a card and returns its id and the id of its version.
async fn add(server: &Server, file: Vec<u8>) -> (i64, i64) {
    server.add_card(file, true).await
}

/// Starts a chat with characters, each as (card version, ID in the card), and returns its view.
async fn chat_with(server: &Server, characters: &[(i64, &str)]) -> Value {
    server.chat_with(characters, 0).await
}

/// A card of its own with a chat called `label`; returns the chat's id.
async fn chat_called(server: &Server, title: &str, label: &str) -> i64 {
    let (_, version) = add(server, card(title, label, label)).await;
    chat_with(server, &[(version, "mira")]).await["chat"]["id"]
        .as_i64()
        .unwrap()
}

/// The list of chats for a query string.
async fn list(server: &Server, query: &str) -> Vec<Value> {
    let (status, list) = server.get(&format!("/api/chats{query}")).await;
    assert_eq!(status, 200, "{list}");
    list.as_array().unwrap().clone()
}

/// The ids of the chats listed for a query string, in order.
async fn ids(server: &Server, query: &str) -> Vec<i64> {
    list(server, query)
        .await
        .iter()
        .map(|chat| chat["id"].as_i64().unwrap())
        .collect()
}

/// The titles of the chats listed for a query string, in order.
async fn titles(server: &Server, query: &str) -> Vec<String> {
    list(server, query)
        .await
        .iter()
        .map(|chat| chat["title"].as_str().unwrap().to_string())
        .collect()
}

/// Runs `change` on the database of a running server, through a connection of its own.
fn plant(server: &Server, change: impl FnOnce(&rusqlite::Connection) -> rusqlite::Result<usize>) {
    let options = server.options();
    let db = Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    db.with(|conn| change(conn)).unwrap();
}

#[tokio::test]
async fn a_line_carries_the_characters_their_cards_and_the_newest_message() {
    let server = start().await;
    let (coast, mira) = add(&server, common::card_file()).await;
    let (ledger, odo) = add(&server, card("Odo's Ledger", "Odo", "Odo")).await;
    let view = chat_with(&server, &[(mira, "mira"), (mira, "bare"), (odo, "mira")]).await;
    let chat = view["chat"]["id"].as_i64().unwrap();

    let listed = list(&server, "").await;
    assert_eq!(listed.len(), 1);
    let line = &listed[0];
    assert_eq!(
        (&line["id"], &line["title"]),
        (&json!(chat), &json!("Mira (storm night)"))
    );
    assert_eq!(
        (&line["favorite"], &line["archived"], &line["trashed"]),
        (&json!(false), &json!(false), &json!(false))
    );
    assert_eq!(
        (&line["created_at"], &line["updated_at"]),
        (&view["chat"]["created_at"], &view["chat"]["updated_at"])
    );
    // In speaking order, as each is called in the chat.
    assert_eq!(line["names"], json!(["Mira", "bare", "Odo"]));
    // Each card once, with the version the chat is with.
    let cards = json!([
        { "id": coast, "title": "Mira of the North Light", "version_id": mira },
        { "id": ledger, "title": "Odo's Ledger", "version_id": odo },
    ]);
    assert_eq!(line["cards"], cards);
    assert_eq!(line["excerpt"], "All of you, inside.");

    // The newest message on one line, without its markup.
    let said = json!({ "content": "*She waves*, then `nods`.\n\nAnd more." });
    let (status, message) = server
        .post(&format!("/api/chats/{chat}/messages"), said)
        .await;
    assert_eq!(status, 201, "{message}");
    assert_eq!(
        list(&server, "").await[0]["excerpt"],
        "She waves, then nods. And more."
    );
    // A long one is cut.
    let long = json!({ "content": "word ".repeat(400), "role": "assistant" });
    server
        .post(&format!("/api/chats/{chat}/messages"), long)
        .await;
    let excerpt = list(&server, "").await[0]["excerpt"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(
        excerpt.ends_with("word…") && excerpt.chars().count() <= 301,
        "{excerpt}"
    );
    // It is the newest of the branch in view: what the chat shows last when it is opened.
    let head = json!({ "message_id": message["id"] });
    assert_eq!(
        server.put(&format!("/api/chats/{chat}/head"), head).await.0,
        200
    );
    assert_eq!(
        list(&server, "").await[0]["excerpt"],
        "She waves, then nods. And more."
    );
}

#[tokio::test]
async fn the_list_leaves_out_the_trash_and_shows_archived_chats_only_when_asked_or_searched() {
    let server = start().await;
    let mut chats = Vec::new();
    for (label, flags) in [
        ("Plain", json!({})),
        ("Starred", json!({ "favorite": true })),
        ("Shelved", json!({ "archived": true })),
        (
            "Shelved star",
            json!({ "archived": true, "favorite": true }),
        ),
        ("Binned", json!({ "trashed": true, "favorite": true })),
    ] {
        let chat = chat_called(&server, &format!("{label} of the Quay"), label).await;
        assert_eq!(
            server.patch(&format!("/api/chats/{chat}"), flags).await.0,
            200
        );
        chats.push(chat);
    }
    // The archived ones were written in last: only a search puts them behind the others.
    plant(&server, |conn| {
        conn.execute("update chats set updated_at = id * 1000", [])
    });

    assert_eq!(titles(&server, "").await, ["Starred", "Plain"]);
    assert_eq!(titles(&server, "?show=all").await, ["Starred", "Plain"]);
    assert_eq!(titles(&server, "?show=favorites").await, ["Starred"]);
    assert_eq!(
        titles(&server, "?show=archived").await,
        ["Shelved star", "Shelved"]
    );
    // A search finds the archived ones too, and lists them after the others.
    assert_eq!(
        titles(&server, "?q=quay").await,
        ["Starred", "Plain", "Shelved star", "Shelved"]
    );
    assert_eq!(
        titles(&server, "?q=quay&sort=name").await,
        ["Plain", "Starred", "Shelved", "Shelved star"]
    );
    assert_eq!(
        titles(&server, "?q=quay&sort=started").await,
        ["Starred", "Plain", "Shelved star", "Shelved"]
    );
    assert_eq!(
        titles(&server, "?q=quay&show=favorites").await,
        ["Starred", "Shelved star"]
    );
    assert_eq!(
        titles(&server, "?q=quay&show=archived").await,
        ["Shelved star", "Shelved"]
    );
    // Blanks alone are no search.
    assert_eq!(titles(&server, "?q=%20%20").await, ["Starred", "Plain"]);
    // What is in the Trash is never listed, and comes back with its star.
    assert!(titles(&server, "?q=binned").await.is_empty());
    server
        .patch(
            &format!("/api/chats/{}", chats[4]),
            json!({ "trashed": false }),
        )
        .await;
    assert_eq!(
        titles(&server, "?show=favorites").await,
        ["Binned", "Starred"]
    );

    for unknown in ["?show=starred", "?sort=size"] {
        assert_eq!(
            server.get(&format!("/api/chats{unknown}")).await.0,
            400,
            "{unknown}"
        );
    }
}

#[tokio::test]
async fn a_search_finds_chats_by_title_character_and_card_and_reads_no_message() {
    let server = start().await;
    let (_, lantern) = add(&server, card("Lantern Row", "Émile the Keeper", "Émile")).await;
    let (_, harbour) = add(&server, card("Harbour 100%", "Odo", "Odo_x")).await;
    let keeper = chat_with(&server, &[(lantern, "mira"), (lantern, "bare")]).await["chat"]["id"]
        .as_i64()
        .unwrap();
    let odo = chat_with(&server, &[(harbour, "mira")]).await["chat"]["id"]
        .as_i64()
        .unwrap();

    for (query, found) in [
        // The chat's title, a character's name and the card's title, in any case, outside ASCII too.
        ("keeper", vec![keeper]),
        ("%C3%89MILE", vec![keeper]),
        ("bare", vec![keeper]),
        ("LANTERN", vec![keeper]),
        ("odo_x", vec![odo]),
        ("harbour", vec![odo]),
        // Every word, wherever each is.
        ("row+keeper+bare", vec![keeper]),
        ("lantern+odo", vec![]),
        // Parts of words, and both chats.
        ("r", vec![odo, keeper]),
        // `%` and `_` are plain characters.
        ("100%25", vec![odo]),
        ("%25", vec![odo]),
        ("_", vec![odo]),
        // Not the messages' words, the card's tags or a character's ID in its card.
        ("night", vec![]),
        ("sea", vec![]),
        ("mira", vec![]),
    ] {
        assert_eq!(ids(&server, &format!("?q={query}")).await, found, "{query}");
    }
}

#[tokio::test]
async fn the_list_is_ordered_by_the_last_message_the_name_or_the_start() {
    let server = start().await;
    let (_, version) = add(&server, card("Azure Deep", "azure", "Azure")).await;
    let azure = chat_with(&server, &[(version, "mira")]).await["chat"]["id"]
        .as_i64()
        .unwrap();
    let alpha = chat_called(&server, "Alpha Light", "Álpha").await;
    let gamma = chat_called(&server, "Gamma Reach", "Gamma").await;
    let again = chat_with(&server, &[(version, "mira")]).await["chat"]["id"]
        .as_i64()
        .unwrap();
    for (chat, started, written) in [
        (azure, 100, 900),
        (alpha, 200, 800),
        (gamma, 300, 500),
        (again, 400, 400),
    ] {
        plant(&server, |conn| {
            conn.execute(
                "update chats set created_at = ?2, updated_at = ?3 where id = ?1",
                [chat, started, written],
            )
        });
    }

    // The chat written in last comes first, unless another order is asked for.
    assert_eq!(ids(&server, "").await, [azure, alpha, gamma, again]);
    assert_eq!(
        ids(&server, "?sort=last_written").await,
        [azure, alpha, gamma, again]
    );
    // By name as a reader orders them: a capital and a mark on a letter change
    // nothing. Of two called the same, the one written in last comes first.
    assert_eq!(
        ids(&server, "?sort=name").await,
        [alpha, azure, again, gamma]
    );
    assert_eq!(
        ids(&server, "?sort=started").await,
        [again, gamma, alpha, azure]
    );

    let (status, _) = server
        .post(
            &format!("/api/chats/{gamma}/messages"),
            json!({ "content": "Still there?" }),
        )
        .await;
    assert_eq!(status, 201);
    assert_eq!(ids(&server, "").await, [gamma, azure, alpha, again]);
    assert_eq!(
        ids(&server, "?sort=started").await,
        [again, gamma, alpha, azure]
    );

    // Of chats written in or started at the same moment, the one made last comes first.
    plant(&server, |conn| {
        conn.execute("update chats set created_at = 700, updated_at = 700", [])
    });
    assert_eq!(ids(&server, "").await, [again, gamma, alpha, azure]);
    assert_eq!(
        ids(&server, "?sort=started").await,
        [again, gamma, alpha, azure]
    );
    assert_eq!(
        ids(&server, "?sort=name").await,
        [alpha, again, azure, gamma]
    );
}

#[tokio::test]
async fn a_chat_goes_by_what_its_card_calls_its_characters() {
    let server = start().await;
    let (card_id, first) = add(&server, common::card_file()).await;
    let view = chat_with(&server, &[(first, "mira"), (first, "bare")]).await;
    let chat = view["chat"]["id"].as_i64().unwrap();
    let line = |listed: Vec<Value>| {
        (
            listed[0]["names"].clone(),
            listed[0]["cards"][0]["version_id"].clone(),
        )
    };
    assert_eq!(
        line(list(&server, "").await),
        (json!(["Mira", "bare"]), json!(first))
    );
    assert!(ids(&server, "?q=mirabel").await.is_empty());

    // An edit of the card moves the chat to it: it is listed and found by the names it has there.
    let (status, second) = server
        .edit_card(&json!(card_id), |form| {
            form["characters"][0]["name"] = json!("Mirabel")
        })
        .await;
    assert_eq!(status, 200, "{second}");
    assert_eq!(
        line(list(&server, "").await),
        (json!(["Mirabel", "bare"]), second["id"].clone())
    );
    assert_eq!(ids(&server, "?q=mirabel").await, [chat]);
}

#[tokio::test]
async fn the_server_names_the_characters_of_older_chats_when_it_starts() {
    let server = start().await;
    let (_, version) = add(&server, common::card_file()).await;
    chat_with(&server, &[(version, "mira"), (version, "bare")]).await;
    // As a build before the names were kept left it.
    plant(&server, |conn| {
        conn.execute("update chat_characters set name = null", [])
    });
    assert_eq!(list(&server, "").await[0]["names"], json!(["mira", "bare"]));

    let server = server.restart().await;
    assert_eq!(list(&server, "").await[0]["names"], json!(["Mira", "bare"]));
    assert_eq!(ids(&server, "?q=mira").await.len(), 1);
}

#[test]
fn a_chat_of_a_card_that_cannot_be_read_is_listed_and_its_characters_go_by_their_ids() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let broken = common::import_whole(db, me, &card("Broken Compass", "Bram", "Bram")).unwrap();
    let sound = common::import_whole(db, me, &common::card_file()).unwrap();
    let characters = [(broken.version_id, "mira"), (sound.version_id, "mira")];
    let chat = chats::create(
        db,
        me,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    db.with(|conn| {
        conn.execute(
            "update card_files set toml = 'not [toml' where version_id = ?1 and toml is not null",
            [broken.version_id],
        )?;
        conn.execute("update chat_characters set name = null", [])
    })
    .unwrap();

    // One card that cannot be read keeps neither the server from starting nor the others from their names.
    chats::name_missing(db).unwrap();
    let listed = chats::find(db, me, &Find::default()).unwrap();
    assert_eq!(
        (listed[0].chat.id, &listed[0].names),
        (chat, &vec!["mira".to_string(), "Mira".to_string()])
    );
    assert_eq!(listed[0].cards[0].title, "Broken Compass");
    // The name is written, so the next start does not try the card again.
    let unnamed: i64 = db
        .with(|conn| {
            conn.query_row(
                "select count(*) from chat_characters where name is null",
                [],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(unnamed, 0);
}

#[test]
fn a_card_cannot_flood_the_list_with_a_name() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let endless =
        common::import_whole(db, me, &card("Flood", "Flood", &"n".repeat(10_000))).unwrap();
    let characters = [(endless.version_id, "mira")];
    chats::create(
        db,
        me,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    let listed = || {
        chats::find(db, me, &Find::default())
            .unwrap()
            .remove(0)
            .names
    };
    assert_eq!(listed(), ["n".repeat(64)]);
    // The same when the server's start reads it.
    db.with(|conn| conn.execute("update chat_characters set name = null", []))
        .unwrap();
    chats::name_missing(db).unwrap();
    assert_eq!(listed(), ["n".repeat(64)]);
}

#[test]
fn another_user_is_listed_none_of_the_chats() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let sam = users::create(db, "sam").unwrap();
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let chat = chats::create(db, me, &new).unwrap();
    chats::set_archived(db, me, chat, true).unwrap();

    for find in [
        Find::default(),
        Find {
            show: Show::Archived,
            ..Find::default()
        },
        Find {
            query: "mira",
            sort: ChatSort::Name,
            ..Find::default()
        },
    ] {
        assert!(chats::find(db, sam, &find).unwrap().is_empty());
    }
    assert_eq!(
        chats::find(
            db,
            me,
            &Find {
                show: Show::Archived,
                ..Find::default()
            }
        )
        .unwrap()
        .len(),
        1
    );
}

//! What the library shows of the cards: the list's rows, search, the order, a
//! card's texts and its chats.

mod common;

use common::Scratch;
use common::server::{Server, event, start};
use cw_ccv4::display;
use cw_ccv4::png::{self, Container};
use cw_key::FILE_NAME;
use cw_library::cards::{self, Find, Show, Sort};
use cw_store::Db;
use serde_json::{Value, json};

/// The sample card under another title, with another name for its first
/// character and other tags.
fn card(title: &str, name: &str, tags: &[&str]) -> Vec<u8> {
    let mut container: Container = common::container();
    let blocks = &mut container.toml[0].1;
    *blocks = blocks
        .replace(
            "title = \"Mira of the North Light\"",
            &format!("title = {}", json!(title)),
        )
        .replace(
            "tags = [\"sea\", \"mystery\"]",
            &format!("tags = {}", json!(tags)),
        )
        .replace(
            "[name.mira]\ntext = \"Mira\"",
            &format!("[name.mira]\ntext = {}", json!(name)),
        );
    assert!(
        blocks.contains(&json!(title).to_string()) && blocks.contains(&json!(name).to_string())
    );
    png::write(&container).unwrap()
}

/// Uploads a card and returns its id and the id of its version.
async fn add(server: &Server, file: Vec<u8>) -> (i64, i64) {
    server.add_card(file, false).await
}

async fn chat_with(server: &Server, version: i64) -> Value {
    server.chat_with(&[(version, "mira")], 0).await
}

/// The titles the library lists for a query string, in order.
async fn titles(server: &Server, query: &str) -> Vec<String> {
    let (status, list) = server.get(&format!("/api/cards{query}")).await;
    assert_eq!(status, 200, "{list}");
    list.as_array()
        .unwrap()
        .iter()
        .map(|card| card["title"].as_str().unwrap().to_string())
        .collect()
}

#[tokio::test]
async fn a_list_row_carries_names_tags_the_first_greeting_and_the_last_chat() {
    let server = start().await;
    let (_, version) = add(&server, common::card_file()).await;
    let (_, list) = server.get("/api/cards").await;
    let row = &list[0];
    assert_eq!(row["names"], json!(["Mira"]));
    assert_eq!(row["tags"], json!(["sea", "mystery"]));
    // The greeting as a chat without a persona would open, on one line.
    assert_eq!(row["excerpt"], "\"You picked a night for it, Guest.\"");
    assert!(row["created_at"].as_i64().unwrap() > 0);
    assert_eq!(row["last_chat_at"], Value::Null);
    assert_eq!(row["last_chat_title"], Value::Null);

    let chat = chat_with(&server, version).await;
    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list[0]["last_chat_at"], chat["chat"]["updated_at"]);
    assert_eq!(list[0]["last_chat_title"], chat["chat"]["title"]);
    // An archived chat or one in the trash is no chat the card was last used in:
    // the library would not go on with it.
    for flag in ["archived", "trashed"] {
        let chat = format!("/api/chats/{}", chat["chat"]["id"]);
        server.patch(&chat, json!({ flag: true })).await;
        let (_, list) = server.get("/api/cards").await;
        assert_eq!(list[0]["last_chat_at"], Value::Null, "{flag}");
        assert_eq!(list[0]["last_chat_title"], Value::Null, "{flag}");
        server.patch(&chat, json!({ flag: false })).await;
        let (_, list) = server.get("/api/cards").await;
        assert!(list[0]["last_chat_at"].is_i64(), "{flag}");
    }
}

#[test]
fn an_excerpt_is_plain_text_on_one_line_cut_at_a_word() {
    assert_eq!(
        display::excerpt("*She   looks up.*\n\n<b>\"Oh.\"</b> <!-- a\nnote --> `ok`"),
        "She looks up. \"Oh.\" ok"
    );
    assert_eq!(
        display::excerpt("![her portrait](https://example.com/a.png) Rain. 1 < 2 and 3 > 2."),
        "Rain. 1 < 2 and 3 > 2."
    );
    assert_eq!(display::excerpt(""), "");
    // What only marks words leaves no gap before the comma or full stop after it.
    assert_eq!(
        display::excerpt("*She waves*, then **smiles**. `Fine`."),
        "She waves, then smiles. Fine."
    );
    assert_eq!(display::excerpt("One<br>two"), "One two");

    let long = "word ".repeat(100);
    let cut = display::excerpt(&long);
    assert_eq!(cut.chars().count(), 300);
    assert!(cut.ends_with("word word…"), "{cut}");
    // Exactly as long as a row has room for: nothing is cut.
    let fits = "word ".repeat(59) + "ab en";
    assert_eq!(fits.chars().count(), 300);
    assert_eq!(display::excerpt(&fits), fits);
    assert_eq!(
        display::excerpt(&(fits.clone() + "d")),
        "word ".repeat(59) + "ab…"
    );

    // One endless word, and a text cut inside a character of several bytes.
    assert_eq!(
        display::excerpt(&"x".repeat(5000)),
        format!("{}…", "x".repeat(300))
    );
    let wide = "é".repeat(20_000);
    assert_eq!(display::excerpt(&wide), format!("{}…", "é".repeat(300)));
}

#[tokio::test]
async fn search_finds_every_word_in_title_names_or_tags() {
    let server = start().await;
    add(
        &server,
        card("Mira of the North Light", "Mira", &["sea", "mystery"]),
    )
    .await;
    add(
        &server,
        card("Élodie's Café", "Élodie", &["city", "slow burn"]),
    )
    .await;
    add(&server, card("100% Wool", "Tam_Lin", &["sheep"])).await;

    let find = async |query: &str| titles(&server, &format!("?sort=name&q={query}")).await;
    // In the title, in a character's name, in a tag; a part of a word will do.
    assert_eq!(find("north").await, ["Mira of the North Light"]);
    assert_eq!(find("tam").await, ["100% Wool"]);
    assert_eq!(find("myst").await, ["Mira of the North Light"]);
    // The name a character has in lists counts as well.
    assert_eq!(find("storm%20night").await.len(), 3);
    // Every word has to be there, in whichever of them.
    assert_eq!(find("light%20sea").await, ["Mira of the North Light"]);
    assert_eq!(find("light%20city").await, [] as [&str; 0]);
    // Upper and lower case are the same, beyond a to z too.
    assert_eq!(find("%C3%89LODIE").await, ["Élodie's Café"]);
    assert_eq!(find("%C3%A9lodie%20CAF%C3%89").await, ["Élodie's Café"]);
    // A percent sign and an underscore are searched for as they are.
    assert_eq!(find("%25").await, ["100% Wool"]);
    assert_eq!(find("_").await, ["100% Wool"]);
    assert_eq!(find("m_ra").await, [] as [&str; 0]);
    // Nothing to search for lists everything.
    assert_eq!(find("%20").await.len(), 3);
}

#[tokio::test]
async fn archived_cards_show_on_request_or_in_a_search_and_trashed_ones_never() {
    let server = start().await;
    let (plain, _) = add(&server, card("Anchor", "Ann", &["sea"])).await;
    let (archived, _) = add(&server, card("Beacon", "Bea", &["sea"])).await;
    let (trashed, _) = add(&server, card("Cove", "Cal", &["sea"])).await;
    let (favorite, _) = add(&server, card("Dune", "Dee", &["sand"])).await;
    server
        .patch(
            &format!("/api/cards/{archived}"),
            json!({ "archived": true, "favorite": true }),
        )
        .await;
    server
        .patch(
            &format!("/api/cards/{trashed}"),
            json!({ "trashed": true, "favorite": true }),
        )
        .await;
    server
        .patch(
            &format!("/api/cards/{favorite}"),
            json!({ "favorite": true }),
        )
        .await;

    assert_eq!(titles(&server, "?sort=name").await, ["Anchor", "Dune"]);
    assert_eq!(
        titles(&server, "?sort=name&show=all").await,
        ["Anchor", "Dune"]
    );
    assert_eq!(titles(&server, "?show=favorites").await, ["Dune"]);
    assert_eq!(titles(&server, "?show=archived").await, ["Beacon"]);
    // A search finds the archived card too and lists it after the others,
    // whatever the order asked for. The trashed one stays out.
    assert_eq!(
        titles(&server, "?sort=name&q=sea").await,
        ["Anchor", "Beacon"]
    );
    server
        .patch(&format!("/api/cards/{plain}"), json!({ "favorite": true }))
        .await;
    assert_eq!(
        titles(&server, "?sort=added&q=sea").await,
        ["Anchor", "Beacon"]
    );
    assert_eq!(
        titles(&server, "?show=favorites&q=sea").await,
        ["Anchor", "Beacon"]
    );
    assert_eq!(titles(&server, "?show=archived&q=sea").await, ["Beacon"]);
    assert_eq!(
        titles(&server, "?show=archived&q=anchor").await,
        [] as [&str; 0]
    );

    let (status, body) = server.get("/api/cards?show=everything").await;
    assert_eq!(status, 400, "{body}");
}

#[tokio::test]
async fn the_list_is_ordered_by_last_chat_name_or_date_added() {
    let server = start().await;
    let (_, azure) = add(&server, card("azure", "B", &[])).await;
    add(&server, card("Álpha", "A", &[])).await;
    add(&server, card("Gamma", "G", &[])).await;

    // By name as a reader orders them: a capital and a mark on a letter change nothing.
    assert_eq!(
        titles(&server, "?sort=name").await,
        ["Álpha", "azure", "Gamma"]
    );
    assert_eq!(
        titles(&server, "?sort=added").await,
        ["Gamma", "Álpha", "azure"]
    );
    // Never chatted with: the newest first.
    assert_eq!(titles(&server, "").await, ["Gamma", "Álpha", "azure"]);
    chat_with(&server, azure).await;
    assert_eq!(
        titles(&server, "?sort=last_chatted").await,
        ["azure", "Gamma", "Álpha"]
    );
    assert_eq!(titles(&server, "").await, ["azure", "Gamma", "Álpha"]);
}

#[tokio::test]
async fn a_card_gives_its_texts_as_a_reader_sees_them() {
    let server = start().await;
    let mut container = common::container();
    container.toml[0].1 = container.toml[0]
        .1
        .replace("[meta-info]", "[meta-info]\ncreator = \" Ines \"");
    let (id, _) = add(&server, png::write(&container).unwrap()).await;

    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["creator"], "Ines");
    let mira = &detail["characters"][0];
    assert_eq!(
        mira["greetings"],
        json!([
            "\"You picked a night for it, Guest.\"",
            "Hold the lamp. Don't ask."
        ])
    );
    assert_eq!(
        mira["description"],
        "Keeper of the north light. Mira counts ships.\n\nA patched oilskin coat."
    );
    // The pinned revision, as the model is told.
    assert_eq!(mira["personality"], "Wry, patient.");
    assert_eq!(
        mira["scenario"],
        "A storm has cut the causeway. Guest is stranded."
    );
    assert_eq!(
        mira["example_dialogue"],
        "<START>\nGuest: Tea?\nMira: \"Black.\""
    );
    assert_eq!(mira["creator_notes"], "Never sent to the model.");
    // A card holds one character: the first of the file's two.
    assert_eq!(detail["characters"].as_array().unwrap().len(), 1);

    let (_, plain) = server
        .get(&format!(
            "/api/cards/{}",
            add(&server, common::card_file()).await.0
        ))
        .await;
    assert_eq!(plain["creator"], "");
}

#[tokio::test]
async fn a_cards_chats_are_listed_newest_first_without_archived_and_trashed_ones() {
    let server = start().await;
    let (id, first_version) = add(&server, common::card_file()).await;
    let (other, other_version) = add(&server, card("Other", "Otto", &[])).await;
    let id_of = |view: &Value| view["chat"]["id"].as_i64().unwrap();

    let old = id_of(&chat_with(&server, first_version).await);
    // A chat stays the card's when the card is edited.
    let (_, second) = server
        .edit_card(&json!(id), |form| {
            form["characters"][0]["personality"][0]["text"] = json!("Warm.")
        })
        .await;
    let second = second["id"].as_i64().unwrap();
    let new = id_of(&chat_with(&server, second).await);
    let archived = id_of(&chat_with(&server, second).await);
    let trashed = id_of(&chat_with(&server, second).await);
    let elsewhere = id_of(&chat_with(&server, other_version).await);
    server
        .patch(
            &format!("/api/chats/{archived}"),
            json!({ "archived": true }),
        )
        .await;
    server
        .patch(&format!("/api/chats/{trashed}"), json!({ "trashed": true }))
        .await;
    // Writing in the old chat makes it the one written in last.
    server
        .post(
            &format!("/api/chats/{old}/messages"),
            json!({ "content": "Still here." }),
        )
        .await;

    let ids = async |card: i64| -> Vec<i64> {
        let (status, chats) = server.get(&format!("/api/cards/{card}/chats")).await;
        assert_eq!(status, 200, "{chats}");
        chats
            .as_array()
            .unwrap()
            .iter()
            .map(|chat| chat["id"].as_i64().unwrap())
            .collect()
    };
    assert_eq!(ids(id).await, [old, new]);
    assert_eq!(ids(other).await, [elsewhere]);
    // Taken out of the trash, the chat is back.
    server
        .patch(
            &format!("/api/chats/{trashed}"),
            json!({ "trashed": false }),
        )
        .await;
    assert_eq!(ids(id).await, [old, trashed, new]);

    assert_eq!(
        server.get("/api/cards/99/chats").await,
        (
            404,
            json!({ "code": "not_found", "error": "no such card", "details": { "what": "card" } })
        )
    );
}

#[tokio::test]
async fn a_chat_names_the_card_of_each_character() {
    let server = start().await;
    let (id, version) = add(&server, common::card_file()).await;
    let view = chat_with(&server, version).await;
    assert_eq!(view["characters"][0]["card_id"], id);
    assert_eq!(
        view["characters"][0]["card_title"],
        "Mira of the North Light"
    );
}

#[test]
fn an_edit_changes_what_the_library_shows_and_finds() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let first = cards::import(db, me, &card("Harbour", "Hal", &["sea"])).unwrap();
    let mut form = cards::editable(db, me, first.card_id, None).unwrap();
    form.characters[0].name = "Hollis".to_string();
    form.tags = vec!["city".to_string()];
    cards::edit(db, me, first.card_id, &form).unwrap();

    let found = |query: &str| {
        cards::find(
            db,
            me,
            &Find {
                query,
                ..Find::default()
            },
        )
        .unwrap()
    };
    // Names and tags are the card's as it is now.
    let listed = &found("")[0];
    assert_eq!((listed.title.as_str(), listed.version), ("Harbour", 2));
    assert_eq!(listed.names, ["Hollis"]);
    assert_eq!(listed.tags, ["city"]);
    assert_eq!(found("hollis city harbour").len(), 1);
    assert!(found("hal").is_empty() && found("sea").is_empty());
}

#[test]
fn a_card_from_before_the_library_or_with_an_outdated_row_is_listed_in_full_after_a_start() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let unlisted = cards::import(db, me, &card("Unlisted", "Una", &["sea"])).unwrap();
    let outdated = cards::import(db, me, &card("Outdated", "Odo", &["old"])).unwrap();
    db.with(|conn| {
        // A newer version than its row tells, as an older build could leave it.
        conn.execute(
            "insert into card_versions (card_id, number, image_id, created_at)
             select card_id, 2, image_id, created_at from card_versions where id = ?1",
            [outdated.version_id],
        )?;
        conn.execute(
            "insert into card_files (version_id, name, toml, asset_id)
             select ?2, name, replace(toml, '\"old\"', '\"new\"'), asset_id from card_files where version_id = ?1",
            [outdated.version_id, conn.last_insert_rowid()],
        )?;
        conn.execute("delete from card_index where card_id = ?1", [unlisted.card_id])?;
        conn.execute(
            "update card_index set version_id = ?2, tags = '[\"old\"]', search = 'outdated' where card_id = ?1",
            [outdated.card_id, outdated.version_id],
        )
    })
    .unwrap();
    let all = Find {
        sort: Sort::Name,
        ..Find::default()
    };
    // Without its row a card is still listed, by its title alone.
    let before = cards::find(db, me, &all).unwrap();
    assert_eq!(
        (
            before[1].title.as_str(),
            before[1].names.len(),
            before[1].excerpt.as_str()
        ),
        ("Unlisted", 0, "")
    );

    cards::index_missing(db).unwrap();
    let after = cards::find(db, me, &all).unwrap();
    assert_eq!(after[0].tags, ["new"]);
    assert_eq!(after[1].names, ["Una"]);
    assert!(!after[1].excerpt.is_empty());
    assert_eq!(
        cards::find(
            db,
            me,
            &Find {
                query: "una",
                ..all
            }
        )
        .unwrap()
        .len(),
        1
    );
    assert_eq!(
        cards::find(
            db,
            me,
            &Find {
                query: "new",
                ..all
            }
        )
        .unwrap()
        .len(),
        1
    );
}

#[test]
fn a_card_that_cannot_be_read_is_listed_and_found_by_its_title() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let broken = cards::import(db, me, &card("Broken Compass", "Bram", &["sea"])).unwrap();
    db.with(|conn| {
        conn.execute(
            "update card_files set toml = 'not [toml' where version_id = ?1 and toml is not null",
            [broken.version_id],
        )?;
        conn.execute(
            "delete from card_index where card_id = ?1",
            [broken.card_id],
        )
    })
    .unwrap();
    let found = |query: &str| {
        cards::find(
            db,
            me,
            &Find {
                query,
                ..Find::default()
            },
        )
        .unwrap()
    };
    assert!(found("compass").is_empty());

    cards::index_missing(db).unwrap();
    assert_eq!(found("compass")[0].title, "Broken Compass");
    assert!(found("bram").is_empty());
    // Its row is written, so the next start does not try it again.
    let indexed: i64 = db
        .with(|conn| {
            conn.query_row(
                "select version_id from card_index where card_id = ?1",
                [broken.card_id],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(indexed, broken.version_id);
}

#[tokio::test]
async fn the_server_lists_older_cards_in_full_when_it_starts() {
    let server = start().await;
    add(&server, common::card_file()).await;
    {
        let options = server.options();
        let db = Db::open(
            &options.data_dir.join(FILE_NAME),
            options.key.given().unwrap(),
        )
        .unwrap();
        db.with(|conn| conn.execute("delete from card_index", []))
            .unwrap();
    }
    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list[0]["names"], json!([]));

    let server = server.restart().await;
    let (_, list) = server.get("/api/cards").await;
    assert_eq!(list[0]["names"], json!(["Mira"]));
}

#[test]
fn a_card_cannot_flood_the_list_with_names_and_tags() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let endless = "t".repeat(10_000);
    let mut tags: Vec<&str> = vec![&endless];
    let many: Vec<String> = (0..5000).map(|n| format!("tag{n}")).collect();
    tags.extend(many.iter().map(String::as_str));
    cards::import(db, me, &card("Flood", &"n".repeat(10_000), &tags)).unwrap();

    let listed = cards::find(
        db,
        me,
        &Find {
            show: Show::All,
            ..Find::default()
        },
    )
    .unwrap()
    .remove(0);
    assert_eq!(listed.tags.len(), 64);
    assert_eq!(listed.tags[0], "t".repeat(64));
    assert_eq!(listed.names[0], "n".repeat(64));
    // What was cut is not searched either; what was kept is.
    let found = |query: &str| {
        cards::find(
            db,
            me,
            &Find {
                query,
                ..Find::default()
            },
        )
        .unwrap()
        .len()
    };
    assert_eq!((found("tag62"), found("tag4999")), (1, 0));
}

#[tokio::test]
async fn a_cards_page_is_given_no_more_of_its_tags_than_the_list() {
    let server = start().await;
    let endless = "t".repeat(10_000);
    let mut tags: Vec<&str> = vec![&endless];
    let many: Vec<String> = (0..5000).map(|n| format!("tag{n}")).collect();
    tags.extend(many.iter().map(String::as_str));
    let (id, _) = add(&server, card("Flood", "Finn", &tags)).await;

    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["tags"], detail["card"]["tags"]);
    assert_eq!(detail["tags"].as_array().unwrap().len(), 64);
    assert_eq!(detail["tags"][0], "t".repeat(64));
}

/// Five cards for the tests of the tags: three the library lists, one archived, one in the trash.
async fn tagged(server: &Server) {
    add(
        server,
        card("Anchor", "Ann", &["Sea", "keeper", "Slow Burn"]),
    )
    .await;
    add(server, card("Beacon", "Bea", &["sea", "Élan", "SEA"])).await;
    add(
        server,
        card(
            "Cove",
            "Cal",
            &[" sea ", "Keeper", "seaside", "a,b & c", " "],
        ),
    )
    .await;
    let (archived, _) = add(server, card("Dune", "Dee", &["sea", "keeper", "dunes"])).await;
    let (trashed, _) = add(server, card("Eddy", "Edd", &["sea", "gone"])).await;
    server
        .patch(
            &format!("/api/cards/{archived}"),
            json!({ "archived": true }),
        )
        .await;
    server
        .patch(&format!("/api/cards/{trashed}"), json!({ "trashed": true }))
        .await;
}

#[tokio::test]
async fn tags_narrow_the_list_to_the_cards_that_have_them_all() {
    let server = start().await;
    tagged(&server).await;
    let find = async |query: &str| titles(&server, &format!("?sort=name&{query}")).await;
    let none: [&str; 0] = [];

    // The whole tag, where a search finds a part of one. Tags are no search:
    // an archived card stays out.
    assert_eq!(find("tag=sea").await, ["Anchor", "Beacon", "Cove"]);
    assert_eq!(find("q=sea").await, ["Anchor", "Beacon", "Cove", "Dune"]);
    assert_eq!(find("tag=seaside").await, ["Cove"]);
    assert_eq!(find("tag=slow").await, none);
    // Whatever its case, beyond a to z too, and whatever the space around it.
    assert_eq!(find("tag=SEA").await, ["Anchor", "Beacon", "Cove"]);
    assert_eq!(find("tag=%C3%A9lan").await, ["Beacon"]);
    assert_eq!(find("tag=%20KEEPER%20").await, ["Anchor", "Cove"]);
    // Every tag asked for has to be there. One asked for twice is asked for
    // once, and one without letters asks for nothing.
    assert_eq!(find("tag=sea&tag=keeper").await, ["Anchor", "Cove"]);
    assert_eq!(find("tag=sea&tag=keeper&tag=seaside").await, ["Cove"]);
    assert_eq!(find("tag=sea&tag=%C3%A9lan&tag=keeper").await, none);
    assert_eq!(
        find("tag=keeper&tag=Keeper&tag=&tag=%20").await,
        ["Anchor", "Cove"]
    );
    assert_eq!(find("tag=nobody-has-this").await, none);
    // A tag is taken as it is written, with what parts words and tags elsewhere.
    assert_eq!(find("tag=a%2Cb%20%26%20c").await, ["Cove"]);
    assert_eq!(find("tag=slow+burn").await, ["Anchor"]);
    // Together with a search, which finds archived cards and lists them last,
    // and with All, Favorites and Archived.
    assert_eq!(find("tag=keeper&q=cove").await, ["Cove"]);
    assert_eq!(find("tag=keeper&q=e").await, ["Anchor", "Cove", "Dune"]);
    assert_eq!(find("tag=keeper&show=archived").await, ["Dune"]);
    assert_eq!(find("tag=sea&show=favorites").await, none);
    let (_, list) = server.get("/api/cards?tag=%C3%A9lan").await;
    server
        .patch(
            &format!("/api/cards/{}", list[0]["id"]),
            json!({ "favorite": true }),
        )
        .await;
    assert_eq!(find("tag=sea&show=favorites").await, ["Beacon"]);
    // In the order asked for.
    assert_eq!(
        titles(&server, "?sort=added&tag=sea").await,
        ["Cove", "Beacon", "Anchor"]
    );
}

#[tokio::test]
async fn the_tags_to_choose_from_are_counted_among_the_cards_listed() {
    let server = start().await;
    tagged(&server).await;
    // Each tag as it is written, how many cards have it, and whether it was asked for.
    let tags = async |query: &str| -> Vec<(String, u64, bool)> {
        let (status, tags) = server.get(&format!("/api/cards/tags{query}")).await;
        assert_eq!(status, 200, "{tags}");
        let tag = |tag: &Value| {
            (
                tag["tag"].as_str().unwrap().to_string(),
                tag["cards"].as_u64().unwrap(),
                tag["chosen"].as_bool().unwrap(),
            )
        };
        tags.as_array().unwrap().iter().map(tag).collect()
    };
    let named = |tags: &[(&str, u64, bool)]| -> Vec<(String, u64, bool)> {
        tags.iter()
            .map(|(tag, cards, chosen)| (tag.to_string(), *cards, *chosen))
            .collect()
    };

    // The tags of the cards the list shows, so none of an archived card or of
    // one in the trash, in the order of their names. A tag is one whatever its
    // case and the space around it, also where one card has it twice, and is
    // written as most cards write it; where that does not tell, as the first
    // by its letters.
    let all = [
        ("a,b & c", 1, false),
        ("Élan", 1, false),
        ("Keeper", 2, false),
        ("sea", 3, false),
        ("seaside", 1, false),
        ("Slow Burn", 1, false),
    ];
    assert_eq!(tags("").await, named(&all));
    assert_eq!(tags("?sort=added&show=all").await, named(&all));
    // With tags asked for: the same tags, each with how many of the cards
    // that have those have it. So one that would leave no card counts 0.
    assert_eq!(
        tags("?tag=KEEPER&tag=%20Sea").await,
        named(&[
            ("a,b & c", 1, false),
            ("Élan", 0, false),
            ("Keeper", 2, true),
            ("sea", 2, true),
            ("seaside", 1, false),
            ("Slow Burn", 1, false),
        ])
    );
    // A tag asked for that no card has is there too, as it was asked for, once.
    assert_eq!(
        tags("?tag=%20Nobody%20Has%20This&tag=nobody+has+this&tag=").await,
        named(&[
            ("a,b & c", 0, false),
            ("Élan", 0, false),
            ("Keeper", 0, false),
            ("Nobody Has This", 0, true),
            ("sea", 0, false),
            ("seaside", 0, false),
            ("Slow Burn", 0, false),
        ])
    );
    // Of the cards the list shows as it is asked otherwise: the archived ones,
    // the favorites, those a search finds, which are the archived ones too.
    assert_eq!(
        tags("?show=archived").await,
        named(&[("dunes", 1, false), ("keeper", 1, false), ("sea", 1, false)])
    );
    assert_eq!(tags("?show=favorites").await, []);
    assert_eq!(
        tags("?q=cove").await,
        named(&[
            ("a,b & c", 1, false),
            ("Keeper", 1, false),
            ("sea", 1, false),
            ("seaside", 1, false)
        ])
    );
    assert_eq!(
        tags("?q=keeper&tag=dunes").await,
        named(&[
            ("a,b & c", 0, false),
            ("dunes", 1, true),
            ("keeper", 1, false),
            ("sea", 1, false),
            ("seaside", 0, false),
            ("Slow Burn", 0, false)
        ])
    );

    let (status, body) = server.get("/api/cards/tags?show=everything").await;
    assert_eq!(status, 400, "{body}");
}

#[test]
fn the_tags_to_choose_from_are_those_of_ones_own_cards() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let other = cw_accounts::users::create(db, "olga").unwrap();
    cards::import(db, me, &card("Mine", "Mo", &["mine"])).unwrap();
    cards::import(db, other, &card("Theirs", "Theo", &["theirs"])).unwrap();

    let tags = cards::tag_counts(db, me, &Find::default()).unwrap();
    assert_eq!(
        tags,
        [cards::TagCount {
            tag: "mine".into(),
            cards: 1,
            chosen: false
        }]
    );
    let theirs = ["theirs".to_string()];
    assert!(
        cards::find(
            db,
            me,
            &Find {
                tags: &theirs,
                ..Find::default()
            }
        )
        .unwrap()
        .is_empty()
    );
}

#[tokio::test]
async fn every_page_of_the_user_is_told_of_a_cards_change() {
    let server = start().await;
    let mut socket = server.listen().await;
    let (id, _) = add(&server, common::card_file()).await;
    let told = json!({ "type": "card", "id": id });
    assert_eq!(event(&mut socket).await, told);

    // Starred, archived, a lorebook of the library attached and taken off.
    let path = format!("/api/cards/{id}");
    for flag in [json!({ "favorite": true }), json!({ "archived": true })] {
        assert_eq!(server.patch(&path, flag).await.0, 200);
        assert_eq!(event(&mut socket).await, told);
    }
    let world =
        json!({ "name": "Mere", "entries": { "0": { "key": ["fog"], "content": "Fog." } } });
    let (status, imported) = server
        .upload(
            "/api/lorebooks?name=mere.json",
            world.to_string().into_bytes(),
        )
        .await;
    assert_eq!(status, 201, "{imported}");
    let lorebook = imported["lorebook"]["id"].as_i64().unwrap();
    assert_eq!(event(&mut socket).await["type"], "lorebook");
    let attach = json!({ "lorebook_id": lorebook });
    assert_eq!(
        server.post(&format!("{path}/lorebooks"), attach).await.0,
        200
    );
    assert_eq!(event(&mut socket).await, told);
    let detach = format!("{path}/lorebooks/{lorebook}");
    assert_eq!(
        server.call(reqwest::Method::DELETE, &detach, None).await.0,
        200
    );
    assert_eq!(event(&mut socket).await, told);

    // Its texts edited as its editor saves them.
    let (_, edit) = server.get(&format!("{path}/edit")).await;
    let saved = server.put(&format!("{path}/edit"), edit).await;
    assert_eq!(saved.0, 200, "{}", saved.1);
    assert_eq!(event(&mut socket).await, told);
}

/// An exact copy of a card the library has (the same picture and texts) is not
/// imported again; one with another text or another asset is, and so is a copy of a card in the Trash.
#[test]
fn an_exact_copy_of_a_card_is_not_imported_again() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let first = cards::import(db, user, &common::card_file()).unwrap();
    let again = cards::import(db, user, &common::card_file()).unwrap_err();
    assert_eq!(format!("{again:#}"), "already in your library");
    cards::import(db, user, &card("Other", "mira", &[])).unwrap();
    let mut other_asset = common::container();
    other_asset.assets[0].1 = b"another picture".to_vec();
    cards::import(db, user, &png::write(&other_asset).unwrap()).unwrap();
    cards::set_trashed(db, user, first.card_id, true).unwrap();
    cards::import(db, user, &common::card_file()).unwrap();
}

/// Cards of one picture (all JSON cards have the picture of one pixel) are told from an exact copy without
/// reading each one's files: the last of 300 is imported about as fast as the first (it grew with their
/// number: 13 ms more per import at 5,000 cards, a release build); a copy in a file of other bytes is
/// refused.
#[test]
fn a_copy_is_told_without_reading_every_card_of_its_picture() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let file = |n: usize| {
        let text = "A card in a JSON file. ".repeat(200);
        json!({ "spec": "chara_card_v2", "spec_version": "2.0",
                "data": { "name": format!("Card {n}"), "description": text, "first_mes": "Hello." } })
        .to_string()
        .into_bytes()
    };
    let mut times = Vec::new();
    for n in 0..300 {
        let since = std::time::Instant::now();
        cards::import(db, user, &file(n)).unwrap();
        times.push(since.elapsed());
    }
    let first: std::time::Duration = times[..50].iter().sum();
    let last: std::time::Duration = times[250..].iter().sum();
    assert!(
        last < first * 3 + std::time::Duration::from_millis(100),
        "first 50: {first:?}, last 50: {last:?}"
    );
    let mut spaced = file(7);
    spaced.push(b' ');
    let again = cards::import(db, user, &spaced).unwrap_err();
    assert_eq!(format!("{again:#}"), "already in your library");
}

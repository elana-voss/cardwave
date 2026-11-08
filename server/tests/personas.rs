//! Personas as the library keeps them: listed, changed, one of them the
//! default, and through the Trash.

mod common;

use common::Scratch;
use common::server::{Server, event, start};
use cw_chat::chats::{self, NewChat};
use cw_library::cards;
use cw_library::personas::{self, Persona};
use cw_library::trash::{self, DAYS, TrashItem};
use cw_store::Db;
use reqwest::Method;
use serde_json::{Value, json};

const DAY: i64 = 24 * 60 * 60 * 1000;

fn persona(scratch: &Scratch, id: i64) -> Persona {
    personas::get(&scratch.db, scratch.user, id)
        .unwrap()
        .expect("the persona is gone")
}

/// The names the list shows for a search, in its order.
fn names(scratch: &Scratch, query: &str) -> Vec<String> {
    personas::find(&scratch.db, scratch.user, query)
        .unwrap()
        .into_iter()
        .map(|persona| persona.name)
        .collect()
}

/// A chat with the sample card's character, as `persona`.
fn chat(scratch: &Scratch, persona_id: Option<i64>) -> anyhow::Result<i64> {
    let card = cards::import(&scratch.db, scratch.user, &common::card_copy())?;
    chats::create(
        &scratch.db,
        scratch.user,
        &NewChat {
            characters: &[(card.version_id, "mira")],
            persona_id,
            greeting: 0,
        },
    )
}

fn chat_persona(scratch: &Scratch, chat_id: i64) -> Option<i64> {
    chats::get(&scratch.db, scratch.user, chat_id)
        .unwrap()
        .expect("the chat is gone")
        .persona_id
}

/// Makes an item look as if it went to the Trash at `at`.
fn trashed_at(db: &Db, table: &str, id: i64, at: i64) {
    let changed = db
        .with(|conn| {
            conn.execute(
                &format!(
                    "update {table} set trashed_at = ?2 where id = ?1 and trashed_at is not null"
                ),
                [id, at],
            )
        })
        .unwrap();
    assert_eq!(changed, 1, "{table} {id} is not in the Trash");
}

/// The personas the Trash lists, as (id, chats it is in).
fn in_trash(db: &Db, user: i64) -> Vec<(i64, u32)> {
    trash::list(db, user)
        .unwrap()
        .into_iter()
        .filter_map(|item| match item {
            TrashItem::Persona { id, chats, .. } => Some((id, chats)),
            _ => None,
        })
        .collect()
}

#[test]
fn a_persona_is_changed_in_its_name_its_description_or_both_and_needs_a_name() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let id = personas::create(db, me, "  Ines ", "A surveyor.").unwrap();
    // The blanks around a name are not kept.
    assert_eq!(
        (
            persona(&scratch, id).name.as_str(),
            persona(&scratch, id).description.as_str()
        ),
        ("Ines", "A surveyor.")
    );
    assert!(personas::create(db, me, " \t", "Nobody.").is_err());

    personas::change(db, me, id, Some(" Inês "), None).unwrap();
    assert_eq!(
        (
            persona(&scratch, id).name.as_str(),
            persona(&scratch, id).description.as_str()
        ),
        ("Inês", "A surveyor.")
    );
    personas::change(db, me, id, None, Some("")).unwrap();
    assert_eq!(
        (
            persona(&scratch, id).name.as_str(),
            persona(&scratch, id).description.as_str()
        ),
        ("Inês", "")
    );
    personas::change(db, me, id, Some("Ida"), Some("A pilot.")).unwrap();
    assert_eq!(
        (
            persona(&scratch, id).name.as_str(),
            persona(&scratch, id).description.as_str()
        ),
        ("Ida", "A pilot.")
    );

    // A name of blanks is refused, and nothing of the change is written.
    let refused = personas::change(db, me, id, Some("  "), Some("Lost.")).unwrap_err();
    assert_eq!(refused.to_string(), "a persona needs a name");
    assert_eq!(
        (
            persona(&scratch, id).name.as_str(),
            persona(&scratch, id).description.as_str()
        ),
        ("Ida", "A pilot.")
    );
    assert!(personas::change(db, me, 99, Some("Nobody"), None).is_err());
}

#[test]
fn the_list_is_by_name_without_those_in_the_trash() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let [zoe, _, _, _, gone] = [
        personas::create(db, me, "Zoe", "A diver from Århus.").unwrap(),
        personas::create(db, me, "enzo", "A diver.").unwrap(),
        personas::create(db, me, "Émil", "Keeps the ferry's books in Ålesund.").unwrap(),
        personas::create(db, me, "Olga", "An old DIVER, retired.").unwrap(),
        personas::create(db, me, "Gone", "A diver nobody misses.").unwrap(),
    ];
    personas::set_trashed(db, me, gone, true).unwrap();
    assert!(persona(&scratch, gone).trashed && !persona(&scratch, zoe).trashed);

    // By name as a reader orders them: a capital and a mark on a letter change nothing.
    // Without the one in the Trash.
    assert_eq!(names(&scratch, ""), ["Émil", "enzo", "Olga", "Zoe"]);
    assert_eq!(names(&scratch, "  "), ["Émil", "enzo", "Olga", "Zoe"]);

    // Every word, in the name or the description, in any case.
    assert_eq!(names(&scratch, "diver"), ["enzo", "Olga", "Zoe"]);
    assert_eq!(names(&scratch, "DIVER århus"), ["Zoe"]);
    assert_eq!(names(&scratch, "ÉMIL ålesund"), ["Émil"]);
    assert_eq!(names(&scratch, "diver ferry"), [] as [&str; 0]);
    assert_eq!(names(&scratch, "ENZO"), ["enzo"]);

    personas::set_trashed(db, me, gone, false).unwrap();
    assert_eq!(names(&scratch, ""), ["Émil", "enzo", "Gone", "Olga", "Zoe"]);
}

#[test]
fn one_persona_is_the_default_and_only_while_it_is_out_of_the_trash() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let ines = personas::create(db, me, "Ines", "").unwrap();
    let omar = personas::create(db, me, "Omar", "").unwrap();
    let default = || personas::default_of(db, me).unwrap();
    let marked = || {
        (
            persona(&scratch, ines).is_default,
            persona(&scratch, omar).is_default,
        )
    };
    assert_eq!((default(), marked()), (None, (false, false)));

    personas::set_default(db, me, ines, true).unwrap();
    assert_eq!((default(), marked()), (Some(ines), (true, false)));
    // Another one takes its place.
    personas::set_default(db, me, omar, true).unwrap();
    assert_eq!((default(), marked()), (Some(omar), (false, true)));
    // Taking it back from one that is not the default leaves the default alone.
    personas::set_default(db, me, ines, false).unwrap();
    assert_eq!((default(), marked()), (Some(omar), (false, true)));

    // In the Trash it is not the default, and is again once it is back.
    personas::set_trashed(db, me, omar, true).unwrap();
    assert_eq!((default(), marked()), (None, (false, false)));
    personas::set_trashed(db, me, omar, false).unwrap();
    assert_eq!((default(), marked()), (Some(omar), (false, true)));

    personas::set_default(db, me, omar, false).unwrap();
    assert_eq!((default(), marked()), (None, (false, false)));

    // One in the Trash is not made the default.
    personas::set_trashed(db, me, ines, true).unwrap();
    let refused = personas::set_default(db, me, ines, true).unwrap_err();
    assert_eq!(
        refused.to_string(),
        "a persona in the Trash cannot be the default; restore it first"
    );
    assert_eq!((default(), marked()), (None, (false, false)));
    assert!(personas::set_default(db, me, 99, true).is_err());
}

#[test]
fn a_chat_keeps_its_persona_in_the_trash_until_that_is_deleted_for_good() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let ines = personas::create(db, me, "Ines", "A surveyor.").unwrap();
    let omar = personas::create(db, me, "Omar", "").unwrap();
    let talk = chat(&scratch, Some(ines)).unwrap();
    let other = chat(&scratch, Some(omar)).unwrap();
    personas::set_default(db, me, ines, true).unwrap();
    let user_name = || {
        chats::prompt_inputs(db, me, talk, None)
            .unwrap()
            .state
            .persona_name
    };

    personas::set_trashed(db, me, ines, true).unwrap();
    assert_eq!(
        (chat_persona(&scratch, talk), user_name().as_str()),
        (Some(ines), "Ines")
    );

    // It is given to no chat while it is there: neither a running one nor a new one.
    let refused = chats::set_persona(db, me, other, Some(ines)).unwrap_err();
    assert_eq!(
        refused.to_string(),
        "the persona “Ines” is in the Trash; restore it to use it"
    );
    assert_eq!(chat_persona(&scratch, other), Some(omar));
    let refused = chat(&scratch, Some(ines)).unwrap_err();
    assert_eq!(
        refused.to_string(),
        "the persona “Ines” is in the Trash; restore it to use it"
    );
    // A chat that has it may drop it.
    chats::set_persona(db, me, other, None).unwrap();

    // Back out, all is as it was.
    personas::set_trashed(db, me, ines, false).unwrap();
    assert_eq!(
        (
            chat_persona(&scratch, talk),
            personas::default_of(db, me).unwrap()
        ),
        (Some(ines), Some(ines))
    );
    chats::set_persona(db, me, other, Some(ines)).unwrap();

    // Deleted for good, its chats go on without a persona, and nobody's default is left behind.
    personas::set_trashed(db, me, ines, true).unwrap();
    trash::delete_persona(db, me, ines).unwrap();
    assert!(personas::get(db, me, ines).unwrap().is_none());
    assert_eq!(
        (
            chat_persona(&scratch, talk),
            chat_persona(&scratch, other),
            user_name().as_str()
        ),
        (None, None, "User")
    );
    let left: Option<i64> = db
        .with(|conn| {
            conn.query_row(
                "select default_persona_id from users where id = ?1",
                [me],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(left, None);
}

#[test]
fn a_persona_goes_through_the_trash_as_cards_and_chats_do() {
    assert_eq!(DAYS, 30);
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let now = 1_800_000_000_000;
    let [old, recent, live] =
        ["Old", "Recent", "Live"].map(|name| personas::create(db, me, name, "").unwrap());
    let [first, second, deleted] = [(); 3].map(|()| chat(&scratch, Some(old)).unwrap());
    chats::set_trashed(db, me, deleted, true).unwrap();
    trashed_at(db, "chats", deleted, now);
    assert!(in_trash(db, me).is_empty());

    // Only what is in the Trash is deleted for good.
    let refused = trash::delete_persona(db, me, old).unwrap_err();
    assert_eq!(
        refused.to_string(),
        "only a persona in the Trash can be deleted for good; move it there first"
    );
    assert!(trash::delete_persona(db, me, 99).is_err());

    personas::set_trashed(db, me, old, true).unwrap();
    trashed_at(db, "personas", old, now - 30 * DAY - 1);
    // Deleting again does not count its days anew.
    personas::set_trashed(db, me, old, true).unwrap();
    let since: i64 = db
        .with(|conn| {
            conn.query_row(
                "select trashed_at from personas where id = ?1",
                [old],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(since, now - 30 * DAY - 1);
    personas::set_trashed(db, me, recent, true).unwrap();
    trashed_at(db, "personas", recent, now - 30 * DAY);
    // Another user's Trash is its own, and is emptied by the same clock.
    let sam = cw_accounts::users::create(db, "sam").unwrap();
    let sams = personas::create(db, sam, "Sam's", "").unwrap();
    personas::set_trashed(db, sam, sams, true).unwrap();
    trashed_at(db, "personas", sams, now - 30 * DAY - 1);
    // The one deleted last comes first; a chat that is in the Trash itself is not counted.
    assert_eq!(in_trash(db, me), [(recent, 0), (old, 2)]);
    assert_eq!(in_trash(db, sam), [(sams, 0)]);
    assert!(
        personas::set_trashed(db, me, 99, true).is_err()
            && personas::set_trashed(db, me, 99, false).is_err()
    );

    // After thirty days it goes, and the chat deleted by itself just now stays.
    assert_eq!(trash::purge(db, now).unwrap(), 2);
    assert!(
        personas::get(db, me, old).unwrap().is_none()
            && personas::get(db, sam, sams).unwrap().is_none()
    );
    assert_eq!(
        (
            chat_persona(&scratch, first),
            chat_persona(&scratch, second)
        ),
        (None, None)
    );
    assert_eq!(in_trash(db, me), [(recent, 0)]);
    assert_eq!(trash::purge(db, now).unwrap(), 0);

    // Emptying takes the rest, and nothing that is not in the Trash.
    assert_eq!(trash::empty(db, me).unwrap(), 2);
    assert!(trash::list(db, me).unwrap().is_empty());
    assert!(personas::get(db, me, recent).unwrap().is_none());
    assert!(!persona(&scratch, live).trashed);
}

async fn delete(server: &Server, path: &str) -> (u16, Value) {
    server.call(Method::DELETE, path, None).await
}

/// What the list answers, as names.
async fn listed(server: &Server, query: &str) -> Vec<String> {
    let (status, list) = server.get(&format!("/api/personas{query}")).await;
    assert_eq!(status, 200, "{list}");
    list.as_array()
        .unwrap()
        .iter()
        .map(|persona| persona["name"].as_str().unwrap().to_string())
        .collect()
}

#[tokio::test]
async fn personas_are_listed_changed_and_deleted_over_http() {
    let server = start().await;
    let (status, ines) = server
        .post(
            "/api/personas",
            json!({ "name": " Ines ", "description": "A surveyor." }),
        )
        .await;
    let whole = json!({
        "id": ines["id"], "name": "Ines", "description": "A surveyor.",
        "trashed": false, "is_default": false, "picture": null, "lorebooks": [],
    });
    assert_eq!((status, &ines), (201, &whole));
    let id = ines["id"].as_i64().unwrap();
    let path = format!("/api/personas/{id}");
    let (_, omar) = server
        .post("/api/personas", json!({ "name": "Omar" }))
        .await;
    let omars = format!("/api/personas/{}", omar["id"]);
    assert_eq!(omar["description"], "");

    // A change answers with the persona as it is then; what it leaves out stays.
    let (status, changed) = server.patch(&path, json!({ "name": "Inès" })).await;
    assert_eq!(
        (status, &changed["name"], &changed["description"]),
        (200, &json!("Inès"), &json!("A surveyor."))
    );
    let (_, changed) = server
        .patch(
            &path,
            json!({ "description": "A pilot.", "is_default": true }),
        )
        .await;
    let now = json!({
        "id": id, "name": "Inès", "description": "A pilot.",
        "trashed": false, "is_default": true, "picture": null, "lorebooks": [],
    });
    assert_eq!(changed, now);
    let (status, error) = server.patch(&path, json!({ "name": " " })).await;
    assert_eq!(
        (status, error["error"].as_str().unwrap()),
        (400, "a persona needs a name")
    );
    // A name is as long as the form lets it be, counted in letters.
    let long = json!({ "name": "é".repeat(65) });
    for (status, error) in [
        server.patch(&path, long.clone()).await,
        server.post("/api/personas", long).await,
    ] {
        assert_eq!(
            (status, error["error"].as_str().unwrap()),
            (400, "a persona's name has at most 64 letters")
        );
    }
    assert_eq!(
        server
            .patch(&path, json!({ "name": format!(" {} ", "é".repeat(64)) }))
            .await
            .0,
        200
    );
    server.patch(&path, json!({ "name": "Inès" })).await;
    assert_eq!(server.patch(&path, json!({})).await, (200, now));
    // The default moves to another, and is taken back.
    assert_eq!(
        server.patch(&omars, json!({ "is_default": true })).await.1["is_default"],
        true
    );
    assert_eq!(listed(&server, "").await, ["Inès", "Omar"]);
    assert_eq!(server.get("/api/personas").await.1[0]["is_default"], false);
    assert_eq!(
        server.patch(&omars, json!({ "is_default": false })).await.1["is_default"],
        false
    );

    // The list takes a search in its address.
    assert_eq!(listed(&server, "?q=PILOT").await, ["Inès"]);
    assert_eq!(listed(&server, "?q=o").await, ["Inès", "Omar"]);

    // Deleting for good: only from the Trash, where it is listed, and then it is gone.
    let (status, error) = delete(&server, &path).await;
    assert_eq!(status, 400);
    assert!(
        error["error"].as_str().unwrap().contains("in the Trash"),
        "{error}"
    );
    let (status, changed) = server.patch(&path, json!({ "trashed": true })).await;
    assert_eq!(
        (status, &changed["trashed"], &changed["is_default"]),
        (200, &json!(true), &json!(false))
    );
    assert_eq!(listed(&server, "?q=in").await, [] as [&str; 0]);
    let (_, list) = server.get("/api/trash").await;
    let item = json!({ "kind": "persona", "id": id, "title": "Inès", "trashed_at": list["items"][0]["trashed_at"], "chats": 0 });
    assert_eq!(list["items"], json!([item]));
    assert!(list["items"][0]["trashed_at"].as_i64().unwrap() > 0);
    assert_eq!(
        server.patch(&path, json!({ "trashed": false })).await.1["trashed"],
        false
    );
    assert_eq!(server.get("/api/trash").await.1["items"], json!([]));
    server.patch(&path, json!({ "trashed": true })).await;
    assert_eq!(delete(&server, &path).await.0, 204);
    assert_eq!(delete(&server, &path).await.0, 404);
    assert_eq!(
        server.patch(&path, json!({ "name": "Nobody" })).await.0,
        404
    );
    assert_eq!(
        server.patch(&path, json!({ "is_default": true })).await.0,
        404
    );

    // Emptying the Trash takes personas too.
    server.patch(&omars, json!({ "trashed": true })).await;
    assert_eq!(delete(&server, "/api/trash").await.0, 204);
    assert_eq!(listed(&server, "").await, [] as [&str; 0]);
}

#[tokio::test]
async fn a_change_that_is_refused_changes_nothing_of_the_persona() {
    let server = start().await;
    let (_, ines) = server
        .post(
            "/api/personas",
            json!({ "name": "Ines", "description": "A surveyor." }),
        )
        .await;
    let path = format!("/api/personas/{}", ines["id"]);
    let refused = |change: Value| {
        let (server, path) = (&server, &path);
        async move {
            let (status, error) = server.patch(path, change).await;
            assert_eq!(status, 400, "{error}");
            error["error"].as_str().unwrap().to_string()
        }
    };

    // The default it asks for is refused for what the same change makes of the persona.
    let trashed =
        json!({ "name": "Inès", "description": "A pilot.", "trashed": true, "is_default": true });
    assert_eq!(
        refused(trashed).await,
        "a persona in the Trash cannot be the default; restore it first"
    );
    assert_eq!(server.get("/api/personas").await.1, json!([ines]));
    // So is a name that cannot be kept, with all that came with it.
    refused(json!({ "name": " ", "description": "A pilot.", "is_default": true })).await;
    assert_eq!(server.get("/api/personas").await.1, json!([ines]));

    // One in the Trash is refused as it is, and taken when the change brings it back.
    server.patch(&path, json!({ "trashed": true })).await;
    refused(json!({ "name": "Inès", "is_default": true })).await;
    let (status, back) = server
        .patch(&path, json!({ "trashed": false, "is_default": true }))
        .await;
    assert_eq!(
        (status, &back["name"], &back["trashed"], &back["is_default"]),
        (200, &json!("Ines"), &json!(false), &json!(true))
    );
}

#[tokio::test]
async fn a_new_chat_starts_with_the_default_persona_and_a_chat_shows_its_persona_wherever_that_is()
{
    let server = start().await;
    let (_, card) = server.upload("/api/cards", common::card_copy()).await;
    let (_, ines) = server
        .post("/api/personas", json!({ "name": "Ines" }))
        .await;
    let (_, omar) = server
        .post("/api/personas", json!({ "name": "Omar" }))
        .await;
    let ines_path = format!("/api/personas/{}", ines["id"]);
    let start = |persona: Option<&Value>| {
        let mut new =
            json!({ "characters": [{ "version_id": card["version_id"], "character": "mira" }] });
        if let Some(persona) = persona {
            new["persona_id"] = persona["id"].clone();
        }
        let server = &server;
        async move {
            let (status, view) = server.post("/api/chats", new).await;
            assert_eq!(status, 201, "{view}");
            view
        }
    };

    // Without a default, a chat that names nobody is with nobody in particular.
    let view = start(None).await;
    assert_eq!(
        (&view["chat"]["persona_id"], &view["persona"]),
        (&Value::Null, &Value::Null)
    );
    assert_eq!(
        view["messages"][0]["content"],
        "\"You picked a night for it, User.\""
    );

    let (_, default) = server
        .patch(&ines_path, json!({ "is_default": true }))
        .await;
    let view = start(None).await;
    assert_eq!(
        (&view["chat"]["persona_id"], &view["persona"]),
        (&ines["id"], &default)
    );
    // The greeting is written for it.
    assert_eq!(
        view["messages"][0]["content"],
        "\"You picked a night for it, Ines.\""
    );
    let with_default = view["chat"]["id"].as_i64().unwrap();
    // A chat that names its persona has that one.
    let view = start(Some(&omar)).await;
    assert_eq!(
        (&view["chat"]["persona_id"], &view["persona"]["name"]),
        (&omar["id"], &json!("Omar"))
    );

    // A default in the Trash is none; the chat that has it keeps it, and shows it as it is.
    server.patch(&ines_path, json!({ "trashed": true })).await;
    assert_eq!(start(None).await["chat"]["persona_id"], Value::Null);
    let (_, view) = server.get(&format!("/api/chats/{with_default}")).await;
    assert_eq!(
        (&view["chat"]["persona_id"], &view["persona"]["trashed"]),
        (&ines["id"], &json!(true))
    );

    // One in the Trash is given to no chat.
    let (status, error) = server.post("/api/chats", json!({
        "characters": [{ "version_id": card["version_id"], "character": "mira" }], "persona_id": ines["id"],
    })).await;
    assert_eq!(
        (status, error["error"].as_str().unwrap()),
        (
            400,
            "the persona “Ines” is in the Trash; restore it to use it"
        )
    );
    let other = start(Some(&omar)).await["chat"]["id"].as_i64().unwrap();
    let (status, _) = server
        .put(
            &format!("/api/chats/{other}/persona"),
            json!({ "persona_id": ines["id"] }),
        )
        .await;
    assert_eq!(status, 400);

    // Deleted for good, the chat goes on without one.
    assert_eq!(delete(&server, &ines_path).await.0, 204);
    let (_, view) = server.get(&format!("/api/chats/{with_default}")).await;
    assert_eq!(
        (&view["chat"]["persona_id"], &view["persona"]),
        (&Value::Null, &Value::Null)
    );
}

#[tokio::test]
async fn a_persona_has_a_picture_of_its_own() {
    let server = start().await;
    let (_, made) = server
        .post("/api/personas", json!({ "name": "Wren" }))
        .await;
    assert_eq!(made["picture"], Value::Null);
    let id = made["id"].as_i64().unwrap();
    let sent = reqwest::Client::new()
        .put(format!("http://{}/api/personas/{id}/picture", server.addr))
        .body(common::picture())
        .send()
        .await
        .unwrap();
    assert_eq!(sent.status(), 200);
    let persona: Value = sent.json().await.unwrap();
    let address = persona["picture"].as_str().unwrap();
    assert!(
        address.starts_with(&format!("/api/personas/{id}/picture?at=")),
        "{address}"
    );
    let (_, listed) = server.get("/api/personas").await;
    assert_eq!(listed[0]["picture"], address);
    let (headers, picture) = server.download(address).await;
    assert_eq!(headers["content-type"], "image/png");
    let made = image::load_from_memory(&picture).unwrap();
    assert_eq!((made.width(), made.height()), (128, 128));

    let (status, removed) = server
        .call(Method::DELETE, &format!("/api/personas/{id}/picture"), None)
        .await;
    assert_eq!((status, &removed["picture"]), (200, &Value::Null));
    assert_eq!(
        server.get(&format!("/api/personas/{id}/picture")).await.0,
        404
    );
}

#[tokio::test]
async fn every_page_of_the_user_is_told_of_a_change_of_the_personas() {
    let server = start().await;
    let mut socket = server.listen().await;
    let (told, trash) = (json!({ "type": "personas" }), json!({ "type": "trash" }));
    let (status, made) = server
        .post("/api/personas", json!({ "name": "Wren" }))
        .await;
    assert_eq!(status, 201, "{made}");
    assert_eq!(event(&mut socket).await, told);
    let path = format!("/api/personas/{}", made["id"]);

    // Changed, made the default; a change refused tells nothing, so the next told is the Trash's.
    for change in [
        json!({ "name": "Wren Hale" }),
        json!({ "is_default": true }),
    ] {
        assert_eq!(server.patch(&path, change).await.0, 200);
        assert_eq!(event(&mut socket).await, told);
    }
    assert_eq!(server.patch(&path, json!({ "name": " " })).await.0, 400);
    assert_eq!(server.patch(&path, json!({ "trashed": true })).await.0, 200);
    assert_eq!(event(&mut socket).await, told);
    assert_eq!(event(&mut socket).await, trash);
    assert_eq!(delete(&server, &path).await.0, 204);
    assert_eq!(event(&mut socket).await, told);
    assert_eq!(event(&mut socket).await, trash);
}

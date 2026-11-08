//! A lorebook's editor, continued from `lorebook_edit.rs`: the library's list after an edit, edits made at
//! once (threads on one `Scratch`, behind a `Barrier`), the editor over HTTP, every page told of a change,
//! and a lorebook made from scratch; its helpers are `common/lorebook_edit.rs`'s.

mod common;

use common::Scratch;
use common::lorebook_edit::*;
use common::server::{event, start};
use cw_library::cards::Show;
use cw_library::lorebooks;
use reqwest::Method;
use serde_json::{Value, json};

#[test]
fn the_library_lists_a_lorebook_as_it_is_after_an_edit() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let found = |query: &str| -> Vec<i64> {
        let found = lorebooks::find(db, user, query, Show::All)
            .unwrap()
            .into_iter();
        found.map(|lorebook| lorebook.id).collect()
    };
    // A name an entry is given is what the list calls it and finds it by.
    assert_eq!(found("beacon"), [] as [i64; 0]);
    let named = only(|change| change.name = Some("Beacon".into()));
    lorebooks::change_entry(db, user, id, "lore.lamp", &named).unwrap();
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.entries, kept.entry_names.clone()),
        (2, strings(&["The wreck", "Beacon"]))
    );
    assert_eq!(found("beacon"), [id]);
    lorebooks::add_entry(
        db,
        user,
        id,
        &only(|change| change.name = Some("Reef".into())),
    )
    .unwrap();
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.entries, kept.entry_names.clone()),
        (3, strings(&["The wreck", "Beacon", "Reef"]))
    );

    // The name and the description are the library's and the file's.
    lorebooks::describe(
        db,
        user,
        id,
        Some("  South \n Coast "),
        Some(" Of the south.\r\nAnd its reefs. "),
        [None; 2],
    )
    .unwrap();
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.name.as_str(), kept.description.as_str()),
        ("South Coast", "Of the south.\nAnd its reefs.")
    );
    let shown = lorebooks::editable(db, user, id).unwrap();
    assert_eq!(
        (shown.name.as_str(), shown.description.as_str()),
        ("South Coast", "Of the south.\nAnd its reefs.")
    );
    let now = file(&scratch, id);
    // A text of several lines is written on lines of its own.
    let head = "[lorebook.coast]\nname = \"South Coast\"\ndescription = \"\"\"\nOf the south.\nAnd its reefs.\"\"\"\nscan-depth = 6\n";
    assert!(now.contains(head), "{now}");
    assert_eq!((found("south"), found("reefs")), (vec![id], vec![id]));
    // One of the two alone leaves the other.
    lorebooks::describe(db, user, id, None, Some(""), [None; 2]).unwrap();
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.name.as_str(), kept.description.as_str()),
        ("South Coast", "")
    );
    // A description taken away is no line.
    assert!(!file(&scratch, id).contains("description"));
    lorebooks::describe(db, user, id, Some("East"), None, [None; 2]).unwrap();
    assert_eq!(lorebooks::get(db, user, id).unwrap().unwrap().name, "East");
    // The library's name is changed also where the file says that name already.
    scratch
        .db
        .with(|conn| conn.execute("update lorebooks set name = 'Other' where id = ?1", [id]))
        .unwrap();
    let before = file(&scratch, id);
    lorebooks::describe(db, user, id, Some("East"), None, [None; 2]).unwrap();
    assert_eq!(lorebooks::get(db, user, id).unwrap().unwrap().name, "East");
    assert_eq!(file(&scratch, id), before);

    // A lorebook needs a name, of 64 signs at most; a refused name leaves the description too.
    for (name, why) in [
        ("", "a lorebook needs a name"),
        (" \n ", "a lorebook needs a name"),
        (
            &"n".repeat(65),
            "a lorebook's name has at most 64 characters",
        ),
    ] {
        let made = lorebooks::describe(db, user, id, Some(name), Some("Not kept."), [None; 2])
            .unwrap_err();
        assert_eq!(format!("{made:#}"), why);
    }
    assert_eq!(file(&scratch, id), before);
    lorebooks::describe(db, user, id, Some(&"🌊".repeat(64)), None, [None; 2]).unwrap();
    assert_eq!(
        lorebooks::get(db, user, id).unwrap().unwrap().name,
        "🌊".repeat(64)
    );

    // The last entry can go: the lorebook is empty then, and takes a new one.
    for reference in listed(&scratch, id) {
        lorebooks::remove_entry(db, user, id, &reference).unwrap();
    }
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!((kept.entries, kept.entry_names.len()), (0, 0));
    assert_eq!(listed(&scratch, id), [] as [&str; 0]);
    lorebooks::add_entry(
        db,
        user,
        id,
        &only(|change| change.name = Some("Anew".into())),
    )
    .unwrap();
    assert_eq!(listed(&scratch, id), ["lore.coast-anew"]);
}

#[test]
fn of_edits_made_at_once_none_is_lost() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    // Each reads the file before another has written.
    let together = std::sync::Barrier::new(8);
    std::thread::scope(|scope| {
        let edits: Vec<_> = (0..8)
            .map(|n| {
                let together = &together;
                scope.spawn(move || {
                    let new = only(|change| change.name = Some(format!("Entry {n}")));
                    together.wait();
                    lorebooks::add_entry(db, user, id, &new).unwrap();
                })
            })
            .collect();
        for edit in edits {
            edit.join().unwrap();
        }
    });
    let mut names = lorebooks::editable(db, user, id).unwrap().entries;
    names.sort_by(|a, b| a.label.cmp(&b.label));
    let names: Vec<String> = names.into_iter().map(|entry| entry.label).collect();
    let expected: Vec<String> = (0..8)
        .map(|n| format!("Entry {n}"))
        .chain(["The wreck".into(), "lamp".into()])
        .collect();
    assert_eq!(names, expected);
    assert_eq!(lorebooks::get(db, user, id).unwrap().unwrap().entries, 10);
}

async fn delete(server: &common::server::Server, path: &str) -> (u16, Value) {
    server.call(Method::DELETE, path, None).await
}

#[tokio::test]
async fn a_lorebook_is_edited_over_http() {
    let server = start().await;
    let world = json!({ "name": "Reedmere", "description": "Of the mere.", "entries": {
        "0": { "key": ["fog"], "comment": "Fog", "content": "Fog lies on the mere.", "constant": true },
        "1": { "key": ["heron", "bird"], "comment": "The heron", "content": "A heron stands in the reeds." },
    }});
    let (status, imported) = server
        .upload(
            "/api/lorebooks?name=mere.json",
            world.to_string().into_bytes(),
        )
        .await;
    assert_eq!(status, 201, "{imported}");
    let id = imported["lorebook"]["id"].as_i64().unwrap();
    let path = format!("/api/lorebooks/{id}");

    let (status, shown) = server.get(&format!("{path}/edit")).await;
    assert_eq!(status, 200, "{shown}");
    let heron = json!({
        "reference": "lore.reedmere-the-heron", "label": "The heron", "name": "The heron", "trigger": "keyword",
        "keywords": ["heron", "bird"], "content": "A heron stands in the reeds.", "enabled": true,
        "at_depth": false, "depth": 4, "order": 100, "secondary": [], "logic": "and_any", "probability": 100,
        "scan_depth": 0, "case_sensitive": false, "whole_words": false,
    });
    assert_eq!(
        (&shown["id"], &shown["name"], &shown["description"]),
        (&json!(id), &json!("Reedmere"), &json!("Of the mere."))
    );
    assert_eq!(shown["entries"][1], heron);
    assert_eq!(
        (
            &shown["entries"][0]["trigger"],
            shown["entries"].as_array().unwrap().len()
        ),
        (&json!("always"), 2)
    );

    // An entry is changed by its reference, with what is named alone.
    let entry = format!("{path}/entries/lore.reedmere-the-heron");
    let change =
        json!({ "trigger": "vector", "secondary": ["dusk"], "logic": "not_all", "enabled": false });
    let (status, changed) = server.patch(&entry, change).await;
    let mut expected = heron.clone();
    expected["trigger"] = json!("vector");
    expected["secondary"] = json!(["dusk"]);
    expected["logic"] = json!("not_all");
    expected["enabled"] = json!(false);
    assert_eq!((status, &changed), (200, &expected));
    // One refused says why, and one that is no entry is not found.
    let (status, error) = server.patch(&entry, json!({ "probability": 101 })).await;
    assert_eq!(
        (status, &error["error"]),
        (400, &json!("an entry's chance is at most 100 percent"))
    );
    let (status, _) = server
        .patch(
            &format!("{path}/entries/lore.nowhere"),
            json!({ "name": "x" }),
        )
        .await;
    assert_eq!(status, 404);
    let (status, _) = server
        .patch(
            "/api/lorebooks/999/entries/lore.reedmere-the-heron",
            json!({ "name": "x" }),
        )
        .await;
    assert_eq!(status, 404);

    // An entry is added, taken out and put back.
    let (status, added) = server
        .post(
            &format!("{path}/entries"),
            json!({ "name": "Old Pike", "keywords": ["pike"] }),
        )
        .await;
    assert_eq!(
        (status, &added["reference"], &added["order"]),
        (201, &json!("lore.reedmere-old-pike"), &json!(100))
    );
    let (status, error) = server
        .post(&format!("{path}/entries"), json!({ "keywords": ["pike"] }))
        .await;
    assert_eq!(
        (status, &error["error"]),
        (400, &json!("an entry needs a name"))
    );
    let (status, removed) = delete(&server, &entry).await;
    assert_eq!((status, &removed["position"]), (200, &json!(1)));
    assert!(
        removed["toml"]
            .as_str()
            .unwrap()
            .contains("[lore.reedmere-the-heron]")
    );
    let (status, _) = delete(&server, &entry).await;
    assert_eq!(status, 404);
    let (_, shown) = server.get(&format!("{path}/edit")).await;
    let references = |shown: &Value| -> Vec<Value> {
        let entries = shown["entries"].as_array().unwrap().iter();
        entries.map(|entry| entry["reference"].clone()).collect()
    };
    assert_eq!(
        references(&shown),
        [json!("lore.reedmere-fog"), json!("lore.reedmere-old-pike")]
    );
    let (status, back) = server
        .post(&format!("{path}/entries/restore"), removed.clone())
        .await;
    assert_eq!((status, &back), (201, &expected));
    let (status, error) = server
        .post(&format!("{path}/entries/restore"), removed)
        .await;
    assert_eq!(
        (status, &error["error"]),
        (
            400,
            &json!("the lorebook has another entry lore.reedmere-the-heron by now")
        )
    );
    let (_, shown) = server.get(&format!("{path}/edit")).await;
    assert_eq!(
        references(&shown),
        [
            json!("lore.reedmere-fog"),
            json!("lore.reedmere-the-heron"),
            json!("lore.reedmere-old-pike")
        ]
    );

    // The name and the description are changed beside the flags, or without them.
    let (status, changed) = server
        .patch(
            &path,
            json!({ "name": "Reedmere Marsh", "description": "", "favorite": true }),
        )
        .await;
    assert_eq!(
        (
            status,
            &changed["name"],
            &changed["description"],
            &changed["favorite"],
            &changed["entries"]
        ),
        (
            200,
            &json!("Reedmere Marsh"),
            &json!(""),
            &json!(true),
            &json!(3)
        )
    );
    // A name that is refused leaves the flags as they are.
    let (status, error) = server
        .patch(&path, json!({ "name": " ", "favorite": false }))
        .await;
    assert_eq!(
        (status, &error["error"]),
        (400, &json!("a lorebook needs a name"))
    );
    let (_, list) = server.get("/api/lorebooks").await;
    assert_eq!(
        (&list[0]["name"], &list[0]["favorite"]),
        (&json!("Reedmere Marsh"), &json!(true))
    );
    // It is exported as Character Card V3's lorebook (the owner, 2026-10-15), which the library imports again.
    let (headers, file) = server.download(&format!("{path}/export")).await;
    assert_eq!(
        headers["content-disposition"],
        "attachment; filename*=UTF-8''Reedmere%20Marsh.json"
    );
    let exported: serde_json::Value = serde_json::from_slice(&file).unwrap();
    assert_eq!(
        (
            &exported["spec"],
            exported["data"]["entries"].as_array().map(Vec::len)
        ),
        (&json!("lorebook_v3"), Some(3)),
        "{exported}"
    );
    let (status, again) = server
        .upload("/api/lorebooks?name=Reedmere%20Marsh.json", file)
        .await;
    assert_eq!(
        (status, &again["lorebook"]["entries"]),
        (201, &json!(3)),
        "{again}"
    );
    // Its own scan depth and token budget are set in "Lorebook settings", and 0 takes either away.
    let (status, _) = server
        .patch(&path, json!({ "scan_depth": 6, "token_budget": 300 }))
        .await;
    assert_eq!(status, 200);
    let (_, edit) = server.get(&format!("{path}/edit")).await;
    assert_eq!(
        (&edit["scan_depth"], &edit["token_budget"]),
        (&json!(6), &json!(300))
    );
    server.patch(&path, json!({ "token_budget": 0 })).await;
    let (_, edit) = server.get(&format!("{path}/edit")).await;
    assert_eq!(
        (&edit["scan_depth"], &edit["token_budget"]),
        (&json!(6), &Value::Null)
    );

    // In the Trash it has no editor.
    let (status, _) = server.patch(&path, json!({ "trashed": true })).await;
    assert_eq!(status, 200);
    let (status, error) = server.get(&format!("{path}/edit")).await;
    assert_eq!(
        (status, &error["error"]),
        (
            400,
            &json!("the lorebook “Reedmere Marsh” is in the Trash; restore it first")
        )
    );
    let (status, _) = server.get("/api/lorebooks/999/edit").await;
    assert_eq!(status, 404);
}

#[tokio::test]
async fn every_page_of_the_user_is_told_of_a_lorebooks_change() {
    let server = start().await;
    let mut socket = server.listen().await;
    let told = |id: i64| json!({ "type": "lorebook", "id": id });
    let world = |name: &str| {
        json!({ "name": name, "entries": { "0": { "key": ["fog"], "comment": "Fog", "content": "Fog lies on the mere." } } })
            .to_string()
            .into_bytes()
    };

    // A lorebook imported is told by its number; asking for it is not a change.
    let (status, imported) = server
        .upload("/api/lorebooks?name=mere.json", world("Reedmere"))
        .await;
    assert_eq!(status, 201, "{imported}");
    let id = imported["lorebook"]["id"].as_i64().unwrap();
    assert_eq!(event(&mut socket).await, told(id));
    let (_, other) = server
        .upload("/api/lorebooks?name=fen.json", world("Fen"))
        .await;
    let other = other["lorebook"]["id"].as_i64().unwrap();
    assert_eq!(event(&mut socket).await, told(other));
    let path = format!("/api/lorebooks/{id}");
    assert_eq!(server.get(&format!("{path}/edit")).await.0, 200);

    // Its name, its description and a flag. A change that is refused tells nothing: the next told is another's.
    let renamed = server
        .patch(&path, json!({ "name": "Mere", "description": "Wet." }))
        .await;
    assert_eq!(renamed.0, 200, "{}", renamed.1);
    assert_eq!(event(&mut socket).await, told(id));
    assert_eq!(server.patch(&path, json!({ "name": " " })).await.0, 400);
    let starred = server
        .patch(
            &format!("/api/lorebooks/{other}"),
            json!({ "favorite": true }),
        )
        .await;
    assert_eq!(starred.0, 200);
    assert_eq!(event(&mut socket).await, told(other));

    // An entry added, changed, switched off, taken out and put back.
    let (status, added) = server
        .post(
            &format!("{path}/entries"),
            json!({ "name": "Old Pike", "keywords": ["pike"] }),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    assert_eq!(event(&mut socket).await, told(id));
    let entry = format!("{path}/entries/{}", added["reference"].as_str().unwrap());
    for change in [json!({ "content": "A pike." }), json!({ "enabled": false })] {
        assert_eq!(server.patch(&entry, change).await.0, 200);
        assert_eq!(event(&mut socket).await, told(id));
    }
    assert_eq!(
        server
            .patch(
                &format!("{path}/entries/lore.nowhere"),
                json!({ "content": "No." })
            )
            .await
            .0,
        404
    );
    let (status, removed) = delete(&server, &entry).await;
    assert_eq!(status, 200, "{removed}");
    assert_eq!(event(&mut socket).await, told(id));
    let restored = server
        .post(&format!("{path}/entries/restore"), removed)
        .await;
    assert_eq!(restored.0, 201, "{}", restored.1);
    assert_eq!(event(&mut socket).await, told(id));

    // Into the Trash, and deleted for good: the Trash is told too.
    let trash = json!({ "type": "trash" });
    assert_eq!(server.patch(&path, json!({ "trashed": true })).await.0, 200);
    assert_eq!(event(&mut socket).await, told(id));
    assert_eq!(event(&mut socket).await, trash);
    assert_eq!(delete(&server, &path).await.0, 204);
    assert_eq!(event(&mut socket).await, told(id));
    assert_eq!(event(&mut socket).await, trash);

    // A lorebook a card brings, copied into the library; the card is told of its import and of the copy.
    let (_, card) = server.upload_whole(common::card_file()).await;
    let card = card["card_id"].as_i64().unwrap();
    let card_told = json!({ "type": "card", "id": card });
    assert_eq!(event(&mut socket).await, card_told);
    let (status, copy) = server
        .post(
            &format!("/api/cards/{card}/lorebooks/copy"),
            json!({ "reference": "lorebook.coast", "copy": "copy" }),
        )
        .await;
    assert_eq!(status, 201, "{copy}");
    assert_eq!(event(&mut socket).await, told(copy["id"].as_i64().unwrap()));
    assert_eq!(event(&mut socket).await, card_told);
}

#[tokio::test]
async fn a_lorebook_is_made_from_scratch_empty_and_is_filled_in_its_editor() {
    let server = start().await;
    let mut socket = server.listen().await;

    // Its name on one line, its description as it is; it has no entries, and the user's pages are told.
    let (status, made) = server
        .post(
            "/api/lorebooks/new",
            json!({ "name": "  Reed\nmere ", "description": "Of the mere.\nAnd its \"reeds\"." }),
        )
        .await;
    assert_eq!(status, 201, "{made}");
    let id = made["id"].as_i64().unwrap();
    assert_eq!(
        (&made["name"], &made["description"], &made["entries"]),
        (
            &json!("Reed mere"),
            &json!("Of the mere.\nAnd its \"reeds\"."),
            &json!(0)
        )
    );
    assert_eq!(
        event(&mut socket).await,
        json!({ "type": "lorebook", "id": id })
    );

    // The editor shows it empty, and an entry is added to it as to any other.
    let path = format!("/api/lorebooks/{id}");
    let (status, shown) = server.get(&format!("{path}/edit")).await;
    assert_eq!(status, 200, "{shown}");
    assert_eq!(
        (&shown["name"], &shown["entries"]),
        (&json!("Reed mere"), &json!([]))
    );
    let (status, added) = server
        .post(
            &format!("{path}/entries"),
            json!({ "name": "Heron", "keywords": ["heron"], "content": "A heron." }),
        )
        .await;
    assert_eq!(status, 201, "{added}");
    let (_, list) = server.get("/api/lorebooks").await;
    assert_eq!(
        (
            &list[0]["name"],
            &list[0]["entries"],
            &list[0]["entry_names"]
        ),
        (&json!("Reed mere"), &json!(1), &json!(["Heron"]))
    );

    // Without a description, and of a name another has, it is made too.
    let (status, again) = server
        .post("/api/lorebooks/new", json!({ "name": "Reed mere" }))
        .await;
    assert_eq!(
        (status, &again["description"]),
        (201, &json!("")),
        "{again}"
    );
    assert_ne!(again["id"], made["id"]);

    // A name that says nothing, or is too long, is refused, and nothing is made.
    for (name, why) in [
        (" \n ".to_string(), "a lorebook needs a name"),
        (
            "x".repeat(65),
            "a lorebook's name has at most 64 characters",
        ),
    ] {
        let (status, error) = server
            .post("/api/lorebooks/new", json!({ "name": name }))
            .await;
        assert_eq!((status, &error["error"]), (400, &json!(why)));
    }
    assert_eq!(
        server
            .get("/api/lorebooks")
            .await
            .1
            .as_array()
            .unwrap()
            .len(),
        2
    );
}

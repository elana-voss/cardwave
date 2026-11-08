//! A folder of cards imported: a card the library has is known by its file's fingerprint and skipped, two
//! cards of one name are both kept, and the folder's import goes on in the background; the folder of cards
//! in the settings is watched while "Import new cards automatically" is on, and a file imported goes to the
//! Recycle Bin where the settings say so; a file it took is not taken again after a restart while unchanged,
//! though its card has gone to the Trash. Which files a look takes is `cards/watch.rs`'s own tests.

mod common;

use std::time::Instant;

use common::Folder;
use common::server::{Server, WAIT, event, start};
use serde_json::{Value, json};

/// Imports `folder` and waits for the import to end: what it came to.
async fn import(server: &Server, folder: &Folder) -> Value {
    let (status, begun) = server
        .post(
            "/api/card-folder/import",
            json!({ "folder": folder.path() }),
        )
        .await;
    assert_eq!(status, 202, "{begun}");
    // Answered before the folder is walked, which in a large folder takes long.
    assert_eq!(
        (begun["running"].clone(), begun["found"].clone()),
        (json!(true), json!(0))
    );
    let since = Instant::now();
    loop {
        let (_, going) = server.get("/api/card-folder/import").await;
        if going["running"] == false {
            return going;
        }
        assert!(since.elapsed() < WAIT, "the import did not end: {going}");
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
}

/// The sample card under the title `title`, otherwise of one name, as a file no other is.
fn card(title: &str) -> Vec<u8> {
    let mut container = common::container();
    container.toml[0].1 = common::unique(&container.toml[0].1.replace(
        "title = \"Mira of the North Light\"",
        &format!("title = {}", json!(title)),
    ));
    cw_ccv4::png::write(&container).unwrap()
}

#[tokio::test]
async fn a_folder_is_imported_in_the_background_and_what_the_library_has_is_skipped() {
    let server = start().await;
    let folder = Folder::new("cards-import");
    let write = |name: &str, file: &[u8]| {
        let path = folder.0.join(name);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, file).unwrap();
    };
    // Two cards of one name, one in a subfolder, a copy of the first file, a picture that is no card, and a
    // file that is no picture.
    let (first, second) = (card("Mira"), card("Mira"));
    write("mira.png", &first);
    write("more/Mira.PNG", &second);
    write("more/mira again.png", &first);
    write("plain.png", &[137, 80, 78, 71, 13, 10, 26, 10]);
    write("notes.txt", b"not a card");
    // A card imported before and edited since is still known by the file it came from.
    let edited = card("Edited");
    write("edited.png", &edited);
    let (id, _) = server.add_card(edited, false).await;
    let (status, _) = server
        .edit_card(&json!(id), |form| {
            form["characters"][0]["scenario"][0]["text"] = json!("A new scenario.");
        })
        .await;
    assert_eq!(status, 200);

    let mut socket = server.listen().await;
    let ended = import(&server, &folder).await;
    // The picture that is no card is passed over silently: neither counted nor failed.
    assert_eq!(ended["found"], 4, "{ended}");
    assert_eq!(ended["imported"], 2, "{ended}");
    assert_eq!(ended["skipped"], 2, "{ended}");
    assert_eq!(ended["failed"], json!([]), "{ended}");
    assert_eq!(event(&mut socket).await["type"], "card_folder");
    let (_, listed) = server.get("/api/cards?sort=name").await;
    let titles: Vec<&str> = listed
        .as_array()
        .unwrap()
        .iter()
        .map(|card| card["title"].as_str().unwrap())
        .collect();
    assert_eq!(titles, ["Edited", "Mira", "Mira"], "{listed}");

    // Imported again, the folder brings nothing new.
    let again = import(&server, &folder).await;
    assert_eq!(
        (again["imported"].clone(), again["skipped"].clone()),
        (json!(0), json!(4))
    );
}

#[tokio::test]
async fn a_folder_that_is_not_there_is_refused() {
    let server = start().await;
    let (status, refused) = server
        .post(
            "/api/card-folder/import",
            json!({ "folder": "C:/no/such/folder/here" }),
        )
        .await;
    assert_eq!(status, 400, "{refused}");
    assert_eq!(server.get("/api/card-folder/import").await.1, Value::Null);
}

/// The titles of the library's cards, by name.
async fn titles(server: &Server) -> Vec<String> {
    let (_, listed) = server.get("/api/cards?sort=name").await;
    let titles = listed.as_array().unwrap().iter();
    titles
        .map(|card| card["title"].as_str().unwrap().to_string())
        .collect()
}

/// Waits until the library holds `wanted`.
async fn until_titles(server: &Server, wanted: &[&str]) {
    let since = Instant::now();
    while titles(server).await != wanted {
        assert!(
            since.elapsed() < WAIT,
            "the library holds {:?}",
            titles(server).await
        );
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
}

#[tokio::test]
async fn a_card_put_in_the_watched_folder_is_imported_while_the_switch_is_on() {
    let server = start().await;
    let folder = Folder::new("cards-watched");
    let (_, settings) = server.get("/api/settings").await;
    assert_eq!(
        settings["card_folder"],
        json!({ "folder": null, "watch": true, "recycle": false })
    );
    let chosen = json!({ "card_folder": { "folder": folder.path() } });
    let (status, changed) = server.patch("/api/settings", chosen).await;
    assert_eq!(status, 200, "{changed}");

    let mut socket = server.listen().await;
    std::fs::create_dir_all(folder.0.join("new")).unwrap();
    std::fs::write(folder.0.join("new/mira.png"), card("Mira")).unwrap();
    until_titles(&server, &["Mira"]).await;
    assert_eq!(event(&mut socket).await["type"], "card_folder");
    // Not counted as an import of the folder; kept where the switch for the Recycle Bin is off.
    assert_eq!(server.get("/api/card-folder/import").await.1, Value::Null);
    assert!(folder.0.join("new/mira.png").exists());

    let off = json!({ "card_folder": { "watch": false } });
    assert_eq!(server.patch("/api/settings", off).await.0, 200);
    std::fs::write(folder.0.join("later.png"), card("Later")).unwrap();
    tokio::time::sleep(std::time::Duration::from_millis(400)).await;
    assert_eq!(titles(&server).await, ["Mira"]);
    let on = json!({ "card_folder": { "watch": true } });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);
    until_titles(&server, &["Later", "Mira"]).await;
}

#[tokio::test]
async fn a_folder_of_cards_that_is_not_there_is_refused() {
    let server = start().await;
    let missing = json!({ "card_folder": { "folder": "C:/no/such/folder/here" } });
    let (status, refused) = server.patch("/api/settings", missing).await;
    assert_eq!(status, 400, "{refused}");
    let root = json!({ "card_folder": { "folder": "C:/" } });
    let (status, refused) = server.patch("/api/settings", root).await;
    assert_eq!(status, 400, "{refused}");
}

#[cfg(windows)]
#[tokio::test]
async fn an_imported_file_goes_to_the_recycle_bin_where_the_switch_is_on() {
    let server = start().await;
    let folder = Folder::new("cards-recycled");
    let recycle = json!({ "card_folder": { "recycle": true, "watch": false } });
    assert_eq!(server.patch("/api/settings", recycle).await.0, 200);
    let (file, plain) = (
        folder.0.join("cardwave test card.png"),
        folder.0.join("plain.png"),
    );
    std::fs::write(&file, card("Recycled")).unwrap();
    std::fs::write(&plain, [137, 80, 78, 71, 13, 10, 26, 10]).unwrap();
    let ended = import(&server, &folder).await;
    assert_eq!(ended["imported"], 1, "{ended}");
    assert!(!file.exists());
    // A file not imported stays.
    assert!(plain.exists());
}

#[tokio::test]
async fn first_run_offers_the_folder_chosen_else_the_documents_folder() {
    let server = start().await;
    // No Documents folder: nothing offered.
    assert_eq!(server.get("/api/card-folder/offered").await.1, Value::Null);
    let documents = server.dir.join("Documents");
    std::fs::create_dir_all(&documents).unwrap();
    let (status, offered) = server.get("/api/card-folder/offered").await;
    assert_eq!(status, 200, "{offered}");
    assert_eq!(offered, json!(documents.display().to_string()));

    let folder = Folder::new("cards-offered");
    let chosen = json!({ "card_folder": { "folder": folder.path(), "watch": false } });
    assert_eq!(server.patch("/api/settings", chosen).await.0, 200);
    assert_eq!(
        server.get("/api/card-folder/offered").await.1,
        json!(folder.path())
    );
    // The folder chosen is gone (a drive unplugged): Documents is offered again.
    drop(folder);
    assert_eq!(
        server.get("/api/card-folder/offered").await.1,
        json!(documents.display().to_string())
    );
}

/// A SillyTavern card as JSON, of the name `name`, `version` 2 or 3, or the oldest bare fields for 1.
fn json_card(name: &str, version: u8) -> String {
    let data =
        json!({ "name": name, "description": "A card in a JSON file.", "first_mes": "Hello." });
    match version {
        1 => data.to_string(),
        _ => json!({ "spec": format!("chara_card_v{version}"), "spec_version": format!("{version}.0"), "data": data })
            .to_string(),
    }
}

#[tokio::test]
async fn json_cards_are_imported_and_other_files_passed_over_silently() {
    let server = start().await;
    let folder = Folder::new("cards-json");
    let write = |name: &str, file: &[u8]| std::fs::write(folder.0.join(name), file).unwrap();
    write("two.json", json_card("Two", 2).as_bytes());
    // With a byte order mark, as some editors write it.
    write(
        "three.JSON",
        &[b"\xEF\xBB\xBF".as_slice(), json_card("Three", 3).as_bytes()].concat(),
    );
    write("one.json", json_card("One", 1).as_bytes());
    // Neither counted nor failed: JSON that is no card, no JSON at all, and a picture without card data.
    write("settings.json", br#"{ "theme": "dark", "spec": "other" }"#);
    write("broken.json", b"{ not json");
    write("list.json", b"[1, 2]");
    write("picture.png", &common::picture());
    write(
        "text.png",
        &common::png_with(vec![common::text_chunk("Comment", b"made by hand")]),
    );

    let ended = import(&server, &folder).await;
    assert_eq!(ended["found"], 3, "{ended}");
    assert_eq!(ended["imported"], 3, "{ended}");
    assert_eq!(ended["failed"], json!([]), "{ended}");
    assert_eq!(titles(&server).await, ["One", "Three", "Two"]);
    let (_, listed) = server.get("/api/cards?sort=name").await;
    let id = listed[0]["id"].clone();
    let (status, card) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(status, 200, "{card}");
}

#[tokio::test]
async fn a_file_found_to_hold_no_card_is_not_read_again_while_unchanged() {
    let server = start().await;
    let folder = Folder::new("cards-not-cards");
    let path = folder.0.join("notes.json");
    let not_card = format!("{:<120}", r#"{ "notes": "no card here" }"#);
    std::fs::write(&path, &not_card).unwrap();
    let ended = import(&server, &folder).await;
    assert_eq!(
        (ended["found"].clone(), ended["failed"].clone()),
        (json!(0), json!([])),
        "{ended}"
    );

    // A card of the same size written over it, and its time written put back: the list says it holds no
    // card, so it is not read.
    let written = std::fs::metadata(&path).unwrap().modified().unwrap();
    let card = json_card("Kept", 1);
    let card = format!("{card:<width$}", width = not_card.len());
    assert_eq!(card.len(), not_card.len());
    std::fs::write(&path, &card).unwrap();
    let file = std::fs::File::options().write(true).open(&path).unwrap();
    file.set_modified(written).unwrap();
    drop(file);
    let again = import(&server, &folder).await;
    assert_eq!(again["imported"], 0, "{again}");
    assert_eq!(titles(&server).await, Vec::<String>::new());

    // Written anew, it is read.
    let file = std::fs::File::options().write(true).open(&path).unwrap();
    file.set_modified(written + std::time::Duration::from_secs(5))
        .unwrap();
    drop(file);
    let changed = import(&server, &folder).await;
    assert_eq!(changed["imported"], 1, "{changed}");
    assert_eq!(titles(&server).await, ["Kept"]);
}

#[tokio::test]
async fn a_file_the_watch_took_is_not_taken_again_after_a_restart_while_unchanged() {
    let server = start().await;
    let folder = Folder::new("cards-watched-again");
    let chosen = json!({ "card_folder": { "folder": folder.path() } });
    assert_eq!(server.patch("/api/settings", chosen).await.0, 200);
    std::fs::write(folder.0.join("mira.png"), card("Mira")).unwrap();
    until_titles(&server, &["Mira"]).await;
    // Put in the Trash, the card is not taken from its file again: the file's stamp is kept, so it is not
    // read, as within one run.
    let (_, listed) = server.get("/api/cards").await;
    let id = listed[0]["id"].clone();
    let trashed = json!({ "trashed": true });
    assert_eq!(
        server.patch(&format!("/api/cards/{id}"), trashed).await.0,
        200
    );
    let server = server.restart().await;
    std::fs::write(folder.0.join("later.png"), card("Later")).unwrap();
    until_titles(&server, &["Later"]).await;
    tokio::time::sleep(std::time::Duration::from_millis(400)).await;
    assert_eq!(titles(&server).await, ["Later"]);
}

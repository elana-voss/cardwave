//! One editor for a lorebook of the library and a card's own (`lorebooks::Book`):
//! an entry's words keep their versions in both, a card's own is edited as a
//! new version of the card, the library lists the cards' own, and a card's own
//! is copied or moved into the library and moved back (with the history it
//! gathered there, and not once it is used elsewhere). The AI tools for a
//! whole lorebook (`POST /api/rewrite/lore`) ask the background model entry by
//! entry. An edit of a card that another saved meanwhile is made again. The
//! list reads only the cards that bring a lorebook.

mod common;

use common::Scratch;
use common::api::{Api, JSON, says};
use common::server::{event, start};
use cw_ccv4::edit::Edited;
use cw_ccv4::lore::{self, EntryChange, RemovedEntry};
use cw_ccv4::png::{self, Container};
use cw_library::cards::{self, Show};
use cw_library::lorebooks::{self, Book, CardLoreSource};
use serde_json::json;

/// A card of one character that brings the lorebook `harbour` with two entries.
const HARBOUR: &str = r#"
spec = "ccv4:1.0.0"

[meta-info]
title = "The Harbour Master"

[lore.lamp]
name = "The lamp"
keywords = ["lamp"]
text = "The lamp turns every ten seconds."

[lore.reef]
keywords = []
text = "The reef lies north."

[lorebook.harbour]
name = "Harbour"
entries = ["lore.lamp", "lore.reef"]

[character.mira]
lorebooks = ["lorebook.harbour"]
prompt = ["LOREBOOK", "CHAT-HISTORY"]
"#;

fn harbour(scratch: &Scratch) -> i64 {
    let toml = vec![("card/0001_card.toml".to_string(), common::unique(HARBOUR))];
    let file = png::write(&Container {
        image: common::picture(),
        toml,
        assets: vec![],
    })
    .unwrap();
    common::import_whole(&scratch.db, scratch.user, &file)
        .unwrap()
        .card_id
}

fn own(card_id: i64) -> Book {
    Book::Card {
        card_id,
        book: None,
    }
}

fn words(text: &str) -> EntryChange {
    EntryChange {
        content: Some(text.to_string()),
        ..Default::default()
    }
}

/// The versions of an entry's words, the newest first: what made each, and the words.
fn versions(scratch: &Scratch, book: Book, reference: &str) -> Vec<(String, String)> {
    let listed = lorebooks::entry_drafts(&scratch.db, scratch.user, book, reference).unwrap();
    listed
        .drafts
        .into_iter()
        .map(|one| (one.made, one.text))
        .collect()
}

#[test]
fn a_cards_own_lorebook_is_edited_as_a_new_version_of_the_card_with_its_words_versions() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    let shown = lorebooks::editable(db, me, own(card)).unwrap();
    assert_eq!(shown.name, "Harbour");
    assert_eq!(shown.id, card);
    let of = shown.card.unwrap();
    assert_eq!(
        (of.title.as_str(), of.reference.as_str(), of.first),
        ("The Harbour Master", "lorebook.harbour", true)
    );
    assert_eq!(shown.entries.len(), 2);

    let before = cards::get(db, me, card).unwrap().unwrap().version;
    lorebooks::change_entry_as(
        db,
        me,
        own(card),
        "lore.lamp",
        &words("The lamp turns every twelve seconds."),
        "fix",
    )
    .unwrap();
    assert_eq!(
        cards::get(db, me, card).unwrap().unwrap().version,
        before + 1
    );
    assert_eq!(
        versions(&scratch, own(card), "lore.lamp"),
        [
            (
                "fix".to_string(),
                "The lamp turns every twelve seconds.".to_string()
            ),
            (
                "imported".to_string(),
                "The lamp turns every ten seconds.".to_string()
            ),
        ]
    );
    // The card's own page lists the same history for the block.
    let page = cards::drafts(db, me, card, "lore.lamp").unwrap();
    assert_eq!(page.drafts.len(), 2);

    // Added, taken out and put back, and called otherwise, all in the card.
    let added = lorebooks::add_entry(
        db,
        me,
        own(card),
        &EntryChange {
            name: Some("Gulls".into()),
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(added.reference, "lore.harbour-gulls");
    let removed: RemovedEntry = lorebooks::remove_entry(db, me, own(card), "lore.reef").unwrap();
    let names = |scratch: &Scratch| {
        let shown = lorebooks::editable(&scratch.db, scratch.user, own(card)).unwrap();
        shown
            .entries
            .into_iter()
            .map(|entry| entry.label)
            .collect::<Vec<_>>()
    };
    assert_eq!(names(&scratch), ["The lamp", "Gulls"]);
    lorebooks::restore_entry(db, me, own(card), &removed).unwrap();
    assert_eq!(names(&scratch), ["The lamp", "reef", "Gulls"]);
    lorebooks::describe(
        db,
        me,
        own(card),
        Some("North Harbour"),
        Some("Of the harbour."),
        [Some(3), None],
    )
    .unwrap();
    let shown = lorebooks::editable(db, me, own(card)).unwrap();
    assert_eq!(
        (
            shown.name.as_str(),
            shown.description.as_str(),
            shown.scan_depth
        ),
        ("North Harbour", "Of the harbour.", Some(3))
    );
    // A version is made only by what makes one.
    let refused = lorebooks::change_entry_as(db, me, own(card), "lore.lamp", &words("x"), "magic")
        .unwrap_err();
    assert!(refused.to_string().contains("magic"), "{refused}");
}

#[test]
fn a_library_lorebooks_entry_keeps_the_versions_of_its_words() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = lorebooks::create(db, me, "Coast", "").unwrap();
    let entry = lorebooks::add_entry(
        db,
        me,
        made.id,
        &EntryChange {
            name: Some("Lamp".into()),
            content: Some("It turns.".into()),
            ..Default::default()
        },
    )
    .unwrap();
    lorebooks::change_entry(
        db,
        me,
        made.id,
        &entry.reference,
        &words("It turns slowly."),
    )
    .unwrap();
    lorebooks::change_entry_as(
        db,
        me,
        made.id,
        &entry.reference,
        &words("It turns."),
        "restored",
    )
    .unwrap();
    let made_by: Vec<String> = versions(&scratch, Book::Library(made.id), &entry.reference)
        .into_iter()
        .map(|(made, _)| made)
        .collect();
    assert_eq!(made_by, ["restored", "edited", "edited"]);
    // The history does not change what the lorebook is: its export and the editor read as before.
    let shown = lorebooks::editable(db, me, made.id).unwrap();
    assert_eq!(shown.entries[0].content, "It turns.");
    let exported = String::from_utf8(lorebooks::export(db, me, made.id).unwrap().data).unwrap();
    assert!(
        !exported.contains("revision") && exported.contains("It turns."),
        "{exported}"
    );
}

#[test]
fn the_library_lists_the_cards_own_lorebooks_and_a_copy_is_told_from_its_namesake() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    let listed = lorebooks::find(db, me, "", Show::All).unwrap();
    assert_eq!(listed.len(), 1);
    let row = &listed[0];
    assert_eq!(
        (row.name.as_str(), row.entries, row.id),
        ("Harbour", 2, card)
    );
    assert_eq!(row.card.as_ref().unwrap().title, "The Harbour Master");
    assert!(
        lorebooks::find(db, me, "", Show::Favorites)
            .unwrap()
            .is_empty()
    );
    cards::set_archived(db, me, card, true).unwrap();
    assert!(lorebooks::find(db, me, "", Show::All).unwrap().is_empty());
    assert_eq!(
        lorebooks::find(db, me, "", Show::Archived).unwrap().len(),
        1
    );
    cards::set_archived(db, me, card, false).unwrap();

    let first = lorebooks::copy_from_card(
        db,
        me,
        card,
        "lorebook.harbour",
        lorebooks::Words { copy: "copy" },
    )
    .unwrap();
    let second = lorebooks::copy_from_card(
        db,
        me,
        card,
        "lorebook.harbour",
        lorebooks::Words { copy: "Kopie" },
    )
    .unwrap();
    assert_eq!(
        (first.name.as_str(), second.name.as_str()),
        ("Harbour", "Harbour (Kopie)")
    );
    // A copy where one is already: the next number, as a preset's copy.
    let third = lorebooks::copy_from_card(
        db,
        me,
        card,
        "lorebook.harbour",
        lorebooks::Words { copy: "Kopie" },
    )
    .unwrap();
    assert_eq!(third.name, "Harbour (Kopie 2)");
}

#[test]
fn the_lorebooks_list_reads_only_the_cards_that_bring_a_lorebook() {
    // A big library listed its lorebooks in half a second by reading every
    // card; a card without one is now not read, so one that cannot be read
    // does not keep the list from showing.
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    let plain = HARBOUR.replace(
        "lorebooks = [\"lorebook.harbour\"]
",
        "",
    );
    let toml = vec![("card/0001_card.toml".to_string(), common::unique(&plain))];
    let file = png::write(&Container {
        image: common::picture(),
        toml,
        assets: vec![],
    })
    .unwrap();
    let other = common::import_whole(db, me, &file).unwrap();
    db.with(|conn| {
        conn.execute(
            "update card_files set toml = 'not [toml' where version_id = ?1 and toml is not null",
            [other.version_id],
        )
    })
    .unwrap();
    let listed = lorebooks::find(db, me, "", Show::All).unwrap();
    assert_eq!(listed.iter().map(|row| row.id).collect::<Vec<_>>(), [card]);
}

#[test]
fn a_cards_own_lorebook_moves_into_the_library_with_its_history_and_back() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    lorebooks::change_entry(db, me, own(card), "lore.lamp", &words("It turns.")).unwrap();
    let moved = lorebooks::move_to_library(db, me, card, "lorebook.harbour").unwrap();
    assert_eq!(
        (moved.name.as_str(), moved.entries, moved.card.is_none()),
        ("Harbour", 2, true)
    );
    // The card brings it no longer, and has it from the library.
    let had = lorebooks::of_card(db, me, card).unwrap();
    assert_eq!(had.len(), 1);
    assert_eq!(had[0].source, CardLoreSource::LorebookId(moved.id));
    assert!(lorebooks::editable(db, me, own(card)).is_err());
    // The entry's history came along.
    let made_by: Vec<String> = versions(&scratch, Book::Library(moved.id), "lore.lamp")
        .into_iter()
        .map(|(made, _)| made)
        .collect();
    assert_eq!(made_by, ["edited", "imported"]);
    // It is edited in the library, and its history grows there.
    lorebooks::change_entry(db, me, moved.id, "lore.lamp", &words("It turns fast.")).unwrap();
    assert_eq!(
        versions(&scratch, Book::Library(moved.id), "lore.lamp").len(),
        3
    );

    lorebooks::move_back(db, me, card, moved.id).unwrap();
    // Back in the card, with the history it gathered in the library, and no version twice.
    let back: Vec<(String, String)> = versions(&scratch, own(card), "lore.lamp");
    let back: Vec<&str> = back.iter().map(|(_, text)| text.as_str()).collect();
    assert_eq!(
        back,
        [
            "It turns fast.",
            "It turns.",
            "The lamp turns every ten seconds."
        ]
    );
    let shown = lorebooks::editable(db, me, own(card)).unwrap();
    let lamp = shown
        .entries
        .iter()
        .find(|entry| entry.reference == "lore.lamp")
        .unwrap();
    assert_eq!(lamp.content, "It turns fast.");
    let had = lorebooks::of_card(db, me, card).unwrap();
    assert_eq!(had.len(), 1);
    assert_eq!(
        had[0].source,
        CardLoreSource::Reference("lorebook.harbour".into())
    );
    assert!(lorebooks::get(db, me, moved.id).unwrap().is_none());
}

#[test]
fn a_moved_lorebook_used_elsewhere_by_now_stays_in_the_library() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    let other = harbour(&scratch);
    let moved = lorebooks::move_to_library(db, me, card, "lorebook.harbour").unwrap();
    lorebooks::attach(db, me, other, moved.id).unwrap();
    let refused = lorebooks::move_back(db, me, card, moved.id).unwrap_err();
    assert!(refused.to_string().contains("used elsewhere"), "{refused}");
    assert!(lorebooks::get(db, me, moved.id).unwrap().is_some());
    assert!(lorebooks::editable(db, me, own(card)).is_err());
}

#[test]
fn a_card_edit_that_another_saved_meanwhile_is_made_again_of_the_card_as_it_then_is() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = harbour(&scratch);
    let tries = std::cell::Cell::new(0);
    lorebooks::change_entry(db, me, own(card), "lore.reef", &words("Reef one.")).unwrap();
    let before = cards::get(db, me, card).unwrap().unwrap().version;
    cards::change_with(db, me, card, "edited", |files| {
        tries.set(tries.get() + 1);
        if tries.get() == 1 {
            // Another edit is saved while this one is made.
            lorebooks::change_entry(db, me, own(card), "lore.reef", &words("Reef two.")).unwrap();
        }
        let (rewritten, _) = lore::change(files, "lorebook.harbour", "lore.lamp", &words("Lamp."))?;
        let rewritten = rewritten.expect("the words differ");
        Ok((
            Some(Edited {
                files: rewritten.files,
                document: rewritten.document,
            }),
            (),
        ))
    })
    .unwrap();
    assert_eq!(tries.get(), 2);
    let shown = lorebooks::editable(db, me, own(card)).unwrap();
    let texts: Vec<&str> = shown
        .entries
        .iter()
        .map(|entry| entry.content.as_str())
        .collect();
    assert_eq!(texts, ["Lamp.", "Reef two."]);
    assert_eq!(
        cards::get(db, me, card).unwrap().unwrap().version,
        before + 2
    );
}

/// A change of a card's own lorebook is told as one of the card (`PageEvent::Card`).
#[tokio::test]
async fn a_cards_own_lorebook_has_no_flags_to_change() {
    let server = start().await;
    let toml = vec![("card/0001_card.toml".to_string(), common::unique(HARBOUR))];
    let file = png::write(&Container {
        image: common::picture(),
        toml,
        assets: vec![],
    })
    .unwrap();
    let (status, made) = server.upload_whole(file).await;
    assert_eq!(status, 201, "{made}");
    let path = format!("/api/cards/{}/lorebook", made["card_id"]);
    let mut socket = server.listen().await;
    let (status, said) = server.patch(&path, json!({ "favorite": true })).await;
    assert_eq!(status, 400, "{said}");
    let (status, _) = server.patch(&path, json!({ "name": "North" })).await;
    assert_eq!(status, 204);
    let told = json!({ "type": "card", "id": made["card_id"] });
    assert_eq!(event(&mut socket).await, told);
}

#[tokio::test]
async fn the_lorebooks_ai_tools_ask_the_background_model_entry_by_entry() {
    let api = Api::start(says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": "lamp, \"light\", beam." } }] }).to_string(),
    ))
    .await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "big-1", "worker_model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let entries = json!([
        { "reference": "lore.lamp", "text": "The lamp turns.", "keywords": [], "secondary_keywords": [] },
        { "reference": "lore.empty", "text": "", "keywords": [], "secondary_keywords": [] },
        { "reference": "lore.named", "text": "The bell.", "keywords": ["bell"], "secondary_keywords": [] },
    ]);
    let (status, answer) = server
        .post(
            "/api/rewrite/lore",
            json!({ "tool": "keywords", "entries": entries }),
        )
        .await;
    assert_eq!(status, 200, "{answer}");
    assert_eq!(answer[0]["keywords"], json!(["lamp", "light", "beam"]));
    // An entry without words is asked nothing, nor one that has keywords.
    assert_eq!(answer[1]["keywords"], json!([]));
    assert_eq!(answer[2]["keywords"], json!(["bell"]));
    assert_eq!(api.asked().len(), 1);
    let (status, _) = server
        .post(
            "/api/rewrite/lore",
            json!({ "tool": "translate", "entries": entries }),
        )
        .await;
    assert_eq!(status, 400);
}

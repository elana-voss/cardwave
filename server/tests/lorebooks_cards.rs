//! Lorebooks and cards: those a card brings and those of the library attached
//! to it, copied out of a card, left out by its chats; and over HTTP.

mod common;

use std::time::Duration;

use common::Scratch;
use common::lore::*;
use common::server::{Server, start};
use cw_accounts::users;
use cw_ccv4::png::{self, Container};
use cw_chat::chats::{self, LoreSource, NewChat};
use cw_core::NotFound;
use cw_library::cards::{self, Imported, Show};
use cw_library::lorebooks::{self, CardLoreSource, CardLorebook, Lorebook};
use cw_library::trash;
use reqwest::Method;
use serde_json::{Value, json};

/// A chat with one character of a card that is there already.
fn chat_of(scratch: &Scratch, card: &Imported, character: &str) -> i64 {
    let new = NewChat {
        characters: &[(card.version_id, character)],
        persona_id: None,
        greeting: 0,
    };
    chats::create(&scratch.db, scratch.user, &new).unwrap()
}

/// The chat's lorebooks as (name, whether the chat took it along itself).
fn had(scratch: &Scratch, chat_id: i64) -> Vec<(String, bool)> {
    chats::lorebooks(&scratch.db, scratch.user, chat_id)
        .unwrap()
        .into_iter()
        .map(|book| (book.name, book.taken))
        .collect()
}

/// A lorebook as a card's page lists it: one the card brings, and one of the library attached to it.
fn brought(reference: &str, name: &str, entries: u32) -> CardLorebook {
    CardLorebook {
        source: CardLoreSource::Reference(reference.into()),
        name: name.into(),
        entries,
        trashed: false,
    }
}

fn attached(id: i64, name: &str, entries: u32) -> CardLorebook {
    CardLorebook {
        source: CardLoreSource::LorebookId(id),
        name: name.into(),
        entries,
        trashed: false,
    }
}

/// The page's word for a copy.
const WORDS: lorebooks::Words = lorebooks::Words { copy: "copy" };

const PAUSE: Duration = Duration::from_millis(5);

/// A card of three characters. `una` and `odo` bring the lorebook `town` and
/// one without entries; `mute` lists a lorebook, but its prompt has no place
/// for one; `orphan` is listed by nobody.
const TWINS: &str = r#"
spec = "ccv4:1.0.0"

[meta-info]
title = "Twins of the Gate"

[lore.gate]
keywords = ["gate"]
sticky = 2
text = "The gate is shut at dusk."

[lore.well]
name = "The well"
trigger = "always"
keywords = []
text = "The well is dry."

[lorebook.town]
name = "Old Town"
description = "Of the town and its gate."
scan-depth = 4
token-budget = 120
entries = ["lore.gate", "lore.well", "lore.missing"]

[lorebook.hidden]
entries = ["lore.gate"]

[lorebook.orphan]
entries = ["lore.gate"]

[lorebook.empty]
entries = ["lore.missing"]

[character.una]
lorebooks = ["lorebook.town", "lorebook.empty"]
prompt = ["LOREBOOK", "CHAT-HISTORY"]

[character.odo]
lorebooks = ["lorebook.empty", "lorebook.town", "lorebook.nowhere"]
prompt = ["CHAT-HISTORY", "LOREBOOK"]

[character.mute]
lorebooks = ["lorebook.hidden"]
prompt = ["CHAT-HISTORY"]
"#;

fn twins(scratch: &Scratch) -> Imported {
    let toml = vec![("card/0001_card.toml".to_string(), TWINS.to_string())];
    let file = png::write(&Container {
        image: common::picture(),
        toml,
        assets: vec![],
    })
    .unwrap();
    common::import_whole(&scratch.db, scratch.user, &file).unwrap()
}

/// Who use a library lorebook as the list says it: the cards and personas that have it, and how many chats took it along.
#[test]
fn the_list_says_who_use_a_lorebook() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let reef = single(&scratch, "Reef");
    let used = || {
        let listed = lorebooks::find(db, me, "Reef", Show::All).unwrap();
        let reef = listed.iter().find(|book| book.id == reef).unwrap();
        (reef.used_by.clone(), reef.chats)
    };
    assert_eq!(used(), (vec![], 0));
    lorebooks::attach(db, me, card.card_id, reef).unwrap();
    let ada = cw_library::personas::create(db, me, "Ada", "").unwrap();
    cw_library::personas::set_lorebooks(db, me, ada, &[reef]).unwrap();
    let chat = chat_of(&scratch, &card, "mira");
    chats::add_lorebook(db, me, chat, reef).unwrap();
    assert_eq!(used(), (vec![card.title.clone(), "Ada".into()], 1));
    // What is in the Trash uses it no more.
    cards::set_trashed(db, me, card.card_id, true).unwrap();
    chats::set_trashed(db, me, chat, true).unwrap();
    assert_eq!(used(), (vec!["Ada".to_string()], 0));
}

#[test]
fn a_card_has_the_lorebooks_it_brings_and_those_of_the_library_attached_to_it() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    let book = harbour();
    // Made in another order than they are attached in.
    let (harbour, reef) = (
        import(&scratch, &book, "h.json").id,
        single(&scratch, "Reef"),
    );
    let coast = brought("lorebook.coast", "coast", 3);
    let of_card = |card_id| lorebooks::of_card(db, me, card_id).unwrap();
    // What an import says the card brings is what the card lists.
    assert_eq!(
        (&card.lorebooks, of_card(card.card_id)),
        (&vec![coast.clone()], vec![coast.clone()])
    );

    // Those attached stand after the card's own, in the order they were attached. One attached again stays where it is.
    let listed = lorebooks::attach(db, me, card.card_id, reef).unwrap();
    assert_eq!(listed, [coast.clone(), attached(reef, "Reef", 1)]);
    std::thread::sleep(PAUSE);
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    std::thread::sleep(PAUSE);
    let listed = lorebooks::attach(db, me, card.card_id, reef).unwrap();
    assert_eq!(
        listed,
        [
            coast.clone(),
            attached(reef, "Reef", 1),
            attached(harbour, "Harbour", 2)
        ]
    );
    assert_eq!(
        (&listed, count(db, "card_lorebooks")),
        (&of_card(card.card_id), 2)
    );
    // Another card has nothing of it.
    assert_eq!(of_card(other.card_id), std::slice::from_ref(&coast));
    // An archived one stays as it is.
    lorebooks::set_archived(db, me, harbour, true).unwrap();
    assert_eq!(of_card(card.card_id).len(), 3);

    // Detached, it is gone from the card and still in the library.
    let listed = lorebooks::detach(db, me, card.card_id, reef).unwrap();
    assert_eq!(listed, [coast.clone(), attached(harbour, "Harbour", 2)]);
    assert_eq!(listed, of_card(card.card_id));
    assert_eq!(names(&scratch, "", Show::All), ["Reef"]);
    let error = lorebooks::detach(db, me, card.card_id, reef).unwrap_err();
    assert_eq!(error.to_string(), "the card has no such lorebook attached");

    // What is not there, or is another user's, is not found.
    let sam = users::create(db, "sam").unwrap();
    let sams = common::import_whole(db, sam, &common::card_file()).unwrap();
    let nowhere = [
        (me, 99, reef),
        (me, card.card_id, 99),
        (sam, sams.card_id, reef),
        (sam, card.card_id, reef),
    ];
    for (user, card_id, lorebook_id) in nowhere {
        assert!(
            lorebooks::attach(db, user, card_id, lorebook_id)
                .unwrap_err()
                .is::<NotFound>(),
            "{user} {card_id} {lorebook_id}"
        );
    }
    assert!(
        lorebooks::detach(db, sam, card.card_id, harbour)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::detach(db, me, 99, harbour)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::of_card(db, sam, card.card_id)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(lorebooks::of_card(db, me, 99).unwrap_err().is::<NotFound>());
    assert_eq!(count(db, "card_lorebooks"), 1);

    // A card in the Trash is read, and nothing is attached to it or detached from it.
    cards::set_trashed(db, me, card.card_id, true).unwrap();
    let in_trash = "the card is in the Trash; restore it first";
    assert_eq!(
        lorebooks::attach(db, me, card.card_id, reef)
            .unwrap_err()
            .to_string(),
        in_trash
    );
    assert_eq!(
        lorebooks::detach(db, me, card.card_id, harbour)
            .unwrap_err()
            .to_string(),
        in_trash
    );
    assert_eq!(of_card(card.card_id).len(), 2);
}

#[test]
fn a_lorebook_a_card_brings_is_copied_into_the_library() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = twins(&scratch);
    let copy = |reference: &str| lorebooks::copy_from_card(db, me, card.card_id, reference, WORDS);
    // A card brings the lorebooks a chat with one of its characters is given, each once.
    let own = [
        brought("lorebook.town", "Old Town", 2),
        brought("lorebook.empty", "empty", 0),
    ];
    assert_eq!(
        (
            card.lorebooks.as_slice(),
            lorebooks::of_card(db, me, card.card_id).unwrap().as_slice()
        ),
        (&own[..], &own[..])
    );

    let town = copy("lorebook.town").unwrap();
    let whole = Lorebook {
        id: town.id,
        name: "Old Town".into(),
        description: "Of the town and its gate.".into(),
        entries: 2,
        entry_names: vec!["gate".into(), "The well".into()],
        favorite: false,
        archived: false,
        trashed: false,
        everywhere: false,
        used_by: vec![],
        chats: 0,
        card: None,
    };
    assert_eq!(town, whole);
    assert_eq!(names(&scratch, "", Show::All), ["Old Town"]);
    // The card keeps its own, and nothing is attached to it.
    assert_eq!(lorebooks::of_card(db, me, card.card_id).unwrap(), own);

    // In a chat of another card the copy gives what the card's own gives a chat of the card.
    let with_una = chat_of(&scratch, &card, "una");
    let elsewhere = chat(&scratch, "bare");
    chats::add_lorebook(db, me, elsewhere, town.id).unwrap();
    let (theirs, copied) = (
        book(&scratch, with_una).unwrap(),
        book(&scratch, elsewhere).unwrap(),
    );
    assert_eq!((copied.token_budget, copied.scan_depth), (120, Some(4)));
    assert_eq!((theirs.token_budget, theirs.scan_depth), (120, Some(4)));
    let ids_of = |book: &cw_prompt::Lorebook| {
        book.entries
            .iter()
            .filter_map(|entry| entry.id.clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(ids_of(&theirs), ["lore.gate", "lore.well"]);
    assert_eq!(
        ids_of(&copied),
        [
            format!(".{}.lore.gate", town.id),
            format!(".{}.lore.well", town.id)
        ]
    );
    let said = |book: cw_prompt::Lorebook| {
        let without_id = |mut entry: cw_prompt::LorebookEntry| {
            entry.id = None;
            format!("{entry:?}")
        };
        book.entries.into_iter().map(without_id).collect::<Vec<_>>()
    };
    assert_eq!(said(copied), said(theirs));

    // A copy made again is another lorebook. One the card gives no name is called as the card is.
    assert_ne!(copy("lorebook.town").unwrap().id, town.id);
    let mira = common::import_whole(db, me, &common::card_copy()).unwrap();
    let coast = lorebooks::copy_from_card(db, me, mira.card_id, "lorebook.coast", WORDS).unwrap();
    assert_eq!(
        (coast.name.as_str(), coast.entries, coast.entry_names),
        (
            "Mira of the North Light",
            3,
            vec!["wreck".to_string(), "lamp".into(), "wreck".into()]
        )
    );

    // Only what the card brings is copied, and only a lorebook with entries.
    for reference in [
        "lorebook.hidden",
        "lorebook.orphan",
        "lorebook.nowhere",
        "lore.gate",
        "lorebook",
        "",
    ] {
        assert_eq!(
            copy(reference).unwrap_err().to_string(),
            "the card brings no such lorebook",
            "{reference:?}"
        );
    }
    assert_eq!(
        copy("lorebook.empty").unwrap_err().to_string(),
        "the lorebook has no entries"
    );
    assert!(
        lorebooks::copy_from_card(db, me, 99, "lorebook.town", WORDS)
            .unwrap_err()
            .is::<NotFound>()
    );
    let sam = users::create(db, "sam").unwrap();
    assert!(
        lorebooks::copy_from_card(db, sam, card.card_id, "lorebook.town", WORDS)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert_eq!(count(db, "lorebooks"), 3);
}

#[test]
fn the_chats_of_a_card_have_the_lorebooks_attached_to_it() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let harbour = import(&scratch, &harbour(), "h.json").id;
    let (reef, atlas) = (single(&scratch, "Reef"), single(&scratch, "Atlas"));
    let before = chat_of(&scratch, &card, "mira");
    let elsewhere = chat(&scratch, "mira");
    let own = ["lore.wreck", "lore.lamp", "lore.off"].map(str::to_string);
    let of = |lorebook: i64, id: &str| format!(".{lorebook}.lore.{id}");
    let harbours = [of(harbour, "harbour-pier"), of(harbour, "harbour-bell")];
    let names_of = |chat_id| {
        had(&scratch, chat_id)
            .into_iter()
            .map(|book| book.0)
            .collect::<Vec<_>>()
    };

    // A chat that was there has it from then on, after its characters' own, and its budget counts with theirs.
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(
        ids(&scratch, before),
        [own.as_slice(), harbours.as_slice()].concat()
    );
    assert_eq!(
        had(&scratch, before),
        [("coast".to_string(), false), ("Harbour".to_string(), false)]
    );
    assert_eq!(book(&scratch, before).unwrap().token_budget, 800);
    // So has a chat started later, and a character whose prompt has no place for its card's own.
    let after = chat_of(&scratch, &card, "bare");
    assert_eq!(
        (ids(&scratch, after), had(&scratch, after)),
        (harbours.to_vec(), vec![("Harbour".to_string(), false)])
    );
    // A chat of another card has nothing of it.
    assert_eq!(ids(&scratch, elsewhere), own);

    // What the chat took along itself stands after what its card has, whenever it took it.
    std::thread::sleep(PAUSE);
    chats::add_lorebook(db, me, before, reef).unwrap();
    std::thread::sleep(PAUSE);
    lorebooks::attach(db, me, card.card_id, atlas).unwrap();
    assert_eq!(names_of(before), ["coast", "Harbour", "Atlas", "Reef"]);
    assert_eq!(
        chats::prompt_inputs(db, me, before, None).unwrap().library,
        [harbour, atlas, reef]
    );
    let others = [of(atlas, "lorebook-atlas"), of(reef, "lorebook-reef")];
    assert_eq!(
        ids(&scratch, before)[3..],
        [harbours.as_slice(), others.as_slice()].concat()
    );

    // One the chat has both ways is there once, as its own. Let go, it is still there through the card.
    chats::add_lorebook(db, me, before, harbour).unwrap();
    assert_eq!(had(&scratch, before)[1], ("Harbour".to_string(), true));
    assert_eq!(
        (names_of(before).len(), ids(&scratch, before).len()),
        (4, 7)
    );
    chats::remove_lorebook(db, me, before, harbour).unwrap();
    assert_eq!(
        (
            had(&scratch, before)[1].clone(),
            ids(&scratch, before).len()
        ),
        (("Harbour".to_string(), false), 7)
    );
    // What a card gives it, the chat does not let go.
    assert_eq!(
        chats::remove_lorebook(db, me, before, harbour)
            .unwrap_err()
            .to_string(),
        "the chat has no such lorebook"
    );
    assert_eq!(names_of(before).len(), 4);

    // Detached, it is gone from the card's chats, but not from one that took it along itself.
    chats::add_lorebook(db, me, after, harbour).unwrap();
    lorebooks::detach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(names_of(before), ["coast", "Atlas", "Reef"]);
    assert_eq!(
        had(&scratch, after),
        [("Atlas".to_string(), false), ("Harbour".to_string(), true)]
    );
    assert_eq!(
        ids(&scratch, after),
        [&[of(atlas, "lorebook-atlas")], harbours.as_slice()].concat()
    );

    // A chat with characters of two cards has what is attached to either, once, whoever speaks.
    let second = common::import_whole(db, me, &common::card_copy()).unwrap();
    lorebooks::attach(db, me, second.card_id, atlas).unwrap();
    std::thread::sleep(PAUSE);
    lorebooks::attach(db, me, second.card_id, reef).unwrap();
    let characters = [
        (card.version_id, "bare"),
        (second.version_id, "bare"),
        (second.version_id, "mira"),
    ];
    let both = chats::create(
        db,
        me,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    assert_eq!(names_of(both), ["coast", "Atlas", "Reef"]);
    for speaker in chats::participants(db, me, both).unwrap() {
        let book = chats::prompt_inputs(db, me, both, Some(speaker.id))
            .unwrap()
            .character
            .lorebook
            .unwrap();
        let library: Vec<_> = book
            .entries
            .iter()
            .filter_map(|entry| entry.id.clone())
            .filter(|id| id.starts_with('.'))
            .collect();
        assert_eq!(library, others, "{}", speaker.character);
    }
}

#[test]
fn a_chat_leaves_things_out_of_a_lorebook_it_has_through_its_card() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let harbour = import(&scratch, &harbour(), "h.json").id;
    let (chat_id, other) = (
        chat_of(&scratch, &card, "bare"),
        chat_of(&scratch, &card, "bare"),
    );
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    let source = LoreSource::LorebookId(harbour);
    let set = |chat_id, reference: &str, on| {
        chats::set_lore(db, me, chat_id, source, reference, on).unwrap()
    };
    let without_pier = [("Harbour".to_string(), true, vec!["Pier".to_string()], false)];
    let whole = [("Harbour".to_string(), true, vec![], false)];

    // One entry, then all of it. The card's other chats have it whole.
    set(chat_id, "lore.harbour-pier", false);
    assert_eq!(taken(&scratch, chat_id), without_pier);
    assert_eq!(
        ids(&scratch, chat_id),
        [format!(".{harbour}.lore.harbour-bell")]
    );
    set(chat_id, "lorebook.harbour", false);
    assert_eq!(
        (ids(&scratch, chat_id), taken(&scratch, other)),
        (vec![], whole.to_vec())
    );
    set(chat_id, "lorebook.harbour", true);
    set(other, "lore.harbour-bell", false);
    assert_eq!(count(db, "chat_lorebook_off"), 2);

    // Taken along as well and let go again, the chat still has it, with what it left out.
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    chats::remove_lorebook(db, me, chat_id, harbour).unwrap();
    assert_eq!(
        (taken(&scratch, chat_id), count(db, "chat_lorebook_off")),
        (without_pier.to_vec(), 2)
    );

    // Detached from the card, what a chat that is now without it had left out is forgotten:
    // attached again, it is whole there. A chat that took it along itself goes on as it was.
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    lorebooks::detach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(
        (taken(&scratch, chat_id), taken(&scratch, other)),
        (without_pier.to_vec(), vec![])
    );
    assert_eq!(count(db, "chat_lorebook_off"), 1);
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(taken(&scratch, other), whole);
    // Let go by the chat while its card has it, nothing is forgotten; detached then, all of it is.
    chats::remove_lorebook(db, me, chat_id, harbour).unwrap();
    assert_eq!(
        (taken(&scratch, chat_id), count(db, "chat_lorebook_off")),
        (without_pier.to_vec(), 1)
    );
    lorebooks::detach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(count(db, "chat_lorebook_off"), 0);
    // Nothing is left out of what the chat does not have.
    let gone = chats::set_lore(db, me, chat_id, source, "lore.harbour-pier", false).unwrap_err();
    assert_eq!(
        gone.to_string(),
        "the chat has no such lorebook or lorebook entry"
    );

    // A chat that has it through another of its cards too keeps what it left out.
    let second = common::import_whole(db, me, &common::card_copy()).unwrap();
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    lorebooks::attach(db, me, second.card_id, harbour).unwrap();
    let characters = [(card.version_id, "bare"), (second.version_id, "bare")];
    let both = chats::create(
        db,
        me,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    set(both, "lore.harbour-pier", false);
    lorebooks::detach(db, me, card.card_id, harbour).unwrap();
    assert_eq!(taken(&scratch, both), without_pier);
    lorebooks::detach(db, me, second.card_id, harbour).unwrap();
    assert_eq!(
        (taken(&scratch, both), count(db, "chat_lorebook_off")),
        (vec![], 0)
    );

    // That a card of other chats has it keeps nothing for a chat that let it go.
    lorebooks::attach(db, me, second.card_id, harbour).unwrap();
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    set(chat_id, "lore.harbour-pier", false);
    set(both, "lore.harbour-bell", false);
    chats::remove_lorebook(db, me, chat_id, harbour).unwrap();
    assert_eq!(count(db, "chat_lorebook_off"), 1);
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    assert_eq!(taken(&scratch, chat_id), whole);
}

#[test]
fn a_card_keeps_an_attached_lorebook_that_is_in_the_trash_until_it_is_deleted_for_good() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    let (harbour, reef) = (
        import(&scratch, &harbour(), "h.json").id,
        single(&scratch, "Reef"),
    );
    let (first, second) = (
        chat_of(&scratch, &card, "bare"),
        chat_of(&scratch, &card, "bare"),
    );
    let apart = chat_of(&scratch, &other, "bare");
    lorebooks::attach(db, me, card.card_id, harbour).unwrap();
    // One chat has it both ways, one of another card took it along, one is in the Trash itself.
    chats::add_lorebook(db, me, first, harbour).unwrap();
    chats::add_lorebook(db, me, apart, harbour).unwrap();
    chats::set_trashed(db, me, second, true).unwrap();
    // And one of the other card has nothing of it.
    chat_of(&scratch, &other, "bare");

    lorebooks::set_trashed(db, me, harbour, true).unwrap();
    // The card keeps it and says so, and so do its chats, one started now too.
    let coast = brought("lorebook.coast", "coast", 3);
    let gone = CardLorebook {
        trashed: true,
        ..attached(harbour, "Harbour", 2)
    };
    assert_eq!(
        lorebooks::of_card(db, me, card.card_id).unwrap(),
        [coast.clone(), gone]
    );
    let later = chat_of(&scratch, &card, "bare");
    assert_eq!(
        taken(&scratch, later),
        [("Harbour".to_string(), true, vec![], true)]
    );
    assert_eq!(ids(&scratch, later).len(), 2);
    // The Trash counts the chats outside it that have it, each once, whichever way they have it.
    assert_eq!(in_trash(db, me), [(harbour, 3)]);
    // It is not attached anew while it is there.
    let error = lorebooks::attach(db, me, other.card_id, harbour).unwrap_err();
    assert_eq!(
        error.to_string(),
        "the lorebook “Harbour” is in the Trash; restore it to use it"
    );

    // Deleted for good, it is gone from the card and from its chats.
    trash::delete_lorebook(db, me, harbour).unwrap();
    assert_eq!(lorebooks::of_card(db, me, card.card_id).unwrap(), [coast]);
    assert_eq!(
        (
            taken(&scratch, later),
            taken(&scratch, first),
            count(db, "card_lorebooks")
        ),
        (vec![], vec![], 0)
    );

    // A card deleted for good leaves what was attached to it in the library.
    lorebooks::attach(db, me, card.card_id, reef).unwrap();
    cards::set_trashed(db, me, card.card_id, true).unwrap();
    trash::delete_card(db, me, card.card_id).unwrap();
    assert_eq!(
        (count(db, "card_lorebooks"), names(&scratch, "", Show::All)),
        (0, vec!["Reef".to_string()])
    );
}

async fn delete(server: &Server, path: &str) -> (u16, Value) {
    server.call(Method::DELETE, path, None).await
}

/// What the list answers of the library's own lorebooks, as names.
async fn listed(server: &Server, query: &str) -> Vec<String> {
    let (status, list) = server.get(&format!("/api/lorebooks{query}")).await;
    assert_eq!(status, 200, "{list}");
    list.as_array()
        .unwrap()
        .iter()
        .filter(|lorebook| lorebook.get("card").is_none())
        .map(|lorebook| lorebook["name"].as_str().unwrap().to_string())
        .collect()
}

#[tokio::test]
async fn lorebooks_are_imported_listed_changed_and_deleted_over_http() {
    let server = start().await;
    let reef = world(&[entry("Reef", &["reef"], "The reef shows at low water.")]);
    let (status, imported) = server
        .upload(
            "/api/lorebooks?name=North%20Reef.json",
            reef.to_string().into_bytes(),
        )
        .await;
    let id = imported["lorebook"]["id"].as_i64().unwrap();
    let whole = json!({
        "id": id, "name": "North Reef", "description": "", "entries": 1, "entry_names": ["Reef"],
        "favorite": false, "archived": false, "trashed": false, "everywhere": false,
        "used_by": [], "chats": 0,
    });
    assert_eq!(
        (status, &imported),
        (201, &json!({ "lorebook": whole, "warnings": [] }))
    );
    let path = format!("/api/lorebooks/{id}");
    // Without a name for the file, and with what the import has to say.
    let mut outlet = entry("Outlet", &["out"], "For an outlet.");
    outlet["position"] = json!("outlet");
    let (status, imported) = server
        .upload("/api/lorebooks", world(&[outlet]).to_string().into_bytes())
        .await;
    assert_eq!(
        (status, &imported["lorebook"]["name"]),
        (201, &json!("Lorebook"))
    );
    assert_eq!(
        imported["warnings"],
        json!([{ "code": "outlet_entries_off", "count": 1 }])
    );
    let unnamed = format!("/api/lorebooks/{}", imported["lorebook"]["id"]);

    // A file that is no lorebook is refused in words.
    let (status, error) = server
        .upload("/api/lorebooks?name=card.png", common::card_file())
        .await;
    assert_eq!(status, 400);
    assert!(
        error["error"]
            .as_str()
            .unwrap()
            .starts_with("the file is not valid JSON"),
        "{error}"
    );
    // A lorebook is larger than most requests, but not of any size.
    let large = world(&[entry("Large", &["large"], &"word ".repeat(600_000))])
        .to_string()
        .into_bytes();
    assert!(large.len() > 2 * 1024 * 1024);
    let (status, imported) = server.upload("/api/lorebooks?name=Large.json", large).await;
    assert_eq!(
        (status, &imported["lorebook"]["name"]),
        (201, &json!("Large"))
    );
    let huge = reqwest::Client::new()
        .post(format!("http://{}/api/lorebooks", server.addr))
        .body(vec![b' '; 20 * 1024 * 1024 + 1]);
    // The server may hang up on what it will not read, before it has said so.
    if let Ok(answer) = huge.send().await {
        assert_eq!(answer.status(), 413);
    }
    let large = format!("/api/lorebooks/{}", imported["lorebook"]["id"]);

    // A change answers with the lorebook as it is then; what it leaves out stays.
    let (status, changed) = server.patch(&path, json!({ "favorite": true })).await;
    let mut starred = whole.clone();
    starred["favorite"] = json!(true);
    assert_eq!((status, &changed), (200, &starred));
    assert_eq!(server.patch(&path, json!({})).await, (200, changed));
    assert_eq!(
        server
            .patch("/api/lorebooks/999", json!({ "favorite": true }))
            .await
            .0,
        404
    );

    // The list takes a search and a filter in its address.
    assert_eq!(
        listed(&server, "").await,
        ["Large", "Lorebook", "North Reef"]
    );
    assert_eq!(listed(&server, "?show=favorites").await, ["North Reef"]);
    assert_eq!(listed(&server, "?q=REEF").await, ["North Reef"]);
    server.patch(&unnamed, json!({ "archived": true })).await;
    assert_eq!(listed(&server, "").await, ["Large", "North Reef"]);
    assert_eq!(listed(&server, "?show=archived").await, ["Lorebook"]);
    assert_eq!(
        listed(&server, "?q=o&show=all").await,
        ["North Reef", "Lorebook"]
    );
    assert_eq!(server.get("/api/lorebooks?show=some").await.0, 400);

    // Deleting for good: only from the Trash, where it is listed, and then it is gone.
    let (status, error) = delete(&server, &path).await;
    assert_eq!(status, 400);
    assert!(
        error["error"].as_str().unwrap().contains("in the Trash"),
        "{error}"
    );
    let (status, changed) = server.patch(&path, json!({ "trashed": true })).await;
    assert_eq!(
        (status, &changed["trashed"], &changed["favorite"]),
        (200, &json!(true), &json!(true))
    );
    assert_eq!(listed(&server, "?q=reef").await, [] as [&str; 0]);
    let (_, list) = server.get("/api/trash").await;
    let item = json!({ "kind": "lorebook", "id": id, "title": "North Reef", "trashed_at": list["items"][0]["trashed_at"], "chats": 0 });
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
        server.patch(&path, json!({ "favorite": true })).await.0,
        404
    );

    // Emptying the Trash takes lorebooks too.
    server.patch(&large, json!({ "trashed": true })).await;
    assert_eq!(delete(&server, "/api/trash").await.0, 204);
    assert_eq!(listed(&server, "?q=l").await, ["Lorebook"]);
}

#[tokio::test]
async fn a_cards_lorebooks_are_listed_attached_detached_and_copied_over_http() {
    let server = start().await;
    let (status, card) = server.upload_whole(common::card_file()).await;
    let coast =
        json!({ "reference": "lorebook.coast", "name": "coast", "entries": 3, "trashed": false });
    // An import says what lorebooks the card brings.
    assert_eq!((status, &card["lorebooks"]), (201, &json!([coast])));
    let path = format!("/api/cards/{}/lorebooks", card["card_id"]);
    assert_eq!(server.get(&path).await, (200, json!([coast])));
    let reef = world(&[entry("Reef", &["reef"], "The reef shows at low water.")]);
    let (_, imported) = server
        .upload(
            "/api/lorebooks?name=Reef.json",
            reef.to_string().into_bytes(),
        )
        .await;
    let reef = imported["lorebook"]["id"].as_i64().unwrap();

    // Attaching and detaching answer with the card's lorebooks as they then are.
    let with_reef =
        json!([coast, { "lorebook_id": reef, "name": "Reef", "entries": 1, "trashed": false }]);
    assert_eq!(
        server.post(&path, json!({ "lorebook_id": reef })).await,
        (200, with_reef.clone())
    );
    assert_eq!(server.get(&path).await, (200, with_reef));
    assert_eq!(
        server.post(&path, json!({ "lorebook_id": 999 })).await.0,
        404
    );
    assert_eq!(
        server
            .post("/api/cards/999/lorebooks", json!({ "lorebook_id": reef }))
            .await
            .0,
        404
    );
    assert_eq!(server.get("/api/cards/999/lorebooks").await.0, 404);

    // A chat of the card has it, and tells it from one it took along itself.
    let start =
        json!({ "characters": [{ "version_id": card["version_id"], "character": "bare" }] });
    let (status, chat) = server.post("/api/chats", start).await;
    assert_eq!(status, 201, "{chat}");
    let through_card = json!({ "lorebook_id": reef, "reference": "lorebook.lorebook", "name": "Reef", "on": true, "entries": ["lore.lorebook-reef"], "removed": [], "trashed": false, "taken": false, "everywhere": false, "persona": false });
    assert_eq!(chat["lorebooks"], json!([through_card]));
    let chat_path = format!("/api/chats/{}", chat["chat"]["id"]);
    let (_, taken) = server
        .post(
            &format!("{chat_path}/lorebooks"),
            json!({ "lorebook_id": reef }),
        )
        .await;
    assert_eq!(taken[0]["taken"], true);
    let (status, left) = delete(&server, &format!("{chat_path}/lorebooks/{reef}")).await;
    assert_eq!((status, &left), (200, &json!([through_card])));
    assert_eq!(
        delete(&server, &format!("{chat_path}/lorebooks/{reef}"))
            .await
            .0,
        400
    );

    // A copy of what the card brings is a lorebook of the library.
    let (status, copy) = server
        .post(
            &format!("{path}/copy"),
            json!({ "reference": "lorebook.coast", "copy": "copy" }),
        )
        .await;
    let whole = json!({
        "id": copy["id"], "name": "Mira of the North Light", "description": "", "entries": 3,
        "entry_names": ["wreck", "lamp", "wreck"], "favorite": false, "archived": false, "trashed": false, "everywhere": false,
        "used_by": [], "chats": 0,
    });
    assert_eq!((status, &copy), (201, &whole));
    assert_eq!(
        listed(&server, "").await,
        ["Mira of the North Light", "Reef"]
    );
    let (status, error) = server
        .post(
            &format!("{path}/copy"),
            json!({ "reference": "lorebook.nothing", "copy": "copy" }),
        )
        .await;
    assert_eq!(
        (status, &error["error"]),
        (400, &json!("the card brings no such lorebook"))
    );
    assert_eq!(
        server
            .post(
                "/api/cards/999/lorebooks/copy",
                json!({ "reference": "lorebook.coast", "copy": "copy" })
            )
            .await
            .0,
        404
    );

    let (status, left) = delete(&server, &format!("{path}/{reef}")).await;
    assert_eq!((status, &left), (200, &json!([coast])));
    let (status, error) = delete(&server, &format!("{path}/{reef}")).await;
    assert_eq!(
        (status, &error["error"]),
        (400, &json!("the card has no such lorebook attached"))
    );
    assert_eq!(
        delete(&server, &format!("/api/cards/999/lorebooks/{reef}"))
            .await
            .0,
        404
    );
    assert_eq!(server.get(&chat_path).await.1["lorebooks"], json!([]));
}

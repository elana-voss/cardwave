//! Lorebooks of the library: read from a file, listed, through the Trash, and
//! taken along by a chat. A card's are `lorebooks_cards.rs`.

mod common;

use std::time::Duration;

use common::Scratch;
use common::lore::*;
use cw_accounts::users;
use cw_chat::chats::{self, ChatLorebook, Lore, LoreSource, NewChat};
use cw_core::NotFound;
use cw_library::cards::Show;
use cw_library::lorebooks::{self, Lorebook};
use cw_library::trash::{self, DAYS};
use cw_prompt::lorebook::evaluate;
use cw_prompt::{ChatMessage, ChatState, Role, SelectiveLogic};
use cw_store::Db;
use serde_json::{Value, json};

const DAY: i64 = 24 * 60 * 60 * 1000;

/// A change of one of a lorebook's flags.
type Change = fn(&dyn lorebooks::Storage, i64, i64, bool) -> anyhow::Result<()>;

/// Why a file is refused.
fn refused(scratch: &Scratch, file: &[u8]) -> String {
    format!(
        "{:#}",
        lorebooks::import(&scratch.db, scratch.user, file, "file.json").unwrap_err()
    )
}

/// Makes an item look as if it went to the Trash at `at`.
fn trashed_at(db: &Db, id: i64, at: i64) {
    let changed = db
        .with(|conn| {
            conn.execute(
                "update lorebooks set trashed_at = ?2 where id = ?1 and trashed_at is not null",
                [id, at],
            )
        })
        .unwrap();
    assert_eq!(changed, 1, "lorebook {id} is not in the Trash");
}

#[test]
fn a_world_info_file_becomes_a_lorebook_with_its_settings() {
    let scratch = Scratch::new();
    // The numbers are not in the order of their text: 10 comes after 2.
    let file = json!({ "entries": {
        "10": { "uid": 10, "key": ["gull"], "comment": "Gulls", "content": "Gulls nest in the lantern room.",
                "disable": true, "order": 100, "position": 1, "probability": 40, "useProbability": true },
        "0": { "uid": 0, "key": ["wreck", "Asta"], "keysecondary": ["storm"], "comment": "The wreck",
               "content": "The Asta sank here in 1911.", "constant": false, "selective": true, "selectiveLogic": 3,
               "order": 20, "position": 0, "disable": false, "probability": 100, "useProbability": true, "depth": 4,
               "caseSensitive": true, "matchWholeWords": true, "ignoreBudget": true, "sticky": 2, "cooldown": 1, "delay": 3,
               "scanDepth": 7,
               "characterFilter": { "isExclude": true, "names": ["Mira"], "tags": [] } },
        "2": { "uid": 2, "key": ["tide"], "keysecondary": [], "comment": "", "content": "The tide turns at six.",
               "constant": true, "selective": true, "order": 5, "position": 4, "depth": 2, "role": 1, "disable": false },
    }});
    // It is called as its file is, without the folders and the ending.
    let lorebook = import(&scratch, &file, "C:\\books/North Coast.v2.json");
    let whole = Lorebook {
        id: lorebook.id,
        name: "North Coast.v2".into(),
        description: String::new(),
        entries: 3,
        entry_names: vec!["The wreck".into(), "tide".into(), "Gulls".into()],
        favorite: false,
        archived: false,
        trashed: false,
        everywhere: false,
        used_by: vec![],
        chats: 0,
        card: None,
    };
    assert_eq!(lorebook, whole);

    let chat_id = chat(&scratch, "bare");
    chats::add_lorebook(&scratch.db, scratch.user, chat_id, lorebook.id).unwrap();
    let book = book(&scratch, chat_id).unwrap();
    let [wreck, tide, gulls] = book.entries.as_slice() else {
        panic!("{} entries", book.entries.len())
    };
    // An entry's ID tells it from an entry of the chat's cards.
    let key = format!(".{}.", lorebook.id);
    assert_eq!(
        wreck.id.as_deref(),
        Some(format!("{key}lore.lorebook-the-wreck").as_str())
    );
    assert_eq!(
        (wreck.name.as_str(), wreck.content.as_str()),
        ("The wreck", "The Asta sank here in 1911.")
    );
    assert_eq!(
        (&wreck.keys, &wreck.secondary_keys),
        (
            &vec!["wreck".to_string(), "Asta".to_string()],
            &vec!["storm".to_string()]
        )
    );
    assert!(
        wreck.enabled && !wreck.constant && wreck.selective && !wreck.use_regex && !wreck.at_depth
    );
    assert_eq!(wreck.selective_logic, SelectiveLogic::AndAll);
    assert!(wreck.case_sensitive && wreck.match_whole_words && wreck.ignore_budget);
    assert_eq!((wreck.insertion_order, wreck.probability), (20, 100));
    assert_eq!((wreck.sticky, wreck.cooldown, wreck.delay), (2, 1, 3));
    // A world info names an entry's own scan depth its own way.
    assert_eq!((wreck.scan_depth, tide.scan_depth), (Some(7), None));
    let filter = wreck.character_filter.as_ref().unwrap();
    assert_eq!(
        (&filter.names, filter.is_exclude),
        (&vec!["Mira".to_string()], true)
    );

    // An entry without a name goes by its first keyword. Position 4 is in the chat, at its depth.
    assert_eq!(
        (tide.id.as_deref(), tide.name.as_str()),
        (Some(format!("{key}lore.lorebook-tide").as_str()), "tide")
    );
    assert!(tide.constant && tide.enabled && !tide.selective && tide.character_filter.is_none());
    assert_eq!(
        (tide.at_depth, tide.depth, tide.role, tide.insertion_order),
        (true, 2, Role::User, 5)
    );
    assert!(!tide.case_sensitive && !tide.match_whole_words && !tide.ignore_budget);

    assert!(!gulls.enabled && !gulls.at_depth);
    assert_eq!((gulls.probability, gulls.insertion_order), (40, 100));
    // A world info has neither a budget nor a scan depth of its own.
    assert_eq!((book.token_budget, book.scan_depth), (0, None));
}

#[test]
fn a_cards_lorebook_saved_by_itself_is_read_bare_or_wrapped() {
    let scratch = Scratch::new();
    let said = json!({
        "name": "  The\nNorth   Coast ", "description": "  Lore of the coast.\nIn two lines. ", "scan_depth": 7, "token_budget": 500,
        "entries": [{ "keys": ["lamp"], "comment": "Lamp", "content": "The lamp must never go out.", "insertion_order": 1, "enabled": true }],
    });
    for file in [said.clone(), json!({ "spec": "lorebook_v3", "data": said })] {
        // What the file calls the lorebook counts, on one line; the file's own name does not.
        let lorebook = import(&scratch, &file, "export (3).json");
        assert_eq!(
            (lorebook.name.as_str(), lorebook.description.as_str()),
            ("The North Coast", "Lore of the coast.\nIn two lines.")
        );
        assert_eq!(
            (lorebook.entries, &lorebook.entry_names),
            (1, &vec!["Lamp".to_string()])
        );
        let chat_id = chat(&scratch, "bare");
        chats::add_lorebook(&scratch.db, scratch.user, chat_id, lorebook.id).unwrap();
        let book = book(&scratch, chat_id).unwrap();
        assert_eq!(
            (
                book.token_budget,
                book.scan_depth,
                book.entries[0].insertion_order
            ),
            (500, Some(7), 1)
        );
        assert_eq!(
            book.entries[0].id.as_deref(),
            Some(format!(".{}.lore.the-north-coast-lamp", lorebook.id).as_str())
        );
    }

    // A world info made from a card keeps the card's book, which says what the file does not.
    let mut file = world(&[entry("Lamp", &["lamp"], "The lamp must never go out.")]);
    file["originalData"] = json!({ "name": "Coast of the card", "description": "From the card.", "token_budget": 90, "entries": [] });
    let lorebook = import(&scratch, &file, "world.json");
    assert_eq!(
        (lorebook.name.as_str(), lorebook.description.as_str()),
        ("Coast of the card", "From the card.")
    );
    file["name"] = json!("Coast of the file");
    file["description"] = Value::Null;
    let lorebook = import(&scratch, &file, "world.json");
    assert_eq!(
        (lorebook.name.as_str(), lorebook.description.as_str()),
        ("Coast of the file", "From the card.")
    );

    // Without any name it is a lorebook all the same.
    let nameless = world(&[entry("Lamp", &["lamp"], "The lamp must never go out.")]);
    for file_name in ["", ".json", "  .json", "books/"] {
        assert_eq!(
            import(&scratch, &nameless, file_name).name,
            "Lorebook",
            "{file_name:?}"
        );
    }
    assert_eq!(import(&scratch, &nameless, "coast").name, "coast");
}

#[test]
fn a_key_written_as_a_pattern_makes_all_keys_of_its_entry_patterns() {
    let scratch = Scratch::new();
    let mut explicit = entry("Said", &["/wyrm/i", "x+y"], "Said to be plain.");
    explicit["use_regex"] = json!(false);
    let mut both = entry(
        "Both",
        &["/dra+gon/i", "C++ (old)"],
        "Dragons and old code.",
    );
    both["keysecondary"] = json!(["a.b"]);
    both["selective"] = json!(true);
    let file = world(&[
        both,
        entry(
            "Plain",
            &["C++", "/not a pattern", "//", "/a b/X"],
            "Plain keys.",
        ),
        explicit,
    ]);
    let lorebook = import(&scratch, &file, "keys.json");
    let chat_id = chat(&scratch, "bare");
    chats::add_lorebook(&scratch.db, scratch.user, chat_id, lorebook.id).unwrap();
    let inputs = chats::prompt_inputs(&scratch.db, scratch.user, chat_id, None).unwrap();
    let [both, plain, explicit] = inputs
        .character
        .lorebook
        .as_ref()
        .unwrap()
        .entries
        .as_slice()
    else {
        panic!()
    };

    assert!(both.use_regex && !plain.use_regex && !explicit.use_regex);
    assert_eq!(both.keys[0], "/dra+gon/i");
    assert_ne!(both.keys[1], "C++ (old)");
    // Keys that are no patterns stay as they came, where no key is one or the file says so.
    assert_eq!(plain.keys, ["C++", "/not a pattern", "//", "/a b/X"]);
    assert_eq!(explicit.keys, ["/wyrm/i", "x+y"]);

    // The plain keys beside a pattern match their text and nothing else.
    let active = |text: &str| {
        let mut state = ChatState {
            messages: vec![ChatMessage::new("1", Role::User, text)],
            ..Default::default()
        };
        evaluate(&inputs.character, &mut state)
            .into_iter()
            .map(|entry| entry.entry.name.clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(active("A DRAAAGON at a.b, they say."), ["Both"]);
    assert_eq!(active("Written in C++ (old) at a.b."), ["Both", "Plain"]);
    assert_eq!(active("Written in C++ (old) at axb."), ["Plain"]);
    assert_eq!(active("Written in C (old) at a.b."), [] as [&str; 0]);
}

#[test]
fn a_file_that_is_no_lorebook_is_refused() {
    let scratch = Scratch::new();
    assert_eq!(
        refused(&scratch, b"not json").split(':').next(),
        Some("the file is not valid JSON")
    );
    assert!(refused(&scratch, b"").starts_with("the file is not valid JSON"));
    assert_eq!(refused(&scratch, b"[1, 2]"), "the file holds no lorebook");
    assert_eq!(
        refused(&scratch, b"\"entries\""),
        "the file holds no lorebook"
    );
    assert_eq!(
        refused(&scratch, b"{}"),
        "the file holds no lorebook: it has no entries"
    );
    assert_eq!(
        refused(&scratch, br#"{"entries": 5}"#),
        "the file holds no lorebook: it has no entries"
    );
    for empty in [
        json!({ "entries": {} }),
        json!({ "entries": [] }),
        json!({ "entries": [1, "two", null] }),
        json!({ "entries": { "0": [] } }),
    ] {
        assert_eq!(
            refused(&scratch, empty.to_string().as_bytes()),
            "the lorebook has no entries",
            "{empty}"
        );
    }
    // A card is not a lorebook, though it may carry one.
    let card =
        json!({ "spec": "chara_card_v2", "data": { "name": "Mira", "character_book": harbour() } });
    assert_eq!(
        refused(&scratch, card.to_string().as_bytes()),
        "the file is a character card, not a lorebook"
    );
    // Nested too deep to read safely: refused, not crashed on.
    let deep = format!(
        "{{\"entries\": {}1{}}}",
        "[".repeat(100_000),
        "]".repeat(100_000)
    );
    assert!(refused(&scratch, deep.as_bytes()).starts_with("the file is not valid JSON"));
    assert_eq!(names(&scratch, "", Show::All), [] as [&str; 0]);
    assert_eq!(count(&scratch.db, "lorebooks"), 0);
}

#[test]
fn what_a_file_says_is_kept_as_it_is_whatever_it_is() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // Text that would end a TOML string, start a block of its own or is no text at all.
    let hostile = "He said \"no\".\n\"\"\"\n[lore.x]\nkeywords = ['x']\n'''\\u0000 \u{1} \t tab \u{7f} é 日本";
    let mut outlet = entry("Outlet", &["out"], "For an outlet.");
    outlet["position"] = json!(7);
    let twin = entry(hostile, &[hostile, "second"], hostile);
    let file = world(&[twin.clone(), twin, outlet]);
    // A file may start with a byte-order mark.
    let bytes = [b"\xEF\xBB\xBF".as_slice(), file.to_string().as_bytes()].concat();
    let imported = lorebooks::import(db, me, &bytes, "hostile.json").unwrap();
    assert_eq!(
        imported.warnings,
        [cw_ccv4::ImportNote::OutletEntriesOff { count: 1 }]
    );
    assert_eq!(imported.lorebook.entries, 3);

    let chat_id = chat(&scratch, "bare");
    chats::add_lorebook(db, me, chat_id, imported.lorebook.id).unwrap();
    let book = book(&scratch, chat_id).unwrap();
    let [first, second, outlet] = book.entries.as_slice() else {
        panic!("{} entries", book.entries.len())
    };
    // Two entries of one name are two entries.
    assert_ne!(first.id, second.id);
    for entry in [first, second] {
        assert_eq!(entry.content, hostile.trim());
        assert_eq!(entry.keys, [hostile.trim(), "second"]);
        assert!(entry.enabled);
    }
    assert!(!outlet.enabled);

    // A name and a description of any length: the list keeps their start.
    let long = json!({
        "name": "é".repeat(70), "description": "ü".repeat(1200),
        "entries": (0..70).map(|n| json!({ "keys": [format!("key{n}")], "content": "Text." })).collect::<Vec<_>>(),
    });
    let lorebook = import(&scratch, &long, "long.json");
    assert_eq!(
        (lorebook.name, lorebook.description),
        ("é".repeat(64), "ü".repeat(1000))
    );
    // All entries are there; the list names the first of them.
    assert_eq!(
        (
            lorebook.entries,
            lorebook.entry_names.len(),
            lorebook.entry_names[63].as_str()
        ),
        (70, 64, "key63")
    );
    chats::add_lorebook(db, me, chat_id, lorebook.id).unwrap();
    assert_eq!(ids(&scratch, chat_id).len(), 73);
}

#[test]
fn lorebooks_are_listed_by_name_searched_and_filtered() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let named = |name: &str, description: &str, entry_name: &str| {
        let mut file = world(&[entry(entry_name, &["key"], "Text.")]);
        file["name"] = json!(name);
        file["description"] = json!(description);
        import(&scratch, &file, "file.json").id
    };
    let zebra = named("zebra crossing", "Roads of the north.", "Toll house");
    let emile = named("Émile's coast", "The LAMP and the sea.", "Wreck");
    let atlas = named("Atlas", "Maps of the sea.", "North road");
    assert_eq!(
        names(&scratch, "", Show::All),
        ["Atlas", "Émile's coast", "zebra crossing"]
    );

    // A search looks in the name, the description and the names of the entries, in any case, for every word.
    assert_eq!(
        names(&scratch, "SEA", Show::All),
        ["Atlas", "Émile's coast"]
    );
    assert_eq!(names(&scratch, "lamp émile", Show::All), ["Émile's coast"]);
    assert_eq!(
        names(&scratch, "north", Show::All),
        ["Atlas", "zebra crossing"]
    );
    assert_eq!(
        names(&scratch, "toll  zebra", Show::All),
        ["zebra crossing"]
    );
    assert_eq!(names(&scratch, "sea toll", Show::All), [] as [&str; 0]);
    // Not in what the entries say.
    assert_eq!(names(&scratch, "text", Show::All), [] as [&str; 0]);

    lorebooks::set_favorite(db, me, zebra, true).unwrap();
    lorebooks::set_archived(db, me, atlas, true).unwrap();
    assert_eq!(
        names(&scratch, "", Show::All),
        ["Émile's coast", "zebra crossing"]
    );
    assert_eq!(names(&scratch, "", Show::Favorites), ["zebra crossing"]);
    assert_eq!(names(&scratch, "", Show::Archived), ["Atlas"]);
    // A search finds the archived ones too, after the others.
    assert_eq!(
        names(&scratch, "sea", Show::All),
        ["Émile's coast", "Atlas"]
    );
    assert_eq!(names(&scratch, "sea", Show::Favorites), [] as [&str; 0]);
    let found = lorebooks::get(db, me, atlas).unwrap().unwrap();
    assert!(found.archived && !found.favorite && !found.trashed);
    lorebooks::set_favorite(db, me, zebra, false).unwrap();
    lorebooks::set_archived(db, me, atlas, false).unwrap();
    assert_eq!(names(&scratch, "", Show::Favorites), [] as [&str; 0]);
    assert_eq!(names(&scratch, "", Show::All).len(), 3);

    // One in the Trash is not listed, searched for or not.
    lorebooks::set_trashed(db, me, emile, true).unwrap();
    assert_eq!(names(&scratch, "", Show::All), ["Atlas", "zebra crossing"]);
    assert_eq!(names(&scratch, "sea", Show::All), ["Atlas"]);

    // Another user has none of them, and reaches none.
    let sam = users::create(db, "sam").unwrap();
    assert!(lorebooks::find(db, sam, "", Show::All).unwrap().is_empty());
    assert!(lorebooks::get(db, sam, atlas).unwrap().is_none());
    let changes: [Change; 3] = [
        lorebooks::set_favorite,
        lorebooks::set_archived,
        lorebooks::set_trashed,
    ];
    for change in changes {
        assert!(change(db, sam, atlas, true).unwrap_err().is::<NotFound>());
    }
    assert!(
        lorebooks::set_trashed(db, sam, emile, false)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        trash::delete_lorebook(db, sam, emile)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(trash::list(db, sam).unwrap().is_empty());
    let theirs = chat(&scratch, "mira");
    let sams_chat = {
        let card = common::import_whole(db, sam, &common::card_file()).unwrap();
        chats::create(
            db,
            sam,
            &NewChat {
                characters: &[(card.version_id, "mira")],
                persona_id: None,
                greeting: 0,
            },
        )
        .unwrap()
    };
    assert!(
        chats::add_lorebook(db, sam, sams_chat, atlas)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        chats::add_lorebook(db, sam, theirs, atlas)
            .unwrap_err()
            .is::<NotFound>()
    );
    chats::add_lorebook(db, me, theirs, atlas).unwrap();
    assert!(
        chats::remove_lorebook(db, sam, theirs, atlas)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert_eq!(trash::empty(db, sam).unwrap(), 0);
    assert_eq!(in_trash(db, me), [(emile, 0)]);
}

#[test]
fn a_lorebook_goes_to_the_trash_alone_and_only_from_there_for_good() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let coast = import(&scratch, &harbour(), "a.json").id;
    let other = import(&scratch, &harbour(), "b.json").id;
    let kept = chat(&scratch, "mira");
    let gone = chat(&scratch, "mira");
    for chat_id in [kept, gone] {
        chats::add_lorebook(db, me, chat_id, coast).unwrap();
    }
    chats::set_trashed(db, me, gone, true).unwrap();

    // Only what is in the Trash is deleted for good.
    let error = trash::delete_lorebook(db, me, coast).unwrap_err();
    assert_eq!(
        error.to_string(),
        "only a lorebook in the Trash can be deleted for good; move it there first"
    );
    assert!(
        trash::delete_lorebook(db, me, 99)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::set_trashed(db, me, 99, true)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::set_trashed(db, me, 99, false)
            .unwrap_err()
            .is::<NotFound>()
    );

    // It goes there alone; the Trash counts the chats outside it that have it.
    lorebooks::set_trashed(db, me, coast, true).unwrap();
    assert!(lorebooks::get(db, me, coast).unwrap().unwrap().trashed);
    assert_eq!(in_trash(db, me), [(coast, 1)]);
    assert!(!chats::get(db, me, kept).unwrap().unwrap().trashed);
    // Deleted again, its days are not counted anew.
    trashed_at(db, coast, 1000);
    lorebooks::set_trashed(db, me, coast, true).unwrap();
    let moment: i64 = db
        .with(|conn| {
            conn.query_row(
                "select trashed_at from lorebooks where id = ?1",
                [coast],
                |r| r.get(0),
            )
        })
        .unwrap();
    assert_eq!(moment, 1000);

    // Restored, it is what it was.
    lorebooks::set_trashed(db, me, coast, false).unwrap();
    assert!(!lorebooks::get(db, me, coast).unwrap().unwrap().trashed);
    assert_eq!(
        (in_trash(db, me), names(&scratch, "", Show::All).len()),
        (vec![], 2)
    );

    // After thirty days it goes by itself, and no sooner; the other stays.
    lorebooks::set_trashed(db, me, coast, true).unwrap();
    let now = 1_000 * DAY;
    trashed_at(db, coast, now - i64::from(DAYS) * DAY);
    assert_eq!(trash::purge(db, now).unwrap(), 0);
    assert!(lorebooks::get(db, me, coast).unwrap().is_some());
    assert_eq!(trash::purge(db, now + 1).unwrap(), 1);
    assert!(lorebooks::get(db, me, coast).unwrap().is_none());
    assert_eq!(names(&scratch, "", Show::All), ["Harbour"]);
    // The chats that had it are without it, and nothing of it is left.
    assert_eq!(taken(&scratch, kept).len(), 1);
    assert_eq!(count(db, "chat_lorebooks"), 0);

    // Deleted by hand, and with all of the Trash.
    lorebooks::set_trashed(db, me, other, true).unwrap();
    trash::delete_lorebook(db, me, other).unwrap();
    assert!(
        trash::delete_lorebook(db, me, other)
            .unwrap_err()
            .is::<NotFound>()
    );
    let last = import(&scratch, &harbour(), "c.json").id;
    lorebooks::set_trashed(db, me, last, true).unwrap();
    assert_eq!(trash::empty(db, me).unwrap(), 2);
    assert_eq!(count(db, "lorebooks"), 0);
}

#[test]
fn a_chat_takes_lorebooks_of_the_library_along_beside_its_characters_own() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let reef = import(
        &scratch,
        &world(&[entry("Reef", &["reef"], "The reef shows at low water.")]),
        "Reef.json",
    )
    .id;
    let harbour = import(&scratch, &harbour(), "h.json").id;
    let with_mira = chat(&scratch, "mira");
    let with_bare = chat(&scratch, "bare");
    let card = LoreSource::CardId(
        chats::prompt_inputs(db, me, with_mira, None)
            .unwrap()
            .card_id
            .unwrap(),
    );
    let own = ["lore.wreck", "lore.lamp", "lore.off"].map(str::to_string);
    let of = |lorebook: i64, id: &str| format!(".{lorebook}.lore.{id}");
    assert_eq!(
        (ids(&scratch, with_mira), ids(&scratch, with_bare)),
        (own.to_vec(), vec![])
    );

    // Its entries come after the characters' own, and its budget and scan depth count with theirs.
    let listed = chats::add_lorebook(db, me, with_mira, harbour).unwrap();
    assert_eq!(listed, chats::lorebooks(db, me, with_mira).unwrap());
    let whole = ChatLorebook {
        source: LoreSource::LorebookId(harbour),
        reference: "lorebook.harbour".into(),
        name: "Harbour".into(),
        on: true,
        entries: vec!["lore.harbour-pier".into(), "lore.harbour-bell".into()],
        removed: vec![],
        trashed: false,
        taken: true,
        everywhere: false,
        persona: false,
    };
    assert_eq!(
        (listed.len(), &listed[0].name, &listed[1]),
        (2, &"coast".to_string(), &whole)
    );
    let harbours = [of(harbour, "harbour-pier"), of(harbour, "harbour-bell")];
    assert_eq!(
        ids(&scratch, with_mira),
        [own.as_slice(), harbours.as_slice()].concat()
    );
    let book_of = |chat_id| book(&scratch, chat_id).unwrap();
    assert_eq!(
        (
            book_of(with_mira).token_budget,
            book_of(with_mira).scan_depth
        ),
        (800, Some(7))
    );
    assert_eq!(book_of(with_mira).entries[4].name, "Bell");
    // Another chat has nothing of it.
    assert_eq!(ids(&scratch, with_bare), [] as [&str; 0]);

    // A character whose prompt has no place for its card's lorebooks is given the chat's all the same.
    chats::add_lorebook(db, me, with_bare, harbour).unwrap();
    assert_eq!(ids(&scratch, with_bare), harbours);
    assert_eq!(book_of(with_bare).token_budget, 500);

    // Lorebooks stand in the order the chat took them, not in the library's. One taken again stays where it is.
    std::thread::sleep(Duration::from_millis(5));
    chats::add_lorebook(db, me, with_mira, reef).unwrap();
    std::thread::sleep(Duration::from_millis(5));
    chats::add_lorebook(db, me, with_mira, harbour).unwrap();
    assert_eq!(
        taken(&scratch, with_mira)
            .into_iter()
            .map(|book| book.0)
            .collect::<Vec<_>>(),
        ["coast", "Harbour", "Reef"]
    );
    assert_eq!(
        ids(&scratch, with_mira)[3..],
        [harbours.as_slice(), &[of(reef, "lorebook-reef")]].concat()
    );
    assert_eq!(count(db, "chat_lorebooks"), 3);
    // One book without a budget lifts the limit for all.
    assert_eq!(book_of(with_mira).token_budget, 0);
    assert_eq!(
        chats::prompt_inputs(db, me, with_mira, None)
            .unwrap()
            .library,
        [harbour, reef]
    );

    // Switched off, nothing of it reaches the prompt, and its budget no longer counts.
    let set =
        |source, reference: &str, on| chats::set_lore(db, me, with_mira, source, reference, on);
    let listed = set(LoreSource::LorebookId(reef), "lorebook.lorebook", false).unwrap();
    assert_eq!(listed, chats::lorebooks(db, me, with_mira).unwrap());
    assert_eq!(
        taken(&scratch, with_mira)[2],
        ("Reef".to_string(), false, vec![], false)
    );
    assert_eq!(
        ids(&scratch, with_mira),
        [own.as_slice(), harbours.as_slice()].concat()
    );
    assert_eq!(book_of(with_mira).token_budget, 800);
    set(LoreSource::LorebookId(reef), "lorebook.lorebook", true).unwrap();
    assert_eq!(ids(&scratch, with_mira).len(), 6);
    // With its only entry left out it counts for as little.
    set(LoreSource::LorebookId(reef), "lore.lorebook-reef", false).unwrap();
    assert_eq!(
        (
            ids(&scratch, with_mira).len(),
            book_of(with_mira).token_budget
        ),
        (5, 800)
    );
    set(LoreSource::LorebookId(reef), "lore.lorebook-reef", true).unwrap();

    // One entry left out is listed with its lorebook, and comes back.
    let listed = set(LoreSource::LorebookId(harbour), "lore.harbour-bell", false).unwrap();
    let bell = Lore {
        source: LoreSource::LorebookId(harbour),
        reference: "lore.harbour-bell".into(),
        name: "Bell".into(),
    };
    assert_eq!(
        listed[1],
        ChatLorebook {
            removed: vec![bell],
            ..whole.clone()
        }
    );
    assert_eq!(
        ids(&scratch, with_mira)[3..],
        [of(harbour, "harbour-pier"), of(reef, "lorebook-reef")]
    );
    // In the other chat it is still in.
    assert_eq!(ids(&scratch, with_bare), harbours);
    // A card's lore of the same name is another thing.
    set(card, "lore.lamp", false).unwrap();
    assert_eq!(
        taken(&scratch, with_mira)[0],
        ("coast".to_string(), true, vec!["lamp".to_string()], false)
    );
    set(card, "lore.lamp", true).unwrap();

    // What the chat does not have is refused.
    let unknown = [
        (LoreSource::LorebookId(harbour), "lore.lamp"),
        (LoreSource::LorebookId(harbour), "lorebook.lorebook"),
        (LoreSource::LorebookId(harbour), "lore.lorebook-reef"),
        (LoreSource::LorebookId(99), "lorebook.harbour"),
        (card, "lore.harbour-bell"),
        (LoreSource::CardId(harbour), "lorebook.harbour"),
    ];
    for (source, reference) in unknown {
        let error = set(source, reference, false).unwrap_err();
        assert_eq!(
            error.to_string(),
            "the chat has no such lorebook or lorebook entry",
            "{source:?} {reference}"
        );
    }
    assert_eq!(count(db, "chat_lorebook_off"), 1);

    // Let go, it is gone from the chat with what was left out of it; taken again, it is whole.
    let listed = chats::remove_lorebook(db, me, with_mira, harbour).unwrap();
    assert_eq!(listed, chats::lorebooks(db, me, with_mira).unwrap());
    assert_eq!(
        taken(&scratch, with_mira)
            .into_iter()
            .map(|book| book.0)
            .collect::<Vec<_>>(),
        ["coast", "Reef"]
    );
    assert_eq!(count(db, "chat_lorebook_off"), 0);
    assert_eq!(
        chats::remove_lorebook(db, me, with_mira, harbour)
            .unwrap_err()
            .to_string(),
        "the chat has no such lorebook"
    );
    assert!(set(LoreSource::LorebookId(harbour), "lore.harbour-bell", true).is_err());
    assert_eq!(names(&scratch, "", Show::All), ["Harbour", "Reef"]);
    chats::add_lorebook(db, me, with_mira, harbour).unwrap();
    assert_eq!(
        taken(&scratch, with_mira)[2],
        ("Harbour".to_string(), true, vec![], false)
    );
    assert!(
        chats::add_lorebook(db, me, with_mira, 99)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        chats::add_lorebook(db, me, 99, harbour)
            .unwrap_err()
            .is::<NotFound>()
    );
}

#[test]
fn a_chat_keeps_a_lorebook_that_is_archived_or_in_the_trash_until_it_is_deleted_for_good() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let harbour = import(&scratch, &harbour(), "h.json").id;
    let chat_id = chat(&scratch, "bare");
    let other = chat(&scratch, "bare");
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    chats::set_lore(
        db,
        me,
        chat_id,
        LoreSource::LorebookId(harbour),
        "lore.harbour-pier",
        false,
    )
    .unwrap();

    lorebooks::set_archived(db, me, harbour, true).unwrap();
    assert_eq!(
        taken(&scratch, chat_id),
        [("Harbour".to_string(), true, vec!["Pier".to_string()], false)]
    );
    assert_eq!(ids(&scratch, chat_id).len(), 1);
    // An archived one is still taken where it is asked for.
    chats::add_lorebook(db, me, other, harbour).unwrap();
    chats::remove_lorebook(db, me, other, harbour).unwrap();

    // In the Trash the chat that has it keeps it, and shows that; no other chat is given it.
    lorebooks::set_trashed(db, me, harbour, true).unwrap();
    assert_eq!(
        taken(&scratch, chat_id),
        [("Harbour".to_string(), true, vec!["Pier".to_string()], true)]
    );
    assert_eq!(ids(&scratch, chat_id).len(), 1);
    let error = chats::add_lorebook(db, me, other, harbour).unwrap_err();
    assert_eq!(
        error.to_string(),
        "the lorebook “Harbour” is in the Trash; restore it to use it"
    );
    assert_eq!(taken(&scratch, other), []);
    // Restored, nothing has changed in the chat.
    lorebooks::set_trashed(db, me, harbour, false).unwrap();
    assert_eq!(
        taken(&scratch, chat_id),
        [("Harbour".to_string(), true, vec!["Pier".to_string()], false)]
    );

    // Deleted for good, it is gone from the chat with what was left out of it.
    lorebooks::set_trashed(db, me, harbour, true).unwrap();
    trash::delete_lorebook(db, me, harbour).unwrap();
    assert_eq!(
        (taken(&scratch, chat_id), ids(&scratch, chat_id)),
        (vec![], vec![])
    );
    assert_eq!(
        (count(db, "chat_lorebooks"), count(db, "chat_lorebook_off")),
        (0, 0)
    );
}

#[test]
fn a_chat_in_the_trash_takes_and_lets_go_of_no_lorebook_and_what_it_took_goes_with_it() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let harbour = import(&scratch, &harbour(), "h.json").id;
    let reef = import(
        &scratch,
        &world(&[entry("Reef", &["reef"], "The reef shows at low water.")]),
        "Reef.json",
    )
    .id;
    let chat_id = chat(&scratch, "bare");
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    chats::set_lore(
        db,
        me,
        chat_id,
        LoreSource::LorebookId(harbour),
        "lore.harbour-pier",
        false,
    )
    .unwrap();
    chats::set_trashed(db, me, chat_id, true).unwrap();

    let in_trash = "the chat is in the Trash; restore it first";
    assert_eq!(
        chats::add_lorebook(db, me, chat_id, reef)
            .unwrap_err()
            .to_string(),
        in_trash
    );
    assert_eq!(
        chats::remove_lorebook(db, me, chat_id, harbour)
            .unwrap_err()
            .to_string(),
        in_trash
    );
    let switched = chats::set_lore(
        db,
        me,
        chat_id,
        LoreSource::LorebookId(harbour),
        "lorebook.harbour",
        false,
    );
    assert_eq!(switched.unwrap_err().to_string(), in_trash);
    // It is still read as it was.
    assert_eq!(
        taken(&scratch, chat_id),
        [("Harbour".to_string(), true, vec!["Pier".to_string()], false)]
    );

    trash::delete_chat(db, me, chat_id).unwrap();
    assert_eq!(
        (count(db, "chat_lorebooks"), count(db, "chat_lorebook_off")),
        (0, 0)
    );
    assert_eq!(names(&scratch, "", Show::All), ["Harbour", "Reef"]);
}

#[test]
fn a_reply_notes_the_entries_of_the_library_it_was_given_by_their_lorebook() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let harbour = import(&scratch, &harbour(), "h.json").id;
    // Its number is the start of the other's: what is noted must not take one for the other.
    let mut tenth = harbour;
    while tenth != harbour * 10 + 1 {
        tenth = import(
            &scratch,
            &world(&[entry("Reef", &["reef"], "The reef shows at low water.")]),
            "Reef.json",
        )
        .id;
    }
    let chat_id = chat(&scratch, "mira");
    chats::add_lorebook(db, me, chat_id, harbour).unwrap();
    chats::add_lorebook(db, me, chat_id, tenth).unwrap();
    let inputs = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    let message = chats::get(db, me, chat_id)
        .unwrap()
        .unwrap()
        .head_id
        .unwrap();

    let given = [
        format!(".{harbour}.lore.harbour-bell"),
        "lore.lamp".to_string(),
        format!(".{tenth}.lore.lorebook-reef"),
        "lore.nothing".to_string(),
    ];
    chats::save_used(
        db,
        me,
        message,
        &inputs,
        &given,
        (
            chats::ContextUse { used: 1, size: 2 },
            chats::Sent::default(),
        ),
    )
    .unwrap();
    let lore = |source, reference: &str, name: &str| Lore {
        source,
        reference: reference.into(),
        name: name.into(),
    };
    let noted = [
        lore(LoreSource::LorebookId(harbour), "lore.harbour-bell", "Bell"),
        lore(
            LoreSource::CardId(inputs.card_id.unwrap()),
            "lore.lamp",
            "lamp",
        ),
        lore(LoreSource::LorebookId(tenth), "lore.lorebook-reef", "Reef"),
    ];
    assert_eq!(chats::view(db, me, message).unwrap().lore, noted);
}

//! A lorebook's editor: what it shows of a lorebook of the library, and its
//! edits written into the lorebook's file, in which what the editor does not
//! show stays as it is written.
//!
//! `NOTED` is a lorebook written by hand, with comments, a list on lines of
//! its own, keys the editor does not show and an entry of every kind: `wreck`
//! (secondary keywords that count, a filter in a table of its own), `lamp`
//! (every setting another than a new entry has, and secondary keywords that
//! do not count, with what they would ask for), `gone`, which the lorebook lists and has no block for, and
//! `stray`, a block the lorebook does not list. `plant` keeps it as a lorebook
//! of the library, `file` reads a lorebook's file as it is kept, `only` makes
//! a change of one thing, `shown` is the editor's entry by its reference, and
//! `chat` starts a chat that took the lorebook along, whose prompts `book`
//! reads; all of them are `common/lorebook_edit.rs`'s. The library's list,
//! edits made at once, HTTP and a lorebook made from scratch are `lorebook_edit_more.rs`'s.

mod common;

use common::Scratch;
use common::lorebook_edit::*;
use cw_accounts::users;
use cw_ccv4::lore::{EditEntry, EntryChange, RemovedEntry, Trigger};
use cw_chat::chats::{self, LoreSource};
use cw_core::NotFound;
use cw_library::lorebooks;
use cw_prompt::SelectiveLogic;
use serde_json::json;

#[test]
fn the_editor_shows_a_lorebook_with_its_entries_as_they_are_written() {
    let scratch = Scratch::new();
    let id = plant(&scratch, NOTED);
    let shown = lorebooks::editable(&scratch.db, scratch.user, id).unwrap();
    // The name is the library's; the description is the file's, in full.
    assert_eq!(
        (shown.id, shown.name.as_str(), shown.description.as_str()),
        (id, "Coast", "Of the coast and its lights.")
    );
    // An entry the lorebook lists without a block is none, and neither is a block it does not list.
    assert_eq!(shown.entries, [wreck(), lamp()]);
    // What a new entry begins with: what an entry is without a word, but for its order.
    assert_eq!(
        shown.blank,
        EditEntry {
            reference: String::new(),
            label: String::new(),
            name: String::new(),
            trigger: Trigger::Keyword,
            keywords: vec![],
            content: String::new(),
            enabled: true,
            at_depth: false,
            depth: 4,
            order: 100,
            secondary: vec![],
            logic: SelectiveLogic::AndAny,
            probability: 100,
            scan_depth: 0,
            case_sensitive: false,
            whole_words: false,
        }
    );

    // What a file says wildly reads as what the prompt makes of it: a chance of 100 at most, an order a number
    // holds, the depth of an entry that names none where its own is none, and the lorebook's scan depth.
    let wild = NOTED
        .replace("probability = 30", "probability = 250")
        .replace("insertion-order = 40", "insertion-order = 9000000000")
        .replace("depth = 3", "depth = -1")
        .replace("scan-depth = 2", "scan-depth = -4")
        .replace(
            "sticky = 2",
            "sticky = 2\nscan-depth = 0\ninsertion-order = -9000000000",
        )
        .replace(
            "description = \"Of the coast and its lights.\"",
            "description = \"  Of the coast\\r\\nand its lights.\\n\"",
        );
    let wild = plant(&scratch, &wild);
    let read = lorebooks::editable(&scratch.db, scratch.user, wild).unwrap();
    assert_eq!(read.description, "Of the coast\nand its lights.");
    let [wreck, lamp] = read.entries.as_slice() else {
        panic!("{} entries", read.entries.len())
    };
    assert_eq!(
        (
            lamp.probability,
            lamp.order,
            lamp.at_depth,
            lamp.depth,
            lamp.scan_depth
        ),
        (100, i32::MAX, true, 4, 0)
    );
    // A chance below nothing is none the prompt reads, so the entry is always used when it applies, and shows so.
    let below = plant(
        &scratch,
        &NOTED.replace("probability = 30", "probability = -5"),
    );
    let read = lorebooks::editable(&scratch.db, scratch.user, below).unwrap();
    assert_eq!(read.entries[1].probability, 100);
    assert_eq!(book(&scratch, chat(&scratch, below))[1].probability, 100);
    assert_eq!((wreck.order, wreck.scan_depth), (i32::MIN, 0));
    // A scan depth of nothing is the lorebook's for the prompt too.
    let chat_id = chat(&scratch, wild);
    assert_eq!(book(&scratch, chat_id)[0].scan_depth, None);

    // What a file from SillyTavern says is shown the same way.
    let world = json!({ "entries": {
        "0": { "key": ["tide"], "comment": "Tide", "content": "  The tide turns at six.\r\n", "vectorized": true,
               "order": 12, "scanDepth": 3, "position": 4, "depth": 0, "probability": 250, "useProbability": true },
        "1": { "key": ["gull"], "keysecondary": ["nest", "egg"], "selective": true, "selectiveLogic": 3,
               "content": "Gulls.", "disable": true },
    }});
    let made = lorebooks::import(
        &scratch.db,
        scratch.user,
        world.to_string().as_bytes(),
        "Shore.json",
    );
    let shore = made.unwrap().lorebook.id;
    let tide = shown_of(&scratch, shore, 0);
    assert_eq!(
        (tide.label.as_str(), tide.trigger, tide.content.as_str()),
        ("Tide", Trigger::Vector, "The tide turns at six.")
    );
    assert_eq!(
        (
            tide.order,
            tide.scan_depth,
            tide.at_depth,
            tide.depth,
            tide.probability
        ),
        (12, 3, true, 0, 100)
    );
    let gull = shown_of(&scratch, shore, 1);
    assert_eq!(
        (gull.label.as_str(), gull.name.as_str(), gull.enabled),
        ("gull", "", false)
    );
    assert_eq!(
        (gull.secondary, gull.logic, gull.order),
        (strings(&["nest", "egg"]), SelectiveLogic::AndAll, 100)
    );
}

/// The entry number `at` of a lorebook, as the editor shows it.
fn shown_of(scratch: &Scratch, id: i64, at: usize) -> EditEntry {
    let shown = lorebooks::editable(&scratch.db, scratch.user, id).unwrap();
    shown.entries.into_iter().nth(at).unwrap()
}

#[test]
fn an_edit_writes_what_it_changes_and_leaves_the_file_as_it_is_written() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    // The file ends its lines as Windows does: an edit that changes nothing leaves it so, to the letter.
    let windows = NOTED.replace('\n', "\r\n");
    let id = plant(&scratch, &windows);
    let same = EntryChange {
        name: Some("  The   wreck ".into()),
        trigger: Some(Trigger::Keyword),
        keywords: Some(strings(&[" wreck", "Asta ", "", "wreck"])),
        content: Some("\nThe Asta sank here in 1911.\r\n\n".into()),
        enabled: Some(true),
        at_depth: Some(false),
        // Without a place at a depth, the depth says nothing.
        depth: Some(9),
        order: Some(0),
        secondary: Some(strings(&["storm", "night"])),
        logic: Some(SelectiveLogic::NotAny),
        probability: Some(100),
        scan_depth: Some(0),
        case_sensitive: Some(false),
        whole_words: Some(false),
    };
    assert_eq!(
        lorebooks::change_entry(db, user, id, "lore.wreck", &same).unwrap(),
        wreck()
    );
    let nothing = EntryChange::default();
    assert_eq!(
        lorebooks::change_entry(db, user, id, "lore.lamp", &nothing).unwrap(),
        lamp()
    );
    // Nor does a name and a description the lorebook has already.
    lorebooks::describe(
        db,
        user,
        id,
        Some("North Coast"),
        Some(" Of the coast and its lights.\n"),
        [None; 2],
    )
    .unwrap();
    assert_eq!(file(&scratch, id), windows);

    // A change is the line it is of: the comments, the order, the other keys and entries stay.
    let id = plant(&scratch, NOTED);
    let text = only(|change| change.content = Some("The Asta sank here in 1912.".into()));
    let answered = lorebooks::change_entry(db, user, id, "lore.wreck", &text).unwrap();
    let mut expected = wreck();
    expected.content = "The Asta sank here in 1912.".into();
    assert_eq!(answered, expected);
    let mut after = NOTED.replace(
        "text = \"\"\"\nThe Asta sank here in 1911.\n\"\"\"\n",
        "text = \"The Asta sank here in 1912.\"\n",
    );
    assert_eq!(file(&scratch, id), after);

    let named = only(|change| change.name = Some("The Asta".into()));
    lorebooks::change_entry(db, user, id, "lore.wreck", &named).unwrap();
    after = after.replace(
        "name = \"The wreck\" # as the charts call it",
        "name = \"The Asta\" # as the charts call it",
    );
    assert_eq!(file(&scratch, id), after);

    let keys = only(|change| change.keywords = Some(strings(&["lamp", " light "])));
    lorebooks::change_entry(db, user, id, "lore.lamp", &keys).unwrap();
    after = after.replace("keywords = [\"lamp\"]", "keywords = [\"lamp\", \"light\"]");
    assert_eq!(file(&scratch, id), after);

    // A name taken away is no line, and the entry goes by its first keyword again.
    let unnamed = only(|change| change.name = Some(" ".into()));
    let answered = lorebooks::change_entry(db, user, id, "lore.wreck", &unnamed).unwrap();
    assert_eq!(
        (answered.name.as_str(), answered.label.as_str()),
        ("", "wreck")
    );
    after = after.replace("name = \"The Asta\" # as the charts call it\n", "");
    assert_eq!(file(&scratch, id), after);
}

#[test]
fn each_setting_is_written_as_the_prompt_reads_it_and_is_no_line_where_it_says_nothing() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let chat_id = chat(&scratch, id);

    // Every setting of the lamp is another than an entry has without it: set back, each is no line.
    let plain = EntryChange {
        trigger: Some(Trigger::Keyword),
        enabled: Some(true),
        at_depth: Some(false),
        probability: Some(100),
        scan_depth: Some(0),
        case_sensitive: Some(false),
        whole_words: Some(false),
        ..EntryChange::default()
    };
    let answered = lorebooks::change_entry(db, user, id, "lore.lamp", &plain).unwrap();
    let expected = EditEntry {
        trigger: Trigger::Keyword,
        enabled: true,
        at_depth: false,
        depth: 4,
        probability: 100,
        scan_depth: 0,
        case_sensitive: false,
        whole_words: false,
        ..lamp()
    };
    assert_eq!(answered, expected);
    // What the editor does not show stays: who speaks it, and the secondary keywords that do not count.
    let block = "[lore.lamp]\nkeywords = [\"lamp\"]\nsecondary-keywords = [\"oil\"]\nselective-logic = \"and-all\"\ninsertion-order = 40\nrole = \"user\"\ntext = \"The lamp burns whale oil.\"\n";
    assert!(file(&scratch, id).contains(block), "{}", file(&scratch, id));

    // Every setting of the wreck is as an entry has it without a word: each is written as the prompt reads it.
    let set = EntryChange {
        trigger: Some(Trigger::Vector),
        enabled: Some(false),
        at_depth: Some(true),
        order: Some(-7),
        secondary: Some(Vec::new()),
        probability: Some(0),
        scan_depth: Some(9),
        case_sensitive: Some(true),
        whole_words: Some(true),
        ..EntryChange::default()
    };
    let answered = lorebooks::change_entry(db, user, id, "lore.wreck", &set).unwrap();
    let expected = EditEntry {
        trigger: Trigger::Vector,
        enabled: false,
        at_depth: true,
        // The depth an entry has that names none.
        depth: 4,
        order: -7,
        secondary: Vec::new(),
        // Without secondary keywords there is nothing to choose.
        logic: SelectiveLogic::AndAny,
        probability: 0,
        scan_depth: 9,
        case_sensitive: true,
        whole_words: true,
        ..wreck()
    };
    assert_eq!(answered, expected);
    assert_eq!(shown(&scratch, id, "lore.wreck"), expected);
    let now = file(&scratch, id);
    for gone in [
        "secondary-keywords = [\"storm\"",
        "selective = true",
        "not-any",
    ] {
        assert!(!now.contains(gone), "{gone}: {now}");
    }
    let entries = book(&scratch, chat_id);
    let [wreck, lamp] = entries.as_slice() else {
        panic!("{} entries", entries.len())
    };
    assert!(
        !wreck.enabled && !wreck.constant && !wreck.selective && wreck.secondary_keys.is_empty()
    );
    assert_eq!(
        (
            wreck.at_depth,
            wreck.depth,
            wreck.insertion_order,
            wreck.probability
        ),
        (true, 4, -7, 0)
    );
    assert_eq!(wreck.scan_depth, Some(9));
    assert!(wreck.case_sensitive && wreck.match_whole_words);
    // What the editor does not show is still what the prompt reads.
    assert_eq!(
        (wreck.priority, wreck.sticky, wreck.use_regex),
        (5, 2, false)
    );
    assert_eq!(wreck.character_filter.as_ref().unwrap().names, ["Mira"]);
    assert!(lamp.enabled && !lamp.constant && !lamp.at_depth && !lamp.selective);
    assert_eq!(
        (lamp.probability, lamp.scan_depth, lamp.insertion_order),
        (100, None, 40)
    );
    assert!(!lamp.case_sensitive && !lamp.match_whole_words);

    // "Always" is the prompt's constant entry, and a depth is the one given.
    let always = EntryChange {
        trigger: Some(Trigger::Always),
        depth: Some(2),
        ..EntryChange::default()
    };
    lorebooks::change_entry(db, user, id, "lore.wreck", &always).unwrap();
    let entries = book(&scratch, chat_id);
    assert_eq!(
        (entries[0].constant, entries[0].at_depth, entries[0].depth),
        (true, true, 2)
    );

    // Secondary keywords given to an entry count, with what they ask for, in the place of those that did not.
    let second = EntryChange {
        secondary: Some(strings(&["tar", " tar ", "pitch"])),
        logic: Some(SelectiveLogic::NotAll),
        ..EntryChange::default()
    };
    let answered = lorebooks::change_entry(db, user, id, "lore.lamp", &second).unwrap();
    assert_eq!(
        (answered.secondary.clone(), answered.logic),
        (strings(&["tar", "pitch"]), SelectiveLogic::NotAll)
    );
    let entries = book(&scratch, chat_id);
    assert!(entries[1].selective);
    assert_eq!(entries[1].secondary_keys, ["tar", "pitch"]);
    assert_eq!(entries[1].selective_logic, SelectiveLogic::NotAll);
    for logic in [
        SelectiveLogic::AndAll,
        SelectiveLogic::NotAny,
        SelectiveLogic::AndAny,
    ] {
        let asked = only(|change| change.logic = Some(logic));
        let answered = lorebooks::change_entry(db, user, id, "lore.lamp", &asked).unwrap();
        assert_eq!(answered.logic, logic);
        assert_eq!(book(&scratch, chat_id)[1].selective_logic, logic);
    }
    // The one that holds without a word is no line.
    assert!(!file(&scratch, id).contains("selective-logic"));
}

#[test]
fn an_edit_is_refused_as_a_whole_where_it_cannot_be_made() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let long = "n".repeat(65);
    let named = |name: &str| EntryChange {
        name: Some(name.into()),
        content: Some("Other words.".into()),
        ..EntryChange::default()
    };
    assert_eq!(
        refused(&scratch, id, "lore.wreck", &named(&long)),
        "an entry's name has at most 64 characters"
    );
    let chance = EntryChange {
        probability: Some(101),
        content: Some("Other words.".into()),
        ..EntryChange::default()
    };
    assert_eq!(
        refused(&scratch, id, "lore.wreck", &chance),
        "an entry's chance is at most 100 percent"
    );
    // Nothing of a refused edit is written.
    assert_eq!(file(&scratch, id), NOTED);
    // A name of 64 signs is taken, counted as signs.
    let wave = "🌊".repeat(64);
    let answered = lorebooks::change_entry(db, user, id, "lore.wreck", &named(&wave)).unwrap();
    assert_eq!(answered.name, wave);

    // A name that is too long already stays while the entry's other words are changed.
    let long_named = plant(&scratch, &NOTED.replace("The wreck", &long));
    let words = only(|change| change.content = Some("Other words.".into()));
    let answered = lorebooks::change_entry(db, user, long_named, "lore.wreck", &words).unwrap();
    assert_eq!(
        (answered.name, answered.content.as_str()),
        (long.clone(), "Other words.")
    );

    // What is no entry of the lorebook is not found: a block it does not list, one it lists and has not, another kind.
    let id = plant(&scratch, NOTED);
    for reference in [
        "lore.stray",
        "lore.gone",
        "lore.nowhere",
        "lorebook.coast",
        "wreck",
        "",
    ] {
        let change = named("Other");
        let made = lorebooks::change_entry(db, user, id, reference, &change).unwrap_err();
        assert!(made.is::<NotFound>(), "{reference}: {made:#}");
        let gone = lorebooks::remove_entry(db, user, id, reference).unwrap_err();
        assert!(gone.is::<NotFound>(), "{reference}: {gone:#}");
    }
    assert_eq!(file(&scratch, id), NOTED);

    // Another user's lorebook is not found, and one in the Trash is not edited.
    let sam = users::create(db, "sam").unwrap();
    let change = named("Other");
    let removed = RemovedEntry {
        toml: "[lore.back]\nkeywords = []\ntext = \"Back.\"\n".into(),
        position: 0,
    };
    assert!(
        lorebooks::editable(db, sam, id)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::change_entry(db, sam, id, "lore.wreck", &change)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::add_entry(db, sam, id, &change)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::remove_entry(db, sam, id, "lore.wreck")
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::restore_entry(db, sam, id, &removed)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert!(
        lorebooks::describe(db, sam, id, Some("Theirs"), None, [None; 2])
            .unwrap_err()
            .is::<NotFound>()
    );
    lorebooks::set_trashed(db, user, id, true).unwrap();
    let trashed = "the lorebook “Coast” is in the Trash; restore it first";
    let why = |made: anyhow::Error| format!("{made:#}");
    assert_eq!(why(lorebooks::editable(db, user, id).unwrap_err()), trashed);
    assert_eq!(
        why(lorebooks::change_entry(db, user, id, "lore.wreck", &change).unwrap_err()),
        trashed
    );
    assert_eq!(
        why(lorebooks::add_entry(db, user, id, &change).unwrap_err()),
        trashed
    );
    assert_eq!(
        why(lorebooks::remove_entry(db, user, id, "lore.wreck").unwrap_err()),
        trashed
    );
    assert_eq!(
        why(lorebooks::restore_entry(db, user, id, &removed).unwrap_err()),
        trashed
    );
    assert_eq!(
        why(lorebooks::describe(db, user, id, Some("Mine"), None, [None; 2]).unwrap_err()),
        trashed
    );
    assert_eq!(file(&scratch, id), NOTED);
    // Back from the Trash it is edited again.
    lorebooks::set_trashed(db, user, id, false).unwrap();
    lorebooks::change_entry(db, user, id, "lore.wreck", &change).unwrap();
    assert_eq!(shown(&scratch, id, "lore.wreck").name, "Other");
}

#[test]
fn an_entry_is_added_as_the_last_under_an_id_of_its_own() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let chat_id = chat(&scratch, id);
    let new = EntryChange {
        name: Some("  The   Lamp ".into()),
        keywords: Some(strings(&["light", " beam "])),
        content: Some("It turns every ten seconds.\n".into()),
        ..EntryChange::default()
    };
    let added = lorebooks::add_entry(db, user, id, &new).unwrap();
    let expected = EditEntry {
        // Its lorebook's ID with its name: `lore.lamp` is another entry.
        reference: "lore.coast-the-lamp".into(),
        label: "The Lamp".into(),
        name: "The Lamp".into(),
        trigger: Trigger::Keyword,
        keywords: strings(&["light", "beam"]),
        content: "It turns every ten seconds.".into(),
        enabled: true,
        at_depth: false,
        depth: 4,
        // As an entry from SillyTavern that names no order.
        order: 100,
        secondary: Vec::new(),
        logic: SelectiveLogic::AndAny,
        probability: 100,
        scan_depth: 0,
        case_sensitive: false,
        whole_words: false,
    };
    assert_eq!(added, expected);
    assert_eq!(
        listed(&scratch, id),
        ["lore.wreck", "lore.lamp", "lore.coast-the-lamp"]
    );
    // It is a block of its own at the file's end, with what it says and nothing that goes without saying.
    let block = "\n[lore.coast-the-lamp]\nname = \"The Lamp\"\nkeywords = [\"light\", \"beam\"]\ninsertion-order = 100\ntext = \"It turns every ten seconds.\"\n";
    let now = file(&scratch, id);
    assert!(now.ends_with(block), "{now}");
    // The list keeps its lines, and what the lorebook lists without a block stays listed.
    let list = "entries = [\n    \"lore.wreck\",\n    \"lore.lamp\",\n    \"lore.gone\",\n    \"lore.coast-the-lamp\",\n]\n";
    assert!(now.contains(list), "{now}");
    // A chat that has the lorebook has the entry from its next reply on.
    let entries = book(&scratch, chat_id);
    assert_eq!(entries.len(), 3);
    assert_eq!(
        (entries[2].name.as_str(), entries[2].insertion_order),
        ("The Lamp", 100)
    );

    // The same name again is another entry, and so is a name that makes the ID of a block that is there.
    let again = lorebooks::add_entry(db, user, id, &new).unwrap();
    assert_eq!(again.reference, "lore.coast-the-lamp-2");
    let third = lorebooks::add_entry(
        db,
        user,
        id,
        &only(|change| change.name = Some("the lamp!".into())),
    )
    .unwrap();
    assert_eq!(third.reference, "lore.coast-the-lamp-3");
    // A new entry begins with what it is given, whatever that is.
    let full = EntryChange {
        name: Some("Ünnamed ¿".into()),
        trigger: Some(Trigger::Always),
        enabled: Some(false),
        at_depth: Some(true),
        depth: Some(1),
        order: Some(3),
        secondary: Some(strings(&["dusk"])),
        logic: Some(SelectiveLogic::AndAll),
        probability: Some(50),
        scan_depth: Some(8),
        case_sensitive: Some(true),
        whole_words: Some(true),
        ..EntryChange::default()
    };
    let made = lorebooks::add_entry(db, user, id, &full).unwrap();
    assert_eq!(made.reference, "lore.coast-nnamed");
    assert_eq!(
        (
            made.trigger,
            made.enabled,
            made.at_depth,
            made.depth,
            made.order
        ),
        (Trigger::Always, false, true, 1, 3)
    );
    assert_eq!(
        (
            made.secondary.clone(),
            made.logic,
            made.probability,
            made.scan_depth
        ),
        (strings(&["dusk"]), SelectiveLogic::AndAll, 50, 8)
    );
    assert!(made.case_sensitive && made.whole_words && made.keywords.is_empty());
    // A name without a letter of the alphabet makes no ID of its own.
    let signs = lorebooks::add_entry(
        db,
        user,
        id,
        &only(|change| change.name = Some("灯台".into())),
    )
    .unwrap();
    assert_eq!(
        (signs.reference.as_str(), signs.label.as_str()),
        ("lore.coast-entry", "灯台")
    );

    // An entry needs a name, and nothing is written without one.
    let before = file(&scratch, id);
    for name in [None, Some(String::new()), Some(" \n ".to_string())] {
        let nameless = EntryChange {
            name,
            keywords: Some(strings(&["key"])),
            ..EntryChange::default()
        };
        let made = lorebooks::add_entry(db, user, id, &nameless).unwrap_err();
        assert_eq!(format!("{made:#}"), "an entry needs a name");
    }
    assert_eq!(file(&scratch, id), before);
}

#[test]
fn an_entry_taken_out_is_put_back_as_it_was_written_and_where_it_stood() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let chat_id = chat(&scratch, id);
    // The chat leaves the wreck out.
    let source = LoreSource::LorebookId(id);
    chats::set_lore(db, user, chat_id, source, "lore.wreck", false).unwrap();
    let names = |scratch: &Scratch| -> Vec<String> {
        let entries = book(scratch, chat_id).into_iter();
        entries.map(|entry| entry.name).collect()
    };
    assert_eq!(names(&scratch), ["lamp"]);

    let removed = lorebooks::remove_entry(db, user, id, "lore.wreck").unwrap();
    assert_eq!(removed.position, 0);
    // What puts it back is the block as it was written, with the table under it.
    let block = "\n# Sank in 1911.\n[lore.wreck]\nname = \"The wreck\" # as the charts call it\nkeywords = [\"wreck\", \"Asta\"]\nsecondary-keywords = [\"storm\", \"night\"]\nselective = true\nselective-logic = \"not-any\"\npriority = 5\nsticky = 2\nuse-regex = false\ntext = \"\"\"\nThe Asta sank here in 1911.\n\"\"\"\n\n[lore.wreck.character-filter]\nnames = [\"Mira\"]\ntags = []\nexclude = true\n";
    assert_eq!(removed.toml, block);
    assert_eq!(listed(&scratch, id), ["lore.lamp"]);
    let now = file(&scratch, id);
    assert!(!now.contains("wreck") && !now.contains("Mira"), "{now}");
    // The other entries and what the lorebook lists without a block stay as written.
    assert!(
        now.contains("entries = [\n    \"lore.lamp\",\n    \"lore.gone\",\n]\n"),
        "{now}"
    );
    assert!(now.contains("[lore.lamp]\nkeywords = [\"lamp\"]\n") && now.contains("[lore.stray]\n"));
    // It is gone for the library's list and for the chat.
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.entries, kept.entry_names.clone()),
        (1, strings(&["lamp"]))
    );
    assert_eq!(names(&scratch), ["lamp"]);
    // Gone, it is no entry to change or to take out.
    assert!(
        lorebooks::remove_entry(db, user, id, "lore.wreck")
            .unwrap_err()
            .is::<NotFound>()
    );

    let back = lorebooks::restore_entry(db, user, id, &removed).unwrap();
    assert_eq!(back, wreck());
    assert_eq!(listed(&scratch, id), ["lore.wreck", "lore.lamp"]);
    let now = file(&scratch, id);
    assert!(
        now.contains(
            "entries = [\n    \"lore.wreck\",\n    \"lore.lamp\",\n    \"lore.gone\",\n]\n"
        ),
        "{now}"
    );
    // It is the block that was taken out, to the letter, at the file's end: its comments, the keys the editor
    // does not show, and the table under it right behind it.
    assert!(now.ends_with(&removed.toml), "{now}");
    let kept = lorebooks::get(db, user, id).unwrap().unwrap();
    assert_eq!(
        (kept.entries, kept.entry_names.clone()),
        (2, strings(&["The wreck", "lamp"]))
    );
    // The chat still leaves it out, and has it once that is taken back.
    assert_eq!(names(&scratch), ["lamp"]);
    chats::set_lore(db, user, chat_id, source, "lore.wreck", true).unwrap();
    assert_eq!(names(&scratch), ["The wreck", "lamp"]);

    // It is put back once: its ID is an entry's by then.
    let twice = lorebooks::restore_entry(db, user, id, &removed).unwrap_err();
    assert_eq!(
        format!("{twice:#}"),
        "the lorebook has another entry lore.wreck by now"
    );
    // Further down than the lorebook has entries, it is the last.
    let lamp = lorebooks::remove_entry(db, user, id, "lore.lamp").unwrap();
    assert_eq!(lamp.position, 1);
    let far = RemovedEntry {
        position: 40,
        ..lamp
    };
    lorebooks::restore_entry(db, user, id, &far).unwrap();
    assert!(file(&scratch, id).contains("    \"lore.gone\",\n    \"lore.lamp\",\n]\n"));
    assert_eq!(listed(&scratch, id), ["lore.wreck", "lore.lamp"]);
}

#[test]
fn an_id_a_chat_has_left_out_is_no_new_entrys() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let chat_id = chat(&scratch, id);
    // An entry is made, left out by the chat and taken out.
    let new = only(|change| change.name = Some("Reef".into()));
    let reef = lorebooks::add_entry(db, user, id, &new).unwrap();
    assert_eq!(reef.reference, "lore.coast-reef");
    chats::set_lore(
        db,
        user,
        chat_id,
        LoreSource::LorebookId(id),
        "lore.coast-reef",
        false,
    )
    .unwrap();
    let removed = lorebooks::remove_entry(db, user, id, "lore.coast-reef").unwrap();
    // Another entry of that name is not the one the chat left out: the chat has it.
    let second = lorebooks::add_entry(db, user, id, &new).unwrap();
    assert_eq!(second.reference, "lore.coast-reef-2");
    let ids = |scratch: &Scratch| -> Vec<String> {
        let entries = book(scratch, chat_id).into_iter();
        entries.filter_map(|entry| entry.id).collect()
    };
    let key = format!(".{id}.");
    assert!(ids(&scratch).contains(&format!("{key}lore.coast-reef-2")));
    // And the first, put back, is left out still.
    lorebooks::restore_entry(db, user, id, &removed).unwrap();
    assert!(!ids(&scratch).contains(&format!("{key}lore.coast-reef")));
    assert_eq!(listed(&scratch, id).len(), 4);
}

#[test]
fn what_is_no_entry_that_was_taken_out_is_not_put_into_a_lorebook() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let id = plant(&scratch, NOTED);
    let no_entry = "this is no lorebook entry that was taken out";
    for toml in [
        "",
        "not toml [",
        "name = \"bare\"\n",
        "[lorebook.other]\nentries = []\n",
        "[lore.one]\ntext = \"One.\"\n\n[lore.two]\ntext = \"Two.\"\n",
        "[lore.one]\ntext = \"One.\"\n\n[character.eve]\nprompt = []\n",
        "lore = \"words\"\n",
        "[lore]\none = 1\n",
        // A block without an ID, which no entry is read from.
        "[lore.\"\"]\ntext = \"None.\"\n",
    ] {
        let removed = RemovedEntry {
            toml: toml.into(),
            position: 0,
        };
        let made = lorebooks::restore_entry(db, user, id, &removed).unwrap_err();
        assert!(
            format!("{made:#}").starts_with(no_entry),
            "{toml}: {made:#}"
        );
    }
    // An entry that is there, as a block or in the list, is not written over.
    for (toml, reference) in [
        ("[lore.lamp]\ntext = \"Other.\"\n", "lore.lamp"),
        ("[lore.stray]\ntext = \"Other.\"\n", "lore.stray"),
        ("[lore.gone]\ntext = \"Other.\"\n", "lore.gone"),
    ] {
        let removed = RemovedEntry {
            toml: toml.into(),
            position: 0,
        };
        let made = lorebooks::restore_entry(db, user, id, &removed).unwrap_err();
        assert_eq!(
            format!("{made:#}"),
            format!("the lorebook has another entry {reference} by now")
        );
    }
    assert_eq!(file(&scratch, id), NOTED);
}

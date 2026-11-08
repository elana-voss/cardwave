//! Lorebook activation. The Flutter app had no unit tests for this, so these
//! pin down the behaviour of its `lorebook_service.dart`, and what was added
//! to it here: an entry's own scan depth.

use cw_prompt::lorebook::{commit_timed_effects, evaluate};
use cw_prompt::{
    Character, CharacterFilter, ChatMessage, ChatState, Lorebook, LorebookEntry, Role,
    SelectiveLogic,
};

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| s.to_string()).collect()
}

fn entry(keys: &[&str], content: &str) -> LorebookEntry {
    LorebookEntry {
        keys: strings(keys),
        content: content.into(),
        ..Default::default()
    }
}

fn character(entries: Vec<LorebookEntry>) -> Character {
    Character {
        name: "Cass".into(),
        lorebook: Some(Lorebook {
            entries,
            ..Default::default()
        }),
        ..Default::default()
    }
}

/// A chat with the given messages, user and assistant taking turns.
fn chat(lines: &[&str]) -> ChatState {
    let mut chat = ChatState::default();
    for line in lines {
        say(&mut chat, line);
    }
    chat
}

fn say(chat: &mut ChatState, line: &str) {
    let n = chat.messages.len();
    let role = if n.is_multiple_of(2) {
        Role::User
    } else {
        Role::Assistant
    };
    chat.messages
        .push(ChatMessage::new(n.to_string(), role, line));
}

/// Contents of the entries active for the chat, in budget order.
fn active(character: &Character, chat: &mut ChatState) -> Vec<String> {
    evaluate(character, chat)
        .into_iter()
        .map(|a| a.content)
        .collect()
}

/// Whether a single entry is active when the chat's only message is `line`.
fn triggers(entry: LorebookEntry, line: &str) -> bool {
    !active(&character(vec![entry]), &mut chat(&[line])).is_empty()
}

#[test]
fn a_key_in_recent_messages_activates_the_entry() {
    let c = character(vec![
        entry(&["zarquon"], "Zarquon is a moon."),
        entry(&["other"], "No."),
    ]);
    assert_eq!(
        active(&c, &mut chat(&["Tell me about ZARQUON."])),
        ["Zarquon is a moon."]
    );
    assert!(active(&c, &mut chat(&["Tell me about the sun."])).is_empty());
}

#[test]
fn an_entry_used_by_meaning_goes_by_what_the_search_model_tells_else_by_its_keys() {
    let meant = |id: &str, keys: &[&str], content: &str| LorebookEntry {
        id: Some(id.into()),
        by_meaning: true,
        ..entry(keys, content)
    };
    let c = character(vec![
        meant("lore.harbor", &["harbor"], "Saltmere's harbor freezes."),
        meant("lore.sword", &["sword"], "Dawnbreaker glows."),
    ]);
    let mut told = chat(&["The boats are pulled up on the stones."]);
    told.meaning = Some(["lore.harbor".to_string()].into());
    assert_eq!(active(&c, &mut told), ["Saltmere's harbor freezes."]);
    // A keyword does not count where the meaning is known.
    let mut told = chat(&["My sword is shining."]);
    told.meaning = Some(Default::default());
    assert!(active(&c, &mut told).is_empty());
    // Without the search model it goes by its keywords, as before.
    assert_eq!(
        active(&c, &mut chat(&["My sword is shining."])),
        ["Dawnbreaker glows."]
    );
}

#[test]
fn no_lorebook_or_no_entries_gives_nothing() {
    assert!(active(&Character::default(), &mut chat(&["hi"])).is_empty());
    assert!(active(&character(vec![]), &mut chat(&["hi"])).is_empty());
}

#[test]
fn an_entry_with_a_scan_depth_of_its_own_is_read_for_in_that_many_messages() {
    let deep = |depth| LorebookEntry {
        scan_depth: depth,
        ..entry(&["dragon"], "Dragons.")
    };
    let lines = ["a dragon", "two", "three", "four", "five", "six"];
    // The lorebook reads the newest four, and so does an entry that names no number.
    assert!(active(&character(vec![deep(None)]), &mut chat(&lines)).is_empty());
    assert!(active(&character(vec![deep(Some(5))]), &mut chat(&lines)).is_empty());
    assert_eq!(
        active(&character(vec![deep(Some(6))]), &mut chat(&lines)),
        ["Dragons."]
    );
    // An entry's own number counts for less too, and beside another entry's.
    let near = ["one", "two", "three", "a dragon", "five", "six"];
    let both = character(vec![deep(Some(2)), entry(&["dragon"], "Wyrms.")]);
    assert_eq!(active(&both, &mut chat(&near)), ["Wyrms."]);
    let both = character(vec![deep(Some(3)), entry(&["dragon"], "Wyrms.")]);
    assert_eq!(active(&both, &mut chat(&near)), ["Dragons.", "Wyrms."]);
}

#[test]
fn only_the_newest_messages_are_scanned() {
    let mut c = character(vec![entry(&["dragon"], "Dragons.")]);
    let mut old = chat(&["a dragon", "two", "three", "four", "five"]);
    assert!(active(&c, &mut old).is_empty());
    assert_eq!(
        active(&c, &mut chat(&["one", "a dragon", "three", "four", "five"])),
        ["Dragons."]
    );

    c.lorebook.as_mut().unwrap().scan_depth = Some(5);
    assert_eq!(active(&c, &mut old), ["Dragons."]);
}

#[test]
fn disabled_empty_and_keyless_entries_stay_out() {
    assert!(!triggers(
        LorebookEntry {
            enabled: false,
            ..entry(&["dragon"], "x")
        },
        "dragon"
    ));
    assert!(!triggers(entry(&["dragon"], "   "), "dragon"));
    assert!(!triggers(entry(&[], "x"), "dragon"));
    assert!(!triggers(entry(&[""], "x"), "dragon"));
}

#[test]
fn constant_entries_need_no_key() {
    assert!(triggers(
        LorebookEntry {
            constant: true,
            ..entry(&[], "Always.")
        },
        "anything"
    ));
}

#[test]
fn case_sensitive_keys() {
    let sensitive = || LorebookEntry {
        case_sensitive: true,
        ..entry(&["Dragon"], "x")
    };
    assert!(triggers(sensitive(), "a Dragon"));
    assert!(!triggers(sensitive(), "a dragon"));
}

#[test]
fn whole_word_keys() {
    let whole = |key: &str| LorebookEntry {
        match_whole_words: true,
        ..entry(&[key], "x")
    };
    assert!(triggers(whole("cat"), "A Cat."));
    assert!(triggers(whole("cat"), "cat"));
    assert!(!triggers(whole("cat"), "concatenate"));
    assert!(triggers(whole("c.t"), "a c.t here"));
    assert!(!triggers(whole("c.t"), "a cat here"));
    // No spaces between words in Japanese: the key still matches in running text.
    assert!(triggers(whole("猫"), "黒猫だ"));
}

#[test]
fn regex_keys() {
    let regex = |key: &str| LorebookEntry {
        use_regex: true,
        ..entry(&[key], "x")
    };
    assert!(triggers(regex("drag(on|ons)"), "two DRAGONS"));
    assert!(triggers(regex("/drag(on|ons)\\b/i"), "two DRAGONS"));
    assert!(!triggers(regex("/dragon$/"), "dragon\nfire"));
    assert!(triggers(regex("/dragon$/m"), "dragon\nfire"));
    assert!(triggers(regex("/a.b/s"), "a\nb"));
    assert!(triggers(regex("/1\\/2/"), "mix 1/2 cup"));
    // JavaScript features the plain Rust engine lacks.
    assert!(triggers(regex("/foo(?=bar)/"), "foobar"));
    assert!(triggers(regex("/(na)\\1/"), "banana nana"));
    // A broken pattern is no match, not an error.
    assert!(!triggers(regex("/(/"), "("));

    let sensitive = LorebookEntry {
        case_sensitive: true,
        ..regex("/dragon/")
    };
    assert!(!triggers(sensitive.clone(), "DRAGON"));
    assert!(triggers(
        LorebookEntry {
            keys: strings(&["/dragon/i"]),
            ..sensitive
        },
        "DRAGON"
    ));
}

#[test]
fn secondary_keys() {
    let selective = |logic| LorebookEntry {
        selective: true,
        selective_logic: logic,
        secondary_keys: strings(&["red", "old"]),
        ..entry(&["dragon"], "x")
    };
    let cases = [
        (SelectiveLogic::AndAny, [false, true, true]),
        (SelectiveLogic::AndAll, [false, false, true]),
        (SelectiveLogic::NotAny, [true, false, false]),
        (SelectiveLogic::NotAll, [true, true, false]),
    ];
    for (logic, expected) in cases {
        let lines = ["a dragon", "a red dragon", "an old red dragon"];
        for (line, expected) in lines.into_iter().zip(expected) {
            assert_eq!(
                triggers(selective(logic), line),
                expected,
                "{logic:?} on {line:?}"
            );
        }
        assert!(
            !triggers(selective(logic), "an old red lizard"),
            "{logic:?} needs a primary key"
        );
    }
    // Without the selective flag secondary keys are ignored.
    assert!(triggers(
        LorebookEntry {
            selective: false,
            ..selective(SelectiveLogic::AndAll)
        },
        "dragon"
    ));
}

#[test]
fn decorators() {
    let c = character(vec![
        entry(&["nope"], "@@activate\nForced."),
        LorebookEntry {
            constant: true,
            ..entry(&[], "@@dont_activate\nNever.")
        },
        entry(
            &["dragon"],
            "  @@depth 2\n@@role user\n@@depth 9\n@@unknown thing\nPlaced.\n@@depth 5",
        ),
        LorebookEntry {
            constant: true,
            ..entry(&[], "@@activate")
        },
    ]);
    let found = evaluate(&c, &mut chat(&["a dragon"]));
    assert_eq!(found.len(), 2);
    assert_eq!(found[0].content, "Forced.");
    assert_eq!(
        (found[0].depth_override, found[0].role_override),
        (None, None)
    );
    assert_eq!(found[1].content, "Placed.\n@@depth 5");
    assert_eq!(
        (found[1].depth_override, found[1].role_override),
        (Some(2), Some(Role::User))
    );
}

#[test]
fn character_filter() {
    let filtered = |names: &[&str], tags: &[&str], is_exclude| LorebookEntry {
        constant: true,
        character_filter: Some(CharacterFilter {
            names: strings(names),
            tags: strings(tags),
            is_exclude,
        }),
        ..entry(&[], "x")
    };
    let cass = Character {
        name: "Cassandra".into(),
        nickname: Some("Cass".into()),
        tags: strings(&["elf"]),
        ..Default::default()
    };
    let passes = |entry: LorebookEntry| {
        let c = Character {
            lorebook: Some(Lorebook {
                entries: vec![entry],
                ..Default::default()
            }),
            ..cass.clone()
        };
        !active(&c, &mut chat(&["hi"])).is_empty()
    };
    assert!(passes(filtered(&["Cassandra"], &[], false)));
    assert!(passes(filtered(&["Cass"], &[], false)));
    assert!(!passes(filtered(&["Bob"], &[], false)));
    assert!(!passes(filtered(&["Cass"], &[], true)));
    assert!(passes(filtered(&["Bob"], &[], true)));
    assert!(passes(filtered(&[], &["elf", "orc"], false)));
    assert!(!passes(filtered(&[], &["orc"], false)));
    assert!(!passes(filtered(&[], &["elf"], true)));
    assert!(!passes(filtered(&["Cass"], &["orc"], false)));
    assert!(passes(filtered(&[], &[], false)));
}

#[test]
fn probability() {
    let chance = |probability| LorebookEntry {
        probability,
        ..entry(&["dragon"], "x")
    };
    for _ in 0..50 {
        assert!(!triggers(chance(0), "dragon"));
        assert!(triggers(chance(100), "dragon"));
    }
    let hits = (0..400).filter(|_| triggers(chance(50), "dragon")).count();
    assert!((100..300).contains(&hits), "{hits} of 400 at 50%");
}

#[test]
fn delay_waits_for_enough_messages() {
    let c = character(vec![LorebookEntry {
        delay: 3,
        ..entry(&["dragon"], "x")
    }]);
    assert!(active(&c, &mut chat(&["dragon", "dragon"])).is_empty());
    assert!(!active(&c, &mut chat(&["dragon", "dragon", "dragon"])).is_empty());
}

#[test]
fn budget_order_is_constant_then_priority_then_insertion_order() {
    let ordered = |content: &str, constant, priority, insertion_order| LorebookEntry {
        constant,
        priority,
        insertion_order,
        ..entry(&["dragon"], content)
    };
    let c = character(vec![
        ordered("late", false, 0, 200),
        ordered("early", false, 0, 50),
        ordered("important", false, 5, 300),
        ordered("constant-late", true, 0, 400),
        ordered("constant-early", true, 0, 10),
        ordered("early-too", false, 0, 50),
    ]);
    assert_eq!(
        active(&c, &mut chat(&["dragon"])),
        [
            "constant-early",
            "constant-late",
            "important",
            "early",
            "early-too",
            "late"
        ]
    );
}

/// Evaluates and starts the timed phases of everything active, as a build does
/// when all of it fits.
fn step(c: &Character, chat: &mut ChatState) -> bool {
    let found = evaluate(c, chat);
    commit_timed_effects(chat, &found);
    !found.is_empty()
}

#[test]
fn sticky_entries_stay_active_for_their_span() {
    let mut c = character(vec![LorebookEntry {
        sticky: 2,
        ..entry(&["dragon"], "x")
    }]);
    c.lorebook.as_mut().unwrap().scan_depth = Some(1);

    let mut chat = chat(&["a dragon"]);
    assert!(step(&c, &mut chat));
    assert_eq!(chat.active_stickies["0"], 3);

    // Sticky now: stays in without its key, and skips the probability roll.
    c.lorebook.as_mut().unwrap().entries[0].probability = 0;
    say(&mut chat, "nothing");
    assert!(step(&c, &mut chat));
    assert_eq!(
        chat.active_stickies["0"], 3,
        "a sticky entry does not extend itself"
    );

    say(&mut chat, "nothing");
    assert!(!step(&c, &mut chat));
    assert!(chat.active_stickies.is_empty());
}

#[test]
fn cooldown_blocks_the_entry_after_it_was_active() {
    let c = character(vec![LorebookEntry {
        id: Some("lore-7".into()),
        cooldown: 2,
        ..entry(&["dragon"], "x")
    }]);
    let mut chat = chat(&["a dragon"]);
    assert!(step(&c, &mut chat));
    assert_eq!(chat.active_cooldowns["lore-7"], 3);

    say(&mut chat, "a dragon");
    assert!(!step(&c, &mut chat));
    say(&mut chat, "a dragon");
    assert!(step(&c, &mut chat));
    assert_eq!(chat.active_cooldowns["lore-7"], 5);
}

#[test]
fn cooldown_starts_after_the_sticky_span() {
    let c = character(vec![LorebookEntry {
        sticky: 1,
        cooldown: 1,
        ..entry(&["dragon"], "x")
    }]);
    let mut chat = chat(&["a dragon"]);
    assert!(step(&c, &mut chat));
    assert_eq!(
        (chat.active_stickies["0"], chat.active_cooldowns["0"]),
        (2, 3)
    );

    // Message 2: sticky over, cooling down. Message 3: free again.
    say(&mut chat, "a dragon");
    assert!(!step(&c, &mut chat));
    say(&mut chat, "a dragon");
    assert!(step(&c, &mut chat));
}

#[test]
fn entries_dropped_by_the_budget_start_no_timed_phase() {
    let c = character(vec![LorebookEntry {
        sticky: 2,
        cooldown: 2,
        ..entry(&["dragon"], "x")
    }]);
    let mut chat = chat(&["a dragon"]);
    assert_eq!(evaluate(&c, &mut chat).len(), 1);
    commit_timed_effects(&mut chat, []);
    assert!(chat.active_stickies.is_empty() && chat.active_cooldowns.is_empty());
}

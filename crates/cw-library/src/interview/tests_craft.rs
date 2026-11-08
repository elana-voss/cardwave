//! The craft check's rules, each once, and what code tidies on a written card.

use super::craft::{craft_check, four_greetings, tidy};
use super::tests_writer::good;
use super::texts;
use super::writer::Fields;

fn kinds(first: &str) -> Vec<String> {
    vec![first.to_string()]
}

/// The rules `card` fails, as an ordinary card of a friend.
fn rules(card: Fields) -> Vec<&'static str> {
    let found = craft_check(&card, &kinds("A friend"), 0, false);
    found.into_iter().map(|failing| failing.rule).collect()
}

#[test]
fn each_rule_names_itself_on_the_field_it_is_about() {
    assert_eq!(rules(good()), Vec::<&str>::new());
    let text = |n: usize| "d".repeat(n);
    let cases: Vec<(&str, &str, Fields)> = vec![
        (
            "empty",
            "scenario",
            Fields {
                scenario: String::new(),
                ..good()
            },
        ),
        (
            "description size",
            "description",
            Fields {
                description: text(599),
                ..good()
            },
        ),
        (
            "description size",
            "description",
            Fields {
                description: text(1101),
                ..good()
            },
        ),
        (
            "first_mes size",
            "first_mes",
            Fields {
                first_mes: format!("{}.", "é".repeat(1000)),
                ..good()
            },
        ),
        (
            "acts for user",
            "first_mes",
            Fields {
                first_mes: "Then {{user}} nodded.".to_string(),
                ..good()
            },
        ),
        (
            "examples",
            "mes_example",
            Fields {
                mes_example: "<START>\n{{char}}: One.\n<START>\n{{char}}: Two.".to_string(),
                ..good()
            },
        ),
        (
            "greetings",
            "alternate_greetings",
            Fields {
                alternate_greetings: vec!["a.".to_string()],
                ..good()
            },
        ),
        (
            "hidden markup",
            "scenario",
            Fields {
                scenario: "*Rain.*".to_string(),
                ..good()
            },
        ),
        (
            "second person",
            "personality",
            Fields {
                personality: "When your friend calls, {{char}} comes.".to_string(),
                ..good()
            },
        ),
        (
            "instruction",
            "personality",
            Fields {
                personality: "Do not smile.".to_string(),
                ..good()
            },
        ),
        (
            "stray tag",
            "first_mes",
            Fields {
                first_mes: "<think>She looks up.".to_string(),
                ..good()
            },
        ),
        (
            "cut off",
            "alternate_greetings",
            Fields {
                alternate_greetings: ["a.", "b.", "c.", "d and th"].map(String::from).to_vec(),
                ..good()
            },
        ),
        (
            "example speaker",
            "mes_example",
            Fields {
                mes_example: "<START>\nMara: One.\n<START>\n{{char}}: Two.\n<START>\n{{char}}: No."
                    .to_string(),
                ..good()
            },
        ),
    ];
    for (rule, field, card) in cases {
        let found = craft_check(&card, &kinds("A friend"), 0, false);
        assert_eq!(found.len(), 1, "{rule}: {found:?}");
        assert_eq!((found[0].rule, found[0].field), (rule, field));
    }
}

#[test]
fn the_permanent_size_falls_on_the_largest_of_the_three_fields() {
    let found = craft_check(
        &Fields {
            personality: "p".repeat(3800),
            ..good()
        },
        &kinds("A friend"),
        0,
        false,
    );
    assert_eq!(found.len(), 1);
    assert_eq!(
        (found[0].rule, found[0].field),
        ("permanent size", "personality")
    );
    assert_eq!(
        found[0].why,
        "personality is 3800 characters; shorten it to about 1720 characters (286 words)"
    );
}

#[test]
fn one_convention_fails_the_fields_against_what_most_texts_do() {
    let card = Fields {
        first_mes: "*She looks up.*".to_string(),
        alternate_greetings: ["*a.*", "*b.*", "*c.*", "d."].map(String::from).to_vec(),
        ..good()
    };
    let found = craft_check(&card, &kinds("A friend"), 0, false);
    let fields: Vec<&str> = found.iter().map(|failing| failing.field).collect();
    assert!(
        found.iter().all(|failing| failing.rule == "one convention"),
        "{found:?}"
    );
    assert_eq!(fields, ["mes_example", "alternate_greetings"]);
    assert_eq!(
        found[0].why,
        "the other greetings mark actions with *…*; mark them so here too"
    );
    assert_eq!(
        found[1].why,
        "first_mes and the examples mark actions with *…*; mark them so here too"
    );

    let few = Fields {
        first_mes: "*She looks up.*".to_string(),
        ..good()
    };
    let found = craft_check(&few, &kinds("A friend"), 0, false);
    assert_eq!(
        found[0].why,
        "the other greetings use no *…*; remove them here"
    );
}

#[test]
fn a_size_that_fails_says_what_to_rewrite_it_to() {
    let why = |card: Fields, cast: usize, several: bool| {
        craft_check(&card, &kinds("A friend"), cast, several)
            .into_iter()
            .map(|failing| failing.why)
            .collect::<Vec<_>>()
    };
    let long = Fields {
        description: "d".repeat(1200),
        ..good()
    };
    assert_eq!(
        why(long, 0, false),
        ["1200 characters; rewrite it to about 800 characters (133 words)"]
    );
    let long_cast = Fields {
        description: "d".repeat(2201),
        ..good()
    };
    assert_eq!(
        why(long_cast, 2, true)[0],
        "2201 characters; rewrite it to about 1600 characters (266 words)"
    );
    let long_greeting = Fields {
        first_mes: format!("{}.", "f".repeat(1000)),
        ..good()
    };
    assert_eq!(
        why(long_greeting, 0, false),
        ["1001 characters; rewrite it to about 700 characters (120 words)"]
    );
}

#[test]
fn a_cast_description_of_2200_characters_passes() {
    let card = Fields {
        description: "d".repeat(2200),
        ..good()
    };
    let found = craft_check(&card, &kinds("A friend"), 2, true);
    assert!(
        !found
            .iter()
            .any(|failing| failing.rule == "description size"),
        "{found:?}"
    );
}

#[test]
fn saying_what_a_character_does_not_do_is_no_instruction() {
    let quiet = |personality: &str| Fields {
        personality: personality.to_string(),
        ..good()
    };
    assert_eq!(
        rules(quiet("They do not agree with everything she says.")),
        Vec::<&str>::new()
    );
    assert_eq!(rules(quiet("She waits. Do not smile.")), ["instruction"]);
}

#[test]
fn quoted_speech_with_an_apostrophe_and_a_thank_you_are_no_second_person() {
    let quiet = |personality: &str| Fields {
        personality: personality.to_string(),
        ..good()
    };
    assert_eq!(
        rules(quiet(
            "{{char}} says 'You're here,' and 'everyone's words' and sends thank-you verses."
        )),
        Vec::<&str>::new()
    );
    assert_eq!(rules(quiet("It isn't you.")), ["second person"]);
}

#[test]
fn a_field_of_no_words_is_empty_and_too_little_in_all_fails_on_the_smallest() {
    let colon = Fields {
        personality: ":".to_string(),
        ..good()
    };
    assert_eq!(rules(colon), ["empty"]);
    let thin = Fields {
        personality: "p".repeat(90),
        scenario: format!("{{{{user}}}} {}", "s".repeat(91)),
        ..good()
    };
    let found = craft_check(&thin, &kinds("A friend"), 0, false);
    assert_eq!(found.len(), 1, "{found:?}");
    assert_eq!(
        (found[0].rule, found[0].field, found[0].why.as_str()),
        (
            "permanent size",
            "personality",
            "personality is 90 characters; lengthen it to about 700 characters (116 words)"
        )
    );
}

#[test]
fn a_card_that_never_names_the_user_by_the_placeholder_fails_but_a_game_may() {
    let named = Fields {
        description: "Elena ".repeat(150),
        scenario: "s".repeat(800),
        ..good()
    };
    assert_eq!(rules(named.clone()), ["user unnamed"]);
    assert!(craft_check(&named, &kinds(texts::FRAMEWORK), 0, false).is_empty());
}

#[test]
fn a_greeting_loses_a_start_line_and_a_speakers_name_and_a_start_left_fails() {
    let headed = Fields {
        first_mes: "<START>\nMara: *She looks up.*".to_string(),
        alternate_greetings: ["<START>\n{{char}}: a.", "b.", "c.", "Mara: d."]
            .map(String::from)
            .to_vec(),
        ..good()
    };
    assert!(rules(headed.clone()).contains(&"stray tag"));
    let tidied = tidy(headed, &kinds("A friend"), false);
    assert_eq!(tidied.first_mes, "*She looks up.*");
    assert_eq!(tidied.alternate_greetings, ["a.", "b.", "c.", "d."]);
}

#[test]
fn an_instruction_fails_in_any_hidden_field_and_never_as_a_trait_does_not() {
    let scene = |scenario: &str| Fields {
        scenario: format!("{{{{user}}}} {scenario} {}", "s".repeat(780)),
        ..good()
    };
    assert_eq!(
        rules(scene("Roleplay mode: Ann narrates.")),
        ["instruction"]
    );
    assert_eq!(rules(scene("Ann waits. Never: sex.")), ["instruction"]);
    assert_eq!(
        rules(scene("Never gives up on {{user}}.")),
        Vec::<&str>::new()
    );
}

#[test]
fn only_what_is_outside_speech_acts_for_the_user() {
    let opening = |first_mes: &str| Fields {
        first_mes: first_mes.to_string(),
        ..good()
    };
    assert_eq!(
        rules(opening("\"Talk if you feel like it,\" he says.")),
        Vec::<&str>::new()
    );
    assert_eq!(rules(opening("You nod.")), ["acts for user"]);
}

#[test]
fn speech_may_say_you_and_an_apostrophe_is_no_speech() {
    let quiet = |personality: &str| Fields {
        personality: personality.to_string(),
        ..good()
    };
    assert_eq!(
        rules(quiet(
            "{{char}} says \"you lied\" and 'you know it' and \u{201c}you\u{201d}."
        )),
        Vec::<&str>::new()
    );
    assert_eq!(
        rules(quiet("It isn't you, it's {{user}}.")),
        ["second person"]
    );
}

#[test]
fn a_game_may_have_no_greetings_and_several_has_its_own_sizes_and_speakers() {
    let none = Fields {
        alternate_greetings: Vec::new(),
        ..good()
    };
    let game = kinds(texts::FRAMEWORK);
    assert!(craft_check(&none, &game, 0, false).is_empty());
    let five = Fields {
        alternate_greetings: vec!["a.".to_string(); 5],
        ..good()
    };
    assert_eq!(craft_check(&five, &game, 0, false)[0].rule, "greetings");

    let cast = Fields {
        description: "d".repeat(2000),
        personality: "p".repeat(3000),
        scenario: format!("{{{{user}}}} {}", "s".repeat(991)),
        mes_example: "<START>\nAnn: One.\n<START>\nBo: Two.\n<START>\nAnn: No.".to_string(),
        ..good()
    };
    assert!(craft_check(&cast, &kinds("A friend"), 2, true).is_empty());
    let found = craft_check(&cast, &kinds("A friend"), 1, true);
    assert_eq!(
        (found[0].rule, found[0].why.as_str()),
        ("cast size", "1 people, wanted 2-4")
    );
    let over = Fields {
        description: "d".repeat(2201),
        ..cast.clone()
    };
    assert_eq!(
        craft_check(&over, &kinds("A friend"), 3, true)[0].rule,
        "description size"
    );
    let big = Fields {
        personality: "p".repeat(3700),
        ..cast
    };
    assert_eq!(
        craft_check(&big, &kinds("A friend"), 3, true)[0].rule,
        "permanent size"
    );
}

#[test]
fn four_greetings_are_kept_of_more() {
    let card = Fields {
        alternate_greetings: ["a", "b", "c", "d", "e"].map(String::from).to_vec(),
        ..good()
    };
    assert_eq!(
        four_greetings(card).alternate_greetings,
        ["a", "b", "c", "d"]
    );
}

#[test]
fn tidy_drops_the_lost_persons_line_on_other_cards_and_a_gender_note_and_turns_the_name_into_char()
{
    let card = Fields {
        creator_notes:
            "A portrait from your memories.  This suits anyone! Kind and ungendered? Warm."
                .to_string(),
        mes_example: "<START>\nMara: One. Mara: two.\nSam: Hi.\nMara: No.".to_string(),
        ..good()
    };

    let done = tidy(card.clone(), &kinds("A friend"), false);
    assert_eq!(done.creator_notes, "Warm.");
    assert_eq!(
        done.mes_example,
        "<START>\n{{char}}: One. Mara: two.\nSam: Hi.\n{{char}}: No."
    );

    let lost = tidy(card.clone(), &kinds("Someone I lost"), false);
    assert_eq!(lost.creator_notes, "A portrait from your memories. Warm.");

    assert_eq!(
        tidy(card.clone(), &kinds("A friend"), true).mes_example,
        card.mes_example
    );
}

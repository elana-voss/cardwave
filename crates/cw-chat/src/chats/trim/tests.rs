use super::{kept, trimmed};
use crate::chats::ReplyEnd;
use cw_provider::Finish;

/// What `text` is trimmed to, as a whole reply.
fn trim(text: &str) -> String {
    trimmed(text, 0).into_owned()
}

#[test]
fn a_cut_off_sentence_goes_and_a_finished_reply_stays() {
    let reply = "The hall was dark and quiet. She opened the door. Behind it she saw";
    assert_eq!(
        trim(reply),
        "The hall was dark and quiet. She opened the door."
    );
    let whole = "The hall was dark and quiet. She opened the door.";
    assert!(matches!(trimmed(whole, 0), std::borrow::Cow::Borrowed(_)));
    assert_eq!(trim("She waved. *smiles*"), "She waved. *smiles*");
    assert_eq!(trim("See you soon 😊 and then"), "See you soon 😊");
}

#[test]
fn only_a_cut_off_reply_or_one_whose_end_is_not_said_is_trimmed() {
    let reply = "The hall was dark and quiet. She opened the door. Behind it she saw";
    let cut = "The hall was dark and quiet. She opened the door.";
    assert_eq!(
        kept(reply, 0, ReplyEnd::Finished(Finish::CutOff).trims()),
        cut
    );
    assert_eq!(
        kept(reply, 0, ReplyEnd::Finished(Finish::NotSaid).trims()),
        cut
    );
    for end in [
        ReplyEnd::Finished(Finish::OnItsOwn),
        ReplyEnd::Stopped,
        ReplyEnd::Failed,
        ReplyEnd::AtModelLimit,
    ] {
        assert_eq!(kept(reply, 0, end.trims()), reply, "{end:?}");
    }
}

#[test]
fn a_cut_keeping_too_little_is_not_made_counted_in_characters() {
    // Four characters kept of seventeen, under 40 % and 120.
    assert_eq!(trim("Yes. And then she"), "Yes. And then she");
    // 41 characters of a hundred kept: over 40 %.
    let reply = format!("{}. {}", "a".repeat(40), "B".repeat(58));
    assert_eq!(trim(&reply), format!("{}.", "a".repeat(40)));
    // Fifty characters, 150 bytes, of two hundred: too little, though over 120 bytes.
    let reply = format!("{}。{}", "猫".repeat(49), "犬".repeat(150));
    assert_eq!(trim(&reply), reply);
}

#[test]
fn an_unfinished_paragraph_goes_back_to_a_line_that_ended() {
    let reply = "*She smiles and waves at you from the window of the old house by the sea*\n\nThen she turns and walks";
    assert_eq!(
        trim(reply),
        "*She smiles and waves at you from the window of the old house by the sea*"
    );
}

#[test]
fn markdown_blocks_are_whole_units() {
    // A code block it ends inside is closed, never cut inside.
    assert_eq!(
        trim("Here it is:\n```rust\nfn main() {\n    let x = 1;"),
        "Here it is:\n```rust\nfn main() {\n    let x = 1;\n```"
    );
    // A closed code block ends it, a sentence inside is none.
    let reply = "Here it is, the whole program you asked for:\n```\nprint(1). x\n```\nAnd then it";
    assert_eq!(
        trim(reply),
        "Here it is, the whole program you asked for:\n```\nprint(1). x\n```"
    );
    // An unfinished list point goes whole, an empty one goes, one its line ended stays.
    let list = "What to buy for the long trip ahead:\n- Eggs. Ten of them\n- Bread. Two lo";
    assert_eq!(
        trim(list),
        "What to buy for the long trip ahead:\n- Eggs. Ten of them"
    );
    let list = "What to buy for the long trip ahead:\n- Eggs\n- Bread\n- ";
    assert_eq!(
        trim(list),
        "What to buy for the long trip ahead:\n- Eggs\n- Bread"
    );
    let list = "What to buy for the long trip ahead:\n1. Eggs\n2. Bread\n";
    assert_eq!(trim(list), list);
    // A table's row that ended stays, an unfinished one goes.
    let table = "The prices we found today:\n| Item | Price |\n|---|---|\n| Eggs | 3 |\n| Bre";
    assert_eq!(
        trim(table),
        "The prices we found today:\n| Item | Price |\n|---|---|\n| Eggs | 3 |"
    );
}

#[test]
fn what_the_kept_text_holds_open_is_closed_and_nothing_else() {
    assert_eq!(
        trim("He looks up from the book. \"Come in. Sit down by the"),
        "He looks up from the book. \"Come in.\""
    );
    assert_eq!(
        trim("He looks up from the book. *He smiles. Then he"),
        "He looks up from the book. *He smiles.*"
    );
    // An asterisk that begins a list point opens nothing.
    let list = "Two things for you today:\n* Tea.\n* Cake. And a lot of";
    assert_eq!(trim(list), "Two things for you today:\n* Tea.");
    // A quotation mark after a digit is no speech.
    assert_eq!(
        trim("He hands you a 6\" pipe. Then he asks for the"),
        "He hands you a 6\" pipe."
    );
    // The same mark open twice cannot be closed at the end: the cut goes before the second.
    assert_eq!(
        trim("\"Wait here by the door, please wait. \"I will be back soon. Then"),
        "\"Wait here by the door, please wait.\""
    );
}

#[test]
fn every_app_language_ends_its_sentences_its_own_way() {
    // German quotation marks and an abbreviation.
    assert_eq!(
        trim("Sie lacht. „Komm herein, z. B. durch die Tür. Setz dich an den"),
        "Sie lacht. „Komm herein, z. B. durch die Tür.“"
    );
    // Russian guillemets and "т. д.".
    assert_eq!(
        trim("Она смеётся. «Хлеб, сыр и т. д. Всё на столе. А потом мы"),
        "Она смеётся. «Хлеб, сыр и т. д. Всё на столе.»"
    );
    // Japanese marks need no space before them.
    assert_eq!(
        trim("彼女は扉を開けた。「こんにちは。今日は"),
        "彼女は扉を開けた。「こんにちは。」"
    );
    // Chinese quotation marks after a colon.
    assert_eq!(
        trim("她笑了。她说：“你好。我们去"),
        "她笑了。她说：“你好。”"
    );
    // Hindi's danda.
    assert_eq!(
        trim("वह दरवाज़ा खोलती है। फिर वह मुस्कुराती है। फिर उसने"),
        "वह दरवाज़ा खोलती है। फिर वह मुस्कुराती है।"
    );
    // Spanish and a sentence that goes on in lower case after a dot.
    assert_eq!(
        trim("¿Vienes? Sra. Gómez abre la puerta. luego mira. Y después"),
        "¿Vienes? Sra. Gómez abre la puerta. luego mira."
    );
}

#[test]
fn a_continuation_is_trimmed_alone() {
    let before = "She opened the door. Behind it she saw";
    let reply = format!("{before} the garden, wide and green. Then she");
    assert_eq!(
        trimmed(&reply, before.len()),
        format!("{before} the garden, wide and green.")
    );
    // A continuation with no end of its own after the text before stays.
    let reply = format!("{before} the garden and");
    assert_eq!(trimmed(&reply, before.len()), reply);
}

#[test]
fn only_the_replys_own_language_has_abbreviations_and_a_letter_must_begin_one() {
    // "NY" is Indonesian's abbreviation, not English's.
    assert_eq!(
        trim(
            "We packed all our bags last spring and finally moved to NY. Then we found a small flat near the park and"
        ),
        "We packed all our bags last spring and finally moved to NY."
    );
    assert_eq!(
        trim("She came in 1st. Then she ran home and"),
        "She came in 1st."
    );
}

#[test]
fn no_dot_of_an_abbreviation_of_two_parts_ends_a_sentence() {
    let reply = "Sie mag vieles sehr, z. B. lange Spaziergänge am";
    assert_eq!(trim(reply), reply);
}

#[test]
fn a_lone_opening_quotation_mark_at_the_end_goes() {
    assert_eq!(
        trim("He turned to her and smiled. \""),
        "He turned to her and smiled."
    );
    assert_eq!(trim("她笑了。她说：“"), "她笑了。");
}

#[test]
fn inline_code_at_a_lines_start_opens_no_code_block() {
    assert_eq!(
        trim("```hello``` she said softly. Then she walked to the"),
        "```hello``` she said softly."
    );
}

#[test]
fn a_reply_ending_on_a_flag_emoji_is_finished() {
    let reply = "Enjoy your trip to Japan! 🇯🇵";
    assert_eq!(trim(reply), reply);
}

#[test]
fn asterisks_inside_a_word_open_nothing() {
    assert_eq!(
        trim("What the f**k is that. Then he"),
        "What the f**k is that."
    );
}

/// A long cut-off reply that holds many marks open (a broken model's loop) is
/// trimmed in time linear in its length: the marks open at each candidate end
/// are not all built at once.
#[test]
fn many_marks_held_open_trim_in_linear_time() {
    let reply = "(He ran. ".repeat(20_000) + "And then";
    let started = std::time::Instant::now();
    let cut = trim(&reply);
    let took = started.elapsed();
    assert!(cut.ends_with(&format!("(He ran.{}", ")".repeat(20_000))));
    assert!(took.as_secs_f64() < 2.0, "took {took:?}");
}

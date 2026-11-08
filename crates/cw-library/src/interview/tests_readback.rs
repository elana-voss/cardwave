//! The read-back on scripted models, and "That's not it".

use cw_ccv4::creation::NeedState;
use serde_json::json;

use super::readback::*;
use super::tests::*;
use super::*;

fn line(sentence: &str, gap: bool) -> Line {
    Line {
        sentence: sentence.to_string(),
        words: format!("words of {sentence}"),
        gap,
    }
}

#[tokio::test]
async fn the_read_back_reads_the_answers_and_shows_every_gap_and_eight_others() {
    let many: Vec<Line> = (0..10)
        .map(|n| line(&format!("plain {n}"), false))
        .chain([line("the gap", true)])
        .collect();
    let script = Script::default().then("read-back", json!({ "needs": many }));
    let interview = run(&script, Style::Tree, vec![free(LONG)]).await;

    let shown = read_back(&script, &interview).await.unwrap();

    assert_eq!(
        script.sent("read-back"),
        vec![format!(
            "{}
The character's gender: {}. How it treats the user: anyone.",
            interview.answers_text(),
            // Drawn by the interview's seed, which is new each time.
            gender::choices(&interview).character_gender
        )]
    );
    let plain = shown.iter().filter(|line| !line.gap).count();
    assert_eq!(plain, SHOWN);
    assert_eq!(shown.last().unwrap(), &line("the gap", true));
    assert_eq!(shown[0], line("plain 0", false));
}

#[tokio::test]
async fn a_read_back_of_nothing_asks_no_model() {
    let script = Script::default();
    let shown = read_back(&script, &Interview::new(Style::Tree)).await;
    assert!(shown.unwrap().is_empty());
    assert!(script.sent("read-back").is_empty());
}

#[test]
fn keep_change_and_remove_make_the_needs_and_untouched_is_kept() {
    let lines = [
        line("kept", false),
        line("changed", false),
        line("empty change", true),
        line("removed", false),
        line("untouched", false),
    ];
    let verdicts = [
        Verdict::Keep,
        Verdict::Change(" my own ".to_string()),
        Verdict::Change("  ".to_string()),
        Verdict::Remove,
    ];

    let needs = corrected(&lines, &verdicts);

    let states: Vec<NeedState> = needs.iter().map(|need| need.state).collect();
    use NeedState::{Changed, Kept, Removed};
    assert_eq!(states, [Kept, Changed, Kept, Removed, Kept]);
    assert_eq!(needs[1].changed_to.as_deref(), Some("my own"));
    assert_eq!(needs[1].sentence, "changed");
    assert_eq!(needs[2].changed_to, None);
    assert!(needs[2].gap);
}

#[test]
fn a_removed_lines_words_go_whole_and_a_short_piece_only_as_a_whole_part() {
    let cases = [
        ("no lectures, no pity", "no", "no lectures, no pity"),
        ("he's kind", "he", "he's kind"),
        (
            "\u{5DC}\u{5D0}\u{5DB}\u{5D5}\u{5DC}",
            "\u{5DC}\u{5D0}",
            "\u{5DC}\u{5D0}\u{5DB}\u{5D5}\u{5DC}",
        ),
        ("no; maybe", "no", "; maybe"),
        ("You said: \"no\". Why?", "no", "You said: \"\". Why?"),
        ("knowing it", "know", "knowing it"),
        ("quiet mornings alone", "quiet mornings; mornings alone", ""),
        (
            "\u{3A3}\u{39F}\u{3A6}\u{39F}\u{3A3} man",
            "\u{3C3}\u{3bf}\u{3c6}\u{3bf}\u{3c2}",
            " man",
        ),
        ("\u{130}stanbul nights", "\u{130}stanbul", " nights"),
        (
            "\u{6211}\u{559C}\u{6B22}\u{5B89}\u{9759}\u{7684}\u{65E9}\u{6668}",
            "\u{5B89}\u{9759}\u{7684}\u{65E9}\u{6668}",
            "\u{6211}\u{559C}\u{6B22}",
        ),
    ];
    for (text, words, left) in cases {
        assert_eq!(
            without_words(text, &[words]),
            left,
            "{text} without {words}"
        );
    }
}

#[tokio::test]
async fn thats_not_it_finds_the_question_and_replaces_it_in_place() {
    let script = Script::default();
    let interview = run(
        &script,
        Style::Tree,
        vec![
            free("someone who listens late at night"),
            free("a friend who remembers small things"),
        ],
    )
    .await;

    let words = "\u{201C}Remembers small things\u{201D} · not said anywhere";
    let index = question_of(&interview, words).unwrap();
    assert_eq!(index, 1);
    assert_eq!(question_of(&interview, "nothing like this"), None);

    let replaced = reanswer(&interview, index, free("a dry sense of humour")).unwrap();

    assert_eq!(replaced.log.len(), interview.log.len());
    assert_eq!(replaced.asking, interview.asking);
    assert_eq!(replaced.log[0], interview.log[0]);
    assert_eq!(replaced.log[1].slot, interview.log[1].slot);
    assert_eq!(
        replaced.log[1].answer.as_deref(),
        Some("a dry sense of humour")
    );

    let script = script.then("read-back", json!({ "needs": [] }));
    read_back(&script, &replaced).await.unwrap();
    assert!(script.sent("read-back")[0].contains("a dry sense of humour"));
    assert!(!script.sent("read-back")[0].contains("small things"));
}

#[tokio::test]
async fn thats_not_it_on_the_kinds_changes_the_kinds_and_keeps_what_the_answer_lit() {
    let script = Script::default();
    let mut interview = run(&script, Style::Cloud, vec![free(LONG)]).await;
    let lit = Some(vec!["humour".to_string()]);
    interview.log[0].lit = lit.clone();
    interview.log.push(Entry {
        slot: "kinds".to_string(),
        picks: vec![texts::KIND_NAMES[0].to_string()],
        ..interview.log[0].clone()
    });
    interview.kinds = vec![texts::KIND_NAMES[0].to_string()];

    let kept = reanswer(&interview, 0, free("another answer of many words")).unwrap();
    assert_eq!(kept.log[0].lit, lit);

    let kinds = reanswer(&interview, 1, picks(&[texts::KIND_NAMES[1]])).unwrap();
    assert_eq!(kinds.kinds, [texts::KIND_NAMES[1]]);
    assert!(reanswer(&interview, 9, free("x")).is_err());
    assert!(reanswer(&interview, 0, Move::Back).is_err());
    assert!(reanswer(&interview, 0, Move::EndAfter(Box::new(free("x")))).is_err());
}

#[tokio::test]
async fn thats_not_it_on_the_kinds_drops_the_own_questions_of_the_old_kind() {
    let script = Script::default();
    let (slot, names) = texts::KIND_SLOT[0];
    let done = finish(&script, Interview::new(Style::Tree), &[names[0]]).await;
    assert!(slots(&done).contains(&slot));
    let other = texts::KIND_NAMES
        .iter()
        .find(|kind| !names.contains(kind))
        .unwrap();
    let index = slots(&done).iter().position(|s| *s == "kinds").unwrap();
    let changed = reanswer(&done, index, picks(&[other])).unwrap();
    assert!(!slots(&changed).contains(&slot));
    assert_eq!(changed.asking, None);
}

#[tokio::test]
async fn thats_not_it_on_the_needs_drops_the_branch_no_longer_picked() {
    let script = Script::default();
    let moves = vec![free(LONG), picks(&[]), picks(&texts::NEEDS[..2])];
    let at = run(&script, Style::Tree, moves).await;
    let done = finish(&script, at, &[]).await;
    let branch = |need: &str| format!("branch: {need}");
    let index = slots(&done).iter().position(|s| *s == "needs").unwrap();
    let changed = reanswer(&done, index, picks(&texts::NEEDS[..1])).unwrap();
    assert!(slots(&changed).contains(&branch(texts::NEEDS[0]).as_str()));
    assert!(!slots(&changed).contains(&branch(texts::NEEDS[1]).as_str()));
}

#[tokio::test]
async fn thats_not_it_drops_the_probe_of_the_old_answer() {
    let script = Script::default();
    let mut at = run(
        &script,
        Style::Tree,
        vec![free(LONG), picks(&[]), picks(&[]), picks(&[])],
    )
    .await;
    while at.asking.as_ref().unwrap().slot != "why" {
        let kinds = at.asking.as_ref().unwrap().slot == "kinds";
        let action = if kinds { picks(&[]) } else { free(LONG) };
        at = step(&script, &at, action, "en").await.unwrap();
    }
    let at = step(&script, &at, free("short"), "en").await.unwrap();
    let done = finish(&script, at, &[]).await;
    assert!(slots(&done).contains(&"why probe"));
    let index = slots(&done).iter().position(|s| *s == "why").unwrap();
    let changed = reanswer(&done, index, free(LONG)).unwrap();
    assert!(!slots(&changed).contains(&"why probe"));
}

#[tokio::test]
async fn the_read_back_is_told_the_characters_gender_and_how_it_treats_the_user() {
    let script = Script::default().then("read-back", json!({ "needs": [] }));
    let interview = run(&script, Style::Tree, vec![free(LONG)]).await;
    let mut interview = interview;
    interview.read = Some(gender::GenderRead {
        character: "woman".to_string(),
        treat: "man".to_string(),
        words: "my words".to_string(),
    });

    readback::read_back(&script, &interview).await.unwrap();

    let sent = script.sent("read-back");
    assert_eq!(
        sent[0],
        format!(
            "{}\nThe character's gender: woman. How it treats the user: man.",
            interview.answers_text()
        )
    );
}

#[tokio::test]
async fn no_line_rests_on_a_bare_something_else_or_not_sure() {
    let script = Script::default();
    let done = finish(&script, Interview::new(Style::Tree), &["Not sure"]).await;
    assert_eq!(question_of(&done, "Not sure"), None);
    let plain = finish(&script, Interview::new(Style::Tree), &["A friend"]).await;
    let at_kinds = slots(&plain).iter().position(|s| *s == "kinds");
    assert_eq!(question_of(&plain, "A friend"), at_kinds);
}

#[tokio::test]
async fn a_line_is_the_models_own_guess_only_where_no_piece_of_its_words_was_said() {
    let script = Script::default();
    let done = finish(&script, Interview::new(Style::Tree), &["Not sure"]).await;
    assert!(
        !guessed(&done, "Not sure"),
        "a bare kind was said all the same"
    );
    assert!(!guessed(&done, "nothing like this · Not sure"));
    assert!(guessed(&done, "nothing like this"));
    assert!(guessed(&done, ""));
}

#[tokio::test]
async fn a_line_whose_words_join_an_answers_own_words_otherwise_is_no_guess() {
    let script = Script::default();
    let said = "I want someone patient who pushes me a little, with dry humour.";
    let interview = run(&script, Style::Tree, vec![free(said)]).await;
    assert!(!guessed(
        &interview,
        "patient, pushes me a little, dry humour"
    ));
    assert!(!guessed(&interview, "someone patient … dry humour"));
    assert!(
        guessed(&interview, "a partner with wit"),
        "short words alone are no sign"
    );
}

#[tokio::test]
async fn a_function_word_an_answer_shares_is_no_sign_it_was_said() {
    let script = Script::default();
    let said = "I want someone patient who pushes me a little, with dry humour.";
    let interview = run(&script, Style::Tree, vec![free(said)]).await;
    assert!(
        guessed(&interview, "someone loud who never listens"),
        "\"someone\" alone is no word of the answer's own"
    );
}

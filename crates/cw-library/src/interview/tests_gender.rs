//! The two gender questions and what moved with the new lists, on scripted models.

use cw_core::Code;
use serde_json::{Value, json};

use super::gender::{GenderRead, offered, quote_found, settle};
use super::readback::reanswer;
use super::tests::*;
use super::*;

fn read_of(character: &str, treat: &str, words: &str) -> Value {
    json!({"character": character, "treat": treat, "words": words})
}

fn unknown() -> GenderRead {
    GenderRead {
        character: "unknown".to_string(),
        treat: "unknown".to_string(),
        words: String::new(),
    }
}

fn kinds(names: &[&str]) -> Vec<String> {
    names.iter().map(|name| name.to_string()).collect()
}

async fn made(script: &Script, kind: &[&str]) -> Interview {
    finish(script, Interview::new(Style::Tree), kind).await
}

#[tokio::test]
async fn the_two_questions_stay_outside_the_limit() {
    let script = Script::default();
    let at_last = with_asked(Style::Tree, 15);
    let mut at = step(&script, &at_last, free(LONG), "en").await.unwrap();
    assert!(at.guard_hit);
    assert_eq!(at.asking.as_ref().unwrap().slot, "character");
    at = step(&script, &at, picks(&["Woman"]), "en").await.unwrap();
    assert_eq!(at.asking.as_ref().unwrap().slot, "treat");
    at = step(&script, &at, picks(&["As a woman"]), "en")
        .await
        .unwrap();
    assert_eq!(at.asking, None);
    assert!(at.guard_hit);
    assert_eq!(gender::choices(&at).character_gender, "woman");
    assert_eq!(gender::choices(&at).treat_user, "woman");
}

#[tokio::test]
async fn the_limit_stays_marked_after_a_probe_it_cut() {
    let script = Script::default();
    let moves = vec![
        free(LONG),
        picks(&[]),
        picks(&texts::NEEDS[..2]),
        picks(&["A character I already know", "Someone I lost"]),
        picks(&[]),
        picks(&[texts::BRANCH[0].2[0]]),
        picks(&[texts::BRANCH[0].2[0]]),
    ];
    let mut at = Interview::new(Style::Tree);
    for action in moves {
        at = step(&script, &at, action, "en").await.unwrap();
    }
    while gender::guard_count(&at.log) + 1 < GUARD {
        at = step(&script, &at, free(LONG), "en").await.unwrap();
    }
    assert_eq!(at.asking.as_ref().unwrap().slot, "lost_person");
    let cut = step(&script, &at, free("short"), "en").await.unwrap();
    assert!(cut.guard_hit);
    assert_eq!(cut.asking.as_ref().unwrap().slot, "character");
    let answered = step(&script, &cut, picks(&["Woman"]), "en").await.unwrap();
    assert!(answered.guard_hit);
}

#[tokio::test]
async fn each_question_is_asked_only_where_the_read_leaves_it_open() {
    let shows_character = Script::default().then("gender read", read_of("man", "unknown", LONG));
    let done = made(&shows_character, &["A friend"]).await;
    assert!(!slots(&done).contains(&"character"));
    assert!(slots(&done).contains(&"treat"));
    assert_eq!(gender::choices(&done).character_gender, "man");

    let shows_treat = Script::default().then("gender read", read_of("unknown", "woman", LONG));
    let done = made(&shows_treat, &["A friend"]).await;
    assert!(slots(&done).contains(&"character"));
    assert!(!slots(&done).contains(&"treat"));
    assert_eq!(gender::choices(&done).treat_user, "woman");

    let shows_both = Script::default().then("gender read", read_of("woman", "man", LONG));
    let done = made(&shows_both, &["A friend"]).await;
    assert!(!slots(&done).contains(&"character"));
    assert!(!slots(&done).contains(&"treat"));
    assert_eq!(shows_both.sent("gender read").len(), 1);
}

#[tokio::test]
async fn a_read_is_believed_only_with_its_words_in_the_answers_and_a_failure_leaves_both_open() {
    let not_said = Script::default().then("gender read", read_of("woman", "man", "not said here"));
    let done = made(&not_said, &["A friend"]).await;
    assert!(slots(&done).contains(&"character"));
    assert_eq!(done.read, Some(unknown()));

    let broken = Script::default().then("gender read", read_of("a cat", "man", LONG));
    assert_eq!(made(&broken, &["A friend"]).await.read, Some(unknown()));

    let down = Script::default().failing("gender read", Code::ModelDeclined);
    let done = made(&down, &["A friend"]).await;
    assert!(slots(&done).contains(&"character") && slots(&done).contains(&"treat"));
    assert_eq!(done.read, Some(unknown()));
}

#[test]
fn quotes_may_be_cut_at_their_joints_but_each_passage_must_be_there() {
    let text = "I want her to be a woman.\nShe should call me sir, always.";
    assert!(quote_found("WANT HER  TO BE a woman", text));
    assert!(quote_found(
        "I want her to be a woman; call me sir, always",
        text
    ));
    assert!(!quote_found("I want her to be a man", text));
    assert!(!quote_found("", text));
}

#[test]
fn a_quote_is_whole_words_whatever_its_punctuation() {
    assert!(quote_found(
        "I want her, to be a woman!",
        "I want her to be a woman"
    ));
    assert!(!quote_found("she is a man", "she is a manager"));
    assert!(!quote_found("...", "and so..."));
    // A script without case runs its words together: a part of a sentence is found.
    assert!(quote_found("她是女人", "我想她是女人的朋友"));
}

#[test]
fn you_choose_and_no_answer_draw_over_what_was_offered_by_the_seed() {
    let friend = kinds(&["A friend"]);
    let drawn = settle(&friend, &unknown(), texts::YOU_CHOOSE, "", "seed");
    let draw = drawn.draw.clone().unwrap();
    assert_eq!(draw.over.len(), texts::CHARACTER_VALUE.len());
    assert_eq!(draw.drawn.len(), 1);
    assert_eq!(draw.drawn[0], drawn.character_gender);
    assert!(draw.over.contains(&drawn.character_gender));
    assert_eq!(
        drawn,
        settle(&friend, &unknown(), texts::YOU_CHOOSE, "", "seed")
    );
    assert_eq!(settle(&friend, &unknown(), "", "", "seed"), drawn);

    let lost = kinds(&["Someone I lost"]);
    let one = settle(&lost, &unknown(), texts::YOU_CHOOSE, "", "seed");
    assert!(!one.draw.unwrap().over.contains(&"several".to_string()));
    assert!(!offered(&lost).contains(&"Several characters"));
}

#[test]
fn several_characters_get_a_cast_of_single_genders_drawn() {
    let settled = settle(
        &kinds(&["A friend"]),
        &unknown(),
        "Several characters",
        "",
        "seed",
    );
    assert_eq!(settled.character_gender, "several");
    assert_eq!(settled.draw, None);
    assert_eq!(settled.cast_genders.len(), 4);
    assert!(!settled.cast_genders.contains(&"several".to_string()));
    assert_eq!(settled.cast_draw.unwrap().drawn, settled.cast_genders);
}

#[tokio::test]
async fn another_me_and_a_group_ask_no_character_question() {
    let script = Script::default();
    let me = made(&script, &[texts::THE_USER]).await;
    assert!(!slots(&me).contains(&"character"));
    assert!(slots(&me).contains(&"treat"));
    assert_eq!(gender::choices(&me).character_gender, "they");

    let group = made(&script, &[texts::GROUP]).await;
    assert!(!slots(&group).contains(&"character"));
    assert_eq!(gender::choices(&group).character_gender, "several");
    assert_eq!(gender::choices(&group).cast_genders.len(), 4);
}

#[test]
fn another_me_follows_how_the_user_is_treated() {
    let me = kinds(&[texts::THE_USER]);
    let man = settle(&me, &unknown(), "", "As a man", "seed");
    assert_eq!(man.character_gender, "man");
    assert_eq!(man.treat_user, "man");
    let anyone = settle(&me, &unknown(), "", "", "seed");
    assert_eq!(anyone.character_gender, "they");
    assert_eq!(anyone.treat_user, "anyone");
}

#[test]
fn a_free_line_is_read_for_one_gender_for_many_and_else_kept_as_told() {
    let friend = kinds(&["A friend"]);
    let read = |line: &str, of: &[String]| settle(of, &unknown(), line, "", "seed");
    let woman = read("a tall woman", &friend);
    assert_eq!(woman.character_gender, "woman");
    assert_eq!(woman.character_words, "a tall woman");
    assert_eq!(woman.draw, None);
    assert_eq!(read("a robot", &friend).character_gender, "not human");
    assert_eq!(read("two sisters", &friend).character_gender, "several");
    assert_eq!(read("a dragon", &friend).character_gender, "as told");
    let lost = kinds(&["Someone I lost"]);
    assert_eq!(read("two sisters", &lost).character_gender, "as told");
    let line = settle(&friend, &unknown(), "Man; with a beard", "", "seed");
    assert_eq!(line.character_gender, "man");
    assert_eq!(line.character_words, "with a beard");
}

#[tokio::test]
async fn a_changed_answer_clears_the_read_and_the_new_read_drops_a_stale_answer() {
    let script = Script::default();
    let done = made(&script, &["A friend"]).await;
    assert!(slots(&done).contains(&"character"));
    assert!(done.read.is_some());
    let back = back_to(&script, done, "why").await;
    let said = "she is a woman I once knew well";
    let script = script.then("gender read", read_of("woman", "unknown", said));
    let changed = step(&script, &back, free(said), "en").await.unwrap();
    assert_eq!(changed.read.as_ref().unwrap().character, "woman");
    let again = finish(&script, changed, &[]).await;
    assert!(!slots(&again).contains(&"character"));
    assert!(slots(&again).contains(&"treat"));
    assert_eq!(gender::choices(&again).character_gender, "woman");
    let told = script.sent("gender read");
    assert!(!told.last().unwrap().contains(texts::CHARACTER_QUESTION));
}

#[tokio::test]
async fn a_gender_answer_changed_by_back_keeps_the_read() {
    let script = Script::default();
    let done = made(&script, &["A friend"]).await;
    let calls = script.sent("gender read").len();
    let back = step(&script, &done, Move::Back, "en").await.unwrap();
    let other = picks(&[texts::TREAT_CHOICES[2]]);
    let changed = step(&script, &back, other, "en").await.unwrap();
    assert_eq!(changed.asking, None);
    assert_eq!(gender::choices(&changed).treat_user, "woman");
    assert_eq!(script.sent("gender read").len(), calls);
}

#[tokio::test]
async fn thats_not_it_on_the_kinds_drops_a_character_answer_no_longer_offered() {
    let script = Script::default();
    let done = made(&script, &["A friend"]).await;
    let index = slots(&done).iter().position(|s| *s == "kinds").unwrap();
    let mut changed = reanswer(&done, index, picks(&["Someone I lost"])).unwrap();
    gender::finish(&script, &mut changed).await;
    assert!(!slots(&changed).contains(&"character"));
    assert!(slots(&changed).contains(&"treat"));
}

#[tokio::test]
async fn just_make_it_reads_and_asks_neither() {
    let script = Script::default();
    let interview = run(&script, Style::Tree, vec![free(LONG), Move::JustMakeIt]).await;
    assert_eq!(interview.asking, None);
    assert_eq!(slots(&interview), ["wanted"]);
    assert_eq!(script.sent("gender read").len(), 1);
    assert!(interview.read.is_some());
    assert_eq!(gender::choices(&interview).treat_user, "anyone");
    assert!(gender::choices(&interview).draw.is_some());
}

#[tokio::test]
async fn nothing_told_needs_no_read() {
    let script = Script::default();
    let interview = run(&script, Style::Tree, vec![Move::JustMakeIt]).await;
    assert_eq!(interview.asking, None);
    assert!(script.sent("gender read").is_empty());
}

#[tokio::test]
async fn the_treat_question_takes_no_free_line_and_which_me_one_pick() {
    let script = Script::default();
    let done = made(&script, &[texts::THE_USER]).await;
    let which = done.log.iter().find(|e| e.slot == "which_me").unwrap();
    assert!(!which.multi);
    let at_treat = step(&script, &done, Move::Back, "en").await.unwrap();
    let with_line = Move::Answer {
        picks: vec![texts::TREAT_CHOICES[1].to_string()],
        free: "and more".to_string(),
    };
    let treat = step(&script, &at_treat, with_line, "en").await.unwrap();
    assert_eq!(treat.answer("treat"), texts::TREAT_CHOICES[1]);
}

#[tokio::test]
async fn the_relation_is_asked_after_the_kinds_only_for_those_that_do_not_say_it() {
    let script = Script::default();
    let open = vec![free(LONG), picks(&[]), picks(&[])];
    let at_kinds = run(&script, Style::Tree, open).await;
    let vague = step(&script, &at_kinds, picks(&["Not sure"]), "en")
        .await
        .unwrap();
    assert_eq!(vague.asking.as_ref().unwrap().slot, "relation");
    let plain = step(&script, &at_kinds, picks(&["A friend"]), "en")
        .await
        .unwrap();
    assert_ne!(plain.asking.as_ref().unwrap().slot, "relation");

    let done = finish(&script, vague, &[]).await;
    assert!(slots(&done).contains(&"relation"));
    let back = back_to(&script, done, "kinds").await;
    let changed = step(&script, &back, picks(&["A friend"]), "en")
        .await
        .unwrap();
    assert!(!slots(&changed).contains(&"relation"));
}

#[tokio::test]
async fn a_known_character_is_never_probed() {
    let script = Script::default();
    let moves = vec![
        free(LONG),
        picks(&[]),
        picks(&[]),
        picks(&["A character I already know"]),
    ];
    let mut tree = run(&script, Style::Tree, moves.clone()).await;
    while tree.asking.as_ref().unwrap().slot != "known_character" {
        tree = step(&script, &tree, free(LONG), "en").await.unwrap();
    }
    let next = step(&script, &tree, free("Ada"), "en").await.unwrap();
    assert_eq!(next.asking.unwrap().slot, "own_role");

    let vague = json!({"fills": [], "touched": [], "vague": true});
    let tagging = Script::default();
    let mut hybrid = run(&tagging, Style::Hybrid, moves).await;
    while hybrid.asking.as_ref().unwrap().slot != "known_character" {
        hybrid = step(&tagging, &hybrid, free(LONG), "en").await.unwrap();
    }
    let tagging = tagging.then("tagger", vague);
    let next = step(&tagging, &hybrid, free("Ada"), "en").await.unwrap();
    assert_ne!(next.asking.unwrap().slot, "known_character");
}

#[test]
fn each_need_has_its_branch_and_the_list_is_the_cards_own() {
    assert_eq!(texts::NEEDS.len(), 31);
    assert_eq!(texts::KIND_NAMES.len(), 26);
    assert_eq!(texts::BRANCH.len(), texts::NEEDS.len());
    for need in texts::NEEDS.iter() {
        assert!(
            texts::BRANCH.iter().any(|(name, ..)| name == need),
            "{need}"
        );
    }
}

#[tokio::test]
async fn the_cloud_asks_the_relation_behind_the_kinds_only_for_those_that_do_not_say_it() {
    let script = Script::default();
    let vague = finish(&script, Interview::new(Style::Cloud), &["Not sure"]).await;
    let at = |slot: &str| slots(&vague).iter().position(|s| *s == slot);
    assert!(at("relation").unwrap() > at("kinds").unwrap());

    let plain = finish(&script, Interview::new(Style::Cloud), &["A friend"]).await;
    assert!(!slots(&plain).contains(&"relation"));
}

#[tokio::test]
async fn the_hybrid_words_which_me_as_one_pick() {
    let script = Script::default();
    let done = finish(&script, Interview::new(Style::Hybrid), &[texts::THE_USER]).await;
    let which = done.log.iter().find(|e| e.slot == "which_me").unwrap();
    assert!(!which.multi);
}

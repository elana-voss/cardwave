//! The interview's engine on scripted models: [`Script`] answers by role, what it
//! was given or a plain default, and keeps what it was asked.

use std::collections::{HashMap, VecDeque};
use std::future::Future;
use std::sync::Mutex;

use cw_provider::form::Question;
use serde_json::{Value, json};

use super::*;

/// Answers by role: what `then` queued, else a plain answer.
#[derive(Default)]
pub(super) struct Script {
    queued: Mutex<HashMap<String, VecDeque<Value>>>,
    pub(super) asked: Mutex<Vec<(String, String)>>,
    /// The system prompt of each call, in the order of `asked`.
    pub(super) systems: Mutex<Vec<String>>,
    fail: Mutex<HashMap<String, Code>>,
}

impl Script {
    pub(super) fn then(self, role: &str, reply: Value) -> Self {
        let mut queued = self.queued.lock().unwrap();
        queued.entry(role.to_string()).or_default().push_back(reply);
        drop(queued);
        self
    }

    /// `role`'s every call fails with `code`.
    pub(super) fn failing(self, role: &str, code: Code) -> Self {
        self.fail.lock().unwrap().insert(role.to_string(), code);
        self
    }

    /// The user messages `role` was sent.
    pub(super) fn sent(&self, role: &str) -> Vec<String> {
        let asked = self.asked.lock().unwrap();
        let of_role = asked.iter().filter(|(who, _)| who == role);
        of_role.map(|(_, user)| user.clone()).collect()
    }
}

impl Models for Script {
    fn ask(&self, question: &Question<'_>) -> impl Future<Output = anyhow::Result<Value>> + Send {
        let (role, user) = (question.role, question.user);
        self.asked
            .lock()
            .unwrap()
            .push((role.to_string(), user.to_string()));
        self.systems
            .lock()
            .unwrap()
            .push(question.system.to_string());
        let failed = self.fail.lock().unwrap().get(role).copied();
        let queued = self
            .queued
            .lock()
            .unwrap()
            .get_mut(role)
            .and_then(VecDeque::pop_front);
        let plain = match role {
            "rank kinds" => json!({"kinds": texts::KIND_NAMES[..6]}),
            "interviewer" => {
                let first = user.lines().next().unwrap_or_default();
                json!({"question": format!("Q {first}"), "choices": []})
            }
            "cloud light" => json!({"lit": []}),
            "tagger" => json!({"fills": [], "touched": [], "vague": false}),
            "gender read" => json!({"character": "unknown", "treat": "unknown", "words": ""}),
            _ => Value::Null,
        };
        std::future::ready(match failed {
            Some(code) => Err(anyhow::anyhow!(Fail::said(code, "scripted"))),
            None => Ok(queued.unwrap_or(plain)),
        })
    }
}

pub(super) fn free(said: &str) -> Move {
    Move::Answer {
        picks: Vec::new(),
        free: said.to_string(),
    }
}

pub(super) fn picks(said: &[&str]) -> Move {
    Move::Answer {
        picks: said.iter().map(|pick| pick.to_string()).collect(),
        free: String::new(),
    }
}

/// `moves` in turn; panics where a step fails.
pub(super) async fn run(script: &Script, style: Style, moves: Vec<Move>) -> Interview {
    let mut interview = Interview::new(style);
    for action in moves {
        interview = step(script, &interview, action, "en").await.unwrap();
    }
    interview
}

pub(super) fn slots(interview: &Interview) -> Vec<&str> {
    interview
        .log
        .iter()
        .map(|entry| entry.slot.as_str())
        .collect()
}

pub(super) const LONG: &str = "a long enough answer of many words";

/// Long free answers until the read-back; `kinds` on the kinds question.
pub(super) async fn finish(script: &Script, mut interview: Interview, kinds: &[&str]) -> Interview {
    while let Some(asking) = interview.asking.clone() {
        let action = if asking.slot == "kinds" {
            picks(kinds)
        } else if asking.slot == "treat" {
            picks(&[texts::TREAT_CHOICES[0]])
        } else {
            free(LONG)
        };
        interview = step(script, &interview, action, "en").await.unwrap();
    }
    interview
}

#[tokio::test]
async fn the_tree_asks_in_its_order() {
    let script = Script::default();
    let moves = vec![
        free(LONG),
        picks(&[texts::MOMENTS[0]]),
        picks(&[texts::NEEDS[2], texts::NEEDS[0], texts::NEEDS[1]]),
    ];
    let opened = run(&script, Style::Tree, moves).await;
    let done = finish(&script, opened, &["Not sure"]).await;
    let got = slots(&done);
    let branch_2 = format!("branch: {}", texts::NEEDS[2]);
    let branch_0 = format!("branch: {}", texts::NEEDS[0]);
    let mut wanted = vec!["wanted", "moments", "needs", "kinds", "relation"];
    wanted.extend([branch_2.as_str(), branch_0.as_str()]);
    wanted.extend(["why", "loved", "third person", "moment", "deal", "standing"]);
    wanted.extend(["character", "treat"]);
    assert_eq!(got, wanted);
    let why = format!("You said \"{LONG}\". Why does that matter to you right now?");
    assert_eq!(done.log[7].question, why);
    assert_eq!(done.kinds, ["Not sure"]);
    assert!(!done.guard_hit);
}

#[tokio::test]
async fn an_answer_is_its_picks_then_its_free_line_and_the_log_tells_skips() {
    let script = Script::default();
    let two = vec![texts::MOMENTS[0].to_string(), "second".to_string()];
    let moves = vec![
        Move::Skip,
        Move::Answer {
            picks: two,
            free: " mine ".to_string(),
        },
        Move::DontKnow,
    ];
    let interview = run(&script, Style::Tree, moves).await;
    assert_eq!(interview.log[0].answer, None);
    assert!(interview.log[0].skipped);
    let said = format!("{}; second; mine", texts::MOMENTS[0]);
    assert_eq!(interview.log[1].answer.as_deref(), Some(said.as_str()));
    assert_eq!(interview.log[2].answer.as_deref(), Some(""));
    assert!(interview.log[2].dont_know);
    let text = interview.answers_text();
    assert!(text.starts_with(&format!("- {} -> (skipped)\n", texts::WANTED)));
    assert!(text.ends_with(&format!("- {} -> (don't know)", texts::NEEDS_QUESTION)));
}

#[tokio::test]
async fn just_make_it_goes_to_the_read_back_and_the_kinds_are_not_sure() {
    let script = Script::default();
    let interview = run(&script, Style::Tree, vec![free(LONG), Move::JustMakeIt]).await;
    assert_eq!(interview.asking, None);
    assert_eq!(interview.kinds, ["Not sure"]);
    assert_eq!(slots(&interview), ["wanted"]);
}

#[tokio::test]
async fn just_make_it_after_a_failed_step_keeps_its_answer_with_no_call() {
    let script = Script::default();
    let at_second = run(&script, Style::Tree, vec![free(LONG)]).await;
    let ended = Move::EndAfter(Box::new(free(LONG)));
    let interview = step(&script, &at_second, ended, "en").await.unwrap();
    assert_eq!(interview.asking, None);
    assert_eq!(slots(&interview).len(), 2);
    assert_eq!(interview.log[1].answer.as_deref(), Some(LONG));
}

#[tokio::test]
async fn just_make_it_after_anything_but_an_answer_is_refused_and_changes_nothing() {
    let script = Script::default();
    let at_second = run(&script, Style::Tree, vec![free(LONG)]).await;
    for inner in [Move::Back, Move::JustMakeIt] {
        let ended = Move::EndAfter(Box::new(inner));
        assert!(step(&script, &at_second, ended, "en").await.is_err());
    }
}

#[tokio::test]
async fn the_kinds_question_no_pick_is_the_first_shown_and_two_at_most() {
    let ranked = json!({"kinds": ["Not a kind", texts::KIND_NAMES[3]]});
    let script = Script::default().then("rank kinds", ranked);
    let moves = vec![free(LONG), picks(&[]), picks(&[])];
    let at_kinds = run(&script, Style::Tree, moves).await;
    let asking = at_kinds.asking.clone().unwrap();
    assert_eq!(asking.slot, "kinds");
    assert_eq!(asking.choices.len(), 6);
    assert_eq!(asking.choices[0], texts::KIND_NAMES[3]);
    let none = step(&script, &at_kinds, Move::Skip, "en").await.unwrap();
    assert_eq!(none.kinds, [texts::KIND_NAMES[3]]);
    assert!(!none.log[3].skipped);
    let three = picks(&texts::KIND_NAMES[..3]);
    let many = step(&script, &at_kinds, three, "en").await.unwrap();
    assert_eq!(many.kinds.len(), 2);
}

#[tokio::test]
async fn the_tree_probes_a_vague_free_answer_once_not_on_the_opening() {
    let script = Script::default();
    let moves = vec![free("short"), picks(&[]), picks(&[]), picks(&[])];
    let mut interview = run(&script, Style::Tree, moves).await;
    assert_eq!(interview.asking.as_ref().unwrap().slot, "why");
    interview = step(&script, &interview, free("too short"), "en")
        .await
        .unwrap();
    let probe = interview.asking.clone().unwrap();
    assert_eq!(probe.slot, "why probe");
    let worded = "You said \"too short\". Could you tell me one concrete moment when that was so?";
    assert_eq!(probe.question, worded);
    interview = step(&script, &interview, free("still short"), "en")
        .await
        .unwrap();
    assert_eq!(interview.asking.as_ref().unwrap().slot, "loved");
    interview = step(&script, &interview, free("short too"), "en")
        .await
        .unwrap();
    assert_ne!(interview.asking.as_ref().unwrap().slot, "loved probe");
}

#[tokio::test]
async fn a_failed_call_keeps_nothing_of_the_step() {
    struct Down;
    impl Models for Down {
        fn ask(&self, _: &Question<'_>) -> impl Future<Output = anyhow::Result<Value>> + Send {
            std::future::ready(Err(anyhow::anyhow!("down")))
        }
    }
    let moves = vec![free(LONG), picks(&[])];
    let at_needs = run(&Script::default(), Style::Tree, moves).await;
    assert!(step(&Down, &at_needs, picks(&[]), "en").await.is_err());
    assert_eq!(at_needs.log.len(), 2);
}

#[tokio::test]
async fn the_cloud_asks_the_same_few_and_no_needs_or_moments_unless_lit() {
    let script = Script::default();
    let opened = run(&script, Style::Cloud, vec![free(LONG)]).await;
    assert_eq!(opened.asking.as_ref().unwrap().slot, "why");
    let done = finish(&script, opened, &["A coach"]).await;
    let own = kind_slots(&["A coach".to_string()]);
    let mut wanted = vec![
        "wanted",
        "why",
        "loved",
        "third person",
        "deal",
        "standing",
        "kinds",
    ];
    wanted.extend(own);
    wanted.extend(["character", "treat"]);
    assert_eq!(slots(&done), wanted);
    let third = done.log.iter().find(|e| e.slot == "third person").unwrap();
    assert_eq!(third.question, texts::THIRD);
    let worded = script.sent("interviewer");
    let (_, why) = texts::SLOT_TEXT.iter().find(|(s, _)| *s == "why").unwrap();
    let answers = format!("- {} -> {LONG}", texts::WANTED);
    assert_eq!(
        worded[0],
        format!("Slot to fill: {why}\nAnswers so far:\n{answers}")
    );
    assert!(!done.guard_hit);
}

#[tokio::test]
async fn the_cloud_asks_what_lit_up_next_two_at_most_and_nothing_known() {
    let script = Script::default()
        .then("cloud light", json!({"lit": []}))
        .then("cloud light", json!({"lit": [" the sea ", "WHY", "third"]}))
        .then("cloud light", json!({"lit": ["The Sea", "her father"]}));
    let moves = vec![free(LONG), free(LONG)];
    let interview = run(&script, Style::Cloud, moves).await;
    // "WHY" was asked already, and only the first two count.
    let asking = interview.asking.clone().unwrap();
    assert_eq!(asking.slot, "lit: the sea");
    let sent = script.sent("cloud light");
    let first = format!(
        "Asked about already: []\nAnswers so far:\n- {} -> {LONG}\nLast question: {}\nLast answer: {LONG}",
        texts::WANTED,
        texts::WANTED
    );
    assert_eq!(sent[0], first);
    assert!(sent[1].starts_with("Asked about already: [\"why\"]\n"));
    let worded = script.sent("interviewer");
    assert!(
        worded
            .last()
            .unwrap()
            .starts_with("Lit up, to ask about: the sea\nAnswers so far:\n")
    );
    let next = step(&script, &interview, free(LONG), "en").await.unwrap();
    assert_eq!(next.asking.unwrap().slot, "lit: her father");
    assert!(script.sent("cloud light")[2].contains("[\"why\", \"the sea\", \"the sea\"]\n"));
}

#[tokio::test]
async fn the_cloud_lights_by_the_probes_answer_and_a_skip_lights_nothing() {
    let script = Script::default();
    let moves = vec![free("short"), free("the probed answer")];
    let probed = run(&script, Style::Cloud, moves).await;
    assert_eq!(slots(&probed), ["wanted", "wanted probe"]);
    assert!(script.sent("cloud light")[0].ends_with("Last answer: the probed answer"));
    let quiet = Script::default();
    let moves = vec![free(LONG), Move::Skip, Move::DontKnow];
    let interview = run(&quiet, Style::Cloud, moves).await;
    assert_eq!(quiet.sent("cloud light").len(), 1);
    assert_eq!(interview.log[1].lit, Some(Vec::new()));
}

#[tokio::test]
async fn the_cloud_drops_what_lit_up_past_the_room_under_the_limit() {
    let mut script = Script::default();
    for at in 0..4 {
        script = script.then(
            "cloud light",
            json!({"lit": [format!("a{at}"), format!("b{at}")]}),
        );
    }
    let done = finish(&script, Interview::new(Style::Cloud), &["Not sure"]).await;
    let lit = done
        .log
        .iter()
        .filter(|e| e.slot.starts_with("lit: "))
        .count();
    assert!(
        gender::guard_count(&done.log) <= GUARD && !done.guard_hit,
        "{:?}",
        slots(&done)
    );
    // The wanted, the five slots and what fits make ten.
    assert_eq!(lit, 4);
}

/// A Hybrid past its opening, at its first drilled question.
async fn drilling(script: &Script, kinds: &[&str]) -> Interview {
    let moves = vec![free(LONG), picks(&[]), picks(&[]), picks(kinds)];
    let interview = run(script, Style::Hybrid, moves).await;
    if interview
        .asking
        .as_ref()
        .is_some_and(|a| a.slot == "relation")
    {
        return step(script, &interview, picks(&[]), "en").await.unwrap();
    }
    interview
}

#[tokio::test]
async fn the_hybrid_drills_its_slots_with_the_friend_right_after_the_why() {
    let script = Script::default();
    let opened = drilling(&script, &["A coach"]).await;
    let done = finish(&script, opened, &[]).await;
    let wanted = [
        "wanted",
        "moments",
        "needs",
        "kinds",
        "why",
        "third person",
        "loved",
        "moment",
        "deal",
        "standing",
        "goal_method",
        "character",
        "treat",
    ];
    assert_eq!(slots(&done), wanted);
    assert!(!done.guard_hit);
    let third = done.log.iter().find(|e| e.slot == "third person").unwrap();
    assert_eq!(third.question, texts::THIRD);
    let worded = script.sent("interviewer");
    assert_eq!(worded.len(), 6);
    let (_, why) = texts::SLOT_TEXT.iter().find(|(s, _)| *s == "why").unwrap();
    let start = format!("Slot to fill: {why}\nKinds picked: ['A coach']\nAnswers so far:\n- ");
    assert!(worded[0].starts_with(&start), "{}", worded[0]);
    let tagged = script.sent("tagger");
    assert_eq!(
        tagged.len(),
        6,
        "the friend's answer and the opening are not tagged"
    );
    assert!(
        tagged[1].starts_with("Open slots: {\"loved\": \""),
        "{}",
        tagged[1]
    );
    let question = "\", \"moment\": \"";
    assert!(tagged[1].contains(question), "{}", tagged[1]);
    assert!(tagged[0].ends_with(&format!("\nAnswer: {LONG}")));
}

#[tokio::test]
async fn the_hybrid_goes_to_what_an_answer_touched_and_closes_what_it_filled() {
    let tag = json!({"fills": ["loved", "not a slot"], "touched": ["standing"], "vague": false});
    let script = Script::default().then("tagger", tag);
    let opened = drilling(&script, &["Not sure"]).await;
    let done = finish(&script, opened, &[]).await;
    let drilled = &slots(&done)[5..];
    assert_eq!(
        drilled,
        [
            "why",
            "third person",
            "standing",
            "moment",
            "deal",
            "character",
            "treat"
        ]
    );
}

#[tokio::test]
async fn the_hybrid_asks_a_vague_slot_once_more_only_once() {
    let vague = json!({"fills": ["loved"], "touched": [], "vague": true});
    let script = Script::default()
        .then("tagger", vague.clone())
        .then("tagger", vague.clone())
        .then("tagger", vague);
    let opened = drilling(&script, &["Not sure"]).await;
    let done = finish(&script, opened, &[]).await;
    let drilled = &slots(&done)[5..];
    let wanted = [
        "why",
        "why",
        "third person",
        "moment",
        "deal",
        "standing",
        "character",
        "treat",
    ];
    assert_eq!(
        drilled, wanted,
        "the second vague closes why and fills loved"
    );
    let worded = script.sent("interviewer");
    assert!(!worded[0].ends_with(texts::VAGUE_AGAIN));
    assert!(worded[1].ends_with(texts::VAGUE_AGAIN));
    assert!(!worded[2].ends_with(texts::VAGUE_AGAIN));
}

#[tokio::test]
async fn the_hybrid_closes_a_skipped_or_unknown_slot_with_no_tagger() {
    let script = Script::default();
    let mut interview = drilling(&script, &["Not sure"]).await;
    for action in [Move::Skip, free(LONG), Move::DontKnow] {
        interview = step(&script, &interview, action, "en").await.unwrap();
    }
    let drilled = &slots(&interview)[5..];
    assert_eq!(drilled, ["why", "third person", "loved"]);
    assert_eq!(interview.asking.unwrap().slot, "moment");
    assert!(script.sent("tagger").is_empty());
}

/// `interview` with plain questions in its log, as at that point of a run.
pub(super) fn with_asked(style: Style, count: usize) -> Interview {
    let mut interview = Interview::new(style);
    for at in 0..count {
        let asking = free_question(&format!("x{at}"), "a question");
        let entry = entry_of(&interview, asking, free(LONG));
        interview.log.push(entry);
    }
    interview
}

#[tokio::test]
async fn the_limit_ends_an_interview_as_a_failure_probe_or_question_left() {
    let script = Script::default();
    for said in [LONG, "short"] {
        let at_last = with_asked(Style::Tree, 15);
        let over = step(&script, &at_last, free(said), "en").await.unwrap();
        assert!(over.guard_hit, "{said}");
        assert_eq!(over.asking.unwrap().slot, "character");
    }
}

#[tokio::test]
async fn the_trees_fullest_run_fits_the_limit_exactly() {
    let script = Script::default();
    let moves = vec![
        free(LONG),
        picks(&[]),
        picks(&texts::NEEDS[..2]),
        picks(&["A character I already know", "A coach"]),
        picks(&[]),
        picks(&[texts::BRANCH[0].2[0]]),
        picks(&[texts::BRANCH[0].2[0]]),
    ];
    let mut interview = Interview::new(Style::Tree);
    for action in moves {
        interview = step(&script, &interview, action, "en").await.unwrap();
    }
    let done = finish(&script, interview, &[]).await;
    assert_eq!(gender::guard_count(&done.log), GUARD, "{:?}", slots(&done));
    assert_eq!(done.log.len(), GUARD + 2);
    assert!(!done.guard_hit);
}

#[tokio::test]
async fn the_cloud_probes_once() {
    let script = Script::default();
    let moves = vec![free("short"), free("short too"), free("short")];
    let interview = run(&script, Style::Cloud, moves).await;
    assert_eq!(slots(&interview), ["wanted", "wanted probe", "why"]);
    assert_eq!(interview.asking.unwrap().slot, "loved");
}

#[tokio::test]
async fn back_then_the_same_answer_restores_all_with_no_call() {
    let lit = json!({"lit": ["the sea"]});
    let script = Script::default().then("cloud light", lit);
    let moves = vec![free(LONG), free(LONG)];
    let at = run(&script, Style::Cloud, moves).await;
    let calls = script.asked.lock().unwrap().len();
    let mut back = at.clone();
    for _ in 0..2 {
        back = step(&script, &back, Move::Back, "en").await.unwrap();
    }
    assert_eq!(slots(&back), Vec::<&str>::new());
    assert_eq!(back.asking.as_ref().unwrap().slot, "wanted");
    let again = step(&script, &back, free(LONG), "en").await.unwrap();
    assert_eq!(again, at);
    assert_eq!(script.asked.lock().unwrap().len(), calls);
}

#[tokio::test]
async fn back_from_the_read_back_is_allowed() {
    let script = Script::default();
    let done = finish(&script, Interview::new(Style::Tree), &["Not sure"]).await;
    let last = done.log.last().unwrap().slot.clone();
    let back = step(&script, &done, Move::Back, "en").await.unwrap();
    assert_eq!(back.asking.as_ref().unwrap().slot, last);
    let same = picks(&[texts::TREAT_CHOICES[0]]);
    assert_eq!(step(&script, &back, same, "en").await.unwrap(), done);
    let other = picks(&[texts::TREAT_CHOICES[1]]);
    let changed = step(&script, &back, other, "en").await.unwrap();
    assert_eq!(changed.asking, None);
    assert_eq!(changed.log.len(), done.log.len());
}

/// Back until `slot` is the question shown.
pub(super) async fn back_to(script: &Script, mut interview: Interview, slot: &str) -> Interview {
    while interview
        .asking
        .as_ref()
        .is_none_or(|asking| asking.slot != slot)
    {
        interview = step(script, &interview, Move::Back, "en").await.unwrap();
    }
    interview
}

#[tokio::test]
async fn a_changed_cloud_answer_drops_what_it_lit_and_what_that_lit() {
    let script = Script::default()
        .then("cloud light", json!({"lit": ["the sea"]}))
        .then("cloud light", json!({"lit": ["her father"]}))
        .then("cloud light", json!({"lit": []}));
    let moves = vec![free(LONG), free(LONG), free(LONG)];
    let at = run(&script, Style::Cloud, moves).await;
    assert_eq!(slots(&at)[1..], ["lit: the sea", "lit: her father"]);
    let back = back_to(&script, at, "wanted").await;
    let script = script.then("cloud light", json!({"lit": ["the lake"]}));
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(slots(&changed), ["wanted"]);
    assert_eq!(changed.asking.unwrap().slot, "lit: the lake");
}

#[tokio::test]
async fn a_changed_probe_answer_lights_its_parent_anew() {
    let script = Script::default()
        .then("cloud light", json!({"lit": ["the sea"]}))
        .then("cloud light", json!({"lit": []}));
    let moves = vec![free("short"), free(LONG), free(LONG)];
    let at = run(&script, Style::Cloud, moves).await;
    assert_eq!(slots(&at)[2], "lit: the sea");
    let back = back_to(&script, at, "wanted probe").await;
    let script = script.then("cloud light", json!({"lit": ["the lake"]}));
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(slots(&changed), ["wanted", "wanted probe"]);
    assert_eq!(changed.asking.unwrap().slot, "lit: the lake");
    let sent = script.sent("cloud light");
    assert!(
        sent.last()
            .unwrap()
            .ends_with("another long answer of many words")
    );
}

#[tokio::test]
async fn a_changed_hybrid_answer_drops_what_it_touched() {
    let tag = json!({"fills": [], "touched": ["standing"], "vague": false});
    let script = Script::default().then("tagger", tag);
    let opened = drilling(&script, &["Not sure"]).await;
    let mut at = opened;
    for _ in 0..3 {
        at = step(&script, &at, free(LONG), "en").await.unwrap();
    }
    assert_eq!(slots(&at)[5..], ["why", "third person", "standing"]);
    let back = back_to(&script, at, "why").await;
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(slots(&changed)[5..], ["why", "third person"]);
    assert_eq!(changed.asking.unwrap().slot, "loved");
}

#[tokio::test]
async fn a_changed_vague_hybrid_answer_drops_its_second_try() {
    let vague = json!({"fills": [], "touched": [], "vague": true});
    let script = Script::default().then("tagger", vague);
    let opened = drilling(&script, &["Not sure"]).await;
    let mut at = opened;
    for _ in 0..2 {
        at = step(&script, &at, free(LONG), "en").await.unwrap();
    }
    assert_eq!(slots(&at)[5..], ["why", "why"]);
    let mut back = step(&script, &at, Move::Back, "en").await.unwrap();
    back = step(&script, &back, Move::Back, "en").await.unwrap();
    assert_eq!(back.asking.as_ref().unwrap().slot, "why");
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(slots(&changed)[5..], ["why"]);
    assert_eq!(changed.asking.unwrap().slot, "third person");
}

#[tokio::test]
async fn a_changed_tree_answer_asks_anew_what_rests_on_it() {
    let script = Script::default();
    let moves = vec![
        free(LONG),
        picks(&[]),
        picks(&texts::NEEDS[..1]),
        picks(&["A coach"]),
        picks(&[texts::BRANCH[0].2[0]]),
        free(LONG),
    ];
    let at = run(&script, Style::Tree, moves).await;
    let branch = format!("branch: {}", texts::NEEDS[0]);
    assert!(slots(&at).contains(&branch.as_str()));
    let back = back_to(&script, at.clone(), "wanted").await;
    let wish = "another long answer of many words";
    let reworded = step(&script, &back, free(wish), "en").await.unwrap();
    assert!(!slots(&reworded).contains(&"why"));
    let why = reworded.asking.unwrap();
    assert_eq!(why.slot, "why");
    assert!(why.question.english().contains(wish));
    let back = back_to(&script, at, "needs").await;
    let other = picks(&texts::NEEDS[1..2]);
    let changed = step(&script, &back, other, "en").await.unwrap();
    assert!(!slots(&changed).contains(&branch.as_str()));
    let next = changed.asking.unwrap().slot;
    assert_eq!(next, format!("branch: {}", texts::NEEDS[1]));
}

#[tokio::test]
async fn changed_kinds_drop_the_own_questions_no_longer_wanted() {
    let script = Script::default();
    let opened = run(
        &script,
        Style::Tree,
        vec![free(LONG), picks(&[]), picks(&[])],
    )
    .await;
    let done = finish(&script, opened, &["A coach"]).await;
    assert!(slots(&done).contains(&"goal_method"));
    let back = back_to(&script, done, "kinds").await;
    let changed = step(&script, &back, picks(&[texts::THE_USER]), "en")
        .await
        .unwrap();
    assert!(!slots(&changed).contains(&"goal_method"));
    assert_eq!(changed.asking.unwrap().slot, "which_me");
    assert_eq!(changed.kinds, [texts::THE_USER]);
}

/// A Hybrid asking "deal", having answered why, third person, loved and moment.
async fn at_the_deal(script: &Script) -> Interview {
    let mut interview = drilling(script, &[]).await;
    while interview.asking.as_ref().unwrap().slot != "deal" {
        interview = step(script, &interview, free(LONG), "en").await.unwrap();
    }
    interview
}

#[tokio::test]
async fn a_changed_hybrid_answer_decides_the_next_question_over_a_later_kept_one() {
    let script = Script::default();
    let at = at_the_deal(&script).await;
    let back = back_to(&script, at, "loved").await;
    let reply = json!({"fills": [], "touched": ["standing"], "vague": false});
    let script = script.then("tagger", reply);
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(changed.asking.unwrap().slot, "standing");
}

#[tokio::test]
async fn a_vague_changed_hybrid_answer_is_asked_again_as_a_second_try() {
    let script = Script::default();
    let at = at_the_deal(&script).await;
    let back = back_to(&script, at, "loved").await;
    let reply = json!({"fills": [], "touched": [], "vague": true});
    let script = script.then("tagger", reply);
    let changed = step(
        &script,
        &back,
        free("another long answer of many words"),
        "en",
    )
    .await
    .unwrap();
    assert_eq!(changed.asking.as_ref().unwrap().slot, "loved");
    let asked = script.sent("interviewer");
    assert!(asked.last().unwrap().ends_with(texts::VAGUE_AGAIN));
    let next = step(&script, &changed, free(LONG), "en").await.unwrap();
    assert_eq!(next.asking.unwrap().slot, "deal");
}

#[tokio::test]
async fn back_from_a_probe_behind_kept_answers_shows_the_answer_it_probes() {
    let script = Script::default();
    let mut at = run(
        &script,
        Style::Tree,
        vec![free(LONG), picks(&[]), picks(&[])],
    )
    .await;
    while at.asking.as_ref().unwrap().slot != "moment" {
        let action = if at.asking.as_ref().unwrap().slot == "kinds" {
            picks(&[])
        } else {
            free(LONG)
        };
        at = step(&script, &at, action, "en").await.unwrap();
    }
    let back = back_to(&script, at, "why").await;
    let probing = step(&script, &back, free("short"), "en").await.unwrap();
    assert_eq!(probing.asking.as_ref().unwrap().slot, "why probe");
    let shown = step(&script, &probing, Move::Back, "en").await.unwrap();
    assert_eq!(shown.asking.as_ref().unwrap().slot, "why");
    assert_eq!(shown.ahead[0].slot, "why");
    let again = step(&script, &shown, free("short"), "en").await.unwrap();
    assert_eq!(again, probing);
}

#[tokio::test]
async fn a_probe_cut_by_the_limit_asks_no_model() {
    let script = Script::default();
    let mut at_last = with_asked(Style::Cloud, 15);
    at_last.log[0].slot = "relation".to_string();
    at_last.asking = Some(free_question("lit: the sea", "a question"));
    let over = step(&script, &at_last, free("short"), "en").await.unwrap();
    assert!(over.guard_hit);
    assert_eq!(over.asking.as_ref().unwrap().slot, "character");
    let answered = step(&script, &over, picks(&["Woman"]), "en").await.unwrap();
    assert_eq!(answered.asking.unwrap().slot, "treat");
    assert!(script.sent("cloud light").is_empty());
}

#[test]
fn the_interviewer_asks_for_choices_that_are_answers() {
    assert!(
        texts::INTERVIEWER
            .contains("Each choice is an answer the user could give, never a question.")
    );
}

#[test]
fn no_named_text_says_he_or_she_outside_the_rules_chosen_by_the_two_answers() {
    let slots = texts::SLOT_TEXT.iter().map(|(_, text)| *text);
    let prompts = [
        texts::INTERVIEWER,
        texts::LIGHT,
        texts::TAGGER,
        texts::GENDER_READ,
        texts::READ_BACK_FOCUSED,
        texts::CRAFT,
        texts::WRITER_PLAN,
        texts::WRITER_CARD,
        texts::FIRST_MES_RULE,
        texts::CAST_CARD,
        texts::CAST_PLAN,
    ];
    let assumed = [
        "he", "she", "him", "her", "his", "hers", "himself", "herself",
    ];
    for text in slots.chain(prompts) {
        let lowered = text.to_lowercase();
        let found = lowered
            .split(|c: char| !c.is_alphabetic())
            .filter(|word| assumed.contains(word))
            .count();
        assert_eq!(found, 0, "{text}");
    }
}

//! The interview as it crosses the wire: every state and move goes to JSON and
//! back between steps, as the page holds them, and every prompt to the models
//! stays byte for byte as `tests/interview_prompts.txt` pins it. After a wanted
//! change of a prompt: `PIN_WRITE=1` writes the file anew, and its diff is read.

use cw_ccv4::creation::Private;
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::json;

use super::readback::{corrected, read_back};
use super::tests::*;
use super::tests_writer::{good, plan};
use super::writer::{Making, write_card};
use super::*;

fn wire<T: Serialize + DeserializeOwned>(value: &T) -> T {
    serde_json::from_value(serde_json::to_value(value).unwrap()).unwrap()
}

/// The answer of `round` to `asking`: its first choices by index, now and then a
/// free line beside; a short free answer every fourth round, so probes come.
fn answer_of(asking: &Asking, round: usize) -> Move {
    if asking.choices.is_empty() {
        return free(if round % 4 == 3 { "not sure" } else { LONG });
    }
    let count = if asking.multi { 2 } else { 1 };
    let picks = asking.choices.iter().take(count).cloned().collect();
    let free = if round.is_multiple_of(2) {
        "and my own"
    } else {
        ""
    };
    Move::Answer {
        picks,
        free: free.to_string(),
    }
}

/// Every prompt of a whole run of `style` through the wire, read-back and writer included.
async fn prompts_of(style: Style) -> String {
    let script = Script::default()
        .then(
            "read-back",
            json!({"needs": [{"sentence": "s", "words": "long enough", "gap": false}]}),
        )
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(good()).unwrap());
    let mut interview = Interview::new(style);
    interview.seed = "pinned".to_string();
    let mut round = 0;
    while let Some(asking) = interview.asking.clone() {
        let action = wire(&answer_of(&asking, round));
        interview = wire(&step(&script, &interview, action, "en").await.unwrap());
        round += 1;
    }
    let lines = read_back(&script, &interview).await.unwrap();
    let needs = corrected(&lines, &[]);
    let private = Private::default();
    let making = Making {
        interview: &interview,
        needs: &needs,
        private: &private,
        model: "a-model",
    };
    write_card(&script, &making).await.unwrap();
    let asked = script.asked.lock().unwrap();
    let systems = script.systems.lock().unwrap();
    let calls = asked.iter().zip(systems.iter());
    let shown = calls.map(|((role, user), system)| format!("== {role}\n{system}\n--\n{user}\n"));
    format!("=== {style:?}\n{}", shown.collect::<String>())
}

#[tokio::test]
async fn every_prompt_to_the_models_stays_as_pinned() {
    let mut got = String::new();
    for style in [Style::Tree, Style::Cloud, Style::Hybrid] {
        got.push_str(&prompts_of(style).await);
    }
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/interview_prompts.txt");
    if std::env::var_os("PIN_WRITE").is_some() {
        std::fs::write(path, &got).unwrap();
    }
    let pinned = std::fs::read_to_string(path).unwrap().replace("\r\n", "\n");
    assert!(
        got == pinned,
        "a prompt changed: PIN_WRITE=1 and read the diff"
    );
}

#[tokio::test]
async fn a_worded_question_is_asked_in_the_pages_language() {
    let script = Script::default();
    let mut interview = Interview::new(Style::Hybrid);
    let mut round = 0;
    while script.sent("interviewer").is_empty() {
        let asking = interview.asking.clone().unwrap();
        let action = answer_of(&asking, round);
        interview = step(&script, &interview, action, "de-AT").await.unwrap();
        round += 1;
    }
    let user = script.sent("interviewer").remove(0);
    let line = "\n\nWord the question and its choices in German.";
    assert!(user.ends_with(line), "{user}");
}

#[test]
fn every_language_the_app_has_is_named_in_the_prompt() {
    let asked = super::in_language("u", "vi-VN");
    assert!(asked.ends_with(" in Vietnamese."), "{asked}");
    let asked = super::in_language("u", "zh-TW");
    assert!(asked.ends_with(" in Chinese (traditional)."), "{asked}");
}

#[tokio::test]
async fn a_typed_answer_is_quoted_as_typed() {
    // A typed wish that is word for word a fixed choice's English is still the user's words.
    let typed = texts::NEEDS[0];
    assert_eq!(why_quotes(typed).await, json!([{ "words": typed }]));
    // Typed words holding "; " and a choice's English are one part, as typed.
    let typed = format!("{}; and more of my own", texts::NEEDS[0]);
    assert_eq!(why_quotes(&typed).await, json!([{ "words": typed }]));
}

/// The parts the "why" question quotes, as the page gets them, where the wish is `typed`.
async fn why_quotes(typed: &str) -> serde_json::Value {
    let script = Script::default();
    let mut interview = Interview::new(Style::Tree);
    let mut round = 0;
    while interview
        .asking
        .as_ref()
        .is_some_and(|asking| asking.slot != "why")
    {
        let asking = interview.asking.clone().unwrap();
        let action = match asking.slot.as_str() {
            "wanted" => free(typed),
            _ => answer_of(&asking, round),
        };
        interview = step(&script, &interview, action, "en").await.unwrap();
        round += 1;
    }
    let shown = serde_json::to_value(&interview).unwrap();
    shown["asking"]["question"]["said"].clone()
}

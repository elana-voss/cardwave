//! The private list and the writer, on scripted models and through the pretend model.

use cw_ccv4::creation::{Private, PrivateRow};
use cw_core::Code;
use cw_provider::{Provider, Sampling, client, form, pretend};
use serde_json::{Value, json};

use super::gender::{self, Choices};
use super::private::sensitive_lines;
use super::readback::{Line, Verdict, corrected};
use super::shown::Text;
use super::tests::*;
use super::writer::*;
use super::*;

fn row(topic: &str, answer: &str, never: bool) -> PrivateRow {
    PrivateRow {
        topic: topic.to_string(),
        answer: answer.to_string(),
        never,
    }
}

#[test]
fn the_private_list_becomes_the_writers_lines_and_at_most_three_nevers() {
    let private = Private {
        open: true,
        rows: vec![
            row("romance", "yes", false),
            row("sex", "fantasy only", false),
            row("violence", "maybe", false),
            row("a", "no", true),
            row("b", "no", false),
            row("c", "no", true),
            row("d", "no", true),
            row("e", "no", true),
        ],
        free: " mine ".to_string(),
    };

    let (lines, nevers) = sensitive_lines(&private);

    assert_eq!(
        lines,
        [
            "romance: welcome",
            "sex: in the story only",
            "violence: only when the user leads",
            "keeps away from: b, e",
            "the user's own line:  mine ",
        ]
    );
    assert_eq!(nevers, ["a", "c", "d"]);
}

#[test]
fn an_empty_private_list_says_nothing() {
    let (lines, nevers) = sensitive_lines(&Private {
        free: "  ".to_string(),
        ..Private::default()
    });
    assert!(lines.is_empty() && nevers.is_empty());
}

pub(super) fn good() -> Fields {
    Fields {
        name: "Mara".to_string(),
        description: format!("{{{{user}}}} {}", "d".repeat(991)),
        personality: "p".repeat(800),
        scenario: format!("{{{{user}}}} {}", "s".repeat(791)),
        first_mes: "She looks up.".to_string(),
        mes_example: "<START>\n{{char}}: One.\n<START>\n{{char}}: Two.\n<START>\n{{char}}: No."
            .to_string(),
        alternate_greetings: ["a.", "b.", "c.", "d."].map(String::from).to_vec(),
        creator_notes: String::new(),
    }
}

fn made_choices(interview: &Interview) -> Choices {
    gender::choices(interview)
}

pub(super) fn plan() -> Value {
    json!({
        "mode": "Companion",
        "nevers": ["a", "from the plan"],
        "persona_lines": (0..10).map(|n| format!("fact {n}")).collect::<Vec<String>>(),
    })
}

async fn answered(script: &Script) -> Interview {
    finish(script, Interview::new(Style::Tree), &["Not sure"]).await
}

fn lines() -> Vec<Line> {
    let line = |sentence: &str, words: &str, gap| Line {
        sentence: sentence.to_string(),
        words: words.to_string(),
        gap,
    };
    vec![
        line("kept one", "said one", false),
        line("old", "said two", true),
        line("removed one", "said three", false),
    ]
}

fn private() -> Private {
    Private {
        open: true,
        rows: vec![row("a", "no", true), row("romance", "yes", false)],
        free: String::new(),
    }
}

#[tokio::test]
async fn a_name_left_unfilled_takes_the_plans_with_no_further_call_else_the_card_keeps_its_own() {
    let unnamed = Fields {
        name: "Placeholder".to_string(),
        ..good()
    };
    let card = serde_json::to_value(&unnamed).unwrap();
    for (plan_name, wanted) in [("Orin Vale", "Orin Vale"), ("placeholder ", "Placeholder")] {
        let mut told = plan();
        told["name"] = json!(plan_name);
        let script = Script::default()
            .then("writer plan", told)
            .then("writer card", card.clone());
        let (script, got) = written_with(script).await;
        let written = got.unwrap();
        assert_eq!(written.card.name, wanted);
        assert_eq!(written.card.title, wanted);
        assert_eq!(writers_calls(&script), ["writer plan", "writer card"]);
    }
}

#[tokio::test]
async fn the_read_backs_choices_and_the_list_reach_the_writer_and_the_card() {
    let script = Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(good()).unwrap());
    let interview = answered(&script).await;
    let needs = corrected(
        &lines(),
        &[
            Verdict::Keep,
            Verdict::Change("my own".to_string()),
            Verdict::Remove,
        ],
    );
    let private = private();
    let making = Making {
        interview: &interview,
        needs: &needs,
        private: &private,
        model: "a-model",
    };

    let written = write_card(&script, &making).await.unwrap();

    let profile: Value = serde_json::from_str(&script.sent("writer plan")[0]).unwrap();
    assert_eq!(
        profile["needs"],
        json!([
            {"sentence": "kept one", "words": "said one", "gap": false},
            {"sentence": "my own", "words": "said two", "gap": true},
        ])
    );
    assert_eq!(profile["kinds"], json!(interview.kinds));
    assert_eq!(profile["nevers_from_list"], json!(["a"]));
    assert_eq!(profile["sensitive_lines"], json!(["romance: welcome"]));
    assert_eq!(profile["question_log"][0]["slot"], "wanted");
    assert_eq!(profile["relation"], json!(LONG));
    assert_eq!(profile["treat_user"], "anyone");
    assert_eq!(
        profile["character_gender"],
        made_choices(&interview).character_gender
    );
    let settled = settle_plan(plan(), &interview.kinds, &made_choices(&interview));
    assert_eq!(
        script.sent("writer card")[0],
        format!(
            "Plan:\n{}\nSensitive list as written: [\"romance: welcome\"]\n{}",
            dumps(&settled),
            texts::FIRST_MES_RULE
        )
    );

    let card = &written.card;
    assert_eq!((card.title.as_str(), card.name.as_str()), ("Mara", "Mara"));
    assert_eq!(card.greetings, ["She looks up.", "a.", "b.", "c.", "d."]);
    assert_eq!(card.example_dialogue, good().mes_example);
    assert_eq!(written.persona.len(), 8);

    let made = card.creation.as_ref().unwrap();
    assert_eq!(made.needs, needs);
    assert_eq!(made.mode, "Companion");
    assert_eq!(made.nevers, ["a", "from the plan"]);
    assert_eq!(made.persona_facts.len(), 10);
    assert_eq!(made.style, "tree");
    assert_eq!(made.model, "a-model");
    assert_eq!(made.private, private);
    assert_eq!(made.relation, LONG);
    assert_eq!(made.moments, Vec::<String>::new());
    assert_eq!(made.question_log.len(), interview.log.len());
    assert_eq!(made.plan, settled);
    let choices = made_choices(&interview);
    assert_eq!(made.character_gender, choices.character_gender);
    assert_eq!(made.treat_user, choices.treat_user);
    assert_eq!(made.character_words, choices.character_words);
    assert_eq!(made.cast_genders, choices.cast_genders);
    assert_eq!(made.draw, choices.draw);
    assert_eq!(made.cast_draw, choices.cast_draw);
}

#[tokio::test]
async fn a_removed_lines_words_are_cut_from_what_the_writer_reads_and_stay_in_the_saved_log() {
    let script = Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(good()).unwrap());
    let mut interview = answered(&script).await;
    let whole = "The Sea\u{2019}s Noise; I know the old pier; no";
    interview.log[0].answer = Some(whole.to_string());
    let relation = interview
        .log
        .iter()
        .position(|entry| entry.slot == "relation");
    let relation = relation.unwrap();
    interview.log[relation].answer = Some("Quiet Mornings.".to_string());
    let mut why = interview.log[0].clone();
    why.question = Text::of("You said: \"quiet mornings\". Why does that matter?");
    why.answer = Some("a walk".to_string());
    why.slot = "why".to_string();
    interview.log.push(why);
    let kinds = interview.log.iter().position(|entry| entry.slot == "kinds");
    let kinds = kinds.unwrap();
    let kind = interview.log[kinds].answer.clone().unwrap();
    let line = |sentence: &str, words: &str| Line {
        sentence: sentence.to_string(),
        words: words.to_string(),
        gap: false,
    };
    let lines = [
        line("kept", "the old pier"),
        line(
            "gone",
            &format!("\"quiet mornings\" · the sea's noise; no; {kind}"),
        ),
    ];
    let needs = corrected(&lines, &[Verdict::Keep, Verdict::Remove]);
    let private = Private::default();
    let making = Making {
        interview: &interview,
        needs: &needs,
        private: &private,
        model: "m",
    };

    let written = write_card(&script, &making).await.unwrap();

    let sent = &script.sent("writer plan")[0];
    let lower = sent.to_lowercase();
    assert!(
        !lower.contains("quiet mornings") && !lower.contains("noise"),
        "{sent}"
    );
    let profile: Value = serde_json::from_str(sent).unwrap();
    assert_eq!(
        profile["needs"],
        json!([{"sentence": "kept", "words": "the old pier", "gap": false}])
    );
    // A word is cut whole: "no" goes, "know" stays.
    assert_eq!(profile["question_log"][0]["answer"], "I know the old pier");
    let told = &profile["question_log"][relation];
    assert_eq!(
        (&told["answer"], &told["skipped"]),
        (&Value::Null, &json!(true))
    );
    assert_eq!(profile["relation"], Value::Null);
    let told = &profile["question_log"][interview.log.len() - 1];
    assert_eq!(told["question"], "You said: \"\". Why does that matter?");
    assert_eq!(told["answer"], "a walk");
    assert_eq!(profile["question_log"][kinds]["answer"], json!(kind));

    let saved = written.card.creation.unwrap();
    assert_eq!(saved.question_log[0].answer.as_deref(), Some(whole));
    assert_eq!(
        saved.question_log[relation].answer.as_deref(),
        Some("Quiet Mornings.")
    );
    assert!(!saved.question_log[relation].skipped);
    assert_eq!(saved.needs, needs);
}

async fn written_with(script: Script) -> (Script, anyhow::Result<Written>) {
    let interview = answered(&script).await;
    let got = write_card(
        &script,
        &Making {
            interview: &interview,
            needs: &[],
            private: &Private::default(),
            model: "m",
        },
    )
    .await;
    (script, got)
}

/// The calls that wrote the card, without those of the interview before it.
fn writers_calls(script: &Script) -> Vec<String> {
    let asked = script.asked.lock().unwrap();
    let roles = asked.iter().map(|(role, _)| role.clone());
    roles
        .filter(|role| role.starts_with("writer") || role.starts_with("gender check"))
        .collect()
}

fn nodding() -> Fields {
    Fields {
        first_mes: "You nod.".to_string(),
        ..good()
    }
}

/// The script of the plan and of `card`; a repair is added after it.
fn card_script(card: &Fields) -> Script {
    Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(card).unwrap())
}

const THREE_CALLS: [&str; 3] = ["writer plan", "writer card", "writer rewrite"];

#[tokio::test]
async fn a_card_that_passes_gets_no_repair() {
    let (script, got) = written_with(card_script(&good())).await;
    got.unwrap();
    assert_eq!(writers_calls(&script), ["writer plan", "writer card"]);
}

#[tokio::test]
async fn examples_spoken_by_the_name_are_tidied_and_cost_no_repair() {
    let card = Fields {
        mes_example: "<START>\nMara: One.\n<START>\nMara: Two.\n<START>\nMara: Three.".to_string(),
        ..good()
    };
    let (script, got) = written_with(card_script(&card)).await;
    got.unwrap();
    assert_eq!(writers_calls(&script), ["writer plan", "writer card"]);
}

#[tokio::test]
async fn the_one_repair_takes_only_the_failing_fields_with_the_card_as_context() {
    let fix = Fields {
        name: "Another".to_string(),
        first_mes: "She smiles.".to_string(),
        ..good()
    };
    let script =
        card_script(&nodding()).then("writer rewrite", serde_json::to_value(&fix).unwrap());

    let (script, got) = written_with(script).await;

    let card = got.unwrap().card;
    assert_eq!(card.name, "Mara");
    assert_eq!(card.greetings[0], "She smiles.");
    assert_eq!(writers_calls(&script), THREE_CALLS);
    assert_eq!(
        script.sent("writer rewrite")[0],
        format!(
            "Card:\n{}\nFailing: [{{\"rule\": \"acts for user\", \"field\": \"first_mes\", \"why\": \"acts or speaks for {{{{user}}}}\"}}]\nReturn the whole card; change only the failing fields.",
            dumps(&nodding())
        )
    );
}

#[tokio::test]
async fn a_card_still_failing_after_its_repair_is_shown_with_one_repair_only() {
    let fix = Fields {
        first_mes: "You smile.".to_string(),
        ..good()
    };
    let script =
        card_script(&nodding()).then("writer rewrite", serde_json::to_value(&fix).unwrap());

    let (script, got) = written_with(script).await;

    assert_eq!(got.unwrap().card.greetings[0], "You smile.");
    assert_eq!(writers_calls(&script), THREE_CALLS);
}

#[tokio::test]
async fn a_repair_that_fails_or_cannot_be_read_leaves_the_card() {
    for code in [Code::ModelDeclined, Code::ModelAnswer, Code::RequestFailed] {
        let script = card_script(&nodding()).failing("writer rewrite", code);
        let (_, got) = written_with(script).await;
        assert_eq!(got.unwrap().card.greetings[0], "You nod.");
    }
    let script = card_script(&nodding()).then("writer rewrite", json!("no card"));
    let (_, got) = written_with(script).await;
    assert_eq!(got.unwrap().card.greetings[0], "You nod.");
}

#[tokio::test]
async fn a_repair_that_leaves_a_failing_field_blank_keeps_what_the_card_had() {
    let script = card_script(&nodding()).then("writer rewrite", json!({"name": "Mara"}));
    let (_, got) = written_with(script).await;
    assert_eq!(got.unwrap().card.greetings[0], "You nod.");
}

#[tokio::test]
async fn a_repair_with_a_fifth_greeting_loses_it() {
    let card = Fields {
        alternate_greetings: vec!["a.".to_string()],
        ..good()
    };
    let fix = Fields {
        alternate_greetings: ["a.", "b.", "c.", "d.", "e."].map(String::from).to_vec(),
        ..good()
    };
    let script = card_script(&card).then("writer rewrite", serde_json::to_value(&fix).unwrap());
    let (_, got) = written_with(script).await;
    assert_eq!(got.unwrap().card.greetings[1..], ["a.", "b.", "c.", "d."]);
}

#[tokio::test]
async fn an_empty_name_the_plan_fills_needs_no_repair() {
    let unnamed = Fields {
        name: String::new(),
        ..good()
    };
    let mut told = plan();
    told["name"] = json!("Orin Vale");
    let script = Script::default()
        .then("writer plan", told)
        .then("writer card", serde_json::to_value(&unnamed).unwrap());
    let (script, got) = written_with(script).await;
    assert_eq!(got.unwrap().card.name, "Orin Vale");
    assert_eq!(writers_calls(&script), ["writer plan", "writer card"]);
}

#[tokio::test]
async fn a_refusal_on_the_plan_or_the_card_is_returned_and_an_unsignalled_one_is_shown() {
    let script = Script::default().failing("writer plan", Code::ModelDeclined);
    let (_, got) = written_with(script).await;
    assert!(form::declined(&got.unwrap_err()));

    let script = Script::default()
        .then("writer plan", plan())
        .failing("writer card", Code::ModelDeclined);
    let (_, got) = written_with(script).await;
    assert!(form::declined(&got.unwrap_err()));

    let sorry = Fields {
        first_mes: "I'm sorry, I can't write this.".to_string(),
        ..good()
    };
    let script = Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(&sorry).unwrap());
    let (_, got) = written_with(script).await;
    assert_eq!(got.unwrap().card.greetings[0], sorry.first_mes);
}

fn pretend_provider() -> Provider {
    Provider {
        base_url: pretend::ADDRESS.to_string(),
        api_key: String::new(),
        model: "pretend-chat".to_string(),
        sampling: Sampling::default(),
        name: String::new(),
        thinking_off: None,
        reply_limit: None,
        seen_thinking: false,
    }
}

#[tokio::test]
async fn the_writer_runs_through_a_provider_and_its_refusal_is_the_models() {
    let http = client().unwrap();
    let provider = pretend_provider();
    let asker = Asker {
        http: &http,
        provider: &provider,
    };
    let script = Script::default();
    let interview = answered(&script).await;
    let private = Private::default();
    let making = Making {
        interview: &interview,
        needs: &[],
        private: &private,
        model: "pretend-chat",
    };

    let written = write_card(&asker, &making).await.unwrap();
    let made = written.card.creation.unwrap();
    assert_eq!(made.mode, "Roleplay");

    let declining = Private {
        free: pretend::DECLINE.to_string(),
        ..Private::default()
    };
    let making = Making {
        private: &declining,
        ..making
    };
    let failure = write_card(&asker, &making).await.unwrap_err();
    assert!(form::declined(&failure));
}

#[tokio::test]
async fn a_fifth_greeting_is_dropped_and_the_card_is_tidied() {
    let card = Fields {
        alternate_greetings: ["a.", "b.", "c.", "d.", "e."].map(String::from).to_vec(),
        mes_example: "<START>\nMara: One.\n<START>\n{{char}}: Two.\n<START>\n{{char}}: No."
            .to_string(),
        creator_notes: "A portrait from your memories. Kind.".to_string(),
        ..good()
    };
    let script = Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(&card).unwrap());

    let (_, got) = written_with(script).await;

    let made = got.unwrap().card;
    assert_eq!(made.greetings[1..], ["a.", "b.", "c.", "d."]);
    assert_eq!(made.creator_notes, "Kind.");
}

/// What a call was: its role, its system text, its limit and its temperature.
type Seen = (String, String, u32, Option<f64>);

/// What the calls ask, besides the script's answers.
#[derive(Default)]
struct Noting {
    script: Script,
    seen: std::sync::Mutex<Vec<Seen>>,
}

impl Models for Noting {
    fn ask(
        &self,
        question: &form::Question<'_>,
    ) -> impl Future<Output = anyhow::Result<Value>> + Send {
        self.seen.lock().unwrap().push((
            question.role.to_string(),
            question.system.to_string(),
            question.limit,
            question.temperature,
        ));
        self.script.ask(question)
    }
}

#[tokio::test]
async fn the_writers_calls_have_their_limits_and_their_rules() {
    let script = Script::default()
        .then("writer plan", plan())
        .then("writer card", serde_json::to_value(nodding()).unwrap())
        .then("writer rewrite", serde_json::to_value(good()).unwrap());
    let noting = Noting {
        script,
        ..Noting::default()
    };
    let interview = answered(&noting.script).await;
    let choices = made_choices(&interview);
    let (treat, character) = (
        choices.treat_user.as_str(),
        choices.character_gender.as_str(),
    );
    let making = Making {
        interview: &interview,
        needs: &[],
        private: &Private::default(),
        model: "m",
    };
    noting.seen.lock().unwrap().clear();

    write_card(&noting, &making).await.unwrap();

    let seen = noting.seen.lock().unwrap();
    let of = |role: &str| seen.iter().find(|(who, ..)| who == role).unwrap();
    assert_eq!(of("writer plan").2, 12_000);
    assert_eq!(of("writer plan").1, plan_system(treat, character));
    assert_eq!(of("writer card").2, 16_000);
    assert_eq!(of("writer card").1, card_system(treat, character));
    assert_eq!(of("writer rewrite").2, 16_000);
    assert_eq!(
        of("writer rewrite").1,
        card_system(treat, character).replacen(texts::WRITER_CARD, texts::WRITER_REWRITE, 1)
    );
}

#[test]
fn the_rules_follow_the_two_answers_and_several_takes_the_cast_rules() {
    let plan_rules = plan_system("man", "not human");
    assert_eq!(
        plan_rules,
        format!(
            "{}\n{{{{user}}}} is a man: use he/him for {{{{user}}}} where natural, and the character and the story treat {{{{user}}}} as one. Add nothing else about {{{{user}}}}'s body or past.\n{{{{char}}}} is not human: it or they, one kept throughout. The name fits.",
            texts::WRITER_PLAN
        )
    );
    assert!(plan_system("anyone", "several").ends_with(texts::CAST_PLAN));
    assert!(card_system("anyone", "several").ends_with(texts::CAST_CARD));
    assert!(card_system("woman", "woman").starts_with(texts::WRITER_CARD));
}

#[test]
fn the_plan_settled_keeps_a_cast_only_for_several_at_most_four_with_the_drawn_genders() {
    let person = |name: &str| json!({"name": name, "gender": "model's"});
    let model = json!({
        "mode": "Companion",
        "cast": [person("a"), "broken", person("b"), person("c"), person("d"), person("e")],
    });
    let choices = |gender: &str, words: &str| Choices {
        character_gender: gender.to_string(),
        treat_user: "anyone".to_string(),
        character_words: words.to_string(),
        cast_genders: ["woman", "man", "nonbinary", "not human"]
            .map(String::from)
            .to_vec(),
        draw: None,
        cast_draw: None,
    };
    let kinds = ["A friend".to_string()];

    let one = settle_plan(model.clone(), &kinds, &choices("woman", ""));
    assert_eq!(one["cast"], json!([]));
    assert_eq!(one["mode"], "Companion");
    assert_eq!(one["kinds"], json!(kinds));
    assert_eq!(one["character_gender"], "woman");
    assert_eq!(one["treat_user"], "anyone");

    let drawn = settle_plan(model.clone(), &kinds, &choices("several", ""));
    assert_eq!(drawn["mode"], "Roleplay");
    let genders: Vec<&str> = drawn["cast"]
        .as_array()
        .unwrap()
        .iter()
        .map(|person| person["gender"].as_str().unwrap())
        .collect();
    assert_eq!(genders, ["woman", "man", "nonbinary", "not human"]);
    assert_eq!(drawn["cast"][3]["name"], "d");

    let told = settle_plan(model, &kinds, &choices("several", "two women"));
    assert_eq!(told["cast"][0]["gender"], "model's");
    assert_eq!(told["character_words"], "two women");
}

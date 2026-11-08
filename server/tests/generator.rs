//! Extras › Character generator (`POST /api/generator`): the description,
//! personality and scenario are composed from the picks, the chat model writes
//! the greeting and the example messages in one call, and the card is made.

mod common;

use common::api::{Api, JSON, says};
use common::server::start;
use cw_library::generator::{self, GeneratorPicks};
use serde_json::{Value, json};

/// The picks of a woman in her thirties, quite shy, somewhat playful, a rival.
fn picks(name: &str) -> Value {
    json!({
        "gender": "Woman", "being": "Human", "age": "30s", "build": "Athletic", "hair": "Long", "hair_colour": "Red",
        "shy_outgoing": 20, "gentle_harsh": 55, "serious_playful": 70, "cautious_bold": 95,
        "relationship": "Rival", "name": name, "creator": "local",
    })
}

/// A server whose chat model is a stand-in answering `answer`, and whose
/// background model is `small-1`.
async fn model(answer: &str) -> (common::server::Server, Api) {
    let api = Api::start(says(
        200,
        JSON,
        &json!({ "choices": [{ "message": { "content": answer } }] }).to_string(),
    ))
    .await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "big-1", "worker_model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    (server, api)
}

const ANSWER: &str = r#"Here it is: {"greeting": "*{{char}} smirks.* You again, {{user}}?", "examples": [{"user": "Hi.", "char": "Hm. Hello."}, {"user": "Help me?", "char": "Fine. Once."}]}"#;

#[test]
fn the_picks_are_composed_into_the_cards_texts() {
    let picks: GeneratorPicks = serde_json::from_value(picks("Mara")).unwrap();
    let never = |_: usize| -> usize { unreachable!("every look is picked") };
    assert_eq!(
        generator::description(&picks.looks(never)),
        "{{char}} is a woman (she/her) in her thirties, athletic, with long red hair."
    );
    // 55 is near the middle and says nothing; 20 is quite shy, 70 somewhat playful, 95 extremely bold.
    assert_eq!(
        generator::personality(&picks),
        "{{char}} is quite shy, somewhat playful and extremely bold."
    );
    assert_eq!(
        generator::rubric(&picks),
        "speaks briefly, hedges and waits to be drawn out; a little: teases, banters and jokes; is decisive and direct, and takes the lead."
    );
    let not_human: GeneratorPicks = serde_json::from_value(json!({
        "gender": "Woman", "being": "Not human", "age": "50s and older", "build": "Slim", "hair": "Short", "hair_colour": "White",
        "shy_outgoing": 50, "gentle_harsh": 50, "serious_playful": 50, "cautious_bold": 50,
        "relationship": "Mentor", "name": "Ix", "creator": "",
    }))
    .unwrap();
    assert_eq!(
        generator::description(&not_human.looks(never)),
        "{{char}} is not human, female (she/her), looking fifty or older, slim, with short white hair."
    );
    assert!(generator::personality(&not_human).starts_with("{{char}} keeps to the middle"));
}

#[test]
fn each_look_left_any_is_picked_and_the_others_kept() {
    // "Any" is null (or left out); the chooser here takes the last value of each.
    let picks: GeneratorPicks = serde_json::from_value(json!({
        "gender": null, "being": null, "age": null, "build": "Slim",
        "shy_outgoing": 50, "gentle_harsh": 50, "serious_playful": 50, "cautious_bold": 50,
        "relationship": "Friend", "name": "Any", "creator": "",
    }))
    .unwrap();
    let mut counts = Vec::new();
    let looks = picks.looks(|count| {
        counts.push(count);
        count - 1
    });
    assert_eq!(
        counts,
        [3, 2, 4, 3, 6],
        "gender, being, age, hair, hair colour"
    );
    assert_eq!(
        generator::description(&looks),
        "{{char}} is not human, non-binary (they/them), looking fifty or older, slim, with long white hair."
    );
}

#[tokio::test]
async fn the_chat_model_writes_the_greeting_and_examples_and_the_card_is_made() {
    let (server, api) = model(ANSWER).await;
    let (status, made) = server.post("/api/generator", picks("Mara Vell")).await;
    assert_eq!(status, 201, "{made}");
    assert_eq!(made["title"], "Mara Vell");

    // One call, to the chat model, with the composed texts and how the character talks.
    let asked = api.asked();
    assert_eq!(asked.len(), 1);
    let sent: Value = serde_json::from_str(&asked[0].body).unwrap();
    assert_eq!(sent["model"], "big-1");
    let prompt = sent["messages"].to_string();
    for part in [
        "athletic, with long red hair",
        "quite shy",
        "{{user}}'s rival",
        "teases, banters",
    ] {
        assert!(prompt.contains(part), "{part}: {prompt}");
    }

    let id = made["card_id"].as_i64().unwrap();
    let (_, edit) = server.get(&format!("/api/cards/{id}/edit")).await;
    let character = &edit["characters"][0];
    let text = |key: &str| character[key][0]["text"].clone();
    assert_eq!(text("greetings"), "*{{char}} smirks.* You again, {{user}}?");
    assert_eq!(
        text("example_dialogue"),
        "<START>\n{{user}}: Hi.\n{{char}}: Hm. Hello.\n<START>\n{{user}}: Help me?\n{{char}}: Fine. Once."
    );
    assert_eq!(
        text("scenario"),
        "{{char}} is {{user}}'s rival, a competitor who keeps {{user}} on their toes."
    );
    assert_eq!(
        text("personality"),
        "{{char}} is quite shy, somewhat playful and extremely bold."
    );
    assert_eq!(edit["creator"], "local");
}

#[tokio::test]
async fn an_answer_without_examples_makes_no_card() {
    let (server, _api) = model(r#"{"greeting": "Hello, {{user}}.", "examples": []}"#).await;
    let (status, answer) = server.post("/api/generator", picks("Nobody Made")).await;
    assert_eq!(status, 400, "{answer}");
    assert!(
        answer.to_string().contains("no example messages"),
        "{answer}"
    );
    let (_, cards) = server.get("/api/cards").await;
    assert_eq!(cards, json!([]));
}

#[tokio::test]
async fn without_a_name_or_a_provider_nothing_is_asked() {
    let (server, api) = model(ANSWER).await;
    let (status, _) = server.post("/api/generator", picks("  ")).await;
    assert_eq!(status, 400);
    assert!(api.asked().is_empty());

    let bare = start().await;
    assert_eq!(bare.post("/api/generator", picks("Mara")).await.0, 424);
}

//! Cards described: the worker model classifies a card from the fixed
//! vocabulary and writes its library title, logline and summary; a card's page
//! tells the deterministic facts of each character. No test asks a provider:
//! `model` starts a stand-in that answers the askings in turn.
//!
//! A card's needs at the end (`asked`, `needs_of`), after its description.
//!
//! The helpers are in `common::describing`; "Describe all again" in `describe_again.rs`.

mod common;

use std::time::Duration;

use common::api::{Api, JSON, Says, says};
use common::describing::*;
use common::server::{Server, WAIT, event, start};
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

#[tokio::test]
async fn describe_cards_gives_each_card_its_tags_logline_title_and_summary() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&json!(format!(
            "```json\n{}\n```",
            written("The Keeper of the Light")
        ))),
    ])
    .await;
    let id = import(&server).await;
    // Nothing is described until it is asked for: the switch is off.
    assert_eq!(row(&server, id).await["describing"], false);
    let (_, progress) = server.get("/api/describe").await;
    assert_eq!(progress["left"], 1, "{progress}");
    assert!(api.asked().is_empty());

    let mut socket = server.listen().await;
    let (status, progress) = server.post("/api/describe", json!({})).await;
    assert_eq!(status, 200, "{progress}");
    assert_eq!(
        event(&mut socket).await,
        json!({ "type": "descriptions", "card_id": null })
    );
    assert_eq!(
        event(&mut socket).await,
        json!({ "type": "descriptions", "card_id": id })
    );
    assert_eq!(
        done(&server).await,
        json!({ "waiting": 0, "left": 0, "failed": 0, "failure": null })
    );

    // The classifier is asked first, of the card's own texts, then the writer, with what it found.
    let asked = api.asked();
    assert_eq!(asked.len(), 3);
    let sent = |at: usize| serde_json::from_str::<Value>(&asked[at].body).unwrap();
    let (first, second) = (sent(0), sent(1));
    assert_eq!(first["model"], "small-1");
    assert!(
        first["messages"][0]["content"]
            .as_str()
            .unwrap()
            .contains("VOCABULARY")
    );
    let card = first["messages"][1]["content"].as_str().unwrap();
    assert!(card.starts_with("<card_to_classify>"), "{card}");
    assert!(
        card.contains("You picked a night for it, {{user}}."),
        "{card}"
    );
    let facets = second["messages"][1]["content"].as_str().unwrap();
    assert!(facets.contains("<facets>") && facets.contains("keeps you inside the lighthouse"));

    // The library: the title written, the classifier's terms of the vocabulary
    // (made-up ones left out), then the file's tags not among them ("sea"),
    // and the logline.
    let card = row(&server, id).await;
    assert_eq!(card["title"], "The Keeper of the Light");
    assert_eq!(
        card["tags"],
        json!([
            "stranger",
            "mystery",
            "stoic",
            "suggestive",
            "substance-use",
            "sea"
        ])
    );
    assert_eq!(
        card["excerpt"],
        "A storm strands you in the lighthouse its keeper never leaves."
    );
    assert_eq!(card["describing"], false);
    // Found by its terms, and by what they are called beside the tags shown.
    let (_, found) = server.get("/api/cards?q=female").await;
    assert_eq!(found.as_array().unwrap().len(), 1, "{found}");
    // and by a tag of its file.
    let (_, found) = server.get("/api/cards?tag=sea").await;
    assert_eq!(found.as_array().unwrap().len(), 1, "{found}");

    // The page: the summary, the content level as chips, and the tags without it.
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(
        detail["summary"],
        "She keeps the north light. A storm has cut you off. It is quiet and wary."
    );
    assert_eq!(detail["content"], json!(["suggestive", "substance-use"]));
    assert_eq!(
        detail["tags"],
        json!(["stranger", "mystery", "stoic", "sea"])
    );

    // The summary as the user writes it on the page.
    let path = format!("/api/cards/{id}/summary");
    let (status, _) = server
        .put(&path, json!({ "summary": " The keeper waits. " }))
        .await;
    assert_eq!(status, 204);
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(detail["summary"], "The keeper waits.");
    let (status, refused) = server.put(&path, json!({ "summary": " " })).await;
    assert_eq!(
        (status, &refused["error"]),
        (400, &json!("a summary needs words"))
    );
    // A card in the Trash is not changed.
    let card = format!("/api/cards/{id}");
    server.patch(&card, json!({ "trashed": true })).await;
    let (status, refused) = server.put(&path, json!({ "summary": "Mine." })).await;
    assert_eq!(
        (status, &refused["error"]),
        (400, &json!("the card is in the Trash; restore it first"))
    );
    server.patch(&card, json!({ "trashed": false })).await;

    // A card described is not described again.
    let (_, progress) = server.post("/api/describe", json!({})).await;
    assert_eq!(progress["waiting"], 0, "{progress}");
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn a_title_and_tags_the_user_gave_stay_through_a_description() {
    let (server, _api) = model(vec![
        reply(&classified()),
        reply(&written("Generated One")),
        reply(&classified()),
        reply(&written("Generated Two")),
    ])
    .await;
    // An imported card renamed, with a tag of the user's own.
    let id = import(&server).await;
    let path = format!("/api/cards/{id}/edit");
    let (_, mut form) = server.get(&path).await;
    form["title"] = json!("My Mira");
    form["tags"] = json!(["sea", "Mystery", "mine"]);
    let (status, saved) = server.put(&path, form).await;
    assert_eq!(status, 200, "{saved}");
    // A card made in the app: its title and its tags are the user's.
    let new = json!({
        "title": "Tern Rock", "tags": ["lighthouse"], "creator": "", "name": "Wren",
        "greetings": ["The lamp is lit."], "description": "", "personality": "",
        "scenario": "", "example_dialogue": "", "creator_notes": "",
    });
    let (status, made) = server.post("/api/cards/new", new).await;
    assert_eq!(status, 201, "{made}");
    let made = made["card_id"].as_i64().unwrap();

    server.post("/api/describe", json!({})).await;
    done(&server).await;
    let terms = [
        "stranger",
        "mystery",
        "stoic",
        "suggestive",
        "substance-use",
    ];
    let card = row(&server, id).await;
    assert_eq!(card["title"], "My Mira");
    let mut tags = json!(terms);
    tags.as_array_mut().unwrap().push(json!("mine"));
    tags.as_array_mut().unwrap().push(json!("sea"));
    assert_eq!(card["tags"], tags);
    let card = row(&server, made).await;
    assert_eq!(card["title"], "Tern Rock");
    let mut tags = json!(terms);
    tags.as_array_mut().unwrap().push(json!("lighthouse"));
    assert_eq!(card["tags"], tags);
}

#[tokio::test]
async fn a_card_refused_or_failed_says_so_and_only_a_failed_one_is_described_again() {
    // A refusal is read however its verdict is written and whatever it leaves empty.
    let refused = json!({
        "verdict": "Reject", "reject_reason": "bla",
        "characters": null, "engine": null, "archetype": null, "multi_mode": "false",
    });
    let (server, api) = model(vec![
        reply(&refused),
        says(500, JSON, r#"{"error":{"message":"out of credit"}}"#),
        reply(&json!({ "verdict": "classified", "needs": [{ "need": "sex", "level": 0 }] })),
        reply(&classified()),
        reply(&written("At Last")),
    ])
    .await;
    let first = import(&server).await;
    let second = import(&server).await;

    server.post("/api/describe", json!({})).await;
    let progress = done(&server).await;
    assert_eq!(
        (&progress["left"], &progress["failed"]),
        (&json!(1), &json!(1)),
        "{progress}"
    );
    let failure = progress["failure"]["error"].as_str().unwrap();
    assert!(failure.contains("out of credit"), "{failure}");
    // Neither has a description: the file's tags and first greeting stand.
    for id in [first, second] {
        let card = row(&server, id).await;
        assert_eq!(card["tags"], json!(["sea", "mystery"]));
        assert_eq!(card["excerpt"], "\"You picked a night for it, Guest.\"");
    }

    // Only the one that failed is asked again.
    server.post("/api/describe", json!({})).await;
    assert_eq!(
        done(&server).await,
        json!({ "waiting": 0, "left": 0, "failed": 0, "failure": null })
    );
    assert_eq!(api.asked().len(), 5);
    assert_eq!(row(&server, second).await["title"], "At Last");
    assert_eq!(
        row(&server, first).await["title"],
        "Mira of the North Light"
    );
}

#[tokio::test]
async fn with_the_switch_on_each_card_imported_is_described() {
    // Without a provider there is nothing to ask.
    let server = start().await;
    import(&server).await;
    let (status, _) = server.post("/api/describe", json!({})).await;
    assert_eq!(status, 424);
    let (_, settings) = server.get("/api/settings").await;
    assert_eq!(settings["describe_imported"], false);
    drop(server);

    let (server, api) = model(vec![reply(&classified()), reply(&written("Kept Light"))]).await;
    import(&server).await;
    assert!(api.asked().is_empty());
    let (status, _) = server
        .patch("/api/settings", json!({ "describe_imported": true }))
        .await;
    assert_eq!(status, 200);
    let id = import(&server).await;
    done(&server).await;
    assert_eq!(row(&server, id).await["title"], "Kept Light");
    // The card imported before the switch was on waits for "Describe cards".
    let (_, progress) = server.get("/api/describe").await;
    assert_eq!(progress["left"], 1, "{progress}");
}

#[tokio::test]
async fn a_description_cut_off_by_the_server_stopping_is_not_waited_for_after_a_start() {
    let mut never = reply(&classified());
    never.after = Duration::from_secs(600);
    let (server, _api) = model(vec![never]).await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    assert_eq!(row(&server, id).await["describing"], true);

    let server = server.restart().await;
    assert_eq!(row(&server, id).await["describing"], false);
    let (_, progress) = server.get("/api/describe").await;
    assert_eq!(
        (&progress["waiting"], &progress["left"]),
        (&json!(0), &json!(1))
    );
}

#[tokio::test]
async fn a_cards_page_tells_the_facts_of_each_character() {
    let server = start().await;
    let new = json!({
        "title": "Long", "tags": [], "creator": "", "name": "Wren",
        "greetings": ["{{user}} walks in. Wren looks up."],
        "description": "word ".repeat(1300), "personality": "Dry.",
        "scenario": "", "example_dialogue": "", "creator_notes": "",
    });
    let (_, made) = server.post("/api/cards/new", new).await;
    let (_, detail) = server.get(&format!("/api/cards/{}", made["card_id"])).await;
    let facts = &detail["characters"][0]["facts"];
    assert_eq!(
        (
            &facts["example_dialogue"],
            &facts["greetings"],
            &facts["speaks_for_user"],
            &facts["long_description"]
        ),
        (&json!(false), &json!(1), &json!(true), &json!(true)),
        "{facts}"
    );
    assert!(
        facts["permanent_tokens"].as_u64().unwrap() >= 1625,
        "{facts}"
    );

    // The sample card: example dialogue, two greetings, none of which speaks for the user.
    let id = import(&server).await;
    let (_, detail) = server.get(&format!("/api/cards/{id}")).await;
    let facts = &detail["characters"][0]["facts"];
    assert_eq!(
        (
            &facts["example_dialogue"],
            &facts["greetings"],
            &facts["speaks_for_user"],
            &facts["long_description"]
        ),
        (&json!(true), &json!(2), &json!(false), &json!(false)),
        "{facts}"
    );
    // Before a description the page has no summary and no chips, and the file's tags.
    assert_eq!(
        (&detail["summary"], &detail["content"]),
        (&json!(""), &json!([]))
    );
    assert_eq!(detail["tags"], json!(["sea", "mystery"]));
    // Without a description there is no summary to write.
    let (status, _) = server
        .put(
            &format!("/api/cards/{id}/summary"),
            json!({ "summary": "Mine." }),
        )
        .await;
    assert_eq!(status, 400);

    // The user named as one who was, or whose house it is, is not the user made to act.
    let mut quiet = new_card(
        "Quiet",
        "{{user}} was expected at the gate. This is his house.",
    );
    quiet["description"] = json!("");
    let (_, made) = server.post("/api/cards/new", quiet).await;
    let (_, detail) = server.get(&format!("/api/cards/{}", made["card_id"])).await;
    assert_eq!(detail["characters"][0]["facts"]["speaks_for_user"], false);
}

fn new_card(title: &str, greeting: &str) -> Value {
    json!({
        "title": title, "tags": [], "creator": "", "name": "Wren",
        "greetings": [greeting], "description": "", "personality": "",
        "scenario": "", "example_dialogue": "", "creator_notes": "",
    })
}

#[tokio::test]
async fn the_classifier_is_given_every_greeting_and_each_text_whole_or_the_card_fails() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("Whole")),
        reply(&json!({ "verdict": "classified", "needs": [{ "need": "sex", "level": 0 }] })),
        reply(&classified()),
        reply(&written("Short")),
    ])
    .await;
    let mut long = new_card("Long", "Greeting 1.");
    long["greetings"] = json!(
        (1..=14)
            .map(|n| format!("Greeting {n}."))
            .collect::<Vec<_>>()
    );
    long["description"] = json!(format!("{}END-OF-DESCRIPTION", "word ".repeat(2000)));
    server.post("/api/cards/new", long).await;
    server.post("/api/describe", json!({})).await;
    assert_eq!(done(&server).await["failed"], 0);
    let sent = &api.asked()[0].body;
    assert!(sent.contains("Greeting 14.") && sent.contains("END-OF-DESCRIPTION"));

    // A card longer than the worker model reads is not classified from its start alone.
    let small =
        json!({ "base_url": api.url, "model": "small-1", "sampling": { "context_size": 6000 } });
    assert_eq!(server.put("/api/provider", small).await.0, 200);
    let (_, other) = server
        .post("/api/cards/new", new_card("Other", "Hello."))
        .await;
    let id = other["card_id"].as_i64().unwrap();
    server.post("/api/describe", json!({})).await;
    let progress = done(&server).await;
    // The short card fits; the long one was described before.
    assert_eq!(progress["failed"], 0, "{progress}");
    assert_eq!(api.asked().len(), 6);
    assert_eq!(row(&server, id).await["describing"], false);
    let mut huge = new_card("Huge", "Hello.");
    huge["description"] = json!("word ".repeat(4000));
    server.post("/api/cards/new", huge).await;
    server.post("/api/describe", json!({})).await;
    let progress = done(&server).await;
    assert_eq!(progress["failed"], 1, "{progress}");
    let failure = progress["failure"]["error"].as_str().unwrap();
    assert!(failure.contains("longer than"), "{failure}");
    assert_eq!(api.asked().len(), 6);
}

#[tokio::test]
async fn a_card_put_in_the_trash_while_it_waits_is_not_described() {
    let mut slow = reply(&classified());
    slow.after = Duration::from_millis(500);
    let (server, api) = model(vec![slow, reply(&written("First"))]).await;
    let first = import(&server).await;
    let second = import(&server).await;
    server.post("/api/describe", json!({})).await;
    let (status, _) = server
        .patch(&format!("/api/cards/{second}"), json!({ "trashed": true }))
        .await;
    assert_eq!(status, 200);
    let (_, progress) = server.get("/api/describe").await;
    assert_eq!(progress["waiting"], 1, "{progress}");
    assert_eq!(done(&server).await["left"], 0);
    assert_eq!(api.asked().len(), 3);
    assert_eq!(row(&server, first).await["title"], "First");

    // Taken out of the Trash, it waits for "Describe cards" again.
    server
        .patch(&format!("/api/cards/{second}"), json!({ "trashed": false }))
        .await;
    let card = row(&server, second).await;
    assert_eq!(
        (&card["describing"], &card["title"]),
        (&json!(false), &json!("Mira of the North Light"))
    );
    assert_eq!(server.get("/api/describe").await.1["left"], 1);
}

/// A server whose one card is described and then asked with `needs` as the answer, the same if asked once more.
async fn described_with(needs: Says) -> (Server, Api, i64) {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        needs.clone(),
        needs,
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    (server, api, id)
}

#[tokio::test]
async fn a_need_counts_at_its_level_whatever_its_quote() {
    let (server, _api, id) = described_with(asked(json!([
        { "need": "keep_company", "quote": "a dragon sings of nothing here", "level": 3 },
        { "need": "listen", "quote": "", "level": 2 },
        { "need": "made_up", "quote": "Mira", "level": 3 },
    ])))
    .await;
    let needs = needs_of(&server, id).await;
    assert_eq!(needs["state"], "found", "{needs}");
    assert_eq!(needs["needs"].as_array().unwrap().len(), 2, "{needs}");
    assert_eq!(needs["needs"][0]["need"], "keep_company");
    assert_eq!(needs["needs"][0]["level"], 3);
    assert_eq!(needs["needs"][1]["need"], "listen");
}

#[tokio::test]
async fn zero_needs_is_a_state_apart_from_not_asked() {
    let none = asked(json!([{ "need": "sex", "quote": "", "level": 0 }]));
    let (server, api) = model(vec![reply(&classified()), reply(&written("K")), none]).await;
    let id = import(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "not_asked");
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "zero");
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn a_need_counts_from_level_2_and_no_setting_moves_it() {
    let (server, _api, id) = described_with(asked(json!([
        { "need": "keep_company", "quote": "Mira", "level": 1 },
        { "need": "listen", "quote": "Mira", "level": 2 },
    ])))
    .await;
    let found = needs_of(&server, id).await;
    assert_eq!(found["needs"].as_array().unwrap().len(), 1);
    assert_eq!(found["needs"][0]["need"], "listen");
    let (_, settings) = server.get("/api/settings").await;
    assert!(settings.get("need_counts_from").is_none());
}

#[tokio::test]
async fn every_need_counts_from_the_same_level() {
    let (server, _api, id) = described_with(asked(json!([
        { "need": "truth", "quote": "Mira", "level": 2 },
        { "need": "safe", "quote": "Mira", "level": 3 },
        { "need": "listen", "quote": "Mira", "level": 2 },
    ])))
    .await;
    let counted = |needs: &Value| -> Vec<String> {
        let found = needs["needs"].as_array().unwrap();
        let names = found.iter().map(|need| need["need"].as_str().unwrap());
        names.map(str::to_string).collect()
    };
    let mut seen = counted(&needs_of(&server, id).await);
    seen.sort();
    assert_eq!(seen, ["listen", "safe", "truth"]);
}

#[tokio::test]
async fn an_answer_without_needs_fails_and_counts_as_failed() {
    let (server, _api, id) = described_with(reply(&json!({ "verdict": "classified" }))).await;
    assert_eq!(needs_of(&server, id).await["state"], "failed");
    assert_eq!(server.get("/api/describe").await.1["failed"], 1);
}

/// A compact card gets compact answers from some models, and those break (milestone 121).
#[tokio::test]
async fn the_card_goes_to_every_ask_on_one_spaced_line() {
    let (_server, api, _id) = described_with(asked(json!([
        { "need": "keep_company", "quote": "Mira", "level": 3 }
    ])))
    .await;
    let asks = api.asked();
    assert_eq!(asks.len(), 3);
    for ask in &asks {
        let body = serde_json::from_str::<Value>(&ask.body).unwrap();
        let card = body["messages"][1]["content"].as_str().unwrap();
        assert!(card.contains(">\n{\"title\": \""), "{card}");
        assert!(card.contains("\", \"tags\": ["), "{card}");
    }
}

#[tokio::test]
async fn a_cards_unread_needs_keep_their_reason_and_the_button_asks_them_again() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        reply(&json!("")),
        reply(&json!("")),
        asked(json!([{ "need": "keep_company", "quote": "Mira", "level": 3 }])),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    let progress = done(&server).await;
    assert_eq!(progress["failed"], 1, "{progress}");
    let failure = progress["failure"]["error"].as_str().unwrap();
    assert!(failure.contains("needs cannot be read"), "{failure}");
    assert_eq!(needs_of(&server, id).await["state"], "failed");

    server.post("/api/describe", json!({})).await;
    let progress = done(&server).await;
    assert_eq!(progress["failed"], 0, "{progress}");
    assert_eq!(needs_of(&server, id).await["state"], "found");
    // Only the needs were asked again: the description stands.
    assert_eq!(api.asked().len(), 5);
    assert_eq!(row(&server, id).await["title"], "The Keeper");
}

#[tokio::test]
async fn a_classified_card_with_an_empty_list_has_no_need() {
    let (server, _api, id) = described_with(asked(json!([]))).await;
    assert_eq!(needs_of(&server, id).await["state"], "zero");
    let unsaid = json!({ "verdict": "", "needs": [] });
    let (server, _api, id) = described_with(reply(&unsaid)).await;
    assert_eq!(needs_of(&server, id).await["state"], "failed");
}

#[tokio::test]
async fn an_answer_with_no_entry_that_can_be_read_fails_rather_than_finding_no_need() {
    // By the need's words, with its level as a string: not one entry names a need of the list at a level.
    let unusable = json!([{ "need": "I need sex", "quote": "Mira", "level": "2" }]);
    let (server, _api, id) = described_with(asked(unusable)).await;
    assert_eq!(needs_of(&server, id).await["state"], "failed");
    // One level 0 of a need of the list is an answer: it found no need.
    let nothing = json!([{ "need": "sex", "quote": "", "level": 0 }]);
    let (server, _api, id) = described_with(asked(nothing)).await;
    assert_eq!(needs_of(&server, id).await["state"], "zero");
}

#[tokio::test]
async fn a_cards_needs_never_reach_its_export() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        asked(json!([{ "need": "keep_company", "quote": "Mira", "level": 3 }])),
    ])
    .await;
    let id = import(&server).await;
    let path = format!("/api/cards/{id}/export");
    let (_, before) = server.download(&path).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "found");
    let (_, after) = server.download(&path).await;
    assert_eq!(before, after);
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn a_second_server_on_the_same_data_does_not_queue_cards_described_before_the_list() {
    let answer = asked(json!([{ "need": "keep_company", "quote": "Mira", "level": 3 }]));
    let (server, api, id) = described_with(answer).await;
    let options = server.options();
    let db = cw_store::Db::open(
        &options.data_dir.join(cw_key::FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    db.with(|c| c.execute("delete from card_needs", []))
        .unwrap();
    drop(db);
    let before = needs_of(&server, id).await["state"].clone();
    let second = cardwave_server::router(options).unwrap();
    sleep(Duration::from_millis(500)).await;
    assert_eq!(needs_of(&server, id).await["state"], before);
    assert_eq!(api.asked().len(), 3);
    drop(second);
}

#[tokio::test]
async fn cards_described_before_the_list_are_queued_at_a_start() {
    let answer = asked(json!([{ "need": "keep_company", "quote": "Mira", "level": 3 }]));
    let (server, _api, id) = described_with(answer).await;
    let options = server.options();
    let db = cw_store::Db::open(
        &options.data_dir.join(cw_key::FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap();
    db.with(|c| c.execute("delete from card_needs", []))
        .unwrap();
    drop(db);
    let server = server.restart().await;
    let end = Instant::now() + WAIT;
    while needs_of(&server, id).await["state"] != "found" {
        assert!(Instant::now() < end, "not asked after the start");
        sleep(Duration::from_millis(50)).await;
    }
}

#[tokio::test]
async fn needs_that_cannot_be_read_are_asked_once_more_and_no_further() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        reply(&json!("")),
        finds("sex"),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "found");
    assert_eq!(api.asked().len(), 4);

    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        reply(&json!("")),
        reply(&json!("")),
        finds("sex"),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "failed");
    assert_eq!(api.asked().len(), 4);
}

#[tokio::test]
async fn a_description_that_cannot_be_read_is_asked_once_more_and_no_further() {
    // The classifier's answer, then the writer's, each unreadable once.
    let (server, api) = model(vec![
        reply(&json!("")),
        reply(&classified()),
        reply(&json!("")),
        reply(&written("The Keeper")),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    assert_eq!(done(&server).await["failed"], 0);
    assert_eq!(row(&server, id).await["title"], "The Keeper");
    assert_eq!(api.asked().len(), 5);

    // Twice: it fails, and only the needs are asked after it.
    let (server, api) = model(vec![reply(&json!("")), reply(&json!(""))]).await;
    import(&server).await;
    server.post("/api/describe", json!({})).await;
    assert_eq!(done(&server).await["failed"], 1);
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn a_refusal_or_a_provider_error_is_not_asked_again() {
    let refused = json!({ "verdict": "reject", "reject_reason": "no" });
    let (server, api, id) = described_with(reply(&refused)).await;
    assert_eq!(needs_of(&server, id).await["state"], "refused");
    assert_eq!(api.asked().len(), 3);

    let error = says(500, JSON, r#"{"error":{"message":"out of credit"}}"#);
    let (server, api, id) = described_with(error).await;
    assert_eq!(needs_of(&server, id).await["state"], "failed");
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn changing_the_helper_model_reads_nothing_again() {
    let (server, api, id) = described_with(finds("sex")).await;
    let provider = json!({ "base_url": api.url, "model": "small-1", "worker_model": "small-2" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    sleep(Duration::from_millis(200)).await;
    assert_eq!(api.asked().len(), 3);
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "sex");
}

#[tokio::test]
async fn stop_drops_the_cards_that_wait_to_be_described_and_lets_the_one_in_hand_finish() {
    let answers = vec![
        slowly(reply(&classified())),
        reply(&written("First")),
        finds("listen"),
    ];
    let (server, api) = model(answers).await;
    let first = import(&server).await;
    import(&server).await;
    import(&server).await;
    let (_, progress) = server.post("/api/describe", json!({})).await;
    assert_eq!(progress["waiting"], 3, "{progress}");

    let (status, stopped) = server
        .call(reqwest::Method::DELETE, "/api/describe", None)
        .await;
    assert_eq!(status, 200, "{stopped}");
    // Only the card in hand is left to finish.
    assert_eq!(stopped["waiting"], 1, "{stopped}");
    let end = Instant::now() + WAIT;
    while row(&server, first).await["title"] != "First" {
        assert!(Instant::now() < end, "the card in hand finishes");
        sleep(Duration::from_millis(20)).await;
    }
    let progress = done(&server).await;
    assert_eq!(
        (&progress["left"], &progress["waiting"]),
        (&json!(2), &json!(0)),
        "{progress}"
    );
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn stop_keeps_the_card_in_hand_not_the_oldest_that_waits() {
    let answers = vec![
        reply(&classified()),
        reply(&written("First")),
        finds("listen"),
        slowly(reply(&classified())),
        reply(&written("Again")),
        finds("listen"),
        reply(&classified()),
        reply(&written("Second")),
        finds("listen"),
    ];
    let (server, api) = model(answers).await;
    import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    // The worker has a card described again in hand when another waits to be described.
    server.post("/api/describe/again", json!({})).await;
    let second = import(&server).await;
    server.post("/api/describe", json!({})).await;
    let (status, stopped) = server
        .call(reqwest::Method::DELETE, "/api/describe", None)
        .await;
    assert_eq!(status, 200, "{stopped}");
    let end = Instant::now() + WAIT;
    while api.asked().len() < 6 {
        assert!(Instant::now() < end, "the card in hand finishes");
        sleep(Duration::from_millis(20)).await;
    }
    sleep(Duration::from_millis(500)).await;
    assert_ne!(
        row(&server, second).await["title"],
        "Second",
        "the card that waited was stopped"
    );
    assert_eq!(api.asked().len(), 6);
}

#[tokio::test]
async fn stop_keeps_the_card_in_hand_after_more_cards_were_queued_during_its_run() {
    let answers = vec![
        slowly(reply(&classified())),
        reply(&written("First")),
        finds("listen"),
    ];
    let (server, api) = model(answers).await;
    let first = import(&server).await;
    server.post("/api/describe", json!({})).await;
    let end = Instant::now() + WAIT;
    while api.asked().is_empty() {
        assert!(Instant::now() < end, "the worker takes the card");
        sleep(Duration::from_millis(20)).await;
    }
    // Queued while the first is in hand: the worker is started again and must keep its card.
    import(&server).await;
    server.post("/api/describe", json!({})).await;
    let (status, stopped) = server
        .call(reqwest::Method::DELETE, "/api/describe", None)
        .await;
    assert_eq!(status, 200, "{stopped}");
    assert_eq!(stopped["waiting"], 1, "{stopped}");
    let end = Instant::now() + WAIT;
    while row(&server, first).await["title"] != "First" {
        assert!(Instant::now() < end, "the card in hand finishes");
        sleep(Duration::from_millis(20)).await;
    }
}

#[tokio::test]
async fn a_logline_that_copies_the_greeting_twice_is_dropped_and_the_description_kept() {
    let mut copied = written("Wren");
    copied["logline"] = json!("The lamp is lit for you.");
    let (server, api) = model(vec![reply(&classified()), reply(&copied), reply(&copied)]).await;
    let (_, made) = server
        .post(
            "/api/cards/new",
            new_card("Wren", "The lamp is lit for {{user}}."),
        )
        .await;
    let id = made["card_id"].as_i64().unwrap();
    server.post("/api/describe", json!({})).await;
    assert_eq!(done(&server).await["failed"], 0);
    let row = row(&server, id).await;
    assert_eq!(row["excerpt"], "", "{row}");
    assert!(
        row["tags"].as_array().unwrap().contains(&json!("mystery")),
        "{row}"
    );
    assert_eq!(
        api.asked().len(),
        4,
        "the logline is asked once more, then the needs"
    );
}

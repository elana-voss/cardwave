//! The Characters page's view "By need", as the server gives it: `GET /api/needs` (the needs any card has,
//! how many cards are read) and `GET /api/cards?need=…` (the cards with any need picked, the highest sum of
//! levels over the picked first, then the best rank, then by title). No test asks a provider: `read_cards` starts a stand-in that describes each
//! card and then answers its needs as the test says.

mod common;

use std::time::Duration;

use common::api::{Api, JSON, Says, says};
use common::server::{Server, WAIT, start};
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

fn reply(content: &Value) -> Says {
    let answer = json!({ "choices": [{ "message": { "content": content.to_string() } }] });
    says(200, JSON, &answer.to_string())
}

fn classified() -> Says {
    reply(&json!({
        "verdict": "classified",
        "reject_reason": "",
        "characters": [{ "name": "Mira", "gender": "female", "age": "unspecified" }],
        "pairing": "unspecified",
        "engine": "mystery",
        "multi_mode": false,
        "per_greeting": [{ "greeting_index": 0, "engine": "mystery", "rating": "sfw", "content_flags": [] }],
        "frame": "stranger",
        "frame_display": "stranger",
        "rating": "sfw",
        "content_flags": [],
        "archetype": ["stoic"],
        "mechanism": "keeps you inside the lighthouse",
        "confidence": 0.8,
        "evidence": "The first greeting."
    }))
}

fn written() -> Says {
    reply(&json!({
        "title": "Keeper",
        "logline": "A storm strands you in the lighthouse its keeper never leaves.",
        "summary": "She keeps the north light. A storm has cut you off. It is quiet and wary."
    }))
}

/// What a card's needs are answered with: each need at its level, quoted from the card.
fn levels(needs: &[(&str, u8)]) -> Says {
    let needs: Vec<Value> = needs
        .iter()
        .map(|(need, level)| json!({ "need": need, "quote": "Mira", "level": level }))
        .collect();
    reply(&json!({ "verdict": "classified", "reject_reason": "", "needs": needs }))
}

/// Waits until no card waits to be read.
async fn read(server: &Server) -> Value {
    let end = Instant::now() + WAIT;
    loop {
        let (status, needs) = server.get("/api/needs").await;
        assert_eq!(status, 200, "{needs}");
        if needs["read"] == needs["of"] && needs["of"] != 0 {
            return needs;
        }
        assert!(Instant::now() < end, "still reading: {needs}");
        sleep(Duration::from_millis(50)).await;
    }
}

/// A server with a card per entry of `cards`, each described and read with those needs; the cards' ids in turn.
async fn read_cards(cards: &[&[(&str, u8)]]) -> (Server, Api, Vec<i64>) {
    let mut answers = Vec::new();
    for _ in cards {
        answers.extend([classified(), written()]);
    }
    answers.extend(cards.iter().map(|needs| levels(needs)));
    let api = Api::start_each(answers).await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let mut ids = Vec::new();
    for _ in cards {
        let (status, imported) = server.upload("/api/cards", common::card_copy()).await;
        assert_eq!(status, 201, "{imported}");
        ids.push(imported["card_id"].as_i64().unwrap());
    }
    assert_eq!(server.post("/api/describe", json!({})).await.0, 200);
    read(&server).await;
    (server, api, ids)
}

/// The ids the list has for what is asked after `?`, in its order.
async fn listed(server: &Server, asked: &str) -> Vec<i64> {
    let (status, list) = server.get(&format!("/api/cards?{asked}")).await;
    assert_eq!(status, 200, "{list}");
    let list = list.as_array().unwrap().iter();
    list.map(|card| card["id"].as_i64().unwrap()).collect()
}

#[tokio::test]
async fn the_needs_any_card_has_stand_most_cards_first_then_in_the_lists_order() {
    let (server, _api, ids) = read_cards(&[
        &[("sex", 3), ("listen", 1)],
        &[("keep_company", 2), ("truth", 2)],
        &[("truth", 3)],
        &[],
    ])
    .await;
    let needs = read(&server).await;
    // `truth` is on two cards; of one card each, `keep_company` comes before `sex` in the list; `listen` is
    // under the level.
    assert_eq!(needs["needs"], json!(["truth", "keep_company", "sex"]));
    // Each card's own, as its tile shows them, strongest first; a card with none has no entry.
    let of = |at: usize| &needs["by_card"][ids[at].to_string()];
    assert_eq!(of(0), &json!(["sex"]));
    assert_eq!(of(1), &json!(["keep_company", "truth"]));
    assert_eq!(of(3), &Value::Null);
    assert_eq!((&needs["read"], &needs["of"]), (&json!(4), &json!(4)));
}

#[tokio::test]
async fn nothing_read_yet_has_no_needs_and_nothing_to_read() {
    let server = start().await;
    assert_eq!(
        server.upload("/api/cards", common::card_copy()).await.0,
        201
    );
    let (_, needs) = server.get("/api/needs").await;
    assert_eq!(
        needs,
        json!({ "needs": [], "by_card": {}, "read": 0, "of": 0 })
    );
}

#[tokio::test]
async fn while_reading_says_how_many_of_how_many() {
    let mut slow = classified();
    slow.after = Duration::from_secs(2);
    let api = Api::start_each(vec![slow, written(), levels(&[("sex", 3)])]).await;
    let server = start().await;
    let provider = json!({ "base_url": api.url, "model": "small-1" });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    assert_eq!(
        server.upload("/api/cards", common::card_copy()).await.0,
        201
    );
    assert_eq!(server.post("/api/describe", json!({})).await.0, 200);
    let (_, needs) = server.get("/api/needs").await;
    assert_eq!(
        needs,
        json!({ "needs": [], "by_card": {}, "read": 0, "of": 1 })
    );
    assert_eq!(read(&server).await["needs"][0], "sex");
}

#[tokio::test]
async fn a_card_in_the_trash_has_no_need_that_shows() {
    let (server, _api, ids) = read_cards(&[&[("sex", 3)], &[("listen", 2)]]).await;
    let trashed = json!({ "trashed": true });
    let (status, _) = server
        .patch(&format!("/api/cards/{}", ids[0]), trashed)
        .await;
    assert_eq!(status, 200);
    let (_, needs) = server.get("/api/needs").await;
    assert_eq!(needs["needs"], json!(["listen"]));
    assert_eq!((&needs["read"], &needs["of"]), (&json!(1), &json!(1)));
}

#[tokio::test]
async fn picked_needs_list_the_cards_with_any_the_highest_sum_over_the_picked_first() {
    let (server, _api, ids) = read_cards(&[
        // The highest sum of all its needs, but only 3 of what is picked.
        &[("keep_company", 3), ("sex", 3), ("loved", 3)],
        &[("keep_company", 2), ("listen", 2)],
        &[("sex", 3)],
        &[],
    ])
    .await;
    let picked = "need=keep_company&need=listen";
    assert_eq!(listed(&server, picked).await, [ids[1], ids[0]]);
    assert_eq!(listed(&server, "need=sex").await.len(), 2);
    // None picked: every card, the one with no need too.
    assert_eq!(listed(&server, "").await.len(), 4);
}

/// Gives each card its title.
async fn titled(server: &Server, titles: &[(i64, &str)]) {
    for (card, title) in titles {
        let (status, saved) = server
            .edit_card(&json!(card), |form| form["title"] = json!(title))
            .await;
        assert_eq!(status, 200, "{saved}");
    }
}

#[tokio::test]
async fn within_a_level_the_card_that_names_the_need_earlier_stands_first_then_by_title() {
    let (server, _api, ids) = read_cards(&[
        // Named second, after a hint that does not count but holds its place.
        &[("loved", 1), ("sex", 2)],
        &[("sex", 2)],
        &[("listen", 2), ("sex", 2)],
        // Named last, at the higher level.
        &[("listen", 3), ("loved", 2), ("sex", 3)],
    ])
    .await;
    let titles = [
        (ids[0], "Bea"),
        (ids[1], "Zoe"),
        (ids[2], "Anna"),
        (ids[3], "Zed"),
    ];
    titled(&server, &titles).await;
    assert_eq!(
        listed(&server, "need=sex").await,
        [ids[3], ids[1], ids[2], ids[0]]
    );
}

#[tokio::test]
async fn of_several_picked_the_sum_decides_then_the_earliest_named_then_the_title() {
    let (server, _api, ids) = read_cards(&[
        &[("loved", 2), ("sex", 2), ("listen", 2)],
        &[("sex", 2), ("loved", 2), ("listen", 2)],
        &[("sex", 3)],
        &[("sex", 2), ("listen", 2)],
    ])
    .await;
    let titles = [
        (ids[0], "Anna"),
        (ids[1], "Zoe"),
        (ids[2], "Bea"),
        (ids[3], "Mia"),
    ];
    titled(&server, &titles).await;
    assert_eq!(
        listed(&server, "need=sex&need=listen").await,
        [ids[3], ids[1], ids[0], ids[2]]
    );
}

#[tokio::test]
async fn cards_of_one_level_stand_by_title_whatever_the_sort() {
    let (server, _api, ids) =
        read_cards(&[&[("sex", 2)], &[("sex", 2)], &[("sex", 3)], &[("sex", 2)]]).await;
    let titles = [
        (ids[0], "Zoe"),
        (ids[1], "anna"),
        (ids[2], "Zed"),
        (ids[3], "Bea"),
    ];
    titled(&server, &titles).await;
    let wanted = [ids[2], ids[1], ids[3], ids[0]];
    assert_eq!(listed(&server, "need=sex").await, wanted);
    assert_eq!(listed(&server, "need=sex&sort=added").await, wanted);
}

#[tokio::test]
async fn a_picked_need_holds_the_level_that_counts() {
    let (server, _api, ids) = read_cards(&[
        &[("listen", 1)],
        &[("listen", 2), ("truth", 2)],
        &[("listen", 3), ("truth", 3)],
    ])
    .await;
    assert_eq!(listed(&server, "need=listen").await, [ids[2], ids[1]]);
    assert_eq!(listed(&server, "need=truth").await, [ids[2], ids[1]]);
}

#[tokio::test]
async fn a_picked_need_narrows_with_what_else_is_asked() {
    let (server, _api, ids) = read_cards(&[&[("sex", 3)], &[("sex", 2)], &[]]).await;
    let favorite = json!({ "favorite": true });
    let (status, _) = server
        .patch(&format!("/api/cards/{}", ids[1]), favorite)
        .await;
    assert_eq!(status, 200);
    assert_eq!(listed(&server, "need=sex&show=favorites").await, [ids[1]]);
    assert!(
        listed(&server, "need=sex&q=nothing-like-it")
            .await
            .is_empty()
    );
    // The tags to filter by count the cards the list holds.
    let (_, tags) = server.get("/api/cards/tags?need=listen").await;
    assert_eq!(tags, json!([]));
}

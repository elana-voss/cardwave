//! "Describe all again": it redoes pitch, summary, tags and needs of every
//! character not in the Trash, a character one step of both calls. Until a
//! character's new result has come its old one stays; a failure keeps the old;
//! Stop ends the run after the character in hand. No test asks a provider.

mod common;

use std::time::Duration;

use common::api::Says;
use common::describing::*;
use common::server::{Server, WAIT, start, until};
use reqwest::Method;
use serde_json::{Value, json};
use tokio::time::{Instant, sleep};

/// Waits until nothing waits to be described again, and answers how far that is.
async fn again_done(server: &Server) -> Value {
    until(|| async {
        let (status, progress) = server.get("/api/describe/again").await;
        assert_eq!(status, 200, "{progress}");
        match progress["waiting"] == 0 {
            true => Ok(progress),
            false => Err(format!("still describing again: {progress}")),
        }
    })
    .await
}

async fn describe_again(server: &Server) -> Value {
    let (status, progress) = server.post("/api/describe/again", json!({})).await;
    assert_eq!(status, 200, "{progress}");
    progress
}

/// A writer's answer that differs from `written` in all it writes.
fn rewritten(title: &str) -> Value {
    json!({
        "title": title, "logline": "Another pitch.", "summary": "Another summary.",
        "tagline": "Another line.", "mood": "sci-fi"
    })
}

/// A character's three answers: its description and its needs.
fn described(title: &str, need: &str) -> Vec<Says> {
    vec![reply(&classified()), reply(&rewritten(title)), finds(need)]
}

/// An answer that cannot be read, twice: the asking once more fails too.
fn unread_twice() -> Vec<Says> {
    vec![reply(&json!("")), reply(&json!(""))]
}

async fn summary_of(server: &Server, id: i64) -> Value {
    server.get(&format!("/api/cards/{id}")).await.1["summary"].clone()
}

async fn put_in_the_trash(server: &Server, id: i64) {
    let patched = server
        .patch(&format!("/api/cards/{id}"), json!({ "trashed": true }))
        .await;
    assert_eq!(patched.0, 200);
}
#[tokio::test]
async fn describing_again_redoes_all_and_the_old_stays_until_the_new_has_come() {
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
        reply(&classified()),
        slowly(reply(&rewritten("The Other"))),
        finds("listen"),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    let first = row(&server, id).await;
    assert_eq!(
        (&first["poster"]["tagline"], &first["poster"]["mood"]),
        (&json!("Some lights are kept for you."), &json!("drama"))
    );
    let (_, before) = server.get("/api/describe/again").await;
    assert_eq!(
        before,
        json!({ "characters": 1, "waiting": 0, "done": 0, "failed": 0, "failure": null, "stopped": false })
    );

    let progress = describe_again(&server).await;
    assert_eq!(
        (&progress["waiting"], &progress["done"]),
        (&json!(1), &json!(0))
    );
    assert_eq!(row(&server, id).await["title"], "The Keeper");
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "sex");
    // Nothing of "Describe cards" moves.
    assert_eq!(server.get("/api/describe").await.1["waiting"], 0);

    let progress = again_done(&server).await;
    assert_eq!(
        (&progress["done"], &progress["failed"]),
        (&json!(1), &json!(0))
    );
    let shown = row(&server, id).await;
    assert_eq!(
        (&shown["title"], &shown["excerpt"]),
        (&json!("The Other"), &json!("Another pitch."))
    );
    assert_eq!(
        (&shown["poster"]["tagline"], &shown["poster"]["mood"]),
        (&json!("Another line."), &json!("sci_fi"))
    );
    assert_eq!(summary_of(&server, id).await, "Another summary.");
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "listen");
    assert_eq!(api.asked().len(), 6);
    // A character that comes after a full run does not make it a stopped one.
    import(&server).await;
    let (_, after) = server.get("/api/describe/again").await;
    assert_eq!(
        (&after["characters"], &after["done"], &after["stopped"]),
        (&json!(2), &json!(1), &json!(false))
    );
}

#[tokio::test]
async fn a_failure_while_describing_again_keeps_the_old_and_says_failed() {
    let mut answers = vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
    ];
    answers.extend(unread_twice()); // the description
    answers.extend(unread_twice()); // the needs, asked all the same
    let (server, api) = model(answers).await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;

    describe_again(&server).await;
    let progress = again_done(&server).await;
    assert_eq!(
        (&progress["done"], &progress["failed"]),
        (&json!(1), &json!(1)),
        "{progress}"
    );
    assert!(progress["failure"]["error"].is_string(), "{progress}");
    assert_eq!(row(&server, id).await["title"], "The Keeper");
    let needs = needs_of(&server, id).await;
    assert_eq!(
        (&needs["state"], &needs["needs"][0]["need"]),
        (&json!("found"), &json!("sex"))
    );
    assert_eq!(api.asked().len(), 7);
    // Not a card for "Describe cards": what it holds stands.
    assert_eq!(server.get("/api/describe").await.1["failed"], 0);
}

#[tokio::test]
async fn a_description_that_fails_alone_keeps_its_old_and_the_needs_are_new() {
    let mut answers = vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
    ];
    answers.extend(unread_twice());
    answers.push(finds("listen"));
    let (server, _api) = model(answers).await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;

    describe_again(&server).await;
    assert_eq!(again_done(&server).await["failed"], 1);
    assert_eq!(row(&server, id).await["title"], "The Keeper");
    let needs = needs_become(&server, id, "found").await;
    assert_eq!(needs["needs"][0]["need"], "listen");
}

#[tokio::test]
async fn a_character_never_described_whose_redo_fails_is_told_once_until_describe_cards_takes_it() {
    let mut answers = unread_twice();
    answers.extend(unread_twice());
    answers.extend(described("The Keeper", "keep_company"));
    let (server, _api) = model(answers).await;
    let id = import(&server).await;
    describe_again(&server).await;
    assert_eq!(again_done(&server).await["failed"], 1);
    assert_eq!(needs_of(&server, id).await["state"], "failed");
    let (_, describing) = server.get("/api/describe").await;
    assert_eq!(
        (&describing["failed"], &describing["left"]),
        (&json!(0), &json!(1))
    );

    let (status, _) = server.post("/api/describe", json!({})).await;
    assert_eq!(status, 200);
    assert_eq!(done(&server).await["failed"], 0);
    let progress = again_done(&server).await;
    assert_eq!(
        (&progress["failed"], &progress["failure"]),
        (&json!(0), &Value::Null)
    );
}

#[tokio::test]
async fn a_redo_failing_while_describe_cards_takes_the_card_up_leaves_it_to_describe_cards() {
    let mut answers = unread_twice();
    answers.push(slowly(finds("sex")));
    answers.extend(unread_twice());
    answers.push(finds("listen"));
    let (server, api) = model(answers).await;
    import(&server).await;
    describe_again(&server).await;
    let end = Instant::now() + WAIT;
    while api.asked().len() < 3 {
        assert!(Instant::now() < end, "its needs were not asked");
        sleep(Duration::from_millis(20)).await;
    }

    // The description failed and its needs are on their way: told by neither line yet, and not by both after.
    assert_eq!(server.get("/api/describe").await.1["failed"], 0);
    assert_eq!(server.post("/api/describe", json!({})).await.0, 200);
    let describing = done(&server).await;
    assert_eq!(describing["failed"], 1, "{describing}");
    assert_eq!(again_done(&server).await["failed"], 0);
}

#[tokio::test]
async fn a_summary_and_a_title_edited_by_hand_stay_through_describing_again() {
    let mut answers = vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
    ];
    answers.extend(described("Generated", "listen"));
    let (server, _api) = model(answers).await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    let path = format!("/api/cards/{id}/edit");
    let (_, mut form) = server.get(&path).await;
    form["title"] = json!("My Mira");
    assert_eq!(server.put(&path, form).await.0, 200);
    let summary = format!("/api/cards/{id}/summary");
    let put = server.put(&summary, json!({ "summary": "Mine." })).await;
    assert_eq!(put.0, 204);

    describe_again(&server).await;
    assert_eq!(again_done(&server).await["failed"], 0);
    let shown = row(&server, id).await;
    assert_eq!(
        (&shown["title"], &shown["excerpt"]),
        (&json!("My Mira"), &json!("Another pitch."))
    );
    assert_eq!(summary_of(&server, id).await, "Mine.");
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "listen");
}

#[tokio::test]
async fn describing_again_also_asks_a_refused_card_and_passes_over_the_trash() {
    let refused = json!({ "verdict": "reject", "reject_reason": "no" });
    let mut answers = vec![reply(&refused)];
    answers.extend(described("Now Described", "sex"));
    let (server, api) = model(answers).await;
    let id = import(&server).await;
    let trashed = import(&server).await;
    put_in_the_trash(&server, trashed).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;
    assert_eq!(needs_of(&server, id).await["state"], "refused");
    assert_eq!(api.asked().len(), 1);

    let progress = describe_again(&server).await;
    assert_eq!(progress["characters"], 1, "{progress}");
    assert_eq!(again_done(&server).await["done"], 1);
    assert_eq!(row(&server, id).await["title"], "Now Described");
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "sex");
    assert_eq!(api.asked().len(), 4);
}

#[tokio::test]
async fn a_needs_failure_after_a_refusal_is_lifted_says_failed() {
    let refused = json!({ "verdict": "reject", "reject_reason": "no" });
    let mut answers = vec![
        reply(&refused),
        reply(&classified()),
        reply(&rewritten("Now Described")),
    ];
    answers.extend(unread_twice());
    let (server, _api) = model(answers).await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;

    describe_again(&server).await;
    assert_eq!(again_done(&server).await["failed"], 1);
    // Failed, so "Describe cards" can ask it; a refusal would never be asked again.
    assert_eq!(needs_of(&server, id).await["state"], "failed");
}

#[tokio::test]
async fn a_refusal_on_a_redo_keeps_the_old_skips_the_needs_and_counts_as_done() {
    let refused = json!({ "verdict": "reject", "reject_reason": "no" });
    let (server, api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
        reply(&refused),
    ])
    .await;
    let id = import(&server).await;
    server.post("/api/describe", json!({})).await;
    done(&server).await;

    describe_again(&server).await;
    let progress = again_done(&server).await;
    assert_eq!(
        (&progress["done"], &progress["failed"]),
        (&json!(1), &json!(0)),
        "{progress}"
    );
    assert_eq!(row(&server, id).await["title"], "The Keeper");
    assert_eq!(needs_of(&server, id).await["needs"][0]["need"], "sex");
    assert_eq!(api.asked().len(), 4);
}

#[tokio::test]
async fn a_character_put_in_the_trash_while_it_waits_is_not_described_again() {
    let mut answers = described("First", "sex");
    answers[0] = slowly(reply(&classified()));
    let (server, api) = model(answers).await;
    let first = import(&server).await;
    let second = import(&server).await;
    describe_again(&server).await;
    put_in_the_trash(&server, second).await;
    assert_eq!(again_done(&server).await["waiting"], 0);
    needs_become(&server, first, "found").await;
    assert_eq!(api.asked().len(), 3);
}

#[tokio::test]
async fn stop_lets_the_character_in_hand_finish_both_calls_and_drops_only_what_waits_for_this() {
    let mut answers = described("First", "sex");
    answers[0] = slowly(reply(&classified()));
    // The card imported while it runs, with the switch on: it waits for this action not at all.
    answers.extend(described("Imported", "listen"));
    let (server, api) = model(answers).await;
    let first = import(&server).await;
    let second = import(&server).await;
    let third = import(&server).await;
    assert_eq!(describe_again(&server).await["waiting"], 3);

    let on = json!({ "describe_imported": true });
    assert_eq!(server.patch("/api/settings", on).await.0, 200);
    let imported = import(&server).await;
    let (status, stopped) = server
        .call(Method::DELETE, "/api/describe/again", None)
        .await;
    assert_eq!(status, 200, "{stopped}");
    assert_eq!(stopped["waiting"], 0, "{stopped}");
    assert_eq!(stopped["stopped"], true, "{stopped}");

    needs_become(&server, first, "found").await;
    needs_become(&server, imported, "found").await;
    assert_eq!(row(&server, first).await["title"], "First");
    assert_eq!(row(&server, imported).await["title"], "Imported");
    assert_eq!(needs_of(&server, second).await["state"], "not_asked");
    assert_eq!(needs_of(&server, third).await["state"], "not_asked");
    assert_eq!(api.asked().len(), 6);

    // Pressed again it starts over from all of them.
    let progress = describe_again(&server).await;
    assert_eq!(
        (&progress["waiting"], &progress["done"]),
        (&json!(4), &json!(0))
    );
}

#[tokio::test]
async fn pressing_again_while_a_character_is_in_hand_starts_that_character_over() {
    let mut answers = vec![slowly(reply(&classified())), reply(&rewritten("Cut Short"))];
    answers.extend(described("Whole", "sex"));
    let (server, api) = model(answers).await;
    let id = import(&server).await;
    describe_again(&server).await;
    // The first answer is on its way.
    let end = Instant::now() + WAIT;
    while api.asked().is_empty() {
        assert!(Instant::now() < end, "nothing was asked");
        sleep(Duration::from_millis(10)).await;
    }
    assert_eq!(describe_again(&server).await["done"], 0);
    assert_eq!(again_done(&server).await["done"], 1);
    assert_eq!(row(&server, id).await["title"], "Whole");
    assert_eq!(api.asked().len(), 5);
}

#[tokio::test]
async fn what_waits_to_be_described_again_is_let_go_at_a_start() {
    let mut never = finds("sex");
    never.after = Duration::from_secs(600);
    let (server, _api) = model(vec![never]).await;
    import(&server).await;
    describe_again(&server).await;
    let server = server.restart().await;
    assert_eq!(server.get("/api/describe/again").await.1["waiting"], 0);
}

#[tokio::test]
async fn describing_again_without_a_model_says_so() {
    let server = start().await;
    let (status, _) = server.post("/api/describe/again", json!({})).await;
    assert_eq!(status, 424);
}

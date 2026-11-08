//! A card's poster design: the letter comes with its description, in the list Posters fetches next (`?posters=true`;
//! no other view is sent what a poster shows). The rule itself
//! is tested in `cw_library::posters`.

mod common;

use common::describing::{classified, done, finds, import, model, reply, written};
use serde_json::json;

#[tokio::test]
async fn a_card_is_given_its_design_as_it_is_described() {
    let (server, _api) = model(vec![
        reply(&classified()),
        reply(&written("The Keeper")),
        finds("sex"),
    ])
    .await;
    import(&server).await;
    let (status, _) = server.post("/api/describe", json!({})).await;
    assert_eq!(status, 200);
    done(&server).await;
    let (_, after) = server.get("/api/cards?posters=true").await;
    assert_eq!(after[0]["poster"]["mood"], "drama");
    assert_eq!(after[0]["poster"]["design"], "a");
}

/// What a poster shows goes only to Posters, which asks for it; the other views and the card's page go without.
#[tokio::test]
async fn only_posters_are_sent_what_a_poster_shows() {
    let (server, _api) = model(vec![]).await;
    let id = import(&server).await;
    let (_, plain) = server.get("/api/cards").await;
    assert_eq!(plain[0]["poster"], serde_json::Value::Null, "{plain}");
    assert_eq!(plain[0].get("tagline"), None, "{plain}");
    let (_, asked) = server.get("/api/cards?posters=true").await;
    assert_eq!(asked[0]["poster"]["faces"], json!([]), "{asked}");
    let (_, page) = server.get(&format!("/api/cards/{id}")).await;
    assert_eq!(page["card"]["poster"], serde_json::Value::Null, "{page}");
}

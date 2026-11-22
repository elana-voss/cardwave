//! The chat tools (`cw-coding`'s `tools/dice.rs` and `tools/names.rs`): the
//! dice rolled on the server, names for new characters never given twice in
//! a chat, each off until switched on in the settings; a round past the last
//! offered no tools.
//!
//! `Model` (`common::model`) is a stand-in for a model's server.

mod common;

use common::model::{Model, call_pieces, chat_at, names, next_event, stream, text_piece};
use common::server::start;
use serde_json::{Value, json};

#[tokio::test]
async fn the_dice_are_rolled_on_the_server_once_switched_on() {
    let server = start().await;
    let model = Model::start(vec![
        (200, stream(&[text_piece("No dice.")])),
        (
            200,
            stream(&call_pieces("dice", &json!({ "count": 2, "sides": 10 }))),
        ),
        (200, stream(&[text_piece("The dice roll.")])),
    ])
    .await;
    // No tool is switched on in the settings: the dice are off until switched on (the owner, 2026-10-23).
    let chat = chat_at(&server, &model).await;
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "No dice.", "{ended}");
    assert!(model.asked()[0].get("tools").is_none());

    let on = server
        .patch("/api/settings", json!({ "tools": { "dice": true } }))
        .await;
    assert_eq!(on.1["tools"]["dice"], true, "{on:?}");
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    assert_eq!(ended["message"]["content"], "The dice roll.", "{ended}");
    let asked = &model.asked()[1..];
    assert_eq!(names(&asked[0]["tools"]), ["dice"]);
    let rolled = asked[1]["messages"].as_array().unwrap().last().unwrap();
    assert_eq!(rolled["tool_call_id"], "call_1");
    // "2d10: 7 + 3 = 10": each die from 1 to 10, and their sum.
    let said = rolled["content"].as_str().unwrap();
    let (dice, total) = said
        .strip_prefix("2d10: ")
        .and_then(|rest| rest.split_once(" = "))
        .unwrap_or_else(|| panic!("{said}"));
    let dice: Vec<u32> = dice.split(" + ").map(|die| die.parse().unwrap()).collect();
    assert_eq!(dice.len(), 2, "{said}");
    assert!(dice.iter().all(|die| (1..=10).contains(die)), "{said}");
    assert_eq!(total.parse::<u32>().unwrap(), dice.iter().sum::<u32>());
}

/// The name the model was given in its last ask's tool reply, which is told
/// as the tool's JSON answer.
fn name_given(asked: &Value) -> String {
    let reply = asked["messages"].as_array().unwrap().last().unwrap();
    let answer: Value = serde_json::from_str(reply["content"].as_str().unwrap())
        .unwrap_or_else(|_| panic!("{reply}"));
    answer["first_name"]
        .as_str()
        .unwrap_or_else(|| panic!("{answer}"))
        .to_string()
}

#[tokio::test]
async fn names_are_offered_once_switched_on_and_not_given_twice_in_a_chat() {
    // The database holds exactly six Greek first names of ambiguous gender:
    // five are given before the app is closed, the sixth after, so a chat
    // that forgot its names would pass only by a one-in-six chance.
    const GREEK: [&str; 6] = [
        "Chelone",
        "Ephialtes",
        "Hesperis",
        "Oenomaus",
        "Thaleia",
        "Thanatos",
    ];
    let filters = json!({ "language_ethnicity": "greek", "gender": "ambiguous" });
    let call = || (200, stream(&call_pieces("suggest_npc_name", &filters)));
    let mut replies = vec![(200, stream(&[text_piece("No name.")]))];
    replies.extend((0..5).map(|_| call()));
    replies.push((200, stream(&[text_piece("Five names.")])));
    replies.push(call());
    replies.push((200, stream(&[text_piece("The sixth name.")])));
    let server = start().await;
    let model = Model::start(replies).await;
    let chat = chat_at(&server, &model).await;
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(next_event(&mut socket).await["type"], "reply_ended");
    // Off: neither offered nor told of.
    let off = &model.asked()[0];
    assert!(off.get("tools").is_none(), "{off}");
    assert!(!off["messages"].to_string().contains("suggest_npc_name"));

    let on = server
        .patch("/api/settings", json!({ "tools": { "names": true } }))
        .await;
    assert_eq!(on.1["tools"]["names"], true, "{on:?}");
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(next_event(&mut socket).await["type"], "reply_ended");
    let asked = &model.asked()[1..];
    assert_eq!(names(&asked[0]["tools"]), ["suggest_npc_name"]);
    // The note on the tool stands just before the chat's latest message.
    let messages = asked[0]["messages"].as_array().unwrap();
    let told = |message: &Value| message.to_string().contains("suggest_npc_name");
    let note = messages
        .iter()
        .position(told)
        .expect("the note on the tool");
    assert_eq!(messages[note]["role"], "system");
    assert_eq!(messages[note + 1]["content"], "No name.");
    assert_eq!(messages.iter().filter(|message| told(message)).count(), 1);
    let mut given: Vec<String> = asked[1..6].iter().map(name_given).collect();

    // Closed and opened again, the chat still knows the name it used.
    drop(socket);
    let server = server.restart().await;
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    assert_eq!(next_event(&mut socket).await["type"], "reply_ended");
    given.push(name_given(&model.asked()[8]));
    given.sort();
    assert_eq!(given, GREEK);
}

#[tokio::test]
async fn used_in_this_reply_names_the_filters_never_the_name_kept_back() {
    let filters = json!({ "language_ethnicity": "japanese", "gender": "female" });
    let server = start().await;
    let model = Model::start(vec![
        (200, stream(&call_pieces("suggest_npc_name", &filters))),
        (200, stream(&[text_piece("A woman at the counter.")])),
    ])
    .await;
    let chat = chat_at(&server, &model).await;
    let on = server
        .patch("/api/settings", json!({ "tools": { "names": true } }))
        .await;
    assert_eq!(on.1["tools"]["names"], true, "{on:?}");
    let mut socket = server.listen().await;
    assert_eq!(
        server.post(&format!("{chat}/generate"), json!({})).await.0,
        202
    );
    let ended = next_event(&mut socket).await;
    let calls = &ended["message"]["calls"];
    assert_eq!(calls[0]["tool"], "suggest_npc_name", "{ended}");
    assert_eq!(calls[0]["what"], "female, japanese", "{ended}");
    let name = name_given(&model.asked()[1]);
    assert!(!calls.to_string().contains(&name), "{calls}");
}

#[tokio::test]
async fn a_round_offered_no_tools_is_not_told_of_them() {
    // Eight rounds of calls, after which the last is offered no tools; then a
    // reply whose server refuses tools and is asked again without.
    let call = || (200, stream(&call_pieces("suggest_npc_name", &json!({}))));
    let mut replies: Vec<_> = (0..8).map(|_| call()).collect();
    replies.push((200, stream(&[text_piece("Named.")])));
    replies.push((
        400,
        json!({ "error": { "message": "tools are not supported" } }).to_string(),
    ));
    replies.push((200, stream(&[text_piece("Hello.")])));
    let server = start().await;
    let model = Model::start(replies).await;
    let chat = chat_at(&server, &model).await;
    let on = server
        .patch("/api/settings", json!({ "tools": { "names": true } }))
        .await;
    assert_eq!(on.1["tools"]["names"], true, "{on:?}");
    let mut socket = server.listen().await;
    for _ in 0..2 {
        assert_eq!(
            server.post(&format!("{chat}/generate"), json!({})).await.0,
            202
        );
        assert_eq!(next_event(&mut socket).await["type"], "reply_ended");
    }
    let asked = model.asked();
    let told = |at: usize| {
        asked[at]["messages"]
            .to_string()
            .contains("call suggest_npc_name")
    };
    assert!(told(0) && told(7) && told(9));
    for at in [8, 10] {
        assert!(asked[at].get("tools").is_none(), "{}", asked[at]);
        assert!(!told(at), "{}", asked[at]["messages"]);
    }
}

//! How a reply ends: cut at the model's own limit (told so until a Continue
//! ends it whole) or cut off mid-sentence (trimmed to its last whole sentence).
//! The stand-in model server is `common::streamed`.

mod common;

use common::server::{event, start};
use common::streamed::*;
use serde_json::{Value, json};

/// The end of a streamed reply with the reason the provider gives for it.
fn ends(reason: &str) -> Vec<u8> {
    let event = json!({ "choices": [{ "delta": {}, "finish_reason": reason }] });
    [format!("data: {event}\n\n").as_bytes(), DONE].concat()
}

/// The text the chat keeps of its newest message.
async fn stored(server: &common::server::Server, chat: &str) -> Value {
    newest(server, chat).await["content"].clone()
}

/// The chat's newest message as it keeps it.
async fn newest(server: &common::server::Server, chat: &str) -> Value {
    let (_, view) = server.get(chat).await;
    view["messages"].as_array().unwrap().last().unwrap().clone()
}

#[tokio::test]
async fn a_reply_cut_at_the_model_s_own_limit_says_so_until_a_continue_ends_it_whole() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    // models.dev says it thinks, so it is asked without the chat's Reply length.
    let thinks =
        json!({ "base_url": provider.url, "model": "deepseek-v3-1", "api_key": "sk-test" });
    assert_eq!(server.put("/api/provider", thinks).await.0, 200);
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let cut = "The hall is dark. She opens the door and";

    // Cut at the model's own limit: kept as it came, stored and told as cut off.
    generate(&server, &chat, json!({})).await;
    let asked = provider.next().await;
    assert_eq!(asked.body["max_tokens"], Value::Null);
    asked
        .answer
        .send([says(cut), ends("length")].concat())
        .unwrap();
    let message = &follow(&mut socket, "").await.1["message"];
    assert_eq!(
        (&message["content"], &message["ending"]),
        (&json!(cut), &json!("cut_off"))
    );
    assert_eq!(newest(&server, &chat).await["ending"], "cut_off");

    // A continue that adds no word (its stream cut) keeps it; one that ends whole clears it.
    let more = json!({ "continue": true });
    generate(&server, &chat, more.clone()).await;
    drop(provider.next().await);
    let ended = follow(&mut socket, cut).await.1;
    assert_ne!(ended["error"], Value::Null, "{ended}");
    assert_eq!(newest(&server, &chat).await["ending"], "cut_off");
    generate(&server, &chat, more).await;
    let asked = provider.next().await;
    asked
        .answer
        .send([says(" looks out."), ends("stop")].concat())
        .unwrap();
    let message = &follow(&mut socket, cut).await.1["message"];
    assert_eq!(message["ending"], "whole", "{message}");
    assert_eq!(newest(&server, &chat).await["ending"], "whole");
}

#[tokio::test]
async fn a_reply_cut_off_mid_sentence_ends_with_its_last_whole_sentence() {
    let server = start().await;
    let mut provider = Provider::start().await;
    use_provider(&server, &provider.url).await;
    let chat = chat(&server).await;
    let mut socket = server.listen().await;
    let whole = "The hall is dark and quiet tonight. She opens the door and looks out at the sea.";
    let words = format!("{whole} Behind it she");
    let again = json!({ "regenerate": true });

    // Cut off at the chat's Reply length, or with no reason given: shown and stored to the
    // last sentence, and whole: the length is the user's own.
    for (end, how) in [(ends("length"), json!({})), (DONE.to_vec(), again.clone())] {
        generate(&server, &chat, how).await;
        let asked = provider.next().await;
        assert_eq!(asked.body["max_tokens"], 350);
        asked.answer.send([says(&words), end].concat()).unwrap();
        let message = &follow(&mut socket, "").await.1["message"];
        assert_eq!(
            (&message["content"], &message["ending"]),
            (&json!(whole), &json!("whole"))
        );
        let kept = newest(&server, &chat).await;
        assert_eq!(
            (&kept["content"], &kept["ending"]),
            (&json!(whole), &json!("whole"))
        );
    }

    // Ended on its own, or stopped with Stop: as it came.
    generate(&server, &chat, again.clone()).await;
    let asked = provider.next().await;
    asked
        .answer
        .send([says(&words), ends("stop")].concat())
        .unwrap();
    assert_eq!(follow(&mut socket, "").await.1["message"]["content"], words);
    assert_eq!(stored(&server, &chat).await, words);
    generate(&server, &chat, again.clone()).await;
    let asked = provider.next().await;
    asked.answer.send(says(&words)).unwrap();
    assert_eq!(event(&mut socket).await["text"], words);
    assert_eq!(server.post(&format!("{chat}/stop"), json!({})).await.0, 204);
    assert_eq!(
        follow(&mut socket, &words).await.1["message"]["content"],
        words
    );
    assert_eq!(stored(&server, &chat).await, words);

    // A continuation cut off is trimmed by its own words alone.
    generate(&server, &chat, again).await;
    let asked = provider.next().await;
    asked
        .answer
        .send([says(whole), ends("stop")].concat())
        .unwrap();
    follow(&mut socket, "").await;
    generate(&server, &chat, json!({ "continue": true })).await;
    let asked = provider.next().await;
    let more = " The wind is cold and the waves are high. Then she";
    asked
        .answer
        .send([says(more), ends("length")].concat())
        .unwrap();
    let kept = format!("{whole}\n\nThe wind is cold and the waves are high.");
    assert_eq!(
        follow(&mut socket, whole).await.1["message"]["content"],
        kept
    );
    assert_eq!(stored(&server, &chat).await, kept);

    // One with no end of its own stays as it came, the whole sentences before it untouched.
    generate(&server, &chat, json!({ "continue": true })).await;
    let asked = provider.next().await;
    asked
        .answer
        .send([says(" Then she"), ends("length")].concat())
        .unwrap();
    let longer = format!("{kept}\n\nThen she");
    assert_eq!(
        follow(&mut socket, &kept).await.1["message"]["content"],
        longer
    );
    assert_eq!(stored(&server, &chat).await, longer);
}

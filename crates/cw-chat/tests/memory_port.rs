//! The memory system proved against the benchmark (build spec A11, tests 1-3),
//! through the hook the server calls (`memory::system()`): the golden file
//! `memory_port/golden.json.gz` (the benchmark's `golden.json`, gzipped) holds
//! three chats (roleplay with away spans, companion, assistant), each helper
//! prompt and its stored reply, the final facts and events, and each question's
//! memory note by words alone (`memory_bm25`) and with the vectors (`memory_hybrid`).
//! The helper is a fake that answers the stored replies; no model is asked.
//! The app's own fields of an entry (`id`, `chat`, `deleted`) are left out of the comparison.

use std::io::Read;

use cw_chat::memory::{self, Ask, Away, Block, Helper, Mode, Said, Vectors};
use futures_util::future::BoxFuture;
use serde_json::Value;

fn golden() -> Value {
    let file = std::fs::File::open(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/memory_port/golden.json.gz"
    ))
    .expect("the golden file is there");
    let mut text = String::new();
    flate2::read::GzDecoder::new(file)
        .read_to_string(&mut text)
        .expect("the golden file reads");
    serde_json::from_str(&text).expect("the golden file is JSON")
}

/// Answers the stored reply once its prompt is the one the benchmark sent.
struct Stored<'a> {
    prompt: &'a str,
    reply: &'a str,
    which: String,
}

impl Helper for Stored<'_> {
    fn ask<'a>(&'a self, prompt: &'a str) -> BoxFuture<'a, anyhow::Result<String>> {
        assert!(
            prompt == self.prompt,
            "{}: the prompt differs\n--- built\n{prompt}\n--- sent\n{}",
            self.which,
            self.prompt
        );
        Box::pin(async move { Ok(self.reply.to_string()) })
    }
}

fn of<T: serde::de::DeserializeOwned>(value: &Value) -> T {
    serde_json::from_value(value.clone()).expect("the golden file's value reads")
}

/// The entries without the app's own fields.
fn bare(entries: &Value) -> Value {
    let mut entries = entries.clone();
    for entry in entries.as_array_mut().expect("a list") {
        let entry = entry.as_object_mut().expect("an entry");
        for own in ["id", "chat", "deleted"] {
            entry.remove(own);
        }
    }
    entries
}

fn vectors(chat: &Value) -> Vectors {
    use base64::Engine;
    chat["vectors"]
        .as_object()
        .expect("vectors")
        .iter()
        .map(|(text, coded)| {
            let bytes = base64::engine::general_purpose::STANDARD
                .decode(coded.as_str().expect("base64"))
                .expect("base64 reads");
            let vector = bytes
                .as_chunks::<4>()
                .0
                .iter()
                .map(|b| f32::from_le_bytes(*b))
                .collect();
            (text.clone(), vector)
        })
        .collect()
}

#[tokio::test]
async fn the_memory_reads_and_tells_the_golden_chats_as_the_benchmark_did() {
    let golden = golden();
    let system = memory::system();
    for chat in golden["chats"].as_array().expect("chats") {
        let id = chat["id"].as_str().expect("an id");
        let messages: Vec<Said> = of(&chat["messages"]);
        let mode: Mode = of(&chat["mode"]);
        let mut state = String::new();
        // Test 1: every prompt, block by block, as the benchmark sent it.
        for (at, stored) in chat["blocks"]
            .as_array()
            .expect("blocks")
            .iter()
            .enumerate()
        {
            let block = Block {
                messages: messages[at * memory::BLOCK..(at + 1) * memory::BLOCK].to_vec(),
                user: of(&chat["user"]),
                cast: of(&chat["cast"]),
                mode,
                absent: of::<Vec<Away>>(&chat["absent"]),
                chat_id: None,
            };
            let helper = Stored {
                prompt: stored["prompt"].as_str().expect("a prompt"),
                reply: stored["reply"].as_str().expect("a reply"),
                which: format!("{id} block {at}"),
            };
            state = system
                .add(&state, &block, &helper)
                .await
                .expect("the block is read")
                .state;
        }
        // Test 2: the facts and events after the last block.
        let kept: Value = serde_json::from_str(&state).expect("the state is JSON");
        assert_eq!(bare(&kept["facts"]), chat["facts_final"], "{id}: the facts");
        assert_eq!(
            bare(&kept["events"]),
            chat["events_final"],
            "{id}: the events"
        );
        // Test 3: every question's note, by words alone and with the vectors.
        let vectors = vectors(chat);
        for (at, question) in chat["questions"]
            .as_array()
            .expect("questions")
            .iter()
            .enumerate()
        {
            let ask = Ask {
                query: of(&question["query"]),
                prev: None,
                speaker: of(&question["speaker"]),
                mode: of(&question["mode"]),
                today: of(&question["today"]),
                budget: memory::BUDGET,
            };
            let by_words = system
                .render(&state, &ask, None)
                .expect("the note is written");
            assert_eq!(
                by_words,
                question["memory_bm25"].as_str().expect("a note"),
                "{id} question {at}: by words"
            );
            let hybrid = system
                .render(&state, &ask, Some(&vectors))
                .expect("the note is written");
            assert_eq!(
                hybrid,
                question["memory_hybrid"].as_str().expect("a note"),
                "{id} question {at}: hybrid"
            );
        }
    }
}

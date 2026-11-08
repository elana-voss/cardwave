//! Model roles: the worker model (the background model), which does the
//! app's own work (tags, loglines, library titles, memory, query expansion)
//! beside the chat model, at the provider it was picked at. No test asks a
//! provider.
//!
//! `values` is what first run sends, `worker` the worker model as stored, and
//! `work` the provider the work is asked of. A preset put in use leaves it
//! where it is.

mod common;

use common::Scratch;
use cw_provider::presets;
use cw_provider::{self as provider, Provider, Sampling, SetProvider};
use serde_json::{Value, json};

const RIG: &str = "https://rig.example.test/v1";
const OTHER: &str = "https://other.example.test/v1";

/// The chat model `big-1` at `at`, with what `more` says beside it.
fn values(at: &str, more: Value) -> SetProvider {
    let mut all = json!({ "base_url": at, "model": "big-1" });
    all.as_object_mut()
        .unwrap()
        .extend(more.as_object().unwrap().clone());
    serde_json::from_value(all).unwrap()
}

fn set(scratch: &Scratch, at: &str, more: Value) {
    provider::set(&scratch.db, scratch.user, values(at, more)).unwrap();
}

fn worker(scratch: &Scratch) -> Option<String> {
    let stored = provider::stored(&scratch.db, scratch.user).unwrap();
    stored.and_then(|(_, worker)| worker)
}

fn work(scratch: &Scratch) -> Provider {
    provider::for_work(&scratch.db, scratch.user)
        .unwrap()
        .expect("no provider is stored")
}

#[test]
fn the_work_is_asked_of_the_worker_model_or_of_the_chat_model_where_none_is_set() {
    let scratch = Scratch::new();
    // Without a provider there is nothing to ask.
    assert!(
        provider::for_work(&scratch.db, scratch.user)
            .unwrap()
            .is_none()
    );

    // Without a worker model the chat model does the work, at its address and
    // with its key, sent nothing of the values for a reply but the context.
    let sampling = json!({ "sampling": { "temperature": 1.3, "context_size": 8192, "max_response_length": 300 } });
    let mut first = sampling.clone();
    first["api_key"] = json!("sk-rig");
    set(&scratch, RIG, first);
    assert_eq!(worker(&scratch), None);
    let only_context = Sampling {
        context_size: Some(8192),
        ..Sampling::default()
    };
    assert_eq!(
        work(&scratch),
        Provider {
            base_url: RIG.into(),
            api_key: "sk-rig".into(),
            model: "big-1".into(),
            sampling: only_context.clone(),
            name: String::new(),
            thinking_off: None,
            reply_limit: None,
            seen_thinking: false,
        }
    );

    // A worker model is kept without the space around it and does the work.
    set(&scratch, RIG, json!({ "worker_model": "  small-1\n" }));
    assert_eq!(worker(&scratch).as_deref(), Some("small-1"));
    assert_eq!(work(&scratch).model, "small-1");
    assert_eq!(work(&scratch).api_key, "sk-rig");
    // Left out, it stays, whatever else is set.
    set(
        &scratch,
        RIG,
        json!({ "model": "big-2", "api_key": "sk-new" }),
    );
    assert_eq!(worker(&scratch).as_deref(), Some("small-1"));
    assert_eq!(
        provider::get(&scratch.db, scratch.user)
            .unwrap()
            .unwrap()
            .model,
        "big-2"
    );
    // Empty takes it off: the chat model does the work again.
    set(&scratch, RIG, json!({ "worker_model": " " }));
    assert_eq!(worker(&scratch), None);
    assert_eq!(work(&scratch).model, "big-1");

    // The chat model at another provider leaves the worker model at its own.
    set(&scratch, RIG, json!({ "worker_model": "small-1" }));
    set(&scratch, OTHER, json!({}));
    assert_eq!(worker(&scratch).as_deref(), Some("small-1"));
    assert_eq!(work(&scratch).base_url, RIG);
    // One given with another address is that address's.
    set(&scratch, OTHER, json!({ "worker_model": "small-2" }));
    assert_eq!(worker(&scratch).as_deref(), Some("small-2"));
    assert_eq!(work(&scratch).base_url, OTHER);
    // The chat model named as the worker model is none: the chat model does
    // the work, whichever it is later.
    set(&scratch, OTHER, json!({ "worker_model": "big-1" }));
    assert_eq!(worker(&scratch), None);
}

#[test]
fn a_preset_put_in_use_and_its_undo_leave_the_worker_model_where_it_is() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    set(&scratch, OTHER, json!({}));
    let there = presets::create(db, user, "There").unwrap();
    set(&scratch, RIG, json!({ "worker_model": "small-1" }));

    let used = presets::put_in_use(db, user, there.id).unwrap();
    assert_eq!(used.provider.base_url, OTHER);
    assert_eq!(worker(&scratch).as_deref(), Some("small-1"));
    assert_eq!(work(&scratch).base_url, RIG);
    // Its Undo puts back the chat model; the worker model stays.
    let back = presets::put_in_use(db, user, used.before.unwrap()).unwrap();
    assert_eq!(back.provider.base_url, RIG);
    assert_eq!(work(&scratch).model, "small-1");
}

//! Model presets, a test per behaviour: a name, in use, put in use with its
//! Undo, renamed or given anew, copied, deleted and the user's alone, and over
//! HTTP with the pages told. A provider's new key reaching its presets is in
//! `provider_list.rs`. `store` stores a chat model as first run does,
//! `preset` stores one and keeps it under a name, `stored` is the chat model
//! with its key, which no list tells, `replaced` counts the rows kept for an
//! Undo. `RIG` is an address the list of providers has not.

mod common;

use common::Scratch;
use common::server::{event, start};
use cw_accounts::users;
use cw_core::NotFound;
use cw_provider::NAME_LIMIT;
use cw_provider::kinds::{self, Kind, PickModel};
use cw_provider::presets::{self, PresetView};
use cw_provider::{self as provider, Provider};
use reqwest::Method;
use serde_json::{Value, json};

const OPENROUTER: &str = "https://openrouter.ai/api/v1";
const KOBOLD: &str = "http://127.0.0.1:5001/v1";
const RIG: &str = "https://rig.example.test/v1";

/// Stores the chat model `model` at `at` for `user`, with what `more` says beside it.
fn store(scratch: &Scratch, user: i64, at: &str, model: &str, more: Value) {
    let mut all = json!({ "base_url": at, "model": model });
    let more = more.as_object().unwrap().clone();
    all.as_object_mut().unwrap().extend(more);
    let holds = serde_json::from_value(all).unwrap();
    provider::set(&scratch.db, user, holds).unwrap();
}

fn preset(scratch: &Scratch, name: &str, at: &str, model: &str, more: Value) -> PresetView {
    store(scratch, scratch.user, at, model, more);
    presets::create(&scratch.db, scratch.user, name).unwrap()
}

fn names(scratch: &Scratch) -> Vec<String> {
    let listed = presets::list(&scratch.db, scratch.user).unwrap();
    listed.into_iter().map(|preset| preset.name).collect()
}

fn shown(scratch: &Scratch, id: i64) -> PresetView {
    let listed = presets::list(&scratch.db, scratch.user).unwrap();
    let found = listed.into_iter().find(|preset| preset.id == id);
    found.expect("the preset is not listed")
}

fn stored(scratch: &Scratch) -> Provider {
    let stored = provider::get(&scratch.db, scratch.user).unwrap();
    stored.expect("no provider is stored")
}

fn replaced(scratch: &Scratch) -> i64 {
    let count = "select count(*) from presets where replaced = 1";
    let db = &scratch.db;
    db.with(|conn| conn.query_row(count, [], |r| r.get(0)))
        .unwrap()
}

fn missing(error: anyhow::Error) -> bool {
    error
        .downcast_ref::<NotFound>()
        .is_some_and(|what| what.0 == "preset")
}

#[test]
fn a_preset_has_a_name_that_no_other_of_the_users_has() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    // Without a chat model there is nothing to keep.
    assert!(presets::create(db, user, "Early").is_err());
    let made = preset(&scratch, "  Night shift \n", RIG, "tide-1", json!({}));
    assert_eq!(made.name, "Night shift");

    let longest = "n".repeat(NAME_LIMIT);
    for (wrong, why) in [
        (" \t ", "needs a name"),
        (&format!("{longest}n"), "at most 60 characters"),
        ("two\u{7}tone", "cannot have"),
        (" Night shift ", "another preset is called “Night shift”"),
    ] {
        let refused = presets::create(db, user, wrong).unwrap_err();
        assert!(refused.to_string().contains(why), "{wrong:?}: {refused}");
    }
    // The limit is counted in characters, and a name is another where it is written otherwise.
    presets::create(db, user, &"é".repeat(NAME_LIMIT)).unwrap();
    presets::create(db, user, "night shift").unwrap();
    assert_eq!(names(&scratch).len(), 3);
    // Another user's presets are that user's: the name is free there.
    let other = users::create(db, "sam").unwrap();
    store(&scratch, other, RIG, "tide-1", json!({}));
    presets::create(db, other, "Night shift").unwrap();
    assert_eq!(presets::list(db, other).unwrap().len(), 1);
}

#[test]
fn the_list_is_in_the_order_of_the_names_and_says_whose_api_a_preset_asks() {
    let scratch = Scratch::new();
    preset(&scratch, "beta", OPENROUTER, "tide-1", json!({}));
    preset(
        &scratch,
        "Alpha",
        RIG,
        "tide-2",
        json!({ "name": "The rig" }),
    );
    let ported = "http://rig.example.test:8080/v1";
    preset(&scratch, "delta", ported, "tide-3", json!({}));
    preset(
        &scratch,
        "Epsilon",
        "http://LOCALHOST:5001/v1",
        "tide-4",
        json!({}),
    );
    preset(
        &scratch,
        "Zeta",
        KOBOLD,
        "tide-5",
        json!({ "name": "Attic" }),
    );

    let listed = presets::list(&scratch.db, scratch.user).unwrap();
    let told: Vec<_> = listed
        .iter()
        .map(|preset| (&*preset.name, &*preset.provider))
        .collect();
    assert_eq!(
        told,
        [
            ("Alpha", "The rig"),
            ("beta", "OpenRouter"),
            ("delta", "rig.example.test:8080"),
            ("Epsilon", "KoboldCpp"),
            ("Zeta", "Attic"),
        ]
    );
}

#[test]
fn a_preset_is_in_use_while_the_stored_provider_is_what_it_holds() {
    let scratch = Scratch::new();
    let all =
        json!({ "api_key": "sk-rig-0000", "name": "The rig", "sampling": { "temperature": 0.7 } });
    let made = preset(&scratch, "Rig", RIG, "tide-1", all);
    assert!(made.in_use);
    let set = |at: &str, model: &str, more: Value| {
        store(&scratch, scratch.user, at, model, more);
        shown(&scratch, made.id).in_use
    };
    assert!(!set(RIG, "tide-2", json!({})));
    assert!(!set(OPENROUTER, "tide-1", json!({})));
    assert!(!set(RIG, "tide-1", json!({ "api_key": "sk-rig-1111" })));
    assert!(set(RIG, "tide-1", json!({ "api_key": "sk-rig-0000" })));
    // What the provider is called is no part of what the preset holds.
    assert!(set(RIG, "tide-1", json!({ "name": "Rig two" })));
    let warmer = json!({ "sampling": { "temperature": 0.8 } });
    assert!(!set(RIG, "tide-1", warmer));
    assert!(!set(&format!("{RIG}/x"), "tide-1", json!({})));
    let back = json!({ "api_key": "sk-rig-0000", "sampling": { "temperature": 0.7 } });
    assert!(set(RIG, "tide-1", back));
    // A copy holds the same, and so is in use with it.
    assert!(
        presets::duplicate(&scratch.db, scratch.user, made.id, "copy")
            .unwrap()
            .in_use
    );
}

#[test]
fn a_preset_put_in_use_is_the_stored_provider_and_the_one_before_is_kept_once() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let all = json!({ "api_key": " sk-or-v1-1111 \n", "name": " Router ", "sampling": { "temperature": 0.7, "seed": 3 } });
    let first = preset(
        &scratch,
        "First",
        &format!(" {OPENROUTER}/ "),
        " tide-1 ",
        all,
    );
    let second = preset(&scratch, "Second", KOBOLD, "tide-2", json!({}));
    let own = json!({ "api_key": "sk-own-0000", "name": "Mine", "sampling": { "top_p": 0.9 } });
    store(&scratch, user, RIG, "tide-own", own);
    let before = stored(&scratch);
    assert_eq!(replaced(&scratch), 0);

    // In use, the preset is what is stored, its key, name and values with it,
    // and what was stored is kept under a number.
    let used = presets::put_in_use(db, user, first.id).unwrap();
    let held = &used.provider;
    assert_eq!(stored(&scratch), *held);
    assert_eq!(
        (&*held.base_url, &*held.api_key, &*held.model, &*held.name),
        (OPENROUTER, "sk-or-v1-1111", "tide-1", "Router")
    );
    let values = (
        held.sampling.temperature,
        held.sampling.seed,
        held.sampling.top_p,
    );
    assert_eq!(values, (Some(0.7), Some(3), None));
    assert!(shown(&scratch, first.id).in_use);
    let kept = used.before.expect("what was stored is kept");
    // On no list, and neither changed, copied nor deleted as a preset is.
    assert_eq!(names(&scratch), ["First", "Second"]);
    assert!(missing(
        presets::change(db, user, kept, Some("Kept"), true).unwrap_err()
    ));
    assert!(missing(
        presets::duplicate(db, user, kept, "copy").unwrap_err()
    ));
    assert!(missing(presets::delete(db, user, kept).unwrap_err()));
    assert_eq!(replaced(&scratch), 1);

    // Put in use in its turn, it takes that back, key and all, and the preset's values are kept for it.
    let undone = presets::put_in_use(db, user, kept).unwrap();
    assert_eq!(stored(&scratch), before);
    assert_eq!(replaced(&scratch), 1);
    let redo = undone.before.expect("what was stored is kept");
    assert!(missing(presets::put_in_use(db, user, kept).unwrap_err()));
    assert_eq!(
        presets::put_in_use(db, user, redo).unwrap().provider,
        used.provider
    );

    // One is kept: the next preset used lets the one before go.
    let next = presets::put_in_use(db, user, second.id).unwrap();
    assert_eq!(replaced(&scratch), 1);
    // The provider stored otherwise stands in that place, and nothing is kept behind it.
    store(&scratch, user, KOBOLD, "tide-3", json!({}));
    assert_eq!(replaced(&scratch), 0);
    let gone = next.before.unwrap();
    assert!(missing(presets::put_in_use(db, user, gone).unwrap_err()));

    // A chat model picked in Settings › Models lets the one kept go too.
    presets::put_in_use(db, user, second.id).unwrap();
    assert_eq!(replaced(&scratch), 1);
    let at = kinds::picked(db, user, Kind::Chat).unwrap().unwrap().entry;
    let picked = PickModel {
        provider_id: at,
        model: "tide-5".into(),
    };
    kinds::pick(db, user, Kind::Chat, picked).unwrap();
    assert_eq!(replaced(&scratch), 0);
}

#[test]
fn a_preset_is_renamed_or_given_the_values_in_use_and_a_change_refused_changes_nothing() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let first = preset(
        &scratch,
        "First",
        RIG,
        "tide-1",
        json!({ "api_key": "sk-first-0000" }),
    );
    preset(&scratch, "Second", OPENROUTER, "tide-2", json!({}));

    // A name alone: what it holds stays; its own name again is no other preset's.
    let renamed = presets::change(db, user, first.id, Some("  Primary "), false).unwrap();
    let told = (&*renamed.name, &*renamed.provider, &*renamed.model);
    assert_eq!(told, ("Primary", "rig.example.test", "tide-1"));
    assert!(presets::change(db, user, first.id, Some("Primary"), false).is_ok());

    // The values in use alone: the name stays, and all it held goes, its key too.
    store(
        &scratch,
        user,
        OPENROUTER,
        "tide-9",
        json!({ "sampling": { "temperature": 1.5 } }),
    );
    let moved = presets::change(db, user, first.id, None, true).unwrap();
    let told = (
        &*moved.name,
        &*moved.provider,
        &*moved.model,
        moved.temperature,
    );
    assert_eq!(told, ("Primary", "OpenRouter", "tide-9", Some(1.5)));
    let held = presets::put_in_use(db, user, first.id).unwrap().provider;
    assert_eq!((&*held.base_url, &*held.api_key), (OPENROUTER, ""));

    // Refused as a whole: a name that is another's, a name that is none.
    let taken = presets::change(db, user, first.id, Some("Second"), true).unwrap_err();
    assert!(
        taken
            .to_string()
            .contains("another preset is called “Second”")
    );
    assert!(presets::change(db, user, first.id, Some(" "), true).is_err());
    let still = shown(&scratch, first.id);
    assert_eq!((&*still.name, &*still.model), ("Primary", "tide-9"));
}

#[test]
fn a_copy_has_a_name_of_its_own_and_all_the_preset_holds() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let all =
        json!({ "api_key": "sk-rig-0000", "name": "The rig", "sampling": { "temperature": 0.7 } });
    let made = preset(&scratch, "Rig", RIG, "tide-1", all);
    let copy = presets::duplicate(db, user, made.id, "copy").unwrap();
    let told = (&*copy.name, &*copy.provider, &*copy.model, copy.temperature);
    assert_eq!(told, ("Rig (copy)", "The rig", "tide-1", Some(0.7)));
    presets::duplicate(db, user, made.id, "copy").unwrap();
    presets::duplicate(db, user, copy.id, "copy").unwrap();
    // The list goes by name, where a space comes before ")".
    assert_eq!(
        names(&scratch),
        ["Rig", "Rig (copy 2)", "Rig (copy)", "Rig (copy) (copy)"]
    );
    // The key goes along, which the list does not tell.
    let held = presets::put_in_use(db, user, copy.id).unwrap().provider;
    assert_eq!((&*held.api_key, &*held.name), ("sk-rig-0000", "The rig"));

    // A name with no room for " (copy)" loses its end, and a space the cut leaves.
    let long = format!("{} tails", "n".repeat(NAME_LIMIT - 8));
    let longest = preset(&scratch, &long, RIG, "tide-1", json!({}));
    let cut = presets::duplicate(db, user, longest.id, "copy")
        .unwrap()
        .name;
    assert_eq!(cut, format!("{} (copy)", "n".repeat(NAME_LIMIT - 8)));
    let again = presets::duplicate(db, user, longest.id, "copy")
        .unwrap()
        .name;
    assert_eq!(again, format!("{} (copy 2)", "n".repeat(NAME_LIMIT - 9)));
}

#[test]
fn a_preset_is_deleted_for_good_and_is_its_users_alone() {
    let scratch = Scratch::new();
    let (db, user) = (&scratch.db, scratch.user);
    let other = users::create(db, "sam").unwrap();
    let made = preset(
        &scratch,
        "Mine",
        RIG,
        "tide-1",
        json!({ "api_key": "sk-mine-0000" }),
    );
    store(&scratch, other, KOBOLD, "tide-sam", json!({}));
    presets::create(db, other, "Sam's").unwrap();

    assert!(missing(
        presets::change(db, other, made.id, Some("Taken"), false).unwrap_err()
    ));
    assert!(missing(
        presets::duplicate(db, other, made.id, "copy").unwrap_err()
    ));
    assert!(missing(presets::delete(db, other, made.id).unwrap_err()));
    assert!(missing(
        presets::put_in_use(db, other, made.id).unwrap_err()
    ));
    let sams = provider::get(db, other).unwrap().unwrap();
    assert_eq!((&*sams.model, &*sams.api_key), ("tide-sam", ""));

    // What one user's provider lets go is that user's: the other's Undo stays.
    let sam = presets::list(db, other).unwrap()[0].id;
    let undo = presets::put_in_use(db, other, sam).unwrap().before.unwrap();
    presets::put_in_use(db, user, made.id).unwrap();
    assert_eq!(replaced(&scratch), 2);
    store(&scratch, user, RIG, "tide-2", json!({}));
    assert_eq!(replaced(&scratch), 1);
    assert!(presets::put_in_use(db, other, undo).is_ok());

    // Deleted, a preset is gone for good, and deleting it again finds none.
    presets::delete(db, user, made.id).unwrap();
    assert!(names(&scratch).is_empty());
    assert!(missing(presets::delete(db, user, made.id).unwrap_err()));
}

#[tokio::test]
async fn presets_over_http_tell_every_page_of_a_change_and_no_answer_tells_a_key() {
    let server = start().await;
    let early = server.post("/api/presets", json!({ "name": "Rig" })).await;
    assert_eq!(
        early.0, 424,
        "without a chat model there is nothing to keep"
    );
    let rig = json!({ "base_url": RIG, "model": "tide-1", "api_key": "sk-rig-secret-0000", "sampling": { "temperature": 0.7 } });
    assert_eq!(server.set_provider(rig).await.0, 200);
    let mut socket = server.listen().await;
    let (presets, provider) = (json!({ "type": "presets" }), json!({ "type": "provider" }));

    let (status, made) = server
        .post("/api/presets", json!({ "name": " Rig " }))
        .await;
    let line = json!({ "id": made["id"], "name": "Rig", "provider": "rig.example.test", "model": "tide-1", "temperature": 0.7, "in_use": true });
    assert_eq!((status, &made), (201, &line));
    let path = format!("/api/presets/{}", made["id"]);
    // Refused, which tells nothing: a name that is taken, a preset that is not there.
    let (status, why) = server.post("/api/presets", json!({ "name": "Rig" })).await;
    let taken = json!("another preset is called “Rig”");
    assert_eq!((status, &why["error"]), (400, &taken));
    for (method, end) in [
        (Method::PATCH, ""),
        (Method::POST, "/duplicate"),
        (Method::POST, "/use"),
        (Method::DELETE, ""),
    ] {
        let body = (method != Method::DELETE).then(|| json!({ "name": "Other", "copy": "copy" }));
        let path = format!("/api/presets/999{end}");
        assert_eq!(server.call(method, &path, body).await.0, 404, "{end}");
    }
    // Renamed, copied, the copy deleted.
    let (status, changed) = server.patch(&path, json!({ "name": "Rig two" })).await;
    assert_eq!((status, &changed["name"]), (200, &json!("Rig two")));
    let (status, copy) = server
        .post(&format!("{path}/duplicate"), json!({ "copy": "Kopie" }))
        .await;
    assert_eq!((status, &copy["name"]), (201, &json!("Rig two (Kopie)")));
    let copied = format!("/api/presets/{}", copy["id"]);
    assert_eq!(server.call(Method::DELETE, &copied, None).await.0, 204);
    for _ in 0..4 {
        assert_eq!(event(&mut socket).await, presets);
    }

    // Put in use: the provider as the settings show it, and the number that
    // takes back what was in use; each stores the provider.
    let (status, used) = server.post(&format!("{path}/use"), json!({})).await;
    assert_eq!(status, 200, "{used}");
    assert_eq!(used["provider"], server.get("/api/provider").await.1);
    assert_eq!(event(&mut socket).await, provider);
    let undo = format!("/api/presets/{}/use", used["before"]);
    let (status, undone) = server.post(&undo, json!({})).await;
    assert_eq!(status, 200, "{undone}");
    assert_eq!(event(&mut socket).await, provider);
    let listed = server.get("/api/presets").await.1;
    for answer in [&made, &used, &undone, &changed, &copy, &listed] {
        assert!(!answer.to_string().contains("secret"), "{answer}");
    }

    // A second server started on the same data folder leaves what a preset
    // took the place of; the server's end does not.
    drop(cardwave_server::router(server.options()).unwrap());
    let redo = format!("/api/presets/{}/use", undone["before"]);
    let (status, again) = server.post(&redo, json!({})).await;
    assert_eq!(status, 200, "{again}");
    let server = server.restart().await;
    let redo = format!("/api/presets/{}/use", again["before"]);
    assert_eq!(server.post(&redo, json!({})).await.0, 404);
}

#[test]
fn a_key_typed_in_first_run_at_the_same_address_goes_to_its_presets_too() {
    let scratch = Scratch::new();
    let old = json!({ "api_key": "sk-rig-old-0123" });
    let kept = preset(&scratch, "Rig", RIG, "tide-1", old);
    let new = json!({ "api_key": "sk-rig-new-0123" });
    store(&scratch, scratch.user, RIG, "tide-2", new);
    assert_eq!(stored(&scratch).api_key, "sk-rig-new-0123");

    let used = presets::put_in_use(&scratch.db, scratch.user, kept.id).unwrap();
    assert_eq!(used.provider.api_key, "sk-rig-new-0123");
}

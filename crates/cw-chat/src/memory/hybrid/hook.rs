//! `HybridFixed`: the system of `hybrid.rs` behind the memory's hook
//! (`memory::Remembers`), its state the JSON of `State` (empty before the
//! first block). It reads and adds to the state without what the user deleted
//! (`State::live`), and a block read carries the deleted entries on, flagged,
//! so their Undo puts them back in every state until the server restarts.

use anyhow::Context;
use cw_core::{Code, Fail};
use futures_util::future::BoxFuture;

use crate::memory::hybrid::{Event, Fact, KnownTo, State};
use crate::memory::{
    Added, Ask, Block, Change, Entry, Helper, Kind, Remembers, Vectors, word_renamed,
};

/// A fact's subject (lower-case, `+` between the names of a relationship, in
/// order) with the name `from` called `to`. "user", the user, is never a name
/// renamed: the stand-in's mark (`memory::kept_form`) is not one either.
fn subject_renamed(subject: &str, from: &str, to: &str) -> String {
    let mut parts: Vec<&str> = subject
        .split('+')
        .map(|part| match part == from && part != "user" {
            true => to,
            false => part,
        })
        .collect();
    if parts.len() > 1 {
        parts.sort_unstable();
    }
    parts.join("+")
}

/// The benchmark's winner: facts-and-events-hybrid-fixed.
pub(crate) struct HybridFixed;

fn parse(state: &str) -> anyhow::Result<State> {
    match state.is_empty() {
        true => Ok(State::default()),
        false => serde_json::from_str(state)
            .context(Fail::said(Code::Internal, "a memory's state does not read")),
    }
}

fn known(to: &KnownTo) -> Option<Vec<String>> {
    match to {
        KnownTo::Everyone => None,
        KnownTo::Names(names) => Some(names.clone()),
    }
}

fn of_fact(f: &Fact) -> Entry {
    Entry {
        id: f.id,
        kind: Kind::Fact,
        text: f.text.clone(),
        status: Some(f.status.clone()),
        until: f.until.clone(),
        world: f.scope == "world",
        known_to: known(&f.known_to),
        chat: f.chat,
        n: f.n,
    }
}

fn of_event(e: &Event) -> Entry {
    Entry {
        id: e.id,
        kind: Kind::Event,
        text: e.text.clone(),
        status: None,
        until: String::new(),
        world: e.scope == "world",
        known_to: known(&e.known_to),
        chat: e.chat,
        n: e.n,
    }
}

/// Applies `change` to one entry's text, who know it and its deletion.
fn changed(text: &mut String, known_to: &mut KnownTo, deleted: &mut bool, change: &Change) {
    if let Some(new) = &change.text {
        new.clone_into(text);
    }
    if let Some(names) = &change.known_to {
        *known_to = KnownTo::Names(names.clone());
    }
    if let Some(gone) = change.deleted {
        *deleted = gone;
    }
}

impl Remembers for HybridFixed {
    fn add<'a>(
        &'a self,
        state: &'a str,
        block: &'a Block,
        helper: &'a dyn Helper,
    ) -> BoxFuture<'a, anyhow::Result<Added>> {
        Box::pin(async move {
            let had = parse(state)?;
            let mut state = had.live();
            let reply = helper.ask(&state.prompt(block)).await?;
            let saved = state.apply(block, &reply);
            state
                .facts
                .extend(had.facts.into_iter().filter(|f| f.deleted));
            state
                .events
                .extend(had.events.into_iter().filter(|e| e.deleted));
            Ok(Added {
                state: serde_json::to_string(&state)?,
                saved,
            })
        })
    }

    fn render(&self, state: &str, ask: &Ask, vectors: Option<&Vectors>) -> anyhow::Result<String> {
        Ok(parse(state)?.live().render(ask, vectors))
    }

    fn texts(&self, state: &str) -> anyhow::Result<Vec<String>> {
        Ok(parse(state)?.live().texts())
    }

    fn entries(&self, state: &str) -> anyhow::Result<Vec<Entry>> {
        let state = parse(state)?.live();
        let facts = state.facts.iter().map(of_fact);
        Ok(facts.chain(state.events.iter().map(of_event)).collect())
    }

    fn change(&self, state: &str, id: u64, change: &Change) -> anyhow::Result<Option<String>> {
        let mut state = parse(state)?;
        if let Some(f) = state.facts.iter_mut().find(|f| f.id == id) {
            changed(&mut f.text, &mut f.known_to, &mut f.deleted, change);
        } else if let Some(e) = state.events.iter_mut().find(|e| e.id == id) {
            changed(&mut e.text, &mut e.known_to, &mut e.deleted, change);
        } else {
            return Ok(None);
        }
        Ok(Some(serde_json::to_string(&state)?))
    }

    fn without(&self, state: &str, chats: &[i64]) -> anyhow::Result<String> {
        if chats.is_empty() || state.is_empty() {
            return Ok(state.to_string());
        }
        let mut state = parse(state)?;
        let gone = |chat: &Option<i64>| chat.is_some_and(|chat| chats.contains(&chat));
        state.facts.retain(|f| !gone(&f.chat));
        state.events.retain(|e| !gone(&e.chat));
        Ok(serde_json::to_string(&state)?)
    }

    fn renamed(&self, state: &str, from: &str, to: &str) -> anyhow::Result<String> {
        if state.is_empty() || from == to {
            return Ok(state.to_string());
        }
        let mut state = parse(state)?;
        let lower = (from.to_lowercase(), to.to_lowercase());
        let names = |known: &mut KnownTo| {
            if let KnownTo::Names(names) = known {
                for name in names.iter_mut().filter(|name| **name == lower.0) {
                    name.clone_from(&lower.1);
                }
            }
        };
        for f in &mut state.facts {
            f.text = word_renamed(&f.text, from, to);
            names(&mut f.known_to);
            f.subject = subject_renamed(&f.subject, &lower.0, &lower.1);
        }
        for e in &mut state.events {
            e.text = word_renamed(&e.text, from, to);
            names(&mut e.known_to);
        }
        for said in &mut state.prev {
            if said.speaker == from {
                to.clone_into(&mut said.speaker);
            }
            said.text = word_renamed(&said.text, from, to);
        }
        Ok(serde_json::to_string(&state)?)
    }

    fn alone(&self, state: &str, id: u64) -> anyhow::Result<Option<(Entry, String)>> {
        let state = parse(state)?;
        let mut alone = State::default();
        let entry = if let Some(f) = state.facts.into_iter().find(|f| f.id == id) {
            alone.facts.push(f);
            of_fact(&alone.facts[0])
        } else if let Some(e) = state.events.into_iter().find(|e| e.id == id) {
            alone.events.push(e);
            of_event(&alone.events[0])
        } else {
            return Ok(None);
        };
        Ok(Some((entry, serde_json::to_string(&alone)?)))
    }

    fn put(&self, state: &str, alone: &str, replaces: &[String]) -> anyhow::Result<String> {
        let mut state = parse(state)?;
        let alone = parse(alone)?;
        let id = state.next_id;
        state.next_id += 1;
        let again = |text: &String, deleted: bool| !deleted && replaces.contains(text);
        if let Some(mut f) = alone.facts.into_iter().next() {
            let same = |x: &Fact| {
                again(&x.text, x.deleted)
                    || (!x.deleted && x.subject == f.subject && x.key == f.key)
            };
            let at = state
                .facts
                .iter()
                .position(same)
                .unwrap_or(state.facts.len());
            state.facts.retain(|x| !same(x));
            (f.id, f.deleted) = (id, false);
            state.facts.insert(at.min(state.facts.len()), f);
        } else if let Some(mut e) = alone.events.into_iter().next() {
            let same = |x: &Event| again(&x.text, x.deleted);
            let at = state
                .events
                .iter()
                .position(same)
                .unwrap_or(state.events.len());
            state.events.retain(|x| !same(x));
            (e.id, e.deleted) = (id, false);
            state.events.insert(at.min(state.events.len()), e);
        }
        Ok(serde_json::to_string(&state)?)
    }
}

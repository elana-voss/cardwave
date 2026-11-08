//! The Cloud: the same few questions for everyone, and whatever an answer lights
//! up goes next. The queue is folded from the log; `lit` on an entry is what its
//! answer lit, filtered and stored, so a Back replays no call. `None` there means
//! the call is due. The relation comes after the kinds, only where they ask for it.
//! A probed entry lights by its probe's answer. Trap: an item the model lit may name a slot of [`texts::EVERY`], which
//! is then asked twice, as in the source.

use super::{
    Entry, Interview, Models, Planned, dumps, fixed_question, free_question, gender, kind_slots,
    relation_due, relation_question, strings, texts,
};
use super::{GUARD, RESERVE, drop_after};
use cw_provider::form::{self, Question};

const LIT: &str = "lit: ";

/// The item a log's entry asked about.
fn item(entry: &Entry) -> Option<&str> {
    if entry.probe {
        None
    } else if texts::EVERY.contains(&entry.slot.as_str()) {
        Some(&entry.slot)
    } else {
        entry.slot.strip_prefix(LIT)
    }
}

/// An answer here lights what comes next (and can be probed).
pub(crate) fn lights(entry: &Entry) -> bool {
    !entry.probe && (entry.slot == "wanted" || item(entry).is_some())
}

/// What the log says is left, asked and lit. Items leave the queue only at the end:
/// the log is not always in asked order.
struct Fold {
    queue: Vec<String>,
    asked: Vec<String>,
    lit: Vec<String>,
}

fn fold(interview: &Interview) -> Fold {
    let mut queue: Vec<String> = texts::EVERY.iter().map(|item| item.to_string()).collect();
    let (mut asked, mut lit) = (Vec::new(), Vec::new());
    for entry in &interview.log {
        asked.extend(item(entry).map(str::to_string));
        let new = entry.lit.as_deref().unwrap_or_default();
        lit.extend_from_slice(new);
        queue.splice(0..0, new.iter().cloned());
    }
    for item in &asked {
        if let Some(index) = queue.iter().position(|left| left == item) {
            queue.remove(index);
        }
    }
    Fold { queue, asked, lit }
}

/// Makes the calls due, oldest first.
pub(crate) async fn light_due<M: Models>(
    models: &M,
    interview: &mut Interview,
) -> anyhow::Result<()> {
    for index in 0..interview.log.len() {
        let entry = &interview.log[index];
        if !lights(entry) || entry.lit.is_some() {
            continue;
        }
        let probe = format!("{} probe", entry.slot);
        let child = interview.log.iter().find(|e| e.probe && e.slot == probe);
        let said = child.unwrap_or(entry).said().map(str::to_string);
        let question = entry.question.english();
        let new = match said {
            Some(said) => light(models, interview, &question, &said).await?,
            None => Vec::new(),
        };
        interview.log[index].lit = Some(new);
    }
    Ok(())
}

/// One call: at most two new items, and none past the room the limit leaves.
async fn light<M: Models>(
    models: &M,
    interview: &Interview,
    question: &str,
    said: &str,
) -> anyhow::Result<Vec<String>> {
    let Fold { queue, asked, lit } = fold(interview);
    let known = [asked, lit].concat();
    let user = format!(
        "Asked about already: {}\nAnswers so far:\n{}\nLast question: {question}\nLast answer: {said}",
        dumps(&known),
        interview.answers_text()
    );
    let reply = models
        .ask(&Question {
            role: "cloud light",
            system: texts::LIGHT,
            user: &user,
            schema: form::object([("lit", form::list(form::text()))]),
            limit: form::LIMIT,
            temperature: None,
        })
        .await?;
    let lowered: Vec<String> = known.iter().map(|item| item.to_lowercase()).collect();
    let mut new: Vec<String> = strings(&reply["lit"]).into_iter().take(2).collect();
    new = new
        .iter()
        .map(|item| item.trim().to_string())
        .filter(|item| !item.is_empty() && !lowered.contains(&item.to_lowercase()))
        .collect();
    let used = gender::guard_count(&interview.log);
    while !new.is_empty() && used + queue.len() + new.len() > GUARD - RESERVE {
        let dropped = new.pop();
        tracing::info!(?dropped, "the cloud's limit left no room for what lit up");
    }
    Ok(new)
}

/// The next question.
pub(crate) fn plan(interview: &Interview) -> Planned {
    if let Some(item) = fold(interview).queue.first() {
        return next_item(interview, item);
    }
    if !interview.has("kinds") {
        return Planned::Kinds;
    }
    if relation_due(interview) {
        return relation_question();
    }
    let own = kind_slots(&interview.kinds).into_iter();
    let next = own
        .filter(|slot| !interview.has(slot))
        .find_map(fixed_question);
    next.map_or(Planned::Done, Planned::Fixed)
}

fn next_item(interview: &Interview, item: &str) -> Planned {
    if item == "third person" {
        return Planned::Fixed(free_question(item, texts::THIRD));
    }
    let text = texts::SLOT_TEXT.iter().find(|(slot, _)| *slot == item);
    let line = match text {
        Some((_, what)) => format!("Slot to fill: {what}"),
        None => format!("Lit up, to ask about: {item}"),
    };
    let slot = if texts::EVERY.contains(&item) {
        item.to_string()
    } else {
        format!("{LIT}{item}")
    };
    let answers = interview.answers_text();
    Planned::Worded(
        slot,
        format!(
            "{line}
Answers so far:
{answers}"
        ),
    )
}

/// A changed answer lights anew; what the old one lit, and what that lit, goes.
pub(crate) fn clear(interview: &mut Interview, just: usize, old: &Entry) {
    let mut seeds = old.lit.clone().unwrap_or_default();
    if let Some(parent) = old.slot.strip_suffix(" probe").filter(|_| old.probe) {
        let of_parent = |entry: &&mut Entry| !entry.probe && entry.slot == parent;
        if let Some(entry) = interview.log.iter_mut().find(of_parent) {
            seeds = entry.lit.take().unwrap_or_default();
        }
    }
    let mut gone: Vec<String> = Vec::new();
    while let Some(seed) = seeds.pop() {
        let slot = format!("{LIT}{seed}");
        if gone.contains(&slot) {
            continue;
        }
        let later = interview.log[just + 1..].iter();
        let dropped = later.filter(|entry| !entry.probe && entry.slot == slot);
        seeds.extend(dropped.flat_map(|entry| entry.lit.iter().flatten().cloned()));
        gone.push(slot);
    }
    drop_after(interview, just, |entry| {
        !entry.probe && gone.contains(&entry.slot)
    });
}

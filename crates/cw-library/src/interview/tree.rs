//! The Tree: fixed questions in a fixed order, no model words one. The next is
//! the first of [`questions`] not in the log; `clear` asks again what rests on a
//! changed answer: the branches on a changed needs answer, a question whose text
//! changed (the why on a changed wish).

use super::{
    Asking, Entry, Interview, Planned, drop_after, fixed_question, free_question, kind_slots,
    opening, texts,
};
use crate::interview::shown::Text;

/// The questions no probe follows and the Hybrid does not drill: the opening's and the two gender questions.
pub(crate) const OPENING: &[&str] = &[
    "wanted",
    "relation",
    "moments",
    "needs",
    "character",
    "treat",
];

/// Every question after the opening, as the answers so far word it.
fn questions(interview: &Interview) -> Vec<Asking> {
    let needs = interview.answer("needs");
    let picked = needs
        .split("; ")
        .filter(|need| texts::NEEDS.contains(need))
        .take(2);
    let branch = |need: &str| {
        let (_, text, choices) = texts::BRANCH.iter().find(|(name, ..)| *name == need)?;
        Some(Asking {
            choices: choices.iter().map(|choice| choice.to_string()).collect(),
            ..free_question(&format!("branch: {need}"), text)
        })
    };
    let mut plan: Vec<Asking> = picked.filter_map(branch).collect();
    let wish = ["wanted", "needs"].into_iter().find_map(|slot| {
        let entry = interview.log.iter().find(|entry| entry.slot == slot);
        entry.filter(|entry| entry.said().is_some())
    });
    for slot in ["why", "loved", "third person", "moment", "deal", "standing"] {
        plan.extend(match slot {
            "third person" => Some(free_question(slot, texts::THIRD)),
            _ => fixed_question(slot),
        });
    }
    if let Some(why) = plan.iter_mut().find(|asking| asking.slot == "why") {
        why.question = Text::quoting(false, wish);
    }
    let own = kind_slots(&interview.kinds);
    plan.extend(own.into_iter().filter_map(fixed_question));
    plan
}

/// The next question.
pub(crate) fn plan(interview: &Interview) -> Planned {
    if let Some(next) = opening(interview) {
        return next;
    }
    let mut plan = questions(interview).into_iter();
    let next = plan.find(|asking| !interview.has(&asking.slot));
    next.map_or(Planned::Done, Planned::Fixed)
}

/// Drops the branches of the needs no longer picked, after the needs' entry `just`.
pub(crate) fn drop_unpicked_branches(interview: &mut Interview, just: usize) {
    let needs = interview.answer("needs").to_string();
    drop_after(interview, just, |entry| {
        let need = entry.slot.strip_prefix("branch: ");
        need.is_some_and(|need| !needs.split("; ").any(|picked| picked == need))
    });
}

/// Drops what rests on the answer at `just`, changed from `old`.
pub(crate) fn clear(interview: &mut Interview, just: usize, old: &Entry) {
    if old.slot == "needs" {
        drop_after(interview, just, |entry| entry.slot.starts_with("branch: "));
    }
    let plan = questions(interview);
    drop_after(interview, just, |entry| {
        let reworded =
            |asking: &Asking| asking.slot == entry.slot && asking.question != entry.question;
        plan.iter().any(reworded)
    });
}

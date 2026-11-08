//! The Hybrid: the Tree's opening, then a drill over the required slots. The
//! interviewer words each question but the friend's, which comes right after the
//! why; a tagger reads each real answer and says what it fills and touches (asked
//! next) and whether it is vague (the same slot once more, the one probe). All
//! that is folded from the log; a real answer with no `tag` is due. It ends once
//! every required slot is closed and the friend's question asked. Trap: the second
//! try at a vague slot is a plain entry of the same slot, `probe` false, as the
//! source logs it; `Tag::probing` on the entry before tells it.

use super::{
    Entry, Interview, Models, Planned, Tag, drop_after, dumps, free_question, kind_slots, opening,
    strings, texts, tree,
};
use cw_provider::form::{self, Question};
use serde::{Serialize, Serializer};

const THIRD_SLOT: &str = "third person";

/// Where the drill stands, by the log up to the first entry still to be tagged.
#[derive(Default)]
struct Fold {
    closed: Vec<String>,
    touched: Vec<String>,
    /// The last answer was vague: the question being asked is the second try.
    probed: bool,
    third_done: bool,
    used: bool,
    due: Option<usize>,
}

fn drilled(entry: &Entry) -> bool {
    !tree::OPENING.contains(&entry.slot.as_str()) && entry.slot != "kinds"
}

fn slot_text(slot: &str) -> Option<&'static str> {
    let found = texts::SLOT_TEXT.iter().find(|(name, _)| *name == slot);
    found.map(|(_, text)| *text)
}

fn fold(interview: &Interview) -> Fold {
    let mut state = Fold::default();
    for (index, entry) in interview.log.iter().enumerate() {
        if !drilled(entry) {
            continue;
        }
        if entry.slot == THIRD_SLOT {
            state.third_done = true;
            continue;
        }
        if entry.said().is_none() {
            state.closed.push(entry.slot.clone());
            state.probed = false;
            continue;
        }
        let Some(tag) = &entry.tag else {
            state.due = Some(index);
            break;
        };
        if tag.probing {
            (state.probed, state.used) = (true, true);
            continue;
        }
        state.closed.push(entry.slot.clone());
        let filled = tag.fills.iter().filter(|slot| slot_text(slot).is_some());
        state.closed.extend(filled.cloned());
        state.touched.clone_from(&tag.touched);
        state.probed = false;
    }
    let changed = interview.changed.and_then(|index| interview.log.get(index));
    if let Some((entry, tag)) = changed.and_then(|entry| Some((entry, entry.tag.as_ref()?))) {
        state.probed = tag.probing;
        state.touched = if tag.probing {
            vec![entry.slot.clone()]
        } else {
            tag.touched.clone()
        };
    }
    state
}

/// The required slots still open.
fn empty(interview: &Interview, state: &Fold) -> Vec<&'static str> {
    let mut required = vec!["why", "loved", "moment", "deal", "standing"];
    required.extend(kind_slots(&interview.kinds));
    required.retain(|slot| !state.closed.iter().any(|closed| closed == slot));
    required
}

/// The open slots with their texts, a JSON object in the slots' order.
struct OpenSlots<'a>(&'a [&'static str]);

impl Serialize for OpenSlots<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let pair = |slot: &&'static str| (*slot, slot_text(slot).unwrap_or_default());
        serializer.collect_map(self.0.iter().map(pair))
    }
}

/// Tags the answers due, oldest first.
pub(crate) async fn tag_due<M: Models>(
    models: &M,
    interview: &mut Interview,
) -> anyhow::Result<()> {
    loop {
        let state = fold(interview);
        let Some(index) = state.due else {
            return Ok(());
        };
        let open = empty(interview, &state);
        let entry = &interview.log[index];
        let user = format!(
            "Open slots: {}\nQuestion: {}\nAnswer: {}",
            dumps(&OpenSlots(&open)),
            entry.question,
            entry.said().unwrap_or_default()
        );
        let schema = form::object([
            ("fills", form::list(form::text())),
            ("touched", form::list(form::text())),
            ("vague", form::yes_no()),
        ]);
        let reply = models
            .ask(&Question {
                role: "tagger",
                system: texts::TAGGER,
                user: &user,
                schema,
                limit: form::LIMIT,
                temperature: None,
            })
            .await?;
        let entry_slot = interview.log[index].slot.clone();
        let vague = reply["vague"].as_bool().unwrap_or_default();
        let probing = vague && !state.probed && !state.used && entry_slot != "known_character";
        interview.log[index].tag = Some(if probing {
            Tag {
                fills: Vec::new(),
                touched: Vec::new(),
                probing,
            }
        } else {
            Tag {
                fills: strings(&reply["fills"]),
                touched: strings(&reply["touched"]),
                probing,
            }
        });
    }
}

/// Python's `str(list)` of the kinds, as the source's message has it.
fn kinds_repr(kinds: &[String]) -> String {
    let quoted: Vec<String> = kinds.iter().map(|kind| format!("'{kind}'")).collect();
    format!("[{}]", quoted.join(", "))
}

/// The next question.
pub(crate) fn plan(interview: &Interview) -> Planned {
    if let Some(next) = opening(interview) {
        return next;
    }
    let state = fold(interview);
    if state.closed.iter().any(|slot| slot == "why") && !state.third_done {
        return Planned::Fixed(free_question(THIRD_SLOT, texts::THIRD));
    }
    let open = empty(interview, &state);
    let touched = open
        .iter()
        .find(|slot| state.touched.iter().any(|t| t == *slot));
    let Some(slot) = touched.or(open.first()) else {
        return Planned::Done;
    };
    let again = if state.probed { texts::VAGUE_AGAIN } else { "" };
    let user = format!(
        "Slot to fill: {}\nKinds picked: {}\nAnswers so far:\n{}{again}",
        slot_text(slot).unwrap_or_default(),
        kinds_repr(&interview.kinds),
        interview.answers_text()
    );
    Planned::Worded(slot.to_string(), user)
}

/// What the old answer filled or touched is asked anew, and what those led to;
/// after a vague old answer, its second try too.
pub(crate) fn clear(interview: &mut Interview, just: usize, old: &Entry) {
    let tag_seeds = |tag: Option<&Tag>| -> Vec<String> {
        let lists = tag.map(|tag| [tag.fills.clone(), tag.touched.clone()].concat());
        let mut seeds = lists.unwrap_or_default();
        seeds.retain(|slot| slot_text(slot).is_some());
        seeds
    };
    let mut seeds = tag_seeds(old.tag.as_ref());
    if old.tag.as_ref().is_some_and(|tag| tag.probing) {
        seeds.push(old.slot.clone());
    }
    let mut gone: Vec<String> = Vec::new();
    while let Some(slot) = seeds.pop() {
        if gone.contains(&slot) {
            continue;
        }
        let later = interview.log[just + 1..].iter();
        let dropped = later.filter(|entry| entry.slot == slot);
        seeds.extend(dropped.flat_map(|entry| tag_seeds(entry.tag.as_ref())));
        gone.push(slot);
    }
    drop_after(interview, just, |entry| gone.contains(&entry.slot));
}

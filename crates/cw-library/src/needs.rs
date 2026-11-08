//! A card's needs: which of the list of needs (`LIST`, the owner's, each finishing "I need…") the worker
//! model finds a card offers. It names as few as the card warrants, strongest first, each with a quote from the card, which makes it
//! look, then a level, how much the card offers it (2 clearly offered, 3 what it is built for). The quote is
//! kept and not checked against the card; the level and the need's place in the answer (its rank) count (`read`).
//! The prompt is measured word for word as it stands (milestone 120): it is not reworded in passing.
//!
//! The prompt is `describe/needs.txt`, the worker `api/describe.rs`, after a card's description; a card the
//! describer refused is not asked (`cw_store::describe`). A row of `card_needs` per card from its queueing
//! on: queued, asked, refused or failed; no row is not asked yet. The levels are kept whole, and the level
//! from which a need counts (`COUNTS_FROM`) applied at reading; zero needs is an asked card none of whose needs counts. In
//! the app's own data alone: never in a card's export.
//!
//! The Characters page's view "By need" reads `overview`, what its list at the top holds, and lists cards by
//! `strengths`, each card's sum of levels over the needs picked and the best rank among them.

use std::collections::HashMap;
use std::sync::LazyLock;

use cw_core::{Code, Fail};
use cw_prompt::{PromptMessage, Role};
use cw_provider::{Http, Provider, object};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use ts_rs::TS;

use crate::describe;
use crate::failures::Failures;

pub const ASK: &str = include_str!("describe/needs.txt");

/// Each need by the name it is stored under, and how it finishes "I need…". The owner's list and words.
pub const LIST: [(&str, &str); 31] = [
    ("keep_company", "someone to keep me company"),
    ("listen", "someone to listen to me"),
    ("understood", "to be understood"),
    ("accepted", "to be accepted as I am"),
    ("loved", "to be loved"),
    ("desired", "to be desired"),
    ("sex", "sex"),
    ("care_for", "to care for someone"),
    ("looked_after", "to be looked after"),
    ("safe", "to feel safe"),
    ("belong", "to belong somewhere"),
    ("forgiven", "to be forgiven"),
    ("grieve", "to grieve someone"),
    ("admired", "to be admired"),
    ("believed_in", "to be believed in"),
    ("truth", "to be told the truth"),
    ("pushed", "to be pushed to do more"),
    ("get_better", "to get better at something"),
    ("in_control", "to be in control"),
    ("lose_control", "to lose control"),
    ("forbidden", "to do what I am not allowed to"),
    ("learn", "to learn something"),
    ("understand_myself", "to understand myself"),
    ("decide", "to decide what to do"),
    ("purpose", "to have a purpose"),
    ("make", "to make something"),
    ("practise", "to practise for real life"),
    ("thrilled", "to be thrilled"),
    ("laugh_play", "to laugh and play"),
    ("elsewhere", "to be somewhere else for a while"),
    ("say_unsaid", "to say what I never got to say to someone"),
];

/// The level from which a need counts, the same for every need.
pub const COUNTS_FROM: u8 = 2;

/// The list's words alone, as the interview shows them.
pub const WORDS: [&str; 31] = {
    let mut words = [""; 31];
    let mut at = 0;
    while at < 31 {
        words[at] = LIST[at].1;
        at += 1;
    }
    words
};

/// The most of a refusal's reason kept.
const REASON_LIMIT: usize = 300;

/// The prompt with the list filled in.
fn prompt() -> &'static str {
    static PROMPT: LazyLock<String> = LazyLock::new(|| {
        let list: Vec<String> = LIST
            .iter()
            .map(|(name, words)| format!("{name}: I need {words}"))
            .collect();
        ASK.replace("{needs}", &list.join("\n"))
    });
    &PROMPT
}

/// A need the model found a card offers, level above 0, its quote in the card.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, TS)]
#[ts(export)]
pub struct Found {
    pub need: String,
    pub level: u8,
    pub quote: String,
    /// Its place among the needs above 0 in the model's answer, the first 0; strongest first, as it is asked.
    pub rank: u32,
}

/// What came of asking about a card.
#[derive(Debug)]
pub enum Outcome {
    Asked(Vec<Found>),
    /// The verdict "reject", with its reason.
    Refused(String),
}

/// How far a card's needs have come.
#[derive(Clone, Copy, Debug, Serialize, PartialEq, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum NeedsState {
    NotAsked,
    Waiting,
    /// Asked, and at least one need counts.
    Found,
    /// Asked, and none counts: a state of its own, apart from not asked.
    Zero,
    Refused,
    Failed,
}

/// A card's needs as its page gets them: those that count.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct CardNeeds {
    pub state: NeedsState,
    pub needs: Vec<Found>,
}

/// What the view "By need" shows over its cards.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct NeedsOverview {
    /// The needs that count on any card not in the Trash, by name: on most cards first, of as many in the list's
    /// order. The page words them in its language.
    pub needs: Vec<String>,
    /// Each card's needs that count, by name, strongest first: what its tile shows pointed at. A card with none
    /// has no entry.
    #[ts(type = "Partial<Record<number, Array<string>>>")]
    pub by_card: HashMap<i64, Vec<String>>,
    /// How many of those `of` have been asked, however that ended. Under `of`, cards are being read.
    pub read: usize,
    /// The cards not in the Trash that are queued for their needs or were so.
    pub of: usize,
}

/// What asking about a card came to, as it is stored.
pub enum Stored {
    /// The found needs as JSON.
    Asked(String),
    /// "refused" or "failed", with the reason.
    Ended(&'static str, String),
}

/// What a card's needs ask of the database, which `cw_store::needs` gives.
pub trait Storage: Failures {
    /// As [`queue`] says.
    fn queue_needs(&self, user: i64, only: Option<i64>) -> anyhow::Result<usize>;
    /// As [`queue_lacking`] says.
    fn queue_lacking_needs(&self, user: i64) -> anyhow::Result<usize>;
    /// The users with a described card that has no row.
    fn users_lacking_needs(&self) -> anyhow::Result<Vec<i64>>;
    /// As [`next`] says.
    fn next_for_needs(&self, user: i64) -> anyhow::Result<Option<(i64, i64)>>;
    fn keep_needs(&self, card_id: i64, version_id: i64, stored: Stored) -> anyhow::Result<()>;
    /// The card's state as stored and its found needs (JSON), where it has a row.
    fn needs_of(&self, card_id: i64) -> anyhow::Result<Option<(String, String)>>;
    /// The same of each of the user's cards not in the Trash that has a row, with its id.
    fn needs_of_user(&self, user: i64) -> anyhow::Result<Vec<(i64, String, String)>>;
}

/// Queues the user's cards not in the Trash whose needs are not asked or failed, but for one the describer
/// refused; with `only`, of those that one alone. Answers how many were queued.
pub fn queue(db: &dyn Storage, user: i64, only: Option<i64>) -> anyhow::Result<usize> {
    db.queue_needs(user, only)
}

/// Queues the user's described cards whose needs were never queued: those from before the list, each start.
pub fn queue_lacking(db: &dyn Storage, user: i64) -> anyhow::Result<usize> {
    db.queue_lacking_needs(user)
}

pub fn users_lacking(db: &dyn Storage) -> anyhow::Result<Vec<i64>> {
    db.users_lacking_needs()
}

/// The card whose needs the worker asks next, with its newest version. One put in the Trash while it waited
/// is let go.
pub fn next(db: &dyn Storage, user: i64) -> anyhow::Result<Option<(i64, i64)>> {
    db.next_for_needs(user)
}

/// Asks the provider's model which needs the card offers.
pub async fn ask(http: &Http, provider: &Provider, card: &str) -> anyhow::Result<Outcome> {
    describe::fits(provider, prompt(), card)?;
    let messages = [
        PromptMessage::new(Role::System, prompt()),
        PromptMessage::new(
            Role::User,
            format!("<card_to_read>\n{card}\n</card_to_read>"),
        ),
    ];
    describe::asked_and_read(http, provider, &messages, |said| {
        read(&object(said).map_err(|_| unread())?)
    })
    .await
}

fn unread() -> Fail {
    Fail::said(Code::ModelAnswer, "the worker model's needs cannot be read").with("what", "needs")
}

/// Reads the model's answer. A need it left out, an unknown one or a level out of 0 to 3 is no need; one said
/// twice keeps its highest level and its first place. An answer without any need of the list at a level of 0 to
/// 3 is no answer, so it fails and is asked again rather than standing as a card with no need; but for an empty
/// list on a card classified, which is what the model is told to answer of a card with none.
pub fn read(answered: &Value) -> anyhow::Result<Outcome> {
    let verdict = answered["verdict"].as_str().unwrap_or("");
    if verdict.trim().to_lowercase().starts_with("reject") {
        let reason = answered["reject_reason"].as_str().unwrap_or("").trim();
        return Ok(Outcome::Refused(if reason.is_empty() {
            "the card was refused".into()
        } else {
            reason.chars().take(REASON_LIMIT).collect()
        }));
    }
    let classified = verdict.trim().eq_ignore_ascii_case("classified");
    let entries = answered["needs"]
        .as_array()
        .filter(|entries| {
            (classified && entries.is_empty())
                || entries.iter().any(|entry| {
                    LIST.iter()
                        .any(|(name, _)| entry["need"].as_str() == Some(name))
                        && entry["level"].as_u64().is_some_and(|level| level <= 3)
                })
        })
        .ok_or_else(unread)?;
    let in_order = named_in_order(entries);
    let mut found: Vec<Found> = Vec::new();
    for (name, _) in LIST {
        let best = entries
            .iter()
            .filter(|entry| entry["need"].as_str() == Some(name))
            .filter_map(|entry| {
                let level = entry["level"]
                    .as_u64()
                    .filter(|level| (1..=3).contains(level))?;
                let quote = entry["quote"].as_str().unwrap_or("").trim();
                Some((level as u8, quote.to_string()))
            })
            .max_by_key(|(level, _)| *level);
        if let Some((level, quote)) = best {
            found.push(Found {
                need: name.to_string(),
                level,
                quote,
                rank: in_order
                    .iter()
                    .position(|named| *named == name)
                    .unwrap_or(0) as u32,
            });
        }
    }
    Ok(Outcome::Asked(found))
}

/// The needs of the list above level 0, each once, in the answer's order.
fn named_in_order(entries: &[Value]) -> Vec<&str> {
    let mut named: Vec<&str> = Vec::new();
    for entry in entries {
        let above = entry["level"]
            .as_u64()
            .is_some_and(|level| (1..=3).contains(&level));
        let need = entry["need"]
            .as_str()
            .filter(|need| LIST.iter().any(|(name, _)| name == need));
        if let Some(need) = need.filter(|need| above && !named.contains(need)) {
            named.push(need);
        }
    }
    named
}

/// Stores what came of asking about the version `version_id` of the card.
pub fn keep(
    db: &dyn Storage,
    card_id: i64,
    version_id: i64,
    outcome: anyhow::Result<Outcome>,
) -> anyhow::Result<()> {
    db.keep_needs(card_id, version_id, stored(db, outcome))
}

/// What came of asking, as it is stored.
pub(crate) fn stored(db: &dyn Failures, outcome: anyhow::Result<Outcome>) -> Stored {
    match outcome {
        Ok(Outcome::Asked(found)) => Stored::Asked(json!(found).to_string()),
        Ok(Outcome::Refused(reason)) => Stored::Ended("refused", reason),
        Err(failure) => Stored::Ended("failed", describe::kept_failure(db, &failure)),
    }
}

/// The card's needs that count: those of level [`COUNTS_FROM`] and above.
pub fn of_card(db: &dyn Storage, card_id: i64) -> anyhow::Result<CardNeeds> {
    let Some((state, found)) = db.needs_of(card_id)? else {
        return Ok(CardNeeds {
            state: NeedsState::NotAsked,
            needs: Vec::new(),
        });
    };
    Ok(counted(&state, &found))
}

/// Each of the user's cards not in the Trash that has a row, as [`of_card`] gives it.
fn of_user(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<(i64, CardNeeds)>> {
    let rows = db.needs_of_user(user)?.into_iter();
    Ok(rows
        .map(|(card, state, found)| (card, counted(&state, &found)))
        .collect())
}

/// What the view "By need" shows over its cards; see [`NeedsOverview`].
pub fn overview(db: &dyn Storage, user: i64) -> anyhow::Result<NeedsOverview> {
    let cards = of_user(db, user)?;
    let having = |name: &str| {
        let needs = cards.iter().flat_map(|(_, card)| &card.needs);
        needs.filter(|need| need.need == name).count()
    };
    let mut needs: Vec<(usize, &str)> = LIST
        .iter()
        .map(|(name, _)| (having(name), *name))
        .filter(|(count, _)| *count > 0)
        .collect();
    // Stable: of as many, the list's order stays.
    needs.sort_by_key(|(count, _)| std::cmp::Reverse(*count));
    let by_card = cards.iter().filter(|(_, card)| !card.needs.is_empty());
    let by_card = by_card.map(|(id, card)| {
        let mut found: Vec<&Found> = card.needs.iter().collect();
        found.sort_by_key(|need| need.rank);
        (*id, found.iter().map(|need| need.need.clone()).collect())
    });
    Ok(NeedsOverview {
        needs: needs
            .into_iter()
            .map(|(_, name)| name.to_string())
            .collect(),
        by_card: by_card.collect(),
        read: cards
            .iter()
            .filter(|(_, card)| card.state != NeedsState::Waiting)
            .count(),
        of: cards.len(),
    })
}

/// How strongly a card offers the needs picked: By need lists the highest `sum` first, of two alike the lower
/// `rank`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Strength {
    /// Its levels over the needs picked.
    pub sum: u32,
    /// The best rank among them. With one need picked, that need's.
    pub rank: u32,
}

/// The cards with any of the needs `picked` that counts, each with its [`Strength`].
pub fn strengths(
    db: &dyn Storage,
    user: i64,
    picked: &[String],
) -> anyhow::Result<HashMap<i64, Strength>> {
    let mut strengths = HashMap::new();
    for (card, needs) in of_user(db, user)? {
        let of_picked: Vec<&Found> = needs
            .needs
            .iter()
            .filter(|need| picked.contains(&need.need))
            .collect();
        if let Some(rank) = of_picked.iter().map(|need| need.rank).min() {
            let sum = of_picked.iter().map(|need| u32::from(need.level)).sum();
            strengths.insert(card, Strength { sum, rank });
        }
    }
    Ok(strengths)
}

/// What a row as stored comes to, of what counts.
fn counted(state: &str, found: &str) -> CardNeeds {
    let mut needs: Vec<Found> = serde_json::from_str(found).unwrap_or_default();
    needs.retain(|need| need.level >= COUNTS_FROM);
    let state = match state {
        "queued" => NeedsState::Waiting,
        "refused" => NeedsState::Refused,
        "failed" => NeedsState::Failed,
        _ if needs.is_empty() => NeedsState::Zero,
        _ => NeedsState::Found,
    };
    CardNeeds { state, needs }
}

#[cfg(test)]
mod tests {
    use super::ASK;

    #[test]
    fn the_prompt_asks_for_few_needs_and_one_or_two_at_the_top() {
        assert!(ASK.contains("as few as the card warrants"));
        assert!(ASK.contains("never more than two"));
        assert!(!ASK.contains("Fewer than 5 is fine"));
    }
}

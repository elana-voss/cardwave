//! The memory note before a reply (`render`, build spec A5), ported line by
//! line: open and temporary facts, then the core subjects' facts, within 450
//! tokens (part 1); then the rest of the facts and all events, searched by the
//! newest message and, where there is one, it with the entry before it (part 2).
//!
//! Part 2 ranks by reciprocal-rank fusion of BM25 and cosine where every text
//! it reads has a vector (`vectors`); else by BM25 alone (`best_rank`, the
//! golden file's `memory_bm25`), as until Search is downloaded.

use std::collections::HashSet;
use std::sync::LazyLock;

use regex::Regex;

use crate::memory::hybrid::{Fact, KnownTo, State};
use crate::memory::text::{best_first, best_rank, cosine, count, picked, relevance, strip};
use crate::memory::{Ask, Mode, Vectors};

/// Part 1's tokens.
const PART1: usize = 450;

/// `visible`: the entries the answering character may know. Roleplay: an
/// entry whose scope is world, whose known_to is everyone or names the
/// speaker; companion and assistant chats show everything.
pub fn visible(scope: &str, known_to: &KnownTo, speaker: &str, mode: Mode) -> bool {
    if mode != Mode::Roleplay {
        return true;
    }
    let me = speaker.to_lowercase();
    scope == "world"
        || match known_to {
            KnownTo::Everyone => true,
            KnownTo::Names(names) => names.iter().any(|n| n.to_lowercase() == me),
        }
}

fn until_day(fact: &Fact) -> Option<i64> {
    static DAY: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"\A(?:day\s*)?([0-9]+)\z").expect("the pattern is valid"));
    DAY.captures(&strip(&fact.until).to_lowercase())
        .and_then(|day| day.get(1)?.as_str().parse().ok())
}

/// A fact ended by a `done` line, or a temporary one whose day has passed (only chats with days).
fn expired(fact: &Fact, today: Option<i64>) -> bool {
    if fact.status == "done" {
        return true;
    }
    let end = until_day(fact);
    fact.status == "temporary" && matches!((today, end), (Some(today), Some(end)) if end < today)
}

fn prefix(day: Option<i64>, mode: Mode) -> String {
    match (mode, day) {
        (Mode::Roleplay, _) | (_, None) => String::new(),
        (_, Some(day)) => format!("day {day}: "),
    }
}

fn fact_line(f: &Fact, mode: Mode, today: Option<i64>) -> String {
    let head = format!("- {}", prefix(f.day, mode));
    if expired(f, today) {
        let end = match f.status == "done" {
            true => f.ended_day.flatten(),
            false => until_day(f),
        };
        let ended = end.map_or(String::new(), |end| format!(" (ended day {end})"));
        return format!("{head}no longer{ended}: {}", f.text);
    }
    if f.status == "temporary" && !f.until.is_empty() {
        let end = until_day(f).map_or(f.until.clone(), |end| format!("day {end}"));
        return format!("{head}{} (until {end})", f.text);
    }
    match f.was.is_empty() {
        true => format!("{head}{}", f.text),
        false => format!("{head}{} (was: {})", f.text, f.was),
    }
}

/// `core`: the subjects always shown.
fn core(speaker: &str, mode: Mode) -> Vec<String> {
    let me = speaker.to_lowercase();
    let mut pair = ["user".to_string(), me.clone()];
    pair.sort();
    let pair = pair.join("+");
    match mode {
        Mode::Roleplay => vec!["user".into(), me, pair],
        Mode::Companion => vec!["user".into(), pair],
        Mode::Assistant => vec!["user".into()],
    }
}

/// An entry of part 2's pool: a fact's or an event's line, text and whether it is a fact.
struct Pooled {
    line: String,
    text: String,
    fact: bool,
}

/// The scores of part 2's pool: by fusion where `vectors` has every text
/// (`FactsAndEventsHybridFixed.rank`), else by BM25 alone.
fn rank(pool: &[Pooled], queries: &[String], vectors: Option<&Vectors>) -> Vec<f64> {
    let texts: Vec<String> = pool.iter().map(|e| e.text.clone()).collect();
    let fused = vectors.and_then(|vectors| {
        let asked: Vec<&Vec<f32>> = queries
            .iter()
            .map(|q| vectors.get(q))
            .collect::<Option<_>>()?;
        let stored: Vec<&Vec<f32>> = texts
            .iter()
            .map(|t| vectors.get(t))
            .collect::<Option<_>>()?;
        let each = queries.iter().zip(asked).map(|(query, v)| {
            let rel = relevance(&texts, query);
            let cos: Vec<f64> = stored.iter().map(|e| cosine(v, e)).collect();
            let by_words = best_first(&rel)
                .into_iter()
                .filter(|&i| rel[i] > 0.0)
                .collect();
            let fused = cw_search::fuse(&[by_words, best_first(&cos)]);
            (0..texts.len())
                .map(|i| fused.get(&i).copied().unwrap_or(0.0))
                .collect::<Vec<f64>>()
        });
        each.reduce(|best, other| {
            best.into_iter()
                .zip(other)
                .map(|(a, b)| f64::max(a, b))
                .collect()
        })
    });
    fused.unwrap_or_else(|| best_rank(&texts, queries))
}

/// The lines of part 1 of the facts `facts` the speaker may know, and their IDs.
fn part1(facts: &[&Fact], ask: &Ask) -> (Vec<String>, HashSet<u64>) {
    let (speaker, mode, today) = (ask.speaker.as_str(), ask.mode, ask.today);
    let live: Vec<&Fact> = facts
        .iter()
        .copied()
        .filter(|f| !expired(f, today))
        .collect();
    let core = core(speaker, mode);
    let due: Vec<&Fact> = live
        .iter()
        .filter(|f| f.status == "open")
        .chain(live.iter().filter(|f| f.status == "temporary"))
        .copied()
        .collect();
    let mine: Vec<&Fact> = live
        .iter()
        .copied()
        .filter(|f| f.status == "current" && core.contains(&f.subject))
        .collect();
    let lines1: Vec<String> = due.iter().map(|f| fact_line(f, mode, today)).collect();
    // Open and temporary first, in store order.
    let kept = picked(&lines1, &vec![1.0; lines1.len()], PART1, true);
    let mut first: Vec<u64> = kept.iter().map(|&i| due[i].id).collect();
    let mut lines1: Vec<String> = kept.into_iter().map(|i| lines1[i].clone()).collect();
    let mine_lines: Vec<String> = mine.iter().map(|f| fact_line(f, mode, today)).collect();
    let tokens = |lines: &[String]| lines.iter().map(|x| count(x) + 1).sum::<usize>();
    let room1 = PART1.saturating_sub(tokens(&lines1));
    let chosen1: Vec<usize> = match tokens(&mine_lines) <= room1 {
        true => (0..mine.len()).collect(),
        false => {
            // By the query, the newest set first among equals.
            let texts: Vec<String> = mine.iter().map(|f| f.text.clone()).collect();
            let rel = relevance(&texts, &ask.query);
            let scores: Vec<f64> = rel
                .iter()
                .enumerate()
                .map(|(i, r)| r + 1e-6 * (i + 1) as f64)
                .collect();
            picked(&mine_lines, &scores, room1, true)
        }
    };
    first.extend(chosen1.iter().map(|&i| mine[i].id));
    lines1.extend(chosen1.into_iter().map(|i| mine_lines[i].clone()));
    (lines1, first.into_iter().collect())
}

impl State {
    /// The memory note for `ask`, at most `ask.budget` tokens; empty where nothing is remembered.
    pub fn render(&self, ask: &Ask, vectors: Option<&Vectors>) -> String {
        let (speaker, mode, today) = (ask.speaker.as_str(), ask.mode, ask.today);
        let facts: Vec<&Fact> = self
            .facts
            .iter()
            .filter(|f| visible(&f.scope, &f.known_to, speaker, mode))
            .collect();
        let events = self
            .events
            .iter()
            .filter(|e| visible(&e.scope, &e.known_to, speaker, mode));
        let (lines1, shown) = part1(&facts, ask);
        let tokens = |lines: &[String]| lines.iter().map(|x| count(x) + 1).sum::<usize>();
        // Facts before events, each in store order.
        let pool: Vec<Pooled> = facts
            .iter()
            .filter(|f| !shown.contains(&f.id))
            .map(|f| Pooled {
                line: fact_line(f, mode, today),
                text: f.text.clone(),
                fact: true,
            })
            .chain(events.map(|e| Pooled {
                line: format!("- {}{}", prefix(e.day, mode), e.text),
                text: e.text.clone(),
                fact: false,
            }))
            .collect();
        // 8: the two headings.
        let room = ask.budget as i64 - tokens(&lines1) as i64 - 8;
        let chosen = match pool.is_empty() || room < 0 {
            true => Vec::new(),
            false => {
                let mut queries = vec![ask.query.clone()];
                if let Some(prev) = &ask.prev {
                    queries.push(format!("{}\n{prev}", ask.query));
                }
                let scores = rank(&pool, &queries, vectors);
                let lines2: Vec<String> = pool.iter().map(|e| e.line.clone()).collect();
                picked(&lines2, &scores, room as usize, true)
            }
        };
        let known: Vec<&str> = lines1
            .iter()
            .map(String::as_str)
            .chain(
                chosen
                    .iter()
                    .filter(|&&i| pool[i].fact)
                    .map(|&i| pool[i].line.as_str()),
            )
            .collect();
        let earlier: Vec<&str> = chosen
            .iter()
            .filter(|&&i| !pool[i].fact)
            .map(|&i| pool[i].line.as_str())
            .collect();
        let mut out = Vec::new();
        if !known.is_empty() {
            out.push("Known:");
            out.extend(known);
        }
        if !earlier.is_empty() {
            out.push("Earlier:");
            out.extend(earlier);
        }
        out.join("\n")
    }
}

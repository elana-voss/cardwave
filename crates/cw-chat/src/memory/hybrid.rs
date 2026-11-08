//! The memory system "facts-and-events-hybrid-fixed", ported line by line from
//! pmbench's `memory_events.py` (build spec, Part B1, `..\cardwave-next-memtest`;
//! Part A explains it). One helper call per block of 20 messages (`prompt`,
//! then `apply` of its reply) gives keyed facts and witnessed events; `render`
//! (`render.rs`) writes the memory note before a reply.
//!
//! Kept as measured, quirks and all (A9): do not clean it up without a new
//! measurement (A12). The app adds to an entry only `id` (its number in the
//! state, `next_id`), `chat` (the chat its block came from) and `deleted`
//! (Knowledge › Memories' delete, until the server starts again), which
//! `live` leaves out before anything reads the state; the golden test
//! (`server/tests/memory_port.rs`) compares all else with the benchmark's.
//! `prev` keeps the last 3 messages of the block added last, all it is read for.

use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::memory::text::{collapse, count, fit, pick, relevance, rows, split, splitlines, strip};
use crate::memory::{Block, Mode, Said};

mod hook;
mod render;

pub(crate) use hook::HybridFixed;
pub use render::visible;

const KNOWN: &str = "everyone who was present: who speaks in or is addressed in these messages, unless the text says someone is away or has left; 'everyone' if all characters are";
const SCOPE: &str = "'world' for a fact about the place, customs, prices or history; 'personal' for what someone did, said, feels, owns or promised";
const LIES: &str =
    "When the chat shows that something said is false, record it as 'A claimed ...'.";
const STATUSES: [&str; 4] = ["current", "open", "temporary", "done"];
const DETAIL: &str = "Every concrete detail said once (a name, a number, a place, a date, a title, what something is called or is made of) is an event of its own, even when nothing happens.";
const PRESENT: &str = "Start the reply with one line PRESENT: the names of those who speak or are addressed in these messages; leave out anyone said to be away, elsewhere or to have left.";
const KEY_RULE: &str = " A key names one attribute only: a fact about another attribute of the same subject gets a new key, never an existing one (a ship's name and its sails are two keys).";

/// How the helper's prompt begins, by which a stand-in for the provider tells it.
pub const OPENING: &str = "Read these new messages of a ";

fn regex(pattern: &str) -> Regex {
    Regex::new(pattern).expect("the pattern is valid")
}

fn fancy(pattern: &str) -> fancy_regex::Regex {
    fancy_regex::Regex::new(pattern).expect("the pattern is valid")
}

/// 'PRESENT: Hesper | Juno', not 'Present at ...'.
static PRESENT_ROW: LazyLock<Regex> = LazyLock::new(|| regex(r"(?i)^\W*present\W*:"));

/// Who knows an entry: the names, lower-case, or `"everyone"`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KnownTo {
    Everyone,
    Names(Vec<String>),
}

impl Serialize for KnownTo {
    fn serialize<S: Serializer>(&self, to: S) -> Result<S::Ok, S::Error> {
        match self {
            Self::Everyone => to.serialize_str("everyone"),
            Self::Names(names) => names.serialize(to),
        }
    }
}

impl<'de> Deserialize<'de> for KnownTo {
    fn deserialize<D: Deserializer<'de>>(from: D) -> Result<Self, D::Error> {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum Either {
            Many(Vec<String>),
            One(serde::de::IgnoredAny),
        }
        Ok(match Either::deserialize(from)? {
            Either::Many(names) => Self::Names(names),
            Either::One(_) => Self::Everyone,
        })
    }
}

fn is_false(value: &bool) -> bool {
    !*value
}

/// A key that is there holding null reads as `Some(None)`; one left out, as `None`.
fn there<'de, D: Deserializer<'de>>(from: D) -> Result<Option<Option<i64>>, D::Error> {
    Ok(Some(Option::deserialize(from)?))
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Fact {
    pub id: u64,
    pub(crate) subject: String,
    pub key: String,
    pub text: String,
    pub scope: String,
    pub(crate) known_to: KnownTo,
    pub status: String,
    pub until: String,
    pub n: i64,
    pub day: Option<i64>,
    pub was: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ended: Option<i64>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "there"
    )]
    pub(crate) ended_day: Option<Option<i64>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub chat: Option<i64>,
    #[serde(default, skip_serializing_if = "is_false")]
    pub deleted: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Event {
    pub id: u64,
    pub text: String,
    pub(crate) known_to: KnownTo,
    pub scope: String,
    pub n: i64,
    pub day: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub chat: Option<i64>,
    #[serde(default, skip_serializing_if = "is_false")]
    pub deleted: bool,
}

/// The memory: facts in the order last set (a subject and key once), events,
/// and the end of the block added last.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct State {
    pub facts: Vec<Fact>,
    pub events: Vec<Event>,
    pub prev: Vec<Said>,
    pub(crate) next_id: u64,
}

/// `split_names`: 'Hesper, the user and Wyn' -> ['hesper', '<user>', 'wyn'].
pub(crate) fn split_names(cell: &str, user: &str) -> Vec<String> {
    static SPLIT: LazyLock<Regex> = LazyLock::new(|| regex(r",|;|/|&|\||\band\b"));
    let lower = cell.to_lowercase();
    SPLIT
        .split(&lower)
        .map(|part| collapse(part.trim_matches(|c| ".:'\"!*".contains(c))))
        .filter(|part| !part.is_empty() && !part.starts_with("not "))
        .map(|part| match (part.as_str(), user.is_empty()) {
            ("user" | "the user", false) => user.to_lowercase(),
            _ => part,
        })
        .collect()
}

/// `names`: 'Hesper, Juno (Caddoc away)' -> ['hesper', 'juno']; nothing, '?'
/// or a cell starting with everyone, everybody or all -> everyone; 'everyone
/// but Caddoc' -> the cast and the user without Caddoc (everyone when the
/// cast is not known); 'the user' -> the user's name.
pub fn names(cell: &str, user: &str, cast: &[String]) -> KnownTo {
    static BUT_IN: LazyLock<Regex> = LazyLock::new(|| regex(r"\(([^)]*\b(?:but|except)\b[^)]*)\)"));
    static ASIDE: LazyLock<Regex> = LazyLock::new(|| regex(r"\([^)]*\)"));
    static ALL: LazyLock<Regex> = LazyLock::new(|| regex(r"^(everyone|everybody|all)\b(.*)"));
    static BUT: LazyLock<Regex> = LazyLock::new(|| regex(r"\b(?:but|except)\b(.*)"));
    let cell = BUT_IN
        .replace_all(&cell.to_lowercase(), " ${1}")
        .into_owned();
    let cell = ASIDE.replace_all(&cell, " ");
    let cell = strip(&cell);
    if cell.is_empty() || cell == "?" {
        return KnownTo::Everyone;
    }
    if let Some(all) = ALL.captures(cell) {
        let rest = all.get(2).map_or("", |m| m.as_str());
        let Some(but) = BUT.captures(rest).filter(|_| !cast.is_empty()) else {
            return KnownTo::Everyone;
        };
        let gone = split_names(but.get(1).map_or("", |m| m.as_str()), user);
        let mut all: Vec<String> = cast.iter().map(|c| c.to_lowercase()).collect();
        if !user.is_empty() {
            all.push(user.to_lowercase());
        }
        return KnownTo::Names(all.into_iter().filter(|n| !gone.contains(n)).collect());
    }
    KnownTo::Names(split_names(cell, user))
}

/// The cell of the reply's 'PRESENT: names' line; none without one.
pub(crate) fn present_line(reply: &str) -> Option<String> {
    static LINE: LazyLock<Regex> = LazyLock::new(|| regex(r"(?im)^\W*PRESENT\W*:(.*)$"));
    LINE.captures(reply)
        .map(|found| found.get(1).map_or("", |m| m.as_str()).to_string())
}

/// `away`: the characters away in the beat starting at message `n`.
fn away(block: &Block, n: i64) -> Vec<String> {
    block
        .absent
        .iter()
        .filter(|span| span.from <= n && n <= span.to)
        .map(|span| span.name.clone())
        .collect()
}

/// `present`: names() of a known-to cell read against the cast not away in
/// the block: 'everyone' (or nothing) is the names of `here_now` (the reply's
/// PRESENT cell) not away, when it names any, else those characters and the
/// user; 'everyone but X' the cast and the user without X.
fn present(block: &Block, cell: &str, here_now: Option<&str>) -> KnownTo {
    let gone = away(block, block.messages[0].n);
    let here: Vec<String> = block
        .cast
        .iter()
        .filter(|c| !gone.contains(c))
        .cloned()
        .collect();
    let who = names(cell, &block.user, &here);
    let said = match (&who, here_now) {
        (KnownTo::Everyone, Some(now)) => names(now, &block.user, &here),
        _ => KnownTo::Everyone,
    };
    if let KnownTo::Names(said) = said {
        let gone: Vec<String> = gone.iter().map(|g| g.to_lowercase()).collect();
        let said: Vec<String> = said.into_iter().filter(|n| !gone.contains(n)).collect();
        if !said.is_empty() {
            return KnownTo::Names(said);
        }
    }
    if who == KnownTo::Everyone && !block.cast.is_empty() {
        let mut all: Vec<String> = here.iter().map(|c| c.to_lowercase()).collect();
        if !block.user.is_empty() {
            all.push(block.user.to_lowercase());
        }
        return KnownTo::Names(all);
    }
    who
}

fn scope_of(cell: &str) -> String {
    match strip(cell).to_lowercase().starts_with("world") {
        true => "world",
        false => "personal",
    }
    .to_string()
}

fn kind(mode: Mode) -> &'static str {
    match mode {
        Mode::Roleplay => "roleplay chat",
        Mode::Companion => "companion chat",
        Mode::Assistant => "assistant chat",
    }
}

/// `fmt`: the messages as `[n] Speaker: text`.
fn fmt(block: &[Said]) -> String {
    block
        .iter()
        .map(|m| format!("[{}] {}: {}", m.n, m.speaker, m.text))
        .collect::<Vec<_>>()
        .join("\n")
}

/// `dated`: the messages, after the day they fall on when the chat has days.
fn dated(block: &[Said]) -> String {
    let day = block.last().and_then(|m| m.day);
    day.map_or(String::new(), |day| format!("Today is day {day}.\n\n")) + &fmt(block)
}

/// `sections`: the 'a | b' rows of a reply under its FACTS: and EVENTS:
/// headings (rows before any heading are events); a row repeating the
/// column names is dropped.
fn sections(reply: &str) -> (Vec<Vec<String>>, Vec<Vec<String>>) {
    static HEAD: LazyLock<fancy_regex::Regex> =
        LazyLock::new(|| fancy(r"(?i)^\W*(FACTS|EVENTS)\b(?=\s*(?:[:*#]|$))\W*"));
    let (mut facts, mut events) = (Vec::new(), Vec::new());
    let mut in_facts = false;
    for line in splitlines(reply) {
        let mut line = line;
        // fancy_regex fails only past its backtrack limit, which these patterns on one line never reach.
        if let Ok(Some(head)) = HEAD.captures(line) {
            let (Some(name), Some(whole)) = (head.get(1), head.get(0)) else {
                continue;
            };
            in_facts = name.as_str().to_uppercase() == "FACTS";
            line = &line[whole.end()..];
        }
        for parts in rows(line) {
            let first = parts[0].to_lowercase();
            if first != "subject"
                && first != "event"
                && parts.iter().any(|p| !p.is_empty())
                && !PRESENT_ROW.is_match(&parts[0])
            {
                match in_facts {
                    true => facts.push(parts),
                    false => events.push(parts),
                }
            }
        }
    }
    (facts, events)
}

/// Where Python's `xs[start:]` begins for a list of `len`.
fn slice_start(len: usize, start: isize) -> usize {
    match start {
        start if start >= 0 => (start as usize).min(len),
        start => (len as isize + start).max(0) as usize,
    }
}

impl State {
    /// The state as the memory reads it: without what the user deleted.
    pub fn live(&self) -> Self {
        Self {
            facts: self.facts.iter().filter(|f| !f.deleted).cloned().collect(),
            events: self.events.iter().filter(|e| !e.deleted).cloned().collect(),
            prev: self.prev.clone(),
            next_id: self.next_id,
        }
    }

    fn fact(&self, subject: &str, key: &str) -> Option<usize> {
        self.facts
            .iter()
            .position(|f| f.subject == subject && f.key == key)
    }

    /// `subject`: 'Sam' (the user) -> 'user'; 'Noor+Sam' -> 'noor+user'.
    fn subject(cell: &str, user: &str) -> String {
        let user = user.to_lowercase();
        let mut parts: Vec<String> = cell
            .to_lowercase()
            .split('+')
            .map(collapse)
            .filter(|p| !p.is_empty())
            .map(|p| if p == user { "user".to_string() } else { p })
            .collect();
        match parts.len() {
            0 => String::new(),
            1 => parts.remove(0),
            _ => {
                parts.sort();
                parts.join("+")
            }
        }
    }

    /// `listed_line`: a fact's line in the helper's list of open and temporary facts.
    fn listed_line(f: &Fact) -> String {
        let who = match &f.known_to {
            KnownTo::Everyone => "everyone".to_string(),
            KnownTo::Names(names) => names.join(", "),
        };
        format!(
            "{} | {} | {} | {} | {} | {} | {}",
            f.subject, f.key, f.text, f.scope, who, f.status, f.until
        )
        .trim_end()
        .to_string()
    }

    /// The helper's prompt for `block` (the first half of `add`).
    pub fn prompt(&self, block: &Block) -> String {
        let due: Vec<&Fact> = self
            .facts
            .iter()
            .filter(|f| f.status == "open" || f.status == "temporary")
            .collect();
        let lines: Vec<String> = due.iter().map(|f| Self::listed_line(f)).collect();
        let listed = fit(&lines, 400, true, false);
        let shown: Vec<(&str, &str)> = match listed.is_empty() {
            true => Vec::new(),
            false => {
                let start = due.len() as isize - splitlines(&listed).len() as isize;
                due[slice_start(due.len(), start)..]
                    .iter()
                    .map(|f| (f.subject.as_str(), f.key.as_str()))
                    .collect()
            }
        };
        let pairs: Vec<String> = self
            .facts
            .iter()
            .filter(|f| !shown.contains(&(f.subject.as_str(), f.key.as_str())))
            .map(|f| format!("{} | {}", f.subject, f.key))
            .collect();
        let all = pairs.join("\n");
        let known = match count(&all) <= 400 {
            true => all,
            false => pick(
                &pairs,
                &relevance(&pairs, &fmt(&block.messages)),
                400,
                false,
            ),
        }
        .replace('\n', "; ");
        let user = if block.user.is_empty() {
            "the user"
        } else {
            &block.user
        };
        let earlier = self
            .prev
            .iter()
            .rev()
            .take(3)
            .rev()
            .map(|m| format!("{}: {}", m.speaker, m.text))
            .collect::<Vec<_>>()
            .join("\n");
        let scene = format!(
            "Characters in this chat: {}; the user is {user}.{}",
            block.cast.join(", "),
            match earlier.is_empty() {
                true => String::new(),
                false => format!("\n\nEarlier, for context only, never extracted from:\n{earlier}"),
            }
        );
        let or_none = |text: &str| match text.is_empty() {
            true => "(none)".to_string(),
            false => text.to_string(),
        };
        format!(
            "{OPENING}{} with {user} (the user). Reply with two sections.\n\
             FACTS: one line per fact as: subject | key | fact | scope | known to | status | until\n\
             - subject: user (for the user), a character's name, two names joined by + for a relationship, or a place or thing. \
             key: a short stable attribute, such as job or spare key location. fact: one short sentence. A fact that updates a \
             known subject and key uses exactly that pair.{KEY_RULE}\n\
             - status: current; open for a promise, task or plan not yet done; temporary for a state that holds for a while \
             (ill this week, market closed until the festival, on call until day 12, a deadline), with until; done when a later \
             message shows an open or temporary one finished or ended (same subject and key).\n\
             - until: for temporary, a day number (resolve 'this week' or 'until Friday' against today) or a short condition \
             ('the festival', 'the refactor lands'); else empty.\n\
             - A dream, story, joke, lie or what-if is never a fact: put it in EVENTS as 'X told a story / dreamed / claimed \
             that ...'. {LIES}\n\
             EVENTS: one line per event as: event | cause | result | known to | scope. Each event says who did or said what, \
             with every concrete detail. {DETAIL}\n\
             Known to: {KNOWN}. Scope: {SCOPE}.\n{PRESENT}\n\n{scene}\n\n\
             Known facts still open or temporary:\n{}\nWhen these messages show one of them fulfilled, ended or no longer true, \
             write its FACTS line again with the same subject and key and with status done.\n\n\
             Other known pairs: {}\n\nNew messages:\n{}\n\nReply with the PRESENT line and the two sections only.",
            kind(block.mode),
            or_none(&listed),
            or_none(&known),
            dated(&block.messages),
        )
    }

    /// `named`: whether any of the lower-case names is a cast name or the user's.
    fn named(block: &Block, who: &[String]) -> bool {
        who.iter().any(|n| {
            block.cast.iter().any(|c| c.to_lowercase() == *n)
                || (!block.user.is_empty() && block.user.to_lowercase() == *n)
        })
    }

    /// `known`: the known-to of a FACTS or EVENTS cell.
    fn known(block: &Block, cell: &str, here_now: Option<&str>) -> KnownTo {
        let who = present(block, &cell.replace('+', ","), here_now);
        match &who {
            KnownTo::Names(names) if !names.is_empty() && !Self::named(block, names) => {
                present(block, "", here_now)
            }
            _ => who,
        }
    }

    /// `cells`: a FACTS row as its 7 cells [subject, key, text, scope, who,
    /// status, until]: positional when cell 6 is a status word and cell 4 is
    /// none, else each cell read by what it holds.
    fn cells(block: &Block, mut parts: Vec<String>) -> Vec<String> {
        static ALL: LazyLock<fancy_regex::Regex> =
            LazyLock::new(|| fancy(r"^\W*all\b(?!\W*(?:$|but\b|except\b))"));
        while parts.len() < 3 {
            parts.push(String::new());
        }
        let status = |c: &str| STATUSES.contains(&strip(c).to_lowercase().as_str());
        let scope = |c: &str| {
            let c = strip(c).to_lowercase();
            c.starts_with("world") || c.starts_with("personal")
        };
        if parts.len() >= 7 && status(&parts[5]) && !status(&parts[3]) {
            parts.truncate(7);
            return parts;
        }
        let rest = &parts[3..];
        let st = rest.iter().find(|c| status(c)).cloned().unwrap_or_default();
        let sc = rest.iter().find(|c| scope(c)).cloned().unwrap_or_default();
        let others: Vec<&String> = rest.iter().filter(|c| !status(c) && !scope(c)).collect();
        // 'all week' is an until, not everyone; 'everyone but Noor' names the others.
        let who = |c: &str| match names(c, &block.user, &block.cast) {
            // As at HEAD: the backtrack limit is never reached.
            KnownTo::Everyone => !ALL.is_match(&c.to_lowercase()).unwrap_or(false),
            KnownTo::Names(said) => {
                Self::named(block, &said)
                    || Self::named(block, &split_names(&c.replace('+', ","), &block.user))
            }
        };
        let who_at = others.iter().position(|c| !strip(c).is_empty() && who(c));
        let until = match strip(&st).to_lowercase() == "temporary" {
            true => others
                .iter()
                .enumerate()
                .rev()
                .find(|(i, c)| !strip(c).is_empty() && Some(*i) != who_at)
                .map(|(_, c)| (*c).clone())
                .unwrap_or_default(),
            false => String::new(),
        };
        let who = who_at.map(|i| others[i].clone()).unwrap_or_default();
        vec![
            parts[0].clone(),
            parts[1].clone(),
            parts[2].clone(),
            sc,
            who,
            st,
            until,
        ]
    }

    /// `set_fact`: applies one FACTS row; answers the ID of the fact it set anew, if any.
    fn set_fact(
        &mut self,
        block: &Block,
        parts: Vec<String>,
        here_now: Option<&str>,
    ) -> Option<u64> {
        let parts = Self::cells(block, parts);
        let [subject, key, text, scope, who, status, until] = &parts[..7] else {
            return None;
        };
        let pair = (
            Self::subject(subject, &block.user),
            collapse(&key.to_lowercase()),
        );
        let status = strip(&status.to_lowercase()).to_string();
        let mut status = match STATUSES.contains(&status.as_str()) {
            true => status,
            false => "current".to_string(),
        };
        let old = self.fact(&pair.0, &pair.1);
        let (n, day) = (
            block.messages[0].n,
            block.messages.last().and_then(|m| m.day),
        );
        if status == "done" {
            // An open one is closed; any other ends, kept to say it no longer holds.
            if let Some(at) = old {
                if self.facts[at].status == "open" {
                    self.facts.remove(at);
                    return None;
                }
                if self.facts[at].status != "done" {
                    let ended = &mut self.facts[at];
                    ended.status = "done".into();
                    ended.ended = Some(n);
                    ended.ended_day = Some(day);
                    return None;
                }
            }
            // Nothing live to end: the line itself is what now holds ('her fever has broken').
            status = "current".into();
        }
        if pair.0.is_empty() || text.is_empty() {
            return None;
        }
        let was = match old.map(|at| &self.facts[at]) {
            Some(old) if old.text == *text => old.was.clone(),
            Some(old) => split(&old.text)
                .into_iter()
                .take(12)
                .collect::<Vec<_>>()
                .join(" "),
            None => String::new(),
        };
        if let Some(at) = old {
            self.facts.remove(at);
        }
        let id = self.next_id;
        self.next_id += 1;
        let temporary = status == "temporary";
        self.facts.push(Fact {
            id,
            subject: pair.0,
            key: pair.1,
            text: text.clone(),
            scope: scope_of(scope),
            known_to: Self::known(block, who, here_now),
            status,
            until: if temporary {
                until.clone()
            } else {
                String::new()
            },
            n,
            day,
            was,
            ended: None,
            ended_day: None,
            chat: block.chat_id,
            deleted: false,
        });
        Some(id)
    }

    /// Reads the helper's `reply` to the prompt of `block` into the state (the
    /// second half of `add`). Answers the texts it set anew: the facts still as
    /// they were set, then the events, which are what is embedded.
    pub fn apply(&mut self, block: &Block, reply: &str) -> Vec<String> {
        let (facts, events) = sections(reply);
        let here = present_line(reply);
        let mut new: Vec<u64> = Vec::new();
        for mut parts in facts {
            while parts.len() < 7 {
                parts.push(String::new());
            }
            if let Some(id) = self.set_fact(block, parts, here.as_deref()) {
                new.push(id);
            }
        }
        let mut saved: Vec<String> = self
            .facts
            .iter()
            .filter(|f| new.contains(&f.id))
            .map(|f| f.text.clone())
            .collect();
        let (n, day) = (
            block.messages[0].n,
            block.messages.last().and_then(|m| m.day),
        );
        for mut parts in events {
            if parts[0].is_empty() || PRESENT_ROW.is_match(&parts[0]) {
                continue;
            }
            while parts.len() < 3 {
                parts.push("?".into());
            }
            parts.extend([String::new(), String::new()]);
            let id = self.next_id;
            self.next_id += 1;
            let text = format!("{} (cause: {}; result: {})", parts[0], parts[1], parts[2]);
            saved.push(text.clone());
            self.events.push(Event {
                id,
                text,
                known_to: Self::known(block, &parts[3], here.as_deref()),
                scope: scope_of(&parts[4]),
                n,
                day,
                chat: block.chat_id,
                deleted: false,
            });
        }
        let from = block.messages.len().saturating_sub(3);
        self.prev = block.messages[from..].to_vec();
        saved
    }

    /// Every text the meaning search reads: each fact's and each event's.
    pub fn texts(&self) -> Vec<String> {
        let facts = self.facts.iter().map(|f| f.text.clone());
        facts
            .chain(self.events.iter().map(|e| e.text.clone()))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn block() -> Block {
        Block {
            messages: vec![Said {
                n: 1,
                speaker: "Sam".into(),
                text: "Hi.".into(),
                day: Some(1),
            }],
            user: "Sam".into(),
            cast: vec!["Noor".into()],
            mode: Mode::Companion,
            absent: Vec::new(),
            chat_id: None,
        }
    }

    fn cells(row: &str) -> Vec<String> {
        let mut parts = rows(row).remove(0);
        while parts.len() < 7 {
            parts.push(String::new());
        }
        State::cells(&block(), parts)
    }

    #[test]
    fn a_facts_row_is_read_by_what_its_cells_hold() {
        // The examples of the build spec, A4.5 step 0.
        assert_eq!(
            cells("mara | task | Mara must fix the stove | open")[3..],
            ["", "", "open", ""]
        );
        assert_eq!(
            cells("road | state | The road is mud | temporary | the mud holds off")[6],
            "the mud holds off"
        );
        assert_eq!(
            cells("noor | shift | Noor is on call | temporary | Noor; Sam | current | day 14")[3..],
            ["", "Noor; Sam", "temporary", "day 14"]
        );
        assert_eq!(
            cells("inn | price | A room costs 3 coins | current | | world")[3..],
            ["world", "", "current", ""]
        );
        assert_eq!(State::subject("Noor+Sam", "Sam"), "noor+user");
    }
}

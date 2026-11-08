//! Lorebook activation: which entries of a character's lorebook apply to the chat
//! as it stands, in the order the token budget is spent on them.
//!
//! An entry's keys are read for in the newest messages, as many as the
//! lorebook says (`scan_depth`, else four), or as the entry says itself
//! (`LorebookEntry::scan_depth`), which the Flutter app did not have. An entry
//! used by meaning goes by `ChatState::meaning` where that is known.

use std::collections::HashMap;

use fancy_regex::Regex;

use crate::{Character, ChatMessage, ChatState, LorebookEntry, Role, SelectiveLogic};

const DEFAULT_SCAN_DEPTH: usize = 4;
const MAX_PROBABILITY: u32 = 100;

/// An entry that applies, with its `@@` decorator lines taken out of the content.
#[derive(Debug)]
pub struct Activated<'a> {
    pub entry: &'a LorebookEntry,
    pub content: String,
    /// Key of the entry in the chat's sticky and cooldown state.
    pub uid: String,
    /// Depth from an `@@depth` decorator; it also makes the entry an at-depth one.
    pub depth_override: Option<usize>,
    /// Role from an `@@role` decorator.
    pub role_override: Option<Role>,
}

/// What identifies an entry, the `index`th of its lorebook, in the chat's
/// state: its id, else its place.
pub fn uid(index: usize, entry: &LorebookEntry) -> String {
    entry.id.clone().unwrap_or_else(|| index.to_string())
}

/// Evaluates the character's lorebook against the chat. Expired sticky and
/// cooldown phases are dropped from `chat`; new ones start in
/// [`commit_timed_effects`], once the token budget has decided which entries stay.
pub fn evaluate<'a>(character: &'a Character, chat: &mut ChatState) -> Vec<Activated<'a>> {
    let Some(lorebook) = &character.lorebook else {
        return Vec::new();
    };
    if lorebook.entries.is_empty() {
        return Vec::new();
    }

    let message_count = chat.messages.len();
    let scan_depth = lorebook.scan_depth.unwrap_or(DEFAULT_SCAN_DEPTH);
    // The newest messages as one text, for each number of them that is read:
    // the lorebook's, and an entry's own where it has one.
    let mut haystacks: HashMap<usize, Haystack> = HashMap::new();

    chat.active_stickies
        .retain(|_, expires| message_count < *expires);
    chat.active_cooldowns
        .retain(|_, expires| message_count < *expires);

    let mut triggered = Vec::new();
    for (index, entry) in lorebook.entries.iter().enumerate() {
        if !entry.enabled {
            continue;
        }
        let decorated = parse_decorators(&entry.content);
        if decorated.content.is_empty() || decorated.dont_activate {
            continue;
        }
        if !passes_character_filter(entry, character) {
            continue;
        }
        if entry.delay > 0 && message_count < entry.delay {
            continue;
        }

        let uid = uid(index, entry);
        let is_sticky = chat.active_stickies.contains_key(&uid);
        // A cooldown blocks the entry unless it is still in its sticky phase.
        if chat.active_cooldowns.contains_key(&uid) && !is_sticky {
            continue;
        }

        let by_meaning = chat.meaning.as_ref().filter(|_| entry.by_meaning);
        let is_triggered = decorated.activate
            || entry.constant
            || is_sticky
            || match by_meaning {
                Some(meant) => meant.contains(&uid),
                None => {
                    let depth = entry.scan_depth.unwrap_or(scan_depth);
                    let recent = haystacks
                        .entry(depth)
                        .or_insert_with(|| Haystack::of(&chat.messages, depth));
                    recent.matches_entry(entry)
                }
            };
        if !is_triggered {
            continue;
        }
        // A sticky entry skips the probability roll.
        let passes_roll = is_sticky
            || entry.probability >= MAX_PROBABILITY
            || rand::random_range(0..MAX_PROBABILITY) < entry.probability;
        if passes_roll {
            triggered.push(Activated {
                entry,
                content: decorated.content,
                uid,
                depth_override: decorated.depth,
                role_override: decorated.role,
            });
        }
    }

    // Budget order: constant entries first, then higher priority, then lower
    // insertion order.
    triggered.sort_by(|a, b| {
        b.entry
            .constant
            .cmp(&a.entry.constant)
            .then(b.entry.priority.cmp(&a.entry.priority))
            .then(a.entry.insertion_order.cmp(&b.entry.insertion_order))
    });
    triggered
}

/// Starts the sticky and cooldown phases of the entries that made it into the
/// prompt. An entry dropped for lack of budget starts neither.
pub fn commit_timed_effects<'a, 'e: 'a>(
    chat: &mut ChatState,
    survivors: impl IntoIterator<Item = &'a Activated<'e>>,
) {
    let message_count = chat.messages.len();
    for survivor in survivors {
        if chat.active_stickies.contains_key(&survivor.uid) {
            continue;
        }
        let entry = survivor.entry;
        if entry.cooldown > 0 {
            let expires = message_count + entry.sticky + entry.cooldown;
            chat.active_cooldowns.insert(survivor.uid.clone(), expires);
        }
        if entry.sticky > 0 {
            chat.active_stickies
                .insert(survivor.uid.clone(), message_count + entry.sticky);
        }
    }
}

#[derive(Default)]
struct Decorated {
    content: String,
    activate: bool,
    dont_activate: bool,
    depth: Option<usize>,
    role: Option<Role>,
}

/// Reads the `@@decorator` lines at the top of an entry's content
/// (`@@activate`, `@@dont_activate`, `@@depth 2`, `@@role user`) and returns the
/// content without them. For depth and role the first valid line wins.
fn parse_decorators(content: &str) -> Decorated {
    let mut decorated = Decorated::default();
    let mut rest = content;
    while !rest.is_empty() {
        let (line, after) = rest.split_once('\n').unwrap_or((rest, ""));
        let Some(decorator) = line.trim_start().strip_prefix("@@") else {
            break;
        };
        let (command, value) = decorator.split_once(' ').unwrap_or((decorator, ""));
        let value = value.trim();
        match command.replace('@', "").as_str() {
            "activate" => decorated.activate = true,
            "dont_activate" => decorated.dont_activate = true,
            "depth" if decorated.depth.is_none() => {
                decorated.depth = value.parse::<i64>().ok().map(|depth| depth.max(0) as usize);
            }
            "role" if decorated.role.is_none() => {
                decorated.role = match value {
                    "user" => Some(Role::User),
                    "assistant" => Some(Role::Assistant),
                    "system" => Some(Role::System),
                    _ => None,
                };
            }
            _ => {}
        }
        rest = after;
    }
    decorated.content = rest.trim().to_string();
    decorated
}

fn passes_character_filter(entry: &LorebookEntry, character: &Character) -> bool {
    let Some(filter) = &entry.character_filter else {
        return true;
    };
    if !filter.names.is_empty() {
        let nickname = character.nickname.as_deref().filter(|n| !n.is_empty());
        let named = filter
            .names
            .iter()
            .any(|n| *n == character.name || Some(n.as_str()) == nickname);
        if named == filter.is_exclude {
            return false;
        }
    }
    if !filter.tags.is_empty() {
        let tagged = filter.tags.iter().any(|t| character.tags.contains(t));
        if tagged == filter.is_exclude {
            return false;
        }
    }
    true
}

/// The recent chat text that keys are searched in.
struct Haystack {
    text: String,
    lower: String,
}

impl Haystack {
    /// The newest `depth` of `messages`, as one text.
    fn of(messages: &[ChatMessage], depth: usize) -> Self {
        let text = messages[messages.len().saturating_sub(depth)..]
            .iter()
            .map(|m| m.content.as_str())
            .collect::<Vec<_>>()
            .join("\n");
        Self {
            lower: text.to_lowercase(),
            text,
        }
    }

    fn matches_entry(&self, entry: &LorebookEntry) -> bool {
        if !entry.keys.iter().any(|key| self.matches(key, entry)) {
            return false;
        }
        if !entry.selective || entry.secondary_keys.is_empty() {
            return true;
        }
        let matched = entry
            .secondary_keys
            .iter()
            .filter(|key| self.matches(key, entry))
            .count();
        let any = matched > 0;
        let all = matched == entry.secondary_keys.len();
        match entry.selective_logic {
            SelectiveLogic::AndAny => any,
            SelectiveLogic::NotAll => !all,
            SelectiveLogic::NotAny => !any,
            SelectiveLogic::AndAll => all,
        }
    }

    fn matches(&self, key: &str, entry: &LorebookEntry) -> bool {
        if key.is_empty() {
            return false;
        }
        let pattern = if entry.use_regex {
            js_regex(key, entry.case_sensitive)
        } else if entry.match_whole_words {
            // A word character is an ASCII letter, digit or underscore, as in
            // JavaScript; so a key in a script without spaces (Japanese, Chinese)
            // still matches inside running text.
            let flags = if entry.case_sensitive { "" } else { "(?i)" };
            let edge = "[^A-Za-z0-9_]";
            format!(
                "{flags}(?:^|{edge}){}(?:$|{edge})",
                fancy_regex::escape(key)
            )
        } else if entry.case_sensitive {
            return self.text.contains(key);
        } else {
            return self.lower.contains(&key.to_lowercase());
        };
        // A pattern that is invalid or runs too long counts as no match: user
        // input, checked for every key on every message.
        Regex::new(&pattern).is_ok_and(|regex| regex.is_match(&self.text).unwrap_or(false))
    }
}

/// Turns a regex key into a pattern for this engine. The key is either a bare
/// pattern or JavaScript's `/pattern/flags`, whose `i`, `m` and `s` flags are kept.
fn js_regex(key: &str, case_sensitive: bool) -> String {
    let mut body = key.to_string();
    let mut flags = String::new();
    if !case_sensitive {
        flags.push('i');
    }
    if let Some(end) = key.rfind('/')
        && end > 1
        && key.starts_with('/')
        && key[end + 1..].bytes().all(|b| b.is_ascii_lowercase())
    {
        body = key[1..end].replace("\\/", "/");
        let js_flags = &key[end + 1..];
        if js_flags.contains('i') && case_sensitive {
            flags.push('i');
        }
        for flag in ['m', 's'] {
            if js_flags.contains(flag) {
                flags.push(flag);
            }
        }
    }
    if flags.is_empty() {
        body
    } else {
        format!("(?{flags}){body}")
    }
}

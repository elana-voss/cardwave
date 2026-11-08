//! Who replies next in a chat of several characters: the one the user picked
//! by hand, and without one whom the chat's turn order picks. A reply asked
//! of one character by name (`Generate::speaker_id`) goes past all of it.
//!
//! The three orders are those of the Flutter app
//! (`lib/group/src/utils/group_speaker_selection.dart`), with three
//! differences in the first of them: there the one who spoke last is never the
//! one named, so a user who names that one is answered by another; here a
//! message does not name the one who wrote it, as a character that tells of
//! itself by its name would else answer itself for good; and there a character
//! is named by its whole name only, here by a word of it too.
//!
//! Who is named (`named`, per message `named_in`): `places` is where a name
//! or a word stands as a whole word, `parts` the words of a name that name its
//! character by themselves, and `LITTLE` and `AFTER_NAME` the words that never
//! do. SillyTavern has any word of a name name its character
//! (`activateNaturalOrder` in its `public/scripts/group-chats.js`), "the"
//! too. Where a word ends `joined` says by the `Script` of the signs on either
//! side: a word ends where no letter, digit or `_` follows and where the
//! script changes; in Han, Hiragana and Katakana, which are written without
//! blanks, at every sign, so that a name of two signs or more is named
//! wherever it stands ("山田さん"), there being no dictionary to tell where a
//! word ends; and in Hangul, written with blanks but with what is said after a
//! name written onto it, after every sign ("민수야"). A name of one sign of
//! these is named only standing apart from signs of its kind, and a name that
//! ends in a sign that is no letter or digit goes on into a letter or digit
//! beside it ("Q." is not named in "q.e.d."). The first part of a "not" said
//! short ("don't") is no word (`negated`). A name's words (`words`) are cut
//! where the script changes too ("春野サクラ"), "ー" going with Hiragana as it
//! does with Katakana ("らーめん"); one of Han of three signs or more names by
//! its first and its last two signs or more as well ("山田太郎" by "山田" and
//! "太郎"), as such a name is mostly written without a blank, and one of
//! Hangul of three signs by its last two, the given name ("김민수" by "민수").
//! Thai, Lao, Khmer and Burmese, written without blanks as well, go by the
//! rule of letters: their vowel signs are no letters to
//! `char::is_alphanumeric`, so their words would want more than a list of
//! signs.
//!
//! `TurnOrder` is the three orders (`chats.turn_order`), and the character
//! picked by hand to reply in the order's place is `chats.replier_id`, which
//! the database forgets when that character leaves. `pick` picks among
//! `Candidate`s by what was `Said` and is given its chance as a number from 0
//! up to 1, so that a test says whom chance picks; `next` is what a reply
//! without a speaker asks (`prepare` in `api/generate.rs`); `set` sets the turn
//! (`PUT /api/chats/{id}/turn` with a `Turn`, `{"order": "list"}` or
//! `{"replier_id": 7}`, answered with the chat). No character is muted (the
//! second review of the v4 boards, 2026-10-17): the column
//! `chat_characters.muted` of before is read by nothing. How talkative a
//! character is, is its card's
//! `group-talkativeness` (`Document::talkativeness` in `ccv4/mod.rs`).
//!
//! The speaking order is `chat_characters.position`, the order the characters
//! joined in until the user moves one: `reorder` (`PUT
//! /api/chat-characters/{id}/position` with `{"position": 0}`, answered with
//! the chat) puts a character at a place and numbers the places anew from 0.
//! The order they joined in stays their IDs' (a new row's ID is above every
//! other's), which is what the chat is called after (`chats::find`, the
//! export, the chat's header).

use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::ops::Range;

use anyhow::bail;
use cw_core::{Code, Fail};
use cw_library::cards;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::chats::{Chat, NOT_IN_CHAT, ensure_kept, participants, path_to};

/// How many of the newest messages the natural order looks for a name in.
const READ_FOR_NAMES: usize = 2;

/// The words of a name that name nobody by themselves, as they are said all
/// the time or before another's name: "the" of "The Captain", "your" of "Your
/// Roommate", "of" of "Lady of the Lake", "dr" of "Dr. Reed", "de" and "la"
/// of "Marie de la Croix". A name that is one of them whole is a name ("Miss").
/// Not among them, as each is a name of its own too: "al", "ben", "don".
const LITTLE: &[&str] = &[
    // English: articles, prepositions and conjunctions, pronouns, and "who" (of "Doctor Who").
    "the", "an", "of", "and", "or", "in", "on", "at", "to", "for", "from", "with", "by", "as", "my",
    "your", "his", "her", "its", "our", "their", "you", "me", "he", "she", "it", "we", "they",
    "him", "them", "us", "who",
    // What stands before a name and is not said alone, and "miss", which is said of other things.
    "mr", "mrs", "ms", "mx", "dr", "jr", "sr", "st", "miss",
    // The little words of names in other languages.
    "de", "del", "della", "di", "da", "do", "dos", "das", "du", "des", "la", "le", "les", "los",
    "las", "el", "il", "lo", "van", "von", "der", "den", "die", "ter", "ten", "zu", "und", "et",
    "bin", "ibn",
];

/// What is said after a name in Japanese and names nobody by itself, as
/// [`LITTLE`]: "ちゃん" of "ハルちゃん". One of a single sign ("様") is no word
/// anyway.
const AFTER_NAME: &[&str] = &["さん", "さま", "くん", "ちゃん", "たん", "どの"];

/// How a chat picks who of several characters replies next.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum TurnOrder {
    /// The one the newest message names, else the one before it: the first,
    /// in speaking order, whose whole name stands there as whole words, in
    /// whatever case, and not inside a longer name of another's ("Mira" in
    /// "Mira Vale"); else the first of whose name a word stands there that
    /// none of the others has; else the first of whose name any word does.
    /// Such a word has two signs or more, a letter among them, is none of
    /// `LITTLE` and `AFTER_NAME`, and stands outside every whole name; neither
    /// stands before the "'t" of "don't". In Japanese and Chinese, written
    /// without blanks, a name or a word is named wherever it stands, and in
    /// Korean with what follows it written onto it (the module's head says
    /// how). A message names neither its own writer nor the newest one's, and
    /// nobody by a word of its own writer's name. Where
    /// nobody is named, as `Random`.
    #[default]
    Natural,
    /// The one after the one who spoke last, in speaking order as it stands
    /// when the reply is asked for, and after the last the first again.
    List,
    /// By chance, a character the more often the
    /// more talkative its card says it is, and not the one who spoke last
    /// while there is another.
    Random,
}

impl TurnOrder {
    /// What the order is called in the database and on the wire.
    pub fn name(self) -> &'static str {
        match self {
            Self::Natural => "natural",
            Self::List => "list",
            Self::Random => "random",
        }
    }
}

/// Who replies next in a chat, as it is set.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Turn {
    /// This order picks, and nobody is picked by hand any more.
    Order(TurnOrder),
    /// This chat character replies, until the turn is set again or it leaves.
    ReplierId(i64),
}

/// One of a chat's characters, as a turn order sees it.
#[derive(Clone, Debug, PartialEq)]
pub struct Candidate {
    /// The chat character.
    pub id: i64,
    /// What it is called in the chat.
    pub name: String,
    /// How readily it speaks up when nobody names it, from 0 to 1.
    pub talkativeness: f64,
}

/// A message, as a turn order sees it.
#[derive(Clone, Copy, Debug)]
pub struct Said<'a> {
    /// The chat character who wrote it; nobody for the user's and the narrator's.
    pub by: Option<i64>,
    pub words: &'a str,
}

/// Picks who of `cast`, a chat's characters in speaking order, replies to
/// `said`, the branch in view from its first message on. `chance` is a number
/// from 0 up to 1, drawn for this reply. Nobody only where there is no
/// character.
pub fn pick(order: TurnOrder, cast: &[Candidate], said: &[Said<'_>], chance: f64) -> Option<i64> {
    // Who of the characters wrote last, however long ago.
    let last = said.iter().rev().find_map(|message| message.by);
    match order {
        TurnOrder::Natural => named(cast, said).or_else(|| by_chance(cast, last, chance)),
        TurnOrder::List => after(cast, last),
        TurnOrder::Random => by_chance(cast, last, chance),
    }
}

/// The character the newest messages name; see [`TurnOrder::Natural`].
fn named(cast: &[Candidate], said: &[Said<'_>]) -> Option<i64> {
    let newest = said.last()?;
    let names: Vec<String> = cast.iter().map(|one| one.name.to_lowercase()).collect();
    said.iter().rev().take(READ_FOR_NAMES).find_map(|message| {
        let free = |one: &Candidate| Some(one.id) != message.by && Some(one.id) != newest.by;
        named_in(
            &message.words.to_lowercase(),
            message.by,
            cast,
            &names,
            free,
        )
    })
}

/// The character that `text`, a message of `by` in lower case, names among
/// those of `cast` that are `free` to be named; `names` are the cast's names
/// in lower case.
fn named_in(
    text: &str,
    by: Option<i64>,
    cast: &[Candidate],
    names: &[String],
    free: impl Fn(&Candidate) -> bool,
) -> Option<i64> {
    // Where each one's whole name stands, also of those that are not free: their names are theirs all the same.
    let whole: Vec<Vec<Range<usize>>> = names
        .iter()
        .map(|name| places(text, name).collect())
        .collect();
    let within = |place: &Range<usize>, other: &Range<usize>| {
        other.start <= place.start && place.end <= other.end
    };
    // A name inside a longer one of another's is a part of that one there.
    let said = |place: &Range<usize>| {
        let longer = |other: &Range<usize>| other.len() > place.len() && within(place, other);
        !whole.iter().flatten().any(longer)
    };
    let able = || (0..cast.len()).filter(|&at| free(&cast[at]));
    if let Some(at) = able().find(|&at| whole[at].iter().any(said)) {
        return Some(cast[at].id);
    }

    // The writer tells of itself by a word of its name too, which so names nobody.
    let writers: Vec<&str> = (0..cast.len())
        .filter(|&at| Some(cast[at].id) == by)
        .flat_map(|at| parts(&names[at]))
        .collect();
    let heard = |word: &&str| {
        let outside =
            |place: Range<usize>| !whole.iter().flatten().any(|name| within(&place, name));
        !writers.contains(word) && places(text, word).any(outside)
    };
    let told: Vec<(usize, Vec<&str>)> = able()
        .map(|at| (at, parts(&names[at]).into_iter().filter(heard).collect()))
        .collect();
    let own = |word: &&str| {
        told.iter()
            .filter(|(_, words)| words.contains(word))
            .count()
            == 1
    };
    told.iter()
        .find(|(_, words)| words.iter().any(own))
        .or_else(|| told.iter().find(|(_, words)| !words.is_empty()))
        .map(|&(at, _)| cast[at].id)
}

/// Whether a word goes on with this sign.
fn in_word(sign: char) -> bool {
    sign.is_alphanumeric() || sign == '_'
}

/// The script of a sign that a word goes on with, which says where a word
/// ends (`joined`) and where a name's words are cut (`words`).
#[derive(Clone, Copy, PartialEq, Eq)]
enum Script {
    /// Chinese characters, those used seldom too ("𠮷", "﨑"), with "々", "〆"
    /// and "〇".
    Han,
    Hiragana,
    /// With "ー".
    Katakana,
    Hangul,
    /// Every other letter, digit and "_".
    Other,
}

impl Script {
    /// The script of `sign`, and none where a word does not go on with it.
    fn of(sign: char) -> Option<Self> {
        if !in_word(sign) {
            return None;
        }
        Some(match u32::from(sign) {
            0x3005..=0x3007 | 0x3400..=0x4dbf | 0x4e00..=0x9fff | 0xf900..=0xfaff => Self::Han,
            0x20000..=0x3134f => Self::Han,
            0x3040..=0x309f => Self::Hiragana,
            0x30a0..=0x30ff => Self::Katakana,
            0x1100..=0x11ff | 0x3130..=0x318f | 0xac00..=0xd7af => Self::Hangul,
            _ => Self::Other,
        })
    }

    /// Whether it is written without blanks between words.
    fn blankless(self) -> bool {
        matches!(self, Self::Han | Self::Hiragana | Self::Katakana)
    }
}

/// Whether `outside`, the sign before a name that was found or, where `after`,
/// the one after it, goes on with `inside`, the name's sign at that end, into
/// one word, so that the name does not stand there as a word of its own. `one`
/// where the name is one sign, which then stands apart from signs of its kind.
/// A name's sign that is no letter or digit goes on into any that is ("Q." in
/// "q.e.d.").
fn joined(inside: char, outside: char, after: bool, one: bool) -> bool {
    let Some(outside) = Script::of(outside) else {
        return false;
    };
    let Some(inside) = Script::of(inside) else {
        return true;
    };
    match (inside, outside) {
        _ if inside.blankless() && outside.blankless() => one,
        // What is said after a name in Korean is written onto it ("민수야").
        (Script::Hangul, Script::Hangul) => one || !after,
        _ => inside == outside,
    }
}

/// Where `name` stands in `text` as a whole word, both in lower case: "al"
/// stands neither in "alice" nor in "although", "don" not in "don't", and
/// "山田" in "山田さん".
fn places<'a>(text: &'a str, name: &'a str) -> impl Iterator<Item = Range<usize>> + 'a {
    let mut signs = name.chars();
    // Nothing is found everywhere, and is no name.
    let ends = signs
        .next()
        .map(|first| (first, signs.next_back().unwrap_or(first)));
    let one = name.chars().nth(1).is_none();
    let found = ends.map(|ends| (ends, text.match_indices(name)));
    found.into_iter().flat_map(move |((first, last), found)| {
        found.filter_map(move |(at, found)| {
            let place = at..at + found.len();
            let rest = &text[place.end..];
            let before = text[..place.start].chars().next_back();
            let alone = !before.is_some_and(|sign| joined(first, sign, false, one))
                && !rest
                    .chars()
                    .next()
                    .is_some_and(|sign| joined(last, sign, true, one))
                && !negated(rest);
            alone.then_some(place)
        })
    })
}

/// Whether `rest`, what follows a word, makes it the first part of a "not"
/// said short ("don't", "can’t", "won't"), which is no name however it is
/// written.
fn negated(rest: &str) -> bool {
    let mut signs = rest.chars();
    matches!(signs.next(), Some('\'' | '’'))
        && signs.next() == Some('t')
        && !signs.next().is_some_and(in_word)
}

/// The words of `name`, which is in lower case, that name its character by
/// themselves: not a letter alone ("J." of "J. Marsh"), not a number ("47" of
/// "Agent 47"), and none of [`LITTLE`] and [`AFTER_NAME`]; of a word of Han
/// of three signs or more its first and its last two signs or more too ("山田"
/// and "太郎" of "山田太郎"), and of one of Hangul of three signs its last two
/// ("민수" of "김민수").
fn parts(name: &str) -> Vec<&str> {
    let mut parts = Vec::new();
    for word in words(name) {
        parts.push(word);
        let starts: Vec<usize> = word.char_indices().map(|(at, _)| at).collect();
        // A word of `words` is of one script, its first sign's.
        match word.chars().next().and_then(Script::of) {
            Some(Script::Han) if starts.len() > 2 => {
                parts.extend(starts[2..].iter().map(|&end| &word[..end]));
                let last = starts.len() - 1;
                parts.extend(starts[1..last].iter().map(|&start| &word[start..]));
            }
            Some(Script::Hangul) if starts.len() == 3 => parts.push(&word[starts[1]..]),
            _ => {}
        }
    }
    parts.retain(|word| {
        word.chars().nth(1).is_some()
            && word.chars().any(char::is_alphabetic)
            && !LITTLE.contains(word)
            && !AFTER_NAME.contains(word)
    });
    parts
}

/// The words `name` is written in: what stands between signs that are no
/// letter, digit or `_`, cut where the script changes ("春野" and "サクラ" of
/// "春野サクラ"), "ー" drawing out a sound of Hiragana too ("らーめん").
fn words(name: &str) -> Vec<&str> {
    let mut words = Vec::new();
    let mut word: Option<(usize, Script)> = None;
    let signs = name
        .char_indices()
        .map(|(at, sign)| (at, sign, Script::of(sign)));
    for (at, sign, script) in signs.chain([(name.len(), ' ', None)]) {
        if let Some((start, was)) = word {
            if script == Some(was) || (sign == 'ー' && was == Script::Hiragana) {
                continue;
            }
            words.push(&name[start..at]);
        }
        word = script.map(|script| (at, script));
    }
    words
}

/// The character after `last` in speaking order; see [`TurnOrder::List`].
fn after(cast: &[Candidate], last: Option<i64>) -> Option<i64> {
    let at = cast.iter().position(|one| Some(one.id) == last);
    let from = at.map_or(0, |at| at + 1);
    (!cast.is_empty()).then(|| cast[from % cast.len()].id)
}

/// A character by chance; see [`TurnOrder::Random`]. Where none of them is
/// talkative at all, each is as likely as the other.
fn by_chance(cast: &[Candidate], last: Option<i64>, chance: f64) -> Option<i64> {
    let others: Vec<&Candidate> = cast.iter().filter(|one| Some(one.id) != last).collect();
    let pool = if others.is_empty() {
        cast.iter().collect()
    } else {
        others
    };
    let silent = pool.iter().all(|one| one.talkativeness <= 0.0);
    let weight = |one: &Candidate| if silent { 1.0 } else { one.talkativeness };
    let mut left = chance * pool.iter().map(|one| weight(one)).sum::<f64>();
    for one in &pool {
        if left < weight(one) {
            return Some(one.id);
        }
        left -= weight(one);
    }
    // Rounding may leave the highest chance over: it is the last one's who can be picked.
    let last = pool.iter().rev().find(|one| weight(one) > 0.0);
    last.map(|one| one.id)
}

/// The chat character who writes the next reply in `chat`: the one picked by
/// hand, else whom the chat's turn order picks ([`pick`]) among its
/// characters, each under the name and as talkative as the version of its card
/// that the chat is with says. `chance` is a number from 0 up to 1. Nobody
/// where the chat has no character.
pub fn next(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat: &Chat,
    chance: f64,
) -> anyhow::Result<Option<i64>> {
    if chat.replier_id.is_some() {
        return Ok(chat.replier_id);
    }
    let characters = participants(db, user, chat.id)?;
    // A chat of one has nobody to pick among: its character replies, and no
    // card is read for it.
    if characters.len() < 2 {
        return Ok(characters.first().map(|one| one.id));
    }
    // Characters out of one card share its version, which is read once.
    let mut versions = HashMap::new();
    let mut cast = Vec::new();
    for one in characters {
        let document = match versions.entry(one.version_id) {
            Entry::Occupied(known) => known.into_mut(),
            Entry::Vacant(new) => new.insert(cards::document_of(db, one.version_id)?),
        };
        cast.push(Candidate {
            id: one.id,
            name: document.character_name(&one.character),
            talkativeness: document.talkativeness(&one.character),
        });
    }
    let branch = path_to(db, chat.id, chat.head_id)?;
    let said: Vec<Said<'_>> = branch
        .iter()
        .map(|message| Said {
            by: message.speaker_id,
            words: &message.content,
        })
        .collect();
    Ok(pick(chat.turn_order, &cast, &said, chance))
}

/// Sets who replies next in the chat, from the next reply on, also while one
/// is being written: by an order, or one of its characters every time. Not
/// in a chat that is in the Trash.
pub fn set(
    db: &dyn crate::chats::Storage,
    user: i64,
    chat_id: i64,
    turn: Turn,
) -> anyhow::Result<()> {
    ensure_kept(db, user, chat_id)?;
    match turn {
        Turn::Order(order) => {
            db.set_turn_order(chat_id, order)?;
        }
        Turn::ReplierId(replier) => {
            if !db.set_replier(chat_id, replier)? {
                bail!(
                    Fail::said(Code::NotPossible, NOT_IN_CHAT).with("what", "speaker_not_in_chat")
                );
            }
        }
    }
    Ok(())
}

/// What the turn order needs of the database, which `cw_store::chat_turns` gives.
pub trait Storage {
    /// Lets the chat's replier go by `order`.
    fn set_turn_order(&self, chat_id: i64, order: TurnOrder) -> anyhow::Result<()>;
    /// Has the chat's character `replier` reply every time: whether the chat has it.
    fn set_replier(&self, chat_id: i64, replier: i64) -> anyhow::Result<bool>;
    fn reorder_participant(
        &self,
        user: i64,
        participant_id: i64,
        place: usize,
    ) -> anyhow::Result<i64>;
}

/// Moves a character of a chat to `place` in the chat's speaking order, the
/// first being 0 and a place past the last the last, while the others keep
/// theirs among themselves; the orders go by it from the next reply on, also
/// while one is being written. The places are numbered anew from 0. Not in a
/// chat that is in the Trash. Answers with the chat.
pub fn reorder(
    db: &dyn Storage,
    user: i64,
    participant_id: i64,
    place: usize,
) -> anyhow::Result<i64> {
    db.reorder_participant(user, participant_id, place)
}

//! A reply's unfinished end trimmed, as the old Cardwave did; text in, text
//! out (`kept`): whether to trim is the caller's (`ReplyEnd::trims`). A
//! finished end is a sentence's end in prose (`sentences`), a closed code
//! block, or a list point or table row its line ends; what the kept text
//! holds open (a quotation, an action's asterisks, brackets) is closed. A
//! reply ending inside a code block gets the block closed, never cut inside
//! it. A cut keeping less than `KEEP_SHARE` and fewer than `KEEP_CHARS`
//! characters is not made. Every app language: its quotation marks paired by
//! position, never by sign (German „…“, Russian «…», Swedish ”…”); lengths in
//! characters; the marks are read once per reply (`closers_back`).
//! Traps: a quotation mark right after a digit (6", 5'10") opens nothing; an
//! asterisk that begins a list point or stands inside a word is no emphasis;
//! a list point or table row not ended by its line goes whole; a backtick
//! fence with another backtick on its line is inline code.

use std::borrow::Cow;
use std::sync::LazyLock;

use regex::Regex;

use super::sentences::{Abbreviations, TERMINALS, sentence_end};

#[cfg(test)]
mod tests;

/// `text` as it is kept after its reply's writing ended: from byte `from` on
/// (a continuation's part; 0 for a whole reply) [`trimmed`] where `trim`
/// says so, else as it came.
pub fn kept(text: &str, from: usize, trim: bool) -> Cow<'_, str> {
    match trim {
        true => trimmed(text, from),
        false => Cow::Borrowed(text),
    }
}

/// The least share of the trimmed part a cut keeps, in tenths (the old Cardwave's 40 %)...
const KEEP_SHARE: usize = 4;
/// ...or else the least characters it keeps.
const KEEP_CHARS: usize = 120;

/// What may follow a sentence's end and still belong to it: closing quotation
/// marks, an action's asterisk, brackets, a playful tilde.
const CLOSERS: &[char] = &[
    '"', '“', '”', '„', '‟', '«', '»', '‹', '›', '\'', '’', '*', '~', ')', ']', '}', '）', '】',
    '」', '』', '》',
];

/// Quotation marks that open or close by where they stand: the same sign
/// closes in one language what it opens in another (“ in German and English).
const QUOTES: &[char] = &['"', '“', '”', '„', '‟', '«', '»', '‹', '›'];

/// Brackets and the quotation marks of Chinese and Japanese, which open and
/// close by sign; the first four open only after a space, so that `f(x` and
/// `:(` open nothing.
const BRACKETS: &[(char, char)] = &[
    ('(', ')'),
    ('[', ']'),
    ('{', '}'),
    ('（', '）'),
    ('【', '】'),
    ('「', '」'),
    ('『', '』'),
    ('《', '》'),
];

/// A line that opens or closes a code block: up to three spaces, then three
/// or more backticks or tildes.
static FENCE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^ {0,3}(`{3,}|~{3,})").unwrap());
/// A list point's line: its mark, then a space or nothing more.
static LIST_POINT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\s*(?:[-*+]|\d{1,9}[.)])(?:\s|$)").unwrap());
/// A list point with no words.
static EMPTY_POINT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\s*(?:[-*+]|\d{1,9}[.)])\s*$").unwrap());
static TABLE_ROW: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^\s*\|").unwrap());
/// A character an emoji is made of: a pictograph, its variation selector,
/// joiner and skin tones, a flag's regional indicators, a keycap's mark, the
/// tags of a region's flag.
static EMOJI: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(concat!(
        r"^[\p{Extended_Pictographic}\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}",
        r"\u{1F1E6}-\u{1F1FF}\u{20E3}\u{E0020}-\u{E007F}]$"
    ))
    .unwrap()
});

fn emoji(c: char) -> bool {
    EMOJI.is_match(c.encode_utf8(&mut [0; 4]))
}

/// `text` from byte `from` on without its unfinished end: up to its last
/// finished end after `from`, with what it holds open closed; a code block it
/// ends inside closed. As it came where it has no finished end after `from`,
/// or the cut would keep too little of that part.
pub fn trimmed(text: &str, from: usize) -> Cow<'_, str> {
    let chars: Vec<char> = text.chars().collect();
    let from = text
        .get(..from)
        .map_or(chars.len(), |before| before.chars().count());
    let lines = lines(&chars);
    if let Some(Line {
        kind: Kind::Code(fence),
        ..
    }) = lines.last()
    {
        let mut closed = text.to_string();
        if !closed.ends_with('\n') {
            closed.push('\n');
        }
        closed.push_str(fence);
        return Cow::Owned(closed);
    }
    let code = code_mask(&chars, &lines);
    let whole: String = text.trim_end().to_string();
    let ends = finished_ends(&chars, &lines, &code, &Abbreviations::of(text));
    // The ends are in order: those after `from` are the last.
    let candidates = &ends[ends.partition_point(|&(end, _)| end <= from)..];
    let after: Vec<usize> = candidates.iter().map(|&(end, _)| end).collect();
    let closing = closers_back(&chars, &code, &after);
    for (&(end, may_close), closers) in candidates.iter().rev().zip(closing) {
        let Some(closers) = closers else {
            continue;
        };
        if !may_close && !closers.is_empty() {
            continue;
        }
        let mut cut: String = chars[..end]
            .iter()
            .collect::<String>()
            .trim_end()
            .to_string();
        cut.push_str(&closers);
        if cut == whole {
            return Cow::Borrowed(text);
        }
        let (kept, all) = (cut.chars().count().saturating_sub(from), chars.len() - from);
        return match kept >= KEEP_CHARS || kept * 10 >= all * KEEP_SHARE {
            true => Cow::Owned(cut),
            false => Cow::Borrowed(text),
        };
    }
    Cow::Borrowed(text)
}

/// What a line of the text is, by Markdown's reading.
#[derive(Debug, PartialEq)]
enum Kind {
    /// A line inside a code block, or the fence that opens it; the fence that
    /// would close it.
    Code(String),
    /// The fence that closes a code block.
    Closing,
    List,
    EmptyPoint,
    Table,
    Prose,
}

/// A line: its kind and where it begins and ends among the characters (its
/// end before its line break).
struct Line {
    kind: Kind,
    start: usize,
    end: usize,
}

/// The text's lines and their kinds.
fn lines(chars: &[char]) -> Vec<Line> {
    let mut lines = Vec::new();
    let mut open: Option<String> = None;
    let mut start = 0;
    while start <= chars.len() {
        let end = chars[start..]
            .iter()
            .position(|&c| c == '\n')
            .map_or(chars.len(), |at| start + at);
        let line: String = chars[start..end].iter().collect();
        let line = line.trim_end_matches('\r');
        // A backtick fence's line holds no other backtick (CommonMark): "```a``` b" is inline code.
        let fence = FENCE
            .captures(line)
            .filter(|found| {
                let run = found.get(1).expect("the fence's group");
                !(run.as_str().starts_with('`') && line[run.end()..].contains('`'))
            })
            .map(|found| found[1].to_string());
        let kind = match (&open, fence) {
            (Some(opened), Some(fence))
                if fence.starts_with(&opened[..1])
                    && fence.len() >= opened.len()
                    && line.trim().len() == fence.len() =>
            {
                open = None;
                Kind::Closing
            }
            (Some(opened), _) => Kind::Code(opened.clone()),
            (None, Some(fence)) => {
                open = Some(fence.clone());
                Kind::Code(fence)
            }
            (None, None) if EMPTY_POINT.is_match(line) => Kind::EmptyPoint,
            (None, None) if LIST_POINT.is_match(line) => Kind::List,
            (None, None) if TABLE_ROW.is_match(line) => Kind::Table,
            (None, None) => Kind::Prose,
        };
        lines.push(Line { kind, start, end });
        start = end + 1;
    }
    // Blank lines after the last say nothing of how it ends.
    while lines.len() > 1
        && lines.last().is_some_and(|line| {
            line.kind == Kind::Prose
                && chars[line.start..line.end]
                    .iter()
                    .all(|c| c.is_whitespace())
        })
    {
        lines.pop();
    }
    lines
}

/// Which characters are code: of a code block's lines, and inline code
/// between backticks.
fn code_mask(chars: &[char], lines: &[Line]) -> Vec<bool> {
    let mut code = vec![false; chars.len()];
    for line in lines {
        if matches!(line.kind, Kind::Code(_) | Kind::Closing) {
            code[line.start..line.end].fill(true);
        }
    }
    let mut at = 0;
    while at < chars.len() {
        if chars[at] != '`' || code[at] {
            at += 1;
            continue;
        }
        let run = chars[at..].iter().take_while(|&&c| c == '`').count();
        let after = at + run;
        // Its end is the next run of as many backticks.
        let mut look = after;
        let mut closed = None;
        while look < chars.len() {
            let next = chars[look..].iter().take_while(|&&c| c == '`').count();
            if next == run {
                closed = Some(look + next);
                break;
            }
            look += next.max(1);
        }
        match closed {
            Some(end) => {
                code[at..end].fill(true);
                at = end;
            }
            None => at = after,
        }
    }
    code
}

/// Where the text may end, in order, each with whether what it holds open
/// may be closed there: after a sentence's end or an emoji in prose (yes),
/// after a prose line that ends cleanly, a closed code block, or a list point
/// or table row its line ends (no).
fn finished_ends(
    chars: &[char],
    lines: &[Line],
    code: &[bool],
    abbreviations: &Abbreviations,
) -> Vec<(usize, bool)> {
    let roles = roles(chars, code);
    let mut ends = Vec::new();
    for line in lines {
        // A list point or table row its line break ends was finished.
        let broken = line.end < chars.len();
        let last = chars[line.start..line.end]
            .iter()
            .rposition(|c| !c.is_whitespace())
            .map(|last| line.start + last);
        match line.kind {
            Kind::Closing => ends.push((line.end, false)),
            Kind::List if broken || last.is_some_and(|last| clean(chars, &roles, last)) => {
                ends.push((line.end, true))
            }
            Kind::Table if broken || last.is_some_and(|last| chars[last] == '|') => {
                ends.push((line.end, false))
            }
            Kind::Prose => {
                for i in line.start..line.end {
                    if code[i] {
                        continue;
                    }
                    if TERMINALS.contains(&chars[i]) && sentence_end(chars, i, abbreviations) {
                        let mut end = i + 1;
                        while end < line.end
                            && CLOSERS.contains(&chars[end])
                            && roles[end] != Role::Opens
                        {
                            end += 1;
                        }
                        ends.push((end, true));
                    } else if emoji(chars[i])
                        && chars.get(i + 1).is_none_or(|&next| next.is_whitespace())
                    {
                        ends.push((i + 1, true));
                    }
                }
                if let Some(last) = last
                    && clean(chars, &roles, last)
                {
                    ends.push((last + 1, false));
                }
            }
            _ => {}
        }
    }
    ends.sort();
    ends.dedup_by_key(|(end, _)| *end);
    ends
}

/// Whether a line may end on the character at `at`: a sentence's end, a
/// closing mark or an emoji; a quotation mark or an asterisk only where it
/// closes (a lone `"` at the end opens or stands for nothing).
fn clean(chars: &[char], roles: &[Role], at: usize) -> bool {
    let c = chars[at];
    match c == '*' || QUOTES.contains(&c) {
        true => roles[at] == Role::Closes,
        false => TERMINALS.contains(&c) || CLOSERS.contains(&c) || emoji(c),
    }
}

/// What a character does as a mark that opens or closes.
#[derive(Clone, Copy, Debug, PartialEq)]
enum Role {
    Opens,
    Closes,
    Neither,
}

/// One mark held open: what closes it.
#[derive(Clone)]
struct Open {
    closer: String,
    /// Whether the same sign closes it (a quotation mark, asterisks), so that
    /// it cannot nest in itself.
    same: Option<String>,
}

/// Each character's role, read from the start as Markdown reads: an asterisk
/// run or a quotation mark opens where a word follows it and none stands
/// before, closes where one stands before and none follows, and between two
/// (Chinese 说：“你) closes what is open, else opens; a quotation mark after
/// a digit opens nothing. A run that begins a list point is no mark.
fn read_marks(chars: &[char], code: &[bool]) -> (Vec<Role>, Vec<Open>) {
    let mut roles = vec![Role::Neither; chars.len()];
    let mut open: Vec<Open> = Vec::new();
    let mut at = 0;
    while at < chars.len() {
        let (role, run, _) = mark(chars, code, at, &mut open);
        roles[at..at + run].fill(role);
        at += run;
    }
    (roles, open)
}

/// How many characters the mark at `at` spans: a run of asterisks, else one.
fn run_at(chars: &[char], code: &[bool], at: usize) -> usize {
    match chars[at] {
        '*' if !code[at] => chars[at..].iter().take_while(|&&c| c == '*').count(),
        _ => 1,
    }
}

/// What a mark changed in what is open, so that it can be undone.
enum Change {
    Opened,
    Closed(usize, Open),
}

/// Reads the mark at `at` as [`read_marks`] does, what it opens or closes
/// changed in `open`: its role, how many characters it spans and the change.
fn mark(
    chars: &[char],
    code: &[bool],
    at: usize,
    open: &mut Vec<Open>,
) -> (Role, usize, Option<Change>) {
    let c = chars[at];
    let run = run_at(chars, code, at);
    if code[at] {
        return (Role::Neither, run, None);
    }
    let before = at.checked_sub(1).map(|i| chars[i]);
    let after = chars.get(at + run).copied();
    let word_before = before.is_some_and(|c| !c.is_whitespace());
    let word_after = after.is_some_and(|c| !c.is_whitespace());
    let line_start = chars[..at]
        .iter()
        .rev()
        .take_while(|&&c| c != '\n')
        .all(|c| c.is_whitespace());
    let sign: String = chars[at..at + run].iter().collect();
    let (role, change) = if c == '*' || QUOTES.contains(&c) {
        if c == '*' && run == 1 && line_start && !word_after {
            (Role::Neither, None)
        } else {
            let last = open.iter().rposition(|held| match c {
                '*' => held.same.as_deref() == Some(sign.as_str()),
                _ => held
                    .same
                    .as_deref()
                    .is_some_and(|same| same.starts_with(QUOTES)),
            });
            let digit = before.is_some_and(|c| c.is_ascii_digit());
            match (word_before, word_after, last) {
                (true, _, Some(held)) => {
                    let closed = open.remove(held);
                    (Role::Closes, Some(Change::Closed(held, closed)))
                }
                // Inside a word only a quotation mark opens (Chinese 说：“你), never asterisks (f**k).
                (false, true, _) | (true, true, None)
                    if !(digit && c != '*') && !(word_before && c == '*') =>
                {
                    open.push(Open {
                        closer: closer_of(c, &sign),
                        same: Some(sign.clone()),
                    });
                    (Role::Opens, Some(Change::Opened))
                }
                _ => (Role::Neither, None),
            }
        }
    } else if let Some(&(_, closer)) = BRACKETS.iter().find(|(opener, _)| *opener == c) {
        match c.is_ascii() && word_before {
            true => (Role::Neither, None),
            false => {
                open.push(Open {
                    closer: closer.to_string(),
                    same: None,
                });
                (Role::Opens, Some(Change::Opened))
            }
        }
    } else if BRACKETS.iter().any(|(_, closer)| *closer == c) {
        match open
            .iter()
            .rposition(|held| held.same.is_none() && held.closer.starts_with(c))
        {
            Some(held) => {
                let closed = open.remove(held);
                (Role::Closes, Some(Change::Closed(held, closed)))
            }
            None => (Role::Neither, None),
        }
    } else {
        (Role::Neither, None)
    };
    (role, run, change)
}

fn roles(chars: &[char], code: &[bool]) -> Vec<Role> {
    read_marks(chars, code).0
}

/// What closes the mark `c` (or the asterisks `sign`) that opened.
fn closer_of(c: char, sign: &str) -> String {
    match c {
        '“' | '‟' => "”".into(),
        '„' => "“".into(),
        '«' => "»".into(),
        '»' => "«".into(),
        '‹' => "›".into(),
        '›' => "‹".into(),
        _ => sign.into(),
    }
}

/// What closes all that the text up to each of `ends` (ascending) holds
/// open, innermost first, as [`read_marks`] would read the text cut there,
/// given from the last end back and built only when asked for; `None` where
/// the same mark is open twice, which closing at the end cannot mend. The
/// marks are read once forward, each change kept; going back undoes them, and
/// only the mark an end cuts through is read again, on a copy of what is open.
fn closers_back<'a>(
    chars: &'a [char],
    code: &'a [bool],
    ends: &'a [usize],
) -> impl Iterator<Item = Option<String>> + 'a {
    let mut open: Vec<Open> = Vec::new();
    let mut changes: Vec<Change> = Vec::new();
    let mut at = 0;
    // Per end: how many changes stand before it and where its last whole mark ends.
    let marks: Vec<(usize, usize)> = ends
        .iter()
        .map(|&end| {
            while at < end && at + run_at(chars, code, at) < end {
                let (_, run, change) = mark(chars, code, at, &mut open);
                changes.extend(change);
                at += run;
            }
            (changes.len(), at)
        })
        .collect();
    ends.iter().zip(marks).rev().map(move |(&end, (made, at))| {
        while changes.len() > made {
            match changes.pop() {
                Some(Change::Opened) => drop(open.pop()),
                Some(Change::Closed(held, closed)) => open.insert(held, closed),
                None => {}
            }
        }
        let mut held = open.clone();
        let mut look = at;
        while look < end {
            look += mark(&chars[..end], &code[..end], look, &mut held).1;
        }
        closers(&held)
    })
}

/// What closes all that is `open`, innermost first; `None` where the same
/// mark is open twice.
fn closers(open: &[Open]) -> Option<String> {
    let twice = open.iter().enumerate().any(|(i, held)| {
        held.same.is_some() && open[i + 1..].iter().any(|other| other.same == held.same)
    });
    if twice {
        return None;
    }
    Some(open.iter().rev().map(|held| held.closer.as_str()).collect())
}

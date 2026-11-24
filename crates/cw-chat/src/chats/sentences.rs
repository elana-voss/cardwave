//! Where a sentence ends, in every app language: its marks (`TERMINALS`:
//! 。！？। beside .!?), and which dots end none: a decimal's, a word's
//! (example.com), an abbreviation's (`ABBREVIATIONS`, of the text's own
//! language where it is told, else of all), and one the sentence goes on
//! after in lower case. The trimmer finds a reply's last finished end by it;
//! `count` tells how many sentences a message has (the Reply length's hint).
//! Traps: an abbreviation matches only as a word of its own ("1st." and
//! "Bst." are none); a run of marks ("!?", "...") ends one sentence.

/// Ends that close a sentence, in every app language.
pub(super) const TERMINALS: &[char] = &[
    '.', '!', '?', '…', '。', '！', '？', '｡', '।', '॥', '‼', '⁇', '⁈', '⁉',
];

/// Abbreviations whose dot ends no sentence, per app language by its code,
/// lower case without their last dot. English leaves out "no", Russian "им",
/// which end sentences.
const ABBREVIATIONS: &[(&str, &[&str])] = &[
    (
        "en",
        &[
            "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc", "e.g", "i.e", "cf",
            "approx", "fig", "inc", "ltd", "mt",
        ],
    ),
    (
        "de",
        &[
            "z. b", "z.b", "d. h", "d.h", "u. a", "u.a", "usw", "bzw", "ca", "vgl", "evtl", "ggf",
            "nr", "str", "hr", "fr", "inkl", "sog", "s. o", "s. u", "u. ä",
        ],
    ),
    (
        "es",
        &[
            "sr", "sra", "srta", "dra", "ud", "uds", "p. ej", "pág", "núm", "aprox", "av", "lic",
        ],
    ),
    (
        "pt",
        &["sra", "dra", "p. ex", "pág", "av", "aprox", "exmo", "exma"],
    ),
    (
        "id",
        &["dll", "dsb", "dst", "yth", "bpk", "sdr", "jl", "tn", "ny"],
    ),
    ("vi", &["tp", "ths", "ts", "pgs", "gs", "bs", "v.v"]),
    (
        "ru",
        &[
            "т. д", "т.д", "т. е", "т.е", "т. п", "т.п", "др", "пр", "ул", "см", "напр", "стр",
            "тыс", "млн", "руб", "коп",
        ],
    ),
    ("hi", &["डॉ", "प्रो"]),
    // Chinese, Japanese and Korean end sentences with marks of their own, or
    // with a dot no abbreviation wears.
];

/// The abbreviations a text is read with: each as its characters, lower
/// case, with its last dot.
pub(super) struct Abbreviations(Vec<Vec<char>>);

impl Abbreviations {
    /// Those of the language `text` is written in; of every app language
    /// where it is not told or has none listed.
    pub(super) fn of(text: &str) -> Abbreviations {
        let own = cw_core::languages::detect(text)
            .and_then(|code| ABBREVIATIONS.iter().find(|(listed, _)| *listed == code));
        let lists: Vec<&[&str]> = match own {
            Some((_, list)) => vec![list],
            None => ABBREVIATIONS.iter().map(|(_, list)| *list).collect(),
        };
        Abbreviations(
            lists
                .into_iter()
                .flatten()
                .map(|short| short.chars().chain(['.']).collect())
                .collect(),
        )
    }
}

/// Whether the mark at `at` (one of `TERMINALS`) ends a sentence: a dot not
/// of a decimal, a word (example.com), an abbreviation (any of its dots, as
/// both of "z. B.") or a sentence that goes on in lower case.
pub(super) fn sentence_end(chars: &[char], at: usize, abbreviations: &Abbreviations) -> bool {
    if chars[at] != '.' {
        return true;
    }
    let next = chars.get(at + 1).copied();
    if next.is_some_and(char::is_alphanumeric) {
        return false;
    }
    if abbreviations
        .0
        .iter()
        .any(|short| abbreviation_at(chars, at, short))
    {
        return false;
    }
    let following = chars[at + 1..]
        .iter()
        .find(|&&c| c != ' ' && c != '\t' && !TERMINALS.contains(&c));
    !following.is_some_and(|c| c.is_lowercase())
}

/// Whether one of the dots of the abbreviation `short` (lower case, with its
/// last dot) stands at `at`, the abbreviation a word of its own: no letter or
/// digit before it ("1st.", "Bst." are none). Compared character by
/// character, none of the listed ones changing its length in lower case.
fn abbreviation_at(chars: &[char], at: usize, short: &[char]) -> bool {
    short
        .iter()
        .enumerate()
        .filter(|(_, c)| **c == '.')
        .any(|(dot, _)| {
            let Some(start) = at.checked_sub(dot) else {
                return false;
            };
            let Some(span) = chars.get(start..start + short.len()) else {
                return false;
            };
            span.iter()
                .zip(short)
                .all(|(c, s)| c.to_lowercase().eq(std::iter::once(*s)))
                && start
                    .checked_sub(1)
                    .is_none_or(|before| !chars[before].is_alphanumeric())
        })
}

/// How many sentences `text` has: each run of marks that ends one after a
/// word, and the words after the last; at least one.
pub fn count(text: &str) -> usize {
    let chars: Vec<char> = text.chars().collect();
    let abbreviations = Abbreviations::of(text);
    let (mut sentences, mut words) = (0, false);
    for (at, &c) in chars.iter().enumerate() {
        if c.is_alphanumeric() {
            words = true;
        } else if words
            && TERMINALS.contains(&c)
            && chars
                .get(at + 1)
                .is_none_or(|next| !TERMINALS.contains(next))
            && sentence_end(&chars, at, &abbreviations)
        {
            sentences += 1;
            words = false;
        }
    }
    (sentences + usize::from(words)).max(1)
}

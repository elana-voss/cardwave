//! The helpers the memory system shares, ported line by line from pmbench's
//! `memory.py` and `embed.py` (build spec, Part B2 and B3): the token estimate
//! (`count`), BM25 (`relevance`, A6), the walks that fit lines into a budget
//! (`fit`, `picked`, `pick`), `best_rank`, the rows of a helper's reply
//! (`rows`), cosine and reciprocal-rank fusion.
//!
//! Python's own behaviour is kept where it shows: lengths count code points,
//! `splitlines` breaks where Python's does, `split()`/`strip()` know Python's
//! whitespace, sorts are stable with the best score first.

use std::collections::HashMap;

/// Words BM25 leaves out (`STOP_WORDS`).
const STOP_WORDS: &[&str] = &[
    "a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "did", "do", "does", "for",
    "from", "had", "has", "have", "he", "her", "him", "his", "i", "in", "is", "it", "its", "me",
    "my", "no", "not", "of", "on", "or", "our", "she", "so", "that", "the", "their", "them",
    "they", "this", "to", "was", "we", "were", "what", "when", "where", "who", "with", "you",
    "your",
];

/// The estimate every budget of the memory counts in: `len(text) // 4 + 1`.
pub fn count(text: &str) -> usize {
    text.chars().count() / 4 + 1
}

/// Whether Python's `str.isspace` holds for `c`.
fn space(c: char) -> bool {
    c.is_whitespace() || ('\x1c'..='\x1f').contains(&c)
}

/// Python's `text.split()`.
pub fn split(text: &str) -> Vec<&str> {
    text.split(space).filter(|word| !word.is_empty()).collect()
}

/// Python's `text.strip()`.
pub(crate) fn strip(text: &str) -> &str {
    text.trim_matches(space)
}

/// Python's `" ".join(text.split())`.
pub(crate) fn collapse(text: &str) -> String {
    split(text).join(" ")
}

/// Python's `text.splitlines()`.
pub(crate) fn splitlines(text: &str) -> Vec<&str> {
    let mut out = Vec::new();
    let mut start = 0;
    let mut chars = text.char_indices().peekable();
    while let Some((at, c)) = chars.next() {
        if !matches!(
            c,
            '\n' | '\r'
                | '\x0b'
                | '\x0c'
                | '\x1c'
                | '\x1d'
                | '\x1e'
                | '\u{85}'
                | '\u{2028}'
                | '\u{2029}'
        ) {
            continue;
        }
        out.push(&text[start..at]);
        start = at + c.len_utf8();
        if c == '\r' && chars.peek().is_some_and(|(_, next)| *next == '\n') {
            chars.next();
            start += 1;
        }
    }
    if start < text.len() {
        out.push(&text[start..]);
    }
    out
}

/// The words BM25 counts: runs of `[a-z0-9]` of the lower-cased text, less the stop words.
pub fn words(text: &str) -> Vec<String> {
    let lower = text.to_lowercase();
    let mut out = Vec::new();
    let mut word = String::new();
    for c in lower.chars().chain(std::iter::once(' ')) {
        if c.is_ascii_lowercase() || c.is_ascii_digit() {
            word.push(c);
        } else if !word.is_empty() {
            if !STOP_WORDS.contains(&word.as_str()) {
                out.push(word.clone());
            }
            word.clear();
        }
    }
    out
}

/// The BM25 score of every doc for the query (A6), over exactly these docs.
pub(crate) fn relevance(docs: &[String], query: &str) -> Vec<f64> {
    if docs.is_empty() {
        return Vec::new();
    }
    let tfs: Vec<(HashMap<String, usize>, usize)> = docs
        .iter()
        .map(|doc| {
            let words = words(doc);
            let mut tf = HashMap::new();
            for word in &words {
                *tf.entry(word.clone()).or_insert(0) += 1;
            }
            (tf, words.len())
        })
        .collect();
    let mut df: HashMap<&str, usize> = HashMap::new();
    for (tf, _) in &tfs {
        for word in tf.keys() {
            *df.entry(word).or_insert(0) += 1;
        }
    }
    let n = docs.len() as f64;
    let total: usize = tfs.iter().map(|(_, len)| len).sum();
    let avg = total as f64 / n;
    let avg = if avg == 0.0 { 1.0 } else { avg };
    let mut asked = words(query);
    let mut seen = std::collections::HashSet::new();
    asked.retain(|word| seen.insert(word.clone()));
    tfs.iter()
        .map(|(tf, len)| {
            asked
                .iter()
                .filter_map(|word| {
                    let tf = *tf.get(word)? as f64;
                    let df = df[word.as_str()] as f64;
                    Some(
                        (1.0 + (n - df + 0.5) / (df + 0.5)).ln() * tf * 2.5
                            / (tf + 1.5 * (0.25 + 0.75 * *len as f64 / avg)),
                    )
                })
                .sum()
        })
        .collect()
}

/// The order of `scores`' indices, the best first; equal ones keep their order.
pub(crate) fn best_first(scores: &[f64]) -> Vec<usize> {
    let mut order: Vec<usize> = (0..scores.len()).collect();
    order.sort_by(|&a, &b| {
        scores[b]
            .partial_cmp(&scores[a])
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    order
}

/// The first lines that fit the budget; with `newest`, the last ones; with
/// `skip`, a line that does not fit is passed over and the walk goes on.
pub fn fit(lines: &[String], budget: usize, newest: bool, skip: bool) -> String {
    let mut out: Vec<&str> = Vec::new();
    let mut used = 0;
    let walk: Box<dyn Iterator<Item = &String>> = match newest {
        true => Box::new(lines.iter().rev()),
        false => Box::new(lines.iter()),
    };
    for line in walk {
        if used + count(line) + 1 > budget {
            if skip {
                continue;
            }
            break;
        }
        used += count(line) + 1;
        out.push(line);
    }
    if newest {
        out.reverse();
    }
    out.join("\n")
}

/// The indices of the best-scored lines that fit the budget, in their own
/// order; the walk stops at a score <= 0; with `skip`, a line that does not
/// fit is passed over and the walk goes on.
pub fn picked(lines: &[String], scores: &[f64], budget: usize, skip: bool) -> Vec<usize> {
    let mut chosen = Vec::new();
    let mut used = 0;
    for i in best_first(scores) {
        if scores[i] <= 0.0 {
            break;
        }
        if used + count(&lines[i]) + 1 > budget {
            if skip {
                continue;
            }
            break;
        }
        chosen.push(i);
        used += count(&lines[i]) + 1;
    }
    chosen.sort_unstable();
    chosen
}

/// The best-scored lines that fit the budget, shown in their own order.
pub fn pick(lines: &[String], scores: &[f64], budget: usize, skip: bool) -> String {
    picked(lines, scores, budget, skip)
        .into_iter()
        .map(|i| lines[i].as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

/// Each doc's best BM25 rank over the queries, as `1 / (1 + rank)`; 0 where no query matches it.
pub(crate) fn best_rank(docs: &[String], queries: &[String]) -> Vec<f64> {
    let mut best = vec![0.0; docs.len()];
    for query in queries {
        let rel = relevance(docs, query);
        let matched: Vec<usize> = best_first(&rel)
            .into_iter()
            .filter(|&i| rel[i] > 0.0)
            .collect();
        for (rank, i) in matched.into_iter().enumerate() {
            best[i] = f64::max(best[i], 1.0 / (1.0 + rank as f64));
        }
    }
    best
}

/// The `a | b | c` lines of a helper's reply, split and trimmed.
pub fn rows(reply: &str) -> Vec<Vec<String>> {
    let edge = |c: char| " -*".contains(c);
    splitlines(reply)
        .into_iter()
        .filter(|line| line.contains('|'))
        .map(|line| {
            line.trim_matches(|c| " -*|".contains(c))
                .split('|')
                .map(|cell| cell.trim_matches(edge).to_string())
                .collect()
        })
        .collect()
}

/// The cosine of two vectors, in double precision on their values as stored.
pub fn cosine(a: &[f32], b: &[f32]) -> f64 {
    let norm = |v: &[f32]| {
        v.iter()
            .fold(0.0, |sum, x| sum + f64::from(*x) * f64::from(*x))
            .sqrt()
    };
    let (na, nb) = (norm(a), norm(b));
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    let dot = a
        .iter()
        .zip(b)
        .fold(0.0, |sum, (x, y)| sum + f64::from(*x) * f64::from(*y));
    dot / (na * nb)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lines_break_and_words_split_as_python_has_them() {
        assert_eq!(splitlines("a\r\nb\rc\u{2028}d\n"), ["a", "b", "c", "d"]);
        assert_eq!(splitlines("\n"), [""]);
        assert!(splitlines("").is_empty());
        assert_eq!(collapse(" a \x1c b\t"), "a b");
        assert_eq!(words("Café, the 2 cats"), ["caf", "2", "cats"]);
    }
}

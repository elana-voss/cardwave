//! A model's thinking, told apart from its reply: what a provider sends as
//! `reasoning_content` or `reasoning` beside the reply's text (`provider::read_event`),
//! and a `<think>…</think>` part the text begins with (`Inline`). Thinking is
//! never stored, so it stays out of memory, copy, search and later prompts; a
//! chat shows only its newest sentence while the model thinks
//! (`newest_sentence`).
//!
//! Trap: the tags may arrive cut across pieces of the stream, so `Inline` holds
//! back what could still be the beginning of one.

const OPEN: &str = "<think>";
const CLOSE: &str = "</think>";

/// Where the reply's text stands with respect to a `<think>` part.
#[derive(Debug, Default)]
pub(crate) enum Inline {
    /// Nothing but space has come, or the beginning of `<think>`, held back.
    #[default]
    Start,
    /// Inside the part; what is held back may be the beginning of `</think>`.
    Inside,
    /// The reply itself.
    After,
}

/// Splits the reply's text as it arrives into thinking and words.
#[derive(Debug, Default)]
pub(crate) struct Splitter {
    state: Inline,
    held: String,
}

impl Splitter {
    /// Takes `text`, the next piece of the reply's text, and adds what is
    /// thinking to `thinking` and what is the reply to `words`. `end`: no more
    /// comes, so nothing is held back.
    pub fn take(&mut self, text: &str, end: bool, thinking: &mut String, words: &mut String) {
        self.held.push_str(text);
        loop {
            match self.state {
                Inline::Start => {
                    let begun = self.held.trim_start();
                    if let Some(rest) = begun.strip_prefix(OPEN) {
                        self.held = rest.to_string();
                        self.state = Inline::Inside;
                    } else if !end && OPEN.starts_with(begun) {
                        return;
                    } else {
                        self.state = Inline::After;
                    }
                }
                Inline::Inside => {
                    if let Some(at) = self.held.find(CLOSE) {
                        thinking.push_str(&self.held[..at]);
                        self.held = self.held[at + CLOSE.len()..].trim_start().to_string();
                        self.state = Inline::After;
                        continue;
                    }
                    // What could begin `</think>` stays held, unless the reply ends.
                    let keep = match end {
                        true => 0,
                        false => (1..CLOSE.len().min(self.held.len() + 1))
                            .rev()
                            .find(|&n| {
                                let from = self.held.len() - n;
                                self.held.is_char_boundary(from)
                                    && CLOSE.starts_with(&self.held[from..])
                            })
                            .unwrap_or(0),
                    };
                    let at = self.held.len() - keep;
                    thinking.push_str(&self.held[..at]);
                    self.held.drain(..at);
                    return;
                }
                Inline::After => {
                    words.push_str(&self.held);
                    self.held.clear();
                    return;
                }
            }
        }
    }
}

/// What a chat shows of the thinking so far: its newest sentence that has
/// ended, else the one being written; on one line, without the space around it.
pub fn newest_sentence(thinking: &str) -> &str {
    let text = thinking.trim_end();
    let ends = |c: char| ".!?…\n".contains(c);
    // The sentence being written is left aside while one before it has ended.
    let ended = match text.rfind(ends) {
        Some(at) => &text[..at + text[at..].chars().next().map_or(0, char::len_utf8)],
        None => text,
    };
    let ended = match ended.trim().is_empty() {
        true => text,
        false => ended,
    };
    let body = ended.trim_end_matches(ends);
    let start = body.rfind(ends).map_or(0, |at| {
        at + body[at..].chars().next().map_or(0, char::len_utf8)
    });
    ended[start..].trim()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn split(pieces: &[&str]) -> (String, String) {
        let mut splitter = Splitter::default();
        let (mut thinking, mut words) = (String::new(), String::new());
        for piece in pieces {
            splitter.take(piece, false, &mut thinking, &mut words);
        }
        splitter.take("", true, &mut thinking, &mut words);
        (thinking, words)
    }

    #[test]
    fn a_think_part_is_split_off_even_where_its_tags_are_cut() {
        let (thinking, words) = split(&[
            "\n<thi",
            "nk>She asks why",
            ". I should</th",
            "ink>\n\nThe tide",
            " turns.",
        ]);
        assert_eq!(
            (thinking.as_str(), words.as_str()),
            ("She asks why. I should", "The tide turns.")
        );
        assert_eq!(
            split(&["The <think> stays."]),
            (String::new(), "The <think> stays.".into())
        );
        assert_eq!(
            split(&["<", "b>Bold</b>"]),
            (String::new(), "<b>Bold</b>".into())
        );
        // A piece that brings nothing while nothing is held keeps the part open.
        assert_eq!(
            split(&["<think>The lamp is", "", " low.</think>Lit."]),
            ("The lamp is low.".into(), "Lit.".into())
        );
        // A part that never closes is thinking to its end.
        assert_eq!(
            split(&["<think>Still thinking </th"]),
            ("Still thinking </th".into(), String::new())
        );
    }

    #[test]
    fn the_newest_sentence_is_the_last_that_ended() {
        assert_eq!(
            newest_sentence("She asks why tonight"),
            "She asks why tonight"
        );
        assert_eq!(
            newest_sentence("She asks why. The tide is"),
            "She asks why."
        );
        assert_eq!(
            newest_sentence("She asks why. The tide is high!\n"),
            "The tide is high!"
        );
        assert_eq!(newest_sentence("First line\nsecond"), "First line");
        assert_eq!(newest_sentence("Wait… what?"), "what?");
        assert_eq!(newest_sentence(""), "");
    }
}

//! A reply's words as they arrive (`api::generate`): each round's taken into
//! the message whole (`take_words`; the provider keeps to the chat's length),
//! joined to the text before (`joint`), saved and pushed to the pages every
//! `PUSH_EVERY` with the newest sentence of the model's thinking (`Pushed`),
//! only when it changed, and when the first word came ("Reply statistics").

use std::pin::Pin;
use std::time::Duration;

use cw_chat::chats;
use cw_core::{Events, PageEvent};
use cw_provider::{self as provider, thinking};
use tokio::sync::futures::Notified;
use tokio::time::{Instant, sleep_until};

use super::Writer;

/// A reply's new text is saved and pushed to the pages at most this often.
const PUSH_EVERY: Duration = Duration::from_millis(100);

/// How much of a model's thinking is held to find its newest sentence in.
const THINKING_KEPT: usize = 4096;

/// What stands between a reply's text and what a continuation adds: nothing
/// after a space or a line's end, a new paragraph after a sentence's end, else
/// a space, as the reply was cut off inside a sentence.
fn joint(text: &str) -> &'static str {
    match text.chars().last() {
        None => "",
        Some(last) if last.is_whitespace() => "",
        Some(last) if ".!?…\"”'’*)]~".contains(last) => "\n\n",
        Some(_) => " ",
    }
}

/// How much of a reply's text the database and the pages have, in bytes and
/// in UTF-16 units, and when the next push is due. The database gets it
/// first, so a page that reads the chat never finds less than it was pushed.
/// The model's thinking is pushed as its newest sentence alone, and never kept.
pub(super) struct Pushed {
    pub(super) saved: usize,
    start: usize,
    due: Instant,
    /// The newest of the thinking, at most [`THINKING_KEPT`] bytes.
    thinking: String,
    /// Whether the pages have been told of the thinking as it is.
    told: bool,
    /// The thinking's line the pages were told last, since words came.
    line: String,
    /// Whether any thinking came (`kinds::saw_thinking`).
    pub(super) thought: bool,
    /// When the reply's first word came ("Reply statistics").
    pub(super) first_word: Option<Instant>,
}

impl Pushed {
    /// Nothing pushed yet past what `content` holds.
    pub(super) fn new(content: &str) -> Self {
        Self {
            saved: content.len(),
            start: content.encode_utf16().count(),
            due: Instant::now(),
            thinking: String::new(),
            told: true,
            line: String::new(),
            thought: false,
            first_word: None,
        }
    }

    /// Saves what `content` holds past what is saved, and pushes it to the pages.
    pub(super) async fn flush(
        &mut self,
        writer: &Writer,
        message_id: i64,
        content: &str,
    ) -> anyhow::Result<()> {
        let (state, user, chat_id) = (&writer.state, writer.user, writer.chat_id);
        if let Some(line) = self.thought() {
            let thought = PageEvent::ReplyThinking {
                chat_id,
                message_id,
                line,
            };
            state.push(user, &thought);
        }
        if self.saved == content.len() {
            return Ok(());
        }
        let text = content[self.saved..].to_string();
        let text = state
            .work(move |db| chats::write_reply(db, user, message_id, &text).map(|()| text))
            .await?;
        self.saved = content.len();
        let length = text.encode_utf16().count();
        let start = self.start;
        state.push(
            user,
            &PageEvent::ReplyText {
                chat_id,
                message_id,
                start,
                text,
            },
        );
        self.said(length);
        Ok(())
    }

    /// Counts `length` UTF-16 units of words pushed. The pages put the
    /// thinking's line away when words come, so the next is told even where equal.
    fn said(&mut self, length: usize) {
        self.start += length;
        self.line.clear();
    }

    /// The thinking's newest sentence where the pages have not been told it.
    fn thought(&mut self) -> Option<String> {
        if self.told {
            return None;
        }
        self.told = true;
        let line = thinking::newest_sentence(&self.thinking);
        if line == self.line {
            return None;
        }
        self.line = line.to_string();
        Some(self.line.clone())
    }

    /// Takes more of the model's thinking, to be told at the next push.
    fn think(&mut self, more: &str) {
        if more.is_empty() {
            return;
        }
        self.thought = true;
        self.thinking.push_str(more);
        if self.thinking.len() > THINKING_KEPT {
            let mut from = self.thinking.len() - THINKING_KEPT / 2;
            while !self.thinking.is_char_boundary(from) {
                from += 1;
            }
            self.thinking.drain(..from);
        }
        self.told = false;
    }
}

/// Reads one round's words from `reply` into `content`, saving and pushing
/// them and the model's thinking every [`PUSH_EVERY`], until the round ends:
/// `false` when the reply is stopped first, or its words drift into another
/// character's lines (`others`, `chats::drift`), where they are cut. The
/// round's words begin at their first, joined to the text before by
/// [`joint`].
pub(super) async fn take_words(
    writer: &Writer,
    (message_id, pushed, content): (i64, &mut Pushed, &mut String),
    (reply, others): (&mut provider::Reply, &[String]),
    mut stopped: Pin<&mut Notified<'_>>,
) -> anyhow::Result<bool> {
    let begun = content.len();
    loop {
        tokio::select! {
            biased;
            _ = &mut stopped => return Ok(false),
            _ = sleep_until(pushed.due), if pushed.saved < content.len() || !pushed.told => {
                pushed.flush(writer, message_id, content).await?;
                pushed.due = Instant::now() + PUSH_EVERY;
            }
            piece = reply.next_piece() => {
                let Some(piece) = piece? else {
                    return Ok(true);
                };
                pushed.think(&piece.thinking);
                let words = match content.len() > begun {
                    true => piece.words.as_str(),
                    false => piece.words.trim_start(),
                };
                if !words.is_empty() && content.len() == begun {
                    content.push_str(joint(content));
                }
                content.push_str(words);
                if !words.is_empty() {
                    pushed.first_word.get_or_insert_with(Instant::now);
                }
                if let Some(at) = chats::characters::drift(&content[begun..], others) {
                    // What the pages were told past it goes with the reply's end, which tells them the whole.
                    let own = content[..begun + at].trim_end().len().max(begun);
                    content.truncate(own);
                    return Ok(false);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Pushed;

    #[test]
    fn the_thinking_is_told_only_when_its_line_changed() {
        let mut pushed = Pushed::new("");
        pushed.think("She asks why. The tide");
        assert_eq!(pushed.thought().as_deref(), Some("She asks why."));
        pushed.think(" is");
        assert_eq!(pushed.thought(), None);
        pushed.think(" high! And");
        assert_eq!(pushed.thought().as_deref(), Some("The tide is high!"));
        assert_eq!(pushed.thought(), None);
        // Words came, which put the line away, and the next round thinks the same.
        pushed.said(4);
        pushed.think(" ");
        assert_eq!(pushed.thought().as_deref(), Some("The tide is high!"));
    }
}

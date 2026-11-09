//! A text as the model's tokens: SentencePiece's unigram model, read from the
//! model's `tokenizer.model` (a protobuf) without SentencePiece's own code, as
//! the voice spike did through the crate `tokenizers`.
//!
//! `encode` writes each space as "▁", puts one before the text, and cuts it
//! into the pieces whose scores sum highest (Viterbi); a character no piece
//! holds becomes the pieces of its UTF-8 bytes (`<0x41>`), where the model has
//! them, else the unknown piece. `decode` puts the pieces back together, with
//! spaces for "▁" and none before the text.

use std::collections::HashMap;

use anyhow::{Context, ensure};
use cw_core::{Code, Fail};

const SPACE: char = '\u{2581}';

/// SentencePiece's kinds of piece, of which only normal and user-defined ones
/// match a text.
const UNKNOWN: u64 = 2;
const CONTROL: u64 = 3;
const BYTE: u64 = 6;

pub(crate) struct Pieces {
    /// Each piece that can match a text, with its id and score.
    matching: HashMap<String, (u32, f64)>,
    /// Every piece by its id.
    all: Vec<String>,
    /// The longest piece, in characters.
    longest: usize,
    unknown: u32,
    unknown_score: f64,
    /// The pieces of the 256 bytes, where the model has them.
    bytes: Vec<Option<u32>>,
}

impl Pieces {
    /// The model of a `tokenizer.model` file.
    pub fn read(file: &[u8]) -> anyhow::Result<Self> {
        let mut vocabulary = Vec::new();
        let mut at = 0;
        while at < file.len() {
            let (tag, next) = varint(file, at)?;
            at = next;
            if tag == (1 << 3 | 2) {
                let (length, next) = varint(file, at)?;
                let end = next + length as usize;
                ensure!(
                    end <= file.len(),
                    Fail::said(Code::Internal, "the tokenizer cannot be read")
                );
                vocabulary.push(piece(&file[next..end])?);
                at = end;
            } else {
                at = skip(tag & 7, file, at)?;
            }
        }
        Self::new(vocabulary)
    }

    /// The model of these pieces, each with its score and kind, in the order of their ids.
    pub fn new(vocabulary: Vec<(String, f64, u64)>) -> anyhow::Result<Self> {
        let unknown = vocabulary
            .iter()
            .position(|(_, _, kind)| *kind == UNKNOWN)
            .context(Fail::said(
                Code::Internal,
                "the tokenizer has no unknown piece",
            ))?;
        let lowest = vocabulary
            .iter()
            .map(|(_, score, _)| *score)
            .fold(f64::INFINITY, f64::min);
        let mut bytes = vec![None; 256];
        let mut matching = HashMap::new();
        for (id, (text, score, kind)) in vocabulary.iter().enumerate() {
            match *kind {
                BYTE => {
                    let value = text
                        .strip_prefix("<0x")
                        .and_then(|rest| rest.strip_suffix('>'))
                        .and_then(|hex| u8::from_str_radix(hex, 16).ok());
                    if let Some(value) = value {
                        bytes[value as usize] = Some(id as u32);
                    }
                }
                UNKNOWN | CONTROL => {}
                _ => {
                    matching.insert(text.clone(), (id as u32, *score));
                }
            }
        }
        Ok(Self {
            longest: matching
                .keys()
                .map(|text| text.chars().count())
                .max()
                .unwrap_or(1),
            matching,
            all: vocabulary.into_iter().map(|(text, _, _)| text).collect(),
            unknown: unknown as u32,
            unknown_score: lowest - 10.0,
            bytes,
        })
    }

    pub fn encode(&self, text: &str) -> Vec<u32> {
        let text: String = std::iter::once(SPACE)
            .chain(text.chars().map(|c| if c == ' ' { SPACE } else { c }))
            .collect();
        let starts: Vec<usize> = text
            .char_indices()
            .map(|(at, _)| at)
            .chain([text.len()])
            .collect();
        let count = starts.len() - 1;
        // The best way to each place: its score, where it came from and with which piece (none: unknown).
        let mut best: Vec<Option<(f64, usize, Option<u32>)>> = vec![None; count + 1];
        best[0] = Some((0.0, 0, None));
        for from in 0..count {
            let Some((score, _, _)) = best[from] else {
                continue;
            };
            let mut single = false;
            for to in from + 1..=count.min(from + self.longest) {
                if let Some(&(id, own)) = self.matching.get(&text[starts[from]..starts[to]]) {
                    single |= to == from + 1;
                    take(&mut best[to], (score + own, from, Some(id)));
                }
            }
            if !single {
                take(
                    &mut best[from + 1],
                    (score + self.unknown_score, from, None),
                );
            }
        }
        let mut found = Vec::new();
        let mut at = count;
        while at > 0 {
            // Each place reaches the next, by a piece of one character or the unknown step.
            let (_, from, id) = best[at].expect("every place is reached");
            found.push(match id {
                Some(id) => vec![id],
                None => self.unknown_as_bytes(&text[starts[from]..starts[at]]),
            });
            at = from;
        }
        found.into_iter().rev().flatten().collect()
    }

    /// A character no piece holds, as the pieces of its bytes, or as the unknown piece.
    fn unknown_as_bytes(&self, text: &str) -> Vec<u32> {
        text.bytes()
            .map(|byte| self.bytes[byte as usize])
            .collect::<Option<Vec<u32>>>()
            .unwrap_or_else(|| vec![self.unknown])
    }

    pub fn decode(&self, ids: &[u32]) -> String {
        let mut bytes = Vec::new();
        for &id in ids {
            let Some(text) = self.all.get(id as usize) else {
                continue;
            };
            match self.bytes.iter().position(|byte| *byte == Some(id)) {
                Some(byte) => bytes.push(byte as u8),
                None => bytes.extend_from_slice(text.as_bytes()),
            }
        }
        let text = String::from_utf8_lossy(&bytes).replace(SPACE, " ");
        text.strip_prefix(' ').map(str::to_string).unwrap_or(text)
    }

    /// Where `tokens` are cut so that no piece holds more than `most`: before
    /// the last word that fits, else at the limit, never inside a character.
    pub fn cuts_within(&self, tokens: &[u32], most: usize) -> Vec<usize> {
        let most = most.max(1);
        let starts_word = |id: u32| {
            self.all
                .get(id as usize)
                .is_some_and(|text| text.starts_with(SPACE))
        };
        // A UTF-8 continuation byte (10xxxxxx) goes on the character before it.
        let inside = |id: u32| {
            self.bytes
                .iter()
                .position(|byte| *byte == Some(id))
                .is_some_and(|byte| byte & 0xC0 == 0x80)
        };
        let mut cuts = vec![0];
        let mut start = 0;
        while tokens.len() - start > most {
            let end = start + most;
            let at = (start + 1..=end)
                .rev()
                .find(|&i| starts_word(tokens[i]))
                .or_else(|| (start + 1..=end).rev().find(|&i| !inside(tokens[i])))
                .unwrap_or(end);
            cuts.push(at);
            start = at;
        }
        cuts.push(tokens.len());
        cuts
    }
}

/// Keeps the better of the way at a place and `way`.
fn take(at: &mut Option<(f64, usize, Option<u32>)>, way: (f64, usize, Option<u32>)) {
    if at.is_none_or(|(score, _, _)| way.0 > score) {
        *at = Some(way);
    }
}

/// One piece of the protobuf: its text (1), score (2) and kind (3, normal unless said).
fn piece(bytes: &[u8]) -> anyhow::Result<(String, f64, u64)> {
    let (mut text, mut score, mut kind, mut at) = (String::new(), 0.0, 1, 0);
    while at < bytes.len() {
        let (tag, next) = varint(bytes, at)?;
        at = next;
        match (tag >> 3, tag & 7) {
            (1, 2) => {
                let (length, next) = varint(bytes, at)?;
                let end = next + length as usize;
                ensure!(
                    end <= bytes.len(),
                    Fail::said(Code::Internal, "the tokenizer cannot be read")
                );
                text = String::from_utf8_lossy(&bytes[next..end]).into_owned();
                at = end;
            }
            (2, 5) => {
                ensure!(
                    at + 4 <= bytes.len(),
                    Fail::said(Code::Internal, "the tokenizer cannot be read")
                );
                score = f64::from(f32::from_le_bytes(bytes[at..at + 4].try_into()?));
                at += 4;
            }
            (3, 0) => {
                let (value, next) = varint(bytes, at)?;
                kind = value;
                at = next;
            }
            (_, wire) => at = skip(wire, bytes, at)?,
        }
    }
    Ok((text, score, kind))
}

fn varint(bytes: &[u8], mut at: usize) -> anyhow::Result<(u64, usize)> {
    let (mut value, mut shift) = (0u64, 0);
    loop {
        let byte = *bytes
            .get(at)
            .context(Fail::said(Code::Internal, "the tokenizer cannot be read"))?;
        at += 1;
        value |= u64::from(byte & 0x7f) << shift;
        if byte & 0x80 == 0 {
            return Ok((value, at));
        }
        shift += 7;
        ensure!(
            shift < 64,
            Fail::said(Code::Internal, "the tokenizer cannot be read")
        );
    }
}

fn skip(wire: u64, bytes: &[u8], at: usize) -> anyhow::Result<usize> {
    Ok(match wire {
        0 => varint(bytes, at)?.1,
        1 => at + 8,
        2 => {
            let (length, next) = varint(bytes, at)?;
            next + length as usize
        }
        5 => at + 4,
        _ => anyhow::bail!(Fail::said(Code::Internal, "the tokenizer cannot be read")),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn model() -> Pieces {
        let normal = |text: &str, score| (text.to_string(), score, 1);
        Pieces::new(vec![
            ("<unk>".into(), 0.0, UNKNOWN),
            ("<s>".into(), 0.0, CONTROL),
            normal("▁the", -1.0),
            normal("▁th", -3.0),
            normal("e", -3.0),
            normal("▁", -2.0),
            normal("a", -2.0),
            normal("t", -2.0),
            normal("▁cat", -1.5),
            ("<0xC3>".into(), 0.0, BYTE),
            ("<0xA9>".into(), 0.0, BYTE),
        ])
        .unwrap()
    }

    #[test]
    fn a_text_is_cut_into_the_pieces_that_score_highest() {
        // "▁the" (-1) beats "▁th" + "e" (-6); "▁cat" (-1.5) beats "▁" "c"… (no "c": unknown).
        assert_eq!(model().encode("the cat"), vec![2, 8]);
    }

    #[test]
    fn a_character_no_piece_holds_becomes_its_bytes_or_the_unknown_piece() {
        // "é" is C3 A9; "ö" (C3 B6) has no piece of its second byte.
        assert_eq!(model().encode("é"), vec![5, 9, 10]);
        assert_eq!(model().encode("ö"), vec![5, 0]);
    }

    #[test]
    fn pieces_are_put_back_together_with_spaces_and_bytes() {
        let model = model();
        assert_eq!(model.decode(&model.encode("the cat")), "the cat");
        assert_eq!(model.decode(&[5, 9, 10]), "é");
    }

    #[test]
    fn a_long_run_is_cut_before_a_word_else_at_the_limit_between_characters() {
        let model = model();
        assert_eq!(
            model.cuts_within(&model.encode("the cat the cat the cat"), 3),
            [0, 3, 6]
        );
        // "▁" C3 A9 C3 A9: never between C3 and A9.
        assert_eq!(model.cuts_within(&model.encode("éé"), 2), [0, 1, 3, 5]);
        assert_eq!(model.cuts_within(&model.encode("the cat"), 2), [0, 2]);
    }
}

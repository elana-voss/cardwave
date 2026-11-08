//! Token estimate used for budgeting until a real tokenizer is wired in.

/// Estimates the tokens in `text` from its writing systems: tokens per character
/// differ widely under BPE tokenizers (about 0.25 for English, 1.0 for CJK), so a
/// flat chars/4 rule under-counts non-Latin text two to four times.
pub fn estimate(text: &str) -> usize {
    text.chars().map(tokens_per_char).sum::<f64>().ceil() as usize
}

fn tokens_per_char(c: char) -> f64 {
    match c as u32 {
        // ASCII: English and code, about 4 characters per token.
        0..0x80 => 0.25,
        // European alphabets: Latin supplements and extensions, Greek, Cyrillic.
        0x80..0x530 => 0.5,
        // Latin Extended Additional (Vietnamese) and Greek Extended.
        0x1E00..0x2000 => 0.5,
        // CJK ideographs, kana, CJK punctuation and compatibility blocks.
        0x2E80..0xA000 => 1.0,
        // Hangul syllables.
        0xAC00..0xD800 => 1.0,
        // Supplementary planes: rare CJK ideographs, emoji, symbols.
        0x10000.. => 1.0,
        // Everything else: Hebrew, Arabic, Indic scripts, Thai, symbols.
        _ => 0.75,
    }
}

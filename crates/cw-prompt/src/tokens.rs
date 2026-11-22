//! Token estimate used for budgeting until a real tokenizer is wired in. The
//! prompt is filled to 90 % of what the reply leaves of the model's window
//! (`builder.rs`), so the estimate must not fall under 90 % of what a real
//! tokenizer counts; its rates are set by the hungrier
//! of cl100k (GPT-4) and o200k (GPT-4o) over a sample of each writing system
//! (the test), so English is over-counted by about a sixth.

/// Estimates the tokens in `text` from its writing systems: tokens per character
/// differ widely under BPE tokenizers (about 0.25 for English words, 1 or more for
/// CJK, Greek, Hebrew and Indic scripts), so a flat chars/4 rule under-counts
/// most text other than English prose.
pub fn estimate(text: &str) -> usize {
    text.chars().map(tokens_per_char).sum::<f64>().ceil() as usize
}

fn tokens_per_char(c: char) -> f64 {
    match c as u32 {
        // ASCII letters, digits and spaces: English words, about 4 per token.
        _ if c.is_ascii_alphanumeric() || c == ' ' => 0.25,
        // ASCII punctuation, symbols and line ends: code and JSON, often one each.
        0..0x80 => 0.75,
        // Latin supplements and extensions (German, French, Vietnamese).
        0x80..0x370 => 1.0,
        // Greek.
        0x370..0x400 => 1.0,
        // Cyrillic.
        0x400..0x530 => 0.5,
        // Hebrew.
        0x590..0x600 => 1.25,
        // Arabic.
        0x600..0x700 => 0.75,
        // Indic scripts (Devanagari to Malayalam).
        0x900..0xE00 => 1.25,
        // Latin Extended Additional (Vietnamese) and Greek Extended.
        0x1E00..0x2000 => 1.0,
        // CJK ideographs, kana, CJK punctuation and compatibility blocks.
        0x2E80..0xA000 => 1.25,
        // Hangul syllables.
        0xAC00..0xD800 => 1.25,
        // Supplementary planes: emoji (often several tokens each), rare CJK.
        0x10000.. => 2.5,
        // Everything else: Thai, other scripts, symbols, joiners.
        _ => 1.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Each writing system's sample and its tokens under the hungrier of two
    /// real tokenizers, cl100k (GPT-4) and o200k (GPT-4o), measured once with
    /// tiktoken-rs 0.7 (2026-11-23).
    const MEASURED: &[(&str, usize, &str)] = &[
        (
            "english",
            51,
            r#"The rain had not stopped for three days, and the old lighthouse keeper was beginning to talk to the gulls. "You again," he said, when the grey one landed on the railing. It tilted its head as if it understood every word."#,
        ),
        (
            "code",
            73,
            r#"{"name": "Mira", "tags": ["fantasy", "rogue"], "stats": {"hp": 42, "mp": 7}} fn main() { let x = vec![1, 2, 3]; println!("{:?}", x.iter().map(|n| n * 2).collect::<Vec<_>>()); }"#,
        ),
        (
            "german",
            53,
            r#"Der Regen hatte seit drei Tagen nicht aufgehört, und der alte Leuchtturmwärter begann, mit den Möwen zu sprechen. „Du schon wieder", sagte er, als die graue auf dem Geländer landete."#,
        ),
        (
            "russian",
            88,
            r#"Дождь не прекращался уже три дня, и старый смотритель маяка начал разговаривать с чайками. «Опять ты», — сказал он, когда серая села на перила. Она наклонила голову, будто понимала каждое слово."#,
        ),
        (
            "greek",
            136,
            r#"Η βροχή δεν είχε σταματήσει εδώ και τρεις μέρες, και ο γέρος φαροφύλακας άρχισε να μιλάει στους γλάρους. «Πάλι εσύ», είπε, όταν ο γκρίζος κάθισε στο κάγκελο."#,
        ),
        (
            "vietnamese",
            74,
            r#"Mưa đã không ngừng suốt ba ngày, và người gác hải đăng già bắt đầu nói chuyện với lũ hải âu. "Lại là mày à," ông nói, khi con chim xám đậu trên lan can."#,
        ),
        (
            "chinese",
            80,
            r#"雨已经连续下了三天，老灯塔看守人开始和海鸥说话。“又是你，”当那只灰色的海鸥落在栏杆上时，他说。它歪着头，好像听懂了每一个字。"#,
        ),
        (
            "japanese",
            74,
            r#"雨は三日間降り続いていて、年老いた灯台守はカモメに話しかけるようになっていた。「またお前か」と、灰色の一羽が手すりに降りたとき彼は言った。"#,
        ),
        (
            "korean",
            81,
            r#"비가 사흘 동안 그치지 않았고, 늙은 등대지기는 갈매기들에게 말을 걸기 시작했다. "또 너구나," 회색 갈매기가 난간에 내려앉자 그가 말했다."#,
        ),
        (
            "arabic",
            88,
            r#"لم يتوقف المطر منذ ثلاثة أيام، وبدأ حارس المنارة العجوز يتحدث إلى طيور النورس. قال عندما حط الرمادي على السياج: «أنت مرة أخرى»."#,
        ),
        (
            "hebrew",
            106,
            r#"הגשם לא פסק כבר שלושה ימים, ושומר המגדלור הזקן התחיל לדבר עם השחפים. "שוב אתה," אמר, כשהאפור נחת על המעקה."#,
        ),
        (
            "hindi",
            140,
            r#"तीन दिनों से बारिश नहीं रुकी थी, और बूढ़ा प्रकाशस्तंभ रक्षक सीगलों से बात करने लगा था। "फिर से तुम," उसने कहा, जब भूरा पक्षी रेलिंग पर उतरा।"#,
        ),
        (
            "thai",
            110,
            r#"ฝนไม่หยุดตกมาสามวันแล้ว และผู้ดูแลประภาคารชราเริ่มพูดคุยกับนกนางนวล "เจ้าอีกแล้ว" เขาพูดเมื่อตัวสีเทาบินมาเกาะราวกันตก"#,
        ),
        (
            "emoji",
            43,
            r#"She laughed 😂😂 and sent back 🌧️🏠🕯️ then ❤️🔥✨ — "see you at 🌅" 🙌🎉"#,
        ),
    ];

    /// The prompt is filled to 90 % of what the reply leaves of the window: an
    /// estimate under 90 % of the real count would take the reply's room.
    #[test]
    fn no_writing_system_is_undercounted_past_the_reply_reserve() {
        let under: Vec<_> = MEASURED
            .iter()
            .filter(|(_, real, text)| (estimate(text) as f64) < 0.9 * *real as f64)
            .map(|(name, real, text)| format!("{name}: {} of {real}", estimate(text)))
            .collect();
        assert!(under.is_empty(), "undercounted: {under:?}");
    }
}

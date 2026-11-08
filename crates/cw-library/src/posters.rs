//! Which of its mood's two poster designs a card takes (the page "Cardwave Posters", "Mood and design"): the letter
//! its mood has fewer of; on a tie the opposite of the most similar earlier card of the mood, by the mean colour of
//! the pictures; the first, or a tie with nothing to compare, "a". Given once, to a card that has a mood and no
//! letter, and kept with the card: neither a new description nor a new picture changes it. Reads the picture but no
//! model, so it runs wherever the app does. A card with no picture that is art keeps no means.
//!
//! Also what the description call writes for a poster: a tagline and a `Mood`. One that does not fit is kept empty
//! and the card shows Gallery's plain tile (`docs/design.md`, Posters), no call more being spent on it.

use image::imageops::FilterType;
use serde::Serialize;
use ts_rs::TS;

use crate::cards::pictures::is_art;

/// The longest tagline: the poster's design holds no more.
const MOST_WORDS: usize = 8;
const MOST_CHARS: usize = 42;

/// Which of a poster's looks a card takes. `Horror` holds thrillers, `Fantasy` what is cosy.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Mood {
    Horror,
    Romance,
    Drama,
    Action,
    SciFi,
    Comedy,
    Fantasy,
}

impl Mood {
    /// As it is stored.
    pub fn word(self) -> &'static str {
        match self {
            Self::Horror => "horror",
            Self::Romance => "romance",
            Self::Drama => "drama",
            Self::Action => "action",
            Self::SciFi => "sci_fi",
            Self::Comedy => "comedy",
            Self::Fantasy => "fantasy",
        }
    }

    /// The word as the model or the store has it, in any case, "sci-fi" and "sci fi" too.
    pub fn read(said: &str) -> Option<Self> {
        let word = said.trim().to_lowercase().replace(['-', ' '], "_");
        [
            Self::Horror,
            Self::Romance,
            Self::Drama,
            Self::Action,
            Self::SciFi,
            Self::Comedy,
            Self::Fantasy,
        ]
        .into_iter()
        .find(|mood| mood.word() == word)
    }
}

/// The model's tagline on one line without its outer quotes; empty where it is over the limits.
pub(crate) fn tagline(said: &str) -> String {
    let line = said.split_whitespace().collect::<Vec<_>>().join(" ");
    let line = line.trim_matches(['"', '\u{201c}', '\u{201d}']).trim();
    if line.split(' ').count() > MOST_WORDS || line.chars().count() > MOST_CHARS {
        return String::new();
    }
    line.to_string()
}

/// Which of its mood's two designs a card takes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum Letter {
    A,
    B,
}

impl Letter {
    /// As it is stored and sent.
    pub fn word(self) -> &'static str {
        match self {
            Self::A => "a",
            Self::B => "b",
        }
    }

    pub fn read(word: &str) -> Option<Self> {
        match word {
            "a" => Some(Self::A),
            "b" => Some(Self::B),
            _ => None,
        }
    }

    fn other(self) -> Self {
        match self {
            Self::A => Self::B,
            Self::B => Self::A,
        }
    }
}

/// A picture's mean L*, a*, b* and C*.
pub type Means = [f64; 4];

/// A card with a mood and no letter.
pub struct Waiting {
    pub card: i64,
    pub user: i64,
    pub mood: String,
    /// Its newest version's picture, where it has one.
    pub picture: Option<Vec<u8>>,
}

/// A card of the same mood that has its letter.
pub struct Earlier {
    pub letter: Letter,
    pub means: Option<Means>,
}

/// What giving letters needs of the database, which `cw_store::posters` gives.
pub trait Storage {
    /// The card described longest ago, of whoever's, that has a mood and no letter.
    fn next_without_letter(&self) -> anyhow::Result<Option<Waiting>>;
    /// The cards of `user`'s of `mood` that have their letter.
    fn letters_of_mood(&self, user: i64, mood: &str) -> anyhow::Result<Vec<Earlier>>;
    /// Keeps the letter, where the card has none yet.
    fn keep_letter(&self, card: i64, letter: Letter, means: Option<Means>) -> anyhow::Result<()>;
}

/// Gives the next waiting card its letter. Answers whether there was one.
pub fn give_once(db: &dyn Storage) -> anyhow::Result<bool> {
    let Some(waiting) = db.next_without_letter()? else {
        return Ok(false);
    };
    let means = waiting.picture.as_deref().and_then(means_of);
    let earlier = db.letters_of_mood(waiting.user, &waiting.mood)?;
    db.keep_letter(waiting.card, letter_for(means, &earlier), means)?;
    Ok(true)
}

/// Gives every waiting card its letter.
pub fn give_all(db: &dyn Storage) -> anyhow::Result<()> {
    while give_once(db)? {}
    Ok(())
}

fn letter_for(means: Option<Means>, earlier: &[Earlier]) -> Letter {
    let of_a = earlier.iter().filter(|e| e.letter == Letter::A).count();
    let of_b = earlier.len() - of_a;
    if of_a != of_b {
        return if of_a < of_b { Letter::A } else { Letter::B };
    }
    let Some(means) = means else {
        return Letter::A;
    };
    earlier
        .iter()
        .filter_map(|e| Some((distance(&means, &e.means?), e.letter)))
        .min_by(|one, other| one.0.total_cmp(&other.0))
        .map_or(Letter::A, |(_, nearest)| nearest.other())
}

fn distance(one: &Means, other: &Means) -> f64 {
    one.iter()
        .zip(other)
        .map(|(a, b)| (a - b) * (a - b))
        .sum::<f64>()
        .sqrt()
}

/// The means of a picture scaled to 40 by 60; none where it is no art or cannot be read.
fn means_of(file: &[u8]) -> Option<Means> {
    if !is_art(file) {
        return None;
    }
    let small = image::load_from_memory(file)
        .ok()?
        .resize_exact(40, 60, FilterType::Triangle)
        .to_rgb8();
    let mut sum = [0.0; 4];
    for pixel in small.pixels() {
        let [l, a, b] = lab(pixel.0);
        for (total, value) in sum.iter_mut().zip([l, a, b, a.hypot(b)]) {
            *total += value;
        }
    }
    let count = f64::from(small.width() * small.height());
    Some(sum.map(|total| total / count))
}

/// CIELAB of an sRGB colour, D65 white.
fn lab(rgb: [u8; 3]) -> [f64; 3] {
    let [r, g, b] = rgb.map(|value| {
        let v = f64::from(value) / 255.0;
        if v <= 0.04045 {
            v / 12.92
        } else {
            ((v + 0.055) / 1.055).powf(2.4)
        }
    });
    let f = |t: f64| {
        if t > 216.0 / 24389.0 {
            t.cbrt()
        } else {
            (24389.0 / 27.0 * t + 16.0) / 116.0
        }
    };
    let x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
    let y = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
    let z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
    [116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z)]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cards::pictures::MIN_ART;

    fn earlier(letter: Letter, l: f64) -> Earlier {
        Earlier {
            letter,
            means: Some([l, 0.0, 0.0, 0.0]),
        }
    }

    #[test]
    fn the_first_of_a_mood_takes_a() {
        assert_eq!(letter_for(Some([50.0; 4]), &[]), Letter::A);
    }

    #[test]
    fn a_card_takes_the_letter_its_mood_has_fewer_of() {
        let one_a = [earlier(Letter::A, 90.0)];
        assert_eq!(letter_for(Some([90.0; 4]), &one_a), Letter::B);
        let one_b = [earlier(Letter::B, 90.0)];
        assert_eq!(letter_for(None, &one_b), Letter::A);
    }

    #[test]
    fn on_a_tie_a_card_takes_the_opposite_of_the_most_similar() {
        let both = [earlier(Letter::A, 90.0), earlier(Letter::B, 10.0)];
        assert_eq!(letter_for(Some([85.0, 0.0, 0.0, 0.0]), &both), Letter::B);
        assert_eq!(letter_for(Some([15.0, 0.0, 0.0, 0.0]), &both), Letter::A);
    }

    #[test]
    fn a_tie_with_nothing_to_compare_takes_a() {
        let both = [earlier(Letter::B, 10.0), earlier(Letter::A, 90.0)];
        assert_eq!(letter_for(None, &both), Letter::A);
        let unread = |letter| Earlier {
            letter,
            means: None,
        };
        let blind = [unread(Letter::B), unread(Letter::A)];
        assert_eq!(letter_for(Some([50.0; 4]), &blind), Letter::A);
    }

    #[test]
    fn a_picture_means_its_colours_and_a_small_one_means_nothing() {
        let file = |side: u32| {
            let white = image::RgbImage::from_pixel(side, side, image::Rgb([255, 255, 255]));
            let mut file = std::io::Cursor::new(Vec::new());
            white.write_to(&mut file, image::ImageFormat::Png).unwrap();
            file.into_inner()
        };
        let [l, a, b, c] = means_of(&file(MIN_ART)).unwrap();
        assert!((l - 100.0).abs() < 0.1 && a.abs() < 0.1 && b.abs() < 0.1 && c.abs() < 0.1);
        assert_eq!(means_of(&file(MIN_ART - 1)), None);
        assert_eq!(means_of(b"no picture"), None);
    }

    #[test]
    fn a_tagline_over_either_limit_is_kept_empty_and_its_quotes_go() {
        assert_eq!(
            tagline(" \"Some nights\n only  lead away.\" "),
            "Some nights only lead away."
        );
        assert_eq!(tagline("one two three four five six seven eight nine"), "");
        assert_eq!(tagline(&"x".repeat(43)), "");
        assert_eq!(tagline(&"x".repeat(42)).len(), 42);
    }

    #[test]
    fn a_mood_is_read_as_the_model_may_write_it_and_another_word_is_none() {
        assert_eq!(Mood::read(" Sci-Fi"), Some(Mood::SciFi));
        assert_eq!(Mood::read("sci fi"), Some(Mood::SciFi));
        assert_eq!(Mood::read(Mood::SciFi.word()), Some(Mood::SciFi));
        assert_eq!(Mood::read("slice of life"), None);
        assert_eq!(Mood::read(""), None);
    }
}

//! What a copy of a thing is called: one rule for presets, prompt presets and
//! a card's lorebook copied into the library.

/// How many signs of the word for a copy, in the user's language, a copy's
/// name takes ("Rig (copy)"); the page sends the word with the request.
pub const COPY_WORD: usize = 20;

/// What a copy of `base` is called, `word` being the word for a copy in the
/// user's language and `taken` saying which names are in use: "… (copy)", and
/// from the second on "… (copy 2)". A name over `limit` signs with that end
/// loses the end of `base`, and a space the cut leaves.
pub fn copy_name(word: &str, base: &str, limit: usize, taken: impl Fn(&str) -> bool) -> String {
    let word: String = word.trim().chars().take(COPY_WORD).collect();
    (1..)
        .map(|n| {
            let end = if n == 1 {
                format!(" ({word})")
            } else {
                format!(" ({word} {n})")
            };
            let room = limit.saturating_sub(end.chars().count());
            let start: String = base.chars().take(room).collect();
            format!("{}{end}", start.trim_end())
        })
        .find(|name| !taken(name))
        // `(1..)` never ends, and a user has finitely many things to name.
        .expect("a name not taken")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_copy_takes_the_first_free_number_and_fits_the_limit() {
        let taken = ["Rig (copy)", "Rig (copy 2)"];
        assert_eq!(
            copy_name(" copy ", "Rig", 60, |name| taken.contains(&name)),
            "Rig (copy 3)"
        );
        assert_eq!(copy_name("copy", "Long name", 12, |_| false), "Long (copy)");
        let word = "w".repeat(30);
        assert_eq!(
            copy_name(&word, "R", 60, |_| false),
            format!("R ({})", "w".repeat(COPY_WORD))
        );
    }
}

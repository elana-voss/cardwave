//! What the model is told of a pick, as the extension's `buildResponse` says:
//! a flat JSON object, the first name's tags, the surname's own where one is
//! given (`last_name_*`), the pantheon where the name has one, and the filters
//! dropped (`relaxed_filters`) where any were, and last the note that the
//! name is the narrator's until revealed (`reveal`, 5ff9fb2). Its fields are
//! the database's `TAGS`, in the extension's order rather than theirs.

use serde::Serialize;

use super::picker::Picked;

/// Sent with every name, the last thing the model reads before it writes on
/// (the extension's `REVEAL_NOTE`, 5ff9fb2).
pub(crate) const REVEAL: &str = "The narrator's knowledge: write this name only once the user's character hears or reads it (someone says it, it is written somewhere visible), unless the card or the user's instructions say how names are revealed; until then, describe this person.";

/// The answer, its fields in the extension's order.
#[derive(Serialize)]
struct Answer<'a> {
    first_name: &'a str,
    gender: &'a Option<String>,
    language_ethnicity: &'a str,
    race: &'a Option<String>,
    age: &'a [String],
    era: &'a [String],
    role: &'a [String],
    intelligence: &'a Option<String>,
    allure: &'a Option<String>,
    commonness: &'a Option<String>,
    genre: &'a [String],
    themes: &'a [String],
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    last: Option<Surname<'a>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    mythology: Option<&'a str>,
    #[serde(skip_serializing_if = "<[_]>::is_empty")]
    relaxed_filters: &'a [&'static str],
    reveal: &'static str,
}

/// The surname's fields; it carries no intelligence, age or gender.
#[derive(Serialize)]
struct Surname<'a> {
    last_name: &'a str,
    last_name_role: &'a [String],
    last_name_allure: &'a Option<String>,
    last_name_commonness: &'a Option<String>,
    last_name_genre: &'a [String],
    last_name_themes: &'a [String],
}

/// `picked` as the model reads it.
pub(crate) fn of(picked: &Picked) -> String {
    let first = picked.first;
    let answer = Answer {
        first_name: &first.name,
        gender: &first.gender,
        language_ethnicity: &first.language_ethnicity,
        race: &first.race,
        age: &first.age,
        era: &first.era,
        role: &first.role,
        intelligence: &first.intelligence,
        allure: &first.allure,
        commonness: &first.commonness,
        genre: &first.genre,
        themes: &first.themes,
        last: picked.last.map(|last| Surname {
            last_name: &last.name,
            last_name_role: &last.role,
            last_name_allure: &last.allure,
            last_name_commonness: &last.commonness,
            last_name_genre: &last.genre,
            last_name_themes: &last.themes,
        }),
        mythology: first.mythology.as_deref().filter(|name| !name.is_empty()),
        relaxed_filters: &picked.relaxed,
        reveal: REVEAL,
    };
    // Strings and lists of strings alone: it cannot fail.
    serde_json::to_string(&answer).unwrap_or_default()
}

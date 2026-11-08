//! The languages the app names: "Language the AI writes in" (Settings) and a
//! card's languages (`ccv4::languages`), each by its ISO 639-1 code as CCV4's
//! `language` key holds it (section 3.3) and named in English, as the screens
//! name them. The crate `whatlang` (which language a text is in, [`detect`])
//! and `sys-locale` (this computer's, [`of_computer`]) are named here only.
//! Also the code of the app's language file for a locale ([`file_code`]),
//! which the page's `appCode` must match (both tested by one table).
//!
//! Trap: a code is compared by its first part, whatever its case ([`same`]):
//! "en-US" is "en", and "no-NO" "nb".

use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Each language: its code, its code in ISO 639-3 (as `whatlang` names it)
/// and its English name; the board's eight first, the others by name.
const LANGUAGES: [(&str, &str, &str); 28] = [
    ("en", "eng", "English"),
    ("de", "deu", "German"),
    ("fr", "fra", "French"),
    ("it", "ita", "Italian"),
    ("es", "spa", "Spanish"),
    ("pt", "por", "Portuguese"),
    ("nl", "nld", "Dutch"),
    ("pl", "pol", "Polish"),
    ("ar", "ara", "Arabic"),
    ("zh", "cmn", "Chinese"),
    ("cs", "ces", "Czech"),
    ("da", "dan", "Danish"),
    ("fi", "fin", "Finnish"),
    ("el", "ell", "Greek"),
    ("he", "heb", "Hebrew"),
    ("hi", "hin", "Hindi"),
    ("hu", "hun", "Hungarian"),
    ("id", "ind", "Indonesian"),
    ("ja", "jpn", "Japanese"),
    ("ko", "kor", "Korean"),
    ("nb", "nob", "Norwegian"),
    ("ro", "ron", "Romanian"),
    ("ru", "rus", "Russian"),
    ("sv", "swe", "Swedish"),
    ("th", "tha", "Thai"),
    ("tr", "tur", "Turkish"),
    ("uk", "ukr", "Ukrainian"),
    ("vi", "vie", "Vietnamese"),
];

/// The language the AI writes in where the computer's is none of these.
pub(crate) const FALLBACK: &str = "en";

/// A language as the screens list it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Language {
    pub code: String,
    /// Its English name ("German").
    pub name: String,
}

/// Every language the app names, in its menus' order.
pub fn all() -> Vec<Language> {
    LANGUAGES
        .iter()
        .map(|(code, _, name)| Language {
            code: code.to_string(),
            name: name.to_string(),
        })
        .collect()
}

/// The first part of a code, in small letters: "en-US" is "en". Norwegian's
/// other codes are "nb", and the old codes of Hebrew and Indonesian the new.
fn primary(code: &str) -> String {
    let first = code
        .trim()
        .split(['-', '_'])
        .next()
        .unwrap_or_default()
        .to_ascii_lowercase();
    match first.as_str() {
        "no" | "nn" => "nb".to_string(),
        "iw" => "he".to_string(),
        "in" => "id".to_string(),
        _ => first,
    }
}

/// Whether two codes name one language.
pub fn same(one: &str, other: &str) -> bool {
    let one = primary(one);
    !one.is_empty() && one == primary(other)
}

/// The app's code for `code` ("en-US" is "en"), where the app knows it.
pub fn known(code: &str) -> Option<&'static str> {
    LANGUAGES
        .iter()
        .find(|(own, ..)| same(own, code))
        .map(|(own, ..)| *own)
}

/// What the screens call the language `code`: its English name, else the code itself.
pub fn name_of(code: &str) -> String {
    LANGUAGES
        .iter()
        .find(|(own, ..)| same(own, code))
        .map_or_else(|| code.trim().to_string(), |(.., name)| name.to_string())
}

/// The language `text` is written in, where it is one the app knows and
/// `whatlang` is sure of it (a short text it is often not).
pub fn detect(text: &str) -> Option<&'static str> {
    let info = whatlang::detect(text)?;
    if !info.is_reliable() {
        return None;
    }
    let found = info.lang().code();
    LANGUAGES
        .iter()
        .find(|(_, long, _)| *long == found)
        .map(|(code, ..)| *code)
}

/// This computer's locale ("zh-TW"), its region and script kept, tidied by
/// [`tidy_locale`]; [`FALLBACK`] where it tells none.
pub fn computer_locale() -> String {
    sys_locale::get_locale().map_or_else(|| FALLBACK.to_string(), |raw| tidy_locale(&raw))
}

/// A locale without its codeset or modifier ("zh_TW.UTF-8" is "zh-TW"), its
/// first part the new code ("in-ID" is "id-ID"), parts joined by "-".
fn tidy_locale(raw: &str) -> String {
    let bare = raw.split(['.', '@']).next().unwrap_or_default();
    let mut parts = bare.split(['-', '_']);
    let first = primary(parts.next().unwrap_or_default());
    std::iter::once(first.as_str())
        .chain(parts)
        .collect::<Vec<_>>()
        .join("-")
}

/// The regions whose Chinese is traditional where no script is named, as
/// Intl's `maximize` (CLDR's likely subtags) has them, old codes ("uk") too.
const TRADITIONAL: [&str; 18] = [
    "au", "bn", "gb", "gf", "hk", "id", "mo", "pa", "pf", "ph", "pz", "sr", "th", "tw", "uk", "us",
    "vd", "vn",
];

/// The code of the app's language file for `locale` ("zh_TW.UTF-8"): its
/// language as [`tidy_locale`] leaves it ("in" is "id"), but Portuguese as
/// Brazil's ("pt-BR"), and Chinese "zh-Hant" where the script or else the
/// region says traditional ([`TRADITIONAL`]), else "zh-Hans". The
/// page's `appCode` (language.ts) gives the same, both tested by
/// `web/src/language/file-codes.json`.
pub fn file_code(locale: &str) -> String {
    let tidy = tidy_locale(locale);
    let mut parts = tidy.split('-');
    let first = parts.next().unwrap_or_default();
    match first {
        "pt" => "pt-BR".to_string(),
        "zh" => {
            let rest: Vec<String> = parts.map(str::to_ascii_lowercase).collect();
            let traditional = match rest.iter().find(|part| part.len() == 4) {
                Some(script) => script == "hant",
                None => rest
                    .first()
                    .is_some_and(|region| TRADITIONAL.contains(&region.as_str())),
            };
            String::from(if traditional { "zh-Hant" } else { "zh-Hans" })
        }
        _ => first.to_string(),
    }
}

/// This computer's language, where the app knows it; else [`FALLBACK`].
pub fn of_computer() -> &'static str {
    sys_locale::get_locale()
        .and_then(|locale| known(&locale))
        .unwrap_or(FALLBACK)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_code_is_known_by_its_first_part_and_its_other_names() {
        assert_eq!(known("en-US"), Some("en"));
        assert_eq!(known("no-NO"), Some("nb"));
        assert_eq!(known("nn"), Some("nb"));
        assert_eq!(known("iw"), Some("he"));
        assert_eq!(known("xx"), None);
    }

    #[test]
    fn a_locale_loses_its_codeset_and_old_code_but_keeps_region_and_script() {
        assert_eq!(tidy_locale("zh_TW.UTF-8"), "zh-TW");
        assert_eq!(tidy_locale("zh-Hant-HK@euro"), "zh-Hant-HK");
        assert_eq!(tidy_locale("in-ID"), "id-ID");
        assert_eq!(tidy_locale("de"), "de");
    }

    /// The table the page's `appCode` (language.ts) is tested by too.
    #[test]
    fn a_locale_has_the_file_code_the_page_gives_it() {
        let table = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .ancestors()
            .nth(2)
            .unwrap()
            .join("web/src/language/file-codes.json");
        let table: std::collections::BTreeMap<String, String> =
            serde_json::from_str(&std::fs::read_to_string(table).unwrap()).unwrap();
        for (locale, code) in table {
            assert_eq!(file_code(&locale), code, "{locale}");
        }
        assert_eq!(file_code("zh_TW.UTF-8"), "zh-Hant");
        assert_eq!(file_code("pt_BR.UTF-8@euro"), "pt-BR");
        assert_eq!(file_code(""), "");
    }

    #[test]
    fn a_text_too_short_to_tell_has_no_language() {
        assert_eq!(detect("Ok."), None);
        let long =
            "She is dry and watchful, and she keeps her own counsel at every feast of the court.";
        assert_eq!(detect(long), Some("en"));
    }
}

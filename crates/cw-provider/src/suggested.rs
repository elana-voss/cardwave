//! The background model first run suggests where the provider is one that
//! `providers/suggested.toml` names (its head says what it holds): the newest
//! model of the first family of its list that the provider offers ([`of`]).
//! Guidance only: `picks` opens with it, the user changes it, nothing stores it.
//!
//! A family is words, not a version: a model counts in it when its name holds
//! each word and besides them only numbers, sizes and "instruct" ([`member`]),
//! so a thinking variant, a finetune or another size is not counted. The newest
//! is by models.dev's release where it knows both, else by the version in the
//! names, a number of four digits or more being a date that counts after it
//! ([`newer`]). Traps: "4.20" is 4 and 20 by name, so models.dev's dates go
//! first; of one version, the maker's own copy goes before a reseller's
//! ("deepseek/…" before "TEE/…").

use std::cmp::Ordering;
use std::sync::LazyLock;

use serde::Deserialize;

use crate::list;
use crate::models_dev::Index;

/// The one format of the file this server reads.
const FORMAT: u32 = 1;

/// Words a member's name may hold besides its family's, numbers and sizes.
const NEUTRAL: [&str; 1] = ["instruct"];

/// A family: the words of its models' names, lower-case.
type Family = Vec<String>;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct File {
    format: u32,
    provider: Vec<Entry>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Entry {
    name: String,
    families: Vec<Family>,
}

/// The providers of `file` with their families in order; why not, where its
/// format is not known, a name is not an online provider's of the list, or a
/// family has no words or a word that is not lower-case letters and digits.
fn read(file: &str) -> Result<Vec<(String, Vec<Family>)>, String> {
    let file: File = toml::from_str(file).map_err(|failure| failure.to_string())?;
    if file.format != FORMAT {
        return Err(format!("format {} is not known", file.format));
    }
    file.provider
        .into_iter()
        .map(|entry| {
            let known = list::all().iter().find(|known| known.name == entry.name);
            if !known.is_some_and(|known| !known.local) {
                return Err(format!("{} is not an online provider's name", entry.name));
            }
            let word = |word: &String| {
                !word.is_empty()
                    && word
                        .chars()
                        .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit())
            };
            if entry
                .families
                .iter()
                .any(|f| f.is_empty() || !f.iter().all(word))
            {
                return Err(format!(
                    "{} has a family of no words or of a sign",
                    entry.name
                ));
            }
            Ok((entry.name, entry.families))
        })
        .collect()
}

static SUGGESTED: LazyLock<Vec<(String, Vec<Family>)>> = LazyLock::new(|| {
    // Our own file, built in: a test reads it whole.
    read(include_str!("../providers/suggested.toml")).expect("the suggested families")
});

/// The families suggested for the provider called `name`, none where it has none.
fn families(name: &str) -> &'static [Family] {
    SUGGESTED
        .iter()
        .find(|(named, _)| named == name)
        .map_or(&[], |(_, families)| families.as_slice())
}

/// The suggestion among `models`, the provider's text models, for the provider
/// at `base_url`: none where it is not on the list, has no families, or offers none of them.
pub(crate) fn of(base_url: &str, models: &[String], index: &Index) -> Option<String> {
    let provider = list::at(base_url.trim_end_matches('/'))?;
    among(families(&provider.name), models, index)
}

/// The newest member of the first of `families` that has one among `models`.
fn among(families: &[Family], models: &[String], index: &Index) -> Option<String> {
    families.iter().find_map(|family| {
        models
            .iter()
            .filter_map(|id| member(family, id).map(|version| (id, version)))
            .max_by(|a, b| newer(a, b, family, index))
            .map(|(id, _)| id.clone())
    })
}

/// A member's version by its name: its numbers of up to three digits, then its dates.
type Version = (Vec<u64>, Vec<u64>);

/// The version of `id` where it is a member of `family`, else none.
fn member(family: &Family, id: &str) -> Option<Version> {
    let lower = id.to_lowercase();
    let name = lower.rsplit('/').next().unwrap_or_default();
    let mut found = vec![false; family.len()];
    let (mut numbers, mut dates) = (Vec::new(), Vec::new());
    let mut number = |digits: &str| {
        let value = digits.parse().unwrap_or(u64::MAX);
        // A date as YYYYMMDD whatever its form ("2603" is 2026-03), so two forms compare.
        match digits.len() {
            ..4 => numbers.push(value),
            4 => dates.push(value.saturating_mul(100).saturating_add(20_000_000)),
            6 => dates.push(value.saturating_add(20_000_000)),
            _ => dates.push(value),
        }
    };
    for word in name.split(|c: char| !c.is_ascii_alphanumeric()) {
        let digits = |rest: &str| !rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit());
        // A family's word first, alone or with its number at its end ("qwen3"), a size ("27b") too.
        let at = family.iter().position(|of| {
            word.strip_prefix(of.as_str())
                .is_some_and(|rest| rest.is_empty() || digits(rest))
        });
        if let Some(at) = at {
            found[at] = true;
            let rest = &word[family[at].len()..];
            if !rest.is_empty() {
                number(rest);
            }
        } else if digits(word) {
            number(word);
        } else if let Some(rest) = word.strip_prefix('v').filter(|rest| digits(rest)) {
            number(rest);
        } else if !(word.is_empty() || NEUTRAL.contains(&word) || size(word)) {
            return None;
        }
    }
    found.iter().all(|&found| found).then_some((numbers, dates))
}

/// Whether `word` is a model's size: "27b", or its active part "a3b".
fn size(word: &str) -> bool {
    let number = word.strip_prefix('a').unwrap_or(word);
    number
        .strip_suffix('b')
        .is_some_and(|digits| !digits.is_empty() && digits.bytes().all(|b| b.is_ascii_digit()))
}

/// Which of two members is the newer: by models.dev's release where it knows
/// both, else by the version in their names; of one, the maker's own copy.
fn newer(
    (a, a_version): &(&String, Version),
    (b, b_version): &(&String, Version),
    family: &Family,
    index: &Index,
) -> Ordering {
    let released = |id: &str| index.get(id).and_then(|known| known.released.clone());
    let by_date = match (released(a), released(b)) {
        (Some(a), Some(b)) => a.cmp(&b),
        _ => Ordering::Equal,
    };
    // The part before the last "/" begins with the family's first word: the maker's own.
    let own = |id: &str| {
        id.to_lowercase()
            .rsplit_once('/')
            .is_none_or(|(maker, _)| maker.starts_with(family[0].as_str()))
    };
    by_date
        .then_with(|| a_version.cmp(b_version))
        .then_with(|| own(a).cmp(&own(b)))
        .then_with(|| b.cmp(a))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ids(list: &[&str]) -> Vec<String> {
        list.iter().map(|id| id.to_string()).collect()
    }

    fn nano(models: &[&str]) -> Option<String> {
        among(families("NanoGPT"), &ids(models), &Index::default())
    }

    #[test]
    fn the_file_names_providers_of_the_list_and_is_refused_otherwise() {
        assert_eq!(families("NanoGPT").len(), 4);
        assert!(families("OpenAI").is_empty());
        assert!(read("format = 2\nprovider = []").is_err());
        assert!(read("format = 1\n[[provider]]\nname = \"Nobody\"\nfamilies = [[\"a\"]]").is_err());
        assert!(read("format = 1\n[[provider]]\nname = \"xAI\"\nfamilies = [[\"Grok\"]]").is_err());
    }

    #[test]
    fn a_family_takes_its_newest_version_whatever_the_number() {
        let listed = [
            "mistralai/mistral-small-3.2-24b-instruct",
            "mistralai/mistral-small-4-119b-2603",
            "mistralai/devstral-small-2505",
            "deepseek/deepseek-v4.1-flash",
        ];
        assert_eq!(
            nano(&listed).as_deref(),
            Some("mistralai/mistral-small-4-119b-2603")
        );
        // A successor no list knows yet replaces it, with no change to the file.
        let next = [&listed[..], &["mistralai/mistral-small-5"]].concat();
        assert_eq!(nano(&next).as_deref(), Some("mistralai/mistral-small-5"));
        // Qwen's size is its family, the numbers beside it its version; a finetune or another size is not counted.
        let qwen = [
            "qwen/qwen3.6-27b",
            "qwen/qwen3.8-27b",
            "qwen/qwen3.8-27b-uncensored",
            "Qwen3.9-27B-Queen-Derestricted",
            "qwen/qwen3.9-35b-a3b",
        ];
        assert_eq!(nano(&qwen).as_deref(), Some("qwen/qwen3.8-27b"));
        // A date after the version counts after it; of one version the maker's own copy, not a reseller's.
        let flash = [
            "deepseek/deepseek-v4-flash-0731",
            "TEE/deepseek-v4.1-flash",
            "deepseek/deepseek-v4.1-flash",
        ];
        assert_eq!(
            nano(&flash).as_deref(),
            Some("deepseek/deepseek-v4.1-flash")
        );
    }

    #[test]
    fn a_thinking_or_reasoning_variant_is_not_counted_in_its_family() {
        let listed = [
            "mistralai/mistral-small-5:thinking",
            "mistralai/mistral-small-4",
        ];
        assert_eq!(nano(&listed).as_deref(), Some("mistralai/mistral-small-4"));
        let xai = |models: &[&str]| among(families("xAI"), &ids(models), &Index::default());
        let grok = [
            "grok-4.20-0309-reasoning",
            "grok-4.20-0309-non-reasoning",
            "grok-4.3",
        ];
        assert_eq!(xai(&grok).as_deref(), Some("grok-4.20-0309-non-reasoning"));
        // No model without reasoning: no suggestion (today's rules pick), never its reasoning one.
        let plain = [
            "grok-4.20-0309-reasoning",
            "grok-4.3",
            "grok-imagine-image",
            "grok-build-0.1",
        ];
        assert_eq!(xai(&plain), None);
    }

    #[test]
    fn a_family_gone_falls_to_the_next_and_none_left_to_none() {
        let listed = ["deepseek/deepseek-v4.1-flash", "qwen/qwen3.8-27b"];
        assert_eq!(
            nano(&listed).as_deref(),
            Some("deepseek/deepseek-v4.1-flash")
        );
        assert_eq!(
            nano(&["qwen/qwen3.8-27b"]).as_deref(),
            Some("qwen/qwen3.8-27b")
        );
        assert_eq!(
            nano(&["glm-5.3", "mistralai/mistral-small-4:thinking"]),
            None
        );
        // A provider the file does not name, or one not on the list: none.
        let gpt = ids(&["gpt-5", "gpt-5-mini"]);
        assert_eq!(
            of("https://api.openai.com/v1", &gpt, &Index::default()),
            None
        );
        assert_eq!(of("http://127.0.0.1:9", &gpt, &Index::default()), None);
        let sonnet = ids(&["claude-haiku-5-5", "claude-sonnet-5-5"]);
        assert_eq!(
            of("https://api.anthropic.com/v1/", &sonnet, &Index::default()).as_deref(),
            Some("claude-sonnet-5-5")
        );
    }

    #[test]
    fn models_devs_release_goes_before_the_numbers_in_the_name() {
        let list = r#"{ "xai": { "models": {
            "grok-4.20-0309": { "id": "grok-4.20-0309", "release_date": "2026-03-31" },
            "grok-4.3": { "id": "grok-4.3", "release_date": "2026-04-17" } } } }"#;
        let index = Index::read(list.as_bytes()).unwrap();
        let grok = ids(&["grok-4.20-0309", "grok-4.3"]);
        assert_eq!(
            among(&[vec!["grok".into()]], &grok, &index).as_deref(),
            Some("grok-4.3")
        );
    }

    #[test]
    fn a_short_date_and_a_long_one_compare_as_dates() {
        let listed = [
            "mistralai/mistral-small-4-2603",
            "mistralai/mistral-small-4-20250929",
        ];
        assert_eq!(
            nano(&listed).as_deref(),
            Some("mistralai/mistral-small-4-2603")
        );
    }
}

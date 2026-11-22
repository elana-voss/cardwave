//! The names tool's database: `name_database.json.gz` beside this file, the
//! extension's `data/name_database.tagged.json` packed (8 MB, 0.16 MB packed),
//! read once on first use (`names`). Each entry is a name with its tags; a tag
//! is one value or a list, and a filter matches an entry where any value it
//! wants is among the entry's (`Entry::fits`). First names carry every tag,
//! surnames no intelligence or age and a gender only where they have one.
//! The twelve tags are named once, in `TAGS` (with what the model is told of
//! each and where it is dropped); `Entry`'s fields and `Entry::values` follow
//! it, which a test checks.

use std::sync::LazyLock;

use serde::Deserialize;

/// The packed database.
const PACKED: &[u8] = include_bytes!("name_database.json.gz");

/// A tag a filter can ask for.
pub(crate) struct Tag {
    /// The tag's name, as the database, the model's filters and the answer have it.
    pub name: &'static str,
    /// What the model is told of the filter.
    pub description: &'static str,
    /// Where the extension drops the filter when nothing matches, first 0
    /// (`drop_order`); none for the genre, which only makes fitting names likelier.
    pub drop_rank: Option<u8>,
}

const fn tag(name: &'static str, description: &'static str, drop_rank: Option<u8>) -> Tag {
    Tag {
        name,
        description,
        drop_rank,
    }
}

/// Every tag, in the order the model is told of them.
pub(crate) const TAGS: [Tag; 12] = [
    tag("gender", "Gender of the new NPC.", Some(10)),
    tag(
        "language_ethnicity",
        "Cultural root. Real-world for humans; fantasyElvish, fantasyDwarven, fantasyDragon for non-human races; cyberpunkHandle for online handles.",
        Some(9),
    ),
    tag(
        "mythology",
        "Pantheon of a god, spirit or monster; pass with race: mythical, never human.",
        Some(7),
    ),
    tag(
        "race",
        "human for every person; mythical only for a god, spirit or monster; elf, dwarf or dragon for those.",
        Some(8),
    ),
    tag("age", "Lifestage the name fits.", Some(5)),
    tag("era", "Period the name evokes.", Some(6)),
    tag(
        "role",
        "Narrative function (hero, villain, mentor, ...).",
        Some(4),
    ),
    tag(
        "intelligence",
        "How cerebral the name sounds: blunt / plain / average / thoughtful / bookish.",
        Some(2),
    ),
    tag(
        "allure",
        "How attractive the name sounds: harsh / unremarkable / pleasant / pretty / striking.",
        Some(1),
    ),
    tag(
        "commonness",
        "Pass only when the story calls for it (a name that must sound plain and everyday, or strikingly unusual); otherwise leave it out.",
        Some(3),
    ),
    tag(
        "genre",
        "The story's flavour; names fitting it become likelier, none is left out.",
        None,
    ),
    tag(
        "themes",
        "Zero or more decorative tags (overlap match).",
        Some(0),
    ),
];

/// The tags a filter can drop, in the order the extension drops them.
pub(crate) fn drop_order() -> Vec<&'static str> {
    let mut ranked: Vec<(u8, &str)> = TAGS
        .iter()
        .filter_map(|tag| Some((tag.drop_rank?, tag.name)))
        .collect();
    ranked.sort_unstable();
    ranked.into_iter().map(|(_, name)| name).collect()
}

/// A name with its tags.
#[derive(Debug, Clone, Default, Deserialize)]
pub(crate) struct Entry {
    pub name: String,
    #[serde(default)]
    pub gender: Option<String>,
    pub language_ethnicity: String,
    #[serde(default)]
    pub mythology: Option<String>,
    #[serde(default)]
    pub race: Option<String>,
    #[serde(default)]
    pub age: Vec<String>,
    #[serde(default)]
    pub era: Vec<String>,
    #[serde(default)]
    pub role: Vec<String>,
    #[serde(default)]
    pub intelligence: Option<String>,
    #[serde(default)]
    pub allure: Option<String>,
    #[serde(default)]
    pub commonness: Option<String>,
    #[serde(default)]
    pub genre: Vec<String>,
    #[serde(default)]
    pub themes: Vec<String>,
}

impl Entry {
    /// The entry's values of the tag `field` (one of `TAGS`, which a test
    /// checks): none for a tag it lacks or an unknown one.
    pub(crate) fn values(&self, field: &str) -> &[String] {
        match field {
            "gender" => self.gender.as_slice(),
            "language_ethnicity" => std::slice::from_ref(&self.language_ethnicity),
            "mythology" => self.mythology.as_slice(),
            "race" => self.race.as_slice(),
            "age" => &self.age,
            "era" => &self.era,
            "role" => &self.role,
            "intelligence" => self.intelligence.as_slice(),
            "allure" => self.allure.as_slice(),
            "commonness" => self.commonness.as_slice(),
            "genre" => &self.genre,
            "themes" => &self.themes,
            _ => &[],
        }
    }

    /// Whether any of `wanted` is among the entry's values of `field`.
    pub(crate) fn fits(&self, field: &str, wanted: &[String]) -> bool {
        let values = self.values(field);
        wanted.iter().any(|value| values.contains(value))
    }

    /// The name as the used list keeps it: the same name in two cultures is two names.
    pub(crate) fn key(&self) -> String {
        format!("{}/{}", self.language_ethnicity, self.name)
    }
}

/// The first names and the surnames.
#[derive(Debug, Default, Deserialize)]
pub(crate) struct Names {
    pub first_names: Vec<Entry>,
    pub last_names: Vec<Entry>,
}

impl Names {
    /// Every value the first names hold of `field`, sorted, each once.
    pub(crate) fn values_of(&self, field: &str) -> Vec<&str> {
        let mut all: Vec<&str> = self
            .first_names
            .iter()
            .flat_map(|entry| entry.values(field))
            .map(String::as_str)
            .collect();
        all.sort_unstable();
        all.dedup();
        all
    }
}

/// The database, read on first use.
pub(crate) fn names() -> &'static Names {
    static NAMES: LazyLock<Names> = LazyLock::new(|| {
        // The file is part of the build, which its test reads: it cannot fail here.
        let bytes = cw_platform::packed::unpacked(PACKED).expect("the names database unpacks");
        serde_json::from_slice(&bytes).expect("the names database reads")
    });
    &NAMES
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_database_reads_with_its_cultures() {
        let names = names();
        assert!(names.first_names.len() > 9_000 && names.last_names.len() > 6_000);
        let cultures = names.values_of("language_ethnicity");
        assert!(cultures.contains(&"finnish") && cultures.contains(&"fantasyElvish"));
        assert!(names.first_names.iter().all(|entry| entry.gender.is_some()));
    }

    /// Each tag of `TAGS` is read by `Entry::values`, where an unknown name gives none.
    #[test]
    fn every_tag_is_read_from_its_own_field() {
        let one = |name: &str| Some(name.to_string());
        let list = |name: &str| vec![name.to_string()];
        let entry = Entry {
            name: String::new(),
            gender: one("gender"),
            language_ethnicity: "language_ethnicity".to_string(),
            mythology: one("mythology"),
            race: one("race"),
            age: list("age"),
            era: list("era"),
            role: list("role"),
            intelligence: one("intelligence"),
            allure: one("allure"),
            commonness: one("commonness"),
            genre: list("genre"),
            themes: list("themes"),
        };
        for tag in &TAGS {
            assert_eq!(entry.values(tag.name), [tag.name], "{}", tag.name);
        }
        assert_eq!(
            drop_order(),
            [
                "themes",
                "allure",
                "intelligence",
                "commonness",
                "role",
                "age",
                "era",
                "mythology",
                "race",
                "language_ethnicity",
                "gender",
            ]
        );
    }
}

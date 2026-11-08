//! The interview's texts as the page gets them: each fixed question and choice of
//! [`texts`] goes as a stable id the page words in its language (`interview-<id>` in
//! `web/src/language/en.interview.ftl`), what a model worded as its words. A
//! question is a [`Text`], serialised as it is; a list of choices or picks keeps
//! its English for the prompts and maps here, `#[serde(with = "shown::many")]`. An
//! id that comes back is checked: an unknown one is refused.
//!
//! Traps: the probe and the "why" question quote an answer, so the engine builds
//! them as their id with `said` ([`Text::quoting`]), the answer's parts each a
//! pick's id or the user's typed line as typed. An English text that is in two
//! lists has one id. The ids are written to
//! `web/src/api/generated/InterviewTextId.ts` by this module's test, which the UI's
//! build checks for words.

use std::collections::HashMap;
use std::fmt;
use std::sync::LazyLock;

use serde::{Deserialize, Deserializer, Serialize, Serializer};
use ts_rs::TS;

use super::{Entry, Tag, answer_of, texts};

/// A text the page shows: an id of the app's, or a model's words.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export, rename = "InterviewText")]
#[serde(untagged)]
pub enum Text {
    /// `said`: the parts of the answer the text quotes, empty where it quotes none.
    Fixed {
        id: String,
        #[serde(default)]
        said: Vec<Text>,
    },
    Worded {
        words: String,
    },
}

const PROBE: &str = "probe";
const WHY: &str = "why";
const WHY_UNSAID: &str = "why-unsaid";

/// Every fixed text's id and English, in the order the ids were given.
struct Table {
    ids: Vec<(String, &'static str)>,
    of_english: HashMap<&'static str, usize>,
    of_id: HashMap<String, usize>,
}

impl Table {
    fn add(&mut self, id: String, english: &'static str) {
        if self.of_english.contains_key(english) {
            return;
        }
        let mut free = id.clone();
        let mut more = 2;
        while self.of_id.contains_key(&free) {
            free = format!("{id}-{more}");
            more += 1;
        }
        self.of_english.insert(english, self.ids.len());
        self.of_id.insert(free.clone(), self.ids.len());
        self.ids.push((free, english));
    }
}

/// `english` as a Fluent name's part: lower case letters and digits, "-" between.
fn slug(english: &str) -> String {
    let words = english.split(|c: char| !c.is_ascii_alphanumeric());
    let words: Vec<String> = words
        .filter(|word| !word.is_empty())
        .map(str::to_ascii_lowercase)
        .collect();
    words.join("-")
}

fn why_template() -> &'static str {
    let why = texts::FIXED.iter().find(|(slot, ..)| *slot == WHY);
    why.map(|(_, text, _)| *text).unwrap_or_default()
}

static TABLE: LazyLock<Table> = LazyLock::new(|| {
    let mut table = Table {
        ids: Vec::new(),
        of_english: HashMap::new(),
        of_id: HashMap::new(),
    };
    let questions = [
        ("ask-wanted", texts::WANTED),
        ("ask-third", texts::THIRD),
        ("ask-relation", texts::RELATION_QUESTION),
        ("ask-moments", texts::MOMENTS_QUESTION),
        ("ask-needs", texts::NEEDS_QUESTION),
        ("ask-kinds", texts::KINDS_QUESTION),
        ("ask-character", texts::CHARACTER_QUESTION),
        ("ask-treat", texts::TREAT_QUESTION),
    ];
    for (id, english) in questions {
        table.add(id.to_string(), english);
    }
    for (id, english) in crate::needs::LIST {
        table.add(format!("need-{}", id.replace('_', "-")), english);
    }
    for (need, question, _) in texts::BRANCH {
        let id = crate::needs::LIST.iter().find(|(_, words)| words == need);
        let id = id.map_or_else(|| slug(need), |(id, _)| id.replace('_', "-"));
        table.add(format!("ask-branch-{id}"), question);
    }
    for (slot, question, _) in texts::FIXED.iter().filter(|(slot, ..)| *slot != WHY) {
        table.add(format!("ask-{}", slug(slot)), question);
    }
    let lists = [
        texts::RELATIONS,
        texts::MOMENTS,
        texts::KIND_NAMES,
        texts::TREAT_CHOICES,
        &[texts::YOU_CHOOSE],
        texts::TOPICS,
    ];
    let branches = texts::BRANCH.iter().map(|(_, _, choices)| *choices);
    let fixed = texts::FIXED.iter().map(|(_, _, choices)| *choices);
    for list in lists.into_iter().chain(branches).chain(fixed) {
        for english in list {
            table.add(format!("pick-{}", slug(english)), english);
        }
    }
    for (english, _) in texts::CHARACTER_VALUE {
        table.add(format!("pick-{}", slug(english)), english);
    }
    table
});

impl Text {
    /// The text the page gets for `english`: its id where it is a fixed text, else as words.
    pub fn of(english: &str) -> Text {
        match TABLE.of_english.get(english) {
            Some(&at) => Text::Fixed {
                id: TABLE.ids[at].0.clone(),
                said: Vec::new(),
            },
            None => Text::Worded {
                words: english.to_string(),
            },
        }
    }

    /// The probe on `entry`'s answer, or the "why" on the wish of `entry`
    /// (`None`: nothing was said), quoting the answer's parts.
    pub(crate) fn quoting(probe: bool, entry: Option<&Entry>) -> Text {
        let Some(entry) = entry else {
            return Text::Fixed {
                id: WHY_UNSAID.to_string(),
                said: Vec::new(),
            };
        };
        let mut said: Vec<Text> = entry.picks.iter().map(|pick| Text::of(pick)).collect();
        if !entry.free.is_empty() {
            said.push(Text::Worded {
                words: entry.free.clone(),
            });
        }
        let id = if probe { PROBE } else { WHY };
        Text::Fixed {
            id: id.to_string(),
            said,
        }
    }

    /// The English this text stands for.
    pub fn english(&self) -> String {
        self.known().unwrap_or_default()
    }

    /// The English, `None` for an id the app does not have.
    fn known(&self) -> Option<String> {
        let (id, said) = match self {
            Text::Worded { words } => return Some(words.clone()),
            Text::Fixed { id, said } => (id.as_str(), said),
        };
        let quote = || -> Option<String> {
            let parts: Option<Vec<String>> = said.iter().map(Text::known).collect();
            Some(parts?.join("; "))
        };
        match id {
            PROBE => Some(texts::PROBE.replacen("{}", &quote()?, 1)),
            WHY => Some(why_template().replacen("{}", &quote()?, 1)),
            WHY_UNSAID => Some(texts::WHY_UNSAID.to_string()),
            _ => {
                let at = TABLE.of_id.get(id)?;
                Some(TABLE.ids[*at].1.to_string())
            }
        }
    }
}

impl fmt::Display for Text {
    fn fmt(&self, to: &mut fmt::Formatter<'_>) -> fmt::Result {
        to.write_str(&self.english())
    }
}

impl PartialEq<&str> for Text {
    fn eq(&self, english: &&str) -> bool {
        self.english() == *english
    }
}

impl PartialEq<String> for Text {
    fn eq(&self, english: &String) -> bool {
        self.english() == *english
    }
}

// A text the page sends back: its ids are checked.
impl<'de> Deserialize<'de> for Text {
    fn deserialize<D: Deserializer<'de>>(from: D) -> Result<Text, D::Error> {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum Sent {
            Fixed {
                id: String,
                #[serde(default)]
                said: Vec<Text>,
            },
            Worded {
                words: String,
            },
        }
        let text = match Sent::deserialize(from)? {
            Sent::Fixed { id, said } => Text::Fixed { id, said },
            Sent::Worded { words } => Text::Worded { words },
        };
        match text.known() {
            Some(_) => Ok(text),
            None => Err(serde::de::Error::custom(format!(
                "the interview has no text {text:?}"
            ))),
        }
    }
}

/// Every id the page may get, in order.
pub fn ids() -> Vec<String> {
    let fixed = TABLE.ids.iter().map(|(id, _)| id.clone());
    let quoted = [PROBE, WHY, WHY_UNSAID].map(str::to_string);
    fixed.chain(quoted).collect()
}

/// An [`Entry`] as the page sends it back: without its answer, which is made anew.
#[derive(Deserialize)]
pub(crate) struct EntryForm {
    slot: String,
    question: Text,
    skipped: bool,
    dont_know: bool,
    #[serde(with = "many")]
    choices: Vec<String>,
    multi: bool,
    probe: bool,
    #[serde(with = "many")]
    picks: Vec<String>,
    free: String,
    lit: Option<Vec<String>>,
    tag: Option<Tag>,
}

impl From<EntryForm> for Entry {
    fn from(form: EntryForm) -> Entry {
        Entry {
            answer: answer_of(&form.picks, &form.free, form.skipped),
            slot: form.slot,
            question: form.question,
            skipped: form.skipped,
            dont_know: form.dont_know,
            choices: form.choices,
            multi: form.multi,
            probe: form.probe,
            picks: form.picks,
            free: form.free,
            lit: form.lit,
            tag: form.tag,
        }
    }
}

/// A field of a list of texts.
pub mod many {
    use super::*;

    pub fn serialize<S: Serializer>(english: &[String], to: S) -> Result<S::Ok, S::Error> {
        let texts: Vec<Text> = english.iter().map(|one| Text::of(one)).collect();
        texts.serialize(to)
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(from: D) -> Result<Vec<String>, D::Error> {
        let texts = Vec::<Text>::deserialize(from)?;
        Ok(texts.iter().map(Text::english).collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Writes the ids for the UI's build check, as ts-rs writes the types.
    #[test]
    fn every_id_stands_for_one_text_and_goes_to_the_page() {
        let ids = ids();
        let unique: std::collections::HashSet<&String> = ids.iter().collect();
        assert_eq!(unique.len(), ids.len());
        for (id, english) in &TABLE.ids {
            let text = Text::Fixed {
                id: id.clone(),
                said: Vec::new(),
            };
            assert_eq!(text.english(), *english);
            assert_eq!(Text::of(english), text);
        }
        let quoted: Vec<String> = ids.iter().map(|id| format!("\"{id}\"")).collect();
        let ts = format!(
            "// Written by cw-library's interview::shown test; the interview's text ids.\n\nexport type InterviewTextId = {};\n",
            quoted.join(" | ")
        );
        let dir = std::env::var("TS_RS_EXPORT_DIR").unwrap_or_default();
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("..")
            .join(dir)
            .join("InterviewTextId.ts");
        if std::fs::read_to_string(&path).ok().as_deref() != Some(ts.as_str()) {
            std::fs::write(&path, ts).unwrap();
        }
    }

    /// Writes the page's English for each id, `web/src/language/en.interview.ftl`, the engine's own.
    #[test]
    fn the_pages_english_is_the_engines() {
        let said = |template: &str| {
            assert!(!template.contains(['{', '}']) || template.matches("{}").count() == 1);
            template.replacen("{}", "{ $said }", 1)
        };
        let mut ftl = String::from(
            "### The UI's words in English: the interview's questions and choices, `interview-<id>`, written by the\n\
             ### test of crates/cw-library/src/interview/shown.rs from the engine's English; never edited by hand.\n\n",
        );
        for (id, english) in &TABLE.ids {
            assert!(
                !english.contains(['{', '}', '\n']) && english.trim() == *english,
                "{english}"
            );
            ftl.push_str(&format!("interview-{id} = {english}\n"));
        }
        let unsaid = texts::WHY_UNSAID;
        ftl.push_str(&format!("interview-{PROBE} = {}\n", said(texts::PROBE)));
        ftl.push_str(&format!("interview-{WHY} = {}\n", said(why_template())));
        ftl.push_str(&format!("interview-{WHY_UNSAID} = {unsaid}\n"));
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../web/src/language/en.interview.ftl"
        );
        if std::fs::read_to_string(path).ok().as_deref() != Some(ftl.as_str()) {
            std::fs::write(path, ftl).unwrap();
        }
    }

    #[test]
    fn a_quoted_answer_goes_in_parts_and_comes_back_whole() {
        let need = texts::NEEDS[0];
        let entry = Entry {
            slot: "needs".to_string(),
            question: Text::of(texts::NEEDS_QUESTION),
            answer: None,
            skipped: false,
            dont_know: false,
            choices: Vec::new(),
            multi: true,
            probe: false,
            picks: vec![need.to_string()],
            free: "my own".to_string(),
            lit: None,
            tag: None,
        };
        let text = Text::quoting(false, Some(&entry));
        let Text::Fixed { id, said } = &text else {
            panic!("{text:?}")
        };
        assert_eq!(id, WHY);
        assert_eq!(said[0], Text::of(need));
        assert!(matches!(&said[0], Text::Fixed { .. }));
        let english = why_template().replacen("{}", &format!("{need}; my own"), 1);
        assert_eq!(text.english(), english);
        assert_eq!(Text::quoting(false, None).english(), texts::WHY_UNSAID);
    }

    #[test]
    fn an_unknown_id_is_refused() {
        let sent = serde_json::json!({"id": "pick-nothing-such"});
        assert!(serde_json::from_value::<Text>(sent).is_err());
        let quoted = serde_json::json!({"id": "probe", "said": [{"id": "pick-nothing-such"}]});
        assert!(serde_json::from_value::<Text>(quoted).is_err());
    }
}

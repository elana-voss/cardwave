//! Prompt assembly, ported from the Flutter app (`chat_prompt_builder.dart`,
//! `lorebook_service.dart`, `utils_prompt.dart`): `{{macro}}` expansion, lorebook
//! activation and the final message list with its token budget.
//!
//! A pure crate (it names only cw-core of the app and saves nothing): the
//! types here are the builder's own inputs, independent of how cards and chats
//! are stored; the server's `chats::reply` reads a stored chat into them.

pub mod builder;
pub mod lorebook;
pub mod macros;
pub mod tokens;

use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Chat variables written and read by macros (`{{setvar}}`, `{{.x}}`, `{{$x}}`).
pub type Variables = HashMap<String, String>;

/// What `{{user}}` stands for where no persona is at hand (in a chat without
/// one, and in a card's text shown outside a chat), in the app's language
/// `language` by its file's code ("pt-BR") or the computer's ("pt"): the
/// page's word `card-user-stand-in`, a name of no gender, which reads in a
/// sentence of that language; English's for a language the app has no file
/// of, by cw-core's `file_code`. Trap: a new language's file needs its word here too (the
/// test fails).
pub fn stand_in_user(language: &str) -> &'static str {
    match cw_core::languages::file_code(language).as_str() {
        "zh-Hans" => "访客",
        "zh-Hant" => "訪客",
        "de" => "Gast",
        "es" => "Visitante",
        "pt-BR" => "Você",
        "id" => "Tamu",
        "ru" => "Гость",
        "vi" => "Khách",
        "hi" => "अतिथि",
        "ja" => "ゲスト",
        "ko" => "게스트",
        _ => "Guest",
    }
}

/// Depth used when a depth prompt or an at-depth lorebook entry names none.
pub const DEFAULT_DEPTH: usize = 4;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum Role {
    #[default]
    System,
    User,
    Assistant,
}

/// What a picture sent with a message is taken to cost of the context: an
/// estimate (Claude's), between what OpenAI's and Anthropic's APIs count for a
/// picture of about a megapixel, as no provider says it before it is sent.
pub(crate) const PICTURE_TOKENS: usize = 1000;

/// One message of the prompt sent to the model. One with pictures (data
/// URLs) is sent as OpenAI's API has a message that shows some: its content a
/// list of its text, where it has any, and the pictures.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptMessage {
    pub role: Role,
    pub content: String,
    pub pictures: Vec<String>,
}

impl PromptMessage {
    pub fn new(role: Role, content: impl Into<String>) -> Self {
        Self {
            role,
            content: content.into(),
            pictures: Vec::new(),
        }
    }
}

impl Serialize for PromptMessage {
    fn serialize<S: serde::Serializer>(&self, to: S) -> Result<S::Ok, S::Error> {
        use serde::ser::SerializeMap;
        let mut map = to.serialize_map(Some(2))?;
        map.serialize_entry("role", &self.role)?;
        if self.pictures.is_empty() {
            map.serialize_entry("content", &self.content)?;
        } else {
            // Some providers refuse an empty text part, so a message of pictures alone has none.
            let text = (!self.content.is_empty())
                .then(|| serde_json::json!({ "type": "text", "text": self.content }));
            let parts: Vec<serde_json::Value> = text
                .into_iter()
                .chain(self.pictures.iter().map(
                    |url| serde_json::json!({ "type": "image_url", "image_url": { "url": url } }),
                ))
                .collect();
            map.serialize_entry("content", &parts)?;
        }
        map.end()
    }
}

#[derive(Clone, Debug, Default)]
pub struct Character {
    pub name: String,
    /// Replaces `name` in `{{char}}` when set; the identity line keeps `name`.
    pub nickname: Option<String>,
    pub tags: Vec<String>,
    pub system_prompt: String,
    pub description: String,
    pub personality: String,
    pub scenario: String,
    pub post_history_instructions: String,
    pub mes_example: String,
    /// Usually none or one; a CCV4 card may sink several prompt blocks into the chat.
    pub depth_prompts: Vec<DepthPrompt>,
    pub lorebook: Option<Lorebook>,
}

impl Character {
    /// The name macros and lorebook filters use for the character.
    pub fn display_name(&self) -> &str {
        match &self.nickname {
            Some(nick) if !nick.is_empty() => nick,
            _ => &self.name,
        }
    }
}

/// A card's extra prompt placed `depth` messages back from the newest one.
#[derive(Clone, Debug)]
pub struct DepthPrompt {
    pub prompt: String,
    pub depth: usize,
    pub role: Role,
}

#[derive(Clone, Debug, Default)]
pub struct Lorebook {
    pub entries: Vec<LorebookEntry>,
    /// How many of the newest messages are searched for keys; 4 when unset.
    pub scan_depth: Option<usize>,
    /// Token limit for all entries together; 0 means no limit.
    pub token_budget: usize,
}

/// How secondary keys combine with a primary key match (SillyTavern's 0–3).
/// A lorebook's editor shows and takes it by these names (`and_any`).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum SelectiveLogic {
    /// 0: at least one secondary key matches.
    #[default]
    AndAny,
    /// 1: not every secondary key matches.
    NotAll,
    /// 2: no secondary key matches.
    NotAny,
    /// 3: every secondary key matches.
    AndAll,
}

#[derive(Clone, Debug, Default)]
pub struct CharacterFilter {
    pub names: Vec<String>,
    pub tags: Vec<String>,
    /// The filter lists who is shut out instead of who is let in.
    pub is_exclude: bool,
}

#[derive(Clone, Debug)]
pub struct LorebookEntry {
    /// Identifies the entry in the chat's sticky and cooldown state; the entry's
    /// index in the book is used when unset.
    pub id: Option<String>,
    /// What the entry is called where it is shown; never part of the prompt.
    pub name: String,
    pub keys: Vec<String>,
    pub secondary_keys: Vec<String>,
    pub content: String,
    pub enabled: bool,
    /// Always active, without a key match.
    pub constant: bool,
    /// Used where the newest messages are about what it says
    /// (`ChatState::meaning`), and by its keys where that is not known.
    pub by_meaning: bool,
    pub selective: bool,
    pub selective_logic: SelectiveLogic,
    /// Higher wins when the token budget runs out.
    pub priority: i64,
    /// Lower comes first in the prompt.
    pub insertion_order: i64,
    /// Keys are regular expressions, optionally in JavaScript's `/pattern/flags` form.
    pub use_regex: bool,
    pub case_sensitive: bool,
    pub match_whole_words: bool,
    /// How many of the newest messages are read for its keys, where that is
    /// not as many as its lorebook says.
    pub scan_depth: Option<usize>,
    pub character_filter: Option<CharacterFilter>,
    /// Placed inside the chat log at `depth` instead of in the world-info block.
    pub at_depth: bool,
    pub depth: usize,
    pub role: Role,
    /// Chance in percent that a triggered entry is used.
    pub probability: u32,
    /// Messages the entry stays active after it triggered.
    pub sticky: usize,
    /// Messages the entry stays off after it was active.
    pub cooldown: usize,
    /// Messages the chat needs before the entry can trigger.
    pub delay: usize,
    /// Not counted against the lorebook's token budget.
    pub ignore_budget: bool,
}

impl Default for LorebookEntry {
    fn default() -> Self {
        Self {
            id: None,
            name: String::new(),
            keys: Vec::new(),
            secondary_keys: Vec::new(),
            content: String::new(),
            enabled: true,
            constant: false,
            by_meaning: false,
            selective: false,
            selective_logic: SelectiveLogic::default(),
            priority: 0,
            insertion_order: 100,
            use_regex: false,
            case_sensitive: false,
            match_whole_words: false,
            scan_depth: None,
            character_filter: None,
            at_depth: false,
            depth: DEFAULT_DEPTH,
            role: Role::System,
            probability: 100,
            sticky: 0,
            cooldown: 0,
            delay: 0,
            ignore_budget: false,
        }
    }
}

#[derive(Clone, Debug)]
pub struct ChatMessage {
    /// Stable per message; keeps `{{pick}}` choices in it the same on every build.
    pub id: String,
    pub role: Role,
    pub content: String,
    /// Token count of the content, filled in by the builder on first use. Whoever
    /// edits the content clears it.
    pub token_count: Option<usize>,
    /// False for a placeholder still being generated; those never reach the model.
    pub complete: bool,
    /// The pictures the user attached to it, as data URLs, sent with it.
    pub pictures: Vec<String>,
}

impl ChatMessage {
    pub fn new(id: impl Into<String>, role: Role, content: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            role,
            content: content.into(),
            token_count: None,
            complete: true,
            pictures: Vec::new(),
        }
    }
}

/// The part of a chat the prompt is built from. Building updates the variables,
/// the timed lorebook state and the cached token counts.
#[derive(Clone, Debug, Default)]
pub struct ChatState {
    pub persona_name: String,
    pub persona_description: String,
    pub messages: Vec<ChatMessage>,
    pub local_variables: Variables,
    /// Entry id to the message count at which its sticky phase ends.
    pub active_stickies: HashMap<String, usize>,
    /// Entry id to the message count at which its cooldown ends.
    pub active_cooldowns: HashMap<String, usize>,
    /// The entries used by meaning (`LorebookEntry::by_meaning`) that the
    /// newest messages are about, by id; none where the search model does
    /// not tell, and such entries go by their keys.
    pub meaning: Option<HashSet<String>>,
}

#[cfg(test)]
mod tests {
    use super::stand_in_user;
    use std::path::Path;

    /// The page's word `card-user-stand-in` of each language file, by code.
    #[test]
    fn the_stand_in_name_is_the_pages_word_in_every_language() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .ancestors()
            .nth(2)
            .unwrap();
        let folder = root.join("web/src/language");
        let mut seen = 0;
        for entry in std::fs::read_dir(&folder).unwrap() {
            let file = entry.unwrap().file_name().into_string().unwrap();
            let Some(code) = file.strip_suffix(".library.ftl") else {
                continue;
            };
            let text = std::fs::read_to_string(folder.join(&file)).unwrap();
            let word = text
                .lines()
                .find_map(|line| line.strip_prefix("card-user-stand-in = "))
                .unwrap_or_else(|| panic!("{file} has no card-user-stand-in"));
            assert_eq!(stand_in_user(code), word, "{code}");
            seen += 1;
        }
        assert!(seen >= 4, "{seen} language files");
        // The computer's code, by its first part; a language without a file: English's.
        assert_eq!(stand_in_user("pt"), "Você");
        assert_eq!(stand_in_user("fr"), "Guest");
        // Chinese by its script, as the page's appCode tells it: the region names it where the script is not given.
        for simplified in ["zh", "zh-CN", "zh_SG", "zh-Hans-HK"] {
            assert_eq!(
                stand_in_user(simplified),
                stand_in_user("zh-Hans"),
                "{simplified}"
            );
        }
        for traditional in ["zh-TW", "zh_HK", "zh-MO", "zh-Hant-CN"] {
            assert_eq!(
                stand_in_user(traditional),
                stand_in_user("zh-Hant"),
                "{traditional}"
            );
            assert_ne!(
                stand_in_user(traditional),
                stand_in_user("zh-Hans"),
                "{traditional}"
            );
        }
    }
}

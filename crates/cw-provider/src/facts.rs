//! What a model is, where its provider's list does not say: what models.dev's
//! list as shipped says of it (`models_dev`, by its name as that looks it
//! up), else what its name tells, a model of no known kind counting as one
//! that writes text, as the Flutter app has it. `guessed` is both;
//! `makes_pictures` its picture half, for the lists of image models.
//!
//! The words a name tells by are here alone: of another kind than text or
//! pictures ([`OTHER_WORDS`]), of them a search model's ([`SEARCH_WORDS`]) and
//! a voice's ([`VOICE_WORDS`]), of pictures ([`IMAGE_WORDS`]), and of a text
//! model that is no chat model ([`NOT_CHAT_WORDS`], first run's picks). A
//! search model or a voice is told by its name alone, as no list says them.
//! A model unknown to models.dev thinks where its name says so
//! ([`THINKING_WORDS`]); a reply that carries thinking teaches it too
//! (`Provider::thinks`).

use std::sync::LazyLock;

use crate::models_dev::{self, Index};

/// Words in a model's ID that mark a model that neither writes text nor makes
/// pictures: a voice, a transcriber, a search model, a filter.
const OTHER_WORDS: &[&str] = &[
    "tts",
    "speech",
    "audio",
    "whisper",
    "transcribe",
    "embed",
    "embedding",
    "embeddings",
    "moderation",
    "rerank",
    "reranker",
];

/// Words in a model's ID that mark a search model, one that turns texts into vectors.
const SEARCH_WORDS: &[&str] = &["embed", "embedding", "embeddings"];

/// Words in a model's ID that mark a voice, one that reads a text aloud.
const VOICE_WORDS: &[&str] = &["tts", "speech"];

/// Words in a model's ID that mark a model that makes pictures, for a list of
/// models that says nothing else of them.
const IMAGE_WORDS: &[&str] = &[
    "image",
    "images",
    "dall",
    "flux",
    "diffusion",
    "sd3",
    "sdxl",
    "imagen",
    "ideogram",
    "recraft",
    "seedream",
    "hidream",
    "kandinsky",
    "playground",
    "midjourney",
    "banana",
];

/// Words in a model's ID that mark one for live talk, search, guarding, code,
/// a computer's use or thinking alone: no chat model, though it writes text.
const NOT_CHAT_WORDS: &[&str] = &[
    "realtime", "search", "research", "guard", "code", "coder", "live", "thinking", "computer",
];

/// Words in a model's ID that mark one that thinks before it replies, for a
/// model models.dev does not list, such as one served by llama.cpp.
const THINKING_WORDS: &[&str] = &["think", "thinking", "reasoning", "reasoner"];

/// Words of a family that thinks, unless its ID also says "instruct" (Qwen3's
/// models of 2507 that do not think).
const THINKING_FAMILIES: &[&str] = &["qwen3", "qwq", "r1", "o1", "o3", "o4", "oss", "magistral"];

/// Whether the model's name marks one that thinks.
fn thinks_by_name(id: &str) -> bool {
    has_word(id, THINKING_WORDS)
        || (has_word(id, THINKING_FAMILIES) && !has_word(id, &["instruct"]))
}

/// What is known of a model.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Facts {
    /// It writes text: a chat model, or the background model.
    pub text: bool,
    /// It makes pictures.
    pub image: bool,
    /// It thinks before it replies.
    pub thinks: bool,
}

/// models.dev's list as shipped with this version.
static SHIPPED: LazyLock<Index> = LazyLock::new(models_dev::shipped);

/// What models.dev says of the model `id`, if it lists it.
pub(crate) fn of_models_dev(id: &str) -> Option<Facts> {
    SHIPPED.get(id).map(|known| Facts {
        text: known.text,
        image: known.image,
        thinks: known.thinks,
    })
}

/// The words of `lower`, a model's ID in lower case: what lies between its other signs.
fn split(lower: &str) -> impl Iterator<Item = &str> {
    lower.split(|c: char| !c.is_ascii_alphanumeric())
}

/// The words of the model's ID, lower-case.
pub fn words(id: &str) -> Vec<String> {
    split(&id.to_lowercase()).map(str::to_string).collect()
}

/// Whether a word of the model's ID, lower-case, is one of `marks`.
pub(crate) fn has_word(id: &str, marks: &[&str]) -> bool {
    split(&id.to_lowercase()).any(|word| marks.contains(&word))
}

/// Whether the model's name marks one that is no chat model: of another kind,
/// one that makes pictures, or a text model of [`NOT_CHAT_WORDS`].
pub(crate) fn no_chat_by_name(id: &str) -> bool {
    [OTHER_WORDS, IMAGE_WORDS, NOT_CHAT_WORDS]
        .iter()
        .any(|words| has_word(id, words))
}

/// What the model's name tells of it: of no kind it names, a model that writes text.
pub fn by_name(id: &str) -> Facts {
    let image = has_word(id, IMAGE_WORDS);
    let other = has_word(id, OTHER_WORDS);
    Facts {
        text: !image && !other,
        image,
        thinks: !image && !other && thinks_by_name(id),
    }
}

/// What models.dev says of the model, else what its name tells. A name of
/// another kind writes no text whatever models.dev says: it lists an
/// embedding model as one whose output is text.
pub(crate) fn guessed(id: &str) -> Facts {
    match of_models_dev(id) {
        Some(facts) => Facts {
            text: facts.text && !has_word(id, OTHER_WORDS),
            ..facts
        },
        None => by_name(id),
    }
}

/// Whether the model's name marks a search model.
pub(crate) fn searches(id: &str) -> bool {
    has_word(id, SEARCH_WORDS)
}

/// Whether the model's name marks a voice.
pub(crate) fn speaks(id: &str) -> bool {
    has_word(id, VOICE_WORDS)
}

/// Whether the model makes pictures, by models.dev or else its name.
pub(crate) fn makes_pictures(id: &str) -> bool {
    guessed(id).image
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_model_is_what_models_dev_says_else_what_its_name_tells() {
        assert_eq!(
            guessed("GPT-5"),
            Facts {
                text: true,
                image: false,
                thinks: true
            }
        );
        assert_eq!(guessed("openai/gpt-5"), guessed("gpt-5"));
        assert!(guessed("gpt-image-1").image && !guessed("gpt-image-1").text);
        // Not on models.dev's list: by its name.
        assert_eq!(
            guessed("my-rig-7b"),
            Facts {
                text: true,
                ..Facts::default()
            }
        );
        assert!(guessed("my-flux-dev").image);
        assert_eq!(guessed("rig-tts-2"), Facts::default());
        assert_eq!(guessed("rig-embed-small"), Facts::default());
        assert!(!guessed("text-embedding-3-small").text);
        assert!(searches("text-embedding-3-small") && !searches("gpt-5"));
        assert!(speaks("gpt-4o-mini-tts") && speaks("vendor/speech-2") && !speaks("whisper-1"));
        // By its name, as models.dev's list is looked up: listed so by one
        // provider it does not think, by most of those of its name it does.
        assert!(guessed("deepseek-v3-1").thinks);
        // Not listed, a local thinking model is told by its name.
        for id in [
            "qwen3-8b-q4_k_m",
            "DeepSeek-R1-Distill-Llama-8B",
            "my-rig-thinking",
        ] {
            assert!(by_name(id).thinks, "{id}");
        }
        assert!(!by_name("my-rig-7b").thinks);
        assert!(!by_name("Qwen3-30B-A3B-Instruct-2507").thinks);
        assert!(by_name("Qwen3-4B-Thinking-2507").thinks);
    }

    #[test]
    fn a_name_of_another_kind_pictures_or_code_is_no_chat_model() {
        for id in [
            "rig-tts-2",
            "my-flux-dev",
            "rig-coder-7b",
            "o4-mini-deep-research",
        ] {
            assert!(no_chat_by_name(id), "{id}");
        }
        assert!(!no_chat_by_name("tide-1"));
    }
}

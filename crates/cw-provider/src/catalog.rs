//! The models a provider of the account's list offers, each with its kinds, for
//! the model picker of one kind (Settings › Providers and › Models). A model's
//! kind is what the provider says first (OpenRouter's output kinds, NanoGPT's
//! lists, a picture server's checkpoints: `said`), else models.dev, else its name
//! (`facts`); a search model's and a voice's by name alone; whether it thinks
//! likewise.
//!
//! Text models come from `<base>/models`, image models from `images::listed_at`
//! where the provider lists them, else the same list; a provider with only one of
//! them is no failure, and the text list's failure is told beside the picture
//! models (`joined`). A ComfyUI's saved workflows come along (`workflows`). Every
//! model of This computer (`local`) writes text (`own`). Nothing is stored.
//! Over HTTP it is `GET /api/provider-list/{id}/models`.

use std::collections::BTreeMap;

use cw_core::{Code, ErrorBody};
use cw_platform::http::Client;
use serde::Serialize;
use ts_rs::TS;

use crate::images::{self, ImageApi};
use crate::models::{self, Described, Limits, ListedModels, Said};
use crate::{facts, local};

/// A model a provider offers.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct OfferedModel {
    pub id: String,
    /// It writes text: a chat or background model.
    pub text: bool,
    /// It makes pictures.
    pub image: bool,
    /// It turns texts into vectors: a search model.
    pub search: bool,
    /// It reads a text aloud.
    pub voice: bool,
    /// It thinks before it replies.
    pub thinks: bool,
}

/// A provider's models.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct Catalog {
    /// In the order of their IDs, whatever their case.
    pub models: Vec<OfferedModel>,
    /// Whether the provider says what kind each is; else the kinds are guessed.
    pub said: bool,
    /// Whether its list did not come whole.
    pub more: bool,
    /// Why no list came, where none did.
    pub failed: Option<ErrorBody>,
    /// A ComfyUI's saved workflows, by name; none for another provider.
    pub(crate) workflows: Option<Vec<String>>,
}

/// The models the provider at `base_url` offers, asked with `key`.
pub async fn of(http: &Client, base_url: &str, key: &str) -> Catalog {
    if local::at(base_url) {
        let url = format!("{base_url}/models");
        return own(models::described(http, &url, key, Limits::default()).await);
    }
    let api = images::api_of(http, base_url, key).await;
    let openrouter = api == ImageApi::OpenRouter;
    let nanogpt = images::is_nanogpt(base_url);
    let url = if nanogpt {
        format!("{base_url}/models?detailed=true")
    } else {
        format!("{base_url}/models")
    };
    // Any other provider's picture models are on its one list.
    let own_list = openrouter || nanogpt || serves_pictures(api);
    let pictures = async {
        match own_list {
            true => images::listed_at(http, api, base_url, key).await,
            false => Ok(ListedModels {
                models: Vec::new(),
                more: false,
            }),
        }
    };
    let workflows = async {
        match api {
            ImageApi::ComfyUi => Some(images::workflows(http, base_url, key).await),
            _ => None,
        }
    };
    let (texts, pictures, workflows) = tokio::join!(
        models::described(http, &url, key, Limits::default()),
        pictures,
        workflows
    );
    let mut catalog = joined(api, nanogpt, texts, pictures);
    catalog.workflows = workflows.map(|listed| {
        listed.unwrap_or_else(|error| {
            catalog.failed.get_or_insert_with(|| not_listed(&error));
            Vec::new()
        })
    });
    catalog
}

/// This computer's models, from the list of its folder: each a chat model.
fn own(listed: anyhow::Result<Described>) -> Catalog {
    let (models, more, failed) = match listed {
        Ok(listed) => (listed.models, listed.more, None),
        Err(error) => (Vec::new(), false, Some(not_listed(&error))),
    };
    Catalog {
        models: models
            .into_iter()
            .map(|(id, _)| OfferedModel {
                thinks: facts::guessed(&id).thinks,
                text: true,
                image: false,
                search: false,
                voice: false,
                id,
            })
            .collect(),
        said: true,
        more,
        failed,
        workflows: None,
    }
}

/// Why a list did not come, as the UI words it.
fn not_listed(error: &anyhow::Error) -> ErrorBody {
    cw_core::told(error, Code::ModelsNotListed)
}

/// Whether the API is a server of pictures alone: a ComfyUI, an Automatic1111 or a Forge.
fn serves_pictures(api: ImageApi) -> bool {
    matches!(api, ImageApi::ComfyUi | ImageApi::Automatic1111)
}

/// The catalog of the text list and the picture list of a provider that
/// speaks `api`; a list that did not come is told, but a picture server's text list.
fn joined(
    api: ImageApi,
    nanogpt: bool,
    texts: anyhow::Result<Described>,
    pictures: anyhow::Result<ListedModels>,
) -> Catalog {
    let openrouter = api == ImageApi::OpenRouter;
    let mut offered: BTreeMap<(String, String), OfferedModel> = BTreeMap::new();
    let mut more = false;
    let mut failed = None;
    match texts {
        Ok(listed) => {
            more = listed.more;
            for (id, said) in listed.models {
                let model = listed_model(id.clone(), &said, openrouter, nanogpt);
                offered.insert((id.to_lowercase(), id), model);
            }
        }
        // A picture server has no list of chat models: its checkpoints are what it offers.
        Err(_) if serves_pictures(api) => {}
        Err(error) => failed = Some(not_listed(&error)),
    }
    match pictures {
        Ok(listed) => {
            more |= listed.more;
            for id in listed.models {
                offered
                    .entry((id.to_lowercase(), id.clone()))
                    .or_insert_with(|| OfferedModel {
                        id,
                        text: false,
                        image: false,
                        search: false,
                        voice: false,
                        thinks: false,
                    })
                    .image = true;
            }
        }
        Err(error) if serves_pictures(api) => failed = Some(not_listed(&error)),
        Err(_) => {}
    }
    Catalog {
        models: offered
            .into_values()
            .filter(|model| model.text || model.image || model.search || model.voice)
            .collect(),
        said: openrouter || nanogpt || serves_pictures(api),
        more,
        failed,
        workflows: None,
    }
}

/// A model of the text list, with what its provider `said` of it: OpenRouter
/// says what it outputs, everything on NanoGPT's text list writes text (its
/// picture models are on a list of their own, as OpenRouter's), and of any
/// other models.dev or the name tells.
fn listed_model(id: String, said: &Said, openrouter: bool, nanogpt: bool) -> OfferedModel {
    let guessed = facts::guessed(&id);
    let output = said.output.as_ref().filter(|_| openrouter);
    let has = |kind: &str| output.is_some_and(|output| output.iter().any(|said| said == kind));
    OfferedModel {
        text: match output {
            Some(_) => has("text"),
            None => nanogpt || guessed.text,
        },
        image: match openrouter || nanogpt {
            true => has("image"),
            false => guessed.image,
        },
        thinks: said.thinks.unwrap_or(guessed.thinks),
        search: facts::searches(&id),
        voice: facts::speaks(&id),
        id,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cw_core::Fail;

    fn said(output: Option<&[&str]>, thinks: Option<bool>) -> Said {
        Said {
            output: output.map(|kinds| kinds.iter().map(|kind| kind.to_string()).collect()),
            thinks,
        }
    }

    fn kinds(id: &str, said: Said, openrouter: bool, nanogpt: bool) -> (bool, bool, bool) {
        let model = listed_model(id.to_string(), &said, openrouter, nanogpt);
        (model.text, model.image, model.thinks)
    }

    #[test]
    fn what_the_provider_says_of_a_model_comes_before_models_dev_and_its_name() {
        // OpenRouter's output kinds, whatever the name says.
        let both = said(Some(&["text", "image"]), Some(false));
        assert_eq!(
            kinds("vendor/tts-1", both, true, false),
            (true, true, false)
        );
        let picture = said(Some(&["image"]), None);
        assert_eq!(
            kinds("vendor/chat-1", picture, true, false),
            (false, true, false)
        );
        // NanoGPT's text list writes text, and says whether it thinks.
        let thinks = said(None, Some(true));
        assert_eq!(kinds("whisper-x", thinks, false, true), (true, false, true));
        // Any other: models.dev, else the name; unknown is text.
        assert_eq!(
            kinds("o3-mini", said(None, None), false, false),
            (true, false, true)
        );
        assert_eq!(
            kinds("text-embedding-3-small", said(None, None), false, false),
            (false, false, false)
        );
        assert_eq!(
            kinds("tide-1", said(None, None), false, false),
            (true, false, false)
        );
        assert_eq!(
            kinds("dall-e-3", said(None, None), false, false),
            (false, true, false)
        );
        // Output kinds said by another provider than OpenRouter are not read.
        let elsewhere = said(Some(&["image"]), None);
        assert_eq!(
            kinds("tide-1", elsewhere, false, false),
            (true, false, false)
        );
    }

    #[test]
    fn a_search_model_and_a_voice_are_offered_by_their_names() {
        let listed = |ids: &[&str]| {
            Ok(Described {
                models: ids
                    .iter()
                    .map(|id| (id.to_string(), said(None, None)))
                    .collect(),
                more: false,
            })
        };
        let none = || {
            Ok(ListedModels {
                models: Vec::new(),
                more: false,
            })
        };
        let catalog = joined(
            ImageApi::OpenAi,
            false,
            listed(&["text-embedding-3-small", "tts-1", "whisper-1"]),
            none(),
        );
        let kinds: Vec<(&str, bool, bool, bool)> = catalog
            .models
            .iter()
            .map(|model| (model.id.as_str(), model.text, model.search, model.voice))
            .collect();
        assert_eq!(
            kinds,
            [
                ("text-embedding-3-small", false, true, false),
                ("tts-1", false, false, true)
            ]
        );
    }

    #[test]
    fn a_text_list_that_did_not_come_is_told_beside_the_picture_models() {
        let pictures = || {
            Ok(ListedModels {
                models: vec!["flux".into()],
                more: false,
            })
        };
        let failed = || {
            Err(anyhow::anyhow!(
                Fail::said(Code::NotPossible, "the key was refused").with("what", "key_refused")
            ))
        };
        let catalog = joined(ImageApi::OpenRouter, false, failed(), pictures());
        let told = catalog.failed.expect("told");
        assert_eq!(
            (told.code, told.error.as_str()),
            (Code::NotPossible, "the key was refused")
        );
        assert_eq!(catalog.models.len(), 1);
        // A picture server has no text list.
        for api in [ImageApi::ComfyUi, ImageApi::Automatic1111] {
            let catalog = joined(api, false, failed(), pictures());
            assert_eq!(
                (catalog.failed, catalog.models.len(), catalog.said),
                (None, 1, true)
            );
        }
    }
}

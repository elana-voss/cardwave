//! What the tests name in place of the product's, read from the environment in a
//! debug build only (a release build reads none): `CARDWAVE_PROVIDER_PLACES` (their
//! server in place of providers' hosts, every call's, and models.dev); `CARDWAVE_SEARCH_MODEL`,
//! `_VOICE_MODEL`, `_DICTATION_MODEL` ("address size sha256" of a file taken as
//! that model), `CARDWAVE_LOCAL_MODELS` (This computer's list in place of
//! `fit::offered`), `CARDWAVE_EMBEDDER` (a stand-in `llama-server`),
//! `CARDWAVE_DICTATION_HEARS`, `CARDWAVE_NETWORK_LOOPBACK` (network on loopback),
//! `CARDWAVE_NO_FACES`. The standalone server and the desktop app both call
//! `stand_ins`.

use std::time::Duration;

use anyhow::{Context, bail};
use cw_dictation as dictation;
use cw_modelfiles::ModelFile;
use cw_provider::embedder::Runner;
use cw_provider::fit::Offered;
use cw_voice as voice;

use crate::{Network, Options};

/// The environment's `name`, in a debug build only.
fn test_only(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|_| cfg!(debug_assertions))
}

/// What the browser tests name in place of the product's (in a debug build only).
pub fn stand_ins(options: &mut Options) -> anyhow::Result<()> {
    if test_only("CARDWAVE_NO_FACES").is_some() {
        options.faces = None;
    }
    if let Some(places) = test_only("CARDWAVE_PROVIDER_PLACES") {
        // Their stand-in for the hosts has models.dev's too.
        options.models_dev = Some(format!("{places}/models.dev/api.json"));
        // And every provider's public host: no browser test asks a live provider.
        cw_provider::stand_in::every_host(&places);
        options.provider_places = Some(places);
    }
    if let Some(model) = test_only("CARDWAVE_SEARCH_MODEL") {
        options.search.model = model_file("CARDWAVE_SEARCH_MODEL", &model)?;
    }
    if let Some(url) = test_only("CARDWAVE_EMBEDDER") {
        options.search.runner = Runner::At(url);
    }
    if let (Some(file), Some(says)) = (
        test_only("CARDWAVE_DICTATION_MODEL"),
        test_only("CARDWAVE_DICTATION_HEARS"),
    ) {
        let file = model_file("CARDWAVE_DICTATION_MODEL", &file)?;
        options.dictation = dictation::Setup::stand_in(file, &says, Duration::ZERO);
    }
    if let Some(file) = test_only("CARDWAVE_VOICE_MODEL") {
        options.voice = voice::Setup::stand_in(model_file("CARDWAVE_VOICE_MODEL", &file)?);
    }
    if let Some(file) = test_only("CARDWAVE_LOCAL_MODELS") {
        options.local_models = test_models(model_file("CARDWAVE_LOCAL_MODELS", &file)?);
    }
    if test_only("CARDWAVE_NETWORK_LOOPBACK").is_some() {
        options.network = Network::loopback();
    }
    Ok(())
}

/// This computer's list of the browser tests: `file` as "Test model", and one
/// too large for any computer.
fn test_models(file: ModelFile) -> Vec<Offered> {
    let large = ModelFile {
        size: 1 << 50,
        ..file.clone()
    };
    vec![
        Offered {
            name: "Test model".into(),
            file_name: "test-model.gguf".into(),
            file,
        },
        Offered {
            name: "Huge model".into(),
            file_name: "huge-model.gguf".into(),
            file: large,
        },
    ]
}

/// The file "address size sha256" the browser tests name in the variable `name`.
fn model_file(name: &str, value: &str) -> anyhow::Result<ModelFile> {
    let parts: Vec<&str> = value.split_whitespace().collect();
    let [url, size, sha256] = parts[..] else {
        bail!("{name} is \"address size sha256\"");
    };
    Ok(ModelFile {
        url: url.into(),
        size: size.parse().with_context(|| format!("{name}'s size"))?,
        sha256: sha256.into(),
    })
}

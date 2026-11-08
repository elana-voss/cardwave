//! Standalone server for browsers, development and e2e tests.
//!
//! cardwave-server [--port N] [--data-dir PATH] [--web-dir PATH] [--llama-dir PATH]
//!
//! `--llama-dir` holds llama.cpp's `llama-server` (default: `llama` beside this
//! program). The database key comes from `CARDWAVE_DB_KEY`, the OS credential
//! store or the start screen's password. Logs go to the terminal and the data
//! folder's `logs` (`logs.rs`).
//!
//! Debug build only, for the browser tests: `CARDWAVE_PROVIDER_PLACES` (their
//! server in place of providers' hosts and models.dev); `CARDWAVE_SEARCH_MODEL`,
//! `_VOICE_MODEL`, `_DICTATION_MODEL` ("address size sha256" of a file taken as
//! that model), `CARDWAVE_LOCAL_MODELS` (This computer's list in place of
//! `fit::offered`), `CARDWAVE_EMBEDDER` (a stand-in `llama-server`),
//! `CARDWAVE_DICTATION_HEARS`, `CARDWAVE_NETWORK_LOOPBACK` (network on loopback).

use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context, bail};
use cardwave_server::{DEFAULT_PORTS, Network, Options, bind_local, router, serve};
use cw_dictation as dictation;
use cw_modelfiles::ModelFile;
use cw_platform::logs;
use cw_provider::embedder::Runner;
use cw_provider::fit::Offered;
use cw_voice as voice;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let Some(Args {
        port,
        data_dir,
        web_dir,
        llama_dir,
    }) = args()?
    else {
        return Ok(());
    };
    let web_dir = web_dir_or_default(web_dir)?;
    // The logs never stop the server: without them it runs as before.
    if let Err(failure) = logs::start(&data_dir) {
        eprintln!("the logs could not be started: {failure}");
    }
    let mut options = Options::product(data_dir, web_dir, llama_dir)?;
    stand_ins(&mut options)?;
    let app = router(options)?;
    let ports = port.map_or(DEFAULT_PORTS, |p| p..=p);
    let listener = bind_local(ports.clone())
        .await
        .with_context(|| match port {
            Some(p) => format!("cannot listen on port {p}"),
            None => format!("no free port in {}-{}", ports.start(), ports.end()),
        })?;
    println!("Cardwave running at http://{}/", listener.local_addr()?);
    serve(listener, app, async {
        if let Err(failure) = tokio::signal::ctrl_c().await {
            tracing::warn!("Ctrl+C cannot be heard, the server runs until ended: {failure}");
            std::future::pending::<()>().await;
        }
    })
    .await?;
    Ok(())
}

/// What the command line chose.
struct Args {
    port: Option<u16>,
    data_dir: PathBuf,
    web_dir: Option<PathBuf>,
    llama_dir: PathBuf,
}

/// Reads the command line; none after `--help`, which prints the usage.
fn args() -> anyhow::Result<Option<Args>> {
    let mut port = None;
    let mut data_dir = PathBuf::from("data");
    let mut web_dir = None;
    let mut llama_dir = std::env::current_exe()?
        .parent()
        .context("the program has no folder")?
        .join("llama");
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        let mut value = || args.next().with_context(|| format!("{arg} needs a value"));
        match arg.as_str() {
            "--port" => {
                port = Some(
                    value()?
                        .parse::<u16>()
                        .context("--port must be a number from 0 to 65535")?,
                )
            }
            "--data-dir" => data_dir = value()?.into(),
            "--web-dir" => web_dir = Some(PathBuf::from(value()?)),
            "--llama-dir" => llama_dir = value()?.into(),
            "-h" | "--help" => {
                println!(
                    "cardwave-server [--port N] [--data-dir PATH] [--web-dir PATH] [--llama-dir PATH]"
                );
                return Ok(None);
            }
            _ => bail!("unknown argument: {arg}"),
        }
    }
    Ok(Some(Args {
        port,
        data_dir,
        web_dir,
        llama_dir,
    }))
}

/// The web UI's folder: an explicit --web-dir must be valid; the default is
/// relative to the working directory, and without it the API alone is served.
fn web_dir_or_default(given: Option<PathBuf>) -> anyhow::Result<Option<PathBuf>> {
    Ok(match given {
        Some(dir) if !dir.join("index.html").exists() => {
            bail!("no index.html in --web-dir {}", dir.display())
        }
        Some(dir) => Some(dir),
        None => {
            let dir = PathBuf::from("web/dist");
            let found = dir.join("index.html").exists().then_some(dir);
            if found.is_none() {
                eprintln!(
                    "No built web UI at web/dist (run `npm run build` in web/, or pass --web-dir); serving the API only."
                );
            }
            found
        }
    })
}

/// The environment's `name`, in a debug build only.
fn test_only(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|_| cfg!(debug_assertions))
}

/// What the browser tests name in place of the product's (in a debug build only).
fn stand_ins(options: &mut Options) -> anyhow::Result<()> {
    if test_only("CARDWAVE_NO_FACES").is_some() {
        options.faces = None;
    }
    if let Some(places) = test_only("CARDWAVE_PROVIDER_PLACES") {
        // Their stand-in for the hosts has models.dev's too.
        options.models_dev = Some(format!("{places}/models.dev/api.json"));
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

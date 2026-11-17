//! Standalone server for browsers, development and e2e tests.
//!
//! cardwave-server [--port N] [--data-dir PATH] [--web-dir PATH] [--llama-dir PATH]
//!
//! `--llama-dir` holds llama.cpp's `llama-server` (default: `llama` beside this
//! program). The database key comes from `CARDWAVE_DB_KEY`, the OS credential
//! store or the start screen's password. Logs go to the terminal and the data
//! folder's `logs` (`logs.rs`).
//!
//! A debug build reads the tests' stand-ins (`stand_ins.rs`).

use std::path::PathBuf;

use anyhow::{Context, bail};
use cardwave_server::{DEFAULT_PORTS, Options, bind_local, router, serve, stand_ins};
use cw_platform::logs;

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

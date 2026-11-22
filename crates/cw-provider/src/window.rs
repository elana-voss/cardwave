//! A model's context window, the most tokens its prompt and reply may take, from
//! what knows it, never a guess ([`settled`], which `Provider::context` reads):
//! the pretend model's own; This computer's loaded `llama-server`, and any other
//! server on this machine or its local network, by its `/props` (llama.cpp's `n_ctx`); else models.dev's
//! listing of the provider (`models_dev::Index::window`). Such a server is
//! never looked up in models.dev: what it loaded can differ from what
//! is listed. Where none knows it, the user's "Context size" stands in, else a
//! reply fails as needed (`context_size`, `Provider::context`). Such a server
//! that does not answer fails as unreachable, as a reply would.

use std::net::{Ipv4Addr, Ipv6Addr};
use std::time::Duration;

use anyhow::bail;
use cw_core::{Code, Fail};
use cw_platform::http::{Client, Url};
use serde_json::Value;

use crate::models_dev::Index;
use crate::{Provider, list, local, pretend};

/// How long a server on this machine may take to tell its window.
const ASK_LIMIT: Duration = Duration::from_secs(10);

/// `provider` with its model's window, where something knows it.
pub async fn settled(http: &Client, index: &Index, provider: Provider) -> anyhow::Result<Provider> {
    let window = of(http, index, &provider).await?;
    Ok(Provider { window, ..provider })
}

/// The window of `provider`'s model; a failure only where This computer cannot load it.
async fn of(http: &Client, index: &Index, provider: &Provider) -> anyhow::Result<Option<usize>> {
    let (base_url, model) = (provider.base_url.as_str(), provider.model.as_str());
    if pretend::at(base_url) {
        return Ok(Some(pretend::WINDOW));
    }
    if local::at(base_url) {
        return local::window(http, base_url, model).await;
    }
    if let Some(root) = on_this_machine(base_url) {
        let key = (!provider.api_key.is_empty()).then(|| format!("Bearer {}", provider.api_key));
        return props(http, &root, key.as_deref()).await;
    }
    let key = list::at(base_url).and_then(|listed| listed.models_dev.as_deref());
    Ok(index
        .window(base_url, key, model)
        .and_then(|window| usize::try_from(window).ok()))
}

/// The root of `base_url` where it is a server on this machine or its local
/// network (a private or link-local address, a name without a dot or under
/// `.local`, `.lan`, `.internal`, `.home.arpa`): what such a server loaded can
/// differ from any list, so only it is asked.
fn on_this_machine(base_url: &str) -> Option<String> {
    let url = Url::parse(base_url).ok()?;
    let host = url.host_str()?.to_lowercase();
    let nearby = if let Ok(ip) = host.parse::<Ipv4Addr>() {
        ip.is_loopback() || ip.is_private() || ip.is_link_local() || ip.is_unspecified()
    } else if let Ok(ip) = host.trim_matches(['[', ']']).parse::<Ipv6Addr>() {
        let first = ip.segments()[0];
        ip.is_loopback()
            || ip.is_unspecified()
            || first & 0xfe00 == 0xfc00
            || first & 0xffc0 == 0xfe80
    } else {
        let name = host.trim_end_matches('.');
        !name.contains('.')
            || [".local", ".lan", ".internal", ".home.arpa"]
                .iter()
                .any(|end| name.ends_with(end))
    };
    nearby.then(|| url.origin().ascii_serialization())
}

/// The window a llama.cpp server at `root` loaded, as its `/props` says; none
/// where it does not answer so. Where nothing answers at `root`, the failure a
/// reply there would meet ("cannot be reached"), never an unknown window.
pub(crate) async fn props(
    http: &Client,
    root: &str,
    authorization: Option<&str>,
) -> anyhow::Result<Option<usize>> {
    let mut asked = http.get(format!("{root}/props")).timeout(ASK_LIMIT);
    if let Some(authorization) = authorization {
        asked = asked.header(cw_platform::http::header::AUTHORIZATION, authorization);
    }
    let answer = match asked.send().await {
        Ok(answer) if answer.status().is_success() => answer,
        Ok(answer) => {
            tracing::debug!("{root}/props answered {}", answer.status());
            return Ok(None);
        }
        Err(failure) if failure.is_timeout() => {
            tracing::debug!("{root}/props was not answered in time");
            return Ok(None);
        }
        Err(failure) => {
            tracing::info!("{root}/props was not answered: {failure}");
            let whose = "the model's server";
            bail!(
                Fail::said(Code::Unreachable, format!("{whose} cannot be reached"))
                    .with("whose", crate::ui_name(whose))
            );
        }
    };
    let Ok(said) = answer.json::<Value>().await else {
        return Ok(None);
    };
    let window = said["default_generation_settings"]["n_ctx"].as_u64();
    Ok(window
        .and_then(|window| usize::try_from(window).ok())
        .filter(|window| *window > 0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_server_on_the_local_network_is_asked_never_a_list() {
        let nearby = |url: &str| on_this_machine(url).is_some();
        for url in [
            "http://127.0.0.1:8080/v1",
            "http://[::1]:8080/v1",
            "http://192.168.1.20:11434/v1",
            "http://10.0.0.5/v1",
            "http://0.0.0.0:1234/v1",
            "http://host.docker.internal:11434/v1",
            "http://gpu-box:8000/v1",
            "http://gpu-box.local:8000/v1",
        ] {
            assert!(nearby(url), "{url}");
        }
        for url in ["https://api.openai.com/v1", "https://8.8.8.8/v1"] {
            assert!(!nearby(url), "{url}");
        }
    }

    fn at(base_url: &str, model: &str) -> Provider {
        Provider {
            base_url: base_url.into(),
            api_key: String::new(),
            model: model.into(),
            sampling: Default::default(),
            name: String::new(),
            thinking_off: None,
            reply_limit: None,
            seen_thinking: false,
            window: None,
        }
    }

    /// A server on this machine that answers `/props` with `answer`.
    async fn serving(answer: &'static str) -> String {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let root = format!("http://{}", listener.local_addr().unwrap());
        tokio::spawn(async move {
            while let Ok((mut socket, _)) = listener.accept().await {
                let mut buffer = [0; 2048];
                let _read = socket.read(&mut buffer).await;
                let reply = format!(
                    "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{answer}",
                    answer.len()
                );
                // A test whose answer is not taken fails on its own.
                let _sent = socket.write_all(reply.as_bytes()).await;
            }
        });
        root
    }

    const LIST: &str = r#"{
        "openai": { "models": { "gpt-5": { "id": "gpt-5", "limit": { "context": 400000 } } } },
        "router": { "api": "https://router.example/api/v1", "models": {
            "openai/gpt-5": { "id": "openai/gpt-5", "limit": { "context": 272000 } } } }
    }"#;

    #[tokio::test]
    async fn each_source_tells_the_window_and_none_is_guessed() {
        let http = Client::new();
        let index = Index::read(LIST.as_bytes()).unwrap();
        let window = |provider: Provider| {
            let (http, index) = (&http, &index);
            async move { settled(http, index, provider).await.unwrap().window }
        };
        // The pretend model's own.
        assert_eq!(
            window(at(pretend::ADDRESS, "pretend-chat")).await,
            Some(pretend::WINDOW)
        );
        // A server on this machine by its /props, never by models.dev.
        let root = serving(r#"{"default_generation_settings":{"n_ctx":8192}}"#).await;
        assert_eq!(window(at(&format!("{root}/v1"), "gpt-5")).await, Some(8192));
        let silent = serving(r#"{"status":"ok"}"#).await;
        assert_eq!(window(at(&format!("{silent}/v1"), "gpt-5")).await, None);
        // A listed provider by models.dev's key, another by its address's host.
        assert_eq!(
            window(at("https://api.openai.com/v1", "gpt-5")).await,
            Some(400000)
        );
        assert_eq!(
            window(at("https://router.example/api/v1", "openai/gpt-5")).await,
            Some(272000)
        );
        // Unknown: none.
        assert_eq!(
            window(at("https://elsewhere.example/v1", "gpt-5")).await,
            None
        );
    }
}

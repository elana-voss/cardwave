//! The web tool: a search (DuckDuckGo's page without scripts, asked as a form
//! is sent, which needs no key) and a page read as text.
//!
//! Only the open internet is reached: an address of this computer or of a
//! private network is refused, by name (`GUARD`, which every connection's
//! name goes through, redirects too, and no proxy is asked in its place) and
//! by number (`numbered_open`), both by `http::public`, so that a page cannot have the model read the app's own API or a
//! device at home. A result of the search that leads through DuckDuckGo's
//! own address is given as the address it leads to (`decoded_link`). A test
//! has `Web::stand_in`, its own server, asked in place of every host,
//! `https://host/path` as `/host/path`, without the guard.

use std::sync::LazyLock;
use std::time::Duration;

use anyhow::{Context, bail, ensure};
use cw_platform::http::header::CONTENT_TYPE;
use cw_platform::http::{Client, Lookup, Make, Redirects, Refusal, Url, public};
use regex::Regex;

/// Where a search is sent.
const SEARCH: &str = "https://lite.duckduckgo.com/lite/";

/// How many results a search gives.
const RESULTS: usize = 8;

/// The most of a page that is read, in bytes.
const PAGE_LIMIT: usize = 2 << 20;

/// The most of a page's text the model is given, in characters.
pub const TEXT_LIMIT: usize = 20_000;

/// How long a page may take.
const TIMEOUT: Duration = Duration::from_secs(20);

/// Asks the web. One is kept for as long as the server runs.
pub struct Web {
    client: Client,
    stand_in: Option<String>,
}

impl Web {
    pub fn new(stand_in: Option<String>) -> cw_platform::http::Result<Self> {
        let mut make = Make {
            whole: Some(TIMEOUT),
            agent: Some("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Cardwave"),
            ..Default::default()
        };
        if stand_in.is_none() {
            make.lookup = Some(GUARD);
            make.redirects = Redirects::Checked {
                most: 5,
                open: numbered_open,
                refused,
            };
        }
        let client = cw_platform::http::client(make)?;
        Ok(Self {
            client,
            stand_in: stand_in.map(|at| at.trim_end_matches('/').to_string()),
        })
    }

    /// Where `url` is asked: itself, or the test's stand-in.
    fn at(&self, url: &Url) -> String {
        match &self.stand_in {
            Some(at) => format!(
                "{at}/{}{}{}",
                url.host_str().unwrap_or_default(),
                url.path(),
                url.query()
                    .map(|query| format!("?{query}"))
                    .unwrap_or_default()
            ),
            None => url.to_string(),
        }
    }

    /// The first results for `query`: each its title, address and what the
    /// search says of it.
    pub async fn search(&self, query: &str) -> anyhow::Result<String> {
        let url = Url::parse(SEARCH)?;
        let response = self
            .client
            .post(self.at(&url))
            .form(&[("q", query)])
            .send()
            .await
            .context("the search cannot be reached")?;
        ensure!(
            response.status().is_success(),
            "the search answered {}",
            response.status()
        );
        let page = read(response).await?;
        let found = results(&String::from_utf8_lossy(&page));
        if found.is_empty() {
            return Ok(format!("No results for {query:?}."));
        }
        Ok(found
            .iter()
            .map(|(title, address, about)| format!("{title}\n{address}\n{about}"))
            .collect::<Vec<_>>()
            .join("\n\n"))
    }

    /// The text of the page at `address`.
    pub async fn read(&self, address: &str) -> anyhow::Result<String> {
        Ok(self.page(address).await?.text)
    }

    /// The page at `address`: its title, where it is HTML that has one, and its text.
    pub async fn page(&self, address: &str) -> anyhow::Result<Page> {
        let url = Url::parse(address.trim()).context("that is no web address")?;
        ensure!(
            matches!(url.scheme(), "http" | "https"),
            "only http and https addresses are read"
        );
        if self.stand_in.is_none() && !numbered_open(&url) {
            bail!(Closed);
        }
        let response =
            self.client
                .get(self.at(&url))
                .send()
                .await
                .map_err(|error| match closed(&error) {
                    true => anyhow::anyhow!(Closed),
                    false => anyhow::Error::new(error).context("the page cannot be reached"),
                })?;
        ensure!(
            response.status().is_success(),
            "the page answered {}",
            response.status()
        );
        let kind = response
            .headers()
            .get(CONTENT_TYPE)
            .and_then(|kind| kind.to_str().ok())
            .unwrap_or("text/html")
            .to_ascii_lowercase();
        let page = read(response).await?;
        let page = String::from_utf8_lossy(&page);
        let html = kind.contains("html");
        let title = if html { title_of(&page) } else { String::new() };
        let text = if html {
            text_of(&page)
        } else if kind.starts_with("text/") || kind.contains("json") || kind.contains("xml") {
            page.trim().to_string()
        } else {
            bail!("the page is no text ({kind})")
        };
        Ok(Page {
            title,
            text: cut(&text, TEXT_LIMIT),
        })
    }
}

/// A page read: its title, empty where it has none, and its text.
pub struct Page {
    pub title: String,
    pub text: String,
}

/// The title of the page `html`, as one line; empty where it has none.
fn title_of(html: &str) -> String {
    // A fixed pattern, run by this file's tests: it compiles.
    static TITLE: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"(?is)<title\b[^>]*>(.*?)</title\s*>").unwrap());
    let title = TITLE
        .captures(html)
        .map_or(String::new(), |found| decoded(&found[1]));
    title.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// The address is on this computer or in a private network.
#[derive(Debug)]
struct Closed;

impl std::fmt::Display for Closed {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("addresses on this computer or in a private network are not read")
    }
}

impl std::error::Error for Closed {}

/// `Closed`, as a client's check refuses.
fn refused() -> Refusal {
    Box::new(Closed)
}

/// Whether `Closed` is what an error of the client comes down to.
fn closed(error: &(dyn std::error::Error + 'static)) -> bool {
    let mut cause = Some(error);
    while let Some(now) = cause {
        if now.is::<Closed>() {
            return true;
        }
        cause = now.source();
    }
    false
}

/// Resolves a name to its addresses on the open internet alone.
const GUARD: Lookup = Lookup {
    keep: public,
    none: refused,
};

/// Whether a URL whose host is a number is on the open internet; a name is
/// left to `GUARD`.
fn numbered_open(url: &Url) -> bool {
    let Some(host) = url.host_str() else {
        return false;
    };
    match host.trim_start_matches('[').trim_end_matches(']').parse() {
        Ok(ip) => public(ip),
        Err(_) => true,
    }
}

/// What an answer says, as far as `PAGE_LIMIT`.
async fn read(mut response: cw_platform::http::Response) -> anyhow::Result<Vec<u8>> {
    let mut page = Vec::new();
    while page.len() < PAGE_LIMIT
        && let Some(more) = response.chunk().await.context("the page broke off")?
    {
        page.extend_from_slice(&more);
    }
    page.truncate(PAGE_LIMIT);
    Ok(page)
}

/// The results on a page of DuckDuckGo's search without scripts: a link of
/// the class `result-link` each, and the snippet after it.
fn results(page: &str) -> Vec<(String, String, String)> {
    static LINK: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r#"(?s)<a[^>]*href="([^"]+)"[^>]*class=['"]result-link['"][^>]*>(.*?)</a>"#)
            // A fixed pattern, run by this file's tests: it compiles.
            .unwrap()
    });
    static SNIPPET: LazyLock<Regex> = LazyLock::new(|| {
        // A fixed pattern, run by this file's tests: it compiles.
        Regex::new(r#"(?s)class=['"]result-snippet['"][^>]*>(.*?)</td>"#).unwrap()
    });
    let links: Vec<_> = LINK.captures_iter(page).collect();
    links
        .iter()
        .enumerate()
        .take(RESULTS)
        .map(|(at, link)| {
            // Group 0, the whole match, is always there.
            let whole = link.get(0).unwrap();
            let end = links
                .get(at + 1)
                // Group 0, the whole match, is always there.
                .map_or(page.len(), |next| next.get(0).unwrap().start());
            let about = SNIPPET
                .captures(&page[whole.end()..end])
                .map(|snippet| text_of(&snippet[1]))
                .unwrap_or_default();
            (text_of(&link[2]), decoded_link(&decoded(&link[1])), about)
        })
        .collect()
}

/// Where a result's link leads: through DuckDuckGo's own address
/// (`//duckduckgo.com/l/?uddg=…`), the address in its `uddg`.
fn decoded_link(link: &str) -> String {
    let inner = link
        .strip_prefix("//duckduckgo.com/l/?")
        .or(link.strip_prefix("https://duckduckgo.com/l/?"))
        .and_then(|query| query.split('&').find_map(|pair| pair.strip_prefix("uddg=")));
    match inner {
        Some(inner) => percent_encoding::percent_decode_str(inner)
            .decode_utf8_lossy()
            .into_owned(),
        None => link.to_string(),
    }
}

/// The text of HTML: what scripts, styles and the head hold left out, a line
/// after each block, and the characters its entities stand for.
pub fn text_of(html: &str) -> String {
    static HIDDEN: LazyLock<Regex> = LazyLock::new(|| {
        // A fixed pattern, run by this file's tests: it compiles.
        Regex::new(r"(?is)<!--.*?-->|<(script|style|head|noscript|svg|template)\b.*?</(script|style|head|noscript|svg|template)\s*>").unwrap()
    });
    static BLOCK: LazyLock<Regex> = LazyLock::new(|| {
        // A fixed pattern, run by this file's tests: it compiles.
        Regex::new(r"(?i)</?(p|div|br|li|tr|h[1-6]|section|article|header|footer|ul|ol|table|pre|blockquote)\b[^>]*>").unwrap()
    });
    // A fixed pattern, run by this file's tests: it compiles.
    static TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?s)<[^>]*>").unwrap());
    // A fixed pattern, run by this file's tests: it compiles.
    static SPACES: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[ \t\r\f\v]+").unwrap());
    // A fixed pattern, run by this file's tests: it compiles.
    static LINES: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s*\n\s*").unwrap());
    let text = HIDDEN.replace_all(html, " ");
    let text = BLOCK.replace_all(&text, "\n");
    let text = TAG.replace_all(&text, "");
    let text = decoded(&text);
    let text = SPACES.replace_all(&text, " ");
    LINES.replace_all(text.trim(), "\n").into_owned()
}

/// `text` with its HTML entities as the characters they stand for.
fn decoded(text: &str) -> String {
    static ENTITY: LazyLock<Regex> =
        // A fixed pattern, run by this file's tests: it compiles.
        LazyLock::new(|| Regex::new(r"&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);").unwrap());
    ENTITY
        .replace_all(text, |found: &regex::Captures| {
            let name = &found[1];
            let sign = if let Some(hex) = name.strip_prefix("#x").or(name.strip_prefix("#X")) {
                u32::from_str_radix(hex, 16).ok().and_then(char::from_u32)
            } else if let Some(number) = name.strip_prefix('#') {
                number.parse().ok().and_then(char::from_u32)
            } else {
                match name {
                    "amp" => Some('&'),
                    "lt" => Some('<'),
                    "gt" => Some('>'),
                    "quot" => Some('"'),
                    "apos" => Some('\''),
                    "nbsp" => Some(' '),
                    _ => None,
                }
            };
            sign.map_or_else(|| found[0].to_string(), String::from)
        })
        .into_owned()
}

/// `text` to at most `limit` characters, which it then says with how many it
/// had: every tool's answer that is cut (pages, files, Cardwave's own).
pub fn cut(text: &str, limit: usize) -> String {
    match text.char_indices().nth(limit) {
        Some((at, _)) => format!(
            "{}\n… (cut at {limit} characters of {})",
            &text[..at],
            text.chars().count()
        ),
        None => text.to_string(),
    }
}

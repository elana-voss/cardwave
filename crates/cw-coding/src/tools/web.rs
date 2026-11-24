//! The web tool: a search (DuckDuckGo's page without scripts, asked as a form
//! is sent, which needs no key) and a page read as text; the HTML of both
//! is read by `html.rs`.
//!
//! Only the open internet is reached: an address of this computer or of a
//! private network is refused, by name (`GUARD`, which every connection's
//! name goes through, redirects too, and no proxy is asked in its place) and
//! by number (`numbered_open`), both by `http::public`, so that a page cannot have the model read the app's own API or a
//! device at home. A result of the search that leads through DuckDuckGo's
//! own address is given as the address it leads to (`decoded_link`). A test
//! has `Web::stand_in`, its own server, asked in place of every host,
//! `https://host/path` as `/host/path`, without the guard. Each gives a
//! `Gave`; each failure of its own is a `Fail` with its code and `what` or
//! `whose`, whose sentence is what the model reads.

use std::time::Duration;

use crate::tools::gave::{Gave, kept};
use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use cw_platform::http::header::CONTENT_TYPE;
use cw_platform::http::{Client, Lookup, Make, Redirects, Refusal, StatusCode, Url, public};

mod html;

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
            Some(at) => cw_provider::stand_in::address(at, url.as_str()),
            None => url.to_string(),
        }
    }

    /// The first results for `query`: each its title, address and what the
    /// search says of it.
    pub async fn search(&self, query: &str) -> anyhow::Result<Gave> {
        let url = Url::parse(SEARCH)?;
        let response = self
            .client
            .post(self.at(&url))
            .form(&[("q", query)])
            .send()
            .await
            .context(unreachable("search"))?;
        answered("search", response.status())?;
        let page = read(response).await?;
        let found = html::results(&String::from_utf8_lossy(&page));
        if found.is_empty() {
            return Ok(Gave::NoResults {
                query: query.to_string(),
            });
        }
        let text = found
            .iter()
            .take(RESULTS)
            .map(|one| format!("{}\n{}\n{}", one.title, decoded_link(&one.link), one.about))
            .collect::<Vec<_>>()
            .join("\n\n");
        Ok(Gave::Text { text, whole: None })
    }

    /// The text of the page at `address`.
    pub async fn read(&self, address: &str) -> anyhow::Result<Gave> {
        Ok(self.page(address).await?.gave())
    }

    /// The page at `address`: its title, where it is HTML that has one, and
    /// its text. A page that refreshes to another at once (`<meta
    /// http-equiv="refresh">`) is read there, as a browser goes on.
    pub async fn page(&self, address: &str) -> anyhow::Result<Page> {
        let mut url = Url::parse(address.trim()).context(
            Fail::said(Code::NotReadable, "that is no web address").with("what", "web_address"),
        )?;
        for _ in 0..REFRESHES {
            match self.one_page(&url).await? {
                Read::Moved(next) => url = next,
                Read::Page(page) => return Ok(page),
            }
        }
        let said = "the page refreshes to another again and again";
        bail!(Fail::said(Code::NotPossible, said).with("what", "page_refreshes"))
    }

    /// The page at `url`, or where it refreshes to.
    async fn one_page(&self, url: &Url) -> anyhow::Result<Read> {
        if !matches!(url.scheme(), "http" | "https") {
            let said = "only http and https addresses are read";
            bail!(Fail::said(Code::NotPossible, said).with("what", "page_scheme"));
        }
        if self.stand_in.is_none() && !numbered_open(url) {
            bail!(Closed::fail());
        }
        let response = self
            .client
            .get(self.at(url))
            .send()
            .await
            .map_err(|error| match closed(&error) {
                true => anyhow::anyhow!(Closed::fail()),
                false => anyhow::Error::new(error).context(unreachable("page")),
            })?;
        answered("page", response.status())?;
        let kind = response
            .headers()
            .get(CONTENT_TYPE)
            .and_then(|kind| kind.to_str().ok())
            .unwrap_or("text/html")
            .to_ascii_lowercase();
        let page = read(response).await?;
        let page = String::from_utf8_lossy(&page);
        let (title, text) = if kind.contains("html") {
            let read = html::read(&page);
            let refresh = read.refresh.as_deref();
            if let Some(next) = refresh.and_then(|content| refreshed_to(content, url)) {
                return Ok(Read::Moved(next));
            }
            (read.title, read.text)
        } else if kind.starts_with("text/") || kind.contains("json") || kind.contains("xml") {
            (String::new(), page.trim().to_string())
        } else {
            let said = format!("the page is no text ({kind})");
            let fail = Fail::said(Code::NotReadable, said).with("what", "page_kind");
            bail!(fail.with("kind", kind))
        };
        let (text, whole) = kept(&text, TEXT_LIMIT);
        Ok(Read::Page(Page { title, text, whole }))
    }
}

/// How many pages one read goes through by their refreshes, the first too.
const REFRESHES: usize = 6;

/// One address read: its page, or the address it refreshes to.
enum Read {
    Page(Page),
    Moved(Url),
}

/// Where the page at `url` refreshes to at once, by the `content` of its
/// `<meta http-equiv="refresh">` (`0; url=…`); none where it waits first or
/// names its own address.
fn refreshed_to(content: &str, url: &Url) -> Option<Url> {
    let (wait, rest) = content.split_once(';').unwrap_or((content, ""));
    (wait.trim().parse::<f64>().ok()? <= 1.0).then_some(())?;
    let rest = rest.trim();
    let target = rest
        .get(..4)
        .filter(|start| start.eq_ignore_ascii_case("url="))
        .map_or(rest, |_| &rest[4..])
        .trim()
        .trim_matches(|c| c == '\'' || c == '"');
    let next = url.join(target).ok()?;
    (!target.is_empty() && next != *url).then_some(next)
}

/// A page read: its title, empty where it has none, and its text, cut at
/// [`TEXT_LIMIT`] characters of `whole` where it was longer.
pub struct Page {
    pub title: String,
    pub text: String,
    pub whole: Option<usize>,
}

impl Page {
    /// Its text as the tool gives it.
    pub fn gave(self) -> Gave {
        Gave::Text {
            text: self.text,
            whole: self.whole,
        }
    }
}

/// `whose` (the search, the page) cannot be reached.
fn unreachable(whose: &str) -> Fail {
    Fail::said(Code::Unreachable, format!("the {whose} cannot be reached")).with("whose", whose)
}

/// `whose` (the search, the page) answered `status`, where it is a failure.
fn answered(whose: &str, status: StatusCode) -> Result<(), Fail> {
    match status.is_success() {
        true => Ok(()),
        false => Err(
            Fail::said(Code::Answered, format!("the {whose} answered {status}"))
                .with("whose", whose)
                .with("status", status.as_u16()),
        ),
    }
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

impl Closed {
    /// The refusal as the tool fails with it.
    fn fail() -> Fail {
        Fail::said(Code::NotPossible, Closed.to_string()).with("what", "page_closed")
    }
}

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

/// `text` to at most `limit` characters, which it then says with how many it
/// had: every tool's answer that is cut (pages, files, Cardwave's own).
pub fn cut(text: &str, limit: usize) -> String {
    Gave::text(text, limit).for_model()
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};

    use super::*;

    /// A stand-in that answers its requests in turn with `pages` (HTML).
    fn serving(pages: Vec<&'static str>) -> String {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("a port");
        let url = format!("http://{}", listener.local_addr().expect("its address"));
        std::thread::spawn(move || {
            for page in pages {
                let (mut stream, _) = listener.accept().expect("a request");
                let mut buffer = [0u8; 4096];
                // The request is read only to be answered after it.
                let _ = stream.read(&mut buffer);
                let answer = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{page}",
                    page.len()
                );
                stream.write_all(answer.as_bytes()).expect("the answer");
            }
        });
        url
    }

    #[tokio::test]
    async fn a_page_that_refreshes_to_another_is_read_there() {
        let moved = r#"<html><head><meta http-equiv="Refresh" content="0; URL='/new/place'"></head><body>Moved.</body></html>"#;
        let there =
            "<html><head><title>New place</title></head><body>The lamp is lit.</body></html>";
        let web = Web::new(Some(serving(vec![moved, there]))).expect("a client");
        let page = web.page("https://example.com/old").await.expect("the page");
        assert_eq!(
            (page.title.as_str(), page.text.as_str()),
            ("New place", "The lamp is lit.")
        );
    }
}

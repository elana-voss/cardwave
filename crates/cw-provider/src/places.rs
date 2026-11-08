//! The search for the API of a provider that is not on the list: the user
//! gives the provider's website, and the usual places of an API are asked
//! there, without a key. What it finds is shown to the user, who takes it or
//! not: the server sends no key to an address because it was found.
//!
//! The server asks addresses a user chose, so it asks little: `https` only,
//! on the domain given and the hosts under it that [`PLACES`] names, at no
//! address inside the server's own network, following no redirect, for a few
//! seconds, reading no more of an answer than its start, and it tells nothing
//! of an answer but whether it is an API's.
//!
//! `Finder` is kept in the server's state; `PLACES` are the usual places,
//! `host_of` reads a website as its domain; where a name may lead is
//! `http::public`'s. Over HTTP it is `POST /api/provider/find`, which stores nothing.

use std::time::Duration;

use anyhow::Context;
use cw_core::{Code, Fail};
use cw_platform::http::header::{ACCEPT, CONTENT_TYPE};
use cw_platform::http::{Client, Lookup, Make, Redirects, Url};
use futures_util::{StreamExt, stream};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::{list, models};

/// Where providers have their API, as what stands before the domain and what
/// after it, in the order they are tried: the first that answers as an API is
/// taken. From the spike "Provider setup helper", which found 27 of 44
/// providers' addresses with them.
pub const PLACES: [(&str, &str); 11] = [
    ("api.", "/v1"),
    ("", "/api/v1"),
    ("", "/v1"),
    ("api.", "/openai/v1"),
    ("api.", "/api/v1"),
    ("api.", "/v1/openai"),
    ("api.", "/inference/v1"),
    ("llm.", "/v1"),
    ("router.", "/v1"),
    ("inference.", "/v1"),
    ("api.", ""),
];

/// A place no API has. A host that answers it as it answers the list of models
/// refuses every path alike, which says nothing of an API.
const NOWHERE: &str = "cardwave-no-such-place";

/// How long a place may take to be reached, and to answer.
const CONNECT_TIMEOUT: Duration = Duration::from_secs(5);
const ANSWER_TIMEOUT: Duration = Duration::from_secs(10);

/// How much of a list of models is read. A provider's list may be megabytes
/// long (Featherless's is 7 MB), and its start says that it is one.
const LIST_START: usize = 64 << 10;
/// How much of a refusal is read, to tell a page from an API's answer.
const REFUSAL_LIMIT: usize = 2048;

/// The longest name of a host that is asked: a domain's 253 letters.
const HOST_LIMIT: usize = 253;

/// What the search is asked: the provider's website.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct FindProvider {
    /// A domain (`example.com`) or an address of the website.
    pub website: String,
}

/// An address for the form to offer.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct FoundProvider {
    pub base_url: String,
    /// What the list calls the provider, if the address is from the list and
    /// not found by asking.
    pub name: Option<String>,
}

/// Asks the places. One is kept for as long as the server runs.
pub struct Finder {
    http: Client,
    /// A test's own server, asked in place of every host: `https://host/path`
    /// is asked as `<stand-in>/host/path`. It is given by its IP address, as a
    /// name is looked up, and one that leads to this machine is not asked.
    stand_in: Option<String>,
}

impl Finder {
    pub fn new(stand_in: Option<String>) -> cw_platform::http::Result<Self> {
        // Names are looked up as the system does, and only the addresses out
        // in the internet are kept, so that a name cannot lead the search into
        // the server's own network.
        let http = cw_platform::http::client(Make {
            connect: Some(CONNECT_TIMEOUT),
            whole: Some(ANSWER_TIMEOUT),
            agent: Some(crate::app_name::NAME),
            redirects: Redirects::None,
            lookup: Some(Lookup {
                keep: cw_platform::http::public,
                none: || Box::new(std::io::Error::other("the name leads to no public address")),
            }),
            ..Default::default()
        })?;
        Ok(Self {
            http,
            stand_in: stand_in.map(|at| at.trim_end_matches('/').to_string()),
        })
    }

    /// The address of the API of the provider whose website is `website`: the
    /// list's, if the list has that provider, else the first of the usual
    /// places there that answers as an API does. `None` when there is none.
    pub async fn find(&self, website: &str) -> anyhow::Result<Option<FoundProvider>> {
        let host = host_of(website).context(
            Fail::said(
                Code::NotReadable,
                "give the provider's website as a name such as example.com",
            )
            .with("what", "provider_website"),
        )?;
        if let Some(known) = list::of_website(&host) {
            return Ok(Some(FoundProvider {
                base_url: known.base_url.clone(),
                name: Some(known.name.clone()),
            }));
        }
        let asked = self.ask_places(&host).await;
        Ok(asked.map(|base_url| FoundProvider {
            base_url,
            name: None,
        }))
    }

    /// The first of the usual places on the domain `host` that answers as an
    /// API does, whatever the list says of that domain.
    async fn ask_places(&self, host: &str) -> Option<String> {
        // All are asked at once, and the first in the order counts: it waits
        // for those before it only. Leaving hangs up on the rest.
        let asked = places(host)
            .into_iter()
            .map(|base| async move { self.is_api(&base).await.then_some(base) });
        let mut found = stream::iter(asked).buffered(PLACES.len());
        while let Some(answer) = found.next().await {
            if answer.is_some() {
                return answer;
            }
        }
        None
    }

    /// The keyless check: the list of models at `base` is one, or is refused
    /// for the missing key as an API refuses, and a place that cannot be
    /// there is not answered the same way.
    async fn is_api(&self, base: &str) -> bool {
        let models = self.ask(&format!("{base}/models")).await;
        let counts = match models.status {
            200 => models.list,
            401 | 403 => true,
            _ => false,
        };
        counts && !models.html && self.ask(&format!("{base}/{NOWHERE}")).await != models
    }

    async fn ask(&self, address: &str) -> Answer {
        let address = match &self.stand_in {
            Some(at) => format!("{at}/{}", address.trim_start_matches("https://")),
            None => address.to_string(),
        };
        let asked = self.http.get(address).header(ACCEPT, "application/json");
        let Ok(mut response) = asked.send().await else {
            return Answer::default();
        };
        let status = response.status().as_u16();
        let limit = if status == 200 {
            LIST_START
        } else {
            REFUSAL_LIMIT
        };
        let mut html = response
            .headers()
            .get(CONTENT_TYPE)
            .is_some_and(|kind| String::from_utf8_lossy(kind.as_bytes()).contains("html"));
        // Read until it shows a page or a list, to its end or to the limit:
        // what is left then is hung up on.
        let mut said = Vec::new();
        let mut list = false;
        while said.len() < limit
            && !html
            && !list
            && let Ok(Some(more)) = response.chunk().await
        {
            said.extend_from_slice(&more);
            html = said.trim_ascii_start().starts_with(b"<");
            list = models::read(&said).list;
        }
        Answer { status, html, list }
    }
}

/// What of an answer counts. Without an answer the status is 0.
#[derive(Default, PartialEq)]
struct Answer {
    status: u16,
    /// A web page, not an API's answer.
    html: bool,
    /// A list of models: JSON that begins as a list, or with one under `data`.
    list: bool,
}

/// The addresses tried for the website `host`, in their order: each `https`,
/// on `host` or a host under it.
pub fn places(host: &str) -> Vec<String> {
    let place = |(before, after): &(&str, &str)| format!("https://{before}{host}{after}");
    PLACES.iter().map(place).collect()
}

/// The domain a user means by `website`, which may be the domain or an address
/// on it, with or without `www.`. `None` for what is no domain: a name without
/// a dot, as `localhost`, an IP address, anything else.
pub fn host_of(website: &str) -> Option<String> {
    let typed = website.trim();
    let address = match typed.contains("://") {
        true => typed.to_string(),
        false => format!("https://{typed}"),
    };
    let address = Url::parse(&address).ok()?;
    let host = address.domain()?.trim_end_matches('.');
    let host = host.strip_prefix("www.").unwrap_or(host);
    let label = |label: &str| {
        !label.is_empty()
            && label
                .bytes()
                .all(|letter| letter.is_ascii_alphanumeric() || letter == b'-')
    };
    let web = matches!(address.scheme(), "http" | "https");
    // Room for the longest of what the places put before it.
    let fits = host.len() + "inference.".len() <= HOST_LIMIT;
    (web && fits && host.contains('.') && host.split('.').all(label)).then(|| host.to_string())
}

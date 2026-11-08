//! The providers the app knows by name: the list kept with it, from which the
//! account's form fills in an address. It is the two files in
//! `crates/cw-provider/providers`, built into the server; `own.toml` says what an entry
//! holds.
//!
//! `own.toml` is kept by hand, and `models.dev.toml` is written by
//! `tools/providers.py`. Over HTTP the list is `GET /api/providers`. An entry
//! of `own.toml` may say how the provider's keys begin (`keys`), by which
//! first run knows whose key was pasted. `at` is the list's provider at an
//! address, by which a preset says whose it is. `app_name.toml`, apart from the
//! list as the script would lose it, is `app_name`'s.

use std::sync::LazyLock;

use cw_platform::http::Url;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// A provider of the list.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct KnownProvider {
    pub name: String,
    /// Address of its API up to the version part, as the form takes it.
    pub base_url: String,
    /// Whether it is a server on the user's own machine.
    pub local: bool,
    /// How its keys begin, where the list says: a key that begins so is taken
    /// for this provider's.
    pub keys: Vec<String>,
    /// Its website's domain, if the list names one.
    #[serde(skip)]
    #[ts(skip)]
    website: Option<String>,
    /// The host of `base_url`.
    #[serde(skip)]
    #[ts(skip)]
    host: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct File {
    provider: Vec<Entry>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Entry {
    name: String,
    base_url: String,
    website: Option<String>,
    keys: Option<Vec<String>>,
}

static LIST: LazyLock<Vec<KnownProvider>> = LazyLock::new(|| {
    let files = [
        include_str!("../providers/own.toml"),
        include_str!("../providers/models.dev.toml"),
    ];
    let mut list: Vec<KnownProvider> = files
        .into_iter()
        .flat_map(|file| {
            // Our own files, built in: every test that asks the list reads them whole.
            let file: File = toml::from_str(file).expect("a list of providers");
            file.provider
        })
        .map(|entry| {
            // Every address in our files parses, as read by every test that asks the list.
            let address = Url::parse(&entry.base_url).expect("a provider's address");
            // An address of `http` or `https` always has a host.
            let host = address.host_str().expect("a provider's host").to_string();
            KnownProvider {
                local: host == "127.0.0.1",
                name: entry.name,
                keys: entry.keys.unwrap_or_default(),
                base_url: entry.base_url,
                website: entry.website,
                host,
            }
        })
        .collect();
    list.sort_by_cached_key(|provider| provider.name.to_lowercase());
    list
});

/// The whole list, in the order of the names.
pub fn all() -> &'static [KnownProvider] {
    &LIST
}

/// The provider of the list whose API is at `base_url`. An address with
/// `localhost` is this machine's by its number, as the list has the servers
/// on it (and as `asListed` of `web/src/models/provider-form.ts` has it).
pub fn at(base_url: &str) -> Option<&'static KnownProvider> {
    const NAMED: &str = "http://localhost";
    const NUMBERED: &str = "http://127.0.0.1";
    let listed = match base_url.split_at_checked(NAMED.len()) {
        Some((start, rest)) if start.eq_ignore_ascii_case(NAMED) => format!("{NUMBERED}{rest}"),
        _ => base_url.to_string(),
    };
    all().iter().find(|provider| provider.base_url == listed)
}

/// Whether `host` is `domain` or a host under it.
fn under(host: &str, domain: &str) -> bool {
    host.strip_suffix(domain)
        .is_some_and(|before| before.is_empty() || before.ends_with('.'))
}

/// The provider of the list whose website `host` is, or is a host of
/// (`platform.openai.com`); else the one whose API is on `host` or under it.
pub(crate) fn of_website(host: &str) -> Option<&'static KnownProvider> {
    let named = |provider: &&KnownProvider| {
        provider
            .website
            .as_deref()
            .is_some_and(|site| under(host, site))
    };
    all()
        .iter()
        .find(named)
        .or_else(|| all().iter().find(|provider| under(&provider.host, host)))
}

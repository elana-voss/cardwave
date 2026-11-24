//! For the tests only: a test's own server asked in place of a provider's
//! public host, so that no test asks a live provider. `https://host/path` is
//! asked as `<stand-in>/host/path` ([`address`], the form the places' search
//! asks its stand-in in too). [`every_host`] takes every `https` host (the
//! browser tests' server, from `CARDWAVE_PROVIDER_PLACES` in a debug build);
//! [`host`] one host (a server test that has OpenRouter's list answered).
//! [`send`](crate::send) moves each request ([`moved`]) after the provider's
//! headers are set and before it leaves.
//!
//! Traps: the stand-ins are the process's, as `send` knows no app: a test
//! binary names a host once, for all its tests. A release build moves no
//! request, whatever was named, and with none named a request goes where it
//! was made for. The places' search and the web tool ask through their own
//! clients, with their test's stand-in, at the same [`address`].

use std::sync::Mutex;

use cw_core::lock;
use cw_platform::http::{Request, Url};

/// Which hosts go where: `None` every `https` host.
static STAND_INS: Mutex<Vec<(Option<String>, String)>> = Mutex::new(Vec::new());

/// From now on every `https` host is asked at `at`.
pub fn every_host(at: &str) {
    keep(None, at);
}

/// From now on the host `host` (`openrouter.ai`) is asked at `at`.
pub fn host(host: &str, at: &str) {
    keep(Some(host.to_string()), at);
}

fn keep(host: Option<String>, at: &str) {
    let at = at.trim_end_matches('/').to_string();
    let mut stand_ins = lock(&STAND_INS);
    stand_ins.retain(|(kept, _)| *kept != host);
    stand_ins.push((host, at));
}

/// `address` (`https://host/path`, or `http://`) as the stand-in at `at` is asked it.
pub fn address(at: &str, address: &str) -> String {
    let at = at.trim_end_matches('/');
    let unschemed = address.split_once("://").map_or(address, |(_, rest)| rest);
    format!("{at}/{unschemed}")
}

/// `request` sent to the stand-in for its host, where there is one.
pub(crate) fn moved(request: &mut Request) {
    let Some(target) = stand_in_for(request.url()) else {
        return;
    };
    match Url::parse(&target) {
        Ok(moved) => *request.url_mut() = moved,
        // A stand-in that is no address is the test's mistake: its call then goes where it was made for.
        Err(failure) => tracing::warn!("the stand-in's address {target} is none: {failure}"),
    }
}

/// Where `url` is asked instead, where a stand-in takes its host: never in a
/// release build.
fn stand_in_for(url: &Url) -> Option<String> {
    if !cfg!(debug_assertions) {
        return None;
    }
    taken_by(&lock(&STAND_INS), url)
}

/// The address of the stand-in among `stand_ins` that takes `url`'s host, if any.
fn taken_by(stand_ins: &[(Option<String>, String)], url: &Url) -> Option<String> {
    if url.scheme() != "https" {
        return None;
    }
    let host = url.host_str()?;
    let (_, at) = stand_ins
        .iter()
        .find(|(kept, _)| kept.as_deref() == Some(host))
        .or_else(|| stand_ins.iter().find(|(kept, _)| kept.is_none()))?;
    Some(address(at, url.as_str()))
}

#[cfg(test)]
mod tests {
    use super::{address, taken_by};
    use cw_platform::http::Url;

    fn url(text: &str) -> Url {
        Url::parse(text).unwrap()
    }

    #[test]
    fn with_no_stand_in_named_a_request_goes_where_it_was_made_for() {
        assert_eq!(
            taken_by(&[], &url("https://openrouter.ai/api/v1/models")),
            None
        );
    }

    #[test]
    fn a_stand_in_takes_its_own_host_only_and_every_host_takes_the_rest() {
        let one = [(
            Some("openrouter.ai".to_string()),
            "http://127.0.0.1:9".to_string(),
        )];
        let to = |text: &str| taken_by(&one, &url(text));
        assert_eq!(
            to("https://openrouter.ai/api/v1/models?x=1").as_deref(),
            Some("http://127.0.0.1:9/openrouter.ai/api/v1/models?x=1")
        );
        assert_eq!(to("https://api.openai.com/v1/models"), None);
        assert_eq!(to("http://openrouter.ai/api/v1/models"), None);
        let every = [(None, "http://127.0.0.1:8".to_string()), one[0].clone()];
        assert_eq!(
            taken_by(&every, &url("https://api.openai.com/v1")).as_deref(),
            Some("http://127.0.0.1:8/api.openai.com/v1")
        );
    }

    #[test]
    fn an_address_keeps_its_host_path_and_query_under_the_stand_in() {
        assert_eq!(
            address("http://a/", "http://b.org/p?q=1"),
            "http://a/b.org/p?q=1"
        );
    }
}

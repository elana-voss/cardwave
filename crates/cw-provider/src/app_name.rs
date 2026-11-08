//! Cardwave's name on the calls to a provider: the headers `providers/app_name.toml`
//! gives the providers that have a way to be told the calling app (the file's head
//! says what it holds). [`on`], from `crate::send`, is the one place that sets them:
//! `keyed` could not, as it has a request not yet built and no address to read.
//!
//! The provider is told by the address asked: of its parts from the longest
//! down, the first that `list::at` knows, so an address the user typed gets them
//! when it is on the list. An address not on the list gets nothing.
//! Traps: a call sent past `crate::send` goes unnamed (`layers` in `tools/check.sh`
//! refuses one sent where it is made keyed); [`stand_in`] exists for the tests, whose stand-in for a
//! provider has no address of the list.

use std::collections::BTreeMap;
use std::sync::{LazyLock, OnceLock};

use cw_platform::http::header::{HeaderName, HeaderValue};
use cw_platform::http::{Request, Url};
use serde::Deserialize;

use crate::list;

/// The name where a call goes out without a provider's own way: never with a version (the owner).
pub const NAME: &str = "Cardwave";

/// The one format of the file this server reads.
const FORMAT: u32 = 1;

/// What a provider is sent.
type Headers = Vec<(HeaderName, HeaderValue)>;

#[derive(Deserialize)]
struct File {
    format: u32,
    provider: Vec<Entry>,
}

/// A line of the file; `page`, `read` and `note` are for the one who keeps it.
#[derive(Deserialize)]
struct Entry {
    name: String,
    headers: BTreeMap<String, String>,
}

/// The providers of `file` with their headers; why not, where its format is
/// not known, a name is not on the list or is a server on the user's own machine,
/// or a header cannot be sent.
fn read(file: &str) -> Result<Vec<(String, Headers)>, String> {
    let file: File = toml::from_str(file).map_err(|failure| failure.to_string())?;
    if file.format != FORMAT {
        return Err(format!("format {} is not known", file.format));
    }
    file.provider
        .into_iter()
        .map(|entry| {
            let known = list::all().iter().find(|known| known.name == entry.name);
            if !known.is_some_and(|known| !known.local) {
                return Err(format!("{} is not an online provider's name", entry.name));
            }
            let headers = entry.headers.iter().map(|(name, value)| {
                let name = HeaderName::try_from(name).map_err(|failure| failure.to_string())?;
                let value = HeaderValue::try_from(value).map_err(|failure| failure.to_string())?;
                Ok((name, value))
            });
            Ok((entry.name.clone(), headers.collect::<Result<_, String>>()?))
        })
        .collect()
}

static NAMED: LazyLock<Vec<(String, Headers)>> = LazyLock::new(|| {
    // Our own file, built in: a test reads it whole.
    read(include_str!("../providers/app_name.toml")).expect("the providers' app names")
});

/// Which provider a test's stand-in at an address is.
static STAND_IN: OnceLock<(&'static str, String)> = OnceLock::new();

/// Takes `address` for the provider `name`, for this process. For the tests:
/// the server never calls it.
pub fn stand_in(name: &'static str, address: &str) {
    // A second stand-in in one process would be a mistake of its test, which then fails on its headers.
    let _ = STAND_IN.set((name, address.to_string()));
}

/// The name of the provider of the list `url` asks.
fn provider_of(url: &Url) -> Option<&'static str> {
    let mut asked = url.clone();
    asked.set_query(None);
    asked.set_fragment(None);
    let mut address = asked.as_str();
    loop {
        address = address.trim_end_matches('/');
        if let Some((name, _)) = STAND_IN.get().filter(|(_, at)| at == address) {
            return Some(name);
        }
        if let Some(known) = list::at(address) {
            return Some(&known.name);
        }
        address = address.rsplit_once('/')?.0;
    }
}

/// The headers of a call to `url`: its provider's, none where it has none or is not on the list.
pub fn of(url: &Url) -> &'static [(HeaderName, HeaderValue)] {
    provider_of(url)
        .and_then(|name| NAMED.iter().find(|(named, _)| named == name))
        .map_or(&[], |(_, headers)| headers.as_slice())
}

/// `request` with the headers of its address.
pub(crate) fn on(request: &mut Request) {
    for (name, value) in of(request.url()) {
        request.headers_mut().insert(name.clone(), value.clone());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(address: &str) -> Vec<&'static str> {
        let url = Url::parse(address).unwrap();
        of(&url).iter().map(|(name, _)| name.as_str()).collect()
    }

    fn value(address: &str, wanted: &str) -> Option<&'static str> {
        let url = Url::parse(address).unwrap();
        of(&url)
            .iter()
            .find(|(name, _)| name == wanted)
            .map(|(_, value)| value.to_str().unwrap())
    }

    #[test]
    fn the_file_holds_each_provider_at_its_own_address_with_no_version() {
        assert!(!NAMED.is_empty());
        for (name, headers) in NAMED.iter() {
            let known = list::all().iter().find(|known| &known.name == name);
            let address = &known.unwrap().base_url;
            assert_eq!(list::at(address).map(|at| &at.name), Some(name));
            assert_eq!(of(&Url::parse(address).unwrap()).len(), headers.len());
            for (header, value) in headers {
                let value = value.to_str().unwrap();
                assert!(!value.contains(|c: char| c.is_ascii_digit()), "{value}");
                assert_ne!(header, "x-openrouter-app-visibility");
            }
        }
    }

    #[test]
    fn a_file_of_a_name_not_on_the_list_or_of_a_format_not_known_is_refused() {
        let line =
            |name| format!("format = 1\nprovider = [{{ name = \"{name}\", headers = {{}} }}]");
        assert!(read(&line("OpenRouter")).is_ok());
        assert!(read(&line("Nobody at all")).unwrap_err().contains("Nobody"));
        assert!(read(&line("LM Studio")).unwrap_err().contains("LM Studio"));
        let later = line("OpenRouter").replace("format = 1", "format = 2");
        assert!(read(&later).unwrap_err().contains("format 2"));
    }

    #[test]
    fn a_provider_is_told_by_the_address_asked() {
        const TITLE: &str = "x-openrouter-title";
        for address in [
            "https://openrouter.ai/api/v1",
            "https://openrouter.ai/api/v1/",
            "https://OpenRouter.ai/api/v1/chat/completions",
            "https://openrouter.ai/api/v1/models?output_modalities=image",
        ] {
            assert_eq!(value(address, TITLE), Some("Cardwave"), "{address}");
        }
        assert_eq!(
            value("https://api.anthropic.com/v1/models", "user-agent"),
            Some("Cardwave (https://cardwave.cc)")
        );
        for address in [
            "https://api.together.xyz/v1/chat/completions",
            "http://openrouter.ai/api/v1/models",
            "https://openrouter.ai.example.com/api/v1/models",
            "https://openrouter.ai/other/v1/models",
            "https://example.com/v1/models",
            "http://127.0.0.1:1234/v1/models",
            "http://localhost:1234/v1/models",
        ] {
            assert_eq!(names(address), Vec::<&str>::new(), "{address}");
        }
    }
}

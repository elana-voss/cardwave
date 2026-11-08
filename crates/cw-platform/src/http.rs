//! The HTTP client, reqwest, which no other module names (global layer rule;
//! `tools/check.sh` holds it): every client the server asks the network with
//! is made here, by `client` from a `Make`, and the client's types the rest
//! names are this module's; an answer made here, not asked of a server, is
//! built by `ResponseBuilder`.
//!
//! A `Make` says only what differs from the client's defaults: its time
//! limits, its user agent, how it follows redirects, and whether its names are
//! looked up past a check (`Lookup`), which also keeps it from a proxy, as a
//! proxy would look the names up itself. `public` is the one check of what
//! is on the open internet, for a lookup and for an address that is a number.

use std::net::{IpAddr, SocketAddr};
use std::time::Duration;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};
use reqwest::redirect::Policy;

pub use ::http::response::Builder as ResponseBuilder;
pub use reqwest::header;
pub use reqwest::{
    Body, Client, Error, Method, Request, RequestBuilder, Response, Result, StatusCode, Url,
};

/// A failure a client's own check gives, as the client carries it.
pub type Refusal = Box<dyn std::error::Error + Send + Sync>;

/// How a client is made; what is left out is the client's default.
#[derive(Default)]
pub struct Make {
    /// To reach a server.
    pub connect: Option<Duration>,
    /// Between two reads of an answer.
    pub silence: Option<Duration>,
    /// For the whole of a request and its answer.
    pub whole: Option<Duration>,
    pub agent: Option<&'static str>,
    pub redirects: Redirects,
    pub lookup: Option<Lookup>,
}

/// How a client follows redirects.
#[derive(Default)]
pub enum Redirects {
    /// As the client does by default.
    #[default]
    Followed,
    /// Not at all: a redirect is the answer.
    None,
    /// At most `most` in a row, each only to an address `open` lets through;
    /// another is refused by `refused`.
    Checked {
        most: usize,
        open: fn(&Url) -> bool,
        refused: fn() -> Refusal,
    },
}

/// Names are looked up as the system does, and only the addresses `keep`
/// lets through are asked; where none is, `none` is the failure.
#[derive(Clone, Copy)]
pub struct Lookup {
    pub keep: fn(IpAddr) -> bool,
    pub none: fn() -> Refusal,
}

/// Whether `ip` is out on the open internet, the one check of the clients that
/// keep off this computer and the home network (the web tool, the search for a
/// provider's API): not this machine, a private or a link's own network, nor
/// any other range set aside. An IPv4 address written as IPv6 or reached
/// through NAT64 is judged as itself; else IPv6 only from what is given out
/// for the internet at large (2000::/3), less what of it is set aside: for
/// protocols of their own, among them Teredo, which carries an IPv4 address
/// inside (2001::/23), for 6to4, which does too (2002::/16), and for examples
/// (2001:db8::/32, 3fff::/20).
pub fn public(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => {
            let [a, b, c, _] = ip.octets();
            let set_aside = a == 0
                || (a == 100 && (64..128).contains(&b))
                || (a == 192 && b == 0 && c == 0)
                || (a == 198 && (18..20).contains(&b))
                || a >= 240;
            !(set_aside
                || ip.is_loopback()
                || ip.is_private()
                || ip.is_link_local()
                || ip.is_documentation()
                || ip.is_multicast())
        }
        IpAddr::V6(ip) => {
            let parts = ip.segments();
            if let Some(inner) = ip.to_ipv4_mapped() {
                return public(inner.into());
            }
            if parts[..6] == [0x64, 0xff9b, 0, 0, 0, 0] {
                let [.., high, low] = parts;
                let inner = (u32::from(high) << 16) | u32::from(low);
                return public(IpAddr::V4(inner.into()));
            }
            let [first, second, ..] = parts;
            let set_aside = match first {
                0x2001 => second < 0x200 || second == 0xdb8,
                0x2002 => true,
                0x3fff => second < 0x1000,
                _ => false,
            };
            first & 0xe000 == 0x2000 && !set_aside
        }
    }
}

/// A client made as `make` says.
pub fn client(make: Make) -> Result<Client> {
    let mut builder = Client::builder();
    if let Some(connect) = make.connect {
        builder = builder.connect_timeout(connect);
    }
    if let Some(silence) = make.silence {
        builder = builder.read_timeout(silence);
    }
    if let Some(whole) = make.whole {
        builder = builder.timeout(whole);
    }
    if let Some(agent) = make.agent {
        builder = builder.user_agent(agent);
    }
    builder = match make.redirects {
        Redirects::Followed => builder,
        Redirects::None => builder.redirect(Policy::none()),
        Redirects::Checked {
            most,
            open,
            refused,
        } => builder.redirect(Policy::custom(move |attempt| {
            if attempt.previous().len() > most {
                attempt.error("too many redirects")
            } else if !open(attempt.url()) {
                attempt.error(refused())
            } else {
                attempt.follow()
            }
        })),
    };
    if let Some(lookup) = make.lookup {
        builder = builder
            .no_proxy()
            .dns_resolver(std::sync::Arc::new(Checked(lookup)));
    }
    builder.build()
}

/// The addresses `host` leads to that `keep` lets through, as the system
/// looks them up.
pub async fn addresses(host: &str, keep: fn(IpAddr) -> bool) -> std::io::Result<Vec<SocketAddr>> {
    Ok(tokio::net::lookup_host((host, 0))
        .await?
        .filter(|address| keep(address.ip()))
        .collect())
}

/// Looks names up past a `Lookup`.
struct Checked(Lookup);

impl Resolve for Checked {
    fn resolve(&self, name: Name) -> Resolving {
        let Lookup { keep, none } = self.0;
        Box::pin(async move {
            let found = addresses(name.as_str(), keep).await?;
            if found.is_empty() {
                return Err(none());
            }
            Ok(Box::new(found.into_iter()) as Addrs)
        })
    }
}

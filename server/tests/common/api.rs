//! A stand-in for a provider's API, started inside a test: no test asks a
//! provider.
//!
//! `Api` answers whatever it is asked as the test says (`Says`) and notes what
//! it was asked, with what it was sent (`Asked::body`), for
//! `provider_models.rs` and `provider_check.rs`, where a reply is `piece`s of a
//! stream. `Api::start_each` answers each asking as the next of a list says,
//! and every one after the list as its last (`describe.rs`), `Api::start_routed`
//! each by its path (`picks.rs`); `Says::bytes`
//! answers a picture (`images.rs`).

use std::convert::Infallible;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, Method, StatusCode, Uri, header};
use axum::response::IntoResponse;
use futures_util::{StreamExt, stream};
use tokio::net::TcpListener;
use tokio::time::sleep;

pub const JSON: &str = "application/json";

/// How long after the first piece of an answer the second comes: long enough to be read by itself.
const PAUSE: Duration = Duration::from_millis(300);

/// How the stand-in answers.
#[derive(Clone)]
pub struct Says {
    pub status: u16,
    pub kind: &'static str,
    pub body: String,
    /// How long the answer takes to begin.
    pub after: Duration,
    /// What comes a moment after `body`, as a piece of its own.
    pub then: Option<String>,
    /// Whether the answer never ends: after that nothing more comes.
    pub endless: bool,
    /// Where the answer sends on, as a redirect does.
    pub onward: Option<String>,
    /// Bytes sent in `body`'s place, for a picture.
    pub bytes: Option<Vec<u8>>,
}

pub fn says(status: u16, kind: &'static str, body: &str) -> Says {
    Says {
        status,
        kind,
        body: body.to_string(),
        after: Duration::ZERO,
        then: None,
        endless: false,
        onward: None,
        bytes: None,
    }
}

/// What the stand-in was asked.
#[derive(Clone, Debug, PartialEq)]
pub struct Asked {
    pub method: Method,
    pub path: String,
    /// The key that came along, as the header has it.
    pub key: Option<String>,
    /// What the asker says it takes.
    pub accept: Option<String>,
    /// Every header it was sent, its name in small letters.
    pub heard: Vec<(String, String)>,
    /// What it was sent, as text.
    pub body: String,
}

/// A stand-in for a provider's API, started inside the test: it answers
/// whatever it is asked as the test says, and notes what it was asked.
pub struct Api {
    /// Its address up to the version part.
    pub url: String,
    asked: Arc<Mutex<Vec<Asked>>>,
}

impl Api {
    pub async fn start(says: Says) -> Self {
        Self::start_each(vec![says]).await
    }

    /// Answers the first asking as the first of `each` says, the second as the
    /// second, and every one after the last as the last.
    pub async fn start_each(each: Vec<Says>) -> Self {
        Self::serve(move |_, n| each[n.min(each.len() - 1)].clone()).await
    }

    /// Answers an asking whose path ends as one of `routes` does as that one
    /// says, and any other with 404.
    pub async fn start_routed(routes: Vec<(&'static str, Says)>) -> Self {
        Self::serve(move |path, _| {
            let route = routes.iter().find(|(end, _)| path.ends_with(end));
            route.map_or_else(|| says(404, JSON, "{}"), |(_, says)| says.clone())
        })
        .await
    }

    /// Answers the `n`th asking, of the path `path`, as `pick` says.
    async fn serve(pick: impl Fn(&str, usize) -> Says + Clone + Send + Sync + 'static) -> Self {
        let asked = Arc::new(Mutex::new(Vec::new()));
        let log = asked.clone();
        let answer = move |method: Method, uri: Uri, headers: HeaderMap, body: String| {
            let pick = pick.clone();
            async move {
                let said = |name| {
                    let value: Option<&header::HeaderValue> = headers.get(name);
                    value.map(|value| value.to_str().unwrap().to_string())
                };
                let says = {
                    let mut log = log.lock().unwrap();
                    let says = pick(uri.path(), log.len());
                    log.push(Asked {
                        method,
                        path: uri.to_string(),
                        key: said(header::AUTHORIZATION),
                        accept: said(header::ACCEPT),
                        heard: headers
                            .iter()
                            .map(|(name, value)| {
                                (name.to_string(), value.to_str().unwrap().to_string())
                            })
                            .collect(),
                        body,
                    });
                    says
                };
                sleep(says.after).await;
                let first = says.bytes.unwrap_or_else(|| says.body.into_bytes());
                let body = stream::once(async move { Ok::<_, Infallible>(first) });
                let body = body.chain(stream::iter(says.then).then(|rest| async {
                    sleep(PAUSE).await;
                    Ok(rest.into_bytes())
                }));
                let body = match says.endless {
                    true => Body::from_stream(body.chain(stream::pending())),
                    false => Body::from_stream(body),
                };
                let mut head = HeaderMap::new();
                head.insert(header::CONTENT_TYPE, says.kind.parse().unwrap());
                if let Some(onward) = says.onward {
                    head.insert(header::LOCATION, onward.parse().unwrap());
                }
                (StatusCode::from_u16(says.status).unwrap(), head, body).into_response()
            }
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let app = Router::new().fallback(answer);
        tokio::spawn(async { axum::serve(listener, app).await.unwrap() });
        Self { url, asked }
    }

    pub fn asked(&self) -> Vec<Asked> {
        self.asked.lock().unwrap().clone()
    }

    /// The key the last asking came with.
    pub fn last_key(&self) -> Option<String> {
        self.asked()
            .last()
            .expect("the API was not asked")
            .key
            .clone()
    }
}

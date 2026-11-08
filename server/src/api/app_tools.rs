//! Cardwave's own tools asked of the API in-process (`api::Api`, built once):
//! the routes that are tools (`tool_routes`, from build.rs's `route_tools`),
//! and a call as the reply's or MCP's caller (`call`, by `request`, which MCP's
//! own tools use too); its answer is cut at `TEXT_LIMIT` characters.

use std::sync::{Arc, OnceLock};

use axum::body::Body;
use axum::extract::Request;
use axum::http::{Method, header};
use cw_coding::tools::app::{self, AskApp, Route};
use cw_coding::tools::web::{TEXT_LIMIT, cut};
use serde_json::Value;
use tower::ServiceExt;

use super::{Api, Caller};

/// The most bytes of an answer that are read.
const READ: usize = 64 << 20;

/// Every route that is a tool.
pub fn tool_routes() -> &'static [Route] {
    static ALL: OnceLock<Vec<Route>> = OnceLock::new();
    ALL.get_or_init(super::route_tools)
}

/// What asks `api` for a tool as `caller`.
pub(crate) fn ask_app(api: Api, caller: Caller) -> AskApp {
    Arc::new(move |route, arguments| {
        let (api, caller) = (api.clone(), caller.clone());
        Box::pin(async move { call(&api, &caller, route, &arguments).await })
    })
}

/// Asks `api` what `route` asks with `arguments`, as `caller`: its answer, or
/// what it said went wrong.
pub(crate) async fn call(
    api: &Api,
    caller: &Caller,
    route: &Route,
    arguments: &Value,
) -> Result<String, String> {
    let (method, uri, body) = app::request_of(route, arguments)?;
    let method = Method::from_bytes(method.as_bytes()).map_err(|e| e.to_string())?;
    let answer = request(api, caller, method, &uri, body).await?;
    Ok(cut(&answer, TEXT_LIMIT))
}

/// Asks `api`, the API without its sign-in, with `method` at `uri` and the
/// JSON `body`, as `caller`: the answer as text (a file says its size), or its
/// status and what it said went wrong. The request carries `api`, for a reply
/// it starts.
pub(crate) async fn request(
    api: &Api,
    caller: &Caller,
    method: Method,
    uri: &str,
    body: Option<String>,
) -> Result<String, String> {
    let body = body.map_or_else(Body::empty, Body::from);
    let mut request = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json")
        .body(body)
        .map_err(|e| e.to_string())?;
    request.extensions_mut().insert(caller.clone());
    request.extensions_mut().insert(api.clone());
    // Another device's, as the routes that read it from the request see it too.
    if caller.remote {
        request.extensions_mut().insert(crate::Remote);
    }
    let Ok(response) = api.0.clone().oneshot(request).await;
    let status = response.status();
    let kind = response
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|kind| kind.to_str().ok())
        .unwrap_or_default()
        .to_string();
    let body = axum::body::to_bytes(response.into_body(), READ)
        .await
        .map_err(|e| e.to_string())?;
    if !status.is_success() {
        let said = serde_json::from_slice::<cw_core::ErrorBody>(&body)
            .map(|said| said.error)
            .unwrap_or_else(|_| String::from_utf8_lossy(&body).into_owned());
        return Err(format!("{status}: {said}"));
    }
    let text = match kind.starts_with("application/json") || kind.starts_with("text/") {
        true => String::from_utf8_lossy(&body).into_owned(),
        false if body.is_empty() => "Done.".to_string(),
        false => format!("The answer is a file of {} bytes ({kind}).", body.len()),
    };
    Ok(text)
}

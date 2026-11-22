//! The pages' Content-Security-Policy: [`PAGE_POLICY`] on every answer that sets none (`outer` in lib.rs),
//! [`WEB_PAGE_POLICY`] for a page whose user shows pictures from the web (`api::page_policy`), and
//! [`WORKER_POLICY`], the only one allowing eval, on the KTX2 transcoder's worker file alone (`worker_policy`).
//! Trap: an address of the worker's form that is no file is answered with index.html, which must keep the page's.

use axum::extract::Request;
use axum::http::{HeaderValue, header};
use axum::middleware::Next;
use axum::response::Response;

/// The pages' Content-Security-Policy with the pictures it allows (`img-src`).
macro_rules! page_policy {
    ($pictures:literal) => {
        concat!(
            "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src ",
            $pictures,
            "; media-src 'self' data: blob:; font-src 'self' data:; ",
            "connect-src 'self' data: blob: ipc: http://ipc.localhost; frame-src 'self'; object-src 'none'; ",
            "base-uri 'none'; form-action 'self'; frame-ancestors 'self'"
        )
    };
}

/// The pages' Content-Security-Policy, the second guard should a stranger's text ever reach the page as HTML:
/// scripts only the app's own files, no inline script or eval; WebAssembly compiled by them ('wasm-unsafe-eval'), the
/// decoders of a compressed figure (web/src/figures/decoders.ts). Styles allow inline for the user's own CSS
/// (a `<style>`); pictures only the app's own; `ipc:` is the desktop window's way to its shell, `blob:`/`data:`
/// the figures' files read in the page. A stored file's answer keeps its own, stricter policy (api.rs).
pub(crate) const PAGE_POLICY: &str = page_policy!("'self' data: blob:");
/// [`PAGE_POLICY`] with pictures from the web, for a page whose user's Settings show them ([`crate::api::page_policy`]).
pub(crate) const WEB_PAGE_POLICY: &str = page_policy!("'self' data: blob: http: https:");

/// The policy of the KTX2 transcoder's worker (web/src/figures/ktx2-worker.ts), whose WebAssembly binding makes its
/// functions by eval: allowed there alone, a worker with no page, which loads nothing (`worker_policy`).
pub(crate) const WORKER_POLICY: &str =
    "default-src 'none'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'; base-uri 'none'";

/// The KTX2 transcoder's worker, the build's `assets/ktx2-worker-<hash>.js` (the file, a script), is answered with [`WORKER_POLICY`];
/// every other answer keeps its own.
pub(crate) async fn worker_policy(request: Request, next: Next) -> Response {
    let worker = request
        .uri()
        .path()
        .strip_prefix("/assets/ktx2-worker-")
        .is_some_and(|rest| rest.ends_with(".js") && !rest.contains('/'));
    let mut response = next.run(request).await;
    // An address of its form that is no file is answered with index.html, which keeps the page's policy.
    let script = response
        .headers()
        .get(header::CONTENT_TYPE)
        .is_some_and(|kind| kind.as_bytes().ends_with(b"javascript"))
        // A revalidation's answer, whose headers replace the kept file's.
        || response.status() == axum::http::StatusCode::NOT_MODIFIED;
    if worker && script {
        response.headers_mut().insert(
            header::CONTENT_SECURITY_POLICY,
            HeaderValue::from_static(WORKER_POLICY),
        );
    }
    response
}

#[cfg(test)]
mod tests {
    /// Only the transcoder's worker itself is answered with the policy allowing eval; the page given for an
    /// address of its form that is no file keeps the page's.
    #[tokio::test]
    async fn the_worker_policy_is_the_worker_files_alone() {
        use axum::{Router, body::Body, http::Request, middleware, routing::get};
        use tower::ServiceExt;
        let app = Router::new()
            .route(
                "/assets/ktx2-worker-a1.js",
                get(|| async { ([(axum::http::header::CONTENT_TYPE, "text/javascript")], "") }),
            )
            .fallback(|| async { axum::response::Html("<html></html>") })
            .layer(middleware::from_fn(super::worker_policy));
        let policy = |path: &'static str| {
            let app = app.clone();
            async move {
                let request = Request::get(path).body(Body::empty()).unwrap();
                let response = app.oneshot(request).await.unwrap();
                response.headers().get("content-security-policy").cloned()
            }
        };
        assert_eq!(
            policy("/assets/ktx2-worker-a1.js").await.unwrap(),
            super::WORKER_POLICY
        );
        assert_eq!(policy("/assets/ktx2-worker-gone.js").await, None);
    }
}

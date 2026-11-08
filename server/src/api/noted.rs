//! The request logging: each request noted in the debug log (`logs`), with
//! its method, path, answer and time; its query is left out, as it may hold
//! what was written in the app.

use std::time::Instant;

use axum::extract::Request;
use axum::middleware::Next;
use axum::response::Response;

/// Notes each request in the debug log: its method, path, answer and time.
pub async fn noted(request: Request, next: Next) -> Response {
    let (method, path) = (request.method().clone(), request.uri().path().to_owned());
    let began = Instant::now();
    let answer = next.run(request).await;
    tracing::debug!(
        "{method} {path} {} in {} ms",
        answer.status().as_u16(),
        began.elapsed().as_millis()
    );
    answer
}

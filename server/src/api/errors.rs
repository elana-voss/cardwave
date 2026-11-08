//! The API's error answers: a failure (`crate::fail`, its head) answered with
//! its code's HTTP status ([`http_status`]) and its [`ErrorBody`]. A handler fails
//! with a [`Fail`], a `NotFound` (404) or any other error, which is
//! `request_failed` (400), its `error` what it says; the database or a task
//! failing is marked `internal` (500) by [`ApiError`] and the server's `work`,
//! and tells nothing more. One made outside a handler is coded by its status
//! (`error_body`), `error` what axum said.

use std::collections::BTreeMap;

use axum::Json;
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use cw_core::{Code, ErrorBody, Fail, told};

/// The HTTP status a failure of `code` answers with: 400 where not listed.
pub(crate) fn http_status(code: Code) -> StatusCode {
    match code {
        Code::Internal => StatusCode::INTERNAL_SERVER_ERROR,
        Code::Forbidden | Code::OwnerOnly => StatusCode::FORBIDDEN,
        Code::NoSuchPath | Code::NotFound => StatusCode::NOT_FOUND,
        Code::MethodNotAllowed => StatusCode::METHOD_NOT_ALLOWED,
        Code::TooLarge => StatusCode::PAYLOAD_TOO_LARGE,
        Code::UnsupportedType => StatusCode::UNSUPPORTED_MEDIA_TYPE,
        Code::Locked => StatusCode::LOCKED,
        Code::SignIn
        | Code::PasswordWrong
        | Code::PasswordNeeded
        | Code::CurrentPasswordNeeded
        | Code::BackupPasswordNeeded => StatusCode::UNAUTHORIZED,
        Code::TooManyTries => StatusCode::TOO_MANY_REQUESTS,
        Code::ChatBusy => StatusCode::CONFLICT,
        Code::NoProvider => StatusCode::FAILED_DEPENDENCY,
        // A request that could not be done: every other code, the areas' own among them.
        _ => StatusCode::BAD_REQUEST,
    }
}

/// What only this computer's account may do, asked by another: its action,
/// such as "use its files". The API answers 403.
pub(crate) fn owner_only(action: &'static str) -> Fail {
    Fail::new(Code::OwnerOnly).with("action", action)
}

/// A failed request, answered with its code (see the head).
pub struct ApiError(anyhow::Error);

pub type ApiResult<T> = Result<T, ApiError>;

impl<E: Into<anyhow::Error>> From<E> for ApiError {
    fn from(error: E) -> Self {
        Self(internal(error.into()))
    }
}

/// `error` marked as the server's own failure (`Code::Internal`) where the
/// database or a task failed in it, which [`told`] knows by that code alone.
pub(crate) fn internal(error: anyhow::Error) -> anyhow::Error {
    match failed_here(&error) {
        true => cw_core::as_internal(error),
        false => error,
    }
}

/// Whether the database or a task failed in `error`: the server's fault,
/// never the request's.
pub(crate) fn failed_here(error: &anyhow::Error) -> bool {
    cw_store::is_storage_error(error) || error.chain().any(|e| e.is::<tokio::task::JoinError>())
}

/// [`told`] for a failure the server tells outside a request's answer (a
/// folder's file, a download, a kept description failure): a database or task
/// failure in it is the server's own, as [`internal`] marks it.
pub(crate) fn body_of(error: &anyhow::Error, fallback: Code) -> ErrorBody {
    match failed_here(error) {
        true => {
            tracing::error!("failed: {error:#}");
            Fail::new(Code::Internal).into()
        }
        false => told(error, fallback),
    }
}

impl ApiError {
    /// The body the failure is told with: one of the server's own is
    /// `internal`, logged, and tells nothing more.
    pub fn body(&self) -> ErrorBody {
        told(&self.0, Code::RequestFailed)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let body = self.body();
        (http_status(body.code), Json(body)).into_response()
    }
}

/// Gives every error answer an [`ErrorBody`]: also those made outside the
/// handlers, such as a request body of the wrong shape or an unknown path,
/// coded by their status.
pub(crate) async fn error_body(response: Response) -> Response {
    let status = response.status();
    let is_json = response
        .headers()
        .get(header::CONTENT_TYPE)
        .is_some_and(|kind| kind == "application/json");
    if !(status.is_client_error() || status.is_server_error()) || is_json {
        return response;
    }
    let text = match axum::body::to_bytes(response.into_body(), 4096).await {
        Ok(text) if !text.is_empty() => String::from_utf8_lossy(&text).into_owned(),
        _ => status.canonical_reason().unwrap_or("error").to_string(),
    };
    let code = match status {
        StatusCode::FORBIDDEN => Code::Forbidden,
        StatusCode::NOT_FOUND => Code::NoSuchPath,
        StatusCode::METHOD_NOT_ALLOWED => Code::MethodNotAllowed,
        StatusCode::PAYLOAD_TOO_LARGE => Code::TooLarge,
        StatusCode::UNSUPPORTED_MEDIA_TYPE => Code::UnsupportedType,
        status if status.is_server_error() => Code::Internal,
        _ => Code::BadRequest,
    };
    let body = ErrorBody {
        code,
        error: text,
        details: BTreeMap::new(),
    };
    (status, Json(body)).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The store's own failure: opening a database in a folder that is not there.
    fn store_failure() -> anyhow::Error {
        let path = std::env::temp_dir().join("cardwave-no-such-folder-96h/cardwave.db");
        let key = cw_key::DbKey::generate().unwrap();
        cw_store::Db::open(&path, &key).err().unwrap()
    }

    #[test]
    fn the_database_failing_is_told_as_internal_without_its_words() {
        use anyhow::Context;
        let failed = Err::<(), _>(store_failure())
            .context(Fail::new(Code::NotFound).with("what", "card"))
            .unwrap_err();
        let body = ApiError::from(failed).body();
        assert_eq!(
            (body.code, body.error.as_str()),
            (Code::Internal, "the server failed to handle the request")
        );
    }

    /// Told outside a request (a folder's file, a kept description failure),
    /// the database failing is the server's own all the same.
    #[test]
    fn the_database_failing_outside_a_request_is_told_as_internal() {
        let body = body_of(&store_failure(), Code::FileNotImported);
        assert_eq!(
            (body.code, body.error.as_str()),
            (Code::Internal, "the server failed to handle the request")
        );
    }
}

//! Search Cardwave over HTTP (`find`): `GET /api/find?q=…` answers what the words find, at once;
//! with `&meaning=true` also what the search model finds by meaning, where it can answer now (else the words
//! alone). `read_after` has the search model read what a change of a lorebook, a persona or a memory wrote.

use axum::extract::{Query, Request, State};
use axum::http::Method;
use axum::middleware::Next;
use axum::response::Response;
use axum::routing::get;
use axum::{Json, Router};
use cw_find::reader;
use cw_find::{self as find, Hit};
use serde::Deserialize;
use ts_rs::TS;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/find", get(search))
}

/// What Search Cardwave is asked: `?q=sea+witch&meaning=true`.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub(crate) struct FindQuery {
    pub q: Option<String>,
    /// Also by meaning, where the search model can answer.
    pub meaning: Option<bool>,
}

async fn search(
    State(state): State<AppState>,
    User(user): User,
    Query(query): Query<FindQuery>,
) -> ApiResult<Json<Vec<Hit>>> {
    let q = query.q.unwrap_or_default();
    if !query.meaning.unwrap_or(false) {
        return state
            .run(move |db| find::by_words(db, user, &q))
            .await
            .map(Json);
    }
    reader::read_cards(&state);
    let near = reader::near(&state, user, &q).await;
    state
        .run(move |db| find::by_meaning(db, user, &q, near.as_deref().map(Vec::as_slice)))
        .await
        .map(Json)
}

/// The paths whose changes write what Search Cardwave keeps of lorebooks, personas and memories.
const WRITING: [&str; 4] = [
    "/api/lorebooks",
    "/api/personas",
    "/api/memories",
    "/api/cards/",
];

/// After a change that went through on one of the `WRITING` paths, the search model reads what is new.
pub(crate) async fn read_after(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Response {
    let writing = request.method() != Method::GET
        && WRITING
            .iter()
            .any(|path| request.uri().path().starts_with(path));
    let response = next.run(request).await;
    if writing && response.status().is_success() {
        reader::read_cards(&state);
        crate::faces::look(&state);
    }
    response
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/find.rs"));

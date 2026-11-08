//! Cards described over HTTP, and the worker that describes them.
//!
//! `GET /api/describe` is how far the describing of the user's cards has come;
//! `POST /api/describe` ("Describe cards") queues every card not yet described
//! and answers the same, or 424 while the user has no provider, `DELETE` stops it (`describe::stop`); `GET /api/needs` is
//! what the view "By need" shows over its cards; `/api/describe/again` is "Describe all
//! again" (`again::start`, `again::stop`, how far: `again::progress`), which the same worker takes after
//! what is queued, each ending as `descriptions` too. An import
//! queues the card it made where the settings say so (`imported`).
//!
//! `start` has the worker take the user's queued cards one after the other, in
//! a task of its own, unless one already does (`AppState::describing`): `run`
//! asks for the next card and gives up its place in the same hold of that set,
//! so a card queued meanwhile is either found or starts a worker anew. Each
//! card is asked of the provider for the work (`provider::for_work`); where
//! there is none, what waits fails. However else `run` ends, a panic too, its
//! `Place` gives the place up. Every card's end is pushed to the user's pages
//! as `descriptions` with the card, a queue as `descriptions` without.
//!
//! The same worker asks a card's needs (`needs`), after what waits to be
//! described: queued with its description, a card made by the interview alone
//! (`made`), and at a start what was described before the list (`queue_lacking`).

use std::future::Future;

use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use cw_core::{Events, PageEvent};
use cw_find::place::Place;
use cw_library::again::{self, DescribingAgain};
use cw_library::cards;
use cw_library::describe::{self, Describing};
use cw_library::needs::{self, NeedsOverview};
use cw_library::posters;
use cw_library::settings;
use cw_provider::{self as provider, NOT_SET_UP, Provider};
use cw_store::Db;

use super::{ApiResult, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/describe",
            get(show).post(describe_all).delete(stop_all),
        )
        .route("/api/needs", get(needs_overview))
        .route(
            "/api/describe/again",
            get(again_progress).post(describe_again).delete(stop_again),
        )
}

async fn show(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Describing>> {
    state
        .run(move |db| describe::progress(db, user))
        .await
        .map(Json)
}

/// The needs any of the user's cards has, in the list's order and words, and how many cards are read, which
/// the Characters page's view "By need" shows.
async fn needs_overview(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<NeedsOverview>> {
    state
        .run(move |db| needs::overview(db, user))
        .await
        .map(Json)
}

/// How far describing the characters again has come, and how many it describes.
async fn again_progress(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<DescribingAgain>> {
    state
        .run(move |db| again::progress(db, user))
        .await
        .map(Json)
}

/// Describes every character not in the Trash again, whose old result stands until the new has come.
async fn describe_again(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<DescribingAgain>> {
    state
        .run(move |db| {
            provider::for_work(db, user)?.ok_or(NOT_SET_UP)?;
            again::start(db, user)
        })
        .await?;
    started(&state, user);
    again_progress(State(state), User(user)).await
}

/// Stops describing the characters again, after the one in hand; what else is queued goes on.
async fn stop_again(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<DescribingAgain>> {
    state.run(move |db| again::stop(db, user)).await?;
    state.push(user, &PageEvent::Descriptions { card_id: None });
    again_progress(State(state), User(user)).await
}

/// Stops describing the cards that wait; the card in hand finishes.
async fn stop_all(State(state): State<AppState>, User(user): User) -> ApiResult<Json<Describing>> {
    // Held through the stop, as the worker holds it while it takes its next card, so neither misses the other.
    let held = state.clone();
    state
        .run(move |db| {
            let describing = held.describing();
            describe::stop(db, user, describing.get(&user).copied().flatten())
        })
        .await?;
    state.push(user, &PageEvent::Descriptions { card_id: None });
    show(State(state), User(user)).await
}

/// Queues every card of the user that is not described yet, and starts the worker.
async fn describe_all(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<Describing>> {
    let queued = state
        .run(move |db| {
            provider::for_work(db, user)?.ok_or(NOT_SET_UP)?;
            describe::queue(db, user, None)
        })
        .await?;
    if queued > 0 {
        state.push(user, &PageEvent::Descriptions { card_id: None });
        start(&state, user);
    }
    state
        .run(move |db| describe::progress(db, user))
        .await
        .map(Json)
}

/// Queues the card just imported, where the user's settings have each card
/// imported described and there is a model to ask. The import stands
/// whatever comes of this.
pub(super) async fn imported(state: &AppState, user: i64, card_id: i64) {
    let queued = state
        .work(move |db| queue_imported(db, user, card_id))
        .await;
    match queued {
        Ok(true) => started(state, user),
        Ok(false) => {}
        Err(failure) => tracing::warn!("card {card_id} is not queued to be described: {failure:#}"),
    }
}

/// Queues the card just imported, where the user's settings have each card imported described and there is
/// a model to ask: whether it was.
pub(super) fn queue_imported(db: &cw_store::Db, user: i64, card_id: i64) -> anyhow::Result<bool> {
    let wanted =
        settings::get(db, user)?.describe_imported && provider::for_work(db, user)?.is_some();
    Ok(wanted && describe::queue(db, user, Some(card_id))? > 0)
}

/// Queues the needs of a card the interview made, whatever the settings say of describing. The card stands
/// whatever comes of this.
pub(super) async fn made(state: &AppState, user: i64, card_id: i64) {
    let queued = state
        .work(move |db| {
            Ok(provider::for_work(db, user)?.is_some()
                && needs::queue(db, user, Some(card_id))? > 0)
        })
        .await;
    match queued {
        Ok(true) => started(state, user),
        Ok(false) => {}
        Err(failure) => tracing::warn!("card {card_id}'s needs are not queued: {failure:#}"),
    }
}

/// At a start: queues the needs of the described cards that have none asked, for each user with a model to
/// ask, and starts the worker.
pub(crate) async fn queue_lacking(state: AppState) {
    let queued = state
        .work(|db| {
            let mut users = Vec::new();
            for user in needs::users_lacking(db)? {
                if provider::for_work(db, user)?.is_some() && needs::queue_lacking(db, user)? > 0 {
                    users.push(user);
                }
            }
            Ok(users)
        })
        .await;
    match queued {
        Ok(users) => users.into_iter().for_each(|user| started(&state, user)),
        Err(failure) => {
            tracing::warn!("the needs of cards described earlier are not queued: {failure:#}")
        }
    }
}

/// Tells the user's pages that cards were queued, and has the worker describe them.
pub(super) fn started(state: &AppState, user: i64) {
    state.push(user, &PageEvent::Descriptions { card_id: None });
    start(state, user);
}

/// Has the worker describe the user's queued cards, unless it does already.
fn start(state: &AppState, user: i64) {
    // A worker running keeps the card it has in hand, which "Stop" spares.
    match state.describing().entry(user) {
        std::collections::hash_map::Entry::Occupied(_) => return,
        std::collections::hash_map::Entry::Vacant(place) => place.insert(None),
    };
    let held = state.clone();
    let place = Place::new(move || {
        held.describing().remove(&user);
    });
    tokio::spawn(run(state.clone(), user, place));
}

/// What the worker does next of a card; `again` for "Describe all again", whose result keeps the old on failure.
#[derive(Clone, Copy)]
enum Job {
    Describe { again: bool },
    Needs { again: bool },
}

/// The next card, with its version and what it waits for: the needs of a character being described again, so its
/// two calls stay together; then what is queued, a description first; then the next to describe again.
fn next_job(db: &cw_store::Db, user: i64) -> anyhow::Result<Option<(Job, i64, i64)>> {
    let of = |job: Job, (card_id, version_id): (i64, i64)| (job, card_id, version_id);
    if let Some(next) = again::needs_in_hand(db, user)? {
        return Ok(Some(of(Job::Needs { again: true }, next)));
    }
    if let Some(next) = describe::next(db, user)? {
        return Ok(Some(of(Job::Describe { again: false }, next)));
    }
    if let Some(next) = needs::next(db, user)? {
        return Ok(Some(of(Job::Needs { again: false }, next)));
    }
    Ok(again::next(db, user)?.map(|next| of(Job::Describe { again: true }, next)))
}

/// One card's job: its question, unless what it needs failed, and what came of it kept.
async fn ask_and_keep<O: Send + 'static, F: Future<Output = anyhow::Result<O>>>(
    state: &AppState,
    asked: anyhow::Result<(Provider, String)>,
    ask: impl FnOnce(Provider, String) -> F,
    keep: impl FnOnce(&Db, anyhow::Result<O>) -> anyhow::Result<()> + Send + 'static,
) -> anyhow::Result<()> {
    let outcome = match asked {
        Ok((provider, card)) => ask(provider, card).await,
        Err(failure) => Err(failure),
    };
    state.work(move |db| keep(db, outcome)).await
}

async fn run(state: AppState, user: i64, place: Place) {
    loop {
        let taken = state.clone();
        let next = state
            .work(move |db| {
                let mut describing = taken.describing();
                let next = next_job(db, user);
                match &next {
                    Ok(Some((_, card_id, _))) => describing.insert(user, Some(*card_id)),
                    _ => describing.remove(&user),
                };
                Ok(next)
            })
            .await;
        let (job, card_id, version_id) = match next {
            Ok(Ok(Some(next))) => next,
            Ok(given_up) => {
                place.release();
                if let Err(failure) = given_up {
                    tracing::error!("the cards to describe cannot be read: {failure:#}");
                }
                return;
            }
            Err(failure) => {
                tracing::error!("the worker describing the cards broke off: {failure:#}");
                return;
            }
        };
        let asked = state
            .work(move |db| {
                let provider = provider::for_work(db, user)?;
                let card = describe::card_text(&cards::document_of(db, version_id)?)?;
                Ok((provider, card))
            })
            .await;
        let asked = match asked {
            Ok((Some(provider), card)) => Ok((provider, card)),
            Ok((None, _)) => {
                let failed = state
                    .work(move |db| {
                        let reason = describe::kept_failure(db, &NOT_SET_UP.into());
                        describe::fail_waiting(db, user, &reason)
                    })
                    .await;
                if let Err(failure) = failed {
                    tracing::warn!("the cards waiting to be described stay waiting: {failure:#}");
                }
                Err(NOT_SET_UP.into())
            }
            Err(failure) => Err(failure),
        };
        let http = &state.http;
        let kept = match job {
            Job::Describe { again } => {
                let ask = |provider: Provider, card: String| async move {
                    describe::ask(http, &provider, &card).await
                };
                let keep = move |db: &Db, outcome| {
                    if again {
                        again::keep_description(db, card_id, version_id, outcome)?;
                    } else {
                        describe::keep(db, card_id, version_id, outcome)?;
                    }
                    // Before the pages hear of it, so their next fetch has the poster.
                    posters::give_all(db)
                };
                ask_and_keep(&state, asked, ask, keep).await
            }
            Job::Needs { again } => {
                let ask = |provider: Provider, card: String| async move {
                    needs::ask(http, &provider, &card).await
                };
                let keep = move |db: &Db, outcome| {
                    if again {
                        again::keep_needs(db, card_id, version_id, outcome)
                    } else {
                        needs::keep(db, card_id, version_id, outcome)
                    }
                };
                ask_and_keep(&state, asked, ask, keep).await
            }
        };
        if let Err(failure) = kept {
            tracing::error!("card {card_id}'s description cannot be kept: {failure:#}");
        }
        state.push(
            user,
            &PageEvent::Descriptions {
                card_id: Some(card_id),
            },
        );
    }
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/describe.rs"));

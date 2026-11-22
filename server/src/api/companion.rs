//! The companion over HTTP (`companion`): `POST /api/companion/plan` asks
//! what the companion's figure does now, after a reply in its chat of the chat
//! model that wrote it, after the hand handled it or now and then left alone of
//! the worker model (both in review, the owner, 2026-10-28), told what
//! Cardwave's window shows, what the character remembers and what it answered
//! last that the window does (`Seen::answered`: by the order asked, not while
//! the hand holds the figure); no
//! steps without a companion or for another card's chat.
//! Which card is the companion is a setting (`settings::Companion`). A touch
//! (`Occasion::Touched`) is answered by the chat model; the window asks one at
//! a time. What the steps of an answer or an act say is given to the figure as
//! its character's and kept as said once the window says its bubble shows it
//! (`Seen::bubbled`, in memory only, for a while), told to the animator and
//! the character's chat model (`Live::bubble_note`, `api::generate`).
//!
//! And the companion as one interface (`cw_chat::companion::live`), each
//! route also a tool of other programs: `GET /api/companion/state` what it
//! knows, `POST /api/companion/act` what it does, which the companion window
//! is told (`CompanionEvent`) and answers by saying it began it. The window
//! says what its figure does (`PUT /api/companion/live`), Cardwave's window
//! which screen it shows (`PUT /api/companion/app`); both are kept here
//! (`Live`), in memory only, with the persona the animator was told last.
//! Traps: those two read their body by hand, which makes them no tools
//! (build.rs), as another program is not to say them.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post, put};
use axum::{Json, Router};
use cw_chat::companion::{
    self, AppScreen, Bubbles, CompanionAct, CompanionFigure, CompanionMoves, CompanionPlan,
    CompanionState, Move, Occasion, Persona,
};
use cw_core::{Code, Fail};
use cw_library::settings;
use cw_provider as provider;
use serde::de::DeserializeOwned;
use std::time::Instant;
use tokio::sync::Notify;

use super::events::CompanionEvent;
use super::{ApiResult, User};
use crate::AppState;

/// How long after the window last said what its figure does it counts as shown.
const SHOWN_FOR: Duration = Duration::from_secs(15);
/// How long an act waits for the window to begin it.
const ACT_WAIT: Duration = Duration::from_secs(3);
/// The newest messages of the companion's chat its state holds.
const SHOWN_MESSAGES: usize = 6;

/// What the companion windows and Cardwave's windows said last, by user.
#[derive(Default)]
pub(crate) struct Live {
    seen: Mutex<HashMap<i64, Seen>>,
    /// Woken each time a window says what its figure does.
    told: Notify,
}

#[derive(Default)]
struct Seen {
    figure: Option<(Instant, CompanionFigure)>,
    app: Option<AppScreen>,
    /// The steps the animator answered last that the window does, by
    /// `Seen::answered`.
    planned: Vec<Move>,
    /// How many questions of the animator were asked, and which of them was
    /// answered last as the window takes it.
    asked: u32,
    answered: u32,
    /// The persona the animator was told last, read again only from a newer card version.
    persona: Option<Persona>,
    /// The last act's number.
    acts: u32,
    /// What the figure said in its bubble lately, as which card.
    bubbled: Bubbles,
}

impl Seen {
    /// A question of the animator asked now, by its number.
    fn ask(&mut self) -> u32 {
        self.asked += 1;
        self.asked
    }

    /// The answer `steps` to the question `ask` kept as what the figure does
    /// as the window does it (`Answers`, react.ts, and `steerer`, main.ts): an
    /// answer come after that of a later question is dropped, one come while
    /// the hand holds the figure is not done.
    /// The question `ask` answered with no steps without asking the animator
    /// (no companion, another card's chat): the window takes that answer too,
    /// which drops older ones, and goes on with what it did.
    fn unasked(&mut self, ask: u32) {
        self.answered = self.answered.max(ask);
    }

    fn answered(&mut self, ask: u32, steps: Vec<Move>) {
        if ask < self.answered {
            return;
        }
        self.answered = ask;
        let held = self
            .figure
            .as_ref()
            .is_some_and(|(_, figure)| matches!(figure.state.as_str(), "dragged" | "shaken"));
        if !held {
            self.planned = steps;
        }
    }
}

impl Live {
    fn with<T>(&self, user: i64, read: impl FnOnce(&mut Seen) -> T) -> T {
        let mut seen = self
            .seen
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        read(seen.entry(user).or_default())
    }

    /// The figure as the window said it last, and whether that is recent.
    fn figure(&self, user: i64) -> (bool, Option<CompanionFigure>) {
        self.with(user, |seen| match &seen.figure {
            Some((at, figure)) => (at.elapsed() < SHOWN_FOR, Some(figure.clone())),
            None => (false, None),
        })
    }

    /// What the character of the card `card_id` (none: no card) is told of
    /// what its figure said in its bubble lately, after a chat's log.
    pub(crate) fn bubble_note(&self, user: i64, card_id: Option<i64>) -> Option<String> {
        let card_id = card_id?;
        let now = Instant::now();
        self.with(user, |seen| {
            companion::bubble_note(&companion::lately(seen.bubbled.lines(), card_id, now))
        })
    }

    /// Whether the window has begun the act `act` within `ACT_WAIT`.
    async fn begun(&self, user: i64, act: u32) -> bool {
        let until = tokio::time::Instant::now() + ACT_WAIT;
        loop {
            let told = self.told.notified();
            tokio::pin!(told);
            told.as_mut().enable();
            let (_, figure) = self.figure(user);
            if figure.is_some_and(|figure| figure.acted >= act) {
                return true;
            }
            if tokio::time::timeout_at(until, told).await.is_err() {
                return false;
            }
        }
    }
}

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/companion/plan", post(plan))
        .route("/api/companion/state", get(state_now))
        .route("/api/companion/act", post(act))
        .route("/api/companion/live", put(figure))
        .route("/api/companion/app", put(app))
}

async fn plan(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<CompanionPlan>,
) -> ApiResult<Json<CompanionMoves>> {
    let (ask, app, last, known, bubbled) = state.companion.with(user, |seen| {
        let (app, last) = (seen.app.clone(), seen.planned.clone());
        (
            seen.ask(),
            app,
            last,
            seen.persona.clone(),
            seen.bubbled.lines().to_vec(),
        )
    });
    let asking = state
        .run(move |db| {
            let Some((question, persona)) =
                companion::question(db, user, &asked, app.as_ref(), &last, known, &bubbled)?
            else {
                return Ok(None);
            };
            let provider = match asked.occasion {
                Occasion::Reply | Occasion::Touched => provider::chat_for_work(db, user)?,
                Occasion::Handled | Occasion::Alone => provider::for_work(db, user)?,
            };
            let Some(provider) = provider else {
                return Err(provider::not_set_up(db, user)?.into());
            };
            Ok(Some((question, persona, provider, asked)))
        })
        .await?;
    let Some((question, persona, provider, asked)) = asking else {
        state.companion.with(user, |seen| seen.unasked(ask));
        return Ok(Json(CompanionMoves { steps: Vec::new() }));
    };
    let (card_id, name) = (persona.card_id(), persona.name().to_string());
    state
        .0
        .companion
        .with(user, |seen| seen.persona = Some(persona));
    let steps = companion::plan(&state.http, &provider, question, &asked).await?;
    let planned = steps.clone();
    state.companion.with(user, |seen| {
        let now = Instant::now();
        seen.bubbled.offer(card_id, &name, &planned, now);
        seen.answered(ask, planned);
    });
    Ok(Json(CompanionMoves { steps }))
}

/// What the companion knows now: whether its figure shows on the screen,
/// where it is, what it does and plays, where it looks, what it feels and
/// says, what is left of the steps it was told; what Cardwave's window shows;
/// and the newest messages of the companion's chat.
async fn state_now(
    State(state): State<AppState>,
    User(user): User,
) -> ApiResult<Json<CompanionState>> {
    Ok(Json(known(&state, user).await?))
}

/// Has the companion's figure do `steps`, in this order, in place of what it
/// does: walk along the floor, climb an edge of the screen and let go, play a
/// clip, look at a point, show a feeling, say a message, wait. Answers what it
/// knows once its window has begun them; refused while the figure does not
/// show.
async fn act(
    State(state): State<AppState>,
    User(user): User,
    Json(act): Json<CompanionAct>,
) -> ApiResult<Json<CompanionState>> {
    let live = &state.companion;
    let (shown, figure) = live.figure(user);
    let Some(figure) = figure.filter(|_| shown) else {
        return Err(not_possible("the companion is not showing", "companion_not_shown").into());
    };
    let number = live.with(user, |seen| {
        seen.acts = seen.acts.max(figure.acted) + 1;
        seen.acts
    });
    let steps: Vec<Move> = act
        .steps
        .into_iter()
        .map(|step| companion::held(step, figure.width, figure.height))
        .collect();
    // What the act says is given to the figure as its character's, kept as said once its bubble shows it.
    if steps.iter().any(|step| matches!(step, Move::Say { .. })) {
        let figure_of = state
            .run(move |db| {
                let Some(card_id) = settings::get(db, user)?.companion.card_id else {
                    return Ok(None);
                };
                Ok(companion::figure_name(db, user, card_id)?.map(|name| (card_id, name)))
            })
            .await?;
        if let Some((card_id, name)) = figure_of {
            let now = Instant::now();
            live.with(user, |seen| seen.bubbled.offer(card_id, &name, &steps, now));
        }
    }
    state.push_companion(user, CompanionEvent::CompanionAct { act: number, steps });
    if !live.begun(user, number).await {
        let failed = not_possible("the companion did not answer", "companion_not_answering");
        return Err(failed.into());
    }
    Ok(Json(known(&state, user).await?))
}

/// The companion window says what its figure does.
async fn figure(
    State(state): State<AppState>,
    User(user): User,
    body: Bytes,
) -> ApiResult<StatusCode> {
    let figure: CompanionFigure = read(&body)?;
    let live = &state.companion;
    live.with(user, |seen| {
        let now = Instant::now();
        seen.bubbled.shown(figure.saying.as_deref(), now);
        seen.figure = Some((Instant::now(), figure));
    });
    live.told.notify_waiters();
    Ok(StatusCode::NO_CONTENT)
}

/// Cardwave's window says which screen it shows.
async fn app(
    State(state): State<AppState>,
    User(user): User,
    body: Bytes,
) -> ApiResult<StatusCode> {
    let app: AppScreen = read(&body)?;
    state.companion.with(user, |seen| seen.app = Some(app));
    Ok(StatusCode::NO_CONTENT)
}

/// What the companion of `user` knows now.
async fn known(state: &AppState, user: i64) -> ApiResult<CompanionState> {
    let (shown, figure) = state.companion.figure(user);
    let app = state.companion.with(user, |seen| seen.app.clone());
    let chat = state
        .run(move |db| {
            let Some(card_id) = settings::get(db, user)?.companion.card_id else {
                return Ok(None);
            };
            companion::newest_said(db, user, card_id, SHOWN_MESSAGES)
        })
        .await?;
    Ok(CompanionState {
        shown,
        figure,
        app,
        chat,
    })
}

/// A body read as JSON.
fn read<T: DeserializeOwned>(body: &[u8]) -> anyhow::Result<T> {
    serde_json::from_slice(body)
        .map_err(|error| Fail::said(Code::BadRequest, error.to_string()).into())
}

fn not_possible(sentence: &str, what: &str) -> Fail {
    Fail::said(Code::NotPossible, sentence).with("what", what)
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/companion.rs"));

#[cfg(test)]
mod tests {
    use serde_json::{from_value, json};

    use super::*;

    fn steps(text: &str) -> Vec<Move> {
        from_value(json!([{ "do": "say", "text": text }])).unwrap()
    }

    fn held(state: &str) -> CompanionFigure {
        from_value(json!({ "width": 1600, "height": 900, "x": 400, "y": 900, "state": state, "clip": null, "looking": null, "feeling": null, "saying": null, "steps": [], "chat_open": false, "acted": 0 })).unwrap()
    }

    #[test]
    fn the_steps_kept_are_those_of_the_newest_question_answered_first() {
        let mut seen = Seen::default();
        let (idle, touch) = (seen.ask(), seen.ask());
        seen.answered(touch, steps("Ouch."));
        seen.answered(idle, steps("Hm."));
        assert_eq!(seen.planned, steps("Ouch."));
        // Asked in order and answered in order, the later answer is kept.
        let (first, second) = (seen.ask(), seen.ask());
        seen.answered(first, steps("One."));
        seen.answered(second, steps("Two."));
        assert_eq!(seen.planned, steps("Two."));
    }

    #[test]
    fn a_question_answered_without_asking_the_animator_drops_older_answers_come_after() {
        let mut seen = Seen::default();
        let first = seen.ask();
        seen.answered(first, steps("Hm."));
        let (idle, other_chat) = (seen.ask(), seen.ask());
        seen.unasked(other_chat);
        seen.answered(idle, steps("Late."));
        assert_eq!(seen.planned, steps("Hm."));
    }

    #[test]
    fn steps_answered_while_the_hand_holds_the_figure_are_not_kept() {
        let mut seen = Seen::default();
        let first = seen.ask();
        seen.answered(first, steps("Hm."));
        for state in ["dragged", "shaken"] {
            seen.figure = Some((Instant::now(), held(state)));
            let ask = seen.ask();
            seen.answered(ask, steps("Wee."));
            assert_eq!(seen.planned, steps("Hm."), "{state}");
        }
        // Nor is an older answer that comes after the dropped one, let go.
        let (older, newer) = (seen.ask(), seen.ask());
        seen.answered(newer, steps("Wee."));
        seen.figure = Some((Instant::now(), held("idle")));
        seen.answered(older, steps("Late."));
        assert_eq!(seen.planned, steps("Hm."));
    }
}

//! "Make a character together" over HTTP. The server keeps no interview:
//! `GET /api/interview` gives a new one at its opening question, in the style of
//! the user's settings, with who its answers go to and all the kinds; each
//! `POST /api/interview/step` takes the page's state and a move and gives the next
//! state; the step carries the page's language, for the questions a model words.
//! 424 while the user has no provider. A page that hangs up drops the
//! handler, which stops the model; a failed step changes nothing, as the state is
//! the page's. `POST /api/interview/read-back` gives the read-back's lines with the
//! question each rests on; `POST /api/interview/not-it` replaces that question's
//! answer and reads back anew; `POST /api/interview/write` makes the card as "New
//! card" does and gives the lines to offer for the persona, with another model of
//! the account for this writing only, stored nowhere.

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use cw_ccv4::creation::{Private, PrivateRow};
use cw_library::interview::readback::{self, Line, Verdict};
use cw_library::interview::writer::{self, Making};
use cw_library::interview::{self, Asker, Interview, Move, gender, shown, texts};
use cw_library::settings;
use cw_provider::{self as provider, Provider};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{ApiResult, Page, User};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/interview", get(start))
        .route("/api/interview/step", post(step))
        .route("/api/interview/read-back", post(read_back))
        .route("/api/interview/not-it", post(not_it))
        .route("/api/interview/write", post(write))
}

#[derive(Serialize, TS)]
#[ts(export)]
pub struct InterviewStart {
    pub interview: Interview,
    /// The provider's name the answers go to; `None` for a model on this computer.
    pub goes_to: Option<String>,
    /// Every kind: what the kinds question's More adds to the six it shows.
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub kinds: Vec<String>,
    /// The private list's topics, in its order.
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub topics: Vec<String>,
    /// The choices that stand alone: a pick of one clears the question's others, another pick clears it.
    #[serde(with = "shown::many")]
    #[ts(as = "Vec<shown::Text>")]
    pub alone: Vec<String>,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewStep {
    pub interview: Interview,
    pub action: Move,
    /// The page's language, a BCP 47 code: a question a model words is in it.
    pub language: String,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewReadBack {
    pub interview: Interview,
}

/// The read-back's lines, and for each the log's index of the question it rests on;
/// `None`: nothing to ask again, so that line has no "That's not it"; and for each
/// whether it is the model's own guess, its words in no answer.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct ReadBack {
    pub lines: Vec<Line>,
    pub questions: Vec<Option<usize>>,
    pub guesses: Vec<bool>,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewNotIt {
    pub interview: Interview,
    /// The log's index of the question asked again.
    pub question: usize,
    pub action: Move,
}

#[derive(Serialize, TS)]
#[ts(export)]
pub struct InterviewCorrected {
    pub interview: Interview,
    pub read_back: ReadBack,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewPrivate {
    pub open: bool,
    pub rows: Vec<InterviewPrivateRow>,
    pub free: String,
}

/// A row of the private list as the page sends it: its topic an id.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewPrivateRow {
    pub topic: shown::Text,
    /// "yes", "no", "maybe" or "fantasy only".
    pub answer: String,
    pub never: bool,
}

/// Another of the account's models, for this writing only.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct OtherModel {
    pub provider_id: i64,
    pub model: String,
}

#[derive(Deserialize, TS)]
#[ts(export)]
pub struct InterviewWrite {
    pub interview: Interview,
    pub lines: Vec<Line>,
    pub verdicts: Vec<Verdict>,
    pub private: InterviewPrivate,
    pub other_model: Option<OtherModel>,
}

/// The new card, and the lines to offer for the persona.
#[derive(Serialize, TS)]
#[ts(export)]
pub struct InterviewWritten {
    pub card_id: i64,
    pub persona: Vec<String>,
}

/// What the user calls the provider, else the list's name, else its address's host.
fn goes_to(provider: &Provider) -> Option<String> {
    if provider::local::at(&provider.base_url) {
        return None;
    }
    if !provider.name.is_empty() {
        return Some(provider.name.clone());
    }
    if let Some(listed) = provider::list::at(&provider.base_url) {
        return Some(listed.name.clone());
    }
    let address = provider.base_url.split_once("://");
    let host = address.map_or(provider.base_url.as_str(), |(_, rest)| rest);
    Some(host.split('/').next().unwrap_or(host).to_string())
}

/// A new interview in the style of the settings, at its opening question.
async fn start(State(state): State<AppState>, User(user): User) -> ApiResult<Json<InterviewStart>> {
    let (provider, style) = state
        .run(move |db| {
            let provider = provider::chat(db, user)?;
            Ok((provider, settings::get(db, user)?.interview_style))
        })
        .await?;
    Ok(Json(InterviewStart {
        interview: Interview::new(style),
        goes_to: goes_to(&provider),
        kinds: texts::KIND_NAMES.iter().map(ToString::to_string).collect(),
        topics: texts::TOPICS.iter().map(ToString::to_string).collect(),
        alone: texts::ALONE.iter().map(ToString::to_string).collect(),
    }))
}

/// Who asks the model for `provider`.
fn models_of<'a>(state: &'a AppState, provider: &'a Provider) -> Asker<'a> {
    Asker {
        http: &state.http,
        provider,
    }
}

/// The interview's next state after a move on a question.
async fn step(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<InterviewStep>,
) -> ApiResult<Json<Interview>> {
    let provider = provider_of(&state, user, None).await?;
    let models = models_of(&state, &provider);
    Ok(Json(
        interview::step(&models, &asked.interview, asked.action, &asked.language).await?,
    ))
}

/// The read-back of `interview`, with each line's question.
async fn lines_of(state: &AppState, user: i64, interview: &Interview) -> ApiResult<ReadBack> {
    let provider = provider_of(state, user, None).await?;
    let models = models_of(state, &provider);
    let lines = readback::read_back(&models, interview).await?;
    let questions = lines
        .iter()
        .map(|line| readback::question_of(interview, &line.words))
        .collect();
    let guesses = lines
        .iter()
        .map(|line| readback::guessed(interview, &line.words))
        .collect();
    Ok(ReadBack {
        lines,
        questions,
        guesses,
    })
}

/// What the answers say the user needs.
async fn read_back(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<InterviewReadBack>,
) -> ApiResult<Json<ReadBack>> {
    Ok(Json(lines_of(&state, user, &asked.interview).await?))
}

/// "That's not it": the question's new answer, and the read-back anew.
async fn not_it(
    State(state): State<AppState>,
    User(user): User,
    Json(asked): Json<InterviewNotIt>,
) -> ApiResult<Json<InterviewCorrected>> {
    let mut interview = readback::reanswer(&asked.interview, asked.question, asked.action)?;
    let provider = provider_of(&state, user, None).await?;
    gender::finish(&models_of(&state, &provider), &mut interview).await;
    let read_back = lines_of(&state, user, &interview).await?;
    Ok(Json(InterviewCorrected {
        interview,
        read_back,
    }))
}

/// The chat model, or `other` of the account's entries with the chat model's values for a reply.
async fn provider_of(
    state: &AppState,
    user: i64,
    other: Option<OtherModel>,
) -> ApiResult<Provider> {
    let provider = state
        .run(move |db| {
            let chat = provider::chat(db, user)?;
            let Some(other) = other else {
                return Ok(chat);
            };
            let entry = provider::kinds::entry(db, user, other.provider_id)?;
            Ok(Provider {
                base_url: entry.base_url,
                api_key: entry.api_key,
                name: entry.name,
                model: other.model,
                thinking_off: None,
                seen_thinking: false,
                ..chat
            })
        })
        .await?;
    Ok(provider)
}

fn row_of(row: InterviewPrivateRow) -> PrivateRow {
    PrivateRow {
        topic: row.topic.english(),
        answer: row.answer,
        never: row.never,
    }
}

/// Writes the character and makes its card. A failure changes nothing: the state is the page's.
async fn write(
    State(state): State<AppState>,
    User(user): User,
    page: Page,
    Json(asked): Json<InterviewWrite>,
) -> ApiResult<(StatusCode, Json<InterviewWritten>)> {
    let _at_work = state.at_work(user)?;
    let provider = provider_of(&state, user, asked.other_model).await?;
    let models = Asker {
        http: &state.writer_http,
        provider: &provider,
    };
    let needs = readback::corrected(&asked.lines, &asked.verdicts);
    let private = Private {
        open: asked.private.open,
        rows: asked.private.rows.into_iter().map(row_of).collect(),
        free: asked.private.free,
    };
    let making = Making {
        interview: &asked.interview,
        needs: &needs,
        private: &private,
        model: &provider.model,
    };
    let mut written = writer::write_card(&models, &making).await?;
    // The card is the account's own, as a new card and a generated one are.
    let account = state
        .run(move |db| cw_accounts::users::account(db, user))
        .await?;
    written.card.creator = account.name;
    let (status, Json(made)) = super::cards::made(&state, user, &page, written.card).await?;
    super::describe::made(&state, user, made.card_id).await;
    let written = InterviewWritten {
        card_id: made.card_id,
        persona: written.persona,
    };
    Ok((status, Json(written)))
}

// This file's routes as tools (`tools::app`), which build.rs lists.
include!(concat!(env!("OUT_DIR"), "/route_tools/interview.rs"));

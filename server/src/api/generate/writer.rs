//! A reply's writer and its end (`api::generate`): `Writer` lists the reply
//! in `AppState::replies` while it is written, so that it can be stopped, and
//! takes it off when dropped; `finish` keeps what the reading left (the text,
//! its times, what the model was learned to do, what it read, the pictures it
//! made), frees the chat, hands memory the turn and pushes `reply_ended`.

use std::collections::hash_map::Entry;
use std::sync::Arc;

use cw_chat::chats::{self, BUSY};
use cw_chat::images;
use cw_coding::tools::Toolbox;
use cw_core::{Code, ErrorBody, Events, Fail, PageEvent};
use cw_provider::images::Picture;
use cw_provider::kinds::{self, Kind};
use cw_store::Db;
use tokio::sync::{Notify, oneshot};
use tokio::time::Instant;

use super::super::{ApiError, ReplyEvent, memory};
use super::Job;
use super::stream::Pushed;
use crate::AppState;

/// A chat's reply in the making, listed from before its message is added until
/// the message has ended, so that it can be stopped all that time. Dropping it
/// takes it off the list.
pub(super) struct Writer {
    pub(super) state: AppState,
    pub(super) user: i64,
    pub(super) chat_id: i64,
    pub(super) stop: Arc<Notify>,
    /// Who waits for its end (`events::reply_end`): the program that asked for it.
    waiter: Option<oneshot::Sender<Option<ErrorBody>>>,
}

impl Writer {
    pub(super) fn list(
        state: &AppState,
        user: i64,
        chat_id: i64,
        waiter: Option<oneshot::Sender<Option<ErrorBody>>>,
    ) -> Result<Self, Fail> {
        let stop = Arc::new(Notify::new());
        state.unless_restoring(|| match state.replies().entry((user, chat_id)) {
            Entry::Occupied(_) => Err(BUSY),
            Entry::Vacant(place) => {
                place.insert(stop.clone());
                Ok(())
            }
        })??;
        Ok(Self {
            state: state.clone(),
            user,
            chat_id,
            stop,
            waiter,
        })
    }

    /// Hands the reply's end to who waits for it, then frees the chat.
    fn end(mut self, error: Option<ErrorBody>) {
        if let Some(waiter) = self.waiter.take() {
            // A waiter that gave up is no fault.
            let _ = waiter.send(error);
        }
    }
}

impl Drop for Writer {
    fn drop(&mut self) {
        self.state.replies().remove(&(self.user, self.chat_id));
    }
}

/// What reading a reply left: its text, the pictures its tools made, what
/// was pushed of it, when it began and the error it ended with.
pub(super) struct Read {
    pub(super) content: String,
    pub(super) made: Vec<(String, Picture)>,
    pub(super) pushed: Pushed,
    pub(super) began: Instant,
    pub(super) failure: Option<anyhow::Error>,
}

/// Keeps what the reading left, frees the chat and tells the pages how the
/// reply ended.
pub(super) async fn finish(writer: Writer, job: Job, read: Read) {
    let (state, user, chat_id) = (writer.state.clone(), writer.user, writer.chat_id);
    let (message_id, head_before, speaker_id) = (job.message_id, job.head_before, job.speaker_id);
    let Read {
        content,
        made,
        pushed,
        began,
        failure,
    } = read;
    let ms = |at: Instant| at.duration_since(began).as_millis() as u64;
    let times = chats::Times {
        to_first_word_ms: pushed.first_word.map(ms),
        in_all_ms: ms(Instant::now()),
    };
    // A model not known to think that sent thinking is kept as one that does.
    let learned = (pushed.thought && !job.provider.thinks()).then(|| job.provider.model.clone());
    // Whether the provider still offers the model, where the reply tells it (Settings says it).
    let gone = match &failure {
        None => Some(false),
        Some(failure) => cw_provider::no_longer_offered(failure).then_some(true),
    };
    let model = job.provider.model.clone();
    let offered = job.toolbox.as_ref().and_then(Toolbox::task_offered);
    let calls = job.toolbox.as_ref().map(Toolbox::used).unwrap_or_default();
    let ended = state
        .work(move |db| {
            if let Some(model) = learned
                && let Err(failure) = kinds::saw_thinking(db, user, Kind::Chat, &model)
            {
                tracing::error!("that the model thinks could not be kept: {failure:#}");
            }
            if let Some(gone) = gone
                && let Err(failure) = kinds::set_gone(db, user, Kind::Chat, &model, gone)
            {
                tracing::error!(
                    "whether the model is still offered could not be kept: {failure:#}"
                );
            }
            // The tools called are kept before the end, whose message tells them.
            if let Err(failure) = chats::save_calls(db, user, message_id, &calls) {
                tracing::error!("what tools a reply called could not be kept: {failure:#}");
            }
            if let Err(failure) = chats::save_times(db, user, message_id, times) {
                tracing::error!("how long a reply took could not be kept: {failure:#}");
            }
            chats::finish_reply(db, user, message_id, &content, head_before)
        })
        .await;
    // The pictures come after the reply, while the chat is still its own.
    let kept = match (&ended, made.is_empty()) {
        (Ok(_), false) => {
            let keep = move |db: &Db| {
                made.iter().try_for_each(|(words, picture)| {
                    images::keep(db, user, chat_id, speaker_id, (words, words), picture).map(drop)
                })
            };
            Some(state.work(keep).await)
        }
        _ => None,
    };
    let pictures = matches!(kept, Some(Ok(())));
    let mut error = failure.map(|failure| ApiError::from(failure).body());
    if let Some(Err(failure)) = kept {
        tracing::error!("pictures could not be kept: {failure:#}");
        error.get_or_insert_with(|| Fail::new(Code::Internal).into());
    }
    if let Err(failure) = &ended {
        tracing::error!("a reply could not be saved: {failure:#}");
        error.get_or_insert_with(|| Fail::new(Code::Internal).into());
    }
    // The chat is free for its next reply before the pages hear of the end.
    writer.end(error.clone());
    let message = match ended {
        // A reply that ended with words is the end of a turn, which memory reads.
        Ok(Some(message)) if error.is_none() => {
            memory::remember(&state, user, chat_id);
            super::super::chats::name_itself(&state, user, chat_id);
            (!pictures).then_some(message)
        }
        Ok(_) if pictures => None,
        Ok(message) => message,
        // The message is still incomplete, which keeps the chat busy until a stop ends it.
        Err(_) => None,
    };
    // A task is offered by a reply that went through.
    let offered = offered.filter(|_| error.is_none());
    state.push_reply(
        user,
        ReplyEvent::ReplyEnded {
            chat_id,
            message_id,
            message: message.map(Box::new),
            error,
        },
    );
    if let Some(goal) = offered {
        state.push(user, &PageEvent::CodingOffer { chat_id, goal });
    }
}

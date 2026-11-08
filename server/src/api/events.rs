//! The event socket (`/ws`): what the server pushes to the pages. A change is
//! told to every page of its user but the one that made it (`AppState::tell`,
//! by its [`Page`] mark, `/ws?page=…`); a reply's end and its tool's question
//! go to all of the user's pages (`push_reply`). A socket ends when its session
//! ends, when another device's no longer reaches the server, when the app is
//! locked again, or when its page is too slow to keep up.

use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::Response;
use cw_chat::chats::MessageView;
use cw_core::{ErrorBody, Events, PageEvent};
use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, watch};
use ts_rs::TS;

use super::{Caller, Page, mark, version};
use crate::AppState;

/// Messages the server pushes over the event socket (`/ws`): what the pages
/// are told of, or a reply's end or its tool's question, which carry the
/// API's own types. The same JSON as one enum tagged by `type`.
#[derive(Serialize, TS)]
#[serde(untagged)]
#[ts(export)]
pub(crate) enum ServerEvent {
    Page(PageEvent),
    Reply(ReplyEvent),
    Companion(CompanionEvent),
}

/// What the companion window is told (`api::companion`).
#[derive(Serialize, TS)]
#[serde(tag = "type", rename_all = "snake_case")]
#[ts(export)]
pub(crate) enum CompanionEvent {
    /// Steps its figure is to run in place of what it does, the act numbered
    /// `act`, which the window says it has begun.
    CompanionAct {
        act: u32,
        steps: Vec<cw_chat::companion::Move>,
    },
}

/// A reply's events that carry the API's own types.
#[derive(Serialize, TS)]
#[serde(tag = "type", rename_all = "snake_case")]
#[ts(export)]
pub(crate) enum ReplyEvent {
    /// A reply has ended: it is complete, was stopped or has failed.
    ReplyEnded {
        chat_id: i64,
        message_id: i64,
        /// The message as it is now, which may hold more text than was pushed.
        /// Not there when the reply ended before any text: the message is gone
        /// and the chat is back where it was; nor when its tools made pictures,
        /// kept as messages after it: the chat is to be read anew.
        message: Option<Box<MessageView>>,
        /// Why the reply failed, when it did; a provider's own words are its
        /// detail `reason`.
        error: Option<ErrorBody>,
    },
    /// A reply's call of a tool waits for the user to allow it (`ask`), or no
    /// longer does (`None`).
    ToolAsks {
        chat_id: i64,
        message_id: i64,
        ask: Option<cw_coding::tools::ToolAsk>,
    },
}

/// What an event socket is given: the user an event is for (none: every
/// user), the page whose change it tells, which is not told of it, and the
/// event as JSON.
#[derive(Clone)]
pub(crate) struct Pushed {
    user: Option<i64>,
    from: Option<Arc<str>>,
    event: Arc<str>,
}

impl AppState {
    /// Pushes a reply's event to the pages of `user` that are listening.
    pub(crate) fn push_reply(&self, user: i64, event: ReplyEvent) {
        self.send(Some(user), None, &ServerEvent::Reply(event));
    }

    /// Tells the companion window of `user` what to do.
    pub(crate) fn push_companion(&self, user: i64, event: CompanionEvent) {
        self.send(Some(user), None, &ServerEvent::Companion(event));
    }

    /// Tells the pages of `user` that are listening of a change the page
    /// `from` made, but for that page.
    pub(super) fn tell(&self, user: i64, Page(from): &Page, event: &PageEvent) {
        self.send(Some(user), from.clone(), &ServerEvent::Page(event.clone()));
    }

    fn send(&self, user: Option<i64>, from: Option<Arc<str>>, event: &ServerEvent) {
        if let Ok(event) = serde_json::to_string(event) {
            let pushed = Pushed {
                user,
                from,
                event: event.into(),
            };
            // Nobody listening is fine.
            let _ = self.events.send(pushed);
        }
    }
}

impl Events for AppState {
    fn push(&self, user: i64, event: &PageEvent) {
        self.send(Some(user), None, &ServerEvent::Page(event.clone()));
    }

    fn push_all(&self, event: &PageEvent) {
        self.send(None, None, &ServerEvent::Page(event.clone()));
    }
}

/// Who opens an event socket: `/ws?page=…`, the page by its mark.
#[derive(Deserialize)]
pub(super) struct Listener {
    page: Option<String>,
}

pub(super) async fn events(
    State(state): State<AppState>,
    caller: Caller,
    Query(listener): Query<Listener>,
    ws: WebSocketUpgrade,
) -> Response {
    // Listening starts before the socket opens, so nothing pushed in between is missed.
    let pushed = state.events.subscribe();
    let page = listener.page.as_deref().and_then(mark);
    // Another device's socket ends when the home network no longer reaches the server.
    let reached = match caller.remote {
        true => state.gate().map(|gate| gate.reached()),
        false => None,
    };
    let shut = state.gate().map(|gate| gate.shut());
    let listening = Listening {
        user: caller.user,
        page,
        session: caller.session.as_deref().map(cw_accounts::sessions::key),
        reached,
        shut,
        state,
    };
    ws.on_upgrade(move |socket| event_loop(socket, listening, pushed))
}

/// Whom an event socket tells: the user, the page that is not told of its own
/// changes, the session its user's events go to while it lasts (by its key),
/// while another device's, whether the home network still reaches the
/// server, and whether the app was locked again, which ends every socket.
struct Listening {
    user: i64,
    page: Option<Arc<str>>,
    session: Option<Vec<u8>>,
    reached: Option<watch::Receiver<bool>>,
    shut: Option<watch::Receiver<bool>>,
    state: AppState,
}

/// Until `watched` is `now`, or for ever where nothing is watched: the home
/// network no longer reaching the server (`false`), the app locked again (`true`).
async fn until(watched: &mut Option<watch::Receiver<bool>>, now: bool) {
    match watched {
        Some(watched) => {
            // A sender gone (the server stopping) ends the wait as the change would.
            let _ = watched.wait_for(|is| *is == now).await;
        }
        None => std::future::pending().await,
    }
}

async fn event_loop(
    mut socket: WebSocket,
    mut listening: Listening,
    mut pushed: broadcast::Receiver<Pushed>,
) {
    let (user, page) = (listening.user, listening.page.clone());
    let Ok(hello) = serde_json::to_string(&PageEvent::Hello { version: version() }) else {
        return;
    };
    if socket.send(Message::Text(hello.into())).await.is_err() {
        return;
    }
    loop {
        tokio::select! {
            message = socket.recv() => match message {
                Some(Ok(message)) if !matches!(message, Message::Close(_)) => {}
                _ => return,
            },
            () = until(&mut listening.reached, false) => return,
            () = until(&mut listening.shut, true) => return,
            next = pushed.recv() => match next {
                Ok(Pushed { user: Some(to), .. }) if to != user => {}
                // A session that ended hears nothing more of its user; what every
                // user is told (a backup restored) it hears still.
                Ok(Pushed { user: Some(_), .. }) if listening
                    .session
                    .as_ref()
                    .is_some_and(|session| !listening.state.sessions.alive(session)) => return,
                // The page shows its own change already.
                Ok(Pushed { from: Some(from), .. }) if page.as_ref() == Some(&from) => {}
                Ok(Pushed { event, .. }) => {
                    if socket.send(Message::Text(event.as_ref().into())).await.is_err() {
                        return;
                    }
                }
                // A page too slow to keep up is cut off. It connects again and
                // reads its chat, which holds what it missed.
                Err(_) => return,
            },
        }
    }
}

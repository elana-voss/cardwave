//! Looks for the faces on the pictures that have none kept (`cw_library::faces`), behind whatever the app is doing:
//! when it starts, when a page fetches the list of cards, after a change of a card, and when the card folder brought
//! new ones; a page sees the boxes at its next fetch. One thread looks at a time and holds the model for that round
//! alone, as Windows ML asks all use of it on one thread. It ends after the picture in hand once the app has ended.
//! A failure, no graphics card above all, ends the looking until the next start: the cards simply have no boxes.
//! A round first gives a poster's letter (`cw_library::posters`) to the cards that have a mood and none, those from
//! before the letters above all; that needs no model, so it runs where the app looks for no faces too.

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use cw_find::place::Place;
use cw_library::faces::{self, Opener};
use cw_library::posters;

use crate::AppState;

/// What looks, where it is the app's; whether a round runs; whether a failure ended the looking.
pub(crate) struct Faces {
    open: Option<Opener>,
    looking: Arc<AtomicBool>,
    off: AtomicBool,
}

impl Faces {
    pub(crate) fn new(open: Option<Opener>) -> Self {
        Self {
            open,
            looking: Arc::default(),
            off: AtomicBool::new(false),
        }
    }
}

/// Starts a round unless one runs. Takes no time here; on a runtime only.
pub(crate) fn look(state: &AppState) {
    let faces = &state.faces;
    if faces.looking.swap(true, Ordering::Relaxed) {
        return;
    }
    let open = faces.open.clone();
    let looking = faces.looking.clone();
    let place = Place::new(move || looking.store(false, Ordering::Relaxed));
    let app = Arc::downgrade(&state.0);
    // Its result is the thread's end, of which nothing waits to hear: a failure is told and kept in `off`.
    drop(tokio::task::spawn_blocking(move || {
        let _place = place;
        while let Some(state) = app.upgrade() {
            match posters::give_once(&state.db) {
                Ok(true) => {}
                Ok(false) => break,
                Err(failure) => {
                    tracing::warn!("the cards' poster designs are not given: {failure:#}");
                    break;
                }
            }
        }
        let Some(open) = open else {
            return;
        };
        let mut eyes = None;
        while let Some(state) = app.upgrade() {
            if state.faces.off.load(Ordering::Relaxed) {
                return;
            }
            match faces::look_once(&state.db, &mut eyes, &open) {
                Ok(true) => {}
                Ok(false) => return,
                Err(failure) => {
                    tracing::warn!("the faces on the pictures are not looked for: {failure:#}");
                    state.faces.off.store(true, Ordering::Relaxed);
                    return;
                }
            }
        }
    }));
}

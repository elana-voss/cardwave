//! The companion as one interface, what it knows and what it does: its state
//! (`CompanionState`: where the figure is, what it plays, looks at, feels and
//! says, what is left of what it was told, what Cardwave's window and the
//! companion's chat show; never a picture of the screen) and its actions, the
//! steps of `Move` (`CompanionAct`). The companion window runs the steps and
//! says what its figure does (`CompanionFigure`); the server's
//! `api::companion` keeps that, hands the steps to the window and answers the
//! state, locally and as tools of other programs.

use serde::{Deserialize, Serialize};
use ts_rs::TS;

use super::{Feeling, Move};

/// A point of the screen, in CSS pixels from its top left corner.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

/// What the companion window says of its figure, each time that changes and
/// now and then while nothing does.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct CompanionFigure {
    /// The screen the figure is on, in CSS pixels; the floor is its foot.
    pub width: f64,
    pub height: f64,
    /// Where its feet are.
    pub x: f64,
    pub y: f64,
    /// What it does: idle, listening, thinking, talking, sleeping, sitting,
    /// startled, dragged, shaken, thrown, falling, bumped, bouncing, landing,
    /// walking or climbing.
    pub state: String,
    /// The clip that plays now, by its name in the figure (the carrier's are
    /// `Clip`'s, the robot's its own); none before the figure shows.
    pub clip: Option<String>,
    /// Where it looks; none: at the user.
    pub looking: Option<Point>,
    /// The feeling it shows now.
    pub feeling: Option<Feeling>,
    /// What its bubble says now.
    pub saying: Option<String>,
    /// What is left of the steps it was told, the one under way first.
    pub steps: Vec<Move>,
    /// Whether its compact chat is open.
    pub chat_open: bool,
    /// The last act (`CompanionAct`) it has begun, by its number.
    pub acted: u32,
}

/// What Cardwave's window shows: its route and the screen's heading.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct AppScreen {
    pub route: String,
    pub title: String,
}

/// A message of a chat: who said it and what, cut short.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct Said {
    pub who: String,
    pub text: String,
}

/// A chat as the companion knows it: its character and newest messages.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct ChatShown {
    pub chat_id: i64,
    pub character: String,
    pub said: Vec<Said>,
}

/// What the companion knows now.
#[derive(Clone, Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct CompanionState {
    /// Whether the companion window shows the figure: it said what the figure
    /// does a moment ago. Where not, `figure` is what it said last.
    pub shown: bool,
    pub figure: Option<CompanionFigure>,
    /// What Cardwave's window showed last; none since the server started.
    pub app: Option<AppScreen>,
    /// The newest chat with the companion's card; none without one.
    pub chat: Option<ChatShown>,
}

/// What the figure is to do now, in this order, in place of what it was
/// doing: walk, climb, let go, play a clip, look, react, say, wait.
#[derive(Clone, Debug, PartialEq, Deserialize, TS)]
#[ts(export)]
pub struct CompanionAct {
    pub steps: Vec<Move>,
}

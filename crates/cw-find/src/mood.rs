//! The mood a chat's reply tells, as the search model reads it (`reader`), and the picture of it its speaker's
//! expression pack shows in the portrait's place (`api/expressions.rs`). Picked as the Flutter app's
//! `cardwave_emotion` does: the reply's vector against each mood's description (`expressions::MOODS`), the
//! nearest at `THRESHOLD` or above, else neutral (`mood_of`); the pack's picture for it is
//! `expressions::picture_for`'s.

use cw_library::expressions::{MOODS, NEUTRAL, Storage, picture_for};
use serde::Serialize;
use ts_rs::TS;

use crate::{Host, reader, work};

/// How near, as a cosine, a reply must come to a mood's description to show it: the Flutter app's starting value,
/// not measured against real chats there or here.
pub const THRESHOLD: f32 = 0.5;

/// The picture of a message's mood, as the chat's portrait shows it.
#[derive(Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Expression {
    /// The mood the message came nearest; none where its speaker's card has no pack or the search model cannot
    /// tell it now (not set up, starting, failed).
    pub mood: Option<String>,
    /// The address of the pack's picture for it; none where the plain portrait shows.
    pub url: Option<String>,
}

/// The picture of a message's mood, where its speaker's card has a pack and the search model tells the mood.
pub async fn shown_for(state: &dyn Host, user: i64, message_id: i64) -> anyhow::Result<Expression> {
    let none = Expression {
        mood: None,
        url: None,
    };
    let (content, pack) =
        work(state, move |db| Storage::message_pack(db, user, message_id)).await?;
    let Some((pack, moods)) = pack else {
        return Ok(none);
    };
    let described = MOODS
        .iter()
        .map(|(_, description)| description.to_string())
        .collect();
    let Some(described) = reader::vectors(state, user, described).await else {
        return Ok(none);
    };
    let Some(reply) = reader::newest_vector(state, user, &content).await else {
        return Ok(none);
    };
    let cosines: Vec<f32> = described
        .iter()
        .map(|stored| cw_provider::embedder::cosine(&reply, stored))
        .collect();
    let mood = mood_of(&cosines);
    Ok(Expression {
        mood: Some(mood.to_string()),
        url: picture_for(mood, &moods).map(|shown| format!("/api/expressions/{pack}/{shown}")),
    })
}

/// The mood nearest to a reply by the cosines of its vector to each of `MOODS` (in that order): neutral where
/// none comes to `THRESHOLD`.
pub fn mood_of(cosines: &[f32]) -> &'static str {
    let best = cosines
        .iter()
        .zip(MOODS)
        .max_by(|a, b| a.0.total_cmp(b.0))
        .filter(|(cosine, _)| **cosine >= THRESHOLD);
    best.map_or(NEUTRAL, |(_, (mood, _))| mood)
}

//! The voices of an account: those it made from a recording (Settings ›
//! Voices, "Make a voice from a recording"), kept in the database with the
//! recording as `prepare` made it, so they are encrypted and backed up as all
//! data is; and the voice a card's character reads in (Settings › Voices,
//! "Characters' voices"), kept with the card. A voice is named by an id: a
//! shipped one's (`VOICES`), or `own-<n>` for one made, `n` never given again.
//! `voice_of` is which voice reads a text: the one asked for, else the card's,
//! else the account's (its setting `voice`), else the first shipped. A
//! provider's voice (`at:<name>`, `voice::at`) is kept in the same places,
//! checked against the provider's list by the API (`api::voice::listed`), and
//! passed over here.

use anyhow::{anyhow, ensure};
use cw_core::{Code, Fail};
use serde::Serialize;
use ts_rs::TS;

use crate::{VOICES, Voice, find};

/// What a made voice's id starts with.
const OWN: &str = "own-";

/// The longest name a made voice takes, in characters.
pub(crate) const NAME_MOST: usize = 60;

/// A voice the account made from a recording.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OwnVoice {
    pub id: i64,
    pub name: String,
}

impl OwnVoice {
    /// Its id among all voices.
    pub fn voice_id(&self) -> String {
        format!("{OWN}{}", self.id)
    }
}

/// A card whose character reads in a voice of its own: the character's name,
/// the card's title and the voice's id.
#[derive(Clone, Debug, Serialize, TS)]
#[ts(export)]
pub struct CharacterVoice {
    pub card_id: i64,
    pub name: String,
    pub title: String,
    pub voice: String,
}

/// What the account's voices need of the database, which `cw_store::voice` gives; every function here takes it.
pub trait Storage {
    fn own_voices(&self, user: i64) -> anyhow::Result<Vec<OwnVoice>>;
    /// The recording of the made voice `id`, where the user has it.
    fn own_recording(&self, user: i64, id: i64) -> anyhow::Result<Option<Vec<u8>>>;
    fn add_own_voice(&self, user: i64, name: &str, recording: &[u8]) -> anyhow::Result<OwnVoice>;
    /// Whether the user has the voice `id` to rename.
    fn rename_own_voice(&self, user: i64, id: i64, name: &str) -> anyhow::Result<bool>;
    /// Deletes it, and takes it from the cards that read in it; whether there was one.
    fn delete_own_voice(&self, user: i64, id: i64, voice_id: &str) -> anyhow::Result<bool>;
    /// The user's cards outside the Trash with a voice of their own, by name.
    fn character_voices(&self, user: i64) -> anyhow::Result<Vec<CharacterVoice>>;
    /// The voice of the user's card `card_id`, if it has one.
    fn character_voice(&self, user: i64, card_id: i64) -> anyhow::Result<Option<String>>;
    /// Sets or takes away the card's voice; whether the user has the card.
    fn set_character_voice(
        &self,
        user: i64,
        card_id: i64,
        voice: Option<&str>,
    ) -> anyhow::Result<bool>;
}

/// The made voice's number in `id`, where it is one's.
pub fn own_number(id: &str) -> Option<i64> {
    id.strip_prefix(OWN)?.parse().ok()
}

/// A voice that reads: shipped (its recording a file) or made (its recording kept).
pub enum Chosen {
    Shipped(&'static Voice),
    Own { id: String, recording: Vec<u8> },
}

impl Chosen {
    pub fn id(&self) -> &str {
        match self {
            Self::Shipped(voice) => voice.id,
            Self::Own { id, .. } => id,
        }
    }
}

/// The voice `id` of the user, if there is one.
pub fn chosen(db: &dyn Storage, user: i64, id: &str) -> anyhow::Result<Option<Chosen>> {
    if let Some(voice) = find(id) {
        return Ok(Some(Chosen::Shipped(voice)));
    }
    let Some(number) = own_number(id) else {
        return Ok(None);
    };
    Ok(db
        .own_recording(user, number)?
        .map(|recording| Chosen::Own {
            id: id.to_string(),
            recording,
        }))
}

/// The voices the user made.
pub fn all(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<OwnVoice>> {
    db.own_voices(user)
}

/// Keeps a voice of `recording` (as `voice::prepare` made it) named `name`.
pub fn add(db: &dyn Storage, user: i64, name: &str, recording: &[u8]) -> anyhow::Result<OwnVoice> {
    db.add_own_voice(user, name, recording)
}

/// Renames the made voice `number`; whether the user has it.
pub fn rename(db: &dyn Storage, user: i64, number: i64, name: &str) -> anyhow::Result<bool> {
    db.rename_own_voice(user, number, name)
}

/// Deletes the made voice `number` (its id `id`); whether the user had it.
pub fn delete(db: &dyn Storage, user: i64, number: i64, id: &str) -> anyhow::Result<bool> {
    db.delete_own_voice(user, number, id)
}

/// The user's cards with a voice of their own.
pub fn characters(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<CharacterVoice>> {
    db.character_voices(user)
}

/// Sets the card's voice to `voice`, which must be the user's, or takes it
/// away (`None`); answers the cards with a voice, `None` where the user has
/// no card `card`.
pub fn set_character(
    db: &dyn Storage,
    user: i64,
    card: i64,
    voice: Option<&str>,
) -> anyhow::Result<Option<Vec<CharacterVoice>>> {
    if let Some(voice) = voice {
        known(db, user, voice)?;
    }
    if !db.set_character_voice(user, card, voice)? {
        return Ok(None);
    }
    db.character_voices(user).map(Some)
}

/// The voice kept for the card's character, of this computer or a provider.
pub fn card_voice(db: &dyn Storage, user: i64, card: i64) -> anyhow::Result<Option<String>> {
    db.character_voice(user, card)
}

/// Refuses an id that is no voice of the user's; a provider's is checked by
/// the API before (`api::voice::listed`).
pub fn known(db: &dyn Storage, user: i64, id: &str) -> anyhow::Result<()> {
    let known = id.starts_with(crate::at::PREFIX)
        || find(id).is_some()
        || own_number(id)
            .map(|number| db.own_recording(user, number).map(|had| had.is_some()))
            .transpose()?
            .unwrap_or(false);
    ensure!(
        known,
        Fail::said(Code::NotPossible, format!("there is no voice {id:?}")).with("what", "no_voice")
    );
    Ok(())
}

/// The voice a text is read in: `asked`, which must be the user's, else the
/// card's (`card`), else the account's `account`, else the first shipped; a
/// voice of the card or account that is gone counts as none.
pub fn voice_of(
    db: &dyn Storage,
    user: i64,
    asked: Option<&str>,
    card: Option<i64>,
    account: Option<&str>,
) -> anyhow::Result<Chosen> {
    if let Some(asked) = asked {
        return chosen(db, user, asked)?.ok_or_else(|| {
            anyhow!(
                Fail::said(Code::NotPossible, format!("there is no voice {asked:?}"))
                    .with("what", "no_voice")
            )
        });
    }
    let of_card = match card {
        Some(card) => db.character_voice(user, card)?,
        None => None,
    };
    for id in [of_card.as_deref(), account].into_iter().flatten() {
        if let Some(voice) = chosen(db, user, id)? {
            return Ok(voice);
        }
    }
    Ok(Chosen::Shipped(&VOICES[0]))
}

/// A name as kept: trimmed, not empty, at most `NAME_MOST` characters.
pub fn name(name: &str) -> anyhow::Result<String> {
    let name = name.trim();
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "the voice needs a name").with("what", "voice_name")
    );
    ensure!(
        name.chars().count() <= NAME_MOST,
        Fail::said(
            Code::TooLong,
            format!("a voice's name is at most {NAME_MOST} characters")
        )
        .with("what", "voice_name")
        .with("name_most", NAME_MOST)
    );
    Ok(name.to_string())
}

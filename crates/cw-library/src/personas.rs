//! Personas: who the user is in a chat, a name, a description and a picture,
//! made small as an account's is (`set_picture`). One of them can be the
//! default, which a new chat starts with. Lorebooks of the library given to
//! one (`set_lorebooks`) are had by every chat it is in (`cw_store::lorebooks::HAD`).

use anyhow::ensure;
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::cards::name_order;
use crate::trash;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct Persona {
    pub id: i64,
    /// What `{{user}}` stands for.
    pub name: String,
    pub description: String,
    pub trashed: bool,
    /// New chats start with it. One in the Trash is not the default, and is
    /// again once it is back.
    pub is_default: bool,
    /// The address of its picture, which changes with the picture, where it has one.
    pub picture: Option<String>,
    /// The lorebooks of the library given to it, in the order they were: every
    /// chat the user is it in has them, as if attached to the chat's cards.
    pub lorebooks: Vec<PersonaLorebook>,
}

/// A lorebook of the library given to a persona.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct PersonaLorebook {
    pub id: i64,
    pub name: String,
    /// It is in the Trash: the persona keeps it until it is deleted for good.
    pub trashed: bool,
}

/// The address of the picture of persona `id`, set at `at`.
pub fn picture_address(id: i64, at: Option<i64>) -> Option<String> {
    at.map(|at| format!("/api/personas/{id}/picture?at={at}"))
}

/// What the personas need of the database, which `cw_store::personas` gives.
pub trait Storage: crate::lorebooks::Storage {
    fn add_persona(&self, user: i64, name: &str, description: &str) -> anyhow::Result<i64>;
    /// A persona of `user`, wherever it is.
    fn persona(&self, user: i64, persona_id: i64) -> anyhow::Result<Option<Persona>>;
    /// Those not in the Trash.
    fn personas(&self, user: i64) -> anyhow::Result<Vec<Persona>>;
    /// Whether the persona was there to change.
    fn change_persona(
        &self,
        user: i64,
        persona_id: i64,
        name: Option<&str>,
        description: Option<&str>,
    ) -> anyhow::Result<bool>;
    /// Whether the persona was there to change.
    fn set_persona_picture(
        &self,
        user: i64,
        persona_id: i64,
        picture: Option<&[u8]>,
        at: Option<i64>,
    ) -> anyhow::Result<bool>;
    fn persona_picture(&self, user: i64, persona_id: i64) -> anyhow::Result<Option<Vec<u8>>>;
    /// Makes the persona the user's default, or stops it being that.
    fn set_default_persona(&self, user: i64, persona_id: i64, default: bool) -> anyhow::Result<()>;
    /// Gives the persona these lorebooks and no others, forgetting what chats
    /// left out of one taken away where they no longer have it.
    fn set_persona_lorebooks(&self, persona_id: i64, lorebooks: &[i64]) -> anyhow::Result<()>;
    /// The default persona, where it is not in the Trash.
    fn default_persona(&self, user: i64) -> anyhow::Result<Option<i64>>;
}

/// How many letters a persona's name has at most; the form takes no more.
const MAX_NAME: usize = 64;

/// A persona's name as it is kept: without the blanks around it, not empty and not too long.
fn named(name: &str) -> anyhow::Result<&str> {
    let name = name.trim();
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "a persona needs a name").with("what", "persona_name")
    );
    ensure!(
        name.chars().count() <= MAX_NAME,
        Fail::said(
            Code::TooLong,
            format!("a persona's name has at most {MAX_NAME} letters")
        )
        .with("what", "persona_name")
        .with("max_name", MAX_NAME)
    );
    Ok(name)
}

pub fn create(db: &dyn Storage, user: i64, name: &str, description: &str) -> anyhow::Result<i64> {
    db.add_persona(user, named(name)?, description)
}

/// A persona of `user`, wherever it is: in the Trash too.
pub fn get(db: &dyn Storage, user: i64, persona_id: i64) -> anyhow::Result<Option<Persona>> {
    db.persona(user, persona_id)
}

/// A persona to give to a chat: not one in the Trash.
pub fn usable(db: &dyn Storage, user: i64, persona_id: i64) -> anyhow::Result<Persona> {
    let persona = get(db, user, persona_id)?.ok_or(NotFound("persona"))?;
    ensure!(
        !persona.trashed,
        Fail::said(
            Code::InTrash,
            format!(
                "the persona “{}” is in the Trash; restore it to use it",
                persona.name
            )
        )
        .with("what", "persona_to_use")
        .with("name", (persona.name).to_string())
    );
    Ok(persona)
}

/// The personas of `user` the library shows, by name, never those in the
/// Trash. A search finds the personas that have every word of the query in
/// their name or their description, in any case.
pub fn find(db: &dyn Storage, user: i64, query: &str) -> anyhow::Result<Vec<Persona>> {
    let query = query.to_lowercase();
    let words: Vec<&str> = query.split_whitespace().collect();
    let mut personas = db.personas(user)?;
    personas.retain(|persona| {
        let text = format!("{}\n{}", persona.name, persona.description).to_lowercase();
        words.iter().all(|word| text.contains(word))
    });
    personas.sort_by_cached_key(|persona| (name_order(&persona.name), persona.id));
    Ok(personas)
}

/// Changes a persona's name, its description or both; what is `None` stays.
/// A chat it is in goes by the new ones from its next reply on.
pub fn change(
    db: &dyn Storage,
    user: i64,
    persona_id: i64,
    name: Option<&str>,
    description: Option<&str>,
) -> anyhow::Result<()> {
    let name = name.map(named).transpose()?;
    let changed = db.change_persona(user, persona_id, name, description)?;
    ensure!(changed, NotFound("persona"));
    Ok(())
}

/// Refuses lorebooks a persona cannot be given: one not the user's, or one in
/// the Trash that the persona does not have yet.
pub fn ensure_givable(
    db: &dyn Storage,
    user: i64,
    persona: Option<&Persona>,
    lorebooks: &[i64],
) -> anyhow::Result<()> {
    for &id in lorebooks {
        let had = persona.is_some_and(|persona| persona.lorebooks.iter().any(|book| book.id == id));
        if !had {
            crate::lorebooks::ensure_usable(db, user, id)?;
        }
    }
    Ok(())
}

/// Gives a persona of `user` the lorebooks of the library `lorebooks`, in that
/// order, and no others; see [`ensure_givable`].
pub fn set_lorebooks(
    db: &dyn Storage,
    user: i64,
    persona_id: i64,
    lorebooks: &[i64],
) -> anyhow::Result<()> {
    let persona = get(db, user, persona_id)?.ok_or(NotFound("persona"))?;
    ensure_givable(db, user, Some(&persona), lorebooks)?;
    db.set_persona_lorebooks(persona_id, lorebooks)
}

/// Gives a persona the picture `file`, made small, or takes its picture away.
pub fn set_picture(
    db: &dyn Storage,
    user: i64,
    persona_id: i64,
    file: Option<&[u8]>,
) -> anyhow::Result<()> {
    let picture = file.map(cw_accounts::users::small).transpose()?;
    let at = picture.as_ref().map(|_| now_ms());
    let changed = db.set_persona_picture(user, persona_id, picture.as_deref(), at)?;
    ensure!(changed, NotFound("persona"));
    Ok(())
}

/// The picture of a persona, where it has one.
pub fn picture(db: &dyn Storage, user: i64, persona_id: i64) -> anyhow::Result<Option<Vec<u8>>> {
    db.persona_picture(user, persona_id)
}

/// Moves the persona to the trash or takes it back out; see [`trash`].
pub fn set_trashed(
    db: &dyn Storage,
    user: i64,
    persona_id: i64,
    trashed: bool,
) -> anyhow::Result<()> {
    if trashed {
        trash::put(db, user, trash::PERSONAS, persona_id)
    } else {
        trash::restore(db, user, trash::PERSONAS, persona_id)
    }
}

/// Makes a persona the one new chats start with, in place of the one that
/// was, or takes that back. One in the Trash cannot be made it.
pub fn set_default(
    db: &dyn Storage,
    user: i64,
    persona_id: i64,
    default: bool,
) -> anyhow::Result<()> {
    let persona = get(db, user, persona_id)?.ok_or(NotFound("persona"))?;
    if default {
        defaultable(persona.trashed)?;
    }
    db.set_default_persona(user, persona_id, default)
}

/// Refuses to make a persona the default that is in the Trash, or is about to be.
pub fn defaultable(trashed: bool) -> anyhow::Result<()> {
    ensure!(
        !trashed,
        Fail::said(
            Code::InTrash,
            "a persona in the Trash cannot be the default; restore it first"
        )
        .with("what", "persona_default")
    );
    Ok(())
}

/// The persona a new chat of `user` starts with, if there is one.
pub fn default_of(db: &dyn Storage, user: i64) -> anyhow::Result<Option<i64>> {
    db.default_persona(user)
}

//! Model presets: a provider's address, name and key, a chat model and the
//! values for a reply, kept under a name. Put in use ([`put_in_use`]), its
//! model is the chat model (at the provider of its address and key, added where
//! there is none) and its values the account's. A preset is made of what is in
//! use ([`create`]), renamed or given it anew ([`change`]), copied
//! ([`duplicate`]) and deleted ([`delete`]); a provider's new address or key
//! goes to its presets (`cw_store::provider`'s `change_entry`).
//!
//! Traps: [`put_in_use`] keeps the chat model before as a nameless row
//! (`replaced`) for Undo, one per user, until the chat model is stored or
//! picked otherwise or the server starts; numbers are never reused, so a gone
//! row's finds nothing. A preset is in use while the chat model is the same
//! address, key, model and values. A name another preset has adds or changes
//! no row. Over HTTP: `server/src/api/presets.rs`.

use anyhow::{anyhow, ensure};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use serde::Serialize;
use ts_rs::TS;

use crate::{NAME_LIMIT, Provider, chat, kinds, name_of};

/// A preset as its list shows it. The key never leaves the server.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct PresetView {
    pub id: i64,
    pub name: String,
    /// Whose API it asks: what the user calls the provider, else the name
    /// the list of providers has for its address, else the address's host;
    /// empty for a server on this computer, which the page words.
    pub provider: String,
    pub model: String,
    /// The one of its values for a reply that the list tells, where it is set.
    pub temperature: Option<f64>,
    /// Whether the stored provider is what this preset holds.
    pub in_use: bool,
}

/// A preset put in the stored provider's place.
#[derive(Debug)]
pub struct Used {
    /// The stored provider from now on.
    pub provider: Provider,
    /// The provider that was stored until now, kept as a preset no list
    /// shows: put in use, it takes this back. `None` where none was stored.
    pub before: Option<i64>,
}

/// Whether the chat model `stored` is what `holds` holds.
fn same(stored: &Provider, holds: &Provider) -> bool {
    stored.base_url == holds.base_url
        && stored.api_key == holds.api_key
        && stored.model == holds.model
        && stored.sampling == holds.sampling
}

/// A preset's name as it is kept: `typed` without the space around it; the
/// prompt presets' too.
pub fn called(typed: &str) -> anyhow::Result<String> {
    let name = name_of(typed, "a preset's")?;
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "the preset needs a name").with("what", "preset_name")
    );
    Ok(name)
}

/// That another preset is called `name`; the prompt presets' too.
pub fn taken(name: &str) -> anyhow::Error {
    anyhow!(
        Fail::said(Code::Taken, format!("another preset is called “{name}”"))
            .with("what", "preset_name")
            .with("name", name.to_string())
    )
}

/// What a copy is named, of a user's presets as (ID, name): none where the
/// one copied is not among them.
pub type Named<'a> = dyn Fn(&[(i64, String)]) -> Option<String> + 'a;

/// The stored provider and the user's presets, as `Storage::model_presets`
/// reads them.
pub struct KeptModelPresets {
    pub stored: Option<Provider>,
    /// Each as (ID, name, what it holds).
    pub presets: Vec<(i64, String, Provider)>,
}

/// What the presets need of the database, which `cw_store::provider` gives; a
/// preset reads the chat model in use through the kinds' storage.
pub trait Storage: crate::kinds::Storage {
    fn model_presets(&self, user: i64) -> anyhow::Result<KeptModelPresets>;
    /// What the row `id` holds, a preset or the provider one took the place
    /// of, if it is the user's.
    fn preset_holds(&self, user: i64, id: i64) -> anyhow::Result<Option<Provider>>;
    /// Its ID; none where another preset is called `name`.
    fn add_preset(&self, user: i64, name: &str, holds: &Provider) -> anyhow::Result<Option<i64>>;
    /// Gives a preset what is given: how many rows changed, none where
    /// another is called `name`.
    fn change_preset(
        &self,
        user: i64,
        id: i64,
        name: Option<&str>,
        holds: Option<&Provider>,
    ) -> anyhow::Result<usize>;
    /// Copies the preset under the name `named` gives of the user's presets
    /// as (ID, name), at once: the copy, none where it has no name.
    fn copy_preset(&self, user: i64, id: i64, named: &Named) -> anyhow::Result<Option<i64>>;
    /// Whether it was there.
    fn delete_preset(&self, user: i64, id: i64) -> anyhow::Result<bool>;
    /// As [`put_in_use`] says, at once; none where the user has no such preset.
    fn put_preset_in_use(&self, user: i64, id: i64) -> anyhow::Result<Option<Used>>;
}

/// The user's presets in the order of their names, whatever their case.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<PresetView>> {
    let KeptModelPresets {
        stored,
        presets: rows,
    } = db.model_presets(user)?;
    let mut presets: Vec<PresetView> = rows
        .into_iter()
        .map(|(id, name, holds)| PresetView {
            id,
            name,
            provider: kinds::whose(&holds.name, &holds.base_url),
            in_use: stored.as_ref().is_some_and(|stored| same(stored, &holds)),
            temperature: holds.sampling.temperature,
            model: holds.model,
        })
        .collect();
    presets.sort_by_cached_key(|preset| (preset.name.to_lowercase(), preset.id));
    Ok(presets)
}

/// The preset `id` as the list shows it.
fn one(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<PresetView> {
    let found = list(db, user)?.into_iter().find(|preset| preset.id == id);
    Ok(found.ok_or(NotFound("preset"))?)
}

/// The chat model in use with the account's values, which a preset keeps.
fn in_use(db: &dyn Storage, user: i64) -> anyhow::Result<Provider> {
    chat(db, user)
}

/// Keeps the chat model in use and the account's values under `name`, which
/// no other preset of the user's has.
pub fn create(db: &dyn Storage, user: i64, name: &str) -> anyhow::Result<PresetView> {
    let name = called(name)?;
    let holds = in_use(db, user)?;
    let id = db.add_preset(user, &name, &holds)?;
    one(db, user, id.ok_or_else(|| taken(&name))?)
}

/// Calls the preset `id` by another `name`, has it hold the chat model in
/// use and the account's values (`replace`), or both; what is left out stays.
/// A change that is refused is refused as a whole.
pub fn change(
    db: &dyn Storage,
    user: i64,
    id: i64,
    name: Option<&str>,
    replace: bool,
) -> anyhow::Result<PresetView> {
    let name = name.map(called).transpose()?;
    let holds = replace.then(|| in_use(db, user)).transpose()?;
    let changed = db.change_preset(user, id, name.as_deref(), holds.as_ref())?;
    // A preset that is not there, or is not the user's, was not changed either, and is not found.
    let preset = one(db, user, id)?;
    ensure!(changed == 1, taken(name.as_deref().unwrap_or(&preset.name)));
    Ok(preset)
}

/// Makes a copy of the preset `id`, with all it holds, under a name of its own
/// (`cw_core::copy_name`, with the word `copy`).
pub fn duplicate(db: &dyn Storage, user: i64, id: i64, copy: &str) -> anyhow::Result<PresetView> {
    let named = |presets: &[(i64, String)]| {
        let (_, name) = presets.iter().find(|(preset, _)| *preset == id)?;
        Some(cw_core::copy_name(copy, name, NAME_LIMIT, |made| {
            presets.iter().any(|(_, name)| name == made)
        }))
    };
    let copy = db.copy_preset(user, id, &named)?;
    one(db, user, copy.ok_or(NotFound("preset"))?)
}

/// Deletes the preset `id` for good, with the key it holds.
pub fn delete(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    ensure!(db.delete_preset(user, id)?, NotFound("preset"));
    Ok(())
}

/// Makes what the preset `id` holds the chat model and the account's values,
/// in place of those in use, which are kept as the one row [`Used::before`]
/// names. The preset may be such a row itself: then what was replaced is back.
pub fn put_in_use(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<Used> {
    // `None`: the user has no such preset.
    Ok(db.put_preset_in_use(user, id)?.ok_or(NotFound("preset"))?)
}

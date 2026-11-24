//! An account's providers (Settings › Providers) and the kind of model each
//! serves: providers ([`Entry`]: address, key, the user's name) and per kind
//! (chat, background, images, search, voice) its provider, model and thinking
//! ([`Picked`]). Each kind is at one provider; picking another's model moves it
//! ([`pick`]). Reply values are the account's (`Storage::sampling`). Search and
//! voice not at a provider are this computer's downloads ([`unpick`]).
//!
//! [`provider_of`] makes a kind a `Provider` to ask; a removed provider takes its
//! kinds along (the table's cascade). A model's thinking (`steps`) is kept per
//! model at its provider, so a model taken again finds its step; set by
//! [`thinking`], an Off once its provider took it. A ComfyUI's entry keeps its
//! workflow ([`Workflow`], [`keep_workflow`]). This computer's entry is made or
//! moved by its models' folder ([`keep_folder`], `local`), told by [`folder`].

use anyhow::{Context, ensure};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::Http;
use crate::steps::{self, Listed, Offer, SetThinking, Step, Thinking, ThinkingView};
use crate::{Provider, Sampling, address, check, key, list as known, local, model, name_of, whom};

/// A kind of model, each at one provider.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum Kind {
    Chat,
    Background,
    Images,
    /// The search model (`embedder`): its vectors asked at `<base>/embeddings`.
    Search,
    /// The voice: speech asked at `<base>/audio/speech` (`voice::at`).
    Voice,
}

impl Kind {
    pub fn as_str(self) -> &'static str {
        match self {
            Kind::Chat => "chat",
            Kind::Background => "background",
            Kind::Images => "images",
            Kind::Search => "search",
            Kind::Voice => "voice",
        }
    }

    /// Every kind, in the order the page shows them.
    pub const ALL: [Kind; 5] = [
        Kind::Chat,
        Kind::Background,
        Kind::Images,
        Kind::Search,
        Kind::Voice,
    ];

    pub fn of(text: &str) -> Option<Kind> {
        Kind::ALL.into_iter().find(|kind| kind.as_str() == text)
    }
}

/// A provider of the account's list, as kept.
#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub id: i64,
    /// What the user calls it; empty for none.
    pub name: String,
    pub base_url: String,
    /// Empty for none.
    pub api_key: String,
    /// A ComfyUI's saved workflow its pictures are made by; none for its default one.
    pub workflow: Option<Workflow>,
}

/// A workflow saved in a ComfyUI, picked for its pictures, and where in it
/// the picture's words go (`images::comfy`).
#[derive(Clone, Debug, PartialEq)]
pub struct Workflow {
    /// Its name in ComfyUI's folder of workflows, as `GET /userdata?dir=workflows` lists it.
    pub name: String,
    /// The ID of the node in the form `POST /prompt` takes, and the name of its input.
    pub node: String,
    pub input: String,
}

/// A kind's model, as kept.
#[derive(Clone, Debug, PartialEq)]
pub struct Picked {
    pub kind: Kind,
    pub entry: i64,
    pub model: String,
    pub thinking: Thinking,
    /// What its provider's list says of its thinking, read when it was picked ([`listed_at`]).
    pub listed: Listed,
    /// Whether an answer of the model carried thinking ([`saw_thinking`]).
    pub seen_thinking: bool,
    /// Whether the provider said it no longer offers the model ([`set_gone`]).
    pub gone: bool,
}

/// A provider as the page shows it. The key never leaves the server.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct EntryView {
    pub id: i64,
    /// What the user calls it, else the name the list has for its address, else the address's host;
    /// empty for a server on this computer, which the page words ([`whose`]).
    pub name: String,
    /// What the user called it, where the user did.
    pub own_name: Option<String>,
    pub base_url: String,
    pub has_key: bool,
    /// The last characters of the key, as the stored provider's are told.
    pub key_end: Option<String>,
    /// The name of the ComfyUI workflow its pictures are made by; none for its default one.
    pub workflow: Option<String>,
    /// This computer's folder of models; none for another provider.
    pub folder: Option<String>,
}

/// A kind's model as the page shows it.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct PickedView {
    pub kind: Kind,
    pub provider_id: i64,
    pub model: String,
    pub thinking: ThinkingView,
    /// Whether the provider said it no longer offers the model, since it was picked.
    pub gone: bool,
}

/// This computer's model of a kind that has one, downloaded in Settings › Models.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct OwnModel {
    pub kind: Kind,
    pub model: String,
}

/// The account's providers and its kinds' models.
#[derive(Debug, PartialEq, Serialize, TS)]
#[ts(export)]
pub struct ProvidersView {
    /// In the order they were added.
    pub(crate) providers: Vec<EntryView>,
    pub kinds: Vec<PickedView>,
    /// This computer's models: Search's and Voice's.
    pub own: Vec<OwnModel>,
}

/// A provider to add, as first run's first step hands it on.
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct NewEntry {
    pub base_url: String,
    /// Left out, the key kept for that address (`provider::whom`); empty, none.
    pub api_key: Option<String>,
    pub name: Option<String>,
}

/// A provider's address and key changed (Edit).
#[derive(Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeEntry {
    pub base_url: String,
    /// Left out, the key kept stays while the address does; empty removes it.
    pub api_key: Option<String>,
    /// Left out, the name stays; empty removes it.
    pub name: Option<String>,
}

/// A kind's model picked.
#[derive(Deserialize, TS)]
#[ts(export)]
pub struct PickModel {
    pub provider_id: i64,
    pub model: String,
}

/// The voice model's name, as the app shows it.
const VOICE_MODEL: &str = "Pocket TTS";

/// What the providers need of the database, which `cw_store::provider` gives.
pub trait Storage {
    /// The chat kind as the provider the chats ask, its thinking with it.
    fn chat_provider(&self, user: i64) -> anyhow::Result<Option<Provider>>;
    fn entries(&self, user: i64) -> anyhow::Result<Vec<Entry>>;
    fn picked(&self, user: i64) -> anyhow::Result<Vec<Picked>>;
    /// The entry at `base_url` with `key`, added where the account has none: its ID.
    fn entry_for(&self, user: i64, base_url: &str, key: &str, name: &str) -> anyhow::Result<i64>;
    /// Whether the user has such an entry; the presets at its address and key go with it.
    fn change_entry(&self, user: i64, entry: &Entry) -> anyhow::Result<bool>;
    fn remove_entry(&self, user: i64, id: i64) -> anyhow::Result<bool>;
    /// Keeps the workflow the entry's pictures are made by; none for ComfyUI's
    /// default one. False where the entry is not the user's.
    fn set_workflow(&self, user: i64, id: i64, workflow: Option<&Workflow>)
    -> anyhow::Result<bool>;
    /// Puts the kind at the entry with the model, which keeps its thinking;
    /// the background kind at the chat model's is none. False where the entry
    /// is not the user's.
    fn pick(&self, user: i64, kind: Kind, entry: i64, model: &str) -> anyhow::Result<bool>;
    /// Takes the kind from its provider; false where it was at none.
    fn unpick(&self, user: i64, kind: Kind) -> anyhow::Result<bool>;
    /// Keeps how the thinking of the entry's model stands. False where the entry is not the user's.
    fn set_thinking(
        &self,
        user: i64,
        entry: i64,
        model: &str,
        thinking: Thinking,
    ) -> anyhow::Result<bool>;
    /// Keeps what the entry's list says of its model's thinking. False where the entry is not the user's.
    fn set_listed(
        &self,
        user: i64,
        entry: i64,
        model: &str,
        listed: Listed,
    ) -> anyhow::Result<bool>;
    /// The chat kind's provider with `model` in its place, that model's thinking with it.
    fn chat_model(&self, user: i64, model: &str) -> anyhow::Result<Option<Provider>>;
    /// Marks the kind's model as one that thinks, while it is still `model`.
    fn saw_thinking(&self, user: i64, kind: Kind, model: &str) -> anyhow::Result<()>;
    /// Marks whether the provider no longer offers the kind's model, while it is still `model`.
    fn set_gone(&self, user: i64, kind: Kind, model: &str, gone: bool) -> anyhow::Result<()>;
    fn sampling(&self, user: i64) -> anyhow::Result<Sampling>;
    fn set_sampling(&self, user: i64, sampling: &Sampling) -> anyhow::Result<()>;
}

/// Whose API an address is, in words: what the user calls it, else the name
/// the list of providers has for it, else nothing for a loopback host (the page
/// words it, "A server on this computer", in its language), else its host.
pub fn whose(name: &str, base_url: &str) -> String {
    if !name.is_empty() {
        return name.to_string();
    }
    if let Some(listed) = known::at(base_url) {
        return listed.name.clone();
    }
    match crate::host(base_url) {
        Some((host, _)) if matches!(host.as_str(), "127.0.0.1" | "localhost" | "[::1]") => {
            String::new()
        }
        _ => crate::host_and_port(base_url).unwrap_or_else(|| base_url.to_string()),
    }
}

fn view(entry: Entry) -> EntryView {
    EntryView {
        name: whose(&entry.name, &entry.base_url),
        own_name: Some(entry.name).filter(|name| !name.is_empty()),
        key_end: crate::key_end(&entry.api_key),
        has_key: !entry.api_key.is_empty(),
        workflow: entry.workflow.map(|workflow| workflow.name),
        folder: local::folder_at(&entry.base_url).map(|folder| folder.display().to_string()),
        id: entry.id,
        base_url: entry.base_url,
    }
}

/// The kind's model at its entry, as far as its thinking needs: the values for a reply are left out.
fn asked(picked: &Picked, entry: &Entry) -> Provider {
    Provider {
        thinking: picked.thinking,
        listed: picked.listed.clone(),
        seen_thinking: picked.seen_thinking,
        ..Provider::new(&entry.base_url, &entry.api_key, &picked.model)
    }
}

fn shown(picked: Picked, entries: &[Entry]) -> PickedView {
    let thinking = match entries.iter().find(|entry| entry.id == picked.entry) {
        Some(entry) => steps::view(&asked(&picked, entry)),
        // The table's cascade takes a kind with its entry.
        None => ThinkingView::Switch { state: "on".into() },
    };
    PickedView {
        kind: picked.kind,
        provider_id: picked.entry,
        model: picked.model,
        thinking,
        gone: picked.gone,
    }
}

/// The account's providers and its kinds' models.
pub fn all(db: &dyn Storage, user: i64) -> anyhow::Result<ProvidersView> {
    let entries = db.entries(user)?;
    let kinds = db.picked(user)?;
    Ok(ProvidersView {
        kinds: kinds
            .into_iter()
            .map(|picked| shown(picked, &entries))
            .collect(),
        providers: entries.into_iter().map(view).collect(),
        own: [
            (Kind::Search, crate::embedder::MODEL),
            (Kind::Voice, VOICE_MODEL),
        ]
        .map(|(kind, model)| OwnModel {
            kind,
            model: model.to_string(),
        })
        .into(),
    })
}

/// Keeps that an answer of the kind's model `model` carried thinking, so that
/// its replies are given no limit that its thinking would fill
/// (`Provider::limited`). Another model picked begins unseen.
pub fn saw_thinking(db: &dyn Storage, user: i64, kind: Kind, model: &str) -> anyhow::Result<()> {
    db.saw_thinking(user, kind, model)
}

/// Keeps whether the provider said it no longer offers the kind's model `model`
/// ([`crate::no_longer_offered`]), for Settings to say; a reply that comes ends it, and
/// so does a model picked, the same one too.
pub fn set_gone(
    db: &dyn Storage,
    user: i64,
    kind: Kind,
    model: &str,
    gone: bool,
) -> anyhow::Result<()> {
    db.set_gone(user, kind, model, gone)
}

/// Lets go of the providers that presets took the place of: `user`'s, or everyone's.
pub fn forget_replaced(db: &dyn crate::Storage, user: Option<i64>) -> anyhow::Result<()> {
    db.forget_replaced_providers(user)
}

/// The account's values for a reply.
pub fn sampling(db: &dyn Storage, user: i64) -> anyhow::Result<Sampling> {
    db.sampling(user)
}

/// Keeps the values for a reply as they are typed, each in its range.
pub fn keep_sampling(db: &dyn Storage, user: i64, new: Sampling) -> anyhow::Result<Sampling> {
    new.check()?;
    db.set_sampling(user, &new)?;
    Ok(new)
}

/// The entry `id` of the user's.
pub fn entry(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<Entry> {
    let found = db.entries(user)?.into_iter().find(|entry| entry.id == id);
    Ok(found.ok_or(NotFound("provider"))?)
}

/// Adds a provider, or finds the one at that address with that key; a key
/// left out is the one kept for that address, as a form's list was asked
/// with (`provider::whom`), This computer's address its own entry.
pub fn add(db: &dyn Storage, user: i64, new: NewEntry) -> anyhow::Result<EntryView> {
    let (base_url, api_key) = whom(db, user, &new.base_url, new.api_key)?;
    let name = name_of(new.name.as_deref().unwrap_or_default(), "a provider's")?;
    let id = db.entry_for(user, &base_url, &api_key, &name)?;
    Ok(view(entry(db, user, id)?))
}

/// Gives a provider another address, key or name. A key left out stays only
/// while the address does: a key never goes to another server than its own.
pub fn change(db: &dyn Storage, user: i64, id: i64, new: ChangeEntry) -> anyhow::Result<EntryView> {
    let kept = entry(db, user, id)?;
    let base_url = address(&new.base_url)?;
    let api_key = match key(new.api_key)? {
        Some(typed) => typed,
        None if base_url == kept.base_url => kept.api_key.clone(),
        None => String::new(),
    };
    let name = match new.name {
        Some(typed) => name_of(&typed, "a provider's")?,
        None => kept.name.clone(),
    };
    // A workflow picked is of the ComfyUI at the old address.
    let moved = base_url != kept.base_url;
    let changed = Entry {
        id,
        name,
        base_url,
        api_key,
        workflow: kept.workflow.clone().filter(|_| !moved),
    };
    ensure!(db.change_entry(user, &changed)?, NotFound("provider"));
    if moved {
        db.set_workflow(user, id, None)?;
    }
    Ok(view(changed))
}

/// Has This computer's models be those of `folder`: its entry is made, or
/// moved there with its kinds, whose models the new folder may lack.
pub fn keep_folder(db: &dyn Storage, user: i64, folder: &str) -> anyhow::Result<()> {
    let folder = std::path::Path::new(folder.trim());
    ensure!(
        folder.is_absolute() && folder.is_dir(),
        Fail::said(
            Code::NotPossible,
            format!("there is no folder {folder:?} on this computer")
        )
        .with("what", "no_folder")
    );
    let base_url = local::address_of(folder)?;
    match db
        .entries(user)?
        .into_iter()
        .find(|entry| local::at(&entry.base_url))
    {
        Some(kept) => {
            let moved = Entry { base_url, ..kept };
            ensure!(db.change_entry(user, &moved)?, NotFound("provider"));
        }
        None => {
            db.entry_for(user, &base_url, "", local::NAME)?;
        }
    }
    Ok(())
}

/// This computer's folder of models, for what needs one chosen.
pub fn folder(db: &dyn Storage, user: i64) -> anyhow::Result<std::path::PathBuf> {
    let folder = db
        .entries(user)?
        .into_iter()
        .find_map(|entry| local::folder_at(&entry.base_url))
        .context(
            Fail::said(Code::Needed, "choose a folder of models first")
                .with("what", "models_folder"),
        )?;
    ensure!(
        folder.is_dir(),
        Fail::said(
            Code::NotPossible,
            format!("there is no folder {} on this computer", folder.display())
        )
        .with("what", "no_folder")
        .with("folder", (folder.display()).to_string())
    );
    Ok(folder)
}

/// Removes a provider, with the kinds that were at it.
pub fn remove(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    ensure!(db.remove_entry(user, id)?, NotFound("provider"));
    Ok(())
}

/// Has the provider's pictures made by `workflow`, or ComfyUI's default one.
pub fn keep_workflow(
    db: &dyn Storage,
    user: i64,
    id: i64,
    workflow: Option<&Workflow>,
) -> anyhow::Result<()> {
    ensure!(db.set_workflow(user, id, workflow)?, NotFound("provider"));
    Ok(())
}

/// Puts `kind` at the provider with the model, its thinking on.
/// With it is kept what its provider's list says of its thinking, where that was read ([`listed_at`]).
pub fn pick(
    db: &dyn Storage,
    user: i64,
    kind: Kind,
    asked: PickModel,
    listed: Option<Listed>,
) -> anyhow::Result<()> {
    let model = model(&asked.model)?;
    ensure!(
        db.pick(user, kind, asked.provider_id, &model)?,
        NotFound("provider")
    );
    if let Some(listed) = listed {
        db.set_listed(user, asked.provider_id, &model, listed)?;
    }
    Ok(())
}

/// Takes search or voice back to this computer's download; another kind
/// stays where it is, as only these two have a model of this computer's.
pub fn unpick(db: &dyn Storage, user: i64, kind: Kind) -> anyhow::Result<()> {
    ensure!(
        matches!(kind, Kind::Search | Kind::Voice),
        Fail::said(
            Code::NotPossible,
            "only search and voice can go back to this computer"
        )
        .with("what", "back_to_computer")
    );
    db.unpick(user, kind)?;
    Ok(())
}

/// The kind's model as kept, if one is picked.
pub fn picked(db: &dyn Storage, user: i64, kind: Kind) -> anyhow::Result<Option<Picked>> {
    Ok(db
        .picked(user)?
        .into_iter()
        .find(|picked| picked.kind == kind))
}

/// The provider to ask for `kind`: its entry's address and key, its model and
/// the account's values for a reply; none where the kind has no model.
pub fn provider_of(db: &dyn Storage, user: i64, kind: Kind) -> anyhow::Result<Option<Provider>> {
    if kind == Kind::Chat {
        return db.chat_provider(user);
    }
    let Some(picked) = picked(db, user, kind)? else {
        return Ok(None);
    };
    let entry = entry(db, user, picked.entry)?;
    Ok(Some(Provider {
        sampling: db.sampling(user)?,
        name: entry.name.clone(),
        ..asked(&picked, &entry)
    }))
}

/// How the thinking of `provider`'s model stands once the user set it: a
/// step it offers (a refused Off still known); on; or off by the first way its provider takes
/// (`steps::offs`), else it cannot be. A step or a switch the model does not
/// offer, and Off for a model that cannot stop thinking, are refused.
pub async fn thinking(
    http: &Http,
    provider: &Provider,
    asked: SetThinking,
) -> anyhow::Result<Thinking> {
    let not_offered = || {
        Fail::said(
            Code::NotPossible,
            format!("“{}” does not offer that thinking", provider.model),
        )
        .with("what", "thinking")
    };
    match (asked, steps::offer(provider)) {
        (SetThinking::Step { step }, Offer::Steps(steps)) if steps.contains(&step) => {
            if step != Step::Off {
                return Ok(provider.thinking.level(step));
            }
        }
        (SetThinking::Switch { on: false }, Offer::Switch) => {}
        (SetThinking::Switch { on: true }, Offer::Switch) => return Ok(Thinking::On),
        _ => anyhow::bail!(not_offered()),
    }
    Ok(check::thinking_off(http, provider, &steps::offs(provider))
        .await?
        .unwrap_or(Thinking::Cannot(None)))
}

/// Keeps how the thinking of the entry's model stands, for every kind at it.
pub fn keep_thinking(
    db: &dyn Storage,
    user: i64,
    entry: i64,
    model: &str,
    thinking: Thinking,
) -> anyhow::Result<()> {
    ensure!(
        db.set_thinking(user, entry, model, thinking)?,
        NotFound("provider")
    );
    Ok(())
}

/// What the list of `entry` says of the thinking of each of `models`, read
/// once where its own API lists it (OpenRouter's, its `reasoning`); none
/// where there is nothing to read, and none of a model the list does not tell.
pub async fn listed_at(
    http: &Http,
    entry: &Entry,
    models: &[String],
) -> anyhow::Result<Vec<(String, Listed)>> {
    if known::own_api(&entry.base_url) != Some(known::OwnApi::OpenRouter) || models.is_empty() {
        return Ok(Vec::new());
    }
    let url = format!("{}/models", entry.base_url);
    let described =
        crate::models::described(http, &url, &entry.api_key, Default::default()).await?;
    let mut found = Vec::new();
    for model in models {
        let model = crate::model(model)?;
        if let Some(listed) = listed_in(&described, &model) {
            found.push((model, listed));
        }
    }
    Ok(found)
}

/// What `described` says of `model`'s thinking: its entry's, else that of the
/// model it is a variant of (OpenRouter's `:nitro`, `:online`); the list's
/// silence where it came whole, nothing where it broke off before the model.
fn listed_in(described: &crate::models::Described, model: &str) -> Option<Listed> {
    let find = |id: &str| described.models.iter().find(|(listed, _)| listed == id);
    let found = find(model).or_else(|| find(model.split_once(':')?.0));
    match found {
        Some((_, said)) => Some(Listed {
            thinks: said.thinks,
            mandatory: said.mandatory,
            efforts: said.efforts.clone(),
        }),
        None if described.more => None,
        None => Some(Listed::default()),
    }
}

/// The chat and background kinds' models at a provider whose list tells their
/// thinking, by provider: read anew ([`listed_at`]) where a provider is stored
/// whole (first run, a preset put in use), as a pick reads its model's.
pub fn listing(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<(Entry, Vec<String>)>> {
    let mut listing: Vec<(Entry, Vec<String>)> = Vec::new();
    let entries = db.entries(user)?;
    for picked in db.picked(user)? {
        if !matches!(picked.kind, Kind::Chat | Kind::Background) {
            continue;
        }
        let Some(entry) = entries.iter().find(|entry| entry.id == picked.entry) else {
            continue;
        };
        if known::own_api(&entry.base_url) != Some(known::OwnApi::OpenRouter) {
            continue;
        }
        match listing.iter_mut().find(|(at, _)| at.id == entry.id) {
            Some((_, models)) => models.push(picked.model),
            None => listing.push((entry.clone(), vec![picked.model])),
        }
    }
    Ok(listing)
}

/// Keeps what the list of the entry `entry` says of its models' thinking ([`listed_at`]).
pub fn keep_listed(
    db: &dyn Storage,
    user: i64,
    entry: i64,
    listed: Vec<(String, Listed)>,
) -> anyhow::Result<()> {
    for (model, listed) in listed {
        ensure!(
            db.set_listed(user, entry, &model, listed)?,
            NotFound("provider")
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Described, Said};

    #[test]
    fn a_model_is_found_in_its_list_by_its_id_or_as_a_variant_and_not_where_the_list_broke_off() {
        let must = Said {
            mandatory: true,
            ..Default::default()
        };
        let mut described = Described {
            models: vec![("x/must".into(), must)],
            more: false,
        };
        let mandatory = |listed: Option<Listed>| listed.map(|listed| listed.mandatory);
        assert_eq!(mandatory(listed_in(&described, "x/must")), Some(true));
        assert_eq!(mandatory(listed_in(&described, "x/must:nitro")), Some(true));
        assert_eq!(listed_in(&described, "x/other"), Some(Listed::default()));
        described.more = true;
        assert_eq!(listed_in(&described, "x/other"), None);
    }

    #[test]
    fn a_server_on_this_computer_has_no_name() {
        assert_eq!(whose("", "http://127.0.0.1:8080/v1"), "");
        assert_eq!(whose("", "http://localhost:4321/v1"), "");
        assert_eq!(whose("", "http://[::1]:5000"), "");
        assert_eq!(whose("Mine", "http://127.0.0.1:8080/v1"), "Mine");
        assert_eq!(whose("", "https://example.org/v1"), "example.org");
    }
}

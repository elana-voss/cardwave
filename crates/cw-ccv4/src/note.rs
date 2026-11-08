//! [`ImportNote`]: what an import tells the user of a card or lorebook it took
//! with a flaw, as a code and fields the page words in its language. Only
//! handed back with the import, never stored.

use serde::Serialize;
use ts_rs::TS;

/// A flaw an import tolerated, or what it changed of the file.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[serde(tag = "code", rename_all = "snake_case")]
#[ts(export)]
pub enum ImportNote {
    /// A SillyTavern lorebook whose entries are not a list was left out.
    EntriesNotAList,
    /// `count` lorebook entries for an outlet were imported switched off.
    OutletEntriesOff { count: usize },
    /// An asset (`kind`, as the card calls it, "asset" where it says none,
    /// and `name`) is only linked, not part of the file, so not downloaded.
    AssetOnlyLinked { kind: String, name: String },
    /// An asset could not be read and was left out.
    AssetUnreadable { kind: String, name: String },
    /// `count` embedded files the card does not list were left out.
    UnlistedFiles { count: usize },
    /// Of several characters only the first, called `name`, was kept.
    FirstCharacterKept { name: String },
    /// An element of the kind `kind` stands in the file `file`, which is for
    /// the other side (the user's or the card's).
    Misplaced { kind: String, file: String },
    /// `owner`'s `key` points at `reference`, which does not exist.
    Dangling {
        owner: String,
        key: String,
        reference: String,
    },
    /// `owner`'s prompt names a placeholder the format does not know.
    UnknownPlaceholder { owner: String, placeholder: String },
    /// `owner`'s `key` names the asset `file`, which the card does not hold.
    MissingAsset {
        owner: String,
        key: String,
        file: String,
    },
}

//! The library: cards (`cards`, its folder, files, pictures and versions), lorebooks, personas, the
//! settings, the Trash, the unsaved edits, the character generator, cards described and rewritten by the
//! worker model (`describe`, `needs`, `rewrite`), thumbnails, expression packs, and the failures told outside a
//! request (`failures`), a model's quote against its text (`quotes`). Each module declares its own `Storage`, which cw-store implements; nothing here
//! knows SQL or HTTP. Above the services (cw-ccv4, cw-provider, cw-search, cw-voice), below cw-coding.

pub mod again;
pub mod cards;
pub mod describe;
pub mod expressions;
pub mod faces;
pub mod failures;
pub mod generator;
pub mod interview;
pub mod lorebooks;
pub mod needs;
pub mod personas;
pub mod posters;
mod quotes;
pub mod rewrite;
pub mod settings;
pub mod thumbnails;
pub mod trash;
pub mod unsaved;

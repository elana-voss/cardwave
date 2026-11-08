//! The chats and what lives in them: the chats, their replies and prompts
//! (`chats`, its `reply`), memory, documents, attachments, the assistant, the
//! companion, chat pictures (`images`), figures and the prompt presets. Each
//! module declares its storage interface, which the store implements;
//! `chats::Storage` is every one of them together, what a function across
//! modules takes. `chats::Side` implements cw-coding's `ChatSide`.

pub mod assistant;
pub mod attachments;
pub mod chats;
pub mod companion;
pub mod documents;
pub mod figures;
pub mod images;
pub mod memory;
pub mod prompt_presets;

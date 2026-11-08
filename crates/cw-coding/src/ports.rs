//! What coding (`coding`, `tools`, `mcp`) asks of the layers above it, which
//! implement it at start: the app (`AppActions`: its storage, its clients, the
//! running coding tasks, telling the pages) and the chats (`ChatSide`: posting
//! a task's message, making a picture). A tool's or task's failure is told by
//! `cw_library::failures::told` with the app's `Failures`.

use std::path::Path;
use std::sync::MutexGuard;

use cw_core::Events;
use cw_library::failures::Failures;
use cw_platform::http::Client;
use cw_provider::images::{Picture, Whom};
use futures_util::future::BoxFuture;

use crate::coding::run::Tasks;
use crate::tools::web::Web;

/// What coding stores: its tasks and the written tools.
pub trait Storage: crate::coding::Storage + crate::tools::written::Storage {}

impl<T: crate::coding::Storage + crate::tools::written::Storage + ?Sized> Storage for T {}

/// What coding's tools and tasks ask of the app.
pub trait AppActions: Events + Failures + Send + Sync {
    /// The storage, for work on a thread that may block.
    fn store(&self) -> &dyn Storage;
    /// The chats a task posts to and pictures are made for.
    fn chat(&self) -> Box<dyn ChatSide + '_>;
    /// The client every model provider is asked with.
    fn http(&self) -> &cw_provider::Http;
    /// The web tool's searches and pages.
    fn web(&self) -> &Web;
    /// The data folder, which commands in the sandbox may not touch.
    fn data_dir(&self) -> &Path;
    /// The coding tasks that run.
    fn tasks(&self) -> MutexGuard<'_, Tasks>;
}

/// What coding asks of the chats.
pub trait ChatSide: Send + Sync {
    /// Posts `content` to the chat as a complete message of its assistant: its ID.
    fn post(&self, user: i64, chat_id: i64, content: &str) -> anyhow::Result<i64>;
    /// A picture of `words` by the image model `whom`.
    fn picture<'a>(
        &'a self,
        http: &'a Client,
        whom: &'a Whom,
        words: &'a str,
    ) -> BoxFuture<'a, anyhow::Result<Picture>>;
}

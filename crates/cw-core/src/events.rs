//! Telling the pages: a [`PageEvent`] is what they are told of, [`Events`]
//! the port an area tells them through, which the server implements on its
//! state and sends over its event socket (`/ws`).

use serde::Serialize;
use ts_rs::TS;

/// Tells the pages that are listening.
pub trait Events {
    /// Tells the pages of `user`.
    fn push(&self, user: i64, event: &PageEvent);

    /// Tells the pages of every user.
    fn push_all(&self, event: &PageEvent);
}

/// What the pages are told of: a change they show anew, or a reply's step.
#[derive(Clone, Debug, Serialize, TS)]
#[serde(tag = "type", rename_all = "snake_case")]
#[ts(export)]
pub enum PageEvent {
    Hello {
        version: String,
    },
    /// The account as it is after a change of it (its name, its picture):
    /// every page of its user shows it.
    Account {
        name: String,
        local: bool,
        picture: Option<String>,
    },
    /// A lorebook of the library was changed: its name, its description, a
    /// flag or an entry. It was also made (imported, copied from a card) or
    /// deleted for good. A page that shows it reads it anew.
    Lorebook {
        id: i64,
    },
    /// The user's model presets were changed: one was made, changed, copied
    /// or deleted. A page that shows them reads them anew.
    Presets,
    /// The card `id` was imported or made, edited (its texts, summary,
    /// picture or languages), starred, archived, put in the Trash or taken
    /// out, or deleted for good, or its lorebooks were changed (its own, or
    /// which of the library it has). A page that shows it, or the library's
    /// list, reads it anew.
    Card {
        id: i64,
    },
    /// The import of a folder of cards came further, at most once a second, or ended: cards were imported.
    /// A page that shows how far it is, or the library's list, reads it anew.
    CardFolder,
    /// The user's personas were changed: one was made, changed, made the
    /// default or no longer, starred, archived, put in the Trash or taken out,
    /// or deleted for good. A page that shows them reads them anew.
    Personas,
    /// The account's settings were changed. A page that shows them reads
    /// them anew.
    Settings,
    /// Something was put in the Trash, taken out or deleted for good, or the
    /// Trash was emptied. A page that shows the Trash, or a list an item came
    /// back to, reads it anew.
    Trash,
    /// A message was sent into the chat, or one was deleted or the deletion
    /// put back. A page that shows the chat, or a list of chats, reads it anew.
    Messages {
        chat_id: i64,
    },
    /// The chat `id` was started, renamed, starred, archived, put in the
    /// Trash or taken out, or deleted for good. A page that shows it, or a list
    /// of chats (the Chats list, the rail's latest, a card's box), reads it anew.
    Chat {
        id: i64,
    },
    /// A tool the model wrote was switched on or off, deleted, or put back. A
    /// page that shows the written tools, or whether a chat offers a tool,
    /// reads it anew.
    WrittenTools,
    /// Cards were queued to be described (`card_id` none), or the card
    /// `card_id` was described, refused or failed. A page that shows a card's
    /// tags, logline or summary, or how far the describing is, reads it anew.
    Descriptions {
        card_id: Option<i64>,
    },
    /// The stored provider was changed: by a form, the settings' line, first
    /// run or a preset put in use. A page that shows it, or which preset is in
    /// use, reads it anew; the key is never told.
    Provider,
    /// A chat's memories were changed: a pass kept some, or one was changed,
    /// deleted or put back. A page that shows them, or the chat, reads it anew.
    Memories {
        chat_id: i64,
    },
    /// The user's documents were changed: one was added, deleted or put back,
    /// or the search model read one. A page that shows them reads them anew.
    Documents,
    /// The search model's download went a step on, ended or was cancelled,
    /// the model was removed or failed, or it read a card. A page that shows
    /// its state reads it anew.
    Search,
    /// The voice's download went a step on, ended, failed or was cancelled. A
    /// page that shows its state reads it anew.
    Voice,
    /// Dictation's download went a step on, ended, failed or was cancelled,
    /// or its model was removed. A page that shows its state reads it anew.
    Dictation,
    /// A download of a model that fits this computer went a step on, ended,
    /// failed or was cancelled, or the model was removed. A page that lists
    /// This computer's models reads them anew.
    LocalModels,
    /// The newest sentence of the model's thinking before a reply, which a
    /// chat shows until the reply's words begin; the thinking is never kept.
    ReplyThinking {
        chat_id: i64,
        message_id: i64,
        line: String,
    },
    /// More text of a reply that is being generated.
    ReplyText {
        chat_id: i64,
        message_id: i64,
        /// Length of the reply before this piece in UTF-16 units, which is what
        /// a JavaScript string's `length` counts. A page whose text is shorter
        /// has missed a piece and reads the chat again.
        start: usize,
        text: String,
    },
    /// A backup was restored: all the user had is another now, so a page
    /// starts anew.
    Restored,
    /// A coding task in the chat began, went a step on, asks the user, or
    /// ended. A page that shows it reads it anew; a chat without its card
    /// reads the chat anew.
    CodingTask {
        id: i64,
        chat_id: i64,
    },
    /// A chat without a character named itself (`chats::title`).
    ChatTitle {
        chat_id: i64,
        title: String,
    },
    /// A chat that picks its mode by itself picked another (`assistant`).
    ChatMode {
        chat_id: i64,
        mode: String,
    },
    /// A reply offered a coding task with this goal: a page that shows the
    /// chat shows the dialog that starts it, filled in.
    CodingOffer {
        chat_id: i64,
        goal: String,
    },
}

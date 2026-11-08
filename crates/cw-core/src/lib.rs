//! The core under every other crate: how the app fails ([`Fail`], its
//! [`Code`] and how it is told, [`ErrorBody`]), an item not found
//! ([`NotFound`]), the clock ([`now_ms`]), a copy's name ([`copy_name`]), taking a mutex ([`lock`]), the
//! languages, and the port the pages are told through ([`Events`], what they
//! are told [`PageEvent`]). No I/O, no web, no SQL: the server turns a code
//! into an HTTP status and implements `Events`.

mod clock;
mod copy;
mod events;
mod fail;
pub mod languages;
mod mutex;

pub use clock::now_ms;
pub use copy::{COPY_WORD, copy_name};
pub use events::{Events, PageEvent};
pub use fail::{Code, Detail, ErrorBody, Fail, NotFound, as_internal, coded, told};
pub use mutex::lock;

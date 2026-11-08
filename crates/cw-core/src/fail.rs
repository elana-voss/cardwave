//! A failure as the app tells it: a stable [`Code`] from the one list, its
//! details (as fields) and an English sentence (`error`) naming them; the UI
//! words it from the code and the details. An area fails with a [`Fail`] (a
//! code and its details) or [`NotFound`]; [`coded`] finds either in an
//! `anyhow` chain, [`told`] makes the [`ErrorBody`] a failure is told with.
//! The HTTP status of each code is the API's (`api::http_status`). Traps: a `Fail`
//! keeps its place in an `anyhow` chain, also given as a context, so a context
//! put before it still reads first; a code's sentence names its details as
//! `{name}`, filled from them; one it does not name follows in brackets, for
//! the log; the server's own failure is known by `Code::Internal` alone, which
//! whoever runs the database or a task adds.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Body of every answer that is an error, and of a failure an event tells.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct ErrorBody {
    pub code: Code,
    /// What went wrong, in English, for a developer or a model; the UI shows
    /// its own words for `code`.
    pub error: String,
    pub details: BTreeMap<String, Detail>,
}

/// A detail of an error, as the sentence names it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[serde(untagged)]
#[ts(export)]
pub enum Detail {
    Number(i64),
    Text(String),
}

impl From<String> for Detail {
    fn from(text: String) -> Self {
        Self::Text(text)
    }
}

impl From<&str> for Detail {
    fn from(text: &str) -> Self {
        Self::Text(text.to_string())
    }
}

impl From<usize> for Detail {
    fn from(number: usize) -> Self {
        Self::Number(i64::try_from(number).unwrap_or(i64::MAX))
    }
}

impl From<u64> for Detail {
    fn from(number: u64) -> Self {
        Self::Number(i64::try_from(number).unwrap_or(i64::MAX))
    }
}

impl From<u32> for Detail {
    fn from(number: u32) -> Self {
        Self::Number(number.into())
    }
}

impl From<u16> for Detail {
    fn from(number: u16) -> Self {
        Self::Number(number.into())
    }
}

impl std::fmt::Display for Detail {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Number(number) => write!(f, "{number}"),
            Self::Text(text) => f.write_str(text),
        }
    }
}

/// Declares the codes, each with its sentence.
macro_rules! codes {
    ($($(#[$doc:meta])* $code:ident, $sentence:literal;)+) => {
        /// What went wrong, the one list of the API's error codes.
        #[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
        #[serde(rename_all = "snake_case")]
        #[ts(export)]
        pub enum Code {
            $($(#[$doc])* $code,)+
        }

        impl Code {
            /// Its English sentence, with `{name}` where a detail goes.
            pub fn sentence(self) -> &'static str {
                match self {
                    $(Self::$code => $sentence,)+
                }
            }
        }
    };
}

codes! {
    /// Anything else the request got wrong; `error` says what.
    RequestFailed, "the request could not be done";
    /// The server itself failed.
    Internal, "the server failed to handle the request";
    /// A request the server could not read (its body's shape, a parameter).
    BadRequest, "the request could not be read";
    /// Another site's page, or an address that is not this computer's.
    Forbidden, "Forbidden";
    NoSuchPath, "Not Found";
    MethodNotAllowed, "Method Not Allowed";
    TooLarge, "the request is too large";
    UnsupportedType, "the request's type is not taken";
    Locked, "Cardwave is locked until its password is given";
    SignIn, "Sign in first.";
    PasswordWrong, "Wrong password.";
    PasswordNeeded, "The password is needed.";
    CurrentPasswordNeeded, "The current password is needed.";
    BackupPasswordNeeded, "This backup needs its password.";
    TooManyTries, "Too many wrong passwords. Try again in {seconds} seconds.";
    /// What only this computer's account may do; `action` says what.
    OwnerOnly, "Only this computer's account can {action}.";
    /// `what` is not there, or is another user's.
    NotFound, "no such {what}";
    ChatBusy, "a reply is being generated in this chat; stop it first";
    NoProvider, "no model provider is set up yet";
    ProviderRefused, "{whose} answered {status}: {reason}";
    AccountBusy, "Cardwave is still writing a reply or describing cards for this account; try again when it is done.";
    RestoreBusy, "Cardwave is still writing a reply or reading your cards; try again when it is done.";
    BackupNeedsPassword, "A backup needs a password.";
    ModelSeesNoPictures, "{model} cannot see pictures, so it takes none";
    NoSuchFolder, "there is no folder {folder} on this computer";
    FolderNotChosen, "choose a folder first";
    DriveRootToWatch, "a drive's root holds too much to watch; choose a folder in it";
    DriveRootForModel, "a drive's root holds too much to give the model; choose a folder in it";
    DataFolder, "that folder holds Cardwave's own data, or is in it; choose another";
    CommandsWindowsOnly, "commands are run only on Windows";
    RecycleBinWindowsOnly, "files are moved to the Recycle Bin only on Windows";
    CardTrashed, "the card is in the Trash; restore it first";
    LorebookTrashed, "the lorebook “{name}” is in the Trash; restore it to use it";
    OwnLorebookFlags, "a card's own lorebook has no star, is not archived or trashed by itself and is not for every chat";
    PictureWordsMissing, "say what the picture shows first";
    PictureWordsTooLong, "what the picture shows is longer than {most} characters";
    PictureNeedsWords, "a picture is made of words";
    GoalMissing, "say what the team is to do";
    FilesToolOff, "switch on Files in Settings › Tools first: the team reads and writes the task's folder with it";
    DictationNotSetUp, "dictation is not set up: Settings › Models › Dictation";
    DirectionWithoutGoOn, "a direction is given only with a reply continued";
    AgainOrGoOn, "a reply is either written again or continued";
    AgainNotReply, "only a character's reply can be written again";
    NoText, "the model sent no text";
    WorkerNoAnswer, "the worker model gave no answer";
    NoPasswordToLock, "Cardwave locks only while a password is on";
    UnknownVoice, "there is no voice “{voice}”";
    NothingToRead, "there is nothing to read";
    VoiceNotDownloaded, "the voice is not downloaded";
    /// Reading aloud on this computer failed; `error` says why.
    VoiceFailed, "reading aloud failed";
    RemoteSignInOff, "This account cannot sign in from another device.";
    NoPasswordOn, "No password is on.";
    NoPasswordSet, "no password is set for this account";
    /// An account other than this computer's cannot switch its password off.
    PasswordKept, "An account on this server keeps a password: it signs in with it.";
    Stopping, "the server is stopping";
    NoReplyToWriteAgain, "the chat has no reply to write again";
    /// A download failed; `error` says why.
    DownloadFailed, "the download failed";
    /// The search model failed to start or to answer; `error` says why.
    SearchModelFailed, "the search model failed";
    /// A provider's list of models, or of workflows, did not come; `error` says why.
    ModelsNotListed, "the provider's list did not come";
    /// A file of a folder of cards could not be imported; `error` says why.
    FileNotImported, "the file could not be imported";
    /// A card's describing by the worker model failed; `error` says why.
    DescribingFailed, "the card could not be described";
    // The kinds an area's own failures are grouped by: `what` (snake case)
    // names the thing, the UI picks its words by it; `said` keeps the area's
    // sentence as `error` (`Fail::said`). Each answers 400 (`api::http_status`).
    /// Something needed is missing; `what` says what.
    Needed, "{what} is needed";
    /// A text longer than it may be; `what`, and `most` its characters.
    TooLong, "{what} is longer than {most} characters";
    /// A number outside what it may be; `what`, `least` and `most`.
    OutOfRange, "{what} is not from {least} to {most}";
    /// Already there: `what`, and `name` where it has one.
    Taken, "{what} is there already";
    /// In the Trash, to be restored first: `what`, and `name` where it has one.
    InTrash, "{what} is in the Trash; restore it first";
    /// A file or text that is not what it is to be: `what` it is to be.
    NotReadable, "this is no {what} that can be read";
    /// Larger than it may be: `what`.
    TooBig, "{what} is too large";
    /// Not possible as things stand: `what` says what stands in the way.
    NotNow, "{what}";
    /// What was asked was changed meanwhile by another: `what`.
    Changed, "{what} was changed meanwhile";
    /// Cannot be done to this thing: `what` says what.
    NotPossible, "{what} cannot be done";
    /// A model's answer that cannot be used: `what` it lacked.
    ModelAnswer, "the model's answer cannot be used: {what}";
    /// The model itself declined to answer, by its provider's signal: `model`, its `reason`.
    ModelDeclined, "{model} declined to write this";
    /// A server Cardwave asks did not answer in time: `whose`.
    TimedOut, "{whose} did not answer in time";
    /// A server Cardwave asks cannot be reached: `whose`.
    Unreachable, "{whose} cannot be reached";
    /// A server Cardwave asks answered with a failure: `whose`, `status`.
    Answered, "{whose} answered {status}";
}

/// A failure with its code and details; it goes through `anyhow` as itself.
#[derive(Clone, Debug)]
pub struct Fail {
    pub code: Code,
    pub details: BTreeMap<String, Detail>,
    /// The area's own English sentence, kept as `error` in place of the code's.
    pub said: Option<String>,
}

impl Fail {
    pub const fn new(code: Code) -> Self {
        Self {
            code,
            details: BTreeMap::new(),
            said: None,
        }
    }

    /// The failure of `code` whose `error` is `sentence`, the area's own words.
    pub fn said(code: Code, sentence: impl Into<String>) -> Self {
        Self {
            said: Some(sentence.into()),
            ..Self::new(code)
        }
    }

    /// The failure with the detail `name`.
    pub fn with(mut self, name: &str, value: impl Into<Detail>) -> Self {
        self.details.insert(name.to_string(), value.into());
        self
    }
}

impl std::fmt::Display for Fail {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if let Some(said) = &self.said {
            return f.write_str(said);
        }
        let mut text = self.code.sentence().to_string();
        for (name, value) in &self.details {
            let mark = format!("{{{name}}}");
            match text.contains(&mark) {
                true => text = text.replace(&mark, &value.to_string()),
                // Kept for the log, such as an internal failure's reason.
                false => text.push_str(&format!(" ({name}: {value})")),
            }
        }
        f.write_str(&text)
    }
}

impl std::error::Error for Fail {}

impl From<Fail> for ErrorBody {
    fn from(fail: Fail) -> Self {
        Self {
            code: fail.code,
            error: fail.to_string(),
            details: fail.details,
        }
    }
}

/// A failure told before, raised again with its code, details and sentence.
impl From<ErrorBody> for Fail {
    fn from(body: ErrorBody) -> Self {
        Self {
            code: body.code,
            details: body.details,
            said: Some(body.error),
        }
    }
}

/// The item asked for does not exist or is another user's; the two look the same
/// to the caller. The API answers it with 404.
#[derive(Debug)]
pub struct NotFound(pub &'static str);

impl std::fmt::Display for NotFound {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "no such {}", self.0)
    }
}

impl std::error::Error for NotFound {}

/// The code and details of the first failure in `error`'s chain the API knows.
pub fn coded(error: &anyhow::Error) -> Option<Fail> {
    // A `Fail` given as a context is found by anyhow's own downcast only.
    if let Some(fail) = error.downcast_ref::<Fail>() {
        return Some(fail.clone());
    }
    error.chain().find_map(|e| {
        if let Some(fail) = e.downcast_ref::<Fail>() {
            return Some(fail.clone());
        }

        let NotFound(what) = e.downcast_ref::<NotFound>()?;
        Some(Fail::new(Code::NotFound).with("what", what.replace(' ', "_")))
    })
}

/// The body a failure is told with, an answer's or one a status keeps (a
/// download's, a task's): one of the server's own is `internal`, logged, and
/// tells nothing more; one with no code is `fallback`, its `error` what it says.
/// `error` marked as the server's own failure (`Code::Internal`), which [`told`] knows by that code alone; one
/// marked so already is left as it is.
pub fn as_internal(error: anyhow::Error) -> anyhow::Error {
    match coded(&error).is_some_and(|fail| fail.code == Code::Internal) {
        true => error,
        false => error.context(Fail::new(Code::Internal)),
    }
}

pub fn told(error: &anyhow::Error, fallback: Code) -> ErrorBody {
    let coded = coded(error);
    if coded.as_ref().is_some_and(|f| f.code == Code::Internal) {
        tracing::error!("request failed: {error:#}");
        return Fail::new(Code::Internal).into();
    }
    let fail = coded.unwrap_or(Fail::new(fallback));
    ErrorBody {
        code: fail.code,
        error: format!("{error:#}"),
        details: fail.details,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_detail_the_sentence_does_not_name_is_kept_in_its_text() {
        let fail = Fail::new(Code::Internal).with("reason", "no random source");
        assert!(fail.to_string().contains("no random source"), "{fail}");
    }

    #[test]
    fn a_fail_given_as_a_context_answers_with_its_code_and_its_sentence() {
        use anyhow::Context;
        let read: Result<(), std::io::Error> = Err(std::io::Error::other("bad byte"));
        let said = Fail::said(Code::NotReadable, "the file is not valid JSON").with("what", "json");
        let fail = coded(&read.context(said).unwrap_err()).expect("coded");
        assert_eq!(
            (fail.code, fail.to_string()),
            (Code::NotReadable, "the file is not valid JSON".into())
        );
        assert_eq!(fail.details["what"], Detail::from("json"));
    }
}

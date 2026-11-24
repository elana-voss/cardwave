//! What a tool gave, as a typed value (`Gave`): a file's or a page's text,
//! a folder's listing, a file written, a command's run, a refusal or a
//! failure with its code and details. `Gave::for_model` is the one place of
//! the English text the model is given of each; the values stay apart so that
//! what the user is shown can be worded in the app's language. Traps: a cut
//! text keeps its first `limit` characters and `whole`, the count it had,
//! so the limit is the kept text's own count; a failure no area coded is
//! `NotPossible` with `what` `tool_failed` and its chain as `reason`, never
//! made the server's own failure (`cw_core::told`), since the model reads it;
//! an area's `Fail` over an outside error keeps that error's text as `reason`.

use std::time::Duration;

use cw_core::{Code, ErrorBody, Fail, coded};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// What a tool's call gave.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[ts(export)]
pub enum Gave {
    /// The user did not allow the call.
    Refused,
    /// It failed; `error.error` is the English sentence the model reads.
    Failed { error: ErrorBody },
    /// A text: a file's, a page's, a search's results; `whole` the
    /// characters it had where it was cut.
    Text { text: String, whole: Option<usize> },
    /// A folder's files and folders by name, and how many more it holds.
    Listing { entries: Vec<Listed>, more: usize },
    /// A file written: its bytes and its path as the model gave it.
    Wrote { bytes: usize, path: String },
    /// A web search that found nothing.
    NoResults { query: String },
    /// A command run: its exit code, `None` when it was ended after
    /// `seconds`; what it printed; whether it read the drive and was refused.
    Ran {
        code: Option<u32>,
        seconds: u64,
        output: String,
        drive_refused: bool,
    },
}

/// A file or folder of a listing.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Listed {
    pub name: String,
    pub folder: bool,
    /// A file's size; `None` for a folder, or where it could not be read.
    pub bytes: Option<u64>,
}

impl Listed {
    /// Its line in the model's listing, which the listing is sorted by.
    pub fn line(&self) -> String {
        match (self.folder, self.bytes) {
            (true, _) => format!("{}/", self.name),
            (false, Some(bytes)) => format!("{} ({bytes} bytes)", self.name),
            (false, None) => self.name.clone(),
        }
    }
}

impl Gave {
    /// What `result` gave: its value, or its failure.
    pub fn of(result: anyhow::Result<Gave>) -> Gave {
        result.unwrap_or_else(|failure| Gave::Failed {
            error: failed(&failure),
        })
    }

    /// `text` kept to at most `limit` characters.
    pub fn text(text: &str, limit: usize) -> Gave {
        let (text, whole) = kept(text, limit);
        Gave::Text { text, whole }
    }

    /// A command's run, which had at most `time`.
    pub fn ran(ran: cw_sandbox::Ran, time: Duration) -> Gave {
        Gave::Ran {
            code: ran.code,
            seconds: time.as_secs(),
            output: ran.output,
            drive_refused: ran.drive_refused,
        }
    }

    /// Whether the call failed (refused or not done).
    pub fn failed(&self) -> bool {
        matches!(self, Gave::Refused | Gave::Failed { .. })
    }

    /// It as a step's output keeps it: its text, a command's output and a
    /// listing's lines at most `limit` characters, and whether a command's
    /// output was cut. A cut text keeps the count it had; a listing counts
    /// the entries left out with those it had left out.
    pub fn shortened(&self, limit: usize) -> (Gave, bool) {
        match self {
            Gave::Text { text, whole } => {
                let (kept, cut) = kept(text, limit);
                let whole = whole.or(cut);
                (Gave::Text { text: kept, whole }, false)
            }
            Gave::Ran {
                code,
                seconds,
                output,
                drive_refused,
            } => {
                let (output, cut) = kept(output, limit);
                let ran = Gave::Ran {
                    code: *code,
                    seconds: *seconds,
                    output,
                    drive_refused: *drive_refused,
                };
                (ran, cut.is_some())
            }
            Gave::Listing { entries, more } => {
                let mut room = limit;
                let shown: Vec<Listed> = entries
                    .iter()
                    .take_while(|entry| {
                        let length = entry.line().chars().count() + 1;
                        let fits = length <= room;
                        room = room.saturating_sub(length);
                        fits
                    })
                    .cloned()
                    .collect();
                let more = more + entries.len() - shown.len();
                (
                    Gave::Listing {
                        entries: shown,
                        more,
                    },
                    false,
                )
            }
            gave => (gave.clone(), false),
        }
    }

    /// The text the model is given of it.
    pub fn for_model(&self) -> String {
        match self {
            Gave::Refused => crate::tools::REFUSED.to_string(),
            Gave::Failed { error } => format!("Failed: {}", error.error),
            Gave::Text { text, whole: None } => text.clone(),
            Gave::Text {
                text,
                whole: Some(whole),
            } => format!(
                "{text}\n… (cut at {} characters of {whole})",
                text.chars().count()
            ),
            Gave::Listing { entries, more } => listing(entries, *more),
            Gave::Wrote { bytes, path } => format!("Wrote {bytes} bytes to {path}."),
            Gave::NoResults { query } => format!("No results for {query:?}."),
            Gave::Ran {
                code,
                seconds,
                output,
                drive_refused,
            } => {
                let drive = if *drive_refused {
                    cw_sandbox::DRIVE_REFUSED
                } else {
                    ""
                };
                match code {
                    Some(code) => format!("Exit code {code}.\n{output}{drive}"),
                    None => format!("Stopped after {seconds} s.\n{output}{drive}"),
                }
            }
        }
    }
}

/// `text`'s first `limit` characters, and the characters it had where it had
/// more.
pub fn kept(text: &str, limit: usize) -> (String, Option<usize>) {
    match text.char_indices().nth(limit) {
        Some((at, _)) => (text[..at].to_string(), Some(text.chars().count())),
        None => (text.to_string(), None),
    }
}

/// A listing as the model reads it: a line per entry, a folder with `/`.
fn listing(entries: &[Listed], more: usize) -> String {
    if entries.is_empty() {
        return "The folder is empty.".into();
    }
    let mut lines: Vec<String> = entries.iter().map(Listed::line).collect();
    if more > 0 {
        lines.push(format!("[{more} more]"));
    }
    lines.join("\n")
}

/// The body `failure` is told with: its code and details where an area gave
/// them, else `tool_failed`; its whole chain as the sentence. Where an area's
/// `Fail` stands over an outside error (an OS error, the web's), that error's
/// own text is its `reason`, so the page can say it.
fn failed(failure: &anyhow::Error) -> ErrorBody {
    let said = format!("{failure:#}");
    let fail = match coded(failure) {
        Some(fail) if !fail.details.contains_key("reason") => match cause_below(failure) {
            Some(cause) => fail.with("reason", cause),
            None => fail,
        },
        Some(fail) => fail,
        None => Fail::new(Code::NotPossible)
            .with("what", "tool_failed")
            .with("reason", said.clone()),
    };
    ErrorBody {
        code: fail.code,
        error: said,
        details: fail.details,
    }
}

/// The text of what `failure`'s first `Fail` stands over, its chain joined as
/// `{:#}` joins it; none where nothing is below it. A `Fail` given as the
/// outer context is found by anyhow's downcast only (its link in the chain is
/// anyhow's own type), as in `cw_core::coded`.
fn cause_below(failure: &anyhow::Error) -> Option<String> {
    let at = match failure.downcast_ref::<Fail>() {
        Some(_) => 0,
        None => failure.chain().position(|error| error.is::<Fail>())?,
    };
    let below: Vec<String> = failure
        .chain()
        .skip(at + 1)
        .map(ToString::to_string)
        .collect();
    (!below.is_empty()).then(|| below.join(": "))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_failure_keeps_its_code_the_cause_below_it_and_the_model_its_sentence() {
        let folder = std::env::temp_dir();
        let gave = Gave::of(crate::tools::files::read(&folder, "no-such-file.txt"));
        let Gave::Failed { error } = &gave else {
            panic!("{gave:?}")
        };
        let cause = std::fs::File::open(folder.join("no-such-file.txt")).unwrap_err();
        assert_eq!(
            (
                error.code,
                error.details.get("what").map(ToString::to_string),
                error.details.get("reason").map(ToString::to_string)
            ),
            (
                Code::NotReadable,
                Some("file".to_string()),
                Some(cause.to_string())
            )
        );
        assert!(
            gave.for_model()
                .starts_with("Failed: there is no such file"),
            "{}",
            gave.for_model()
        );
    }

    #[test]
    fn a_failure_no_area_coded_is_a_tool_failed_with_its_reason() {
        let gave = Gave::of(Err(anyhow::anyhow!("the disk is full")));
        let Gave::Failed { error } = &gave else {
            panic!("{gave:?}")
        };
        assert_eq!(
            (
                error.code,
                error.details.get("reason").map(ToString::to_string)
            ),
            (Code::NotPossible, Some("the disk is full".to_string()))
        );
        assert_eq!(gave.for_model(), "Failed: the disk is full");
    }

    #[test]
    fn a_command_refused_the_drive_is_told_how_to_list_after_its_output() {
        let ran = cw_sandbox::Ran {
            output: "Access is denied.".into(),
            code: Some(1),
            drive_refused: true,
        };
        assert_eq!(
            Gave::ran(ran, Duration::from_secs(60)).for_model(),
            format!(
                "Exit code 1.\nAccess is denied.{}",
                cw_sandbox::DRIVE_REFUSED
            )
        );
    }

    #[test]
    fn the_output_keeps_a_text_a_command_and_a_listing_to_its_limit() {
        let text = Gave::Text {
            text: "abcdef".into(),
            whole: None,
        };
        let ran = Gave::Ran {
            code: Some(0),
            seconds: 1,
            output: "abcdef".into(),
            drive_refused: false,
        };
        let listing = Gave::Listing {
            entries: ["a", "b", "c"]
                .map(|name| Listed {
                    name: name.into(),
                    folder: true,
                    bytes: None,
                })
                .to_vec(),
            more: 1,
        };
        let short = |gave: &Gave| gave.shortened(4);
        assert_eq!(
            [short(&text), short(&ran), short(&listing)],
            [
                (
                    Gave::Text {
                        text: "abcd".into(),
                        whole: Some(6)
                    },
                    false
                ),
                (
                    Gave::Ran {
                        code: Some(0),
                        seconds: 1,
                        output: "abcd".into(),
                        drive_refused: false
                    },
                    true
                ),
                (
                    Gave::Listing {
                        entries: listing_of(&["a"]),
                        more: 3
                    },
                    false
                ),
            ]
        );
    }

    fn listing_of(names: &[&str]) -> Vec<Listed> {
        names
            .iter()
            .map(|name| Listed {
                name: name.to_string(),
                folder: true,
                bytes: None,
            })
            .collect()
    }

    #[test]
    fn a_listing_reads_as_before() {
        let entries = vec![
            Listed {
                name: "notes".into(),
                folder: true,
                bytes: None,
            },
            Listed {
                name: "a.txt".into(),
                folder: false,
                bytes: Some(5),
            },
        ];
        assert_eq!(listing(&entries, 2), "notes/\na.txt (5 bytes)\n[2 more]");
        assert_eq!(listing(&[], 0), "The folder is empty.");
    }
}

//! What a user has chosen for the app as a whole. Kept as one JSON text with
//! the user, so a choice added later needs no schema step: what is not in the
//! text has its default. "Language the AI writes in" (`language`) is this
//! computer's at first (`languages::of_computer`) and only a code the app knows;
//! "Language of the app" (`app_language`) is none at first, the page then
//! following the computer's, and the AI's follows it until changed itself
//! (`language_chosen`, which the page cannot set).

use std::path::{Path, PathBuf};

use anyhow::ensure;
use cw_core::NotFound;
use cw_core::{Code, Fail};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::cards::ExportFormat;
use crate::interview::Style;

/// What a chat without a character is told at first, its macros filled in at
/// each reply.
pub const PLAIN_PROMPT: &str = "You are a helpful, honest assistant. It is now {{date}}, {{time}}.";

/// Refuses a folder the model's tools may not work in: one that is not there,
/// a drive's root, or one that holds Cardwave's data folder `data` or is in
/// it (the owner, 2026-10-15).
pub fn folder_checked(folder: &str, data: &Path) -> anyhow::Result<()> {
    let path = folder_there(folder, Code::DriveRootForModel)?;
    let data = data.canonicalize()?;
    ensure!(
        !data.starts_with(&path) && !path.starts_with(&data),
        Fail::new(Code::DataFolder)
    );
    Ok(())
}

/// The folder `folder` as it is on disk, refused where it is not there or is a
/// drive's root (`root`, the code that says why that one is refused).
pub fn folder_there(folder: &str, root: Code) -> anyhow::Result<PathBuf> {
    let path = Path::new(folder);
    ensure!(
        path.is_absolute() && path.is_dir(),
        Fail::new(Code::NoSuchFolder).with("folder", folder.to_string())
    );
    let path = path.canonicalize()?;
    ensure!(path.parent().is_some(), Fail::new(root));
    Ok(path)
}

/// The speeds a message is read aloud at, in hundredths: 0.5× to 2×.
pub(crate) const VOICE_SPEEDS: std::ops::RangeInclusive<u16> = 50..=200;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct Settings {
    /// The file format "Export" writes a card in.
    pub export_format: ExportFormat,
    /// Whether a card exported as CCV4 keeps its texts' earlier drafts.
    pub export_history: bool,
    /// Whether the worker model describes each card imported (`describe`).
    pub describe_imported: bool,
    /// How "Make a character together" asks its questions (a temporary line).
    pub interview_style: Style,
    /// Whether a picture in a message from another address than Cardwave's
    /// own shows; off, as its server learns the chat was opened.
    pub web_pictures: bool,
    /// Whether the desktop app looks for a newer version by itself, at start
    /// and once a day; on at first.
    pub check_updates: bool,
    /// The voice a message is read aloud in (`voice::own`), where one was chosen.
    pub voice: Option<String>,
    /// How fast messages are read aloud, in hundredths of the speed spoken:
    /// `VOICE_SPEEDS`, 100 at first.
    pub voice_speed: u16,
    /// The tools the chat model may call (`tools`).
    pub tools: Tools,
    /// The coding team's (`coding`).
    pub coding: CodingTeam,
    /// The companion of the desktop app.
    pub companion: Companion,
    /// The folder of cards, this computer's account's alone (`api/card_folder.rs`).
    pub card_folder: CardFolder,
    /// The one text a chat without a character is told (`chats::plain_inputs`).
    pub plain_prompt: String,
    /// The language the AI writes in, by its code: a chat uses a card in it
    /// where the card has it (`Document::in_language`). This computer's at first.
    pub language: String,
    /// Whether `language` was chosen itself; until then it follows `app_language`.
    pub language_chosen: bool,
    /// The language of the app's screens, by its file's code ("pt-BR"); none
    /// while the user has not chosen one, the page then following the computer.
    pub app_language: Option<String>,
    /// First run's downloads chosen (the search model, the voice) while they
    /// are not through yet: the app then starts at first run's step 4. Empty
    /// once they are, or where none was chosen.
    pub setup_downloads: Vec<SetupDownload>,
    /// The user's own CSS, put after the app's stylesheet: empty for none.
    pub own_css: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            export_format: ExportFormat::default(),
            export_history: false,
            describe_imported: false,
            interview_style: Style::Tree,
            web_pictures: false,
            check_updates: true,
            voice: None,
            voice_speed: 100,
            tools: Tools::default(),
            coding: CodingTeam::default(),
            companion: Companion::default(),
            card_folder: CardFolder::default(),
            plain_prompt: PLAIN_PROMPT.to_string(),
            language: cw_core::languages::of_computer().to_string(),
            language_chosen: false,
            app_language: None,
            setup_downloads: Vec::new(),
            own_css: String::new(),
        }
    }
}

/// A download first run makes, where it was chosen in its step 2.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum SetupDownload {
    Voice,
    Search,
}

/// The companion of the desktop app: the card whose first character it is,
/// whether it starts with the app, the day it shows again after "Hide
/// until tomorrow" (the window's own day, as `2026-10-16`), the figure
/// it shows where the card has none (`figure`, picked at first run or in
/// Settings), the figure's height in percent of the screen's work area
/// (`size`, `COMPANION_SIZES`, at first 21: the 260 px window of before on
/// a work area 752 px high), and whether its compact chat's replies are not
/// read aloud (`muted`, by the speaker in its head; read aloud at first).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct Companion {
    pub card_id: Option<i64>,
    pub starts: bool,
    pub(crate) hidden_until: Option<String>,
    pub figure: BaseFigure,
    pub size: u8,
    pub muted: bool,
}

/// The companion figure's heights the slider in Settings offers, in percent
/// of the screen's work area.
pub const COMPANION_SIZES: std::ops::RangeInclusive<u8> = 10..=50;

impl Default for Companion {
    fn default() -> Self {
        Self {
            card_id: None,
            starts: false,
            hidden_until: None,
            figure: BaseFigure::default(),
            size: 21,
            muted: false,
        }
    }
}

/// The companion's figure where its card has none: the app's woman or man
/// (Mixamo's, tools/companion_assets.py), or the robot, which has no human skeleton.
/// The woman at first (the owner, 2026-10-27: "for your dev work we use the
/// female figure").
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum BaseFigure {
    #[default]
    Woman,
    Man,
    Robot,
}

/// Settings › Data's folder of cards: the folder, whether a card file put in it is imported by itself
/// (`watch`, on at first: Claude), and whether a file imported from a folder goes to the Recycle Bin then
/// (`recycle`, off at first: the owner, 2026-10-24).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct CardFolder {
    pub folder: Option<String>,
    pub watch: bool,
    pub recycle: bool,
}

impl Default for CardFolder {
    fn default() -> Self {
        Self {
            folder: None,
            watch: true,
            recycle: false,
        }
    }
}

/// The tools the chat model may call, each switched on by the user, and what
/// it may do without asking. Files and commands work in `folder` and are this
/// computer's account's alone.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct Tools {
    /// Search the web and read its pages.
    pub web: bool,
    /// List, read and write the files of `folder`.
    pub files: bool,
    /// A file is written only once the user allows it in the chat.
    pub ask_writes: bool,
    /// Run commands in `folder`, in the sandbox.
    pub commands: bool,
    /// A command runs only once the user allows it in the chat.
    pub ask_commands: bool,
    /// Make pictures with the image model.
    pub pictures: bool,
    /// A tool the model wrote is kept only once the user allows it in the chat.
    pub ask_new_tools: bool,
    /// Cardwave itself, a tool per route of its API (`tools::app`): in a chat
    /// without a character and in Assistant and Companion mode, and over MCP.
    pub app: bool,
    /// Dice the model rolls (`tools::dice`), off until switched on (the owner, 2026-10-23).
    pub dice: bool,
    /// The folder of files and commands, as the user gave it.
    pub folder: Option<String>,
}

impl Default for Tools {
    fn default() -> Self {
        Self {
            web: false,
            files: false,
            ask_writes: true,
            commands: false,
            ask_commands: true,
            pictures: false,
            ask_new_tools: true,
            app: false,
            dice: false,
            folder: None,
        }
    }
}

/// The coding team (`coding`): the team a task is given unless it names
/// another, and the models of its roles. What its tools may do is the
/// account's Settings › Tools (`Permissions::of`; second review of the v4
/// boards, 2026-10-17).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(default)]
#[ts(export)]
pub struct CodingTeam {
    pub team: Team,
    /// The models of the roles, at the stored provider. None: the planner and
    /// the auditor have the chat model, the workers the background model.
    pub planner_model: Option<String>,
    pub worker_model: Option<String>,
    pub auditor_model: Option<String>,
    /// How many workers the team Custom has, 1 to 3.
    pub workers: u8,
    /// When the team Custom's auditor checks.
    pub audit: Audit,
}

impl Default for CodingTeam {
    fn default() -> Self {
        Self {
            team: Team::Balanced,
            planner_model: None,
            worker_model: None,
            auditor_model: None,
            workers: 2,
            audit: Audit::End,
        }
    }
}

impl CodingTeam {
    /// How many workers `team` has, and when its auditor checks.
    pub fn shape(&self, team: Team) -> (u8, Audit) {
        match team {
            Team::Quick => (1, Audit::Never),
            Team::Balanced => (2, Audit::End),
            Team::Thorough => (3, Audit::EachStep),
            Team::Custom => (self.workers.clamp(1, 3), self.audit),
        }
    }
}

/// The ready-made teams, and the user's own.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Team {
    Quick,
    #[default]
    Balanced,
    Thorough,
    Custom,
}

/// When the auditor checks the workers' changes and runs the tests.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Audit {
    Never,
    #[default]
    End,
    EachStep,
}

/// What a coding team's tool may do: run, ask the user first, or nothing
/// (it is not offered).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Permit {
    Allow,
    Ask,
    Never,
}

/// A coding team's tools, each with what it may do, as the account's tools
/// were when the task began.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Permissions {
    /// Read files in the task's folder.
    pub read: Permit,
    /// Write files in the task's folder.
    pub write: Permit,
    /// Run commands in the folder, in the sandbox without network.
    pub commands: Permit,
    /// Install packages: a command in the sandbox with network.
    pub install: Permit,
    /// Search the web and read its pages.
    pub web: Permit,
}

impl Permissions {
    /// What Settings › Tools allow: Files reads and writes, asking first
    /// where "Ask before writing" is on; Commands runs commands and installs
    /// packages, asking first where "Ask before running" is on; Web searches
    /// and reads pages. What is switched off is not offered.
    pub fn of(tools: &Tools) -> Self {
        let permit = |on: bool, ask: bool| match (on, ask) {
            (false, _) => Permit::Never,
            (true, true) => Permit::Ask,
            (true, false) => Permit::Allow,
        };
        let commands = permit(tools.commands, tools.ask_commands);
        Self {
            read: permit(tools.files, false),
            write: permit(tools.files, tools.ask_writes),
            commands,
            install: commands,
            web: permit(tools.web, false),
        }
    }
}

/// Changes to the tools; what is left out stays as it is.
#[derive(Clone, Default, Serialize, Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeTools {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub web: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub files: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ask_writes: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub commands: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ask_commands: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pictures: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub code: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ask_new_tools: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dice: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub folder: Option<String>,
}

/// Changes to the folder of cards; what is left out stays as it is.
#[derive(Clone, Default, Serialize, Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeCardFolder {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub folder: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub watch: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub recycle: Option<bool>,
}

/// Changes to the settings; what is left out stays as it is.
#[derive(Clone, Default, Serialize, Deserialize, TS)]
#[ts(export, optional_fields)]
pub struct ChangeSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub export_format: Option<ExportFormat>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub export_history: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub describe_imported: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub interview_style: Option<Style>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub web_pictures: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub check_updates: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub voice: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub voice_speed: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tools: Option<ChangeTools>,
    /// The coding team as a whole, in place of the one kept.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub coding: Option<CodingTeam>,
    /// The companion as a whole, in place of the one kept.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub companion: Option<Companion>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub card_folder: Option<ChangeCardFolder>,
    /// The text a chat without a character is told, in place of the one kept.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub plain_prompt: Option<String>,
    /// The language the AI writes in, one the app names (`languages::all`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    /// Set by `change` alone, with `language`.
    #[serde(skip_serializing_if = "Option::is_none", skip_deserializing)]
    #[ts(skip)]
    pub language_chosen: Option<bool>,
    /// The language of the app's screens, one the app names (`languages::all`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app_language: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub setup_downloads: Option<Vec<SetupDownload>>,
    /// The user's own CSS, in place of the one kept.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub own_css: Option<String>,
}

/// What the settings need of the database, which `cw_store::settings` gives.
pub trait Storage: cw_voice::own::Storage {
    /// The user's settings as kept, where the user is there.
    fn settings_text(&self, user: i64) -> anyhow::Result<Option<String>>;
    /// Merges `changes` (JSON) into them and returns them as they are then.
    fn patch_settings(&self, user: i64, changes: &str) -> anyhow::Result<Option<String>>;
}

/// Settings as kept. A text this build cannot read (a newer one wrote it)
/// counts as no choice made.
fn read(text: Option<String>) -> Option<Settings> {
    text.map(|text| serde_json::from_str(&text).unwrap_or_default())
}

pub fn get(db: &dyn Storage, user: i64) -> anyhow::Result<Settings> {
    Ok(read(db.settings_text(user)?).ok_or(NotFound("user"))?)
}

/// What `{{user}}` stands for without a persona: the stand-in name in the
/// app's language, the computer's while none is chosen, as the page follows it
/// (its whole locale, which tells Chinese's script by its region).
pub fn user_stand_in(db: &dyn Storage, user: i64) -> anyhow::Result<&'static str> {
    let language = get(db, user)?
        .app_language
        .unwrap_or_else(cw_core::languages::computer_locale);
    Ok(cw_prompt::stand_in_user(&language))
}

/// Makes the changes and returns the settings as they are then. Only what is
/// changed is written: what a newer build keeps in the text stays in it.
pub fn change(db: &dyn Storage, user: i64, change: &ChangeSettings) -> anyhow::Result<Settings> {
    if let Some(speed) = change.voice_speed {
        anyhow::ensure!(
            VOICE_SPEEDS.contains(&speed),
            Fail::said(
                Code::OutOfRange,
                format!(
                    "the speed is from {} to {} hundredths",
                    VOICE_SPEEDS.start(),
                    VOICE_SPEEDS.end()
                )
            )
            .with("what", "voice_speed")
            .with("start", (VOICE_SPEEDS.start()).to_string())
            .with("end", (VOICE_SPEEDS.end()).to_string())
        );
    }
    if let Some(companion) = &change.companion {
        let sizes = COMPANION_SIZES;
        anyhow::ensure!(
            sizes.contains(&companion.size),
            Fail::said(
                Code::OutOfRange,
                format!(
                    "the size is from {} to {} percent",
                    sizes.start(),
                    sizes.end()
                )
            )
            .with("what", "companion_size")
            .with("start", sizes.start().to_string())
            .with("end", sizes.end().to_string())
        );
    }
    if let Some(voice) = &change.voice {
        cw_voice::own::known(db, user, voice)?;
    }
    if let Some(language) = &change.language {
        anyhow::ensure!(
            cw_core::languages::known(language) == Some(language.as_str()),
            Fail::said(
                Code::NotPossible,
                format!("{language:?} is no language this app knows")
            )
            .with("what", "unknown_language")
        );
    }
    let mut follows = None;
    if let Some(app) = &change.app_language {
        let code = cw_core::languages::known(app);
        anyhow::ensure!(
            code.is_some(),
            Fail::said(
                Code::NotPossible,
                format!("{app:?} is no language this app knows")
            )
            .with("what", "unknown_language")
        );
        if change.language.is_none() && !get(db, user)?.language_chosen {
            follows = code.map(str::to_string);
        }
    }
    let changes = serde_json::to_string(&ChangeSettings {
        language: change.language.clone().or(follows),
        language_chosen: change.language.as_ref().map(|_| true),
        ..change.clone()
    })?;
    Ok(read(db.patch_settings(user, &changes)?).ok_or(NotFound("user"))?)
}

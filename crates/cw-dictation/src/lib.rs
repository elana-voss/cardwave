//! Dictation: what is said into the message field, heard on this computer by
//! Whisper large-v3-turbo (OpenAI, MIT; whisper.cpp's GGML file, q5_0),
//! which whisper.cpp runs inside the server on the graphics card alone
//! (cw-whisper). The trial measured 0.2 s for a sentence and 0.9 GB of the
//! card (`..\cardwave-next-stttest`, "Vulkan"). Its file is downloaded when
//! asked, into the data folder's `models/dictation`, as the voice's are
//! (`cw_modelfiles::download`); the model names the language itself.
//!
//! [`samples`] takes the page's WAV (16 kHz, one channel, 16-bit) and
//! refuses any other. A [`Model`] is either Whisper or the tests' stand-in,
//! which hears the words it was given; both block, so the server's
//! `api/dictation.rs`, its HTTP, runs them on a blocking thread.

use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{bail, ensure};
use cw_core::{Code, Fail};
use cw_modelfiles::ModelFile;
use cw_modelfiles::Part;
use cw_whisper::whisper::Whisper;

/// The model's name, as the app shows it.
pub const MODEL: &str = "Whisper large-v3-turbo";
/// The model's file in the model's folder.
const WEIGHTS: &str = "ggml-large-v3-turbo-q5_0.bin";
/// The revision of `ggerganov/whisper.cpp` on Hugging Face the file is taken from.
const REVISION: &str = "5359861c739e955e79d9a303bcbc70fb988958b1";
/// The rate of the sound Whisper hears, a second.
const RATE: u32 = 16_000;

/// What hears: Whisper, or the tests' stand-in, which loads in `loading` and says `says` after `slow`.
#[derive(Clone, Debug)]
pub(crate) enum Ears {
    Whisper,
    StandIn {
        says: String,
        slow: Duration,
        loading: Duration,
    },
}

/// Where the model comes from and what hears.
#[derive(Clone, Debug)]
pub struct Setup {
    /// The model's file, alone.
    pub parts: Vec<Part>,
    pub(crate) ears: Ears,
}

impl Setup {
    /// Whisper large-v3-turbo q5_0, as the trial measured it.
    pub fn turbo() -> Self {
        Self {
            parts: vec![Part {
                file: ModelFile {
                    url: format!(
                        "https://huggingface.co/ggerganov/whisper.cpp/resolve/{REVISION}/{WEIGHTS}"
                    ),
                    size: 574_041_195,
                    sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2"
                        .into(),
                },
                path: WEIGHTS.into(),
                unpack: None,
            }],
            ears: Ears::Whisper,
        }
    }

    /// The tests' stand-in: `file` downloaded as the model, hearing `says` after `slow`.
    pub fn stand_in(file: ModelFile, says: &str, slow: Duration) -> Self {
        Self {
            parts: vec![Part {
                file,
                path: WEIGHTS.into(),
                unpack: None,
            }],
            ears: Ears::StandIn {
                says: says.into(),
                slow,
                loading: Duration::ZERO,
            },
        }
    }

    /// The stand-in taking `time` to load.
    pub fn loading(mut self, time: Duration) -> Self {
        if let Ears::StandIn { loading, .. } = &mut self.ears {
            *loading = time;
        }
        self
    }
}

/// Where the model's file is kept in the data folder.
pub fn folder(data_dir: &Path) -> PathBuf {
    data_dir.join("models").join("dictation")
}

/// The model while it is loaded.
pub enum Model {
    Whisper(Whisper),
    StandIn { says: String, slow: Duration },
}

impl Model {
    /// Loads the model of `setup` from `folder` on the graphics card; blocks.
    pub fn load(setup: &Setup, folder: &Path) -> anyhow::Result<Self> {
        Ok(match &setup.ears {
            Ears::Whisper => Self::Whisper(Whisper::load(&folder.join(WEIGHTS))?),
            Ears::StandIn {
                says,
                slow,
                loading,
            } => {
                std::thread::sleep(*loading);
                Self::StandIn {
                    says: says.clone(),
                    slow: *slow,
                }
            }
        })
    }

    /// The words said in `samples` ([`samples`]); blocks.
    pub fn hear(&mut self, samples: &[f32]) -> anyhow::Result<String> {
        match self {
            Self::Whisper(whisper) => whisper.hear(samples),
            Self::StandIn { says, slow } => {
                std::thread::sleep(*slow);
                Ok(says.clone())
            }
        }
    }
}

/// The sound of `wav`, a WAV file of 16-bit PCM in one channel at 16 kHz, as
/// numbers from -1 to 1; any other file is refused.
pub fn samples(wav: &[u8]) -> anyhow::Result<Vec<f32>> {
    let not = "the recording is not a WAV file of 16-bit sound in one channel at 16 kHz";
    ensure!(
        wav.len() >= 12 && &wav[..4] == b"RIFF" && &wav[8..12] == b"WAVE",
        Fail::said(Code::NotReadable, not).with("what", "dictation_recording")
    );
    let mut rest = &wav[12..];
    let mut format_ok = false;
    while rest.len() >= 8 {
        let (id, size) = (
            &rest[..4],
            u32::from_le_bytes(rest[4..8].try_into()?) as usize,
        );
        let body = &rest[8..rest.len().min(8 + size)];
        match id {
            b"fmt " => {
                ensure!(
                    body.len() >= 16,
                    Fail::said(Code::NotReadable, not).with("what", "dictation_recording")
                );
                let number = |at: usize, len: usize| {
                    body[at..at + len]
                        .iter()
                        .rev()
                        .fold(0u32, |sum, byte| (sum << 8) | u32::from(*byte))
                };
                // PCM, one channel, the rate, 16 bits.
                format_ok = number(0, 2) == 1
                    && number(2, 2) == 1
                    && number(4, 4) == RATE
                    && number(14, 2) == 16;
                ensure!(
                    format_ok,
                    Fail::said(Code::NotReadable, not).with("what", "dictation_recording")
                );
            }
            b"data" => {
                ensure!(
                    format_ok,
                    Fail::said(Code::NotReadable, not).with("what", "dictation_recording")
                );
                return Ok(body
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|pair| f32::from(i16::from_le_bytes(*pair)) / 32_768.0)
                    .collect());
            }
            _ => {}
        }
        // A chunk of odd size is followed by a byte of padding.
        rest = &rest[(8 + size + size % 2).min(rest.len())..];
    }
    bail!(Fail::said(Code::NotReadable, not).with("what", "dictation_recording"))
}

//! Voice: a message read aloud by Pocket TTS (Kyutai, CC BY 4.0), as the ONNX
//! export `KevinAHM/pocket-tts-onnx` run by ONNX Runtime (`pocket.rs`).
//!
//! Downloaded when asked (`Setup::pocket`, `download`), each file checked by size
//! and SHA-256, into the data folder's `models/voice`: ONNX Runtime's library
//! (`RUNTIME`), the English model (`ENGLISH`) and the recordings of `VOICES`
//! (Kyutai's `tts-voices`, CC0 or CC BY only); a cancelled download goes on
//! where it stopped. The native speakers' voices (`NATIVE`) are inside the
//! program (`voices/`, `tools/voices.py`). Other languages are packs
//! (`languages.rs`); a voice from the user's recording is `own.rs`; a reading is
//! sped by `Stretch`; a provider's voice is `at.rs`, its model's name
//! `cw_provider::kinds`'.
//!
//! Sound is mono at `RATE`, -1 to 1. In the tests `Speaker::Tone` stands in for
//! the model: a short tone for each word.

pub mod at;
mod languages;
pub mod own;
mod pieces;
mod pocket;
mod stretch;

pub use languages::LANGUAGES;
pub use stretch::Stretch;

use std::path::{Path, PathBuf};

use anyhow::{bail, ensure};
use cw_core::{Code, Fail};
use cw_modelfiles::ModelFile;

pub use cw_modelfiles::{Part, download, ready_in, size_of};

/// Samples a second, of the sound made and of a voice's recording as the model takes it.
pub const RATE: u32 = 24_000;

/// A voice to choose: its recording, and what Settings › Voices and "About
/// Cardwave" say of it.
pub struct Voice {
    pub id: &'static str,
    pub name: &'static str,
    pub set: &'static str,
    pub license: &'static str,
    /// The language its speaker speaks, as the page says it.
    pub language: &'static str,
    recording: Recording,
}

/// Where a voice's recording comes from.
enum Recording {
    /// Downloaded with the model: `file` in Kyutai's `tts-voices`, of `size`
    /// bytes, checked by `sha256`.
    Fetched {
        file: &'static str,
        size: u64,
        sha256: &'static str,
    },
    /// Inside the program: CML-TTS's speaker `speaker`'s WAV file.
    Shipped {
        speaker: &'static str,
        wav: &'static [u8],
    },
}

const CC0: &str = "CC0";
const CC_BY: &str = "CC BY 4.0";

/// Pocket TTS's own English voices whose sets are CC0 or CC BY 4.0, by its
/// names (`pocket_tts/utils/utils.py`), the first the one used until another
/// is chosen. Left out: "cosette" (Expresso) and "jean" (EARS), which are for
/// no commercial use.
pub(crate) const VOICES: &[Voice] = &[
    voice(
        "alba",
        "Alba",
        "Alba MacKenna",
        CC_BY,
        "alba-mackenna/casual.wav",
        958_542,
        "46264e83cb99115c3d210260e029117566d9c64f20266d10daa78107759ede3e",
    ),
    voice(
        "marius",
        "Marius",
        "Voice donations",
        CC0,
        "voice-donations/Selfie.wav",
        480_044,
        "076968c3122520f3412eb7090e8c1c3f75fe57be1e24a2f96465583d84c71e16",
    ),
    voice(
        "javert",
        "Javert",
        "Voice donations",
        CC0,
        "voice-donations/Butter.wav",
        480_044,
        "b889e080eec3efa824bddaf875b4f531d75464f88128d08941ae648d9d3ade70",
    ),
    voice(
        "anna",
        "Anna",
        "VCTK",
        CC_BY,
        "vctk/p228_023_enhanced.wav",
        804_630,
        "0a6de25cf12bf1540beb85979f306a92be81fecc051c547c5395e7e5237a3856",
    ),
    voice(
        "vera",
        "Vera",
        "VCTK",
        CC_BY,
        "vctk/p229_023_enhanced.wav",
        691_416,
        "309cf91a895830f15842b398f69a4962cb1f7e0bfab10e25dd27838e826c204b",
    ),
    voice(
        "fantine",
        "Fantine",
        "VCTK",
        CC_BY,
        "vctk/p244_023_enhanced.wav",
        674_852,
        "5f07d4e2a3f20a15572aae885156b43ef3fc12ef3812996fd135680d9956448b",
    ),
    voice(
        "charles",
        "Charles",
        "VCTK",
        CC_BY,
        "vctk/p254_023_enhanced.wav",
        639_272,
        "6b681a429198f16e378d53bccb08d06939da7b00144a7696111d4f8f76be7756",
    ),
    voice(
        "paul",
        "Paul",
        "VCTK",
        CC_BY,
        "vctk/p259_023_enhanced.wav",
        717_182,
        "7aba504fe0b3b16478b69eb27ce6007e3cb42b0c1915b5f1c6a6024ae37d679b",
    ),
    voice(
        "eponine",
        "Eponine",
        "VCTK",
        CC_BY,
        "vctk/p262_023_enhanced.wav",
        716_330,
        "a13c27fb47627b05223691a0ef2974358a18c886e6c2f9d2762ff1d02c20926b",
    ),
    voice(
        "azelma",
        "Azelma",
        "VCTK",
        CC_BY,
        "vctk/p303_023_enhanced.wav",
        823_852,
        "60e3d26cdf2efdec5df712152c839928f4d5522821e6554ae11fd96c57ab1026",
    ),
    voice(
        "george",
        "George",
        "VCTK",
        CC_BY,
        "vctk/p315_023_enhanced.wav",
        642_692,
        "29a41f93bf5236e5b21501091d7774c255d5f3d4e62fa4f9fdf0a92a793c84ae",
    ),
    voice(
        "mary",
        "Mary",
        "VCTK",
        CC_BY,
        "vctk/p333_023_enhanced.wav",
        639_084,
        "a35b0468382218e9f37a9a7494d1e4b74deaf18d7ced22265b4e325bb55c183f",
    ),
    voice(
        "jane",
        "Jane",
        "VCTK",
        CC_BY,
        "vctk/p339_023_enhanced.wav",
        759_340,
        "2f12e7f155eb3118f55425394f1b049e5b1b67bdc9b3932c8ba4521420aeb84a",
    ),
    voice(
        "michael",
        "Michael",
        "VCTK",
        CC_BY,
        "vctk/p360_023_enhanced.wav",
        751_140,
        "b6743e9195e5e3fd34fe9d1633ae93f7ffab787b249e45f6467d7d6f7a6ee6ad",
    ),
    voice(
        "eve",
        "Eve",
        "VCTK",
        CC_BY,
        "vctk/p361_023_enhanced.wav",
        671_872,
        "396e7cbd066b0f3fb6d67fa26e7904076958239d736d4390f15b5fe88feb14cd",
    ),
    voice(
        "bill_boerst",
        "Bill Boerst",
        "Voice-Zero",
        CC0,
        "voice-zero/bill_boerst.wav",
        955_496,
        "be4815e4fb760ba1b78117545a260cce4a4c124c7657bc5c6127a0fef8ba661f",
    ),
    voice(
        "peter_yearsley",
        "Peter Yearsley",
        "Voice-Zero",
        CC0,
        "voice-zero/peter_yearsley.wav",
        524_448,
        "fbb3920fda7ae26a5a8b317ffcae1d55c0bd5d89d075205f5a52b1e924b83f51",
    ),
    voice(
        "stuart_bell",
        "Stuart Bell",
        "Voice-Zero",
        CC0,
        "voice-zero/stuart_bell.wav",
        745_776,
        "00c7baeb2fb7a8c1c6198e045b5e853a7ccc04002a51a09b4be3dd7c96994f73",
    ),
    voice(
        "caro_davy",
        "Caro Davy",
        "Voice-Zero",
        CC0,
        "voice-zero/caro_davy.wav",
        743_528,
        "40c692c005a0268a7a5b6ebae348077d3dca6a86eb6b12bd36e343bbcd71b5f6",
    ),
];

/// Native speakers' voices, of CML-TTS (CC BY 4.0), a lower and a higher
/// one per language, by names Claude gave them (`tools/voices.py`).
pub const NATIVE: &[Voice] = &[
    native(
        "lena",
        "Lena",
        "German",
        "3277",
        include_bytes!("../voices/lena.wav"),
    ),
    native(
        "jonas",
        "Jonas",
        "German",
        "138",
        include_bytes!("../voices/jonas.wav"),
    ),
    native(
        "giulia",
        "Giulia",
        "Italian",
        "11247",
        include_bytes!("../voices/giulia.wav"),
    ),
    native(
        "marco",
        "Marco",
        "Italian",
        "642",
        include_bytes!("../voices/marco.wav"),
    ),
    native(
        "beatriz",
        "Beatriz",
        "Portuguese",
        "9056",
        include_bytes!("../voices/beatriz.wav"),
    ),
    native(
        "tiago",
        "Tiago",
        "Portuguese",
        "5417",
        include_bytes!("../voices/tiago.wav"),
    ),
    native(
        "lucia",
        "Lucía",
        "Spanish",
        "2592",
        include_bytes!("../voices/lucia.wav"),
    ),
    native(
        "mateo",
        "Mateo",
        "Spanish",
        "1075",
        include_bytes!("../voices/mateo.wav"),
    ),
    native(
        "elise",
        "Élise",
        "French",
        "577",
        include_bytes!("../voices/elise.wav"),
    ),
    native(
        "hugo",
        "Hugo",
        "French",
        "4724",
        include_bytes!("../voices/hugo.wav"),
    ),
];

const fn voice(
    id: &'static str,
    name: &'static str,
    set: &'static str,
    license: &'static str,
    file: &'static str,
    size: u64,
    sha256: &'static str,
) -> Voice {
    Voice {
        id,
        name,
        set,
        license,
        language: LANGUAGE,
        recording: Recording::Fetched { file, size, sha256 },
    }
}

const fn native(
    id: &'static str,
    name: &'static str,
    language: &'static str,
    speaker: &'static str,
    wav: &'static [u8],
) -> Voice {
    Voice {
        id,
        name,
        set: "CML-TTS",
        license: CC_BY,
        language,
        recording: Recording::Shipped { speaker, wav },
    }
}

impl Voice {
    /// Whom the page "About Cardwave" names for the recording, as CC BY asks;
    /// empty for CC0, which asks for nothing.
    pub fn credit(&self) -> String {
        match (self.set, &self.recording) {
            ("Alba MacKenna", _) => "Voice-acted by Alba MacKenna".into(),
            ("VCTK", Recording::Fetched { file, .. }) => {
                let speaker = file.trim_start_matches("vctk/");
                let speaker = speaker.split('_').next().unwrap_or_default();
                format!(
                    "Speaker {speaker} of the CSTR VCTK Corpus by Junichi Yamagishi, Christophe Veaux and Kirsten MacDonald, University of Edinburgh; cleaned by Kyutai"
                )
            }
            (_, Recording::Shipped { speaker, .. }) => {
                // The French recordings are those Kyutai picked and cleaned.
                let cleaned = if self.language == "French" {
                    "; cleaned by Kyutai"
                } else {
                    ""
                };
                format!(
                    "Speaker {speaker} of CML-TTS by Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares and Arlindo R. Galvão Filho, read for LibriVox{cleaned}"
                )
            }
            _ => String::new(),
        }
    }
}

/// Every voice to choose: the English ones, then the native speakers'.
pub fn all() -> impl Iterator<Item = &'static Voice> {
    VOICES.iter().chain(NATIVE)
}

/// The language the model speaks, as the dialog says it.
pub(crate) const LANGUAGE: &str = "English";

/// The voice of `id`, if there is one.
pub fn find(id: &str) -> Option<&'static Voice> {
    all().find(|voice| voice.id == id)
}

/// The revision of `kyutai/tts-voices` the recordings are taken from.
const VOICES_AT: &str = "323332d33f997de8394f24a193e1a76df720e01a";
/// The revision of `KevinAHM/pocket-tts-onnx` the model is taken from.
const MODEL_AT: &str = "58a6d00cf13d239b6748cb0769f35c580a8f606c";

/// ONNX Runtime 1.28.0, the one the crate `ort` 2.0.0-rc.13 is made for, as
/// Microsoft's Python package for 64-bit Windows holds it (MIT).
const RUNTIME: (&str, u64, &str) = (
    "https://files.pythonhosted.org/packages/56/f1/51225c202edba4dfc94e1ea03f3d78f1aaf307da75fd792c0ce1946b2514/onnxruntime-1.28.0-cp313-cp313-win_amd64.whl",
    13_755_033,
    "1a1a19175464665c9b8d50bc916f216cc0b569110045b7bbca8f9f290b186f58",
);
/// Where the library is in that package, and where it is kept.
const RUNTIME_IN_PACKAGE: &str = "onnxruntime/capi/onnxruntime.dll";
pub(crate) const RUNTIME_FILE: &str = "onnxruntime.dll";

/// The folder of the English model, and its files the app uses: the main
/// model, the flow and the decoder as int8, the encoder of a voice's recording
/// and the text's as they come.
pub(crate) const ENGLISH_DIR: &str = "english";
const ENGLISH: &[(&str, u64, &str)] = &[
    (
        "bundle.json",
        24_381,
        "bab643150f437f37df080a710520ff39ed9ebd9a339f8ebdc739f7eddfc28b3f",
    ),
    (
        "tokenizer.model",
        59_339,
        "d461765ae179566678c93091c5fa6f2984c31bbe990bf1aa62d92c64d91bc3f6",
    ),
    (
        "bos_before_voice.npy",
        4_224,
        "f46edf4f7007b7ba4ea58831f49d003e59e167b4641c44bb3addfe9231a780b1",
    ),
    (
        "text_conditioner.onnx",
        16_388_344,
        "4ecee995fb69f85c7a7493d11f7b5ee15d9950facc7ab3f5c9c49ef1e03847bb",
    ),
    (
        "mimi_encoder.onnx",
        39_768_446,
        "853e2ca623b8782d94c3745ec6133bfdff7ce33d9b11128bd29ea03f28d76e3d",
    ),
    (
        "flow_lm_main_int8.onnx",
        76_341_079,
        "f9bd8106b79a0192c1c43399ab938fb24900a95c1c599870d75a884e99000116",
    ),
    (
        "flow_lm_flow_int8.onnx",
        9_962_530,
        "3dd781ee5abee9e195320bf0106bebd6372a852b3b36352524ee78b40554635d",
    ),
    (
        "mimi_decoder_int8.onnx",
        22_684_077,
        "3630450a3297a101792a6ac66619ebc70ab916b265e6220c2afaef8b1673f925",
    ),
];

/// What the voice downloads, and what speaks: `parts` with English, and
/// each other language's pack.
#[derive(Clone, Debug)]
pub struct Setup {
    pub parts: Vec<Part>,
    pub languages: Vec<Pack>,
    pub speaker: Speaker,
}

/// A language's model: its id (its folder in the voice's), its name, the code
/// "Language the AI writes in" tells it by, and its files.
#[derive(Clone, Debug)]
pub struct Pack {
    pub id: String,
    pub name: String,
    pub code: String,
    pub parts: Vec<Part>,
}

impl Pack {
    /// What it downloads, in bytes.
    pub fn size(&self) -> u64 {
        size_of(&self.parts)
    }

    /// Whether every file is there.
    pub fn ready(&self, folder: &Path) -> bool {
        ready_in(&self.parts, folder)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Speaker {
    /// Pocket TTS, from the parts of `Setup::pocket`.
    Pocket,
    /// The tests' stand-in: a tone of a tenth of a second for each word, which
    /// fails at the word "FAIL".
    Tone,
}

impl Setup {
    /// Pocket TTS in English, with the voices of `VOICES`.
    pub fn pocket() -> Self {
        let file = |url: String, size, sha256: &str| ModelFile {
            url,
            size,
            sha256: sha256.into(),
        };
        let mut parts = vec![Part {
            file: file(RUNTIME.0.into(), RUNTIME.1, RUNTIME.2),
            path: RUNTIME_FILE.into(),
            unpack: Some(RUNTIME_IN_PACKAGE.into()),
        }];
        parts.extend(ENGLISH.iter().map(|(name, size, sha256)| Part {
            file: file(
                format!("https://huggingface.co/KevinAHM/pocket-tts-onnx/resolve/{MODEL_AT}/onnx/english_2026-04/{name}"),
                *size,
                sha256,
            ),
            path: format!("{ENGLISH_DIR}/{name}"),
            unpack: None,
        }));
        parts.extend(VOICES.iter().filter_map(|voice| match voice.recording {
            Recording::Fetched {
                file: at,
                size,
                sha256,
            } => Some(Part {
                file: file(
                    format!("https://huggingface.co/kyutai/tts-voices/resolve/{VOICES_AT}/{at}"),
                    size,
                    sha256,
                ),
                path: recording(voice),
                unpack: None,
            }),
            Recording::Shipped { .. } => None,
        }));
        let languages = LANGUAGES
            .iter()
            .map(|language| Pack {
                id: language.id.into(),
                name: language.name.into(),
                code: language.code.into(),
                parts: language
                    .files
                    .iter()
                    .map(|(name, size, sha256)| Part {
                        file: file(
                            format!("https://huggingface.co/KevinAHM/pocket-tts-onnx/resolve/{MODEL_AT}/onnx/{}/{name}", language.source),
                            *size,
                            sha256,
                        ),
                        path: format!("{}/{name}", language.id),
                        unpack: None,
                    })
                    .collect(),
            })
            .collect();
        Self {
            parts,
            languages,
            speaker: Speaker::Pocket,
        }
    }

    /// The tests' stand-in: `file` alone is downloaded, for English and for
    /// each language, and a tone speaks.
    pub fn stand_in(file: ModelFile) -> Self {
        let part = |path: String| Part {
            file: file.clone(),
            path,
            unpack: None,
        };
        Self {
            parts: vec![part("stand-in".into())],
            languages: LANGUAGES
                .iter()
                .map(|language| Pack {
                    id: language.id.into(),
                    name: language.name.into(),
                    code: language.code.into(),
                    parts: vec![part(format!("{}/stand-in", language.id))],
                })
                .collect(),
            speaker: Speaker::Tone,
        }
    }

    /// The language of `id`, if the voice has it.
    pub fn language(&self, id: &str) -> Option<&Pack> {
        self.languages.iter().find(|pack| pack.id == id)
    }

    /// The folder of the model a text is read with, of the language `code`
    /// where it is downloaded, else English's; with the language's name and code.
    pub fn reads_in(&self, folder: &Path, code: &str) -> (&str, &str, &str) {
        match self
            .languages
            .iter()
            .find(|pack| pack.code == code && pack.ready(folder))
        {
            Some(pack) => (&pack.id, &pack.name, &pack.code),
            None => (ENGLISH_DIR, LANGUAGE, "en"),
        }
    }

    /// What all of it downloads, in bytes.
    pub fn size(&self) -> u64 {
        size_of(&self.parts)
    }

    /// Whether every file is there.
    pub fn ready(&self, folder: &Path) -> bool {
        ready_in(&self.parts, folder)
    }
}

/// Where the voice's files are kept in the data folder.
pub fn folder(data_dir: &Path) -> PathBuf {
    data_dir.join("models").join("voice")
}

/// Where a voice's recording is kept in the voice's folder.
fn recording(voice: &Voice) -> String {
    format!("voices/{}.wav", voice.id)
}

/// What speaks: it reads `text` aloud in the voice `voice` of the recording
/// `recording` (a WAV file's bytes), handing the sound to `out` piece by piece
/// as it comes, and stops where `out` says no more is wanted.
pub trait Speak: Send {
    fn speak(
        &mut self,
        voice: &str,
        recording: &[u8],
        text: &str,
        out: &mut dyn FnMut(&[f32]) -> bool,
    ) -> anyhow::Result<()>;
}

/// What `setup` speaks with in the language of the folder `language`, its
/// files in `folder`.
pub fn load(setup: &Setup, folder: &Path, language: &str) -> anyhow::Result<Box<dyn Speak>> {
    Ok(match setup.speaker {
        Speaker::Pocket => Box::new(pocket::Pocket::load(folder, language)?),
        Speaker::Tone => Box::new(Tone),
    })
}

/// Where the recording of `voice` is, of the voice's folder `folder`.
pub(crate) fn recording_of(folder: &Path, voice: &Voice) -> PathBuf {
    folder.join(recording(voice))
}

impl Setup {
    /// The recording of the shipped `voice`; the stand-in has none of those it downloads.
    pub fn recording(&self, folder: &Path, voice: &Voice) -> std::io::Result<Vec<u8>> {
        match (&voice.recording, &self.speaker) {
            (Recording::Shipped { wav, .. }, _) => Ok(wav.to_vec()),
            (Recording::Fetched { .. }, Speaker::Pocket) => {
                std::fs::read(recording_of(folder, voice))
            }
            (Recording::Fetched { .. }, Speaker::Tone) => Ok(Vec::new()),
        }
    }
}

struct Tone;

impl Speak for Tone {
    fn speak(
        &mut self,
        _voice: &str,
        _recording: &[u8],
        text: &str,
        out: &mut dyn FnMut(&[f32]) -> bool,
    ) -> anyhow::Result<()> {
        let tenth = (RATE / 10) as usize;
        for word in text.split_whitespace() {
            // As a speaker's own failure: no code, so the answer's is voice_failed.
            ensure!(word != "FAIL", "the stand-in failed");
            let tone: Vec<f32> = (0..tenth)
                .map(|at| (at as f32 * 440.0 * std::f32::consts::TAU / RATE as f32).sin() * 0.2)
                .collect();
            if !out(&tone) {
                break;
            }
        }
        Ok(())
    }
}

/// The sound of a WAV file of 16-bit PCM, as its rate and its samples, its
/// channels made one.
pub fn read_wav(bytes: &[u8]) -> anyhow::Result<(u32, Vec<f32>)> {
    ensure!(
        bytes.len() >= 12 && &bytes[..4] == b"RIFF" && &bytes[8..12] == b"WAVE",
        Fail::said(Code::NotReadable, "the recording is no WAV file").with("what", "recording_wav")
    );
    let (mut rate, mut channels, mut at) = (0, 0, 12);
    while at + 8 <= bytes.len() {
        let size = u32::from_le_bytes(bytes[at + 4..at + 8].try_into()?) as usize;
        let body = &bytes[at + 8..(at + 8 + size).min(bytes.len())];
        match &bytes[at..at + 4] {
            b"fmt " => {
                ensure!(
                    body.len() >= 16,
                    Fail::said(Code::NotReadable, "the recording's format cannot be read")
                        .with("what", "recording_format")
                );
                let format = u16::from_le_bytes([body[0], body[1]]);
                channels = u16::from_le_bytes([body[2], body[3]]) as usize;
                rate = u32::from_le_bytes(body[4..8].try_into()?);
                let bits = u16::from_le_bytes([body[14], body[15]]);
                ensure!(
                    format == 1 && bits == 16 && channels > 0,
                    Fail::said(Code::NotReadable, "the recording is not 16-bit PCM")
                        .with("what", "recording_pcm")
                );
            }
            b"data" => {
                ensure!(
                    channels > 0,
                    Fail::said(Code::NotReadable, "the recording's format cannot be read")
                        .with("what", "recording_format")
                );
                let samples = body
                    .as_chunks::<2>()
                    .0
                    .chunks_exact(channels)
                    .map(|frame| {
                        frame
                            .iter()
                            .map(|two| f32::from(i16::from_le_bytes(*two)) / 32768.0)
                            .sum::<f32>()
                            / channels as f32
                    })
                    .collect();
                return Ok((rate, samples));
            }
            _ => {}
        }
        at += 8 + size + size % 2;
    }
    bail!(
        Fail::said(Code::NotReadable, "the recording has no sound")
            .with("what", "recording_silent")
    )
}

/// The shortest and the longest recording a voice is made of, in seconds; a
/// longer one is cut.
pub const SHORTEST: u32 = 3;
pub const LONGEST: u32 = 30;

/// A recording the user gives (a WAV file of 16-bit PCM) as the shipped
/// voices' are: one channel at `RATE`, at most `LONGEST` seconds.
pub fn prepare(wav: &[u8]) -> anyhow::Result<Vec<u8>> {
    let (rate, sound) = read_wav(wav)?;
    ensure!(
        rate > 0,
        Fail::said(Code::NotReadable, "the recording's rate cannot be read")
            .with("what", "recording_rate")
    );
    // Cut to the longest first, so a long recording is not resampled whole.
    let longest = (u64::from(LONGEST) * u64::from(rate)) as usize;
    let mut sound = resample(&sound[..sound.len().min(longest)], rate, RATE);
    ensure!(
        sound.len() >= (SHORTEST * RATE) as usize,
        Fail::said(
            Code::NotReadable,
            format!("the recording is too short: at least {SHORTEST} seconds are needed")
        )
        .with("what", "recording_short")
        .with("shortest", SHORTEST)
    );
    sound.truncate((LONGEST * RATE) as usize);
    Ok(write_wav(&sound))
}

/// `sound` as 16-bit PCM, little-endian, each sample cut to -1 to 1.
pub fn pcm16(sound: &[f32]) -> Vec<u8> {
    sound
        .iter()
        .flat_map(|sample| ((sample.clamp(-1.0, 1.0) * 32767.0) as i16).to_le_bytes())
        .collect()
}

/// `sound` at `RATE` as a WAV file of 16-bit PCM, one channel.
pub(crate) fn write_wav(sound: &[f32]) -> Vec<u8> {
    let pcm = pcm16(sound);
    let data = pcm.len() as u32;
    let mut wav = Vec::with_capacity(44 + pcm.len());
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16u32.to_le_bytes());
    wav.extend_from_slice(&1u16.to_le_bytes());
    wav.extend_from_slice(&1u16.to_le_bytes());
    wav.extend_from_slice(&RATE.to_le_bytes());
    wav.extend_from_slice(&(RATE * 2).to_le_bytes());
    wav.extend_from_slice(&2u16.to_le_bytes());
    wav.extend_from_slice(&16u16.to_le_bytes());
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data.to_le_bytes());
    wav.extend_from_slice(&pcm);
    wav
}

/// `samples` at `from` samples a second made `to` a second: each new sample
/// the old ones near it weighed by a sinc in a Hann window of `TAPS` on each
/// side, cut off below the lower rate's half.
pub fn resample(samples: &[f32], from: u32, to: u32) -> Vec<f32> {
    const TAPS: f64 = 32.0;
    if from == to || samples.is_empty() {
        return samples.to_vec();
    }
    let step = f64::from(from) / f64::from(to);
    let cut = (f64::from(to) / f64::from(from)).min(1.0);
    let reach = TAPS / cut;
    let count = (samples.len() as f64 / step).floor() as usize;
    (0..count)
        .map(|n| {
            let at = n as f64 * step;
            let first = (at - reach).ceil().max(0.0) as usize;
            let last = ((at + reach).floor() as usize).min(samples.len() - 1);
            let mut sum = 0.0;
            for (k, sample) in samples.iter().enumerate().take(last + 1).skip(first) {
                let x = (k as f64 - at) * cut;
                let sinc = if x == 0.0 {
                    1.0
                } else {
                    (std::f64::consts::PI * x).sin() / (std::f64::consts::PI * x)
                };
                let window = 0.5 + 0.5 * (std::f64::consts::PI * x / TAPS).cos();
                sum += f64::from(*sample) * sinc * window * cut;
            }
            sum as f32
        })
        .collect()
}

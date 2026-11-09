//! The one wrapper of `whisper-rs` (whisper.cpp, built in with Vulkan) for
//! the server (global layer rule; `tools/check.sh` holds it): a Whisper
//! model loaded on the graphics card ([`Whisper::load`]) and what it hears
//! ([`Whisper::hear`]). Dictation (`dictation.rs`) is its one user.
//!
//! Traps: whisper.cpp counts the graphics devices ggml sees, discrete and
//! integrated alike, in the order Vulkan lists them, and runs on the CPU
//! where it finds none; on a laptop the integrated one often comes first
//! (an AMD 780M). So the card is picked by its kind ([`pick`]) and
//! nothing is loaded without one. Vulkan's loader is asked for first
//! (`sys::has_vulkan`), as the programs load it at its first call. Silence
//! is heard as a word ("you"), and whisper.cpp's likelihood of no speech is
//! near 0 for it (measured), so a recording without a loud moment
//! ([`silent`]) is not heard at all.

use std::ffi::{CStr, c_int};
use std::path::Path;

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use whisper_rs::whisper_rs_sys as ggml;
use whisper_rs::{
    FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters, WhisperState,
};

/// The loudness (root mean square, of 1) that a stretch of [`WINDOW`]
/// samples must reach somewhere for a recording to hold speech: -60 dBFS.
/// The page's microphone has the browser's noise suppression, which brings
/// a quiet room below it; the softest of the trial's 50 spoken recordings
/// (FLEURS) reaches 0.0014.
const LOUD: f32 = 0.001;
/// 30 ms at 16 kHz.
const WINDOW: usize = 480;
/// 1.1 s at 16 kHz: whisper.cpp returns no words for less than 1 s (its
/// "input is too short"), so a shorter recording is padded to this.
const SHORTEST: usize = 16_000 * 11 / 10;
/// The processor's threads for what whisper.cpp does there (the sound's
/// spectrum), as the trial ran it.
const THREADS: c_int = 4;

/// A graphics device's kind, as ggml tells it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Discrete,
    Integrated,
}

/// Which of the devices, in whisper.cpp's count, to run on: the first
/// discrete card, else the first integrated one.
pub fn pick(kinds: &[Kind]) -> Option<usize> {
    let first = |wanted| kinds.iter().position(|kind| *kind == wanted);
    first(Kind::Discrete).or_else(|| first(Kind::Integrated))
}

/// The graphics devices ggml sees, in whisper.cpp's count, with their names.
fn devices() -> Vec<(Kind, String)> {
    let mut found = Vec::new();
    // SAFETY: ggml's registry of the backends built in, which it makes at the
    // first call; each device it hands out lives as long as the program.
    unsafe {
        for at in 0..ggml::ggml_backend_dev_count() {
            let device = ggml::ggml_backend_dev_get(at);
            let kind = match ggml::ggml_backend_dev_type(device) {
                ggml::ggml_backend_dev_type_GGML_BACKEND_DEVICE_TYPE_GPU => Kind::Discrete,
                ggml::ggml_backend_dev_type_GGML_BACKEND_DEVICE_TYPE_IGPU => Kind::Integrated,
                _ => continue,
            };
            let name = CStr::from_ptr(ggml::ggml_backend_dev_description(device));
            found.push((kind, name.to_string_lossy().into_owned()));
        }
    }
    found
}

/// A Whisper model on the graphics card.
pub struct Whisper {
    /// The card it runs on, by its name.
    pub card: String,
    /// What it hears with; its context stays alive inside it.
    state: WhisperState,
}

impl Whisper {
    /// Loads `model` (a GGML file) on the graphics card, or says there is none.
    pub fn load(model: &Path) -> anyhow::Result<Self> {
        let none = "this computer has no graphics card with Vulkan, which dictation runs on";
        if !cw_platform::sys::has_vulkan() {
            bail!(Fail::said(Code::NotPossible, none).with("what", "no_vulkan_dictation"));
        }
        let devices = devices();
        let kinds: Vec<Kind> = devices.iter().map(|(kind, _)| *kind).collect();
        let Some(at) = pick(&kinds) else {
            bail!(Fail::said(Code::NotPossible, none).with("what", "no_vulkan_dictation"))
        };
        let mut params = WhisperContextParameters::default();
        params.use_gpu(true).gpu_device(c_int::try_from(at)?);
        let path = model
            .to_str()
            .context(Fail::said(Code::Internal, "the model's path is not text"))?;
        let context = WhisperContext::new_with_params(path, params).context(
            Fail::said(Code::NotPossible, "the dictation model cannot be loaded")
                .with("what", "dictation_model_load"),
        )?;
        let state = context.create_state().context(
            Fail::said(Code::NotPossible, "the dictation model cannot be started")
                .with("what", "dictation_model_start"),
        )?;
        tracing::info!("dictation: {} on {}", model.display(), devices[at].1);
        Ok(Self {
            card: devices[at].1.clone(),
            state,
        })
    }

    /// The words said in `samples` (16 kHz, one channel, from -1 to 1), in
    /// whatever language they are said.
    pub fn hear(&mut self, samples: &[f32]) -> anyhow::Result<String> {
        if silent(samples) {
            return Ok(String::new());
        }
        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_language(Some("auto"));
        params.set_n_threads(THREADS);
        params.set_no_timestamps(true);
        params.set_suppress_nst(true);
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        self.state.full(params, &padded(samples)).context(
            Fail::said(Code::NotPossible, "the dictation model failed")
                .with("what", "dictation_failed"),
        )?;
        let mut words = Vec::new();
        for segment in self.state.as_iter() {
            words.push(segment.to_str_lossy()?.trim().to_string());
        }
        words.retain(|said| !said.is_empty());
        Ok(words.join(" "))
    }
}

/// `samples` with silence after them up to [`SHORTEST`]: whisper.cpp hears
/// nothing in less than a second.
fn padded(samples: &[f32]) -> Vec<f32> {
    let mut samples = samples.to_vec();
    if samples.len() < SHORTEST {
        samples.resize(SHORTEST, 0.0);
    }
    samples
}

/// Whether no stretch of `samples` reaches [`LOUD`].
fn silent(samples: &[f32]) -> bool {
    !samples.chunks(WINDOW).any(|stretch| {
        let power = stretch.iter().map(|x| x * x).sum::<f32>() / stretch.len() as f32;
        power.sqrt() >= LOUD
    })
}

#[cfg(test)]
mod tests {
    use crate::whisper::{Kind, SHORTEST, padded, pick, silent};

    #[test]
    fn the_discrete_card_is_picked_before_an_integrated_one() {
        use Kind::{Discrete, Integrated};
        assert_eq!(pick(&[Integrated, Discrete]), Some(1));
        assert_eq!(pick(&[Discrete, Integrated, Discrete]), Some(0));
        assert_eq!(pick(&[Integrated]), Some(0));
        assert_eq!(pick(&[]), None);
    }

    #[test]
    fn a_short_recording_is_padded_with_silence_to_the_shortest_heard() {
        let short = padded(&[0.5; 1_000]);
        assert_eq!(short.len(), SHORTEST);
        assert_eq!(&short[..1_000], &[0.5; 1_000]);
        assert!(short[1_000..].iter().all(|x| *x == 0.0));
        assert_eq!(padded(&[0.5; 20_000]).len(), 20_000);
    }

    #[test]
    fn a_recording_without_a_loud_moment_is_silent() {
        let hum = |level: f32| -> Vec<f32> {
            (0..16_000)
                .map(|i| level * (i as f32 * 0.3).sin())
                .collect()
        };
        assert!(silent(&[]));
        assert!(silent(&hum(0.0005)));
        let mut spoken = hum(0.0005);
        spoken[8_000..8_480].copy_from_slice(&hum(0.05)[..480]);
        assert!(!silent(&spoken));
    }
}

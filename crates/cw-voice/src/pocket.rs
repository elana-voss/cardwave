//! Pocket TTS on ONNX Runtime: a port of the export's own
//! `pocket_tts_onnx.py` (the voice spike's, in the work log), with no Python.
//!
//! ONNX Runtime is the library downloaded beside the model (`RUNTIME_FILE`),
//! loaded once for the process's whole life (`runtime`); one that cannot be
//! loaded (Windows lacking the Visual C++ runtime it needs) is tried again at
//! the next reading. Five models: `mimi_encoder` makes a voice's
//! recording numbers, which `flow_lm_main` takes in as its state (`voice`,
//! kept for the last voice asked); for each piece of the text (`split`: by
//! sentences, of at most `max_token_per_chunk` tokens) `text_conditioner`
//! reads its tokens into the state, then frame by frame `flow_lm_main` says
//! what comes next and when the speech ends, `flow_lm_flow` makes a frame of
//! it from noise (temperature `TEMPERATURE`, one step) and `mimi_decoder`
//! turns frames into sound, two at first and eight at a time after, so that
//! the first sound comes at once. Four threads, as the spike measured. It is
//! the model of one language, its folder named at `load`; every language's
//! takes the same recordings.

use std::path::Path;
use std::sync::Mutex;

use anyhow::{Context, anyhow, ensure};
use cw_core::{Code, Fail};
use ort::session::builder::GraphOptimizationLevel;
use ort::session::{Session, SessionInputValue};
use ort::value::{DynValue, Tensor};
use serde_json::Value;

use crate::pieces::Pieces;
use crate::{RATE, RUNTIME_FILE, Speak, read_wav, resample};

const THREADS: usize = 4;
const TEMPERATURE: f32 = 0.7;
/// Above this, `flow_lm_main` says the speech has ended.
const END: f32 = -4.0;

/// An array of a model's state, as its numbers.
#[derive(Clone)]
enum Array {
    F32(Vec<i64>, Vec<f32>),
    I64(Vec<i64>, Vec<i64>),
    Bool(Vec<i64>, Vec<bool>),
}

impl Array {
    fn value(&self) -> anyhow::Result<DynValue> {
        Ok(match self {
            Array::F32(shape, data) => {
                Tensor::from_array((shape.clone(), data.clone()))?.into_dyn()
            }
            Array::I64(shape, data) => {
                Tensor::from_array((shape.clone(), data.clone()))?.into_dyn()
            }
            Array::Bool(shape, data) => {
                Tensor::from_array((shape.clone(), data.clone()))?.into_dyn()
            }
        })
    }

    fn of(value: &DynValue, kind: &str) -> anyhow::Result<Self> {
        Ok(match kind {
            "float32" => {
                let (shape, data) = value.try_extract_tensor::<f32>()?;
                Array::F32(shape.to_vec(), data.to_vec())
            }
            "int64" => {
                let (shape, data) = value.try_extract_tensor::<i64>()?;
                Array::I64(shape.to_vec(), data.to_vec())
            }
            "bool" => {
                let (shape, data) = value.try_extract_tensor::<bool>()?;
                Array::Bool(shape.to_vec(), data.to_vec())
            }
            other => anyhow::bail!(Fail::said(
                Code::Internal,
                format!("the voice model has a state of {other}")
            )),
        })
    }
}

/// One array of a model's state, as `bundle.json` lists it.
struct Entry {
    kind: String,
    fill: String,
    shape: Vec<i64>,
    output: String,
}

impl Entry {
    fn list(bundle: &Value, key: &str) -> anyhow::Result<Vec<Self>> {
        let unreadable = || {
            anyhow!(Fail::said(
                Code::Internal,
                format!("the voice model's {key} cannot be read")
            ))
        };
        bundle[key]
            .as_array()
            .ok_or_else(unreadable)?
            .iter()
            .map(|entry| {
                Ok(Self {
                    kind: entry["dtype"].as_str().ok_or_else(unreadable)?.into(),
                    fill: entry["fill"].as_str().ok_or_else(unreadable)?.into(),
                    shape: entry["shape"]
                        .as_array()
                        .ok_or_else(unreadable)?
                        .iter()
                        .map(|n| n.as_i64().ok_or_else(unreadable))
                        .collect::<anyhow::Result<_>>()?,
                    output: entry["output_name"].as_str().ok_or_else(unreadable)?.into(),
                })
            })
            .collect()
    }

    /// The array as it starts.
    fn start(&self) -> Array {
        let count = self.shape.iter().product::<i64>().max(0) as usize;
        let shape = self.shape.clone();
        match self.kind.as_str() {
            "float32" => Array::F32(
                shape,
                vec![
                    match self.fill.as_str() {
                        "nan" => f32::NAN,
                        "ones" => 1.0,
                        _ => 0.0,
                    };
                    count
                ],
            ),
            "int64" => Array::I64(shape, vec![i64::from(self.fill == "ones"); count]),
            _ => Array::Bool(shape, vec![self.fill == "ones"; count]),
        }
    }
}

pub(crate) struct Pocket {
    encoder: Session,
    conditioner: Session,
    main: Session,
    flow: Session,
    decoder: Session,
    pieces: Pieces,
    /// Put before a voice's numbers, where `insert_bos_before_voice` says so.
    before_voice: Option<Vec<f32>>,
    main_state: Vec<Entry>,
    decoder_state: Vec<Entry>,
    latent: usize,
    conditioning: usize,
    most_tokens: usize,
    pad_short: bool,
    no_semicolons: bool,
    frames_after_end: Option<usize>,
    /// The last voice asked for, and `flow_lm_main`'s state with it taken in.
    voice: Option<(String, Vec<Array>)>,
}

/// Loads ONNX Runtime from `folder`, once it has loaded for the process's life.
fn runtime(folder: &Path) -> anyhow::Result<()> {
    static LOADED: Mutex<bool> = Mutex::new(false);
    let mut loaded = cw_core::lock(&LOADED);
    if !*loaded {
        let environment = ort::init_from(folder.join(RUNTIME_FILE)).map_err(|failure| {
            anyhow!(Fail::said(Code::NotPossible, format!("ONNX Runtime cannot be loaded ({failure}); it needs the Microsoft Visual C++ Redistributable")).with("what", "voice_runtime").with("failure", failure.to_string()))
        })?;
        environment.with_name("cardwave-voice").commit();
        *loaded = true;
    }
    Ok(())
}

fn session(folder: &Path, file: &str) -> anyhow::Result<Session> {
    let failed = |failure: ort::Error| {
        anyhow!(Fail::said(
            Code::Internal,
            format!("the voice model's {file} cannot be loaded: {failure}")
        ))
    };
    Session::builder()
        .map_err(failed)?
        .with_optimization_level(GraphOptimizationLevel::Level3)
        .map_err(|e| failed(e.into()))?
        .with_intra_threads(THREADS)
        .map_err(|e| failed(e.into()))?
        .with_inter_threads(1)
        .map_err(|e| failed(e.into()))?
        .commit_from_file(folder.join(file))
        .map_err(failed)
}

/// The numbers of a `.npy` file of float32, after its header.
fn npy(bytes: &[u8]) -> anyhow::Result<Vec<f32>> {
    ensure!(
        bytes.len() >= 10,
        Fail::said(Code::Internal, "the voice model's .npy cannot be read")
    );
    let header = u16::from_le_bytes([bytes[8], bytes[9]]) as usize;
    let data = bytes.get(10 + header..).context(Fail::said(
        Code::Internal,
        "the voice model's .npy cannot be read",
    ))?;
    Ok(data
        .as_chunks::<4>()
        .0
        .iter()
        .map(|four| f32::from_le_bytes(*four))
        .collect())
}

fn f32s(shape: &[i64], data: Vec<f32>) -> anyhow::Result<DynValue> {
    Ok(Tensor::from_array((shape.to_vec(), data))?.into_dyn())
}

impl Pocket {
    /// The model of the language in its folder `language` of `folder`, the voice's folder.
    pub fn load(folder: &Path, language: &str) -> anyhow::Result<Self> {
        runtime(folder)?;
        let model = folder.join(language);
        let bundle: Value = serde_json::from_slice(&std::fs::read(model.join("bundle.json"))?)?;
        let number = |key: &str| {
            bundle[key].as_u64().map(|n| n as usize).with_context(|| {
                Fail::said(
                    Code::Internal,
                    format!("the voice model's {key} cannot be read"),
                )
            })
        };
        let before_voice = match bundle["insert_bos_before_voice"].as_bool() {
            Some(true) => {
                let file = bundle["bos_before_voice_file"]
                    .as_str()
                    .unwrap_or("bos_before_voice.npy");
                Some(npy(&std::fs::read(model.join(file))?)?)
            }
            _ => None,
        };
        ensure!(
            bundle["sample_rate"].as_u64() == Some(u64::from(RATE)),
            Fail::said(
                Code::Internal,
                format!("the voice model's rate is not {RATE}")
            )
        );
        Ok(Self {
            encoder: session(&model, "mimi_encoder.onnx")?,
            conditioner: session(&model, "text_conditioner.onnx")?,
            main: session(&model, "flow_lm_main_int8.onnx")?,
            flow: session(&model, "flow_lm_flow_int8.onnx")?,
            decoder: session(&model, "mimi_decoder_int8.onnx")?,
            pieces: Pieces::read(&std::fs::read(model.join("tokenizer.model"))?)?,
            before_voice,
            main_state: Entry::list(&bundle, "flow_lm_state_manifest")?,
            decoder_state: Entry::list(&bundle, "mimi_state_manifest")?,
            latent: number("latent_dim")?,
            conditioning: number("conditioning_dim")?,
            most_tokens: bundle["max_token_per_chunk"].as_u64().unwrap_or(50) as usize,
            pad_short: bundle["pad_with_spaces_for_short_inputs"]
                .as_bool()
                .unwrap_or(false),
            no_semicolons: bundle["remove_semicolons"].as_bool().unwrap_or(false),
            frames_after_end: bundle["model_recommended_frames_after_eos"]
                .as_u64()
                .map(|n| n as usize),
            voice: None,
        })
    }

    /// Runs `flow_lm_main` on the frames `frames` (`count` of them) and the
    /// text's numbers `text`, from `state`: what it conditions the next frame
    /// on (shape and numbers), how sure it is the speech ends, and its state after.
    #[allow(clippy::type_complexity)]
    fn run_main(
        &mut self,
        frames: Vec<f32>,
        count: usize,
        text: Option<(&[i64], Vec<f32>)>,
        state: Vec<DynValue>,
    ) -> anyhow::Result<(Vec<i64>, Vec<f32>, f32, Vec<DynValue>)> {
        let mut inputs: Vec<(String, SessionInputValue<'static>)> = vec![(
            "sequence".into(),
            f32s(&[1, count as i64, self.latent as i64], frames)?.into(),
        )];
        let text = match text {
            Some((shape, data)) => f32s(shape, data)?,
            None => f32s(&[1, 0, self.conditioning as i64], Vec::new())?,
        };
        inputs.push(("text_embeddings".into(), text.into()));
        for (at, value) in state.into_iter().enumerate() {
            inputs.push((format!("state_{at}"), value.into()));
        }
        let mut out = self.main.run(inputs)?;
        let (shape, conditions) = {
            let (shape, data) = out[0].try_extract_tensor::<f32>()?;
            (shape.to_vec(), data.to_vec())
        };
        let end = out[1].try_extract_tensor::<f32>()?.1[0];
        let state = self
            .main_state
            .iter()
            .map(|entry| {
                out.remove(entry.output.as_str()).with_context(|| {
                    Fail::said(
                        Code::Internal,
                        format!("the voice model gave no {}", entry.output),
                    )
                })
            })
            .collect::<anyhow::Result<_>>()?;
        Ok((shape, conditions, end, state))
    }

    /// `flow_lm_main`'s state with the voice `voice`, of the recording `recording`, taken in, as numbers.
    fn voice(&mut self, voice: &str, recording: &[u8]) -> anyhow::Result<Vec<Array>> {
        if let Some((had, state)) = &self.voice
            && had == voice
        {
            return Ok(state.clone());
        }
        let (rate, sound) = read_wav(recording)?;
        let sound = resample(&sound, rate, RATE);
        let length = sound.len() as i64;
        let out = self.encoder.run(vec![(
            "audio".to_string(),
            SessionInputValue::from(f32s(&[1, 1, length], sound)?),
        )])?;
        let mut numbers = self.before_voice.clone().unwrap_or_default();
        numbers.extend_from_slice(out[0].try_extract_tensor::<f32>()?.1);
        drop(out);
        let count = (numbers.len() / self.conditioning) as i64;
        let start = self
            .main_state
            .iter()
            .map(|entry| entry.start().value())
            .collect::<anyhow::Result<_>>()?;
        let shape = [1, count, self.conditioning as i64];
        let (_, _, _, state) = self.run_main(Vec::new(), 0, Some((&shape, numbers)), start)?;
        let state: Vec<Array> = state
            .iter()
            .zip(&self.main_state)
            .map(|(value, entry)| Array::of(value, &entry.kind))
            .collect::<anyhow::Result<_>>()?;
        self.voice = Some((voice.to_string(), state.clone()));
        Ok(state)
    }

    /// A piece of text as the model reads it best: one line, a capital first, a
    /// stop at its end; and how many frames to let it go on after it says it
    /// has ended (more for a few words).
    fn prepare(&self, text: &str) -> (String, usize) {
        let mut text = text.trim().replace(['\n', '\r'], " ").replace("  ", " ");
        if self.no_semicolons {
            text = text.replace(';', ",");
        }
        let after = if text.split_whitespace().count() <= 4 {
            3
        } else {
            1
        };
        let mut chars = text.chars();
        if let Some(first) = chars.next()
            && !first.is_uppercase()
        {
            text = first.to_uppercase().collect::<String>() + chars.as_str();
        }
        if text.chars().last().is_some_and(char::is_alphanumeric) {
            text.push('.');
        }
        if self.pad_short && text.split_whitespace().count() < 5 {
            text = " ".repeat(8) + &text;
        }
        (text, after)
    }

    /// Where the tokens `tokens` are cut: after each run of the tokens `at`.
    fn cuts(tokens: &[u32], at: &[u32]) -> Vec<usize> {
        let mut cuts = vec![0];
        let mut after = false;
        for (i, token) in tokens.iter().enumerate() {
            if at.contains(token) {
                after = true;
            } else {
                if after {
                    cuts.push(i);
                }
                after = false;
            }
        }
        cuts.push(tokens.len());
        cuts
    }

    /// The tokens cut at `cuts`, each piece with its count and its text.
    fn pieces_of(&self, tokens: &[u32], cuts: &[usize]) -> Vec<(usize, String)> {
        cuts.windows(2)
            .map(|pair| {
                (
                    pair[1] - pair[0],
                    self.pieces.decode(&tokens[pair[0]..pair[1]]),
                )
            })
            .collect()
    }

    /// `text` in pieces of at most `most_tokens` tokens: its sentences, put
    /// together while they fit, a longer one cut at its commas, colons and semicolons.
    fn split(&self, text: &str) -> Vec<String> {
        let (prepared, _) = self.prepare(text);
        let tokens = self.pieces.encode(prepared.trim());
        let ends: Vec<u32> = self.pieces.encode(".!...?").into_iter().skip(1).collect();
        let marks: Vec<u32> = self.pieces.encode(",;:").into_iter().skip(1).collect();
        let mut sentences = Vec::new();
        for (count, sentence) in self.pieces_of(&tokens, &Self::cuts(&tokens, &ends)) {
            if count <= self.most_tokens {
                sentences.push((count, sentence));
                continue;
            }
            let own = self.pieces.encode(sentence.trim());
            let parts = self.pieces_of(&own, &Self::cuts(&own, &marks));
            if parts.len() > 1 {
                sentences.extend(parts);
            } else {
                sentences.push((count, sentence));
            }
        }
        let mut chunks = Vec::new();
        let (mut chunk, mut tokens) = (String::new(), 0);
        for (count, sentence) in sentences {
            if !chunk.is_empty() && tokens + count > self.most_tokens {
                chunks.push(std::mem::take(&mut chunk).trim().to_string());
                tokens = 0;
            }
            if !chunk.is_empty() {
                chunk.push(' ');
            }
            chunk += &sentence;
            tokens += count;
        }
        if !chunk.trim().is_empty() {
            chunks.push(chunk.trim().to_string());
        }
        chunks
    }

    /// Turns `count` frames into sound, from the decoder's state `state`.
    fn decode(
        &mut self,
        frames: Vec<f32>,
        count: usize,
        state: Vec<DynValue>,
    ) -> anyhow::Result<(Vec<f32>, Vec<DynValue>)> {
        let mut inputs: Vec<(String, SessionInputValue<'static>)> = vec![(
            "latent".into(),
            f32s(&[1, count as i64, self.latent as i64], frames)?.into(),
        )];
        for (at, value) in state.into_iter().enumerate() {
            inputs.push((format!("state_{at}"), value.into()));
        }
        let mut out = self.decoder.run(inputs)?;
        let sound = out[0].try_extract_tensor::<f32>()?.1.to_vec();
        let state = self
            .decoder_state
            .iter()
            .map(|entry| {
                out.remove(entry.output.as_str()).with_context(|| {
                    Fail::said(
                        Code::Internal,
                        format!("the voice model gave no {}", entry.output),
                    )
                })
            })
            .collect::<anyhow::Result<_>>()?;
        Ok((sound, state))
    }

    /// One frame from noise, by `flow_lm_flow` in one Euler step from 0 to 1.
    fn frame(&mut self, shape: &[i64], conditions: Vec<f32>) -> anyhow::Result<Vec<f32>> {
        let spread = TEMPERATURE.sqrt();
        let mut x: Vec<f32> = (0..self.latent).map(|_| normal() * spread).collect();
        let out = self.flow.run(vec![
            (
                "c".to_string(),
                SessionInputValue::from(f32s(shape, conditions)?),
            ),
            (
                "s".to_string(),
                SessionInputValue::from(f32s(&[1, 1], vec![0.0])?),
            ),
            (
                "t".to_string(),
                SessionInputValue::from(f32s(&[1, 1], vec![1.0])?),
            ),
            (
                "x".to_string(),
                SessionInputValue::from(f32s(&[1, self.latent as i64], x.clone())?),
            ),
        ])?;
        let flow = out[0].try_extract_tensor::<f32>()?.1;
        for (value, change) in x.iter_mut().zip(flow) {
            *value += change;
        }
        Ok(x)
    }
}

/// A number of the standard normal distribution (Box–Muller).
fn normal() -> f32 {
    let u: f32 = 1.0 - rand::random::<f32>();
    let v: f32 = rand::random::<f32>();
    (-2.0 * u.ln()).sqrt() * (std::f32::consts::TAU * v).cos()
}

impl Speak for Pocket {
    fn speak(
        &mut self,
        voice: &str,
        recording: &[u8],
        text: &str,
        out: &mut dyn FnMut(&[f32]) -> bool,
    ) -> anyhow::Result<()> {
        let voiced = self.voice(voice, recording)?;
        for chunk in self.split(text) {
            let (prepared, after) = self.prepare(&chunk);
            let after = self.frames_after_end.unwrap_or(after + 2);
            let tokens: Vec<i64> = self
                .pieces
                .encode(&prepared)
                .into_iter()
                .map(i64::from)
                .collect();
            let count = tokens.len();
            let (shape, numbers) = {
                let read = self.conditioner.run(vec![(
                    "token_ids".to_string(),
                    SessionInputValue::from(
                        Tensor::from_array((vec![1i64, count as i64], tokens))?.into_dyn(),
                    ),
                )])?;
                let (shape, data) = read[0].try_extract_tensor::<f32>()?;
                (shape.to_vec(), data.to_vec())
            };
            let shape = if shape.len() == 2 {
                vec![1, shape[0], shape[1]]
            } else {
                shape
            };
            let state = voiced
                .iter()
                .map(Array::value)
                .collect::<anyhow::Result<_>>()?;
            let (_, _, _, mut state) =
                self.run_main(Vec::new(), 0, Some((&shape, numbers)), state)?;
            let mut sound_state: Vec<DynValue> = self
                .decoder_state
                .iter()
                .map(|entry| entry.start().value())
                .collect::<anyhow::Result<_>>()?;
            let mut last = vec![f32::NAN; self.latent];
            let most = ((count as f32 / 3.0 + 2.0) * 12.5).ceil() as usize;
            let mut ended = None;
            let (mut waiting, mut waiting_count, mut first) = (Vec::new(), 0, true);
            for step in 0..most {
                let (shape, conditions, end, next) = self.run_main(last, 1, None, state)?;
                state = next;
                if end > END && ended.is_none() {
                    ended = Some(step);
                }
                if ended.is_some_and(|at| step >= at + after) {
                    break;
                }
                let frame = self.frame(&shape, conditions)?;
                waiting.extend_from_slice(&frame);
                waiting_count += 1;
                last = frame;
                if waiting_count >= if first { 2 } else { 8 } {
                    let (sound, next) =
                        self.decode(std::mem::take(&mut waiting), waiting_count, sound_state)?;
                    sound_state = next;
                    waiting_count = 0;
                    first = false;
                    if !out(&sound) {
                        return Ok(());
                    }
                }
            }
            if waiting_count > 0 {
                let (sound, _) = self.decode(waiting, waiting_count, sound_state)?;
                if !out(&sound) {
                    return Ok(());
                }
            }
        }
        Ok(())
    }
}

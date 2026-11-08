//! This computer's models that fit (Settings › Providers' box "This
//! computer", milestone 74): Cardwave's list of chat models to download
//! ([`offered`], one GGUF file each on Hugging Face, checked by its size and
//! SHA-256), and the models of the chosen folder, each with whether it fits
//! ([`Downloads::list`]): at most half of `sys::memory` ([`fits`]). A
//! download goes into the folder (`fetching::download_file`, a `.part` until
//! checked), so it is a GGUF file like any other, run by `local`. Only a
//! model of the list is downloaded and removed here; others are only listed.
//!
//! Traps: the downloads are the server's (`Downloads`), kept by the file each
//! writes, so a folder changed meanwhile has the running one finish in the
//! old folder unlisted. Only the API's check keeps a model too large or there
//! already from being downloaded. `LIST` pins each file's size and SHA-256 as
//! of 2026-10-23: bartowski and unsloth re-upload quants, after which that
//! model's download fails with a checksum error until its line is edited.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::AtomicBool;

use anyhow::{Context, bail, ensure};
use cw_core::NotFound;
use cw_core::{Code, ErrorBody, Fail};
use cw_modelfiles::ModelFile;
use cw_modelfiles::{self as fetching, Begun, Fetches, Seen};
use cw_platform::http::Client;
use serde::Serialize;
use ts_rs::TS;

use crate::local;

/// A model Cardwave offers to download: its name on the page, its file's name
/// in the folder, and where the file comes from.
#[derive(Clone, Debug)]
pub struct Offered {
    pub name: String,
    pub file_name: String,
    pub file: ModelFile,
}

/// Cardwave's list: name, Hugging Face repository, file, size in bytes and
/// SHA-256, as the repository's listing gave them (2026-10-23), smallest first.
const LIST: &[(&str, &str, &str, u64, &str)] = &[
    (
        "Qwen3 1.7B",
        "unsloth/Qwen3-1.7B-GGUF",
        "Qwen3-1.7B-Q4_K_M.gguf",
        1_107_409_472,
        "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897",
    ),
    (
        "Llama 3.2 3B Instruct",
        "bartowski/Llama-3.2-3B-Instruct-GGUF",
        "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
        2_019_377_696,
        "6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff",
    ),
    (
        "Gemma 3 4B",
        "unsloth/gemma-3-4b-it-GGUF",
        "gemma-3-4b-it-Q4_K_M.gguf",
        2_489_894_016,
        "04a43a22e8d2003deda5acc262f68ec1005fa76c735a9962a8c77042a74a7d19",
    ),
    (
        "Qwen3 4B",
        "unsloth/Qwen3-4B-GGUF",
        "Qwen3-4B-Q4_K_M.gguf",
        2_497_281_312,
        "f6f851777709861056efcdad3af01da38b31223a3ba26e61a4f8bf3a2195813a",
    ),
    (
        "Qwen3 8B",
        "unsloth/Qwen3-8B-GGUF",
        "Qwen3-8B-Q4_K_M.gguf",
        5_027_784_512,
        "120307ba529eb2439d6c430d94104dabd578497bc7bfe7e322b5d9933b449bd4",
    ),
    (
        "Gemma 3 12B",
        "unsloth/gemma-3-12b-it-GGUF",
        "gemma-3-12b-it-Q4_K_M.gguf",
        7_300_778_336,
        "15b8fd9d8672cd4240c178c217ca781409291f34e353d2e913b29c7602ceb3ff",
    ),
    (
        "Mistral Nemo Instruct",
        "bartowski/Mistral-Nemo-Instruct-2407-GGUF",
        "Mistral-Nemo-Instruct-2407-Q4_K_M.gguf",
        7_477_208_192,
        "7c1a10d202d8788dbe5628dc962254d10654c853cae6aaeca0618f05490d4a46",
    ),
    (
        "Qwen3 14B",
        "unsloth/Qwen3-14B-GGUF",
        "Qwen3-14B-Q4_K_M.gguf",
        9_001_753_984,
        "5eaa0870bd81ed3b58a630a271234cfa604e43ffb3a19cd68e54a80dd9d52a66",
    ),
    (
        "Mistral Small 3.2 24B",
        "unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF",
        "Mistral-Small-3.2-24B-Instruct-2506-Q4_K_M.gguf",
        14_333_922_848,
        "a3cc56310807ed0d145eaf9f018ccda9ae7ad8edb41ec870aa2454b0d4700b3c",
    ),
    (
        "Qwen3 30B A3B",
        "unsloth/Qwen3-30B-A3B-GGUF",
        "Qwen3-30B-A3B-Q4_K_M.gguf",
        18_556_686_912,
        "9f1a24700a339b09c06009b729b5c809e0b64c213b8af5b711b3dbdfd0c5ba48",
    ),
    (
        "Qwen3 32B",
        "unsloth/Qwen3-32B-GGUF",
        "Qwen3-32B-Q4_K_M.gguf",
        19_762_150_048,
        "8df67573b2c23484e02ec7af295e39bed7ee774f3771d5fda2978265b59370e7",
    ),
    (
        "Llama 3.3 70B Instruct",
        "bartowski/Llama-3.3-70B-Instruct-GGUF",
        "Llama-3.3-70B-Instruct-Q4_K_M.gguf",
        42_520_398_816,
        "32df3baccb556f9840059b2528b2dee4d3d516b24afdfb9d0c56ff5f63e3a664",
    ),
];

/// Cardwave's list of models to download.
pub fn offered() -> Vec<Offered> {
    LIST.iter()
        .map(|(name, repo, file, size, sha256)| Offered {
            name: (*name).into(),
            file_name: (*file).into(),
            file: ModelFile {
                url: format!("https://huggingface.co/{repo}/resolve/main/{file}"),
                size: *size,
                sha256: (*sha256).into(),
            },
        })
        .collect()
}

/// Whether a model of `size` bytes fits a computer of `memory` bytes: where
/// the memory cannot be told, every model does. The other half is Windows',
/// the app's and the model's context.
pub fn fits(size: u64, memory: Option<u64>) -> bool {
    memory.is_none_or(|memory| size <= memory / 2)
}

/// Where a model of the folder's list is.
#[derive(Serialize, TS, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
#[ts(export)]
pub enum FitState {
    Absent,
    Downloading,
    Downloaded,
}

/// A model as the box "This computer" lists it.
#[derive(Serialize, TS, Debug)]
#[ts(export)]
pub struct FitModel {
    /// Its file's name in the folder: its name at This computer, as a kind picks it.
    pub file: String,
    /// Cardwave's name for it, else its file's name.
    pub name: String,
    /// In bytes; a split model's parts together.
    #[ts(type = "number")]
    pub size: u64,
    pub fits: bool,
    /// Whether it is of Cardwave's list, which downloads and removes it.
    pub offered: bool,
    pub state: FitState,
    /// The bytes downloaded so far.
    #[ts(type = "number")]
    pub done: u64,
    /// Why its last download failed.
    pub failure: Option<ErrorBody>,
}

/// The box's list: this computer's memory and its models.
#[derive(Serialize, TS, Debug)]
#[ts(export)]
pub struct FitView {
    /// In bytes, where it can be told.
    #[ts(type = "number | null")]
    pub memory: Option<u64>,
    /// Cardwave's list in its order, then the folder's other models by name.
    pub models: Vec<FitModel>,
}

/// Cardwave's list, and how far each of its downloads is.
pub struct Downloads {
    offered: Vec<Offered>,
    http: Client,
    /// By the file each writes, so that a download is of its folder alone.
    fetches: Fetches<PathBuf>,
}

impl Downloads {
    pub fn new(offered: Vec<Offered>) -> anyhow::Result<Self> {
        Ok(Self {
            offered,
            http: fetching::client()?,
            fetches: Fetches::default(),
        })
    }

    fn offer(&self, file: &str) -> anyhow::Result<&Offered> {
        Ok(self
            .offered
            .iter()
            .find(|offered| offered.file_name == file)
            .ok_or(NotFound("model"))?)
    }

    /// The list of the box for the models' `folder`.
    pub fn list(&self, folder: &Path) -> anyhow::Result<FitView> {
        let memory = cw_platform::sys::memory();
        let there = local::models(folder)?;
        let mut models: Vec<FitModel> = self
            .offered
            .iter()
            .map(|offered| {
                let (state, done, failure) =
                    match self.fetches.state(&folder.join(&offered.file_name)) {
                        Seen::Running(done) => (FitState::Downloading, done, None),
                        _ if there.contains(&offered.file_name) => (FitState::Downloaded, 0, None),
                        Seen::Failed(why) => (FitState::Absent, 0, Some(why)),
                        Seen::Idle => (FitState::Absent, 0, None),
                    };
                FitModel {
                    file: offered.file_name.clone(),
                    name: offered.name.clone(),
                    size: offered.file.size,
                    fits: fits(offered.file.size, memory),
                    offered: true,
                    state,
                    done,
                    failure,
                }
            })
            .collect();
        for file in there {
            if self.offered.iter().any(|offered| offered.file_name == file) {
                continue;
            }
            let size = size_in(folder, &file);
            models.push(FitModel {
                name: file.clone(),
                file,
                size,
                fits: fits(size, memory),
                offered: false,
                state: FitState::Downloaded,
                done: 0,
                failure: None,
            });
        }
        Ok(FitView { memory, models })
    }

    /// Marks the model `file` of the list as downloading into `folder` and
    /// answers what stops it, or none where it is downloading already. A
    /// model too large for this computer, or there already, is refused.
    pub fn begin(&self, file: &str, folder: &Path) -> anyhow::Result<Option<Arc<AtomicBool>>> {
        let offered = self.offer(file)?;
        ensure!(
            fits(offered.file.size, cw_platform::sys::memory()),
            Fail::said(
                Code::TooBig,
                format!("{} is too large for this computer", offered.name)
            )
            .with("what", "model_for_computer")
            .with("name", (offered.name).to_string())
        );
        let lower = file.to_lowercase();
        let there = local::models(folder)?;
        ensure!(
            !there.iter().any(|name| name.to_lowercase() == lower),
            Fail::said(
                Code::Taken,
                format!("{} is in the folder already", offered.name)
            )
            .with("what", "model_file")
            .with("name", (offered.name).to_string())
        );
        match self.fetches.begin(&folder.join(file)) {
            Begun::Started(stop) => Ok(Some(stop)),
            Begun::Running => Ok(None),
            Begun::Stopping => bail!(
                Fail::said(
                    Code::NotNow,
                    "its download is being cancelled; try again in a moment"
                )
                .with("what", "download_cancelling")
            ),
        }
    }

    /// Downloads the model `file`, begun by [`Self::begin`], into `folder`,
    /// telling `told` at each hundredth and at its end, until `stop` is set.
    pub async fn fetch(&self, file: &str, folder: &Path, stop: &AtomicBool, told: impl Fn()) {
        let to = folder.join(file);
        let fetched = match self.offer(file) {
            Ok(offered) => {
                let progress = self.fetches.progress(&to, offered.file.size, &told);
                fetching::download_file(&self.http, &offered.file, &to, progress, stop).await
            }
            Err(failure) => Err(failure),
        };
        self.fetches.finish(&to, fetched, file);
        told();
    }

    /// Stops the model `file`'s download into `folder`; whether one ran.
    pub fn cancel(&self, file: &str, folder: &Path) -> bool {
        self.fetches.cancel(&folder.join(file))
    }

    /// Removes the model `file` of the list from `folder`, letting it go first
    /// where it is loaded.
    pub async fn remove(&self, file: &str, folder: &Path) -> anyhow::Result<()> {
        self.offer(file)?;
        if matches!(self.fetches.state(&folder.join(file)), Seen::Running(_)) {
            bail!(
                Fail::said(Code::NotNow, "the model is being downloaded")
                    .with("what", "model_downloading")
            );
        }
        let path = folder.join(file);
        local::let_go_of(&path).await?;
        match tokio::fs::remove_file(&path).await {
            Err(failure) if failure.kind() != std::io::ErrorKind::NotFound => Err(failure)
                .with_context(|| {
                    Fail::said(
                        Code::NotPossible,
                        format!("{} cannot be removed", path.display()),
                    )
                    .with("what", "model_remove")
                    .with("path", (path.display()).to_string())
                })?,
            _ => {}
        }
        // A failed download's word goes with it.
        self.fetches.forget_failure(&path);
        Ok(())
    }
}

/// The bytes of the model `file` in `folder`: of all its parts where it is
/// split (`…-00001-of-00003.gguf`).
fn size_in(folder: &Path, file: &str) -> u64 {
    let size = |path: &Path| std::fs::metadata(path).map_or(0, |meta| meta.len());
    let (Some((stem, _, count)), Ok(read)) = (local::split_name(file), std::fs::read_dir(folder))
    else {
        return size(&folder.join(file));
    };
    let (head, tail) = (format!("{stem}-"), format!("-of-{count:05}.gguf"));
    read.filter_map(Result::ok)
        .filter(|entry| {
            let name = entry.file_name().to_string_lossy().to_lowercase();
            name.starts_with(&head) && name.ends_with(&tail)
        })
        .map(|entry| size(&entry.path()))
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_model_fits_in_half_the_memory() {
        let gb = 1 << 30;
        assert!(fits(4 * gb, Some(8 * gb)));
        assert!(!fits(4 * gb + 1, Some(8 * gb)));
        assert!(fits(u64::MAX, None));
    }

    #[test]
    fn a_split_model_is_as_large_as_its_parts() {
        let folder = std::env::temp_dir().join(format!("cardwave-fit-{}", std::process::id()));
        std::fs::create_dir_all(&folder).unwrap();
        let files = [
            ("Big-00001-of-00002.gguf", 3),
            ("Big-00002-of-00002.gguf", 4),
            ("one.gguf", 5),
        ];
        for (name, bytes) in files {
            std::fs::write(folder.join(name), vec![0; bytes]).unwrap();
        }
        let sizes = [
            size_in(&folder, "Big-00001-of-00002.gguf"),
            size_in(&folder, "one.gguf"),
        ];
        std::fs::remove_dir_all(&folder).unwrap();
        assert_eq!(sizes, [7, 5]);
    }

    #[test]
    fn the_list_is_smallest_first_and_each_file_once() {
        let list = offered();
        assert!(
            list.windows(2)
                .all(|two| two[0].file.size <= two[1].file.size)
        );
        let mut files: Vec<_> = list.iter().map(|one| &one.file_name).collect();
        files.dedup();
        assert_eq!(files.len(), LIST.len());
    }
}

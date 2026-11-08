//! The faces on a picture, found by YuNet (2023mar, MIT, Shiqi Yu; `yunet.onnx`, 232,589 bytes, inside the app).
//!
//! The model runs on the graphics card, never on the processor: through Windows ML, which comes with Windows
//! (`winml.rs`), so no runtime is added; elsewhere, and on a computer with no graphics card, [`Finder::open`]
//! fails and no picture has faces. This crate alone names `windows`; what is here beside it is plain arithmetic.
//!
//! A picture is looked at twice, its longest side at 640 pixels and at 320 (a face filling a picture is too large
//! for the first), top-left on a black square of 640. Each pass answers per stride a score and a box per cell.
//! The boxes of both are merged, the surest first. A box is in fractions of the picture, cut at its edges.
//! Trap: a Finder keeps video memory: hold it for a round, no longer.

use anyhow::Result;
use image::RgbImage;
use image::imageops::{FilterType, resize};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

#[cfg(not(windows))]
#[path = "elsewhere.rs"]
mod engine;
#[cfg(windows)]
#[path = "winml.rs"]
mod engine;

/// The square the model reads.
const SQUARE: u32 = 640;
/// The picture's longest side in each pass.
const PASSES: [u32; 2] = [640, 320];
/// How sure the model must be of a face.
const SURE: f32 = 0.7;
/// How much two boxes may overlap and be two faces.
const SAME: f32 = 0.3;
/// The model's strides, its outputs `cls_8`, `obj_8`, `bbox_8` and so on.
#[cfg(windows)]
const STRIDES: [u32; 3] = [8, 16, 32];

/// Where a face is, in fractions of the picture's width and height.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Face {
    pub left: f32,
    pub top: f32,
    pub width: f32,
    pub height: f32,
}

/// The model's answer for one stride: per cell a class and an object score, and four numbers of a box.
struct Stride {
    stride: u32,
    cls: Vec<f32>,
    obj: Vec<f32>,
    bbox: Vec<f32>,
}

/// The model, open on the graphics card.
pub struct Finder(engine::Session);

impl Finder {
    /// Fails where there is no graphics card to run it on: it never runs on the processor.
    pub fn open() -> Result<Self> {
        Ok(Self(engine::Session::open()?))
    }

    /// The faces on a picture, the surest first.
    pub fn find(&self, picture: &RgbImage) -> Result<Vec<Face>> {
        let mut found = vec![];
        for side in PASSES {
            let (scale, tensor) = square(picture, side);
            let answer = self.0.pass(&tensor)?;
            found.extend(boxes(&answer, scale, picture.width(), picture.height()));
        }
        Ok(merged(found))
    }
}

/// The picture scaled to `side`, top-left on the black square, as the model reads it: blue, green, red planes of
/// 0 to 255. With the scale.
fn square(picture: &RgbImage, side: u32) -> (f32, Vec<f32>) {
    let scale = side as f32 / picture.width().max(picture.height()).max(1) as f32;
    let at = |length: u32| (((length as f32) * scale) as u32).clamp(1, SQUARE);
    let small = resize(
        picture,
        at(picture.width()),
        at(picture.height()),
        FilterType::Triangle,
    );
    let cells = (SQUARE * SQUARE) as usize;
    let mut tensor = vec![0f32; 3 * cells];
    for (x, y, pixel) in small.enumerate_pixels() {
        let cell = (y * SQUARE + x) as usize;
        tensor[cell] = pixel[2] as f32;
        tensor[cells + cell] = pixel[1] as f32;
        tensor[2 * cells + cell] = pixel[0] as f32;
    }
    (scale, tensor)
}

/// The sure boxes of a pass's answer, with their scores, in fractions of a picture `wide` by `high`.
fn boxes(answer: &[Stride], scale: f32, wide: u32, high: u32) -> Vec<(f32, Face)> {
    let mut found = vec![];
    for one in answer {
        let cells = SQUARE / one.stride;
        let stride = one.stride as f32;
        for row in 0..cells {
            for column in 0..cells {
                let cell = (row * cells + column) as usize;
                let (Some(&cls), Some(&obj), Some(bbox)) = (
                    one.cls.get(cell),
                    one.obj.get(cell),
                    one.bbox.get(cell * 4..cell * 4 + 4),
                ) else {
                    continue;
                };
                let score = (cls.clamp(0., 1.) * obj.clamp(0., 1.)).sqrt();
                if score < SURE {
                    continue;
                }
                let (w, h) = (bbox[2].exp() * stride, bbox[3].exp() * stride);
                let (x, y) = (
                    (column as f32 + bbox[0]) * stride - w / 2.,
                    (row as f32 + bbox[1]) * stride - h / 2.,
                );
                let span = |start: f32, length: f32, whole: u32| {
                    let whole = whole as f32 * scale;
                    let from = (start / whole).clamp(0., 1.);
                    (from, ((start + length) / whole).clamp(0., 1.) - from)
                };
                let (left, width) = span(x, w, wide);
                let (top, height) = span(y, h, high);
                found.push((
                    score,
                    Face {
                        left,
                        top,
                        width,
                        height,
                    },
                ));
            }
        }
    }
    found
}

/// How much two boxes overlap: their shared area over their joined area.
fn overlap(a: &Face, b: &Face) -> f32 {
    let wide = (a.left + a.width).min(b.left + b.width) - a.left.max(b.left);
    let high = (a.top + a.height).min(b.top + b.height) - a.top.max(b.top);
    let shared = wide.max(0.) * high.max(0.);
    let joined = a.width * a.height + b.width * b.height - shared;
    if joined > 0. { shared / joined } else { 0. }
}

/// The boxes left, the surest first, each with none surer on the same face.
fn merged(mut found: Vec<(f32, Face)>) -> Vec<Face> {
    found.sort_by(|a, b| b.0.total_cmp(&a.0));
    let mut kept: Vec<Face> = vec![];
    for (_, face) in found {
        if kept.iter().all(|other| overlap(other, &face) <= SAME) {
            kept.push(face);
        }
    }
    kept
}

#[cfg(test)]
mod tests;

//! A card's picture made small, for the lists. A list draws a picture a few
//! dozen pixels wide, and the whole one has millions: read whole, each line
//! of a list costs the browser a megabyte and more to fetch and to unpack. So
//! a list asks for the picture in one of a few sizes ([`Size`]). A small
//! picture is made when it is first asked for and kept in the database beside
//! the picture it is of, encrypted as that is. It can be made again at any
//! time: it goes with its picture, at the server's start when no list asks
//! for its size any more, and when its user clears the cache ([`clear`]).
//!
//! `Size` is the sizes, each called by the pixels of its box on the wire
//! (`ThumbnailSize` in the UI); `shrink` scales a PNG down with the crate
//! `image`, as a JPEG, or as a PNG where it is see-through; `kept` and `make`
//! read and keep them (`Storage`, the table `thumbnails`); who makes a
//! small picture takes a turn first (`Turns`, a `Turn`) and hands it to `make`,
//! as `small_image` in `api/cards.rs` does; `remove_unasked` runs at the
//! server's start. How much a user's small pictures take and throwing them away
//! are `size` and `clear`.

use std::io::Cursor;
use std::sync::Arc;

use image::codecs::jpeg::JpegEncoder;
use image::codecs::png::PngEncoder;
use image::imageops::{self, FilterType};
use image::{
    DynamicImage, GenericImageView, ImageBuffer, ImageDecoder, ImageEncoder, ImageFormat,
    ImageReader, ImageResult, PixelWithColorType, Rgba, RgbaImage,
};
use serde::Deserialize;
use tokio::sync::{Mutex, OwnedMutexGuard};
use ts_rs::TS;

use crate::cards;

/// The sizes a picture is made small in: the box, in pixels, that the small
/// picture fills. A size is called by its pixels in the address of a small
/// picture (`?size=96x128`), which a browser keeps for a year: a size that is
/// changed has another address.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, TS)]
#[ts(export, rename = "ThumbnailSize")]
pub enum Size {
    /// For a line of a list, which draws the picture 48 by 64, on a screen
    /// with two pixels to the point.
    #[serde(rename = "96x128")]
    Row,
    /// For a tile of the Gallery, 2:3 and up to 248 wide where three or more
    /// stand side by side, grown by 3% when pointed at, on such a screen; and
    /// for Discovery, which draws the picture up to 300 high.
    #[serde(rename = "512x768")]
    Tile,
}

impl Size {
    pub const ALL: [Self; 2] = [Self::Row, Self::Tile];

    /// Width and height of the box.
    pub fn pixels(self) -> (u32, u32) {
        match self {
            Self::Row => (96, 128),
            Self::Tile => (512, 768),
        }
    }
}

/// A picture of more pixels is not made small, and the lists get the whole
/// one, as they did: unpacked, a picture takes four bytes a pixel and more,
/// and several are unpacked at once. Art of 4096 by 6144 is under it.
pub(crate) const MAX_PIXELS: u64 = 32_000_000;

/// How many pictures are made small at once, at most. More gain little, and
/// each holds its whole picture unpacked.
const AT_ONCE: usize = 4;

/// Of 100. Under it fine lines of a drawing smear; over it the file grows fast.
const JPEG_QUALITY: u8 = 85;

/// What the database has of a version's picture in a size.
pub enum Kept {
    Small(Vec<u8>),
    /// None yet. The number is the picture's, in `blobs`.
    NotYet(i64),
}

/// What the small pictures need of the database, which `cw_store::thumbnails` gives.
pub trait Storage: crate::cards::Storage {
    /// The small picture of `size` (its pixels) of a card version of
    /// `user`'s, or the picture's number where it is not made yet.
    fn small_image(
        &self,
        user: i64,
        version_id: i64,
        size: (u32, u32),
    ) -> anyhow::Result<Option<Kept>>;
    /// Keeps a small picture of the picture `picture`, unless that is gone.
    fn keep_small_image(&self, picture: i64, size: (u32, u32), small: &[u8]) -> anyhow::Result<()>;
    /// Throws away those of other sizes than `asked`.
    fn remove_small_images_but(&self, asked: &[(u32, u32)]) -> anyhow::Result<()>;
    /// How many bytes the user's are.
    fn small_images_size(&self, user: i64) -> anyhow::Result<i64>;
    fn clear_small_images(&self, user: i64) -> anyhow::Result<()>;
}

/// The small picture of a card version of `user`'s, if it was made already;
/// `None` when there is no such version. Short: it only reads.
pub fn kept(
    db: &dyn Storage,
    user: i64,
    version_id: i64,
    size: Size,
) -> anyhow::Result<Option<Kept>> {
    db.small_image(user, version_id, size.pixels())
}

/// The small picture of a card version of `user`'s, made and kept if it was
/// not there; `None` when there is no such version. Where no smaller one can
/// be made ([`shrink`]), the answer is the whole picture, and nothing is kept.
///
/// Making one takes a moment, in which the database is free: it is asked
/// before and after. It is made in a turn taken for the picture ([`Turns`]),
/// which lasts until it is made.
pub fn make(
    db: &dyn Storage,
    _turn: Turn,
    user: i64,
    version_id: i64,
    size: Size,
) -> anyhow::Result<Option<Vec<u8>>> {
    let picture = match kept(db, user, version_id, size)? {
        None => return Ok(None),
        // Made by the one whose turn was before this one.
        Some(Kept::Small(small)) => return Ok(Some(small)),
        Some(Kept::NotYet(picture)) => picture,
    };
    let Some(whole) = cards::image(db, user, version_id)? else {
        return Ok(None);
    };
    let Some(small) = shrink(&whole, size) else {
        return Ok(Some(whole));
    };
    // The picture may have gone meanwhile, with its card deleted for good.
    db.keep_small_image(picture, size.pixels(), &small)?;
    Ok(Some(small))
}

/// Throws away the small pictures of sizes that no list asks for any more.
/// Run at the server's start, so it looks for them in the table's index, which
/// is a few bytes a row: asked of the table itself, it reads every row.
pub fn remove_unasked(db: &dyn Storage) -> anyhow::Result<()> {
    db.remove_small_images_but(&Size::ALL.map(Size::pixels))
}

/// How many bytes `user`'s small pictures are, as they are kept: the files
/// themselves, without what the database needs around them. A sum over the
/// table's rows, so it is asked when someone wants to know, and not at the
/// server's start.
pub fn size(db: &dyn Storage, user: i64) -> anyhow::Result<u64> {
    let bytes = db.small_images_size(user)?;
    Ok(bytes.unsigned_abs())
}

/// Throws away `user`'s small pictures; the pictures they are of stay. Each is
/// made again when a list asks for it. It waits for no turn: one that is being
/// made meanwhile is kept afterwards. The room they took stays the database's
/// file's, for what is written next.
pub fn clear(db: &dyn Storage, user: i64) -> anyhow::Result<()> {
    db.clear_small_images(user)
}

/// A PNG scaled down until it just fills the box of `size`, in its own shape
/// (the list cuts off what stands over), as a JPEG; as a PNG if it is
/// see-through in places, which a JPEG cannot be. Its colour profile comes
/// along, unless it is a picture of greys. Of a picture that moves, it is the
/// picture that stands still.
///
/// `None` where there is no smaller picture to make: one side is no longer
/// than the box's, so it is never enlarged; it has too many pixels
/// ([`MAX_PIXELS`]); or it cannot be read as a picture.
pub(crate) fn shrink(whole: &[u8], size: Size) -> Option<Vec<u8>> {
    shrunk(whole, size).unwrap_or_else(|error| {
        tracing::debug!("a picture cannot be made small: {error}");
        None
    })
}

fn shrunk(whole: &[u8], size: Size) -> ImageResult<Option<Vec<u8>>> {
    let mut decoder =
        ImageReader::with_format(Cursor::new(whole), ImageFormat::Png).into_decoder()?;
    let (wide, high) = decoder.dimensions();
    let Some((width, height)) = fitted((wide, high), size.pixels()) else {
        return Ok(None);
    };
    if u64::from(wide) * u64::from(high) > MAX_PIXELS {
        return Ok(None);
    }
    // A profile that cannot be read is done without. So is that of a picture
    // of greys, which is one for greys: the small picture is written in
    // colours, which it does not fit.
    let profile = if decoder.color_type().has_color() {
        decoder.icc_profile().ok().flatten()
    } else {
        None
    };
    let picture = DynamicImage::from_decoder(decoder)?;

    let mut small = Vec::new();
    let picture = if picture.color().has_alpha() {
        let picture = picture.into_rgba8();
        if picture.pixels().any(|pixel| pixel[3] != u8::MAX) {
            let picture = shrink_see_through(&picture, width, height);
            written(&picture, PngEncoder::new(&mut small), profile)?;
            return Ok(Some(small));
        }
        DynamicImage::ImageRgba8(picture)
    } else {
        picture
    };
    let picture = picture
        .resize_exact(width, height, FilterType::Lanczos3)
        .into_rgb8();
    let encoder = JpegEncoder::new_with_quality(&mut small, JPEG_QUALITY);
    written(&picture, encoder, profile)?;
    Ok(Some(small))
}

/// Writes a picture as the encoder's kind of file, with its colour profile. A
/// profile the encoder does not take is done without.
fn written<P: PixelWithColorType<Subpixel = u8>>(
    picture: &ImageBuffer<P, Vec<u8>>,
    mut encoder: impl ImageEncoder,
    profile: Option<Vec<u8>>,
) -> ImageResult<()> {
    if let Some(profile) = profile {
        // A profile the encoder does not take is done without.
        let _ = encoder.set_icc_profile(profile);
    }
    picture.write_with_encoder(encoder)
}

/// Width and height of a picture scaled down until it just fills `frame`: one
/// side as long as the frame's, the other no shorter. `None` for a picture
/// that would have to grow, or stay as it is, for that.
fn fitted((width, height): (u32, u32), (wide, high): (u32, u32)) -> Option<(u32, u32)> {
    let scale = f64::max(
        f64::from(wide) / f64::from(width),
        f64::from(high) / f64::from(height),
    );
    let scaled = |side: u32| (f64::from(side) * scale).round() as u32;
    (scale < 1.0).then(|| (scaled(width), scaled(height)))
}

/// What shows in full, of 255.
const FULL: u16 = u8::MAX as u16;

/// A picture that is see-through in places, as it is read to be scaled: each
/// pixel's colour times how much of it shows. Read so, and not copied so, as
/// the copy would be twice the picture's size beside it.
struct Weighed<'a>(&'a RgbaImage);

impl GenericImageView for Weighed<'_> {
    type Pixel = Rgba<u16>;

    fn dimensions(&self) -> (u32, u32) {
        self.0.dimensions()
    }

    fn get_pixel(&self, x: u32, y: u32) -> Rgba<u16> {
        let [red, green, blue, shows] = self.0.get_pixel(x, y).0.map(u16::from);
        Rgba([red * shows, green * shows, blue * shows, shows * FULL])
    }
}

/// A picture that is see-through in places, scaled down. Each pixel's colour
/// counts by how much of it shows: counted in full, the colour a file gives
/// its see-through parts, mostly black, would run into the rims around them.
fn shrink_see_through(picture: &RgbaImage, width: u32, height: u32) -> RgbaImage {
    let weighed = imageops::resize(&Weighed(picture), width, height, FilterType::Lanczos3);
    let mut small = RgbaImage::new(width, height);
    for (to, from) in small.pixels_mut().zip(weighed.pixels()) {
        let [red, green, blue, shows] = from.0.map(u32::from);
        if shows == 0 {
            continue;
        }
        let full = u32::from(FULL);
        let colour = |weighed: u32| ((weighed * full + shows / 2) / shows).min(full) as u8;
        let shows = ((shows + full / 2) / full) as u8;
        *to = Rgba([colour(red), colour(green), colour(blue), shows]);
    }
    small
}

/// Whose turn it is to make small pictures. A list asks for many at once:
/// they are made side by side, [`AT_ONCE`] at most or one per processor,
/// and one picture by one at a time, so that who asks for it second finds it
/// made. Each picture has its place in a row of locks, by its number.
pub struct Turns(Vec<Arc<Mutex<()>>>);

/// A turn to make a picture small ([`Turns::take`]), which [`make`] is given.
/// It lasts until it is dropped.
pub struct Turn {
    _place: OwnedMutexGuard<()>,
}

impl Default for Turns {
    fn default() -> Self {
        let processors = std::thread::available_parallelism().map_or(1, usize::from);
        Self::of(processors.min(AT_ONCE))
    }
}

impl Turns {
    fn of(at_once: usize) -> Self {
        Self((0..at_once).map(|_| Arc::default()).collect())
    }

    /// Waits for the turn of the picture with this number in `blobs`. Who
    /// makes the picture takes it along, so that the turn does not end when
    /// the browser stops waiting.
    pub async fn take(&self, picture: i64) -> Turn {
        let place = Arc::clone(&self.0[self.place(picture)]);
        Turn {
            _place: place.lock_owned().await,
        }
    }

    /// A picture's place in the row. Not its number's remainder: pictures and
    /// a card's other files are numbered in one row, so the pictures of cards
    /// with three files each are four apart and would all have one place of
    /// four. The numbers are spread first (multiplied by 2^64 over the golden
    /// ratio, which sets numbers that are near each other far apart in the
    /// product's upper half), and the place is where in the row that falls.
    fn place(&self, picture: i64) -> usize {
        let spread = (picture as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15) >> 32;
        ((spread * self.0.len() as u64) >> 32) as usize
    }
}

#[cfg(test)]
mod tests {
    use futures_util::FutureExt;

    use super::*;

    /// A size is called by its pixels in an address, so a size that is changed
    /// is asked for under another address.
    #[test]
    fn a_size_is_called_by_the_pixels_of_its_box() {
        for size in Size::ALL {
            let (width, height) = size.pixels();
            let name = format!("\"{width}x{height}\"");
            assert_eq!(serde_json::from_str::<Size>(&name).unwrap(), size);
        }
    }

    #[test]
    fn one_picture_is_made_by_one_at_a_time_and_no_more_at_once_than_there_are_places() {
        let turns = Turns::of(2);
        // Pictures by their place of the two: those with the first one's, and the others.
        let (here, there): (Vec<i64>, Vec<i64>) =
            (1..20).partition(|picture| turns.place(*picture) == turns.place(1));
        let first = turns.take(here[0]).now_or_never().expect("free");
        // The same picture, and another one with the same place.
        assert!(turns.take(here[0]).now_or_never().is_none());
        assert!(turns.take(here[1]).now_or_never().is_none());
        let second = turns
            .take(there[0])
            .now_or_never()
            .expect("the other place");
        assert!(turns.take(there[1]).now_or_never().is_none());
        drop(first);
        assert!(turns.take(here[0]).now_or_never().is_some());
        drop(second);
        assert!(turns.take(there[1]).now_or_never().is_some());
        assert!(Turns::default().0.len() <= AT_ONCE);
    }

    /// A card's picture and its other files are numbered in one row, so the
    /// pictures of cards with as many files each are as far apart.
    #[test]
    fn pictures_numbered_evenly_apart_do_not_share_one_place() {
        let turns = Turns::of(4);
        for apart in 1..=8 {
            let mut places: Vec<usize> = (0..16).map(|n| turns.place(1 + n * apart)).collect();
            places.sort_unstable();
            places.dedup();
            assert_eq!(places, [0, 1, 2, 3], "{apart} apart");
        }
    }
}

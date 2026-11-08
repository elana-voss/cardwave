//! The faces on the pictures of the cards' newest versions: looked for once per picture and kept with it, so a
//! changed picture, a new row in `blobs`, is looked at anew. A picture that is no art, or cannot be read, keeps no
//! faces and opens no model. `look_once` is one step, on the thread that holds the eyes for the whole round.

use std::sync::Arc;

pub use cw_faces::Face;
use cw_faces::Finder;
use image::RgbImage;

use crate::cards::pictures::is_art;

/// What looking for faces needs of the database, which `cw_store::faces` gives.
pub trait Storage {
    /// A picture of a card's newest version, whoever's, with no faces kept: its row in `blobs` and its file.
    fn next_without_faces(&self) -> anyhow::Result<Option<(i64, Vec<u8>)>>;
    fn keep_faces(&self, picture: i64, faces: &[Face]) -> anyhow::Result<()>;
}

/// What finds the faces; a test's own in place of the model.
pub trait Eyes {
    fn find(&self, picture: &RgbImage) -> anyhow::Result<Vec<Face>>;
}

impl Eyes for Finder {
    fn find(&self, picture: &RgbImage) -> anyhow::Result<Vec<Face>> {
        Finder::find(self, picture)
    }
}

/// Opens the eyes, for a round of looking. It fails where there is no graphics card to run them on.
pub type Opener = Arc<dyn Fn() -> anyhow::Result<Box<dyn Eyes>> + Send + Sync>;

/// The model, as the app opens it.
pub fn the_model() -> Opener {
    Arc::new(|| Ok(Box::new(Finder::open()?)))
}

/// Looks at the next picture, opening `eyes` where they are needed and not open. Answers whether there was one.
/// A failure keeps nothing, so that the picture is looked at again.
pub fn look_once(
    db: &dyn Storage,
    eyes: &mut Option<Box<dyn Eyes>>,
    open: &Opener,
) -> anyhow::Result<bool> {
    let Some((id, file)) = db.next_without_faces()? else {
        return Ok(false);
    };
    let picture = if is_art(&file) {
        // One that cannot be read keeps no faces, as one that is no art.
        image::load_from_memory(&file).ok()
    } else {
        None
    };
    let faces = match picture {
        Some(picture) => {
            let eyes = match eyes {
                Some(eyes) => eyes,
                None => eyes.insert(open()?),
            };
            eyes.find(&picture.to_rgb8())?
        }
        None => Vec::new(),
    };
    db.keep_faces(id, &faces)?;
    Ok(true)
}

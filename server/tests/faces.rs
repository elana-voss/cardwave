//! The faces on a card's picture: looked for once per picture, behind the scenes, and in the list Posters asks for; a
//! changed picture is looked at anew. A stand-in looks in place of the model, whose own tests are in `cw-faces`.

mod common;

use std::io::Cursor;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use common::server::{Server, start_looking, until};
use cw_library::faces::{Eyes, Face, Opener};
use image::{ImageFormat, RgbImage};
use serde_json::Value;
use tokio::time::sleep;

/// What the stand-in was asked: how often it was opened and looked.
#[derive(Default)]
struct Asked {
    opened: AtomicUsize,
    looked: AtomicUsize,
}

struct StandIn(Arc<Asked>);

impl Eyes for StandIn {
    /// A box whose left edge tells the picture by its width.
    fn find(&self, picture: &RgbImage) -> anyhow::Result<Vec<Face>> {
        self.0.looked.fetch_add(1, Ordering::SeqCst);
        Ok(vec![Face {
            left: picture.width() as f32 / 100.0,
            top: 0.0,
            width: 0.5,
            height: 0.5,
        }])
    }
}

fn opener(asked: &Arc<Asked>) -> Opener {
    let asked = asked.clone();
    Arc::new(move || {
        asked.opened.fetch_add(1, Ordering::SeqCst);
        Ok(Box::new(StandIn(asked.clone())))
    })
}

/// A PNG `width` pixels wide, of one colour; the colour makes it another picture.
fn painted(width: u32, shade: u8) -> Vec<u8> {
    let picture = RgbImage::from_pixel(width, 60, image::Rgb([shade, 120, 40]));
    let mut file = Cursor::new(Vec::new());
    picture.write_to(&mut file, ImageFormat::Png).unwrap();
    file.into_inner()
}

/// What the only card's poster shows, as Posters asks the list.
async fn listed(server: &Server) -> Value {
    let (status, list) = server.get("/api/cards?posters=true").await;
    assert_eq!(status, 200, "{list}");
    list[0]["poster"].clone()
}

/// Asks the list until the card's box stands where `left` says.
async fn box_at(server: &Server, left: f64) {
    until(|| async {
        let found = listed(server).await["faces"][0]["left"].as_f64();
        match found.is_some_and(|found| (found - left).abs() < 0.001) {
            true => Ok(()),
            false => Err(format!("no box at {left}: {found:?}")),
        }
    })
    .await
}

/// Time for a round the list asked for to have come and gone.
async fn a_round_later(server: &Server) {
    listed(server).await;
    sleep(Duration::from_millis(200)).await;
}

async fn imported(server: &Server) -> String {
    let (status, card) = server.upload("/api/cards", common::card_copy()).await;
    assert_eq!(status, 201, "{card}");
    format!("/api/cards/{}/pictures", card["card_id"])
}

#[tokio::test]
async fn a_picture_is_looked_at_once_and_a_changed_one_anew() {
    let asked = Arc::new(Asked::default());
    let server = start_looking(opener(&asked)).await;
    let pictures = imported(&server).await;

    // The sample card's picture of one pixel is no art: no boxes, and the model stays shut.
    a_round_later(&server).await;
    assert_eq!(listed(&server).await["faces"], serde_json::json!([]));
    assert_eq!(asked.opened.load(Ordering::SeqCst), 0);

    let (status, kept) = server.upload(&pictures, painted(40, 200)).await;
    assert_eq!(status, 200, "{kept}");
    box_at(&server, 0.4).await;
    a_round_later(&server).await;
    assert_eq!(asked.looked.load(Ordering::SeqCst), 1);

    let (status, kept) = server.upload(&pictures, painted(30, 100)).await;
    assert_eq!(status, 200, "{kept}");
    box_at(&server, 0.3).await;
    a_round_later(&server).await;
    assert_eq!(asked.looked.load(Ordering::SeqCst), 2);
}

#[tokio::test]
async fn where_the_model_cannot_be_opened_it_is_tried_once_and_the_card_has_no_boxes() {
    let tried = Arc::new(AtomicUsize::new(0));
    let counted = tried.clone();
    let server = start_looking(Arc::new(move || {
        counted.fetch_add(1, Ordering::SeqCst);
        anyhow::bail!("no graphics card")
    }))
    .await;
    let pictures = imported(&server).await;
    let (status, kept) = server.upload(&pictures, painted(40, 200)).await;
    assert_eq!(status, 200, "{kept}");

    a_round_later(&server).await;
    a_round_later(&server).await;
    assert_eq!(listed(&server).await["faces"], serde_json::json!([]));
    assert_eq!(tried.load(Ordering::SeqCst), 1);
}

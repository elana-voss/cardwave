//! A card's picture made small for the lists: its size and shape, what it is
//! written as, where it is kept and when it goes, and when the whole picture
//! is answered in its place.
//!
//! The pictures are made with the crate `image`: `fields` (four fields of one
//! colour each, so that the corners tell whether anything was cut off), `file`
//! (a picture as a PNG) and `card` (the sample card with that picture); `kept`
//! reads the table, `make` makes a small picture without a server and
//! `database` opens a running server's.

mod common;

use std::io::Cursor;

use common::Scratch;
use common::server::{Server, start};
use cw_accounts::users;
use cw_ccv4::png::{self, Container};
use cw_key::FILE_NAME;
use cw_library::cards;
use cw_library::thumbnails::{self, Kept, Size, Turns};
use cw_library::trash;
use cw_store::Db;
use futures_util::FutureExt;
use futures_util::future::join_all;
use image::codecs::png::PngEncoder;
use image::{
    DynamicImage, ExtendedColorType, GrayAlphaImage, GrayImage, ImageDecoder, ImageEncoder,
    ImageFormat, ImageReader, Luma, LumaA, Rgb, RgbImage, Rgba, RgbaImage,
};
use reqwest::Method;

const RED: [u8; 3] = [200, 30, 30];
const GREEN: [u8; 3] = [30, 160, 60];
const BLUE: [u8; 3] = [30, 60, 200];
const SAND: [u8; 3] = [220, 200, 150];

/// A picture as a PNG file.
fn file(picture: impl Into<DynamicImage>) -> Vec<u8> {
    let mut out = Cursor::new(Vec::new());
    picture.into().write_to(&mut out, ImageFormat::Png).unwrap();
    out.into_inner()
}

/// A picture of four fields, each of one colour: red and green over blue and sand.
fn fields(width: u32, height: u32) -> RgbImage {
    RgbImage::from_fn(width, height, |x, y| {
        Rgb(match (x < width / 2, y < height / 2) {
            (true, true) => RED,
            (false, true) => GREEN,
            (true, false) => BLUE,
            (false, false) => SAND,
        })
    })
}

/// The sample card with this picture.
fn card(image: Vec<u8>) -> Vec<u8> {
    png::write(&Container {
        image,
        ..common::container()
    })
    .unwrap()
}

/// Imports a card with this picture; its version.
async fn add(server: &Server, image: Vec<u8>) -> i64 {
    server.add_card(card(image), false).await.1
}

fn address(version: i64, size: &str) -> String {
    format!("/api/card-versions/{version}/image?size={size}")
}

/// What an answer is: its type by its first bytes, and the picture.
fn read(picture: &[u8]) -> (ImageFormat, DynamicImage) {
    (
        image::guess_format(picture).unwrap(),
        image::load_from_memory(picture).unwrap(),
    )
}

/// Whether a pixel has this colour, as near as a JPEG keeps one.
fn is(pixel: [u8; 3], colour: [u8; 3]) -> bool {
    pixel
        .iter()
        .zip(colour)
        .all(|(have, want)| have.abs_diff(want) <= 12)
}

/// The small pictures a database keeps: the box each was made for, in the order of their widths.
fn kept(db: &Db) -> Vec<(u32, u32)> {
    db.with(|conn| {
        conn.prepare("select width, height from thumbnails order by width, blob_id")?
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect()
    })
    .unwrap()
}

/// Makes a version's picture small for a line, as the server does: in a turn
/// taken for it. `None` when `user` has no such version.
fn make(db: &Db, user: i64, version: i64) -> Option<Vec<u8>> {
    let turn = Turns::default().take(version).now_or_never().unwrap();
    thumbnails::make(db, turn, user, version, Size::Row).unwrap()
}

/// The database of a running server, through a connection of its own.
fn database(server: &Server) -> Db {
    let options = server.options();
    Db::open(
        &options.data_dir.join(FILE_NAME),
        options.key.given().unwrap(),
    )
    .unwrap()
}

#[tokio::test]
async fn a_list_gets_the_picture_scaled_down_to_fill_its_box_in_its_own_shape() {
    let server = start().await;
    let whole = file(fields(1200, 1500));
    let version = add(&server, whole.clone()).await;

    // The box is 96 by 128 and 512 by 768: the picture is as high as it and wider.
    for (size, width, height) in [("96x128", 102, 128), ("512x768", 614, 768)] {
        let (headers, small) = server.download(&address(version, size)).await;
        let (format, picture) = read(&small);
        assert_eq!(format, ImageFormat::Jpeg, "{size}");
        assert_eq!(headers["content-type"], "image/jpeg", "{size}");
        assert_eq!((picture.width(), picture.height()), (width, height));
        // All of it is there, nothing cut off: each corner has its field's colour.
        let picture = picture.into_rgb8();
        let (right, foot) = (width - 3, height - 3);
        let corners = [
            (3, 3, RED),
            (right, 3, GREEN),
            (3, foot, BLUE),
            (right, foot, SAND),
        ];
        for (x, y, colour) in corners {
            let pixel = picture.get_pixel(x, y).0;
            assert!(is(pixel, colour), "{size} at {x}, {y}: {pixel:?}");
        }
        // A version's picture never changes, small or whole, so a browser keeps
        // it; and what comes out of a card is neither guessed at nor run.
        assert_eq!(
            headers["cache-control"],
            "private, max-age=31536000, immutable"
        );
        assert_eq!(headers["x-content-type-options"], "nosniff");
        assert_eq!(
            headers["content-security-policy"],
            "default-src 'none'; sandbox"
        );
    }

    // Without a size the picture is the whole one, as a card's page shows it.
    let (headers, answered) = server
        .download(&format!("/api/card-versions/{version}/image"))
        .await;
    assert_eq!(answered, whole);
    assert_eq!(headers["content-type"], "image/png");
}

#[tokio::test]
async fn a_picture_no_larger_than_the_box_is_answered_as_it_is() {
    let server = start().await;
    // As large as the box of a tile, wider but lower, higher but narrower, and
    // the one pixel of a card without art.
    let pictures = [
        file(fields(512, 768)),
        file(fields(900, 700)),
        file(fields(400, 2000)),
        common::picture(),
    ];
    for whole in pictures {
        let version = add(&server, whole.clone()).await;
        let (headers, answered) = server.download(&address(version, "512x768")).await;
        assert_eq!(answered, whole);
        assert_eq!(headers["content-type"], "image/png");
    }
    // Nothing is kept for them.
    assert_eq!(kept(&database(&server)), []);
}

#[tokio::test]
async fn a_see_through_picture_stays_see_through_and_its_rims_keep_their_colour() {
    let server = start().await;
    // White on the left; on the right nothing, which the file writes as black.
    let glass = RgbaImage::from_fn(800, 1200, |x, _| {
        Rgba(if x < 400 { [255; 4] } else { [0; 4] })
    });
    let version = add(&server, file(glass)).await;
    let (headers, small) = server.download(&address(version, "96x128")).await;
    let (format, picture) = read(&small);
    assert_eq!(format, ImageFormat::Png);
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!((picture.width(), picture.height()), (96, 144));
    let picture = picture.into_rgba8();
    assert_eq!(picture.get_pixel(2, 70).0, [255; 4]);
    assert_eq!(picture.get_pixel(93, 70).0[3], 0);
    // Where the two meet, the white shows less and less, and stays white: the
    // black behind the glass does not run into it.
    let rim: Vec<[u8; 4]> = (40..56).map(|x| picture.get_pixel(x, 70).0).collect();
    assert!(
        rim.iter().any(|pixel| (1..255).contains(&pixel[3])),
        "{rim:?}"
    );
    assert!(
        rim.iter()
            .filter(|pixel| pixel[3] > 0)
            .all(|pixel| pixel[..3] == [255; 3]),
        "{rim:?}"
    );

    // A picture that could be see-through and is not anywhere is a JPEG, as any other.
    let solid = DynamicImage::from(fields(800, 1200)).into_rgba8();
    let version = add(&server, file(solid)).await;
    let (headers, small) = server.download(&address(version, "96x128")).await;
    assert_eq!(read(&small).0, ImageFormat::Jpeg);
    assert_eq!(headers["content-type"], "image/jpeg");
}

#[tokio::test]
async fn the_colour_profile_of_a_picture_comes_along() {
    let server = start().await;
    let profile = b"what a screen is told about the colours".to_vec();
    let with_profile = |picture: DynamicImage| {
        let mut out = Vec::new();
        let mut encoder = PngEncoder::new(&mut out);
        encoder.set_icc_profile(profile.clone()).unwrap();
        let colour = ExtendedColorType::from(picture.color());
        encoder
            .write_image(
                picture.as_bytes(),
                picture.width(),
                picture.height(),
                colour,
            )
            .unwrap();
        out
    };
    let glass = RgbaImage::from_fn(800, 1200, |x, _| {
        Rgba(if x < 400 { [255; 4] } else { [0; 4] })
    });
    // The profile of the small picture of a card with this picture, and what it is written as.
    let small_of = async |picture: DynamicImage| {
        let version = add(&server, with_profile(picture)).await;
        let (_, small) = server.download(&address(version, "96x128")).await;
        let mut decoder = ImageReader::new(Cursor::new(&small))
            .with_guessed_format()
            .unwrap()
            .into_decoder()
            .unwrap();
        (decoder.icc_profile().unwrap(), read(&small).0)
    };
    // As a JPEG and as a PNG.
    let colours = small_of(fields(800, 1200).into()).await;
    assert_eq!(colours, (Some(profile.clone()), ImageFormat::Jpeg));
    assert_eq!(
        small_of(glass.into()).await,
        (Some(profile.clone()), ImageFormat::Png)
    );

    // A picture of greys has a profile for greys, and its small picture is
    // written in colours, which that does not fit: it stays behind.
    let greys = GrayImage::from_fn(800, 1200, |x, _| Luma([(x / 4) as u8]));
    assert_eq!(small_of(greys.into()).await, (None, ImageFormat::Jpeg));
    let glass = GrayAlphaImage::from_fn(800, 1200, |x, _| {
        LumaA(if x < 400 { [255; 2] } else { [0; 2] })
    });
    assert_eq!(small_of(glass.into()).await, (None, ImageFormat::Png));
}

#[tokio::test]
async fn a_small_picture_is_made_once_and_kept_with_the_picture_it_is_of() {
    let server = start().await;
    let sample = card(file(fields(1200, 1500)));
    let (_, imported) = server.upload("/api/cards", sample).await;
    let (card, first) = (imported["card_id"].clone(), imported["version_id"].clone());
    let first = first.as_i64().unwrap();
    let (_, small) = server.download(&address(first, "96x128")).await;
    let db = database(&server);
    assert_eq!(kept(&db), [(96, 128)]);

    // It is read from there the next time, not made again.
    let planted = [0xFF, 0xD8, 0xFF, 1, 2, 3];
    db.with(|conn| conn.execute("update thumbnails set data = ?1", [planted]))
        .unwrap();
    let (headers, answered) = server.download(&address(first, "96x128")).await;
    assert_eq!(answered, planted);
    assert_eq!(headers["content-type"], "image/jpeg");
    assert_ne!(small, planted);

    // The card edited has the same picture, and the small one with it.
    let (status, added) = server
        .edit_card(&card, |form| form["title"] = "Renamed".into())
        .await;
    assert_eq!(status, 200, "{added}");
    let second = added["id"].as_i64().unwrap();
    assert_ne!(second, first);
    let (_, answered) = server.download(&address(second, "96x128")).await;
    assert_eq!(answered, planted);
    // Each size is kept by itself.
    let (_, tile) = server.download(&address(second, "512x768")).await;
    assert_eq!(read(&tile).1.height(), 768);
    assert_eq!(kept(&db), [(96, 128), (512, 768)]);
}

#[test]
fn a_small_picture_goes_with_its_picture() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let stays = cards::import(db, me, &card(file(fields(1200, 1500)))).unwrap();
    let goes = cards::import(db, me, &card(file(fields(1500, 1200)))).unwrap();
    for version in [stays.version_id, goes.version_id] {
        let small = make(db, me, version).unwrap();
        assert_eq!(read(&small).0, ImageFormat::Jpeg);
    }
    assert_eq!(kept(db), [(96, 128), (96, 128)]);

    cards::set_trashed(db, me, goes.card_id, true).unwrap();
    assert_eq!(kept(db).len(), 2);
    trash::delete_card(db, me, goes.card_id).unwrap();
    assert_eq!(kept(db), [(96, 128)]);
    let left = thumbnails::kept(db, me, stays.version_id, Size::Row).unwrap();
    assert!(matches!(left, Some(Kept::Small(_))));
    assert!(
        thumbnails::kept(db, me, goes.version_id, Size::Row)
            .unwrap()
            .is_none()
    );
}

#[tokio::test]
async fn small_pictures_of_a_size_no_list_asks_for_go_at_the_start() {
    let server = start().await;
    let version = add(&server, file(fields(1200, 1500))).await;
    server.download(&address(version, "96x128")).await;
    {
        let db = database(&server);
        db.with(|conn| {
            conn.execute(
                "insert into thumbnails select blob_id, 40, 60, data from thumbnails",
                [],
            )
        })
        .unwrap();
        assert_eq!(kept(&db), [(40, 60), (96, 128)]);
    }

    let server = server.restart().await;
    assert_eq!(kept(&database(&server)), [(96, 128)]);
}

#[tokio::test]
async fn a_picture_that_cannot_be_read_is_answered_whole() {
    let server = start().await;
    // A PNG by its parts and their checksums, which is all an import asks of
    // it, and 1200 by 1500 by its head. Its pixels are none.
    let head = [0, 0, 4, 176, 0, 0, 5, 220, 8, 2, 0, 0, 0];
    let broken = common::png_of(&[
        common::chunk(b"IHDR", &head),
        common::chunk(b"IDAT", b"no pixels"),
        common::chunk(b"IEND", &[]),
    ]);
    let version = add(&server, broken.clone()).await;
    for size in ["96x128", "512x768"] {
        let (headers, answered) = server.download(&address(version, size)).await;
        assert_eq!(answered, broken);
        assert_eq!(headers["content-type"], "image/png");
    }
    assert_eq!(kept(&database(&server)), []);
}

#[tokio::test]
async fn a_picture_of_too_many_pixels_is_answered_whole() {
    let server = start().await;
    // Just over 32 million of them, all black.
    let vast = file(GrayImage::new(8000, 4001));
    let version = add(&server, vast.clone()).await;
    let (headers, answered) = server.download(&address(version, "96x128")).await;
    assert_eq!(answered, vast);
    assert_eq!(headers["content-type"], "image/png");
    assert_eq!(kept(&database(&server)), []);

    // Just under them it is made small.
    let large = file(GrayImage::new(8000, 3999));
    let version = add(&server, large).await;
    let (_, small) = server.download(&address(version, "96x128")).await;
    let small = read(&small).1;
    assert_eq!((small.width(), small.height()), (256, 128));
}

#[tokio::test]
async fn only_the_owner_gets_a_small_picture_and_only_in_a_size_of_the_lists() {
    let server = start().await;
    let version = add(&server, file(fields(1200, 1500))).await;
    let (status, _) = server.get(&address(version + 1, "96x128")).await;
    assert_eq!(status, 404);
    for size in ["97x128", "row", "", "96x128x"] {
        let (status, _) = server.get(&address(version, size)).await;
        assert_eq!(status, 400, "{size:?}");
    }

    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let mine = cards::import(db, me, &card(file(fields(1200, 1500)))).unwrap();
    let sam = users::create(db, "sam").unwrap();
    let theirs = thumbnails::kept(db, sam, mine.version_id, Size::Row).unwrap();
    assert!(theirs.is_none());
    assert!(make(db, sam, mine.version_id).is_none());
    assert_eq!(kept(db), []);
    // Nor one that the owner has had made.
    assert!(make(db, me, mine.version_id).is_some());
    let theirs = thumbnails::kept(db, sam, mine.version_id, Size::Row).unwrap();
    assert!(theirs.is_none());
    assert!(make(db, sam, mine.version_id).is_none());
}

#[tokio::test]
async fn pictures_asked_for_at_once_are_each_made_and_kept_once() {
    let server = start().await;
    let mut versions = Vec::new();
    for n in 0..6 {
        versions.push(add(&server, file(fields(1000 + 100 * n, 1600))).await);
    }
    // As a list and a Gallery do that are opened side by side, each twice.
    let asked: Vec<String> = versions
        .iter()
        .flat_map(|version| {
            ["96x128", "512x768", "96x128", "512x768"].map(|size| address(*version, size))
        })
        .collect();
    let answers = join_all(asked.iter().map(|address| server.download(address))).await;
    for (address, (_, small)) in asked.iter().zip(answers) {
        let (format, picture) = read(&small);
        assert_eq!(format, ImageFormat::Jpeg, "{address}");
        let (wide, high) = if address.ends_with("96x128") {
            (96, 128)
        } else {
            (512, 768)
        };
        let (width, height) = (picture.width(), picture.height());
        assert!(width >= wide && height >= high, "{address}");
        assert!(width == wide || height == high, "{address}");
    }
    let boxes = kept(&database(&server));
    assert_eq!(boxes.len(), 12, "{boxes:?}");
}

/// How many bytes the server says the cache holds of small pictures.
async fn cached(server: &Server) -> u64 {
    let (status, cache) = server.get("/api/cache").await;
    assert_eq!(status, 200, "{cache}");
    cache["thumbnails"].as_u64().unwrap()
}

#[tokio::test]
async fn the_cache_is_as_large_as_its_small_pictures_and_is_cleared_without_the_pictures() {
    let server = start().await;
    assert_eq!(cached(&server).await, 0);
    let whole = file(fields(1200, 1500));
    let version = add(&server, whole.clone()).await;
    assert_eq!(cached(&server).await, 0);
    let (_, row) = server.download(&address(version, "96x128")).await;
    assert_eq!(cached(&server).await, row.len() as u64);
    let (_, tile) = server.download(&address(version, "512x768")).await;
    let both = (row.len() + tile.len()) as u64;
    assert_eq!(cached(&server).await, both);
    // A picture answered whole in a small one's place is not kept, so it counts for nothing.
    let little = add(&server, file(fields(90, 120))).await;
    server.download(&address(little, "96x128")).await;
    assert_eq!(cached(&server).await, both);

    let db = database(&server);
    let pictures = |db: &Db| -> i64 {
        db.with(|conn| conn.query_row("select count(*) from blobs", [], |r| r.get(0)))
            .unwrap()
    };
    let before = pictures(&db);
    let (status, answer) = server.call(Method::DELETE, "/api/cache", None).await;
    assert_eq!(status, 204, "{answer}");
    assert_eq!(cached(&server).await, 0);
    assert_eq!(kept(&db), []);
    // The pictures themselves stay.
    assert_eq!(pictures(&db), before);
    let (_, answered) = server
        .download(&format!("/api/card-versions/{version}/image"))
        .await;
    assert_eq!(answered, whole);

    // A small picture is made again when it is asked for, and cleared again.
    let (_, again) = server.download(&address(version, "96x128")).await;
    assert_eq!(again, row);
    assert_eq!(kept(&db), [(96, 128)]);
    assert_eq!(cached(&server).await, row.len() as u64);
    let (status, _) = server.call(Method::DELETE, "/api/cache", None).await;
    assert_eq!(status, 204);
    assert_eq!(kept(&db), []);
}

#[test]
fn the_cache_is_a_users_own_the_small_pictures_of_that_users_cards() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let sam = users::create(db, "sam").unwrap();
    let shared = card(file(fields(1300, 1500)));
    let mine = cards::import(db, me, &card(file(fields(1200, 1500)))).unwrap();
    let theirs = cards::import(db, sam, &card(file(fields(1500, 1200)))).unwrap();
    let mine_too = cards::import(db, me, &shared).unwrap();
    let theirs_too = cards::import(db, sam, &shared).unwrap();
    assert_eq!(thumbnails::size(db, me).unwrap(), 0);

    let small = |user, version| make(db, user, version).unwrap().len() as u64;
    let (a, b) = (small(me, mine.version_id), small(sam, theirs.version_id));
    // One picture that both have is kept once, and its small one is both users'.
    let c = small(me, mine_too.version_id);
    assert_eq!(small(sam, theirs_too.version_id), c);
    assert_eq!(kept(db).len(), 3);
    assert_ne!(a, b);
    assert_eq!(thumbnails::size(db, me).unwrap(), a + c);
    assert_eq!(thumbnails::size(db, sam).unwrap(), b + c);

    // A card in the Trash has its small picture still, and it counts.
    cards::set_trashed(db, sam, theirs.card_id, true).unwrap();
    assert_eq!(thumbnails::size(db, sam).unwrap(), b + c);

    thumbnails::clear(db, sam).unwrap();
    assert_eq!(thumbnails::size(db, sam).unwrap(), 0);
    assert_eq!(thumbnails::size(db, me).unwrap(), a);
    assert_eq!(kept(db), [(96, 128)]);
    let left = thumbnails::kept(db, me, mine.version_id, Size::Row).unwrap();
    assert!(matches!(left, Some(Kept::Small(_))));
}

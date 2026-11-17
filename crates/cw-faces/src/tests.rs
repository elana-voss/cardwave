use super::*;

/// A stride's answer that is silent but for one cell, whose box is a stride wide and high around its corner.
fn one_cell(stride: u32, cell: usize, score: f32) -> Stride {
    let cells = ((SQUARE / stride) * (SQUARE / stride)) as usize;
    let mut answer = Stride {
        stride,
        cls: vec![0.; cells],
        obj: vec![0.; cells],
        bbox: vec![0.; cells * 4],
    };
    answer.cls[cell] = score;
    answer.obj[cell] = score;
    answer
}

#[test]
fn a_sure_cell_is_a_box_in_fractions_of_the_picture() {
    // Row 1, column 2 of stride 32: a box of 32 around (64, 32), on a picture shown at half of 1280 by 640.
    let found = boxes(&[one_cell(32, 20 + 2, 0.9)], 0.5, 1280, 640);
    assert_eq!(found.len(), 1);
    let face = found[0].1;
    assert!((face.left - 48. / 640.).abs() < 1e-5, "{face:?}");
    assert!((face.top - 16. / 320.).abs() < 1e-5, "{face:?}");
    assert!((face.width - 32. / 640.).abs() < 1e-5, "{face:?}");
    assert!((face.height - 32. / 320.).abs() < 1e-5, "{face:?}");
}

#[test]
fn an_unsure_cell_is_no_face() {
    assert!(boxes(&[one_cell(32, 5, 0.6)], 1., 640, 640).is_empty());
}

#[test]
fn a_box_past_the_edge_is_cut_there() {
    let found = boxes(&[one_cell(32, 0, 0.9)], 1., 640, 640);
    assert_eq!(found[0].1.left, 0.);
    assert!((found[0].1.width - 16. / 640.).abs() < 1e-5);
}

#[test]
fn two_passes_on_one_face_are_one_box_and_the_surest_stays() {
    let at = |left: f32| Face {
        left,
        top: 0.1,
        width: 0.2,
        height: 0.2,
    };
    let found = merged(vec![(0.8, at(0.11)), (0.9, at(0.1)), (0.75, at(0.6))]);
    assert_eq!(found, vec![at(0.1), at(0.6)]);
}

#[test]
fn a_tall_picture_lies_top_left_on_the_square_in_blue_green_red() {
    let picture = RgbImage::from_pixel(10, 20, image::Rgb([10, 20, 30]));
    let (scale, tensor) = square(&picture, 320);
    assert_eq!(scale, 16.);
    let cells = (SQUARE * SQUARE) as usize;
    assert_eq!(tensor.len(), 3 * cells);
    assert_eq!(
        (tensor[0], tensor[cells], tensor[2 * cells]),
        (30., 20., 10.)
    );
    // Past its 160 by 320: black.
    assert_eq!(tensor[160], 0.);
    assert_eq!(tensor[320 * SQUARE as usize], 0.);
}

/// Off Windows, a computer whose Vulkan has only the processor (WSL's llvmpipe, GitHub's runner) has no Finder.
#[cfg(not(windows))]
#[test]
fn without_a_graphics_card_no_finder_opens() {
    if vulkan::card().unwrap().is_none() {
        assert!(Finder::open().is_err());
    }
}

/// Through the model itself, where this computer has a graphics card to run it on.
#[test]
fn a_blank_picture_has_no_faces() {
    // No graphics card: nothing to show here.
    let Ok(finder) = Finder::open() else { return };
    let blank = RgbImage::from_pixel(64, 64, image::Rgb([128, 128, 128]));
    assert_eq!(finder.find(&blank).unwrap(), vec![]);
}

/// The Vulkan engine, run here on this computer's graphics card, finds the boxes Windows ML finds on the browser
/// tests' portraits, each side within a hundredth of the picture.
#[cfg(windows)]
#[test]
fn vulkan_finds_the_faces_windows_ml_finds() {
    // Where neither engine finds a graphics card (GitHub's runner) there is nothing to compare: skipped by name,
    // never passed. Where only one does, the test fails. A Vulkan without its loader counts as no card.
    let windows = match (engine::Session::open(), vulkan::card().ok().flatten()) {
        (Ok(windows), Some(_)) => windows,
        (Err(why), None) => {
            eprintln!(
                "skipped vulkan_finds_the_faces_windows_ml_finds: no graphics card here ({why:#})"
            );
            return;
        }
        (windows, card) => panic!(
            "vulkan_finds_the_faces_windows_ml_finds: only one engine reaches a graphics card \
             (Windows ML: {:?}; Vulkan's card found: {})",
            windows.err().map(|why| format!("{why:#}")),
            card.is_some()
        ),
    };
    let vulkan = vulkan::Session::open().unwrap();
    let folder = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../e2e/portraits");
    let mut compared = 0;
    for entry in std::fs::read_dir(&folder).unwrap() {
        let path = entry.unwrap().path();
        let picture = image::open(&path).unwrap().to_rgb8();
        let expected = faces(&picture, |tensor| windows.pass(tensor)).unwrap();
        let found = faces(&picture, |tensor| vulkan.pass(tensor)).unwrap();
        assert_eq!(
            found.len(),
            expected.len(),
            "{path:?}: {found:?} {expected:?}"
        );
        for (one, other) in found.iter().zip(&expected) {
            let sides = [
                one.left - other.left,
                one.top - other.top,
                one.width - other.width,
                one.height - other.height,
            ];
            assert!(
                sides.iter().all(|side| side.abs() <= 0.01),
                "{path:?}: {one:?} {other:?}"
            );
        }
        compared += 1;
    }
    assert!(compared > 0, "no portrait in {folder:?} to compare on");
}

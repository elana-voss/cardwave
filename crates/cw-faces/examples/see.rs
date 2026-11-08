//! The boxes of each picture named, one line each, in percent of the picture, with the time it took: the tracked
//! tool of milestone 124a's try. `cargo run --example see -- <absolute paths>` from `crates/cw-faces`.

use std::time::Instant;

fn main() -> anyhow::Result<()> {
    let opened = Instant::now();
    let finder = cw_faces::Finder::open()?;
    println!("open {:?}", opened.elapsed());
    for path in std::env::args().skip(1) {
        let picture = image::ImageReader::open(&path)?
            .with_guessed_format()?
            .decode()?
            .to_rgb8();
        let looked = Instant::now();
        let faces = finder.find(&picture)?;
        let name = path.rsplit(['/', '\\']).next().unwrap_or(&path);
        let boxes: Vec<String> = faces
            .iter()
            .map(|f| {
                let (l, t) = (f.left * 100., f.top * 100.);
                format!(
                    "x{l:.0}-{:.0} y{t:.0}-{:.0}",
                    l + f.width * 100.,
                    t + f.height * 100.
                )
            })
            .collect();
        println!("{name} {:?} {boxes:?}", looked.elapsed());
    }
    Ok(())
}

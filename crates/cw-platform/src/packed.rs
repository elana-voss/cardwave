//! Gzipped bytes unpacked (the one wrapper of flate2): the files built into
//! the app (the names database, models.dev's list) and the tests' golden files.

use std::io::Read;

/// The bytes `packed` holds, gzip undone; an error where they are not gzip.
pub fn unpacked(packed: &[u8]) -> std::io::Result<Vec<u8>> {
    let mut bytes = Vec::new();
    flate2::read::GzDecoder::new(packed).read_to_end(&mut bytes)?;
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::*;

    #[test]
    fn gzipped_bytes_come_back_as_they_were_and_others_are_refused() {
        let mut packer = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        packer.write_all(b"Sail at noon.").unwrap();
        let packed = packer.finish().unwrap();
        assert_eq!(unpacked(&packed).unwrap(), b"Sail at noon.");
        assert!(unpacked(b"Sail at noon.").is_err());
    }
}

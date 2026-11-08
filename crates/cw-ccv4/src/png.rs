//! The CCV4 container: a PNG whose private `toMl` and `asEt` chunks carry the
//! card's TOML files and binary assets (spec section 2).

use std::collections::HashSet;

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Fail};
use std::io::{ErrorKind, Read, Seek, SeekFrom};

pub(crate) const SIGNATURE: [u8; 8] = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];
/// Every CCV4 payload starts with this; other apps' chunks of the same name do not.
const MAGIC: &[u8] = b"ccv4\0";
const TOML_CHUNK: [u8; 4] = *b"toMl";
const ASSET_CHUNK: [u8; 4] = *b"asEt";
const MAX_PAYLOAD: usize = i32::MAX as usize;

/// A card file taken apart.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Container {
    /// The PNG without its CCV4 chunks: the plain picture.
    pub image: Vec<u8>,
    /// TOML files as (filename, text).
    pub toml: Vec<(String, String)>,
    /// Assets as (filename, bytes).
    pub assets: Vec<(String, Vec<u8>)>,
}

struct Chunk<'a> {
    kind: [u8; 4],
    data: &'a [u8],
    /// Length, type, data and checksum as they stand in the file.
    raw: &'a [u8],
}

/// Walks the chunks up to and including `IEND`, checking structure and checksums.
fn chunks(bytes: &[u8]) -> anyhow::Result<Vec<Chunk<'_>>> {
    ensure!(
        bytes.starts_with(&SIGNATURE),
        Fail::said(Code::NotReadable, "not a PNG file").with("what", "png")
    );
    let mut out = Vec::new();
    let mut pos = SIGNATURE.len();
    loop {
        let header = bytes.get(pos..pos + 8).context(
            Fail::said(Code::NotReadable, "the PNG ends before its IEND chunk")
                .with("what", "png_damaged"),
        )?;
        let len = u32::from_be_bytes([header[0], header[1], header[2], header[3]]) as usize;
        let kind = [header[4], header[5], header[6], header[7]];
        ensure!(
            len <= MAX_PAYLOAD,
            Fail::said(Code::NotReadable, "a PNG chunk is too large").with("what", "png_damaged")
        );
        ensure!(
            kind.iter().all(u8::is_ascii_alphabetic),
            Fail::said(Code::NotReadable, "a PNG chunk has an invalid type")
                .with("what", "png_damaged")
        );
        let end = pos + 12 + len;
        let raw = bytes.get(pos..end).context(
            Fail::said(
                Code::NotReadable,
                "a PNG chunk runs past the end of the file",
            )
            .with("what", "png_damaged"),
        )?;
        let data = &raw[8..8 + len];
        let stored = u32::from_be_bytes([raw[8 + len], raw[9 + len], raw[10 + len], raw[11 + len]]);
        ensure!(
            crc32fast::hash(&raw[4..8 + len]) == stored,
            Fail::said(
                Code::NotReadable,
                format!(
                    "the PNG is damaged (checksum of a {} chunk)",
                    String::from_utf8_lossy(&kind)
                )
            )
            .with("what", "png_damaged")
        );
        ensure!(
            !out.is_empty() || kind == *b"IHDR",
            Fail::said(Code::NotReadable, "the PNG does not start with IHDR")
                .with("what", "png_damaged")
        );
        out.push(Chunk { kind, data, raw });
        if kind == *b"IEND" {
            return Ok(out);
        }
        pos = end;
    }
}

/// Filename rules of spec section 2.4; they also keep a later extraction to
/// disk from leaving its folder.
fn check_filename(name: &str) -> anyhow::Result<()> {
    ensure!(
        name.starts_with("card/") || name.starts_with("user/"),
        Fail::said(
            Code::NotReadable,
            format!("the file name {name:?} does not start with card/ or user/")
        )
        .with("what", "card_file_name")
    );
    ensure!(
        !name.contains('\\'),
        Fail::said(
            Code::NotReadable,
            format!("the file name {name:?} contains a backslash")
        )
        .with("what", "card_file_name")
    );
    ensure!(
        !name
            .split('/')
            .any(|segment| segment == "." || segment == ".."),
        Fail::said(
            Code::NotReadable,
            format!("the file name {name:?} contains a . or .. segment")
        )
        .with("what", "card_file_name")
    );
    Ok(())
}

/// Splits a card file into its picture, TOML files and assets.
pub fn read(bytes: &[u8]) -> anyhow::Result<Container> {
    let mut container = Container {
        image: SIGNATURE.to_vec(),
        ..Default::default()
    };
    let mut names = HashSet::new();
    for chunk in chunks(bytes)? {
        let is_toml = chunk.kind == TOML_CHUNK;
        let payload = match chunk.data.strip_prefix(MAGIC) {
            Some(payload) if is_toml || chunk.kind == ASSET_CHUNK => payload,
            _ => {
                container.image.extend_from_slice(chunk.raw);
                continue;
            }
        };
        let split = payload.iter().position(|b| *b == 0).context(
            Fail::said(Code::NotReadable, "a CCV4 chunk has no file name")
                .with("what", "card_file_name"),
        )?;
        let name = std::str::from_utf8(&payload[..split]).context(
            Fail::said(Code::NotReadable, "a CCV4 file name is not UTF-8")
                .with("what", "card_file_name"),
        )?;
        check_filename(name)?;
        ensure!(
            names.insert(name.to_string()),
            Fail::said(
                Code::NotReadable,
                format!("the file name {name:?} is used twice")
            )
            .with("what", "card_file_name")
        );
        let content = &payload[split + 1..];
        if is_toml {
            let text = std::str::from_utf8(content).with_context(|| {
                Fail::said(Code::NotReadable, format!("{name} is not UTF-8"))
                    .with("what", "card_file_name")
                    .with("name", name.to_string())
            })?;
            container.toml.push((name.to_string(), text.to_string()));
        } else {
            container.assets.push((name.to_string(), content.to_vec()));
        }
    }
    Ok(container)
}

/// Whether the PNG read from `file` has a chunk a card is kept in: CCV4's, or a `tEXt` chunk whose keyword
/// `wanted` accepts. Only the chunks' headers are read (and a `tEXt` chunk's keyword), the rest seeked past,
/// up to `IEND` or the file's end. False for a file that is no PNG or ends early.
pub fn holds_card_chunk(
    file: &mut (impl Read + Seek),
    wanted: impl Fn(&str) -> bool,
) -> std::io::Result<bool> {
    let ended = |failure: std::io::Error| match failure.kind() {
        ErrorKind::UnexpectedEof => Ok(false),
        _ => Err(failure),
    };
    let mut signature = [0; 8];
    if let Err(failure) = file.read_exact(&mut signature) {
        return ended(failure);
    }
    if signature != SIGNATURE {
        return Ok(false);
    }
    let mut header = [0; 8];
    loop {
        if let Err(failure) = file.read_exact(&mut header) {
            return ended(failure);
        }
        let len = u64::from(u32::from_be_bytes([
            header[0], header[1], header[2], header[3],
        ]));
        let kind = [header[4], header[5], header[6], header[7]];
        if kind == TOML_CHUNK || kind == ASSET_CHUNK {
            return Ok(true);
        }
        if kind == *b"IEND" {
            return Ok(false);
        }
        // The data and the checksum.
        let mut skip = len + 4;
        if kind == *b"tEXt" {
            // A keyword is 1 to 79 Latin-1 characters, ended by a nought.
            let mut start = vec![0; len.min(80) as usize];
            if let Err(failure) = file.read_exact(&mut start) {
                return ended(failure);
            }
            let end = start.iter().position(|b| *b == 0).unwrap_or(start.len());
            let keyword: String = start[..end].iter().map(|b| char::from(*b)).collect();
            if wanted(&keyword) {
                return Ok(true);
            }
            skip -= start.len() as u64;
        }
        file.seek(SeekFrom::Current(skip as i64))?;
    }
}

/// A PNG `tEXt` chunk as (keyword, text).
pub type Text<'a> = (String, &'a [u8]);

/// Takes the `tEXt` chunks whose keyword `wanted` accepts out of a PNG. Returns
/// the PNG without them and the chunks in file order. Other card formats keep
/// their data in such chunks.
pub fn take_text(
    bytes: &[u8],
    wanted: impl Fn(&str) -> bool,
) -> anyhow::Result<(Vec<u8>, Vec<Text<'_>>)> {
    let mut image = SIGNATURE.to_vec();
    let mut taken = Vec::new();
    for chunk in chunks(bytes)? {
        if chunk.kind == *b"tEXt"
            && let Some(split) = chunk.data.iter().position(|b| *b == 0)
        {
            // Keywords are Latin-1.
            let keyword: String = chunk.data[..split].iter().map(|b| char::from(*b)).collect();
            if wanted(&keyword) {
                taken.push((keyword, &chunk.data[split + 1..]));
                continue;
            }
        }
        image.extend_from_slice(chunk.raw);
    }
    Ok((image, taken))
}

/// Builds a card file: the picture with the TOML files and assets placed before
/// its `IEND` chunk.
pub fn write(container: &Container) -> anyhow::Result<Vec<u8>> {
    let (mut out, end) = open_end(&container.image)?;
    let mut names = HashSet::new();
    let files = container
        .toml
        .iter()
        .map(|(name, text)| (TOML_CHUNK, name, text.as_bytes()))
        .chain(
            container
                .assets
                .iter()
                .map(|(name, data)| (ASSET_CHUNK, name, data.as_slice())),
        );
    for (kind, name, content) in files {
        ensure!(
            !name.contains('\0'),
            Fail::said(Code::Internal, format!("invalid file name {name:?}"))
        );
        check_filename(name)?;
        ensure!(
            names.insert(name.as_str()),
            Fail::said(
                Code::Internal,
                format!("the file name {name:?} is used twice")
            )
        );
        push_chunk(&mut out, kind, &[MAGIC, name.as_bytes(), &[0], content])
            .with_context(|| Fail::said(Code::Internal, format!("{name} cannot be written")))?;
    }
    out.extend_from_slice(end);
    Ok(out)
}

/// Puts `tEXt` chunks, given as (keyword, text), before the `IEND` chunk of a PNG.
pub(crate) fn add_text(image: &[u8], texts: &[(String, Vec<u8>)]) -> anyhow::Result<Vec<u8>> {
    let (mut out, end) = open_end(image)?;
    for (keyword, text) in texts {
        // A keyword is 1 to 79 Latin-1 characters; these are ASCII.
        ensure!(
            (1..80).contains(&keyword.len()) && keyword.bytes().all(|b| b.is_ascii_graphic()),
            Fail::said(Code::Internal, format!("invalid PNG keyword {keyword:?}"))
        );
        push_chunk(&mut out, *b"tEXt", &[keyword.as_bytes(), &[0], text])
            .with_context(|| Fail::said(Code::Internal, format!("{keyword} cannot be written")))?;
    }
    out.extend_from_slice(end);
    Ok(out)
}

/// A PNG up to its `IEND` chunk, and that chunk: more chunks go in between.
fn open_end(image: &[u8]) -> anyhow::Result<(Vec<u8>, &[u8])> {
    let mut out = SIGNATURE.to_vec();
    for chunk in chunks(image)? {
        if chunk.kind == *b"IEND" {
            return Ok((out, chunk.raw));
        }
        out.extend_from_slice(chunk.raw);
    }
    bail!(
        Fail::said(Code::NotReadable, "the picture has no IEND chunk").with("what", "png_damaged")
    )
}

/// Appends one chunk whose data is `parts` in a row.
fn push_chunk(out: &mut Vec<u8>, kind: [u8; 4], parts: &[&[u8]]) -> anyhow::Result<()> {
    let len: usize = parts.iter().map(|part| part.len()).sum();
    ensure!(
        len <= MAX_PAYLOAD,
        Fail::said(Code::Internal, "it is too large for a PNG chunk")
    );
    let start = out.len();
    out.extend_from_slice(&(len as u32).to_be_bytes());
    out.extend_from_slice(&kind);
    for part in parts {
        out.extend_from_slice(part);
    }
    let crc = crc32fast::hash(&out[start + 4..]);
    out.extend_from_slice(&crc.to_be_bytes());
    Ok(())
}

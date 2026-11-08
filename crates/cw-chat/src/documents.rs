//! Documents a chat or a character is given ("Add document"): read as text
//! (`text_of`: .txt, .md, .pdf, .docx), kept beside the memories, cut into
//! `pieces` that the search model reads in the background after the cards
//! (`find/reader.rs`), and before a reply the pieces nearest its newest
//! messages go into its prompt (`excerpts`, asked by `api/memory.rs`'s
//! `recall` with the same vector as the memories), after those attached to the
//! message the reply answers, which go from their start (`given`). A chat's documents serve
//! its replies, a card's every reply its character writes (`for_reply`).
//! Knowledge › Documents: `list`, `delete` (kept for its Undo, `restore`,
//! until the server starts again, `purge_deleted`).
//!
//! Traps: a PDF's text is lopdf's reading of its pages, so a scanned one has
//! none and is refused; of a Word file only the body is read; lopdf and zip
//! read what a user brings, each with a limit on what it unpacks. The pieces
//! reach the model as written: the prompt's macros are not expanded in them.

use std::io::{Cursor, Read};
use std::sync::LazyLock;

use anyhow::{Context, bail, ensure};
use cw_core::NotFound;
use cw_core::{Code, Fail};
use cw_prompt::tokens;
use cw_search::{self as search, Piece, nearest};
use regex::Regex;
use serde::Serialize;
use ts_rs::TS;

/// The largest file taken, in bytes.
pub const FILE_LIMIT: usize = 32 * 1024 * 1024;
/// The most characters of text a document may have.
pub const TEXT_LIMIT: usize = 2_000_000;
/// The most bytes a page of a PDF, or a Word file's text, is unpacked to.
const UNPACKED_LIMIT: usize = 64 * 1024 * 1024;
/// The most characters of a piece: about 300 tokens of English, which
/// the search model reads whole.
const PIECE_CHARS: usize = 1_200;
/// The most pieces a reply is given.
const EXCERPTS: usize = 3;
/// How near, as a cosine, a piece must be to the newest messages to be given:
/// at least `NEAR`, and no more than `BEHIND` behind the nearest piece.
/// Measured with bge-m3 (the work log, "Documents"): of 15 exchanges each about
/// one piece of 6, the piece came at 0.44 to 0.62 and first in 14, the next
/// nearest at 0.40 to 0.50, and exchanges about none at most 0.43.
pub(crate) const NEAR: f32 = 0.45;
const BEHIND: f32 = 0.03;
/// The longest name kept, in characters.
const NAME_LIMIT: usize = 200;

/// What a document is of.
#[derive(Clone, Copy, Debug)]
pub enum Owner {
    Chat(i64),
    Card(i64),
}

/// A document as Knowledge › Documents shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, TS)]
#[ts(export)]
pub struct DocumentView {
    pub id: i64,
    /// Its file's name.
    pub name: String,
    pub words: i64,
    /// Whether the search model has read it, so that replies are given of it.
    pub read: bool,
    /// The chat it is of, or the card.
    pub chat_id: Option<i64>,
    pub card_id: Option<i64>,
    /// What that is called: a card's title; a chat's title, else the name of
    /// the character it began with.
    pub owner_name: String,
    pub created_at: i64,
}

/// The text of the file `name`, by its ending: as written for .txt and .md,
/// the pages' text of a PDF, the paragraphs of a Word file (.docx).
pub fn text_of(name: &str, file: &[u8]) -> anyhow::Result<String> {
    let ending = name.rsplit_once('.').map(|(_, e)| e.to_lowercase());
    let text = match ending.as_deref() {
        Some("txt" | "text" | "md" | "markdown") => plain_text(file),
        Some("pdf") => pdf_text(file)?,
        Some("docx") => word_text(file)?,
        _ => bail!(
            Fail::said(
                Code::NotReadable,
                "a document is a .txt, .md, .pdf or .docx file"
            )
            .with("what", "document_type")
        ),
    };
    let text = text.replace("\r\n", "\n").trim().to_string();
    ensure!(
        !text.is_empty(),
        Fail::said(
            Code::NotReadable,
            format!("{name} has no text that can be read")
        )
        .with("what", "document_text")
        .with("name", name.to_string())
    );
    ensure!(
        text.chars().count() <= TEXT_LIMIT,
        Fail::said(
            Code::TooLong,
            format!("{name} is too long: a document has 2,000,000 characters at most")
        )
        .with("what", "document")
        .with("name", name.to_string())
    );
    Ok(text)
}

/// A text file as UTF-8, or as UTF-16 where it begins with UTF-16's mark.
fn plain_text(file: &[u8]) -> String {
    let utf16 = |rest: &[u8], word: fn([u8; 2]) -> u16| {
        let words: Vec<u16> = rest
            .as_chunks::<2>()
            .0
            .iter()
            .map(|pair| word(*pair))
            .collect();
        String::from_utf16_lossy(&words)
    };
    match file {
        [0xFF, 0xFE, rest @ ..] => utf16(rest, u16::from_le_bytes),
        [0xFE, 0xFF, rest @ ..] => utf16(rest, u16::from_be_bytes),
        _ => {
            String::from_utf8_lossy(file.strip_prefix(b"\xEF\xBB\xBF").unwrap_or(file)).into_owned()
        }
    }
}

fn pdf_text(file: &[u8]) -> anyhow::Result<String> {
    let document = lopdf::Document::load_mem(file)
        .context(Fail::said(Code::NotReadable, "the PDF cannot be read").with("what", "pdf"))?;
    let mut text = String::new();
    for page in document.get_pages().into_keys() {
        // A page that cannot be read is left out, not the document.
        if let Ok(read) = document.extract_text_with_limit(&[page], UNPACKED_LIMIT) {
            text.push_str(&read);
            text.push('\n');
        }
    }
    Ok(text)
}

static LEFT_OUT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?s)<w:instrText\b[^>]*>.*?</w:instrText>|<w:delText\b[^>]*>.*?</w:delText>|<mc:Fallback\b[^>]*>.*?</mc:Fallback>",
    )
    // A fixed pattern, run by this file's tests: it compiles.
    .unwrap()
});
static BREAK: LazyLock<Regex> =
    // A fixed pattern, run by this file's tests: it compiles.
    LazyLock::new(|| Regex::new(r"</w:p>|<w:br\b[^>]*/>|<w:cr\b[^>]*/>").unwrap());
// A fixed pattern, run by this file's tests: it compiles.
static TAB: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<w:tab\b[^>]*/>").unwrap());
// A fixed pattern, run by this file's tests: it compiles.
static TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>]*>").unwrap());
static ENTITY: LazyLock<Regex> =
    // A fixed pattern, run by this file's tests: it compiles.
    LazyLock::new(|| Regex::new(r"&(lt|gt|amp|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);").unwrap());

/// The text of a Word file's body: its paragraphs one to a line, without its
/// deleted text, field codes, and the copy of a text box kept for older Words
/// (`mc:Fallback`). Headers, footers and footnotes are parts of their own,
/// not read.
fn word_text(file: &[u8]) -> anyhow::Result<String> {
    let mut archive = zip::ZipArchive::new(Cursor::new(file)).context(
        Fail::said(Code::NotReadable, "the Word file cannot be read").with("what", "word_file"),
    )?;
    let mut xml = String::new();
    archive
        .by_name("word/document.xml")
        .context(
            Fail::said(Code::NotReadable, "the Word file has no text").with("what", "word_text"),
        )?
        .take(UNPACKED_LIMIT as u64)
        .read_to_string(&mut xml)
        .context(
            Fail::said(Code::NotReadable, "the Word file cannot be read").with("what", "word_file"),
        )?;
    let xml = LEFT_OUT.replace_all(&xml, "");
    let xml = BREAK.replace_all(&xml, "\n");
    let xml = TAB.replace_all(&xml, "\t");
    let text = TAG.replace_all(&xml, "");
    Ok(ENTITY
        .replace_all(&text, |found: &regex::Captures| match &found[1] {
            "lt" => "<".to_string(),
            "gt" => ">".to_string(),
            "amp" => "&".to_string(),
            "quot" => "\"".to_string(),
            "apos" => "'".to_string(),
            number => {
                let code = match number.strip_prefix("#x") {
                    Some(hex) => u32::from_str_radix(hex, 16).ok(),
                    None => number[1..].parse().ok(),
                };
                code.and_then(char::from_u32)
                    .map(String::from)
                    .unwrap_or_default()
            }
        })
        .into_owned())
}

/// `text` in pieces of at most `PIECE_CHARS` characters, in their order: its
/// lines joined while they fit, a longer line cut at a space.
pub fn pieces(text: &str) -> Vec<String> {
    let mut pieces = Vec::new();
    let (mut piece, mut length) = (String::new(), 0);
    for line in text.lines().map(str::trim).filter(|line| !line.is_empty()) {
        for part in cut(line) {
            let size = part.chars().count();
            if length > 0 && length + 1 + size > PIECE_CHARS {
                pieces.push(std::mem::take(&mut piece));
                length = 0;
            }
            if length > 0 {
                piece.push('\n');
                length += 1;
            }
            piece.push_str(part);
            length += size;
        }
    }
    if !piece.is_empty() {
        pieces.push(piece);
    }
    pieces
}

/// A line in parts of at most `PIECE_CHARS` characters, each cut at its last
/// space where it has one.
fn cut(line: &str) -> Vec<&str> {
    let mut parts = Vec::new();
    let mut rest = line;
    while let Some((end, _)) = rest.char_indices().nth(PIECE_CHARS) {
        let at = rest[..end]
            .rfind(char::is_whitespace)
            .filter(|&at| at > 0)
            .unwrap_or(end);
        parts.push(rest[..at].trim_end());
        rest = rest[at..].trim_start();
    }
    if !rest.is_empty() {
        parts.push(rest);
    }
    parts
}

/// What a reply is given of the documents: those attached to the message it
/// answers (`attached`: ID, name, text) from their start, as the user means
/// them whatever the search model makes of the question; then of the other
/// `read` pieces those near `query` ([`excerpts`]), where the search model
/// made one; all in at most `budget` tokens. None where none is.
pub fn given(
    attached: &[(i64, String, String)],
    query: Option<&[f32]>,
    read: Vec<Piece>,
    budget: usize,
) -> Option<String> {
    let mut given = Vec::new();
    let mut used = 0;
    for (_, name, text) in attached {
        let head = format!("From \"{name}\":");
        let mut parts = vec![head.clone()];
        used += tokens::estimate(&head);
        for part in pieces(text) {
            let size = tokens::estimate(&part);
            if used + size > budget {
                break;
            }
            used += size;
            parts.push(part);
        }
        if parts.len() > 1 {
            given.push(parts.join("\n"));
        }
    }
    let others: Vec<Piece> = read
        .into_iter()
        .filter(|piece| !attached.iter().any(|(id, ..)| *id == piece.document))
        .collect();
    if let Some(near) = query.and_then(|query| excerpts(query, others, budget.saturating_sub(used)))
    {
        given.push(near);
    }
    (!given.is_empty()).then(|| given.join("\n\n"))
}

/// What a reply is given of `pieces`: the `EXCERPTS` nearest the vector of
/// its newest messages, of those near enough (`NEAR`), each with its
/// document's name, while they take no more than `budget` tokens. None where
/// none is.
pub fn excerpts(query: &[f32], pieces: Vec<Piece>, budget: usize) -> Option<String> {
    let mut near: Vec<(f32, Piece)> = pieces
        .into_iter()
        .map(|piece| (nearest(query, &piece.embedding), piece))
        .collect();
    near.sort_by(|a, b| b.0.total_cmp(&a.0));
    let bar = NEAR.max(near.first().map_or(f32::MAX, |(near, _)| near - BEHIND));
    near.retain(|(near, _)| *near >= bar);
    let mut given = Vec::new();
    let mut used = 0;
    for (_, piece) in near.into_iter().take(EXCERPTS) {
        let text = format!("From \"{}\":\n{}", piece.name, piece.text);
        let size = tokens::estimate(&text);
        if used + size > budget {
            break;
        }
        used += size;
        given.push(text);
    }
    (!given.is_empty()).then(|| given.join("\n\n"))
}

/// What the documents need of the database, which `cw_store::documents` gives; their
/// pieces and what the search model read of them are `search::Index`'s.
pub trait Storage: cw_search::Index + cw_search::kept::Storage {
    /// A document of the user's that the list shows.
    fn document(&self, user: i64, id: i64) -> anyhow::Result<Option<DocumentView>>;
    /// Keeps a document of the user's chat or card `owner` (one of the two):
    /// its ID, none where the user has no such one out of the Trash.
    fn add_document(
        &self,
        user: i64,
        owner: (Option<i64>, Option<i64>),
        name: &str,
        text: &str,
    ) -> anyhow::Result<Option<i64>>;
    /// Those the list shows, the newest first.
    fn documents(&self, user: i64) -> anyhow::Result<Vec<DocumentView>>;
    /// How many it deleted.
    fn delete_document(&self, user: i64, id: i64) -> anyhow::Result<usize>;
    /// How many it put back: none while its chat or card is in the Trash.
    fn restore_document(&self, user: i64, id: i64) -> anyhow::Result<usize>;
    fn purge_deleted_documents(&self) -> anyhow::Result<()>;
}

fn view(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<DocumentView> {
    let found = db.document(user, id)?;
    Ok(found.ok_or(NotFound("document"))?)
}

/// Keeps `text`, the text of the file `name`, as a document of `owner`.
pub fn add(
    db: &dyn Storage,
    user: i64,
    owner: Owner,
    name: &str,
    text: &str,
) -> anyhow::Result<DocumentView> {
    let name: String = name.trim().chars().take(NAME_LIMIT).collect();
    let (chat, card) = match owner {
        Owner::Chat(id) => (Some(id), None),
        Owner::Card(id) => (None, Some(id)),
    };
    let added = db.add_document(user, (chat, card), &name, text)?;
    let id = added.ok_or(NotFound(if chat.is_some() { "chat" } else { "card" }))?;
    view(db, user, id)
}

/// The user's documents but those of chats and cards in the Trash, the newest first.
pub fn list(db: &dyn Storage, user: i64) -> anyhow::Result<Vec<DocumentView>> {
    db.documents(user)
}

/// Deletes a document, which its Undo puts back until the server starts again.
pub fn delete(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<()> {
    let changed = db.delete_document(user, id)?;
    ensure!(changed == 1, NotFound("document"));
    Ok(())
}

/// Puts back a document that was deleted, unless its chat or card is in the
/// Trash, which hides it.
pub fn restore(db: &dyn Storage, user: i64, id: i64) -> anyhow::Result<DocumentView> {
    let changed = db.restore_document(user, id)?;
    ensure!(changed == 1, NotFound("document"));
    view(db, user, id)
}

/// Deletes for good the documents the user deleted, as `memory::purge_deleted`.
pub fn purge_deleted(db: &dyn Storage) -> anyhow::Result<()> {
    db.purge_deleted_documents()
}

/// The next document its user's search model is to read, of any user but
/// those whose stamp is in `skip`: one not deleted that it has not read. With
/// its user, its text and the stamp.
pub fn next(
    db: &dyn Storage,
    skip: &[String],
) -> anyhow::Result<Option<(i64, i64, String, String)>> {
    search::Index::unread_document(db, skip)
}

/// Keeps the document's pieces, each with its vectors, in place of those it
/// had, as read by the search model; none where it could not be read, which
/// is not tried again until the model changes.
pub fn keep(
    db: &dyn Storage,
    id: i64,
    stamp: &str,
    pieces: &[(String, Vec<u8>)],
) -> anyhow::Result<()> {
    search::Index::keep_document_pieces(db, id, stamp, pieces)
}

/// The pieces a reply in the chat by a character of the card `card_id` may be
/// given: of the chat's documents and of the card's, as the search model read them.
pub fn for_reply(
    db: &dyn Storage,
    user: i64,
    chat_id: i64,
    card_id: Option<i64>,
) -> anyhow::Result<Vec<Piece>> {
    search::Index::document_pieces(db, user, Some((chat_id, card_id)))
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::*;
    use cw_provider::embedder::to_bytes;

    #[test]
    fn a_word_file_is_read_by_its_paragraphs_without_deleted_text() {
        let xml = concat!(
            r#"<?xml version="1.0"?><w:document><w:body>"#,
            r#"<w:p><w:r><w:t>Saltmere &amp; its </w:t></w:r><w:r><w:t xml:space="preserve">lamp</w:t></w:r></w:p>"#,
            r#"<w:p><w:r><w:delText>gone</w:delText><w:instrText> PAGE </w:instrText><w:t>Tide&#x2019;s</w:t><w:tab/><w:t>end</w:t></w:r></w:p>"#,
            r#"<w:p><mc:AlternateContent><mc:Choice><w:t>Box</w:t></mc:Choice><mc:Fallback><w:t>Box</w:t></mc:Fallback></mc:AlternateContent></w:p>"#,
            "</w:body></w:document>"
        );
        let mut file = Vec::new();
        {
            let mut zip = zip::ZipWriter::new(Cursor::new(&mut file));
            zip.start_file(
                "word/document.xml",
                zip::write::SimpleFileOptions::default(),
            )
            .unwrap();
            zip.write_all(xml.as_bytes()).unwrap();
            zip.finish().unwrap();
        }
        assert_eq!(
            text_of("Notes.DOCX", &file).unwrap(),
            "Saltmere & its lamp\nTide\u{2019}s\tend\nBox"
        );
    }

    #[test]
    fn a_pdf_is_read_by_its_pages_and_a_broken_one_is_refused() {
        use lopdf::content::{Content, Operation};
        use lopdf::{Object, Stream, dictionary};
        let mut pdf = lopdf::Document::with_version("1.5");
        let pages = pdf.new_object_id();
        let font = pdf.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Courier", "Encoding" => "WinAnsiEncoding",
        });
        let resources = pdf.add_object(dictionary! { "Font" => dictionary! { "F1" => font } });
        let content = Content {
            operations: vec![
                Operation::new("BT", vec![]),
                Operation::new("Tf", vec!["F1".into(), 12.into()]),
                Operation::new("Td", vec![100.into(), 600.into()]),
                Operation::new("Tj", vec![Object::string_literal("The lamp of Saltmere")]),
                Operation::new("ET", vec![]),
            ],
        };
        let content = pdf.add_object(Stream::new(dictionary! {}, content.encode().unwrap()));
        let page = pdf
            .add_object(dictionary! { "Type" => "Page", "Parent" => pages, "Contents" => content });
        pdf.objects.insert(
            pages,
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Kids" => vec![page.into()], "Count" => 1, "Resources" => resources,
                "MediaBox" => vec![0.into(), 0.into(), 595.into(), 842.into()],
            }),
        );
        let catalog = pdf.add_object(dictionary! { "Type" => "Catalog", "Pages" => pages });
        pdf.trailer.set("Root", catalog);
        let mut file = Vec::new();
        pdf.save_to(&mut file).unwrap();
        assert!(
            text_of("a.pdf", &file)
                .unwrap()
                .contains("The lamp of Saltmere")
        );
        assert!(text_of("a.pdf", b"%PDF-1.5 not a document").is_err());
        assert!(text_of("a.png", b"text").is_err());
        assert!(text_of("a.txt", b" \n ").is_err());
        // Notepad's "Unicode" and "Unicode big endian".
        assert_eq!(text_of("a.txt", b"\xFF\xFEL\0a\0m\0p\0").unwrap(), "Lamp");
        assert_eq!(text_of("a.md", b"\xFE\xFF\0L\0a\0m\0p").unwrap(), "Lamp");
    }

    #[test]
    fn a_text_is_cut_into_pieces_by_its_lines_and_a_long_line_at_a_space() {
        let long = "word ".repeat(500);
        let text = format!("One.\nTwo.\n\n{long}\n{}", "x".repeat(1_500));
        let pieces = pieces(&text);
        assert_eq!(pieces[0], "One.\nTwo.");
        assert!(pieces.iter().all(|p| p.chars().count() <= PIECE_CHARS));
        assert!(pieces[1].ends_with("word") && pieces[1].len() > 1_000);
        assert_eq!(pieces.concat().matches("word").count(), 500);
        assert_eq!(pieces.last().unwrap().len(), 300);
    }

    #[test]
    fn a_reply_is_given_the_nearest_pieces_while_they_fit_its_budget() {
        let piece = |text: &str, toward: f32| Piece {
            document: 1,
            name: "Guide".into(),
            text: text.into(),
            embedding: to_bytes(&[toward, (1.0 - toward * toward).sqrt()]),
        };
        let pieces = || {
            vec![
                piece("behind", 0.8),
                piece("near", 0.89),
                piece("nearest", 0.9),
                piece("next", 0.88),
                piece("fourth", 0.875),
            ]
        };
        assert_eq!(
            excerpts(&[1.0, 0.0], pieces(), 1_000).unwrap(),
            "From \"Guide\":\nnearest\n\nFrom \"Guide\":\nnear\n\nFrom \"Guide\":\nnext"
        );
        assert_eq!(
            excerpts(&[1.0, 0.0], pieces(), 8).unwrap(),
            "From \"Guide\":\nnearest"
        );
        assert_eq!(excerpts(&[0.0, 1.0], vec![piece("far", 0.9)], 1_000), None);
    }
}

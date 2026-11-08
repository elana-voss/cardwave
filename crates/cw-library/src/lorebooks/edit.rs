//! A lorebook's editor, for a lorebook of the library and a card's own alike
//! ([`Book`]): what it shows (`editable`), its entries changed, added, taken
//! out and put back, what it says of itself (`describe`), an entry's earlier
//! versions (`entry_drafts`) and its file (`export`). Each edit goes through
//! `rewrite`. A library lorebook's text is written only where it is still the
//! one read, else the edit is made again, so of two edits made at once both
//! are kept, and what the library lists of it (`listed`) is kept with it. A
//! card's own is an edit of the card (`cards::change_with`): a new version in
//! the card's place. Both keep a version of each entry's words an edit changed
//! (`drafts::record`), made by `made`. A chat reads a lorebook when it asks
//! for a reply, so it has an edit from its next reply on. One in the Trash,
//! or of a card there, is not edited.

use anyhow::{Context, ensure};
use cw_ccv4::edit::Edited;
use cw_ccv4::lore::{self, EditEntry, EntryChange, RemovedEntry, Rewritten};
use cw_ccv4::{Document, drafts, mapping};
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};

use crate::cards;
use crate::lorebooks::{
    KeptLorebook, LorebookEdit, OwnedBy, Storage, brought_by, checked_name, get, left_out, listed,
};

/// Which lorebook an editor is of.
#[derive(Clone, Debug)]
pub enum Book {
    /// A lorebook of the library, by its ID.
    Library(i64),
    /// A lorebook a card brings itself: `book` (`lorebook.ID`), or the card's first where none is named.
    Card { card_id: i64, book: Option<String> },
}

impl From<i64> for Book {
    fn from(id: i64) -> Self {
        Book::Library(id)
    }
}

/// A lorebook as it is read for its editor.
struct Opened {
    /// The library lorebook's ID, or the card's.
    id: i64,
    document: Document,
    /// The lorebook in it, `lorebook.ID`.
    reference: String,
    /// When it came: an entry's words never changed are a version of then.
    since: i64,
    name: String,
    favorite: bool,
    archived: bool,
    everywhere: bool,
    card: Option<OwnedBy>,
}

/// The lorebook `lorebook_id` of `user` as it is kept. Not one in the Trash,
/// which is not edited.
pub(super) fn kept(db: &dyn Storage, user: i64, lorebook_id: i64) -> anyhow::Result<KeptLorebook> {
    let kept = db
        .kept_lorebook(user, lorebook_id)?
        .ok_or(NotFound("lorebook"))?;
    ensure!(
        !kept.trashed,
        Fail::said(
            Code::InTrash,
            format!(
                "the lorebook “{}” is in the Trash; restore it first",
                kept.name
            )
        )
        .with("what", "lorebook")
        .with("name", (kept.name).to_string())
    );
    Ok(kept)
}

/// The lorebook a card's `document` brings that `asked` names, or its first.
fn own_book(document: &Document, asked: Option<&str>) -> anyhow::Result<String> {
    let brought = brought_by(document);
    let found = match asked {
        Some(asked) => brought.into_iter().find(|book| *book == asked),
        None => brought.first().copied(),
    };
    Ok(found.ok_or(NotFound("lorebook"))?.to_string())
}

/// The lorebook `book` as it is now.
fn open(db: &dyn Storage, user: i64, book: &Book) -> anyhow::Result<Opened> {
    match book {
        Book::Library(id) => {
            let kept = kept(db, user, *id)?;
            let files = lore::files_of(&kept.toml)?;
            let document = Document::parse(&files)?;
            let reference = lore::book(&document).context(
                Fail::said(Code::NotReadable, "the lorebook is empty")
                    .with("what", "lorebook_empty"),
            )?;
            let listed = get(db, user, *id)?.ok_or(NotFound("lorebook"))?;
            Ok(Opened {
                id: *id,
                document,
                reference,
                since: kept.created_at,
                name: kept.name,
                favorite: listed.favorite,
                archived: listed.archived,
                everywhere: listed.everywhere,
                card: None,
            })
        }
        Book::Card { card_id, book } => {
            let (card, files) = cards::newest(db, user, *card_id)?;
            ensure!(
                !card.trashed,
                Fail::said(Code::InTrash, "the card is in the Trash; restore it first")
                    .with("what", "card")
            );
            let document = Document::parse(&files)?;
            let reference = own_book(&document, book.as_deref())?;
            let first = brought_by(&document).first() == Some(&reference.as_str());
            Ok(Opened {
                id: *card_id,
                name: mapping::lore_name(&document, &reference),
                card: Some(OwnedBy {
                    card_id: *card_id,
                    title: card.title,
                    reference: reference.clone(),
                    first,
                }),
                document,
                reference,
                since: card.created_at,
                favorite: false,
                archived: false,
                everywhere: false,
            })
        }
    }
}

/// A lorebook as its editor shows it: its name, what it says of itself and its
/// entries, as they are written; for a card's own, the card it is of.
pub fn editable(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
) -> anyhow::Result<LorebookEdit> {
    let opened = open(db, user, &book.into())?;
    let (document, reference) = (&opened.document, &opened.reference);
    Ok(LorebookEdit {
        id: opened.id,
        favorite: opened.favorite,
        archived: opened.archived,
        everywhere: opened.everywhere,
        description: lore::description(document, reference),
        scan_depth: lore::book_number(document, reference, "scan-depth"),
        token_budget: lore::book_number(document, reference, "token-budget"),
        entries: lore::entries(document, reference),
        blank: EditEntry::blank(),
        name: opened.name.clone(),
        card: opened.card.clone(),
    })
}

/// The versions of the entry `reference`'s words, the newest first (`drafts::list`).
pub fn entry_drafts(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    reference: &str,
) -> anyhow::Result<drafts::TextDrafts> {
    let opened = open(db, user, &book.into())?;
    Ok(drafts::list(&opened.document, reference, opened.since))
}

/// The lorebook as a file: Character Card V3's lorebook, `{"spec":
/// "lorebook_v3", "data": …}` with a card's `character_book` as `data` (the
/// owner, 2026-10-15), which the library imports again, named after it.
pub fn export(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
) -> anyhow::Result<cards::Exported> {
    let opened = open(db, user, &book.into())?;
    let world = serde_json::json!({
        "spec": "lorebook_v3",
        "data": cw_ccv4::sillytavern::world(&opened.document, &opened.reference),
    });
    Ok(cards::Exported {
        file_name: format!("{}.json", cards::file_stem(&opened.name, "lorebook")),
        data: serde_json::to_vec_pretty(&world)?,
    })
}

/// Makes an edit of a lorebook's files. `edit` is given them as they are and
/// the lorebook in them, and answers the files as they are to be (none where
/// they stay as they are) and what the caller is answered. A library
/// lorebook's is written only where it is still the one `edit` was given;
/// where another edit came first, `edit` is asked again. `name`, where there
/// is one, is what a library lorebook is called from then on.
fn rewrite<T>(
    db: &dyn Storage,
    user: i64,
    book: &Book,
    made: &str,
    name: Option<&str>,
    edit: impl Fn(&[(String, String)], &str) -> anyhow::Result<(Option<Rewritten>, T)>,
) -> anyhow::Result<T> {
    ensure!(
        drafts::made_by(made),
        Fail::said(
            Code::NotPossible,
            format!("a version is not made by “{made}”")
        )
        .with("what", "draft_made_by")
        .with("made", made.to_string())
    );
    let id = match book {
        Book::Library(id) => id,
        Book::Card { card_id, book } => {
            return cards::change_with(db, user, *card_id, made, |files| {
                let reference = own_book(&Document::parse(files)?, book.as_deref())?;
                let (rewritten, answer) = edit(files, &reference)?;
                let edited =
                    rewritten.map(|Rewritten { files, document }| Edited { files, document });
                Ok((edited, answer))
            });
        }
    };
    loop {
        let kept = kept(db, user, *id)?;
        let files = lore::files_of(&kept.toml)?;
        let before = Document::parse(&files)?;
        let reference = lore::book(&before).context(
            Fail::said(Code::NotReadable, "the lorebook is empty").with("what", "lorebook_empty"),
        )?;
        let (rewritten, answer) = edit(&files, &reference)?;
        let written = match rewritten {
            Some(Rewritten {
                mut files,
                document,
            }) => {
                drafts::record(
                    &mut files,
                    Some(&before),
                    &document,
                    made,
                    now_ms(),
                    kept.created_at,
                )?;
                let listed = listed(&document, &reference);
                db.write_lorebook(*id, &kept.toml, &lore::joined(&files), &listed, name)?
            }
            None => db.rename_lorebook(*id, name)?,
        };
        if written {
            return Ok(answer);
        }
    }
}

/// [`change_entry_as`], its words' version "edited".
pub fn change_entry(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    reference: &str,
    change: &EntryChange,
) -> anyhow::Result<EditEntry> {
    change_entry_as(db, user, book, reference, change, drafts::EDITED)
}

/// Changes an entry of a lorebook, for every chat that has the lorebook, from
/// its next reply on; new words are a version made by `made` (an AI tool's
/// key, "restored", …). Answers with the entry as it then is.
pub fn change_entry_as(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    reference: &str,
    change: &EntryChange,
    made: &str,
) -> anyhow::Result<EditEntry> {
    rewrite(db, user, &book.into(), made, None, |files, book| {
        lore::change(files, book, reference, change)
    })
}

/// Adds an entry to a lorebook, as its last. Answers with the entry. Of a
/// library lorebook, no entry is given the ID of one a chat has left out.
pub fn add_entry(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    entry: &EntryChange,
) -> anyhow::Result<EditEntry> {
    let book = book.into();
    let left_out = match book {
        Book::Library(id) => left_out(db, id)?,
        Book::Card { .. } => Default::default(),
    };
    rewrite(db, user, &book, drafts::EDITED, None, |files, book| {
        let (rewritten, entry) =
            lore::add(files, book, entry, |reference| left_out.contains(reference))?;
        Ok((Some(rewritten), entry))
    })
}

/// Takes an entry out of a lorebook. Answers with what puts it back
/// ([`restore_entry`]). What chats had left out of it stays noted, and its
/// words' versions stay.
pub fn remove_entry(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    reference: &str,
) -> anyhow::Result<RemovedEntry> {
    rewrite(
        db,
        user,
        &book.into(),
        drafts::EDITED,
        None,
        |files, book| {
            let (rewritten, removed) = lore::remove(files, book, reference)?;
            Ok((Some(rewritten), removed))
        },
    )
}

/// Puts an entry that was taken out of a lorebook back, as it was written
/// and where it stood. Answers with the entry.
pub fn restore_entry(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    removed: &RemovedEntry,
) -> anyhow::Result<EditEntry> {
    rewrite(
        db,
        user,
        &book.into(),
        drafts::EDITED,
        None,
        |files, book| {
            let (rewritten, entry) = lore::restore(files, book, removed)?;
            Ok((Some(rewritten), entry))
        },
    )
}

/// Gives a lorebook another name, another description, its own scan depth
/// and token budget (`numbers`, 0 for none): in its file and, of a library
/// lorebook, in the library. What is `None` stays. A name is kept on one
/// line; refused are one without a letter and one too long.
pub fn describe(
    db: &dyn Storage,
    user: i64,
    book: impl Into<Book>,
    name: Option<&str>,
    description: Option<&str>,
    numbers: [Option<u32>; 2],
) -> anyhow::Result<()> {
    let name = name.map(checked_name).transpose()?;
    let book = book.into();
    let listed_name = matches!(book, Book::Library(_))
        .then_some(name.as_deref())
        .flatten();
    rewrite(
        db,
        user,
        &book,
        drafts::EDITED,
        listed_name,
        |files, book| {
            Ok((
                lore::describe(files, book, name.as_deref(), description, numbers)?,
                (),
            ))
        },
    )
}

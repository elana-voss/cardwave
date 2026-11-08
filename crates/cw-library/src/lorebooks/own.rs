//! The lorebooks cards bring themselves, as the library lists them (`own_rows`,
//! "in [card]" after the name), and moved into the library ("Move to
//! library": a library lorebook attached to the card, its entries' history
//! with it) and back again (`move_back`, the notice's Undo, refused once
//! another card or a chat has it).

use anyhow::{Context, ensure};
use cw_ccv4::edit::Edited;
use cw_ccv4::lore::{self, Rewritten};
use cw_ccv4::{Document, drafts, mapping};
use cw_core::NotFound;
use cw_core::{Code, Fail};

use crate::cards::{self, Show};
use crate::lorebooks::{
    CardLoreSource, Lorebook, MAX_DESCRIPTION, MAX_LISTED, OwnedBy, Storage, add, brought_by, get,
    set_trashed, short,
};
use crate::trash;

/// The lorebooks the cards of `user` bring, as the library lists them beside
/// its own: of cards not in the Trash, none among the favourites, those of
/// archived cards where archived ones are shown or searched for. Only the
/// documents of cards that bring one are read (`cards_bringing_lore`).
pub(super) fn own_rows(
    db: &dyn Storage,
    user: i64,
    show: Show,
    searching: bool,
) -> anyhow::Result<Vec<Lorebook>> {
    let mut rows = Vec::new();
    for card in db.cards_bringing_lore(user)? {
        let shown = match show {
            Show::Favorites => false,
            Show::Archived => card.archived,
            Show::All => !card.archived || searching,
        };
        if card.trashed || !shown {
            continue;
        }
        let document = cards::document_of(db, card.version_id)?;
        for (at, reference) in brought_by(&document).into_iter().enumerate() {
            let entries = mapping::entries(&document, reference);
            let about = lore::description(&document, reference);
            rows.push(Lorebook {
                id: card.id,
                name: mapping::lore_name(&document, reference),
                description: short(&about, MAX_DESCRIPTION),
                entries: entries.len() as u32,
                entry_names: entries
                    .iter()
                    .take(MAX_LISTED)
                    .map(|entry| mapping::lore_name(&document, entry))
                    .collect(),
                favorite: false,
                archived: card.archived,
                trashed: false,
                everywhere: false,
                used_by: Vec::new(),
                chats: 0,
                card: Some(OwnedBy {
                    card_id: card.id,
                    title: card.title.clone(),
                    reference: reference.to_string(),
                    first: at == 0,
                }),
            });
        }
    }
    Ok(rows)
}

/// Moves a lorebook a card brings into the library: a lorebook of the library,
/// called as the card calls it, with its entries and their history, attached
/// to the card, which no longer brings it. Its chats have it from their next
/// reply on as the card's attached one. Answers with the new lorebook.
pub fn move_to_library(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    reference: &str,
) -> anyhow::Result<Lorebook> {
    let card = cards::get(db, user, card_id)?.ok_or(NotFound("card"))?;
    ensure!(
        !card.trashed,
        Fail::said(Code::InTrash, "the card is in the Trash; restore it first")
            .with("what", "card")
    );
    let document = cards::document_of(db, card.version_id)?;
    ensure!(
        brought_by(&document).contains(&reference),
        Fail::said(Code::NotPossible, "the card brings no such lorebook")
            .with("what", "card_lorebook")
    );
    let toml = lore::alone(&document, reference)?.context(
        Fail::said(Code::NotPossible, "the card brings no such lorebook")
            .with("what", "card_lorebook"),
    )?;
    let name = document
        .lookup(reference)
        .and_then(|book| book.get("name")?.as_str())
        .unwrap_or("");
    let moved = add(db, user, &toml, [name, &card.title])?;
    // Attached before the card lets go of its own, so that a failure of either
    // leaves the card as it was: the lorebook made of it goes again.
    let taken = db.attach_lorebook(card_id, moved.id).and_then(|()| {
        cards::change_with(db, user, card_id, drafts::EDITED, |files| {
            let Rewritten { files, document } = lore::take_out(files, reference)?;
            Ok((Some(Edited { files, document }), ()))
        })
    });
    if let Err(error) = taken {
        db.detach_lorebook(card_id, moved.id)?;
        set_trashed(db, user, moved.id, true)?;
        trash::delete_lorebook(db, user, moved.id)?;
        return Err(error);
    }
    Ok(get(db, user, moved.id)?.ok_or(NotFound("lorebook"))?)
}

/// Undoes [`move_to_library`]: the lorebook `lorebook_id`, attached to the
/// card, is put back into the card as its own, as it now reads, with its
/// entries' history, and deleted from the library for good. Refused where
/// another card or a chat has it by now, which would lose it.
pub fn move_back(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    lorebook_id: i64,
) -> anyhow::Result<()> {
    let attached = db.attached_lorebooks(card_id)?;
    ensure!(
        attached
            .iter()
            .any(|one| one.source == CardLoreSource::LorebookId(lorebook_id)),
        Fail::said(Code::NotPossible, "the card has no such lorebook attached")
            .with("what", "card_lorebook_attached")
    );
    ensure!(
        db.lorebook_uses(lorebook_id)? == 1,
        Fail::said(
            Code::NotNow,
            "the lorebook is used elsewhere by now, so it stays in the library"
        )
        .with("what", "lorebook_used_elsewhere")
    );
    let kept = crate::lorebooks::edit::kept(db, user, lorebook_id)?;
    let from = Document::parse(&lore::files_of(&kept.toml)?)?;
    let book = lore::book(&from).context(
        Fail::said(Code::NotReadable, "the lorebook is empty").with("what", "lorebook_empty"),
    )?;
    cards::change_with(db, user, card_id, drafts::EDITED, |files| {
        let Rewritten { files, document } = lore::put_in(files, &from, &book)?;
        Ok((Some(Edited { files, document }), ()))
    })?;
    db.detach_lorebook(card_id, lorebook_id)?;
    set_trashed(db, user, lorebook_id, true)?;
    trash::delete_lorebook(db, user, lorebook_id)
}

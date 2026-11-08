//! A card's versions: an edit stored as a new version in the card's place, the
//! card's chats moved to it (`retire`), and an older build's versions folded
//! into drafts at a start (`fold_versions`); a translation kept as a whole
//! (`translate`, a language of the card's, ccv4/languages.rs); another picture
//! shown (`use_picture`, of `pictures`). Trap: `change_as` asks for the card's
//! version again inside its transaction, and fails as `Late` when another saved
//! first; `change_with` and `use_picture` then make their change again.

use anyhow::{anyhow, bail, ensure};
use cw_ccv4::edit::{self, CardEdit};
use cw_ccv4::languages::{self, Translation};
use cw_ccv4::{Document, drafts};
use cw_core::{Code, Fail};
use cw_core::{NotFound, now_ms};

use crate::describe;

use crate::cards::{
    CardSummary, CardVersion, SavedEdit, Storage, document_of, index_of, newest, tags, toml_of,
};

/// A card as its editor shows it: the library's title, and what its newest
/// version says, as it is written, in `language` where the card has it. Not a
/// card in the Trash, which is not edited.
pub fn editable(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    language: Option<&str>,
) -> anyhow::Result<CardEdit> {
    let (card, files) = kept_card(db, user, card_id)?;
    Ok(CardEdit::of(
        &Document::parse(&files)?,
        card.version,
        &card.title,
        language,
    ))
}

/// The entries of the card's own lorebooks, as they are translated (`languages::lore_texts`).
pub fn lore_texts(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
) -> anyhow::Result<Vec<languages::LoreText>> {
    let (_, files) = kept_card(db, user, card_id)?;
    Ok(languages::lore_texts(&Document::parse(&files)?))
}

/// Keeps a translation of the card (`languages::add`), each text of it a draft
/// "translated"; refused where the card was changed after it was translated.
pub fn translate(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    translation: &Translation,
) -> anyhow::Result<CardVersion> {
    change_as(
        db,
        user,
        card_id,
        translation.version,
        None,
        drafts::TRANSLATED,
        None,
        |files, now, _| languages::add(files, translation, now).map(Some),
    )
}

/// A card of `user` that can be edited and given a version, one that is not in
/// the Trash, with its newest version's files ([`newest`]).
pub(super) fn kept_card(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
) -> anyhow::Result<(CardSummary, Vec<(String, String)>)> {
    let (card, files) = newest(db, user, card_id)?;
    ensure!(
        !card.trashed,
        Fail::said(Code::InTrash, "the card is in the Trash; restore it first")
            .with("what", "card")
    );
    Ok((card, files))
}

/// The drafts of the card's text `reference` (see [`drafts::list`]).
pub fn drafts(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    reference: &str,
) -> anyhow::Result<drafts::TextDrafts> {
    let (card, files) = newest(db, user, card_id)?;
    let mut listed = drafts::list(&Document::parse(&files)?, reference, card.created_at);
    listed.file = db.card_file(card_id)?;
    Ok(listed)
}

/// [`edit_as`], each text changed a draft "edited".
pub fn edit(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    edit: &CardEdit,
) -> anyhow::Result<CardVersion> {
    edit_as(db, user, card_id, edit, drafts::EDITED)
}

/// Saves an edit of a card: a new version in the place of the card's, with its
/// picture, assets and files, and in the files what the edit changed (see
/// [`edit::apply`]) with a draft of each text it changed; the chats move to it.
/// A new title is the card's from then on, in the library and in the new
/// version's file; each draft made by `made` (`drafts::made_by`). An
/// edit that changes nothing adds no version. Not an edit of another version
/// than the card's (the card was changed after it was read), not one without
/// a title, and not on a card in the Trash. Answers with the card's version.
pub fn edit_as(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    edit: &CardEdit,
    made: &str,
) -> anyhow::Result<CardVersion> {
    let title = edit.title.trim();
    ensure!(
        !title.is_empty(),
        Fail::said(Code::Needed, "a card needs a title").with("what", "card_title")
    );
    change_as(
        db,
        user,
        card_id,
        edit.version,
        Some(title),
        made,
        None,
        |files, now, renamed| edit::apply(files, edit, renamed.then_some(title), now),
    )
}

/// Changes the card's newest files by `change`, which answers them as they are
/// to be (`None` where they stay) and what the caller is answered; saved as
/// [`edit_as`] saves an edit, each text changed a draft made by `made`. A
/// card's own lorebook is edited so (`lorebooks::edit`). Where another change
/// was saved meanwhile, `change` is made again of the card as it then is.
pub fn change_with<T>(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    made: &str,
    change: impl Fn(&[(String, String)]) -> anyhow::Result<(Option<edit::Edited>, T)>,
) -> anyhow::Result<T> {
    retried(|| {
        let (card, _) = kept_card(db, user, card_id)?;
        let mut answer = None;
        change_as(
            db,
            user,
            card_id,
            card.version,
            None,
            made,
            None,
            |files, _, _| {
                let (edited, said) = change(files)?;
                answer = Some(said);
                Ok(edited)
            },
        )?;
        answer.ok_or_else(|| {
            anyhow!(
                Fail::said(Code::NotPossible, "the card was not changed")
                    .with("what", "card_not_changed")
            )
        })
    })
}

/// Has the card show its picture `picture` (a blob of `card_pictures`): a new
/// version in its place with the same files, saved as [`edit_as`] saves an
/// edit. Where another change was saved meanwhile, it is made again.
pub(super) fn use_picture(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    picture: i64,
) -> anyhow::Result<(CardVersion, i64)> {
    retried(|| {
        // The picture shown before is read after the version it is changed from,
        // so a version saved between them makes the change late and read anew.
        let (card, _) = kept_card(db, user, card_id)?;
        let kept = db.card_pictures(user, card_id)?;
        ensure!(
            kept.iter().any(|one| one.id == picture),
            cw_core::NotFound("picture")
        );
        let before = kept
            .iter()
            .find(|one| one.in_use)
            .map_or(picture, |one| one.id);
        if before == picture {
            let version = CardVersion {
                id: card.version_id,
                number: card.version,
                created_at: db.version_made(card.version_id)?,
            };
            return Ok((version, before));
        }
        let version = change_as(
            db,
            user,
            card_id,
            card.version,
            None,
            drafts::EDITED,
            Some(picture),
            |files, _, _| {
                Ok(Some(edit::Edited {
                    files: files.to_vec(),
                    document: Document::parse(files)?,
                }))
            },
        )?;
        Ok((version, before))
    })
}

/// Runs `once` again, up to five times in all, while it fails as [`Late`].
/// Whether `error` is a change of a version of a card that is not its newest by now.
fn is_late(error: &anyhow::Error) -> bool {
    let detail = Some(&cw_core::Detail::from("card_version"));
    error
        .downcast_ref::<Fail>()
        .is_some_and(|fail| fail.code == Code::Changed && fail.details.get("what") == detail)
}

fn retried<T>(mut once: impl FnMut() -> anyhow::Result<T>) -> anyhow::Result<T> {
    let mut tries = 0;
    loop {
        tries += 1;
        match once() {
            Err(error) if tries < 5 && is_late(&error) => continue,
            done => return done,
        }
    }
}

/// Saves a change of the card's files that `change` makes of them at a moment,
/// told whether the title is another (`None` where it changes nothing), made of
/// its version `version`, as [`edit_as`] says; `title` the card's title from
/// then on, where it names one, and `image` the picture it shows, where another.
#[allow(clippy::too_many_arguments)] // Each says one thing of the change; a struct would only rename them.
fn change_as(
    db: &dyn Storage,
    user: i64,
    card_id: i64,
    version: i64,
    title: Option<&str>,
    made: &str,
    image: Option<i64>,
    change: impl FnOnce(&[(String, String)], i64, bool) -> anyhow::Result<Option<edit::Edited>>,
) -> anyhow::Result<CardVersion> {
    ensure!(
        drafts::made_by(made),
        Fail::said(
            Code::NotPossible,
            format!("a draft is not made by “{made}”")
        )
        .with("what", "draft_made_by")
        .with("made", made.to_string())
    );
    let (card, files) = kept_card(db, user, card_id)?;
    // A change made of a version of a card that is not its newest by now.
    let late = |newest: i64| {
        anyhow::Error::new(
            Fail::said(
                Code::Changed,
                format!(
                    "the card was changed meanwhile (v{newest}, not v{version}); it is read anew"
                ),
            )
            .with("what", "card_version")
            .with("newest", newest.to_string())
            .with("version", version.to_string()),
        )
    };
    if version != card.version {
        return Err(late(card.version));
    }
    let title = title.unwrap_or(&card.title);
    let renamed = title != card.title;
    let now = now_ms();
    let Some(mut edited) = change(&files, now, renamed)? else {
        return Ok(CardVersion {
            id: card.version_id,
            number: card.version,
            created_at: version_made(db, card.version_id)?,
        });
    };
    drafts::record(
        &mut edited.files,
        Some(&Document::parse(&files)?),
        &edited.document,
        made,
        now,
        card.created_at,
    )?;
    let new_tags = tags(&edited.document);
    let own_tags = |own: &str, before: &str| {
        let read = |json: &str| serde_json::from_str::<Vec<String>>(json).unwrap_or_default();
        let own = describe::own_after(&read(own), &read(before), &new_tags);
        serde_json::json!(own).to_string()
    };
    let saved = db.save_edit(&SavedEdit {
        card_id,
        version: card.version,
        version_id: card.version_id,
        now,
        files: &edited.files,
        title,
        renamed,
        own_tags: &own_tags,
        index: &index_of(title, Some(&edited.document)),
        document: &edited.document,
        image,
    })?;
    saved.map_err(|newest| newest.map_or_else(|| NotFound("card").into(), late))
}

/// When a version was made.
fn version_made(db: &dyn Storage, version_id: i64) -> anyhow::Result<i64> {
    db.version_made(version_id)
}

/// Makes the card versions an older build kept into the texts' history: each
/// card with several keeps its newest alone, with a draft of each text as each
/// version before had it otherwise (as edited, at the time it was made), and
/// its chats move to it. Run when the server starts alone on its data. A card
/// that cannot be read, or one with a chat with a character its newest version
/// lacks, keeps its versions and is tried again at the next start.
pub fn fold_versions(db: &dyn Storage) -> anyhow::Result<()> {
    let cards = db.cards_with_versions()?;
    for card_id in &cards {
        if let Err(error) = fold(db, *card_id) {
            tracing::warn!("the versions of card {card_id} stay as they are: {error:#}");
        }
    }
    if !cards.is_empty() {
        db.remove_unused_blobs()?;
    }
    Ok(())
}

/// [`fold_versions`] for one card.
fn fold(db: &dyn Storage, card_id: i64) -> anyhow::Result<()> {
    let versions = db.versions_of(card_id)?;
    let Some((&(first, since), later)) = versions.split_first() else {
        return Ok(());
    };
    let keep = later.last().map_or(first, |(id, _)| *id);
    let newest = document_of(db, keep)?;
    let characters = db.characters_chatted(card_id)?;
    if let Some(lacking) = characters
        .iter()
        .find(|one| newest.character(one).is_none())
    {
        bail!(
            Fail::said(
                Code::NotPossible,
                format!("a chat is with the character {lacking:?}, which its newest version lacks")
            )
            .with("what", "version_lacks_character")
        );
    }
    let mut files = toml_of(db, first)?;
    let mut before = Document::parse(&files)?;
    for &(id, at) in later {
        // A version's own `user/` files are a copy of the one's before but where an edit wrote into a
        // pinned draft; the drafts are in these.
        let own = toml_of(db, id)?;
        let mut next: Vec<(String, String)> = own
            .iter()
            .filter(|(name, _)| name.starts_with("card/"))
            .cloned()
            .collect();
        next.extend(
            files
                .into_iter()
                .filter(|(name, _)| !name.starts_with("card/")),
        );
        drafts::take_pins(&mut next, &Document::parse(&own)?)?;
        let after = Document::parse(&next)?;
        drafts::record(&mut next, Some(&before), &after, drafts::EDITED, at, since)?;
        files = next;
        before = after;
    }
    // What is written has to read as a card.
    Document::parse(&files)?;
    db.fold_into(card_id, keep, &files, &before)?;
    Ok(())
}

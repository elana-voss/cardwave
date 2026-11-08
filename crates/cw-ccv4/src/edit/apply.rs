//! [`apply`]: an edit written into a card's files, a character at a time
//! (`character_edit`), then what the whole card holds (`card_edit`), checked
//! against the card as it reads afterwards (`finish`).

use anyhow::{Context, bail, ensure};
use cw_core::{Code, Fail};
use toml_edit::visit::Visit;
use toml_edit::{Datetime, DocumentMut};

use crate::mapping::Section;
use crate::{Document, plain, tag_key, tidy_modes, written_date};

use crate::edit::{
    Card, CardEdit, EditCharacter, EditText, Named, character, greetings, of_block, set, set_list,
    tidy,
};

/// A card with an edit made in it.
pub struct Edited {
    /// The card's TOML files, each with its name: all of them, in the order they were given in.
    pub files: Vec<(String, String)>,
    /// The card as it reads now.
    pub document: Document,
}

/// Makes `edit` in a card's `files`, given as (file name, TOML). `title` is the
/// card's new title where the edit changes it, and `now` the moment in
/// milliseconds, which the card is told as when it was last modified. Answers
/// with the card as it is then; `None` when the edit changes nothing: no file,
/// and not the title. What the edit does not show stays as it is written.
///
/// Refused: a character the card has not, a character without a name, a
/// talkativeness beyond 0 and 1, a text in a mode the card has not, a block
/// that is not among the texts the editor shows of that character, and an
/// edit that the card would not read as it was made (a character that a
/// pinned draft stands in for).
pub fn apply(
    files: &[(String, String)],
    edit: &CardEdit,
    title: Option<&str>,
    now: i64,
) -> anyhow::Result<Option<Edited>> {
    let document = Document::parse(files)?;
    let mut card = Card::open(&document, files)?;
    // Greetings taken off a character: gone from the card unless something else names them.
    let mut dropped: Vec<String> = Vec::new();
    let modes = tidy_modes(edit.modes.iter().map(String::as_str));
    // A text's modes as kept, the card's as it names them; refused where the card has no such mode.
    let modes_of = |part: &EditText| -> anyhow::Result<Vec<String>> {
        tidy_modes(part.modes.iter().map(String::as_str))
            .into_iter()
            .map(|asked| {
                let mode = modes.iter().find(|mode| tag_key(mode) == tag_key(&asked));
                mode.cloned().with_context(|| {
                    Fail::said(
                        Code::NotPossible,
                        format!("{asked:?} is no mode of this card"),
                    )
                    .with("what", "card_mode")
                })
            })
            .collect()
    };
    for asked in &edit.characters {
        character_edit(&mut card, &document, asked, &modes_of, &mut dropped)?;
    }
    card_edit(&mut card, &document, edit, modes, title)?;

    if !dropped.is_empty() {
        let mut named = Named::default();
        for file in &card.files {
            named.visit_document(file);
        }
        dropped.retain(|reference| !named.0.contains(reference.as_str()));
    }
    for reference in &dropped {
        card.remove(reference);
    }
    finish(card, files, title, now)
}

/// A text's modes as the card names them (`apply`'s `modes_of`).
type ModesOf<'m> = dyn Fn(&EditText) -> anyhow::Result<Vec<String>> + 'm;

/// Writes what `asked` changes of its character into `card`; the greetings it
/// takes off go into `dropped`.
fn character_edit(
    card: &mut Card<'_>,
    document: &Document,
    asked: &EditCharacter,
    modes_of: &ModesOf<'_>,
    dropped: &mut Vec<String>,
) -> anyhow::Result<()> {
    let id = asked.id.as_str();
    let shown = character(document, id).with_context(|| {
        Fail::said(
            Code::NotPossible,
            format!("the card has no character {id:?}"),
        )
        .with("what", "card_character")
    })?;

    let name = plain(&asked.name);
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "a character needs a name").with("what", "character_name")
    );
    if name != shown.name {
        card.write_under(id, "name-char", "name", &name)?;
        // A label that was the name stays the name.
        if shown.label == shown.name {
            set(card.character(id)?, "name-card", &name);
        }
        let (id, name) = (id.to_string(), name.clone());
        card.expect(format!("the name of {id}"), move |after| {
            after.character_name(&id) == name
        });
    }

    texts(card, asked, &shown, modes_of)?;
    for (key, asked, shown) in [
        ("greetings", &asked.greetings, &shown.greetings),
        (
            "group-greetings",
            &asked.group_greetings,
            &shown.group_greetings,
        ),
    ] {
        greetings(card, document, id, key, asked, shown, modes_of, dropped)?;
    }

    let notes = plain(&asked.creator_notes);
    if notes != shown.creator_notes {
        card.write_under(id, "creator-note", "creator-note", &notes)?;
        let id = id.to_string();
        card.expect(format!("the creator notes of {id}"), move |after| {
            plain(after.creator_note(&id).unwrap_or("")) == notes
        });
    }

    let talkativeness = asked.talkativeness;
    ensure!(
        (0.0..=1.0).contains(&talkativeness),
        Fail::said(
            Code::OutOfRange,
            format!("the talkativeness of {id} is not between 0 and 1")
        )
        .with("what", "talkativeness")
        .with("id", id.to_string())
    );
    if talkativeness != shown.talkativeness {
        set(card.character(id)?, "group-talkativeness", talkativeness);
        let id = id.to_string();
        card.expect(format!("the talkativeness of {id}"), move |after| {
            after.talkativeness(&id) == talkativeness
        });
    }
    Ok(())
}

/// Writes a character's texts of each kind (but its greetings) as `asked`
/// has them, where `shown` had them otherwise.
fn texts(
    card: &mut Card<'_>,
    asked: &EditCharacter,
    shown: &EditCharacter,
    modes_of: &ModesOf<'_>,
) -> anyhow::Result<()> {
    let id = asked.id.as_str();
    // A note at a depth is changed, never added: a new one would have no depth.
    if asked
        .depth_prompts
        .iter()
        .any(|one| one.part.reference.is_none() && !plain(&one.part.text).is_empty())
    {
        bail!(
            Fail::said(Code::NotPossible, "a note at a depth cannot be added")
                .with("what", "depth_note")
        );
    }
    // Each kind of text, and whether a new one stands after the chat.
    let depth_asked: Vec<EditText> = asked
        .depth_prompts
        .iter()
        .map(|one| one.part.clone())
        .collect();
    let depth_had: Vec<EditText> = shown
        .depth_prompts
        .iter()
        .map(|one| one.part.clone())
        .collect();
    let fields = [
        (
            Section::Description.kind(),
            false,
            &asked.description,
            &shown.description,
        ),
        (
            Section::Personality.kind(),
            false,
            &asked.personality,
            &shown.personality,
        ),
        (
            Section::Scenario.kind(),
            false,
            &asked.scenario,
            &shown.scenario,
        ),
        (
            Section::Examples.kind(),
            false,
            &asked.example_dialogue,
            &shown.example_dialogue,
        ),
        ("prompt", false, &asked.system_prompt, &shown.system_prompt),
        ("prompt", true, &asked.post_history, &shown.post_history),
        ("prompt", false, &depth_asked, &depth_had),
    ];
    for (kind, after_chat, parts, had) in fields {
        for part in parts {
            let text = plain(&part.text);
            let used_in = modes_of(part)?;
            match &part.reference {
                Some(reference) => {
                    let before = of_block(had, reference);
                    let before = before.with_context(|| {
                        Fail::said(
                            Code::NotPossible,
                            format!("{reference} is no {kind} of {id} to change"),
                        )
                        .with("what", "card_part")
                        .with("reference", reference.to_string())
                        .with("kind", kind.to_string())
                        .with("id", id.to_string())
                    })?;
                    if text != before.text {
                        card.write(reference, &text)?;
                    }
                    if used_in != before.modes {
                        card.set_modes(reference, &used_in)?;
                    }
                }
                None if !text.is_empty() => {
                    let reference = card.add(id, kind, &text)?;
                    if after_chat {
                        card.place_after_chat(id, &reference)?;
                    } else {
                        card.place(id, &reference)?;
                    }
                    if !used_in.is_empty() {
                        card.set_modes(&reference, &used_in)?;
                    }
                }
                None => {}
            }
        }
    }
    Ok(())
}

/// Writes what `edit` changes of the whole card: its modes, tags, creator and
/// `title`.
fn card_edit(
    card: &mut Card<'_>,
    document: &Document,
    edit: &CardEdit,
    modes: Vec<String>,
    title: Option<&str>,
) -> anyhow::Result<()> {
    if modes != document.modes() {
        if modes.is_empty() {
            card.meta("modes")?.remove("modes");
        } else {
            set_list(card.meta("modes")?, "modes", &modes);
        }
        card.expect("the modes".to_string(), move |after| after.modes() == modes);
    }
    let tags = tidy(&edit.tags);
    if tags != tidy(&document.tags()) {
        set_list(card.meta("tags")?, "tags", &tags);
        card.expect("the tags".to_string(), move |after| after.tags() == tags);
    }
    let creator = plain(&edit.creator);
    if creator != document.creator().unwrap_or("") {
        if creator.is_empty() {
            card.meta("creator")?.remove("creator");
        } else {
            set(card.meta("creator")?, "creator", &creator);
        }
        card.expect("the creator".to_string(), move |after| {
            after.creator().unwrap_or("") == creator
        });
    }
    if let Some(title) = title {
        set(card.meta("title")?, "title", title);
    }
    Ok(())
}

/// The card's files as the edit leaves them, read and checked; `None` where
/// nothing changed (`apply`).
fn finish(
    mut card: Card<'_>,
    files: &[(String, String)],
    title: Option<&str>,
    now: i64,
) -> anyhow::Result<Option<Edited>> {
    // A new title is an edit also where the file has it already: it is the library's that changes.
    let written = |card: &Card<'_>| {
        card.files
            .iter()
            .map(DocumentMut::to_string)
            .collect::<Vec<_>>()
    };
    if title.is_none() && written(&card) == card.untouched {
        return Ok(None);
    }
    let modified: Datetime = written_date(now)?.parse()?;
    set(card.meta("modified")?, "modified", modified);

    // A file nothing was changed in stays as it was given, to the letter.
    let after: Vec<(String, String)> = files
        .iter()
        .zip(written(&card).into_iter().zip(&card.untouched))
        .map(|((name, given), (written, untouched))| {
            (
                name.clone(),
                if written == *untouched {
                    given.clone()
                } else {
                    written
                },
            )
        })
        .collect();
    let read = Document::parse(&after).context(
        Fail::said(
            Code::NotPossible,
            "the card cannot be read with this edit made",
        )
        .with("what", "edit_breaks_card"),
    )?;
    for (what, holds) in &card.checks {
        if !holds(&read) {
            bail!(
                Fail::said(
                    Code::NotPossible,
                    format!("{what} cannot be changed in this card")
                )
                .with("what", "card_change")
            );
        }
    }
    Ok(Some(Edited {
        files: after,
        document: read,
    }))
}

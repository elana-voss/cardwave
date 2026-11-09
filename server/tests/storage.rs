mod common;

use common::{Scratch, reply, user, writing};
use cw_accounts::users;
use cw_ccv4::png;
use cw_chat::chats::{self, NewChat, NewMessage};
use cw_library::cards;
use cw_library::personas;
use cw_prompt::builder::{PromptRequest, build};
use cw_prompt::{PromptMessage, Role, Variables};

fn count(scratch: &Scratch, table: &str) -> i64 {
    scratch
        .db
        .with(|c| c.query_row(&format!("select count(*) from {table}"), [], |r| r.get(0)))
        .unwrap()
}

fn busy(refused: anyhow::Error) -> bool {
    cw_core::coded(&refused).is_some_and(|fail| fail.code == cw_core::Code::ChatBusy)
}

fn texts(messages: &[chats::Message]) -> Vec<&str> {
    messages.iter().map(|m| m.content.as_str()).collect()
}

/// Imports the sample card and starts a chat with Mira.
fn chat_with_mira(scratch: &Scratch, persona_id: Option<i64>, greeting: usize) -> i64 {
    let card = common::import_whole(&scratch.db, scratch.user, &common::card_copy()).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id,
        greeting,
    };
    chats::create(&scratch.db, scratch.user, &new).unwrap()
}

#[test]
fn an_imported_card_is_kept_whole() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let imported = common::import_whole(db, me, &common::card_file()).unwrap();
    assert_eq!(imported.title, "Mira of the North Light");
    assert_eq!(imported.version, 1);
    // The import tells that it kept the first character alone (`import_whole` puts the second back).
    assert_eq!(imported.warnings.len(), 1, "{:?}", imported.warnings);

    let card = cards::get(db, me, imported.card_id).unwrap().unwrap();
    assert_eq!(
        (card.title.as_str(), card.version_id, card.version),
        ("Mira of the North Light", imported.version_id, 1)
    );
    // The file's own user state (it says favorite) is not taken over.
    assert_eq!(
        (card.favorite, card.archived, card.trashed),
        (false, false, false)
    );

    let document = cards::document(db, me, imported.version_id).unwrap();
    assert_eq!(document.ids("character"), ["mira", "bare"]);
    assert_eq!(document.text("personality.mira"), Some("Wry, patient."));
    let avatar = document.avatar("mira").unwrap();
    assert_eq!(
        cards::asset(db, me, imported.version_id, avatar)
            .unwrap()
            .unwrap(),
        common::AVATAR
    );
    assert_eq!(
        cards::asset(db, me, imported.version_id, "card/none.png").unwrap(),
        None
    );
    assert_eq!(
        cards::image(db, me, imported.version_id).unwrap().unwrap(),
        common::picture()
    );
}

#[test]
fn equal_content_is_stored_once() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let first = common::import_whole(db, me, &common::card_file()).unwrap();
    assert_eq!(count(&scratch, "blobs"), 2);

    // The same file again is refused; one that differs in a text is a card of its own, its picture stored once.
    let again = common::import_whole(db, me, &common::card_file()).unwrap_err();
    assert_eq!(again.to_string(), "already in your library");
    let other = common::import_whole(db, me, &common::card_copy()).unwrap();
    assert_ne!(other.card_id, first.card_id);
    assert_eq!(cards::list(db, me).unwrap().len(), 2);
    assert_eq!(count(&scratch, "blobs"), 2);

    assert_eq!(count(&scratch, "card_versions"), 2);
}

#[test]
fn files_that_are_not_cards_change_nothing() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let error = common::import_whole(db, me, &common::picture()).unwrap_err();
    assert!(error.to_string().contains("no character card"));
    assert!(common::import_whole(db, me, b"not a png").is_err());

    let mut container = common::container();
    container.toml[1]
        .1
        .push_str("\n[name.mira]\ntext = \"Twice\"\n");
    assert!(common::import_whole(db, me, &png::write(&container).unwrap()).is_err());
    assert_eq!(count(&scratch, "cards") + count(&scratch, "blobs"), 0);
}

#[test]
fn cards_and_chats_can_be_marked_archived_and_trashed() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let card_id = cards::list(db, me).unwrap()[0].id;

    cards::set_archived(db, me, card_id, true).unwrap();
    cards::set_trashed(db, me, card_id, true).unwrap();
    cards::set_favorite(db, me, card_id, true).unwrap();
    let card = cards::get(db, me, card_id).unwrap().unwrap();
    assert_eq!(
        (card.favorite, card.archived, card.trashed),
        (true, true, true)
    );
    // Out of the trash it is archived again, as before.
    cards::set_trashed(db, me, card_id, false).unwrap();
    let card = cards::get(db, me, card_id).unwrap().unwrap();
    assert_eq!((card.archived, card.trashed), (true, false));
    assert!(cards::set_favorite(db, me, 999, true).is_err());

    chats::set_archived(db, me, chat_id, true).unwrap();
    chats::set_favorite(db, me, chat_id, true).unwrap();
    chats::set_trashed(db, me, chat_id, true).unwrap();
    let chat = chats::get(db, me, chat_id).unwrap().unwrap();
    assert_eq!(
        (chat.favorite, chat.archived, chat.trashed),
        (true, true, true)
    );
    assert!(chats::set_trashed(db, me, 999, true).is_err());
}

#[test]
fn nobody_reaches_another_users_cards_chats_or_personas() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let persona = personas::create(db, me, "Ines", "A surveyor.").unwrap();
    let chat_id = chat_with_mira(&scratch, Some(persona), 0);
    let card = cards::list(db, me).unwrap().remove(0);
    let first = chats::path(db, me, chat_id).unwrap().remove(0);
    let state = chats::prompt_inputs(db, me, chat_id, None).unwrap().state;

    let sam = users::create(db, "sam").unwrap();
    assert!(cards::list(db, sam).unwrap().is_empty());
    assert!(cards::get(db, sam, card.id).unwrap().is_none());
    assert!(cards::document(db, sam, card.version_id).is_err());
    assert!(
        cards::asset(db, sam, card.version_id, "card/images/mira.png")
            .unwrap()
            .is_none()
    );
    assert!(cards::image(db, sam, card.version_id).unwrap().is_none());
    assert!(cards::set_trashed(db, sam, card.id, true).is_err());
    assert!(personas::get(db, sam, persona).unwrap().is_none());

    let theirs = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id: None,
        greeting: 0,
    };
    assert!(chats::create(db, sam, &theirs).is_err());
    assert!(chats::get(db, sam, chat_id).unwrap().is_none());
    assert!(chats::participants(db, sam, chat_id).unwrap().is_empty());
    assert!(chats::path(db, sam, chat_id).is_err());
    assert!(chats::swipes(db, sam, first.id).unwrap().is_empty());
    assert!(
        chats::find(db, sam, &chats::Find::default())
            .unwrap()
            .is_empty()
    );
    assert!(chats::branch(db, sam, chat_id).is_err());
    assert!(chats::show_branch(db, sam, chat_id, first.id).is_err());
    assert!(personas::find(db, sam, "").unwrap().is_empty());
    assert!(personas::find(db, sam, "ines").unwrap().is_empty());
    assert!(personas::change(db, sam, persona, Some("Sam"), None).is_err());
    assert!(personas::set_trashed(db, sam, persona, true).is_err());
    assert!(personas::set_trashed(db, sam, persona, false).is_err());
    assert!(personas::set_default(db, sam, persona, true).is_err());
    assert!(personas::default_of(db, sam).unwrap().is_none());
    assert!(cw_library::trash::delete_persona(db, sam, persona).is_err());
    assert!(chats::append(db, sam, chat_id, &user("Hello?")).is_err());
    assert!(chats::add_swipe(db, sam, first.id, "Hello?", true).is_err());
    assert!(chats::set_head(db, sam, chat_id, first.id).is_err());
    assert!(chats::set_content(db, sam, first.id, "Changed.").is_err());
    assert!(chats::set_archived(db, sam, chat_id, true).is_err());
    assert!(chats::prompt_inputs(db, sam, chat_id, None).is_err());
    assert!(chats::save_prompt_state(db, sam, chat_id, &state).is_err());

    // Sam's own things cannot be tied to what is not his either.
    let own_card = common::import_whole(db, sam, &common::card_file()).unwrap();
    let with_persona = NewChat {
        characters: &[(own_card.version_id, "mira")],
        persona_id: Some(persona),
        greeting: 0,
    };
    assert!(chats::create(db, sam, &with_persona).is_err());
    let own_chat = chats::create(
        db,
        sam,
        &NewChat {
            characters: &[(own_card.version_id, "mira")],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    assert!(chats::set_persona(db, sam, own_chat, Some(persona)).is_err());

    assert_eq!(cards::list(db, me).unwrap().len(), 1);
    assert_eq!(
        texts(&chats::path(db, me, chat_id).unwrap()),
        ["\"You picked a night for it, Ines.\""]
    );
}

#[test]
fn a_chat_opens_with_the_picked_greeting_and_keeps_the_others_as_swipes() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 1);
    let chat = chats::get(db, me, chat_id).unwrap().unwrap();
    assert_eq!(chat.title, "Mira (storm night)");

    let path = chats::path(db, me, chat_id).unwrap();
    assert_eq!(texts(&path), ["Hold the lamp. Don't ask."]);
    assert_eq!(chat.head_id, Some(path[0].id));
    let mira = &chats::participants(db, me, chat_id).unwrap()[0];
    assert_eq!(
        (path[0].role, path[0].speaker_id),
        (Role::Assistant, Some(mira.id))
    );
    let swipes = chats::swipes(db, me, path[0].id).unwrap();
    assert_eq!(
        texts(&swipes),
        [
            "\"You picked a night for it, Guest.\"",
            "Hold the lamp. Don't ask."
        ]
    );

    // A greeting that does not exist falls back to the first one.
    let other = chat_with_mira(&scratch, None, 7);
    assert_eq!(
        texts(&chats::path(db, me, other).unwrap()),
        ["\"You picked a night for it, Guest.\""]
    );
}

#[test]
fn a_greetings_macros_are_resolved_when_the_chat_starts() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let mut container = common::container();
    container.toml[0].1 = container.toml[0].1.replace(
        "Hold the lamp.",
        "{{setvar::lamp::lit}}{{char}} hands {{user}} the lamp.",
    );
    let card = common::import_whole(db, me, &png::write(&container).unwrap()).unwrap();
    let persona = personas::create(db, me, "Ines", "").unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id: Some(persona),
        greeting: 1,
    };
    let chat_id = chats::create(db, me, &new).unwrap();
    let greeting = chats::path(db, me, chat_id).unwrap().remove(0);
    assert_eq!(greeting.content, "Mira hands Ines the lamp. Don't ask.");

    // What a greeting set holds for a reply made straight after it, however often it is made.
    let lamp = || {
        chats::prompt_inputs(db, me, chat_id, None)
            .unwrap()
            .state
            .local_variables
            .get("lamp")
            .cloned()
    };
    let mut state = chats::prompt_inputs(db, me, chat_id, None).unwrap().state;
    assert_eq!(lamp().as_deref(), Some("lit"));
    state
        .local_variables
        .insert("lamp".to_string(), "out".to_string());
    chats::save_prompt_state(db, me, chat_id, &state).unwrap();
    assert_eq!(lamp().as_deref(), Some("lit"));
    // What that reply changed holds after it, on the greeting's own branch only.
    chats::append(db, me, chat_id, &user("Why?")).unwrap();
    assert_eq!(lamp().as_deref(), Some("out"));
    let other = chats::swipes(db, me, greeting.id).unwrap().remove(0);
    chats::set_head(db, me, chat_id, other.id).unwrap();
    chats::append(db, me, chat_id, &user("Why?")).unwrap();
    assert_eq!(lamp(), None);
}

#[test]
fn in_a_group_chat_the_other_characters_lines_carry_their_names() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let card = common::import_whole(db, me, &common::card_file()).unwrap();
    let characters = [(card.version_id, "mira"), (card.version_id, "bare")];
    let chat_id = chats::create(
        db,
        me,
        &NewChat {
            characters: &characters,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    assert_eq!(
        texts(&chats::path(db, me, chat_id).unwrap()),
        ["All of you, inside."]
    );
    let participants = chats::participants(db, me, chat_id).unwrap();
    assert_eq!(
        participants
            .iter()
            .map(|p| p.character.as_str())
            .collect::<Vec<_>>(),
        ["mira", "bare"]
    );
    let (mira, bare) = (participants[0].id, participants[1].id);

    chats::append(db, me, chat_id, &user("Thanks.")).unwrap();
    let line = NewMessage {
        role: Role::Assistant,
        speaker_id: Some(bare),
        content: "Mind the step.",
        complete: true,
    };
    chats::append(db, me, chat_id, &line).unwrap();

    let contents = |speaker| {
        let inputs = chats::prompt_inputs(db, me, chat_id, Some(speaker)).unwrap();
        let lines: Vec<String> = inputs
            .state
            .messages
            .into_iter()
            .map(|m| m.content)
            .collect();
        (inputs.character.name, lines)
    };
    assert_eq!(
        contents(bare),
        (
            "bare".to_string(),
            vec![
                "Mira: All of you, inside.".into(),
                "Thanks.".into(),
                "Mind the step.".into()
            ]
        )
    );
    assert_eq!(
        contents(mira),
        (
            "Mira".to_string(),
            vec![
                "All of you, inside.".into(),
                "Thanks.".into(),
                "bare: Mind the step.".into()
            ]
        )
    );
    assert!(chats::prompt_inputs(db, me, chat_id, Some(999)).is_err());

    // Only the chat's own characters can speak in it.
    let elsewhere = chat_with_mira(&scratch, None, 0);
    let stranger = chats::participants(db, me, elsewhere).unwrap()[0].id;
    let foreign = NewMessage {
        role: Role::Assistant,
        speaker_id: Some(stranger),
        content: "Hello.",
        complete: true,
    };
    assert!(chats::append(db, me, chat_id, &foreign).is_err());

    let nobody = [(card.version_id, "nobody")];
    assert!(
        chats::create(
            db,
            me,
            &NewChat {
                characters: &nobody,
                persona_id: None,
                greeting: 0
            }
        )
        .is_err()
    );
    assert_eq!(count(&scratch, "chats"), 2);
}

#[test]
fn swipes_and_branches_share_one_tree() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let question = chats::append(db, me, chat_id, &user("Who built it?")).unwrap();
    let answer = chats::append(db, me, chat_id, &reply("My grandfather.")).unwrap();
    let swipe = chats::add_swipe(db, me, answer, "Nobody you'd know.", true).unwrap();

    let path = chats::path(db, me, chat_id).unwrap();
    assert_eq!(texts(&path)[1..], ["Who built it?", "Nobody you'd know."]);
    assert_eq!(path[2].parent_id, Some(question));
    assert_eq!(
        texts(&chats::swipes(db, me, swipe).unwrap()),
        ["My grandfather.", "Nobody you'd know."]
    );

    // Back to the first answer and on from there.
    chats::set_head(db, me, chat_id, answer).unwrap();
    chats::append(db, me, chat_id, &user("When?")).unwrap();
    assert_eq!(
        texts(&chats::path(db, me, chat_id).unwrap())[1..],
        ["Who built it?", "My grandfather.", "When?"]
    );

    // A new line of talk from an earlier message leaves the old one in place.
    chats::set_head(db, me, chat_id, question).unwrap();
    let branch = chats::append(db, me, chat_id, &reply("Why do you ask?")).unwrap();
    assert_eq!(
        texts(&chats::path(db, me, chat_id).unwrap())[1..],
        ["Who built it?", "Why do you ask?"]
    );
    assert_eq!(chats::swipes(db, me, branch).unwrap().len(), 3);
    assert_eq!(count(&scratch, "messages"), 7);

    let other_chat = chat_with_mira(&scratch, None, 0);
    assert!(chats::set_head(db, me, other_chat, branch).is_err());
    assert!(chats::append(db, me, 999, &user("Hello?")).is_err());
    assert!(chats::add_swipe(db, me, 999, "Hello?", true).is_err());
}

#[test]
fn a_very_long_chat_can_still_be_deleted() {
    let scratch = Scratch::new();
    let chat_id = chat_with_mira(&scratch, None, 0);
    scratch
        .db
        .with(|c| {
            let tx = c.transaction()?;
            for _ in 0..1500 {
                tx.execute(
                    "insert into messages (chat_id, parent_id, role, content, created_at)
                     select ?1, max(id), 'user', 'x', 0 from messages",
                    [chat_id],
                )?;
            }
            tx.commit()
        })
        .unwrap();
    scratch
        .db
        .with(|c| c.execute("delete from chats where id = ?1", [chat_id]))
        .unwrap();
    assert_eq!(
        count(&scratch, "messages") + count(&scratch, "chat_characters"),
        0
    );
}

#[test]
fn an_edit_replaces_the_text_and_drops_the_cached_token_count() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let id = chats::append(db, me, chat_id, &reply("Dne.")).unwrap();
    db.with(|c| c.execute("update messages set token_count = 5 where id = ?1", [id]))
        .unwrap();

    chats::set_content(db, me, id, "Done.").unwrap();
    let last = chats::path(db, me, chat_id).unwrap().pop().unwrap();
    assert_eq!(
        (last.content.as_str(), last.complete, last.token_count),
        ("Done.", true, None)
    );
    assert!(chats::set_content(db, me, 999, "Lost.").is_err());
}

#[test]
fn a_chat_uses_its_cards_texts_as_they_are_now() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let card_id = cards::list(db, me).unwrap()[0].id;
    let scenario = || {
        chats::prompt_inputs(db, me, chat_id, None)
            .unwrap()
            .character
            .scenario
    };
    assert_eq!(
        scenario(),
        "A storm has cut the causeway. {{user}} is stranded."
    );

    let mut form = cards::editable(db, me, card_id, None).unwrap();
    form.characters[0].scenario[0].text = "The causeway is dry.".to_string();
    cards::edit(db, me, card_id, &form).unwrap();
    assert_eq!(scenario(), "The causeway is dry.");
}

#[test]
fn a_stored_chat_builds_the_prompt() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let persona = personas::create(db, me, "Ines", "A surveyor.").unwrap();
    let chat_id = chat_with_mira(&scratch, Some(persona), 0);
    chats::append(db, me, chat_id, &user("Tell me about the wreck.")).unwrap();

    let mut inputs = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    let prompt = build(
        &PromptRequest::new(&inputs.character, 10_000),
        &mut inputs.state,
        &mut Variables::new(),
    );
    let system = |content: &str| PromptMessage::new(Role::System, content);
    assert_eq!(
        prompt.messages,
        [
            system(
                "<identity>\nYou are Mira.\n</identity>\n\
                 <system_prompt>\nWrite tersely.\n</system_prompt>\n\
                 <description>\nKeeper of the north light. Mira counts ships.\n\nA patched oilskin coat.\n</description>\n\
                 <personality>\nWry, patient.\n</personality>\n\
                 <scenario>\nA storm has cut the causeway. Ines is stranded.\n</scenario>\n\
                 <user_persona>\nName: Ines\nA surveyor.\n</user_persona>"
            ),
            // The entry always given stands at the start, the one its key
            // triggered just before the newest message.
            system("<world_info>\nThe lamp must never go out.\n</world_info>"),
            system(
                "<example_dialogue>\n<START>\nInes: Tea?\nMira: \"Black.\"\n</example_dialogue>"
            ),
            system("<depth_prompt>\n[The light flickers.]\n</depth_prompt>"),
            PromptMessage::new(Role::Assistant, "\"You picked a night for it, Ines.\""),
            system("<world_info>\nThe Asta sank here in 1911.\n</world_info>"),
            PromptMessage::new(Role::User, "Tell me about the wreck."),
            system("<depth_prompt>\n[The tide is rising.]\n</depth_prompt>"),
            system(
                "<post_history_instructions>\nStay in the scene.\n\n[Under 100 words.]\n</post_history_instructions>"
            ),
        ]
    );

    // The token counts the build worked out are kept with the messages.
    chats::save_prompt_state(db, me, chat_id, &inputs.state).unwrap();
    let again = chats::prompt_inputs(db, me, chat_id, None).unwrap().state;
    assert!(
        again
            .messages
            .iter()
            .all(|m| m.token_count.is_some_and(|n| n > 0))
    );
    assert_eq!(
        (
            again.persona_name.as_str(),
            again.persona_description.as_str()
        ),
        ("Ines", "A surveyor.")
    );

    // Without a persona the user is just "Guest".
    chats::set_persona(db, me, chat_id, None).unwrap();
    assert_eq!(
        chats::prompt_inputs(db, me, chat_id, None)
            .unwrap()
            .state
            .persona_name,
        "Guest"
    );
}

#[test]
fn what_a_reply_changed_holds_only_on_its_own_branch() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let greeting = chats::path(db, me, chat_id).unwrap()[0].id;
    chats::append(db, me, chat_id, &user("Tell me about the wreck.")).unwrap();

    // The build for the first reply makes the wreck entry sticky and sets a variable.
    let mut inputs = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    build(
        &PromptRequest::new(&inputs.character, 10_000),
        &mut inputs.state,
        &mut Variables::new(),
    );
    inputs
        .state
        .local_variables
        .insert("mood".into(), "wary".into());
    assert_eq!(inputs.state.active_stickies.get("lore.wreck"), Some(&4));
    chats::save_prompt_state(db, me, chat_id, &inputs.state).unwrap();

    // Asking for that reply again starts from the state before it.
    let retry = chats::prompt_inputs(db, me, chat_id, None).unwrap().state;
    assert!(retry.active_stickies.is_empty() && retry.local_variables.is_empty());

    // Further down the same branch the state is there.
    chats::append(
        db,
        me,
        chat_id,
        &reply("It went down in a night like this."),
    )
    .unwrap();
    chats::append(db, me, chat_id, &user("Go on.")).unwrap();
    let mut later = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    assert_eq!(later.state.active_stickies.get("lore.wreck"), Some(&4));
    assert_eq!(
        later.state.local_variables.get("mood").map(String::as_str),
        Some("wary")
    );
    let prompt = build(
        &PromptRequest::new(&later.character, 10_000),
        &mut later.state,
        &mut Variables::new(),
    );
    assert!(
        prompt
            .messages
            .iter()
            .any(|m| m.content.contains("The Asta sank"))
    );

    // Back at the greeting, a different conversation knows nothing of it.
    chats::set_head(db, me, chat_id, greeting).unwrap();
    chats::append(db, me, chat_id, &user("Quiet night.")).unwrap();
    let mut branch = chats::prompt_inputs(db, me, chat_id, None).unwrap();
    assert!(branch.state.active_stickies.is_empty() && branch.state.local_variables.is_empty());
    let prompt = build(
        &PromptRequest::new(&branch.character, 10_000),
        &mut branch.state,
        &mut Variables::new(),
    );
    assert!(
        !prompt
            .messages
            .iter()
            .any(|m| m.content.contains("The Asta sank"))
    );
}

#[test]
fn a_sent_messages_macros_change_the_variables_once() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    chats::append(db, me, chat_id, &user("{{.visits++}}Hello.")).unwrap();
    let mut visits = Vec::new();
    for next in ["Go on.", "And then?"] {
        let mut inputs = chats::prompt_inputs(db, me, chat_id, None).unwrap();
        build(
            &PromptRequest::new(&inputs.character, 10_000),
            &mut inputs.state,
            &mut Variables::new(),
        );
        visits.push(inputs.state.local_variables["visits"].clone());
        chats::save_prompt_state(db, me, chat_id, &inputs.state).unwrap();
        chats::append(db, me, chat_id, &reply("Mm.")).unwrap();
        chats::append(db, me, chat_id, &user(next)).unwrap();
    }
    assert_eq!(visits, ["1", "1"]);
}

#[test]
fn a_reply_that_ends_without_text_is_removed() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let asked = chats::append(db, me, chat_id, &user("Why tonight?")).unwrap();
    let head = || chats::get(db, me, chat_id).unwrap().unwrap().head_id;

    // With text it is a complete message; nobody else can end it.
    let half = chats::append(db, me, chat_id, &writing("")).unwrap();
    let sam = users::create(db, "sam").unwrap();
    assert!(chats::finish_reply(db, sam, half, "The causeway", Some(asked)).is_err());
    let done = chats::finish_reply(db, me, half, "The causeway", Some(asked))
        .unwrap()
        .unwrap();
    assert_eq!(
        (done.message.content.as_str(), done.message.complete, head()),
        ("The causeway", true, Some(half))
    );

    // Without text it is gone, and the chat is back where it was.
    chats::set_head(db, me, chat_id, asked).unwrap();
    let empty = chats::append(db, me, chat_id, &writing("")).unwrap();
    assert!(
        chats::finish_reply(db, me, empty, " \n", Some(asked))
            .unwrap()
            .is_none()
    );
    assert_eq!(
        (head(), chats::swipes(db, me, half).unwrap().len()),
        (Some(asked), 1)
    );

    // Ended once, it cannot be ended again.
    assert!(chats::finish_reply(db, me, half, "", Some(asked)).is_err());
    assert_eq!(chats::swipes(db, me, half).unwrap().len(), 1);
}

#[test]
fn a_chat_takes_nothing_else_while_a_reply_is_generated() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    let asked = chats::append(db, me, chat_id, &user("Why tonight?")).unwrap();
    let first = chats::append(db, me, chat_id, &reply("The causeway.")).unwrap();
    let half = chats::add_swipe(db, me, first, "", false).unwrap();

    assert!(chats::append(db, me, chat_id, &user("Hello?")).is_err_and(busy));
    assert!(chats::add_swipe(db, me, first, "The tide.", true).is_err_and(busy));
    assert!(chats::set_head(db, me, chat_id, asked).is_err_and(busy));
    assert!(chats::show_branch(db, me, chat_id, first).is_err_and(busy));
    assert!(chats::set_content(db, me, half, "Mine.").is_err_and(busy));
    // Another chat is not held up, and what is there can still be corrected.
    let other = chat_with_mira(&scratch, None, 0);
    chats::append(db, me, other, &user("And you?")).unwrap();
    chats::set_content(db, me, asked, "Why tonight of all nights?").unwrap();

    // Only the reply's own text grows, and only until it has ended.
    chats::write_reply(db, me, half, "The").unwrap();
    chats::write_reply(db, me, half, " ti").unwrap();
    assert!(chats::write_reply(db, me, first, "No.").is_err());
    assert_eq!(
        chats::path(db, me, chat_id)
            .unwrap()
            .last()
            .unwrap()
            .content,
        "The ti"
    );
    chats::finish_reply(db, me, half, "The tide.", Some(first))
        .unwrap()
        .unwrap();
    assert!(chats::write_reply(db, me, half, "The tide. And").is_err());
    chats::set_content(db, me, half, "The tide!").unwrap();
    chats::set_head(db, me, chat_id, first).unwrap();
    chats::append(db, me, chat_id, &user("Hello?")).unwrap();

    // A reply that nothing writes any more is ended when asked for, like one
    // cut off by a restart; the user stopped it, so it does not say it broke off.
    let lost = chats::append(db, me, chat_id, &writing("")).unwrap();
    chats::write_reply(db, me, lost, "Hel").unwrap();
    let sam = users::create(db, "sam").unwrap();
    assert!(chats::finish_abandoned(db, sam, chat_id).is_err());
    let ended = chats::finish_abandoned(db, me, chat_id).unwrap();
    assert!(
        matches!(&ended[..], [(id, Some(kept))] if *id == lost && kept.message.complete && !kept.broke_off)
    );
    assert!(chats::finish_abandoned(db, me, chat_id).unwrap().is_empty());
    chats::append(db, me, chat_id, &user("Hello again?")).unwrap();
}

#[test]
fn replies_cut_off_by_a_restart_are_ended() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let chat_id = chat_with_mira(&scratch, None, 0);
    chats::append(db, me, chat_id, &user("Why tonight?")).unwrap();
    let half = chats::append(db, me, chat_id, &writing("The cause")).unwrap();
    let other = chat_with_mira(&scratch, None, 0);
    let asked = chats::append(db, me, other, &user("And you?")).unwrap();
    chats::append(db, me, other, &writing("")).unwrap();
    // Another version of a reply that got no further than a line end.
    let third = chat_with_mira(&scratch, None, 0);
    chats::append(db, me, third, &user("Go on.")).unwrap();
    let first = chats::append(db, me, third, &reply("It sank.")).unwrap();
    let again = chats::add_swipe(db, me, first, "", false).unwrap();
    chats::write_reply(db, me, again, "\n").unwrap();

    chats::finish_interrupted(db).unwrap();
    let cut = chats::path(db, me, chat_id).unwrap();
    assert_eq!(
        (cut.last().unwrap().id, cut.last().unwrap().complete),
        (half, true)
    );
    assert_eq!(texts(&cut)[1..], ["Why tonight?", "The cause"]);
    // It says it broke off, as a reply whose connection broke says so as it ends.
    assert!(chats::view(db, me, half).unwrap().broke_off);
    let emptied = chats::path(db, me, other).unwrap();
    assert_eq!((emptied.len(), emptied.last().unwrap().id), (2, asked));
    assert_eq!(
        chats::path(db, me, third).unwrap().last().unwrap().id,
        first
    );
    assert_eq!(chats::swipes(db, me, first).unwrap().len(), 1);
    assert_eq!(count(&scratch, "messages where complete = 0"), 0);
}

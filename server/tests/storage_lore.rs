//! The storage of a chat's lorebooks: which a chat has through its cards, what
//! it switched off or left out, and which entries each reply's prompt held.

mod common;

use common::{Scratch, user, writing};
use cw_accounts::users;
use cw_ccv4::png;
use cw_chat::chats::{self, ChatLorebook, Lore, LoreSource, NewChat};
use cw_coding::tools::Read;
use cw_core::NotFound;
use cw_prompt::Variables;
use cw_prompt::builder::{PromptRequest, build};

#[test]
fn a_chat_lists_its_lorebooks_and_leaves_out_what_it_switched_off() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // The sample card with a third character, `twin`, which brings Mira's lorebook too.
    let third = "\n[character.twin]\nlorebooks = [\"lorebook.coast\"]\nprompt = [\"LOREBOOK\", \"CHAT-HISTORY\"]\n";
    let mut container = common::container();
    container.toml[1].1 = format!("{}{third}", common::CARDS);
    let card = common::import_whole(db, me, &png::write(&container).unwrap()).unwrap();
    let characters = [
        (card.version_id, "bare"),
        (card.version_id, "mira"),
        (card.version_id, "twin"),
    ];
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
    let mira = chats::participants(db, me, chat_id).unwrap()[1].id;
    let lore = |reference: &str, name: &str| Lore {
        source: LoreSource::CardId(card.card_id),
        reference: reference.into(),
        name: name.into(),
    };
    let coast = |on, removed: Vec<Lore>| {
        let entries = ["lore.wreck", "lore.lamp", "lore.off"]
            .map(str::to_string)
            .to_vec();
        vec![ChatLorebook {
            source: LoreSource::CardId(card.card_id),
            reference: "lorebook.coast".into(),
            name: "coast".into(),
            on,
            entries,
            removed,
            trashed: false,
            taken: false,
            everywhere: false,
            persona: false,
        }]
    };
    let entries = || {
        let book = chats::prompt_inputs(db, me, chat_id, Some(mira))
            .unwrap()
            .character
            .lorebook;
        book.map(|book| {
            book.entries
                .into_iter()
                .filter_map(|entry| entry.id)
                .collect::<Vec<_>>()
        })
    };
    let set = |reference: &str, on| {
        chats::set_lore(
            db,
            me,
            chat_id,
            LoreSource::CardId(card.card_id),
            reference,
            on,
        )
    };

    // One lorebook, though two of the characters bring it; the one without a lorebook adds none.
    assert_eq!(
        chats::lorebooks(db, me, chat_id).unwrap(),
        coast(true, vec![])
    );
    assert_eq!(entries().unwrap(), ["lore.wreck", "lore.lamp", "lore.off"]);

    // An entry left out is gone from the prompt's lorebook and listed as removed; twice is once.
    set("lore.lamp", false).unwrap();
    set("lore.lamp", false).unwrap();
    assert_eq!(
        chats::lorebooks(db, me, chat_id).unwrap(),
        coast(true, vec![lore("lore.lamp", "lamp")])
    );
    assert_eq!(entries().unwrap(), ["lore.wreck", "lore.off"]);

    // The lorebook switched off: none of it reaches the prompt. Its removed entry stays removed.
    // The change answers with the lorebooks as they then are.
    assert_eq!(
        set("lorebook.coast", false).unwrap(),
        coast(false, vec![lore("lore.lamp", "lamp")])
    );
    assert_eq!(
        chats::lorebooks(db, me, chat_id).unwrap(),
        coast(false, vec![lore("lore.lamp", "lamp")])
    );
    assert_eq!(entries(), None);
    set("lorebook.coast", true).unwrap();
    assert_eq!(entries().unwrap(), ["lore.wreck", "lore.off"]);
    set("lore.lamp", true).unwrap();
    assert_eq!(
        chats::lorebooks(db, me, chat_id).unwrap(),
        coast(true, vec![])
    );
    assert_eq!(entries().unwrap(), ["lore.wreck", "lore.lamp", "lore.off"]);

    // Only what the chat's characters bring can be switched, and only by the chat's user.
    for (card_id, reference) in [
        (card.card_id, "lore.nothing"),
        (card.card_id, "character.mira"),
        (card.card_id + 1, "lorebook.coast"),
    ] {
        let error = chats::set_lore(
            db,
            me,
            chat_id,
            LoreSource::CardId(card_id),
            reference,
            false,
        )
        .unwrap_err();
        assert_eq!(
            format!("{error:#}"),
            "the chat has no such lorebook or lorebook entry"
        );
    }
    let sam = users::create(db, "sam").unwrap();
    assert!(
        chats::set_lore(
            db,
            sam,
            chat_id,
            LoreSource::CardId(card.card_id),
            "lorebook.coast",
            false
        )
        .unwrap_err()
        .is::<NotFound>()
    );
    assert!(
        chats::lorebooks(db, sam, chat_id)
            .unwrap_err()
            .is::<NotFound>()
    );
    assert_eq!(
        chats::lorebooks(db, me, chat_id).unwrap(),
        coast(true, vec![])
    );

    // What one chat leaves out, another does not.
    set("lorebook.coast", false).unwrap();
    let other = chats::create(
        db,
        me,
        &NewChat {
            characters: &characters[1..2],
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    assert_eq!(
        chats::lorebooks(db, me, other).unwrap(),
        coast(true, vec![])
    );
    assert!(
        chats::prompt_inputs(db, me, other, None)
            .unwrap()
            .character
            .lorebook
            .is_some()
    );

    // Two cards may name their lorebooks alike: each is switched by itself.
    let twin = common::import_whole(db, me, &common::card_file()).unwrap();
    let both = [(card.version_id, "mira"), (twin.version_id, "mira")];
    let shared = chats::create(
        db,
        me,
        &NewChat {
            characters: &both,
            persona_id: None,
            greeting: 0,
        },
    )
    .unwrap();
    chats::set_lore(
        db,
        me,
        shared,
        LoreSource::CardId(twin.card_id),
        "lorebook.coast",
        false,
    )
    .unwrap();
    chats::set_lore(
        db,
        me,
        shared,
        LoreSource::CardId(card.card_id),
        "lore.lamp",
        false,
    )
    .unwrap();
    let listed = chats::lorebooks(db, me, shared).unwrap();
    let state: Vec<_> = listed
        .iter()
        .map(|book| (book.source, book.on, book.removed.len()))
        .collect();
    assert_eq!(
        state,
        [
            (LoreSource::CardId(card.card_id), true, 1),
            (LoreSource::CardId(twin.card_id), false, 0)
        ]
    );
    let speakers = chats::participants(db, me, shared).unwrap();
    let book = |speaker: usize| {
        chats::prompt_inputs(db, me, shared, Some(speakers[speaker].id))
            .unwrap()
            .character
            .lorebook
    };
    assert_eq!(book(0).unwrap().entries.len(), 2);
    assert!(book(1).is_none());
}

#[test]
fn a_reply_keeps_which_lorebook_entries_its_prompt_held() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // Seventy entries that always apply, beside the sample card's own.
    let mut container = common::container();
    let more: String = (0..70)
        .map(|n| {
            format!(
                "[lore.n{n:02}]\ntrigger = \"always\"\ninsertion-order = 2\ntext = \"Fact {n}.\"\n"
            )
        })
        .collect();
    let listed: String = (0..70).map(|n| format!(", \"lore.n{n:02}\"")).collect();
    container.toml[1].1 = format!(
        "{more}{}",
        common::CARDS.replace("\"lore.off\"]", &format!("\"lore.off\"{listed}]"))
    )
    .replace("token-budget = 300", "token-budget = 0");
    let card = common::import_whole(db, me, &png::write(&container).unwrap()).unwrap();
    let new = NewChat {
        characters: &[(card.version_id, "mira")],
        persona_id: None,
        greeting: 0,
    };
    let chat_id = chats::create(db, me, &new).unwrap();
    chats::append(db, me, chat_id, &user("Tell me about the wreck.")).unwrap();
    let reply = chats::append(db, me, chat_id, &writing("")).unwrap();

    let chat = chats::get(db, me, chat_id).unwrap().unwrap();
    let asked = chats::view(db, me, reply).unwrap().message.parent_id;
    let mut inputs = chats::prompt_inputs_after(db, me, &chat, None, asked).unwrap();
    assert_eq!(inputs.card_id, Some(card.card_id));
    let built = build(
        &PromptRequest::new(&inputs.character, 100_000),
        &mut inputs.state,
        &mut Variables::new(),
    );
    // In the prompt's order: the triggered entry, the lamp, then the seventy.
    assert_eq!(built.lore.len(), 72);
    assert_eq!(built.lore[..3], ["lore.wreck", "lore.lamp", "lore.n00"]);

    // Nobody else's message takes it, and a message no model wrote has none.
    let sam = users::create(db, "sam").unwrap();
    chats::save_used(
        db,
        sam,
        reply,
        &inputs,
        &built.lore,
        (
            chats::ContextUse { used: 1, size: 2 },
            chats::Sent::default(),
        ),
    )
    .unwrap();
    assert!(chats::view(db, me, reply).unwrap().lore.is_empty());
    chats::save_used(
        db,
        me,
        reply,
        &inputs,
        &built.lore,
        (
            chats::ContextUse { used: 1, size: 2 },
            chats::Sent::default(),
        ),
    )
    .unwrap();
    let kept = chats::view(db, me, reply).unwrap().lore;
    assert_eq!(kept.len(), 64);
    // The pages and files read: nobody else's, and those of a reply continued after the first, each once.
    let page = |title: &str| Read::Web {
        title: title.into(),
        address: format!("https://example.com/{title}"),
    };
    let file = Read::File {
        path: "notes/a.md".into(),
    };
    chats::save_reads(db, sam, reply, &[page("a")]).unwrap();
    assert!(chats::view(db, me, reply).unwrap().reads.is_empty());
    chats::save_reads(db, me, reply, &[page("a"), file.clone()]).unwrap();
    chats::save_reads(db, me, reply, &[file.clone(), page("b")]).unwrap();
    assert_eq!(
        chats::view(db, me, reply).unwrap().reads,
        [page("a"), file, page("b")]
    );
    let lore = |reference: &str, name: &str| Lore {
        source: LoreSource::CardId(card.card_id),
        reference: reference.into(),
        name: name.into(),
    };
    assert_eq!(
        kept[..3],
        [
            lore("lore.wreck", "wreck"),
            lore("lore.lamp", "lamp"),
            lore("lore.n00", "n00")
        ]
    );
    // The chat's view carries it on that message alone.
    let (_, branch) = chats::branch(db, me, chat_id).unwrap();
    assert_eq!(
        branch
            .iter()
            .map(|message| message.lore.len())
            .collect::<Vec<_>>(),
        [0, 0, 64]
    );
    // A build that used none leaves none.
    chats::save_used(
        db,
        me,
        reply,
        &inputs,
        &[],
        (
            chats::ContextUse { used: 1, size: 2 },
            chats::Sent::default(),
        ),
    )
    .unwrap();
    assert!(chats::view(db, me, reply).unwrap().lore.is_empty());
    // What is kept there and cannot be read is shown as none: the chat opens all the same.
    db.with(|conn| {
        conn.execute(
            "update messages set lore = 'not a list' where id = ?1",
            [reply],
        )
    })
    .unwrap();
    assert!(chats::view(db, me, reply).unwrap().lore.is_empty());
    assert_eq!(chats::branch(db, me, chat_id).unwrap().1.len(), 3);
}

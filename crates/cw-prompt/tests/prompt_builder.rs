//! The prompt builder. The Flutter app had no unit tests for this, so these pin
//! down the behaviour of its `chat_prompt_builder.dart`.

use cw_prompt::builder::{BuiltPrompt, PromptRequest, SegmentKind, build};
use cw_prompt::{
    Character, ChatMessage, ChatState, DepthPrompt, Lorebook, LorebookEntry, PromptMessage, Role,
    Variables, tokens,
};

/// One token per character, so budgets in the tests are easy to follow.
fn chars(text: &str) -> usize {
    text.chars().count()
}

fn request(character: &Character, context_size: usize) -> PromptRequest<'_> {
    PromptRequest {
        count_tokens: &chars,
        ..PromptRequest::new(character, context_size)
    }
}

fn run(req: &PromptRequest<'_>, chat: &mut ChatState) -> BuiltPrompt {
    build(req, chat, &mut Variables::new())
}

/// A chat with the given messages, user and assistant taking turns.
fn chat(lines: &[&str]) -> ChatState {
    let mut chat = ChatState::default();
    for (n, line) in lines.iter().enumerate() {
        let role = if n % 2 == 0 {
            Role::User
        } else {
            Role::Assistant
        };
        chat.messages
            .push(ChatMessage::new(n.to_string(), role, *line));
    }
    chat
}

fn constant(content: &str) -> LorebookEntry {
    LorebookEntry {
        constant: true,
        content: content.into(),
        ..Default::default()
    }
}

fn with_lorebook(entries: Vec<LorebookEntry>) -> Character {
    Character {
        lorebook: Some(Lorebook {
            entries,
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn system(content: &str) -> PromptMessage {
    PromptMessage::new(Role::System, content)
}

fn user(content: &str) -> PromptMessage {
    PromptMessage::new(Role::User, content)
}

fn assistant(content: &str) -> PromptMessage {
    PromptMessage::new(Role::Assistant, content)
}

fn cass() -> Character {
    Character {
        name: "Cassandra".into(),
        nickname: Some("Cass".into()),
        system_prompt: "Stay in character as {{char}}.".into(),
        description: "{{char}} guides {{user}}.".into(),
        personality: "Calm".into(),
        scenario: "A bar".into(),
        ..Default::default()
    }
}

fn rowan(lines: &[&str]) -> ChatState {
    ChatState {
        persona_name: " Rowan ".into(),
        persona_description: "A product manager.\n".into(),
        ..chat(lines)
    }
}

#[test]
fn card_sections_then_the_chat_log() {
    let card = cass();
    let mut chat = rowan(&["Hi", "Hello {{user}}", "How are you?"]);
    let prompt = run(&request(&card, 10_000), &mut chat);

    let expected_system = "<identity>\nYou are Cassandra.\n</identity>\n\
        <system_prompt>\nStay in character as Cass.\n</system_prompt>\n\
        <description>\nCass guides Rowan.\n</description>\n\
        <personality>\nCalm\n</personality>\n\
        <scenario>\nA bar\n</scenario>\n\
        <user_persona>\nName: Rowan\nA product manager.\n</user_persona>";
    assert_eq!(
        prompt.messages,
        [
            system(expected_system),
            user("Hi"),
            assistant("Hello Rowan"),
            user("How are you?")
        ]
    );

    let kinds: Vec<_> = prompt.breakdown.segments.iter().map(|s| s.kind).collect();
    assert_eq!(
        kinds,
        [
            SegmentKind::Identity,
            SegmentKind::SystemPrompt,
            SegmentKind::Description,
            SegmentKind::Personality,
            SegmentKind::Scenario,
            SegmentKind::UserPersona,
            SegmentKind::CurrentMessage,
            SegmentKind::History,
        ]
    );
    let segment = |kind| {
        prompt
            .breakdown
            .segments
            .iter()
            .find(|s| s.kind == kind)
            .unwrap()
    };
    assert_eq!(segment(SegmentKind::CurrentMessage).text, "How are you?");
    assert_eq!(segment(SegmentKind::History).text, "Hi\n\nHello Rowan");
    assert_eq!(segment(SegmentKind::History).tokens, 13);
    assert_eq!(prompt.breakdown.context_size, 10_000);
    assert_eq!(prompt.breakdown.reserved_reply, 1_000);
}

#[test]
fn an_empty_card_gives_just_the_chat_log() {
    let card = Character::default();
    let prompt = run(&request(&card, 10_000), &mut chat(&["Hi"]));
    assert_eq!(prompt.messages, [user("Hi")]);
}

#[test]
fn persona_with_only_a_name() {
    let card = Character::default();
    let mut chat = ChatState {
        persona_name: "Rowan".into(),
        ..chat(&["Hi"])
    };
    let prompt = run(&request(&card, 10_000), &mut chat);
    assert_eq!(
        prompt.messages[0],
        system("<user_persona>\nName: Rowan\n</user_persona>")
    );
}

#[test]
fn optional_sections_in_their_fixed_order() {
    let card = Character {
        system_prompt: "S".into(),
        description: "D".into(),
        ..Default::default()
    };
    let req = PromptRequest {
        unlimited_mode: Some("U"),
        scenario_mode: Some("M"),
        memory_context: Some("R"),
        data_context: Some("X"),
        tools_advertisement: Some("T"),
        ..request(&card, 10_000)
    };
    let prompt = run(&req, &mut chat(&["Hi"]));
    assert_eq!(
        prompt.messages[0].content,
        "<system_prompt>\nS\n</system_prompt>\n\
         <unlimited_nsfw_mode>\nU\n</unlimited_nsfw_mode>\n\
         <scenario_mode>\nM\n</scenario_mode>\n\
         <description>\nD\n</description>\n\
         <available_tools>\nT\n</available_tools>"
    );
}

#[test]
fn memories_and_a_documents_pieces_reach_the_model_as_written() {
    let card = Character {
        name: "Cass".into(),
        ..Default::default()
    };
    let req = PromptRequest {
        memory_context: Some("- {{char}} met {{user}}, {{random:a,b}}."),
        data_context: Some("From \"t.md\":\nHello {{user}}, {{setvar::x::1}}{{random:a,b}}"),
        tools_advertisement: Some("{{char}}'s tools"),
        ..request(&card, 10_000)
    };
    let mut state = ChatState {
        persona_name: "Rowan".into(),
        ..chat(&["Hi"])
    };
    let prompt = run(&req, &mut state);
    assert!(
        prompt.messages[0]
            .content
            .ends_with("<available_tools>\nCass's tools\n</available_tools>")
    );
    assert!(state.local_variables.is_empty());
    // The pieces, then the memory note, stand just before the newest message, as written.
    let at = prompt.messages.len() - 3;
    assert_eq!(
        prompt.messages[at..],
        [
            system(
                "<supplemental_data_context>\nFrom \"t.md\":\nHello {{user}}, {{setvar::x::1}}{{random:a,b}}\n</supplemental_data_context>"
            ),
            system("[Memory]\n- {{char}} met {{user}}, {{random:a,b}}."),
            user("Hi"),
        ]
    );
}

/// What changes from reply to reply stands after what stays the same, so a
/// provider's cache of the prompt's start holds.
#[test]
fn what_changes_from_reply_to_reply_stands_after_what_stays_the_same() {
    let card = Character {
        name: "Cass".into(),
        mes_example: "{{char}}: hello".into(),
        ..with_lorebook(vec![
            constant("Always."),
            LorebookEntry {
                keys: vec!["dragon".into()],
                content: "Dragons breathe fire.".into(),
                ..Default::default()
            },
            // Always given, but for its cooldown: not at every reply.
            LorebookEntry {
                cooldown: 1,
                ..constant("Now and then.")
            },
        ])
    };
    let lines = ["Hi", "Hello", "A dragon!"];
    let built = |documents, memory| {
        let req = PromptRequest {
            data_context: documents,
            memory_context: memory,
            ..request(&card, 10_000)
        };
        run(&req, &mut chat(&lines)).messages
    };
    let texts = |messages: &[PromptMessage]| -> Vec<String> {
        messages.iter().map(|m| m.content.clone()).collect()
    };
    let first = texts(&built(Some("Piece one."), Some("Known: one.")));
    assert_eq!(
        first,
        [
            "<identity>\nYou are Cass.\n</identity>",
            "<world_info>\nAlways.\n</world_info>",
            "<example_dialogue>\nCass: hello\n</example_dialogue>",
            "Hi",
            "Hello",
            "<world_info>\nNow and then.\n\nDragons breathe fire.\n</world_info>",
            "<supplemental_data_context>\nPiece one.\n</supplemental_data_context>",
            "[Memory]\nKnown: one.",
            "A dragon!",
        ]
    );
    // Other pieces and another note change nothing before them.
    let second = texts(&built(Some("Piece two."), Some("Known: two.")));
    assert_eq!(first[..5], second[..5]);
}

/// The reply keeps its room: a part that would leave none is left out, and
/// the newest message keeps its room before the memory and the documents.
#[test]
fn what_would_leave_the_reply_no_room_is_left_out() {
    // 100 tokens: 10 for the reply.
    let big = Character {
        system_prompt: "s".repeat(95),
        post_history_instructions: "p".repeat(95),
        ..Default::default()
    };
    let prompt = run(&request(&big, 100), &mut chat(&["Hi"]));
    assert_eq!(prompt.messages, [user("Hi")]);
    assert!(
        prompt
            .breakdown
            .segments
            .iter()
            .all(|s| s.kind == SegmentKind::CurrentMessage)
    );

    let card = Character::default();
    let newest = "n".repeat(40);
    let req = PromptRequest {
        memory_context: Some(&*"m".repeat(30)),
        data_context: Some(&*"d".repeat(30)),
        ..request(&card, 100)
    };
    let prompt = run(&req, &mut chat(&[&newest]));
    // 10 + 40 for the newest; the memory's 39 fit beside it, the documents' 87 do not.
    let texts: Vec<&str> = prompt.messages.iter().map(|m| m.content.as_str()).collect();
    assert_eq!(texts, [&*format!("[Memory]\n{}", "m".repeat(30)), &*newest]);
}

#[test]
fn the_memory_note_is_nearer_the_newest_message_than_any_depth_insertion_and_holds_its_room() {
    let card = Character {
        depth_prompts: vec![DepthPrompt {
            prompt: "Deep.".into(),
            depth: 1,
            role: Role::System,
        }],
        ..Default::default()
    };
    let req = PromptRequest {
        memory_context: Some("Known:\n- A fact."),
        ..request(&card, 10_000)
    };
    let prompt = run(&req, &mut chat(&["One", "Two", "Three"]));
    let texts: Vec<&str> = prompt.messages.iter().map(|m| m.content.as_str()).collect();
    assert_eq!(
        texts[texts.len() - 3..],
        [
            "<depth_prompt>\nDeep.\n</depth_prompt>",
            "[Memory]\nKnown:\n- A fact.",
            "Three"
        ]
    );
    // It takes the memory's whole budget of the context, however short: the
    // history that fits beside it is that which fits beside a full note.
    let long = "word ".repeat(80);
    let lines = [
        &*format!("First {long}"),
        &long,
        &long,
        &long,
        &long,
        "Newest",
    ];
    let small = |memory| PromptRequest {
        memory_context: memory,
        ..request(&card, 2_400)
    };
    let has_first = |p: &BuiltPrompt| p.messages.iter().any(|m| m.content.starts_with("First"));
    assert!(has_first(&run(&small(None), &mut chat(&lines))));
    assert!(!has_first(&run(
        &small(Some("Known:\n- A fact.")),
        &mut chat(&lines)
    )));
}

#[test]
fn injected_message_and_post_history_follow_the_log() {
    let card = Character {
        post_history_instructions: "Reply as {{char}}.".into(),
        name: "Cass".into(),
        ..Default::default()
    };
    let req = PromptRequest {
        injected_message: Some((Role::User, "Continue, {{char}}.")),
        ..request(&card, 10_000)
    };
    let prompt = run(&req, &mut chat(&["Hi", "Hello"]));
    assert_eq!(
        prompt.messages[1..],
        [
            user("Hi"),
            assistant("Hello"),
            user("Continue, Cass."),
            system("<post_history_instructions>\nReply as Cass.\n</post_history_instructions>"),
        ]
    );
}

#[test]
fn world_info_block_in_insertion_order() {
    let card = with_lorebook(vec![
        LorebookEntry {
            insertion_order: 20,
            ..constant("Second, for {{user}}.")
        },
        LorebookEntry {
            insertion_order: 10,
            ..constant("First.")
        },
        LorebookEntry {
            keys: vec!["dragon".into()],
            content: "Unmentioned.".into(),
            ..Default::default()
        },
    ]);
    let mut chat = ChatState {
        persona_name: "Rowan".into(),
        ..chat(&["Hi"])
    };
    let prompt = run(&request(&card, 10_000), &mut chat);
    assert_eq!(
        prompt.messages,
        [
            system("<user_persona>\nName: Rowan\n</user_persona>"),
            system("<world_info>\nFirst.\n\nSecond, for Rowan.\n</world_info>"),
            user("Hi"),
        ]
    );
    let world_info = prompt
        .breakdown
        .segments
        .iter()
        .find(|s| s.kind == SegmentKind::WorldInfo);
    assert_eq!(
        world_info.unwrap().tokens,
        chars("First.") + chars("Second, for Rowan.")
    );
}

#[test]
fn depth_insertions_count_back_from_the_newest_message() {
    let mut card = with_lorebook(vec![
        LorebookEntry {
            at_depth: true,
            depth: 0,
            role: Role::User,
            ..constant("At zero.")
        },
        LorebookEntry {
            at_depth: true,
            depth: 99,
            ..constant("Far back.")
        },
        constant("@@depth 1\n@@role assistant\nBy decorator."),
    ]);
    card.name = "Cass".into();
    card.post_history_instructions = "After.".into();
    card.depth_prompts = vec![DepthPrompt {
        prompt: "Note for {{char}}.".into(),
        depth: 2,
        role: Role::System,
    }];

    let req = PromptRequest {
        injected_message: Some((Role::User, "Injected.")),
        ..request(&card, 10_000)
    };
    let prompt = run(&req, &mut chat(&["m1", "m2", "m3", "m4", "m5"]));
    assert_eq!(
        prompt.messages,
        [
            system("<identity>\nYou are Cass.\n</identity>"),
            system("Far back."),
            user("m1"),
            assistant("m2"),
            user("m3"),
            system("<depth_prompt>\nNote for Cass.\n</depth_prompt>"),
            assistant("m4"),
            assistant("By decorator."),
            user("m5"),
            user("At zero."),
            user("Injected."),
            system("<post_history_instructions>\nAfter.\n</post_history_instructions>"),
        ]
    );
}

#[test]
fn depth_prompt_in_a_chat_role_is_not_wrapped() {
    let card = Character {
        depth_prompts: vec![DepthPrompt {
            prompt: "Psst.".into(),
            depth: 1,
            role: Role::User,
        }],
        ..Default::default()
    };
    let prompt = run(&request(&card, 10_000), &mut chat(&["m1", "m2"]));
    assert_eq!(
        prompt.messages,
        [user("m1"), user("Psst."), assistant("m2")]
    );
}

#[test]
fn at_depth_entries_sharing_depth_and_role_become_one_message() {
    let at = |depth, role, content: &str| LorebookEntry {
        at_depth: true,
        depth,
        role,
        ..constant(content)
    };
    let card = with_lorebook(vec![
        at(1, Role::System, "One."),
        at(1, Role::User, "Other role."),
        at(1, Role::System, "Two."),
    ]);
    let prompt = run(&request(&card, 10_000), &mut chat(&["m1", "m2"]));
    assert_eq!(
        prompt.messages,
        [
            user("m1"),
            system("One.\n\nTwo."),
            user("Other role."),
            assistant("m2")
        ]
    );
}

#[test]
fn oldest_history_is_dropped_when_the_context_is_full() {
    let card = Character::default();
    let line = |c: char| c.to_string().repeat(30);
    let (a, b, c, d) = (line('a'), line('b'), line('c'), line('d'));
    let mut chat = chat(&[&a, &b, &c, &d]);
    // 100 tokens, 10 kept for the reply: three messages of 30 fit exactly.
    let prompt = run(&request(&card, 100), &mut chat);
    assert_eq!(prompt.messages, [assistant(&b), user(&c), assistant(&d)]);
    let counts: Vec<_> = chat.messages.iter().map(|m| m.token_count).collect();
    assert_eq!(counts, [Some(30), Some(30), Some(30), Some(30)]);
}

/// The history is dropped in blocks of an eighth of the context, counted from the
/// chat's start, so the prompt begins alike from one reply to the next; the example dialogue
/// stays out once the history is cut.
#[test]
fn history_is_dropped_in_blocks_so_the_prompt_begins_alike() {
    let card = Character {
        mes_example: "Example".into(),
        ..Default::default()
    };
    let lines: Vec<String> = (0..22).map(|n| format!("{n:02}").repeat(5)).collect();
    let first = |count: usize| {
        let lines: Vec<&str> = lines[..count].iter().map(String::as_str).collect();
        // 160 tokens, 16 kept for the reply: 14 messages of 10 fit; blocks of 20, two messages each.
        let prompt = run(&request(&card, 160), &mut chat(&lines));
        prompt.messages[0].content.clone()
    };
    assert_eq!(first(20), lines[6]);
    // Message by message the 21st would begin at the 7th; in blocks both begin at the 8th.
    assert_eq!(first(21), lines[8]);
    assert_eq!(first(22), lines[8]);
}

#[test]
fn a_longer_reply_reserves_more_of_the_context() {
    let card = Character::default();
    let line = "x".repeat(30);
    let req = PromptRequest {
        max_response_length: Some(45),
        ..request(&card, 100)
    };
    let prompt = run(&req, &mut chat(&[&line, &line, &line]));
    assert_eq!(prompt.messages.len(), 1);
    assert_eq!(prompt.breakdown.reserved_reply, 45);

    let req = PromptRequest {
        max_response_length: Some(5),
        ..request(&card, 100)
    };
    assert_eq!(run(&req, &mut chat(&[&line])).breakdown.reserved_reply, 10);

    // A reply longer than the context keeps half of it for the prompt.
    let req = PromptRequest {
        max_response_length: Some(500),
        ..request(&card, 100)
    };
    let prompt = run(&req, &mut chat(&[&line]));
    assert_eq!(prompt.breakdown.reserved_reply, 50);
    assert_eq!(prompt.messages.len(), 1);
}

#[test]
fn cached_token_counts_are_used() {
    let card = Character::default();
    let mut chat = chat(&["short", "short"]);
    chat.messages[0].token_count = Some(95);
    let prompt = run(&request(&card, 100), &mut chat);
    assert_eq!(prompt.messages, [assistant("short")]);
}

#[test]
fn placeholders_and_the_empty_reply_stay_out() {
    let card = Character::default();
    let mut chat = chat(&["Hi", "Hello", "Go on", ""]);
    chat.messages[1].complete = false;
    let prompt = run(&request(&card, 10_000), &mut chat);
    assert_eq!(prompt.messages, [user("Hi"), user("Go on")]);

    let req = PromptRequest {
        is_impersonating: true,
        ..request(&card, 10_000)
    };
    let prompt = run(&req, &mut chat);
    assert_eq!(prompt.messages, [user("Hi"), user("Go on"), assistant("")]);
}

#[test]
fn lorebook_token_budget() {
    let mut card = with_lorebook(vec![
        LorebookEntry {
            insertion_order: 1,
            ..constant("Alpha...")
        },
        LorebookEntry {
            insertion_order: 2,
            ..constant("Beta....")
        },
        LorebookEntry {
            insertion_order: 3,
            ..constant("Gamma!")
        },
        LorebookEntry {
            insertion_order: 4,
            ignore_budget: true,
            ..constant("Delta...")
        },
        LorebookEntry {
            insertion_order: 5,
            ..constant("E.")
        },
    ]);
    card.lorebook.as_mut().unwrap().token_budget = 10;
    // Alpha takes 8 of 10; Beta and Gamma do not fit, Delta is exempt, E still fits.
    let prompt = run(&request(&card, 10_000), &mut chat(&["Hi"]));
    assert_eq!(
        prompt.messages[0],
        system("<world_info>\nAlpha...\n\nDelta...\n\nE.\n</world_info>")
    );
}

#[test]
fn lorebook_entries_that_overflow_the_context_are_skipped() {
    let card = with_lorebook(vec![
        LorebookEntry {
            sticky: 3,
            ..constant(&"x".repeat(95))
        },
        LorebookEntry {
            sticky: 3,
            insertion_order: 200,
            ..constant("small")
        },
    ]);
    let mut chat = chat(&["Hi"]);
    let prompt = run(&request(&card, 100), &mut chat);
    assert_eq!(
        prompt.messages,
        [system("<world_info>\nsmall\n</world_info>"), user("Hi")]
    );
    // Only the entry that made it in starts its sticky phase.
    assert_eq!(chat.active_stickies.keys().collect::<Vec<_>>(), ["1"]);
}

#[test]
fn example_dialogue_follows_the_system_message() {
    let card = Character {
        name: "Cass".into(),
        mes_example: "{{user}}: hi\n{{char}}: hello".into(),
        ..Default::default()
    };
    let mut chat = ChatState {
        persona_name: "Rowan".into(),
        ..chat(&["Hi"])
    };
    let prompt = run(&request(&card, 10_000), &mut chat);
    assert_eq!(
        prompt.messages[1..],
        [
            system("<example_dialogue>\nRowan: hi\nCass: hello\n</example_dialogue>"),
            user("Hi")
        ]
    );
    assert_eq!(
        prompt.breakdown.segments.last().unwrap().kind,
        SegmentKind::ExampleDialogue
    );
}

#[test]
fn example_dialogue_is_cut_to_the_room_left() {
    let card = Character {
        mes_example: "é".repeat(300),
        ..Default::default()
    };
    // 200 tokens: 20 for the reply, 39 for the wrapper, 141 for the content,
    // of which, beside the 41 of the note that it is cut, whole blocks of 25:
    // 100. 300 * (100 / 300) * 0.95 = 95 characters are kept.
    let prompt = run(&request(&card, 200), &mut chat(&[]));
    let expected = format!(
        "<example_dialogue>\n{}\n...[Example truncated for context limit]\n</example_dialogue>",
        "é".repeat(95)
    );
    assert_eq!(prompt.messages, [system(&expected)]);
}

#[test]
fn example_dialogue_is_left_out_without_room() {
    let card = Character {
        mes_example: "Example".into(),
        ..Default::default()
    };
    let line = "x".repeat(50);
    let prompt = run(&request(&card, 100), &mut chat(&[&line]));
    assert_eq!(prompt.messages, [user(&line)]);
}

#[test]
fn macros_share_the_chat_and_global_variables() {
    let card = Character {
        system_prompt: "{{setvar::mood::grim}}{{$visits++}}{{pick::a::b::c}}".into(),
        post_history_instructions: "Mood: {{getvar::mood}}, visit {{$visits}}.".into(),
        ..Default::default()
    };
    let mut chat = chat(&["I feel {{getvar::mood}}."]);
    let mut globals = Variables::new();
    let req = request(&card, 10_000);

    let first = build(&req, &mut chat, &mut globals);
    assert_eq!(first.messages[1], user("I feel grim."));
    assert_eq!(
        first.messages[2],
        system("<post_history_instructions>\nMood: grim, visit 1.\n</post_history_instructions>")
    );
    assert_eq!(chat.local_variables["mood"], "grim");
    assert_eq!(globals["visits"], "1");

    // A second build keeps the pick and moves the counter on.
    let second = build(&req, &mut chat, &mut globals);
    let pick = &chat.local_variables["__sys_pick_system_0"];
    assert_eq!(
        first.messages[0].content,
        format!("<system_prompt>\n1{pick}\n</system_prompt>")
    );
    assert_eq!(
        second.messages[0].content,
        format!("<system_prompt>\n2{pick}\n</system_prompt>")
    );
}

#[test]
fn token_estimate_weighs_writing_systems() {
    assert_eq!(tokens::estimate(""), 0);
    assert_eq!(tokens::estimate("abcd"), 1);
    assert_eq!(tokens::estimate("abcde"), 2);
    assert_eq!(tokens::estimate("привет"), 3);
    assert_eq!(tokens::estimate("黒猫"), 2);
    assert_eq!(tokens::estimate("한국어"), 3);
    assert_eq!(tokens::estimate("😀"), 1);
    assert_eq!(tokens::estimate("שלום"), 3);
}

/// A picture costs the context `PICTURE_TOKENS` besides its message's words, and a
/// message of pictures alone is sent without a text part.
#[test]
fn a_messages_pictures_count_against_the_context_and_go_without_an_empty_text() {
    let card = Character::default();
    let line = "b".repeat(30);
    let mut pictured = chat(&["a", &line]);
    pictured.messages[0].pictures = vec!["data:image/png;base64,AA==".into()];
    let prompt = run(&request(&card, 1_200), &mut pictured);
    assert_eq!(prompt.messages.len(), 2);
    let prompt = run(&request(&card, 1_000), &mut pictured);
    assert_eq!(prompt.messages, [assistant(&line)]);

    let alone = PromptMessage {
        pictures: vec!["data:image/png;base64,AA==".into()],
        ..PromptMessage::new(Role::User, "")
    };
    assert_eq!(
        serde_json::to_value(&alone).unwrap(),
        serde_json::json!({ "role": "user", "content": [{ "type": "image_url", "image_url": { "url": "data:image/png;base64,AA==" } }] })
    );
}

#[test]
fn history_macros_run_once_in_order_and_draw_the_same_on_every_build() {
    let card = Character {
        name: "Mira".into(),
        ..Default::default()
    };
    let req = request(&card, 10_000);
    let mut chat = chat(&[
        "{{setvar::mood::happy}}Hello.",
        "Hi.",
        "{{setvar::mood::sad}}I roll {{roll:1d1000000000}}, {{random::a::b::c::d::e::f::g::h}}.",
    ]);
    let first = run(&req, &mut chat);
    // The newer message's value is the one kept.
    assert_eq!(chat.local_variables["mood"], "sad");
    let said = first
        .messages
        .iter()
        .find(|m| m.content.starts_with("I roll"))
        .unwrap()
        .content
        .clone();

    // The next build sees the reply and a new message; the first three are in the variables already.
    chat.messages
        .push(ChatMessage::new("3", Role::Assistant, "So be it."));
    chat.messages
        .push(ChatMessage::new("4", Role::User, "And now?"));
    chat.settled = 3;
    let second = run(&req, &mut chat);
    assert_eq!(chat.local_variables["mood"], "sad");
    assert!(
        second.messages.iter().any(|m| m.content == said),
        "{said} drawn anew"
    );
}

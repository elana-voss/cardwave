//! The prompts of a chat's replies (`chats::reply`); what they do in a chat
//! is tested through the routes in `generate.rs`.

use chrono::{DateTime, FixedOffset};
use cw_chat::chats::reply::{length_hint, time_note};
use cw_prompt::{ChatMessage, Role};

fn said(role: Role, content: &str) -> ChatMessage {
    ChatMessage::new(content, role, content)
}

/// The user's next message is as long as the user's last five, on average:
/// in paragraphs where one has several, else in sentences, else one paragraph.
#[test]
fn length_hint_follows_the_users_own_messages() {
    assert_eq!(
        length_hint(&[]),
        " Limit your response to approximately 1 paragraph."
    );
    let sentences = [
        said(Role::User, "Hi. How are you?"),
        said(Role::Assistant, "Fine.\n\nAnd you? Good. Yes."),
        said(Role::User, "Good. Very good. Thanks. Bye."),
    ];
    assert_eq!(
        length_hint(&sentences),
        " Limit your response to approximately 3 sentences."
    );
    let paragraphs = [
        said(Role::User, "One.\n\nTwo.\n\nThree."),
        said(Role::User, "Only one."),
    ];
    assert_eq!(
        length_hint(&paragraphs),
        " Limit your response to approximately 2 paragraphs."
    );
}

/// A character writing first is told the date, the time and how long since the
/// newest message; a reply to the user is told so only after a pause of an hour
/// or more, of the message before the user's.
#[test]
fn the_time_is_told_where_the_character_writes_first_or_after_a_pause() {
    let now: DateTime<FixedOffset> = "2026-10-20T14:05:00+02:00".parse().unwrap();
    let ms = now.timestamp_millis();
    let (minute, hour) = (60_000, 3_600_000);
    assert_eq!(
        time_note(&[], &[], now).as_deref(),
        Some("[It is Tuesday, 20 October 2026, 14:05. There is no message yet.]")
    );
    let greeting = [said(Role::Assistant, "Hello.")];
    assert_eq!(
        time_note(&greeting, &[ms - 3 * hour], now).as_deref(),
        Some("[It is Tuesday, 20 October 2026, 14:05. The last message was written 3 hours ago.]")
    );
    assert_eq!(
        time_note(&greeting, &[ms - 10_000], now).as_deref(),
        Some(
            "[It is Tuesday, 20 October 2026, 14:05. The last message was written less than a minute ago.]"
        )
    );
    let answered = [said(Role::Assistant, "Hello."), said(Role::User, "Hi.")];
    assert_eq!(time_note(&answered, &[ms - 59 * minute, ms], now), None);
    assert_eq!(
        time_note(&answered, &[ms - 2 * 24 * hour, ms - minute], now).as_deref(),
        Some(
            "[It is Tuesday, 20 October 2026, 14:05. Before {{user}}'s message, the last one was written 2 days ago.]"
        )
    );
    assert_eq!(
        time_note(&answered, &[ms - hour - minute, ms - minute], now).as_deref(),
        Some(
            "[It is Tuesday, 20 October 2026, 14:05. Before {{user}}'s message, the last one was written 1 hour ago.]"
        )
    );
}

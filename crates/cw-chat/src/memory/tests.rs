#[test]
fn a_name_is_renamed_where_it_is_a_whole_word() {
    let renamed = |text| crate::memory::word_renamed(text, "Guest", "{{user}}");
    assert_eq!(
        renamed("Guest's Guests, Guest."),
        "{{user}}'s Guests, {{user}}."
    );
    let korean = crate::memory::word_renamed("게스트는 차를 좋아한다", "게스트", "Guest");
    assert_eq!(korean, "Guest는 차를 좋아한다");
}

#[test]
fn who_know_a_memory_are_its_names_asked_each_once() {
    let may = ["Ann", "Bob", "ann"].map(String::from);
    let asked = ["ANN", "Odo", "bob"].map(String::from);
    assert_eq!(crate::memory::known_of(&may, &asked), ["ann", "bob"]);
}

use super::*;

fn kept(id: i64, chat: Option<i64>, block: i64, chain: &str) -> Kept {
    Kept {
        id,
        chat_id: chat,
        block,
        chain: chain.into(),
    }
}

#[test]
fn a_block_holds_until_its_messages_change_or_its_chat_is_deleted() {
    let read = ChatRead {
        chat_id: 1,
        user: "Sam".into(),
        cast: Vec::new(),
        said: Vec::new(),
        chains: vec!["a".into(), "b2".into()],
    };
    let blocks = [
        kept(1, Some(1), 0, "a"),
        kept(2, Some(2), 0, "x"),
        kept(3, Some(1), 1, "b"),
    ];
    assert_eq!(holding(&blocks, &[&read]), 2);
    let blocks = [kept(1, Some(1), 0, "a"), kept(2, None, 0, "x")];
    assert_eq!(holding(&blocks, &[&read]), 1);
    assert_eq!(holding(&blocks[..1], &[]), 1);
}

#[test]
fn a_day_is_a_calendar_day_counted_from_the_memorys_first() {
    use chrono::TimeZone;
    let noon = chrono::Local
        .with_ymd_and_hms(2026, 10, 1, 12, 0, 0)
        .unwrap()
        .timestamp_millis();
    let (first, hour) = (date(noon), 3_600_000);
    assert_eq!(day(Mode::Companion, Some(first), noon + 11 * hour), Some(1));
    assert_eq!(day(Mode::Companion, Some(first), noon + 13 * hour), Some(2));
    assert_eq!(day(Mode::Assistant, None, noon), Some(1));
    assert_eq!(day(Mode::Roleplay, Some(first), noon), None);
}

//! Who replies next in a chat of several characters: the three turn orders,
//! the character picked by hand, the speaking order the user changes, and a
//! reply that names nobody; no character is muted, one muted before neither.
//!
//! `crew` is the three a turn order picks among (Ada, Bo and "Cy Vane", as
//! `Candidate`s); `called` is
//! a cast of other names, numbered from 1 in speaking order, and `names` whom
//! a message of the user names among such a cast, which is the last of them
//! where it names nobody, so a cast there ends with one that is not named.
//! `user` and `by` are what was said,
//! `speaking` its characters in speaking order with their places, and
//! `card` a card of those three, each as talkative as told and the third
//! called as told. The tests over HTTP have `common::api::Api` write the
//! replies and wait for a reply's end by reading the chat (`reply`).

mod common;

use std::time::Duration;

use common::Scratch;
use common::api::{Api, says};
use common::server::{Server, WAIT, start};
use cw_accounts::users;
use cw_ccv4::png::{self, Container};
use cw_chat::chats::turn::{self, Candidate, Said, Turn, pick};
use cw_chat::chats::{self, ChatSort, Find, NewChat, NewMessage, TurnOrder};
use cw_core::NotFound;
use cw_library::cards::Show;
use cw_library::trash;
use cw_prompt::Role;
use cw_store::Db;
use serde_json::{Value, json};
use tokio::time::{sleep, timeout};

const ADA: i64 = 11;
const BO: i64 = 12;
const CY: i64 = 13;

/// The crew in speaking order, each as talkative as `talk` says.
fn crew_of(talk: [f64; 3]) -> Vec<Candidate> {
    [(ADA, "Ada"), (BO, "Bo"), (CY, "Cy Vane")]
        .into_iter()
        .zip(talk)
        .map(|((id, name), talkativeness)| Candidate {
            id,
            name: name.to_string(),
            talkativeness,
        })
        .collect()
}

/// The crew, each as talkative as the other.
fn crew() -> Vec<Candidate> {
    crew_of([0.5; 3])
}

/// The user's message.
fn user(words: &str) -> Said<'_> {
    Said { by: None, words }
}

/// A message of the chat character `by`.
fn by(by: i64, words: &str) -> Said<'_> {
    Said {
        by: Some(by),
        words,
    }
}

#[test]
fn the_natural_order_has_the_one_named_in_the_newest_messages_reply() {
    let natural = |said: &[Said<'_>], chance| pick(TurnOrder::Natural, &crew(), said, chance);
    // Where nobody is named, chance picks among those who did not speak last: the first of them at 0, the last at 0.75.
    let unnamed = |said: &[Said<'_>], others: [i64; 2]| {
        assert_eq!(
            [natural(said, 0.0), natural(said, 0.75)],
            others.map(Some),
            "{said:?}"
        );
    };

    // The user names one, also the one who spoke last, in any case and with what stands against a word.
    for words in [
        "Bo, what do you see?",
        "what about BO",
        "Is that Bo's boat?",
        "(bo)",
    ] {
        let said = [by(BO, "Hm."), user(words)];
        assert_eq!(natural(&said, 0.99), Some(BO), "{words}");
    }
    // A name is a whole word.
    for words in [
        "Bolt the door.",
        "A hobo came by.",
        "Bo2?",
        "Boë sails.",
        "bo_",
    ] {
        unnamed(&[by(ADA, "Hm."), user(words)], [BO, CY]);
    }
    assert_eq!(
        natural(&[by(ADA, "Hm."), user("cy vane, come.")], 0.0),
        Some(CY)
    );
    // Letters beyond a to z are letters too.
    let emile = [Candidate {
        id: 21,
        name: "Émile".to_string(),
        talkativeness: 0.5,
    }];
    let named = |words| {
        pick(
            TurnOrder::Natural,
            &[crew(), emile.to_vec()].concat(),
            &[user(words)],
            0.0,
        )
    };
    assert_eq!(named("émile!"), Some(21));
    assert_eq!(named("Émilement."), Some(ADA));

    // One without a name is named by nothing.
    let nameless = [Candidate {
        id: 31,
        name: String::new(),
        talkativeness: 0.5,
    }];
    let cast = [nameless.to_vec(), crew()].concat();
    let unnamed_too = pick(TurnOrder::Natural, &cast, &[user("Well, well.")], 0.99);
    assert_eq!(unnamed_too, Some(CY));

    // The newest message counts before the one before it, and where it names nobody that one counts.
    let before = by(ADA, "Cy Vane knows.");
    assert_eq!(natural(&[before, user("And Bo?")], 0.0), Some(BO));
    assert_eq!(natural(&[before, user("Go on.")], 0.0), Some(CY));
    // No message before those two is read.
    unnamed(&[user("Bo!"), by(ADA, "Hm."), user("Well?")], [BO, CY]);
    // Of two named in one message it is the first in speaking order, not in the message.
    let both = [by(ADA, "Hm."), user("Cy Vane and Bo, listen.")];
    assert_eq!(natural(&both, 0.99), Some(BO));

    // A message does not name its own writer, who tells of itself by its name.
    unnamed(&[by(BO, "Bo shrugs."), user("And then?")], [ADA, CY]);
    // The writer of the newest message is passed over: it is named by nothing, so none answers itself,
    unnamed(&[user("Bo, speak."), by(BO, "Hm.")], [ADA, CY]);
    // while the one it names replies.
    let onward = [user("Bo, speak."), by(BO, "Bo looks at Cy Vane.")];
    assert_eq!(natural(&onward, 0.0), Some(CY));

    // Nothing said yet: by chance among all.
    assert_eq!(natural(&[], 0.0), Some(ADA));
    assert_eq!(natural(&[], 0.99), Some(CY));
}

/// A cast called so, in speaking order, the first with the number 1.
fn called(names: &[&str]) -> Vec<Candidate> {
    let one = |(at, name): (usize, &&str)| Candidate {
        id: at as i64 + 1,
        name: name.to_string(),
        talkativeness: 0.5,
    };
    names.iter().enumerate().map(one).collect()
}

/// Whom the user's message names among a cast of three or more: the number of
/// the one who replies at the chance that picks the last where nobody is named.
fn names(cast: &[Candidate], words: &str) -> i64 {
    pick(TurnOrder::Natural, cast, &[user(words)], 0.99).unwrap()
}

#[test]
fn a_word_of_a_name_names_its_character() {
    let natural = |said: &[Said<'_>], chance| pick(TurnOrder::Natural, &crew(), said, chance);
    // Either word of "Cy Vane" names Cy, in any case and with what stands against a word,
    for words in ["Cy, come.", "Vane!", "is that VANE's boat?", "(cy)"] {
        let said = [by(ADA, "Hm."), user(words)];
        assert_eq!(natural(&said, 0.0), Some(CY), "{words}");
    }
    // as a whole word only.
    for words in ["Vanessa!", "Cyan seas.", "The vanes turn.", "cy_"] {
        let said = [by(CY, "Hm."), user(words)];
        assert_eq!(natural(&said, 0.99), Some(BO), "{words}");
    }
    // The newest message counts before the one before it, a word in it before a whole name there,
    let said = [by(BO, "Ada knows."), user("Vane?")];
    assert_eq!(natural(&said, 0.0), Some(CY));
    // and a word in the one before it where the newest names nobody.
    let said = [by(ADA, "Vane knows."), user("Go on.")];
    assert_eq!(natural(&said, 0.0), Some(CY));

    // A word is what stands between signs that are no letter, digit or "_".
    let cast = called(&["Jean-Luc O'Brien", "Ann_Lee Marsh", "Bo"]);
    for (words, named) in [
        ("Luc?", 1),
        ("jean, wait", 1),
        ("Brien!", 1),
        ("O, what a day", 3),
        ("Marsh?", 2),
        ("ann_lee", 2),
        ("Ann and Lee", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }

    // A letter alone and a number name nobody,
    let cast = called(&["J. T. Marsh", "Agent 47", "Unit K9", "Bo"]);
    for (words, named) in [
        ("J? T?", 4),
        ("I have 47 of them.", 4),
        ("Marsh!", 1),
        ("agent?", 2),
        ("K9, here", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // nor do the little words of a name, which are said all the time or before another's name,
    let cast = called(&[
        "The Captain",
        "Lady of the Lake",
        "Your Roommate",
        "Dr. Who",
        "Miss Scarlet",
        "Marie de la Croix",
        "Otto von der Heide",
        "Bo",
    ]);
    for (words, named) in [
        ("Who is at the door of your house?", 8),
        ("I miss you, and so does Dr. Brown.", 8),
        ("Voilà: de la crème. Von der Tür!", 8),
        ("Captain!", 1),
        ("the lady?", 2),
        ("my roommate", 3),
        ("Scarlet, you", 5),
        ("croix", 6),
        ("Heide?", 7),
        // while the whole name names as ever.
        ("Dr. Who?", 4),
        ("Miss Scarlet!", 5),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // A name that is such a word and no more is a name.
    let cast = called(&["Ada", "Miss", "Bo"]);
    assert_eq!(names(&cast, "I miss you."), 2);
    // Every one of the little words: said all at once, they do not name the one whose name has them all.
    let little = "the an of and or in on at to for from with by as my your his her its our their you me he \
                  she it we they him them us who mr mrs ms mx dr jr sr st miss de del della di da do dos das \
                  du des la le les los las el il lo van von der den die ter ten zu und et bin ibn \
                  さん さま くん ちゃん たん どの";
    let cast = called(&[&format!("{little} Zed"), "Ada", "Bo"]);
    assert_eq!(names(&cast, little), 3);
    assert_eq!(names(&cast, "zed?"), 1);
    // Not among them are those that are names of their own too.
    let cast = called(&["Al Reed", "Ben Kay", "Don Vito", "Bo"]);
    for (words, named) in [("al?", 1), ("Ben!", 2), ("don", 3)] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // A "not" said short is no name, whole or a word of one: "don't" names no Don,
    for (words, named) in [
        ("Don't!", 4),
        ("I don’t know.", 4),
        ("Don't, Don.", 3),
        ("Don'ts", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    let cast = called(&["Can", "Won", "Bo"]);
    assert_eq!(names(&cast, "I can't, and she won't."), 3);
    // while what is its own names it: "Won's turn" names Won.
    assert_eq!(names(&cast, "Won's turn."), 2);
}

#[test]
fn a_name_written_without_blanks_is_named_where_it_stands() {
    // In Japanese and Chinese, written without blanks, a name is named wherever it stands, with what is said after it,
    let cast = called(&["山田", "王小明", "Ada", "Bo"]);
    for (words, named) in [
        ("山田、来て", 1),
        ("山田さん、来て", 1),
        ("ねえ山田くん", 1),
        ("那是王小明的书。", 2),
        ("山だ", 4),
        ("田山さん", 4),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // and beside letters of another script, which end a word there, and the other way round.
    for (words, named) in [
        ("Hey山田!", 1),
        ("Yamada山田", 1),
        ("Adaさん、来て", 3),
        ("Ada来て", 3),
        ("Adaline来て", 4),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // A name that ends in a sign that is no letter goes on into a letter beside it.
    let cast = called(&["Q.", "Ada", "Bo"]);
    assert_eq!(names(&cast, "Q., come"), 1);
    assert_eq!(names(&cast, "That is q.e.d."), 3);
    // A name of one sign is named only standing apart from the signs of its script.
    let cast = called(&["空", "Ada", "Bo"]);
    for (words, named) in [
        ("空、来て", 1),
        ("「空」", 1),
        ("Sora空", 1),
        ("空が青い", 3),
        ("青空", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }

    // A name of several parts is named by each, with a blank or "・" between them or a change of script,
    let cast = called(&[
        "山田 太郎",
        "ジョン・スミス",
        "春野サクラ",
        "美空ひばり",
        "Bo",
    ]);
    for (words, named) in [
        ("太郎くん", 1),
        ("スミスさん", 2),
        ("ジョン!", 2),
        ("サクラちゃん", 3),
        ("春野?", 3),
        ("ひばりさん", 4),
        ("美空", 4),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // and one of Han without a blank by its first and its last two signs or more, and not by those between,
    let cast = called(&["山田太郎", "長谷川一郎", "Bo"]);
    for (words, named) in [
        ("山田さん", 1),
        ("太郎、来て", 1),
        ("山田太郎!", 1),
        ("田太", 3),
        ("長谷川さん", 2),
        ("一郎", 2),
        ("谷川さん", 3),
        ("谷川一", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // Han is also the signs used seldom, and "々".
    for name in ["佐々木太郎", "𠮷田太郎", "山﨑太郎", "㐂田太郎"] {
        let cast = called(&[name, "Ada", "Bo"]);
        let first: String = name.chars().take(2).collect();
        assert_eq!(names(&cast, &format!("{first}さん")), 1, "{name}");
    }
    // while a word of Kana is not cut: "まき" is no word of "うずまき".
    let cast = called(&["うずまきナルト", "Ada", "Bo"]);
    for (words, named) in [
        ("うずまき!", 1),
        ("ナルトくん", 1),
        ("まき", 3),
        ("ナル", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // "ー" draws out a sound of Hiragana too, and does not cut its word.
    let cast = called(&["らーめん", "Ada", "Bo"]);
    assert_eq!(names(&cast, "らーめん!"), 1);
    assert_eq!(names(&cast, "ごめん"), 3);
    // What is said after a name names nobody by itself, of one sign or in Hiragana.
    let cast = called(&["ハルちゃん", "山田様", "Ada", "Bo"]);
    for (words, named) in [("ミカちゃん", 4), ("お客様", 4), ("ハル!", 1), ("山田", 2)]
    {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // As anywhere, the whole name goes before a word, and a word one alone has before one several have.
    let cast = called(&["山田", "山田太郎", "山田花子", "Bo"]);
    for (words, named) in [
        ("山田太郎さん", 2),
        ("山田花子さん", 3),
        ("花子さん、山田さん", 1),
        ("花子さん", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    let cast = called(&["山田太郎", "山田花子", "Bo"]);
    assert_eq!(names(&cast, "山田さん"), 1);
    assert_eq!(names(&cast, "山田さん、花子さん"), 2);

    // In Korean, written with blanks, what is said after a name is written onto it, and before it is not,
    let cast = called(&["민수", "김지은", "Ada", "Bo"]);
    for (words, named) in [
        ("민수야, 와", 1),
        ("민수씨!", 1),
        ("김민수가 왔어", 4),
        ("김지은은?", 2),
        ("Ada야", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
    // nor onto a name of one sign.
    let cast = called(&["별", "Ada", "Bo"]);
    assert_eq!(names(&cast, "별, 와"), 1);
    assert_eq!(names(&cast, "별이 빛나"), 3);
    // A name of Hangul of three signs, written without a blank, is named by its last two, the given name, as well.
    let cast = called(&["김민수", "Ada", "Bo"]);
    for (words, named) in [
        ("민수야, 와", 1),
        ("김민수 씨", 1),
        ("김민", 3),
        ("이민수가 왔어", 3),
    ] {
        assert_eq!(names(&cast, words), named, "{words}");
    }
}

#[test]
fn of_several_a_message_names_the_one_it_names_best() {
    // The whole name goes before a word: "Vale" is Mira's word too, and she is the first in speaking order.
    let vales = called(&["Mira Vale", "Tom Vale", "Bo"]);
    assert_eq!(names(&vales, "Tom Vale, go on."), 2);
    // A word that one alone has goes before a word that several have,
    assert_eq!(names(&vales, "Vale? Tom, I mean."), 2);
    assert_eq!(names(&vales, "Mr Vale, or Bo."), 3);
    // and a word that several have names the first of them in speaking order,
    assert_eq!(names(&vales, "Vale, go on."), 1);
    let tom_first = called(&["Tom Vale", "Ada Smith", "Mira Vale"]);
    assert_eq!(names(&tom_first, "Vale and Ada."), 2);
    // Of two named by words of their own it is the first in speaking order.
    assert_eq!(names(&tom_first, "Smith, ask Tom."), 1);

    // One's whole name is another's word: said alone it names the one whose name it is,
    for cast in [
        called(&["Mira Vale", "Mira", "Bo"]),
        called(&["Mira", "Mira Vale", "Bo"]),
    ] {
        let number = |name| cast.iter().find(|one| one.name == name).unwrap().id;
        assert_eq!(names(&cast, "Mira, go on."), number("Mira"));
        // and inside the longer name it names nobody: that one is named,
        assert_eq!(names(&cast, "Mira Vale, go on."), number("Mira Vale"));
        assert_eq!(names(&cast, "Vale?"), number("Mira Vale"));
        // while both are named where it stands alone as well, the first in speaking order replying.
        assert_eq!(names(&cast, "Mira, and Mira Vale."), 1);
    }

    // The words of a whole name are that character's, also where it cannot be named: the writer, who tells of itself by its name, and by a word of it too, which so names nobody.
    let after = |words| {
        pick(
            TurnOrder::Natural,
            &vales,
            &[user("Well?"), by(1, words)],
            0.99,
        )
    };
    assert_eq!(after("Mira Vale looks out to sea."), Some(3));
    assert_eq!(after("Vale looks out to sea."), Some(3));
    assert_eq!(after("Vale looks at Tom."), Some(2));
    // The writer of the newest message is not named by the one before it, so the other who has the word is.
    let said = [user("Vale, go on."), by(1, "Hm.")];
    assert_eq!(pick(TurnOrder::Natural, &vales, &said, 0.99), Some(2));
}

#[test]
fn the_list_order_has_the_characters_reply_one_after_the_other() {
    let list = |said: &[Said<'_>]| pick(TurnOrder::List, &crew(), said, 0.99);
    // The first begins, each follows the one before, and the first follows the last.
    assert_eq!(list(&[]), Some(ADA));
    assert_eq!(list(&[user("Hello.")]), Some(ADA));
    assert_eq!(list(&[by(ADA, "Hm.")]), Some(BO));
    assert_eq!(list(&[by(ADA, "Hm."), by(BO, "Hm.")]), Some(CY));
    assert_eq!(list(&[by(BO, "Hm."), by(CY, "Hm.")]), Some(ADA));
    // Who spoke last is asked past the user's messages, however many,
    let far = [by(ADA, "Hm."), user("One."), user("Two."), user("Three.")];
    assert_eq!(list(&far), Some(BO));
    // and a name decides nothing.
    assert_eq!(list(&[by(ADA, "Hm."), user("Cy Vane?")]), Some(BO));
    // After one who is no character of the chat, the first begins again.
    assert_eq!(list(&[by(99, "Hm.")]), Some(ADA));
    // A chat without characters has nobody to reply.
    assert_eq!(pick(TurnOrder::List, &[], &[by(ADA, "Hm.")], 0.0), None);
}

#[test]
fn the_random_order_picks_by_chance_the_more_talkative_more_often() {
    let random =
        |talk, said: &[Said<'_>], chance| pick(TurnOrder::Random, &crew_of(talk), said, chance);
    /// Who is picked at each of the chances.
    fn each<const N: usize>(
        pick: impl Fn(f64) -> Option<i64>,
        chances: [f64; N],
    ) -> [Option<i64>; N] {
        chances.map(pick)
    }

    // Nobody spoke: each has the share of the chances that its talkativeness is of all.
    let nobody = |chance| random([0.5, 0.25, 0.25], &[user("Hello.")], chance);
    assert_eq!(
        each(nobody, [0.0, 0.49, 0.5, 0.74, 0.75, 0.99]),
        [ADA, ADA, BO, BO, CY, CY].map(Some)
    );
    // The one who spoke last is not picked while there is another,
    let after_ada = |chance| random([0.5, 0.25, 0.25], &[by(ADA, "Hm."), user("Well?")], chance);
    assert_eq!(
        each(after_ada, [0.0, 0.49, 0.5, 0.99]),
        [BO, BO, CY, CY].map(Some)
    );
    // whoever is named.
    let named = |chance| random([0.5; 3], &[by(ADA, "Hm."), user("Ada?")], chance);
    assert_eq!(each(named, [0.0, 0.99]), [BO, CY].map(Some));
    // One that is not talkative at all is never picked beside one that is,
    let one = |chance| random([0.0, 1.0, 0.0], &[], chance);
    assert_eq!(each(one, [0.0, 0.5, 0.99]), [BO, BO, BO].map(Some));
    // also at the highest chance there is, which the rounding of these shares leaves over,
    let highest = 1.0 - f64::EPSILON / 2.0;
    assert_eq!(random([0.3, 0.7, 0.0], &[], highest), Some(BO));
    // and where none is, each is as likely as the other.
    let none = |chance| random([0.0; 3], &[], chance);
    assert_eq!(
        each(none, [0.0, 0.33, 0.34, 0.66, 0.67, 0.99]),
        [ADA, ADA, BO, BO, CY, CY].map(Some)
    );

    // A chat of one has that one reply, though it spoke last.
    let alone = [Candidate {
        id: ADA,
        name: "Ada".to_string(),
        talkativeness: 0.5,
    }];
    for order in [TurnOrder::Natural, TurnOrder::List, TurnOrder::Random] {
        assert_eq!(pick(order, &alone, &[by(ADA, "Hm.")], 0.5), Some(ADA));
        assert_eq!(pick(order, &[], &[], 0.5), None);
    }
}

/// A card of three, Ada, who greets, Bo and Cy, who is called as `cy` says.
/// Each is as talkative as `talk` says, a value as TOML writes it; an empty
/// one says nothing.
fn card(cy: &str, talk: [&str; 3]) -> Vec<u8> {
    let character = |id: &str, name: &str, talk: &str, greets: bool| {
        let talk = match talk {
            "" => String::new(),
            value => format!("group-talkativeness = {value}\n"),
        };
        let greetings = if greets { r#""greeting.ada""# } else { "" };
        format!(
            "[name.{id}]\ntext = \"{name}\"\n\n[character.{id}]\nname-char = \"name.{id}\"\n\
             greetings = [{greetings}]\n{talk}prompt = [\"CHAT-HISTORY\"]\n\n"
        )
    };
    let toml = format!(
        "spec = \"ccv4:1.0.0\"\n\n[meta-info]\ntitle = \"The Skerry Crew\"\n\n\
         [greeting.ada]\ntext = \"Ada looks up.\"\n\n{}{}{}",
        character("ada", "Ada", talk[0], true),
        character("bo", "Bo", talk[1], false),
        character("cy", cy, talk[2], false),
    );
    png::write(&Container {
        image: common::picture(),
        toml: vec![("card/0001_card.toml".to_string(), toml)],
        assets: Vec::new(),
    })
    .unwrap()
}

fn begin(db: &Db, user: i64, characters: &[(i64, &str)]) -> i64 {
    let new = NewChat {
        characters,
        persona_id: None,
        greeting: 0,
    };
    chats::create(db, user, &new).unwrap()
}

/// Adds a complete message to the chat: the user's, or the chat character `by`'s.
fn write(db: &Db, user: i64, chat: i64, by: Option<i64>, content: &str) -> i64 {
    let new = NewMessage {
        role: if by.is_some() {
            Role::Assistant
        } else {
            Role::User
        },
        speaker_id: by,
        content,
        complete: true,
    };
    chats::append(db, user, chat, &new).unwrap()
}

/// Who replies next in the chat at this chance.
fn next(db: &Db, user: i64, chat: i64, chance: f64) -> Option<i64> {
    let chat = chats::get(db, user, chat).unwrap().unwrap();
    turn::next(db, user, &chat, chance).unwrap()
}

/// The chat's turn as it is stored: its order, and who is picked by hand.
fn stored(db: &Db, user: i64, chat: i64) -> (TurnOrder, Option<i64>) {
    let chat = chats::get(db, user, chat).unwrap().unwrap();
    (chat.turn_order, chat.replier_id)
}

/// Why a change was refused.
fn refused<T>(change: anyhow::Result<T>) -> String {
    format!("{:#}", change.err().expect("the change was taken"))
}

#[test]
fn a_chat_picks_among_its_characters_as_the_versions_it_is_with_tell_them() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    // Ada's talkativeness is beyond the most there is, Bo's a number with a point, Cy's none at all.
    let made = common::import_whole(db, me, &card("Cy Vane", ["3", "0.9", "nan"])).unwrap();
    let chat = begin(
        db,
        me,
        &[
            (made.version_id, "ada"),
            (made.version_id, "bo"),
            (made.version_id, "cy"),
        ],
    );
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];

    // A chat starts with the natural order and nobody picked by hand.
    assert_eq!(stored(db, me, chat), (TurnOrder::Natural, None));
    // Ada greeted, and her greeting names herself alone: chance picks between Bo, as talkative as his card
    // says (0.9), and Cy, as talkative as a card that says nothing (0.5).
    assert_eq!(next(db, me, chat, 0.64), Some(bo));
    assert_eq!(next(db, me, chat, 0.65), Some(cy));
    // After Bo it is between Ada, who is as talkative as can be (1) and no more, and Cy.
    let asked = write(db, me, chat, None, "Well?");
    write(db, me, chat, Some(bo), "Hm.");
    assert_eq!(next(db, me, chat, 0.66), Some(ada));
    assert_eq!(next(db, me, chat, 0.67), Some(cy));

    // A character is named by the name its card gives it now. A word of that name will do.
    write(db, me, chat, None, "Cyrus, your watch.");
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    // The page edits a card's first character alone: Cy's card is given another name as a card from before is.
    let renamed = card("Cyrus Vane", ["3", "0.9", "nan"]);
    common::plant_whole(db, made.version_id, &renamed);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));

    // Who spoke last is asked of the branch in view: where Bo's answer is not on it, Ada was the last.
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    assert_eq!(next(db, me, chat, 0.99), Some(cy));
    chats::set_head(db, me, chat, asked).unwrap();
    assert_eq!(next(db, me, chat, 0.99), Some(bo));
}

#[test]
fn one_picked_by_hand_replies_in_the_orders_place_until_it_leaves() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [
        (made.version_id, "ada"),
        (made.version_id, "bo"),
        (made.version_id, "cy"),
    ];
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.99), Some(bo));

    // The one picked replies whatever the order says, and the order stays the chat's.
    turn::set(db, me, chat, Turn::ReplierId(cy)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, Some(cy)));
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    write(db, me, chat, None, "Ada?");
    assert_eq!(next(db, me, chat, 0.99), Some(cy));
    // Another picked takes its place, and an order takes the pick away.
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    turn::set(db, me, chat, Turn::Order(TurnOrder::Random)).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::Random, None));
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // When the one picked leaves the chat, its order picks again.
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    turn::set(db, me, chat, Turn::ReplierId(cy)).unwrap();
    chats::remove_character(db, me, cy).unwrap();
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // Refused, with nothing changed: a character of another chat, one that is none, a chat in the
    // Trash, and a chat that is another user's or not there.
    let other = begin(db, me, &all[..2]);
    let foreign = chats::participants(db, me, other).unwrap()[0].id;
    for nobody in [foreign, 999] {
        let why = refused(turn::set(db, me, chat, Turn::ReplierId(nobody)));
        assert_eq!(why, "the speaker is not part of this chat");
    }
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    let stranger = users::create(db, "sam").unwrap();
    for (who, which) in [(stranger, chat), (me, 999)] {
        for turn in [Turn::Order(TurnOrder::Random), Turn::ReplierId(ada)] {
            let failure = turn::set(db, who, which, turn).unwrap_err();
            assert!(failure.is::<NotFound>(), "{failure:#}");
        }
    }
    chats::set_trashed(db, me, chat, true).unwrap();
    for turn in [Turn::Order(TurnOrder::Random), Turn::ReplierId(ada)] {
        let why = refused(turn::set(db, me, chat, turn));
        assert_eq!(why, "the chat is in the Trash; restore it first");
    }
    assert_eq!(stored(db, me, chat), (TurnOrder::List, None));
    // A chat with one picked by hand is deleted for good as any other.
    turn::set(db, me, other, Turn::ReplierId(foreign)).unwrap();
    chats::set_trashed(db, me, other, true).unwrap();
    trash::delete_chat(db, me, other).unwrap();
    assert!(chats::get(db, me, other).unwrap().is_none());

    // A chat of one has that one reply under every order.
    let alone = begin(db, me, &all[..1]);
    let only = chats::participants(db, me, alone).unwrap()[0].id;
    for order in [TurnOrder::Natural, TurnOrder::List, TurnOrder::Random] {
        turn::set(db, me, alone, Turn::Order(order)).unwrap();
        assert_eq!(next(db, me, alone, 0.5), Some(only));
    }
}

#[test]
fn a_character_muted_before_takes_its_turn() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [(made.version_id, "ada"), (made.version_id, "bo")];
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo] = [cast[0].id, cast[1].id];
    // Muted when there was muting (the column is read by nothing now).
    db.with(|conn| conn.execute("update chat_characters set muted = 1", []))
        .unwrap();
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
}

/// The chat's characters in speaking order, each with its place.
fn speaking(db: &Db, user: i64, chat: i64) -> Vec<(i64, i64)> {
    let cast = chats::participants(db, user, chat).unwrap();
    cast.iter().map(|one| (one.id, one.position)).collect()
}

#[test]
fn a_character_moved_in_the_speaking_order_speaks_in_its_new_place() {
    let scratch = Scratch::new();
    let (db, me) = (&scratch.db, scratch.user);
    let made = common::import_whole(db, me, &card("Cy Vane", ["", "", ""])).unwrap();
    let all = [
        (made.version_id, "ada"),
        (made.version_id, "bo"),
        (made.version_id, "cy"),
    ];
    let other = begin(db, me, &all);
    let chat = begin(db, me, &all);
    let cast = chats::participants(db, me, chat).unwrap();
    let [ada, bo, cy] = [cast[0].id, cast[1].id, cast[2].id];
    let theirs = speaking(db, me, other);
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));

    // Cy moved between Ada, who spoke last, and Bo is next from the next reply on.
    assert_eq!(turn::reorder(db, me, cy, 1).unwrap(), chat);
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    // To the first place; a place past the last is the last; a character's own place changes nothing.
    turn::reorder(db, me, bo, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(bo, 0), (ada, 1), (cy, 2)]);
    assert_eq!(next(db, me, chat, 0.0), Some(cy));
    turn::reorder(db, me, bo, 99).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    turn::reorder(db, me, cy, 1).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
    // Another chat of the same characters keeps its own order.
    assert_eq!(speaking(db, me, other), theirs);

    // Of two named alike, the first in speaking order replies.
    turn::set(db, me, chat, Turn::Order(TurnOrder::Natural)).unwrap();
    write(db, me, chat, None, "Bo and Ada, a word.");
    assert_eq!(next(db, me, chat, 0.0), Some(ada));
    turn::reorder(db, me, bo, 0).unwrap();
    assert_eq!(next(db, me, chat, 0.0), Some(bo));
    // Who is picked by hand stays as it was.
    turn::set(db, me, chat, Turn::ReplierId(ada)).unwrap();
    turn::reorder(db, me, cy, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(cy, 0), (bo, 1), (ada, 2)]);
    assert_eq!(stored(db, me, chat), (TurnOrder::Natural, Some(ada)));
    turn::set(db, me, chat, Turn::Order(TurnOrder::List)).unwrap();

    // The chat is called after the one it began with: the list of chats and the export name them in the
    // order they joined.
    let find = Find {
        query: "",
        show: Show::default(),
        sort: ChatSort::default(),
    };
    let found = chats::find(db, me, &find).unwrap();
    let listed = found.iter().find(|one| one.chat.id == chat).unwrap();
    assert_eq!(listed.names, ["Ada", "Bo", "Cy Vane"]);
    let file = String::from_utf8(chats::export(db, me, chat).unwrap().data).unwrap();
    let head: Value = serde_json::from_str(file.lines().next().unwrap()).unwrap();
    assert_eq!(head["character_name"], "Ada");

    // One that joins after a move is the last; one that leaves leaves its place empty, which a move fills.
    let two = begin(db, me, &all[..2]);
    let pair = chats::participants(db, me, two).unwrap();
    let [first, second] = [pair[0].id, pair[1].id];
    turn::reorder(db, me, second, 0).unwrap();
    let third = chats::add_character(db, me, two, made.card_id, "cy").unwrap();
    assert_eq!(speaking(db, me, two), [(second, 0), (first, 1), (third, 2)]);
    chats::remove_character(db, me, second).unwrap();
    assert_eq!(speaking(db, me, two), [(first, 1), (third, 2)]);
    turn::reorder(db, me, third, 0).unwrap();
    assert_eq!(speaking(db, me, two), [(third, 0), (first, 1)]);
    // A character's message without a speaker, and a prompt for nobody named, are the one's the chat began with.
    let unnamed = NewMessage {
        role: Role::Assistant,
        speaker_id: None,
        content: "Hm.",
        complete: true,
    };
    let said = chats::append(db, me, two, &unnamed).unwrap();
    assert_eq!(
        chats::view(db, me, said).unwrap().message.speaker_id,
        Some(first)
    );
    assert_eq!(
        chats::prompt_inputs(db, me, two, None)
            .unwrap()
            .character
            .name,
        "Ada"
    );

    // A character is moved while a reply is being written, its own too.
    let reply = NewMessage {
        role: Role::Assistant,
        speaker_id: Some(ada),
        content: "",
        complete: false,
    };
    chats::append(db, me, chat, &reply).unwrap();
    turn::reorder(db, me, ada, 0).unwrap();
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);

    // Refused, with nothing changed: one that is none or another user's, and one of a chat in the Trash.
    let stranger = users::create(db, "sam").unwrap();
    for (who, which) in [(stranger, bo), (me, 999)] {
        let failure = turn::reorder(db, who, which, 0).unwrap_err();
        assert!(failure.is::<NotFound>(), "{failure:#}");
    }
    // The reply ends first: a chat is not moved to the Trash while one is written in it.
    chats::finish_interrupted(db).unwrap();
    chats::set_trashed(db, me, chat, true).unwrap();
    let why = refused(turn::reorder(db, me, bo, 0));
    assert_eq!(why, "the chat is in the Trash; restore it first");
    assert_eq!(speaking(db, me, chat), [(ada, 0), (cy, 1), (bo, 2)]);
}

/// One piece of a streamed reply, as OpenAI's API sends it, and the reply's end.
const REPLY: &str = "data: {\"choices\":[{\"delta\":{\"content\":\"Hm.\"}}]}\n\ndata: [DONE]\n\n";

/// Asks for a reply in the chat, waits for its end and tells who wrote it.
async fn reply(server: &Server, chat: &str, how: Value) -> i64 {
    let (status, message) = server.post(&format!("{chat}/generate"), how).await;
    assert_eq!(status, 202, "{message}");
    let written = async {
        loop {
            let (_, view) = server.get(chat).await;
            let newest = view["messages"].as_array().unwrap().last().unwrap().clone();
            if newest["complete"] == true {
                break newest;
            }
            sleep(Duration::from_millis(20)).await;
        }
    };
    let newest = timeout(WAIT, written).await.expect("the reply did not end");
    assert_eq!(newest["content"], "Hm.");
    newest["speaker_id"].as_i64().unwrap()
}

#[tokio::test]
async fn a_reply_that_names_nobody_is_written_by_the_one_the_chats_turn_says() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", REPLY)).await;
    let provider =
        json!({ "base_url": api.url, "model": "test-model", "api_key": "sk-test", "sampling": {} });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, made) = server.upload_whole(card("Cy Vane", ["", "", ""])).await;
    let character = |id: &str| json!({ "version_id": made["version_id"], "character": id });
    let new = json!({ "characters": [character("ada"), character("bo")] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let turn = format!("{chat}/turn");
    let [ada, bo] = [0, 1].map(|at| view["characters"][at]["id"].as_i64().unwrap());
    // What the chat says of its turn: its order, and who is picked by hand.
    let told = |chat: &Value| (chat["turn_order"].clone(), chat["replier_id"].clone());
    assert_eq!(told(&view["chat"]), (json!("natural"), Value::Null));

    // The natural order: after Ada's greeting Bo replies, and Ada replies to him.
    let said = json!({ "content": "Well?" });
    assert_eq!(server.post(&format!("{chat}/messages"), said).await.0, 201);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    assert_eq!(reply(&server, &chat, json!({})).await, ada);
    // Written again, a reply is its writer's, whoever the order would pick.
    assert_eq!(
        reply(&server, &chat, json!({ "regenerate": true })).await,
        ada
    );

    // An order set answers with the chat, and holds from the next reply on.
    let (status, set) = server.put(&turn, json!({ "order": "list" })).await;
    assert_eq!((status, told(&set)), (200, (json!("list"), Value::Null)));
    assert_eq!(set["id"], view["chat"]["id"]);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // One picked by hand replies every time,
    let (status, set) = server.put(&turn, json!({ "replier_id": bo })).await;
    assert_eq!((status, told(&set)), (200, (json!("list"), json!(bo))));
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // but for a reply that names its writer.
    assert_eq!(
        reply(&server, &chat, json!({ "speaker_id": ada })).await,
        ada
    );
    assert_eq!(reply(&server, &chat, json!({})).await, bo);
    // The chat is read with its turn, and listed with it.
    let (_, read) = server.get(&chat).await;
    assert_eq!(told(&read["chat"]), (json!("list"), json!(bo)));
    let (_, listed) = server.get("/api/chats").await;
    assert_eq!(told(&listed[0]), (json!("list"), json!(bo)));
    let (status, set) = server.put(&turn, json!({ "order": "random" })).await;
    assert_eq!((status, told(&set)), (200, (json!("random"), Value::Null)));
    assert_eq!(reply(&server, &chat, json!({})).await, ada);

    // What is no turn is refused, and a chat that is not there is not found.
    let (status, why) = server.put(&turn, json!({ "replier_id": 999 })).await;
    assert_eq!(
        (status, &why["error"]),
        (400, &json!("the speaker is not part of this chat"))
    );
    for none in [
        json!({ "order": "sideways" }),
        json!({}),
        json!({ "order": "list", "replier_id": bo }),
    ] {
        let (status, _) = server.put(&turn, none.clone()).await;
        assert!([400, 422].contains(&status), "{none}: {status}");
    }
    let (status, _) = server
        .put("/api/chats/999/turn", json!({ "order": "list" }))
        .await;
    assert_eq!(status, 404);
    let (_, read) = server.get(&chat).await;
    assert_eq!(told(&read["chat"]), (json!("random"), Value::Null));
}

#[tokio::test]
async fn a_character_is_moved_in_the_speaking_order_over_http() {
    let server = start().await;
    let api = Api::start(says(200, "text/event-stream", REPLY)).await;
    let provider =
        json!({ "base_url": api.url, "model": "test-model", "api_key": "sk-test", "sampling": {} });
    assert_eq!(server.put("/api/provider", provider).await.0, 200);
    let (_, made) = server.upload_whole(card("Cy Vane", ["", "", ""])).await;
    let character = |id: &str| json!({ "version_id": made["version_id"], "character": id });
    let new = json!({ "characters": [character("ada"), character("bo"), character("cy")] });
    let (_, view) = server.post("/api/chats", new).await;
    let chat = format!("/api/chats/{}", view["chat"]["id"]);
    let [ada, cy] = [0, 2].map(|at| view["characters"][at]["id"].as_i64().unwrap());
    let place = |one: i64, position: Value| {
        let server = &server;
        async move {
            let path = format!("/api/chat-characters/{one}/position");
            server.put(&path, json!({ "position": position })).await
        }
    };
    // The names of a view's characters, and their places.
    let order = |view: &Value| {
        let cast = view["characters"].as_array().unwrap();
        let named = |one: &Value| {
            (
                one["name"].as_str().unwrap().to_string(),
                one["position"].as_i64().unwrap(),
            )
        };
        cast.iter().map(named).collect::<Vec<_>>()
    };
    let at = |names: [&str; 3]| {
        (0..)
            .zip(names)
            .map(|(at, name)| (name.to_string(), at))
            .collect::<Vec<_>>()
    };
    let (_, set) = server
        .put(&format!("{chat}/turn"), json!({ "order": "list" }))
        .await;
    assert_eq!(set["turn_order"], "list");

    // Moving answers with the chat, its characters in their new order; in turn Cy, moved after Ada, is next.
    let (status, moved) = place(cy, json!(1)).await;
    assert_eq!(status, 200, "{moved}");
    assert_eq!(moved["chat"]["id"], view["chat"]["id"]);
    assert_eq!(order(&moved), at(["Ada", "Cy Vane", "Bo"]));
    assert_eq!(reply(&server, &chat, json!({})).await, cy);
    // The chat read anew has it so.
    let (_, read) = server.get(&chat).await;
    assert_eq!(order(&read), at(["Ada", "Cy Vane", "Bo"]));
    let (_, moved) = place(ada, json!(5)).await;
    assert_eq!(order(&moved), at(["Cy Vane", "Bo", "Ada"]));
    // The list of chats names them in the order they joined.
    let (_, list) = server.get("/api/chats").await;
    assert_eq!(list[0]["names"], json!(["Ada", "Bo", "Cy Vane"]));

    // A chat character that is not there is not found, and what is no place is refused.
    assert_eq!(place(999, json!(0)).await.0, 404);
    let path = format!("/api/chat-characters/{ada}/position");
    for none in [
        json!({}),
        json!({ "position": -1 }),
        json!({ "position": "first" }),
    ] {
        let (status, _) = server.put(&path, none.clone()).await;
        assert!([400, 422].contains(&status), "{none}: {status}");
    }
    let (_, read) = server.get(&chat).await;
    assert_eq!(order(&read), at(["Cy Vane", "Bo", "Ada"]));
}

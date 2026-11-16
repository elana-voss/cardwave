//! Who replies next by the turn order alone (`turn::pick`): the natural order,
//! which follows whom the newest messages name, the list order and the random
//! one, which weighs how talkative each is.
//!
//! `crew` is the three a turn order picks among (Ada, Bo and "Cy Vane", as
//! `Candidate`s); `called` is a cast of other names, numbered from 1 in
//! speaking order, and `names` whom a message of the user names among such a
//! cast, which is the last of them where it names nobody, so a cast there ends
//! with one that is not named. `user` and `by` are what was said. The same in a
//! stored chat and over HTTP: `chat_turn.rs`.

use cw_chat::chats::TurnOrder;
use cw_chat::chats::turn::{Candidate, Said, pick};

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

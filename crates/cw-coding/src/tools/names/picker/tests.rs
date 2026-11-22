//! The picker's rules, each by a test of the extension's `test/product.test.js`
//! (0.3.0) where it holds one; `fixed` is its `fixedRng` (always 0).

use super::*;
use crate::tools::names::answer;
use serde_json::Value;
/// Filters as a case gives them.
type Asked = &'static [(&'static str, &'static [&'static str])];

fn entry(name: &str, change: impl FnOnce(&mut Entry)) -> Entry {
    let text = |all: &[&str]| all.iter().map(|value| value.to_string()).collect();
    let mut entry = Entry {
        name: name.into(),
        gender: Some("female".into()),
        language_ethnicity: "english".into(),
        mythology: None,
        race: Some("human".into()),
        age: text(&["adult"]),
        era: text(&["contemporary"]),
        role: text(&["neutral"]),
        intelligence: Some("average".into()),
        allure: Some("pleasant".into()),
        commonness: Some("uncommon".into()),
        genre: text(&["sliceOfLife"]),
        themes: Vec::new(),
    };
    change(&mut entry);
    entry
}

fn surname(name: &str, change: impl FnOnce(&mut Entry)) -> Entry {
    entry(name, |entry| {
        entry.gender = None;
        entry.intelligence = None;
        entry.age = Vec::new();
        change(entry);
    })
}

fn culture(culture: &str) -> impl FnOnce(&mut Entry) {
    move |entry: &mut Entry| entry.language_ethnicity = culture.into()
}

fn filters(given: &[(&'static str, &[&str])]) -> Filters {
    given
        .iter()
        .map(|(field, values)| (*field, values.iter().map(|v| v.to_string()).collect()))
        .collect()
}

fn names(first_names: Vec<Entry>, last_names: Vec<Entry>) -> Names {
    Names {
        first_names,
        last_names,
    }
}

/// The answer the model reads of a pick with every draw 0, on `used`.
fn pick_on(names: &Names, given: &[(&'static str, &[&str])], used: &mut Used) -> Value {
    let picked = pick(names, &filters(given), used, &mut |_| 0).unwrap();
    serde_json::from_str(&answer::of(&picked)).unwrap()
}

fn fresh(names: &Names, given: &[(&'static str, &[&str])]) -> Value {
    pick_on(names, given, &mut Used::default())
}

/// A random source that draws `shares` of its maximum in turn, then 0.
fn scripted(shares: &[f64]) -> impl FnMut(u64) -> u64 + '_ {
    let mut next = shares.iter();
    move |max| (next.next().copied().unwrap_or(0.0) * max as f64) as u64
}

#[test]
fn matches_gender_and_culture_exactly() {
    let all = names(
        vec![
            entry("Bo", |e| {
                e.gender = Some("male".into());
                e.language_ethnicity = "japanese".into();
            }),
            entry("Alice", |_| {}),
            entry("Hana", culture("japanese")),
        ],
        vec![
            surname("Tanaka", culture("japanese")),
            surname("Smith", |_| {}),
        ],
    );
    let picked = fresh(
        &all,
        &[
            ("gender", &["female"]),
            ("language_ethnicity", &["japanese"]),
        ],
    );
    assert_eq!(picked["first_name"], "Hana");
    assert_eq!(picked["last_name"], "Tanaka");
    assert!(picked.get("relaxed_filters").is_none());
}

#[test]
fn drops_filters_in_their_order_and_names_them() {
    let all = names(
        vec![entry("Mira", |e| {
            e.language_ethnicity = "slavicRussian".into();
            e.role = vec!["villain".into()];
            e.intelligence = Some("bookish".into());
            e.themes = vec!["regal".into()];
        })],
        vec![surname("Volkov", culture("slavicRussian"))],
    );
    let picked = fresh(
        &all,
        &[
            ("gender", &["female"]),
            ("language_ethnicity", &["slavicRussian"]),
            ("age", &["child"]),
            ("era", &["nineteenTwenties"]),
            ("role", &["villain"]),
            ("intelligence", &["bookish"]),
            ("themes", &["celestial"]),
        ],
    );
    assert_eq!(picked["first_name"], "Mira");
    assert_eq!(
        picked["relaxed_filters"],
        serde_json::json!(["themes", "age", "era"])
    );
}

#[test]
fn relaxing_puts_back_every_filter_not_part_of_the_conflict() {
    let all = names(
        vec![
            entry("Hana", |e| {
                e.language_ethnicity = "japanese".into();
                e.commonness = Some("rare".into());
            }),
            entry("Alice", |e| e.commonness = Some("common".into())),
        ],
        vec![
            surname("Generic", culture("japanese")),
            surname("Smith", |_| {}),
        ],
    );
    let picked = fresh(
        &all,
        &[
            ("gender", &["nonbinary"]),
            ("language_ethnicity", &["japanese"]),
            ("commonness", &["rare"]),
        ],
    );
    assert_eq!(picked["first_name"], "Hana");
    assert_eq!(picked["relaxed_filters"], serde_json::json!(["gender"]));
}

#[test]
fn a_filter_as_a_list_matches_any_of_its_values_in_every_kind_of_field() {
    let all = names(
        vec![
            entry("Ann", |e| {
                e.age = vec!["child".into()];
                e.intelligence = Some("plain".into());
                e.genre = vec!["horror".into()];
            }),
            entry("Bob", |e| {
                e.gender = Some("male".into());
                e.age = vec!["elder".into()];
                e.intelligence = Some("bookish".into());
                e.genre = vec!["western".into()];
            }),
        ],
        vec![surname("Generic", |_| {})],
    );
    let cases: [(Asked, &str); 4] = [
        (&[("gender", &["male"])], "Bob"),
        (&[("age", &["elder", "nope"])], "Bob"),
        (&[("intelligence", &["bookish"])], "Bob"),
        (&[("genre", &["western", "nope"])], "Bob"),
    ];
    for (given, name) in cases {
        let picked = fresh(&all, given);
        assert_eq!(picked["first_name"], name, "{given:?}");
        assert!(picked.get("relaxed_filters").is_none());
    }
    let era = names(
        vec![
            entry("Eleanor", |e| {
                e.era = vec!["victorian".into(), "midcentury".into()]
            }),
            entry("Beatrice", |e| e.era = vec!["ancient".into()]),
        ],
        vec![surname("Generic", |_| {})],
    );
    assert_eq!(
        fresh(&era, &[("era", &["midcentury"])])["first_name"],
        "Eleanor"
    );
}

#[test]
fn a_name_comes_back_only_once_every_fitting_name_is_used() {
    let all = names(
        vec![
            entry("Hana", culture("japanese")),
            entry("Yuki", culture("japanese")),
        ],
        vec![surname("Tanaka", culture("japanese"))],
    );
    let mut used = Used::default();
    let japanese: &[(&'static str, &[&str])] = &[("language_ethnicity", &["japanese"])];
    let one = pick_on(&all, japanese, &mut used);
    let two = pick_on(&all, japanese, &mut used);
    assert_ne!(one["first_name"], two["first_name"]);
    assert_eq!(used.first.len(), 2);
    let three = pick_on(&all, japanese, &mut used);
    assert_eq!(used.first.len(), 1);
    assert!(used.first.contains(&format!(
        "japanese/{}",
        three["first_name"].as_str().unwrap()
    )));
}

#[test]
fn a_name_used_in_one_culture_stays_free_in_another() {
    let all = names(
        vec![
            entry("Noah", culture("hebrew")),
            entry("Noah", |_| {}),
            entry("Eli", |_| {}),
        ],
        vec![
            surname("Cohen", culture("hebrew")),
            surname("Cohen", |_| {}),
            surname("Smith", |_| {}),
        ],
    );
    let mut used = Used::default();
    pick_on(&all, &[("language_ethnicity", &["hebrew"])], &mut used);
    let other = pick_on(&all, &[("language_ethnicity", &["english"])], &mut used);
    assert_eq!(other["first_name"], "Noah");
    assert_eq!(other["last_name"], "Cohen");
}

#[test]
fn the_surname_is_of_the_first_names_culture() {
    let all = names(
        vec![entry("Hana", culture("japanese"))],
        vec![
            surname("Tanaka", culture("japanese")),
            surname("Smith", |_| {}),
        ],
    );
    assert_eq!(fresh(&all, &[])["last_name"], "Tanaka");
}

#[test]
fn a_culture_without_surnames_and_a_god_get_a_single_name() {
    let dragon = names(
        vec![entry("Paarthurnax", |e| {
            e.language_ethnicity = "fantasyDragon".into();
            e.race = Some("dragon".into());
        })],
        vec![surname("Smith", |_| {})],
    );
    let picked = fresh(&dragon, &[]);
    assert_eq!(picked["first_name"], "Paarthurnax");
    assert!(picked.get("last_name").is_none() && picked.get("last_name_role").is_none());
    let god = names(
        vec![entry("Shiva", |e| {
            e.language_ethnicity = "hindi".into();
            e.race = Some("mythical".into());
            e.mythology = Some("hindu".into());
        })],
        vec![surname("Sharma", culture("hindi"))],
    );
    let picked = fresh(&god, &[]);
    assert!(picked.get("last_name").is_none());
    assert_eq!(picked["mythology"], "hindu");
}

#[test]
fn the_surname_never_repeats_the_first_name() {
    let all = names(
        vec![entry("Agus", |_| {})],
        vec![surname("Agus", |_| {}), surname("Wijaya", |_| {})],
    );
    assert_eq!(fresh(&all, &[])["last_name"], "Wijaya");
}

#[test]
fn a_surname_of_the_other_gender_is_never_given_but_an_ambiguous_one_takes_any() {
    let male = vec![entry("Piotr", |e| e.gender = Some("male".into()))];
    let kowalska = || surname("Kowalska", |e| e.gender = Some("female".into()));
    let both = names(male.clone(), vec![kowalska(), surname("Wojcik", |_| {})]);
    assert_eq!(fresh(&both, &[])["last_name"], "Wojcik");
    assert!(
        fresh(&names(male, vec![kowalska()]), &[])
            .get("last_name")
            .is_none()
    );
    let sasha = names(
        vec![entry("Sasha", |e| e.gender = Some("ambiguous".into()))],
        vec![kowalska()],
    );
    assert_eq!(fresh(&sasha, &[])["last_name"], "Kowalska");
}

#[test]
fn a_genre_makes_fitting_names_likelier_and_leaves_none_out() {
    // T unused names carrying it take a pick with chance T/20.
    let plain: Vec<Entry> = (0..5).map(|i| entry(&format!("P{i}"), |_| {})).collect();
    let tagged = |n: usize| -> Vec<Entry> {
        (0..n)
            .map(|i| entry(&format!("H{i}"), |e| e.genre = vec!["horror".into()]))
            .collect()
    };
    let at = |count: usize, chance: f64, used: &mut Used| {
        let all = names(
            [plain.clone(), tagged(count)].concat(),
            vec![surname("Generic", |_| {})],
        );
        let picked = pick(
            &all,
            &filters(&[("genre", &["horror"])]),
            used,
            &mut scripted(&[chance, 0.0]),
        )
        .unwrap();
        assert!(picked.relaxed.is_empty());
        picked.first.name.clone()
    };
    assert_eq!(at(3, 0.14, &mut Used::default()), "H0");
    assert_eq!(at(3, 0.16, &mut Used::default()), "P0");
    assert_eq!(at(20, 0.999, &mut Used::default()), "H0");
    assert_eq!(at(0, 0.0, &mut Used::default()), "P0");
    let mut used = Used::default();
    used.first
        .extend(["english/H0".to_string(), "english/H1".to_string()]);
    assert_eq!(
        at(3, 0.06, &mut used),
        "P0",
        "one unused horror name: chance 0.05"
    );
    // Nor does a genre make another filter drop.
    let ann = names(
        vec![
            entry("Ann", |e| {
                e.age = vec!["child".into()];
                e.genre = vec!["horror".into()];
            }),
            entry("Bea", |_| {}),
        ],
        vec![surname("Generic", |_| {})],
    );
    let picked = fresh(&ann, &[("age", &["adult"]), ("genre", &["horror"])]);
    assert_eq!(picked["first_name"], "Bea");
    assert!(picked.get("relaxed_filters").is_none());
}

/// The share in percent of each class (common, uncommon, rare) over 2000
/// evenly spread draws, each on the used names `used` gives.
fn shares(all: &[Entry], given: &[(&'static str, &[&str])], used: impl Fn() -> Used) -> [i64; 3] {
    let all = names(all.to_vec(), vec![surname("Generic", |_| {})]);
    let draws = 2000;
    let mut count = [0; 3];
    for k in 0..draws {
        let mut draw = |max: u64| (k as f64 / draws as f64 * max as f64) as u64;
        let picked = pick(&all, &filters(given), &mut used(), &mut draw).unwrap();
        count[class_of(picked.first)] += 1;
    }
    count.map(|n| (100.0 * n as f64 / draws as f64).round() as i64)
}

fn classes(common: usize, uncommon: usize, rare: usize) -> Vec<Entry> {
    [("common", common), ("uncommon", uncommon), ("rare", rare)]
        .into_iter()
        .flat_map(|(class, n)| {
            (0..n).map(move |i| {
                entry(&format!("{class}{i}"), |e| {
                    e.commonness = Some(class.into())
                })
            })
        })
        .collect()
}

#[test]
fn the_pick_leans_to_common_names_unless_a_commonness_is_asked() {
    let common = |all: Vec<Entry>| shares(&all, &[], Used::default)[0];
    assert_eq!(common(classes(10, 10, 10)), 70);
    assert_eq!(common(classes(10, 5, 20)), 70);
    assert_eq!(common(classes(8, 1, 1)), 80);
    assert_eq!(
        common(classes(1, 0, 20)),
        (100.0 * 16.0 / 36.0_f64).round() as i64
    );
    assert_eq!(
        common(classes(1, 20, 0)),
        (100.0 * 4.0 / 24.0_f64).round() as i64
    );
    // Set from the unused names: an uncommon one 4x a rare one once the common are used.
    let all = classes(10, 10, 10);
    let common_used = || Used {
        first: (0..10).map(|i| format!("english/common{i}")).collect(),
        last: Default::default(),
    };
    assert_eq!(shares(&all, &[], common_used), [0, 80, 20]);
    // A commonness asked for keeps the pick even.
    let asked = shares(
        &classes(1, 0, 19),
        &[("commonness", &["common", "rare"])],
        Used::default,
    );
    assert_eq!(asked[0], 5);
}

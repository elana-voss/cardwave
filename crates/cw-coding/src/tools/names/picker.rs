//! The pick, as the extension's `picker.js` makes it: the filters (dropped in
//! `drop_order` while no first name fits them, each put back that was not part
//! of the conflict, and named as relaxed), the used names of the chat (a name
//! comes back only once every name fitting the request is used), a first name
//! leaning to names of the story's genre (never a filter) and to common names
//! (`lean_pick`), and a surname of the first name's culture: none for a god or
//! a culture without surnames, of the first name's gender or none, never the
//! first name itself.
//!
//! The random source is `rng(max)`, a number below `max`, called in the
//! extension's order (the genre's chance first, then the pick), so its tests
//! port as they are.

use std::collections::{BTreeMap, HashSet};

use anyhow::bail;

use super::database::{Entry, Names, TAGS, drop_order};

/// The filters asked for, each tag with the values wanted; the genre among them.
pub(crate) type Filters = BTreeMap<&'static str, Vec<String>>;

/// A random number below its argument.
pub(crate) type Rng<'a> = &'a mut dyn FnMut(u64) -> u64;

/// T unused names carrying the genre take a pick with chance min(1, T / GENRE_FULL).
const GENRE_FULL: f64 = 20.0;
/// Common names come this share of the picks, whatever the list's sizes (`lean_for`).
const COMMON_TARGET: f64 = 0.7;
const MAX_LEAN: f64 = 4.0;
/// A draw of a share from 0 to 1.
const DRAW: u64 = 1 << 32;

/// The names a chat used, as "culture/name".
#[derive(Debug, Default, Clone, PartialEq)]
pub(crate) struct Used {
    pub first: HashSet<String>,
    pub last: HashSet<String>,
}

/// A pick: the first name, the surname where one is given, and the filters dropped.
pub(crate) struct Picked<'a> {
    pub first: &'a Entry,
    pub last: Option<&'a Entry>,
    pub relaxed: Vec<&'static str>,
}

/// Picks a name of `names` for `filters`, keeping it among `used`.
pub(crate) fn pick<'a>(
    names: &'a Names,
    filters: &Filters,
    used: &mut Used,
    rng: Rng<'_>,
) -> anyhow::Result<Picked<'a>> {
    if names.first_names.is_empty() {
        bail!("the names database is empty");
    }
    let (current, relaxed) = relax(&names.first_names, filters);
    let candidates = fitting(&names.first_names, &current);
    if candidates.is_empty() {
        bail!("no first name fits, even with every filter dropped");
    }
    // A commonness asked for decides alone: among the names it allows the pick stays even.
    let lean = !current.contains_key("commonness");
    let first = pick_unused(
        &candidates,
        &mut used.first,
        rng,
        lean,
        current.get("genre"),
    );
    let surnames: Vec<&Entry> = match first.race.as_deref() {
        Some("mythical") => Vec::new(),
        _ => names
            .last_names
            .iter()
            .filter(|surname| {
                surname.language_ethnicity == first.language_ethnicity
                    && surname.name != first.name
                    && (surname.gender.as_deref().is_none_or(str::is_empty)
                        || first.gender.as_deref() == Some("ambiguous")
                        || surname.gender == first.gender)
            })
            .collect(),
    };
    let last =
        (!surnames.is_empty()).then(|| pick_unused(&surnames, &mut used.last, rng, false, None));
    Ok(Picked {
        first,
        last,
        relaxed,
    })
}

/// The first names that fit `filters`; the genre is no filter.
fn fitting<'a>(names: &'a [Entry], filters: &Filters) -> Vec<&'a Entry> {
    names
        .iter()
        .filter(|entry| fits_all(entry, filters))
        .collect()
}

/// Whether `entry` fits every filter of `filters` but the genre.
fn fits_all(entry: &Entry, filters: &Filters) -> bool {
    TAGS.iter()
        .filter(|tag| tag.drop_rank.is_some())
        .all(|tag| {
            filters
                .get(tag.name)
                .is_none_or(|wanted| entry.fits(tag.name, wanted))
        })
}

/// Drops filters in `drop_order` until a name fits, then puts back every
/// dropped one that was not part of the conflict, the most important first.
fn relax(names: &[Entry], filters: &Filters) -> (Filters, Vec<&'static str>) {
    let fits = |filters: &Filters| names.iter().any(|entry| fits_all(entry, filters));
    let mut current = filters.clone();
    let mut dropped = Vec::new();
    for field in drop_order() {
        if fits(&current) {
            break;
        }
        if current.remove(field).is_some() {
            dropped.push(field);
        }
    }
    for field in dropped.clone().into_iter().rev() {
        let mut trial = current.clone();
        trial.insert(field, filters[field].clone());
        if fits(&trial) {
            current = trial;
            dropped.retain(|kept| *kept != field);
        }
    }
    (current, dropped)
}

/// A name of `candidates` not yet among `used`, kept there; once all are used,
/// they are free again. With `genre`, names carrying it are preferred as
/// `GENRE_FULL` says; with `lean`, common names (`lean_pick`).
fn pick_unused<'a>(
    candidates: &[&'a Entry],
    used: &mut HashSet<String>,
    rng: Rng<'_>,
    lean: bool,
    genre: Option<&Vec<String>>,
) -> &'a Entry {
    let mut unused: Vec<&Entry> = candidates
        .iter()
        .copied()
        .filter(|entry| !used.contains(&entry.key()))
        .collect();
    if unused.is_empty() {
        for entry in candidates {
            used.remove(&entry.key());
        }
        unused = candidates.to_vec();
    }
    if let Some(genre) = genre {
        // The chance is drawn first, even where no name carries the genre.
        let chance = rng(DRAW) as f64 / DRAW as f64;
        let carrying: Vec<&Entry> = unused
            .iter()
            .copied()
            .filter(|entry| entry.fits("genre", genre))
            .collect();
        if chance < carrying.len() as f64 / GENRE_FULL {
            unused = carrying;
        }
    }
    let picked = match lean {
        true => lean_pick(&unused, rng),
        false => unused[rng(unused.len() as u64) as usize],
    };
    used.insert(picked.key());
    picked
}

/// The class of a name: 0 common, 1 uncommon, 2 rare or none.
fn class_of(entry: &Entry) -> usize {
    match entry.commonness.as_deref() {
        Some("common") => 0,
        Some("uncommon") => 1,
        _ => 2,
    }
}

/// The weight x at which common names make `COMMON_TARGET` of the picks, a
/// common name weighing x², an uncommon one x, a rare one 1: never under 1
/// (a less usual name is never likelier) nor over `MAX_LEAN`.
fn lean_for([common, uncommon, rare]: [usize; 3]) -> f64 {
    let (c, u, r) = (common as f64, uncommon as f64, rare as f64);
    if common == 0 {
        return MAX_LEAN;
    }
    if uncommon + rare == 0 {
        return 1.0;
    }
    let a = (1.0 - COMMON_TARGET) * c;
    let t = COMMON_TARGET;
    let x = (t * u + ((t * u).powi(2) + 4.0 * a * t * r).sqrt()) / (2.0 * a);
    x.clamp(1.0, MAX_LEAN)
}

/// A name of `unused`, common ones weighed as `lean_for` says.
fn lean_pick<'a>(unused: &[&'a Entry], rng: Rng<'_>) -> &'a Entry {
    let mut sizes = [0; 3];
    for entry in unused {
        sizes[class_of(entry)] += 1;
    }
    let x = lean_for(sizes);
    if x == 1.0 {
        return unused[rng(unused.len() as u64) as usize];
    }
    let weight = [x * x, x, 1.0];
    let total: f64 = (0..3)
        .map(|class| sizes[class] as f64 * weight[class])
        .sum();
    let mut ticket = rng(DRAW) as f64 / DRAW as f64 * total;
    for entry in unused {
        ticket -= weight[class_of(entry)];
        if ticket < 0.0 {
            return entry;
        }
    }
    // Rounding left the ticket at the very end.
    unused[unused.len() - 1]
}

#[cfg(test)]
mod tests;

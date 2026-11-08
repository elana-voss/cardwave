//! The dice a chat's model rolls (`dice(count, sides)`, the owner,
//! 2026-10-23): the server rolls, so the model cannot pick its own number.
//! It is offered in every chat reply while Settings › Tools › Dice is on (off
//! at first, the owner, 2026-10-23), and as its arguments are two numbers it
//! leaves the Reply length sent (`cuts`).
//!
//! A model may send a number as text ("2") or with a point ("2.0"); it is taken. At most `MOST_COUNT`
//! dice of at most `MOST_SIDES` sides; what is out of range is told the model.

use anyhow::{Context, ensure};
use serde_json::{Value, json};

/// The tool's name.
pub const NAME: &str = "dice";

/// The most dice a roll throws, and the most sides a die has.
const MOST_COUNT: u64 = 100;
const MOST_SIDES: u64 = 1_000;

/// The tool as the model is told of it.
pub(crate) fn definition() -> Value {
    crate::tools::tool(
        NAME,
        "Rolls dice: `count` dice of `sides` sides each, as 2d10 is count 2 and sides 10. Gives each die and the total. Roll with it whenever a story or game asks for chance; never make a roll up.",
        json!({
            "count": { "type": "integer", "description": "How many dice, from 1 to 100" },
            "sides": { "type": "integer", "description": "The sides of each die, from 2 to 1000" },
        }),
    )
}

/// Whether a request offered `definitions` is sent no Reply length: where
/// any tool but the dice is offered, whose call's arguments a limit could cut.
pub fn cuts(definitions: &[Value]) -> bool {
    definitions
        .iter()
        .any(|definition| definition["function"]["name"] != NAME)
}

/// The roll `arguments` ask for, each die from `die(sides)` (1 to `sides`),
/// as the model reads it: "2d10: 7 + 3 = 10", one die "1d20: 14".
pub fn roll(arguments: &str, mut die: impl FnMut(u64) -> u64) -> anyhow::Result<String> {
    let arguments: Value = serde_json::from_str(arguments).context("the arguments are no JSON")?;
    let count = number(&arguments, "count")?;
    let sides = number(&arguments, "sides")?;
    ensure!(
        (1..=MOST_COUNT).contains(&count),
        "count is to be from 1 to {MOST_COUNT}"
    );
    ensure!(
        (2..=MOST_SIDES).contains(&sides),
        "sides is to be from 2 to {MOST_SIDES}"
    );
    let dice: Vec<u64> = (0..count).map(|_| die(sides)).collect();
    let shown: Vec<String> = dice.iter().map(u64::to_string).collect();
    Ok(match dice.len() {
        1 => format!("{count}d{sides}: {}", dice[0]),
        _ => format!(
            "{count}d{sides}: {} = {}",
            shown.join(" + "),
            dice.iter().sum::<u64>()
        ),
    })
}

/// A die of `sides` sides, thrown.
pub(crate) fn throw(sides: u64) -> u64 {
    rand::random_range(1..=sides)
}

/// The whole number `name` of `arguments`, given as a number or as text.
fn number(arguments: &Value, name: &str) -> anyhow::Result<u64> {
    let given = &arguments[name];
    given
        .as_u64()
        .or_else(|| given.as_str().and_then(|text| text.trim().parse().ok()))
        .or_else(|| {
            let whole = given.as_f64().filter(|n| *n >= 0.0 && n.fract() == 0.0)?;
            (whole <= u64::MAX as f64).then_some(whole as u64)
        })
        .with_context(|| format!("{name} is to be a whole number"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_roll_gives_each_die_and_the_total() {
        let mut thrown = [7, 3].into_iter();
        let said = roll(r#"{"count":2,"sides":10}"#, |sides| {
            assert_eq!(sides, 10);
            thrown.next().unwrap()
        });
        assert_eq!(said.unwrap(), "2d10: 7 + 3 = 10");
        assert_eq!(
            roll(r#"{"count":"1","sides":" 20"}"#, |_| 14).unwrap(),
            "1d20: 14"
        );
        assert_eq!(
            roll(r#"{"count":1.0,"sides":20.0}"#, |_| 5).unwrap(),
            "1d20: 5"
        );
    }

    #[test]
    fn a_roll_out_of_range_is_told() {
        for (arguments, said) in [
            (r#"{"count":0,"sides":6}"#, "count is to be from 1 to 100"),
            (r#"{"count":101,"sides":6}"#, "count is to be from 1 to 100"),
            (r#"{"count":1,"sides":1}"#, "sides is to be from 2 to 1000"),
            (
                r#"{"count":1.5,"sides":6}"#,
                "count is to be a whole number",
            ),
            (r#"{"count":-1,"sides":6}"#, "count is to be a whole number"),
            (r#"{"count":1}"#, "sides is to be a whole number"),
        ] {
            let failure = roll(arguments, |_| 1).unwrap_err();
            assert_eq!(failure.to_string(), said, "{arguments}");
        }
    }

    #[test]
    fn a_die_falls_on_one_of_its_sides() {
        let thrown: Vec<u64> = (0..200).map(|_| throw(6)).collect();
        assert!(thrown.iter().all(|die| (1..=6).contains(die)));
        assert!(thrown.contains(&1) && thrown.contains(&6));
    }

    #[test]
    fn the_dice_alone_cut_nothing() {
        let other = crate::tools::tool("web_search", "", json!({}));
        assert!(!cuts(&[definition()]));
        assert!(!cuts(&[]));
        assert!(cuts(&[definition(), other]));
    }
}

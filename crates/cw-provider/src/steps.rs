//! How much a model thinks: the steps Off, Light, Normal and Deep ([`Step`]), how
//! a model's thinking stands ([`Thinking`], kept per model at its provider), what
//! a request carries for it ([`sent`]) and what the page offers ([`offer`], [`view`]).
//!
//! A provider the app knows by address has a table of its own documented values
//! per step (`own.toml`'s `[provider.steps]`, [`Table`]); every step is sent,
//! Normal too, as a provider's own default is not its middle. A model offers the
//! steps where its provider has a table with levels and the model thinks: the
//! levels its provider's list says it takes (OpenRouter's `supported_efforts`,
//! all three where it does not say), Off only where it can stop (not OpenRouter's
//! `mandatory`, not a `cannot_stop` model) and its provider did not refuse it.
//! A level kept while the model shows the switch is not sent: the switch is on.
//! Any other model keeps the switch, whose Off is found by trying the known forms
//! ([`NoThinking`], `check::thinking_off`). An Off, the table's too, is tried once
//! before it is kept: a provider refusing it marks the model as one that cannot.
//!
//! Trap: no level is found by trying: a provider answers 200 to a field it
//! ignores, and a Deep try would cost a full deep answer.

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::collections::BTreeMap;
use ts_rs::TS;

use crate::{Provider, facts, list};

/// How much a model thinks, as the user sets it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "lowercase")]
#[ts(export, rename = "ThinkingStep")] // cw-coding's `Step` is the page's `Step`.
pub enum Step {
    Off,
    Light,
    Normal,
    Deep,
}

impl Step {
    /// Every step, least first.
    pub const ALL: [Step; 4] = [Step::Off, Step::Light, Step::Normal, Step::Deep];

    pub fn as_str(self) -> &'static str {
        match self {
            Step::Off => "off",
            Step::Light => "light",
            Step::Normal => "normal",
            Step::Deep => "deep",
        }
    }
}

/// A form by which a provider not on the list is told not to think, tried in turn.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NoThinking {
    /// OpenAI's `"reasoning_effort": "none"`.
    ReasoningEffort,
    /// OpenRouter's `"reasoning": {"enabled": false}`.
    Reasoning,
    /// Qwen's `"enable_thinking": false`.
    EnableThinking,
    /// DeepSeek's and Anthropic's `"thinking": {"type": "disabled"}`.
    ThinkingDisabled,
}

impl NoThinking {
    /// Every form, in the order they are tried.
    pub const ALL: [NoThinking; 4] = [
        NoThinking::ReasoningEffort,
        NoThinking::Reasoning,
        NoThinking::EnableThinking,
        NoThinking::ThinkingDisabled,
    ];

    /// As the table keeps it.
    fn kept(self) -> &'static str {
        match self {
            NoThinking::ReasoningEffort => "reasoning_effort",
            NoThinking::Reasoning => "reasoning",
            NoThinking::EnableThinking => "enable_thinking",
            NoThinking::ThinkingDisabled => "thinking_disabled",
        }
    }

    /// The field of the request's body and its value.
    fn sent(self) -> (&'static str, Value) {
        match self {
            NoThinking::ReasoningEffort => ("reasoning_effort", "none".into()),
            NoThinking::Reasoning => ("reasoning", json!({ "enabled": false })),
            NoThinking::EnableThinking => ("enable_thinking", false.into()),
            NoThinking::ThinkingDisabled => ("thinking", json!({ "type": "disabled" })),
        }
    }
}

/// How a model's thinking stands.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Thinking {
    /// Nothing set: a model offering steps is at Normal, any other thinks as its provider's default.
    #[default]
    On,
    /// A step of its provider's table; Off is the table's documented Off, which the provider took.
    Step(Step),
    /// Off by the form the provider took, of a provider without a documented Off.
    OffBy(NoThinking),
    /// The user turned it off and the provider took no form of it; with the
    /// level chosen since, where the model offers steps (never Off).
    Cannot(Option<Step>),
}

impl Thinking {
    /// As the table keeps it.
    pub fn kept(self) -> &'static str {
        match self {
            Thinking::On => "",
            Thinking::Step(step) => step.as_str(),
            Thinking::OffBy(form) => form.kept(),
            Thinking::Cannot(None | Some(Step::Off)) => "cannot",
            Thinking::Cannot(Some(Step::Light)) => "cannot light",
            Thinking::Cannot(Some(Step::Normal)) => "cannot normal",
            Thinking::Cannot(Some(Step::Deep)) => "cannot deep",
        }
    }

    /// The level `step` set by the user, a refused Off still known.
    pub fn level(self, step: Step) -> Thinking {
        match self {
            Thinking::Cannot(_) => Thinking::Cannot(Some(step)),
            _ => Thinking::Step(step),
        }
    }

    /// Read back from the table; what is not known is on.
    pub fn read(text: &str) -> Thinking {
        let steps = Step::ALL.map(Thinking::Step);
        let forms = NoThinking::ALL.map(Thinking::OffBy);
        steps
            .into_iter()
            .chain(forms)
            .chain(
                [
                    None,
                    Some(Step::Light),
                    Some(Step::Normal),
                    Some(Step::Deep),
                ]
                .map(Thinking::Cannot),
            )
            .find(|thinking| thinking.kept() == text)
            .unwrap_or(Thinking::On)
    }

    /// Whether the model is told not to think.
    pub fn off(self) -> bool {
        matches!(self, Thinking::Step(Step::Off) | Thinking::OffBy(_))
    }
}

/// What a provider's list of models says of a model's thinking (OpenRouter's), kept with the model.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Listed {
    /// Whether it thinks; none where the list does not say.
    pub thinks: Option<bool>,
    /// Whether it cannot stop thinking (OpenRouter's `reasoning.mandatory`).
    pub mandatory: bool,
    /// The provider's levels of effort it takes (OpenRouter's `reasoning.supported_efforts`); none where the
    /// list does not say.
    pub efforts: Option<Vec<String>>,
}

/// A provider's documented values per step (`own.toml`'s `[provider.steps]`):
/// each a table of fields merged into a request's body.
#[derive(Clone, Debug, Default, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Table {
    off: Option<Map<String, Value>>,
    light: Option<Map<String, Value>>,
    normal: Option<Map<String, Value>>,
    deep: Option<Map<String, Value>>,
    /// Parts of the IDs of its models that cannot stop thinking.
    #[serde(default)]
    cannot_stop: Vec<String>,
    /// Parts of the IDs of its models that take only some levels, with those
    /// levels in the provider's words, as a list of models would name them.
    #[serde(default)]
    only: BTreeMap<String, Vec<String>>,
}

impl Table {
    /// The fields sent for `step`, where the table has them.
    fn of(&self, step: Step) -> Option<&Map<String, Value>> {
        match step {
            Step::Off => self.off.as_ref(),
            Step::Light => self.light.as_ref(),
            Step::Normal => self.normal.as_ref(),
            Step::Deep => self.deep.as_ref(),
        }
    }

    /// Whether it has Light, Normal and Deep; one with only an Off keeps the switch.
    pub(crate) fn levels(&self) -> bool {
        self.light.is_some() && self.normal.is_some() && self.deep.is_some()
    }

    /// The provider's own name of the level sent for `step` (OpenRouter's `reasoning.effort`): the one word
    /// among its fields, as a list of models names the levels a model takes; none for a budget in tokens.
    fn effort(&self, step: Step) -> Option<&str> {
        fn word(value: &Value) -> Option<&str> {
            match value {
                Value::String(word) => Some(word),
                Value::Object(fields) => fields.values().find_map(word),
                _ => None,
            }
        }
        self.of(step)?.values().find_map(word)
    }

    /// Whether it has some level but not all three (a mistake of the list).
    #[cfg(test)]
    pub(crate) fn partial(&self) -> bool {
        !self.levels() && (self.light.is_some() || self.normal.is_some() || self.deep.is_some())
    }
}

/// What the page offers for a model's thinking.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Offer {
    /// The steps, least first: the levels the model takes, Off before them where it can stop thinking
    /// and its provider did not refuse it.
    Steps(Vec<Step>),
    /// On and off.
    Switch,
}

impl Offer {
    /// The step a model offering steps is at when none is set: Normal, else the nearest level it takes.
    fn unset(steps: &[Step]) -> Step {
        [Step::Normal, Step::Light, Step::Deep]
            .into_iter()
            .find(|step| steps.contains(step))
            .unwrap_or(Step::Normal)
    }

    /// `thinking` as it stands for a model offering this: a kept step, or a
    /// found Off, the model still offers; else the step it is at when none is
    /// set. Under the switch a kept level is on, as the switch shows it.
    fn within(&self, thinking: Thinking) -> Thinking {
        let Offer::Steps(steps) = self else {
            return match thinking {
                Thinking::Step(step) if step != Step::Off => Thinking::On,
                _ => thinking,
            };
        };
        match thinking {
            Thinking::Step(step) | Thinking::Cannot(Some(step)) if steps.contains(&step) => {
                Thinking::Step(step)
            }
            Thinking::OffBy(_) if steps.contains(&Step::Off) => thinking,
            _ => Thinking::Step(Offer::unset(steps)),
        }
    }
}

/// Whether `provider`'s model thinks: seen to, else as its provider's list says, else by its name.
pub(crate) fn model_thinks(provider: &Provider) -> bool {
    provider.seen_thinking
        || provider
            .listed
            .thinks
            .unwrap_or_else(|| facts::guessed(&provider.model).thinks)
}

/// What `provider`'s model offers: the steps where its provider's table has
/// levels, the model thinks and takes one of them, else the switch. Off is
/// left out where the model cannot stop or its provider refused the Off.
pub fn offer(provider: &Provider) -> Offer {
    let Some(table) = list::steps(&provider.base_url).filter(|table| table.levels()) else {
        return Offer::Switch;
    };
    if !model_thinks(provider) {
        return Offer::Switch;
    }
    let model = provider.model.to_lowercase();
    let stops = !matches!(provider.thinking, Thinking::Cannot(_))
        && !provider.listed.mandatory
        && !table
            .cannot_stop
            .iter()
            .any(|part| model.contains(part.as_str()));
    let only = table
        .only
        .iter()
        .find(|(part, _)| model.contains(part.as_str()))
        .map(|(_, efforts)| efforts);
    let efforts = provider.listed.efforts.as_ref().or(only);
    let takes = |step: &Step| match (efforts, table.effort(*step)) {
        (Some(efforts), Some(effort)) => efforts.iter().any(|listed| listed == effort),
        _ => true,
    };
    let levels: Vec<Step> = [Step::Light, Step::Normal, Step::Deep]
        .into_iter()
        .filter(takes)
        .collect();
    if levels.is_empty() {
        return Offer::Switch;
    }
    Offer::Steps(
        stops
            .then_some(Step::Off)
            .into_iter()
            .chain(levels)
            .collect(),
    )
}

/// The fields a request to `provider` carries for its thinking: its step's,
/// Normal where none is set, its form of Off; none for a switch that is on.
pub(crate) fn sent(provider: &Provider) -> Vec<(String, Value)> {
    let table = list::steps(&provider.base_url);
    let fields = |step: Step| {
        table
            .and_then(|table| table.of(step))
            .map(|fields| fields.clone().into_iter().collect())
            .unwrap_or_default()
    };
    match offer(provider).within(provider.thinking) {
        Thinking::OffBy(form) => {
            let (name, value) = form.sent();
            vec![(name.to_string(), value)]
        }
        Thinking::Step(step) => fields(step),
        Thinking::On | Thinking::Cannot(_) => Vec::new(),
    }
}

/// The ways of turning `provider`'s thinking off that are tried, in turn: its
/// table's documented Off, else every known form.
pub(crate) fn offs(provider: &Provider) -> Vec<Thinking> {
    match list::steps(&provider.base_url).and_then(|table| table.off.as_ref()) {
        Some(_) => vec![Thinking::Step(Step::Off)],
        None => NoThinking::ALL.map(Thinking::OffBy).into(),
    }
}

/// A model's thinking as the page shows it.
#[derive(Debug, PartialEq, Serialize, TS)]
#[serde(tag = "control", rename_all = "lowercase")]
#[ts(export)]
pub enum ThinkingView {
    /// The steps the model offers, least first (Off only where it can stop),
    /// the one it is at, and whether its provider refused the Off the user chose.
    Steps {
        steps: Vec<Step>,
        step: Step,
        refused: bool,
    },
    /// "on", "off", or "cannot" where the provider took no form of turning it off.
    Switch { state: String },
}

/// How `provider`'s thinking is shown.
pub fn view(provider: &Provider) -> ThinkingView {
    let offer = offer(provider);
    let thinking = offer.within(provider.thinking);
    match offer {
        Offer::Steps(steps) => ThinkingView::Steps {
            step: match thinking {
                Thinking::Step(step) => step,
                _ => Step::Off,
            },
            steps,
            refused: matches!(provider.thinking, Thinking::Cannot(_)),
        },
        Offer::Switch => ThinkingView::Switch {
            state: match thinking {
                Thinking::Cannot(_) => "cannot",
                thinking if thinking.off() => "off",
                _ => "on",
            }
            .to_string(),
        },
    }
}

/// How the user sets a model's thinking: a step where the model offers them, else the switch.
#[derive(Clone, Copy, Debug, Deserialize, TS)]
#[serde(untagged)]
#[ts(export)]
pub enum SetThinking {
    Step { step: Step },
    Switch { on: bool },
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A thinking `model` at `base_url`, set to `thinking`.
    fn at(base_url: &str, model: &str, thinking: Thinking) -> Provider {
        let mut provider = Provider::new(base_url, "", model);
        provider.listed.thinks = Some(true);
        provider.thinking = thinking;
        provider
    }

    /// The fields sent for each of Off, Light, Normal, Deep, and for nothing set.
    fn each(base_url: &str, model: &str) -> Vec<Value> {
        let mut thinkings: Vec<Thinking> = Step::ALL.map(Thinking::Step).into();
        thinkings.push(Thinking::On);
        thinkings
            .into_iter()
            .map(|thinking| {
                Value::Object(sent(&at(base_url, model, thinking)).into_iter().collect())
            })
            .collect()
    }

    #[test]
    fn each_known_provider_is_sent_its_documented_value_per_step() {
        let effort = |off: &str, light: &str, normal: &str, deep: &str| {
            [off, light, normal, deep, normal].map(|value| json!({ "reasoning_effort": value }))
        };
        let openai = effort("none", "low", "medium", "high");
        assert_eq!(each("https://api.openai.com/v1", "gpt-5"), openai);
        let gemini = "https://generativelanguage.googleapis.com/v1beta/openai";
        assert_eq!(each(gemini, "gemini-2.5-flash"), openai);
        let router = ["none", "low", "medium", "high", "medium"]
            .map(|value| json!({ "reasoning": { "effort": value } }));
        assert_eq!(each("https://openrouter.ai/api/v1", "openai/gpt-5"), router);
        let mut deepseek = effort("", "low", "high", "max").to_vec();
        deepseek[0] = json!({ "thinking": { "type": "disabled" } });
        assert_eq!(
            each("https://api.deepseek.com/v1", "deepseek-chat"),
            deepseek
        );
        let budget = |tokens: u64| json!({ "enable_thinking": true, "thinking_budget": tokens });
        let qwen = [
            json!({ "enable_thinking": false }),
            budget(4096),
            budget(16384),
            json!({ "enable_thinking": true }),
            budget(16384),
        ];
        let dashscope = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
        assert_eq!(each(dashscope, "qwen3-max"), qwen);
        let china = "https://dashscope.aliyuncs.com/compatible-mode/v1";
        assert_eq!(each(china, "qwen3-8b"), qwen);
    }

    #[test]
    fn a_kept_step_the_model_no_longer_offers_is_neither_sent_nor_shown() {
        let router = "https://openrouter.ai/api/v1";
        let mut off = at(router, "x/model", Thinking::Step(Step::Off));
        off.listed.mandatory = true;
        let mut deep = at(router, "x/model", Thinking::Step(Step::Deep));
        deep.listed.efforts = Some(vec!["low".into(), "medium".into()]);
        for provider in [&off, &deep] {
            assert_eq!(
                sent(provider),
                [("reasoning".to_string(), json!({ "effort": "medium" }))]
            );
            let ThinkingView::Steps { steps, step, .. } = view(provider) else {
                panic!("{provider:?}");
            };
            assert!(steps.contains(&step), "{step:?} of {steps:?}");
        }
    }

    #[test]
    fn an_off_the_provider_refused_is_not_offered_again() {
        let refused = at(
            "https://api.openai.com/v1",
            "gpt-5.1",
            Thinking::Cannot(None),
        );
        let levels = vec![Step::Light, Step::Normal, Step::Deep];
        assert_eq!(offer(&refused), Offer::Steps(levels.clone()));
        assert_eq!(
            view(&refused),
            ThinkingView::Steps {
                steps: levels,
                step: Step::Normal,
                refused: true,
            }
        );
        assert_eq!(
            sent(&refused),
            [("reasoning_effort".to_string(), json!("medium"))]
        );
    }

    #[test]
    fn a_refused_off_stays_known_when_a_level_is_set_after_it() {
        let refused = Thinking::Cannot(None);
        let light = at(
            "https://api.openai.com/v1",
            "gpt-5.1",
            refused.level(Step::Light),
        );
        let levels = vec![Step::Light, Step::Normal, Step::Deep];
        assert_eq!(offer(&light), Offer::Steps(levels.clone()));
        assert_eq!(
            view(&light),
            ThinkingView::Steps {
                steps: levels,
                step: Step::Light,
                refused: true,
            }
        );
        assert_eq!(
            sent(&light),
            [("reasoning_effort".to_string(), json!("low"))]
        );
        assert_eq!(Thinking::On.level(Step::Deep), Thinking::Step(Step::Deep));
    }

    #[test]
    fn a_kept_level_is_not_sent_while_the_model_shows_the_switch() {
        let mut deep = at(
            "https://api.deepseek.com/v1",
            "deepseek-chat",
            Thinking::Step(Step::Deep),
        );
        deep.listed.thinks = Some(false);
        assert_eq!(offer(&deep), Offer::Switch);
        assert_eq!(sent(&deep), []);
        assert_eq!(
            view(&deep),
            ThinkingView::Switch {
                state: "on".to_string()
            }
        );
    }

    #[test]
    fn an_openai_pro_model_offers_only_what_it_takes() {
        let pro = at(
            "https://api.openai.com/v1",
            "gpt-5.5-pro",
            Thinking::Step(Step::Light),
        );
        assert_eq!(offer(&pro), Offer::Steps(vec![Step::Normal, Step::Deep]));
        assert_eq!(
            sent(&pro),
            [("reasoning_effort".to_string(), json!("medium"))]
        );
    }

    #[test]
    fn a_provider_without_levels_keeps_the_switch_and_its_off() {
        let anthropic = at(
            "https://api.anthropic.com/v1",
            "claude-sonnet-4-5",
            Thinking::On,
        );
        assert_eq!(offer(&anthropic), Offer::Switch);
        assert!(sent(&anthropic).is_empty());
        assert_eq!(offs(&anthropic), [Thinking::Step(Step::Off)]);
        let off = at(
            "https://api.anthropic.com/v1",
            "claude-sonnet-4-5",
            Thinking::Step(Step::Off),
        );
        assert_eq!(
            sent(&off),
            [("thinking".to_string(), json!({ "type": "disabled" }))]
        );
        assert_eq!(
            view(&off),
            ThinkingView::Switch {
                state: "off".into()
            }
        );

        let elsewhere = at("http://localhost:1234/v1", "qwen3", Thinking::On);
        assert_eq!(offer(&elsewhere), Offer::Switch);
        assert!(sent(&elsewhere).is_empty());
        assert_eq!(offs(&elsewhere).len(), NoThinking::ALL.len());
        let off = at(
            "http://localhost:1234/v1",
            "qwen3",
            Thinking::OffBy(NoThinking::EnableThinking),
        );
        assert_eq!(sent(&off), [("enable_thinking".to_string(), json!(false))]);
    }

    #[test]
    fn a_model_that_cannot_stop_thinking_offers_no_off() {
        let gemini = "https://generativelanguage.googleapis.com/v1beta/openai";
        let all = Step::ALL.to_vec();
        let levels = all[1..].to_vec();
        let steps = |provider: &Provider| match view(provider) {
            ThinkingView::Steps { steps, .. } => steps,
            other => panic!("{other:?}"),
        };
        assert_eq!(steps(&at(gemini, "gemini-2.5-flash", Thinking::On)), all);
        assert_eq!(steps(&at(gemini, "gemini-2.5-pro", Thinking::On)), levels);
        assert_eq!(
            steps(&at(gemini, "Gemini-3-Pro-Preview", Thinking::On)),
            levels
        );
        let mut mandatory = at("https://openrouter.ai/api/v1", "openai/gpt-5", Thinking::On);
        mandatory.listed.mandatory = true;
        assert_eq!(steps(&mandatory), levels);
    }

    #[test]
    fn a_model_offers_the_levels_its_list_says_it_takes() {
        let router = "https://openrouter.ai/api/v1";
        let listed = |efforts: &[&str]| {
            let mut provider = at(router, "x/model", Thinking::On);
            provider.listed.efforts =
                Some(efforts.iter().map(|effort| effort.to_string()).collect());
            provider
        };
        let high = listed(&["max", "high", "none"]);
        assert_eq!(offer(&high), Offer::Steps(vec![Step::Off, Step::Deep]));
        assert_eq!(
            sent(&high),
            [("reasoning".to_string(), json!({ "effort": "high" }))]
        );
        let no_medium = listed(&["max", "high", "low"]);
        assert_eq!(
            offer(&no_medium),
            Offer::Steps(vec![Step::Off, Step::Light, Step::Deep])
        );
        assert_eq!(
            sent(&no_medium),
            [("reasoning".to_string(), json!({ "effort": "low" }))]
        );
        assert_eq!(offer(&listed(&["xhigh", "max"])), Offer::Switch);
        assert_eq!(
            offer(&at(router, "x/model", Thinking::On)),
            Offer::Steps(Step::ALL.into())
        );
    }

    #[test]
    fn a_model_that_does_not_think_keeps_the_switch() {
        let mut plain = at(
            "https://openrouter.ai/api/v1",
            "openai/gpt-4o",
            Thinking::On,
        );
        plain.listed.thinks = Some(false);
        assert_eq!(offer(&plain), Offer::Switch);
        assert!(sent(&plain).is_empty());
    }

    #[test]
    fn a_kept_thinking_reads_back_as_itself() {
        let mut all = vec![Thinking::On, Thinking::Cannot(None)];
        all.extend(
            [Step::Light, Step::Normal, Step::Deep].map(|step| Thinking::Cannot(Some(step))),
        );
        all.extend(Step::ALL.map(Thinking::Step));
        all.extend(NoThinking::ALL.map(Thinking::OffBy));
        for thinking in all {
            assert_eq!(Thinking::read(thinking.kept()), thinking);
        }
        assert_eq!(Thinking::read("on"), Thinking::On);
    }
}

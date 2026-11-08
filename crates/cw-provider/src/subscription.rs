//! NanoGPT's subscription: whether the key has an active one
//! (`<origin>/api/subscription/v1/usage`, which a key not a UUID is refused
//! on, so only an answer "not active" counts) and the models it includes (that
//! folder's `models`, text, and `image-models`, pictures). Under one, other
//! models are refused or paid apart, so first run's picks keep to the included
//! models of a kind where it includes any ([`keep_included`]). Any other
//! provider, a key without one, or a list that did not come: no preference.

use std::collections::HashSet;
use std::time::Duration;

use cw_platform::http::{Client, Url};
use serde_json::Value;

use crate::catalog::OfferedModel;
use crate::images::is_nanogpt;
use crate::models::{self, Limits};
use crate::{keyed, send};

/// How long each of the subscription's answers may take.
const LIMIT: Duration = Duration::from_secs(15);

/// The models the key's NanoGPT subscription includes; none where `base_url`
/// is not NanoGPT's, the key has no active subscription or a list did not come.
pub(crate) async fn included(http: &Client, base_url: &str, key: &str) -> Option<HashSet<String>> {
    if !is_nanogpt(base_url) {
        return None;
    }
    let mut url = Url::parse(base_url).ok()?;
    url.set_path("/api/subscription/v1");
    let base = url.as_str().trim_end_matches('/').to_string();
    let usage = match send(keyed(http.get(format!("{base}/usage")), key).timeout(LIMIT)).await {
        Ok(answer) => answer.json::<Value>().await.ok(),
        Err(_) => None,
    };
    if !may_be_subscribed(usage) {
        return None;
    }
    let images = format!("{base}/image-models");
    let (texts, pictures) = tokio::join!(
        models::of(http, &base, key, Limits::default()),
        models::described(http, &images, key, Limits::default()),
    );
    let mut ids: HashSet<String> = texts.ok()?.models.into_iter().collect();
    ids.extend(pictures.ok()?.models.into_iter().map(|(id, _)| id));
    Some(ids)
}

/// Whether the lists are asked after the usage answer: only a usage saying
/// the subscription is not active stops them. NanoGPT refuses usage for a key
/// that is not a UUID ("Malformed API key") yet answers the lists for it.
fn may_be_subscribed(usage: Option<Value>) -> bool {
    usage.is_none_or(|usage| usage["active"] != Value::Bool(false))
}

/// Keeps of `models` the `included` ones, of each kind (text, pictures) where
/// any of that kind is included; a kind none of which is included stays whole.
pub(crate) fn keep_included(models: &mut Vec<OfferedModel>, included: &HashSet<String>) {
    let any = |kind: fn(&OfferedModel) -> bool| {
        models
            .iter()
            .any(|model| kind(model) && included.contains(&model.id))
    };
    let texts = any(|model| model.text);
    let pictures = any(|model| model.image);
    models.retain(|model| {
        let only = (model.text && texts) || (model.image && pictures);
        !only || included.contains(&model.id)
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn offered(id: &str, text: bool, image: bool) -> OfferedModel {
        OfferedModel {
            id: id.into(),
            text,
            image,
            search: false,
            voice: false,
            thinks: false,
            said: true,
            name: None,
        }
    }

    #[test]
    fn only_a_usage_saying_inactive_stops_the_lists() {
        assert!(!may_be_subscribed(Some(
            serde_json::json!({"active": false})
        )));
        assert!(may_be_subscribed(Some(serde_json::json!({"active": true}))));
        // NanoGPT refuses a key that is not a UUID on usage alone ("Malformed
        // API key") and answers it on the lists: the lists decide.
        assert!(may_be_subscribed(None));
    }

    #[test]
    fn the_included_models_of_a_kind_are_kept_where_any_of_it_is_included() {
        let all = || {
            vec![
                offered("chat-a", true, false),
                offered("chat-b", true, false),
                offered("paint-a", false, true),
                offered("paint-b", false, true),
            ]
        };
        let ids = |models: &[OfferedModel]| -> Vec<String> {
            models.iter().map(|model| model.id.clone()).collect()
        };
        let mut models = all();
        keep_included(
            &mut models,
            &HashSet::from(["chat-b".into(), "paint-a".into()]),
        );
        assert_eq!(ids(&models), ["chat-b", "paint-a"]);
        // No picture model included: every picture model stays.
        let mut models = all();
        keep_included(&mut models, &HashSet::from(["chat-a".into()]));
        assert_eq!(ids(&models), ["chat-a", "paint-a", "paint-b"]);
    }
}

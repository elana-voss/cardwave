//! Automatic1111's and Forge's pictures, by the API they serve when started
//! with `--api`: their checkpoints at `GET /sdapi/v1/sd-models` (a model's
//! `model_name`, which `sd_model_checkpoint` takes as it takes the title),
//! and a picture of `POST /sdapi/v1/txt2img`, with the checkpoint picked for
//! that request alone (`override_settings`), answered as base64 PNGs. The
//! size is the default ComfyUI workflow's; steps, sampler and scale are the
//! server's own. An address is one where its list of models comes (`provider::images::is_one`).

use anyhow::{Context, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use cw_core::{Code, Fail};
use cw_platform::http::Client;
use serde_json::{Value, json};

use crate::images::{Shape, Whom, keyed, read};
use cw_provider as provider;

/// A picture of `words` made by the Automatic1111 or Forge of `whom`.
pub async fn make(
    http: &Client,
    whom: &Whom,
    words: &str,
    shape: Shape,
) -> anyhow::Result<Vec<u8>> {
    let (width, height) = match shape {
        Shape::Own => (1024, 1024),
        Shape::Upright => (832, 1248),
    };
    let body = json!({
        "prompt": words,
        "negative_prompt": "text, watermark",
        "width": width,
        "height": height,
        "override_settings": { "sd_model_checkpoint": whom.model },
    });
    let request = keyed(
        http.post(format!("{}/sdapi/v1/txt2img", whom.base_url)),
        &whom.api_key,
    )
    .json(&body);
    let said = read(
        provider::send(request).await.context(
            Fail::said(Code::Unreachable, "the picture server cannot be reached")
                .with("whose", "picture_server"),
        )?,
    )
    .await?;
    let said: Value = serde_json::from_slice(&said).context(
        Fail::said(
            Code::NotReadable,
            "the picture server's answer cannot be read",
        )
        .with("what", "picture_server_answer"),
    )?;
    let Some(first) = said["images"][0].as_str() else {
        bail!(
            Fail::said(
                Code::ModelAnswer,
                "the picture server answered without a picture"
            )
            .with("what", "picture_server_no_picture")
        );
    };
    // Some servers put the type before the data, as an address of data does.
    let data = first.rsplit_once(',').map_or(first, |(_, data)| data);
    STANDARD.decode(data).context(
        Fail::said(
            Code::NotReadable,
            "the picture server's picture cannot be read",
        )
        .with("what", "picture_server_answer"),
    )
}

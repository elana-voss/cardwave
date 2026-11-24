//! The context window a server on this machine or its local network loaded
//! its model with, by the server's own API, for the servers that do not
//! answer llama.cpp's `/props` ([`crate::window`] asks that first; KoboldCpp
//! answers it): Ollama's `/api/ps`, LM Studio's `/api/v1/models`. A model not
//! loaded yet is loaded first, as the reply's request would load it, so the
//! window read is the one the reply meets. Only the loaded window is read,
//! never the model's trained maximum (Ollama's `/api/show`, LM Studio's
//! `max_context_length`). A server that is neither, or tells no window so,
//! tells none (`None`), and the user is asked; a refusal is logged with its
//! status and text. Which server answers is told by the shape of its answer,
//! never by its port: either may run anywhere.

use std::time::Duration;

use cw_platform::http::{Client, header::AUTHORIZATION};
use serde_json::{Value, json};

use crate::local::LOAD_LIMIT;
use crate::window::ASK_LIMIT;

/// The window the server at `root` loaded `model` with, loading it first
/// where it is not loaded; none where the server tells none.
pub(crate) async fn window(
    http: &Client,
    root: &str,
    authorization: Option<&str>,
    model: &str,
) -> Option<usize> {
    let asked = Asked {
        http,
        root,
        authorization,
    };
    match ollama(&asked, model).await {
        Some(window) => Some(window),
        None => lm_studio(&asked, model).await,
    }
}

/// Ollama: its `/api/ps` lists each loaded model's `context_length`, after
/// `/api/generate` with the model alone loaded it with the options its
/// OpenAI route uses (none). Not Ollama where `/api/ps` lists no `models`.
async fn ollama(asked: &Asked<'_>, model: &str) -> Option<usize> {
    asked.get("/api/ps").await?["models"].as_array()?;
    asked
        .post("/api/generate", json!({ "model": model }), LOAD_LIMIT)
        .await?;
    let listed = asked.get("/api/ps").await?;
    let wanted = tagged(model);
    let loaded = listed["models"].as_array()?.iter().find(|loaded| {
        ["model", "name"].iter().any(|field| {
            loaded[field]
                .as_str()
                .is_some_and(|name| tagged(name) == wanted)
        })
    })?;
    tokens(&loaded["context_length"])
}

/// An Ollama model's name with its tag, `:latest` where it names none, as
/// Ollama itself completes it.
fn tagged(name: &str) -> String {
    let last = name.rsplit('/').next().unwrap_or(name);
    if last.contains(':') {
        name.to_string()
    } else {
        format!("{name}:latest")
    }
}

/// LM Studio: its `/api/v1/models` gives each model's loaded instances with
/// their `context_length`; `model` is an instance's id or a model's key, the
/// latter loaded by `/api/v1/models/load` where it has no instance yet. Not
/// LM Studio where it lists no `models`.
async fn lm_studio(asked: &Asked<'_>, model: &str) -> Option<usize> {
    let listed = asked.get("/api/v1/models").await?;
    let models = listed["models"].as_array()?;
    let instances = |entry: &'_ Value| {
        entry["loaded_instances"]
            .as_array()
            .cloned()
            .unwrap_or_default()
    };
    let window = |instance: &Value| tokens(&instance["config"]["context_length"]);
    if let Some(instance) = models
        .iter()
        .flat_map(instances)
        .find(|instance| instance["id"].as_str() == Some(model))
    {
        return window(&instance);
    }
    let entry = models
        .iter()
        .find(|entry| entry["key"].as_str() == Some(model))?;
    if let Some(instance) = instances(entry).first() {
        return window(instance);
    }
    let body = json!({ "model": model, "echo_load_config": true });
    let loaded = asked.post("/api/v1/models/load", body, LOAD_LIMIT).await?;
    tokens(&loaded["load_config"]["context_length"])
}

/// A count of tokens, where it is one above zero.
fn tokens(value: &Value) -> Option<usize> {
    value
        .as_u64()
        .and_then(|count| usize::try_from(count).ok())
        .filter(|count| *count > 0)
}

/// A server's root and how to ask it.
struct Asked<'a> {
    http: &'a Client,
    root: &'a str,
    authorization: Option<&'a str>,
}

impl Asked<'_> {
    async fn get(&self, path: &str) -> Option<Value> {
        self.answer(
            path,
            self.http
                .get(format!("{}{path}", self.root))
                .timeout(ASK_LIMIT),
        )
        .await
    }

    async fn post(&self, path: &str, body: Value, limit: Duration) -> Option<Value> {
        let asked = self.http.post(format!("{}{path}", self.root)).json(&body);
        self.answer(path, asked.timeout(limit)).await
    }

    /// What the server answered to `asked` at `path`, where it took it; a
    /// refusal or no answer is logged and is none.
    async fn answer(
        &self,
        path: &str,
        mut asked: cw_platform::http::RequestBuilder,
    ) -> Option<Value> {
        if let Some(authorization) = self.authorization {
            asked = asked.header(AUTHORIZATION, authorization);
        }
        let root = self.root;
        let answer = match asked.send().await {
            Ok(answer) => answer,
            Err(failure) => {
                tracing::info!("{root}{path} was not answered: {failure}");
                return None;
            }
        };
        let status = answer.status();
        if !status.is_success() {
            // Its text only explains the refusal; one that cannot be read is told as empty.
            let text = answer.text().await.unwrap_or_default();
            tracing::info!("{root}{path} answered {status}: {text}");
            return None;
        }
        answer.json::<Value>().await.ok()
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use super::*;
    use crate::Provider;
    use crate::models_dev::Index;

    /// What a stand-in was asked, a request line ("GET /api/ps") each.
    type Seen = Arc<Mutex<Vec<String>>>;

    /// A stand-in server on this machine: `route` answers each request line,
    /// given those before it, with a status and a body.
    async fn stand_in(route: fn(&str, &[String]) -> (u16, String)) -> (String, Seen) {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let root = format!("http://{}", listener.local_addr().unwrap());
        let seen = Seen::default();
        let kept = seen.clone();
        tokio::spawn(async move {
            while let Ok((mut socket, _)) = listener.accept().await {
                let mut request = Vec::new();
                let mut buffer = [0; 4096];
                // The whole request is read, so closing the socket resets nothing.
                while let Ok(read @ 1..) = socket.read(&mut buffer).await {
                    request.extend_from_slice(&buffer[..read]);
                    let text = String::from_utf8_lossy(&request).to_lowercase();
                    let Some(end) = text.find("\r\n\r\n") else {
                        continue;
                    };
                    let length = text
                        .lines()
                        .find_map(|line| line.strip_prefix("content-length:"))
                        .and_then(|length| length.trim().parse::<usize>().ok())
                        .unwrap_or(0);
                    if request.len() >= end + 4 + length {
                        break;
                    }
                }
                let text = String::from_utf8_lossy(&request);
                let line: String = text.split(" HTTP/").next().unwrap_or_default().to_string();
                let (status, body) = {
                    let mut seen = kept.lock().unwrap();
                    let answer = route(&line, &seen);
                    seen.push(line);
                    answer
                };
                let reply = format!(
                    "HTTP/1.1 {status} X\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                    body.len()
                );
                // A test whose answer is not taken fails on its own.
                let _sent = socket.write_all(reply.as_bytes()).await;
            }
        });
        (root, seen)
    }

    /// The window `crate::window` settles for `model` at `root`.
    async fn window(root: &str, model: &str) -> Option<usize> {
        let index = Index::read(b"{}").unwrap();
        let provider = Provider::new(format!("{root}/v1"), "", model);
        crate::window::settled(&Client::new(), &index, provider)
            .await
            .unwrap()
            .window
    }

    fn not_found() -> (u16, String) {
        (404, r#"{"error":"not found"}"#.to_string())
    }

    /// Ollama with "llama3.2:latest" (8192) listed once loaded, and another
    /// model always loaded (4096); "missing" it refuses to load.
    fn ollama(line: &str, seen: &[String]) -> (u16, String) {
        let loaded = seen.iter().any(|line| line == "POST /api/generate");
        match line {
            "GET /api/ps" if loaded => (
                200,
                r#"{"models":[
                {"name":"other:7b","model":"other:7b","context_length":4096},
                {"name":"llama3.2:latest","model":"llama3.2:latest","context_length":8192}]}"#
                    .to_string(),
            ),
            "GET /api/ps" => (
                200,
                r#"{"models":[
                {"name":"other:7b","model":"other:7b","context_length":4096}]}"#
                    .to_string(),
            ),
            "POST /api/generate" => (
                200,
                r#"{"model":"llama3.2","response":"","done":true}"#.to_string(),
            ),
            _ => not_found(),
        }
    }

    #[tokio::test]
    async fn ollama_tells_the_window_it_loaded_the_model_with_after_loading_it() {
        let (root, seen) = stand_in(ollama).await;
        assert_eq!(window(&root, "llama3.2").await, Some(8192));
        assert_eq!(window(&root, "other:7b").await, Some(4096));
        assert!(
            seen.lock()
                .unwrap()
                .iter()
                .any(|line| line == "POST /api/generate")
        );
    }

    /// LM Studio with "a/loaded" in an instance of 4096 (trained 131072),
    /// "b/idle" not loaded, which its load gives 16384.
    fn lm_studio(line: &str, _seen: &[String]) -> (u16, String) {
        match line {
            "GET /api/v1/models" => (200, r#"{"models":[
                {"key":"a/loaded","loaded_instances":[{"id":"a/loaded","config":{"context_length":4096}}],"max_context_length":131072},
                {"key":"b/idle","loaded_instances":[],"max_context_length":32768}]}"#.to_string()),
            "POST /api/v1/models/load" => (200, r#"{"type":"llm","instance_id":"b/idle","status":"loaded","load_config":{"context_length":16384}}"#.to_string()),
            // As LM Studio answers a path it does not know.
            _ => (200, r#"{"error":"Unexpected endpoint or method."}"#.to_string()),
        }
    }

    #[tokio::test]
    async fn lm_studio_tells_its_loaded_instances_window_else_loads_the_model() {
        let (root, seen) = stand_in(lm_studio).await;
        assert_eq!(window(&root, "a/loaded").await, Some(4096));
        assert!(
            !seen
                .lock()
                .unwrap()
                .iter()
                .any(|line| line.contains("/load"))
        );
        assert_eq!(window(&root, "b/idle").await, Some(16384));
        assert!(
            seen.lock()
                .unwrap()
                .iter()
                .any(|line| line == "POST /api/v1/models/load")
        );
        assert_eq!(window(&root, "c/unknown").await, None);
    }

    /// Ollama refusing to load the model.
    fn refusing(line: &str, _seen: &[String]) -> (u16, String) {
        match line {
            "GET /api/ps" => (200, r#"{"models":[]}"#.to_string()),
            "POST /api/generate" => (404, r#"{"error":"model 'gone' not found"}"#.to_string()),
            _ => not_found(),
        }
    }

    /// Ollama too old to tell a loaded model's window.
    fn old(line: &str, _seen: &[String]) -> (u16, String) {
        match line {
            "GET /api/ps" => (
                200,
                r#"{"models":[{"name":"old:latest","model":"old:latest"}]}"#.to_string(),
            ),
            "POST /api/generate" => (200, r#"{"done":true}"#.to_string()),
            _ => not_found(),
        }
    }

    fn failing_load(line: &str, _seen: &[String]) -> (u16, String) {
        match line {
            "GET /api/v1/models" => (
                200,
                r#"{"models":[{"key":"b/idle","loaded_instances":[]}]}"#.to_string(),
            ),
            "POST /api/v1/models/load" => (500, r#"{"error":"not enough memory"}"#.to_string()),
            _ => not_found(),
        }
    }

    #[tokio::test]
    async fn a_refusal_or_a_server_that_tells_no_loaded_window_gives_none() {
        let (refusing, _) = stand_in(refusing).await;
        assert_eq!(window(&refusing, "gone").await, None);
        let (old, _) = stand_in(old).await;
        assert_eq!(window(&old, "old").await, None);
        let (lm_studio, _) = stand_in(failing_load).await;
        assert_eq!(window(&lm_studio, "b/idle").await, None);
    }

    #[test]
    fn an_ollama_name_without_a_tag_is_its_latest() {
        assert_eq!(tagged("llama3.2"), "llama3.2:latest");
        assert_eq!(tagged("llama3.2:1b"), "llama3.2:1b");
        assert_eq!(tagged("host:5000/me/model"), "host:5000/me/model:latest");
    }
}

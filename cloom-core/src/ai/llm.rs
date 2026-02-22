use crate::CloomError;
use serde::{Deserialize, Serialize};

/// Which LLM provider to use.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum LlmProvider {
    OpenAi,
    Claude,
}

/// A chapter marker with title and start time.
#[derive(Debug, Clone, uniffi::Record)]
pub struct Chapter {
    pub id: String,
    pub title: String,
    pub start_ms: i64,
}

const MAX_TRANSCRIPT_CHARS: usize = 100_000;

/// Generate a concise title from transcript text.
#[uniffi::export]
pub fn generate_title(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<String, CloomError> {
    validate_provider(&provider)?;
    let truncated = truncate_transcript(&transcript_text);
    let prompt = format!(
        "Generate a concise title (max 10 words) for this recording based on its transcript. \
         Return ONLY the title text, no quotes or extra formatting.\n\nTranscript:\n{truncated}"
    );
    chat_completion(&api_key, &prompt)
}

/// Generate a 2-3 sentence summary from transcript text.
#[uniffi::export]
pub fn generate_summary(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<String, CloomError> {
    validate_provider(&provider)?;
    let truncated = truncate_transcript(&transcript_text);
    let prompt = format!(
        "Summarize the key points of this recording in 2-3 sentences. \
         Be concise and informative.\n\nTranscript:\n{truncated}"
    );
    chat_completion(&api_key, &prompt)
}

/// Divide transcript into chapters with timestamps.
#[uniffi::export]
pub fn generate_chapters(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<Vec<Chapter>, CloomError> {
    validate_provider(&provider)?;
    let truncated = truncate_transcript(&transcript_text);
    let prompt = format!(
        "Divide this recording transcript into logical chapters. \
         Return a JSON array where each element has \"title\" (string) and \"start_ms\" (integer milliseconds). \
         Return ONLY the JSON array, no markdown fences or extra text.\n\nTranscript:\n{truncated}"
    );
    let raw = chat_completion(&api_key, &prompt)?;
    parse_chapters(&raw)
}

pub(crate) fn validate_provider(provider: &LlmProvider) -> Result<(), CloomError> {
    match provider {
        LlmProvider::OpenAi => Ok(()),
        LlmProvider::Claude => Err(CloomError::InvalidInput {
            msg: "Claude provider is not yet supported".to_string(),
        }),
    }
}

// Made pub(crate) for testability
pub(crate) fn truncate_transcript(text: &str) -> &str {
    if text.len() <= MAX_TRANSCRIPT_CHARS {
        text
    } else {
        &text[..MAX_TRANSCRIPT_CHARS]
    }
}

// --- OpenAI Chat API ---

#[derive(Serialize)]
struct ChatRequest {
    model: String,
    messages: Vec<ChatMessage>,
    temperature: f32,
}

#[derive(Serialize)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Deserialize)]
struct ChatResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Deserialize)]
struct ChatChoice {
    message: ChatResponseMessage,
}

#[derive(Deserialize)]
struct ChatResponseMessage {
    content: String,
}

fn chat_completion(api_key: &str, prompt: &str) -> Result<String, CloomError> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| CloomError::ApiError {
        msg: format!("Failed to create async runtime: {e}"),
    })?;

    rt.block_on(async {
        let client = reqwest::Client::new();

        let body = ChatRequest {
            model: "gpt-4o-mini".to_string(),
            messages: vec![ChatMessage {
                role: "user".to_string(),
                content: prompt.to_string(),
            }],
            temperature: 0.3,
        };

        let response = client
            .post("https://api.openai.com/v1/chat/completions")
            .bearer_auth(api_key)
            .json(&body)
            .send()
            .await
            .map_err(|e| CloomError::ApiError {
                msg: format!("Chat request failed: {e}"),
            })?;

        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CloomError::ApiError {
                msg: format!("OpenAI API error ({status}): {body}"),
            });
        }

        let result: ChatResponse =
            response.json().await.map_err(|e| CloomError::ApiError {
                msg: format!("Failed to parse chat response: {e}"),
            })?;

        result
            .choices
            .into_iter()
            .next()
            .map(|c| c.message.content.trim().to_string())
            .ok_or_else(|| CloomError::ApiError {
                msg: "Empty response from LLM".to_string(),
            })
    })
}

// --- Chapter parsing ---

#[derive(Deserialize)]
struct RawChapter {
    title: String,
    start_ms: i64,
}

// Made pub(crate) for testability
pub(crate) fn parse_chapters(raw: &str) -> Result<Vec<Chapter>, CloomError> {
    // Strip markdown code fences if present
    let json_str = raw
        .trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();

    match serde_json::from_str::<Vec<RawChapter>>(json_str) {
        Ok(chapters) => Ok(chapters
            .into_iter()
            .map(|c| Chapter {
                id: uuid::Uuid::new_v4().to_string(),
                title: c.title,
                start_ms: c.start_ms,
            })
            .collect()),
        Err(_) => {
            // Fallback: single chapter covering the whole recording
            Ok(vec![Chapter {
                id: uuid::Uuid::new_v4().to_string(),
                title: "Full Recording".to_string(),
                start_ms: 0,
            }])
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // --- parse_chapters tests ---

    #[test]
    fn test_parse_chapters_valid_json() {
        let json = r#"[{"title": "Intro", "start_ms": 0}, {"title": "Demo", "start_ms": 30000}]"#;
        let chapters = parse_chapters(json).unwrap();
        assert_eq!(chapters.len(), 2);
        assert_eq!(chapters[0].title, "Intro");
        assert_eq!(chapters[0].start_ms, 0);
        assert_eq!(chapters[1].title, "Demo");
        assert_eq!(chapters[1].start_ms, 30000);
    }

    #[test]
    fn test_parse_chapters_code_fenced_json() {
        let raw = "```json\n[{\"title\": \"Setup\", \"start_ms\": 0}]\n```";
        let chapters = parse_chapters(raw).unwrap();
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].title, "Setup");
    }

    #[test]
    fn test_parse_chapters_bare_code_fence() {
        let raw = "```\n[{\"title\": \"A\", \"start_ms\": 100}]\n```";
        let chapters = parse_chapters(raw).unwrap();
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].start_ms, 100);
    }

    #[test]
    fn test_parse_chapters_invalid_fallback() {
        let raw = "This is not JSON at all";
        let chapters = parse_chapters(raw).unwrap();
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].title, "Full Recording");
        assert_eq!(chapters[0].start_ms, 0);
    }

    #[test]
    fn test_parse_chapters_empty_array() {
        let raw = "[]";
        let chapters = parse_chapters(raw).unwrap();
        assert_eq!(chapters.len(), 0);
    }

    #[test]
    fn test_parse_chapters_ids_are_unique() {
        let json = r#"[{"title": "A", "start_ms": 0}, {"title": "B", "start_ms": 1000}]"#;
        let chapters = parse_chapters(json).unwrap();
        assert_ne!(chapters[0].id, chapters[1].id);
    }

    // --- truncate_transcript tests ---

    #[test]
    fn test_truncate_short_text() {
        let text = "Hello world";
        let result = truncate_transcript(text);
        assert_eq!(result, "Hello world");
    }

    #[test]
    fn test_truncate_long_text() {
        let text = "a".repeat(200_000);
        let result = truncate_transcript(&text);
        assert_eq!(result.len(), 100_000);
    }

    #[test]
    fn test_truncate_at_boundary() {
        let text = "a".repeat(100_000);
        let result = truncate_transcript(&text);
        assert_eq!(result.len(), 100_000);
    }

    // --- validate_provider tests ---

    #[test]
    fn test_validate_openai_ok() {
        assert!(validate_provider(&LlmProvider::OpenAi).is_ok());
    }

    #[test]
    fn test_validate_claude_error() {
        let result = validate_provider(&LlmProvider::Claude);
        assert!(result.is_err());
        if let Err(CloomError::InvalidInput { msg }) = result {
            assert!(msg.contains("Claude"));
        }
    }
}

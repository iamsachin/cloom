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
         The transcript includes timestamps in [M:SS] format. Use these timestamps to determine accurate start_ms values. \
         Convert the [M:SS] timestamps to milliseconds (e.g., [1:30] = 90000). \
         Return a JSON array where each element has \"title\" (string) and \"start_ms\" (integer milliseconds). \
         Return ONLY the JSON array, no markdown fences or extra text.\n\nTranscript:\n{truncated}"
    );
    let raw = chat_completion(&api_key, &prompt)?;
    parse_chapters(&raw)
}

/// Insert paragraph breaks into transcript text using an LLM.
/// Returns the same text with `\n\n` inserted between logical paragraphs.
#[uniffi::export]
pub fn format_paragraphs(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<String, CloomError> {
    validate_provider(&provider)?;
    let truncated = truncate_transcript(&transcript_text);
    let prompt = format!(
        "Add paragraph breaks to this transcript. Insert exactly \"\\n\\n\" between logical paragraphs \
         (topic changes, speaker pauses, or shifts in subject). \
         Do NOT change, add, or remove any words or punctuation — return the original text \
         with only paragraph breaks inserted.\n\nTranscript:\n{truncated}"
    );
    chat_completion(&api_key, &prompt)
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
    crate::runtime::RUNTIME.block_on(async {
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
#[path = "llm_tests.rs"]
mod tests;

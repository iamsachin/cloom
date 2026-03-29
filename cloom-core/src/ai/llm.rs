use crate::CloomError;

use async_openai::types::chat::{
    ChatCompletionRequestMessage, ChatCompletionRequestUserMessage,
    CreateChatCompletionRequestArgs,
};
use serde::Deserialize;

/// Which LLM provider to use.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum LlmProvider {
    OpenAi,
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
    llm_from_transcript(
        &transcript_text,
        &api_key,
        &provider,
        "Generate a concise title (max 10 words) for this recording based on its transcript. \
         Return ONLY the title text, no quotes or extra formatting.",
    )
}

/// Generate a 2-3 sentence summary from transcript text.
#[uniffi::export]
pub fn generate_summary(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<String, CloomError> {
    llm_from_transcript(
        &transcript_text,
        &api_key,
        &provider,
        "Summarize the key points of this recording in 2-3 sentences. \
         Be concise and informative.",
    )
}

/// Divide transcript into chapters with timestamps.
#[uniffi::export]
pub fn generate_chapters(
    transcript_text: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<Vec<Chapter>, CloomError> {
    let raw = llm_from_transcript(
        &transcript_text,
        &api_key,
        &provider,
        "Divide this recording transcript into logical chapters. \
         The transcript includes timestamps in [M:SS.t] format (minutes:seconds.tenths). \
         Use the EXACT timestamp closest to where each chapter begins to determine start_ms. \
         Convert [M:SS.t] to milliseconds: e.g., [1:30.5] = 90500, [0:04.2] = 4200. \
         Return a JSON array where each element has \"title\" (string) and \"start_ms\" (integer milliseconds). \
         Return ONLY the JSON array, no markdown fences or extra text.",
    )?;
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
    llm_from_transcript(
        &transcript_text,
        &api_key,
        &provider,
        "Add paragraph breaks to this transcript. Insert exactly \"\\n\\n\" between logical paragraphs \
         (topic changes, speaker pauses, or shifts in subject). \
         Do NOT change, add, or remove any words. Restore any missing punctuation \
         (periods, commas, question marks) and fix capitalization at sentence boundaries. \
         Return the text with paragraph breaks and corrected punctuation.",
    )
}

/// Translate text to a target language using the LLM.
/// `target_language` is a human-readable language name (e.g., "Spanish", "Japanese").
#[uniffi::export]
pub fn translate_text(
    text: String,
    target_language: String,
    api_key: String,
    provider: LlmProvider,
) -> Result<String, CloomError> {
    validate_provider(&provider)?;
    let truncated = truncate_transcript(&text);
    let prompt = format!(
        "Translate the following text to {target_language}. \
         Return ONLY the translated text, preserving all line breaks. \
         Do not add any commentary or notes.\n\nText:\n{truncated}"
    );
    chat_completion(&api_key, &prompt)
}

/// Shared preamble for all LLM-from-transcript operations:
/// validate provider → truncate → format prompt with transcript → chat completion.
fn llm_from_transcript(
    transcript_text: &str,
    api_key: &str,
    provider: &LlmProvider,
    instruction: &str,
) -> Result<String, CloomError> {
    validate_provider(provider)?;
    let truncated = truncate_transcript(transcript_text);
    let prompt = format!("{instruction}\n\nTranscript:\n{truncated}");
    chat_completion(api_key, &prompt)
}

pub(crate) fn validate_provider(provider: &LlmProvider) -> Result<(), CloomError> {
    match provider {
        LlmProvider::OpenAi => Ok(()),
    }
}

// Made pub(crate) for testability
pub(crate) fn truncate_transcript(text: &str) -> &str {
    if text.len() <= MAX_TRANSCRIPT_CHARS {
        text
    } else {
        // Find a char boundary at or before MAX_TRANSCRIPT_CHARS to avoid panicking
        // on multi-byte UTF-8 sequences.
        let end = text
            .char_indices()
            .take_while(|(i, _)| *i <= MAX_TRANSCRIPT_CHARS)
            .last()
            .map(|(i, _)| i)
            .unwrap_or(0);
        &text[..end]
    }
}

fn chat_completion(api_key: &str, prompt: &str) -> Result<String, CloomError> {
    crate::runtime::RUNTIME.block_on(async {
        let client = super::make_openai_client(api_key);

        log::debug!("Sending chat completion request ({} chars)", prompt.len());

        let user_msg: ChatCompletionRequestMessage =
            ChatCompletionRequestUserMessage::from(prompt).into();

        let request = CreateChatCompletionRequestArgs::default()
            .model("gpt-4.1-mini")
            .messages(vec![user_msg])
            .temperature(0.3)
            .build()
            .map_err(|e| CloomError::ApiError {
                msg: format!("Failed to build chat request: {e}"),
            })?;

        let response = client.chat().create(request).await.map_err(|e| {
            log::error!("Chat request failed: {e}");
            CloomError::ApiError {
                msg: format!("Chat request failed: {e}"),
            }
        })?;

        response
            .choices
            .into_iter()
            .next()
            .and_then(|c| c.message.content)
            .map(|s| s.trim().to_string())
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

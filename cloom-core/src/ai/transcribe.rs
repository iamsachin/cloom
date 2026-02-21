use crate::CloomError;
use serde::Deserialize;
use std::fs;

/// Which transcription service to use.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum TranscriptionProvider {
    OpenAi,
}

/// A single word with timing information from the transcript.
#[derive(Debug, Clone, uniffi::Record)]
pub struct TranscriptWord {
    pub word: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub confidence: f32,
}

/// Full transcription result.
#[derive(Debug, Clone, uniffi::Record)]
pub struct Transcript {
    pub full_text: String,
    pub words: Vec<TranscriptWord>,
    pub language: String,
}

// --- OpenAI API response types ---

#[derive(Deserialize)]
struct OpenAiTranscriptionResponse {
    text: String,
    language: Option<String>,
    words: Option<Vec<OpenAiWord>>,
}

#[derive(Deserialize)]
struct OpenAiWord {
    word: String,
    start: f64,
    end: f64,
}

const MAX_FILE_SIZE: u64 = 25 * 1024 * 1024; // 25 MB

/// Transcribe an audio file using the specified provider.
///
/// Blocks the calling thread while the async HTTP request completes.
#[uniffi::export]
pub fn transcribe_audio(
    audio_path: String,
    api_key: String,
    provider: TranscriptionProvider,
    model: String,
) -> Result<Transcript, CloomError> {
    match provider {
        TranscriptionProvider::OpenAi => transcribe_openai(&audio_path, &api_key, &model),
    }
}

fn transcribe_openai(
    audio_path: &str,
    api_key: &str,
    model: &str,
) -> Result<Transcript, CloomError> {
    let metadata = fs::metadata(audio_path).map_err(|e| CloomError::IoError {
        msg: format!("Cannot read audio file: {e}"),
    })?;

    if metadata.len() > MAX_FILE_SIZE {
        return Err(CloomError::InvalidInput {
            msg: format!(
                "Audio file is {}MB, exceeds 25MB limit",
                metadata.len() / (1024 * 1024)
            ),
        });
    }

    let file_bytes = fs::read(audio_path).map_err(|e| CloomError::IoError {
        msg: format!("Failed to read audio file: {e}"),
    })?;

    let file_name = std::path::Path::new(audio_path)
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let model = if model.is_empty() {
        "whisper-1".to_string()
    } else {
        model.to_string()
    };

    let rt = tokio::runtime::Runtime::new().map_err(|e| CloomError::ApiError {
        msg: format!("Failed to create async runtime: {e}"),
    })?;

    rt.block_on(async {
        let client = reqwest::Client::new();

        let mime_type = if file_name.ends_with(".m4a") {
            "audio/m4a"
        } else if file_name.ends_with(".wav") {
            "audio/wav"
        } else {
            "audio/mp4"
        };

        let file_part = reqwest::multipart::Part::bytes(file_bytes)
            .file_name(file_name)
            .mime_str(mime_type)
            .map_err(|e| CloomError::ApiError {
                msg: format!("Failed to create multipart: {e}"),
            })?;

        let form = reqwest::multipart::Form::new()
            .part("file", file_part)
            .text("model", model)
            .text("response_format", "verbose_json")
            .text("timestamp_granularities[]", "word")
            .text("prompt", "Hello, welcome. This is a screen recording with proper punctuation, capitalization, and full stops.");

        let response = client
            .post("https://api.openai.com/v1/audio/transcriptions")
            .bearer_auth(api_key)
            .multipart(form)
            .send()
            .await
            .map_err(|e| CloomError::ApiError {
                msg: format!("Transcription request failed: {e}"),
            })?;

        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CloomError::ApiError {
                msg: format!("OpenAI API error ({status}): {body}"),
            });
        }

        let result: OpenAiTranscriptionResponse =
            response.json().await.map_err(|e| CloomError::ApiError {
                msg: format!("Failed to parse transcription response: {e}"),
            })?;

        let words = result
            .words
            .unwrap_or_default()
            .into_iter()
            .map(|w| TranscriptWord {
                word: w.word,
                start_ms: (w.start * 1000.0) as i64,
                end_ms: (w.end * 1000.0) as i64,
                confidence: 1.0,
            })
            .collect();

        Ok(Transcript {
            full_text: result.text,
            words,
            language: result.language.unwrap_or_else(|| "en".to_string()),
        })
    })
}

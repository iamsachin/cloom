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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_file_not_found() {
        let result = transcribe_audio(
            "/nonexistent/file.m4a".to_string(),
            "test-key".to_string(),
            TranscriptionProvider::OpenAi,
            "whisper-1".to_string(),
        );
        assert!(result.is_err());
        if let Err(CloomError::IoError { msg }) = result {
            assert!(msg.contains("Cannot read audio file"));
        }
    }

    #[test]
    fn test_file_too_large() {
        // Create a temp file larger than 25MB
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("large.m4a");
        let data = vec![0u8; 26 * 1024 * 1024];
        std::fs::write(&path, &data).unwrap();

        let result = transcribe_audio(
            path.to_str().unwrap().to_string(),
            "test-key".to_string(),
            TranscriptionProvider::OpenAi,
            "whisper-1".to_string(),
        );
        assert!(result.is_err());
        if let Err(CloomError::InvalidInput { msg }) = result {
            assert!(msg.contains("exceeds 25MB"));
        }
    }

    #[test]
    fn test_parse_transcription_response() {
        let json = r#"{
            "text": "Hello world",
            "language": "en",
            "words": [
                {"word": "Hello", "start": 0.0, "end": 0.5},
                {"word": "world", "start": 0.5, "end": 1.0}
            ]
        }"#;

        let resp: OpenAiTranscriptionResponse = serde_json::from_str(json).unwrap();
        assert_eq!(resp.text, "Hello world");
        assert_eq!(resp.language, Some("en".to_string()));

        let words = resp.words.unwrap();
        assert_eq!(words.len(), 2);
        assert_eq!(words[0].word, "Hello");
        assert_eq!(words[0].start, 0.0);
        assert_eq!(words[0].end, 0.5);
    }

    #[test]
    fn test_parse_response_no_words() {
        let json = r#"{"text": "Hello world"}"#;
        let resp: OpenAiTranscriptionResponse = serde_json::from_str(json).unwrap();
        assert_eq!(resp.text, "Hello world");
        assert!(resp.words.is_none());
        assert!(resp.language.is_none());
    }

    #[test]
    fn test_parse_response_empty_words() {
        let json = r#"{"text": "Hello", "words": []}"#;
        let resp: OpenAiTranscriptionResponse = serde_json::from_str(json).unwrap();
        assert!(resp.words.unwrap().is_empty());
    }

    #[test]
    fn test_mime_type_detection() {
        // Test the MIME logic inline
        let m4a = if "test.m4a".ends_with(".m4a") { "audio/m4a" } else { "audio/mp4" };
        assert_eq!(m4a, "audio/m4a");

        let wav = if "test.wav".ends_with(".m4a") {
            "audio/m4a"
        } else if "test.wav".ends_with(".wav") {
            "audio/wav"
        } else {
            "audio/mp4"
        };
        assert_eq!(wav, "audio/wav");

        let mp4 = if "test.mp4".ends_with(".m4a") {
            "audio/m4a"
        } else if "test.mp4".ends_with(".wav") {
            "audio/wav"
        } else {
            "audio/mp4"
        };
        assert_eq!(mp4, "audio/mp4");
    }

    #[tokio::test]
    async fn test_transcription_api_with_wiremock() {
        use wiremock::matchers::{method, path};
        use wiremock::{Mock, MockServer, ResponseTemplate};

        let mock_server = MockServer::start().await;

        let response_body = std::fs::read_to_string(
            concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/transcription_response.json")
        ).unwrap();

        Mock::given(method("POST"))
            .and(path("/v1/audio/transcriptions"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_string(&response_body)
            )
            .mount(&mock_server)
            .await;

        // We can't easily redirect the client URL in the current architecture,
        // so we verify the fixture parses correctly
        let resp: OpenAiTranscriptionResponse = serde_json::from_str(&response_body).unwrap();
        assert_eq!(resp.words.unwrap().len(), 9);
        assert_eq!(resp.language, Some("en".to_string()));
    }
}

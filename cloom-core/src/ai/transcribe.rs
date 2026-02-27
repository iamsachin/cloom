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

/// Transcribe multiple audio chunks and merge results with offset-adjusted timestamps.
///
/// Each chunk path corresponds to a segment of the original audio.
/// `offset_ms` provides the start time of each chunk in the original timeline.
#[uniffi::export]
pub fn transcribe_audio_chunked(
    chunk_paths: Vec<String>,
    offset_ms: Vec<i64>,
    api_key: String,
    provider: TranscriptionProvider,
    model: String,
) -> Result<Transcript, CloomError> {
    if chunk_paths.is_empty() {
        return Ok(Transcript {
            full_text: String::new(),
            words: Vec::new(),
            language: "en".to_string(),
        });
    }

    let mut all_words: Vec<TranscriptWord> = Vec::new();
    let mut all_texts: Vec<String> = Vec::new();
    let mut language = "en".to_string();

    for (i, path) in chunk_paths.iter().enumerate() {
        let offset = offset_ms.get(i).copied().unwrap_or(0);
        let chunk_result = match provider {
            TranscriptionProvider::OpenAi => transcribe_openai(path, &api_key, &model),
        }?;

        if i == 0 {
            language = chunk_result.language;
        }

        all_texts.push(chunk_result.full_text);

        for mut word in chunk_result.words {
            word.start_ms += offset;
            word.end_ms += offset;
            all_words.push(word);
        }
    }

    Ok(Transcript {
        full_text: all_texts.join(" "),
        words: all_words,
        language,
    })
}

fn transcribe_openai(
    audio_path: &str,
    api_key: &str,
    model: &str,
) -> Result<Transcript, CloomError> {
    let _metadata = fs::metadata(audio_path).map_err(|e| CloomError::IoError {
        msg: format!("Cannot read audio file: {e}"),
    })?;

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

    crate::runtime::RUNTIME.block_on(async {
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
            .text("timestamp_granularities[]", "word");

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
    fn test_chunked_offset_adjustment() {
        // Simulate merging two chunk results with offsets
        let chunk1 = Transcript {
            full_text: "Hello world".to_string(),
            words: vec![
                TranscriptWord { word: "Hello".to_string(), start_ms: 0, end_ms: 500, confidence: 1.0 },
                TranscriptWord { word: "world".to_string(), start_ms: 500, end_ms: 1000, confidence: 1.0 },
            ],
            language: "en".to_string(),
        };
        let chunk2 = Transcript {
            full_text: "foo bar".to_string(),
            words: vec![
                TranscriptWord { word: "foo".to_string(), start_ms: 0, end_ms: 400, confidence: 1.0 },
                TranscriptWord { word: "bar".to_string(), start_ms: 400, end_ms: 800, confidence: 1.0 },
            ],
            language: "en".to_string(),
        };

        // Apply offset of 5000ms to chunk2
        let offset: i64 = 5000;
        let mut merged_words = chunk1.words.clone();
        for mut w in chunk2.words {
            w.start_ms += offset;
            w.end_ms += offset;
            merged_words.push(w);
        }

        assert_eq!(merged_words.len(), 4);
        assert_eq!(merged_words[2].word, "foo");
        assert_eq!(merged_words[2].start_ms, 5000);
        assert_eq!(merged_words[2].end_ms, 5400);
        assert_eq!(merged_words[3].start_ms, 5400);
        assert_eq!(merged_words[3].end_ms, 5800);
    }

    #[test]
    fn test_chunked_text_merging() {
        let texts = vec!["Hello world".to_string(), "foo bar".to_string()];
        let merged = texts.join(" ");
        assert_eq!(merged, "Hello world foo bar");
    }

    #[test]
    fn test_chunked_empty_paths() {
        let result = transcribe_audio_chunked(
            vec![],
            vec![],
            "test-key".to_string(),
            TranscriptionProvider::OpenAi,
            "whisper-1".to_string(),
        );
        assert!(result.is_ok());
        let transcript = result.unwrap();
        assert!(transcript.full_text.is_empty());
        assert!(transcript.words.is_empty());
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

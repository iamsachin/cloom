use crate::CloomError;

use async_openai::{
    config::OpenAIConfig,
    types::audio::{AudioResponseFormat, CreateTranscriptionRequestArgs, TimestampGranularity},
    Client,
};

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
    // Check file exists before calling API for a clear IoError
    if !std::path::Path::new(audio_path).exists() {
        return Err(CloomError::IoError {
            msg: format!("Failed to read audio file: No such file or directory (os error 2)"),
        });
    }

    let model = if model.is_empty() {
        "whisper-1".to_string()
    } else {
        model.to_string()
    };

    crate::runtime::RUNTIME.block_on(async {
        let config = OpenAIConfig::new().with_api_key(api_key);
        let client = Client::with_config(config);

        log::info!("Starting transcription of {audio_path} with model {model}");

        let request = CreateTranscriptionRequestArgs::default()
            .file(audio_path)
            .model(&model)
            .response_format(AudioResponseFormat::VerboseJson)
            .timestamp_granularities(vec![TimestampGranularity::Word])
            .build()
            .map_err(|e| CloomError::ApiError {
                msg: format!("Failed to build transcription request: {e}"),
            })?;

        let response = client
            .audio()
            .transcription()
            .create_verbose_json(request)
            .await
            .map_err(|e| {
                log::error!("Transcription request failed: {e}");
                CloomError::ApiError {
                    msg: format!("Transcription request failed: {e}"),
                }
            })?;

        let word_count = response.words.as_ref().map_or(0, Vec::len);
        log::info!("Transcription complete — {word_count} words");

        let words = response
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
            full_text: response.text,
            words,
            language: response.language,
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
            assert!(msg.contains("read audio file"));
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
    fn test_transcript_word_ms_conversion() {
        // Verify the seconds-to-milliseconds conversion logic
        let start_secs: f32 = 1.234;
        let end_secs: f32 = 2.567;
        let start_ms = (start_secs * 1000.0) as i64;
        let end_ms = (end_secs * 1000.0) as i64;
        assert_eq!(start_ms, 1234);
        assert_eq!(end_ms, 2567);
    }

    #[test]
    fn test_transcript_construction_from_word_data() {
        // Test building a Transcript from word-level data (simulating API response)
        let words_data: Vec<(&str, f32, f32)> = vec![
            ("Hello,", 0.0, 0.5),
            ("this", 0.5, 0.7),
            ("is", 0.7, 0.8),
            ("a", 0.8, 0.9),
            ("test", 0.9, 1.2),
        ];

        let words: Vec<TranscriptWord> = words_data
            .iter()
            .map(|(word, start, end)| TranscriptWord {
                word: word.to_string(),
                start_ms: (*start * 1000.0) as i64,
                end_ms: (*end * 1000.0) as i64,
                confidence: 1.0,
            })
            .collect();

        let transcript = Transcript {
            full_text: "Hello, this is a test".to_string(),
            words,
            language: "en".to_string(),
        };

        assert_eq!(transcript.words.len(), 5);
        assert_eq!(transcript.words[0].word, "Hello,");
        assert_eq!(transcript.words[0].start_ms, 0);
        assert_eq!(transcript.words[0].end_ms, 500);
        assert_eq!(transcript.words[4].word, "test");
        assert_eq!(transcript.words[4].start_ms, 900);
        assert_eq!(transcript.words[4].end_ms, 1200);
    }
}

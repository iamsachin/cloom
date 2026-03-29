use crate::ai::transcribe::TranscriptWord;

/// A detected filler word or phrase with its occurrence count.
#[derive(Debug, Clone, uniffi::Record)]
pub struct FillerWord {
    pub word: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub count: i32,
}

/// Single-word fillers (case-insensitive match).
const SINGLE_FILLERS: &[&str] = &[
    "um", "uh", "umm", "hmm", "like", "basically", "actually", "right", "so",
];

/// Multi-word fillers (matched via sliding window).
const MULTI_FILLERS: &[&str] = &["you know", "i mean", "sort of", "kind of"];

/// Returns the default single-word filler list.
#[uniffi::export]
pub fn default_filler_words() -> Vec<String> {
    SINGLE_FILLERS.iter().map(|s| s.to_string()).collect()
}

/// Returns the default multi-word filler phrases.
#[uniffi::export]
pub fn default_filler_phrases() -> Vec<String> {
    MULTI_FILLERS.iter().map(|s| s.to_string()).collect()
}

/// Identify filler words in a transcript word list.
///
/// Returns one `FillerWord` entry per detected occurrence. The `count` field
/// is always 1 for individual detections — aggregate counts per filler type
/// can be computed on the Swift side if needed.
#[uniffi::export]
pub fn identify_filler_words(words: Vec<TranscriptWord>) -> Vec<FillerWord> {
    identify_filler_words_custom(words, vec![], vec![], 0.0)
}

/// Identify filler words with custom word lists and a confidence threshold.
///
/// - `custom_singles`: overrides the default single-word filler list (empty = use defaults).
/// - `custom_phrases`: overrides the default multi-word filler list (empty = use defaults).
/// - `min_confidence`: skip words whose `confidence` is below this value (0.0 = no filtering).
#[uniffi::export]
pub fn identify_filler_words_custom(
    words: Vec<TranscriptWord>,
    custom_singles: Vec<String>,
    custom_phrases: Vec<String>,
    min_confidence: f32,
) -> Vec<FillerWord> {
    let singles: Vec<&str> = if custom_singles.is_empty() {
        SINGLE_FILLERS.to_vec()
    } else {
        custom_singles.iter().map(|s| s.as_str()).collect()
    };
    let phrases: Vec<&str> = if custom_phrases.is_empty() {
        MULTI_FILLERS.to_vec()
    } else {
        custom_phrases.iter().map(|s| s.as_str()).collect()
    };

    let mut results = Vec::with_capacity(words.len() / 5);

    // Pre-compute cleaned/lowercased words once to avoid redundant allocations
    let cleaned: Vec<String> = words
        .iter()
        .map(|w| w.word.trim_matches(|c: char| !c.is_alphanumeric()).to_lowercase())
        .collect();

    // Single-word fillers
    for (i, lower) in cleaned.iter().enumerate() {
        if min_confidence > 0.0 && words[i].confidence < min_confidence {
            continue;
        }
        if singles.contains(&lower.as_str()) {
            results.push(FillerWord {
                word: lower.clone(),
                start_ms: words[i].start_ms,
                end_ms: words[i].end_ms,
                count: 1,
            });
        }
    }

    // Multi-word fillers (sliding window of 2-3 words) using pre-computed lowercase
    for window_size in 2..=3 {
        if cleaned.len() < window_size {
            continue;
        }
        for i in 0..=(cleaned.len() - window_size) {
            // Skip if any word in the window is below confidence threshold
            if min_confidence > 0.0
                && words[i..i + window_size]
                    .iter()
                    .any(|w| w.confidence < min_confidence)
            {
                continue;
            }
            let phrase: String = cleaned[i..i + window_size].join(" ");

            if phrases.contains(&phrase.as_str()) {
                results.push(FillerWord {
                    word: phrase,
                    start_ms: words[i].start_ms,
                    end_ms: words[i + window_size - 1].end_ms,
                    count: 1,
                });
            }
        }
    }

    // Sort by start time
    results.sort_by_key(|f| f.start_ms);
    results
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_word(word: &str, start_ms: i64, end_ms: i64) -> TranscriptWord {
        TranscriptWord {
            word: word.to_string(),
            start_ms,
            end_ms,
            confidence: 1.0,
        }
    }

    #[test]
    fn test_single_fillers() {
        let words = vec![
            make_word("Hello", 0, 500),
            make_word("um", 500, 800),
            make_word("how", 800, 1000),
            make_word("uh", 1000, 1200),
            make_word("are", 1200, 1500),
            make_word("you", 1500, 1800),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 2);
        assert_eq!(fillers[0].word, "um");
        assert_eq!(fillers[1].word, "uh");
    }

    #[test]
    fn test_multi_word_fillers() {
        let words = vec![
            make_word("I", 0, 200),
            make_word("you", 200, 400),
            make_word("know", 400, 600),
            make_word("think", 600, 900),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 1);
        assert_eq!(fillers[0].word, "you know");
        assert_eq!(fillers[0].start_ms, 200);
        assert_eq!(fillers[0].end_ms, 600);
    }

    #[test]
    fn test_case_insensitive() {
        let words = vec![
            make_word("Um", 0, 300),
            make_word("Like", 300, 600),
            make_word("BASICALLY", 600, 1000),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 3);
    }

    #[test]
    fn test_empty_input() {
        let fillers = identify_filler_words(vec![]);
        assert!(fillers.is_empty());
    }

    #[test]
    fn test_punctuation_stripping() {
        let words = vec![
            make_word("\"um,\"", 0, 300),
            make_word("(like)", 300, 600),
            make_word("so.", 600, 900),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 3);
        assert_eq!(fillers[0].word, "um");
        assert_eq!(fillers[1].word, "like");
        assert_eq!(fillers[2].word, "so");
    }

    #[test]
    fn test_all_single_fillers() {
        let all_fillers = ["um", "uh", "umm", "hmm", "like", "basically", "actually", "right", "so"];
        let words: Vec<TranscriptWord> = all_fillers
            .iter()
            .enumerate()
            .map(|(i, w)| make_word(w, (i * 500) as i64, ((i + 1) * 500) as i64))
            .collect();
        let fillers = identify_filler_words(words);
        // "so" + "right" may also appear in multi-word checks but single fillers should be 9
        let single_count = fillers.iter().filter(|f| !f.word.contains(' ')).count();
        assert_eq!(single_count, 9);
    }

    #[test]
    fn test_all_multi_fillers() {
        let words = vec![
            make_word("you", 0, 200),
            make_word("know", 200, 400),
            make_word("I", 500, 600),
            make_word("mean", 600, 800),
            make_word("sort", 900, 1000),
            make_word("of", 1000, 1100),
            make_word("kind", 1200, 1300),
            make_word("of", 1300, 1400),
        ];
        let fillers = identify_filler_words(words);
        let multi_count = fillers.iter().filter(|f| f.word.contains(' ')).count();
        assert_eq!(multi_count, 4);
    }

    #[test]
    fn test_no_fillers_in_clean_speech() {
        let words = vec![
            make_word("The", 0, 200),
            make_word("quick", 200, 400),
            make_word("brown", 400, 600),
            make_word("fox", 600, 800),
            make_word("jumps", 800, 1000),
        ];
        let fillers = identify_filler_words(words);
        assert!(fillers.is_empty());
    }

    #[test]
    fn test_consecutive_fillers() {
        let words = vec![
            make_word("um", 0, 200),
            make_word("uh", 200, 400),
            make_word("like", 400, 600),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 3);
    }

    #[test]
    fn test_single_word_input() {
        let words = vec![make_word("um", 0, 300)];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 1);
        assert_eq!(fillers[0].word, "um");
    }

    #[test]
    fn test_sorted_by_start_ms() {
        let words = vec![
            make_word("hello", 0, 500),
            make_word("uh", 500, 700),
            make_word("you", 700, 900),
            make_word("know", 900, 1100),
            make_word("um", 1100, 1400),
        ];
        let fillers = identify_filler_words(words);
        for i in 1..fillers.len() {
            assert!(fillers[i].start_ms >= fillers[i - 1].start_ms);
        }
    }

    #[test]
    fn test_filler_count_always_one() {
        let words = vec![
            make_word("um", 0, 300),
            make_word("um", 300, 600),
        ];
        let fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), 2);
        for f in &fillers {
            assert_eq!(f.count, 1);
        }
    }

    // --- Tests for identify_filler_words_custom ---

    fn make_word_conf(word: &str, start_ms: i64, end_ms: i64, confidence: f32) -> TranscriptWord {
        TranscriptWord {
            word: word.to_string(),
            start_ms,
            end_ms,
            confidence,
        }
    }

    #[test]
    fn test_custom_singles_override() {
        let words = vec![
            make_word("um", 0, 300),
            make_word("well", 300, 600),
            make_word("like", 600, 900),
        ];
        // Custom list: only "well" is a filler
        let fillers = identify_filler_words_custom(
            words,
            vec!["well".to_string()],
            vec![],
            0.0,
        );
        assert_eq!(fillers.len(), 1);
        assert_eq!(fillers[0].word, "well");
    }

    #[test]
    fn test_custom_phrases_override() {
        let words = vec![
            make_word("you", 0, 200),
            make_word("know", 200, 400),
            make_word("at", 500, 600),
            make_word("the", 600, 700),
            make_word("end", 700, 800),
            make_word("of", 800, 900),
            make_word("the", 900, 1000),
            make_word("day", 1000, 1100),
        ];
        let fillers = identify_filler_words_custom(
            words,
            vec![],
            vec!["at the end".to_string()],
            0.0,
        );
        // "you know" should NOT match (custom phrases override defaults)
        // "at the end" should match (3-word window)
        assert_eq!(fillers.len(), 1);
        assert_eq!(fillers[0].word, "at the end");
    }

    #[test]
    fn test_confidence_filters_low_confidence_singles() {
        let words = vec![
            make_word_conf("um", 0, 300, 0.9),
            make_word_conf("uh", 300, 600, 0.3),
            make_word_conf("like", 600, 900, 0.8),
        ];
        let fillers = identify_filler_words_custom(words, vec![], vec![], 0.5);
        assert_eq!(fillers.len(), 2);
        assert_eq!(fillers[0].word, "um");
        assert_eq!(fillers[1].word, "like");
    }

    #[test]
    fn test_confidence_filters_low_confidence_phrases() {
        let words = vec![
            make_word_conf("you", 0, 200, 0.9),
            make_word_conf("know", 200, 400, 0.2), // low confidence
            make_word_conf("I", 500, 600, 0.8),
            make_word_conf("mean", 600, 800, 0.7),
        ];
        let fillers = identify_filler_words_custom(words, vec![], vec![], 0.5);
        // "you know" skipped (one word below threshold), "i mean" matches
        assert_eq!(fillers.len(), 1);
        assert_eq!(fillers[0].word, "i mean");
    }

    #[test]
    fn test_confidence_zero_disables_filtering() {
        let words = vec![
            make_word_conf("um", 0, 300, 0.1),
            make_word_conf("uh", 300, 600, 0.01),
        ];
        let fillers = identify_filler_words_custom(words, vec![], vec![], 0.0);
        assert_eq!(fillers.len(), 2);
    }

    #[test]
    fn test_custom_empty_lists_use_defaults() {
        let words = vec![make_word("um", 0, 300), make_word("uh", 300, 600)];
        let fillers = identify_filler_words_custom(words.clone(), vec![], vec![], 0.0);
        let default_fillers = identify_filler_words(words);
        assert_eq!(fillers.len(), default_fillers.len());
    }

    #[test]
    fn test_default_filler_words_returns_all() {
        let defaults = default_filler_words();
        assert_eq!(defaults.len(), 9);
        assert!(defaults.contains(&"um".to_string()));
        assert!(defaults.contains(&"like".to_string()));
    }

    #[test]
    fn test_default_filler_phrases_returns_all() {
        let defaults = default_filler_phrases();
        assert_eq!(defaults.len(), 4);
        assert!(defaults.contains(&"you know".to_string()));
        assert!(defaults.contains(&"i mean".to_string()));
    }
}

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

/// Identify filler words in a transcript word list.
///
/// Returns one `FillerWord` entry per detected occurrence. The `count` field
/// is always 1 for individual detections — aggregate counts per filler type
/// can be computed on the Swift side if needed.
#[uniffi::export]
pub fn identify_filler_words(words: Vec<TranscriptWord>) -> Vec<FillerWord> {
    let mut results = Vec::new();

    // Single-word fillers
    for w in &words {
        let lower = w.word.trim_matches(|c: char| !c.is_alphanumeric()).to_lowercase();
        if SINGLE_FILLERS.contains(&lower.as_str()) {
            results.push(FillerWord {
                word: lower,
                start_ms: w.start_ms,
                end_ms: w.end_ms,
                count: 1,
            });
        }
    }

    // Multi-word fillers (sliding window of 2-3 words)
    for window_size in 2..=3 {
        if words.len() < window_size {
            continue;
        }
        for i in 0..=(words.len() - window_size) {
            let phrase: String = words[i..i + window_size]
                .iter()
                .map(|w| {
                    w.word
                        .trim_matches(|c: char| !c.is_alphanumeric())
                        .to_lowercase()
                })
                .collect::<Vec<_>>()
                .join(" ");

            if MULTI_FILLERS.contains(&phrase.as_str()) {
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
}

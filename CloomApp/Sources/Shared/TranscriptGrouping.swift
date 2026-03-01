import Foundation

// MARK: - Caption Phrases

struct CaptionPhrase: Identifiable, Sendable {
    let id = UUID()
    let words: [TranscriptWordSnapshot]
    let startMs: Int64
    let endMs: Int64
}

/// Group transcript words into display phrases (max 7 words or 3s span).
func buildCaptionPhrases(from words: [TranscriptWordSnapshot]) -> [CaptionPhrase] {
    guard !words.isEmpty else { return [] }
    var phrases: [CaptionPhrase] = []
    var current: [TranscriptWordSnapshot] = []
    var phraseStartMs: Int64 = words[0].startMs

    for word in words {
        current.append(word)
        let elapsed = word.endMs - phraseStartMs
        if current.count >= 7 || elapsed >= 3000 {
            let phrase = CaptionPhrase(
                words: current,
                startMs: phraseStartMs,
                endMs: word.endMs
            )
            phrases.append(phrase)
            current = []
            phraseStartMs = word.endMs
        }
    }

    if !current.isEmpty, let lastWord = current.last {
        phrases.append(CaptionPhrase(
            words: current,
            startMs: phraseStartMs,
            endMs: lastWord.endMs
        ))
    }

    return phrases
}

// MARK: - Transcript Sentences

struct TranscriptSentence: Identifiable {
    let id = UUID()
    let words: [TranscriptWordSnapshot]
    let isParagraphStart: Bool

    init(words: [TranscriptWordSnapshot], isParagraphStart: Bool = false) {
        self.words = words
        self.isParagraphStart = isParagraphStart
    }
}

/// Group transcript words into sentences by punctuation / paragraph boundaries (max 18 words).
func groupTranscriptIntoSentences(_ words: [TranscriptWordSnapshot]) -> [TranscriptSentence] {
    guard !words.isEmpty else { return [] }
    var sentences: [TranscriptSentence] = []
    var current: [TranscriptWordSnapshot] = []
    var paragraphStart = false

    for word in words {
        if word.isParagraphStart && !current.isEmpty {
            sentences.append(TranscriptSentence(words: current, isParagraphStart: paragraphStart))
            current = []
            paragraphStart = true
        } else if word.isParagraphStart {
            paragraphStart = true
        }

        current.append(word)
        let trimmed = word.word.trimmingCharacters(in: .whitespaces)
        let endsWithPunctuation = trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
        if endsWithPunctuation || current.count >= 18 {
            sentences.append(TranscriptSentence(words: current, isParagraphStart: paragraphStart))
            current = []
            paragraphStart = false
        }
    }
    if !current.isEmpty {
        sentences.append(TranscriptSentence(words: current, isParagraphStart: paragraphStart))
    }
    return sentences
}

import Testing
@testable import Cloom

// MARK: - Task 159: Caption & Transcript Grouping Tests

// MARK: Helpers

private func makeWord(
    _ text: String,
    startMs: Int64,
    endMs: Int64,
    isFillerWord: Bool = false,
    isParagraphStart: Bool = false
) -> TranscriptWordSnapshot {
    TranscriptWordSnapshot(
        word: text,
        startMs: startMs,
        endMs: endMs,
        confidence: 1.0,
        isFillerWord: isFillerWord,
        isParagraphStart: isParagraphStart
    )
}

// MARK: - CaptionOverlayView.buildPhrases

@Suite("CaptionOverlayView.buildPhrases")
struct CaptionBuildPhrasesTests {

    @Test func emptyInput() {
        let result = CaptionOverlayView.buildPhrases(from: [])
        #expect(result.isEmpty)
    }

    @Test func singleWord() {
        let words = [makeWord("Hello", startMs: 0, endMs: 500)]
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 1)
        #expect(result[0].words.count == 1)
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 500)
    }

    @Test func sevenWordsExact() {
        // 7 words within time limit → 1 phrase
        let words = (0..<7).map { i in
            makeWord("w\(i)", startMs: Int64(i * 100), endMs: Int64(i * 100 + 100))
        }
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 1)
        #expect(result[0].words.count == 7)
    }

    @Test func eightWordsBreaksAtSeven() {
        // 8 words → first phrase has 7, second has 1
        let words = (0..<8).map { i in
            makeWord("w\(i)", startMs: Int64(i * 100), endMs: Int64(i * 100 + 100))
        }
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 2)
        #expect(result[0].words.count == 7)
        #expect(result[1].words.count == 1)
    }

    @Test func fourteenWordsTwoPhrases() {
        let words = (0..<14).map { i in
            makeWord("w\(i)", startMs: Int64(i * 100), endMs: Int64(i * 100 + 100))
        }
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 2)
        #expect(result[0].words.count == 7)
        #expect(result[1].words.count == 7)
    }

    @Test func timeThresholdBreaks() {
        // 3 words spanning >3000ms → should break at time threshold
        let words = [
            makeWord("one", startMs: 0, endMs: 1000),
            makeWord("two", startMs: 1000, endMs: 2000),
            makeWord("three", startMs: 2000, endMs: 3100), // elapsed >= 3000
        ]
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 1) // 3 words, elapsed = 3100 - 0 = 3100 >= 3000 → break after word 3
        #expect(result[0].words.count == 3)
    }

    @Test func timeThresholdCreatesMultiplePhrases() {
        // Words spread far apart: each triggers time threshold
        let words = [
            makeWord("one", startMs: 0, endMs: 500),
            makeWord("two", startMs: 500, endMs: 1000),
            makeWord("three", startMs: 1000, endMs: 3200), // elapsed = 3200 >= 3000 → break
            makeWord("four", startMs: 3200, endMs: 6500),  // elapsed = 6500 - 3200 = 3300 >= 3000 → break
        ]
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 2)
        #expect(result[0].words.count == 3)
        #expect(result[1].words.count == 1)
    }

    @Test func phraseTimingCorrect() {
        let words = [
            makeWord("a", startMs: 100, endMs: 200),
            makeWord("b", startMs: 200, endMs: 300),
        ]
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 1)
        #expect(result[0].startMs == 100)
        #expect(result[0].endMs == 300)
    }

    @Test func nextPhraseStartsAtPreviousEnd() {
        // After a break, the next phrase's startMs = previous phrase's endMs
        let words = (0..<8).map { i in
            makeWord("w\(i)", startMs: Int64(i * 100), endMs: Int64(i * 100 + 100))
        }
        let result = CaptionOverlayView.buildPhrases(from: words)
        #expect(result.count == 2)
        #expect(result[1].startMs == result[0].endMs)
    }
}

// MARK: - TranscriptPanelView.groupIntoSentences

@Suite("TranscriptPanelView.groupIntoSentences")
struct GroupIntoSentencesTests {

    @Test func emptyInput() {
        let result = TranscriptPanelView.groupIntoSentences([])
        #expect(result.isEmpty)
    }

    @Test func singleWordNoPunctuation() {
        let words = [makeWord("hello", startMs: 0, endMs: 500)]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 1)
        #expect(result[0].words.count == 1)
    }

    @Test func periodBreaksSentence() {
        let words = [
            makeWord("Hello.", startMs: 0, endMs: 500),
            makeWord("World", startMs: 500, endMs: 1000),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 2)
        #expect(result[0].words.count == 1)
        #expect(result[1].words.count == 1)
    }

    @Test func questionMarkBreaksSentence() {
        let words = [
            makeWord("Why?", startMs: 0, endMs: 500),
            makeWord("Because", startMs: 500, endMs: 1000),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 2)
    }

    @Test func exclamationMarkBreaksSentence() {
        let words = [
            makeWord("Wow!", startMs: 0, endMs: 500),
            makeWord("Amazing", startMs: 500, endMs: 1000),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 2)
    }

    @Test func overflowAtEighteenWords() {
        // 20 words without punctuation → breaks at 18
        let words = (0..<20).map { i in
            makeWord("word\(i)", startMs: Int64(i * 100), endMs: Int64(i * 100 + 100))
        }
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 2)
        #expect(result[0].words.count == 18)
        #expect(result[1].words.count == 2)
    }

    @Test func paragraphBoundaryFlushes() {
        let words = [
            makeWord("end", startMs: 0, endMs: 500),
            makeWord("start", startMs: 500, endMs: 1000, isParagraphStart: true),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 2)
        #expect(result[0].isParagraphStart == false)
        #expect(result[1].isParagraphStart == true)
    }

    @Test func paragraphStartOnFirstWord() {
        // First word is paragraph start + no current words to flush
        let words = [
            makeWord("begin", startMs: 0, endMs: 500, isParagraphStart: true),
            makeWord("continue", startMs: 500, endMs: 1000),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        #expect(result.count == 1)
        #expect(result[0].isParagraphStart == true)
        #expect(result[0].words.count == 2)
    }

    @Test func multipleParagraphs() {
        let words = [
            makeWord("a.", startMs: 0, endMs: 500),
            makeWord("b", startMs: 500, endMs: 1000, isParagraphStart: true),
            makeWord("c.", startMs: 1000, endMs: 1500),
            makeWord("d", startMs: 1500, endMs: 2000, isParagraphStart: true),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        // "a." → sentence 1 (period break), "b" "c." → sentence 2 (paragraph start + period), "d" → sentence 3 (paragraph)
        #expect(result.count == 3)
        #expect(result[0].isParagraphStart == false)
        #expect(result[1].isParagraphStart == true)
        #expect(result[2].isParagraphStart == true)
    }

    @Test func whitespaceAroundPunctuation() {
        // Word with trailing space before punctuation
        let words = [
            makeWord("hello. ", startMs: 0, endMs: 500),
            makeWord("world", startMs: 500, endMs: 1000),
        ]
        let result = TranscriptPanelView.groupIntoSentences(words)
        // trimmed = "hello." which ends with "."
        #expect(result.count == 2)
    }
}

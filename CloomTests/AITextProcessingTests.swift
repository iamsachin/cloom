import Testing
@testable import Cloom

// MARK: - Task 160: AI Orchestrator Text Processing Tests

@Suite("AIOrchestrator.buildTimestampedTranscript")
struct BuildTimestampedTranscriptTests {

    private func makeWord(_ text: String, startMs: Int64, endMs: Int64) -> TranscriptWord {
        TranscriptWord(word: text, startMs: startMs, endMs: endMs, confidence: 1.0)
    }

    @Test func emptyInput() {
        let result = AIOrchestrator.buildTimestampedTranscript(from: [])
        #expect(result == "")
    }

    @Test func singleWord() {
        let words = [makeWord("hello", startMs: 0, endMs: 500)]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        #expect(result == "[0:00.0] hello")
    }

    @Test func timestampEvery2Seconds() {
        let words = [
            makeWord("one", startMs: 0, endMs: 500),
            makeWord("two", startMs: 500, endMs: 1000),
            makeWord("three", startMs: 1000, endMs: 1500),
            makeWord("four", startMs: 2000, endMs: 2500), // 2000ms gap from first → new timestamp
        ]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        #expect(result.contains("[0:00.0]"))
        #expect(result.contains("[0:02.0]"))
    }

    @Test func noTimestampWithinThreshold() {
        // Words within 2s of last timestamp → no new timestamp
        let words = [
            makeWord("one", startMs: 0, endMs: 500),
            makeWord("two", startMs: 1900, endMs: 2000),
        ]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        // Only one timestamp marker
        let timestampCount = result.components(separatedBy: "[").count - 1
        #expect(timestampCount == 1)
    }

    @Test func minuteFormatting() {
        // 65 seconds = 1:05
        let words = [makeWord("late", startMs: 65_000, endMs: 66_000)]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        #expect(result.contains("[1:05.0]"))
    }

    @Test func tenthsFormatting() {
        // 1500ms = 0:01.5
        let words = [makeWord("word", startMs: 1500, endMs: 2000)]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        #expect(result.contains("[0:01.5]"))
    }

    @Test func trailingWhitspaceTrimmed() {
        let words = [makeWord("end", startMs: 0, endMs: 500)]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        #expect(!result.hasSuffix(" "))
    }

    @Test func multipleTimestampBlocks() {
        let words = [
            makeWord("a", startMs: 0, endMs: 500),
            makeWord("b", startMs: 2000, endMs: 2500),
            makeWord("c", startMs: 4000, endMs: 4500),
        ]
        let result = AIOrchestrator.buildTimestampedTranscript(from: words)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
    }
}

@Suite("AIOrchestrator.findParagraphStartIndices")
struct FindParagraphStartIndicesTests {

    @Test func nilTextReturnsEmpty() {
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b"], paragraphedText: nil
        )
        #expect(result.isEmpty)
    }

    @Test func singleParagraphReturnsEmpty() {
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b", "c"],
            paragraphedText: "a b c"
        )
        #expect(result.isEmpty)
    }

    @Test func twoParagraphs() {
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b", "c", "d", "e"],
            paragraphedText: "a b\n\nc d e"
        )
        #expect(result == Set([2]))
    }

    @Test func threeParagraphs() {
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b", "c", "d", "e", "f"],
            paragraphedText: "a b\n\nc d\n\ne f"
        )
        #expect(result == Set([2, 4]))
    }

    @Test func emptyParagraphsFiltered() {
        // Multiple \n\n in a row → empty paragraphs filtered
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b", "c", "d"],
            paragraphedText: "a b\n\n\n\nc d"
        )
        #expect(result == Set([2]))
    }

    @Test func outOfBoundsIndicesFiltered() {
        // paragraphedText has more words than originalWords
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b"],
            paragraphedText: "a b\n\nc d e f"
        )
        #expect(result == Set([2]) || result.isEmpty) // 2 is out of bounds for 2-word array
        // Index 2 >= count(2) → filtered out
        #expect(result.isEmpty)
    }

    @Test func firstParagraphNeverInSet() {
        let result = AIOrchestrator.findParagraphStartIndices(
            originalWords: ["a", "b", "c"],
            paragraphedText: "a\n\nb c"
        )
        // paraIdx 0 is skipped, paraIdx 1 at wordIndex 1
        #expect(result == Set([1]))
        #expect(!result.contains(0))
    }
}

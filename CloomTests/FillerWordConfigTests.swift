import Testing
@testable import Cloom

@Suite("Filler Word Configuration")
struct FillerWordConfigTests {

    // MARK: - Default Lists

    @Test func defaultFillerWordsReturnsExpectedCount() {
        let words = defaultFillerWords()
        #expect(words.count == 9)
        #expect(words.contains("um"))
        #expect(words.contains("like"))
        #expect(words.contains("basically"))
    }

    @Test func defaultFillerPhrasesReturnsExpectedCount() {
        let phrases = defaultFillerPhrases()
        #expect(phrases.count == 4)
        #expect(phrases.contains("you know"))
        #expect(phrases.contains("i mean"))
    }

    // MARK: - Custom Word Lists

    @Test func customSinglesOverrideDefaults() {
        let words = [
            TranscriptWord(word: "um", startMs: 0, endMs: 300, confidence: 1.0),
            TranscriptWord(word: "well", startMs: 300, endMs: 600, confidence: 1.0),
        ]
        let fillers = identifyFillerWordsCustom(
            words: words,
            customSingles: ["well"],
            customPhrases: [],
            minConfidence: 0.0
        )
        #expect(fillers.count == 1)
        #expect(fillers.first?.word == "well")
    }

    @Test func emptyCustomListsUseDefaults() {
        let words = [
            TranscriptWord(word: "um", startMs: 0, endMs: 300, confidence: 1.0),
        ]
        let custom = identifyFillerWordsCustom(
            words: words, customSingles: [], customPhrases: [], minConfidence: 0.0
        )
        let defaults = identifyFillerWords(words: words)
        #expect(custom.count == defaults.count)
    }

    // MARK: - Confidence Filtering

    @Test func confidenceFilterSkipsLowConfidenceWords() {
        let words = [
            TranscriptWord(word: "um", startMs: 0, endMs: 300, confidence: 0.9),
            TranscriptWord(word: "uh", startMs: 300, endMs: 600, confidence: 0.3),
            TranscriptWord(word: "like", startMs: 600, endMs: 900, confidence: 0.8),
        ]
        let fillers = identifyFillerWordsCustom(
            words: words, customSingles: [], customPhrases: [], minConfidence: 0.5
        )
        #expect(fillers.count == 2)
        #expect(fillers[0].word == "um")
        #expect(fillers[1].word == "like")
    }

    @Test func zeroConfidenceDetectsAll() {
        let words = [
            TranscriptWord(word: "um", startMs: 0, endMs: 300, confidence: 0.01),
            TranscriptWord(word: "uh", startMs: 300, endMs: 600, confidence: 0.1),
        ]
        let fillers = identifyFillerWordsCustom(
            words: words, customSingles: [], customPhrases: [], minConfidence: 0.0
        )
        #expect(fillers.count == 2)
    }

    @Test func confidenceFilterAppliesToPhrases() {
        let words = [
            TranscriptWord(word: "you", startMs: 0, endMs: 200, confidence: 0.9),
            TranscriptWord(word: "know", startMs: 200, endMs: 400, confidence: 0.2),
        ]
        let fillers = identifyFillerWordsCustom(
            words: words, customSingles: [], customPhrases: [], minConfidence: 0.5
        )
        // "you know" should be skipped because "know" is below threshold
        let phraseMatches = fillers.filter { $0.word.contains(" ") }
        #expect(phraseMatches.isEmpty)
    }

    // MARK: - UserDefaults Keys

    @Test func fillerUserDefaultsKeysExist() {
        #expect(UserDefaultsKeys.fillerWordsSingle == "fillerWordsSingle")
        #expect(UserDefaultsKeys.fillerWordsPhrases == "fillerWordsPhrases")
        #expect(UserDefaultsKeys.fillerMinConfidence == "fillerMinConfidence")
    }

    // MARK: - Backward Compatibility

    @Test func originalFunctionStillWorks() {
        let words = [
            TranscriptWord(word: "um", startMs: 0, endMs: 300, confidence: 1.0),
            TranscriptWord(word: "hello", startMs: 300, endMs: 600, confidence: 1.0),
            TranscriptWord(word: "uh", startMs: 600, endMs: 900, confidence: 1.0),
        ]
        let fillers = identifyFillerWords(words: words)
        #expect(fillers.count == 2)
        #expect(fillers[0].word == "um")
        #expect(fillers[1].word == "uh")
    }
}

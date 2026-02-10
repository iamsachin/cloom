import Foundation
import SwiftData

@Model
final class TranscriptRecord {
    @Attribute(.unique) var id: String
    var videoID: String
    var fullText: String
    var language: String

    @Relationship(deleteRule: .cascade) var words: [TranscriptWordRecord]
    @Relationship(inverse: \VideoRecord.transcript) var video: VideoRecord?

    init(
        id: String = UUID().uuidString,
        videoID: String,
        fullText: String,
        language: String = "en"
    ) {
        self.id = id
        self.videoID = videoID
        self.fullText = fullText
        self.language = language
        self.words = []
    }
}

@Model
final class TranscriptWordRecord {
    var word: String
    var startMs: Int64
    var endMs: Int64
    var confidence: Float
    var isFillerWord: Bool

    @Relationship(inverse: \TranscriptRecord.words) var transcript: TranscriptRecord?

    init(
        word: String,
        startMs: Int64,
        endMs: Int64,
        confidence: Float = 1.0,
        isFillerWord: Bool = false
    ) {
        self.word = word
        self.startMs = startMs
        self.endMs = endMs
        self.confidence = confidence
        self.isFillerWord = isFillerWord
    }
}

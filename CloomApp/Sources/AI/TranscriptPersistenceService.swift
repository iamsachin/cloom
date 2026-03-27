import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TranscriptPersistence")

/// Persists AI pipeline results (transcript, words, chapters, title, summary) to SwiftData.
enum TranscriptPersistenceService {
    @MainActor
    static func persist(
        videoRecordID: String,
        transcript: Transcript,
        paragraphedText: String?,
        fillerWords: [FillerWord],
        generatedTitle: String?,
        generatedSummary: String?,
        generatedChapters: [Chapter],
        silenceRanges: [TimeRange] = [],
        modelContainer: ModelContainer
    ) {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<VideoRecord> { $0.id == videoRecordID }
        var descriptor = FetchDescriptor<VideoRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let video = try? context.fetch(descriptor).first else {
            logger.error("Video record not found: \(videoRecordID)")
            return
        }

        let fillerSet = Set(fillerWords.map { "\($0.startMs)-\($0.endMs)" })

        let paragraphStartIndices = AIOrchestrator.findParagraphStartIndices(
            originalWords: transcript.words.map(\.word),
            paragraphedText: paragraphedText
        )

        let transcriptRecord = TranscriptRecord(
            videoID: videoRecordID,
            fullText: paragraphedText ?? transcript.fullText,
            language: transcript.language
        )
        context.insert(transcriptRecord)

        for (index, w) in transcript.words.enumerated() {
            let isFiller = fillerSet.contains("\(w.startMs)-\(w.endMs)")
            let wordRecord = TranscriptWordRecord(
                word: w.word,
                startMs: w.startMs,
                endMs: w.endMs,
                confidence: w.confidence,
                isFillerWord: isFiller,
                isParagraphStart: paragraphStartIndices.contains(index)
            )
            wordRecord.transcript = transcriptRecord
            context.insert(wordRecord)
        }

        video.transcript = transcriptRecord
        video.hasTranscript = true

        if let title = generatedTitle {
            video.title = title
        }
        if let summary = generatedSummary {
            video.summary = summary
        }

        for ch in generatedChapters {
            let chapterRecord = ChapterRecord(
                id: ch.id,
                title: ch.title,
                startMs: ch.startMs
            )
            chapterRecord.video = video
            context.insert(chapterRecord)
        }

        if !silenceRanges.isEmpty {
            video.silenceRanges = silenceRanges.map {
                SilenceRange(startMs: $0.startMs, endMs: $0.endMs)
            }
        }

        video.updatedAt = .now

        do {
            try context.save()
            logger.info("Persisted AI results for video \(videoRecordID)")
        } catch {
            logger.error("Failed to save AI results: \(error)")
        }
    }
}

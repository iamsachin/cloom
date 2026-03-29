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

        // Map punctuation from the LLM-formatted text back onto individual words
        let punctuatedWords = Self.mapPunctuationToWords(
            originalWords: transcript.words.map(\.word),
            formattedText: paragraphedText
        )

        let transcriptRecord = TranscriptRecord(
            videoID: videoRecordID,
            fullText: paragraphedText ?? transcript.fullText,
            language: transcript.language
        )
        context.insert(transcriptRecord)

        for (index, w) in transcript.words.enumerated() {
            let isFiller = fillerSet.contains("\(w.startMs)-\(w.endMs)")
            let displayWord = punctuatedWords[index]
            let wordRecord = TranscriptWordRecord(
                word: displayWord,
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

    /// Map punctuation from the LLM-formatted text back onto individual word records.
    /// Matches words by stripping punctuation, then preserves the formatted version.
    static func mapPunctuationToWords(
        originalWords: [String],
        formattedText: String?
    ) -> [String] {
        guard let text = formattedText else { return originalWords }

        // Split formatted text into words (ignore paragraph breaks and whitespace)
        let formattedWords = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Walk both arrays in sync, matching by lowercase stripped form
        var result: [String] = []
        var fmtIdx = 0

        for original in originalWords {
            let strippedOriginal = original.lowercased().trimmingCharacters(in: .punctuationCharacters)

            if fmtIdx < formattedWords.count {
                let strippedFormatted = formattedWords[fmtIdx].lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)

                if strippedOriginal == strippedFormatted {
                    // Words match — use the formatted version (with punctuation)
                    result.append(formattedWords[fmtIdx])
                    fmtIdx += 1
                } else {
                    // Mismatch (timestamp markers, etc.) — skip formatted words until we find a match
                    var found = false
                    for lookAhead in (fmtIdx + 1)..<min(fmtIdx + 5, formattedWords.count) {
                        let candidate = formattedWords[lookAhead].lowercased()
                            .trimmingCharacters(in: .punctuationCharacters)
                        if strippedOriginal == candidate {
                            result.append(formattedWords[lookAhead])
                            fmtIdx = lookAhead + 1
                            found = true
                            break
                        }
                    }
                    if !found {
                        result.append(original)
                        fmtIdx += 1
                    }
                }
            } else {
                result.append(original)
            }
        }

        return result
    }
}

import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "SubtitleExport")

// MARK: - SubtitlePhrase

struct SubtitlePhrase: Sendable {
    let text: String
    let startMs: Int64
    let endMs: Int64
}

// MARK: - SubtitleExportService

actor SubtitleExportService {

    /// Build subtitle phrases with EDL-adjusted timing (accounting for trim, cuts, speed).
    func buildPhrases(
        from words: [TranscriptWordSnapshot],
        edl: EDLSnapshot,
        totalDurationMs: Int64
    ) -> [SubtitlePhrase] {
        let captionPhrases = CaptionOverlayView.buildPhrases(from: words)
        let trimStart = edl.trimStartMs
        let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : totalDurationMs
        let cuts = edl.cuts.sorted { $0.startMs < $1.startMs }
        let speed = edl.speedMultiplier

        var result: [SubtitlePhrase] = []

        for phrase in captionPhrases {
            // Skip phrases entirely outside trim range
            guard phrase.endMs > trimStart && phrase.startMs < trimEnd else { continue }

            // Clamp to trim bounds
            let clampedStart = max(phrase.startMs, trimStart)
            let clampedEnd = min(phrase.endMs, trimEnd)

            // Check if phrase is entirely within a cut
            let isFullyCut = cuts.contains { clampedStart >= $0.startMs && clampedEnd <= $0.endMs }
            if isFullyCut { continue }

            // Map source time to composition time (subtract trim offset + cut durations before this point)
            let compositionStart = mapToCompositionTime(sourceMs: clampedStart, trimStart: trimStart, cuts: cuts, speed: speed)
            let compositionEnd = mapToCompositionTime(sourceMs: clampedEnd, trimStart: trimStart, cuts: cuts, speed: speed)

            guard compositionEnd > compositionStart else { continue }

            let text = phrase.words.map(\.word).joined(separator: " ")
            result.append(SubtitlePhrase(text: text, startMs: compositionStart, endMs: compositionEnd))
        }

        return result
    }

    // MARK: - Private Helpers

    private func mapToCompositionTime(
        sourceMs: Int64,
        trimStart: Int64,
        cuts: [CutRange],
        speed: Double
    ) -> Int64 {
        var offset = sourceMs - trimStart

        // Subtract duration of cuts that come before this source time
        for cut in cuts {
            let cutStart = max(cut.startMs, trimStart)
            let cutEnd = cut.endMs
            guard cutStart < sourceMs else { break }
            let effectiveEnd = min(cutEnd, sourceMs)
            if effectiveEnd > cutStart {
                offset -= (effectiveEnd - cutStart)
            }
        }

        // Apply speed
        if speed != 1.0 && speed > 0 {
            offset = Int64(Double(offset) / speed)
        }

        return max(0, offset)
    }
}

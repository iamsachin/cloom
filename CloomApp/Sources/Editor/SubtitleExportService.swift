import AVFoundation
import CoreImage
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "SubtitleExport")

// MARK: - SubtitleMode

enum SubtitleMode: String, CaseIterable, Identifiable {
    case none = "None"
    case hardBurn = "Hard Burn"
    case srtSidecar = "SRT File"
    case both = "Both"

    var id: String { rawValue }

    var needsHardBurn: Bool {
        self == .hardBurn || self == .both
    }

    var needsSRT: Bool {
        self == .srtSidecar || self == .both
    }
}

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

    /// Generate an SRT subtitle file.
    func generateSRT(phrases: [SubtitlePhrase], outputURL: URL) throws {
        var srt = ""
        for (index, phrase) in phrases.enumerated() {
            srt += "\(index + 1)\n"
            srt += "\(formatSRTTime(ms: phrase.startMs)) --> \(formatSRTTime(ms: phrase.endMs))\n"
            srt += "\(phrase.text)\n\n"
        }
        try srt.write(to: outputURL, atomically: true, encoding: .utf8)
        logger.info("Generated SRT with \(phrases.count) phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Hard-burn rendering (nonisolated for CIFilter handler)

    /// Pre-render all subtitle phrase images once. Call before export starts.
    /// Returns an array parallel to `phrases` — each entry is the rendered CIImage overlay.
    nonisolated static func prerenderImages(
        phrases: [SubtitlePhrase],
        videoWidth: CGFloat,
        videoHeight: CGFloat
    ) -> [CIImage?] {
        phrases.map { phrase in
            renderTextImage(text: phrase.text, videoWidth: videoWidth, videoHeight: videoHeight)
        }
    }

    /// Composite a pre-rendered subtitle image onto a video frame.
    /// Uses binary search to find the active phrase, then looks up its cached image.
    nonisolated static func burnSubtitle(
        onto source: CIImage,
        phrases: [SubtitlePhrase],
        cache: [CIImage?],
        frameTimeMs: Int64
    ) -> CIImage {
        guard let index = findActivePhraseIndex(in: phrases, at: frameTimeMs),
              index < cache.count,
              let textImage = cache[index] else {
            return source
        }
        return textImage.composited(over: source)
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

    private nonisolated static func findActivePhraseIndex(
        in phrases: [SubtitlePhrase],
        at timeMs: Int64
    ) -> Int? {
        var lo = 0
        var hi = phrases.count - 1

        while lo <= hi {
            let mid = (lo + hi) / 2
            let phrase = phrases[mid]
            if timeMs >= phrase.startMs && timeMs < phrase.endMs {
                return mid
            } else if timeMs < phrase.startMs {
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }
        return nil
    }

    private nonisolated static func renderTextImage(
        text: String,
        videoWidth: CGFloat,
        videoHeight: CGFloat
    ) -> CIImage? {
        let w = Int(videoWidth)
        let h = Int(videoHeight)
        let fontSize: CGFloat = max(16, videoHeight * 0.035)
        let padding: CGFloat = 12
        let bottomMargin: CGFloat = videoHeight * 0.06

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // Measure text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()

        let bgWidth = textSize.width + padding * 2
        let bgHeight = textSize.height + padding
        let bgRect = CGRect(
            x: (videoWidth - bgWidth) / 2,
            y: bottomMargin,
            width: bgWidth,
            height: bgHeight
        )

        // Draw background capsule
        let capsulePath = CGPath(roundedRect: bgRect, cornerWidth: bgHeight / 2, cornerHeight: bgHeight / 2, transform: nil)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.65))
        ctx.addPath(capsulePath)
        ctx.fillPath()

        // Draw text using NSGraphicsContext
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        let textOrigin = CGPoint(
            x: bgRect.origin.x + padding,
            y: bgRect.origin.y + (bgHeight - textSize.height) / 2
        )
        attrString.draw(at: textOrigin)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private func formatSRTTime(ms: Int64) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = ms % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}

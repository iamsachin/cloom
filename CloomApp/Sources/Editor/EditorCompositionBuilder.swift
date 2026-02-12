import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorCompositionBuilder")

struct CompositionResult: @unchecked Sendable {
    let composition: AVMutableComposition
    let duration: CMTime
}

/// Value type snapshot of EDL data for cross-actor use.
struct EDLSnapshot: Sendable {
    let trimStartMs: Int64
    let trimEndMs: Int64
    let cuts: [CutRange]
    let stitchVideoIDs: [String]
    let speedMultiplier: Double

    init(from edl: EditDecisionList) {
        self.trimStartMs = edl.trimStartMs
        self.trimEndMs = edl.trimEndMs
        self.cuts = edl.cuts
        self.stitchVideoIDs = edl.stitchVideoIDs
        self.speedMultiplier = edl.speedMultiplier
    }
}

actor EditorCompositionBuilder {
    enum BuildError: LocalizedError {
        case noVideoTrack
        case noSourceAsset
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "No video track found"
            case .noSourceAsset: "Source asset could not be loaded"
            case .exportFailed(let msg): "Export failed: \(msg)"
            }
        }
    }

    func build(
        edl: EDLSnapshot,
        sourceURL: URL,
        stitchURLs: [URL]
    ) async throws -> CompositionResult {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw BuildError.noVideoTrack }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        // Build time ranges from trim + cuts
        let sourceAsset = AVURLAsset(url: sourceURL)
        let sourceDuration = try await sourceAsset.load(.duration)
        let timeRanges = buildTimeRanges(edl: edl, totalDuration: sourceDuration)

        // Insert source segments
        var insertTime = CMTime.zero
        let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)

        for range in timeRanges {
            if let srcVideo = sourceVideoTracks.first {
                try videoTrack.insertTimeRange(range, of: srcVideo, at: insertTime)
            }
            if let srcAudio = sourceAudioTracks.first, let audioTrack {
                try audioTrack.insertTimeRange(range, of: srcAudio, at: insertTime)
            }
            insertTime = CMTimeAdd(insertTime, range.duration)
        }

        // Append stitched clips
        for stitchURL in stitchURLs {
            let asset = AVURLAsset(url: stitchURL)
            let duration = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: duration)

            let stitchVideoTracks = try await asset.loadTracks(withMediaType: .video)
            let stitchAudioTracks = try await asset.loadTracks(withMediaType: .audio)

            if let srcVideo = stitchVideoTracks.first {
                try videoTrack.insertTimeRange(range, of: srcVideo, at: insertTime)
            }
            if let srcAudio = stitchAudioTracks.first, let audioTrack {
                try audioTrack.insertTimeRange(range, of: srcAudio, at: insertTime)
            }
            insertTime = CMTimeAdd(insertTime, duration)
        }

        // Apply speed
        if edl.speedMultiplier != 1.0 {
            let currentDuration = composition.duration
            let scaledDuration = CMTimeMultiplyByFloat64(currentDuration, multiplier: 1.0 / edl.speedMultiplier)
            let fullRange = CMTimeRange(start: .zero, duration: currentDuration)
            composition.scaleTimeRange(fullRange, toDuration: scaledDuration)
        }

        logger.info("Built composition: \(timeRanges.count) ranges, \(stitchURLs.count) stitched, speed=\(edl.speedMultiplier)x")

        return CompositionResult(
            composition: composition,
            duration: composition.duration
        )
    }

    private func buildTimeRanges(edl: EDLSnapshot, totalDuration: CMTime) -> [CMTimeRange] {
        let totalMs = Int64(totalDuration.seconds * 1000)
        let trimStart = edl.trimStartMs
        let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : totalMs
        let cuts = edl.cuts.sorted { $0.startMs < $1.startMs }

        var ranges: [CMTimeRange] = []
        var currentMs = trimStart

        for cut in cuts {
            let cutStart = max(cut.startMs, trimStart)
            let cutEnd = min(cut.endMs, trimEnd)
            guard cutStart < cutEnd, cutStart > currentMs else { continue }

            let rangeStart = CMTime(value: CMTimeValue(currentMs), timescale: 1000)
            let rangeEnd = CMTime(value: CMTimeValue(cutStart), timescale: 1000)
            let range = CMTimeRange(start: rangeStart, duration: CMTimeSubtract(rangeEnd, rangeStart))
            if range.duration > .zero {
                ranges.append(range)
            }
            currentMs = cutEnd
        }

        if currentMs < trimEnd {
            let rangeStart = CMTime(value: CMTimeValue(currentMs), timescale: 1000)
            let rangeEnd = CMTime(value: CMTimeValue(trimEnd), timescale: 1000)
            let range = CMTimeRange(start: rangeStart, duration: CMTimeSubtract(rangeEnd, rangeStart))
            if range.duration > .zero {
                ranges.append(range)
            }
        }

        return ranges
    }
}

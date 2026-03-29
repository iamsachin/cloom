import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorCompositionBuilder")

struct CompositionResult: @unchecked Sendable {
    let composition: AVMutableComposition
    let duration: CMTime
    let audioMix: AVMutableAudioMix?
}

/// Value type snapshot of EDL data for cross-actor use.
struct EDLSnapshot: Sendable {
    let trimStartMs: Int64
    let trimEndMs: Int64
    let cuts: [CutRange]
    let stitchVideoIDs: [String]
    let blurRegions: [BlurRegion]
    let speedMultiplier: Double

    init(from edl: EditDecisionList) {
        self.trimStartMs = edl.trimStartMs
        self.trimEndMs = edl.trimEndMs
        self.cuts = edl.cuts
        self.stitchVideoIDs = edl.stitchVideoIDs
        self.blurRegions = edl.blurRegions
        self.speedMultiplier = edl.speedMultiplier
    }

    init(
        trimStartMs: Int64 = 0,
        trimEndMs: Int64 = 0,
        cuts: [CutRange] = [],
        stitchVideoIDs: [String] = [],
        blurRegions: [BlurRegion] = [],
        speedMultiplier: Double = 1.0
    ) {
        self.trimStartMs = trimStartMs
        self.trimEndMs = trimEndMs
        self.cuts = cuts
        self.stitchVideoIDs = stitchVideoIDs
        self.blurRegions = blurRegions
        self.speedMultiplier = speedMultiplier
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

        // Build time ranges from trim + cuts
        let sourceAsset = AVURLAsset(url: sourceURL)
        let sourceDuration = try await sourceAsset.load(.duration)
        let timeRanges = buildTimeRanges(edl: edl, totalDuration: sourceDuration)

        // Load ALL source audio tracks (e.g. Track 0 = system, Track 1 = mic)
        let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)

        // Create one composition audio track per source audio track
        var compAudioTracks: [AVMutableCompositionTrack] = []
        for _ in sourceAudioTracks {
            if let t = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                compAudioTracks.append(t)
            }
        }

        // Insert source segments
        var insertTime = CMTime.zero
        for range in timeRanges {
            if let srcVideo = sourceVideoTracks.first {
                try videoTrack.insertTimeRange(range, of: srcVideo, at: insertTime)
            }
            for (i, srcAudio) in sourceAudioTracks.enumerated() where i < compAudioTracks.count {
                try compAudioTracks[i].insertTimeRange(range, of: srcAudio, at: insertTime)
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
            for (i, srcAudio) in stitchAudioTracks.enumerated() {
                // Grow composition audio tracks if stitched clip has more tracks
                while i >= compAudioTracks.count {
                    if let t = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    ) {
                        compAudioTracks.append(t)
                    }
                }
                if i < compAudioTracks.count {
                    try compAudioTracks[i].insertTimeRange(range, of: srcAudio, at: insertTime)
                }
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

        // Build audio mix if multiple audio tracks (mixes down to stereo on export)
        let audioMix: AVMutableAudioMix? = compAudioTracks.count > 1
            ? .stereoMix(from: compAudioTracks)
            : nil

        logger.info("Built composition: \(timeRanges.count) ranges, \(compAudioTracks.count) audio tracks, \(stitchURLs.count) stitched, speed=\(edl.speedMultiplier)x")

        return CompositionResult(
            composition: composition,
            duration: composition.duration,
            audioMix: audioMix
        )
    }

    private func buildTimeRanges(edl: EDLSnapshot, totalDuration: CMTime) -> [CMTimeRange] {
        Self.buildTimeRanges(edl: edl, totalDurationMs: Int64(totalDuration.seconds * 1000))
    }

    static func buildTimeRanges(edl: EDLSnapshot, totalDurationMs: Int64) -> [CMTimeRange] {
        let trimStart = edl.trimStartMs
        let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : totalDurationMs
        let cuts = edl.cuts.sorted { $0.startMs < $1.startMs }

        var ranges: [CMTimeRange] = []
        var currentMs = trimStart

        for cut in cuts {
            let cutStart = max(cut.startMs, trimStart)
            let cutEnd = min(cut.endMs, trimEnd)
            guard cutStart < cutEnd else { continue }

            if cutStart > currentMs {
                let rangeStart = CMTime(value: CMTimeValue(currentMs), timescale: 1000)
                let rangeEnd = CMTime(value: CMTimeValue(cutStart), timescale: 1000)
                let range = CMTimeRange(start: rangeStart, duration: CMTimeSubtract(rangeEnd, rangeStart))
                if range.duration > .zero {
                    ranges.append(range)
                }
            }
            currentMs = max(currentMs, cutEnd)
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

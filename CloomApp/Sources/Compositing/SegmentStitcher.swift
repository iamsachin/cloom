import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "SegmentStitcher")

actor SegmentStitcher {
    enum StitchError: LocalizedError {
        case noSegments
        case noVideoTrack
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSegments: "No segments to stitch."
            case .noVideoTrack: "No video track found in segment."
            case .exportFailed(let reason): "Export failed: \(reason)"
            }
        }
    }

    func stitch(segments: [URL], to outputURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !segments.isEmpty else { throw StitchError.noSegments }

        if segments.count == 1 {
            // Single segment — just move it
            try FileManager.default.moveItem(at: segments[0], to: outputURL)
            progress(1.0)
            return
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw StitchError.noVideoTrack }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertTime = CMTime.zero
        let trackProgress = 0.7 // 70% for track insertion

        for (index, segmentURL) in segments.enumerated() {
            let asset = AVURLAsset(url: segmentURL)

            let duration: CMTime
            do {
                duration = try await asset.load(.duration)
            } catch {
                logger.error("Failed to load duration for segment \(index): \(error)")
                continue
            }

            let timeRange = CMTimeRange(start: .zero, duration: duration)

            // Insert video track
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                if let sourceVideoTrack = videoTracks.first {
                    try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
                }
            } catch {
                logger.error("Failed to insert video track for segment \(index): \(error)")
            }

            // Insert audio track(s)
            do {
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                for sourceAudioTrack in audioTracks {
                    if let audioTrack {
                        try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
                    }
                }
            } catch {
                logger.error("Failed to insert audio track for segment \(index): \(error)")
            }

            insertTime = CMTimeAdd(insertTime, duration)
            progress(trackProgress * Double(index + 1) / Double(segments.count))
        }

        // Export using modern API
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw StitchError.exportFailed("Could not create export session")
        }

        do {
            try await exportSession.export(to: outputURL, as: .mp4)
            progress(1.0)
            // Clean up temp segment files
            for segmentURL in segments {
                try? FileManager.default.removeItem(at: segmentURL)
            }
            logger.info("Stitched \(segments.count) segments → \(outputURL.lastPathComponent)")
        } catch {
            throw StitchError.exportFailed(error.localizedDescription)
        }
    }
}

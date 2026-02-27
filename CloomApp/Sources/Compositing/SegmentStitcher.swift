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

        // Always clean up temp segment files, even on failure
        defer {
            for segmentURL in segments {
                try? FileManager.default.removeItem(at: segmentURL)
            }
        }

        if segments.count == 1 {
            // Single segment — mixdown audio for web player compatibility
            try await mixdownAudio(inputURL: segments[0], to: outputURL)
            progress(1.0)
            return
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw StitchError.noVideoTrack }

        var compAudioTracks: [AVMutableCompositionTrack] = []
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

            // Insert all audio tracks (grow composition tracks as needed)
            do {
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                for (i, sourceAudioTrack) in audioTracks.enumerated() {
                    while i >= compAudioTracks.count {
                        if let t = composition.addMutableTrack(
                            withMediaType: .audio,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        ) {
                            compAudioTracks.append(t)
                        }
                    }
                    if i < compAudioTracks.count {
                        try compAudioTracks[i].insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
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

        // Apply audio mix for multi-track mixdown
        if compAudioTracks.count > 1 {
            let mix = AVMutableAudioMix()
            mix.inputParameters = compAudioTracks.map { track in
                let params = AVMutableAudioMixInputParameters(track: track)
                params.setVolume(1.0, at: .zero)
                return params
            }
            exportSession.audioMix = mix
        }

        do {
            try await exportSession.export(to: outputURL, as: .mp4)
            progress(1.0)
            logger.info("Stitched \(segments.count) segments → \(outputURL.lastPathComponent)")
        } catch {
            throw StitchError.exportFailed(error.localizedDescription)
        }
    }

    /// Mix down multiple audio tracks into a single stereo output for web player compatibility.
    /// If the file has <=1 audio track, just moves the file (no re-encode needed).
    func mixdownAudio(inputURL: URL, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        if audioTracks.count <= 1 {
            try FileManager.default.moveItem(at: inputURL, to: outputURL)
            return
        }

        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)

        // Copy video track
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if let srcVideo = videoTracks.first,
           let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compVideo.insertTimeRange(timeRange, of: srcVideo, at: .zero)
        }

        // Copy all audio tracks separately
        var compAudioTracks: [AVMutableCompositionTrack] = []
        for srcAudio in audioTracks {
            if let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try compAudio.insertTimeRange(timeRange, of: srcAudio, at: .zero)
                compAudioTracks.append(compAudio)
            }
        }

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            // Fallback: just move the file
            try FileManager.default.moveItem(at: inputURL, to: outputURL)
            return
        }

        // Mix all tracks to stereo
        let mix = AVMutableAudioMix()
        mix.inputParameters = compAudioTracks.map { track in
            let params = AVMutableAudioMixInputParameters(track: track)
            params.setVolume(1.0, at: .zero)
            return params
        }
        session.audioMix = mix

        try await session.export(to: outputURL, as: .mp4)

        // Clean up input file
        try? FileManager.default.removeItem(at: inputURL)
        logger.info("Mixed down \(audioTracks.count) audio tracks → \(outputURL.lastPathComponent)")
    }
}

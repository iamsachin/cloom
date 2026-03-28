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

    /// Stitch multiple segments into a single output file.
    /// Normalizes each segment to a temp file first (handles format differences),
    /// then concatenates via AVMutableComposition with passthrough export.
    func stitch(
        segments: [URL],
        effectiveDurations: [TimeInterval?] = [],
        to outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard !segments.isEmpty else { throw StitchError.noSegments }

        // Always clean up temp segment files, even on failure
        defer {
            for segmentURL in segments {
                try? FileManager.default.removeItem(at: segmentURL)
            }
        }

        if segments.count == 1 {
            try await mixdownAudio(inputURL: segments[0], to: outputURL)
            progress(1.0)
            return
        }

        // Step 1: Normalize each segment to a consistent format (mixdown audio)
        var normalizedURLs: [URL] = []
        for (index, url) in segments.enumerated() {
            let effectiveDur = (index < effectiveDurations.count) ? effectiveDurations[index] : nil
            let normalizedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cloom_norm_\(index)_\(UUID().uuidString).mp4")

            if let dur = effectiveDur {
                // Trim segment to effective duration first, then normalize
                try await normalizeSegment(
                    inputURL: url, to: normalizedURL,
                    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: dur, preferredTimescale: 600))
                )
            } else {
                try await normalizeSegment(inputURL: url, to: normalizedURL, timeRange: nil)
            }

            normalizedURLs.append(normalizedURL)
            progress(0.4 * Double(index + 1) / Double(segments.count))
        }

        // Step 2: Concatenate normalized segments via AVMutableComposition
        defer {
            for url in normalizedURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw StitchError.noVideoTrack }

        var audioTrack: AVMutableCompositionTrack?
        var insertTime = CMTime.zero

        for (index, url) in normalizedURLs.enumerated() {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let srcVideo = videoTracks.first {
                try videoTrack.insertTimeRange(timeRange, of: srcVideo, at: insertTime)
            }

            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let srcAudio = audioTracks.first {
                if audioTrack == nil {
                    audioTrack = composition.addMutableTrack(
                        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }
                try audioTrack?.insertTimeRange(timeRange, of: srcAudio, at: insertTime)
            }

            insertTime = CMTimeAdd(insertTime, duration)
            progress(0.4 + 0.3 * Double(index + 1) / Double(normalizedURLs.count))
        }

        // Step 3: Export with passthrough
        let metadata = try await loadSegmentMetadata(segments: normalizedURLs)
        let videoFmtHint = metadata.first?.videoFormatHint
        try await passthroughExport(asset: composition, audioMix: nil, to: outputURL, videoFormatHint: videoFmtHint)
        progress(1.0)
        logger.info("Stitched \(segments.count) segments → \(outputURL.lastPathComponent)")
    }

    /// Normalize a segment: mixdown all audio tracks to single stereo AAC, keep video passthrough.
    /// This ensures all segments have compatible formats for composition.
    private func normalizeSegment(inputURL: URL, to outputURL: URL, timeRange: CMTimeRange?) async throws {
        let asset = AVURLAsset(url: inputURL)
        let reader = try AVAssetReader(asset: asset)
        if let timeRange { reader.timeRange = timeRange }
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var trackPairs: [TrackPair] = []

        // Video: passthrough
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let formatHint = try await videoTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(
                mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint
            )
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            trackPairs.append(TrackPair(output: readerOutput, input: writerInput))
        }

        // Audio: mix all tracks down to single stereo AAC
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
            mixOutput.alwaysCopiesSampleData = false
            reader.add(mixOutput)
            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000,
            ])
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            trackPairs.append(TrackPair(output: mixOutput, input: writerInput))
        }

        guard reader.startReading() else {
            throw StitchError.exportFailed(reader.error?.localizedDescription ?? "Reader failed")
        }
        guard writer.startWriting() else {
            throw StitchError.exportFailed(writer.error?.localizedDescription ?? "Writer failed")
        }
        writer.startSession(atSourceTime: .zero)

        // Feed video + audio concurrently (avoids AVAssetWriter deadlock)
        await Self.copyTracksConcurrently(trackPairs)

        await writer.finishWriting()
        if let error = writer.error {
            throw StitchError.exportFailed(error.localizedDescription)
        }
    }

    /// Mix down multiple audio tracks into a single stereo output for web player compatibility.
    /// If the file has <=1 audio track, just moves the file (no re-encode needed).
    /// Uses video passthrough (no re-encode) — only the audio is re-encoded.
    func mixdownAudio(inputURL: URL, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        if audioTracks.count <= 1 {
            try FileManager.default.moveItem(at: inputURL, to: outputURL)
            return
        }

        // Build audio mix from source tracks
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioTracks.map { track in
            let params = AVMutableAudioMixInputParameters(track: track)
            params.setVolume(1.0, at: .zero)
            return params
        }

        try await passthroughExport(asset: asset, audioMix: mix, to: outputURL)

        // Clean up input file
        try? FileManager.default.removeItem(at: inputURL)
        logger.info("Mixed down \(audioTracks.count) audio tracks → \(outputURL.lastPathComponent)")
    }

    // MARK: - Passthrough Export (No Video Re-encode)

    /// Export using AVAssetReader/Writer with video passthrough + optional audio mixing.
    /// Much faster than AVAssetExportPresetHighestQuality which re-encodes everything.
    private func passthroughExport(
        asset: AVAsset,
        audioMix: AVAudioMix?,
        to outputURL: URL,
        videoFormatHint: CMFormatDescription? = nil
    ) async throws {
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var trackPairs: [TrackPair] = []

        // Video: passthrough (copy compressed bytes, no decode/re-encode)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            // Composition tracks may not expose formatDescriptions — use provided hint
            let loadedHint = try await videoTrack.load(.formatDescriptions).first
            let formatHint = videoFormatHint ?? loadedHint
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(
                mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint
            )
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            trackPairs.append(TrackPair(output: readerOutput, input: writerInput))
        }

        // Audio: mix if needed, otherwise passthrough first track
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let audioReaderOutput: AVAssetReaderOutput
            let audioWriterInput: AVAssetWriterInput

            if let audioMix, audioTracks.count > 1 {
                let mixOutput = AVAssetReaderAudioMixOutput(
                    audioTracks: audioTracks, audioSettings: nil
                )
                mixOutput.alwaysCopiesSampleData = false
                mixOutput.audioMix = audioMix
                audioReaderOutput = mixOutput
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000,
                ])
            } else {
                let trackOutput = AVAssetReaderTrackOutput(
                    track: audioTracks[0], outputSettings: nil
                )
                trackOutput.alwaysCopiesSampleData = false
                audioReaderOutput = trackOutput
                let formatHint = try await audioTracks[0].load(.formatDescriptions).first
                audioWriterInput = AVAssetWriterInput(
                    mediaType: .audio, outputSettings: nil, sourceFormatHint: formatHint
                )
            }

            audioWriterInput.expectsMediaDataInRealTime = false
            reader.add(audioReaderOutput)
            writer.add(audioWriterInput)
            trackPairs.append(TrackPair(output: audioReaderOutput, input: audioWriterInput))
        }

        guard reader.startReading() else {
            throw StitchError.exportFailed(reader.error?.localizedDescription ?? "Reader failed")
        }
        guard writer.startWriting() else {
            throw StitchError.exportFailed(writer.error?.localizedDescription ?? "Writer failed")
        }
        writer.startSession(atSourceTime: .zero)

        // Feed all tracks concurrently to avoid AVAssetWriter deadlocks
        await Self.copyTracksConcurrently(trackPairs)

        await writer.finishWriting()
        if let error = writer.error {
            throw StitchError.exportFailed(error.localizedDescription)
        }
    }

    // MARK: - Concurrent Track Copying

    private struct TrackPair: @unchecked Sendable {
        let output: AVAssetReaderOutput
        let input: AVAssetWriterInput
    }

    private static func copyTracksConcurrently(
        _ trackPairs: [TrackPair]
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for pair in trackPairs {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        let queue = DispatchQueue(label: "com.cloom.stitch.\(UUID().uuidString)")
                        pair.input.requestMediaDataWhenReady(on: queue) {
                            while pair.input.isReadyForMoreMediaData {
                                if let sample = pair.output.copyNextSampleBuffer() {
                                    pair.input.append(sample)
                                } else {
                                    pair.input.markAsFinished()
                                    continuation.resume()
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Parallel Metadata Loading

    private struct SegmentMetadata: @unchecked Sendable {
        let index: Int
        let duration: CMTime
        let videoTrack: AVAssetTrack?
        let audioTracks: [AVAssetTrack]
        let videoFormatHint: CMFormatDescription?
    }

    private func loadSegmentMetadata(segments: [URL]) async throws -> [SegmentMetadata] {
        try await withThrowingTaskGroup(of: SegmentMetadata.self) { group in
            for (index, url) in segments.enumerated() {
                group.addTask {
                    let asset = AVURLAsset(url: url)
                    let duration = try await asset.load(.duration)
                    let video = try await asset.loadTracks(withMediaType: .video)
                    let audio = try await asset.loadTracks(withMediaType: .audio)
                    let formatHint = try await video.first?.load(.formatDescriptions).first
                    return SegmentMetadata(
                        index: index, duration: duration,
                        videoTrack: video.first, audioTracks: audio,
                        videoFormatHint: formatHint
                    )
                }
            }
            var results: [SegmentMetadata] = []
            for try await m in group { results.append(m) }
            return results.sorted { $0.index < $1.index }
        }
    }
}

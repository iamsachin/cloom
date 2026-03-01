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

        // Load all segment metadata in parallel
        let metadata = try await loadSegmentMetadata(segments: segments)

        // Insert tracks sequentially (insertTime is cumulative)
        for (index, meta) in metadata.enumerated() {
            let timeRange = CMTimeRange(start: .zero, duration: meta.duration)

            // Insert video track
            if let sourceVideoTrack = meta.videoTrack {
                do {
                    try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
                } catch {
                    logger.error("Failed to insert video track for segment \(index): \(error)")
                }
            }

            // Insert all audio tracks (grow composition tracks as needed)
            for (i, sourceAudioTrack) in meta.audioTracks.enumerated() {
                while i >= compAudioTracks.count {
                    if let t = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    ) {
                        compAudioTracks.append(t)
                    }
                }
                if i < compAudioTracks.count {
                    do {
                        try compAudioTracks[i].insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
                    } catch {
                        logger.error("Failed to insert audio track \(i) for segment \(index): \(error)")
                    }
                }
            }

            insertTime = CMTimeAdd(insertTime, meta.duration)
            progress(trackProgress * Double(index + 1) / Double(segments.count))
        }

        // Export with video passthrough + optional audio mix (no video re-encode)
        let audioMix: AVMutableAudioMix? = compAudioTracks.count > 1
            ? .stereoMix(from: compAudioTracks) : nil

        try await passthroughExport(asset: composition, audioMix: audioMix, to: outputURL)
        progress(1.0)
        logger.info("Stitched \(segments.count) segments → \(outputURL.lastPathComponent)")
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
        to outputURL: URL
    ) async throws {
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var trackPairs: [TrackPair] = []

        // Video: passthrough (copy compressed bytes, no decode/re-encode)
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
    }

    private func loadSegmentMetadata(segments: [URL]) async throws -> [SegmentMetadata] {
        try await withThrowingTaskGroup(of: SegmentMetadata.self) { group in
            for (index, url) in segments.enumerated() {
                group.addTask {
                    let asset = AVURLAsset(url: url)
                    let duration = try await asset.load(.duration)
                    let video = try await asset.loadTracks(withMediaType: .video)
                    let audio = try await asset.loadTracks(withMediaType: .audio)
                    return SegmentMetadata(
                        index: index, duration: duration,
                        videoTrack: video.first, audioTracks: audio
                    )
                }
            }
            var results: [SegmentMetadata] = []
            for try await m in group { results.append(m) }
            return results.sorted { $0.index < $1.index }
        }
    }
}

import AVFoundation
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportWriter")

/// Wraps AVAssetReader + AVAssetWriter to inject tx3g subtitle tracks into
/// existing video files via passthrough remux (no re-encode).
enum ExportWriter {

    enum ExportError: LocalizedError {
        case writerSetupFailed(String)
        case readerSetupFailed(String)
        case writingFailed(String)

        var errorDescription: String? {
            switch self {
            case .writerSetupFailed(let msg): "Export writer setup failed: \(msg)"
            case .readerSetupFailed(let msg): "Export reader setup failed: \(msg)"
            case .writingFailed(let msg): "Export writing failed: \(msg)"
            }
        }
    }

    // MARK: - Subtitle Injection

    /// Remux source video+audio with passthrough and inject tx3g subtitles.
    /// Creates a new .mov file at outputURL containing all tracks from sourceURL plus subtitles.
    static func injectSubtitles(
        sourceURL: URL,
        outputURL: URL,
        phrases: [SubtitlePhrase],
        durationMs: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // Sendable wrappers for concurrent track feeding
        var avTasks: [PassthroughTask] = []

        // Video passthrough
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
            avTasks.append(PassthroughTask(output: readerOutput, input: writerInput, duration: duration))
        }

        // Audio passthrough
        for audioTrack in audioTracks {
            let formatHint = try await audioTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(
                mediaType: .audio, outputSettings: nil, sourceFormatHint: formatHint
            )
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            avTasks.append(PassthroughTask(output: readerOutput, input: writerInput, duration: duration))
        }

        // Subtitle input with fixed format description
        let subtitleInput: AVAssetWriterInput
        if let fd = makeTx3gFormatDescription() {
            subtitleInput = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil, sourceFormatHint: fd)
        } else {
            logger.warning("Could not create tx3g format description; subtitle track may not work in all players")
            subtitleInput = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil)
        }
        subtitleInput.expectsMediaDataInRealTime = false
        writer.add(subtitleInput)

        // Start reading/writing
        guard reader.startReading() else {
            throw ExportError.readerSetupFailed(reader.error?.localizedDescription ?? "Unknown")
        }
        guard writer.startWriting() else {
            throw ExportError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown")
        }
        writer.startSession(atSourceTime: .zero)

        // Feed all tracks concurrently — AVAssetWriter requires simultaneous feeding
        let samples = buildSamplesWithGaps(phrases: phrases, durationMs: durationMs)
        guard let fd = makeTx3gFormatDescription() else {
            throw ExportError.writerSetupFailed("Could not create tx3g format description")
        }

        let subTask = SubtitleTask(
            input: subtitleInput, samples: samples,
            formatDescription: fd, progress: progress
        )
        await withTaskGroup(of: Void.self) { group in
            for task in avTasks {
                group.addTask { await copyTrackPassthrough(task: task) }
            }
            group.addTask {
                await writeSubtitleSamples(task: subTask)
            }
        }

        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        progress(1.0)
        logger.info("Injected \(phrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Private Helpers

    /// Sendable wrapper for reader/writer pair used in concurrent track copying.
    private struct PassthroughTask: @unchecked Sendable {
        let output: AVAssetReaderOutput
        let input: AVAssetWriterInput
        let duration: CMTime
    }

    /// Sendable wrapper for subtitle writing task.
    private struct SubtitleTask: @unchecked Sendable {
        let input: AVAssetWriterInput
        let samples: [SubtitlePhrase]
        let formatDescription: CMFormatDescription
        let progress: @Sendable (Double) -> Void
    }

    private static func copyTrackPassthrough(task: PassthroughTask) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.track.\(UUID().uuidString)")
            task.input.requestMediaDataWhenReady(on: queue) {
                while task.input.isReadyForMoreMediaData {
                    if let sampleBuffer = task.output.copyNextSampleBuffer() {
                        task.input.append(sampleBuffer)
                    } else {
                        task.input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }

    private static func writeSubtitleSamples(task: SubtitleTask) async {
        guard !task.samples.isEmpty else {
            task.input.markAsFinished()
            return
        }

        let sampleIndex = OSAllocatedUnfairLock(initialState: 0)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.subtitle")
            task.input.requestMediaDataWhenReady(on: queue) {
                while task.input.isReadyForMoreMediaData {
                    let idx = sampleIndex.withLock { $0 }
                    guard idx < task.samples.count else {
                        task.input.markAsFinished()
                        continuation.resume()
                        return
                    }

                    if let sb = buildTx3gSampleBuffer(
                        phrase: task.samples[idx], formatDescription: task.formatDescription
                    ) {
                        task.input.append(sb)
                    }

                    let newIdx = sampleIndex.withLock { val -> Int in
                        val += 1
                        return val
                    }
                    task.progress(Double(newIdx) / Double(task.samples.count))
                }
            }
        }
    }
}

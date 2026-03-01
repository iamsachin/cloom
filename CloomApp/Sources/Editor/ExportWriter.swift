import AVFoundation
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportWriter")

/// Wraps AVAssetReader + AVAssetWriter to support embedded tx3g subtitle tracks.
/// Use `remuxWithSubtitles` for passthrough (no re-encode) or `exportEdited` for
/// composition-based exports with passthrough video + subtitle embedding.
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

    /// Sendable wrapper for AV reader/writer pairs used in concurrent track copying.
    private struct TrackTask: @unchecked Sendable {
        let output: AVAssetReaderOutput
        let input: AVAssetWriterInput
        let duration: CMTime
        let progress: @Sendable (Double) -> Void
    }

    private struct SubtitleTask: @unchecked Sendable {
        let input: AVAssetWriterInput
        let phrases: [SubtitlePhrase]
    }

    // MARK: - Remux (Passthrough + Subtitles)

    static func remuxWithSubtitles(
        sourceURL: URL,
        outputURL: URL,
        phrases: [SubtitlePhrase],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var trackTasks: [TrackTask] = []
        let totalTracks = (videoTracks.isEmpty ? 0 : 1) + audioTracks.count

        if let videoTrack = videoTracks.first {
            let formatHint = try await videoTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            trackTasks.append(TrackTask(
                output: readerOutput, input: writerInput, duration: duration
            ) { p in progress(p / Double(totalTracks)) })
        }

        for (index, audioTrack) in audioTracks.enumerated() {
            let formatHint = try await audioTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formatHint)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            let trackIndex = index + 1
            trackTasks.append(TrackTask(
                output: readerOutput, input: writerInput, duration: duration
            ) { p in progress(p * Double(trackIndex + 1) / Double(totalTracks)) })
        }

        let subtitleInput = createSubtitleWriterInput()
        writer.add(subtitleInput)

        guard reader.startReading() else {
            throw ExportError.readerSetupFailed(reader.error?.localizedDescription ?? "Unknown")
        }
        guard writer.startWriting() else {
            throw ExportError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown")
        }
        writer.startSession(atSourceTime: .zero)

        // Feed all tracks + subtitles concurrently to avoid AVAssetWriter deadlocks
        let subTask = SubtitleTask(input: subtitleInput, phrases: phrases)
        await feedAllTracksConcurrently(tracks: trackTasks, subtitles: subTask)

        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        progress(1.0)
        logger.info("Remuxed with \(phrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Export Edited (Passthrough + Subtitles)

    static func exportEdited(
        composition: AVMutableComposition,
        audioMix: AVMutableAudioMix?,
        subtitlePhrases: [SubtitlePhrase],
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let duration = composition.duration
        let reader = try AVAssetReader(asset: composition)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var trackTasks: [TrackTask] = []

        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let formatHint = try await videoTrack.load(.formatDescriptions).first
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            videoReaderOutput.alwaysCopiesSampleData = false
            reader.add(videoReaderOutput)

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
            videoWriterInput.expectsMediaDataInRealTime = false
            writer.add(videoWriterInput)
            trackTasks.append(TrackTask(
                output: videoReaderOutput, input: videoWriterInput, duration: duration
            ) { p in progress(p * 0.9) })
        }

        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let audioReaderOutput: AVAssetReaderOutput
            if let audioMix, audioTracks.count > 1 {
                let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
                mixOutput.alwaysCopiesSampleData = false
                mixOutput.audioMix = audioMix
                audioReaderOutput = mixOutput
            } else {
                let trackOutput = AVAssetReaderTrackOutput(track: audioTracks[0], outputSettings: nil)
                trackOutput.alwaysCopiesSampleData = false
                audioReaderOutput = trackOutput
            }
            reader.add(audioReaderOutput)

            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            audioWriterInput.expectsMediaDataInRealTime = false
            writer.add(audioWriterInput)
            trackTasks.append(TrackTask(
                output: audioReaderOutput, input: audioWriterInput, duration: duration
            ) { _ in })
        }

        let subtitleInput = createSubtitleWriterInput()
        writer.add(subtitleInput)

        guard reader.startReading() else {
            throw ExportError.readerSetupFailed(reader.error?.localizedDescription ?? "Unknown")
        }
        guard writer.startWriting() else {
            throw ExportError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown")
        }
        writer.startSession(atSourceTime: .zero)

        let subTask = SubtitleTask(input: subtitleInput, phrases: subtitlePhrases)
        await feedAllTracksConcurrently(tracks: trackTasks, subtitles: subTask)

        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        progress(1.0)
        logger.info("Exported edited with \(subtitlePhrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Concurrent Track Feeding

    /// Feed all tracks + subtitles concurrently. AVAssetWriter requires all inputs
    /// to be fed simultaneously — sequential feeding causes deadlocks.
    private static func feedAllTracksConcurrently(
        tracks: [TrackTask],
        subtitles: SubtitleTask
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for task in tracks {
                group.addTask {
                    await copyTrackPassthrough(task: task)
                }
            }
            group.addTask {
                await writeSubtitleSamples(
                    to: subtitles.input, phrases: subtitles.phrases
                ) { _ in }
            }
        }
    }

    // MARK: - Track Copying

    private static func copyTrackPassthrough(task: TrackTask) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.track.\(UUID().uuidString)")
            task.input.requestMediaDataWhenReady(on: queue) {
                while task.input.isReadyForMoreMediaData {
                    if let sampleBuffer = task.output.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let fraction = task.duration.seconds > 0
                            ? pts.seconds / task.duration.seconds : 0
                        task.progress(min(fraction, 1.0))
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

}

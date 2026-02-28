import AVFoundation
import CoreMedia
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportWriter")

/// Wraps AVAssetReader + AVAssetWriter to support embedded tx3g subtitle tracks.
/// Use `remuxWithSubtitles` for passthrough (no re-encode) or `exportEdited` for
/// composition-based exports with optional video processing.
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

        var readerOutputs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = []

        if let videoTrack = videoTracks.first {
            let formatHint = try await videoTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            readerOutputs.append((readerOutput, writerInput))
        }

        for audioTrack in audioTracks {
            let formatHint = try await audioTrack.load(.formatDescriptions).first
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formatHint)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)
            readerOutputs.append((readerOutput, writerInput))
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

        for (readerOutput, writerInput) in readerOutputs {
            await copyTrackPassthrough(from: readerOutput, to: writerInput, duration: duration, progress: progress)
        }

        await writeSubtitleSamples(to: subtitleInput, phrases: phrases, progress: progress)
        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        logger.info("Remuxed with \(phrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Export Edited (Re-encode + Subtitles)

    static func exportEdited(
        composition: AVMutableComposition,
        audioMix: AVMutableAudioMix?,
        brightness: Float,
        contrast: Float,
        subtitlePhrases: [SubtitlePhrase],
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let duration = composition.duration
        let reader = try AVAssetReader(asset: composition)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        var readerOutputs: [(AVAssetReaderOutput, AVAssetWriterInput)] = []
        let needsProcessing = brightness != 0 || contrast != 1

        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])
            videoReaderOutput.alwaysCopiesSampleData = false
            reader.add(videoReaderOutput)

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(naturalSize.width),
                AVVideoHeightKey: Int(naturalSize.height),
            ])
            videoWriterInput.expectsMediaDataInRealTime = false
            writer.add(videoWriterInput)
            readerOutputs.append((videoReaderOutput, videoWriterInput))
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
            readerOutputs.append((audioReaderOutput, audioWriterInput))
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

        for (index, pair) in readerOutputs.enumerated() {
            let (readerOutput, writerInput) = pair
            if index == 0 && needsProcessing {
                await copyVideoWithProcessing(
                    from: readerOutput, to: writerInput,
                    brightness: brightness, contrast: contrast,
                    duration: duration, progress: progress
                )
            } else {
                await copyTrackPassthrough(
                    from: readerOutput, to: writerInput,
                    duration: duration, progress: progress
                )
            }
        }

        await writeSubtitleSamples(to: subtitleInput, phrases: subtitlePhrases, progress: progress)
        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        logger.info("Exported edited with \(subtitlePhrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Track Copying

    static func copyTrackPassthrough(
        from readerOutput: AVAssetReaderOutput,
        to writerInput: AVAssetWriterInput,
        duration: CMTime,
        progress: @escaping @Sendable (Double) -> Void
    ) async {
        nonisolated(unsafe) let output = readerOutput
        nonisolated(unsafe) let input = writerInput

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.track.\(UUID().uuidString)")
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let sampleBuffer = output.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let fraction = duration.seconds > 0
                            ? pts.seconds / duration.seconds : 0
                        progress(min(fraction, 1.0))
                        input.append(sampleBuffer)
                    } else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }

    static func copyVideoWithProcessing(
        from readerOutput: AVAssetReaderOutput,
        to writerInput: AVAssetWriterInput,
        brightness: Float,
        contrast: Float,
        duration: CMTime,
        progress: @escaping @Sendable (Double) -> Void
    ) async {
        let ciContext = SharedCIContext.instance
        nonisolated(unsafe) let output = readerOutput
        nonisolated(unsafe) let input = writerInput

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.video.\(UUID().uuidString)")
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard let sampleBuffer = output.copyNextSampleBuffer() else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }

                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let fraction = duration.seconds > 0
                        ? pts.seconds / duration.seconds : 0
                    progress(min(fraction, 1.0))

                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        input.append(sampleBuffer)
                        continue
                    }

                    var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    ciImage = ciImage.applyingFilter("CIColorControls", parameters: [
                        kCIInputBrightnessKey: brightness,
                        kCIInputContrastKey: contrast,
                    ])

                    ciContext.render(ciImage, to: pixelBuffer)
                    input.append(sampleBuffer)
                }
            }
        }
    }
}

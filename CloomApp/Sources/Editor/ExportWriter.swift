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

    // MARK: - Public API

    /// Remux source file (no re-encode) + add subtitle track.
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

        // Set up passthrough video
        var readerOutputs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = []

        if let videoTrack = videoTracks.first {
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)

            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)

            readerOutputs.append((readerOutput, writerInput))
        }

        // Set up passthrough audio (all tracks)
        for audioTrack in audioTracks {
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)

            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            writerInput.expectsMediaDataInRealTime = false
            writer.add(writerInput)

            readerOutputs.append((readerOutput, writerInput))
        }

        // Set up subtitle writer input
        let subtitleInput = createSubtitleWriterInput()
        writer.add(subtitleInput)

        guard reader.startReading() else {
            throw ExportError.readerSetupFailed(reader.error?.localizedDescription ?? "Unknown")
        }
        guard writer.startWriting() else {
            throw ExportError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown")
        }
        writer.startSession(atSourceTime: .zero)

        // Copy all tracks sequentially, then write subtitles
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

    /// Export from composition (with optional video processing) + subtitle track.
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

        // Video: re-encode with processing
        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            let width = Int(naturalSize.width)
            let height = Int(naturalSize.height)

            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])
            videoReaderOutput.alwaysCopiesSampleData = false
            reader.add(videoReaderOutput)

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ])
            videoWriterInput.expectsMediaDataInRealTime = false
            writer.add(videoWriterInput)

            readerOutputs.append((videoReaderOutput, videoWriterInput))
        }

        // Audio: passthrough (reader handles audioMix internally if set)
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

        // Subtitle track
        let subtitleInput = createSubtitleWriterInput()
        writer.add(subtitleInput)

        guard reader.startReading() else {
            throw ExportError.readerSetupFailed(reader.error?.localizedDescription ?? "Unknown")
        }
        guard writer.startWriting() else {
            throw ExportError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown")
        }
        writer.startSession(atSourceTime: .zero)

        // Copy tracks sequentially
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

        // Write subtitle samples
        await writeSubtitleSamples(to: subtitleInput, phrases: subtitlePhrases, progress: progress)

        await writer.finishWriting()

        if let error = writer.error {
            throw ExportError.writingFailed(error.localizedDescription)
        }

        logger.info("Exported edited with \(subtitlePhrases.count) subtitle phrases → \(outputURL.lastPathComponent)")
    }

    // MARK: - Subtitle Format

    /// Create AVAssetWriterInput for tx3g (3GPP Timed Text) subtitles.
    private static func createSubtitleWriterInput() -> AVAssetWriterInput {
        var formatDescription: CMFormatDescription?
        let tx3gInitData = Data([
            0x00, 0x00, 0x00, 0x00, // displayFlags
            0x00,                     // horizontal-justification (left)
            0x01,                     // vertical-justification (bottom)
            0x00, 0x00, 0x00, 0x00,  // background-color-rgba
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // default-text-box
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // style-record (start)
            0x00, 0x00,             // startChar, endChar
            0x00, 0x01,             // font-ID
            0x00,                    // face-style-flags
            0x12,                    // font-size (18pt)
            0xFF, 0xFF, 0xFF, 0xFF, // text-color-rgba (white)
        ])

        tx3gInitData.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!
            let extensions = [
                "mdia" as CFString: [
                    "minf" as CFString: [
                        "stbl" as CFString: [
                            "stsd" as CFString: [
                                "tx3g" as CFString: NSData(bytes: ptr, length: tx3gInitData.count),
                            ] as CFDictionary,
                        ] as CFDictionary,
                    ] as CFDictionary,
                ] as CFDictionary,
            ] as CFDictionary

            CMFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                mediaType: kCMMediaType_Subtitle,
                mediaSubType: FourCharCode(0x74783367), // 'tx3g'
                extensions: extensions,
                formatDescriptionOut: &formatDescription
            )
        }

        let input: AVAssetWriterInput
        if let fd = formatDescription {
            input = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil, sourceFormatHint: fd)
        } else {
            logger.warning("Could not create tx3g format description, subtitle track may not work in all players")
            input = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil)
        }
        input.expectsMediaDataInRealTime = false
        return input
    }

    // MARK: - Track Copying

    /// Passthrough copy: read samples from reader output and append to writer input.
    private static func copyTrackPassthrough(
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
                            ? pts.seconds / duration.seconds
                            : 0
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

    /// Copy video with brightness/contrast CIFilter processing.
    private static func copyVideoWithProcessing(
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
                        ? pts.seconds / duration.seconds
                        : 0
                    progress(min(fraction, 1.0))

                    // Apply CIFilter to pixel buffer
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        input.append(sampleBuffer)
                        continue
                    }

                    var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    ciImage = ciImage.applyingFilter("CIColorControls", parameters: [
                        kCIInputBrightnessKey: brightness,
                        kCIInputContrastKey: contrast,
                    ])

                    // Render back into the same pixel buffer
                    ciContext.render(ciImage, to: pixelBuffer)
                    input.append(sampleBuffer)
                }
            }
        }
    }

    /// Write tx3g subtitle samples for each phrase.
    private static func writeSubtitleSamples(
        to writerInput: AVAssetWriterInput,
        phrases: [SubtitlePhrase],
        progress: @escaping @Sendable (Double) -> Void
    ) async {
        guard !phrases.isEmpty else {
            writerInput.markAsFinished()
            return
        }

        // Create a format description for tx3g
        var formatDescription: CMFormatDescription?
        let tx3gInitData = Data([
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00,
            0x00, 0x01,
            0x00,
            0x12,
            0xFF, 0xFF, 0xFF, 0xFF,
        ])

        tx3gInitData.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!
            let extensions = [
                "mdia" as CFString: [
                    "minf" as CFString: [
                        "stbl" as CFString: [
                            "stsd" as CFString: [
                                "tx3g" as CFString: NSData(bytes: ptr, length: tx3gInitData.count),
                            ] as CFDictionary,
                        ] as CFDictionary,
                    ] as CFDictionary,
                ] as CFDictionary,
            ] as CFDictionary

            CMFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                mediaType: kCMMediaType_Subtitle,
                mediaSubType: FourCharCode(0x74783367),
                extensions: extensions,
                formatDescriptionOut: &formatDescription
            )
        }

        guard let fd = formatDescription else {
            logger.error("Failed to create tx3g format description for subtitle writing")
            writerInput.markAsFinished()
            return
        }

        nonisolated(unsafe) let input = writerInput

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.subtitle")
            var phraseIndex = 0

            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard phraseIndex < phrases.count else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }

                    let phrase = phrases[phraseIndex]
                    let pts = CMTime(value: CMTimeValue(phrase.startMs), timescale: 1000)
                    let dur = CMTime(
                        value: CMTimeValue(phrase.endMs - phrase.startMs),
                        timescale: 1000
                    )

                    // Build tx3g payload: 2-byte big-endian length + UTF-8 text
                    let textData = Data(phrase.text.utf8)
                    var payload = Data()
                    var bigEndianLen = UInt16(textData.count).bigEndian
                    payload.append(Data(bytes: &bigEndianLen, count: 2))
                    payload.append(textData)

                    var blockBuffer: CMBlockBuffer?
                    let dataLen = payload.count

                    payload.withUnsafeBytes { rawBuf in
                        let bufPtr = rawBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        CMBlockBufferCreateWithMemoryBlock(
                            allocator: kCFAllocatorDefault,
                            memoryBlock: nil,
                            blockLength: dataLen,
                            blockAllocator: kCFAllocatorDefault,
                            customBlockSource: nil,
                            offsetToData: 0,
                            dataLength: dataLen,
                            flags: 0,
                            blockBufferOut: &blockBuffer
                        )
                        if let block = blockBuffer {
                            CMBlockBufferReplaceDataBytes(
                                with: bufPtr,
                                blockBuffer: block,
                                offsetIntoDestination: 0,
                                dataLength: dataLen
                            )
                        }
                    }

                    if let block = blockBuffer {
                        var timingInfo = CMSampleTimingInfo(
                            duration: dur,
                            presentationTimeStamp: pts,
                            decodeTimeStamp: .invalid
                        )
                        var sampleSize = dataLen
                        var sampleBuffer: CMSampleBuffer?

                        CMSampleBufferCreate(
                            allocator: kCFAllocatorDefault,
                            dataBuffer: block,
                            dataReady: true,
                            makeDataReadyCallback: nil,
                            refcon: nil,
                            formatDescription: fd,
                            sampleCount: 1,
                            sampleTimingEntryCount: 1,
                            sampleTimingArray: &timingInfo,
                            sampleSizeEntryCount: 1,
                            sampleSizeArray: &sampleSize,
                            sampleBufferOut: &sampleBuffer
                        )

                        if let sb = sampleBuffer {
                            input.append(sb)
                        }
                    }

                    phraseIndex += 1
                    progress(Double(phraseIndex) / Double(phrases.count))
                }
            }
        }
    }
}

import AVFoundation
import CoreVideo
import VideoToolbox
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "VideoWriter")

enum AudioSourceType {
    case system
    case microphone
}

actor VideoWriter {
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let systemAudioInput: AVAssetWriterInput
    private let micAudioInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor

    /// Exposed for the compositing pipeline to allocate output buffers.
    /// Only valid after `start()` has been called.
    /// Set once in start() before capture begins; read-only from capture queue thereafter.
    nonisolated(unsafe) var exposedPixelBufferPool: CVPixelBufferPool?

    private var firstVideoPTS: CMTime?
    private var firstSystemAudioPTS: CMTime?
    private var firstMicAudioPTS: CMTime?
    private var started = false
    private var frameCount: Int64 = 0
    private var dropCount: Int64 = 0

    init(outputURL: URL, settings: RecordingSettings, width: Int, height: Int) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Video input — HEVC with configurable bitrate
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.quality.bitrate,
                AVVideoExpectedSourceFrameRateKey: settings.fps,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
            ] as [String: Any],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        // Pixel buffer adaptor with IOSurface-backed pool
        let adaptorAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: adaptorAttributes
        )

        // System audio input — AAC 48kHz stereo
        let systemAudioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]
        let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: systemAudioSettings)
        systemAudioInput.expectsMediaDataInRealTime = true

        // Microphone audio input — AAC 48kHz stereo
        let micAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: systemAudioSettings)
        micAudioInput.expectsMediaDataInRealTime = true

        if writer.canAdd(videoInput) { writer.add(videoInput) }
        if writer.canAdd(systemAudioInput) { writer.add(systemAudioInput) }
        if writer.canAdd(micAudioInput) { writer.add(micAudioInput) }

        self.writer = writer
        self.videoInput = videoInput
        self.systemAudioInput = systemAudioInput
        self.micAudioInput = micAudioInput
        self.pixelBufferAdaptor = adaptor
    }

    func start() {
        guard !started else { return }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        started = true
        exposedPixelBufferPool = pixelBufferAdaptor.pixelBufferPool
        logger.info("VideoWriter started")
    }

    func appendVideo(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        guard started, writer.status == .writing else { return }

        if firstVideoPTS == nil {
            firstVideoPTS = pts
        }

        guard let offset = firstVideoPTS else { return }
        let normalizedPTS = CMTimeSubtract(pts, offset)

        guard videoInput.isReadyForMoreMediaData else {
            dropCount += 1
            if dropCount % 100 == 0 {
                logger.warning("Dropped \(self.dropCount) video frames total")
            }
            return
        }

        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: normalizedPTS)
        frameCount += 1
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, sourceType: AudioSourceType) {
        guard started, writer.status == .writing else { return }

        let input: AVAssetWriterInput
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch sourceType {
        case .system:
            if firstSystemAudioPTS == nil { firstSystemAudioPTS = pts }
            input = systemAudioInput
        case .microphone:
            if firstMicAudioPTS == nil { firstMicAudioPTS = pts }
            input = micAudioInput
        }

        // Use video PTS offset for normalization (audio should align with video)
        guard let videoOffset = firstVideoPTS else { return }

        let normalizedPTS = CMTimeSubtract(pts, videoOffset)
        guard normalizedPTS.seconds >= 0 else { return }

        guard input.isReadyForMoreMediaData else { return }

        // Create timing-adjusted sample buffer
        if let adjusted = adjustTiming(of: sampleBuffer, offset: videoOffset) {
            input.append(adjusted)
        }
    }

    func finish() async {
        guard started, writer.status == .writing else {
            logger.warning("VideoWriter finish called but not in writing state: \(String(describing: self.writer.status.rawValue))")
            return
        }

        videoInput.markAsFinished()
        systemAudioInput.markAsFinished()
        micAudioInput.markAsFinished()

        let totalFrames = frameCount
        let totalDropped = dropCount
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                logger.info("VideoWriter finished — \(totalFrames) frames, \(totalDropped) dropped")
                continuation.resume()
            }
        }
    }

    // MARK: - Private

    private func adjustTiming(of sampleBuffer: CMSampleBuffer, offset: CMTime) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo()
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        timingInfo.presentationTimeStamp = CMTimeSubtract(pts, offset)
        timingInfo.duration = duration
        timingInfo.decodeTimeStamp = .invalid

        var newBuffer: CMSampleBuffer?
        let timingCount: CMItemCount = 1
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: nil,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: timingCount,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &newBuffer
        )
        return newBuffer
    }
}

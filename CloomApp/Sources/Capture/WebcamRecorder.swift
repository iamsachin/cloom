import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamRecorder")

@MainActor
final class WebcamRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var startTime: CMTime?

    func start(outputURL: URL, width: Int, height: Int) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        if writer.canAdd(input) {
            writer.add(input)
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.isRecording = true
        self.startTime = nil

        logger.info("Webcam recorder started → \(outputURL.lastPathComponent)")
    }

    func appendFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isRecording,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor,
              input.isReadyForMoreMediaData else { return }

        let now = CMClockGetTime(CMClockGetHostTimeClock())
        if startTime == nil {
            startTime = now
        }

        let presentationTime = CMTimeSubtract(now, startTime!)
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false

        videoInput?.markAsFinished()
        assetWriter?.finishWriting {
            logger.info("Webcam recording finished")
        }
        cleanup()
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
    }
}

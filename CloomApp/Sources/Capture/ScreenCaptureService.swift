@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreVideo
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ScreenCaptureService")

@MainActor
protocol CaptureServiceDelegate: AnyObject {
    func captureDidStart()
    func captureDidFail(error: Error)
}

/// Thread-safe state accessed from both MainActor and the SCStreamOutput callback queue.
struct CaptureState: @unchecked Sendable {
    var videoWriter: VideoWriter?
    var compositor: WebcamCompositor?
    var annotationRenderer: AnnotationRenderer?
    var bufferPool: CVPixelBufferPool?
    var micGainProcessor: MicGainProcessor?
    var isProcessingFrame: Bool = false
}

@MainActor
final class ScreenCaptureService: NSObject {
    weak var delegate: CaptureServiceDelegate?

    /// Optional recording metrics — set by coordinator before starting capture.
    var recordingMetrics: RecordingMetrics?

    private var stream: SCStream?
    private var currentConfig: SCStreamConfiguration?

    /// All cross-queue state protected by a single unfair lock.
    nonisolated let captureState = OSAllocatedUnfairLock(initialState: CaptureState())

    private let outputQueue = DispatchQueue(label: "com.cloom.capture.output", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "com.cloom.capture.audio", qos: .userInteractive)

    func startCapture(outputURL: URL, mode: CaptureMode, micEnabled: Bool, settings: RecordingSettings, compositor: WebcamCompositor?, annotationRenderer: AnnotationRenderer? = nil) async throws {
        let content = try await SCShareableContent.current
        let filter = try buildFilter(mode: mode, content: content)
        let config = SCStreamConfiguration()
        configureStream(config, mode: mode, content: content)
        configureCommon(config, settings: settings, micEnabled: micEnabled)
        try await startStream(filter: filter, config: config, outputURL: outputURL, settings: settings, compositor: compositor, annotationRenderer: annotationRenderer)
        logger.info("Capture started → \(outputURL.lastPathComponent) mode=\(String(describing: mode))")
    }

    func startCapture(outputURL: URL, filter: SCContentFilter, micEnabled: Bool, settings: RecordingSettings, compositor: WebcamCompositor?, annotationRenderer: AnnotationRenderer? = nil) async throws {
        let config = SCStreamConfiguration()
        let scale = Int(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width) * scale
        config.height = Int(filter.contentRect.height) * scale
        configureCommon(config, settings: settings, micEnabled: micEnabled)
        try await startStream(filter: filter, config: config, outputURL: outputURL, settings: settings, compositor: compositor, annotationRenderer: annotationRenderer)
        logger.info("Capture started (picker filter) → \(outputURL.lastPathComponent)")
    }

    private func startStream(filter: SCContentFilter, config: SCStreamConfiguration, outputURL: URL, settings: RecordingSettings, compositor: WebcamCompositor?, annotationRenderer: AnnotationRenderer? = nil) async throws {
        let gainProc = MicGainProcessor(sensitivity: settings.micSensitivity)

        let writer = try VideoWriter(
            outputURL: outputURL,
            settings: settings,
            width: config.width,
            height: config.height
        )

        self.currentConfig = config
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue)

        writer.metrics = recordingMetrics
        await writer.start()
        let pool = writer.exposedPixelBufferPool
        // CVPixelBufferPool isn't Sendable but is safe here — set before capture starts.
        nonisolated(unsafe) let sendablePool = pool

        captureState.withLock {
            $0.videoWriter = writer
            $0.compositor = compositor
            $0.annotationRenderer = annotationRenderer
            $0.micGainProcessor = gainProc.isUnity ? nil : gainProc
            $0.bufferPool = sendablePool
        }

        try await stream.startCapture()
        delegate?.captureDidStart()
    }

    func stopCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()

        let writer = captureState.withLock { $0.videoWriter }
        if let writer {
            await writer.finish()
        }

        captureState.withLock {
            $0.videoWriter = nil
            $0.compositor = nil
            $0.annotationRenderer = nil
            $0.bufferPool = nil
            $0.micGainProcessor = nil
        }

        logger.info("Capture stopped")
        self.stream = nil
        self.currentConfig = nil
    }

    func updateCompositor(_ compositor: WebcamCompositor?) {
        captureState.withLock { $0.compositor = compositor }
    }

    func updateConfiguration(micEnabled: Bool) async throws {
        guard let stream, let base = currentConfig else { return }
        let config = SCStreamConfiguration()
        config.width = base.width
        config.height = base.height
        config.minimumFrameInterval = base.minimumFrameInterval
        config.showsCursor = base.showsCursor
        config.capturesAudio = base.capturesAudio
        config.sourceRect = base.sourceRect
        config.destinationRect = base.destinationRect
        config.captureMicrophone = micEnabled
        if micEnabled, let defaultMic = AVCaptureDevice.default(for: .audio) {
            config.microphoneCaptureDeviceID = defaultMic.uniqueID
        }
        try await stream.updateConfiguration(config)
        currentConfig = config
    }
}

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

@MainActor
final class ScreenCaptureService: NSObject {
    weak var delegate: CaptureServiceDelegate?

    private var stream: SCStream?
    private var currentConfig: SCStreamConfiguration?
    nonisolated(unsafe) var videoWriter: VideoWriter?
    nonisolated(unsafe) var compositor: WebcamCompositor?
    nonisolated(unsafe) var annotationRenderer: AnnotationRenderer?
    nonisolated(unsafe) var bufferPool: CVPixelBufferPool?
    nonisolated(unsafe) var micGainProcessor: MicGainProcessor?
    nonisolated(unsafe) var isProcessingFrame: Bool = false

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
        self.compositor = compositor
        self.annotationRenderer = annotationRenderer
        let gainProc = MicGainProcessor(sensitivity: settings.micSensitivity)
        self.micGainProcessor = gainProc.isUnity ? nil : gainProc

        let writer = try VideoWriter(
            outputURL: outputURL,
            settings: settings,
            width: config.width,
            height: config.height
        )
        self.videoWriter = writer

        self.currentConfig = config
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue)

        await writer.start()
        self.bufferPool = writer.exposedPixelBufferPool

        try await stream.startCapture()
        delegate?.captureDidStart()
    }

    func stopCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()

        if let writer = videoWriter {
            await writer.finish()
        }

        logger.info("Capture stopped")
        self.stream = nil
        self.currentConfig = nil
        self.videoWriter = nil
        self.compositor = nil
        self.annotationRenderer = nil
        self.bufferPool = nil
        self.micGainProcessor = nil
    }

    func updateCompositor(_ compositor: WebcamCompositor?) {
        self.compositor = compositor
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

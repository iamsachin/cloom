@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreVideo
import os.log

private struct SendableCVBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

private struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

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
    nonisolated(unsafe) var videoWriter: VideoWriter?
    nonisolated(unsafe) var compositor: WebcamCompositor?
    nonisolated(unsafe) var bufferPool: CVPixelBufferPool?

    private let outputQueue = DispatchQueue(label: "com.cloom.capture.output", qos: .userInteractive)

    func startCapture(outputURL: URL, mode: CaptureMode, micEnabled: Bool, settings: RecordingSettings, compositor: WebcamCompositor?) async throws {
        let content = try await SCShareableContent.current
        let filter = try buildFilter(mode: mode, content: content)
        let config = SCStreamConfiguration()
        configureStream(config, mode: mode, content: content)
        configureCommon(config, settings: settings, micEnabled: micEnabled)
        try await startStream(filter: filter, config: config, outputURL: outputURL, settings: settings, compositor: compositor)
        logger.info("Capture started → \(outputURL.lastPathComponent) mode=\(String(describing: mode))")
    }

    func startCapture(outputURL: URL, filter: SCContentFilter, micEnabled: Bool, settings: RecordingSettings, compositor: WebcamCompositor?) async throws {
        let config = SCStreamConfiguration()
        let scale = Int(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width) * scale
        config.height = Int(filter.contentRect.height) * scale
        configureCommon(config, settings: settings, micEnabled: micEnabled)
        try await startStream(filter: filter, config: config, outputURL: outputURL, settings: settings, compositor: compositor)
        logger.info("Capture started (picker filter) → \(outputURL.lastPathComponent)")
    }

    private func configureCommon(_ config: SCStreamConfiguration, settings: RecordingSettings, micEnabled: Bool) {
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        config.showsCursor = true
        config.capturesAudio = true

        if micEnabled {
            config.captureMicrophone = true
            if let micID = settings.micDeviceID {
                config.microphoneCaptureDeviceID = micID
            } else if let defaultMic = AVCaptureDevice.default(for: .audio) {
                config.microphoneCaptureDeviceID = defaultMic.uniqueID
            }
        }
    }

    private func startStream(filter: SCContentFilter, config: SCStreamConfiguration, outputURL: URL, settings: RecordingSettings, compositor: WebcamCompositor?) async throws {
        self.compositor = compositor

        // Create VideoWriter with the configured dimensions
        let writer = try VideoWriter(
            outputURL: outputURL,
            settings: settings,
            width: config.width,
            height: config.height
        )
        self.videoWriter = writer

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)

        if config.captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: outputQueue)
        }

        // Start the writer, then capture
        await writer.start()

        // Get the buffer pool after writer has started
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
        self.videoWriter = nil
        self.compositor = nil
        self.bufferPool = nil
    }

    func updateConfiguration(micEnabled: Bool) async throws {
        guard let stream else { return }
        let config = SCStreamConfiguration()
        config.captureMicrophone = micEnabled
        if micEnabled, let defaultMic = AVCaptureDevice.default(for: .audio) {
            config.microphoneCaptureDeviceID = defaultMic.uniqueID
        }
        try await stream.updateConfiguration(config)
    }

    // MARK: - Filter builder

    private func buildFilter(mode: CaptureMode, content: SCShareableContent) throws -> SCContentFilter {
        switch mode {
        case .fullScreen(let displayID):
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                    ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            let selfApp = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            return SCContentFilter(display: display, excludingApplications: selfApp, exceptingWindows: [])

        case .window(let windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw CaptureError.noWindow
            }
            return SCContentFilter(desktopIndependentWindow: window)

        case .region(let displayID, _):
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                    ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            let selfApp = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            return SCContentFilter(display: display, excludingApplications: selfApp, exceptingWindows: [])
        }
    }

    // MARK: - Stream configuration per mode

    private func configureStream(_ config: SCStreamConfiguration, mode: CaptureMode, content: SCShareableContent) {
        let scaleFactor: Int

        switch mode {
        case .fullScreen(let displayID):
            let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first
            scaleFactor = display.map { screenScaleFactor(for: $0.displayID) } ?? 2
            config.width = (display?.width ?? 1920) * scaleFactor
            config.height = (display?.height ?? 1080) * scaleFactor

        case .window:
            scaleFactor = 2
            config.width = 1920 * scaleFactor
            config.height = 1080 * scaleFactor

        case .region(let displayID, let rect):
            scaleFactor = screenScaleFactor(for: displayID)
            config.sourceRect = rect
            config.width = Int(rect.width) * scaleFactor
            config.height = Int(rect.height) * scaleFactor
            config.destinationRect = CGRect(
                origin: .zero,
                size: CGSize(
                    width: CGFloat(config.width),
                    height: CGFloat(config.height)
                )
            )
        }
    }

    private func screenScaleFactor(for displayID: CGDirectDisplayID) -> Int {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            if let screenDisplayID = screen.deviceDescription[key] as? CGDirectDisplayID,
               screenDisplayID == displayID {
                return Int(screen.backingScaleFactor)
            }
        }
        return 2 // default Retina
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureService: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        switch type {
        case .screen:
            handleScreenFrame(sampleBuffer)
        case .audio:
            handleAudio(sampleBuffer, sourceType: .system)
        case .microphone:
            handleAudio(sampleBuffer, sourceType: .microphone)
        @unknown default:
            break
        }
    }

    nonisolated private func handleScreenFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        guard let writer = videoWriter else { return }

        // Composite webcam if available
        let outputBuffer: CVPixelBuffer
        if let comp = compositor, let pool = bufferPool,
           let composited = comp.composite(screenBuffer: pixelBuffer, bufferPool: pool) {
            outputBuffer = composited
        } else {
            outputBuffer = pixelBuffer
        }

        let wrapped = SendableCVBuffer(buffer: outputBuffer)
        Task { await writer.appendVideo(wrapped.buffer, pts: pts) }
    }

    nonisolated private func handleAudio(_ sampleBuffer: CMSampleBuffer, sourceType: AudioSourceType) {
        guard let writer = videoWriter else { return }
        let wrapped = SendableSampleBuffer(buffer: sampleBuffer)
        let source = sourceType
        Task { await writer.appendAudio(wrapped.buffer, sourceType: source) }
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        logger.error("SCStream stopped with error: \(error)")
        Task { @MainActor in
            delegate?.captureDidFail(error: error)
        }
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case noDisplay
    case noWindow

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display found for screen capture."
        case .noWindow: "Selected window is no longer available."
        }
    }
}

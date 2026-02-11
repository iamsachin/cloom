@preconcurrency import ScreenCaptureKit
import AVFoundation
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
    private var recordingOutput: SCRecordingOutput?

    func startCapture(outputURL: URL, mode: CaptureMode, micEnabled: Bool) async throws {
        let content = try await SCShareableContent.current

        let filter = try buildFilter(mode: mode, content: content)

        let config = SCStreamConfiguration()
        configureStream(config, mode: mode, content: content)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = true
        config.capturesAudio = true

        if micEnabled {
            config.captureMicrophone = true
            if let defaultMic = AVCaptureDevice.default(for: .audio) {
                config.microphoneCaptureDeviceID = defaultMic.uniqueID
            }
        }

        try await startStream(filter: filter, config: config, outputURL: outputURL)
        logger.info("Capture started → \(outputURL.lastPathComponent) mode=\(String(describing: mode))")
    }

    /// Start capture using an SCContentFilter directly (from SCContentSharingPicker).
    func startCapture(outputURL: URL, filter: SCContentFilter, micEnabled: Bool) async throws {
        let config = SCStreamConfiguration()
        let scale = Int(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width) * scale
        config.height = Int(filter.contentRect.height) * scale
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = true
        config.capturesAudio = true

        if micEnabled {
            config.captureMicrophone = true
            if let defaultMic = AVCaptureDevice.default(for: .audio) {
                config.microphoneCaptureDeviceID = defaultMic.uniqueID
            }
        }

        try await startStream(filter: filter, config: config, outputURL: outputURL)
        logger.info("Capture started (picker filter) → \(outputURL.lastPathComponent)")
    }

    private func startStream(filter: SCContentFilter, config: SCStreamConfiguration, outputURL: URL) async throws {
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.stream = stream

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = outputURL
        recordingConfig.outputFileType = .mp4

        let recording = SCRecordingOutput(configuration: recordingConfig, delegate: self)
        self.recordingOutput = recording
        try stream.addRecordingOutput(recording)

        try await stream.startCapture()
    }

    func stopCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        logger.info("Capture stopped")
        self.stream = nil
        self.recordingOutput = nil
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
    }
}

// MARK: - SCRecordingOutputDelegate

extension ScreenCaptureService: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            delegate?.captureDidStart()
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        logger.info("Recording file written")
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        logger.error("Recording failed: \(error)")
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

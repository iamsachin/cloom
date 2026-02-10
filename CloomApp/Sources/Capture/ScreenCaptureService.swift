@preconcurrency import ScreenCaptureKit
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

    func startCapture(outputURL: URL) async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = true
        config.capturesAudio = true

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
        logger.info("Capture started → \(outputURL.lastPathComponent)")
    }

    func stopCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        logger.info("Capture stopped")
        self.stream = nil
        self.recordingOutput = nil
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureService: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Consumed by SCRecordingOutput; this handler prevents frame-drop log spam.
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

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display found for screen capture."
        }
    }
}

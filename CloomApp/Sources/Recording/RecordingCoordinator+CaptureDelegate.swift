import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - CaptureServiceDelegate

extension RecordingCoordinator: CaptureServiceDelegate {
    func captureDidStart() {
        let now = Date()
        state = .recording(startedAt: now)
        recordingStartedAt = now

        // Start recording instrumentation (metrics created in beginCapture)
        recordingMetrics?.start()

        if case .region(_, let rect) = selectedMode {
            regionHighlight.show(region: rect)
        }

        showRecordingToolbar(startedAt: now)
    }

    func captureDidFail(error: Error) {
        logger.error("Recording failed: \(error)")
        recordingToolbar.dismiss()
        regionHighlight.dismiss()
        cleanupAnnotations()
        stopWebcam()
        state = .idle
    }
}

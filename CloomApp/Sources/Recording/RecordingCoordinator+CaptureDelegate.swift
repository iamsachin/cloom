import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - CaptureServiceDelegate

extension RecordingCoordinator: CaptureServiceDelegate {
    func captureDidStart() {
        let now = Date()
        state = .recording(startedAt: now)
        recordingStartedAt = now

        if case .region(_, let rect) = selectedMode {
            regionHighlight.show(region: rect)
        }

        showRecordingToolbar(startedAt: now)

        // Show bubble control pill if camera is enabled
        if cameraEnabled, let bubblePanel = webcamBubble?.windowPanel {
            let pill = BubbleControlPill()
            pill.show(
                bubbleWindow: bubblePanel,
                startedAt: now,
                pausedDuration: 0,
                isPaused: false,
                onStop: { [weak self] in self?.stopRecording() },
                onPause: { [weak self] in self?.pauseRecording() },
                onResume: { [weak self] in self?.resumeRecording() },
                onDiscard: { [weak self] in self?.discardRecording() }
            )
            self.bubbleControlPill = pill
        }
    }

    func captureDidFail(error: Error) {
        logger.error("Recording failed: \(error)")
        recordingToolbar.dismiss()
        regionHighlight.dismiss()
        cleanupAnnotations()
        bubbleControlPill?.dismiss()
        bubbleControlPill = nil
        stopWebcam()
        state = .idle
    }
}

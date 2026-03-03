import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Recording Toolbar, Discard & Alerts

extension RecordingCoordinator {

    func showReadyToolbar() {
        recordingToolbar.showReady(
            micEnabled: micEnabled,
            cameraEnabled: cameraEnabled,
            onToggleMic: { [weak self] in self?.toggleMic() },
            onToggleCamera: { [weak self] in self?.toggleCamera() },
            onToggleAnnotations: { [weak self] in self?.toggleAnnotations() },
            onToggleClickEmphasis: { [weak self] in self?.toggleClickEmphasis() },
            onToggleCursorSpotlight: { [weak self] in self?.toggleCursorSpotlight() },
            onRecord: { [weak self] in self?.confirmRecording() },
            onCancel: { [weak self] in self?.cancelReadyState() }
        )
    }

    func showRecordingToolbar(startedAt: Date) {
        recordingToolbar.show(
            startedAt: startedAt,
            pausedDuration: pausedDuration,
            isPaused: false,
            micEnabled: micEnabled,
            cameraEnabled: cameraEnabled,
            onStop: { [weak self] in self?.stopRecording() },
            onToggleMic: { [weak self] in self?.toggleMic() },
            onToggleCamera: { [weak self] in self?.toggleCamera() },
            onPause: { [weak self] in self?.pauseRecording() },
            onResume: { [weak self] in self?.resumeRecording() },
            onToggleAnnotations: { [weak self] in self?.toggleAnnotations() },
            onToggleClickEmphasis: { [weak self] in self?.toggleClickEmphasis() },
            onToggleCursorSpotlight: { [weak self] in self?.toggleCursorSpotlight() },
            onDiscard: { [weak self] in self?.discardRecording() }
        )
    }

    // MARK: - Discard

    func performDiscard() {
        let wasPaused = state.isPaused
        state = .stopping
        recordingToolbar.dismiss()
        regionHighlight.dismiss()
        cleanupAnnotations()

        Task {
            stopWebcam()

            if !wasPaused {
                do {
                    try await captureService.stopCapture()
                } catch {
                    logger.error("Failed to stop capture during discard: \(error)")
                }
            }

            for url in segmentURLs {
                try? FileManager.default.removeItem(at: url)
            }
            if let outputURL = currentOutputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }

            resetSegmentState()
            state = .idle
            logger.info("Recording discarded")
        }
    }

    // MARK: - Alerts

    func checkDiskSpace() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: homeDir),
              let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return true
        }
        let oneGB: Int64 = 1_073_741_824
        return freeSize >= oneGB
    }

    func showLowDiskSpaceAlert() {
        let alert = NSAlert()
        alert.messageText = "Low Disk Space"
        alert.informativeText = "Less than 1 GB of free disk space remaining. Free up space before recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showCaptureFailedAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Failed"
        alert.informativeText = "\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

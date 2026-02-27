import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Pause & Resume

extension RecordingCoordinator {

    func pauseRecording() {
        guard case .recording(let startedAt) = state else { return }

        state = .paused(startedAt: startedAt, pausedAt: Date())

        Task {
            do {
                try await captureService.stopCapture()
            } catch {
                logger.error("Failed to stop capture for pause: \(error)")
            }
        }

        recordingToolbar.dismiss()
    }

    func resumeRecording() {
        guard case .paused(let startedAt, let pausedAt) = state else { return }

        pausedDuration += Date().timeIntervalSince(pausedAt)
        segmentIndex += 1
        recordingMetrics?.reportSegment()

        let settings = currentSettings ?? RecordingSettings.fromDefaults()
        let segmentURL = makeSegmentURL()
        segmentURLs.append(segmentURL)

        // Reuse existing compositor and renderer — they hold no segment-specific state
        let activeCompositor: WebcamCompositor?
        if cameraEnabled, let comp = self.compositor {
            activeCompositor = comp
            webcamBubble?.onLayoutChanged = { [weak self] layout in
                self?.compositor?.updateBubbleLayout(layout)
            }
            cameraService?.onFrame = { [weak self] pixelBuffer, ciImage in
                guard let self else { return }
                self.compositor?.updateWebcamFrame(pixelBuffer)
                Task { @MainActor in
                    self.handleCameraFrameForPreview(ciImage, pixelBuffer: pixelBuffer)
                }
            }
        } else {
            activeCompositor = nil
        }

        let activeRenderer = self.annotationRenderer

        Task {
            do {
                if let filter = currentFilter {
                    try await captureService.startCapture(
                        outputURL: segmentURL,
                        filter: filter,
                        micEnabled: micEnabled,
                        settings: settings,
                        compositor: activeCompositor,
                        annotationRenderer: activeRenderer
                    )
                } else {
                    try await captureService.startCapture(
                        outputURL: segmentURL,
                        mode: selectedMode,
                        micEnabled: micEnabled,
                        settings: settings,
                        compositor: activeCompositor,
                        annotationRenderer: activeRenderer
                    )
                }
                state = .recording(startedAt: startedAt)

                showRecordingToolbar(startedAt: startedAt)
            } catch {
                logger.error("Failed to resume capture: \(error)")
                state = .idle
            }
        }
    }
}

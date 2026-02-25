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

        let settings = currentSettings ?? RecordingSettings.fromDefaults()
        let segmentURL = makeSegmentURL()
        segmentURLs.append(segmentURL)

        let activeCompositor: WebcamCompositor?
        if cameraEnabled {
            let comp = WebcamCompositor()
            self.compositor = comp
            activeCompositor = comp
            webcamBubble?.onLayoutChanged = { [weak self] layout in
                self?.compositor?.updateBubbleLayout(layout)
            }
            comp.imageAdjuster = imageAdjuster
            if let bubble = webcamBubble {
                comp.updateBubbleLayout(bubble.currentLayout())
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

        let activeRenderer: AnnotationRenderer?
        if let store = annotationStore {
            let renderer = AnnotationRenderer(store: store)
            self.annotationRenderer = renderer
            activeRenderer = renderer
        } else {
            activeRenderer = nil
        }

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

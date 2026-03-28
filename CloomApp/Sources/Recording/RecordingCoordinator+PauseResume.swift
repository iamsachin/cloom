import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Pause & Resume

extension RecordingCoordinator {

    func pauseRecording() {
        guard case .recording(let startedAt) = state else { return }

        let pausedAt = Date()
        state = .paused(startedAt: startedAt, pausedAt: pausedAt)

        Task {
            do {
                try await captureService.stopCapture()
            } catch {
                logger.error("Failed to stop capture for pause: \(error)")
            }

            // Capture segment duration for rewind calculations
            await loadCurrentSegmentDuration()

            showPausedToolbar(startedAt: startedAt)
        }
    }

    func resumeRecording() {
        guard case .paused(let startedAt, let pausedAt) = state else { return }

        pausedDuration += Date().timeIntervalSince(pausedAt)
        segmentIndex += 1
        recordingMetrics?.reportSegment()

        let settings = currentSettings ?? RecordingSettings.fromDefaults()
        let segmentURL = makeSegmentURL()
        segments.append(RecordingSegment(url: segmentURL, index: segmentIndex, duration: 0))

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
                try await startCaptureWithCurrentConfig(
                    outputURL: segmentURL,
                    filter: currentFilter,
                    settings: settings,
                    compositor: activeCompositor,
                    annotationRenderer: activeRenderer
                )
                state = .recording(startedAt: startedAt)
                showRecordingToolbar(startedAt: startedAt)
            } catch {
                logger.error("Failed to resume capture: \(error)")
                state = .idle
            }
        }
    }

    // MARK: - Segment Duration

    private func loadCurrentSegmentDuration() async {
        guard let last = segments.last else { return }
        let asset = AVURLAsset(url: last.url)
        do {
            let duration = try await asset.load(.duration)
            let index = segments.count - 1
            segments[index].duration = duration.seconds
            logger.info("Segment \(last.index) duration: \(duration.seconds)s")
        } catch {
            logger.error("Failed to load segment duration: \(error)")
        }
    }
}

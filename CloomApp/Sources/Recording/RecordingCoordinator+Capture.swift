import SwiftUI
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Pre-recording & Capture

extension RecordingCoordinator {

    private static func recordingTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }

    func beginPreRecordingFlow() {
        if pendingFilter == nil && selectedMode != .webcamOnly {
            Task {
                do {
                    _ = try await SCShareableContent.current
                } catch {
                    logger.info("Screen capture permission not yet granted — waiting for user")
                    state = .idle
                    return
                }
                enterReadyState()
            }
        } else {
            enterReadyState()
        }
    }

    private func enterReadyState() {
        state = .ready
        if cameraEnabled {
            startWebcam()
        }
        showReadyToolbar()
    }

    // MARK: - Countdown

    func showCountdownOverlay(count: Int) {
        switch selectedMode {
        case .region(_, let rect):
            countdownOverlay.show(count: count, region: rect)
        default:
            countdownOverlay.show(count: count)
        }
    }

    func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    func tickCountdown() {
        guard case .countdown(let remaining) = state else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }

        let next = remaining - 1
        if next > 0 {
            state = .countdown(next)
            showCountdownOverlay(count: next)
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownOverlay.dismiss()
            beginCapture()
        }
    }

    // MARK: - Capture

    func beginCapture() {
        guard checkDiskSpace() else {
            showLowDiskSpaceAlert()
            state = .idle
            return
        }

        // Handle webcam-only mode separately
        if selectedMode == .webcamOnly {
            beginWebcamOnlyCapture()
            return
        }

        let filename = "Cloom Recording \(Self.recordingTimestamp()).mp4"

        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate desktop directory")
            return
        }
        let outputURL = desktopURL.appendingPathComponent(filename)
        let settings = RecordingSettings.fromDefaults()

        // Reset segment tracking and set up for new recording
        resetSegmentState()
        self.currentOutputURL = outputURL
        self.currentSettings = settings

        // First segment writes directly to the final URL (if no pauses, it stays)
        let segmentURL = makeSegmentURL()
        segmentURLs.append(segmentURL)

        // Create compositor if camera is enabled
        let activeCompositor: WebcamCompositor?
        if cameraEnabled {
            let comp = WebcamCompositor()
            self.compositor = comp
            activeCompositor = comp
            // Pass image adjuster to compositor
            comp.imageAdjuster = imageAdjuster
            // Seed with current bubble position
            if let bubble = webcamBubble {
                comp.updateBubbleLayout(bubble.currentLayout())
            }
        } else {
            activeCompositor = nil
        }

        // Create annotation store and renderer
        let store = AnnotationStore()
        self.annotationStore = store
        let renderer = AnnotationRenderer(store: store)
        self.annotationRenderer = renderer

        // Create recording metrics and wire to capture service
        let metrics = RecordingMetrics()
        self.recordingMetrics = metrics
        captureService.recordingMetrics = metrics

        // Start webcam bubble + camera feed if camera is enabled
        if cameraEnabled {
            startWebcam()
        }

        // Resolve and store the active filter
        self.currentFilter = pendingFilter
        let activeFilter = pendingFilter
        pendingFilter = nil

        Task {
            do {
                try await startCaptureWithCurrentConfig(
                    outputURL: segmentURL,
                    filter: activeFilter,
                    settings: settings,
                    compositor: activeCompositor,
                    annotationRenderer: renderer
                )
            } catch {
                logger.error("Failed to start capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    func beginWebcamOnlyCapture() {
        let filename = "Cloom Webcam \(Self.recordingTimestamp()).mp4"

        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate desktop directory")
            return
        }
        let outputURL = desktopURL.appendingPathComponent(filename)
        let settings = RecordingSettings.fromDefaults()

        resetSegmentState()
        self.currentOutputURL = outputURL
        self.currentSettings = settings

        let service = WebcamRecordingService()
        service.imageAdjuster = imageAdjuster
        let gainProc = MicGainProcessor(sensitivity: settings.micSensitivity)
        if !gainProc.isUnity { service.micGainProcessor = gainProc }
        if blurEnabled {
            let segmenter = PersonSegmenter()
            segmenter.isEnabled = true
            service.personSegmenter = segmenter
        }
        self.webcamRecordingService = service

        // Show bubble for preview
        if webcamBubble == nil {
            webcamBubble = WebcamBubbleWindow()
        }
        service.onPreviewFrame = { [weak self] image, pixelBuffer in
            Task { @MainActor in
                self?.webcamBubble?.updateFrame(image)
            }
        }

        Task {
            do {
                try await service.startRecording(
                    outputURL: outputURL,
                    cameraDeviceID: settings.cameraDeviceID,
                    micEnabled: micEnabled,
                    micDeviceID: settings.micDeviceID
                )
                let now = Date()
                state = .recording(startedAt: now)
                recordingStartedAt = now
                webcamBubble?.show()
                showRecordingToolbar(startedAt: now)
            } catch {
                logger.error("Failed to start webcam-only capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    /// Start capture using either a pre-built SCContentFilter or the selected CaptureMode.
    func startCaptureWithCurrentConfig(
        outputURL: URL,
        filter: SCContentFilter?,
        settings: RecordingSettings,
        compositor: WebcamCompositor?,
        annotationRenderer: AnnotationRenderer?
    ) async throws {
        if let filter {
            try await captureService.startCapture(
                outputURL: outputURL,
                filter: filter,
                micEnabled: micEnabled,
                settings: settings,
                compositor: compositor,
                annotationRenderer: annotationRenderer
            )
        } else {
            try await captureService.startCapture(
                outputURL: outputURL,
                mode: selectedMode,
                micEnabled: micEnabled,
                settings: settings,
                compositor: compositor,
                annotationRenderer: annotationRenderer
            )
        }
    }

    func makeSegmentURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let segmentFilename = "cloom_segment_\(segmentIndex)_\(UUID().uuidString).mp4"
        return tempDir.appendingPathComponent(segmentFilename)
    }
}

import SwiftUI
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Pre-recording & Capture

extension RecordingCoordinator {

    func beginPreRecordingFlow() {
        if pendingFilter == nil {
            Task {
                do {
                    _ = try await SCShareableContent.current
                } catch {
                    logger.info("Screen capture permission not yet granted — waiting for user")
                    state = .idle
                    return
                }
                state = .countdown(3)
                showCountdownOverlay(count: 3)
                startCountdownTimer()
            }
        } else {
            state = .countdown(3)
            showCountdownOverlay(count: 3)
            startCountdownTimer()
        }
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Cloom Recording \(timestamp).mp4"

        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate desktop directory")
            return
        }
        let outputURL = desktopURL.appendingPathComponent(filename)
        self.currentOutputURL = outputURL

        let settings = RecordingSettings.fromDefaults()
        self.currentSettings = settings

        // Reset segment tracking
        segmentURLs = []
        segmentIndex = 0
        pausedDuration = 0

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

        // Start webcam bubble + camera feed if camera is enabled
        if cameraEnabled {
            startWebcam()
        }

        Task {
            do {
                if let filter = pendingFilter {
                    self.currentFilter = filter
                    try await captureService.startCapture(
                        outputURL: segmentURL,
                        filter: filter,
                        micEnabled: micEnabled,
                        settings: settings,
                        compositor: activeCompositor,
                        annotationRenderer: renderer
                    )
                    pendingFilter = nil
                } else {
                    self.currentFilter = nil
                    try await captureService.startCapture(
                        outputURL: segmentURL,
                        mode: selectedMode,
                        micEnabled: micEnabled,
                        settings: settings,
                        compositor: activeCompositor,
                        annotationRenderer: renderer
                    )
                }
            } catch {
                logger.error("Failed to start capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    func beginWebcamOnlyCapture() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Cloom Webcam \(timestamp).mp4"

        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate desktop directory")
            return
        }
        let outputURL = desktopURL.appendingPathComponent(filename)
        self.currentOutputURL = outputURL

        let settings = RecordingSettings.fromDefaults()
        self.currentSettings = settings

        segmentURLs = []
        segmentIndex = 0
        pausedDuration = 0

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

                // Show bubble control pill
                if let bubblePanel = webcamBubble?.windowPanel {
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
            } catch {
                logger.error("Failed to start webcam-only capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    func makeSegmentURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let segmentFilename = "cloom_segment_\(segmentIndex)_\(UUID().uuidString).mp4"
        return tempDir.appendingPathComponent(segmentFilename)
    }
}

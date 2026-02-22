import SwiftUI
import SwiftData
import AVFoundation
@preconcurrency import ScreenCaptureKit
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

@MainActor
final class RecordingCoordinator: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var selectedMode: CaptureMode = .default
    @Published var micEnabled: Bool = false
    @Published var cameraEnabled: Bool = false
    @Published var blurEnabled: Bool = false
    @Published var annotationsEnabled: Bool = false
    @Published var clickEmphasisEnabled: Bool = false
    @Published var cursorSpotlightEnabled: Bool = false

    let modelContainer: ModelContainer
    let captureService = ScreenCaptureService()
    var countdownTimer: Timer?
    var currentOutputURL: URL?

    let countdownOverlay = CountdownOverlayWindow()
    let recordingToolbar = RecordingToolbarPanel()
    let regionSelector = RegionSelectionWindow()
    let regionHighlight = RegionHighlightOverlay()

    var cameraService: CameraService?
    var webcamBubble: WebcamBubbleWindow?
    var personSegmenter: PersonSegmenter?
    var compositor: WebcamCompositor?

    // Webcam enhancements
    var imageAdjuster: WebcamImageAdjuster?
    var bubbleControlPill: BubbleControlPill?
    var webcamRecordingService: WebcamRecordingService?

    // Annotations
    var annotationStore: AnnotationStore?
    var annotationRenderer: AnnotationRenderer?
    var annotationCanvas: AnnotationCanvasWindow?
    var annotationToolbar: AnnotationToolbarPanel?
    var clickEmphasisMonitor: ClickEmphasisMonitor?
    var cursorSpotlightMonitor: CursorSpotlightMonitor?

    let systemPicker = SystemContentPicker()
    var pendingFilter: SCContentFilter?

    // Pause/resume segment tracking
    var segmentURLs: [URL] = []
    var segmentIndex: Int = 0
    var currentSettings: RecordingSettings?
    var currentFilter: SCContentFilter?
    var pausedDuration: TimeInterval = 0
    var recordingStartedAt: Date?
    let stitcher = SegmentStitcher()
    var exportProgressWindow: ExportProgressWindow?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        captureService.delegate = self
    }

    // MARK: - Public API

    func startRecording() {
        guard state.isIdle else { return }
        selectedMode = .default
        beginPreRecordingFlow()
    }

    func startRecordingWithPicker() {
        guard state.isIdle else { return }
        state = .selectingContent
        systemPicker.present(
            onFilterSelected: { [weak self] filter in
                Task { @MainActor [weak self] in
                    self?.pendingFilter = filter
                    self?.beginPreRecordingFlow()
                }
            },
            onCancelled: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                }
            }
        )
    }

    func selectMode(_ mode: CaptureMode) {
        pendingFilter = nil
        selectedMode = mode
        beginPreRecordingFlow()
    }

    func startWebcamOnlyRecording() {
        guard state.isIdle else { return }
        selectedMode = .webcamOnly
        cameraEnabled = true
        beginPreRecordingFlow()
    }

    func startRegionSelection() {
        regionSelector.show(
            onSelection: { [weak self] displayID, rect in
                Task { @MainActor [weak self] in
                    self?.selectMode(.region(displayID: displayID, rect: rect))
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                }
            }
        )
    }

    func cancelContentSelection() {
        state = .idle
    }

    func stopRecording() {
        guard state.isActiveOrPaused else { return }

        let wasPaused = state.isPaused
        let isWebcamOnly = selectedMode == .webcamOnly
        state = .stopping
        recordingToolbar.dismiss()
        regionHighlight.dismiss()
        cleanupAnnotations()
        bubbleControlPill?.dismiss()
        bubbleControlPill = nil

        Task {
            if isWebcamOnly {
                // Webcam-only: stop the webcam recording service
                await webcamRecordingService?.stopRecording()
                webcamRecordingService = nil
                webcamBubble?.dismiss()
                webcamBubble = nil
                imageAdjuster = nil

                guard let finalURL = currentOutputURL else {
                    state = .idle
                    return
                }
                await handleRecordingFinished(outputURL: finalURL)
            } else {
                stopWebcam()

                // If not paused, stop the current capture to finalize the segment
                if !wasPaused {
                    do {
                        try await captureService.stopCapture()
                    } catch {
                        logger.error("Failed to stop capture: \(error)")
                    }
                }

                guard let finalURL = currentOutputURL else {
                    state = .idle
                    return
                }

                if segmentURLs.count <= 1 {
                    // Single segment — move temp file to final destination
                    if let segmentURL = segmentURLs.first {
                        do {
                            try FileManager.default.moveItem(at: segmentURL, to: finalURL)
                        } catch {
                            logger.error("Failed to move segment to final URL: \(error)")
                        }
                    }
                    await handleRecordingFinished(outputURL: finalURL)
                } else {
                    // Multiple segments — stitch into final URL
                    let progressWindow = ExportProgressWindow()
                    self.exportProgressWindow = progressWindow
                    progressWindow.show(message: "Stitching segments...")

                    do {
                        try await stitcher.stitch(segments: segmentURLs, to: finalURL) { progress in
                            Task { @MainActor in
                                progressWindow.updateProgress(progress)
                            }
                        }
                        progressWindow.dismiss()
                        await handleRecordingFinished(outputURL: finalURL)
                    } catch {
                        progressWindow.dismiss()
                        logger.error("Failed to stitch segments: \(error)")
                        state = .idle
                    }
                    self.exportProgressWindow = nil
                }
            }

            segmentURLs = []
            segmentIndex = 0
            pausedDuration = 0
            recordingStartedAt = nil
            currentSettings = nil
            currentFilter = nil
        }
    }

    func discardRecording() {
        guard state.isActiveOrPaused else { return }
        guard DiscardConfirmation.show() else { return }
        performDiscard()
    }

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
            // Re-wire camera frames and layout to new compositor
            webcamBubble?.onLayoutChanged = { [weak self] layout in
                self?.compositor?.updateBubbleLayout(layout)
            }
            // Send current layout immediately
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

        // Re-wire annotation renderer for new segment (store persists)
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

    func toggleMic() {
        micEnabled.toggle()
        guard state.isRecording else { return }
        Task {
            do {
                try await captureService.updateConfiguration(micEnabled: micEnabled)
            } catch {
                logger.error("Failed to toggle mic: \(error)")
            }
        }
    }

    func toggleCamera() {
        cameraEnabled.toggle()
        if cameraEnabled {
            // Create compositor if toggling ON mid-recording
            if state.isRecording && compositor == nil {
                let comp = WebcamCompositor()
                self.compositor = comp
                captureService.updateCompositor(comp)
            }
            startWebcam()
            // Seed compositor with current bubble position
            if let comp = compositor, let bubble = webcamBubble {
                comp.updateBubbleLayout(bubble.currentLayout())
            }
        } else {
            stopWebcam()
            // Remove compositor from capture pipeline
            captureService.updateCompositor(nil)
        }
    }

    func toggleBlur() {
        blurEnabled.toggle()
        personSegmenter?.isEnabled = blurEnabled
    }

    func toggleAnnotations() {
        annotationsEnabled.toggle()
        if annotationsEnabled {
            showAnnotationCanvas()
        } else {
            hideAnnotationCanvas()
        }
    }

    func toggleClickEmphasis() {
        clickEmphasisEnabled.toggle()
        if clickEmphasisEnabled {
            if let store = annotationStore {
                if clickEmphasisMonitor == nil {
                    clickEmphasisMonitor = ClickEmphasisMonitor(store: store)
                }
                clickEmphasisMonitor?.start(captureArea: getCaptureAreaScreenRect())
            }
        } else {
            clickEmphasisMonitor?.stop()
        }
    }

    func toggleCursorSpotlight() {
        cursorSpotlightEnabled.toggle()
        if cursorSpotlightEnabled {
            if let store = annotationStore {
                if cursorSpotlightMonitor == nil {
                    cursorSpotlightMonitor = CursorSpotlightMonitor(store: store)
                }
                store.setSpotlightEnabled(true)
                cursorSpotlightMonitor?.start(captureArea: getCaptureAreaScreenRect())
            }
        } else {
            annotationStore?.setSpotlightEnabled(false)
            cursorSpotlightMonitor?.stop()
        }
    }
}

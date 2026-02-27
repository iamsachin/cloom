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
    var webcamRecordingService: WebcamRecordingService?
    var webcamSettingsObserver: NSObjectProtocol?

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

    func confirmRecording() {
        guard state.isReady else { return }
        recordingToolbar.dismiss()
        state = .countdown(3)
        showCountdownOverlay(count: 3)
        startCountdownTimer()
    }

    func cancelReadyState() {
        guard state.isReady else { return }
        recordingToolbar.dismiss()
        if cameraEnabled {
            stopWebcam()
        }
        cleanupAnnotations()
        state = .idle
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

        let tracker = PostRecordingTracker.shared
        let recordingTitle = currentOutputURL?.deletingPathExtension().lastPathComponent ?? "Recording"
        tracker.start(title: recordingTitle)

        Task {
            if isWebcamOnly {
                await webcamRecordingService?.stopRecording()
                webcamRecordingService = nil
                webcamBubble?.dismiss()
                webcamBubble = nil
                imageAdjuster = nil

                guard let finalURL = currentOutputURL else {
                    tracker.finish()
                    state = .idle
                    return
                }
                tracker.updateStep(.extractingMetadata)
                await handleRecordingFinished(outputURL: finalURL)
            } else {
                stopWebcam()

                if !wasPaused {
                    do {
                        try await captureService.stopCapture()
                    } catch {
                        logger.error("Failed to stop capture: \(error)")
                    }
                }

                guard let finalURL = currentOutputURL else {
                    tracker.finish()
                    state = .idle
                    return
                }

                if segmentURLs.count <= 1 {
                    if let segmentURL = segmentURLs.first {
                        tracker.updateStep(.mixingAudio)
                        do {
                            try await stitcher.mixdownAudio(inputURL: segmentURL, to: finalURL)
                        } catch {
                            logger.error("Failed to mixdown audio: \(error), falling back to move")
                            try? FileManager.default.moveItem(at: segmentURL, to: finalURL)
                        }
                    }
                    tracker.updateStep(.extractingMetadata)
                    await handleRecordingFinished(outputURL: finalURL)
                } else {
                    tracker.updateStep(.stitchingSegments)
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
                        tracker.updateStep(.extractingMetadata)
                        await handleRecordingFinished(outputURL: finalURL)
                    } catch {
                        progressWindow.dismiss()
                        tracker.finish()
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
}

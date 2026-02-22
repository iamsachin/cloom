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
    private let modelContainer: ModelContainer
    private let captureService = ScreenCaptureService()
    private var countdownTimer: Timer?
    private var currentOutputURL: URL?

    private let countdownOverlay = CountdownOverlayWindow()
    private let recordingToolbar = RecordingToolbarPanel()
    private let regionSelector = RegionSelectionWindow()
    private let regionHighlight = RegionHighlightOverlay()

    private var cameraService: CameraService?
    private var webcamBubble: WebcamBubbleWindow?
    private var personSegmenter: PersonSegmenter?
    private var compositor: WebcamCompositor?

    // Webcam enhancements
    private var imageAdjuster: WebcamImageAdjuster?
    private var bubbleControlPill: BubbleControlPill?
    private var webcamRecordingService: WebcamRecordingService?

    // Annotations
    private var annotationStore: AnnotationStore?
    private var annotationRenderer: AnnotationRenderer?
    private var annotationCanvas: AnnotationCanvasWindow?
    private var annotationToolbar: AnnotationToolbarPanel?
    private var clickEmphasisMonitor: ClickEmphasisMonitor?
    private var cursorSpotlightMonitor: CursorSpotlightMonitor?

    private let systemPicker = SystemContentPicker()
    private var pendingFilter: SCContentFilter?

    // Pause/resume segment tracking
    private var segmentURLs: [URL] = []
    private var segmentIndex: Int = 0
    private var currentSettings: RecordingSettings?
    private var currentFilter: SCContentFilter?
    private var pausedDuration: TimeInterval = 0
    private var recordingStartedAt: Date?
    private let stitcher = SegmentStitcher()
    private var exportProgressWindow: ExportProgressWindow?

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

    /// Returns the screen rect of the current capture area for normalizing mouse positions.
    private func getCaptureAreaScreenRect() -> CGRect {
        switch selectedMode {
        case .fullScreen(let displayID):
            for screen in NSScreen.screens {
                let key = NSDeviceDescriptionKey("NSScreenNumber")
                if let screenID = screen.deviceDescription[key] as? CGDirectDisplayID, screenID == displayID {
                    return screen.frame
                }
            }
            return NSScreen.main?.frame ?? .zero

        case .window:
            // For window captures, use the main screen as approximation
            return NSScreen.main?.frame ?? .zero

        case .region(_, let rect):
            return rect

        case .webcamOnly:
            return NSScreen.main?.frame ?? .zero
        }
    }

    // MARK: - Discard

    private func performDiscard() {
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
                await webcamRecordingService?.stopRecording()
                webcamRecordingService = nil
                webcamBubble?.dismiss()
                webcamBubble = nil
                imageAdjuster = nil
            } else {
                stopWebcam()

                if !wasPaused {
                    do {
                        try await captureService.stopCapture()
                    } catch {
                        logger.error("Failed to stop capture during discard: \(error)")
                    }
                }
            }

            // Delete all segment files
            for url in segmentURLs {
                try? FileManager.default.removeItem(at: url)
            }
            // Delete the final output URL if it exists
            if let outputURL = currentOutputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }

            // Reset state
            segmentURLs = []
            segmentIndex = 0
            pausedDuration = 0
            recordingStartedAt = nil
            currentSettings = nil
            currentFilter = nil
            currentOutputURL = nil

            state = .idle
            logger.info("Recording discarded")
        }
    }

    // MARK: - Annotation Canvas

    private func showAnnotationCanvas() {
        guard let store = annotationStore else { return }
        guard let screen = NSScreen.main else { return }

        if annotationCanvas == nil {
            annotationCanvas = AnnotationCanvasWindow()
        }
        annotationCanvas?.onEscape = { [weak self] in
            self?.annotationsEnabled = false
            self?.hideAnnotationCanvas()
        }
        annotationCanvas?.isDrawingEnabled = true
        annotationCanvas?.show(covering: screen, store: store)

        // Show annotation toolbar
        if annotationToolbar == nil {
            annotationToolbar = AnnotationToolbarPanel()
        }
        annotationToolbar?.show(
            currentTool: annotationCanvas?.currentTool ?? .pen,
            currentColor: annotationCanvas?.currentColor ?? .red,
            currentLineWidth: annotationCanvas?.currentLineWidth ?? 3.0,
            onToolChanged: { [weak self] tool in
                self?.annotationCanvas?.currentTool = tool
            },
            onColorChanged: { [weak self] color in
                self?.annotationCanvas?.currentColor = color
            },
            onLineWidthChanged: { [weak self] width in
                self?.annotationCanvas?.currentLineWidth = width
            },
            onUndo: { [weak self] in
                self?.annotationStore?.undo()
                self?.annotationCanvas?.canvasView?.needsDisplay = true
            },
            onClearAll: { [weak self] in
                self?.annotationStore?.clearAll()
                self?.annotationCanvas?.canvasView?.needsDisplay = true
            },
            onDismiss: { [weak self] in
                self?.annotationsEnabled = false
                self?.hideAnnotationCanvas()
            }
        )
    }

    private func hideAnnotationCanvas() {
        annotationCanvas?.isDrawingEnabled = false
        annotationToolbar?.dismiss()
    }

    private func cleanupAnnotations() {
        annotationsEnabled = false
        clickEmphasisEnabled = false
        cursorSpotlightEnabled = false
        annotationCanvas?.dismiss()
        annotationCanvas = nil
        annotationToolbar?.dismiss()
        annotationToolbar = nil
        clickEmphasisMonitor?.stop()
        clickEmphasisMonitor = nil
        cursorSpotlightMonitor?.stop()
        cursorSpotlightMonitor = nil
        annotationStore = nil
        annotationRenderer = nil
    }

    // MARK: - Recording Toolbar

    private func showRecordingToolbar(startedAt: Date) {
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

    // MARK: - Pre-recording flow

    private func beginPreRecordingFlow() {
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

    private func showCountdownOverlay(count: Int) {
        switch selectedMode {
        case .region(_, let rect):
            countdownOverlay.show(count: count, region: rect)
        default:
            countdownOverlay.show(count: count)
        }
    }

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    private func tickCountdown() {
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

    private func beginCapture() {
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

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
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

    private func beginWebcamOnlyCapture() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Cloom Webcam \(timestamp).mp4"

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let outputURL = desktopURL.appendingPathComponent(filename)
        self.currentOutputURL = outputURL

        let settings = RecordingSettings.fromDefaults()
        self.currentSettings = settings

        segmentURLs = []
        segmentIndex = 0
        pausedDuration = 0

        let service = WebcamRecordingService()
        service.imageAdjuster = imageAdjuster
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

    private func makeSegmentURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let segmentFilename = "cloom_segment_\(segmentIndex)_\(UUID().uuidString).mp4"
        return tempDir.appendingPathComponent(segmentFilename)
    }

    // MARK: - Webcam

    private func startWebcam() {
        let settings = RecordingSettings.fromDefaults()

        if cameraService == nil {
            cameraService = CameraService(deviceID: settings.cameraDeviceID)
        }
        if blurEnabled && personSegmenter == nil {
            personSegmenter = PersonSegmenter()
            personSegmenter?.isEnabled = true
        }
        if webcamBubble == nil {
            webcamBubble = WebcamBubbleWindow()
        }

        // Create image adjuster with current settings
        let adjuster = WebcamImageAdjuster(adjustments: loadWebcamAdjustments())
        self.imageAdjuster = adjuster
        compositor?.imageAdjuster = adjuster

        // Wire bubble layout changes to compositor
        webcamBubble?.onLayoutChanged = { [weak self] layout in
            self?.compositor?.updateBubbleLayout(layout)
        }

        cameraService?.onFrame = { [weak self] pixelBuffer, ciImage in
            guard let self else { return }

            // Update compositor frame (thread-safe, called from camera queue)
            self.compositor?.updateWebcamFrame(pixelBuffer)

            Task { @MainActor in
                self.handleCameraFrameForPreview(ciImage, pixelBuffer: pixelBuffer)
            }
        }
        cameraService?.start()
        webcamBubble?.show()
    }

    private func stopWebcam() {
        cameraService?.stop()
        webcamBubble?.dismiss()
        bubbleControlPill?.dismiss()
        bubbleControlPill = nil
        compositor = nil
        imageAdjuster = nil
    }

    private func handleCameraFrameForPreview(_ image: CIImage, pixelBuffer: CVPixelBuffer) {
        var displayImage = image

        // Apply image adjustments for preview
        if let adjuster = imageAdjuster {
            displayImage = adjuster.apply(to: displayImage)
        }

        if blurEnabled, let segmenter = personSegmenter {
            displayImage = segmenter.process(image: displayImage, pixelBuffer: pixelBuffer)
        }

        webcamBubble?.updateFrame(displayImage)
    }

    private func loadWebcamAdjustments() -> WebcamAdjustments {
        let defaults = UserDefaults.standard
        return WebcamAdjustments(
            brightness: Float(defaults.double(forKey: "webcamBrightness")),
            contrast: {
                let v = defaults.double(forKey: "webcamContrast")
                return v == 0 ? 1 : Float(v)
            }(),
            saturation: {
                let v = defaults.double(forKey: "webcamSaturation")
                return v == 0 ? 1 : Float(v)
            }(),
            highlights: {
                let v = defaults.double(forKey: "webcamHighlights")
                return v == 0 ? 1 : Float(v)
            }(),
            shadows: Float(defaults.double(forKey: "webcamShadows")),
            temperature: {
                let v = defaults.double(forKey: "webcamTemperature")
                return v == 0 ? 6500 : Float(v)
            }(),
            tint: Float(defaults.double(forKey: "webcamTint"))
        )
    }

    // MARK: - Alerts

    private func checkDiskSpace() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: homeDir),
              let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return true // If we can't check, allow recording
        }
        let oneGB: Int64 = 1_073_741_824
        return freeSize >= oneGB
    }

    private func showLowDiskSpaceAlert() {
        let alert = NSAlert()
        alert.messageText = "Low Disk Space"
        alert.informativeText = "Less than 1 GB of free disk space remaining. Free up space before recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showCaptureFailedAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Failed"
        alert.informativeText = "\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    // MARK: - Post-Recording

    private func handleRecordingFinished(outputURL: URL) async {
        let asset = AVURLAsset(url: outputURL)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            logger.error("Failed to load duration: \(error)")
            duration = .zero
        }

        var width: Int32 = 0
        var height: Int32 = 0
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                width = Int32(size.width)
                height = Int32(size.height)
            }
        } catch {
            logger.error("Failed to load video track: \(error)")
        }

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        } else {
            fileSize = 0
        }

        let thumbnailPath = await ThumbnailGenerator.generateThumbnail(for: outputURL) ?? ""

        let recordingType: String
        if selectedMode == .webcamOnly {
            recordingType = "webcamOnly"
        } else if cameraEnabled {
            recordingType = "screenAndWebcam"
        } else {
            recordingType = "screenOnly"
        }

        let context = ModelContext(modelContainer)
        let durationMs = Int64(duration.seconds * 1000)
        let record = VideoRecord(
            title: outputURL.deletingPathExtension().lastPathComponent,
            filePath: outputURL.path,
            thumbnailPath: thumbnailPath,
            durationMs: durationMs,
            width: width,
            height: height,
            fileSizeBytes: fileSize,
            recordingType: recordingType,
            webcamFilePath: nil
        )
        context.insert(record)
        do {
            try context.save()
            logger.info("Saved recording: \(record.title) (\(durationMs)ms)")
        } catch {
            logger.error("Failed to save recording: \(error)")
        }

        // Launch AI pipeline in background
        let videoID = record.id
        let audioPath = outputURL.path
        let container = self.modelContainer
        Task.detached {
            let orchestrator = AIOrchestrator()
            await orchestrator.runPipeline(
                videoRecordID: videoID,
                audioPath: audioPath,
                modelContainer: container
            )
        }

        showRecordingCompleteNotification(title: record.title)
        state = .idle
    }

    private func showRecordingCompleteNotification(title: String) {
        // Default to true if never set
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "notificationsEnabled") != nil {
            guard defaults.bool(forKey: "notificationsEnabled") else { return }
        }

        let content = UNMutableNotificationContent()
        content.title = "Recording Complete"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = "RECORDING_COMPLETE"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

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

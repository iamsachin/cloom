import SwiftUI
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - UI: Annotations, Toolbar, Alerts, Webcam

extension RecordingCoordinator {

    // MARK: - Annotation Canvas

    func showAnnotationCanvas() {
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

    func hideAnnotationCanvas() {
        annotationCanvas?.isDrawingEnabled = false
        annotationToolbar?.dismiss()
    }

    func cleanupAnnotations() {
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

    // MARK: - Webcam

    func startWebcam() {
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

    func stopWebcam() {
        cameraService?.stop()
        webcamBubble?.dismiss()
        bubbleControlPill?.dismiss()
        bubbleControlPill = nil
        compositor = nil
        imageAdjuster = nil
    }

    func handleCameraFrameForPreview(_ image: CIImage, pixelBuffer: CVPixelBuffer) {
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

    func loadWebcamAdjustments() -> WebcamAdjustments {
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

    /// Returns the screen rect of the current capture area for normalizing mouse positions.
    func getCaptureAreaScreenRect() -> CGRect {
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

    func performDiscard() {
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

    // MARK: - Alerts

    func checkDiskSpace() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: homeDir),
              let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return true // If we can't check, allow recording
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

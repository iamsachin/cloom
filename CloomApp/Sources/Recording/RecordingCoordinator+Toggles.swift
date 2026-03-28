import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Toggle Controls

extension RecordingCoordinator {

    func toggleSystemAudio() {
        systemAudioEnabled.toggle()
        UserDefaults.standard.set(systemAudioEnabled, forKey: UserDefaultsKeys.systemAudioEnabled)
        guard state.isActiveOrPaused else { return }
        Task {
            do {
                try await captureService.updateConfiguration(systemAudioEnabled: systemAudioEnabled)
            } catch {
                logger.error("Failed to toggle system audio: \(error)")
            }
        }
    }

    func toggleMic() {
        micEnabled.toggle()
        guard state.isActiveOrPaused else { return }
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
            if state.isActiveOrPaused && compositor == nil {
                let comp = WebcamCompositor()
                self.compositor = comp
                captureService.updateCompositor(comp)
            }
            startWebcam()
            if let comp = compositor, let bubble = webcamBubble {
                comp.updateBubbleLayout(bubble.currentLayout())
            }
        } else {
            stopWebcam()
            if state.isActiveOrPaused {
                captureService.updateCompositor(nil)
            }
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

    func toggleZoom() {
        zoomEnabled.toggle()
        if zoomEnabled {
            if let store = annotationStore {
                if zoomClickMonitor == nil {
                    zoomClickMonitor = ZoomClickMonitor(store: store)
                }
                zoomClickMonitor?.start(captureArea: getCaptureAreaScreenRect())
            }
        } else {
            zoomClickMonitor?.stop()
            annotationStore?.setZoomEnabled(false)
        }
    }

    func toggleKeystroke() {
        keystrokeEnabled.toggle()
        if keystrokeEnabled {
            // Create annotation store eagerly if it doesn't exist yet (e.g. in ready state)
            let store: AnnotationStore
            if let existing = annotationStore {
                store = existing
            } else {
                store = AnnotationStore()
                self.annotationStore = store
                self.annotationRenderer = AnnotationRenderer(store: store)
            }

            if keystrokeMonitor == nil {
                keystrokeMonitor = KeystrokeMonitor(store: store)
            }
            store.setKeystrokeEnabled(true)

            // Apply saved settings
            let posRaw = UserDefaults.standard.string(forKey: UserDefaultsKeys.keystrokePosition) ?? KeystrokePosition.bottomLeft.rawValue
            let position = KeystrokePosition(rawValue: posRaw) ?? .bottomLeft
            store.setKeystrokePosition(position)

            let modeRaw = UserDefaults.standard.string(forKey: UserDefaultsKeys.keystrokeDisplayMode) ?? KeystrokeDisplayMode.allKeys.rawValue
            let displayMode = KeystrokeDisplayMode(rawValue: modeRaw) ?? .allKeys
            store.setKeystrokeDisplayMode(displayMode)

            keystrokeMonitor?.start()

            // Show on-screen overlay
            if keystrokeOverlay == nil {
                keystrokeOverlay = KeystrokeOverlayWindow()
            }
            let screenFrame = NSScreen.main?.frame ?? .zero
            keystrokeOverlay?.show(store: store, screenFrame: screenFrame)
        } else {
            keystrokeMonitor?.stop()
            annotationStore?.setKeystrokeEnabled(false)
            keystrokeOverlay?.dismiss()
        }
    }
}

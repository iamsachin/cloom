import AppKit

// MARK: - Annotation Canvas & Toolbar

extension RecordingCoordinator {

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
    }

    func hideAnnotationCanvas() {
        annotationCanvas?.isDrawingEnabled = false
    }

    func cleanupAnnotations() {
        annotationsEnabled = false
        clickEmphasisEnabled = false
        cursorSpotlightEnabled = false
        zoomEnabled = false
        keystrokeEnabled = false
        keystrokeMonitor?.stop()
        keystrokeMonitor = nil
        keystrokeOverlay?.dismiss()
        keystrokeOverlay = nil
        dismissTeleprompter()
        teleprompterOverlay = nil
        annotationCanvas?.dismiss()
        annotationCanvas = nil
        annotationToolbar?.dismiss()
        annotationToolbar = nil
        clickEmphasisMonitor?.stop()
        clickEmphasisMonitor = nil
        cursorSpotlightMonitor?.stop()
        cursorSpotlightMonitor = nil
        zoomClickMonitor?.stop()
        zoomClickMonitor = nil
        annotationStore = nil
        annotationRenderer = nil
    }
}

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
}

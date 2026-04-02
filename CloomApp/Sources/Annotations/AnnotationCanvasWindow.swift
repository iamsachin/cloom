import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationCanvas")

/// Custom NSPanel subclass that can become key window for text input.
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Transparent NSPanel overlay for drawing annotations.
/// Uses sharingType = .none so SCStream ignores it (annotations are burned in via AnnotationRenderer).
@MainActor
final class AnnotationCanvasWindow {
    private var panel: NSPanel?
    private(set) var canvasView: AnnotationCanvasView?

    /// Called when the user presses Escape while drawing — used to exit draw mode.
    var onEscape: (() -> Void)?

    var isDrawingEnabled: Bool = false {
        didSet {
            panel?.ignoresMouseEvents = !isDrawingEnabled
            if isDrawingEnabled {
                panel?.level = .screenSaver
                panel?.makeKey()
                if let view = canvasView {
                    panel?.makeFirstResponder(view)
                }
            } else {
                panel?.level = .floating
            }
        }
    }

    var currentTool: AnnotationTool = .pen {
        didSet { canvasView?.currentTool = currentTool }
    }

    var currentColor: StrokeColor = .red {
        didSet { canvasView?.currentColor = currentColor }
    }

    var currentLineWidth: CGFloat = 3.0 {
        didSet { canvasView?.currentLineWidth = currentLineWidth }
    }

    func show(covering screen: NSScreen, store: AnnotationStore) {
        if panel == nil {
            createPanel(screen: screen, store: store)
        }
        panel?.orderFrontRegardless()
        logger.info("Annotation canvas shown")
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        canvasView = nil
        logger.info("Annotation canvas dismissed")
    }

    private func createPanel(screen: NSScreen, store: AnnotationStore) {
        let frame = screen.frame

        let panel = KeyablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = !isDrawingEnabled
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = UserDefaults.standard.bool(forKey: UserDefaultsKeys.creatorModeEnabled) ? .readOnly : .none

        let view = AnnotationCanvasView(frame: frame, store: store, screenFrame: frame)
        view.currentTool = currentTool
        view.currentColor = currentColor
        view.currentLineWidth = currentLineWidth
        view.onEscape = { [weak self] in
            self?.onEscape?()
        }
        panel.contentView = view

        self.panel = panel
        self.canvasView = view
    }
}

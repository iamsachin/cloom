import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationToolbar")

@MainActor
final class AnnotationToolbarPanel {
    private var panel: NSPanel?

    func show(
        currentTool: AnnotationTool,
        currentColor: StrokeColor,
        currentLineWidth: CGFloat,
        onToolChanged: @escaping (AnnotationTool) -> Void,
        onColorChanged: @escaping (StrokeColor) -> Void,
        onLineWidthChanged: @escaping (CGFloat) -> Void,
        onUndo: @escaping () -> Void,
        onClearAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: AnnotationToolbarContentView(
                initialTool: currentTool,
                initialColor: currentColor,
                initialLineWidth: currentLineWidth,
                onToolChanged: onToolChanged,
                onColorChanged: onColorChanged,
                onLineWidthChanged: onLineWidthChanged,
                onUndo: onUndo,
                onClearAll: onClearAll,
                onDismiss: onDismiss
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 44)
        panel.contentView = hostingView

        if let screen = NSScreen.main {
            let x = screen.frame.midX - 240
            let y = screen.frame.maxY - 110
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
        logger.info("Annotation toolbar shown")
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        logger.info("Annotation toolbar dismissed")
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Must be above annotation canvas (.screenSaver) so toolbar stays clickable
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        self.panel = panel
    }
}

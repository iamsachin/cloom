import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RegionSelection")

@MainActor
final class RegionSelectionWindow {
    private var panels: [NSPanel] = []
    private var onSelection: ((CGDirectDisplayID, CGRect) -> Void)?
    private var onCancel: (() -> Void)?

    func show(onSelection: @escaping (CGDirectDisplayID, CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelection = onSelection
        self.onCancel = onCancel
        dismiss()

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = NSColor.black.withAlphaComponent(0.3)
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = false

            let selectionView = RegionSelectionView(
                screen: screen,
                onSelection: { [weak self] rect in
                    let displayID = screen.displayID
                    self?.dismiss()
                    onSelection(displayID, rect)
                },
                onCancel: { [weak self] in
                    self?.dismiss()
                    onCancel()
                }
            )
            panel.contentView = selectionView
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        NSCursor.crosshair.push()
        logger.info("Region selection started")
    }

    func dismiss() {
        NSCursor.pop()
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }
}

// MARK: - NSScreen displayID helper

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? CGDirectDisplayID) ?? CGMainDisplayID()
    }
}

// MARK: - Selection View

private final class RegionSelectionView: NSView {
    private let screen: NSScreen
    private let onSelection: (CGRect) -> Void
    private let onCancel: () -> Void

    private var dragOrigin: NSPoint?
    private var currentRect: NSRect?
    private let dashedLayer = CAShapeLayer()

    init(screen: NSScreen, onSelection: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.screen = screen
        self.onSelection = onSelection
        self.onCancel = onCancel
        super.init(frame: screen.frame)
        wantsLayer = true
        setupDashedLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupDashedLayer() {
        dashedLayer.strokeColor = NSColor.white.cgColor
        dashedLayer.fillColor = NSColor.white.withAlphaComponent(0.1).cgColor
        dashedLayer.lineWidth = 2
        dashedLayer.lineDashPattern = [6, 4]
        layer?.addSublayer(dashedLayer)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel()
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let current = convert(event.locationInWindow, from: nil)
        let rect = NSRect(
            x: min(origin.x, current.x),
            y: min(origin.y, current.y),
            width: abs(current.x - origin.x),
            height: abs(current.y - origin.y)
        )
        currentRect = rect
        updateDashedLayer(rect)
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width >= 10, rect.height >= 10 else {
            dragOrigin = nil
            currentRect = nil
            dashedLayer.path = nil
            return
        }

        let screenFrame = screen.frame
        let displayRect = CGRect(
            x: rect.origin.x,
            y: screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        onSelection(displayRect)
    }

    private func updateDashedLayer(_ rect: NSRect) {
        let path = CGPath(rect: rect, transform: nil)
        dashedLayer.path = path
    }
}

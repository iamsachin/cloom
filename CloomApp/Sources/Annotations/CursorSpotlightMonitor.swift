import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "CursorSpotlight")

/// Monitors global cursor movement and updates spotlight position in the annotation store.
@MainActor
final class CursorSpotlightMonitor {
    private let store: AnnotationStore
    private var moveMonitor: Any?
    private var dragMonitor: Any?
    private var captureArea: CGRect = .zero

    init(store: AnnotationStore) {
        self.store = store
    }

    func start(captureArea: CGRect) {
        self.captureArea = captureArea
        stop()

        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event)
            }
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event)
            }
        }
        logger.info("Cursor spotlight monitor started")
    }

    func stop() {
        if let moveMonitor {
            NSEvent.removeMonitor(moveMonitor)
        }
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
        moveMonitor = nil
        dragMonitor = nil
    }

    private func handleMouseMove(_ event: NSEvent) {
        let screenLocation = NSEvent.mouseLocation

        guard captureArea.width > 0, captureArea.height > 0 else { return }

        let normalizedX = (screenLocation.x - captureArea.origin.x) / captureArea.width
        let normalizedY = (screenLocation.y - captureArea.origin.y) / captureArea.height

        store.updateSpotlight(normalizedX: normalizedX, normalizedY: normalizedY)
    }
}

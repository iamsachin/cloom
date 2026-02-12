import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "CursorSpotlight")

/// Monitors global cursor movement and updates spotlight position in the annotation store.
@MainActor
final class CursorSpotlightMonitor {
    private let store: AnnotationStore
    private var globalMoveMonitor: Any?
    private var globalDragMonitor: Any?
    private var localMoveMonitor: Any?
    private var localDragMonitor: Any?
    private var captureArea: CGRect = .zero
    private var displayLinkTimer: Timer?

    init(store: AnnotationStore) {
        self.store = store
    }

    func start(captureArea: CGRect) {
        self.captureArea = captureArea
        stop()

        // Prompt for Accessibility permission if not granted
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            logger.warning("Accessibility not granted — cursor spotlight may not track in other apps")
        }

        // Global monitors: mouse movement in other apps
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
        }
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
        }

        // Local monitors: mouse movement within our app windows
        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
            return event
        }
        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
            return event
        }

        // Fallback: polling timer at 30Hz to catch any missed events
        displayLinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
        }

        // Set initial position immediately
        updatePosition()

        logger.info("Cursor spotlight monitor started (accessibility trusted: \(trusted))")
    }

    func stop() {
        if let globalMoveMonitor { NSEvent.removeMonitor(globalMoveMonitor) }
        if let globalDragMonitor { NSEvent.removeMonitor(globalDragMonitor) }
        if let localMoveMonitor { NSEvent.removeMonitor(localMoveMonitor) }
        if let localDragMonitor { NSEvent.removeMonitor(localDragMonitor) }
        globalMoveMonitor = nil
        globalDragMonitor = nil
        localMoveMonitor = nil
        localDragMonitor = nil
        displayLinkTimer?.invalidate()
        displayLinkTimer = nil
    }

    private func updatePosition() {
        let screenLocation = NSEvent.mouseLocation

        guard captureArea.width > 0, captureArea.height > 0 else { return }

        let normalizedX = (screenLocation.x - captureArea.origin.x) / captureArea.width
        let normalizedY = (screenLocation.y - captureArea.origin.y) / captureArea.height

        store.updateSpotlight(normalizedX: normalizedX, normalizedY: normalizedY)
    }
}

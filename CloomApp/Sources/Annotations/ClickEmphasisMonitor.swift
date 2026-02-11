import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ClickEmphasis")

/// Monitors global mouse clicks and creates ripple effects in the annotation store.
@MainActor
final class ClickEmphasisMonitor {
    private let store: AnnotationStore
    private var monitor: Any?
    private var captureArea: CGRect = .zero

    init(store: AnnotationStore) {
        self.store = store
    }

    func start(captureArea: CGRect) {
        self.captureArea = captureArea
        stop()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClick(event)
            }
        }
        logger.info("Click emphasis monitor started")
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleClick(_ event: NSEvent) {
        let screenLocation = NSEvent.mouseLocation

        // Convert screen location to normalized coordinates relative to capture area
        guard captureArea.width > 0, captureArea.height > 0 else { return }

        let normalizedX = (screenLocation.x - captureArea.origin.x) / captureArea.width
        let normalizedY = (screenLocation.y - captureArea.origin.y) / captureArea.height

        // Only create ripple if click is within capture area
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else { return }

        let ripple = ClickRipple(normalizedX: normalizedX, normalizedY: normalizedY)
        store.addRipple(ripple)
    }
}

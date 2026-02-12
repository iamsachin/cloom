import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ClickEmphasis")

/// Monitors global mouse clicks and creates ripple effects in the annotation store.
@MainActor
final class ClickEmphasisMonitor {
    private let store: AnnotationStore
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var captureArea: CGRect = .zero

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
            logger.warning("Accessibility not granted — click emphasis may not work for other apps")
        }

        // Global monitor: clicks in other apps
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClick(event)
            }
        }

        // Local monitor: clicks within our own app (toolbar, etc.)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClick(event)
            }
            return event
        }

        logger.info("Click emphasis monitor started (accessibility trusted: \(trusted))")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleClick(_ event: NSEvent) {
        let screenLocation = NSEvent.mouseLocation

        guard captureArea.width > 0, captureArea.height > 0 else { return }

        let normalizedX = (screenLocation.x - captureArea.origin.x) / captureArea.width
        let normalizedY = (screenLocation.y - captureArea.origin.y) / captureArea.height

        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else { return }

        let ripple = ClickRipple(normalizedX: normalizedX, normalizedY: normalizedY)
        store.addRipple(ripple)
        logger.debug("Click ripple at (\(normalizedX), \(normalizedY))")
    }
}

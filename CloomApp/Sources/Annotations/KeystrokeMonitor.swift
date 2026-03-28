import AppKit
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "KeystrokeMonitor")

/// Monitors global keyboard events and adds keystroke visualizations to the annotation store.
@MainActor
final class KeystrokeMonitor {
    private let store: AnnotationStore
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var lastModifierFlags: NSEvent.ModifierFlags = []

    init(store: AnnotationStore) {
        self.store = store
    }

    func start() {
        stop()
        lastModifierFlags = NSEvent.modifierFlags

        // Check Accessibility permission silently
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            logger.warning("Accessibility not granted — keystroke visualization may not work for other apps")
        }

        // Key down events
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyDown(event)
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyDown(event)
            }
            return event
        }

        // Modifier-only key presses (Shift, Cmd, etc. pressed alone)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event)
            }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event)
            }
            return event
        }

        logger.info("Keystroke monitor started (accessibility trusted: \(trusted))")
    }

    func stop() {
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalFlagsMonitor { NSEvent.removeMonitor(globalFlagsMonitor) }
        if let localFlagsMonitor { NSEvent.removeMonitor(localFlagsMonitor) }
        globalKeyMonitor = nil
        localKeyMonitor = nil
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
    }

    // MARK: - Event Handling

    private func handleKeyDown(_ event: NSEvent) {
        // Skip key repeats
        guard !event.isARepeat else { return }

        let label = Self.formatKeystroke(event: event)
        guard !label.isEmpty else { return }

        let hasModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .control, .option]) != []

        // In modifier-combos-only mode, skip plain key presses
        let snap = store.snapshot()
        if snap.keystroke.displayMode == .modifierCombosOnly && !hasModifiers {
            return
        }

        store.addKeystroke(KeystrokeEvent(label: label))
        logger.debug("Keystroke: \(label)")
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Only show modifier-only presses (not as part of combos — those come via keyDown)
        // Detect modifier key-down by checking which flag was added
        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let previous = lastModifierFlags
        lastModifierFlags = current

        // We only care about new modifier presses, not releases
        let added = current.subtracting(previous)
        guard !added.isEmpty else { return }

        // Don't show standalone modifier presses in modifier-combos-only mode
        // (those are not combos, just individual modifier taps)
    }

    // MARK: - Formatting

    /// Formats an NSEvent into a human-readable keystroke label.
    static func formatKeystroke(event: NSEvent) -> String {
        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyLabel = Self.keyLabel(for: event)
        if !keyLabel.isEmpty {
            parts.append(keyLabel)
        }

        return parts.joined()
    }

    /// Returns a human-readable label for the key (not modifiers).
    static func keyLabel(for event: NSEvent) -> String {
        let keyCode = Int(event.keyCode)

        // Special keys
        if let special = specialKeyLabels[keyCode] {
            return special
        }

        // Use charactersIgnoringModifiers for printable keys
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let upper = chars.uppercased()
            // Filter out control characters
            if upper.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) {
                return upper
            }
        }

        return ""
    }

    /// Map of key codes to special key labels
    private static let specialKeyLabels: [Int: String] = [
        kVK_Return: "↩︎",
        kVK_Tab: "⇥",
        kVK_Space: "Space",
        kVK_Delete: "⌫",
        kVK_Escape: "⎋",
        kVK_ForwardDelete: "⌦",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
        kVK_F1: "F1",
        kVK_F2: "F2",
        kVK_F3: "F3",
        kVK_F4: "F4",
        kVK_F5: "F5",
        kVK_F6: "F6",
        kVK_F7: "F7",
        kVK_F8: "F8",
        kVK_F9: "F9",
        kVK_F10: "F10",
        kVK_F11: "F11",
        kVK_F12: "F12",
    ]
}

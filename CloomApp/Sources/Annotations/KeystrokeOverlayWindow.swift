import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "KeystrokeOverlay")

/// Floating overlay panel that displays recent keystrokes on screen during recording.
/// Uses sharingType = .none so it's invisible to screen capture (keystrokes are burned in via AnnotationRenderer).
@MainActor
final class KeystrokeOverlayWindow {
    private var panel: NSPanel?
    private var refreshTimer: Timer?
    private var store: AnnotationStore?
    private var position: KeystrokePosition = .bottomLeft

    func show(store: AnnotationStore, screenFrame: CGRect) {
        self.store = store
        if panel == nil { createPanel() }
        guard let panel else { return }

        position = store.snapshot().keystroke.position

        // Initial empty content
        updateContent(events: [], currentTime: 0)

        let visibleFrame = NSScreen.main?.visibleFrame ?? screenFrame
        positionPanel(panel, screenFrame: visibleFrame)
        panel.orderFrontRegardless()

        startRefreshTimer()
        logger.info("Keystroke overlay shown")
    }

    func dismiss() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel?.orderOut(nil)
        panel = nil
        store = nil
    }

    func updatePosition(_ newPosition: KeystrokePosition, screenFrame: CGRect) {
        position = newPosition
        if let panel {
            positionPanel(panel, screenFrame: screenFrame)
        }
    }

    // MARK: - Private

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel, screenFrame: CGRect) {
        let padding: CGFloat = 40
        let panelSize = panel.frame.size

        let x: CGFloat
        let y: CGFloat

        switch position {
        case .bottomLeft:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        case .bottomRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.minY + padding
        case .topLeft:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - panelSize.height - padding
        case .topRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.maxY - panelSize.height - padding
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshEvents()
            }
        }
    }

    private func refreshEvents() {
        guard let store else { return }
        let currentTime = ProcessInfo.processInfo.systemUptime
        store.pruneExpiredKeystrokes(currentTime: currentTime)
        let snap = store.snapshot()
        updateContent(events: snap.keystroke.events, currentTime: currentTime)
    }

    /// Replace the SwiftUI rootView with fresh data each tick — matches the working pattern
    /// used by BubbleControlPill and RecordingToolbarPanel.
    private func updateContent(events: [KeystrokeEvent], currentTime: TimeInterval) {
        guard let panel else { return }
        let view = KeystrokeOverlayView(
            events: events,
            currentTime: currentTime,
            position: position
        )
        let hostingView = NSHostingView(rootView: view)
        let size = NSSize(width: 300, height: 200)
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView
        panel.setContentSize(size)
    }
}

// MARK: - SwiftUI View (pure value types — no @Observable)

struct KeystrokeOverlayView: View {
    let events: [KeystrokeEvent]
    let currentTime: TimeInterval
    let position: KeystrokePosition

    private var alignment: HorizontalAlignment {
        switch position {
        case .bottomLeft, .topLeft: return .leading
        case .bottomRight, .topRight: return .trailing
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            if isBottomPosition {
                Spacer()
            }

            ForEach(events) { event in
                KeystrokePillView(label: event.label)
                    .opacity(event.opacity(at: currentTime))
            }

            if !isBottomPosition {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private var isBottomPosition: Bool {
        position == .bottomLeft || position == .bottomRight
    }

    private var frameAlignment: Alignment {
        switch position {
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        }
    }
}

struct KeystrokePillView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(in: .rect(cornerRadius: 10))
    }
}

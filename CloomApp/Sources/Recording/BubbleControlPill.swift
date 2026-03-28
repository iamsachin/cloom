import SwiftUI
import AppKit

@MainActor
final class BubbleControlPill {
    private var panel: NSPanel?

    func show(
        bubbleWindow: NSPanel,
        startedAt: Date,
        pausedDuration: TimeInterval,
        isPaused: Bool,
        onStop: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onRewind: @escaping () -> Void = {}
    ) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: BubbleControlPillContentView(
                startedAt: startedAt,
                initialPausedDuration: pausedDuration,
                initialIsPaused: isPaused,
                onStop: onStop,
                onPause: onPause,
                onResume: onResume,
                onDiscard: onDiscard,
                onRewind: onRewind
            )
        )
        let fittingSize = hostingView.fittingSize
        let panelWidth = max(fittingSize.width, 200)
        let panelHeight = max(fittingSize.height, 36)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

        // Position below the bubble window
        let bubbleFrame = bubbleWindow.frame
        let x = bubbleFrame.midX - panelWidth / 2
        let y = bubbleFrame.minY - panelHeight - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.orderFrontRegardless()

        // Attach as child window so it follows the bubble
        bubbleWindow.addChildWindow(panel, ordered: .below)
    }

    func dismiss() {
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        panel = nil
    }

    func updatePausedState(isPaused: Bool) {
        // The SwiftUI view handles pause state via its own @State
        // This could be expanded with a binding if needed
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        self.panel = panel
    }
}

// MARK: - SwiftUI Content

private struct BubbleControlPillContentView: View {
    let startedAt: Date
    let initialPausedDuration: TimeInterval
    @State var isPaused: Bool
    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onDiscard: () -> Void
    let onRewind: () -> Void

    init(
        startedAt: Date,
        initialPausedDuration: TimeInterval,
        initialIsPaused: Bool,
        onStop: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onRewind: @escaping () -> Void = {}
    ) {
        self.startedAt = startedAt
        self.initialPausedDuration = initialPausedDuration
        self._isPaused = State(initialValue: initialIsPaused)
        self.onStop = onStop
        self.onPause = onPause
        self.onResume = onResume
        self.onDiscard = onDiscard
        self.onRewind = onRewind
    }

    var body: some View {
        HStack(spacing: 8) {
            // Stop button (red)
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(.red, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Stop recording")
            .accessibilityLabel("Stop recording")

            // Timer
            if isPaused {
                Text("Paused")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange)
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt) - initialPausedDuration
                    Text(formatElapsed(elapsed))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            // Pause/Resume
            Button {
                if isPaused {
                    isPaused = false
                    onResume()
                } else {
                    isPaused = true
                    onPause()
                }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume" : "Pause")
            .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")

            // Rewind (only when paused)
            if isPaused {
                Button(action: onRewind) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Rewind and re-record")
                .accessibilityLabel("Rewind and re-record")
            }

            // Discard
            Button(action: onDiscard) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Discard recording")
            .accessibilityLabel("Discard recording")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(in: .capsule)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

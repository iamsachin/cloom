import SwiftUI
import AppKit

@MainActor
final class RecordingToolbarPanel {
    private var panel: NSPanel?
    private var onStop: (() -> Void)?

    func show(
        startedAt: Date,
        micEnabled: Bool,
        cameraEnabled: Bool,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void
    ) {
        self.onStop = onStop
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: RecordingToolbarContentView(
                startedAt: startedAt,
                initialMicEnabled: micEnabled,
                initialCameraEnabled: cameraEnabled,
                onStop: onStop,
                onToggleMic: onToggleMic,
                onToggleCamera: onToggleCamera
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 44)
        panel.contentView = hostingView

        if let screen = NSScreen.main {
            let x = screen.frame.midX - 160
            let y = screen.frame.maxY - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        onStop = nil
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 44),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none  // Don't capture the toolbar itself
        self.panel = panel
    }
}

private struct RecordingToolbarContentView: View {
    let startedAt: Date
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    let onStop: () -> Void
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void

    init(
        startedAt: Date,
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void
    ) {
        self.startedAt = startedAt
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self.onStop = onStop
        self.onToggleMic = onToggleMic
        self.onToggleCamera = onToggleCamera
    }

    var body: some View {
        HStack(spacing: 10) {
            // Recording indicator + timer
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)

            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                Text(formatElapsed(elapsed))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Divider()
                .frame(height: 20)

            // Mic toggle
            Button {
                micEnabled.toggle()
                onToggleMic()
            } label: {
                Image(systemName: micEnabled ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(micEnabled ? .white : .red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(micEnabled ? "Mute microphone" : "Unmute microphone")

            // Camera toggle
            Button {
                cameraEnabled.toggle()
                onToggleCamera()
            } label: {
                Image(systemName: cameraEnabled ? "video.fill" : "video.slash.fill")
                    .foregroundStyle(cameraEnabled ? .white : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(cameraEnabled ? "Turn off camera" : "Turn on camera")

            Divider()
                .frame(height: 20)

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.red, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

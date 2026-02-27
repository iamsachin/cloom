import SwiftUI
import AppKit

@MainActor
final class RecordingToolbarPanel {
    private var panel: NSPanel?
    private var onStop: (() -> Void)?

    func show(
        startedAt: Date,
        pausedDuration: TimeInterval = 0,
        isPaused: Bool = false,
        micEnabled: Bool,
        cameraEnabled: Bool,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onToggleAnnotations: @escaping () -> Void = {},
        onToggleClickEmphasis: @escaping () -> Void = {},
        onToggleCursorSpotlight: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void = {}
    ) {
        self.onStop = onStop
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: RecordingToolbarContentView(
                startedAt: startedAt,
                initialPausedDuration: pausedDuration,
                initialIsPaused: isPaused,
                initialMicEnabled: micEnabled,
                initialCameraEnabled: cameraEnabled,
                onStop: onStop,
                onToggleMic: onToggleMic,
                onToggleCamera: onToggleCamera,
                onPause: onPause,
                onResume: onResume,
                onToggleAnnotations: onToggleAnnotations,
                onToggleClickEmphasis: onToggleClickEmphasis,
                onToggleCursorSpotlight: onToggleCursorSpotlight,
                onDiscard: onDiscard
            )
        )
        let fittingSize = hostingView.fittingSize
        let panelWidth = max(fittingSize.width, 400)
        let panelHeight = max(fittingSize.height, 44)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

        if let screen = NSScreen.main {
            let x = screen.frame.midX - panelWidth / 2
            let y = screen.frame.maxY - screen.frame.height * 0.10
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
    }

    func showReady(
        micEnabled: Bool,
        cameraEnabled: Bool,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onToggleAnnotations: @escaping () -> Void = {},
        onToggleClickEmphasis: @escaping () -> Void = {},
        onToggleCursorSpotlight: @escaping () -> Void = {},
        onRecord: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: ReadyToolbarContentView(
                initialMicEnabled: micEnabled,
                initialCameraEnabled: cameraEnabled,
                onToggleMic: onToggleMic,
                onToggleCamera: onToggleCamera,
                onToggleAnnotations: onToggleAnnotations,
                onToggleClickEmphasis: onToggleClickEmphasis,
                onToggleCursorSpotlight: onToggleCursorSpotlight,
                onRecord: onRecord,
                onCancel: onCancel
            )
        )
        let fittingSize = hostingView.fittingSize
        let panelWidth = max(fittingSize.width, 400)
        let panelHeight = max(fittingSize.height, 44)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

        if let screen = NSScreen.main {
            let x = screen.frame.midX - panelWidth / 2
            let y = screen.frame.maxY - screen.frame.height * 0.10
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 44),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        // Must be above annotation canvas (.screenSaver = 1000) so toolbar stays clickable during draw mode
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

private struct RecordingToolbarContentView: View {
    let startedAt: Date
    let initialPausedDuration: TimeInterval
    @State var isPaused: Bool
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    @State var annotationsEnabled: Bool = false
    @State var clickEmphasisEnabled: Bool = false
    @State var spotlightEnabled: Bool = false
    let onStop: () -> Void
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onToggleAnnotations: () -> Void
    let onToggleClickEmphasis: () -> Void
    let onToggleCursorSpotlight: () -> Void
    let onDiscard: () -> Void

    init(
        startedAt: Date,
        initialPausedDuration: TimeInterval,
        initialIsPaused: Bool,
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onToggleAnnotations: @escaping () -> Void,
        onToggleClickEmphasis: @escaping () -> Void,
        onToggleCursorSpotlight: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.startedAt = startedAt
        self.initialPausedDuration = initialPausedDuration
        self._isPaused = State(initialValue: initialIsPaused)
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self.onStop = onStop
        self.onToggleMic = onToggleMic
        self.onToggleCamera = onToggleCamera
        self.onPause = onPause
        self.onResume = onResume
        self.onToggleAnnotations = onToggleAnnotations
        self.onToggleClickEmphasis = onToggleClickEmphasis
        self.onToggleCursorSpotlight = onToggleCursorSpotlight
        self.onDiscard = onDiscard
    }

    var body: some View {
        HStack(spacing: 10) {
            // Recording indicator + timer
            Circle()
                .fill(isPaused ? .orange : .red)
                .frame(width: 10, height: 10)

            if isPaused {
                Text("Paused")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.orange)
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt) - initialPausedDuration
                    Text(formatElapsed(elapsed))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            // Pause/Resume button
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
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume recording" : "Pause recording")
            .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")

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
            .accessibilityLabel(micEnabled ? "Mute microphone" : "Unmute microphone")

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
            .accessibilityLabel(cameraEnabled ? "Turn off camera" : "Turn on camera")

            Divider()
                .frame(height: 20)

            // Draw annotations toggle
            Button {
                annotationsEnabled.toggle()
                onToggleAnnotations()
            } label: {
                Image(systemName: "pencil.tip.crop.circle")
                    .foregroundStyle(annotationsEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(annotationsEnabled ? "Stop drawing" : "Draw on screen")
            .accessibilityLabel(annotationsEnabled ? "Stop drawing" : "Draw on screen")

            // Click emphasis toggle
            Button {
                clickEmphasisEnabled.toggle()
                onToggleClickEmphasis()
            } label: {
                Image(systemName: "cursorarrow.click.2")
                    .foregroundStyle(clickEmphasisEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(clickEmphasisEnabled ? "Disable click emphasis" : "Enable click emphasis")
            .accessibilityLabel(clickEmphasisEnabled ? "Disable click emphasis" : "Enable click emphasis")

            // Cursor spotlight toggle
            Button {
                spotlightEnabled.toggle()
                onToggleCursorSpotlight()
            } label: {
                Image(systemName: "light.max")
                    .foregroundStyle(spotlightEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(spotlightEnabled ? "Disable cursor spotlight" : "Enable cursor spotlight")
            .accessibilityLabel(spotlightEnabled ? "Disable cursor spotlight" : "Enable cursor spotlight")

            Divider()
                .frame(height: 20)

            // Discard button
            Button(action: onDiscard) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Discard recording")
            .accessibilityLabel("Discard recording")

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.red, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Stop recording")
            .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityValue(isPaused ? "Recording paused" : "Recording in progress")
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Ready Mode Content View

private struct ReadyToolbarContentView: View {
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    @State var annotationsEnabled: Bool = false
    @State var clickEmphasisEnabled: Bool = false
    @State var spotlightEnabled: Bool = false
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onToggleAnnotations: () -> Void
    let onToggleClickEmphasis: () -> Void
    let onToggleCursorSpotlight: () -> Void
    let onRecord: () -> Void
    let onCancel: () -> Void

    init(
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onToggleAnnotations: @escaping () -> Void,
        onToggleClickEmphasis: @escaping () -> Void,
        onToggleCursorSpotlight: @escaping () -> Void,
        onRecord: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self.onToggleMic = onToggleMic
        self.onToggleCamera = onToggleCamera
        self.onToggleAnnotations = onToggleAnnotations
        self.onToggleClickEmphasis = onToggleClickEmphasis
        self.onToggleCursorSpotlight = onToggleCursorSpotlight
        self.onRecord = onRecord
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: 10) {
            // Ready indicator
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)

            Text("Ready")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)

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

            // Annotations toggle
            Button {
                annotationsEnabled.toggle()
                onToggleAnnotations()
            } label: {
                Image(systemName: "pencil.tip.crop.circle")
                    .foregroundStyle(annotationsEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(annotationsEnabled ? "Stop drawing" : "Draw on screen")

            // Click emphasis toggle
            Button {
                clickEmphasisEnabled.toggle()
                onToggleClickEmphasis()
            } label: {
                Image(systemName: "cursorarrow.click.2")
                    .foregroundStyle(clickEmphasisEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(clickEmphasisEnabled ? "Disable click emphasis" : "Enable click emphasis")

            // Cursor spotlight toggle
            Button {
                spotlightEnabled.toggle()
                onToggleCursorSpotlight()
            } label: {
                Image(systemName: "light.max")
                    .foregroundStyle(spotlightEnabled ? .blue : .white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(spotlightEnabled ? "Disable cursor spotlight" : "Enable cursor spotlight")

            Divider()
                .frame(height: 20)

            // Record button
            Button(action: onRecord) {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }
            .buttonStyle(.plain)
            .help("Start recording")
            .accessibilityLabel("Start recording")

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Cancel")
            .accessibilityLabel("Cancel recording setup")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityValue("Ready to record")
    }
}

import SwiftUI

struct RecordingToolbarContentView: View {
    let startedAt: Date
    let initialPausedDuration: TimeInterval
    @State var isPaused: Bool
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    @State var systemAudioEnabled: Bool
    @State var annotationsEnabled: Bool = false
    @State var clickEmphasisEnabled: Bool = false
    @State var spotlightEnabled: Bool = false
    @State var zoomEnabled: Bool = false
    @State var keystrokeEnabled: Bool = false
    let onStop: () -> Void
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onToggleAnnotations: () -> Void
    let onToggleClickEmphasis: () -> Void
    let onToggleCursorSpotlight: () -> Void
    let onToggleZoom: () -> Void
    let onToggleKeystroke: () -> Void
    let onToggleSystemAudio: () -> Void
    let onDiscard: () -> Void
    let onRewind: () -> Void

    init(
        startedAt: Date,
        initialPausedDuration: TimeInterval,
        initialIsPaused: Bool,
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        initialSystemAudioEnabled: Bool = true,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onToggleAnnotations: @escaping () -> Void,
        onToggleClickEmphasis: @escaping () -> Void,
        onToggleCursorSpotlight: @escaping () -> Void,
        onToggleZoom: @escaping () -> Void,
        onToggleKeystroke: @escaping () -> Void = {},
        onToggleSystemAudio: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void,
        onRewind: @escaping () -> Void = {}
    ) {
        self.startedAt = startedAt
        self.initialPausedDuration = initialPausedDuration
        self._isPaused = State(initialValue: initialIsPaused)
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self._systemAudioEnabled = State(initialValue: initialSystemAudioEnabled)
        self.onStop = onStop
        self.onToggleMic = onToggleMic
        self.onToggleCamera = onToggleCamera
        self.onPause = onPause
        self.onResume = onResume
        self.onToggleAnnotations = onToggleAnnotations
        self.onToggleClickEmphasis = onToggleClickEmphasis
        self.onToggleCursorSpotlight = onToggleCursorSpotlight
        self.onToggleZoom = onToggleZoom
        self.onToggleKeystroke = onToggleKeystroke
        self.onToggleSystemAudio = onToggleSystemAudio
        self.onDiscard = onDiscard
        self.onRewind = onRewind
    }

    var body: some View {
        HStack(spacing: 10) {
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

            ToolbarToggleButton(
                icon: isPaused ? "play.fill" : "pause.fill",
                isActive: false,
                activeColor: .white,
                help: isPaused ? "Resume recording" : "Pause recording"
            ) {
                isPaused.toggle()
                isPaused ? onPause() : onResume()
            }

            if isPaused {
                ToolbarToggleButton(
                    icon: "backward.fill",
                    isActive: false,
                    activeColor: .yellow,
                    help: "Rewind and re-record"
                ) {
                    onRewind()
                }
            }

            Divider().frame(height: 20)

            ToolbarToggleButton(icon: "mic.fill", offIcon: "mic.slash.fill", isActive: micEnabled, activeColor: .white, offColor: .red, help: micEnabled ? "Mute microphone" : "Unmute microphone") {
                micEnabled.toggle(); onToggleMic()
            }
            ToolbarToggleButton(icon: "speaker.wave.2.fill", offIcon: "speaker.slash.fill", isActive: systemAudioEnabled, activeColor: .white, offColor: .secondary, help: systemAudioEnabled ? "Mute system audio" : "Unmute system audio") {
                systemAudioEnabled.toggle(); onToggleSystemAudio()
            }
            ToolbarToggleButton(icon: "video.fill", offIcon: "video.slash.fill", isActive: cameraEnabled, activeColor: .white, offColor: .secondary, help: cameraEnabled ? "Turn off camera" : "Turn on camera") {
                cameraEnabled.toggle(); onToggleCamera()
            }

            Divider().frame(height: 20)

            ToolbarToggleButton(icon: "pencil.tip.crop.circle", isActive: annotationsEnabled, activeColor: .blue, help: annotationsEnabled ? "Stop drawing" : "Draw on screen") {
                annotationsEnabled.toggle(); onToggleAnnotations()
            }
            ToolbarToggleButton(icon: "cursorarrow.click.2", isActive: clickEmphasisEnabled, activeColor: .blue, help: clickEmphasisEnabled ? "Disable click emphasis" : "Enable click emphasis") {
                clickEmphasisEnabled.toggle(); onToggleClickEmphasis()
            }
            ToolbarToggleButton(icon: "light.max", isActive: spotlightEnabled, activeColor: .blue, help: spotlightEnabled ? "Disable cursor spotlight" : "Enable cursor spotlight") {
                spotlightEnabled.toggle(); onToggleCursorSpotlight()
            }
            ToolbarToggleButton(icon: "plus.magnifyingglass", isActive: zoomEnabled, activeColor: .blue, help: zoomEnabled ? "Disable zoom" : "Enable zoom") {
                zoomEnabled.toggle(); onToggleZoom()
            }
            ToolbarToggleButton(icon: "keyboard", isActive: keystrokeEnabled, activeColor: .blue, help: keystrokeEnabled ? "Hide keystrokes" : "Show keystrokes") {
                keystrokeEnabled.toggle(); onToggleKeystroke()
            }

            Divider().frame(height: 20)

            Button(action: onDiscard) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Discard recording")
            .accessibilityLabel("Discard recording")

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.glass(.regular.tint(.red)))
            .help("Stop recording")
            .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(in: .capsule)
        .accessibilityValue(isPaused ? "Recording paused" : "Recording in progress")
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

import SwiftUI

struct ReadyToolbarContentView: View {
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    @State var systemAudioEnabled: Bool
    @State var annotationsEnabled: Bool
    @State var clickEmphasisEnabled: Bool
    @State var spotlightEnabled: Bool
    @State var keystrokeEnabled: Bool
    @State var teleprompterEnabled: Bool
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onToggleSystemAudio: () -> Void
    let onToggleAnnotations: () -> Void
    let onToggleClickEmphasis: () -> Void
    let onToggleCursorSpotlight: () -> Void
    let onToggleKeystroke: () -> Void
    let onToggleTeleprompter: () -> Void
    let onRecord: () -> Void
    let onCancel: () -> Void

    init(
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        initialSystemAudioEnabled: Bool = true,
        initialAnnotationsEnabled: Bool = false,
        initialClickEmphasisEnabled: Bool = false,
        initialSpotlightEnabled: Bool = false,
        initialKeystrokeEnabled: Bool = false,
        initialTeleprompterEnabled: Bool = false,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onToggleSystemAudio: @escaping () -> Void = {},
        onToggleAnnotations: @escaping () -> Void,
        onToggleClickEmphasis: @escaping () -> Void,
        onToggleCursorSpotlight: @escaping () -> Void,
        onToggleKeystroke: @escaping () -> Void = {},
        onToggleTeleprompter: @escaping () -> Void = {},
        onRecord: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self._systemAudioEnabled = State(initialValue: initialSystemAudioEnabled)
        self._annotationsEnabled = State(initialValue: initialAnnotationsEnabled)
        self._clickEmphasisEnabled = State(initialValue: initialClickEmphasisEnabled)
        self._spotlightEnabled = State(initialValue: initialSpotlightEnabled)
        self._keystrokeEnabled = State(initialValue: initialKeystrokeEnabled)
        self._teleprompterEnabled = State(initialValue: initialTeleprompterEnabled)
        self.onToggleMic = onToggleMic
        self.onToggleCamera = onToggleCamera
        self.onToggleSystemAudio = onToggleSystemAudio
        self.onToggleAnnotations = onToggleAnnotations
        self.onToggleClickEmphasis = onToggleClickEmphasis
        self.onToggleCursorSpotlight = onToggleCursorSpotlight
        self.onToggleKeystroke = onToggleKeystroke
        self.onToggleTeleprompter = onToggleTeleprompter
        self.onRecord = onRecord
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
            Text("Ready")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)

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
            ToolbarToggleButton(icon: "keyboard", isActive: keystrokeEnabled, activeColor: .blue, help: keystrokeEnabled ? "Hide keystrokes" : "Show keystrokes") {
                keystrokeEnabled.toggle(); onToggleKeystroke()
            }
            ToolbarToggleButton(icon: "doc.text", isActive: teleprompterEnabled, activeColor: .blue, help: teleprompterEnabled ? "Hide teleprompter" : "Show teleprompter") {
                teleprompterEnabled.toggle(); onToggleTeleprompter()
            }

            Divider().frame(height: 20)

            Button(action: onRecord) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.glass(.regular.tint(.red)))
            .help("Start recording")
            .accessibilityLabel("Start recording")

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
        .glassEffect(in: .capsule)
        .accessibilityValue("Ready to record")
    }
}

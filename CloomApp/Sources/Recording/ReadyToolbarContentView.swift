import SwiftUI

struct ReadyToolbarContentView: View {
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

            Divider().frame(height: 20)

            Button(action: onRecord) {
                ZStack {
                    Circle().fill(.red).frame(width: 24, height: 24)
                    Circle().fill(.white).frame(width: 8, height: 8)
                }
            }
            .buttonStyle(.plain)
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
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityValue("Ready to record")
    }
}

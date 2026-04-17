import SwiftUI

struct RecordingToolbarContentView: View {
    let startedAt: Date
    let initialPausedDuration: TimeInterval
    @State var isPaused: Bool
    @State var micEnabled: Bool
    @State var cameraEnabled: Bool
    @State var systemAudioEnabled: Bool
    @State var annotationsEnabled: Bool
    @State var clickEmphasisEnabled: Bool
    @State var spotlightEnabled: Bool
    @State var zoomEnabled: Bool
    @State var keystrokeEnabled: Bool
    @State var teleprompterEnabled: Bool
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
    let onToggleTeleprompter: () -> Void
    let onToggleSystemAudio: () -> Void
    let onDiscard: () -> Void
    let onRewind: () -> Void

    // Annotation tool callbacks (inline row)
    let onAnnotationToolChanged: ((AnnotationTool) -> Void)?
    let onAnnotationColorChanged: ((StrokeColor) -> Void)?
    let onAnnotationUndo: (() -> Void)?
    let onAnnotationClearAll: (() -> Void)?
    let initialAnnotationTool: AnnotationTool
    let initialAnnotationColor: StrokeColor

    @State private var selectedTool: AnnotationTool
    @State private var selectedColor: StrokeColor
    @State private var showColorPicker = false
    @State private var customColor: Color = .white

    init(
        startedAt: Date,
        initialPausedDuration: TimeInterval,
        initialIsPaused: Bool,
        initialMicEnabled: Bool,
        initialCameraEnabled: Bool,
        initialSystemAudioEnabled: Bool = true,
        initialAnnotationsEnabled: Bool = false,
        initialClickEmphasisEnabled: Bool = false,
        initialSpotlightEnabled: Bool = false,
        initialZoomEnabled: Bool = false,
        initialKeystrokeEnabled: Bool = false,
        initialTeleprompterEnabled: Bool = false,
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
        onToggleTeleprompter: @escaping () -> Void = {},
        onToggleSystemAudio: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void,
        onRewind: @escaping () -> Void = {},
        onAnnotationToolChanged: ((AnnotationTool) -> Void)? = nil,
        onAnnotationColorChanged: ((StrokeColor) -> Void)? = nil,
        onAnnotationUndo: (() -> Void)? = nil,
        onAnnotationClearAll: (() -> Void)? = nil,
        initialAnnotationTool: AnnotationTool = .pen,
        initialAnnotationColor: StrokeColor = .red
    ) {
        self.startedAt = startedAt
        self.initialPausedDuration = initialPausedDuration
        self._isPaused = State(initialValue: initialIsPaused)
        self._micEnabled = State(initialValue: initialMicEnabled)
        self._cameraEnabled = State(initialValue: initialCameraEnabled)
        self._systemAudioEnabled = State(initialValue: initialSystemAudioEnabled)
        self._annotationsEnabled = State(initialValue: initialAnnotationsEnabled)
        self._clickEmphasisEnabled = State(initialValue: initialClickEmphasisEnabled)
        self._spotlightEnabled = State(initialValue: initialSpotlightEnabled)
        self._zoomEnabled = State(initialValue: initialZoomEnabled)
        self._keystrokeEnabled = State(initialValue: initialKeystrokeEnabled)
        self._teleprompterEnabled = State(initialValue: initialTeleprompterEnabled)
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
        self.onToggleTeleprompter = onToggleTeleprompter
        self.onToggleSystemAudio = onToggleSystemAudio
        self.onDiscard = onDiscard
        self.onRewind = onRewind
        self.onAnnotationToolChanged = onAnnotationToolChanged
        self.onAnnotationColorChanged = onAnnotationColorChanged
        self.onAnnotationUndo = onAnnotationUndo
        self.onAnnotationClearAll = onAnnotationClearAll
        self.initialAnnotationTool = initialAnnotationTool
        self.initialAnnotationColor = initialAnnotationColor
        self._selectedTool = State(initialValue: initialAnnotationTool)
        self._selectedColor = State(initialValue: initialAnnotationColor)
    }

    private var isCustomColor: Bool {
        !StrokeColor.palette.contains(selectedColor)
    }

    var body: some View {
        VStack(spacing: 4) {
            mainRow
            if annotationsEnabled {
                annotationRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: annotationsEnabled)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .cloomGlassCapsule()
        .accessibilityValue(isPaused ? "Recording paused" : "Recording in progress")
    }

    private var mainRow: some View {
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
            ToolbarToggleButton(icon: "doc.text", isActive: teleprompterEnabled, activeColor: .blue, help: teleprompterEnabled ? "Hide teleprompter" : "Show teleprompter") {
                teleprompterEnabled.toggle(); onToggleTeleprompter()
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
    }

    private var annotationRow: some View {
        HStack(spacing: 6) {
            annotationToolButton(.pen, icon: "pencil", label: "Pen")
            annotationToolButton(.highlighter, icon: "highlighter", label: "Highlighter")
            annotationToolButton(.text, icon: "textformat", label: "Text")
            annotationToolButton(.arrow, icon: "arrow.up.right", label: "Arrow")
            annotationToolButton(.line, icon: "line.diagonal", label: "Line")
            annotationToolButton(.rectangle, icon: "rectangle", label: "Rectangle")
            annotationToolButton(.ellipse, icon: "circle", label: "Ellipse")
            annotationToolButton(.eraser, icon: "eraser", label: "Eraser")

            Divider().frame(height: 20)

            ForEach(Array(StrokeColor.palette.enumerated()), id: \.offset) { _, color in
                annotationColorSwatch(color)
            }

            Button {
                showColorPicker.toggle()
            } label: {
                ZStack {
                    if isCustomColor {
                        Circle()
                            .fill(Color(cgColor: selectedColor.cgColor))
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    } else {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Custom color")
            .accessibilityLabel("Custom color picker")
            .popover(isPresented: $showColorPicker) {
                annotationColorPickerPopover
            }

            Divider().frame(height: 20)

            Button { onAnnotationUndo?() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Undo")
            .accessibilityLabel("Undo annotation")

            Button { onAnnotationClearAll?() } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Clear all")
            .accessibilityLabel("Clear all annotations")
        }
    }

    private var annotationColorPickerPopover: some View {
        VStack(spacing: 12) {
            ColorPicker("Color", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: customColor) {
                    let nsColor = NSColor(customColor)
                    let strokeColor = StrokeColor(nsColor: nsColor)
                    selectedColor = strokeColor
                    onAnnotationColorChanged?(strokeColor)
                }

            HStack {
                Text("#")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
                TextField("Hex", text: .init(
                    get: { selectedColor.hexString.dropFirst().description },
                    set: { newValue in
                        if let color = StrokeColor(hex: newValue) {
                            selectedColor = color
                            customColor = Color(cgColor: color.cgColor)
                            onAnnotationColorChanged?(color)
                        }
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .frame(width: 200)
    }

    private func annotationToolButton(_ tool: AnnotationTool, icon: String, label: String) -> some View {
        Button {
            selectedTool = tool
            onAnnotationToolChanged?(tool)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(selectedTool == tool ? .blue : .white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel("\(label) tool")
    }

    private func annotationColorSwatch(_ color: StrokeColor) -> some View {
        Button {
            selectedColor = color
            onAnnotationColorChanged?(color)
        } label: {
            Circle()
                .fill(Color(cgColor: color.cgColor))
                .frame(width: 14, height: 14)
                .overlay {
                    if selectedColor == color {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(color.displayName) color")
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

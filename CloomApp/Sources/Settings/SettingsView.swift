import SwiftUI
import AVFoundation
import CoreImage
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }

            RecordingSettingsTab()
                .tabItem { Label("Recording", systemImage: "record.circle") }

            WebcamSettingsTab()
                .tabItem { Label("Webcam", systemImage: "camera.fill") }

            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            AISettingsTab()
                .tabItem { Label("AI", systemImage: "sparkle") }
        }
        .frame(width: 600, height: 480)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

            Toggle("Show Notifications", isOn: $notificationsEnabled)

            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceMode) { _, newValue in
                switch newValue {
                case "light": NSApp.appearance = NSAppearance(named: .aqua)
                case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
                default: NSApp.appearance = nil
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Recording Tab

private struct RecordingSettingsTab: View {
    @AppStorage("recordingFPS") private var fps: Int = 30
    @AppStorage("recordingQuality") private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage("recordingMicDeviceID") private var micDeviceID: String = ""
    @AppStorage("recordingCameraDeviceID") private var cameraDeviceID: String = ""
    @AppStorage("noiseCancellationEnabled") private var noiseCancellationEnabled: Bool = false

    @State private var microphones: [AVCaptureDevice] = []
    @State private var cameras: [AVCaptureDevice] = []

    private var quality: Binding<VideoQuality> {
        Binding(
            get: { VideoQuality(rawValue: qualityRaw) ?? .medium },
            set: { qualityRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Video") {
                Picker("Frame Rate", selection: $fps) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                }
                .pickerStyle(.segmented)

                Picker("Quality", selection: quality) {
                    ForEach(VideoQuality.allCases) { q in
                        Text(q.label).tag(q)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Microphone") {
                Picker("Device", selection: $micDeviceID) {
                    Text("System Default").tag("")
                    ForEach(microphones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                Toggle("Noise Reduction", isOn: $noiseCancellationEnabled)
                    .help("Reduces background noise from microphone input using a noise gate")
            }

            Section("Camera") {
                Picker("Device", selection: $cameraDeviceID) {
                    Text("System Default").tag("")
                    ForEach(cameras, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshDevices() }
    }

    private func refreshDevices() {
        let micDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        microphones = micDiscovery.devices
        cameras = CameraService.availableCameras()
    }
}

// MARK: - Webcam Tab

private struct WebcamSettingsTab: View {
    @AppStorage("webcamBrightness") private var webcamBrightness: Double = 0
    @AppStorage("webcamContrast") private var webcamContrast: Double = 1
    @AppStorage("webcamSaturation") private var webcamSaturation: Double = 1
    @AppStorage("webcamHighlights") private var webcamHighlights: Double = 1
    @AppStorage("webcamShadows") private var webcamShadows: Double = 0
    @AppStorage("webcamTemperature") private var webcamTemperature: Double = 6500
    @AppStorage("webcamTint") private var webcamTint: Double = 0
    @AppStorage("webcamShape") private var webcamShapeRaw: String = "circle"
    @AppStorage("webcamBubbleTheme") private var webcamThemeRaw: String = "none"

    @State private var previewImage: NSImage?
    @State private var cameraService: CameraService?
    @State private var imageAdjuster = WebcamImageAdjuster()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var currentShape: WebcamShape {
        WebcamShape(rawValue: webcamShapeRaw) ?? .circle
    }

    private var currentTheme: BubbleTheme {
        BubbleTheme(rawValue: webcamThemeRaw) ?? .none
    }

    /// Preview dimensions: fits inside the left panel while respecting shape aspect ratio.
    private var previewSize: CGSize {
        let maxDim: CGFloat = 180
        let ar = currentShape.aspectRatio
        if ar <= 1 {
            return CGSize(width: maxDim * ar, height: maxDim)
        } else {
            return CGSize(width: maxDim, height: maxDim / ar)
        }
    }

    private var webcamShape: Binding<WebcamShape> {
        Binding(
            get: { WebcamShape(rawValue: webcamShapeRaw) ?? .circle },
            set: { webcamShapeRaw = $0.rawValue }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: live preview + shape/theme
            VStack(spacing: 16) {
                // Live camera preview with theme ring
                ZStack {
                    // Theme border ring (behind preview)
                    if currentTheme != .none {
                        themeRingView
                    }

                    // Camera preview
                    if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                    } else {
                        RoundedRectangle(cornerRadius: previewCornerRadius)
                            .fill(.quaternary)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("Camera Preview")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: webcamShapeRaw)
                .animation(.easeInOut(duration: 0.2), value: webcamThemeRaw)

                // Shape picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Shape", selection: webcamShape) {
                        ForEach(WebcamShape.allCases, id: \.rawValue) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Theme swatches
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bubble Theme")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 5), spacing: 4) {
                        ForEach(BubbleTheme.allCases, id: \.rawValue) { theme in
                            Button {
                                webcamThemeRaw = theme.rawValue
                            } label: {
                                if theme == .none {
                                    Circle()
                                        .strokeBorder(Color.secondary, lineWidth: 1)
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if webcamThemeRaw == theme.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                            }
                                        }
                                } else {
                                    Circle()
                                        .fill(Color(nsColor: theme.swatchColor()))
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if webcamThemeRaw == theme.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                            .help(theme.displayName)
                        }
                    }
                }

                Spacer()
            }
            .frame(width: 200)
            .padding()

            Divider()

            // Right: sliders in two columns
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Image Adjustments")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 24) {
                        // Column 1: Color
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LabeledSlider(label: "Brightness", value: $webcamBrightness, range: -1...1, defaultValue: 0)
                            LabeledSlider(label: "Contrast", value: $webcamContrast, range: 0...4, defaultValue: 1)
                            LabeledSlider(label: "Saturation", value: $webcamSaturation, range: 0...2, defaultValue: 1)
                        }

                        // Column 2: Light & Tone
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Light & Tone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LabeledSlider(label: "Highlights", value: $webcamHighlights, range: 0...1, defaultValue: 1)
                            LabeledSlider(label: "Shadows", value: $webcamShadows, range: -1...1, defaultValue: 0)
                            LabeledSlider(label: "Temp", value: $webcamTemperature, range: 2000...10000, defaultValue: 6500)
                            LabeledSlider(label: "Tint", value: $webcamTint, range: -150...150, defaultValue: 0)
                        }
                    }

                    Button("Reset to Defaults") {
                        resetWebcamAdjustments()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .onAppear { startPreview() }
        .onDisappear { stopPreview() }
        .onChange(of: webcamBrightness) { _, _ in updateAdjuster() }
        .onChange(of: webcamContrast) { _, _ in updateAdjuster() }
        .onChange(of: webcamSaturation) { _, _ in updateAdjuster() }
        .onChange(of: webcamHighlights) { _, _ in updateAdjuster() }
        .onChange(of: webcamShadows) { _, _ in updateAdjuster() }
        .onChange(of: webcamTemperature) { _, _ in updateAdjuster() }
        .onChange(of: webcamTint) { _, _ in updateAdjuster() }
    }

    private var previewCornerRadius: CGFloat {
        currentShape.cornerRadius(forHeight: previewSize.height)
    }

    // MARK: - Theme Ring

    @ViewBuilder
    private var themeRingView: some View {
        let borderWidth: CGFloat = 5
        let ringWidth = previewSize.width + borderWidth * 2
        let ringHeight = previewSize.height + borderWidth * 2
        let ringRadius = previewCornerRadius + borderWidth

        if let (c1, c2) = currentTheme.gradientCGColors() {
            RoundedRectangle(cornerRadius: ringRadius)
                .fill(LinearGradient(
                    colors: [Color(cgColor: c1), Color(cgColor: c2)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ))
                .frame(width: ringWidth, height: ringHeight)
        } else if let c = currentTheme.cgColor() {
            RoundedRectangle(cornerRadius: ringRadius)
                .fill(Color(cgColor: c))
                .frame(width: ringWidth, height: ringHeight)
        }
    }

    private func startPreview() {
        let cam = CameraService()
        cam.onFrame = { [ciContext] _, ciImage in
            let adjusted = imageAdjuster.apply(to: ciImage)
            // Flip horizontally
            let flipped = adjusted.transformed(by: CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -adjusted.extent.width, y: 0))
            guard let cgImage = ciContext.createCGImage(flipped, from: flipped.extent) else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            Task { @MainActor in
                previewImage = nsImage
            }
        }
        cam.start()
        cameraService = cam
        updateAdjuster()
    }

    private func stopPreview() {
        cameraService?.stop()
        cameraService = nil
    }

    private func updateAdjuster() {
        imageAdjuster.updateAdjustments(WebcamAdjustments(
            brightness: Float(webcamBrightness),
            contrast: Float(webcamContrast),
            saturation: Float(webcamSaturation),
            highlights: Float(webcamHighlights),
            shadows: Float(webcamShadows),
            temperature: Float(webcamTemperature),
            tint: Float(webcamTint)
        ))
    }

    private func resetWebcamAdjustments() {
        webcamBrightness = 0
        webcamContrast = 1
        webcamSaturation = 1
        webcamHighlights = 1
        webcamShadows = 0
        webcamTemperature = 6500
        webcamTint = 0
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            ForEach(HotkeyAction.allCases, id: \.rawValue) { action in
                HStack {
                    Text(action.label)
                    Spacer()
                    ShortcutRecorderButton(action: action)
                }
            }

            Button("Reset to Defaults") {
                GlobalHotkeyManager.shared.resetToDefaults()
            }
            .font(.caption)
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI Tab

private struct AISettingsTab: View {
    @AppStorage("aiAutoTranscribe") private var aiAutoTranscribe: Bool = true
    @State private var apiKeyInput: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var apiKeyPrefix: String = ""

    var body: some View {
        Form {
            if hasAPIKey {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OpenAI API Key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(apiKeyPrefix)...")
                                .monospaced()
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button("Remove", role: .destructive) {
                        KeychainService.deleteAPIKey()
                        apiKeyInput = ""
                        apiKeyPrefix = ""
                        hasAPIKey = false
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                HStack {
                    SecureField("OpenAI API Key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveAPIKey() }

                    Button("Save") { saveAPIKey() }
                        .disabled(apiKeyInput.isEmpty)
                }
            }

            Toggle("Auto-transcribe after recording", isOn: $aiAutoTranscribe)
        }
        .formStyle(.grouped)
        .onAppear {
            if let key = KeychainService.loadAPIKey() {
                hasAPIKey = true
                apiKeyPrefix = String(key.prefix(15))
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKeyInput.isEmpty else { return }
        apiKeyPrefix = String(apiKeyInput.prefix(15))
        KeychainService.saveAPIKey(apiKeyInput)
        hasAPIKey = true
        apiKeyInput = ""
    }
}

// MARK: - Hotkey Action Labels

extension HotkeyAction {
    var label: String {
        switch self {
        case .toggleRecording: "Start / Stop Recording"
        case .togglePause: "Pause / Resume"
        }
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    let action: HotkeyAction
    @State private var isRecording = false
    @State private var monitor: Any?

    private var binding: HotkeyBinding? {
        GlobalHotkeyManager.shared.bindings[action]
    }

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            if isRecording {
                Text("Press shortcut...")
                    .foregroundStyle(.orange)
                    .frame(minWidth: 120)
            } else {
                Text(binding?.displayString ?? "None")
                    .frame(minWidth: 120)
            }
        }
        .buttonStyle(.bordered)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        GlobalHotkeyManager.shared.stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                .intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

            if keyCode == 53 {
                stopRecording()
                return nil
            }

            guard flags.rawValue != 0 else { return nil }

            let newBinding = HotkeyBinding(keyCode: keyCode, modifiers: flags.rawValue)
            GlobalHotkeyManager.shared.updateBinding(action: action, binding: newBinding)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        GlobalHotkeyManager.shared.start()
    }
}

// MARK: - Labeled Slider

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    private var isDefault: Bool {
        abs(value - defaultValue) < 0.01
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(isDefault ? .secondary : .accentColor)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            value = defaultValue
                        }
                    }
                    .help("Click to reset")
            }
            Slider(value: $value, in: range)
        }
    }
}

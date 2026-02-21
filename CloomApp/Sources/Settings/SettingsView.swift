import SwiftUI
import AVFoundation
import ServiceManagement

struct SettingsView: View {
    @AppStorage("recordingFPS") private var fps: Int = 30
    @AppStorage("recordingQuality") private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage("recordingMicDeviceID") private var micDeviceID: String = ""
    @AppStorage("recordingCameraDeviceID") private var cameraDeviceID: String = ""
    @AppStorage("aiAutoTranscribe") private var aiAutoTranscribe: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("noiseCancellationEnabled") private var noiseCancellationEnabled: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    @State private var microphones: [AVCaptureDevice] = []
    @State private var cameras: [AVCaptureDevice] = []
    @State private var apiKeyInput: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var apiKeyPrefix: String = ""

    private var quality: Binding<VideoQuality> {
        Binding(
            get: { VideoQuality(rawValue: qualityRaw) ?? .medium },
            set: { qualityRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Revert on failure
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
                    applyAppearance(newValue)
                }
            }

            Section("Recording") {
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

            Section("Shortcuts") {
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

            Section("AI") {
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
                            .onSubmit {
                                saveAPIKey()
                            }

                        Button("Save") {
                            saveAPIKey()
                        }
                        .disabled(apiKeyInput.isEmpty)
                    }
                }

                Toggle("Auto-transcribe after recording", isOn: $aiAutoTranscribe)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 650)
        .onAppear {
            refreshDevices()
            if let key = KeychainService.loadAPIKey() {
                hasAPIKey = true
                apiKeyPrefix = String(key.prefix(15))
            }
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func applyAppearance(_ mode: String) {
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // system default
        }
    }

    private func saveAPIKey() {
        guard !apiKeyInput.isEmpty else { return }
        apiKeyPrefix = String(apiKeyInput.prefix(15))
        KeychainService.saveAPIKey(apiKeyInput)
        hasAPIKey = true
        apiKeyInput = ""
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
        // Temporarily stop the global event tap so it doesn't intercept
        GlobalHotkeyManager.shared.stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                .intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

            // Escape cancels
            if keyCode == 53 { // kVK_Escape
                stopRecording()
                return nil
            }

            // Require at least one modifier
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

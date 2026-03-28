import SwiftUI
import AVFoundation
import AppKit

struct RecordingSettingsTab: View {
    @AppStorage(UserDefaultsKeys.recordingFPS) private var fps: Int = 30
    @AppStorage(UserDefaultsKeys.recordingQuality) private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage(UserDefaultsKeys.recordingMicDeviceID) private var micDeviceID: String = ""
    @AppStorage(UserDefaultsKeys.recordingCameraDeviceID) private var cameraDeviceID: String = ""
    @AppStorage(UserDefaultsKeys.micSensitivity) private var micSensitivity: Int = 100
    @AppStorage(UserDefaultsKeys.systemAudioEnabled) private var systemAudioEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.countdownDuration) private var countdownDuration: Int = 3
    @AppStorage(UserDefaultsKeys.defaultSaveLocation) private var defaultSaveLocation: String = ""
    @AppStorage(UserDefaultsKeys.silenceThresholdDb) private var silenceThresholdDb: Double = -40.0
    @AppStorage(UserDefaultsKeys.silenceMinDurationMs) private var silenceMinDurationMs: Int = 500
    @AppStorage(UserDefaultsKeys.keystrokePosition) private var keystrokePositionRaw: String = KeystrokePosition.bottomLeft.rawValue
    @AppStorage(UserDefaultsKeys.keystrokeDisplayMode) private var keystrokeDisplayModeRaw: String = KeystrokeDisplayMode.allKeys.rawValue

    // Teleprompter
    @AppStorage(UserDefaultsKeys.teleprompterFontSize) private var teleprompterFontSize: Double = 40
    @AppStorage(UserDefaultsKeys.teleprompterScrollSpeed) private var teleprompterScrollSpeed: Double = 60
    @AppStorage(UserDefaultsKeys.teleprompterOpacity) private var teleprompterOpacity: Double = 0.85
    @AppStorage(UserDefaultsKeys.teleprompterPosition) private var teleprompterPositionRaw: String = TeleprompterPosition.bottom.rawValue
    @AppStorage(UserDefaultsKeys.teleprompterMirrorEnabled) private var teleprompterMirrorEnabled: Bool = false

    @State private var microphones: [AVCaptureDevice] = []
    @State private var cameras: [AVCaptureDevice] = []
    @StateObject private var micMonitor = MicLevelMonitor()

    private var keystrokePosition: Binding<KeystrokePosition> {
        Binding(
            get: { KeystrokePosition(rawValue: keystrokePositionRaw) ?? .bottomLeft },
            set: { keystrokePositionRaw = $0.rawValue }
        )
    }

    private var keystrokeDisplayMode: Binding<KeystrokeDisplayMode> {
        Binding(
            get: { KeystrokeDisplayMode(rawValue: keystrokeDisplayModeRaw) ?? .allKeys },
            set: { keystrokeDisplayModeRaw = $0.rawValue }
        )
    }

    private var teleprompterPosition: Binding<TeleprompterPosition> {
        Binding(
            get: { TeleprompterPosition(rawValue: teleprompterPositionRaw) ?? .bottom },
            set: { teleprompterPositionRaw = $0.rawValue }
        )
    }

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

            Section("Audio") {
                Toggle("Capture System Audio", isOn: $systemAudioEnabled)
                    .help("Include system audio (app sounds, music) in recordings")
            }

            Section("Microphone") {
                Picker("Device", selection: $micDeviceID) {
                    Text("System Default").tag("")
                    ForEach(microphones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                HStack {
                    Text("Sensitivity")
                    Slider(value: Binding(
                        get: { Double(micSensitivity) },
                        set: { micSensitivity = Int($0) }
                    ), in: 0...200, step: 1)
                    Text("\(micSensitivity)%")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                        .foregroundStyle(micSensitivity != 100 ? Color.accentColor : .secondary)
                        .onTapGesture { micSensitivity = 100 }
                }
                .help("Microphone input gain — 100% is full volume, lower values attenuate")
                .onChange(of: micSensitivity) {
                    micMonitor.updateSensitivity(micSensitivity)
                }

                MicLevelMeterView(level: micMonitor.level)
            }

            Section("Camera") {
                Picker("Device", selection: $cameraDeviceID) {
                    Text("System Default").tag("")
                    ForEach(cameras, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
            }

            Section("Countdown") {
                Picker("Duration", selection: $countdownDuration) {
                    Text("No Countdown").tag(0)
                    Text("1 second").tag(1)
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
            }

            Section("Save Location") {
                HStack {
                    Text(defaultSaveLocation.isEmpty ? "Desktop (default)" : abbreviatePath(defaultSaveLocation))
                        .foregroundStyle(defaultSaveLocation.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.prompt = "Select"
                        if panel.runModal() == .OK, let url = panel.url {
                            defaultSaveLocation = url.path
                        }
                    }
                    if !defaultSaveLocation.isEmpty {
                        Button("Reset") { defaultSaveLocation = "" }
                            .controlSize(.small)
                    }
                }
                .help("Where recordings are saved — defaults to Desktop")
            }

            Section("Keystroke Visualization") {
                Picker("Position", selection: keystrokePosition) {
                    ForEach(KeystrokePosition.allCases, id: \.rawValue) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .help("Where the keystroke overlay appears on screen")

                Picker("Display", selection: keystrokeDisplayMode) {
                    ForEach(KeystrokeDisplayMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .help("Show all keys or only modifier combos (⌘S, ⌃C, etc.)")
            }

            Section("Teleprompter") {
                HStack {
                    Text("Font Size")
                    Slider(value: $teleprompterFontSize, in: 20...72, step: 2)
                    Text("\(Int(teleprompterFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                        .foregroundStyle(teleprompterFontSize != 40 ? Color.accentColor : .secondary)
                        .onTapGesture { teleprompterFontSize = 40 }
                }
                .help("Text size in the teleprompter overlay")

                HStack {
                    Text("Scroll Speed")
                    Slider(value: $teleprompterScrollSpeed, in: 10...200, step: 5)
                    Text("\(Int(teleprompterScrollSpeed)) pt/s")
                        .monospacedDigit()
                        .frame(width: 55, alignment: .trailing)
                        .foregroundStyle(teleprompterScrollSpeed != 60 ? Color.accentColor : .secondary)
                        .onTapGesture { teleprompterScrollSpeed = 60 }
                }
                .help("How fast the script scrolls (points per second)")

                HStack {
                    Text("Background Opacity")
                    Slider(value: $teleprompterOpacity, in: 0.3...1.0, step: 0.05)
                    Text("\(Int(teleprompterOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                        .foregroundStyle(teleprompterOpacity != 0.85 ? Color.accentColor : .secondary)
                        .onTapGesture { teleprompterOpacity = 0.85 }
                }
                .help("Opacity of the teleprompter background")

                Picker("Position", selection: teleprompterPosition) {
                    ForEach(TeleprompterPosition.allCases) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .help("Where the teleprompter appears on screen")

                Toggle("Mirror Mode", isOn: $teleprompterMirrorEnabled)
                    .help("Flip text horizontally for use with a physical beamsplitter teleprompter")
            }

            Section("Silence Detection") {
                HStack {
                    Text("Threshold")
                    Slider(value: $silenceThresholdDb, in: -60...(-20), step: 1)
                    Text("\(Int(silenceThresholdDb)) dB")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(silenceThresholdDb != -40 ? Color.accentColor : .secondary)
                        .onTapGesture { silenceThresholdDb = -40 }
                }
                .help("Audio level below which is considered silence (-40 dB default)")

                HStack {
                    Text("Min Duration")
                    Slider(value: Binding(
                        get: { Double(silenceMinDurationMs) },
                        set: { silenceMinDurationMs = Int($0) }
                    ), in: 100...2000, step: 100)
                    Text("\(silenceMinDurationMs) ms")
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(silenceMinDurationMs != 500 ? Color.accentColor : .secondary)
                        .onTapGesture { silenceMinDurationMs = 500 }
                }
                .help("Minimum silence duration to detect (500 ms default)")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshDevices()
            micMonitor.start(deviceID: micDeviceID.isEmpty ? nil : micDeviceID, sensitivity: micSensitivity)
        }
        .onDisappear {
            micMonitor.stop()
        }
        .onChange(of: micDeviceID) {
            micMonitor.start(deviceID: micDeviceID.isEmpty ? nil : micDeviceID, sensitivity: micSensitivity)
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        if let home = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
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

// MARK: - Level Meter

private struct MicLevelMeterView: View {
    let level: Float

    var body: some View {
        HStack(spacing: 6) {
            Text("Level")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(level)))
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            .frame(height: 8)
        }
    }

    private var barColor: Color {
        if level > 0.9 { return .red }
        if level > 0.6 { return .yellow }
        return .green
    }
}

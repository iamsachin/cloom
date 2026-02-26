import SwiftUI
import AVFoundation

struct RecordingSettingsTab: View {
    @AppStorage("recordingFPS") private var fps: Int = 30
    @AppStorage("recordingQuality") private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage("recordingMicDeviceID") private var micDeviceID: String = ""
    @AppStorage("recordingCameraDeviceID") private var cameraDeviceID: String = ""
    @AppStorage("micSensitivity") private var micSensitivity: Int = 100

    @State private var microphones: [AVCaptureDevice] = []
    @State private var cameras: [AVCaptureDevice] = []
    @StateObject private var micMonitor = MicLevelMonitor()

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

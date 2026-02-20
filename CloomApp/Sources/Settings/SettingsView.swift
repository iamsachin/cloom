import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("recordingFPS") private var fps: Int = 30
    @AppStorage("recordingQuality") private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage("recordingMicDeviceID") private var micDeviceID: String = ""
    @AppStorage("recordingCameraDeviceID") private var cameraDeviceID: String = ""
    @AppStorage("aiAutoTranscribe") private var aiAutoTranscribe: Bool = true

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
            }

            Section("Camera") {
                Picker("Device", selection: $cameraDeviceID) {
                    Text("System Default").tag("")
                    ForEach(cameras, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
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
        .frame(width: 400, height: 550)
        .onAppear {
            refreshDevices()
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

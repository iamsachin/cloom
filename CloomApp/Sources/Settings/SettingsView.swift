import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("recordingFPS") private var fps: Int = 30
    @AppStorage("recordingQuality") private var qualityRaw: String = VideoQuality.medium.rawValue
    @AppStorage("recordingMicDeviceID") private var micDeviceID: String = ""
    @AppStorage("recordingCameraDeviceID") private var cameraDeviceID: String = ""

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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .onAppear {
            refreshDevices()
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

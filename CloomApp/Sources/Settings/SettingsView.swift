import SwiftUI

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

            CloudSettingsTab()
                .tabItem { Label("Cloud", systemImage: "icloud") }
        }
        .frame(width: 600, height: 480)
    }
}

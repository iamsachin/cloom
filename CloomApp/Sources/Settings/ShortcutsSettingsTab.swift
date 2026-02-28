import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Start / Stop Recording:", name: .toggleRecording)
            KeyboardShortcuts.Recorder("Pause / Resume:", name: .togglePause)
        }
        .formStyle(.grouped)
    }
}

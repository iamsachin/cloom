import SwiftUI

struct AISettingsTab: View {
    @AppStorage("aiAutoTranscribe") private var aiAutoTranscribe: Bool = true

    var body: some View {
        Form {
            APIKeyInputView()

            Toggle("Auto-transcribe after recording", isOn: $aiAutoTranscribe)
        }
        .formStyle(.grouped)
    }
}

import SwiftUI

struct AISettingsTab: View {
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

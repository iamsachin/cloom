import SwiftUI

struct AISettingsTab: View {
    @AppStorage(UserDefaultsKeys.aiAutoTranscribe) private var aiAutoTranscribe: Bool = true
    @AppStorage(UserDefaultsKeys.fillerMinConfidence) private var fillerMinConfidence: Double = 0.0

    @State private var singleWords: [String] = []
    @State private var phrases: [String] = []
    @State private var newWord: String = ""
    @State private var newPhrase: String = ""

    var body: some View {
        Form {
            APIKeyInputView()

            Toggle("Auto-transcribe after recording", isOn: $aiAutoTranscribe)

            fillerWordsSection
            fillerPhrasesSection
            sensitivitySection
        }
        .formStyle(.grouped)
        .onAppear(perform: loadFillerWords)
    }

    // MARK: - Single-Word Fillers

    @ViewBuilder
    private var fillerWordsSection: some View {
        Section {
            ForEach(Array(singleWords.enumerated()), id: \.offset) { index, word in
                HStack {
                    Text(word)
                    Spacer()
                    Button {
                        singleWords.remove(at: index)
                        persistSingleWords()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Add word…", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addSingleWord)
                Button("Add", action: addSingleWord)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            HStack {
                Text("Filler Words")
                Spacer()
                Button("Reset to Defaults") {
                    singleWords = defaultFillerWords()
                    persistSingleWords()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Multi-Word Filler Phrases

    @ViewBuilder
    private var fillerPhrasesSection: some View {
        Section {
            ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                HStack {
                    Text(phrase)
                    Spacer()
                    Button {
                        phrases.remove(at: index)
                        persistPhrases()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Add phrase…", text: $newPhrase)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addPhrase)
                Button("Add", action: addPhrase)
                    .disabled(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            HStack {
                Text("Filler Phrases")
                Spacer()
                Button("Reset to Defaults") {
                    phrases = defaultFillerPhrases()
                    persistPhrases()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Sensitivity

    @ViewBuilder
    private var sensitivitySection: some View {
        Section("Filler Detection Sensitivity") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Min Confidence")
                    Slider(value: $fillerMinConfidence, in: 0.0...0.9, step: 0.1)
                    Text(String(format: "%.0f%%", fillerMinConfidence * 100))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Words with transcription confidence below this threshold are skipped during filler detection. Set to 0% to detect all matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func addSingleWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !singleWords.contains(trimmed) else { return }
        singleWords.append(trimmed)
        singleWords.sort()
        persistSingleWords()
        newWord = ""
    }

    private func addPhrase() {
        let trimmed = newPhrase.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !phrases.contains(trimmed) else { return }
        phrases.append(trimmed)
        phrases.sort()
        persistPhrases()
        newPhrase = ""
    }

    // MARK: - Persistence

    private func loadFillerWords() {
        if let stored = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.fillerWordsSingle) {
            singleWords = stored
        } else {
            singleWords = defaultFillerWords()
        }
        if let stored = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.fillerWordsPhrases) {
            phrases = stored
        } else {
            phrases = defaultFillerPhrases()
        }
    }

    private func persistSingleWords() {
        UserDefaults.standard.set(singleWords, forKey: UserDefaultsKeys.fillerWordsSingle)
    }

    private func persistPhrases() {
        UserDefaults.standard.set(phrases, forKey: UserDefaultsKeys.fillerWordsPhrases)
    }
}

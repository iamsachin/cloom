import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TagEditor")

struct TagEditorView: View {
    enum Mode {
        case create
        case edit(TagRecord)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: String = "#007AFF"

    static let presetColors: [(String, String)] = [
        ("#FF3B30", "Red"),
        ("#FF9500", "Orange"),
        ("#FFCC00", "Yellow"),
        ("#34C759", "Green"),
        ("#007AFF", "Blue"),
        ("#AF52DE", "Purple"),
        ("#FF2D55", "Pink"),
        ("#8E8E93", "Gray"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Tag" : "New Tag")
                .font(.headline)

            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            // Color picker grid
            HStack(spacing: 12) {
                ForEach(Self.presetColors, id: \.0) { hex, label in
                    Button {
                        selectedColor = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selectedColor == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(label)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Button(isEditing ? "Save" : "Create") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            if case .edit(let tag) = mode {
                name = tag.name
                selectedColor = tag.color
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .create:
            let tag = TagRecord(name: trimmed, color: selectedColor)
            modelContext.insert(tag)
        case .edit(let tag):
            tag.name = trimmed
            tag.color = selectedColor
        }
        do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
        dismiss()
    }
}

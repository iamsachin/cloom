import SwiftUI

struct RewindPickerContentView: View {
    @ObservedObject var model: RewindPickerModel
    let onConfirm: (TimeInterval) -> Void
    let onCancel: () -> Void

    private let presets: [TimeInterval] = [5, 10, 30, 60]

    var body: some View {
        VStack(spacing: 16) {
            header
            presetButtons
            rewindSlider
            actionButtons
        }
        .padding(20)
        .frame(width: 340)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 4) {
            Text("Rewind Recording")
                .font(.headline)
            Text("Total recorded: \(formatTime(model.totalDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetButtons: some View {
        HStack(spacing: 8) {
            ForEach(presets.filter { $0 <= model.totalDuration }, id: \.self) { seconds in
                Button(formatPreset(seconds)) {
                    model.rewindSeconds = seconds
                }
                .buttonStyle(.bordered)
                .tint(model.rewindSeconds == seconds ? .accentColor : nil)
            }
        }
    }

    private var rewindSlider: some View {
        VStack(spacing: 4) {
            Slider(
                value: $model.rewindSeconds,
                in: 1...max(1, model.totalDuration),
                step: 1
            )

            HStack {
                Text("Rewind by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(model.rewindSeconds))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button("Confirm Rewind") {
                onConfirm(model.rewindSeconds)
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
            .disabled(model.rewindSeconds <= 0)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatPreset(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total >= 60 { return "\(total / 60)m" }
        return "\(total)s"
    }
}

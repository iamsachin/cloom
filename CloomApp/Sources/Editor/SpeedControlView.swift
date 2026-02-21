import SwiftUI

private struct SpeedOption: Identifiable {
    let id: Double
    let label: String
    var value: Double { id }
}

private let speedOptions: [SpeedOption] = [
    SpeedOption(id: 0.25, label: "0.25x"),
    SpeedOption(id: 0.5, label: "0.5x"),
    SpeedOption(id: 0.75, label: "0.75x"),
    SpeedOption(id: 1.0, label: "1x"),
    SpeedOption(id: 1.5, label: "1.5x"),
    SpeedOption(id: 2.0, label: "2x"),
    SpeedOption(id: 4.0, label: "4x"),
]

struct SpeedControlView: View {
    let editorState: EditorState

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text(speedLabel)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .help("Playback speed")
        .popover(isPresented: $showPopover) {
            VStack(spacing: 4) {
                Text("Playback Speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                ForEach(Array(speedOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        editorState.setSpeed(option.value)
                        showPopover = false
                    } label: {
                        HStack {
                            Text(option.label)
                                .frame(width: 50, alignment: .leading)
                            if editorState.edl.speedMultiplier == option.value {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .frame(width: 120)
        }
    }

    private var speedLabel: String {
        let s = editorState.edl.speedMultiplier
        if s == Double(Int(s)) {
            return "\(Int(s))x"
        }
        return String(format: "%.2gx", s)
    }
}

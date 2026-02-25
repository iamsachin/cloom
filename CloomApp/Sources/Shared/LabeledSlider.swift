import SwiftUI

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    private var isDefault: Bool {
        abs(value - defaultValue) < 0.01
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(isDefault ? .secondary : .accentColor)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            value = defaultValue
                        }
                    }
                    .help("Click to reset")
            }
            Slider(value: $value, in: range)
        }
    }
}

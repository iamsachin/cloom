import SwiftUI

struct ProcessingCardView: View {
    let info: PostRecordingInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.large)
                        Text(info.step.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text(info.step.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Spacer()

                    Text("Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .cardShadow, radius: 4, y: 2)
        .accessibilityLabel("Processing: \(info.title)")
    }
}

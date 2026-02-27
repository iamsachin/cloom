import SwiftUI

struct ProcessingCardView: View {
    let info: PostRecordingInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: 0)
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
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(info.step.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Spacer()

                    Text("Just now")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .cardShadow, radius: 3, y: 1)
        .accessibilityLabel("Processing: \(info.title)")
    }
}

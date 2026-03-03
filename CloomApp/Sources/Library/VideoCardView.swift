import SwiftUI
import SwiftData
import AppKit

struct VideoCardView: View {
    let video: VideoRecord

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with badges
            ZStack {
                AsyncThumbnailImage(thumbnailPath: video.thumbnailPath)
                    .aspectRatio(16 / 9, contentMode: .fit)

                // Top-right: transcript status badge
                VStack {
                    HStack {
                        Spacer()
                        if AIProcessingTracker.shared.isProcessing(video.id) {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Transcribing")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                        } else if video.hasTranscript {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.blue.opacity(0.8), in: Circle())
                                .padding(6)
                        }
                    }
                    Spacer()
                    // Bottom-right: duration badge
                    HStack {
                        Spacer()
                        Text(video.durationMs.formattedDuration)
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.durationBadge, in: RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))

            // Info section
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    CloudStatusBadgeView(videoId: video.id, uploadStatus: video.uploadStatus ?? "")

                    Spacer()

                    Text(relativeTime(from: video.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let summary = video.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(summary)
                }

                // Tag pills
                if !video.tags.isEmpty {
                    tagPills
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: isHovered ? .cardShadowHover : .cardShadow, radius: isHovered ? 6 : 3, y: isHovered ? 3 : 1)
        .brightness(isHovered ? 0.03 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("\(video.title), \(video.durationMs.formattedDuration)")
    }

    // MARK: - Tag Pills

    @ViewBuilder
    private var tagPills: some View {
        let maxDisplay = 2
        let displayTags = Array(video.tags.prefix(maxDisplay))
        let remaining = video.tags.count - maxDisplay

        HStack(spacing: 4) {
            ForEach(displayTags, id: \.id) { tag in
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: tag.color))
                        .frame(width: 5, height: 5)
                    Text(tag.name)
                        .font(.system(size: 9))
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color(hex: tag.color).opacity(0.12), in: Capsule())
            }
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "<1 min" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr" }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

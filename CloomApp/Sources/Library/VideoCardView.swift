import SwiftUI
import SwiftData

struct VideoCardView: View {
    let video: VideoRecord

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Group {
                if let nsImage = loadThumbnail() {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if AIProcessingTracker.shared.isProcessing(video.id) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing...")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if video.hasTranscript {
                        Image(systemName: "text.bubble.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    Text(video.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Tag Pills

    @ViewBuilder
    private var tagPills: some View {
        let maxDisplay = 3
        let displayTags = Array(video.tags.prefix(maxDisplay))
        let remaining = video.tags.count - maxDisplay

        HStack(spacing: 4) {
            ForEach(displayTags, id: \.id) { tag in
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: tag.color))
                        .frame(width: 6, height: 6)
                    Text(tag.name)
                        .font(.system(size: 9))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: tag.color).opacity(0.15), in: Capsule())
            }
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private func loadThumbnail() -> NSImage? {
        guard !video.thumbnailPath.isEmpty else { return nil }
        return NSImage(contentsOfFile: video.thumbnailPath)
    }

    private var formattedDuration: String {
        let totalSeconds = video.durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

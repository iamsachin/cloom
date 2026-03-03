import SwiftUI

// MARK: - Library List Row View

struct LibraryListRowView: View {
    let video: VideoRecord
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncThumbnailImage(
                    thumbnailPath: video.thumbnailPath,
                    placeholderIcon: "play.circle.fill",
                    placeholderIconFont: .caption
                )
                .aspectRatio(16 / 9, contentMode: .fill)
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Title + Summary
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if let summary = video.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Tags
                if !video.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(video.tags.prefix(2), id: \.id) { tag in
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 8, height: 8)
                        }
                        if video.tags.count > 2 {
                            Text("+\(video.tags.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Cloud status
                CloudStatusBadgeView(videoId: video.id, uploadStatus: video.uploadStatus ?? "", iconFontSize: 10)

                // Duration
                Text(video.durationMs.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                    .monospacedDigit()

                // Date
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)

                // Selection badge
                if isSelecting {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.selectionBadge)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .strokeBorder(.white, lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.listRowHover : .clear)
            )
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let days = Calendar.current.dateComponents([.day], from: video.createdAt, to: Date()).day ?? 0
        if days == 0 {
            formatter.dateFormat = "h:mm a"
        } else if days < 7 {
            formatter.dateFormat = "EEE"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: video.createdAt)
    }
}

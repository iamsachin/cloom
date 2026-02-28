import SwiftUI
import AppKit

// MARK: - Library List Row View

struct LibraryListRowView: View {
    let video: VideoRecord
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                Group {
                    if let nsImage = thumbnailImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
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
                cloudStatusIcon

                // Duration
                Text(formattedDuration)
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
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .task(id: video.thumbnailPath) {
            guard !video.thumbnailPath.isEmpty else {
                thumbnailImage = nil
                return
            }
            let key = video.thumbnailPath as NSString
            if let cached = thumbnailCache.object(forKey: key) {
                thumbnailImage = cached
                return
            }
            let path = video.thumbnailPath
            let loadTask = Task.detached(priority: .medium) {
                NSImage(contentsOfFile: path)
            }
            if let loaded = await loadTask.value {
                thumbnailCache.setObject(loaded, forKey: key)
                thumbnailImage = loaded
            }
        }
    }

    @ViewBuilder
    private var cloudStatusIcon: some View {
        let status = UploadStatus(video.uploadStatus)
        if DriveUploadManager.shared.isUploading(video.id) {
            ProgressView()
                .controlSize(.mini)
        } else if status == .uploaded {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
                .help("Shared on Google Drive")
        } else if status == .failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .help("Upload failed")
        }
    }

    private var formattedDuration: String {
        let totalSeconds = video.durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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

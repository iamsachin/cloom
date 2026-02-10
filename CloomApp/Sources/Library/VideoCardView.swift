import SwiftUI
import SwiftData

struct VideoCardView: View {
    let video: VideoRecord

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

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(video.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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

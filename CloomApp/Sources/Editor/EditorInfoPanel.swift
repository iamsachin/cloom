import SwiftUI

struct EditorInfoPanel: View {
    let videoRecord: VideoRecord
    let durationMs: Int64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Info")
                    .font(.headline)
                    .padding(.bottom, 4)

                Text(videoRecord.title)
                    .font(.title3.bold())

                if let summary = videoRecord.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(formatTime(ms: durationMs), systemImage: "clock")
                    Label(formattedFileSize(videoRecord.fileSizeBytes), systemImage: "doc")
                    Label("\(videoRecord.width)x\(videoRecord.height)", systemImage: "rectangle")
                    Label(videoRecord.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let millis = Int((ms % 1000) / 10)
        return String(format: "%d:%02d.%02d", minutes, seconds, millis)
    }
}

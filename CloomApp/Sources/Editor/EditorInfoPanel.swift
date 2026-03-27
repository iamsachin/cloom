import SwiftUI
import AppKit

struct EditorInfoPanel: View {
    let videoRecord: VideoRecord
    let durationMs: Int64

    @State private var metadata: VideoMetadata?

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

                detailsSection

                Divider()

                encodingSection

                cloudSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .task {
            metadata = await VideoMetadataLoader.load(from: videoRecord.filePath)
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)

            Label(formatTime(ms: durationMs), systemImage: "clock")
            Label(formattedFileSize(videoRecord.fileSizeBytes), systemImage: "doc")
            Label("\(videoRecord.width)x\(videoRecord.height)", systemImage: "rectangle")
            Label(
                videoRecord.createdAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            )

            if let quality = VideoQuality(rawValue: videoRecord.recordingQuality ?? "") {
                Label("Quality: \(quality.label)", systemImage: "dial.medium")
            }

            Label(
                videoRecord.recordingType == "screenAndWebcam" ? "Screen + Webcam" : "Screen Only",
                systemImage: videoRecord.recordingType == "screenAndWebcam"
                    ? "person.crop.rectangle" : "rectangle.on.rectangle"
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Encoding

    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encoding")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)

            if let metadata {
                if let codec = metadata.videoCodec {
                    Label("Video: \(codec)", systemImage: "film")
                }
                if let bitrate = metadata.videoBitrate {
                    Label("Bitrate: \(formattedBitrate(bitrate))", systemImage: "speedometer")
                }
                if let fps = metadata.fps {
                    Label("FPS: \(String(format: "%.0f", fps))", systemImage: "timer")
                }
                if let audioCodec = metadata.audioCodec {
                    Label(
                        "Audio: \(audioCodec) (\(metadata.audioTrackCount) track\(metadata.audioTrackCount == 1 ? "" : "s"))",
                        systemImage: "waveform"
                    )
                } else if metadata.audioTrackCount > 0 {
                    Label(
                        "Audio: \(metadata.audioTrackCount) track\(metadata.audioTrackCount == 1 ? "" : "s")",
                        systemImage: "waveform"
                    )
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Cloud

    @ViewBuilder
    private var cloudSection: some View {
        let status = UploadStatus(videoRecord.uploadStatus)
        if status != nil || videoRecord.shareUrl != nil {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Cloud")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)

                if let shareUrl = videoRecord.shareUrl, status == .uploaded {
                    HStack {
                        Label("Shared", systemImage: "link.circle.fill")
                            .foregroundStyle(.green)

                        Spacer()

                        Button("Copy Link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(shareUrl, forType: .string)
                        }
                        .controlSize(.small)
                    }
                } else if status == .uploading {
                    Label("Uploading...", systemImage: "arrow.up.circle")
                        .foregroundStyle(.orange)
                } else if status == .failed {
                    Label("Upload failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                if let uploadedAt = videoRecord.uploadedAt {
                    Label(
                        uploadedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatting

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedBitrate(_ bps: Int) -> String {
        if bps >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bps) / 1_000_000)
        } else {
            return String(format: "%d kbps", bps / 1000)
        }
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let millis = Int((ms % 1000) / 10)
        return String(format: "%d:%02d.%02d", minutes, seconds, millis)
    }
}

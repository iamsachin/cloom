import SwiftUI
import SwiftData
import AppKit
import CoreGraphics

struct VideoCardView: View {
    let video: VideoRecord
    var onTagTap: ((String) -> Void)?

    @State private var isHovered = false
    @State private var hasAppeared = false
    @State private var previewFrames: [CGImage]?
    @State private var previewIndex = 0
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with badges
            ZStack {
                AsyncThumbnailImage(thumbnailPath: video.thumbnailPath)
                    .aspectRatio(16 / 9, contentMode: .fit)

                // Hover preview overlay — fills thumbnail frame exactly
                if isHovered, let frames = previewFrames, !frames.isEmpty {
                    GeometryReader { geo in
                        Image(decorative: frames[previewIndex], scale: 1.0)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .transition(.opacity)
                }

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
                    // Bottom: progress dots + duration badge
                    HStack {
                        if isHovered, let frames = previewFrames, !frames.isEmpty {
                            previewDots(count: frames.count, current: previewIndex)
                        }
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
            .clipped()
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

                // Metadata chips
                HStack(spacing: 4) {
                    metadataChip("\(video.width)x\(video.height)", color: .blue)
                    metadataChip(formattedFileSize(video.fileSizeBytes), color: .green)
                }
                HStack(spacing: 4) {
                    if let raw = video.recordingQuality, let q = VideoQuality(rawValue: raw) {
                        metadataChip(q.label, color: .purple)
                    }
                    metadataChip(video.recordingType == "screenAndWebcam" ? "Screen+Cam" : "Screen", color: .orange)
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
        .shadow(color: isHovered ? .cardShadowHover : .cardShadow, radius: isHovered ? 4 : 2, y: isHovered ? 2 : 1)
        .brightness(isHovered ? 0.02 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                startPreview()
            } else {
                stopPreview()
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }
        }
        .help(videoTooltip)
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
                tagPillButton(tag)
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

    @ViewBuilder
    private func tagPillButton(_ tag: TagRecord) -> some View {
        let pill = HStack(spacing: 3) {
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

        if let onTagTap {
            Button {
                onTagTap(tag.id)
            } label: {
                pill
            }
            .buttonStyle(.plain)
            .help("Filter by \(tag.name)")
        } else {
            pill
        }
    }

    @ViewBuilder
    private func metadataChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private var videoTooltip: String {
        var lines: [String] = []
        lines.append("\(video.width)x\(video.height)")
        lines.append(video.durationMs.formattedDuration)
        lines.append(formattedFileSize(video.fileSizeBytes))
        if let raw = video.recordingQuality, let quality = VideoQuality(rawValue: raw) {
            lines.append("Quality: \(quality.label)")
        }
        let type = video.recordingType == "screenAndWebcam" ? "Screen + Webcam" : "Screen Only"
        lines.append(type)
        lines.append(video.createdAt.formatted(date: .abbreviated, time: .shortened))
        return lines.joined(separator: "\n")
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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

    // MARK: - Hover Preview

    private func startPreview() {
        previewTask = Task {
            // Debounce: wait 300ms before loading
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let frames = try await HoverPreviewGenerator.shared.previewFrames(for: video.filePath)
                guard !Task.isCancelled, !frames.isEmpty else { return }
                previewFrames = frames
                previewIndex = 0

                // Cycle through frames
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { break }
                    previewIndex = (previewIndex + 1) % frames.count
                }
            } catch {
                // Silently fail — just show static thumbnail
            }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewIndex = 0
    }

    @ViewBuilder
    private func previewDots(count: Int, current: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.leading, 8)
        .padding(.bottom, 8)
    }
}

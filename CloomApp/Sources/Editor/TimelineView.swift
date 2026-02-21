import SwiftUI

struct EditorTimelineView: View {
    let editorState: EditorState

    @State private var isDragging = false

    var body: some View {
        // Read @Observable properties in view builder context so SwiftUI tracks changes
        let peaks = editorState.waveformPeaks
        let thumbnails = editorState.thumbnailImages
        let currentTimeMs = editorState.currentTimeMs
        let durationMs = editorState.durationMs

        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.controlBackgroundColor))

                // Thumbnail strip (top half)
                thumbnailStrip(thumbnails: thumbnails, width: width, height: height * 0.5)
                    .offset(y: -height * 0.25)

                // Waveform (bottom half)
                waveformCanvas(peaks: peaks, width: width, height: height * 0.4)
                    .offset(y: height * 0.2)

                // Trim handles overlay
                TrimHandlesView(editorState: editorState, timelineWidth: width)

                // Cut region overlays
                CutRegionOverlay(editorState: editorState, timelineWidth: width)

                // Chapter markers
                chapterMarkers(chapters: editorState.chapters, durationMs: durationMs, width: width, height: height)

                // Playhead
                playhead(currentTimeMs: currentTimeMs, durationMs: durationMs, width: width, height: height)
            }
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let fraction = max(0, min(1, value.location.x / width))
                        let ms = Int64(Double(durationMs) * fraction)
                        editorState.seekTo(ms: ms)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }

    // MARK: - Thumbnail Strip

    @ViewBuilder
    private func thumbnailStrip(thumbnails: [(timeMs: Int64, image: CGImage)], width: CGFloat, height: CGFloat) -> some View {
        if !thumbnails.isEmpty {
            Canvas { context, size in
                let thumbCount = thumbnails.count
                let thumbWidth = size.width / CGFloat(thumbCount)

                for (i, thumb) in thumbnails.enumerated() {
                    let x = CGFloat(i) * thumbWidth
                    let rect = CGRect(x: x, y: 0, width: thumbWidth, height: size.height)
                    let nsImage = NSImage(cgImage: thumb.image, size: NSSize(width: thumb.image.width, height: thumb.image.height))
                    context.draw(Image(nsImage: nsImage), in: rect)
                }
            }
            .frame(width: width, height: height)
            .opacity(0.6)
        }
    }

    // MARK: - Waveform

    @ViewBuilder
    private func waveformCanvas(peaks: [Float], width: CGFloat, height: CGFloat) -> some View {
        if !peaks.isEmpty {
            Canvas { context, size in
                let barWidth = size.width / CGFloat(peaks.count)
                let midY = size.height / 2

                for (i, peak) in peaks.enumerated() {
                    let barHeight = CGFloat(peak) * size.height * 0.9
                    let x = CGFloat(i) * barWidth
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: max(barWidth - 0.5, 0.5),
                        height: max(barHeight, 1)
                    )
                    context.fill(Path(rect), with: .color(.accentColor.opacity(0.6)))
                }
            }
            .frame(width: width, height: height)
        }
    }

    // MARK: - Chapter Markers

    @ViewBuilder
    private func chapterMarkers(chapters: [ChapterSnapshot], durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        if !chapters.isEmpty && durationMs > 0 {
            ForEach(chapters) { chapter in
                let fraction = CGFloat(chapter.startMs) / CGFloat(durationMs)
                let x = fraction * width

                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x - 4, y: -8))
                    path.addLine(to: CGPoint(x: x + 4, y: -8))
                    path.closeSubpath()
                }
                .fill(Color.accentColor)
                .offset(y: height * 0.1)

                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(width: 1, height: height)
                    .offset(x: x)
            }
        }
    }

    // MARK: - Playhead

    @ViewBuilder
    private func playhead(currentTimeMs: Int64, durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        let fraction = durationMs > 0
            ? CGFloat(currentTimeMs) / CGFloat(durationMs)
            : 0
        let x = fraction * width

        Rectangle()
            .fill(Color.red)
            .frame(width: 2, height: height)
            .offset(x: x)
    }
}

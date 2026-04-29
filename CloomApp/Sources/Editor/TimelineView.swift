import SwiftUI

struct EditorTimelineView: View {
    let editorState: EditorState
    var cutMarkInMs: Int64? = nil

    @State private var isDragging = false
    @State private var gestureStartHandled = false
    @State private var gestureConsumedBySelection = false

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

                // Blur region overlays on timeline
                blurRegionBars(durationMs: durationMs, width: width, height: height)

                // Auto-cut preview overlay (silences/fillers)
                if editorState.isShowingCutPreview {
                    AutoCutPreviewOverlay(editorState: editorState, timelineWidth: width)
                }

                // Chapter markers
                chapterMarkers(chapters: editorState.chapters, durationMs: durationMs, width: width, height: height)

                // Bookmark markers
                bookmarkMarkers(bookmarks: editorState.bookmarks, durationMs: durationMs, width: width, height: height)

                // Punch-in re-record markers
                punchInMarkerOverlays(markers: editorState.punchInMarkers, durationMs: durationMs, width: width, height: height)

                // Mark-in indicator
                markInIndicator(durationMs: durationMs, currentTimeMs: currentTimeMs, width: width, height: height)

                // Playhead
                playhead(currentTimeMs: currentTimeMs, durationMs: durationMs, width: width, height: height)
            }
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !gestureStartHandled {
                            gestureStartHandled = true
                            if editorState.isShowingCutPreview,
                               let hit = previewBarHit(at: value.location.x, width: width) {
                                editorState.togglePreviewSelection(hit)
                                gestureConsumedBySelection = true
                                return
                            }
                        }
                        if gestureConsumedBySelection { return }
                        isDragging = true
                        let fraction = max(0, min(1, value.location.x / width))
                        let ms = Int64(Double(durationMs) * fraction)
                        editorState.seekTo(ms: ms)
                    }
                    .onEnded { _ in
                        isDragging = false
                        gestureStartHandled = false
                        gestureConsumedBySelection = false
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
        let maxPeak = peaks.max() ?? 0
        if !peaks.isEmpty && maxPeak > 0.001 {
            let normFactor: Float = 1.0 / maxPeak

            Canvas { context, size in
                let midY = size.height / 2
                let count = peaks.count

                // Downsample peaks for smoother curves — ~1 point per 2px
                let targetPoints = max(4, Int(size.width / 2))
                let stride = max(1, count / targetPoints)
                let pointCount = (count + stride - 1) / stride

                // Build amplitude array (downsampled, normalized, sqrt-boosted)
                var amplitudes = [CGFloat](repeating: 0, count: pointCount)
                for i in 0..<pointCount {
                    let start = i * stride
                    let end = min(start + stride, count)
                    var maxVal: Float = 0
                    for j in start..<end {
                        maxVal = max(maxVal, peaks[j])
                    }
                    let normalized = min(maxVal * normFactor, 1.0)
                    amplitudes[i] = CGFloat(sqrt(normalized)) * size.height * 0.45
                }

                let step = size.width / CGFloat(pointCount - 1)

                // Build top path (above center) using smooth quadratic curves
                var topPath = Path()
                topPath.move(to: CGPoint(x: 0, y: midY - amplitudes[0]))
                for i in 1..<pointCount {
                    let prev = CGPoint(x: CGFloat(i - 1) * step, y: midY - amplitudes[i - 1])
                    let curr = CGPoint(x: CGFloat(i) * step, y: midY - amplitudes[i])
                    let midX = (prev.x + curr.x) / 2
                    let midYTop = (prev.y + curr.y) / 2
                    topPath.addQuadCurve(to: midYTop == midY ? curr : CGPoint(x: midX, y: midYTop), control: prev)
                    topPath.addQuadCurve(to: curr, control: CGPoint(x: midX, y: midYTop))
                }

                // Continue path along bottom (mirror) back to start
                for i in (0..<pointCount).reversed() {
                    let curr = CGPoint(x: CGFloat(i) * step, y: midY + amplitudes[i])
                    if i == pointCount - 1 {
                        topPath.addLine(to: curr)
                    } else {
                        let next = CGPoint(x: CGFloat(i + 1) * step, y: midY + amplitudes[i + 1])
                        let midX = (curr.x + next.x) / 2
                        let midYBot = (curr.y + next.y) / 2
                        topPath.addQuadCurve(to: CGPoint(x: midX, y: midYBot), control: next)
                        topPath.addQuadCurve(to: curr, control: CGPoint(x: midX, y: midYBot))
                    }
                }
                topPath.closeSubpath()

                context.fill(topPath, with: .color(.accentColor.opacity(0.7)))

                // Draw a thin center line
                var centerLine = Path()
                centerLine.move(to: CGPoint(x: 0, y: midY))
                centerLine.addLine(to: CGPoint(x: size.width, y: midY))
                context.stroke(centerLine, with: .color(.accentColor.opacity(0.3)), lineWidth: 0.5)
            }
            .frame(width: width, height: height)
        }
    }

    // MARK: - Blur Region Bars

    @ViewBuilder
    private func blurRegionBars(durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        let regions = editorState.edl.blurRegions
        if !regions.isEmpty && durationMs > 0 {
            ForEach(regions) { region in
                let startFrac = CGFloat(region.startMs) / CGFloat(durationMs)
                let endFrac = CGFloat(region.endMs) / CGFloat(durationMs)
                let barX = startFrac * width
                let barW = max(2, (endFrac - startFrac) * width)

                Rectangle()
                    .fill(blurBarColor(region.style).opacity(0.35))
                    .frame(width: barW, height: 6)
                    .clipShape(Capsule())
                    .offset(x: barX + barW / 2 - width / 2, y: height * 0.42)
                    .help("\(region.style.displayName) (\(formatMs(region.startMs))–\(formatMs(region.endMs)))")
                    .allowsHitTesting(false)
            }
        }
    }

    private func blurBarColor(_ style: BlurStyle) -> Color {
        switch style {
        case .gaussian: .red
        case .pixelate: .orange
        case .blackBox: .white
        }
    }

    // MARK: - Chapter Markers

    @ViewBuilder
    private func chapterMarkers(chapters: [ChapterSnapshot], durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        if !chapters.isEmpty && durationMs > 0 {
            ForEach(chapters) { chapter in
                let fraction = CGFloat(chapter.startMs) / CGFloat(durationMs)
                let x = fraction * width
                let tooltip = chapter.title.isEmpty ? formatMs(chapter.startMs) : chapter.title

                ZStack {
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

                    // Invisible hit-test area for tooltip
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: height)
                        .offset(x: x)
                        .contentShape(Rectangle())
                }
                .help(tooltip)
            }
        }
    }

    // MARK: - Bookmark Markers

    @ViewBuilder
    private func bookmarkMarkers(bookmarks: [BookmarkSnapshot], durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        if !bookmarks.isEmpty && durationMs > 0 {
            ForEach(bookmarks) { bookmark in
                let fraction = CGFloat(bookmark.timestampMs) / CGFloat(durationMs)
                let x = fraction * width
                let tooltip = bookmark.text.isEmpty ? formatMs(bookmark.timestampMs) : bookmark.text

                ZStack {
                    // Green diamond
                    Path { path in
                        path.move(to: CGPoint(x: x, y: -6))
                        path.addLine(to: CGPoint(x: x + 5, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 6))
                        path.addLine(to: CGPoint(x: x - 5, y: 0))
                        path.closeSubpath()
                    }
                    .fill(Color.green)
                    .offset(y: height * 0.1)

                    Rectangle()
                        .fill(Color.green.opacity(0.4))
                        .frame(width: 1, height: height)
                        .offset(x: x)

                    // Invisible hit-test area for tooltip
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: height)
                        .offset(x: x)
                        .contentShape(Rectangle())
                }
                .help(tooltip)
            }
        }
    }

    // MARK: - Punch-In Markers

    @ViewBuilder
    private func punchInMarkerOverlays(markers: [PunchInMarker], durationMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        if !markers.isEmpty && durationMs > 0 {
            ForEach(markers) { marker in
                let fraction = CGFloat(marker.timestampMs) / CGFloat(durationMs)
                let x = fraction * width

                ZStack {
                    // Amber arrow indicator
                    Image(systemName: "backward.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.orange)
                        .offset(x: x, y: -height * 0.35)

                    // Amber vertical line
                    Rectangle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 1.5, height: height)
                        .offset(x: x)

                    // Invisible hit-test area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: height)
                        .offset(x: x)
                        .contentShape(Rectangle())
                }
                .help("Punch-in at \(formatMs(marker.timestampMs))")
            }
        }
    }

    // MARK: - Mark-In Indicator

    @ViewBuilder
    private func markInIndicator(durationMs: Int64, currentTimeMs: Int64, width: CGFloat, height: CGFloat) -> some View {
        if let markIn = cutMarkInMs, durationMs > 0 {
            let markFrac = CGFloat(markIn) / CGFloat(durationMs)
            let markX = markFrac * width
            let currentFrac = CGFloat(currentTimeMs) / CGFloat(durationMs)
            let currentX = currentFrac * width
            let regionWidth = currentX - markX

            // Shaded region from mark-in to playhead
            if regionWidth > 0 {
                Rectangle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: regionWidth, height: height)
                    .offset(x: markX + regionWidth / 2 - width / 2)
                    .allowsHitTesting(false)
            }

            // Orange vertical line at mark-in point
            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: height)
                .offset(x: markX)

            // Small flag at top of mark-in line
            Path { path in
                path.move(to: CGPoint(x: markX, y: 0))
                path.addLine(to: CGPoint(x: markX + 8, y: 4))
                path.addLine(to: CGPoint(x: markX, y: 8))
                path.closeSubpath()
            }
            .fill(Color.orange)
        }
    }

    // MARK: - Helpers

    /// Returns the ID of the preview bar under the given click x, if any.
    /// Hit-tests in pixel space using the same `max(_, 2)` width floor as the
    /// overlay, so the click target matches what the user sees.
    private func previewBarHit(at clickX: CGFloat, width: CGFloat) -> UUID? {
        let durationMs = editorState.durationMs
        guard durationMs > 0 else { return nil }
        for range in editorState.previewCutRanges {
            let startFrac = CGFloat(range.startMs) / CGFloat(durationMs)
            let endFrac = CGFloat(range.endMs) / CGFloat(durationMs)
            let barX = startFrac * width
            let barW = max((endFrac - startFrac) * width, 2)
            if clickX >= barX && clickX <= barX + barW {
                return range.id
            }
        }
        return nil
    }

    private func formatMs(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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

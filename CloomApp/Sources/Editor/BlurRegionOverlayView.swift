import SwiftUI

/// Overlay on the video preview that displays blur region rectangles
/// with drag-to-move, edge resize handles, and draw-new-region support.
/// Accounts for AVPlayerLayer's `.resizeAspect` letterboxing.
struct BlurRegionOverlayView: View {
    let editorState: EditorState
    let isDrawing: Bool
    @Binding var selectedRegionID: String?

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let contentRect = videoContentRect(in: geo.size)
            ZStack {
                // Draw mode: invisible surface captures mouse events
                if isDrawing {
                    Color.white.opacity(0.001)
                        .gesture(drawGesture(contentRect: contentRect))
                }

                // Existing blur regions
                ForEach(activeRegions) { region in
                    BlurRegionRectView(
                        region: region,
                        contentRect: contentRect,
                        isSelected: selectedRegionID == region.id,
                        onSelect: {
                            selectedRegionID = selectedRegionID == region.id ? nil : region.id
                        },
                        onUpdate: { updated in
                            editorState.updateBlurRegion(updated)
                        }
                    )
                }

                // Live drag preview for new regions
                if let start = dragStart, let current = dragCurrent, isDrawing {
                    let rect = normalizedRect(from: start, to: current, contentRect: contentRect)
                    let w = rect.width * contentRect.width
                    let h = rect.height * contentRect.height
                    let cx = contentRect.minX + (rect.x + rect.width / 2) * contentRect.width
                    let cy = contentRect.minY + (rect.y + rect.height / 2) * contentRect.height
                    Rectangle()
                        .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        .background(Rectangle().fill(Color.red.opacity(0.15)))
                        .frame(width: w, height: h)
                        .position(x: cx, y: cy)
                        .allowsHitTesting(false)
                }
            }
        }
        .allowsHitTesting(isDrawing || !editorState.edl.blurRegions.isEmpty)
    }

    // MARK: - Video Content Rect

    func videoContentRect(in viewSize: CGSize) -> CGRect {
        let videoW = CGFloat(editorState.videoRecord.width)
        let videoH = CGFloat(editorState.videoRecord.height)
        guard videoW > 0 && videoH > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }
        let viewAspect = viewSize.width / viewSize.height
        let videoAspect = videoW / videoH
        if videoAspect > viewAspect {
            let contentW = viewSize.width
            let contentH = viewSize.width / videoAspect
            return CGRect(x: 0, y: (viewSize.height - contentH) / 2, width: contentW, height: contentH)
        } else {
            let contentH = viewSize.height
            let contentW = viewSize.height * videoAspect
            return CGRect(x: (viewSize.width - contentW) / 2, y: 0, width: contentW, height: contentH)
        }
    }

    // MARK: - Active Regions

    private var activeRegions: [BlurRegion] {
        let currentMs = editorState.currentTimeMs
        return editorState.edl.blurRegions.filter { $0.startMs <= currentMs && $0.endMs >= currentMs }
    }

    // MARK: - Draw Gesture

    private func drawGesture(contentRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard isDrawing else { return }
                if dragStart == nil { dragStart = value.startLocation }
                dragCurrent = value.location
            }
            .onEnded { value in
                guard isDrawing, let start = dragStart else {
                    dragStart = nil; dragCurrent = nil; return
                }
                let rect = normalizedRect(from: start, to: value.location, contentRect: contentRect)
                if rect.width >= 0.02 && rect.height >= 0.02 {
                    let region = BlurRegion(
                        startMs: 0, endMs: editorState.durationMs,
                        x: rect.x, y: rect.y, width: rect.width, height: rect.height
                    )
                    editorState.addBlurRegion(region)
                    selectedRegionID = region.id
                }
                dragStart = nil; dragCurrent = nil
            }
    }

    // MARK: - Helpers

    private struct NormalizedRect {
        let x: Double; let y: Double; let width: Double; let height: Double
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint, contentRect: CGRect) -> NormalizedRect {
        let minX = (min(start.x, end.x) - contentRect.minX) / contentRect.width
        let minY = (min(start.y, end.y) - contentRect.minY) / contentRect.height
        let maxX = (max(start.x, end.x) - contentRect.minX) / contentRect.width
        let maxY = (max(start.y, end.y) - contentRect.minY) / contentRect.height
        return NormalizedRect(
            x: max(0, min(1, minX)), y: max(0, min(1, minY)),
            width: min(1, max(0, maxX)) - max(0, min(1, minX)),
            height: min(1, max(0, maxY)) - max(0, min(1, minY))
        )
    }
}

// MARK: - Resize Edge

enum ResizeEdge {
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Individual Region View (with move + resize)

/// Stores the region's original normalized rect at drag start so cumulative
/// translation can be applied correctly (not as incremental deltas).
private struct BlurRegionRectView: View {
    let region: BlurRegion
    let contentRect: CGRect
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (_ updated: BlurRegion) -> Void

    /// Snapshot of the region at drag start — used for both move and resize.
    @State private var dragOrigin: BlurRegion?

    private let handleSize: CGFloat = 8
    private let minSize = 0.02

    private var w: CGFloat { region.width * contentRect.width }
    private var h: CGFloat { region.height * contentRect.height }
    private var cx: CGFloat { contentRect.minX + (region.x + region.width / 2) * contentRect.width }
    private var cy: CGFloat { contentRect.minY + (region.y + region.height / 2) * contentRect.height }

    var body: some View {
        ZStack {
            // Main rectangle — tap to select, drag to move
            Rectangle()
                .strokeBorder(
                    isSelected ? Color.white : Color.red,
                    style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: [6, 3])
                )
                .background(Rectangle().fill(styleColor.opacity(0.2)))
                .frame(width: w, height: h)
                .position(x: cx, y: cy)
                .gesture(moveGesture)
                .simultaneousGesture(TapGesture().onEnded { onSelect() })

            // Resize handles (only when selected)
            if isSelected {
                resizeHandle(edge: .topLeft, x: cx - w / 2, y: cy - h / 2)
                resizeHandle(edge: .topRight, x: cx + w / 2, y: cy - h / 2)
                resizeHandle(edge: .bottomLeft, x: cx - w / 2, y: cy + h / 2)
                resizeHandle(edge: .bottomRight, x: cx + w / 2, y: cy + h / 2)
                resizeHandle(edge: .top, x: cx, y: cy - h / 2)
                resizeHandle(edge: .bottom, x: cx, y: cy + h / 2)
                resizeHandle(edge: .left, x: cx - w / 2, y: cy)
                resizeHandle(edge: .right, x: cx + w / 2, y: cy)
            }
        }
    }

    // MARK: - Move

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = region }
                guard let origin = dragOrigin else { return }
                let dx = value.translation.width / contentRect.width
                let dy = value.translation.height / contentRect.height
                var updated = region
                updated.x = max(0, min(1 - origin.width, origin.x + dx))
                updated.y = max(0, min(1 - origin.height, origin.y + dy))
                onUpdate(updated)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    // MARK: - Resize Handles

    @ViewBuilder
    private func resizeHandle(edge: ResizeEdge, x: CGFloat, y: CGFloat) -> some View {
        let isCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight].contains(edge)
        let size = isCorner ? handleSize + 2 : handleSize
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.4), radius: 1)
            .position(x: x, y: y)
            .gesture(resizeGesture(edge: edge))
    }

    private func resizeGesture(edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = region }
                guard let o = dragOrigin else { return }
                let dx = value.translation.width / contentRect.width
                let dy = value.translation.height / contentRect.height
                var r = o // always start from the snapshot

                switch edge {
                case .left:
                    let newX = max(0, o.x + dx)
                    let newW = o.width - (newX - o.x)
                    if newW >= minSize { r.x = newX; r.width = newW }
                case .right:
                    r.width = max(minSize, min(1 - o.x, o.width + dx))
                case .top:
                    let newY = max(0, o.y + dy)
                    let newH = o.height - (newY - o.y)
                    if newH >= minSize { r.y = newY; r.height = newH }
                case .bottom:
                    r.height = max(minSize, min(1 - o.y, o.height + dy))
                case .topLeft:
                    let newX = max(0, o.x + dx)
                    let newW = o.width - (newX - o.x)
                    let newY = max(0, o.y + dy)
                    let newH = o.height - (newY - o.y)
                    if newW >= minSize { r.x = newX; r.width = newW }
                    if newH >= minSize { r.y = newY; r.height = newH }
                case .topRight:
                    r.width = max(minSize, min(1 - o.x, o.width + dx))
                    let newY = max(0, o.y + dy)
                    let newH = o.height - (newY - o.y)
                    if newH >= minSize { r.y = newY; r.height = newH }
                case .bottomLeft:
                    let newX = max(0, o.x + dx)
                    let newW = o.width - (newX - o.x)
                    if newW >= minSize { r.x = newX; r.width = newW }
                    r.height = max(minSize, min(1 - o.y, o.height + dy))
                case .bottomRight:
                    r.width = max(minSize, min(1 - o.x, o.width + dx))
                    r.height = max(minSize, min(1 - o.y, o.height + dy))
                }
                onUpdate(r)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var styleColor: Color {
        switch region.style {
        case .gaussian: .red
        case .pixelate: .orange
        case .blackBox: .primary
        }
    }
}

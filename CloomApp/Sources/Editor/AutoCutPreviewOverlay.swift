import SwiftUI

/// Shows preview highlights on the timeline for auto-cut ranges (silences/fillers).
/// Selected ranges fill orange; deselected ranges show a dashed outline only,
/// signalling they will be excluded when the user hits Apply.
struct AutoCutPreviewOverlay: View {
    let editorState: EditorState
    let timelineWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            ForEach(editorState.previewCutRanges) { range in
                let isSelected = editorState.selectedPreviewIDs.contains(range.id)
                let startFrac = CGFloat(range.startMs) / CGFloat(max(1, editorState.durationMs))
                let endFrac = CGFloat(range.endMs) / CGFloat(max(1, editorState.durationMs))
                let x = startFrac * timelineWidth
                let w = (endFrac - startFrac) * timelineWidth

                Rectangle()
                    .fill(isSelected ? Color.orange.opacity(0.25) : Color.clear)
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .frame(width: max(w, 2), height: height)
                    .offset(x: x)
            }
        }
        .allowsHitTesting(false)
    }
}

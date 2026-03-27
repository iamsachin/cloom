import SwiftUI

/// Shows preview highlights on the timeline for auto-cut ranges (silences/fillers).
/// Orange dashed rectangles indicate regions that will be cut when the user confirms.
struct AutoCutPreviewOverlay: View {
    let editorState: EditorState
    let timelineWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            ForEach(Array(editorState.previewCutRanges.enumerated()), id: \.offset) { _, range in
                let startFrac = CGFloat(range.startMs) / CGFloat(max(1, editorState.durationMs))
                let endFrac = CGFloat(range.endMs) / CGFloat(max(1, editorState.durationMs))
                let x = startFrac * timelineWidth
                let w = (endFrac - startFrac) * timelineWidth

                Rectangle()
                    .fill(Color.orange.opacity(0.25))
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

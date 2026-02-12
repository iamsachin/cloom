import SwiftUI

struct CutRegionOverlay: View {
    let editorState: EditorState
    let timelineWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            ForEach(editorState.edl.cuts) { cut in
                let startFrac = CGFloat(cut.startMs) / CGFloat(max(1, editorState.durationMs))
                let endFrac = CGFloat(cut.endMs) / CGFloat(max(1, editorState.durationMs))
                let x = startFrac * timelineWidth
                let w = (endFrac - startFrac) * timelineWidth

                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .overlay {
                        // Hatched pattern
                        Canvas { context, size in
                            let spacing: CGFloat = 8
                            var x: CGFloat = -size.height
                            while x < size.width + size.height {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                                context.stroke(path, with: .color(.red.opacity(0.3)), lineWidth: 1)
                                x += spacing
                            }
                        }
                    }
                    .frame(width: max(w, 2), height: height)
                    .offset(x: x)
                    .contextMenu {
                        Button("Remove Cut") {
                            editorState.removeCut(id: cut.id)
                        }
                    }
            }
        }
        .allowsHitTesting(true)
    }
}

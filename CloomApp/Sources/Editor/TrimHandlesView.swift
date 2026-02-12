import SwiftUI

struct TrimHandlesView: View {
    let editorState: EditorState
    let timelineWidth: CGFloat

    private let handleWidth: CGFloat = 10

    private var trimStartFraction: CGFloat {
        guard editorState.durationMs > 0 else { return 0 }
        return CGFloat(editorState.edl.trimStartMs) / CGFloat(editorState.durationMs)
    }

    private var trimEndFraction: CGFloat {
        guard editorState.durationMs > 0 else { return 1 }
        let endMs = editorState.edl.trimEndMs > 0 ? editorState.edl.trimEndMs : editorState.durationMs
        return CGFloat(endMs) / CGFloat(editorState.durationMs)
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Grayed out: before trim start
                if trimStartFraction > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: trimStartFraction * timelineWidth, height: height)
                }

                // Grayed out: after trim end
                if trimEndFraction < 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: (1 - trimEndFraction) * timelineWidth, height: height)
                        .offset(x: trimEndFraction * timelineWidth)
                }

                // Left trim handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.yellow)
                    .frame(width: handleWidth, height: height)
                    .offset(x: trimStartFraction * timelineWidth - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let fraction = max(0, min(trimEndFraction - 0.01, value.location.x / timelineWidth))
                                let ms = Int64(Double(editorState.durationMs) * fraction)
                                editorState.setTrimStart(ms: ms)
                            }
                    )

                // Right trim handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.yellow)
                    .frame(width: handleWidth, height: height)
                    .offset(x: trimEndFraction * timelineWidth - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let fraction = max(trimStartFraction + 0.01, min(1, value.location.x / timelineWidth))
                                let ms = Int64(Double(editorState.durationMs) * fraction)
                                editorState.setTrimEnd(ms: ms)
                            }
                    )
            }
        }
        .allowsHitTesting(true)
    }
}

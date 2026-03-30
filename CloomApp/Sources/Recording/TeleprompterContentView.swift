import SwiftUI

/// SwiftUI content view for the teleprompter overlay panel.
/// Displays scrolling script text with controls, edge fades, and scroll wheel support.
struct TeleprompterContentView: View {
    let script: String
    let fontSize: CGFloat
    let backgroundOpacity: Double
    let scrollOffset: CGFloat
    let isScrolling: Bool
    let mirrorEnabled: Bool
    let scrollSpeed: CGFloat
    let onToggleScroll: () -> Void
    let onReset: () -> Void
    let onManualScroll: (CGFloat) -> Void
    let onContentHeightChanged: (CGFloat) -> Void
    let onSpeedChange: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Script text area
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(backgroundOpacity))

                    scrollableText(viewportHeight: geo.size.height)
                        .mask(edgeFadeMask(height: geo.size.height))
                }
            }

            // Control bar
            controlBar
        }
        .onScrollWheel { delta in
            onManualScroll(-delta * 3)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            // Reset
            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Reset to top")

            Spacer()

            // Slower
            Button { onSpeedChange(-10) } label: {
                Text("Slower")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: .capsule)
            }
            .buttonStyle(.plain)
            .help("Decrease scroll speed")

            // Play / Pause
            Button(action: onToggleScroll) {
                HStack(spacing: 6) {
                    Image(systemName: isScrolling ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                    Text(isScrolling ? "Pause" : "Scroll")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15), in: .capsule)
            }
            .buttonStyle(.plain)
            .help("Toggle auto-scroll (⌘⇧T)")

            // Faster
            Button { onSpeedChange(10) } label: {
                Text("Faster")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: .capsule)
            }
            .buttonStyle(.plain)
            .help("Increase scroll speed")

            Spacer()

            // Speed indicator
            Text("\(Int(scrollSpeed)) pt/s")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(.black.opacity(backgroundOpacity * 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: - Scrollable Text

    private func scrollableText(viewportHeight: CGFloat) -> some View {
        Text(script)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.white)
            .lineSpacing(fontSize * 0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .scaleEffect(x: mirrorEnabled ? -1 : 1, y: 1)
            .fixedSize(horizontal: false, vertical: true)
            // Measure full text height BEFORE clipping
            .background(
                GeometryReader { textGeo in
                    Color.clear.preference(
                        key: ContentHeightKey.self,
                        value: textGeo.size.height
                    )
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { height in
                onContentHeightChanged(height)
            }
            .offset(y: -scrollOffset)
            .frame(height: viewportHeight, alignment: .top)
            .clipped()
    }

    // MARK: - Edge Fade Mask

    private func edgeFadeMask(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)

            Color.white

            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
        }
        .frame(height: height)
    }
}

// MARK: - Scroll Wheel Modifier

private struct ScrollWheelModifier: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content.background(
            ScrollWheelView(onScroll: onScroll)
        )
    }
}

private struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var isDragging = false
    private var lastDragY: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastDragY = event.locationInWindow.y
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentY = event.locationInWindow.y
        let delta = lastDragY - currentY
        lastDragY = currentY
        onScroll?(-delta)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }
}

extension View {
    func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(onScroll: action))
    }
}

// MARK: - Preference Key

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

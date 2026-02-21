import SwiftUI
import AppKit

@MainActor
final class CountdownOverlayWindow {
    private var panel: NSPanel?

        func show(count: Int) {
        if panel == nil {
            createFullScreenPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(rootView: CountdownContentView(count: count))
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    func show(count: Int, region: CGRect) {
        if panel == nil {
            createFullScreenPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(rootView: CountdownRegionContentView(count: count, region: region))
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func createFullScreenPanel() {
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
    }
}

// MARK: - Countdown views

private struct CountdownContentView: View {
    let count: Int

    var body: some View {
        ZStack {
            Color.dimmingOverlay

            Text("\(count)")
                .font(.system(size: 200, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: count)
        }
    }
}

private struct CountdownRegionContentView: View {
    let count: Int
    let region: CGRect

    var body: some View {
        GeometryReader { geo in
            let holeRect = CGRect(
                x: region.origin.x,
                y: region.origin.y,
                width: region.width,
                height: region.height
            )

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(holeRect)
                }
                .fill(Color.dimmingOverlay, style: FillStyle(eoFill: true))

                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(.white)
                    .frame(width: region.width, height: region.height)
                    .position(x: holeRect.midX, y: holeRect.midY)

                Text("\(count)")
                    .font(.system(size: min(region.width, region.height) * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .position(x: holeRect.midX, y: holeRect.midY)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: count)
            }
        }
        .ignoresSafeArea()
    }
}

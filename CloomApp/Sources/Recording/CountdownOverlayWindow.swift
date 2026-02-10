import SwiftUI
import AppKit

@MainActor
final class CountdownOverlayWindow {
    private var panel: NSPanel?

    func show(count: Int) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let hostingView = NSHostingView(rootView: CountdownContentView(count: count))
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func createPanel() {
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

// MARK: - SwiftUI Content

private struct CountdownContentView: View {
    let count: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)

            Text("\(count)")
                .font(.system(size: 200, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: count)
        }
    }
}

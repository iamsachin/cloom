import SwiftUI
import AppKit

@MainActor
final class RewindPickerPanel {
    private var panel: NSPanel?
    private var model = RewindPickerModel()

    func show(
        totalDuration: TimeInterval,
        onConfirm: @escaping (TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        model.totalDuration = totalDuration
        model.rewindSeconds = min(10, totalDuration)

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
                styleMask: [.titled, .nonactivatingPanel, .hudWindow],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 2)
            panel.title = "Rewind Recording"
            panel.isMovableByWindowBackground = true
            panel.sharingType = .none

            let hostingView = NSHostingView(
                rootView: RewindPickerContentView(
                    model: model,
                    onConfirm: { [weak self] seconds in
                        self?.dismiss()
                        onConfirm(seconds)
                    },
                    onCancel: { [weak self] in
                        self?.dismiss()
                        onCancel()
                    }
                )
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 240)
            panel.contentView = hostingView

            if let screen = NSScreen.main {
                let x = screen.frame.midX - 170
                let y = screen.frame.midY - 120
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

@MainActor
final class RewindPickerModel: ObservableObject {
    @Published var totalDuration: TimeInterval = 0
    @Published var rewindSeconds: TimeInterval = 10
}

import SwiftUI
import AppKit

@MainActor
final class ExportProgressWindow {
    private var panel: NSPanel?
    private var progressModel = ExportProgressModel()

    func show(message: String) {
        progressModel.message = message
        progressModel.progress = 0

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.title = "Processing"
            panel.isMovableByWindowBackground = true

            let hostingView = NSHostingView(
                rootView: ExportProgressContentView(model: progressModel)
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
            panel.contentView = hostingView

            if let screen = NSScreen.main {
                let x = screen.frame.midX - 150
                let y = screen.frame.midY - 50
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func updateProgress(_ value: Double) {
        progressModel.progress = value
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

@MainActor
private class ExportProgressModel: ObservableObject {
    @Published var message: String = ""
    @Published var progress: Double = 0
}

private struct ExportProgressContentView: View {
    @ObservedObject var model: ExportProgressModel

    var body: some View {
        VStack(spacing: 12) {
            Text(model.message)
                .font(.headline)

            ProgressView(value: model.progress)

            Text("\(Int(model.progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 300)
    }
}

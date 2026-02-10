import SwiftUI
import AppKit

@MainActor
final class RegionHighlightOverlay {
    private var panel: NSPanel?

    func show(region: CGRect) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none  // Don't capture this overlay

        let hostingView = NSHostingView(
            rootView: RegionHighlightView(region: region)
        )
        hostingView.frame = screen.frame
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - SwiftUI overlay

private struct RegionHighlightView: View {
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
                .fill(Color.black.opacity(0.25), style: FillStyle(eoFill: true))

                Rectangle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: region.width + 2, height: region.height + 2)
                    .position(
                        x: holeRect.midX,
                        y: holeRect.midY
                    )
            }
        }
        .ignoresSafeArea()
    }
}

import SwiftUI
import AppKit

/// Shown after a user completes permissions onboarding. Teaches them where
/// Cloom lives (the menu bar) so a headless LSUIElement app isn't invisible.
/// Window repositions itself to the top-right so the up-right arrow naturally
/// points at the actual menu bar icon.
struct MenuBarHintView: View {
    let onDismiss: () -> Void

    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .offset(x: arrowOffset, y: -arrowOffset)
                .animation(
                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: arrowOffset
                )
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Cloom lives in your menu bar.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Click the Cloom icon up there to start a recording, open your library, or change settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Text("Got it")
                    .font(.headline)
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 480, height: 440)
        .onAppear {
            arrowOffset = 10
            repositionWindowNearMenuBar()
        }
    }

    private func repositionWindowNearMenuBar() {
        DispatchQueue.main.async {
            guard
                let window = NSApp.windows.first(where: { $0.title == "Welcome to Cloom" }),
                let screen = NSScreen.main
            else { return }
            let target = NSSize(width: 480, height: 440)
            let visible = screen.visibleFrame
            let x = visible.maxX - target.width - 20
            let y = visible.maxY - target.height - 12
            window.setFrame(
                NSRect(origin: NSPoint(x: x, y: y), size: target),
                display: true,
                animate: true
            )
        }
    }
}

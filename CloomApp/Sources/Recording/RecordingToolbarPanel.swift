import SwiftUI
import AppKit

@MainActor
final class RecordingToolbarPanel {
    private var panel: NSPanel?
    private var onStop: (() -> Void)?

    func show(
        startedAt: Date,
        pausedDuration: TimeInterval = 0,
        isPaused: Bool = false,
        micEnabled: Bool,
        cameraEnabled: Bool,
        systemAudioEnabled: Bool = true,
        annotationsEnabled: Bool = false,
        clickEmphasisEnabled: Bool = false,
        spotlightEnabled: Bool = false,
        zoomEnabled: Bool = false,
        keystrokeEnabled: Bool = false,
        teleprompterEnabled: Bool = false,
        onStop: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onToggleAnnotations: @escaping () -> Void = {},
        onToggleClickEmphasis: @escaping () -> Void = {},
        onToggleCursorSpotlight: @escaping () -> Void = {},
        onToggleZoom: @escaping () -> Void = {},
        onToggleKeystroke: @escaping () -> Void = {},
        onToggleTeleprompter: @escaping () -> Void = {},
        onToggleSystemAudio: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void = {},
        onRewind: @escaping () -> Void = {}
    ) {
        self.onStop = onStop
        if panel == nil { createPanel() }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: RecordingToolbarContentView(
                startedAt: startedAt,
                initialPausedDuration: pausedDuration,
                initialIsPaused: isPaused,
                initialMicEnabled: micEnabled,
                initialCameraEnabled: cameraEnabled,
                initialSystemAudioEnabled: systemAudioEnabled,
                initialAnnotationsEnabled: annotationsEnabled,
                initialClickEmphasisEnabled: clickEmphasisEnabled,
                initialSpotlightEnabled: spotlightEnabled,
                initialZoomEnabled: zoomEnabled,
                initialKeystrokeEnabled: keystrokeEnabled,
                initialTeleprompterEnabled: teleprompterEnabled,
                onStop: onStop,
                onToggleMic: onToggleMic,
                onToggleCamera: onToggleCamera,
                onPause: onPause,
                onResume: onResume,
                onToggleAnnotations: onToggleAnnotations,
                onToggleClickEmphasis: onToggleClickEmphasis,
                onToggleCursorSpotlight: onToggleCursorSpotlight,
                onToggleZoom: onToggleZoom,
                onToggleKeystroke: onToggleKeystroke,
                onToggleTeleprompter: onToggleTeleprompter,
                onToggleSystemAudio: onToggleSystemAudio,
                onDiscard: onDiscard,
                onRewind: onRewind
            )
        )

        positionPanel(panel, hostingView: hostingView)
        panel.orderFrontRegardless()
    }

    func showReady(
        micEnabled: Bool,
        cameraEnabled: Bool,
        systemAudioEnabled: Bool = true,
        annotationsEnabled: Bool = false,
        clickEmphasisEnabled: Bool = false,
        spotlightEnabled: Bool = false,
        keystrokeEnabled: Bool = false,
        teleprompterEnabled: Bool = false,
        onToggleMic: @escaping () -> Void,
        onToggleCamera: @escaping () -> Void,
        onToggleSystemAudio: @escaping () -> Void = {},
        onToggleAnnotations: @escaping () -> Void = {},
        onToggleClickEmphasis: @escaping () -> Void = {},
        onToggleCursorSpotlight: @escaping () -> Void = {},
        onToggleKeystroke: @escaping () -> Void = {},
        onToggleTeleprompter: @escaping () -> Void = {},
        onRecord: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        if panel == nil { createPanel() }
        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: ReadyToolbarContentView(
                initialMicEnabled: micEnabled,
                initialCameraEnabled: cameraEnabled,
                initialSystemAudioEnabled: systemAudioEnabled,
                initialAnnotationsEnabled: annotationsEnabled,
                initialClickEmphasisEnabled: clickEmphasisEnabled,
                initialSpotlightEnabled: spotlightEnabled,
                initialKeystrokeEnabled: keystrokeEnabled,
                initialTeleprompterEnabled: teleprompterEnabled,
                onToggleMic: onToggleMic,
                onToggleCamera: onToggleCamera,
                onToggleSystemAudio: onToggleSystemAudio,
                onToggleAnnotations: onToggleAnnotations,
                onToggleClickEmphasis: onToggleClickEmphasis,
                onToggleCursorSpotlight: onToggleCursorSpotlight,
                onToggleKeystroke: onToggleKeystroke,
                onToggleTeleprompter: onToggleTeleprompter,
                onRecord: onRecord,
                onCancel: onCancel
            )
        )

        positionPanel(panel, hostingView: hostingView)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        onStop = nil
    }

    // MARK: - Private

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel, hostingView: NSHostingView<some View>) {
        let fittingSize = hostingView.fittingSize
        let panelWidth = max(fittingSize.width, 400)
        let panelHeight = max(fittingSize.height, 44)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

        if let screen = NSScreen.main {
            let x = screen.frame.midX - panelWidth / 2
            let y = screen.frame.maxY - screen.frame.height * 0.10
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

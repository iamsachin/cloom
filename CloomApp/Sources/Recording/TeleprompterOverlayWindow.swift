import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TeleprompterOverlay")

/// Floating transparent teleprompter panel — visible to the presenter but excluded from screen capture.
/// Uses `sharingType = .none` so it's invisible to SCStream.
@MainActor
final class TeleprompterOverlayWindow {
    private var panel: NSPanel?
    private var scrollTimer: Timer?

    // Scroll state
    private(set) var isScrolling = false
    private var scrollOffset: CGFloat = 0
    private var contentHeight: CGFloat = 0
    private var lastTickTime: TimeInterval = 0

    // Configuration (read from UserDefaults on show)
    private var scriptText: String = ""
    private var fontSize: CGFloat = 40
    private var opacity: Double = 0.85
    private var position: TeleprompterPosition = .bottom
    private var scrollSpeed: CGFloat = 60 // points per second
    private var mirrorEnabled: Bool = false

    func show(
        script: String,
        fontSize: CGFloat,
        opacity: Double,
        position: TeleprompterPosition,
        scrollSpeed: CGFloat,
        mirrorEnabled: Bool
    ) {
        self.scriptText = script
        self.fontSize = fontSize
        self.opacity = opacity
        self.position = position
        self.scrollSpeed = scrollSpeed
        self.mirrorEnabled = mirrorEnabled
        self.scrollOffset = 0
        self.isScrolling = false

        if panel == nil { createPanel() }
        guard let panel else { return }

        updateContent()
        positionPanel(panel)
        panel.orderFrontRegardless()
        logger.info("Teleprompter overlay shown")
    }

    func dismiss() {
        stopScrolling()
        panel?.orderOut(nil)
        panel = nil
        scriptText = ""
        scrollOffset = 0
        logger.info("Teleprompter overlay dismissed")
    }

    // MARK: - Scroll Control

    func startScrolling() {
        guard !isScrolling else { return }
        isScrolling = true
        lastTickTime = ProcessInfo.processInfo.systemUptime
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickScroll()
            }
        }
        updateContent()
    }

    func stopScrolling() {
        isScrolling = false
        scrollTimer?.invalidate()
        scrollTimer = nil
        updateContent()
    }

    func toggleScrolling() {
        if isScrolling {
            stopScrolling()
        } else {
            startScrolling()
        }
    }

    func resetScroll() {
        stopScrolling()
        scrollOffset = 0
        updateContent()
    }

    func nudgeScroll(by delta: CGFloat) {
        scrollOffset = max(0, scrollOffset + delta)
        let maxScroll = max(0, contentHeight - viewportHeight())
        scrollOffset = min(scrollOffset, maxScroll)
        updateContent()
    }

    func adjustSpeed(by delta: CGFloat) {
        let newSpeed = max(10, min(200, scrollSpeed + delta))
        scrollSpeed = newSpeed
        UserDefaults.standard.set(Double(newSpeed), forKey: UserDefaultsKeys.teleprompterScrollSpeed)
        updateContent()
    }

    func updateScrollSpeed(_ speed: CGFloat) {
        self.scrollSpeed = speed
    }

    // MARK: - Private

    private func createPanel() {
        let frame = panelFrame()
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 300, height: 150)

        self.panel = panel
    }

    private func panelFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelWidth = screen.width * 0.6
        let panelHeight: CGFloat = 280

        let x = screen.midX - panelWidth / 2
        let y: CGFloat
        switch position {
        case .top:
            y = screen.maxY - panelHeight - 60
        case .bottom:
            y = screen.minY + 60
        }
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    private func positionPanel(_ panel: NSPanel) {
        let frame = panelFrame()
        panel.setFrame(frame, display: true)
    }

    private func viewportHeight() -> CGFloat {
        // Approximate viewport = panel height - control bar (36) - top safe area
        return max(100, (panel?.frame.height ?? 280) - 50)
    }

    private func tickScroll() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTickTime
        lastTickTime = now

        scrollOffset += scrollSpeed * CGFloat(dt)

        let maxScroll = max(0, contentHeight - viewportHeight())
        if scrollOffset >= maxScroll {
            scrollOffset = maxScroll
            stopScrolling()
            return
        }

        updateContent()
    }

    private func updateContent() {
        guard let panel else { return }
        let frame = panel.frame
        let view = TeleprompterContentView(
            script: scriptText,
            fontSize: fontSize,
            backgroundOpacity: opacity,
            scrollOffset: scrollOffset,
            isScrolling: isScrolling,
            mirrorEnabled: mirrorEnabled,
            scrollSpeed: scrollSpeed,
            onToggleScroll: { [weak self] in self?.toggleScrolling() },
            onReset: { [weak self] in self?.resetScroll() },
            onManualScroll: { [weak self] delta in self?.nudgeScroll(by: delta) },
            onContentHeightChanged: { [weak self] height in
                self?.contentHeight = height
            },
            onSpeedChange: { [weak self] delta in self?.adjustSpeed(by: delta) }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hostingView
    }
}
